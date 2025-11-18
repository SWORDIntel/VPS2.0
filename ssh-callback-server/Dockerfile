FROM python:3.11-alpine

LABEL maintainer="SWORDIntel"
LABEL description="POLYGOTTEM SSH Callback Server - Lightweight callback verification"

# Install dependencies
RUN apk add --no-cache \
    sqlite \
    curl \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Create data directory
RUN mkdir -p /data && chmod 777 /data

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Expose port
EXPOSE 5000

# Run as non-root user
RUN adduser -D -u 1000 callback && chown -R callback:callback /app /data
USER callback

# Start application
CMD ["python", "app.py"]
