FROM python:3.11-slim AS base

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY examples/ ./examples/

# Make scripts executable
RUN chmod +x scripts/*.sh src/*.py

# Set Python path
ENV PYTHONPATH=/app/src:$PYTHONPATH

# Default command (can be overridden)
ENTRYPOINT ["python3"]
CMD ["src/update_keepmesignedin.py", "--help"]
