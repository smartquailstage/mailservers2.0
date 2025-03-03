echo "Permissions and ownership have been set."

# Set permissions for Dovecot sockets
echo "Setting permissions for Dovecot sockets..."
chown postfix:postfix /var/run/dovecot/auth-client
chmod 660 /var/run/dovecot/auth-client
chown postfix:postfix /var/run/dovecot/lmtp
chmod 660 /var/run/dovecot/lmtp
