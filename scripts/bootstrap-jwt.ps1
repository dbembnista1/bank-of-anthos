#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot bootstrap: generate Bank of Anthos JWT RS256 keypair and store in AWS Secrets Manager.

.DESCRIPTION
  Mirrors upstream BoA (openssl + key files) but writes to Secrets Manager instead of
  kubectl create secret. External Secrets Operator later syncs into Kubernetes Secret jwt-key.

  Run after terraform apply (platform up). Safe to re-run: skips if the secret already
  has a value unless -ForceRotate is set. Does not commit PEM files to the repo.

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

# Skip when secret already has a current version (idempotent lab setup).
$secretExists = $false
$hasValue = $false

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
    }
}

if ($hasValue -and -not $ForceRotate) {
    Write-Host "Secret '$SecretName' already has a value. Skipping (use -ForceRotate)."
    exit 0
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

    # Keys must match the umbrella chart Kubernetes Secret jwt-key.
    $payload = [ordered]@{
        "jwtRS256.key"     = (Get-Content -Raw -Path $keyPath)
        "jwtRS256.key.pub" = (Get-Content -Raw -Path $pubPath)
    }
    $json = $payload | ConvertTo-Json -Compress
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
