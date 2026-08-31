# Purge stale CMake build trees whose configured generator doesn't match the one
# we want ($env:CMAKE_GENERATOR, default Ninja). cmake-rs skips reconfiguration when
# a build dir is already configured, so a leftover "Visual Studio" cache from an
# earlier manual run makes it drive MSBuild -> MSB1009. Deleting the stale tree forces
# a clean Ninja reconfigure. Only touches the CUDA/CMake-heavy sys crates.
$ErrorActionPreference = "SilentlyContinue"
$want = if ($env:CMAKE_GENERATOR) { $env:CMAKE_GENERATOR } else { "Ninja" }
$frontend = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $frontend -Parent

foreach ($profile in @("release", "debug")) {
  $buildRoot = Join-Path $repo "target\$profile\build"
  if (-not (Test-Path $buildRoot)) { continue }
  Get-ChildItem $buildRoot -Directory -Filter "*-sys*" |
    Where-Object { $_.Name -match "llama-cpp-sys|whisper-rs-sys" } |
    ForEach-Object {
      $cache = Join-Path $_.FullName "out\build\CMakeCache.txt"
      if (Test-Path $cache) {
        $gen = (Select-String -Path $cache -Pattern "CMAKE_GENERATOR:INTERNAL=(.*)").Matches.Groups[1].Value
        if ($gen -and $gen -notmatch [regex]::Escape($want)) {
          Write-Host "Purging stale CMake tree ($gen != $want): $($_.Name)"
          Remove-Item $_.FullName -Recurse -Force
        }
      }
    }
}
