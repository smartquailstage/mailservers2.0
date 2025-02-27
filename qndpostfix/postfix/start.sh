#!/bin/bash

# Configuración de las credenciales de PostgreSQL
export PGPASSWORD="Support1719@"
export POSTFIX_DB="QND41DB"
export PPOSTFIX_USER_DB="sqadmindb"
export POSTFIX_DB_HOST="smartquaildb"

VUSER="support"
DOMAIN="smartquail.io"


function log {
  echo "$(date) $ME - $@"
}

function addUserInfo {
  local user_name="support"
  local user_maildir="/home/${user_name}/mail/${DOMAIN}/${VUSER}/Maildir/"

  # Verifica si el usuario ya existe
  if ! id -u "$user_name" &>/dev/null; then
    log "Adding user '${user_name}'"

    # Añade el usuario con un directorio home (el directorio home no será utilizado para el correo)
    useradd --system --home "/home/$user_name" --create-home "$user_name"

    # Crea el directorio de Maildir si no existe
    if [ ! -d "$user_maildir" ]; then
      mkdir -p "$user_maildir/{tmp,new,cur}"

      # Ajusta los permisos del directorio de Maildir
      chown -R vmail:vmail "$user_maildir"
      chmod -R 700 "$user_maildir"

      log "Maildir for user '${user_name}' created at '${user_maildir}'"
    else
      log "Maildir for user '${user_name}' already exists"
    fi

    log "User '${user_name}' added with maildir '${user_maildir}'"
  else
    log "User '${user_name}' already exists"
  fi
}



function createTable {
  local table_name=$1
  local table_sql=$2

  log "Creating ${table_name} table in PostgreSQL..."

  # Check if table exists
  local check_sql="SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table_name}');"
  local table_exists=$(psql -U "$POSTFIX_USER_DB" -d "$POSTFIX_DB" -h "$POSTFIX_DB_HOST" -t -c "$check_sql")

  if [[ "$table_exists" =~ ^t$ ]]; then
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

    INSERT INTO admin (username,password,created,modified,active,superadmin,phone,email_other,token,token_validity) 
    VALUES ('support','ms95355672' ,NOW(),NOW(),TRUE,TRUE,'+593993521262','support@smartquail.io',gen_random_uuid(), NOW() + INTERVAL '24 hours')
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
    sed -i "s|{{ $VAR }}|$VALUE|g" /etc/postfix/*.cf
  done

  if [ -f /overrides/postfix.cf ]; then
    while read -r line; do
      [[ -n "$line" && "$line" != [[:blank:]#]* ]] && postconf -e "$line"
    done < /overrides/postfix.cf
    echo "Loaded '/overrides/postfix.cf'"
  else
    echo "No extra postfix settings loaded because optional '/overrides/postfix.cf' not provided."
  fi

  if ls -A /overrides/*.map 1> /dev/null 2>&1; then
    cp /overrides/*.map /etc/postfix/
    postmap /etc/postfix/*.map
    rm /etc/postfix/*.map
    chown root:root /etc/postfix/*.db
    chmod 0600 /etc/postfix/*.db
    echo "Loaded 'map files'"
  else
    echo "No extra map files loaded because optional '/overrides/*.map' not provided."
  fi
}

function setPermissions {
  # Ensure directories and files have correct permissions
  log "Setting permissions for Postfix directories and files..."

  # Set ownership and permissions for Postfix directories
  chown -R postfix:postfix /var/spool/postfix
  chmod 750 /var/spool/postfix/private
  chmod 750 /var/spool/postfix

  # Set ownership and permissions for Postfix configuration files
  chown -R root:root /etc/postfix
  chmod 640 /etc/postfix/*.cf

  # Set ownership and permissions for mail directories
  chown -R postfix:postfix /home/support/mail/
  chmod 700 /home/support/mail/
}

function serviceStart {
  addUserInfo
  createVirtualTables
  insertInitialData
  serviceConf
  setPermissions
  log "[ Iniciando Postfix... ]"
  /usr/sbin/opendkim -x /etc/opendkim/opendkim.conf 
  /usr/sbin/postfix start-fg
}



serviceStart &>> /proc/1/fd/1
