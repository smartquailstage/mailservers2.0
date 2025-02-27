#!/bin/bash
service postfix start
# Esperar a que Postfix cree los directorios necesarios
sleep 5
service dovecot start
tail -f /var/log/mail.log