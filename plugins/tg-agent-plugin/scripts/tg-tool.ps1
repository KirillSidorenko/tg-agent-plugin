[CmdletBinding()]
param(
    [ValidateSet('status', 'install', 'repair', 'check-update', 'authorize', 'verify-authorization')]
    [string]$Action = 'status',
    [switch]$Json,
    [ValidateSet('phone', 'qr')][string]$Mode = 'phone',
    [Parameter(DontShow)][switch]$LibraryOnly
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path (Split-Path -Parent $ScriptRoot) 'config\release-manifest.json'

if (-not $env:LOCALAPPDATA) {
    throw 'LOCALAPPDATA is unavailable.'
}

$ManagedPath = Join-Path $env:LOCALAPPDATA 'Programs\tg\tg.exe'
$BackupPath = Join-Path $env:LOCALAPPDATA 'Programs\tg\tg.exe.bak'
$NewPath = "$ManagedPath.new.$PID"
$StateDirectory = Join-Path $env:LOCALAPPDATA 'TGAgentPlugin'
$InstallStatePath = Join-Path $StateDirectory 'install.json'
$StateTempPath = "$InstallStatePath.tmp.$PID"

Remove-Item Env:TG_PASSWORD -ErrorAction SilentlyContinue
Remove-Item Env:APP_ID -ErrorAction SilentlyContinue
Remove-Item Env:APP_HASH -ErrorAction SilentlyContinue
Remove-Item Env:BOT_TOKEN -ErrorAction SilentlyContinue

function Write-Result {
    param(
        [Parameter(Mandatory)][string]$Status,
        [hashtable]$Fields = @{}
    )

    $result = [ordered]@{
        schemaVersion = 1
        status = $Status
        platform = 'windows'
        architecture = Get-PlatformArchitecture
    }
    foreach ($entry in $Fields.GetEnumerator()) {
        $result[$entry.Key] = $entry.Value
    }

    if ($Json) {
        $result | ConvertTo-Json -Compress -Depth 6
    }
    else {
        $parts = @($Status)
        foreach ($entry in $Fields.GetEnumerator()) {
            $parts += "$($entry.Key)=$($entry.Value)"
        }
        $parts -join ' '
    }
}

function Get-PlatformArchitecture {
    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    switch ($architecture) {
        'X64' { 'amd64' }
        'Arm64' { 'arm64' }
        default { throw "Unsupported Windows architecture: $architecture" }
    }
}

function Read-ReleaseManifest {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw 'Release manifest is missing.'
    }
    Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

function Get-PinnedAsset {
    param([Parameter(Mandatory)]$Manifest)

    $architecture = Get-PlatformArchitecture
    $assets = @($Manifest.assets | Where-Object {
        $_.os -eq 'windows' -and $_.arch -eq $architecture
    })
    if ($assets.Count -ne 1) {
        throw "Expected one pinned Windows/$architecture asset."
    }

    $asset = $assets[0]
    $expectedName = "tg_$($Manifest.upstream.version)_windows_$architecture.tar.gz"
    $expectedUrl = "https://github.com/gotd/cli/releases/download/$($Manifest.upstream.tag)/$expectedName"
    if ($asset.name -ne $expectedName) {
        throw 'Pinned asset name is unexpected.'
    }
    if ($asset.url -ne $expectedUrl) {
        throw 'Pinned asset URL is not the approved gotd/cli GitHub release URL.'
    }
    if ($asset.sha256 -notmatch '^[a-f0-9]{64}$') {
        throw 'Pinned SHA-256 is malformed.'
    }
    if ($asset.githubDigest -ne "sha256:$($asset.sha256)") {
        throw 'Pinned GitHub digest does not match SHA-256.'
    }
    $asset
}

function Resolve-TgExecutable {
    $fromPath = Get-Command tg.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($fromPath) {
        return $fromPath.Source
    }
    if (Test-Path -LiteralPath $ManagedPath -PathType Leaf) {
        return $ManagedPath
    }
    $null
}

function Get-InstalledVersion {
    if (-not (Test-Path -LiteralPath $InstallStatePath -PathType Leaf)) {
        return ''
    }
    try {
        $state = Get-Content -LiteralPath $InstallStatePath -Raw | ConvertFrom-Json
        [string]$state.version
    }
    catch {
        ''
    }
}

function Invoke-TgDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination
    )
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
}

