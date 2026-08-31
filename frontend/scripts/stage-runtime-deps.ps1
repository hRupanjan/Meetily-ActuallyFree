# Stage Windows runtime dependencies for the NSIS/MSI installer.
# Runs as tauri beforeBundleCommand (after Rust compile, before bundling) AND
# can be called standalone. CUDA staging only runs for GPU/CUDA builds, gated on
# MEETILY_STAGE_CUDA=1 so CPU/Vulkan bundles don't fail on missing CUDA DLLs.
param(
  [string[]]$BuildOutput = @(),
  # Pre-build (before tauri codegen) DirectML.dll may not exist yet on a clean build.
  # AllowMissing warns instead of throwing so the resource glob still gets the CUDA DLLs.
  # The strict beforeBundleCommand pass (post-compile) then completes DirectML.
  [switch]$AllowMissing
)
$ErrorActionPreference = "Stop"
$frontend = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $frontend -Parent
$deps = Join-Path $frontend "src-tauri\runtime-deps"
New-Item -ItemType Directory -Force -Path $deps | Out-Null

if ($env:MEETILY_STAGE_CUDA -ne "1") {
  Write-Host "MEETILY_STAGE_CUDA != 1: skipping CUDA runtime staging (non-CUDA build)."
  return
}

$dlls = @("cudart64_13.dll", "cublas64_13.dll", "cublasLt64_13.dll", "DirectML.dll")
foreach ($dll in $dlls) {
  Remove-Item (Join-Path $deps $dll) -Force -ErrorAction SilentlyContinue
}

# Auto-locate the CUDA toolkit bin\x64 (where cudart/cublas DLLs live) so callers
# don't have to pass -BuildOutput. Honors CUDA_PATH, else newest v* under Program Files.
$cudaDirs = @()
if ($env:CUDA_PATH) { $cudaDirs += (Join-Path $env:CUDA_PATH "bin\x64"); $cudaDirs += (Join-Path $env:CUDA_PATH "bin") }
$cudaRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
if (Test-Path $cudaRoot) {
  Get-ChildItem $cudaRoot -Directory | Sort-Object Name -Descending | ForEach-Object {
    $cudaDirs += (Join-Path $_.FullName "bin\x64"); $cudaDirs += (Join-Path $_.FullName "bin")
  }
}

$candidates = @($BuildOutput | Where-Object { $_ } | ForEach-Object {
  [System.IO.Path]::GetFullPath($_)
}) + @(
  (Join-Path $repo "target\release"),
  (Join-Path $repo ".cuda_toolkit\bin\x64"),
  (Join-Path $repo ".cuda_toolkit\bin")
) + $cudaDirs

function Find-Dll([string]$name) {
  foreach ($dir in $candidates) {
    $p = Join-Path $dir $name
    if (Test-Path $p) { return $p }
  }
  return $null
}

foreach ($dll in $dlls) {
  $from = Find-Dll $dll
  if ($from) {
    Copy-Item $from (Join-Path $deps $dll) -Force
    Write-Host "staged $dll"
  } elseif ($AllowMissing) {
    Write-Warning "runtime DLL not found yet (will stage at bundle time): $dll"
  } else {
    throw "Required installer runtime missing: $dll"
  }
}

$vc = Join-Path $deps "vc_redist.x64.exe"
$vcSha256 = "CC0FF0EB1DC3F5188AE6300FAEF32BF5BEEBA4BDD6E8E445A9184072096B713B"
if (-not (Test-Path $vc)) {
  Write-Host "Downloading VC++ Redistributable x64..."
  Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile $vc -UseBasicParsing
}
# Use .NET SHA256 directly rather than Get-FileHash: the build env (vcvars) can
# clobber PSModulePath so Get-FileHash fails to autoload ("not recognized"), which
# would kill tauri's beforeBundleCommand.
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $actual = [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($vc))).Replace('-', '')
} finally {
  $sha.Dispose()
}
if ($actual -ne $vcSha256) {
  throw "VC++ Redistributable checksum mismatch (got $actual)"
}
Write-Host "Runtime deps ready:"
Get-ChildItem $deps | ForEach-Object { Write-Host ("  " + $_.Name) }
