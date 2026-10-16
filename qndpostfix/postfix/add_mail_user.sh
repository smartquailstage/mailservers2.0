#!/bin/bash

# Definir las variables de conexión a PostgreSQL usando las variables de entorno
POSTGRES_USER="${POSTFIX_USER_DB}"
POSTGRES_DB="${POSTFIX_DB}"
POSTGRES_HOST="${POSTFIX_DB_HOST}"

# Función para loguear mensajes
log() {
  echo "$(date) - $1"
}

# Función para agregar dominio, usuario y alias sin usar ON CONFLICT
insertData() {
  local domain=$1
  local email=$2
  local password=$3
  local alias=$4

  log "Processing data for $domain and $email..."

  # 1. Verificar o insertar el dominio
  local domain_id
  domain_id=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -t -c "SELECT id FROM virtual_domains WHERE domain = '$domain';" | tr -d ' ')

  if [ -z "$domain_id" ]; then
    log "Inserting new domain: $domain"
    domain_id=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -t -c "INSERT INTO virtual_domains (domain) VALUES ('$domain') RETURNING id;" | tr -d ' ')
  else
    log "Domain $domain already exists (ID: $domain_id)."
  fi

  # 2. Verificar o insertar el usuario
  local user_exists
  user_exists=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -t -c "SELECT COUNT(*) FROM virtual_users WHERE email = '$email';" | tr -d ' ')

  if [ "$user_exists" -eq "0" ]; then
    log "Creating user: $email"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -c "INSERT INTO virtual_users (domain_id, email, password) VALUES ($domain_id, '$email', '$password');"
  else
    log "User $email already exists. Updating password..."
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -c "UPDATE virtual_users SET password = '$password' WHERE email = '$email';"
  fi

  # 3. Verificar o insertar el alias
  local alias_exists
  alias_exists=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -t -c "SELECT COUNT(*) FROM virtual_aliases WHERE source = '$alias';" | tr -d ' ')

  if [ "$alias_exists" -eq "0" ]; then
    log "Creating alias: $alias -> $email"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -c "INSERT INTO virtual_aliases (domain_id, source, destination) VALUES ($domain_id, '$alias', '$email');"
  else
    log "Alias $alias already exists."
  fi

  log "Operation completed successfully for $email."
}

# Verificar que se pasen los parámetros correctos
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <domain> <email> <password> <alias>"
  exit 1
fi

# Obtener los parámetros
DOMAIN=$1
EMAIL=$2
PASSWORD=$3
ALIAS=$4

# Llamar a la función insertData
insertData "$DOMAIN" "$EMAIL" "$PASSWORD" "$ALIAS"