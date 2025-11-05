#!/usr/bin/env bash

# Exit on error, undefined variable, or error in a pipeline
set -euo pipefail

# Configuration
USER="${CLOUD_USERNAME}"
SERVER="https://${CLOUD_ADDRESS}"
TARGET="${CLOUD_LOCAL_PATH}"
CREDENTIALS="nextcloud/$USER"

# Check that all required variables are set and non-empty
if [ -z "${USER:-}" ] || [ -z "${SERVER:-}" ] || [ -z "${TARGET:-}" ]; then
  echo "Error: One or more required variables (USER, SERVER, TARGET) are not set or are empty." >&2
  echo "Please ensure all values are initialized (done at initial manual sync)." >&2
  exit 1
fi

# Read password from pass
PASSWORD=$(pass "$CREDENTIALS")
if [ -z "$PASSWORD" ]; then
  echo "Failed to read password from pass ($CREDENTIALS)" >&2
  exit 2
fi

# Create temporary NETRC file for authentication
NETRC="$HOME/.netrc"
trap 'rm -f "$NETRC"' EXIT

# Write credentials to NETRC file
cat > "$HOME/.netrc" <<EOF
default
login $USER
password $PASSWORD
EOF

# Set permissions on NETRC file
chmod 600 "$NETRC"

# Execute NextCloud synch with the provided parameters
exec /usr/bin/nextcloudcmd -n --path / "$TARGET" "$SERVER"