function Get-ArchiveSha256 {
    param([Parameter(Mandatory)][string]$Archive)
    (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ArchiveEntryData {
    param([Parameter(Mandatory)][string]$Archive)

    $entries = @(& tar.exe -tzf $Archive)
    if ($LASTEXITCODE -ne 0) {
        throw 'Archive listing failed.'
    }
    $details = @(& tar.exe -tvzf $Archive)
    if ($LASTEXITCODE -ne 0) {
        throw 'Archive metadata listing failed.'
    }
    @{ Entries = $entries; Details = $details }
}

function Assert-SafeArchive {
    param([Parameter(Mandatory)][hashtable]$ArchiveData)

    $counts = @{ 'LICENSE' = 0; 'README.md' = 0; 'tg.exe' = 0 }
    foreach ($rawEntry in @($ArchiveData.Entries)) {
        $entry = [string]$rawEntry
        if ([string]::IsNullOrWhiteSpace($entry)) {
            throw 'Archive contains an empty path.'
        }
        if ($entry.StartsWith('/') -or $entry.StartsWith('\') -or $entry -match '^[A-Za-z]:') {
            throw 'Archive contains an absolute path.'
        }
        if ($entry.Contains('\')) {
            throw 'Archive contains a backslash path.'
        }
        if (@($entry.Split('/')) -contains '..') {
            throw 'Archive contains parent traversal.'
        }
        if (-not $counts.ContainsKey($entry)) {
            throw "Archive contains an unexpected entry: $entry"
        }
        $counts[$entry]++
    }

    if ($counts['LICENSE'] -ne 1 -or $counts['README.md'] -ne 1) {
        throw 'Archive metadata files are incomplete.'
    }
    if ($counts['tg.exe'] -ne 1) {
        throw 'Archive must contain exactly one tg.exe executable.'
    }

    foreach ($rawDetail in @($ArchiveData.Details)) {
        $detail = [string]$rawDetail
        if ($detail -match '^[lh]' -or $detail -match ' link to ') {
            throw 'Archive symbolic links and hard links are not allowed.'
        }
    }
}

function Expand-TgArchive {
    param(
        [Parameter(Mandatory)][string]$Archive,
        [Parameter(Mandatory)][string]$Destination
    )
    & tar.exe -xzf $Archive -C $Destination
    if ($LASTEXITCODE -ne 0) {
        throw 'Archive extraction failed.'
    }
}

function Invoke-SmokeChecks {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)]$Manifest
    )
    foreach ($check in @($Manifest.smokeCommands)) {
        $arguments = @($check.args | ForEach-Object { [string]$_ })
        & $Executable @arguments *> $null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }
    $true
}

function Rollback-Replacement {
    param([Parameter(Mandatory)][bool]$HadPrevious)

    if (Test-Path -LiteralPath $ManagedPath) {
        Remove-Item -LiteralPath $ManagedPath -Force
    }
    if ($HadPrevious -and (Test-Path -LiteralPath $BackupPath)) {
        Move-Item -LiteralPath $BackupPath -Destination $ManagedPath
    }
}

function Write-InstallState {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)]$Asset
    )

    New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
    $state = [ordered]@{
        schemaVersion = 1
        version = [string]$Manifest.upstream.version
        tag = [string]$Manifest.upstream.tag
        asset = [string]$Asset.name
        archiveSha256 = [string]$Asset.sha256
        installedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        executable = $ManagedPath
    }
    $state | ConvertTo-Json -Compress | Set-Content -LiteralPath $StateTempPath -Encoding UTF8
    Move-Item -LiteralPath $StateTempPath -Destination $InstallStatePath -Force
}

