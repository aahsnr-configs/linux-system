#!/usr/r/bin/env fish

# Script to set up fisher and install specified fisher plugins.

# --- Functions ---

# Check if a command exists.
function command_exists
    command -v $argv[1] >/dev/null 2>&1
end

# --- Main Logic ---

# Install Fisher if it's not already installed.
if not command_exists fisher
    echo "Installing fisher..."
    # Download and install fisher
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
else
    echo "fisher is already installed."
end
