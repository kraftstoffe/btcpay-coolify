# BTCPay Server on Coolify

Self-hosted [BTCPay Server](https://btcpayserver.org) stack for deployment via [Coolify](https://coolify.io) Docker Compose.

- **Network:** Bitcoin mainnet
- **Coins:** BTC only
- **Lightning:** disabled
- **Node:** pruned (~50 GB via `opt-save-storage-s`)
- **SSL:** Coolify Traefik (BTCPay internal Nginx disabled)

## Server requirements

| Resource | Minimum |
|----------|---------|
| RAM | 4 GB (8 GB recommended) |
| Disk | ~80 GB SSD |
| Ports | 80, 443 (Coolify proxy) |
| OS | Ubuntu 22.04/24.04 LTS |

Initial Bitcoin sync can take hours to days.

## Coolify deployment

1. Install Coolify on your dedicated VPS ([installation guide](https://coolify.io/docs/get-started/installation)).
2. Configure a wildcard domain or set a fixed domain for this service.
3. Create a DNS **A record** pointing your BTCPay hostname to the server IP.
4. In Coolify: **New Resource → Docker Compose** and connect this Git repository.
5. Build pack: **Docker Compose**, file: `docker-compose.yml`.
6. Assign your domain to the **btcpayserver** service on port **49392**.
7. Enable **Persistent Storage** for these volumes:
   - `bitcoin_datadir` (blockchain data)
   - `postgres_datadir`
   - `btcpay_datadir`
   - `nbxplorer_datadir`
8. Set environment variables (or use `.env.example` as reference):

```env
BTCPAY_HOST=btcpay.example.com
BTCPAY_PROTOCOL=http
NBITCOIN_NETWORK=mainnet
```

9. Deploy and wait for `bitcoind` to finish syncing (check container logs).
10. Open `https://btcpay.example.com` and create the first admin account.

## Regenerating the compose file

When BTCPay releases new versions, regenerate from the official generator (requires Docker):

```bash
# Linux / Coolify server
./scripts/generate-compose.sh

# Windows
.\scripts\generate-compose.ps1
```

Then commit the updated `docker-compose.yml` and redeploy in Coolify.

## Architecture

```
Internet → Coolify Traefik (:443) → btcpayserver (:49392)
                                      ├── postgres
                                      ├── nbxplorer
                                      └── bitcoind (pruned)
```

BTCPay runs without its own reverse proxy so Coolify can own ports 80/443.

## Troubleshooting

- **HTTP 400 on registration:** ensure `BTCPAY_PROTOCOL=http` (Traefik terminates TLS).
- **502 / 503 from Coolify:** confirm domain is mapped to port `49392` on `btcpayserver`.
- **Payments not detected:** wait until `bitcoind` is fully synced.
