Looking at your SWORDINTELLIGENCE ASP.NET project, I'll enhance the stack with GitLab and proper ASP.NET hosting capabilities:

## Enhanced Stack with GitLab & ASP.NET Intelligence Platform

### GitLab Infrastructure

**GitLab CE with Integrated CI/CD**
```yaml
# GitLab CE (Community Edition)
gitlab:
  image: gitlab/gitlab-ce:latest
  hostname: gitlab.yourdomain.com
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'https://gitlab.yourdomain.com'
      nginx['enable'] = false  # Using Caddy instead
      gitlab_rails['gitlab_shell_ssh_port'] = 2222
      
      # Performance tuning for single node
      postgresql['shared_buffers'] = "256MB"
      postgresql['max_worker_processes'] = 4
      sidekiq['max_concurrency'] = 15
      
      # Container registry
      registry_external_url 'https://registry.yourdomain.com'
      gitlab_rails['registry_enabled'] = true
      
      # Security
      gitlab_rails['rack_attack_git_basic_auth'] = {
        'enabled' => true,
        'ip_whitelist' => ['127.0.0.1'],
        'maxretry' => 10,
        'findtime' => 60,
        'bantime' => 3600
      }
      
      # SMTP configuration
      gitlab_rails['smtp_enable'] = true
      gitlab_rails['smtp_address'] = "smtp.gmail.com"
      
      # Backup settings
      gitlab_rails['backup_keep_time'] = 604800
      gitlab_rails['backup_upload_connection'] = {
        'provider' => 'Local',
        'local_root' => '/var/opt/gitlab/backups'
      }
      
      # Monitoring
      prometheus['enable'] = true
      grafana['enable'] = false  # Using external Grafana
      
      # Pages for static sites
      pages_external_url 'https://pages.yourdomain.com'
      gitlab_pages['enable'] = true
      
  ports:
    - "2222:22"  # Git SSH
    - "5050:5050"  # Container Registry
  volumes:
    - gitlab_config:/etc/gitlab
    - gitlab_logs:/var/log/gitlab
    - gitlab_data:/var/opt/gitlab
    - ./gitlab/backups:/var/opt/gitlab/backups
  shm_size: '256m'
  
# GitLab Runner for CI/CD
gitlab-runner:
  image: gitlab/gitlab-runner:alpine
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - gitlab_runner_config:/etc/gitlab-runner
  environment:
    - DOCKER_HOST=unix:///var/run/docker.sock
```

### ASP.NET Core Hosting Infrastructure

**SWORDINTELLIGENCE Application Setup**
```yaml
# ASP.NET Runtime Container
swordintelligence:
  build:
    context: ./swordintelligence
    dockerfile: Dockerfile
  image: swordintelligence:latest
  environment:
    ASPNETCORE_ENVIRONMENT: Production
    ASPNETCORE_URLS: http://+:5000
    ConnectionStrings__DefaultConnection: "Server=postgres;Database=swordintel;User Id=swordintel;Password=${DB_PASSWORD};"
    ConnectionStrings__Neo4j: "bolt://neo4j:7687"
    ConnectionStrings__Redis: "redis:6379"
    
    # Security settings
    ASPNETCORE_HTTPS_PORT: 443
    ASPNETCORE_Kestrel__Certificates__Default__Password: "${CERT_PASSWORD}"
    ASPNETCORE_Kestrel__Certificates__Default__Path: /https/aspnetapp.pfx
    
    # Application specific
    JwtSettings__Secret: "${JWT_SECRET}"
    JwtSettings__Issuer: "SWORDINTELLIGENCE"
    JwtSettings__Audience: "SWORDOPS"
    
  volumes:
    - ./swordintelligence/appsettings.Production.json:/app/appsettings.Production.json:ro
    - swordintel_uploads:/app/wwwroot/uploads
    - swordintel_logs:/app/logs
    - ./certs:/https:ro
  depends_on:
    - postgres
    - neo4j
    - redis-stack
  networks:
    - frontend
    - backend
  deploy:
    resources:
      limits:
        memory: 2G
      reservations:
        memory: 512M
```

