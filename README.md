# Development Environment

Local development stack with Traefik reverse proxy, TimescaleDB (PostgreSQL), and Redis. All services use `.test` domains with trusted SSL certificates.

## Quick Start

```bash
git clone <repo-url> && cd develop-environment
make setup
```

This single command handles everything: installs dependencies, generates SSL certificates, configures DNS, creates the Docker network, and starts all services. It's idempotent — safe to run again at any time.

You'll be prompted for your password during setup (dnsmasq and DNS resolver configuration require `sudo`).

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- [Docker](https://www.docker.com/products/docker-desktop/)

All other dependencies (mkcert, nss, dnsmasq) are installed automatically by `make setup`.

## Services

| Service | URL / Address | Description |
|---------|---------------|-------------|
| Traefik | https://traefik.test | Reverse proxy dashboard |
| PostgreSQL | localhost:5432 | TimescaleDB (pg16) |
| Redis | localhost:6379 | Key-value store |

## Make Targets

| Target | Description |
|--------|-------------|
| `make setup` | Full environment setup (runs all targets below) |
| `make setup-deps` | Install Homebrew dependencies (mkcert, nss, dnsmasq) |
| `make ssl` | Generate trusted SSL certificates for `*.test` domains |
| `make setup-dns` | Configure dnsmasq, macOS resolver, and network DNS |
| `make setup-docker` | Create Docker network and `.env` file |
| `make up` | Start all containers |
| `make down` | Stop all containers |

## How It Works

### DNS Resolution

[dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) resolves all `.test` domains to `127.0.0.1` locally, so you don't need to edit `/etc/hosts` for each new service. A macOS resolver at `/etc/resolver/test` routes only `.test` lookups through dnsmasq — all other DNS continues through Cloudflare (`1.1.1.1`).

### SSL Certificates

[mkcert](https://github.com/FiloSottile/mkcert) generates locally-trusted certificates. The CA is installed in your system trust store so browsers accept `*.test` domains without warnings. Certificates cover:

- `*.test`
- `*.trustshop.test`
- `trustshop.test`
- `traefik.test`
- `localhost`

### Traefik

Traefik acts as the single entry point, routing HTTP/HTTPS and TCP traffic to the appropriate service. It automatically discovers Docker containers via labels and handles TLS termination. HTTP requests are redirected to HTTPS.

## Adding a New Service

1. Create a `docker-compose.<service>.yml` file
2. Add it to the `include` list in `docker-compose.yml`
3. Add Traefik labels to your service for routing
4. If using a new `.test` domain, the existing wildcard certificate already covers it

## Verify Setup

```bash
dig traefik.test @127.0.0.1
# Should return 127.0.0.1
```

Visit https://traefik.test to confirm the dashboard loads with a trusted certificate.
