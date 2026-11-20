#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Configurer d'abord la signature dans Xcode, comme indiqué dans DEMARRER_SUR_MAC.md."
read -r -p "Team ID Apple (10 caractères) : " signing_team
read -r -p "Identifiant UDID de l'iPhone branché : " target_device
exec bash scripts/build-and-install.sh "$signing_team" "$target_device"