**Dockerfile for SWORDINTELLIGENCE**
```dockerfile
# Multi-stage build for SWORDINTELLIGENCE
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Clone and build the application
RUN git clone https://github.com/SWORDOps/SWORDINTELLIGENCE.git .

# Restore dependencies
RUN dotnet restore "SWORDINTELLIGENCE.csproj"

# Build
RUN dotnet build "SWORDINTELLIGENCE.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "SWORDINTELLIGENCE.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Final runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install additional tools for intelligence operations
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Security hardening
RUN useradd -m -u 1000 -s /bin/bash appuser && \
    chown -R appuser:appuser /app

COPY --from=publish --chown=appuser:appuser /app/publish .

USER appuser
EXPOSE 5000
ENTRYPOINT ["dotnet", "SWORDINTELLIGENCE.dll"]
```

### GitLab CI/CD Pipeline

**.gitlab-ci.yml for SWORDINTELLIGENCE**
```yaml
stages:
  - build
  - test
  - security
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  LATEST_TAG: $CI_REGISTRY_IMAGE:latest

before_script:
  - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

# Build stage
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $IMAGE_TAG -t $LATEST_TAG .
    - docker push $IMAGE_TAG
    - docker push $LATEST_TAG
  only:
    - main
    - develop

# Test stage
test:
  stage: test
  image: mcr.microsoft.com/dotnet/sdk:8.0
  script:
    - dotnet restore
    - dotnet test --no-restore --verbosity normal
    - dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
  coverage: '/Total\s*\|\s*(\d+\.?\d*)\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.opencover.xml

# Security scanning
security-scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL $IMAGE_TAG
    - trivy fs --security-checks vuln,config .
  allow_failure: false

sast:
  stage: security
  image: mcr.microsoft.com/dotnet/sdk:8.0
  script:
    - dotnet tool install --global security-scan
    - dotnet security-scan .
    
dependency-check:
  stage: security
  image: owasp/dependency-check:latest
  script:
    - /usr/share/dependency-check/bin/dependency-check.sh \
      --scan . \
      --format HTML \
      --project "SWORDINTELLIGENCE"
  artifacts:
    paths:
      - dependency-check-report.html

# Deploy stage
deploy:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker pull $LATEST_TAG
    - docker-compose down swordintelligence
    - docker-compose up -d swordintelligence
    - docker-compose exec -T swordintelligence dotnet ef database update
  environment:
    name: production
    url: https://swordintel.yourdomain.com
  only:
    - main
  when: manual
```

### Enhanced Caddy Configuration with New Services

