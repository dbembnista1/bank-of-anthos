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

foreach ($cmd in @("openssl", "aws")) {
    if (-not (Test-CommandExists $cmd)) {
        throw "Required command not found: $cmd. Install OpenSSL (e.g. Git for Windows) and AWS CLI v2."
    }
}

# Skip when secret already has a current version (idempotent lab setup).
$secretExists = $false
$hasValue = $false
aws secretsmanager describe-secret --secret-id $SecretName --region $Region 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    $secretExists = $true
    $meta = aws secretsmanager describe-secret --secret-id $SecretName --region $Region --output json | ConvertFrom-Json
    if ($null -ne $meta.VersionIdsToStages -and $meta.VersionIdsToStages.PSObject.Properties.Count -gt 0) {
        $hasValue = $true
    }
}

if ($hasValue -and -not $ForceRotate) {
    Write-Host "Secret '$SecretName' already has a value. Skipping (use -ForceRotate to replace)."
    exit 0
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("boa-jwt-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
    $keyPath = Join-Path $workDir "jwtRS256.key"
    $pubPath = Join-Path $workDir "jwtRS256.key.pub"
    $jsonPath = Join-Path $workDir "secret.json"

    & openssl genrsa -out $keyPath 4096
    if ($LASTEXITCODE -ne 0) { throw "openssl genrsa failed" }

    & openssl rsa -in $keyPath -outform PEM -pubout -out $pubPath
    if ($LASTEXITCODE -ne 0) { throw "openssl rsa -pubout failed" }

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
        aws secretsmanager create-secret `
            --name $SecretName `
            --description "Bank of Anthos JWT RS256 keypair (synced to K8s via External Secrets)" `
            --secret-string $fileUri `
            --region $Region | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "create-secret failed" }
        Write-Host "Created Secrets Manager secret: $SecretName"
    }
    else {
        aws secretsmanager put-secret-value `
            --secret-id $SecretName `
            --secret-string $fileUri `
            --region $Region | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "put-secret-value failed" }
        Write-Host "Updated Secrets Manager secret: $SecretName"
    }

    $arn = aws secretsmanager describe-secret --secret-id $SecretName --region $Region --query ARN --output text
    Write-Host "ARN: $arn"
    Write-Host "Local PEM files removed with temp dir. Next: External Secrets syncs this into jwt-key."
}
finally {
    if (Test-Path $workDir) {
        Remove-Item -Recurse -Force $workDir
    }
}
