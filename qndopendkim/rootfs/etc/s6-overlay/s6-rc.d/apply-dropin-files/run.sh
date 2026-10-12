#!/bin/sh

set -e

DOMAIN="${DOMAIN:-smartquail.io}"
KEYS_DIR="/etc/opendkim/keys/$DOMAIN"
KEY_NAME="default"

# Crear directorio para las claves si no existe
mkdir -p "$KEYS_DIR"
chown -R 90:91 "$KEYS_DIR"
chmod 750 "$KEYS_DIR"

# Verificar si la clave privada ya existe. Si no, generarla.
if [ ! -f "$KEYS_DIR/$KEY_NAME.private" ]; then
  echo "Generando claves DKIM para el dominio $DOMAIN..."
  opendkim-genkey -b 2048 -d "$DOMAIN" -s "$KEY_NAME" -D "$KEYS_DIR"
  echo "Claves DKIM generadas en $KEYS_DIR"
else
  echo "Las claves DKIM ya existen en $KEYS_DIR, no se generarán nuevas."
fi

# Obtener el usuario actual que ejecuta el proceso
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Forzar permisos correctos para el UID de ejecución actual
chown -R "$CURRENT_UID:$CURRENT_GID" "$KEYS_DIR"
chmod 700 "$KEYS_DIR"
chmod 600 "$KEYS_DIR/$KEY_NAME.private"
chmod 644 "$KEYS_DIR/$KEY_NAME.txt"

# Aplicando los archivos .conf de OpenDKIM
for file in /etc/opendkim/conf.d/*.conf; do
  [ -f "$file" ] || continue
  printf "\n\n#\n# %s\n#\n" "$file" >> /etc/opendkim/opendkim.conf
  cat "$file" >> /etc/opendkim/opendkim.conf
done

chown 90:91 /etc/opendkim/opendkim.conf
chmod 644 /etc/opendkim/opendkim.conf

echo "Configuración de OpenDKIM completada."