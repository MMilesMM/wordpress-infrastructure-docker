# WordPress Multi Docker

Resource-efficient Docker setup for hosting multiple independent WordPress sites with **one shared MariaDB container** and **one shared Redis container**.

Each site still gets its own:

- WordPress container
- WordPress files
- MariaDB database
- MariaDB user and password
- Redis logical database and cache prefix
- localhost port
- Docker Compose lifecycle

The default WordPress image is `mmilesmm/wordpress-apache-php-fix:latest`.

## Architecture

```text
Reverse Proxy
   |
   +-- 127.0.0.1:3000 -> site-a.de WordPress ----+
   +-- 127.0.0.1:3001 -> site-b.de WordPress ----+---- wordpress-backend
   +-- 127.0.0.1:3002 -> site-c.de WordPress ----+          |
                                                            +-- MariaDB
                                                            +-- Redis
```

The database and Redis containers are not published to the host network. WordPress containers communicate with them through the shared Docker network `wordpress-backend`.

## Requirements

- Linux server
- Docker Engine
- Docker Compose v2 (`docker compose`)
- `openssl`, `sed`, `grep`, `ss`, `tar`, `gzip`

## Quick start

```bash
git clone <YOUR-REPOSITORY-URL> /opt/wordpress
cd /opt/wordpress

./scripts/init.sh
./scripts/create-site.sh example.de
```

`init.sh` automatically creates a random MariaDB root password in `infrastructure/.env` and starts the shared MariaDB and Redis containers.

`create-site.sh` automatically:

1. selects the next free localhost port, starting at `3000`
2. selects a free Redis logical database
3. generates a random database password
4. creates a dedicated MariaDB database and user
5. creates the site directory from `site-template/`
6. starts the new WordPress container

Example output:

```text
Site created successfully.
  Domain:         example.de
  Local URL:      http://127.0.0.1:3000
  Directory:      /opt/wordpress/sites/example.de
  Database:       wp_example_de
  Redis database: 0
```

Then configure your reverse proxy to forward `example.de` to `127.0.0.1:3000`.

## Publish this repository to GitHub

If the GitHub CLI is installed and authenticated:

```bash
gh auth login
./scripts/publish-github.sh wordpress-multi-docker public
```

The script creates the GitHub repository, adds it as `origin`, and pushes the existing `main` branch.

## Create another site

Automatic port:

```bash
./scripts/create-site.sh customer.example
```

Specific port:

```bash
./scripts/create-site.sh customer.example 3050
```

## Site layout

```text
sites/example.de/
├── .env
├── compose.yml
└── wordpress_data/
```

The `.env` file contains the database credentials and is excluded from Git.

## List sites

```bash
./scripts/list-sites.sh
```

or:

```bash
make list
```

## Start / stop one site

```bash
cd sites/example.de

docker compose stop
docker compose start
docker compose restart
```

Stopping one WordPress site does not affect MariaDB, Redis, or other sites.

## Backups

Back up one site:

```bash
./scripts/backup-site.sh example.de
```

Back up all sites:

```bash
./scripts/backup-all.sh
```

Backups are written to:

```text
backups/<domain>/<timestamp>/
├── database.sql.gz
├── wordpress_data.tar.gz
├── site.env
└── README.txt
```

The backup directory is ignored by Git. Backups contain credentials and must be stored securely.

## Update all WordPress containers

```bash
./scripts/update-sites.sh
```

This pulls the image configured in each site's `.env` and recreates its WordPress container.

For production environments, consider using a fixed image tag instead of `latest` so updates are deliberate and reproducible.

## Remove a site

To remove only its container while preserving files and database:

```bash
./scripts/remove-site.sh example.de --keep-data
```

To permanently delete the WordPress files, database, database user, and Redis cache:

```bash
./scripts/remove-site.sh example.de
```

**Warning:** the second command is destructive.

## Redis

The shared Redis server provides 256 logical databases. Every automatically created site receives its own database number and unique cache prefix:

```php
define('WP_REDIS_HOST', 'wordpress-redis');
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_PREFIX', 'example_de:');
define('WP_CACHE_KEY_SALT', 'example_de:');
```

These constants work directly with plugins such as Redis Object Cache. If a cache plugin maintains its own Redis prefix/database configuration, configure the same site-specific separation there as well.

## MariaDB isolation

Every site receives a separate database and database user. A WordPress installation therefore does not receive credentials for the databases of other sites.

Example:

```text
site-a.de -> wp_site_a_de / wp_site_a_de
site-b.de -> wp_site_b_de / wp_site_b_de
site-c.de -> wp_site_c_de / wp_site_c_de
```

All databases still live in the same MariaDB server, so MariaDB is a shared failure domain. Maintain reliable external backups.

## Shared infrastructure

Start:

```bash
make infra-up
```

Logs:

```bash
make infra-logs
```

Stop:

```bash
make infra-down
```

Normally there is no reason to stop the shared infrastructure while sites are running.

## Custom WordPress image

The included `Dockerfile` is based on the existing `MMilesMM/wordpress-docker` image concept and adds:

- Apache `headers`
- Apache `ext_filter`
- PHP `tidy`
- PHP `soap`
- PHP `redis`
- PHP `brotli`

A GitHub Actions workflow builds multi-architecture images for `amd64` and `arm64` and publishes them to GitHub Container Registry.

To use your GHCR image instead of Docker Hub, change in the site's `.env`:

```env
WORDPRESS_IMAGE=ghcr.io/<github-user>/wordpress-apache-php-fix:latest
```

## Production notes

- Keep `infrastructure/.env` and every `sites/*/.env` readable only by root/admin users.
- Do not publish MariaDB or Redis ports on the host.
- Put TLS termination in your reverse proxy.
- Back up both SQL and `wordpress_data`.
- Monitor MariaDB RAM usage and adjust `MARIADB_INNODB_BUFFER_POOL_SIZE` for the number and size of sites.
- Use fixed WordPress image tags if you need controlled maintenance windows.

## Repository structure

```text
.
├── .github/workflows/docker-image.yml
├── config/wordpress.ini
├── infrastructure/
│   ├── .env.example
│   └── compose.yml
├── scripts/
│   ├── lib.sh
│   ├── init.sh
│   ├── create-site.sh
│   ├── list-sites.sh
│   ├── remove-site.sh
│   ├── backup-site.sh
│   ├── backup-all.sh
│   └── update-sites.sh
├── site-template/
│   ├── .env.example
│   └── compose.yml
├── sites/
├── backups/
├── Dockerfile
├── Makefile
└── README.md
```

## License

GPL-3.0.
