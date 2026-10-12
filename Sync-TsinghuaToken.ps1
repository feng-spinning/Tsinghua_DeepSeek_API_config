<#
.SYNOPSIS
    Copy a Tsinghua DeepSeek token from a text file into the DSH credential store.

.DESCRIPTION
    The DSH profile refers to this credential by the name
    TSINGHUA_DEEPSEEK_API_KEY. This script reads the token from a plain text
    file and writes it to the DSH credential store. The store keeps all other
    credential entries.

    The script does not print the token. It prints the token length, the
    expiry time, and a short fingerprint instead.

.PARAMETER TokenFile
    Path of the text file that holds the token. The file must contain one line.
    The default is 'tsinghua_token.txt' next to this script.

.PARAMETER CredentialFile
    Path of the DSH credential store.
    The default is '%USERPROFILE%\.dsh\.credentials.yaml' on Windows and
    '~/.dsh/.credentials.yaml' on other systems. Set DSH_HOME to change the
    harness home.

.PARAMETER Ref
    Credential reference name. The default is TSINGHUA_DEEPSEEK_API_KEY.
    This value must agree with apiKeyEnv in cordis.patch.yml.

.PARAMETER DryRun
    Check the token and the credential store, but do not write.

.EXAMPLE
    .\Sync-TsinghuaToken.ps1 -DryRun

.EXAMPLE
    .\Sync-TsinghuaToken.ps1

.EXAMPLE
    .\Sync-TsinghuaToken.ps1 -TokenFile D:\tokens\tsinghua_token.txt
#>
[CmdletBinding()]
param(
    [string]$TokenFile,
    [string]$CredentialFile,
    [string]$Ref = 'TSINGHUA_DEEPSEEK_API_KEY',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-HarnessHome {
    if ($env:DSH_HOME) { return $env:DSH_HOME }
    $homeDir = [Environment]::GetFolderPath('UserProfile')
    if (-not $homeDir) { $homeDir = $env:HOME }
    return (Join-Path $homeDir '.dsh')
}

function Get-TextFileUtf8NoBom {
    param([string]$Path)
    # Read as UTF-8. Accept a BOM if the file has one.
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Write-TextFileUtf8NoBom {
    param([string]$Path, [string]$Text)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8.GetBytes($Text)
    $stream = [System.IO.File]::Create($Path)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $stream.Dispose()
    }
}

function Get-JwtExpiry {
    param([string]$Token)
    $parts = $Token.Split('.')
    if ($parts.Count -ne 3) {
        throw "The token does not have 3 dot-separated parts. Copy the token again."
    }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
    }
    $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
    $data = $json | ConvertFrom-Json
    if (-not $data.exp) {
        throw "The token has no 'exp' field. This is not a Tsinghua login token."
    }
    return [DateTimeOffset]::FromUnixTimeSeconds([long]$data.exp)
}

function Get-Fingerprint {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $sha.Dispose()
    }
    return ([System.BitConverter]::ToString($hash) -replace '-', '').Substring(0, 12)
}

# --- Resolve the paths -------------------------------------------------------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

if (-not $TokenFile) {
    $TokenFile = Join-Path $scriptDir 'tsinghua_token.txt'
}
elseif (-not [System.IO.Path]::IsPathRooted($TokenFile)) {
    # A relative path is relative to this script, not to the current directory.
    $TokenFile = Join-Path $scriptDir $TokenFile
}

if (-not $CredentialFile) {
    $CredentialFile = Join-Path (Get-HarnessHome) '.credentials.yaml'
}
elseif (-not [System.IO.Path]::IsPathRooted($CredentialFile)) {
    $CredentialFile = Join-Path $scriptDir $CredentialFile
}

if (-not (Test-Path -LiteralPath $TokenFile)) {
    throw "Token file not found: $TokenFile"
}
if (-not (Test-Path -LiteralPath $CredentialFile)) {
    throw "Credential store not found: $CredentialFile  (Start DSH Desktop one time first.)"
}

