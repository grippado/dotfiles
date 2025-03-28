#!/bin/bash

# Load secrets from a separate file that should not be committed
if [ -f "$HOME/.secrets" ]; then
    source "$HOME/.secrets"
else
    echo "Warning: ~/.secrets file not found. Create it to store your secrets."
fi

# Export secrets as environment variables
export GITHUB_REGISTRY_TOKEN="${GITHUB_TOKEN:-}" 