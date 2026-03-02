BREW_PREFIX := $(shell brew --prefix 2>/dev/null)
ifeq ($(BREW_PREFIX),)
  $(warning Homebrew not found — run 'make setup-deps' targets will fail for DNS config)
endif
DNSMASQ_CONF := $(BREW_PREFIX)/etc/dnsmasq.conf

.PHONY: setup setup-deps setup-dns setup-docker ssl up down

# ─── Main Setup ─────────────────────────────────────────────
setup: setup-deps ssl setup-dns setup-docker up
	@echo ""
	@echo "Setup complete!"
	@echo "  Traefik dashboard: https://traefik.test"
	@echo "  Postgres:          localhost:5432"
	@echo "  Redis:             localhost:6379"
	@echo ""
	@echo "Verify DNS: dig traefik.test @127.0.0.1"

# ─── Dependencies ──────────────────────────────────────────
setup-deps:
	@echo "==> Checking dependencies..."
	@if ! command -v brew &>/dev/null; then \
		echo "Error: Homebrew is required. Install from https://brew.sh"; \
		exit 1; \
	fi
	@if ! command -v mkcert &>/dev/null; then \
		echo "  Installing mkcert..."; \
		brew install mkcert; \
	else \
		echo "  mkcert: OK"; \
	fi
	@if ! brew list nss &>/dev/null 2>&1; then \
		echo "  Installing nss (Firefox support)..."; \
		brew install nss; \
	else \
		echo "  nss: OK"; \
	fi
	@if ! command -v dnsmasq &>/dev/null; then \
		echo "  Installing dnsmasq..."; \
		brew install dnsmasq; \
	else \
		echo "  dnsmasq: OK"; \
	fi

# ─── SSL Certificates ─────────────────────────────────────
ssl:
	@echo "==> Setting up SSL certificates..."
	@mkdir -p traefik/certs
	@if [ -f traefik/certs/local.crt ] && [ -f traefik/certs/local.key ]; then \
		echo "  Certificates already exist, skipping."; \
	else \
		if ! command -v mkcert &>/dev/null; then \
			echo "Error: mkcert is not installed. Run 'make setup-deps' first."; \
			exit 1; \
		fi; \
		mkcert -key-file traefik/certs/local.key -cert-file traefik/certs/local.crt \
			"*.test" "*.trustshop.test" "trustshop.test" "traefik.test" "localhost"; \
		mkcert -install; \
		echo "  Certificates generated and CA installed."; \
	fi

# ─── DNS Configuration ────────────────────────────────────
setup-dns:
	@echo "==> Configuring DNS..."
	@# dnsmasq config: resolve .test to localhost
	@if grep -q 'address=/.test/127.0.0.1' "$(DNSMASQ_CONF)" 2>/dev/null; then \
		echo "  dnsmasq .test resolution: OK"; \
	else \
		echo "  Adding .test domain resolution to dnsmasq..."; \
		echo 'address=/.test/127.0.0.1' >> "$(DNSMASQ_CONF)"; \
	fi
	@# dnsmasq config: upstream DNS servers
	@if grep -q 'server=1.1.1.1' "$(DNSMASQ_CONF)" 2>/dev/null; then \
		echo "  dnsmasq upstream DNS: OK"; \
	else \
		echo "  Adding upstream DNS servers to dnsmasq..."; \
		echo 'server=1.1.1.1' >> "$(DNSMASQ_CONF)"; \
		echo 'server=1.0.0.1' >> "$(DNSMASQ_CONF)"; \
	fi
	@# macOS resolver for .test domains
	@if [ -f /etc/resolver/test ]; then \
		echo "  macOS .test resolver: OK"; \
	else \
		echo "  Creating macOS resolver for .test domains (requires sudo)..."; \
		sudo mkdir -p /etc/resolver; \
		echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/test > /dev/null; \
	fi
	@# Start dnsmasq (or restart if already running to pick up config changes)
	@if sudo brew services list | grep -q 'dnsmasq.*started'; then \
		echo "  Restarting dnsmasq to apply config changes..."; \
		sudo brew services restart dnsmasq; \
	else \
		echo "  Starting dnsmasq service..."; \
		sudo brew services start dnsmasq; \
	fi
	@# Set DNS on active network interface
	@ACTIVE_SERVICE=$$(networksetup -listallnetworkservices | tail -n +2 | grep -v '^\*' | while read -r svc; do \
		if networksetup -getinfo "$$svc" 2>/dev/null | grep -q 'IP address: [0-9]'; then \
			echo "$$svc"; \
			break; \
		fi; \
	done); \
	if [ -n "$$ACTIVE_SERVICE" ]; then \
		CURRENT_DNS=$$(networksetup -getdnsservers "$$ACTIVE_SERVICE" 2>/dev/null); \
		if echo "$$CURRENT_DNS" | grep -q '127.0.0.1'; then \
			echo "  DNS for $$ACTIVE_SERVICE: OK"; \
		else \
			echo "  Setting DNS to 127.0.0.1 on $$ACTIVE_SERVICE (requires sudo)..."; \
			sudo networksetup -setdnsservers "$$ACTIVE_SERVICE" 127.0.0.1 1.1.1.1; \
		fi; \
	else \
		echo "  Warning: Could not detect active network service."; \
		echo "  Manually run: sudo networksetup -setdnsservers \"<Your Network>\" 127.0.0.1"; \
	fi
	@# Flush DNS cache
	@echo "  Flushing DNS cache..."
	@sudo dscacheutil -flushcache
	@sudo killall -HUP mDNSResponder 2>/dev/null || true

# ─── Docker Setup ──────────────────────────────────────────
setup-docker:
	@echo "==> Setting up Docker..."
	@# Create external traefik network
	@if docker network ls --format '{{.Name}}' | grep -q '^traefik$$'; then \
		echo "  Docker network 'traefik': OK"; \
	else \
		echo "  Creating Docker network 'traefik'..."; \
		docker network create traefik; \
	fi
	@# Copy .env from example if missing
	@if [ -f .env ]; then \
		echo "  .env file: OK"; \
	else \
		echo "  Creating .env from .env.example..."; \
		cp .env.example .env; \
	fi

# ─── Container Management ─────────────────────────────────
up:
	docker-compose up -d

down:
	docker-compose down
