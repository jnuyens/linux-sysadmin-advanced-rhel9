#!/bin/bash
# ssh-agent-autoload.sh - Reload SSH keys after reboot
# Add important keys below. You will be prompted for each passphrase.

echo "Loading SSH keys into agent..."

# Add your keys here:
ssh-add ~/.ssh/id_ed25519
# ssh-add ~/.ssh/id_rsa_webserver
# ssh-add ~/.ssh/id_ed25519_deployment

echo "Done. Loaded keys:"
ssh-add -l
