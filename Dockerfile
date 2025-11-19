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
