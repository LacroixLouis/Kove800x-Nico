# Reprise de Double Interface pour Louis

Bonjour Louis,

Nicolas te transmet le projet complet pour que tu puisses le reprendre dans GitHub.
La dernière révision ajoute le plein écran et corrige le centrage initial sur la
position de l’iPhone.

## Importer dans GitHub

Décompresser et utiliser **le contenu du dossier `Double_Interface` comme racine du dépôt**.
Le dossier caché `.github` doit être à cette racine pour que GitHub détecte le workflow.
Déposer seulement le ZIP dans le dépôt ne permet pas de lancer le workflow.

Dans un dépôt GitHub vide que tu as créé, depuis le dossier `Double_Interface` :

```sh
git init -b main
git add .
git commit -m "Import Double Interface"
git remote add origin URL_DU_DEPOT_GITHUB
git push -u origin main
```

Remplacer `URL_DU_DEPOT_GITHUB` par l’URL réelle du dépôt.
L’archive ne contient pas d’historique Git local.

## Ouvrir et construire

Sur Mac avec Xcode compatible iOS 26 ou supérieur :

```sh
open NicoMirror.xcodeproj
```

Schéma partagé : **NicoMirror**. Cible principale : **KoveMirror**.
Ces noms internes sont conservés ; l’application s’affiche comme **Double Interface**.

```sh
# Tests des scripts
python3 -m unittest discover -s scripts/tests -v

# Tests Swift portables, avec Swift installé
swift test

# Construction iOS sans signature, avec Xcode sur Mac
bash scripts/build-ios.sh
```

Après l’import sur la branche par défaut, ouvrir **Actions**, sélectionner
**Vérifier Double Interface**, puis **Run workflow**.
Le workflow utilise macOS et lance le script de construction. Il n’a pas été exécuté
pour cette livraison. L’archive produite est non signée et demande une signature
avant installation.

Pour installer, configurer ton équipe Apple dans Xcode pour l’application et
ses extensions. Aucune équipe Apple n’est préconfigurée.
Les identifiants et l’App Group actuels sont ceux du projet de Nicolas.
Si tu les modifies, garder les références cohérentes dans le projet, les droits
des cibles et le code :

- `NicoMirror.xcodeproj/project.pbxproj`
- `KoveMirror/KoveMirror.entitlements`
- `Kove broadcast extension/Broadcast.entitlements`
- `KoveMirror/SetupViews/KoveScreenPreset.swift`
- `KoveMirror/Connection/BleController.swift`
- `KoveMirrorUploadExtension/SampleHandler.swift`
- `KoveMirror/NavigationAppMenu.swift` pour le choix de l’extension ReplayKit.

Pour développer, ouvrir directement le projet. Le script `Mettre_a_jour_sur_Mac.command`
sert à transférer une mise à jour vers un projet existant déjà signé.

## Repères dans le code

| Fonction | Fichier |
| --- | --- |
| Accueil et lancement des modes | `KoveMirror/ConnectionStatusView.swift` |
| Plein écran, miniature et menu | `KoveMirror/WebCockpitView.swift` |
| Sessions WebKit et réception de position | `KoveMirror/WebCockpitSession.swift` |
| URL des cartes et disposition sauvegardée | `KoveMirror/SetupViews/WebPanelLayout.swift` |
| Instantanés de la miniature et flux H.264 | `KoveMirror/Connection/WebPanelStream.swift` |
| Permissions et mises à jour de position | `KoveMirror/Connection/LocationAndNavigationManager.swift` |
| Connexion et choix de la source vidéo | `KoveMirror/Connection/BleController.swift` |

Le mode web prend des instantanés de la vue WebKit de la miniature environ deux fois
par seconde. Le menu et les réglages ne font pas partie de cette source vidéo.
Une image préparée localement ne prouve pas sa réception sur le compteur.

## Vérifier en priorité

1. Construire et exécuter les tests Swift sur Mac.
2. Vérifier le plein écran et la miniature en portrait et paysage.
3. Autoriser la localisation de Double Interface et la demande éventuelle du site.
4. Vérifier le centrage réel dans Waze et Wikiloc, le refus de localisation, sa
   réactivation dans les réglages et l’utilisation sans position disponible.
5. Ouvrir une trace personnalisée : les nouvelles positions ne doivent pas la remplacer.
6. Sur la moto à l’arrêt, déplacer la miniature et échanger les cartes ; le TFT
   doit afficher le contenu de la miniature.

Les contrôles disponibles figurent dans `VERIFICATION_ESSAI_WEB.json`.
Le centrage et le flux TFT de cette révision n’ont pas été validés ici sur iPhone ou moto.

Le mode à deux cartes affiche les pages web officielles, sans héberger les applications
natives ni leur guidage. Le point de position et le suivi continu dépendent des sites.
Le projet vise le TFT d’origine de la Kove, pas la tablette DMD NOR7E.
La licence MIT de la base et les notices de tiers sont conservées.

