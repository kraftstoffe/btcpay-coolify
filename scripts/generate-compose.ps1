$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendorDir = Join-Path $repoRoot "vendor\btcpayserver-docker"
$repoUrl = "https://github.com/btcpayserver/btcpayserver-docker.git"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is required to generate the compose file. Install Docker Desktop and retry."
}

if (-not (Test-Path $vendorDir)) {
    Write-Host "Cloning btcpayserver-docker..."
    New-Item -ItemType Directory -Path (Join-Path $repoRoot "vendor") -Force | Out-Null
    git clone --depth 1 $repoUrl $vendorDir
} else {
    Write-Host "Updating btcpayserver-docker..."
    Push-Location $vendorDir
    git pull --ff-only
    Pop-Location
}

$env:BTCPAY_HOST = if ($env:BTCPAY_HOST) { $env:BTCPAY_HOST } else { "btcpay.example.com" }
$env:NBITCOIN_NETWORK = "mainnet"
$env:BTCPAYGEN_CRYPTO1 = "btc"
$env:BTCPAYGEN_REVERSEPROXY = "none"
$env:BTCPAY_PROTOCOL = "http"
$env:BTCPAYGEN_LIGHTNING = ""
$env:BTCPAYGEN_ADDITIONAL_FRAGMENTS = "opt-save-storage-s"

Write-Host "Generating docker-compose with:"
Write-Host "  BTCPAY_HOST=$($env:BTCPAY_HOST)"
Write-Host "  NBITCOIN_NETWORK=$($env:NBITCOIN_NETWORK)"
Write-Host "  BTCPAYGEN_REVERSEPROXY=$($env:BTCPAYGEN_REVERSEPROXY)"
Write-Host "  BTCPAYGEN_ADDITIONAL_FRAGMENTS=$($env:BTCPAYGEN_ADDITIONAL_FRAGMENTS)"

Push-Location $vendorDir
try {
    & .\build.ps1
} finally {
    Pop-Location
}

$generated = Join-Path $vendorDir "Generated\docker-compose.generated.yml"
if (-not (Test-Path $generated)) {
    throw "Generation failed: $generated not found"
}

& (Join-Path $PSScriptRoot "patch-coolify.ps1") -InputFile $generated -OutputFile (Join-Path $repoRoot "docker-compose.yml")
Write-Host "Done. Deploy docker-compose.yml via Coolify."