function Install-Pinned {
    param([Parameter(Mandatory)][string]$SuccessStatus)

    $manifest = Read-ReleaseManifest
    $asset = Get-PinnedAsset -Manifest $manifest
    if (Test-Path -LiteralPath $BackupPath) {
        throw 'Refusing replacement because a stale backup exists.'
    }
    if (Test-Path -LiteralPath $NewPath) {
        throw 'Refusing replacement because a stale temporary executable exists.'
    }

    $work = Join-Path ([System.IO.Path]::GetTempPath()) "tg-agent-plugin.$([guid]::NewGuid().ToString('N'))"
    $extract = Join-Path $work 'extract'
    $archive = Join-Path $work ([string]$asset.name)
    $hadPrevious = $false
    $replacementActive = $false

    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    try {
        Invoke-TgDownload -Uri ([string]$asset.url) -Destination $archive
        $actualSha = Get-ArchiveSha256 -Archive $archive
        if ($actualSha -ne [string]$asset.sha256) {
            throw 'Checksum mismatch for pinned gotd/cli archive.'
        }

        $archiveData = Get-ArchiveEntryData -Archive $archive
        Assert-SafeArchive -ArchiveData $archiveData
        Expand-TgArchive -Archive $archive -Destination $extract
        $candidate = Join-Path $extract 'tg.exe'
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw 'Extracted tg.exe candidate is not a regular file.'
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $ManagedPath) -Force | Out-Null
        Copy-Item -LiteralPath $candidate -Destination $NewPath
        if (Test-Path -LiteralPath $ManagedPath) {
            Move-Item -LiteralPath $ManagedPath -Destination $BackupPath
            $hadPrevious = $true
        }
        $replacementActive = $true
        Move-Item -LiteralPath $NewPath -Destination $ManagedPath

        if (-not (Invoke-SmokeChecks -Executable $ManagedPath -Manifest $manifest)) {
            throw 'Smoke check failed.'
        }
        Write-InstallState -Manifest $manifest -Asset $asset

        $replacementActive = $false
        if ($hadPrevious -and (Test-Path -LiteralPath $BackupPath)) {
            Remove-Item -LiteralPath $BackupPath -Force
        }
        Write-Result -Status $SuccessStatus -Fields @{
            version = [string]$manifest.upstream.version
            tag = [string]$manifest.upstream.tag
            asset = [string]$asset.name
            path = $ManagedPath
        }
    }
    catch {
        if ($replacementActive) {
            Rollback-Replacement -HadPrevious $hadPrevious
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $NewPath) {
            Remove-Item -LiteralPath $NewPath -Force
        }
        if (Test-Path -LiteralPath $StateTempPath) {
            Remove-Item -LiteralPath $StateTempPath -Force
        }
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force
        }
    }
}

function Get-LatestReleaseUrl {
    $response = Invoke-WebRequest -Uri 'https://github.com/gotd/cli/releases/latest' `
        -MaximumRedirection 10 -UseBasicParsing
    if ($response.BaseResponse.RequestMessage.RequestUri) {
        return $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
    }
    $response.BaseResponse.ResponseUri.AbsoluteUri
}

function Check-Update {
    $manifest = Read-ReleaseManifest
    $latestUrl = Get-LatestReleaseUrl
    if ($latestUrl -notmatch '^https://github\.com/gotd/cli/releases/tag/v[0-9]+\.[0-9]+\.[0-9]+$') {
        throw 'Latest release response is not an approved gotd/cli GitHub tag URL.'
    }
    $latestTag = Split-Path -Leaf $latestUrl
    $status = if ($latestTag -eq [string]$manifest.upstream.tag) {
        'pinned-current'
    }
    else {
        'newer-unpinned'
    }
    Write-Result -Status $status -Fields @{
        pinnedVersion = [string]$manifest.upstream.version
        pinnedTag = [string]$manifest.upstream.tag
        latestTag = $latestTag
        releaseUrl = $latestUrl
    }
}

function Test-TgAuthorization {
    param([Parameter(Mandatory)][string]$Executable)
    & $Executable whoami -o json *> $null
    $LASTEXITCODE -eq 0
}

function Start-TgAuthorization {
    $resolved = Resolve-TgExecutable
    if (-not $resolved) {
        return Write-Result -Status 'missing' -Fields @{ path = $ManagedPath }
    }
    if (Test-TgAuthorization -Executable $resolved) {
        return Write-Result -Status 'already-authorized' -Fields @{ path = $resolved }
    }

    $launcher = Join-Path $ScriptRoot 'tg-login-windows.ps1'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
        throw 'Authorization launcher is unavailable.'
    }
    & $launcher -TgPath $resolved -Mode $Mode | Out-Null
    Write-Result -Status 'login-started' -Fields @{ mode = $Mode }
}

function Confirm-TgAuthorization {
    $resolved = Resolve-TgExecutable
    if (-not $resolved) {
        return Write-Result -Status 'missing' -Fields @{ path = $ManagedPath }
    }
    if (Test-TgAuthorization -Executable $resolved) {
        Write-Result -Status 'authorized' -Fields @{ path = $resolved }
    }
    else {
        Write-Result -Status 'not-authorized' -Fields @{ path = $resolved }
    }
}

if ($LibraryOnly) {
    return
}

switch ($Action) {
    'status' {
        $resolved = Resolve-TgExecutable
        if ($resolved) {
            Write-Result -Status 'ready' -Fields @{
                path = $resolved
                version = Get-InstalledVersion
            }
        }
        else {
            Write-Result -Status 'missing' -Fields @{ path = $ManagedPath }
        }
    }
    'install' { Install-Pinned -SuccessStatus 'installed' }
    'repair' { Install-Pinned -SuccessStatus 'repaired' }
    'check-update' { Check-Update }
    'authorize' { Start-TgAuthorization }
    'verify-authorization' { Confirm-TgAuthorization }
}