```caddyfile
# Global options
{
    email admin@yourdomain.com
    
    servers {
        metrics
        protocols h1 h2 h3
    }
    
    # Security headers snippet
    (security) {
        header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            X-Frame-Options DENY
            X-Content-Type-Options nosniff
            X-XSS-Protection "1; mode=block"
            Referrer-Policy strict-origin-when-cross-origin
            Permissions-Policy "geolocation=(), microphone=(), camera=()"
            Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';"
        }
    }
    
    # Rate limiting snippet
    (ratelimit) {
        rate_limit {
            zone dynamic 100r/m
            burst 50
        }
    }
}

# Main domain - SWORDINTELLIGENCE
swordintel.yourdomain.com {
    import security
    import ratelimit
    
    encode gzip zstd
    
    # Handle WebSocket for SignalR
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websockets swordintelligence:5000
    
    # Main application
    reverse_proxy swordintelligence:5000 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        
        # Health checks
        health_uri /health
        health_interval 30s
        health_timeout 5s
        health_status 200
    }
    
    # Static file caching
    @static {
        path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000, immutable"
    
    # API specific settings
    handle_path /api/* {
        rate_limit {
            zone api 30r/m
            burst 10
        }
    }
    
    log {
        output file /logs/swordintel_access.log
        format json
    }
}

# GitLab
gitlab.yourdomain.com {
    import security
    
    encode gzip
    
    reverse_proxy gitlab:80 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        flush_interval -1
        
        # Increase timeouts for Git operations
        transport http {
            dial_timeout 30s
            response_header_timeout 300s
        }
    }
    
    # Git LFS specific
    handle_path /namespace/project.git/info/lfs/* {
        reverse_proxy gitlab:80 {
            transport http {
                response_header_timeout 600s
            }
        }
    }
}

# GitLab Container Registry
registry.yourdomain.com {
    import security
    
    reverse_proxy gitlab:5050 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        
        # Docker client compatibility
        header_down Docker-Distribution-Api-Version "registry/2.0"
    }
    
    # Large layer uploads
    request_body {
        max_size 5GB
    }
}

# GitLab Pages
pages.yourdomain.com {
    import security
    
    reverse_proxy gitlab:8090
}

# Portainer
portainer.yourdomain.com {
    import security
    import ratelimit
    
    reverse_proxy portainer:9000
}

# Grafana
monitoring.yourdomain.com {
    import security
    
    reverse_proxy grafana:3000
}

# MISP
misp.yourdomain.com {
    import security
    
    reverse_proxy misp:443 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
```

### Database Setup for SWORDINTELLIGENCE

```sql
-- PostgreSQL setup for SWORDINTELLIGENCE
CREATE DATABASE swordintel;
CREATE USER swordintel WITH ENCRYPTED PASSWORD 'ChangeMeSecurePassword123!';
GRANT ALL PRIVILEGES ON DATABASE swordintel TO swordintel;

-- Enable required extensions
\c swordintel
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For full-text search
CREATE EXTENSION IF NOT EXISTS "postgis";   -- For geospatial data

-- Audit table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id VARCHAR(255),
    action VARCHAR(100),
    entity_type VARCHAR(100),
    entity_id VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at);
```

### Docker Compose Integration

