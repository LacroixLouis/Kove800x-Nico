#!/usr/bin/env python3
"""Update an already signed local Xcode project without replacing its signing files."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import tempfile
from datetime import datetime


def safe_path(base, relative):
    name = Path(relative)
    if name.is_absolute() or not name.parts or ".." in name.parts:
        raise ValueError("Chemin de mise à jour invalide.")
    path = base / name
    if not path.resolve().is_relative_to(base.resolve()):
        raise ValueError("Un lien symbolique sort du dossier du projet.")
    return path


def update_project(source, target):
    source, target = Path(source).resolve(), Path(target).resolve()
    if source == target:
        raise ValueError("Ce dossier contient déjà la nouvelle version. Ouvre son projet dans Xcode.")
    project = target / "NicoMirror.xcodeproj/project.pbxproj"
    if not project.is_file() or not (target / "KoveMirror/Connection/BleController.swift").is_file():
        raise ValueError("Choisis le dossier de ton projet existant, celui qui contient NicoMirror.xcodeproj.")
    if "PBXFileSystemSynchronizedRootGroup" not in project.read_text():
        raise ValueError("La structure de ce projet ne permet pas l’ajout automatique des nouveaux fichiers.")
    manifest = json.loads((source / "MISE_A_JOUR.json").read_text())
    plans, seen, planned_modes = [], set(), {}
    for entry in manifest["files"]:
        relative = entry["path"]
        if relative in seen:
            raise ValueError("Fichier dupliqué dans la mise à jour.")
        seen.add(relative)
        mode = entry.get("mode", "copy")
        hotspot_merge = relative == "KoveMirror/KoveMirror.entitlements" and mode == "enable_hotspot"
        project_branding = relative == "NicoMirror.xcodeproj/project.pbxproj" and mode == "merge_project_display_name"
        if (".xcodeproj" in relative and not project_branding) or (relative.endswith(".entitlements") and not hotspot_merge):
            raise ValueError("La mise à jour ne doit pas modifier les identifiants de signature.")
        src, dst = safe_path(source, relative), safe_path(target, relative)
        executable = entry.get("executable", False)
        if not isinstance(executable, bool) or (executable and not relative.endswith((".command", ".sh"))):
            raise ValueError("Le droit d’exécution est réservé aux scripts de lancement.")
        permissions = (dst.stat().st_mode & 0o777) if dst.exists() else 0o644
        planned_modes[relative] = permissions | 0o111 if executable else permissions
        data = src.read_bytes()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError("Le fichier de mise à jour a changé : " + relative)
        if mode in ("merge_queries", "merge_app_settings", "merge_app_branding"):
            existing = plistlib.loads(dst.read_bytes())
            incoming = plistlib.loads(data)
            existing["LSApplicationQueriesSchemes"] = sorted(set(existing.get("LSApplicationQueriesSchemes", []))
                | set(incoming.get("LSApplicationQueriesSchemes", [])))
            if mode in ("merge_app_settings", "merge_app_branding"):
                existing["UIRequiresPersistentWiFi"] = True
                existing["UIBackgroundModes"] = sorted(set(existing.get("UIBackgroundModes", []))
                    | {"location", "bluetooth-central"})
                for key in ("NSLocationAlwaysAndWhenInUseUsageDescription", "NSLocationWhenInUseUsageDescription"):
                    if key in incoming:
                        existing[key] = incoming[key]
            if mode == "merge_app_branding":
                existing["CFBundleDisplayName"] = incoming["CFBundleDisplayName"]
                for key in ("NSBluetoothAlwaysUsageDescription", "NSBluetoothPeripheralUsageDescription",
                            "NSCameraUsageDescription", "NSLocalNetworkUsageDescription"):
                    if key in incoming:
                        existing[key] = incoming[key]
            data = plistlib.dumps(existing, sort_keys=False)
        elif mode == "merge_project_display_name":
            # Merge only this display setting into the signed project. Bundle
            # identifiers, team, targets, capabilities and paths stay intact.
            pattern = re.compile(r'(?m)^(\s*INFOPLIST_KEY_CFBundleDisplayName\s*=\s*)("(?:[^"\\]|\\.)*"|[^;\n]+)(;)')
            names = {match.group(2).strip() for match in pattern.finditer(data.decode("utf-8"))}
            if len(names) != 1:
                raise ValueError("Le nom de l’application doit être unique dans cette mise à jour.")
            name = json.loads(names.pop())
            if not isinstance(name, str) or not name.strip():
                raise ValueError("Le nom de l’application est invalide.")
            quoted_name = json.dumps(name, ensure_ascii=False)
            data = pattern.sub(lambda match: match.group(1) + quoted_name + match.group(3),
                               dst.read_text()).encode("utf-8")
        elif mode == "enable_hotspot":
            if not hotspot_merge:
                raise ValueError("La capacité Wi-Fi ne doit modifier que les droits de l’application principale.")
            # The project may have custom bundle IDs and App Groups. Merge this
            # one requested capability, never copy the template signing rights.
            existing = plistlib.loads(dst.read_bytes())
            if plistlib.loads(data).get("com.apple.developer.networking.HotspotConfiguration") is not True:
                raise ValueError("Capacité de configuration Wi-Fi absente de la mise à jour.")
            existing["com.apple.developer.networking.HotspotConfiguration"] = True
            data = plistlib.dumps(existing, sort_keys=False)
        elif mode in ("merge_extension_icons", "merge_extension_branding"):
            existing = plistlib.loads(dst.read_bytes())
            incoming = plistlib.loads(data)
            for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
                existing[key] = incoming[key]
            if mode == "merge_extension_branding":
                existing["CFBundleDisplayName"] = incoming["CFBundleDisplayName"]
            data = plistlib.dumps(existing, sort_keys=False)
        elif mode == "merge_display_name":
            existing = plistlib.loads(dst.read_bytes())
            existing["CFBundleDisplayName"] = plistlib.loads(data)["CFBundleDisplayName"]
            data = plistlib.dumps(existing, sort_keys=False)
        elif mode != "copy":
            raise ValueError("Type de mise à jour inconnu.")
        plans.append((relative, dst, data))

    for relative in manifest.get("removed_files", []):
        if relative in seen:
            raise ValueError("Suppression dupliquée ou en conflit avec un fichier à copier.")
        seen.add(relative)
        # Only obsolete source/test files may be removed. Signing, project
        # configuration, user documents and data are never deletion targets.
        if not isinstance(relative, str) or not relative.endswith(".swift") or not relative.startswith(
                ("KoveMirror/", "KoveMirrorTests/", "Tests/Connection/")):
            raise ValueError("Suppression réservée aux anciens fichiers source.")
        dst = safe_path(target, relative)
        if dst.exists():
            if not dst.is_file():
                raise ValueError("Une suppression ne doit pas viser un dossier.")
            plans.append((relative, dst, None))

    backup = Path(tempfile.mkdtemp(prefix="Sauvegarde_Double_Interface_" + datetime.now().strftime("%Y%m%d_%H%M%S_"),
                                  dir=target.parent))
    prior = {}
    for relative, dst, _ in plans:
        if dst.exists():
            saved = safe_path(backup, relative)
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, saved)
            prior[relative] = saved
        else:
            prior[relative] = None
    written = []
    try:
        for relative, dst, data in plans:
            if data is None:
                dst.unlink()
                written.append((relative, dst))
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=dst.parent, delete=False) as stream:
                stage = Path(stream.name)
                stream.write(data)
            try:
                os.chmod(stage, planned_modes[relative])
                os.replace(stage, dst)
                written.append((relative, dst))
            finally:
                stage.unlink(missing_ok=True)
    except Exception:
        for relative, dst in reversed(written):
            saved = prior[relative]
            if saved is None:
                dst.unlink(missing_ok=True)
            else:
                shutil.copy2(saved, dst)
        raise
    return {"updated_files": sum(data is not None for _, _, data in plans),
            "removed_files": sum(data is None for _, _, data in plans),
            "backup": str(backup), "project": str(project.parent)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", type=Path)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    try:
        result = update_project(args.source, args.target)
    except Exception as error:
        parser.exit(1, "Mise à jour arrêtée : " + str(error) + "\n")
    print("Mise à jour appliquée : " + str(result["updated_files"]) + " fichiers.")
    print("Anciens fichiers retirés : " + str(result["removed_files"]) + ".")
    print("Sauvegarde de la version précédente : " + result["backup"])
    print("Les identifiants, l’équipe Apple et les groupes partagés ont été conservés.")
    print("Le Wi-Fi peut être associé une fois dans les Réglages de l’iPhone ; ses réglages Apple existants sont conservés.")
    print("Dans Xcode, garde ton iPhone comme destination puis fais Commande + R.")


if __name__ == "__main__":
    main()
