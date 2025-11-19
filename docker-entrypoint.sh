#!/bin/sh

# This script will run as the entrypoint for the Docker container.
# It will first process any .epub files found in the current directory,
# then it will start the web server.

set -e

# For each .epub file in the /app directory...
for epub_file in /app/*.epub; do
  # Check if the file exists to handle the case of no .epub files
  [ -e "$epub_file" ] || continue

  # Construct the expected data directory name
  data_dir="/app/$(basename "$epub_file" .epub)_data"

  # If the corresponding _data directory doesn't already exist, process the book
  if [ ! -d "$data_dir" ]; then
    echo "Processing book: $epub_file"
    uv run reader3.py "$epub_file"
  else
    echo "Book already processed: $epub_file"
  fi
done

echo "Starting web server..."
# The CMD from the Dockerfile will be appended here.
# So we use exec to replace the shell with the server process.
exec "$@"
