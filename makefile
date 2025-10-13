up:
	docker-compose up -d
down:
	docker-compose down
ssl:
	if ! [ -x "$$(command -v mkcert)" ]; then \
		echo "mkcert is not installed. Please install mkcert first."; \
		exit 1; \
	fi
	mkdir -p traefik/certs
	mkcert -key-file traefik/certs/local.key -cert-file traefik/certs/local.crt "*.test" "*.trustshop.test" "trustshop.test" "traefik.test" "localhost"
	mkcert -install
	