# Agents.md

## Development Workflow

After making any changes to the codebase (HTML templates, Python code, static files), you **must** rebuild and restart the Docker container:

```bash
docker compose down && docker compose up -d
```

If you want to force a complete rebuild without cache:

```bash
docker compose down && docker compose build --no-cache && docker compose up -d
```

**Important:** Simply running `docker compose build` is not enough. The container must be stopped and restarted with `docker compose down && docker compose up -d` to pick up the new image.

## Project Structure

- `app.py` - Flask backend application
- `templates/index.html` - Main HTML template with embedded CSS and JavaScript
- `static/` - Static assets (manifest.json, icon.svg)
- `Dockerfile` - Docker image definition
- `docker-compose.yml` - Docker Compose configuration

## Tech Stack

- Python 3.11 with Flask
- dvgrab for DV capture
- Docker containerization
