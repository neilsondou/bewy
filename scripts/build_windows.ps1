param(
  [string]$Version = "",
  [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")

function Get-VersionFromPubspec {
  $pubspec = Get-Content "pubspec.yaml" -Raw
  $match = [regex]::Match($pubspec, "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9A-Za-z\.-]+)?\s*$")
  if (-not $match.Success) {
    throw "Cannot parse version from pubspec.yaml"
  }
  return $match.Groups[1].Value
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-VersionFromPubspec
}

$buildTime = [DateTimeOffset]::Now.ToString("yyyy-MM-dd HH:mm:ss zzz")
$flutterVersion = "unknown"

try {
  $flutterInfoRaw = flutter --version --machine
  $flutterInfo = $flutterInfoRaw | ConvertFrom-Json
  if ($flutterInfo.flutterVersion) {
    $flutterVersion = $flutterInfo.flutterVersion
  } elseif ($flutterInfo.frameworkVersion) {
    $flutterVersion = $flutterInfo.frameworkVersion
  }
} catch {
  Write-Warning "Failed to detect Flutter version from flutter --version --machine, fallback to 'unknown'."
}

Write-Host "Building bewy windows release..."
Write-Host "APP_VERSION=$Version"
Write-Host "BUILD_TIME=$buildTime"
Write-Host "FLUTTER_VERSION=$flutterVersion"

# Verify tree-sitter grammar sources exist before building
$tsGrammarDir = Join-Path $PSScriptRoot ".." "third_party" "tree_sitter" "grammars"
if (-not (Test-Path $tsGrammarDir)) {
  Write-Warning "Tree-sitter grammars not found. Run scripts/download_tree_sitter_grammars.ps1 first."
}

$modeArg = if ($Release) { "--release" } else { "--debug" }

flutter build windows $modeArg `
  --dart-define=APP_VERSION="$Version" `
  --dart-define=BUILD_TIME="$buildTime" `
  --dart-define=FLUTTER_VERSION="$flutterVersion"

if ($LASTEXITCODE -ne 0) {
  throw "flutter build windows failed with code $LASTEXITCODE"
}

Write-Host "Build completed: build/windows/x64/runner/Release/bewy.exe"

# Verify tree-sitter DLL was built and installed
$tsDll = Join-Path $PSScriptRoot ".." "build" "windows" "x64" "runner" "Release" "bewy_tree_sitter.dll"
if (Test-Path $tsDll) {
  Write-Host "Tree-sitter DLL: $tsDll"
} else {
  Write-Warning "bewy_tree_sitter.dll not found in output directory."
}
