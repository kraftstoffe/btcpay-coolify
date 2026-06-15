param(
    [string]$InputFile = "",
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $InputFile) { $InputFile = Join-Path $repoRoot "vendor\btcpayserver-docker\Generated\docker-compose.generated.yml" }
if (-not $OutputFile) { $OutputFile = Join-Path $repoRoot "docker-compose.yml" }

if (-not (Test-Path $InputFile)) {
    throw "Generated compose not found: $InputFile"
}

$header = @"
# BTCPay Server - Coolify-ready Docker Compose
# Generated from btcpayserver/btcpayserver-docker (mainnet, btc, no reverse proxy, pruned node)
# Regenerate: ./scripts/generate-compose.sh  or  .\scripts\generate-compose.ps1
#
# Coolify: assign domain to btcpayserver service on port 49392
# Persistent volumes: bitcoin_datadir, postgres_datadir, btcpay_datadir, nbxplorer_datadir

"@

$content = Get-Content -Path $InputFile -Raw
$lines = $content -split "`n"
$result = New-Object System.Collections.Generic.List[string]

$inBtcpayserver = $false
$inPorts = $false
$inEnvironment = $false
$envIsList = $false
$btcpayIndent = ""
$addedCoolify = $false

$coolifyMapLines = @(
    "      SERVICE_FQDN_BTCPAYSERVER_49392: `"`"",
    "      BTCPAY_HOST: `${SERVICE_FQDN_BTCPAYSERVER:-`${BTCPAY_HOST}}",
    "      BTCPAY_PROTOCOL: `${BTCPAY_PROTOCOL:-http}"
)

$coolifyListLines = @(
    "      - SERVICE_FQDN_BTCPAYSERVER_49392",
    "      - BTCPAY_HOST=`${SERVICE_FQDN_BTCPAYSERVER:-`${BTCPAY_HOST}}",
    "      - BTCPAY_PROTOCOL=`${BTCPAY_PROTOCOL:-http}"
)

foreach ($line in $lines) {
    if ($line -match '^(\s*)btcpayserver:\s*$') {
        $inBtcpayserver = $true
        $btcpayIndent = $Matches[1]
        $result.Add($line)
        continue
    }

    if ($inBtcpayserver -and $line -match '^[a-zA-Z0-9_]+:\s*$' -and $line -notmatch '^\s') {
        $inBtcpayserver = $false
        $inPorts = $false
        $inEnvironment = $false
    }

    if ($inBtcpayserver -and $line -match '^\s+ports:\s*$') {
        $inPorts = $true
        $inEnvironment = $false
        continue
    }

    if ($inPorts) {
        if ($line -match '^\s+-\s+"?\d+:\d+"?\s*$' -or $line -match 'NOREVERSEPROXY_HTTP_PORT') {
            continue
        }
        $inPorts = $false
    }

    if ($inBtcpayserver -and $line -match '^\s+environment:\s*$') {
        $inEnvironment = $true
        $result.Add($line)
        $nextIndex = [array]::IndexOf($lines, $line) + 1
        $envIsList = $false
        if ($nextIndex -lt $lines.Count -and $lines[$nextIndex] -match '^\s+-\s+') {
            $envIsList = $true
        }
        if (-not $addedCoolify) {
            if ($envIsList) { $result.AddRange($coolifyListLines) }
            else { $result.AddRange($coolifyMapLines) }
            $addedCoolify = $true
        }
        continue
    }

    if ($inBtcpayserver -and $inEnvironment) {
        if ($envIsList) {
            if ($line -match 'BTCPAY_HOST=' -or $line -match 'BTCPAY_PROTOCOL=' -or $line -match 'SERVICE_FQDN_BTCPAYSERVER') {
                continue
            }
        } else {
            if ($line -match '^\s+(BTCPAY_HOST|BTCPAY_PROTOCOL|SERVICE_FQDN_BTCPAYSERVER_49392):') {
                continue
            }
        }
        if ($line -match '^(\s+)\S') {
            $indent = $Matches[1]
            if ($indent.Length -le ($btcpayIndent.Length + 2) -and $line.Trim()) {
                $inEnvironment = $false
            }
        }
    }

    if ($inBtcpayserver -and $line -match '^\s+labels:\s*$') {
        $inEnvironment = $false
        continue
    }

    if ($inBtcpayserver -and $line -match '^\s+traefik\.') {
        continue
    }

    $result.Add($line)
}

$output = $header + ($result -join "`n")

if ($output -notmatch '(?ms)btcpayserver:\s*\n(?:\s+.+\n)*?\s+expose:\s*\n\s+-\s+"49392"') {
    $output = $output -replace '(?m)(^(\s*)btcpayserver:\s*$)', "`$1`n`$2  expose:`n`$2    - `"49392`""
}

Set-Content -Path $OutputFile -Value $output -NoNewline
Write-Host "Patched compose written to: $OutputFile"
