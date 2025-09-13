#!/bin/bash
set -e
set -x

ME=$(basename "$0")

# Corregir permisos para evitar que postfix ignore los mapas pgsql
chown root:root /etc/postfix/dynamicmaps.cf
chmod 0644 /etc/postfix/dynamicmaps.cf

chown -R root:root /etc/postfix/dynamicmaps.cf.d/
chmod -R go-w /etc/postfix/dynamicmaps.cf.d/

chown root:root /etc/postfix/sql/virtual_alias_maps.cf
chmod 0600 /etc/postfix/sql/virtual_alias_maps.cf

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

function addUserInfo {
  local user="support"
  local domain="smartquail.io"
  local mail_home="/var/mail/vhosts/${domain}/${user}"
  local user_maildir="${mail_home}/Maildir"

  if ! getent passwd "$user" &>/dev/null; then
    log "Adding user '${user}'"
    adduser --system --home "/nonexistent" --no-create-home "$user"
    mkdir -p "${user_maildir}/tmp" "${user_maildir}/new" "${user_maildir}/cur"
    chown -R vmail:vmail "$mail_home"
    chmod -R 700 "$mail_home"
    log "User '${user}' added with maildir '${user_maildir}'"
  else
    log "User '${user}' already exists"
  fi
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
  addUserInfo
  createVirtualTables
  insertInitialData

  log "[ Verificando o generando clave DKIM... ]"

  DKIM_DOMAIN="smartquail.io"
  DKIM_SELECTOR="default"
  DKIM_KEY_DIR="/etc/opendkim/keys/${DKIM_DOMAIN}"
  DKIM_PRIVATE_KEY="${DKIM_KEY_DIR}/${DKIM_SELECTOR}.private"

  mkdir -p "${DKIM_KEY_DIR}"

  if [ ! -f "${DKIM_PRIVATE_KEY}" ]; then
    log "🔐 Clave DKIM no existe. Generando con opendkim-genkey..."

    cd "${DKIM_KEY_DIR}"
    opendkim-genkey -b 2048 -d "${DKIM_DOMAIN}" -s "${DKIM_SELECTOR}"

    if [ -f "${DKIM_SELECTOR}.private" ]; then
      mv "${DKIM_SELECTOR}.private" "${DKIM_PRIVATE_KEY}"
      chmod 600 "${DKIM_PRIVATE_KEY}"
      chown -R opendkim:opendkim /etc/opendkim
      log "✅ Clave DKIM generada y movida a ${DKIM_PRIVATE_KEY}"
    else
      log "❌ Error: No se generó la clave DKIM correctamente"
      exit 1
    fi
  else
    log "✅ Clave DKIM ya existe en ${DKIM_PRIVATE_KEY}, no se vuelve a generar"
  fi

  log "[ Iniciando OpenDKIM... ]"

  /usr/sbin/opendkim -x /etc/opendkim/opendkim.conf

  if [ $? -ne 0 ]; then
    log "❌ Error al iniciar OpenDKIM"
    exit 1
  else
    log "✅ OpenDKIM iniciado correctamente"
  fi

  # Paso extra: preparar directorio del socket
  SOCKET_DIR="/var/spool/postfix/opendkim"
  SOCKET_PATH="$SOCKET_DIR/opendkim.sock"

  mkdir -p "$SOCKET_DIR"
  chown opendkim:postfix "$SOCKET_DIR"
  chmod 750 "$SOCKET_DIR"

  log "[ Iniciando OpenDKIM... ]"

  /usr/sbin/opendkim -x /etc/opendkim/opendkim.conf

  if [ $? -ne 0 ]; then
    log "❌ Error al iniciar OpenDKIM"
    exit 1
  else
    log "✅ OpenDKIM iniciado correctamente"
  fi

  # Corregir permisos del socket (solo si fue creado correctamente)
  if [ -S "$SOCKET_PATH" ]; then
    chown opendkim:postfix "$SOCKET_PATH"
    chmod 770 "$SOCKET_PATH"
    log "✅ Permisos del socket OpenDKIM corregidos ($SOCKET_PATH)"
  else
    log "⚠️ Socket OpenDKIM no encontrado en $SOCKET_PATH. Asegúrate que la configuración sea correcta."
  fi

  # Verifica configuración de Postfix
  if ! postfix check; then
    log "❌ Postfix configuration check failed!"
    exit 1
  fi

  log "[ Iniciando Postfix... ]"

  # Ejecuta Postfix en modo foreground (requerido para contenedor)
  exec /usr/sbin/postfix start-fg
}


# Ejecuta y redirige logs al stdout del contenedor
serviceStart >> /proc/1/fd/1 2>&1

