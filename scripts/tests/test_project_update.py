import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("rivet_update", Path(__file__).resolve().parents[1] / "update-project.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ProjectUpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source, self.target = self.root / "nouvelle version", self.root / "mon projet signé"
        self.source.mkdir(); self.target.mkdir()
        self.project = self.target / "NicoMirror.xcodeproj/project.pbxproj"
        self.project.parent.mkdir()
        self.project.write_text("PBXFileSystemSynchronizedRootGroup; DEVELOPMENT_TEAM = KEEP_ME;")
        (self.target / "KoveMirror/Connection").mkdir(parents=True)
        (self.target / "KoveMirror/Connection/BleController.swift").write_text("old controller")
        (self.target / "KoveMirror/KoveMirror.entitlements").write_text("keep entitlements")
        self.entries = []

    def add(self, name, new, old=None, mode="copy"):
        src = self.source / name
        src.parent.mkdir(parents=True, exist_ok=True)
        src.write_bytes(new)
        if old is not None:
            dst = self.target / name
            dst.parent.mkdir(parents=True, exist_ok=True); dst.write_bytes(old)
        self.entries.append({"path": name, "sha256": hashlib.sha256(new).hexdigest(), "mode": mode})

    def run_update(self):
        (self.source / "MISE_A_JOUR.json").write_text(json.dumps({"files": self.entries}))
        return MODULE.update_project(self.source, self.target)

    def test_updates_files_and_backs_up_without_changing_signing(self):
        original_project = self.project.read_bytes()
        self.add("KoveMirror/Connection/BleController.swift", b"new controller", b"old controller")
        self.add("KoveMirror/NewView.swift", b"new view")
        result = self.run_update()
        self.assertEqual(self.project.read_bytes(), original_project)
        self.assertEqual((self.target / "KoveMirror/KoveMirror.entitlements").read_text(), "keep entitlements")
        self.assertEqual((self.target / "KoveMirror/NewView.swift").read_bytes(), b"new view")
        self.assertEqual((Path(result["backup"]) / "KoveMirror/Connection/BleController.swift").read_bytes(), b"old controller")

    def test_merges_query_schemes_and_preserves_existing_identifiers(self):
        before = {"CFBundleIdentifier": "my.actual.bundle", "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mycallback"]}],
                  "LSApplicationQueriesSchemes": ["custom"], "NSCameraUsageDescription": "my text"}
        self.add("KoveMirror/Info.plist", plistlib.dumps({"LSApplicationQueriesSchemes": ["waze", "shortcuts"]}),
                 plistlib.dumps(before), "merge_queries")
        self.run_update()
        after = plistlib.loads((self.target / "KoveMirror/Info.plist").read_bytes())
        self.assertEqual(after["LSApplicationQueriesSchemes"], ["custom", "shortcuts", "waze"])
        for key in before:
            if key != "LSApplicationQueriesSchemes": self.assertEqual(before[key], after[key])

    def test_hash_failure_prevents_all_writes(self):
        self.add("KoveMirror/Connection/BleController.swift", b"new", b"old")
        (self.source / self.entries[0]["path"]).write_bytes(b"changed")
        with self.assertRaises(ValueError): self.run_update()
        self.assertEqual((self.target / self.entries[0]["path"]).read_bytes(), b"old")

    def test_app_settings_merge_keeps_identity_and_existing_background_modes(self):
        before = {"CFBundleDisplayName": "Mon nom", "CFBundleIdentifier": "my.signed.app",
                  "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mycallback"]}],
                  "LSApplicationQueriesSchemes": ["custom"], "UIBackgroundModes": ["audio"],
                  "NSLocationWhenInUseUsageDescription": "Old explanation"}
        incoming = {"CFBundleDisplayName": "Template name", "CFBundleIdentifier": "must.not.copy",
                    "LSApplicationQueriesSchemes": ["waze"],
                    "NSLocationWhenInUseUsageDescription": "Share a position on request",
                    "NSLocationAlwaysAndWhenInUseUsageDescription": "Ride telemetry while locked"}
        self.add("KoveMirror/Info.plist", plistlib.dumps(incoming), plistlib.dumps(before), "merge_app_settings")
        self.run_update()
        after = plistlib.loads((self.target / "KoveMirror/Info.plist").read_bytes())
        for key in ("CFBundleDisplayName", "CFBundleIdentifier", "CFBundleURLTypes"):
            self.assertEqual(after[key], before[key])
        self.assertEqual(after["LSApplicationQueriesSchemes"], ["custom", "waze"])
        self.assertEqual(after["UIBackgroundModes"], ["audio", "bluetooth-central", "location"])
        self.assertTrue(after["UIRequiresPersistentWiFi"])
        self.assertEqual(after["NSLocationWhenInUseUsageDescription"], incoming["NSLocationWhenInUseUsageDescription"])

    def test_hotspot_merge_preserves_custom_groups_and_signing(self):
        before = {"com.apple.security.application-groups": ["group.my.actual.app"],
                  "application-identifier": "ABC123.my.actual.app"}
        source = {"com.apple.developer.networking.HotspotConfiguration": True,
                  "com.apple.security.application-groups": ["group.template.must.not.copy"]}
        self.add("KoveMirror/KoveMirror.entitlements", plistlib.dumps(source),
                 plistlib.dumps(before), "enable_hotspot")
        original = self.project.read_bytes()
        self.run_update()
        after = plistlib.loads((self.target / "KoveMirror/KoveMirror.entitlements").read_bytes())
        self.assertEqual(after, before | {"com.apple.developer.networking.HotspotConfiguration": True})
        self.assertEqual(self.project.read_bytes(), original)

    def test_app_branding_updates_name_and_permission_text_without_changing_identity(self):
        before = {"CFBundleDisplayName": "My previous name", "CFBundleIdentifier": "my.signed.app",
                  "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mycallback"]}],
                  "NSCameraUsageDescription": "Previous app uses the camera",
                  "UIBackgroundModes": ["audio"]}
        incoming = {"CFBundleDisplayName": "Double Interface", "CFBundleIdentifier": "must.not.copy",
                    "CFBundleURLTypes": [{"CFBundleURLSchemes": ["mustnotcopy"]}],
                    "NSCameraUsageDescription": "Double Interface reads the motorcycle QR code"}
        self.add("KoveMirror/Info.plist", plistlib.dumps(incoming), plistlib.dumps(before), "merge_app_branding")
        original = self.project.read_bytes()
        self.run_update()
        after = plistlib.loads((self.target / "KoveMirror/Info.plist").read_bytes())
        self.assertEqual(after["CFBundleDisplayName"], incoming["CFBundleDisplayName"])
        self.assertEqual(after["NSCameraUsageDescription"], incoming["NSCameraUsageDescription"])
        for key in ("CFBundleIdentifier", "CFBundleURLTypes"):
            self.assertEqual(after[key], before[key])
        self.assertIn("audio", after["UIBackgroundModes"])
        self.assertEqual(self.project.read_bytes(), original)

    def test_extension_icon_merge_preserves_name_and_extension_settings(self):
        before = {"CFBundleDisplayName": "My App — screen", "CFBundleIdentifier": "my.actual.extension",
                  "NSExtension": {"NSExtensionPointIdentifier": "com.apple.broadcast-services-upload"}}
        icons = {"CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["RivetIcon60x60"]}},
                 "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["RivetIcon76x76"]}}}
        self.add("Kove broadcast extension/Info.plist", plistlib.dumps(icons),
                 plistlib.dumps(before), "merge_extension_icons")
        self.run_update()
        self.assertEqual(plistlib.loads((self.target / "Kove broadcast extension/Info.plist").read_bytes()), before | icons)

    def test_extension_branding_updates_name_and_icons_without_changing_extension_settings(self):
        before = {"CFBundleDisplayName": "My previous broadcast", "CFBundleIdentifier": "my.signed.extension",
                  "NSExtension": {"NSExtensionPointIdentifier": "com.apple.broadcast-services-upload"}}
        incoming = {"CFBundleDisplayName": "Double Interface", "CFBundleIdentifier": "must.not.copy",
                    "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60"]}},
                    "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon76x76"]}}}
        self.add("Kove broadcast extension/Info.plist", plistlib.dumps(incoming),
                 plistlib.dumps(before), "merge_extension_branding")
        self.run_update()
        after = plistlib.loads((self.target / "Kove broadcast extension/Info.plist").read_bytes())
        self.assertEqual(after, before | {key: value for key, value in incoming.items() if key != "CFBundleIdentifier"})

    def test_project_branding_changes_only_display_names_in_signed_build_settings(self):
        before = ('PBXFileSystemSynchronizedRootGroup; DEVELOPMENT_TEAM = KEEP_ME;\n'
                  '    INFOPLIST_KEY_CFBundleDisplayName = "Old app";\n'
                  '    PRODUCT_BUNDLE_IDENTIFIER = my.signed.app;\n'
                  '    INFOPLIST_KEY_CFBundleDisplayName = "Old broadcast";\n')
        incoming = ('PBXFileSystemSynchronizedRootGroup; DEVELOPMENT_TEAM = MUST_NOT_COPY;\n'
                    '    INFOPLIST_KEY_CFBundleDisplayName = "Double Interface";\n'
                    '    PRODUCT_BUNDLE_IDENTIFIER = must.not.copy;\n')
        self.add("NicoMirror.xcodeproj/project.pbxproj", incoming.encode(), before.encode(), "merge_project_display_name")
        result = self.run_update()
        expected = before.replace('"Old app"', '"Double Interface"').replace('"Old broadcast"', '"Double Interface"')
        self.assertEqual(self.project.read_text(), expected)
        self.assertEqual((self.target / "KoveMirror/KoveMirror.entitlements").read_text(), "keep entitlements")
        self.assertEqual((Path(result["backup"]) / "NicoMirror.xcodeproj/project.pbxproj").read_text(), before)

    def test_inconsistent_project_branding_prevents_all_writes(self):
        original = self.project.read_bytes()
        self.add("KoveMirror/Connection/BleController.swift", b"new", b"old controller")
        incoming = ('INFOPLIST_KEY_CFBundleDisplayName = "One name";\n'
                    'INFOPLIST_KEY_CFBundleDisplayName = "Another name";\n')
        self.add("NicoMirror.xcodeproj/project.pbxproj", incoming.encode(), mode="merge_project_display_name")
        with self.assertRaises(ValueError):
            self.run_update()
        self.assertEqual(self.project.read_bytes(), original)
        self.assertEqual((self.target / "KoveMirror/Connection/BleController.swift").read_bytes(), b"old controller")

    def test_rejects_parent_paths_and_signing_file_replacements(self):
        for name in ["../outside.swift", "KoveMirror/KoveMirror.entitlements", "NicoMirror.xcodeproj/project.pbxproj"]:
            self.entries = [{"path": name, "sha256": "unused"}]
            with self.assertRaises((ValueError, FileNotFoundError)): self.run_update()
        self.assertFalse((self.root / "outside.swift").exists())

    def test_rejects_destination_symlink_outside_project(self):
        outside = self.root / "external"; outside.mkdir()
        (self.target / "linked").symlink_to(outside, target_is_directory=True)
        self.add("linked/new.swift", b"new")
        with self.assertRaises(ValueError): self.run_update()
        self.assertEqual(list(outside.iterdir()), [])

    def test_failed_replace_rolls_back_written_files(self):
        self.add("KoveMirror/Connection/BleController.swift", b"new", b"old")
        self.add("KoveMirror/NewView.swift", b"new view")
        self.add("KoveMirror/LastView.swift", b"last view")
        replace = MODULE.os.replace
        calls = [0]
        def failing_replace(src, dst):
            calls[0] += 1
            if calls[0] == 3: raise OSError("simulated full disk")
            return replace(src, dst)
        with patch.object(MODULE.os, "replace", side_effect=failing_replace):
            with self.assertRaises(OSError): self.run_update()
        self.assertEqual((self.target / "KoveMirror/Connection/BleController.swift").read_bytes(), b"old")
        self.assertFalse((self.target / "KoveMirror/NewView.swift").exists())


if __name__ == "__main__":
    unittest.main()
