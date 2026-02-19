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

In `docker-compose.yml` remove the blocks of containers you don't need (utils, data-enhancer, etc.) to prevent the start up process from erroring out.

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
echo "127.0.0.1 www-dev.artic.edu api-dev.artic.edu" | sudo tee -a /etc/hosts
```

4. Helper Shortcuts (Optional)

To simplify managing multiple containers, you can add these aliases to your shell profile (~/.zshrc or ~/.bashrc):

```bash
# Set this to your aic-docker directory
export DOCKER_PROJECT_DIR="$HOME/path/to/aic-docker"

# Start/Stop all services
alias d-up="docker compose --project-directory $DOCKER_PROJECT_DIR up -d"
alias d-down="docker compose --project-directory $DOCKER_PROJECT_DIR down"

# Execute commands in a specific service (e.g., d-run website php artisan migrate)
function d-run() {
    local service="$1"
    shift
    docker compose --project-directory "$DOCKER_PROJECT_DIR" exec "$service" "$@"
}
```

5. Building and Running

You can build and start the entire stack or target a specific project.

Build and Start Everything:

```bash
d-up --build
```
Build/Start a Single Project:
```bash
docker compose up -d --build website
```

6. Application Integration

After the containers are running, update the .env file inside your individual project folders (e.g., the /website or /data-aggregator directories):

  Database Hosts: Set DB_HOST to the service name defined in docker-compose.yml (e.g., pgsql or mysql).

  Database Ports: Use standard internal ports (e.g., 3306 or 5432).

  Maintenance: Run migrations or clear cache through the container:

```bash
d-run website php artisan migrate
d-run website php artisan cache:clear
```

7. Useful Commands Reference
| Action | Command |
| --- | --- |
| Check Logs | `docker compose logs -f [service_name]` |
| Stop All Services | `docker stop $(docker ps -q)` |
| Interactive Shell | `docker exec -it [container_name] /bin/bash` |
| Full Reset | `docker compose down -v (Removes containers and volumes)` |

## Contributing

We welcome your contributions. Please fork this repository and make your changes in a separate branch. To better understand how we organize our code, please review our [version control guidelines](https://docs.google.com/document/d/1B-27HBUc6LDYHwvxp3ILUcPTo67VFIGwo5Hiq4J9Jjw).

### Starting a new feature branch
```bash
# Clone the repo to your computer
git clone git@github.com:your-github-account/aic-docker.git

# Enter the folder that was created by the clone
cd website

# Install

# Start a feature branch
git checkout -b feature/good-short-description

# ... make some changes
```