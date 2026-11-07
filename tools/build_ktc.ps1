param(
  [string]$UpstreamDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Root-My-Galaxy-Payloads'),
  [string]$NdkHome = (Join-Path (Split-Path -Parent $PSScriptRoot) '.tools\android-ndk-r28c')
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $ProjectRoot 'build\KTC-v1.3'
$Compiler = Join-Path $NdkHome 'toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android35-clang.cmd'

if (-not (Test-Path -LiteralPath $Compiler)) {
  throw "Android NDK r28c compiler not found: $Compiler"
}
if (-not (Test-Path -LiteralPath (Join-Path $UpstreamDir 'src\target_guard.c'))) {
  throw "Apply patches\ktc-v1.3-upstream.patch to the upstream tree first: $UpstreamDir"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Push-Location $UpstreamDir
try {
  $Sources = @(
    'src/target_guard.c',
    'src/main.c',
    'src/util.c',
    'src/slide_app.c',
    'src/fops.c',
    'src/pipe.c',
    'src/root.c',
    'src/preload.c'
  )
  $Flags = @(
    '-DAPP_PAYLOAD=1',
    '-DAPP_S928_STABLE_RACE=1',
    '-fPIC',
    '-Oz',
    '-g0',
    '-fvisibility=hidden',
    '-fno-semantic-interposition',
    '-fstack-protector-strong',
    '-fno-unwind-tables',
    '-fno-asynchronous-unwind-tables',
    '-ffunction-sections',
    '-fdata-sections',
    '-Wall',
    '-Wextra',
    '-Wno-unused-parameter',
    '-Wno-sign-compare',
    "-I$ProjectRoot\src",
    '-Isrc',
    '-DTARGET_HEADER=\"targets/e3q-S928NKSU6EZIF/target.h\"',
    '-shared',
    '-pthread',
    '-Wl,--gc-sections',
    '-Wl,--icf=all',
    '-s'
  )

  $Payload = Join-Path $OutDir 'cve-2026-43499-app.so'
  & $Compiler @Flags @Sources '-o' $Payload
  if ($LASTEXITCODE -ne 0) {
    throw "Payload compilation failed: $LASTEXITCODE"
  }

  $Size = (Get-Item -LiteralPath $Payload).Length
  if ($Size -gt 104128) {
    throw "Payload exceeds the fixed asset size: $Size"
  }
  python -c "from pathlib import Path; p=Path(r'$Payload'); b=p.read_bytes(); p.write_bytes(b+b'\0'*(104128-len(b)))"

  $RootHelper = Join-Path $OutDir 'cve-2026-43499-root'
  & $Compiler -fPIE -pie -O2 -g0 -Wall -Wextra -DKSUD_LATE_LOAD_EPHEMERAL=0 src/su_daemon.c -ldl -o $RootHelper
  if ($LASTEXITCODE -ne 0) {
    throw "Root-helper compilation failed: $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

Get-Item -LiteralPath (Join-Path $OutDir 'cve-2026-43499-app.so'), (Join-Path $OutDir 'cve-2026-43499-root') |
  ForEach-Object {
    $Hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$($_.FullName) size=$($_.Length) sha256=$Hash"
  }
