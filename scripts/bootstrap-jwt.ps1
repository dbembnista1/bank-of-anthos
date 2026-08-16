#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot bootstrap: generate Bank of Anthos JWT RS256 keypair and store in AWS Secrets Manager.

.DESCRIPTION
  Mirrors upstream BoA (openssl + key files) but writes to Secrets Manager instead of
  kubectl create secret. External Secrets Operator later syncs into Kubernetes Secret jwt-key.

  Run after terraform apply (platform up). Safe to re-run: skips if the secret already
  has ESO-compatible keys (private_key / public_key) unless -ForceRotate is set.
  Rewrites automatically if the payload still uses dotted keys (jwtRS256.key*), which
  External Secrets treats as a gjson path and cannot extract. Does not commit PEM files.

.PARAMETER SecretName
  Secrets Manager secret name (default: bank-of-anthos-jwt).

.PARAMETER Region
  AWS region (default: eu-central-1).

.PARAMETER ForceRotate
  Replace the secret value even if one already exists (breaks existing JWT sessions).

.EXAMPLE
  .\scripts\bootstrap-jwt.ps1

.EXAMPLE
  .\scripts\bootstrap-jwt.ps1 -ForceRotate
#>
param(
    [string]$SecretName = "bank-of-anthos-jwt",
    [string]$Region = "eu-central-1",
    [switch]$ForceRotate
)

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# AWS CLI / openssl write to stderr for non-fatal cases; with ErrorActionPreference=Stop
# PowerShell turns that into a terminating NativeCommandError. Run natives under Continue.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

foreach ($cmd in @("openssl", "aws")) {
    if (-not (Test-CommandExists $cmd)) {
        throw "Required command not found: $cmd. Install OpenSSL (e.g. Git for Windows) and AWS CLI v2."
    }
}

function Test-JwtPayloadHasEsoKeys {
    param([string]$SecretString)
    if ([string]::IsNullOrWhiteSpace($SecretString)) { return $false }
    try {
        $obj = $SecretString | ConvertFrom-Json
        return -not [string]::IsNullOrWhiteSpace($obj.private_key) -and
            -not [string]::IsNullOrWhiteSpace($obj.public_key)
    }
    catch {
        return $false
    }
}

function Get-PemLf {
    param([Parameter(Mandatory = $true)][string]$Path)
    $raw = Get-Content -Raw -Path $Path
    return (($raw -replace "`r`n", "`n" -replace "`r", "`n").Trim() + "`n")
}

# Skip when secret already has ESO-compatible keys (idempotent lab setup).
$secretExists = $false
$hasValue = $false
$hasEsoKeys = $false

$describeExit = Invoke-Native {
    aws secretsmanager describe-secret --secret-id $SecretName --region $Region 2>$null | Out-Null
}
if ($describeExit -eq 0) {
    $secretExists = $true
    $metaJson = $null
    $metaExit = Invoke-Native {
        $script:metaJson = aws secretsmanager describe-secret --secret-id $SecretName --region $Region --output json
    }
    if ($metaExit -ne 0 -or [string]::IsNullOrWhiteSpace($metaJson)) {
        throw "describe-secret succeeded once then failed for '$SecretName'."
    }
    $meta = $metaJson | ConvertFrom-Json
    if ($null -ne $meta.VersionIdsToStages -and $meta.VersionIdsToStages.PSObject.Properties.Count -gt 0) {
        $hasValue = $true
        $secretString = $null
        $getExit = Invoke-Native {
            $script:secretString = aws secretsmanager get-secret-value --secret-id $SecretName --region $Region --query SecretString --output text
        }
        if ($getExit -eq 0) {
            $hasEsoKeys = Test-JwtPayloadHasEsoKeys -SecretString $secretString
        }
    }
}

if ($hasValue -and $hasEsoKeys -and -not $ForceRotate) {
    Write-Host "Secret '$SecretName' already has private_key/public_key. Skipping (use -ForceRotate)."
    exit 0
}

if ($hasValue -and -not $hasEsoKeys -and -not $ForceRotate) {
    Write-Host "Secret '$SecretName' uses dotted JSON keys that External Secrets cannot extract. Rewriting as private_key/public_key."
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("boa-jwt-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
    $keyPath = Join-Path $workDir "jwtRS256.key"
    $pubPath = Join-Path $workDir "jwtRS256.key.pub"
    $jsonPath = Join-Path $workDir "secret.json"

    $genExit = Invoke-Native { openssl genrsa -out $keyPath 4096 }
    if ($genExit -ne 0) { throw "openssl genrsa failed (exit $genExit)" }

    $pubExit = Invoke-Native { openssl rsa -in $keyPath -outform PEM -pubout -out $pubPath }
    if ($pubExit -ne 0) { throw "openssl rsa -pubout failed (exit $pubExit)" }

    # JSON field names must not contain dots: External Secrets treats property as a
    # gjson path, so jwtRS256.key.pub would write the whole JSON blob into K8s.
    # ExternalSecret maps these onto Secret keys jwtRS256.key / jwtRS256.key.pub.
    $payload = [ordered]@{
        private_key = Get-PemLf -Path $keyPath
        public_key  = Get-PemLf -Path $pubPath
    }
    $json = $payload | ConvertTo-Json -Compress -Depth 5
    # Avoid UTF-8 BOM (Windows PowerShell 5.1 Set-Content -Encoding utf8 adds BOM; breaks AWS CLI).
    [System.IO.File]::WriteAllText($jsonPath, $json)

    # AWS CLI on Windows accepts file:// with a forward-slash absolute path.
    $fileUri = "file://" + ($jsonPath -replace "\\", "/")

    if (-not $secretExists) {
        $createExit = Invoke-Native {
            aws secretsmanager create-secret `
                --name $SecretName `
                --description "Bank of Anthos JWT RS256 keypair (synced to K8s via External Secrets)" `
                --secret-string $fileUri `
                --region $Region | Out-Null
        }
        if ($createExit -ne 0) { throw "create-secret failed (exit $createExit)" }
        Write-Host "Created Secrets Manager secret: $SecretName"
    }
    else {
        $putExit = Invoke-Native {
            aws secretsmanager put-secret-value `
                --secret-id $SecretName `
                --secret-string $fileUri `
                --region $Region | Out-Null
        }
        if ($putExit -ne 0) { throw "put-secret-value failed (exit $putExit)" }
        Write-Host "Updated Secrets Manager secret: $SecretName"
    }

    $arn = $null
    $arnExit = Invoke-Native {
        $script:arn = aws secretsmanager describe-secret --secret-id $SecretName --region $Region --query ARN --output text
    }
    if ($arnExit -ne 0) { throw "failed to read secret ARN (exit $arnExit)" }

    Write-Host "ARN: $arn"
    Write-Host "Local PEM files removed with temp dir. Next: External Secrets syncs this into jwt-key."
}
finally {
    if (Test-Path $workDir) {
        Remove-Item -Recurse -Force $workDir
    }
}
