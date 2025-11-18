# Dockerfile for HURRICANE - IPv6-over-IPv4 Tunnel Daemon
# Source: https://github.com/SWORDIntel/HURRICANE

FROM debian:12-slim AS builder

# Build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG HURRICANE_VERSION=latest

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    cmake \
    pkg-config \
    libssl-dev \
    libcurl4-openssl-dev \
    libjson-c-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone HURRICANE repository
WORKDIR /build
RUN git clone https://github.com/SWORDIntel/HURRICANE.git .

# Build HURRICANE
RUN mkdir -p build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# Runtime image
FROM debian:12-slim

# Metadata labels
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="SWORDIntel" \
      org.opencontainers.image.url="https://github.com/SWORDIntel/HURRICANE" \
      org.opencontainers.image.source="https://github.com/SWORDIntel/HURRICANE" \
      org.opencontainers.image.version="${HURRICANE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="HURRICANE" \
      org.opencontainers.image.description="IPv6-over-IPv4 tunnel daemon with REST API and SOCKS5 proxy" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    netcat-openbsd \
    # Network tools
    iproute2 \
    iptables \
    iputils-ping \
    traceroute \
    wireguard-tools \
    # Tunnel backends
    openssl \
    libcurl4 \
    libjson-c5 \
    # Monitoring
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries from builder
COPY --from=builder /usr/local/bin/hurricane /usr/local/bin/
COPY --from=builder /usr/local/bin/hurricane-cli /usr/local/bin/
COPY --from=builder /usr/local/lib/libhurricane.* /usr/local/lib/
COPY --from=builder /usr/local/share/hurricane /usr/local/share/hurricane

# Create directories
RUN mkdir -p \
    /etc/hurricane \
    /etc/hurricane/credentials \
    /etc/hurricane/wireguard \
    /var/lib/hurricane \
    /var/log/hurricane \
    /var/run/hurricane

# Create non-root user
RUN useradd -r -u 1000 -U -m -s /bin/bash -d /var/lib/hurricane hurricane && \
    chown -R hurricane:hurricane /etc/hurricane /var/lib/hurricane /var/log/hurricane /var/run/hurricane

# Copy configuration templates
COPY config/hurricane.conf.template /etc/hurricane/
COPY config/tunnels.conf.template /etc/hurricane/
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/healthcheck.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Expose ports
# 8080: REST API
# 8081: Web UI
# 1080: SOCKS5 Proxy
# 9090: Prometheus Metrics
EXPOSE 8080 8081 1080 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Run as non-root user (will need NET_ADMIN capability)
USER hurricane

# Set working directory
WORKDIR /var/lib/hurricane

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["hurricane", "--config", "/etc/hurricane/hurricane.conf", "--daemon=false"]
