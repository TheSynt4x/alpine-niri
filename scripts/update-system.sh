#!/bin/sh
# /usr/local/bin/update-system

set -e

echo "--- 1. Updating Alpine Linux (APK) ---"
doas apk update
doas apk upgrade

echo "--- 2. Upgrading Nix Profile (DMS, QuickShell, etc.) ---"
# This is the modern way to upgrade Flake-installed apps
nix profile upgrade --all

echo "--- 3. Updating nixGL Wrapper (Flake Version) ---"
# We switch to the flake version of nixGL to prevent profile conflicts
nix profile add github:nix-community/nixGL --impure

echo "--- 4. Cleaning up old Nix generations ---"
nix-collect-garbage -d

echo "--- 5. Refreshing Font Cache ---"
fc-cache -fv

echo "System update complete!"