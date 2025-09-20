param(
  [string]$RepositoryName = "ecr_kareem_repo",
  [string]$Region = "us-east-1",
  [string]$LocalImage = "hello-python:latest",
  [switch]$Build,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red; exit 1 }

# Try to locate the AWS CLI even if PATH isn't refreshed (common after install in new terminals)
function Resolve-AwsCli {
  $cmd = Get-Command aws -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $defaultPath = "C:\\Program Files\\Amazon\\AWSCLIV2\\aws.exe"
  if (Test-Path $defaultPath) { return $defaultPath }
  return $null
}

# Optionally build the image
if ($Build) {
  Info "Building local image $LocalImage"
  docker build -t $LocalImage . | Out-Host
}

# Verify local image exists
try {
  $null = docker image inspect $LocalImage 2>$null
} catch {
  Die "Local image '$LocalImage' not found. Run with -Build or build it first."
}

# Dry-run should not require AWS at all
if ($DryRun) {
  $AWS = Resolve-AwsCli
  $AccountId = $null
  if ($AWS) {
    try { $AccountId = (& $AWS sts get-caller-identity --query Account --output text) } catch { $AccountId = $null }
  }
  $registryPreview = if ($AccountId) { "$AccountId.dkr.ecr.$Region.amazonaws.com" } else { "<account>.dkr.ecr.$Region.amazonaws.com" }
  $remotePreview = "$registryPreview/$($RepositoryName):latest"

  Info "Dry run: would perform the following"
  Info " - Login to: $registryPreview"
  Info " - Tag: $LocalImage -> $remotePreview"
  Info " - Push: $remotePreview"
  exit 0
}

# Determine account and registry (requires AWS CLI)
$AWS = Resolve-AwsCli
if (-not $AWS) { Die "AWS CLI not found. Install AWS CLI v2 or open a new terminal. Typical path: C:\\Program Files\\Amazon\\AWSCLIV2\\aws.exe" }

$AccountId = (& $AWS sts get-caller-identity --query Account --output text)
if (-not $AccountId) { Die "AWS CLI not authenticated. Run 'aws configure' or 'aws configure sso'." }
$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$Remote = "$Registry/$($RepositoryName):latest"

Info "Account: $AccountId"
Info "Region:  $Region"
Info "Repo:    $RepositoryName"
Info "Local:   $LocalImage"
Info "Remote:  $Remote"

# Ensure repo exists
$repoExists = $true
try {
  $null = & $AWS ecr describe-repositories --repository-names $RepositoryName --region $Region 2>$null
} catch { $repoExists = $false }

if (-not $repoExists) {
  Info "Creating ECR repository $RepositoryName in $Region"
  & $AWS ecr create-repository --repository-name $RepositoryName --region $Region `
    --image-scanning-configuration scanOnPush=true `
    --encryption-configuration encryptionType=AES256 | Out-Host
}

# Login to ECR
Info "Logging in to ECR registry $Registry"
& $AWS ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry | Out-Host

# Tag and push
Info "Tagging $LocalImage -> $Remote"
docker tag $LocalImage $Remote | Out-Host

Info "Pushing $Remote"
docker push $Remote | Out-Host

Info "Done"
