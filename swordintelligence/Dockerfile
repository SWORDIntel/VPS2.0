# Dockerfile for SWORDINTELLIGENCE
# Auto-pulls from https://github.com/SWORDOps/SWORDINTELLIGENCE

ARG DOTNET_VERSION=8.0

# Build stage
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
WORKDIR /src

# Build argument for repository URL
ARG REPO_URL=https://github.com/SWORDOps/SWORDINTELLIGENCE.git

# Clone the repository
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone ${REPO_URL} .

# Restore dependencies
RUN dotnet restore "SWORDINTELLIGENCE.csproj" || dotnet restore "*.csproj" || echo "No .csproj found, using directory"

# Build the application
RUN dotnet build -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS final
WORKDIR /app

# Install additional tools for intelligence operations
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    python3 \
    python3-pip \
    libgdiplus \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -u 1000 -s /bin/bash appuser && \
    chown -R appuser:appuser /app

# Copy published application
COPY --from=publish --chown=appuser:appuser /app/publish .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Entry point
ENTRYPOINT ["dotnet", "SWORDINTELLIGENCE.dll"]
