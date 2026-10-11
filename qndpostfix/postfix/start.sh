#!/bin/bash
set -e
set -x

ME=$(basename "$0")

# NOTA: Los permisos de /etc/postfix/dynamicmaps.cf y archivos sql
# deben configurarse durante la construcción en el Dockerfile, ya que
# este contenedor se ejecuta como usuario no privilegiado (1001).

export PGPASSWORD="$POSTFIX_PASSWORD_DB"
export PGUSER="$POSTFIX_USER_DB"
export POSTFIX_POSTGRES_DB="$POSTFIX_DB"
export POSTFIX_POSTGRES_USER="$POSTFIX_USER_DB"
export POSTFIX_POSTGRES_HOST="$POSTFIX_DB_HOST"
export DOMAIN="$DOMAIN"
export MAILBOX_SIZE_LIMIT="${MAILBOX_SIZE_LIMIT:-51200000}"

function log {
    echo "$(date) $ME - $@"
}

function createTable {
  local table_name=$1
  local table_sql=$2

  log "Creating ${table_name} table in PostgreSQL..."

  local check_sql="SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table_name}');"
  local table_exists=$(psql -U "$POSTFIX_POSTGRES_USER" -d "$POSTFIX_POSTGRES_DB" -h "$POSTFIX_POSTGRES_HOST" -t -c "$check_sql" | tr -d '[:space:]')

  if [[ "$table_exists" == "t" ]]; then
    log "Table ${table_name} already exists, skipping creation."
  else
    psql -U "$POSTFIX_POSTGRES_USER" -d "$POSTFIX_POSTGRES_DB" -h "$POSTFIX_POSTGRES_HOST" -c "$table_sql"
    if [ $? -eq 0 ]; then
      log "${table_name} table created successfully."
    else
      log "Failed to create ${table_name} table."
    fi
  fi
}

function createVirtualTables {
  createTable "virtual_domains" "CREATE TABLE IF NOT EXISTS virtual_domains (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL UNIQUE
  );"

  createTable "virtual_aliases" "CREATE TABLE IF NOT EXISTS virtual_aliases (
    id SERIAL PRIMARY KEY,
    domain_id INT NOT NULL,
    source VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
  );"

  createTable "virtual_users" "CREATE TABLE IF NOT EXISTS virtual_users (
    id SERIAL PRIMARY KEY,
    domain_id INT NOT NULL,
    password VARCHAR(106) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
  );"
}

function insertInitialData {
  log "Inserting initial data into PostgreSQL tables..."

  local insert_sql="
    INSERT INTO virtual_domains (domain) VALUES
    ('smartquail.io'),
    ('mail.smartquail.io') 
    ON CONFLICT DO NOTHING;

    INSERT INTO virtual_users (domain_id, email, password) VALUES 
    ((SELECT id FROM virtual_domains WHERE domain = 'smartquail.io'), 'support@smartquail.io', 'ms95355672') 
    ON CONFLICT DO NOTHING;

    INSERT INTO virtual_aliases (domain_id, source, destination) VALUES 
    ((SELECT id FROM virtual_domains WHERE domain = 'smartquail.io'), 'support@mail.smartquail.io', 'support@smartquail.io') 
    ON CONFLICT DO NOTHING;
  "

  psql -U "$POSTFIX_POSTGRES_USER" -d "$POSTFIX_POSTGRES_DB" -h "$POSTFIX_POSTGRES_HOST" -c "$insert_sql"

  if [ $? -eq 0 ]; then
    log "Initial data inserted successfully."
  else
    log "Failed to insert initial data."
  fi
}

function serviceStart {
  createVirtualTables
  insertInitialData



  log "[ Iniciando Postfix... ]"

  # Ejecuta Postfix en modo foreground (requerido para contenedor)
  exec /usr/sbin/postfix start-fg
}

# Ejecuta y redirige logs al stdout del contenedor
serviceStart >> /proc/1/fd/1 2>&1