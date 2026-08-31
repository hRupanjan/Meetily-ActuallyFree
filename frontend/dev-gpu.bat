@echo off
REM Meetily GPU-Accelerated Development Script for Windows
REM Automatically detects and runs in development mode with optimal GPU features
REM Based on build-gpu.bat but for development (debug build, tauri dev)

REM Exit on error
setlocal enabledelayedexpansion

REM Check if help is requested
if "%~1" == "help" (
    call :_print_help
    exit /b 0
) else if "%~1" == "--help" (
    call :_print_help
    exit /b 0
) else if "%~1" == "-h" (
    call :_print_help
    exit /b 0
) else if "%~1" == "/?" (
    call :_print_help
    exit /b 0
)

echo.
echo ========================================
echo   Meetily GPU-Accelerated Development
echo ========================================
echo.

echo.

REM Kill any existing processes on port 3118
echo [CLEAN] Checking for existing processes on port 3118...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3118 2^>nul') do (
    echo    Killing process %%a on port 3118
    taskkill /PID %%a /F >nul 2>&1
)

REM Set libclang path for whisper-rs-sys
set "LIBCLANG_PATH=C:\Program Files\LLVM\bin"

REM Try to find and setup Visual Studio environment
echo [SETUP] Setting up Visual Studio environment...
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2022 Build Tools
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

    REM Manually set up the environment
    set "LIB=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64"
    set "INCLUDE=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\include;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt"
    set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64;C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64;%PATH%"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2022 Build Tools
    call "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2022 Community
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2022 Professional
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2022 Enterprise
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    echo    Using Visual Studio 2019 Build Tools
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
) else (
    echo    [WARN]  Visual Studio not found, using manual SDK setup
    set "WindowsSDKVersion=10.0.22621.0"
    set "WindowsSDKLibVersion=10.0.22621.0"
    set "WindowsSDKIncludeVersion=10.0.22621.0"
    set "LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64;%LIB%"
    set "INCLUDE=C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared;C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt;%INCLUDE%"
    set "PATH=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64;%PATH%"
)

REM Prefer newer MSVC STL libs (VS18) so the linker can resolve modern
REM __std_* / charconv symbols pulled in by the prebuilt onnxruntime (ort crate).
if exist "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\lib\x64\msvcprt.lib" (
    echo    Prepending VS18 MSVC STL libs for onnxruntime link
    set "LIB=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\lib\x64;%LIB%"
)

REM Export environment variables for the child process
set "RUST_ENV_LIB=%LIB%"
set "RUST_ENV_INCLUDE=%INCLUDE%"

echo.
echo [BUILD] Starting Meetily in development mode...
echo.

REM Find package.json location
if exist "package.json" (
    echo    Found package.json in current directory
) else if exist "frontend\package.json" (
    echo    Found package.json in frontend directory
    cd frontend
) else (
    echo    [ERROR] Error: Could not find package.json
    echo    Make sure you're in the project root or frontend directory
    exit /b 1
)

REM Check if pnpm or npm is available
where pnpm >nul 2>&1
if %errorlevel% equ 0 (
    set "USE_PNPM=1"
) else (
    set "USE_PNPM=0"
)

where npm >nul 2>&1
if %errorlevel% equ 0 (
    set "USE_NPM=1"
) else (
    set "USE_NPM=0"
)

if %USE_PNPM% equ 0 (
    if %USE_NPM% equ 0 (
        echo    [ERROR] Error: Neither npm nor pnpm found
        exit /b 1
    )
)

REM Detect GPU feature (honor a preset TAURI_GPU_FEATURE, e.g. from tauri:dev:cuda)
if defined TAURI_GPU_FEATURE (
    echo [OK] Using forced GPU feature: !TAURI_GPU_FEATURE!
) else (
    echo [DETECT] Detecting GPU features...
    for /f "delims=" %%i in ('node scripts/auto-detect-gpu.js') do set TAURI_GPU_FEATURE=%%i
    if defined TAURI_GPU_FEATURE (
        echo [OK] Detected GPU feature: !TAURI_GPU_FEATURE!
    ) else (
        echo [WARN] No specific GPU feature detected or forced
    )
)

