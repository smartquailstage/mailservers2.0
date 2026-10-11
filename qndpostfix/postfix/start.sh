#!/bin/bash
set -e
set -x

# Configuración de las credenciales de PostgreSQL actualizadas al clúster
export PGPASSWORD="ms95355672@"
export POSTFIX_DB="QND041MAILDB"
export POSTFIX_USER_DB="sqadmindb"
export POSTFIX_DB_HOST="smartquaildb"

VUSER="support"
DOMAIN="smartquail.io"
ME=$(basename "$0")

function log {
    echo "$(date) $ME - $@"
}

function createTable {
  local table_name=$1
  local table_sql=$2

  log "Creating ${table_name} table in PostgreSQL..."

  # Check if table exists
  local check_sql="SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table_name}');"
  local table_exists=$(psql -U "$POSTFIX_USER_DB" -d "$POSTFIX_DB" -h "$POSTFIX_DB_HOST" -t -c "$check_sql" | tr -d '[:space:]')

  if [[ "$table_exists" == "t" ]]; then
    log "Table ${table_name} already exists, skipping creation."
  else
    psql -U "$POSTFIX_USER_DB" -d "$POSTFIX_DB" -h "$POSTFIX_DB_HOST" -c "$table_sql"
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
    ((SELECT id FROM virtual_domains WHERE domain = 'smartquail.io'), 'support@mail.smartquail.io', 'support') 
    ON CONFLICT DO NOTHING;
  "

  psql -U "$POSTFIX_USER_DB" -d "$POSTFIX_DB" -h "$POSTFIX_DB_HOST" -c "$insert_sql"

  if [ $? -eq 0 ]; then
    log "Initial data inserted successfully."
  else
    log "Failed to insert initial data."
  fi
}

function serviceConf {
  if [[ ! $HOSTNAME =~ \. ]]; then
    HOSTNAME="$HOSTNAME.$DOMAIN"
  fi

  for VARIABLE in $(env | cut -f1 -d=); do
    VAR=${VARIABLE//:/_}
    VALUE=${!VAR}
    # Solo reemplaza si el archivo es escribible localmente
    sed -i "s|{{ $VAR }}|$VALUE|g" /etc/postfix/*.cf 2>/dev/null || true
  done

  if [ -f /overrides/postfix.cf ]; then
    while read -r line; do
      [[ -n "$line" && "$line" != [[:blank:]#]* ]] && postconf -e "$line"
    done < /overrides/postfix.cf
    echo "Loaded '/overrides/postfix.cf'"
  else
    echo "No extra postfix settings loaded because optional '/overrides/postfix.cf' not provided."
  fi
}

function serviceStart {
  createVirtualTables
  insertInitialData
  serviceConf
  
  log "[ Iniciando Postfix... ]"
  
  # Limpiar archivos de bloqueo previos si existen por reinicios forzados
  rm -f /var/spool/postfix/pid/*.pid
  
  # Iniciar Postfix en segundo plano y mantener vivo el contenedor redirigiendo logs
  postfix start
  sleep 2
  
  tail -f /var/log/mail.log /var/log/maillog 2>/dev/null || tail -f /dev/null
}

# Ejecuta y redirige logs al stdout del contenedor
serviceStart >> /proc/1/fd/1 2>&1