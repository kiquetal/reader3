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

## Step 3: Baking the Book into the Image

The user requested to avoid having to pass arguments or run separate commands for processing EPUBs after starting the Docker Compose services. To achieve this, the book processing step was integrated directly into the Docker image build process.

**Changes Made:**
1.  **`.dockerignore` modification:** Removed `*.epub` from `.dockerignore` to ensure `dracula.epub` is copied into the build context.
2.  **`Dockerfile` update:** Added a `RUN` instruction to execute the book processing script during the image build.
3.  **`docker-compose.yml` update:** Removed the `volumes` section, as the book data is now part of the image itself, eliminating the need for host-to-container volume mapping for books.

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

# Process the book during the build
RUN uv run reader3.py dracula.epub

# Expose the port the app runs on
EXPOSE 8123

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
```

**Trade-offs:**
*   The Docker image size will be larger as it includes the book data.
*   To add a new book, you will need to modify the `Dockerfile` (or add a generic mechanism to it) and rebuild the Docker image.

## How to Use (Current State)

With the finalized Docker setup, interacting with the `reader3` application is streamlined:

*   **Build and Run (old command equivalent):** `docker compose up -d --build`
*   **Access the application:** Open your web browser to `http://localhost:8123`
*   **Stop the application:** `docker compose down`
