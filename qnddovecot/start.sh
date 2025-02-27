#!/bin/sh

# Define the user and group
USER="vmail"
GROUP="vmail"

# Define the main directory
MAIL_DIR="/var/mail"


# Create the main mail directory if it doesn't exist
mkdir -p "$MAIL_DIR"

# Adjust ownership and permissions for the main mail directory
echo "Setting permissions and ownership for $MAIL_DIR"
chown -R $USER:$GROUP "$MAIL_DIR"
chmod 750 "$MAIL_DIR"  # Permissions to allow group access and prevent others

# Recursively adjust ownership and permissions for all directories under /var/mail
echo "Setting permissions and ownership for all directories under $MAIL_DIR"
find "$MAIL_DIR" -type d -exec chown $USER:$GROUP {} \; -exec chmod 750 {} \;  # Directories need execute permissions
find "$MAIL_DIR" -type f -exec chown $USER:$GROUP {} \; -exec chmod 640 {} \;  # Files need read and write for owner

# Ensure Maildir structure for the domain (in this case juansilvaphoto.com)
MAILDIR_STRUCTURE="$MAIL_DIR/support@smartquail.io"

# Create the directories only if they do not already exist
echo "Creating Maildir structure if it doesn't exist..."
mkdir -p "$MAILDIR_STRUCTURE/cur" "$MAILDIR_STRUCTURE/new" "$MAILDIR_STRUCTURE/tmp"

# Adjust ownership and permissions for the Maildir structure
echo "Setting permissions and ownership for the Maildir structure: $MAILDIR_STRUCTURE"
chown -R $USER:$GROUP "$MAILDIR_STRUCTURE"
chmod -R 700 "$MAILDIR_STRUCTURE"  # Only owner should have full access

# Set ownership and permissions for subdirectories in Maildir (cur, new, tmp)
echo "Setting permissions for Maildir subdirectories"
find "$MAILDIR_STRUCTURE" -type d -exec chown $USER:$GROUP {} \; -exec chmod 700 {} \;  # Only owner should have full access
find "$MAILDIR_STRUCTURE" -type f -exec chown $USER:$GROUP {} \; -exec chmod 640 {} \;  # Files need read and write for owner

# Verify the results
echo "Verification of permissions and ownership:"
ls -ld "$MAIL_DIR"
ls -ld "$MAILDIR_STRUCTURE"
ls -ld "$MAILDIR_STRUCTURE/cur"
ls -ld "$MAILDIR_STRUCTURE/new"
ls -ld "$MAILDIR_STRUCTURE/tmp"

echo "Permissions and ownership have been set."



# Ensure that Dovecot is running in the foreground (this might be preferred for Docker containers)
exec dovecot -F
