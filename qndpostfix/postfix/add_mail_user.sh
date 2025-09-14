#!/bin/bash

# Definir las variables de conexión a PostgreSQL
POSTGRES_USER="postgres_user"  # Reemplaza con tu usuario de PostgreSQL
POSTGRES_DB="postgres_db"      # Reemplaza con tu nombre de base de datos
POSTGRES_HOST="localhost"      # Si tu PostgreSQL está en el mismo contenedor, puedes usar localhost

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

  local insert_sql="
    INSERT INTO virtual_domains (domain) 
    VALUES ('$domain') 
    ON CONFLICT (domain) DO NOTHING;

    INSERT INTO virtual_users (domain_id, email, password) 
    VALUES 
    ((SELECT id FROM virtual_domains WHERE domain = '$domain'), '$email', '$password') 
    ON CONFLICT (email) DO NOTHING;

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
