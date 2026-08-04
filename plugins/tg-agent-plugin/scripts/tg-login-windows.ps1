[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TgPath,
    [ValidateSet('phone', 'qr')][string]$Mode = 'phone',
    [switch]$Worker,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

function Complete-LoginWindow {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][int]$Code
    )

    Write-Host ''
    Write-Host $Message
    if (-not $NoPause) {
        [void](Read-Host 'Press Enter to close this window')
    }
    exit $Code
}

if (-not (Test-Path -LiteralPath $TgPath -PathType Leaf)) {
    throw 'The local tg executable was not found.'
}

Remove-Item Env:TG_PASSWORD -ErrorAction SilentlyContinue
Remove-Item Env:APP_ID -ErrorAction SilentlyContinue
Remove-Item Env:APP_HASH -ErrorAction SilentlyContinue
Remove-Item Env:BOT_TOKEN -ErrorAction SilentlyContinue

if (-not $Worker) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $powerShellPath = (Get-Process -Id $PID).Path
    $arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy', 'RemoteSigned',
        '-File', $scriptPath,
        '-Worker',
        '-TgPath', $TgPath,
        '-Mode', $Mode
    )
    Start-Process -FilePath $powerShellPath -ArgumentList $arguments | Out-Null
    [pscustomobject]@{ schemaVersion = 1; status = 'login-started'; mode = $Mode } |
        ConvertTo-Json -Compress
    exit 0
}

try {
    Write-Host 'Secure local Telegram login'
    Write-Host 'Enter every credential only in this local window.'
    Write-Host 'Never send a phone number, code, QR token, or 2FA password to the agent.'
    Write-Host ''

    if (-not $env:APPDATA) {
        throw 'APPDATA is unavailable, so the gotd/cli config path cannot be resolved.'
    }
    $configPath = Join-Path $env:APPDATA 'gotd\gotd.cli.yaml'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        & $TgPath init
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to initialize the local gotd/cli configuration.'
        }
    }

    if ($Mode -eq 'phone') {
        Write-Host 'Enter the phone number, Telegram code, and 2FA password when prompted.'
        & $TgPath login '--phone='
    }
    else {
        Write-Host 'In Telegram, open Settings, Devices, then Link Desktop Device.'
        & $TgPath login
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Login did not complete.'
    }

    Complete-LoginWindow `
        -Message 'Login completed. Return to the agent and report that you are ready.' `
        -Code 0
}
catch {
    Complete-LoginWindow -Message $_.Exception.Message -Code 1
}
