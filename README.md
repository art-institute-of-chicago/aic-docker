![Art Institute of Chicago](https://raw.githubusercontent.com/Art-Institute-of-Chicago/template/main/aic-logo.gif)

# AIC Docker Environment
> A repository to setup and run our public projects in a Docker environment

This repo contains all the necessary configurations and scripts to get our public projects up and running.

## Local Development Setup

This guide provides a generic framework for setting up a Docker-based development environment for our projects. It is designed to be modular, allowing you to install and run only the projects you need.
1. Prerequisites

Install Docker Desktop from [here](https://docs.docker.com/desktop/) (or Docker Engine for Linux). Mac users can use Homebrew:

```bash
brew install --cask docker
```

Clone the configuration repository which contains the Docker Compose file and environment templates:

```bash
git clone git@github.com:art-institute-of-chicago/aic-docker.git
cd aic-docker
```

Services use Docker Compose profiles — you choose which to run at startup time. No need to edit `docker-compose.yml`.

2. Environment Configuration

The Docker setup uses a root .env file to map your local source code into the containers.

Initialize Environment File:

```bash
cp .env.example .env
```

Map Local Paths: Open .env and update the LOCAL_*_PATH variables to point to the absolute paths where your projects reside on your machine.

  Example: LOCAL_WEBSITE_PATH='/Users/name/projects/website'

3. Network Setup

To access your applications via custom domains rather than localhost, add the necessary host mappings to your system's hosts file:

```bash
# Example for mapping local dev domains
echo "127.0.0.1 www-dev.artic.edu api-dev.artic.edu styles-data-dev.artic.edu archives-data-dev.artic.edu artist-enrichment-data-dev.artic.edu journeymaker-dev.artic.edu" | sudo tee -a /etc/hosts
```

4. Service Management (compose.sh)

Use `compose.sh` to start, stop, and manage services via Docker Compose profiles.

```bash
# Interactive mode — select services from a menu
./compose.sh

# Start specific services (infra: mysql, pgsql, redis, nginx always start)
./compose.sh website data-aggregator

# Start everything
./compose.sh --all

# Rebuild then start
./compose.sh --build website

# Stop everything
./compose.sh --down

# Stop specific services
./compose.sh --down website

# List available services
./compose.sh --list
```

Available services:

| Service | Description |
|---|---|
| `website` | Main website (Laravel) |
| `utils` | Utility scripts + Ansible |
| `data-aggregator` | Data aggregation pipeline |
| `data-service-assets` | Assets microservice |
| `data-service-styles` | Styles microservice |
| `data-service-archives` | Archives microservice |
| `data-enhancer` | Data enhancement service |
| `journeymaker-client` | JourneyMaker frontend |
| `data-service-artist-enrichment` | Artist enrichment service |

Infrastructure services (`mysql`, `pgsql`, `redis`, `nginx`) start automatically with any profile.

5. Building and Running

Build and start the services you need:

```bash
# Interactive — pick from a menu
./compose.sh

# Specific services with rebuild
./compose.sh --build website data-aggregator

# Everything
./compose.sh --all --build
```

To run commands inside a running container:

```bash
docker compose exec website php artisan migrate
docker compose exec data-aggregator bash
```

6. Application Integration

After the containers are running, update the .env file inside your individual project folders (e.g., the /website or /data-aggregator directories):

  Database Hosts: Set DB_HOST to the service name defined in docker-compose.yml (e.g., pgsql or mysql).

  Database Ports: Use standard internal ports (e.g., 3306 or 5432).

  Maintenance: Run migrations or clear cache through the container:

```bash
docker compose exec website php artisan migrate
docker compose exec website php artisan cache:clear
```

7. Useful Commands Reference
| Action | Command |
| --- | --- |
| Start services (menu) | `./compose.sh` |
| Start specific services | `./compose.sh website data-aggregator` |
| Start all services | `./compose.sh --all` |
| Stop all services | `./compose.sh --down` |
| Check Logs | `docker compose logs -f [service_name]` |
| Interactive Shell | `docker compose exec [service_name] bash` |
| Rebuild service | `./compose.sh --build website` |
| Full Reset | `docker compose down -v` |

## Contributing

We welcome your contributions. Please fork this repository and make your changes in a separate branch. To better understand how we organize our code, please review our [version control guidelines](https://docs.google.com/document/d/1B-27HBUc6LDYHwvxp3ILUcPTo67VFIGwo5Hiq4J9Jjw).

### Starting a new feature branch
```bash
# Clone the repo to your computer
git clone git@github.com:your-github-account/aic-docker.git

# Enter the folder that was created by the clone
cd aic-docker

# Install

# Start a feature branch
git checkout -b feature/good-short-description

# ... make some changes
```