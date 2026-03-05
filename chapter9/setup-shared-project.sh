#!/bin/bash
# Shared Project Directory Setup - Chapter 9 Exercise
# Usage: sudo bash setup-shared-project.sh <project-name> <group-name>
#
# Creates a shared project directory with proper permissions:
# - SGID so all new files inherit the group
# - Sticky bit so only owners can delete their own files
# - Default ACL for read access by an auditors group
#
# Example: sudo bash setup-shared-project.sh webapp developers

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <project-name> <group-name>"
    echo "Example: $0 webapp developers"
    exit 1
fi

PROJECT="$1"
GROUP="$2"
BASE_DIR="/srv/projects"
PROJECT_DIR="$BASE_DIR/$PROJECT"

# Verify the group exists
if ! getent group "$GROUP" > /dev/null 2>&1; then
    echo "Error: group '$GROUP' does not exist. Create it first with: groupadd $GROUP"
    exit 1
fi

echo "Setting up shared project directory: $PROJECT_DIR"
echo "Group: $GROUP"
echo ""

# Create the directory structure
mkdir -p "$PROJECT_DIR"/{src,docs,configs,scripts}

# Set ownership: root owns, group is the project group
chown -R root:"$GROUP" "$PROJECT_DIR"

# Set permissions:
# - Owner (root): rwx
# - Group: rwx (SGID forces group inheritance)
# - Other: no access
# - SGID (2) + Sticky (1) = 3 prefix
chmod 2770 "$PROJECT_DIR"
chmod -R 2770 "$PROJECT_DIR"/*/

echo "Directory created with SGID + group permissions:"
ls -ld "$PROJECT_DIR"
echo ""

# Set default ACL so new files inherit group rwx
setfacl -d -m g:"$GROUP":rwx "$PROJECT_DIR"
setfacl -d -m o::--- "$PROJECT_DIR"

# If auditors group exists, give read access
if getent group auditors > /dev/null 2>&1; then
    setfacl -R -m g:auditors:r-x "$PROJECT_DIR"
    setfacl -d -m g:auditors:r-x "$PROJECT_DIR"
    echo "Added read access for auditors group"
fi

echo ""
echo "ACLs configured:"
getfacl "$PROJECT_DIR"
echo ""
echo "Done. Members of '$GROUP' can now collaborate in $PROJECT_DIR"
echo "All new files will automatically belong to group '$GROUP'"
echo ""
echo "To add users to the group:"
echo "  sudo usermod -aG $GROUP username"
echo ""
echo "Users must log out and back in for group changes to take effect."
