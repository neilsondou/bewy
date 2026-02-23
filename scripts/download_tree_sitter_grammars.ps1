<#
.SYNOPSIS
  Downloads tree-sitter runtime and 29 language grammar C sources for Bewy IDE.
.DESCRIPTION
  Clones the tree-sitter runtime library and grammar repos, then copies only
  the required C source files into third_party/tree_sitter/.
#>

param(
  [string]$Tag = "v0.24.7"
)

$ErrorActionPreference = "Stop"

$root = Join-Path $PSScriptRoot ".."
$tsDir = Join-Path (Join-Path $root "third_party") "tree_sitter"
$runtimeDir = Join-Path $tsDir "tree-sitter"
$grammarsDir = Join-Path $tsDir "grammars"
$tempDir = Join-Path $root ".ts_download_temp"

if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
New-Item -ItemType Directory -Path $grammarsDir -Force | Out-Null

# ── 1. Download tree-sitter runtime ──────────────────────────────────────
Write-Host "Downloading tree-sitter runtime ($Tag)..."
$tsRepo = Join-Path $tempDir "tree-sitter"
git clone --depth 1 --branch $Tag "https://github.com/tree-sitter/tree-sitter.git" $tsRepo

# Copy lib/ directory (contains the C runtime)
if (Test-Path (Join-Path $tsRepo "lib")) {
  Copy-Item -Path (Join-Path $tsRepo "lib") -Destination (Join-Path $runtimeDir "lib") -Recurse -Force
  Write-Host "  -> Copied tree-sitter/lib/"
}

# ── 2. Grammar repos ────────────────────────────────────────────────────
$grammars = @(
  @{ name = "c";          repo = "tree-sitter/tree-sitter-c";          src = "src" },
  @{ name = "cpp";        repo = "tree-sitter/tree-sitter-cpp";        src = "src" },
  @{ name = "javascript"; repo = "tree-sitter/tree-sitter-javascript"; src = "src" },
  @{ name = "typescript";  repo = "tree-sitter/tree-sitter-typescript"; src = "typescript/src" },
  @{ name = "tsx";         repo = "tree-sitter/tree-sitter-typescript"; src = "tsx/src" },
  @{ name = "python";     repo = "tree-sitter/tree-sitter-python";     src = "src" },
  @{ name = "dart";       repo = "UserNobody/tree-sitter-dart";        src = "src" },
  @{ name = "json";       repo = "tree-sitter/tree-sitter-json";       src = "src" },
  @{ name = "yaml";       repo = "tree-sitter-grammars/tree-sitter-yaml"; src = "src" },
  @{ name = "markdown";   repo = "tree-sitter-grammars/tree-sitter-markdown"; src = "tree-sitter-markdown/src" },
  @{ name = "html";       repo = "tree-sitter/tree-sitter-html";       src = "src" },
  @{ name = "xml";        repo = "tree-sitter-grammars/tree-sitter-xml"; src = "xml/src" },
  @{ name = "css";        repo = "tree-sitter/tree-sitter-css";        src = "src" },
  @{ name = "scss";       repo = "serenadeai/tree-sitter-scss";        src = "src" },
  @{ name = "java";       repo = "tree-sitter/tree-sitter-java";       src = "src" },
  @{ name = "kotlin";     repo = "fwcd/tree-sitter-kotlin";            src = "src" },
  @{ name = "swift";      repo = "alex-pinkus/tree-sitter-swift";      src = "src" },
  @{ name = "go";         repo = "tree-sitter/tree-sitter-go";         src = "src" },
  @{ name = "rust";       repo = "tree-sitter/tree-sitter-rust";       src = "src" },
  @{ name = "ruby";       repo = "tree-sitter/tree-sitter-ruby";       src = "src" },
  @{ name = "php";        repo = "tree-sitter/tree-sitter-php";        src = "php/src" },
  @{ name = "lua";        repo = "tree-sitter-grammars/tree-sitter-lua"; src = "src" },
  @{ name = "sql";        repo = "DerekStride/tree-sitter-sql";        src = "src" },
  @{ name = "bash";       repo = "tree-sitter/tree-sitter-bash";       src = "src" },
  @{ name = "csharp";     repo = "tree-sitter/tree-sitter-c-sharp";    src = "src" },
  @{ name = "r";          repo = "r-lib/tree-sitter-r";                src = "src" },
  @{ name = "toml";       repo = "tree-sitter-grammars/tree-sitter-toml"; src = "src" },
  @{ name = "powershell"; repo = "airbus-cert/tree-sitter-powershell"; src = "src" },
  @{ name = "dockerfile"; repo = "camdencheek/tree-sitter-dockerfile"; src = "src" },
  @{ name = "make";       repo = "alemuller/tree-sitter-make";         src = "src" }
)

$cloned = @{}
foreach ($g in $grammars) {
  $repoName = $g.repo.Split("/")[-1]
  $clonePath = Join-Path $tempDir $repoName

  if (-not $cloned.ContainsKey($g.repo)) {
    Write-Host "Cloning $($g.repo)..."
    git clone --depth 1 "https://github.com/$($g.repo).git" $clonePath
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "  !! Failed to clone $($g.repo), skipping $($g.name)"
      continue
    }
    $cloned[$g.repo] = $clonePath
  } else {
    $clonePath = $cloned[$g.repo]
  }

  $srcPath = Join-Path $clonePath $g.src
  $destPath = Join-Path $grammarsDir $g.name
  New-Item -ItemType Directory -Path $destPath -Force | Out-Null

  # Copy parser.c (required)
  $parserC = Join-Path $srcPath "parser.c"
  if (Test-Path $parserC) {
    Copy-Item $parserC -Destination $destPath -Force
    Write-Host "  -> $($g.name)/parser.c"
  } else {
    Write-Warning "  !! $($g.name)/parser.c NOT FOUND at $srcPath"
  }

  # Copy scanner.c or scanner.cc (optional)
  $scannerC = Join-Path $srcPath "scanner.c"
  $scannerCC = Join-Path $srcPath "scanner.cc"
  if (Test-Path $scannerC) {
    Copy-Item $scannerC -Destination $destPath -Force
    Write-Host "  -> $($g.name)/scanner.c"
  } elseif (Test-Path $scannerCC) {
    Copy-Item $scannerCC -Destination $destPath -Force
    Write-Host "  -> $($g.name)/scanner.cc"
  }

  # Copy tree_sitter/ include directory if present in src (needed by some grammars)
  $tsInclude = Join-Path $srcPath "tree_sitter"
  if (Test-Path $tsInclude) {
    Copy-Item -Path $tsInclude -Destination (Join-Path $destPath "tree_sitter") -Recurse -Force
    Write-Host "  -> $($g.name)/tree_sitter/"
  }
}

# ── 3. Cleanup ───────────────────────────────────────────────────────────
Write-Host "Cleaning up temp directory..."
Remove-Item $tempDir -Recurse -Force

Write-Host ""
Write-Host "Done. Grammar sources are in: $grammarsDir"
Write-Host "Tree-sitter runtime is in:    $runtimeDir"
