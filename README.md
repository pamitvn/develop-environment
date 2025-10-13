# Environment Setup

This project requires a specific environment setup to ensure compatibility and optimal performance. Follow the steps
below to set up your environment.

## Prerequisites

- Docker
- Docker Compose
- mkcerts (for generating SSL certificates)
- Git

## Steps to Set Up the Environment

1. **Clone the Repository**
2. **Generate SSL Certificates**

- Install mkcerts if you haven't already:
  ```bash
  brew install mkcert
  brew install nss # if you use Firefox
  ```
- Create a local CA (Certificate Authority):
   ```bash
  mkcert -key-file traefik/certs/local.key -cert-file traefik/certs/local.crt "*.test" "*.trustshop.test" "trustshop.test" "traefik.test" "localhost"
  mkcert -install
   ```

3. **Start the Docker Containers**
   ```bash
   docker-compose up -d
   ```