#!/usr/bin/env bash

echo "Initializing secure erlang distribution cookie..."
NEW_COOKIE=$(dd if=/dev/urandom bs=1 count=128 2>/dev/null | base64 | sed -e 's/\///g')
sed -e "s/^-setcookie.*/-setcookie $NEW_COOKIE/" -i "insecure" "$VMARGS_PATH"
