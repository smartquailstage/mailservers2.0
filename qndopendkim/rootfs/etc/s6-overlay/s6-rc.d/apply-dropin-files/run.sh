#!/bin/sh

set -e

# Variables de entorno
DOMAIN="${DOMAIN:-smartquail.io}"  # Usará smartquail.io si no se define la variable de entorno DOMAIN
KEYS_DIR="/etc/opendkim/keys/$DOMAIN"
KEY_NAME="default"

# Crear directorio para las claves si no existe
mkdir -p "$KEYS_DIR"
chown -R opendkim:opendkim "$KEYS_DIR"
chmod 750 "$KEYS_DIR"

# Verificar si la clave privada ya existe. Si no, generarla.
if [ ! -f "$KEYS_DIR/$KEY_NAME.private" ]; then
  echo "Generando claves DKIM para el dominio $DOMAIN..."
  opendkim-genkey -b 2048 -d "$DOMAIN" -s "$KEY_NAME" -z "$KEY_NAME" -D "$KEYS_DIR"
  chmod 600 "$KEYS_DIR/$KEY_NAME.private"
  chmod 644 "$KEYS_DIR/$KEY_NAME.txt"
  echo "Claves DKIM generadas en $KEYS_DIR"
else
  echo "Las claves DKIM ya existen en $KEYS_DIR, no se generarán nuevas."
fi

# Aplicando los archivos .conf de OpenDKIM
for file in /etc/opendkim/conf.d/*.conf; do
  [ -f "$file" ] || continue
  printf "\n\n#\n# %s\n#\n" "$file" >> /etc/opendkim/opendkim.conf
  cat "$file" >> /etc/opendkim/opendkim.conf
done

# Ajustes de permisos finales para los archivos de configuración
chown opendkim:opendkim /etc/opendkim/opendkim.conf
chmod 644 /etc/opendkim/opendkim.conf

echo "Configuración de OpenDKIM completada."
