# SM-S928N / S928NKSU6EZIF / KTC v1.3 report

## Result

The KTC adaptation obtained root on the connected handset on its first full
attempt after the pselect-gate fix. The bundled KernelSU 3.2.5 module was then
late-loaded successfully. SELinux returned to **Enforcing**, and the boot ID did
not change. Root remains per-boot; no partition or boot image was modified.

## Exact target identity

| Property | Live value |
| --- | --- |
| Model / device | `SM-S928N` / `e3q` |
| Active and bootloader sales codes | `KTC` / `KTC` |
| Firmware | `S928NKSU6EZIF` |
| Fingerprint | `samsung/e3qksx/e3q:17/CP2A.260605.016/S928NKSU6EZIF:user/release-keys` |
| Android / SDK | 17 / 37 |
| Kernel | `6.1.162-android14-11-34343818-abS928NKSU6EZIF` |
| Security patch | 2026-09-05 |
| `/proc/zoneinfo` Normal `start_pfn` | 530144 = `P0_PHYS_OFFSET 0x816e0000` |
| KASLR slide used during validation | `0x110000` |
| Boot ID before and after late-load | `998c9afb-e6e1-4fb9-b654-91de46a762d0` |

The original v1.2 target guard already accepted this firmware. The failure was
not a KTC kernel-offset mismatch.

## Failure analysis and changes

The supplied v1.2 failure log contained 13 complete attempts ending in:

```text
p0 pipe gate hits=0 changed=0
p0 physical pipe reclaim miss
slide kaslr leak failed
```

The tracefs diagnostic instead recovered exactly one caller candidate,
`slide=0x110000`, with event ID 106 and no parse failures. The KTC profile now:

- requires model, firmware, kernel, Android/SDK, patch and `KTC` sales codes;
- uses the exact tracefs caller for KASLR and refuses the physical-P0 fallback;
- restores the EZIF pselect gate: a positive pselect result requires a successful
  scheduler transition; a timeout additionally requires one call and a zero
  scheduler return value;
- retains independent retry and the second bank slot that restores
  `ashmem_misc_fops` after `triggered && !verified`.

The pselect condition was checked against the published v1.2 binary's ARM64
instructions, not inferred from the CSC.

## Full test 1: stopped before the misc_fops write

`ktc-v1.3-full-test-1.log` reached tracefs KASLR and the FOPS route, but ended
with:

```text
S928 route result=0 waiter_ok=1 write_window=0 ... pselect_ret=7
app fops slide attempt=1/1 triggered=0 verified=0
```

No misc_fops write or root occurred. The phone remained usable. This exposed
that the public upstream source did not set `slide_pselect_write_window`; the
condition was restored before the second test.

## Full test 2: root on attempt 1

`ktc-v1.3-full-test-2-root.log` records:

```text
slide-kaslr-ok source=tracefs ... slide=0000000000110000 data_mode=canonical
app fops slide attempt=1/1 triggered=1 verified=1 step=0 errno=0
pipe physrw ... done=1 root=1 kaslr=1 read_ok=1 write_ok=1 rw64=1/1 uid=2000->0
exploit completed attempt=1/1
```

The root client then reported:

```text
uid=0(root) gid=0(root) groups=0(root) context=u:r:kernel:s0
root
Permissive
```

Permissive was the expected temporary state before KernelSU late-load.

## KernelSU late-load

The current upstream helper passes `--ephemeral`, which the paired EZIF `ksud`
rejects. The standalone helper build therefore sets
`KSUD_LATE_LOAD_EPHEMERAL=0`; the repacked APK also retains the original EZIF
helper, which does not contain that flag.

Late-load used the same private mount namespace and bind-mounted
`/data/local/tmp/ksud-s25u-kdp` over `/system/bin/logcat`, without
`--ephemeral`. See `ktc-v1.3-late-load.log`. Validation afterwards:

```text
Enforcing
998c9afb-e6e1-4fb9-b654-91de46a762d0
kernelsu 217088 0 - Live 0x0000000000000000 (O)
```

The late-load script could not create its status file after SELinux returned to
Enforcing; that expected permission error happened **after** `ksud` exited 0 and
does not indicate a module-load failure. The old bootstrap root socket likewise
became unavailable under Enforcing. KernelSU Manager was opened for visual
confirmation; this report does not claim a UI state that was not captured.

## Artifacts

| File | SHA-256 |
| --- | --- |
| `artifacts/e3q-S928NKSU6EZIF/cve-2026-43499-app.so` | `c83f92534ff24daf6c75bb1882ac84344893f29e23cc7cab52ff99727686cdd4` |
| `kernelsu/ksud-e3q-S928NKSU6EZIF-kdp` | `248725370336cd1557503a6ba525e34969b9b922bedc63f43290efc349d7b874` |
| `releases/RootMyGalaxy-EZIF-KTC-v1.3-debug.apk` | `395b652efe4018a5d113574f0655a51f86c17a6d8128ddb6076edd97a8e2a221` |
| Standalone root helper (local build) | `e0bf49c29086e369fba854d0ac7778f61c07600f224c17fd3e67564142e71f99` |

The APK is signed with a new local debug key. It cannot be installed as an
update over the differently signed v1.2 APK. Uninstall the old package first
(which removes its app data), then install the KTC APK. Do not uninstall it if
you need to preserve its settings.

## Rebuild

Use upstream BuSung-dev/Root-My-Galaxy-Payloads commit
`6e3223e689688540060ddd97a0927e927bfed207`, apply
`patches/ktc-v1.3-upstream.patch`, then run `tools/build_ktc.ps1` with Android
NDK r28c. `tools/repack_ktc.py` bundles the resulting payload into the offline
EZIF installer. These are build instructions, not a request to rerun the
exploit. A reboot returns the phone to stock.
