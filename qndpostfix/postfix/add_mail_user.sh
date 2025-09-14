#!/bin/bash

# Definir las variables de conexión a PostgreSQL usando las variables de entorno
POSTGRES_USER="${POSTFIX_USER_DB}"  # Usando la variable POSTFIX_USER_DB
POSTGRES_DB="${POSTFIX_DB}"         # Usando la variable POSTFIX_DB
POSTGRES_HOST="${POSTFIX_DB_HOST}"  # Usando la variable POSTFIX_DB_HOST

# Función para loguear mensajes
log() {
  echo "$(date) - $1"
}

# Función para agregar dominio, usuario y alias
insertData() {
  local domain=$1
  local email=$2
  local password=$3
  local alias=$4

  log "Inserting data for $domain and $email..."

  # Aquí se implementan las restricciones para evitar duplicados
  local insert_sql="
    -- Insertar dominio, asegurándose de que sea único
    INSERT INTO virtual_domains (domain) 
    VALUES ('$domain') 
    ON CONFLICT (domain) DO NOTHING;

    -- Insertar usuario, asegurándose de que el email sea único
    INSERT INTO virtual_users (domain_id, email, password) 
    VALUES 
    ((SELECT id FROM virtual_domains WHERE domain = '$domain'), '$email', '$password') 
    ON CONFLICT (email) DO NOTHING;

    -- Insertar alias, asegurándose de que el alias sea único
    INSERT INTO virtual_aliases (domain_id, source, destination) 
    VALUES 
    ((SELECT id FROM virtual_domains WHERE domain = '$domain'), '$alias', '$email') 
    ON CONFLICT (source) DO NOTHING;
  "

  # Ejecutar la inserción en la base de datos PostgreSQL
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h "$POSTGRES_HOST" -c "$insert_sql"

  if [ $? -eq 0 ]; then
    log "Data inserted successfully for $email."
  else
    log "Failed to insert data for $email."
  fi
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

# Llamar a la función insertData para agregar la información
insertData "$DOMAIN" "$EMAIL" "$PASSWORD" "$ALIAS"


#./add_mail_user.sh smartquail.io mausilva@smartquail.io ms95355672 mausilva@mail.smartquail.io