REM ============================================================
REM  CUDA 13.x build fixes - same as build-gpu.bat, needed here too
REM  because dev compiles the CUDA sys-crates. Each guarded so you can override.
REM ============================================================
if /i "!TAURI_GPU_FEATURE!"=="cuda" (
    echo [FIX] Applying CUDA 13.x build fixes...
    if not defined CMAKE_GENERATOR set "CMAKE_GENERATOR=Ninja"
    if not defined CARGO_BUILD_JOBS set "CARGO_BUILD_JOBS=4"
    if not defined CMAKE_BUILD_PARALLEL_LEVEL set "CMAKE_BUILD_PARALLEL_LEVEL=4"
    if not defined CUDAARCHS set "CUDAARCHS=120"
    if not defined CUDAFLAGS set "CUDAFLAGS=-Xcompiler=/Zc:preprocessor -std=c++17"
    set "MEETILY_STAGE_CUDA=1"
    where ninja >nul 2>&1
    if errorlevel 1 (
        echo    [WARN]  ninja not found on PATH - CUDA build needs it. Install: pip install ninja
    )
    echo    Cleaning stale CMake caches...
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\clean-stale-cmake.ps1
    echo    CMAKE_GENERATOR=!CMAKE_GENERATOR!  CUDAARCHS=!CUDAARCHS!  JOBS=!CARGO_BUILD_JOBS!
)

REM Build llama-helper
echo.
echo [HELPER] Building llama-helper sidecar (debug)...

set "HELPER_DIR=..\llama-helper"
if not exist "%HELPER_DIR%" (
    echo [ERROR] Could not find llama-helper directory at %HELPER_DIR%
    exit /b 1
)

set "HELPER_FEATURES="
if defined TAURI_GPU_FEATURE (
    set "HELPER_FEATURES=--features !TAURI_GPU_FEATURE!"
)

echo    Building in %HELPER_DIR% with features: %HELPER_FEATURES%
pushd "%HELPER_DIR%"
call cargo build %HELPER_FEATURES%
if errorlevel 1 (
    echo [ERROR] Failed to build llama-helper
    popd
    exit /b 1
)
popd
echo [OK] llama-helper built successfully

REM Detect target triple
echo.
echo [TARGET] Detecting target triple...
for /f "tokens=2" %%i in ('rustc -vV ^| findstr "host:"') do set TARGET_TRIPLE=%%i
echo    Target: !TARGET_TRIPLE!

REM Copy binary
set "BINARIES_DIR=src-tauri\binaries"
if not exist "%BINARIES_DIR%" mkdir "%BINARIES_DIR%"

REM Clean old binaries
del /q "%BINARIES_DIR%\llama-helper*" 2>nul

set "BASE_BINARY=llama-helper.exe"
set "SIDECAR_BINARY=llama-helper-!TARGET_TRIPLE!.exe"
set "SRC_PATH=..\target\debug\%BASE_BINARY%"
set "DEST_PATH=%BINARIES_DIR%\%SIDECAR_BINARY%"

if not exist "%SRC_PATH%" (
    REM Fallback check
    set "SRC_PATH=target\debug\%BASE_BINARY%"
)

if exist "%SRC_PATH%" (
    copy /Y "%SRC_PATH%" "%DEST_PATH%" >nul
    echo [OK] Copied binary to %DEST_PATH%
) else (
    echo [ERROR] Binary not found at %SRC_PATH%
    echo [WARN] Contents of ..\target\debug:
    dir "..\target\debug"
    exit /b 1
)

REM tauri's build-script codegen validates the bundle.resources glob
REM (runtime-deps/*) even in dev, so it must be non-empty. Pre-stage the CUDA
REM DLLs (DirectML.dll loads from target\debug at runtime via PATH).
if not exist "src-tauri\runtime-deps" mkdir "src-tauri\runtime-deps"
if /i "!TAURI_GPU_FEATURE!"=="cuda" (
    echo    Pre-staging CUDA runtime DLLs for resource glob...
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stage-runtime-deps.ps1 -AllowMissing
)

REM Run tauri dev
echo.
echo [BUILD] Starting complete Tauri application...
echo.

if %USE_PNPM% equ 1 (
    call pnpm run tauri:dev
) else (
    call npm run tauri:dev
)

if errorlevel 1 (
    echo.
    echo [ERROR] Development server encountered an error
    exit /b 1
)

echo.
echo ========================================
echo [OK] Development server stopped cleanly
echo ========================================
echo.
exit /b 0

:_print_help
echo.
echo ========================================
echo   Meetily GPU Development Script - Help
echo ========================================
echo.
echo USAGE:
echo   dev-gpu.bat [OPTION]
echo.
echo OPTIONS:
echo   help      Show this help message
echo   --help    Show this help message
echo   -h        Show this help message
echo   /?        Show this help message
echo.
echo DESCRIPTION:
echo   This script automatically detects your GPU and runs
echo   Meetily in development mode with optimal hardware acceleration:
echo.
echo   - NVIDIA GPU    : Builds with CUDA acceleration
echo   - AMD/Intel GPU : Builds with Vulkan acceleration
echo   - No GPU        : Builds with OpenBLAS CPU optimization
echo.
echo REQUIREMENTS:
echo   - Visual Studio 2022 Build Tools
echo   - Windows SDK 10.0.22621.0 or compatible
echo   - Rust toolchain installed
echo   - LLVM installed at C:\Program Files\LLVM\bin
echo.
echo ========================================
exit /b 0