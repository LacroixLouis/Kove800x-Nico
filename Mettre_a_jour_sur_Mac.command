#!/bin/bash
set -euo pipefail
task_update_folder="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
    echo "Cette mise à jour s’applique sur ton Mac."
    exit 1
fi
if ! task_project_folder="$(osascript -e 'POSIX path of (choose folder with prompt "Choisis ton ANCIEN dossier de projet Kove, qui contient NicoMirror.xcodeproj. Ses réglages de signature seront conservés.")')"; then
    exit 0
fi
python3 "$task_update_folder/scripts/update-project.py" "$task_project_folder" --source "$task_update_folder"
open -a Xcode "$task_project_folder/NicoMirror.xcodeproj"
echo "Branche ton iPhone, puis fais Commande + R dans Xcode."
