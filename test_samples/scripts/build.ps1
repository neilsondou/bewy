#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info'    { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-ProjectStats {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $files = Get-ChildItem -Path $Path -Recurse -File
    $stats = @{
        TotalFiles = $files.Count
        TotalSize  = ($files | Measure-Object -Property Length -Sum).Sum
        Extensions = @{}
    }

    foreach ($file in $files) {
        $ext = $file.Extension
        if (-not $ext) { $ext = '(none)' }
        if ($stats.Extensions.ContainsKey($ext)) {
            $stats.Extensions[$ext]++
        } else {
            $stats.Extensions[$ext] = 1
        }
    }

    return $stats
}

function Invoke-Build {
    param([string]$ProjectPath = '.')

    Write-Log "Starting build..."
    $stats = Get-ProjectStats -Path $ProjectPath

    Write-Log "Project stats:"
    Write-Log "  Total files: $($stats.TotalFiles)"
    Write-Log "  Total size: $([math]::Round($stats.TotalSize / 1KB, 2)) KB"
    Write-Log "  File types:"

    $stats.Extensions.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        ForEach-Object {
            Write-Log "    $($_.Key): $($_.Value) files"
        }

    Write-Log "Build complete!" -Level Info
}

# Main
try {
    Invoke-Build -ProjectPath $PSScriptRoot
} catch {
    Write-Log "Build failed: $_" -Level Error
    exit 1
}
