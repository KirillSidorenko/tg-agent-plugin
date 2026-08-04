$ErrorActionPreference = 'Stop'
$PassCount = 0
$FailCount = 0

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message. Expected [$Expected], received [$Actual]."
    }
}

function Assert-Contains {
    param([string]$Actual, [string]$Expected, [string]$Message)
    if (-not $Actual.Contains($Expected)) {
        throw "$Message. Expected [$Expected] in [$Actual]."
    }
}

function Assert-Throws {
    param([scriptblock]$Operation, [string]$Expected, [string]$Message)
    try {
        & $Operation
    }
    catch {
        Assert-Contains -Actual $_.Exception.Message -Expected $Expected -Message $Message
        return
    }
    throw "$Message. Expected an exception containing [$Expected]."
}

function Run-Test {
    param([string]$Name, [scriptblock]$Operation)
    try {
        & $Operation
        $script:PassCount++
        Write-Host "ok - $Name"
    }
    catch {
        $script:FailCount++
        Write-Host "not ok - $Name"
        Write-Host $_.Exception.Message
    }
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ToolPath = Join-Path $RepositoryRoot 'plugins\tg-agent-plugin\scripts\tg-tool.ps1'
$TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "tg-agent-windows-test.$([guid]::NewGuid().ToString('N'))"
$env:LOCALAPPDATA = Join-Path $TestRoot 'local'
$env:USERPROFILE = Join-Path $TestRoot 'home'
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null

. $ToolPath -LibraryOnly

$ExpectedHash = 'b5b3dab350c073d4058805c3327e849f8ee8cccb6ecd28e668838d10a0be33de'
$ArchiveData = @{
    Entries = @('LICENSE', 'README.md', 'tg.exe')
    Details = @(
        '-rw-r--r-- user/group 1 2026-01-01 00:00 LICENSE',
        '-rw-r--r-- user/group 1 2026-01-01 00:00 README.md',
        '-rwxr-xr-x user/group 1 2026-01-01 00:00 tg.exe'
    )
}
$SmokePass = $true
$LatestUrl = 'https://github.com/gotd/cli/releases/tag/v0.12.0'

function Get-PlatformArchitecture { 'amd64' }
function Invoke-TgDownload {
    param([string]$Uri, [string]$Destination)
    Set-Content -LiteralPath $Destination -Value 'mock archive' -Encoding Ascii
}
function Get-ArchiveSha256 { param([string]$Archive) $script:ExpectedHash }
function Get-ArchiveEntryData { param([string]$Archive) $script:ArchiveData }
function Expand-TgArchive {
    param([string]$Archive, [string]$Destination)
    Set-Content -LiteralPath (Join-Path $Destination 'tg.exe') -Value 'new-binary' -Encoding Ascii
}
function Invoke-SmokeCheck { param($Executable, $Manifest) $script:SmokePass }
function Get-LatestReleaseUrl { $script:LatestUrl }

Run-Test 'pinned Windows asset contract' {
    $manifest = Read-ReleaseManifest
    $asset = Get-PinnedAsset -Manifest $manifest
    Assert-Equal $asset.name 'tg_0.11.0_windows_amd64.tar.gz' 'asset name'
    Assert-Equal $asset.sha256 $ExpectedHash 'asset SHA-256'
}

Run-Test 'install and state' {
    Install-Pinned -SuccessStatus 'installed' | Out-Null
    Assert-Equal (Test-Path -LiteralPath $ManagedPath -PathType Leaf) $true 'managed executable'
    $state = Get-Content -LiteralPath $InstallStatePath -Raw | ConvertFrom-Json
    Assert-Equal $state.version '0.11.0' 'installed version'
    Assert-Equal $state.archiveSha256 $ExpectedHash 'state digest'
}

Run-Test 'checksum mismatch preserves current executable' {
    Set-Content -LiteralPath $ManagedPath -Value 'old-checksum-binary' -Encoding Ascii
    $script:ExpectedHash = '0' * 64
    Assert-Throws { Install-Pinned -SuccessStatus 'installed' | Out-Null } `
        'Checksum mismatch' 'checksum mismatch'
    Assert-Contains (Get-Content -LiteralPath $ManagedPath -Raw) 'old-checksum-binary' 'checksum preservation'
    $script:ExpectedHash = 'b5b3dab350c073d4058805c3327e849f8ee8cccb6ecd28e668838d10a0be33de'
}

Run-Test 'absolute path archive rejection' {
    Assert-Throws { Assert-SafeArchive @{ Entries = @('/tg.exe'); Details = @() } } `
        'absolute path' 'absolute path'
}

Run-Test 'parent traversal archive rejection' {
    Assert-Throws { Assert-SafeArchive @{ Entries = @('../tg.exe'); Details = @() } } `
        'parent traversal' 'parent traversal'
}

Run-Test 'symbolic link archive rejection' {
    $data = @{ Entries = @('LICENSE', 'README.md', 'tg.exe'); Details = @('lrwx tg.exe -> C:\Windows\System32\cmd.exe') }
    Assert-Throws { Assert-SafeArchive $data } 'symbolic links' 'symbolic link'
}

Run-Test 'hard link archive rejection' {
    $data = @{ Entries = @('LICENSE', 'README.md', 'tg.exe'); Details = @('hrwx tg.exe link to other.exe') }
    Assert-Throws { Assert-SafeArchive $data } 'hard links' 'hard link'
}

Run-Test 'duplicate executable archive rejection' {
    $data = @{ Entries = @('LICENSE', 'README.md', 'tg.exe', 'tg.exe'); Details = @() }
    Assert-Throws { Assert-SafeArchive $data } 'exactly one' 'duplicate executable'
}

Run-Test 'failed smoke rollback' {
    Set-Content -LiteralPath $ManagedPath -Value 'old-rollback-binary' -Encoding Ascii
    $script:SmokePass = $false
    Assert-Throws { Install-Pinned -SuccessStatus 'installed' | Out-Null } 'Smoke check failed' 'rollback'
    Assert-Contains (Get-Content -LiteralPath $ManagedPath -Raw) 'old-rollback-binary' 'rollback preservation'
    Assert-Equal (Test-Path -LiteralPath $BackupPath) $false 'rollback backup cleanup'
    $script:SmokePass = $true
}

Run-Test 'stale backup blocks replacement' {
    Set-Content -LiteralPath $BackupPath -Value 'stale' -Encoding Ascii
    Assert-Throws { Install-Pinned -SuccessStatus 'installed' | Out-Null } 'stale backup' 'stale backup'
    Remove-Item -LiteralPath $BackupPath -Force
}

Run-Test 'newer-unpinned update is report only' {
    $before = Get-Content -LiteralPath $ManagedPath -Raw
    $output = Get-UpdateStatus | Out-String
    Assert-Contains $output 'newer-unpinned' 'newer-unpinned report'
    Assert-Equal (Get-Content -LiteralPath $ManagedPath -Raw) $before 'report-only executable'
}

if (Test-Path -LiteralPath $TestRoot) {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force
}

Write-Host "$PassCount passed, $FailCount failed"
if ($FailCount -ne 0) { exit 1 }
