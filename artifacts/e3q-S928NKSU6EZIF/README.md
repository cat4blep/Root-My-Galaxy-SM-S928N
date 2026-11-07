# Exploit artifact · SM-S928N / S928NKSU6EZIF

Device-specific CVE-2026-43499 app payload used by the [schema-v3 support
feed](../../support/targets-v3.json) entry `e3q-S928NKSU6EZIF-KTC-v1.3`.

## Artifact

- File: `cve-2026-43499-app.so`
- Size: **104,128 bytes**
- SHA-256:

```text
c83f92534ff24daf6c75bb1882ac84344893f29e23cc7cab52ff99727686cdd4
```

This KTC v1.3 payload obtained root on the connected KTC handset on its first
full attempt: tracefs KASLR discovery, fake-FOPS/configfs access, physical
read/write and root UMH all completed. Exact firmware, kernel and memory-start
checks passed. See the KTC validation report for the separate first attempt,
which stopped before the misc_fops write and led to the pselect-gate fix.

The paired KernelSU daemon is described in the [artifact
reference](../../kernelsu/README.md). See the [KTC v1.3 validation
report](../../docs/ports/e3q-S928NKSU6EZIF/ktc-v1.3-report.md) for the live test and the
[original port report](../../docs/ports/e3q-S928NKSU6EZIF/port-report.md) for the firmware
values that remain candidates.
