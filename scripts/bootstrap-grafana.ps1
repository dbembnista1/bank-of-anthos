#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot bootstrap: generate a Grafana admin password and store it in AWS Secrets Manager.

.DESCRIPTION
  Analogous to scripts/bootstrap-jwt.ps1. Writes JSON keys admin_user / admin_password
  (no dots — External Secrets treats property as a gjson path). ESO syncs into the
  Kubernetes Secret grafana-admin that kube-prometheus-stack mounts via existingSecret.

  Run after terraform apply (ESO IRSA must include this secret ARN). Safe to re-run:
  skips if the secret already has admin_user / admin_password unless -ForceRotate is set.
  Does not print the password.

.PARAMETER SecretName
  Secrets Manager secret name (default: bank-of-anthos-grafana-admin). Must match
  gitops/platform/monitoring grafanaAdmin.remoteKey and var.grafana_admin_secret_name.

.PARAMETER Region
  AWS region (default: eu-central-1).

.PARAMETER AdminUser
  Grafana admin username stored as admin_user (default: admin).

.PARAMETER ForceRotate
  Replace the secret value even if one already exists (Grafana login changes after ESO refresh).

.EXAMPLE
  .\scripts\bootstrap-grafana.ps1

.EXAMPLE
  .\scripts\bootstrap-grafana.ps1 -ForceRotate
#>
param(
    [string]$SecretName = "bank-of-anthos-grafana-admin",
    [string]$Region = "eu-central-1",
    [string]$AdminUser = "admin",
    [switch]$ForceRotate
)

$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# AWS CLI writes to stderr for non-fatal cases; with ErrorActionPreference=Stop
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

function Test-GrafanaPayloadHasEsoKeys {
    param([string]$SecretString)
    if ([string]::IsNullOrWhiteSpace($SecretString)) { return $false }
    try {
        $obj = $SecretString | ConvertFrom-Json
        return -not [string]::IsNullOrWhiteSpace($obj.admin_user) -and
            -not [string]::IsNullOrWhiteSpace($obj.admin_password)
    }
    catch {
        return $false
    }
}

function New-GrafanaAdminPassword {
    # 32 alphanumeric chars — copy-paste friendly in the Grafana UI.
    $alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }
    $chars = for ($i = 0; $i -lt $bytes.Length; $i++) {
        $alphabet[$bytes[$i] % $alphabet.Length]
    }
    return -join $chars
}

if (-not (Test-CommandExists "aws")) {
    throw "Required command not found: aws. Install AWS CLI v2."
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
            $hasEsoKeys = Test-GrafanaPayloadHasEsoKeys -SecretString $secretString
        }
    }
}

if ($hasValue -and $hasEsoKeys -and -not $ForceRotate) {
    Write-Host "Secret '$SecretName' already has admin_user/admin_password. Skipping (use -ForceRotate)."
    exit 0
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("boa-grafana-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
    $jsonPath = Join-Path $workDir "secret.json"
    $payload = [ordered]@{
        admin_user     = $AdminUser
        admin_password = New-GrafanaAdminPassword
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
                --description "Bank of Anthos Grafana admin credentials (synced to K8s via External Secrets)" `
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
    Write-Host "Password is only in Secrets Manager (not printed). Next: External Secrets syncs this into grafana-admin."
}
finally {
    if (Test-Path $workDir) {
        Remove-Item -Recurse -Force $workDir
    }
}
