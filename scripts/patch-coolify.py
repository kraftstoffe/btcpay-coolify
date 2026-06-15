#!/usr/bin/env python3
"""Patch generated BTCPay compose for Coolify (Linux fallback when PowerShell is unavailable)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

HEADER = """# BTCPay Server - Coolify-ready Docker Compose
# Generated from btcpayserver/btcpayserver-docker (mainnet, btc, no reverse proxy, pruned node)
# Regenerate: ./scripts/generate-compose.sh  or  .\\scripts\\generate-compose.ps1
#
# Coolify: assign domain to btcpayserver service on port 49392
# Persistent volumes: bitcoin_datadir, postgres_datadir, btcpay_datadir, nbxplorer_datadir

"""

COOLIFY_ENV_LINES = [
    "      SERVICE_FQDN_BTCPAYSERVER_49392: \"\"",
    "      BTCPAY_HOST: ${SERVICE_FQDN_BTCPAYSERVER:-${BTCPAY_HOST}}",
    "      BTCPAY_PROTOCOL: ${BTCPAY_PROTOCOL:-http}",
]

SKIP_ENV_KEYS = {"BTCPAY_HOST", "BTCPAY_PROTOCOL", "SERVICE_FQDN_BTCPAYSERVER_49392"}


def patch_compose(content: str) -> str:
    lines = content.splitlines()
    result: list[str] = []
    in_btcpay = False
    in_ports = False
    in_environment = False
    env_is_list = False
    btcpay_indent = ""
    added_coolify = False

    i = 0
    while i < len(lines):
        line = lines[i]

        if re.match(r"^(\s*)btcpayserver:\s*$", line):
            in_btcpay = True
            btcpay_indent = re.match(r"^(\s*)", line).group(1)
            result.append(line)
            i += 1
            continue

        if in_btcpay and re.match(r"^[a-zA-Z0-9_]+:\s*$", line) and not line.startswith(" "):
            in_btcpay = False
            in_ports = False
            in_environment = False

        if in_btcpay and re.match(r"^\s+ports:\s*$", line):
            in_ports = True
            in_environment = False
            i += 1
            continue

        if in_ports:
            if re.match(r'^\s+-\s+"?\d+:\d+"?\s*$', line) or "NOREVERSEPROXY_HTTP_PORT" in line:
                i += 1
                continue
            in_ports = False

        if in_btcpay and re.match(r"^(\s+)environment:\s*$", line):
            in_environment = True
            env_is_list = False
            result.append(line)
            if i + 1 < len(lines) and re.match(r"^\s+-\s+", lines[i + 1]):
                env_is_list = True
            if not added_coolify:
                if env_is_list:
                    for env_line in [
                        "      - SERVICE_FQDN_BTCPAYSERVER_49392",
                        "      - BTCPAY_HOST=${SERVICE_FQDN_BTCPAYSERVER:-${BTCPAY_HOST}}",
                        "      - BTCPAY_PROTOCOL=${BTCPAY_PROTOCOL:-http}",
                    ]:
                        result.append(env_line)
                else:
                    result.extend(COOLIFY_ENV_LINES)
                added_coolify = True
            i += 1
            continue

        if in_btcpay and in_environment:
            if env_is_list:
                if re.search(r"BTCPAY_HOST=", line) or re.search(r"BTCPAY_PROTOCOL=", line) or "SERVICE_FQDN_BTCPAYSERVER" in line:
                    i += 1
                    continue
            else:
                key_match = re.match(r"^\s+([A-Z0-9_]+):", line)
                if key_match and key_match.group(1) in SKIP_ENV_KEYS:
                    i += 1
                    continue

            indent = re.match(r"^(\s*)", line).group(1)
            if line.strip() and len(indent) <= len(btcpay_indent) + 2:
                in_environment = False

        if in_btcpay and re.match(r"^\s+labels:\s*$", line):
            in_environment = False
            i += 1
            while i < len(lines):
                if not lines[i].startswith(" " * (len(btcpay_indent) + 2)) and lines[i].strip():
                    break
                if "traefik." in lines[i]:
                    i += 1
                    continue
                break
            continue

        result.append(line)
        i += 1

    output = "\n".join(result)
    btcpay_section = output.split("btcpayserver:", 1)
    if len(btcpay_section) > 1 and "expose:" not in btcpay_section[1].split("volumes:", 1)[0]:
        output = re.sub(
            r"(^(\s*)btcpayserver:\s*$)",
            r'\1\n\2  expose:\n\2    - "49392"',
            output,
            count=1,
            flags=re.MULTILINE,
        )

    output = re.sub(r"(?ms)^\s+labels:\s*\n(?:\s+traefik\..+\n)+", "", output)
    return HEADER + output


def main() -> None:
    input_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("vendor/btcpayserver-docker/Generated/docker-compose.generated.yml")
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("docker-compose.yml")

    if not input_file.exists():
        raise SystemExit(f"Generated compose not found: {input_file}")

    patched = patch_compose(input_file.read_text(encoding="utf-8"))
    output_file.write_text(patched, encoding="utf-8")
    print(f"Patched compose written to: {output_file}")


if __name__ == "__main__":
    main()
