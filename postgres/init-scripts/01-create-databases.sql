-- VPS2.0 Database Initialization Script
-- Creates databases and users for all services

-- SWORDINTELLIGENCE Database
CREATE DATABASE swordintel;
CREATE USER swordintel WITH ENCRYPTED PASSWORD :'SWORDINTEL_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE swordintel TO swordintel;

\c swordintel
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- n8n Database
\c postgres
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD :'N8N_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

\c n8n
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- GitLab Database (GitLab will manage its own schema)
\c postgres
CREATE DATABASE gitlab;
CREATE USER gitlab WITH ENCRYPTED PASSWORD :'GITLAB_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE gitlab TO gitlab;
ALTER DATABASE gitlab OWNER TO gitlab;

-- Grant privileges on public schema
\c gitlab
GRANT ALL ON SCHEMA public TO gitlab;

-- Create audit logging table in postgres database
\c postgres
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    database_name VARCHAR(255),
    user_name VARCHAR(255),
    action VARCHAR(100),
    object_type VARCHAR(100),
    object_name VARCHAR(255),
    details JSONB,
    ip_address INET
);

CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_user ON audit_logs(user_name);
CREATE INDEX idx_audit_database ON audit_logs(database_name);

-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create monitoring user
CREATE USER monitoring WITH PASSWORD :'POSTGRES_PASSWORD';
GRANT pg_monitor TO monitoring;
