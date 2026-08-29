# LocalAI Docker Setup

This project runs LocalAI, Open WebUI, and PostgreSQL with Docker Compose. Models are downloaded through the application and are not stored in Git.

## Quickstart

From a PowerShell terminal, run the following from the repository root:

```powershell
Copy-Item env_defaults .env
New-Item -ItemType Directory -Force secrets | Out-Null
notepad secrets/webui_postgres_password.txt
notepad secrets/localai_postgres_password.txt
docker compose up -d
```

Enter one strong password on a single line in each file. Use different passwords, do not add quotes or `PASSWORD=`, and do not commit these files.

Once the containers are ready, open [Open WebUI](http://localhost). The LocalAI API is available at http://localhost:8080. Create the initial Open WebUI account when prompted.

The first startup may take several minutes while the CUDA 12 `llama-cpp` backend is installed. Check progress with:

```powershell
docker compose ps
docker compose logs -f postgres localai open-webui
```

For port changes, model storage, database secrets, GPU requirements, updates, backups, and resets, continue with the detailed configuration below.

## Detailed configuration

## Prerequisites

Install the following on the host machine:

- Docker Desktop with Docker Compose support
- An NVIDIA GPU and the NVIDIA Container Toolkit, because the LocalAI service requests NVIDIA GPUs
- Git, if cloning this repository

Verify Docker before continuing:

```powershell
docker --version
docker compose version
```

## Get the project

Clone the repository and enter its directory:

```powershell
git clone <repository-url>
Set-Location LocalAI
```

If the project is already on the machine, just change to its root directory:

```powershell
Set-Location E:\LocalAI
```

## Configure the environment

Create the local `.env` file from the checked-in defaults. `.env` is ignored by Git and must not be committed.

```powershell
Copy-Item env_defaults .env
```

Edit `.env` if the default web port, database names, or CORS origins need to change. The default Open WebUI address is:

- http://localhost

If port 80 is already in use, set `WEBUI_PORT` in `.env` to another host port, such as `3000`.

## Create database secrets

Create both secret files referenced by `docker-compose.yaml`. Use different strong passwords for the two databases. Do not commit these files.

Create the directory, then create each file with a text editor and enter only the password on one line:

```text
secrets/webui_postgres_password.txt
secrets/localai_postgres_password.txt
```

On PowerShell, create the directory with:

```powershell
New-Item -ItemType Directory -Force secrets | Out-Null
```

Do not add quotes or a label such as `PASSWORD=`. Keep these files local.

## Check the PostgreSQL initialization script

The compose file mounts `postgres/init-localai-db.sh` into the PostgreSQL container. That path must be a readable shell script file, not a directory. Make sure the repository contains that file before starting the stack.

The script is run only when the PostgreSQL data volume is initialized for the first time. Changes to it will not affect an existing database volume unless that volume is recreated.

## Start the services

From the directory containing `docker-compose.yaml`, start the stack in the background:

```powershell
docker compose up -d
```

Check service status and logs:

```powershell
docker compose ps
docker compose logs -f postgres localai open-webui
```

Open WebUI at http://localhost, or at `http://localhost:<WEBUI_PORT>` if you changed `WEBUI_PORT`. Create the initial Open WebUI account when prompted.

LocalAI's API is available at http://localhost:8080. Open WebUI is configured to use it automatically.

## Download models

Models are intentionally not included in this repository. Use Open WebUI or the LocalAI model management interface to download models into the mounted `models` directory. The directory may be empty on first startup.

Model files can be large, so make sure the host has sufficient disk space. Downloaded models and runtime data are ignored by Git.

The CUDA 12 `llama-cpp` backend is installed automatically into the persistent `localai-backends` Docker volume on first startup. The initial installation downloads the backend and may take several minutes. Later starts reuse that volume.

## Stop and restart

Stop the containers without deleting their data:

```powershell
docker compose down
```

Start them again:

```powershell
docker compose up -d
```

To follow logs while troubleshooting:

```powershell
docker compose logs -f
```

## Update Open WebUI

The Open WebUI notification refers to the application image, so update it through Docker Compose rather than from inside the web application. The compose file currently uses the moving `main` image tag:

```yaml
image: ghcr.io/open-webui/open-webui:main
```

Before updating, make a database backup. Open WebUI data is stored in the PostgreSQL `webui` database, and the update may run database migrations:

```powershell
New-Item -ItemType Directory -Force backups | Out-Null
docker compose exec -T postgres pg_dump -U webui -d webui > backups/webui-before-update.sql
```

Update only Open WebUI:

```powershell
docker compose pull open-webui
docker compose up -d --no-deps open-webui
```

The container is recreated, but the `open-webui` named volume and PostgreSQL database are preserved. Confirm that the service is healthy and inspect its logs:

```powershell
docker compose ps open-webui
docker compose logs --tail=100 open-webui
```

Then reload http://localhost and confirm that users, chats, settings, and the LocalAI connection are available. Do not use `docker compose down -v` for this update; it deletes the database and Open WebUI volumes.

For predictable deployments, replace `main` with a tested release tag in `docker-compose.yaml`, for example:

```yaml
image: ghcr.io/open-webui/open-webui:v0.11.1
```

After changing the tag, run the same `pull` and `up -d --no-deps open-webui` commands. Pinning a release avoids receiving unplanned changes from the moving `main` tag. If an update causes a problem, stop Open WebUI, restore the previous image tag, and restore `backups/webui-before-update.sql` only if the newer image changed the database schema and the previous version cannot read it.

## Update the complete stack

Only update LocalAI or PostgreSQL after reviewing their release notes and creating backups. To pull all configured images and recreate changed services:

```powershell
docker compose pull
docker compose up -d
```

This does not delete named volumes, but it can update more than Open WebUI. Check all services afterward:

```powershell
docker compose ps
```

## Reset all application data

This removes the PostgreSQL and Open WebUI Docker volumes. It permanently deletes database data, Open WebUI users/settings, and LocalAI agent-pool data.

```powershell
docker compose down -v
```

Downloaded files in `models` and host data in `data` are separate bind-mounted directories and must be removed separately if a complete reset is required.

## Preserve and move the database

The PostgreSQL and Open WebUI data live in Docker named volumes. `docker compose down` does not remove them, but the volumes are local to the current Docker installation and are not transferred through Git.

Create portable SQL backups before moving, resetting, or changing the setup. Docker Desktop must be running and the PostgreSQL service must be healthy:

```powershell
New-Item -ItemType Directory -Force backups | Out-Null
docker compose exec -T postgres pg_dumpall -U webui --globals-only > backups/postgres-roles.sql
docker compose exec -T postgres pg_dump -U webui -d webui > backups/webui.sql
docker compose exec -T postgres pg_dump -U webui -d localai_memory > backups/localai_memory.sql
```

The `backups/` directory is ignored by Git. Store these files separately and protect them because database dumps can contain users, conversations, configuration, and other private data.

On another machine, first complete the normal setup, create the secret files, and start PostgreSQL once so the databases and roles exist. Stop the application services while restoring:

```powershell
docker compose stop localai open-webui
Get-Content backups/postgres-roles.sql | docker compose exec -T postgres psql -U webui -d postgres
Get-Content backups/webui.sql | docker compose exec -T postgres psql -U webui -d webui
Get-Content backups/localai_memory.sql | docker compose exec -T postgres psql -U webui -d localai_memory
docker compose start localai open-webui
```

Do not run `docker compose down -v` until you have verified the backups. That command deletes the named volumes and cannot be undone by Git.

## Repository and secret safety

The following files and directories are local-only and must not be committed:

- `.env`
- `secrets/*.txt`
- downloaded files under `models/`
- runtime files under `data/`
- Python virtual environments under `backends/**/venv/`

Before committing configuration, remove passwords and connection strings containing passwords from `configuration/runtime_settings.json`. Use new database passwords on every machine.
