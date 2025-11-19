# Dockerizing the Reader3 Application

This document outlines the process of containerizing the lightweight EPUB reader application, `reader3`, using Docker. The goal was to simplify deployment and usage, ultimately allowing the application to run with a single `docker compose up` command.

## Initial Setup (Before Dockerization)

The `reader3` application initially runs using `uv` to manage dependencies and execute Python scripts.
*   **Processing a book:** `uv run reader3.py dracula.epub` (creates `dracula_data` folder)
*   **Running the server:** `uv run server.py`

## Step 1: Creating Dockerfiles and Docker Compose (Initial Attempt)

To containerize the application, a `Dockerfile` was created to build the image and a `docker-compose.yml` was set up to orchestrate the service.

**Initial `Dockerfile`:**
```dockerfile
# Use the specified Python version
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Install uv
RUN pip install uv

# Copy the dependency files to the working directory
COPY pyproject.toml uv.lock ./

# Install dependencies using uv
RUN uv sync

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 8123

# The command to run the server
CMD ["uv", "run", "server.py"]
```

**Initial `docker-compose.yml`:**
```yaml
services:
  reader3:
    build: .
    ports:
      - "8123:8123"
    volumes:
      - .:/app
```
*(Note: The `version: '3.8'` tag was removed from `docker-compose.yml` as it is obsolete.)*

**Workflow with initial Docker setup:**
*   **Process a book (old command):** `docker compose run --rm reader3 uv run reader3.py your_book.epub`
*   **Start the server:** `docker compose up -d --build`

## Step 2: Addressing "Connection Reset" Error

Upon running the server, a "connection reset" error was encountered. Inspection of the container logs revealed that the `uvicorn` server inside the container was binding to `127.0.0.1` (localhost), making it inaccessible from the host machine.

**Fix:** The `server.py` file was modified to make `uvicorn` listen on `0.0.0.0` (all network interfaces).

**Change in `server.py`:**
```python
# Old:
# uvicorn.run(app, host="127.0.0.1", port=8123)

# New:
import uvicorn # Added this import
uvicorn.run(app, host="0.0.0.0", port=8123)
```
After this change, the container image needed to be rebuilt and restarted.

## Step 3: A More Flexible Approach with an Entrypoint Script

The previous method of baking the book into the image was simple, but inflexible. A superior approach is to use a volume to manage books and an entrypoint script to automatically process them on container startup.

**The Entrypoint Script (`docker-entrypoint.sh`):**

A shell script was created to act as the container's entrypoint. Its logic is as follows:
1.  On startup, scan the `/app` directory for any `*.epub` files.
2.  For each EPUB found, check if a corresponding `*_data` directory already exists.
3.  If the data directory does *not* exist, process the book by running `uv run reader3.py <book.epub>`.
4.  If the data directory *does* exist, skip processing.
5.  After the loop, start the main web server.

```bash
#!/bin/sh
set -e
for epub_file in /app/*.epub; do
  [ -e "$epub_file" ] || continue
  data_dir="/app/$(basename "$epub_file" .epub)_data"
  if [ ! -d "$data_dir" ]; then
    echo "Processing book: $epub_file"
    uv run reader3.py "$epub_file"
  else
    echo "Book already processed: $epub_file"
  fi
done
echo "Starting web server..."
exec "$@"
```

**Changes Made:**
1.  **`Dockerfile` update:** The `RUN` command for processing a specific book was removed. The new `docker-entrypoint.sh` script is copied into the image and set as the `ENTRYPOINT`.
2.  **`docker-compose.yml` update:** The `volumes` section was re-added to mount the host's project directory into the container's `/app` directory.
3.  **`.dockerignore` update:** `*.epub` and `*_data` were re-added to prevent local book files from being copied into the image build, as they are now handled by the volume.

**Final `Dockerfile`:**
```dockerfile
# Use the specified Python version
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Install uv
RUN pip install uv

# Copy the dependency files to the working directory
COPY pyproject.toml uv.lock ./

# Install dependencies using uv
RUN uv sync

# Copy the rest of the application code
COPY . .

# Copy the entrypoint script
COPY docker-entrypoint.sh .

# Expose the port the app runs on
EXPOSE 8123

# Set the entrypoint
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# The command to run the server
CMD ["uv", "run", "server.py"]
```

**Final `docker-compose.yml`:**
```yaml
services:
  reader3:
    build: .
    ports:
      - "8123:8123"
    volumes:
      - .:/app
```

## How to Use (Current State)

This setup provides a simple and powerful workflow for managing your library.

*   **Add Books:** Simply place your `.epub` files in the same directory as the `docker-compose.yml` file.
*   **Build and Run:** `docker compose up -d --build`
    *   On the first run, the entrypoint script will process all found EPUBs.
    *   On subsequent runs, it will only process new EPUBs that you've added.
*   **Access the application:** Open your web browser to `http://localhost:8123`
*   **Stop the application:** `docker compose down`