# --- Read and check the token ------------------------------------------------
$token = (Get-TextFileUtf8NoBom -Path $TokenFile).Trim()
$token = $token.Trim('"').Trim("'")
$token = $token -replace '\s', ''
# Accept a copy that includes the Authorization scheme prefix.
$token = $token -replace '^(?i)Bearer[:]?', ''

$parts = $token.Split('.')
if ($parts.Count -ne 3) {
    throw "The token does not have 3 dot-separated parts. It has $($parts.Count). Copy the token again."
}
if ($token.Length -lt 40) {
    throw "The token is too short ($($token.Length) characters). The file must contain the full token on one line."
}
if ($token -match '[^A-Za-z0-9_\-\.]') {
    throw "The token has an invalid character. The token must contain only letters, digits, '-', '_' and '.'."
}

$expiry = Get-JwtExpiry -Token $token
$now = [DateTimeOffset]::UtcNow
$minutesLeft = [math]::Round(($expiry - $now).TotalMinutes, 0)
$fingerprint = Get-Fingerprint -Text $token

Write-Host "Token file      : $TokenFile"
Write-Host "Token length    : $($token.Length) characters"
Write-Host "Token fingerprint: $fingerprint"
Write-Host "Expiry (UTC)    : $($expiry.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
Write-Host "Time left       : $minutesLeft minutes"

if ($expiry -le $now) {
    Write-Warning "This token is already expired. Get a new token, then run this script again."
}
# --- Write the credential store ----------------------------------------------
$doc = Get-TextFileUtf8NoBom -Path $CredentialFile

if ($doc -notmatch '(?m)^refs:\s*$') {
    throw "The credential store has no 'refs:' section. Check the file: $CredentialFile"
}
if ($doc -notmatch ('(?m)^\s+' + [regex]::Escape($Ref) + ':')) {
    Write-Warning "The store has no '$Ref' entry yet. This script will add it."
}

$pattern = '(?m)^(\s+' + [regex]::Escape($Ref) + ':\s*).*$'
$replacement = '${1}' + $token
$newDoc = [regex]::Replace($doc, $pattern, $replacement)

if ($newDoc -eq $doc) {
    if ($doc -match $pattern) {
        Write-Host "The store already holds this exact token. No change."
        return
    }
    # No entry yet: insert one directly below the 'refs:' line.
    $newDoc = [regex]::Replace($doc, '(?m)^refs:\s*$', "refs:`n  ${Ref}: $token", 1)
}

if ($DryRun) {
    Write-Host "Dry run. The script did not write the credential store."
    return
}

$backup = "$CredentialFile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $CredentialFile -Destination $backup -Force
Write-Host "Backup written  : $backup"

Write-TextFileUtf8NoBom -Path $CredentialFile -Text $newDoc

# Restrict the store to the current user where the platform supports it.
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    try {
        $acl = Get-Acl -LiteralPath $CredentialFile
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            'FullControl', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $CredentialFile -AclObject $acl
    }
    catch {
        Write-Warning "Could not restrict the file permissions: $($_.Exception.Message)"
    }
}

# --- Verify ------------------------------------------------------------------
$check = Get-TextFileUtf8NoBom -Path $CredentialFile
if ($check -notmatch ('(?m)^\s+' + [regex]::Escape($Ref) + ':')) {
    throw "Verification failed: the store has no '$Ref' entry after the write."
}
$saved = ([regex]::Match($check, $pattern)).Groups[0].Value
$saved = ($saved -split ':', 2)[1].Trim()

if ($saved -ne $token) {
    throw "Verification failed: the stored value is not the token from the file."
}
if ($check -notmatch '(?m)^refs:\s*$') {
    throw "Verification failed: the 'refs:' section is damaged."
}

Write-Host "Result          : OK. The store now holds '$Ref' ($($saved.Length) characters, fingerprint $fingerprint)."
Write-Host "Next step       : DSH reloads credential changes automatically. No restart is necessary."