```yaml
# docker-compose.yml additions
version: '3.9'

services:
  # ... existing services ...
  
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    hostname: gitlab.yourdomain.com
    restart: unless-stopped
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        # ... config from above ...
    ports:
      - "2222:22"
      - "5050:5050"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
      - ./gitlab/backups:/var/opt/gitlab/backups
    networks:
      - frontend
      - backend
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
  
  gitlab-runner:
    image: gitlab/gitlab-runner:alpine
    container_name: gitlab-runner
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - gitlab_runner_config:/etc/gitlab-runner
    networks:
      - backend
    depends_on:
      - gitlab
  
  swordintelligence:
    build:
      context: ./swordintelligence
      dockerfile: Dockerfile
    container_name: swordintelligence
    restart: unless-stopped
    environment:
      # ... environment from above ...
    volumes:
      - ./swordintelligence/appsettings.Production.json:/app/appsettings.Production.json:ro
      - swordintel_uploads:/app/wwwroot/uploads
      - swordintel_logs:/app/logs
      - ./certs:/https:ro
    depends_on:
      - postgres
      - neo4j
      - redis-stack
    networks:
      - frontend
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
  gitlab_runner_config:
  swordintel_uploads:
  swordintel_logs:

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

### Deployment & Maintenance Scripts

**Initial Setup Script**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Setup SWORDINTELLIGENCE deployment
setup_swordintelligence() {
    local -r app_dir="/srv/docker/swordintelligence"
    
    # Clone repository
    git clone https://github.com/SWORDOps/SWORDINTELLIGENCE.git "$app_dir"
    
    # Generate secure passwords
    export DB_PASSWORD=$(openssl rand -base64 32)
    export JWT_SECRET=$(openssl rand -base64 64)
    export CERT_PASSWORD=$(openssl rand -base64 32)
    
    # Create self-signed cert for development
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$app_dir/certs/aspnetapp.key" \
        -out "$app_dir/certs/aspnetapp.crt" \
        -days 365 -nodes \
        -subj "/CN=swordintel.local"
    
    # Convert to PFX for ASP.NET
    openssl pkcs12 -export \
        -out "$app_dir/certs/aspnetapp.pfx" \
        -inkey "$app_dir/certs/aspnetapp.key" \
        -in "$app_dir/certs/aspnetapp.crt" \
        -password "pass:$CERT_PASSWORD"
    
    # Create production config
    cat > "$app_dir/appsettings.Production.json" <<EOF
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=postgres;Database=swordintel;User Id=swordintel;Password=$DB_PASSWORD;",
    "Neo4j": "bolt://neo4j:7687",
    "Redis": "redis:6379"
  },
  "JwtSettings": {
    "Secret": "$JWT_SECRET",
    "Issuer": "SWORDINTELLIGENCE",
    "Audience": "SWORDOPS",
    "TokenLifetime": "01:00:00"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "IntelligenceSettings": {
    "MispUrl": "https://misp:443",
    "MispApiKey": "YOUR_MISP_API_KEY",
    "EnableAutoAnalysis": true,
    "MaxConcurrentAnalysis": 5
  }
}
EOF
    
    # Set permissions
    chmod 600 "$app_dir/appsettings.Production.json"
    chmod 600 "$app_dir/certs"/*
}

# GitLab runner registration
register_gitlab_runner() {
    docker-compose exec gitlab-runner gitlab-runner register \
        --non-interactive \
        --url "https://gitlab.yourdomain.com/" \
        --registration-token "YOUR_REGISTRATION_TOKEN" \
        --executor "docker" \
        --docker-image alpine:latest \
        --description "docker-runner" \
        --maintenance-note "SWORDINTELLIGENCE CI/CD Runner" \
        --tag-list "docker,swordintel" \
        --run-untagged="true" \
        --locked="false" \
        --access-level="not_protected"
}

# Database initialization
init_database() {
    docker-compose exec -T postgres psql -U postgres <<EOF
CREATE DATABASE swordintel;
CREATE USER swordintel WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE swordintel TO swordintel;
\c swordintel
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EOF
}

main() {
    setup_swordintelligence
    docker-compose up -d postgres
    sleep 10
    init_database
    docker-compose up -d
    sleep 30
    register_gitlab_runner
    
    echo "Stack deployed successfully!"
    echo "Access points:"
    echo "  - SWORDINTELLIGENCE: https://swordintel.yourdomain.com"
    echo "  - GitLab: https://gitlab.yourdomain.com"
    echo "  - Portainer: https://portainer.yourdomain.com"
    echo ""
    echo "Default GitLab root password: docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
}

main "$@"
```

**Backup Script**
```bash
#!/usr/bin/env bash
set -euo pipefail

backup_all() {
    local -r backup_dir="/srv/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup databases
    docker-compose exec -T postgres pg_dumpall -U postgres > "$backup_dir/postgres_all.sql"
    docker-compose exec -T neo4j neo4j-admin dump --to="/backups/neo4j.dump"
    
    # Backup GitLab
    docker-compose exec -T gitlab gitlab-backup create
    
    # Backup SWORDINTELLIGENCE uploads
    docker run --rm -v swordintel_uploads:/data -v "$backup_dir":/backup \
        alpine tar czf /backup/swordintel_uploads.tar.gz /data
    
    # Compress everything
    tar czf "$backup_dir.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    echo "Backup completed: $backup_dir.tar.gz"
}

backup_all
```

This integrated solution provides:
- Full GitLab CI/CD for SWORDINTELLIGENCE
- Secure ASP.NET Core hosting environment
- Automated build/test/deploy pipelines
- Integration with your threat intelligence stack
- Caddy-based routing with proper WebSocket support
- Database connectivity for the intelligence platform
- Security scanning in CI/CD pipeline
