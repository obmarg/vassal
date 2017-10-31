#!/usr/bin/env bash

echo "Initializing secure erlang distribution cookie..."
NEW_COOKIE=$(python -c "import base64; import os; rand = os.urandom(64); print(base64.urlsafe_b64encode(os.urandom(64)).replace(b'/', b'_'))")
sed -e "s/^-setcookie.*/-setcookie $NEW_COOKIE/" -i".insecure" "$VMARGS_PATH"
