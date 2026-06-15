#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/btcpayserver-docker"
REPO_URL="https://github.com/btcpayserver/btcpayserver-docker.git"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to generate the compose file." >&2
  exit 1
fi

if [[ ! -d "$VENDOR_DIR" ]]; then
  echo "Cloning btcpayserver-docker..."
  mkdir -p "$REPO_ROOT/vendor"
  git clone --depth 1 "$REPO_URL" "$VENDOR_DIR"
else
  echo "Updating btcpayserver-docker..."
  git -C "$VENDOR_DIR" pull --ff-only
fi

export BTCPAY_HOST="${BTCPAY_HOST:-btcpay.example.com}"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_REVERSEPROXY="none"
export BTCPAY_PROTOCOL="http"
export BTCPAYGEN_LIGHTNING=""
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"

echo "Generating docker-compose with:"
echo "  BTCPAY_HOST=$BTCPAY_HOST"
echo "  NBITCOIN_NETWORK=$NBITCOIN_NETWORK"
echo "  BTCPAYGEN_REVERSEPROXY=$BTCPAYGEN_REVERSEPROXY"
echo "  BTCPAYGEN_ADDITIONAL_FRAGMENTS=$BTCPAYGEN_ADDITIONAL_FRAGMENTS"

(
  cd "$VENDOR_DIR"
  ./build.sh
)

GENERATED="$VENDOR_DIR/Generated/docker-compose.generated.yml"
if [[ ! -f "$GENERATED" ]]; then
  echo "Generation failed: $GENERATED not found" >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  pwsh "$REPO_ROOT/scripts/patch-coolify.ps1" -InputFile "$GENERATED" -OutputFile "$REPO_ROOT/docker-compose.yml"
elif command -v powershell >/dev/null 2>&1; then
  powershell -File "$REPO_ROOT/scripts/patch-coolify.ps1" -InputFile "$GENERATED" -OutputFile "$REPO_ROOT/docker-compose.yml"
else
  python3 "$REPO_ROOT/scripts/patch-coolify.py" "$GENERATED" "$REPO_ROOT/docker-compose.yml"
fi

echo "Done. Deploy docker-compose.yml via Coolify."
