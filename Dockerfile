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
