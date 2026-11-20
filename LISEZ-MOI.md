> Révision actuelle : lire NOUVEAUTES_V5.md et TESTS_MOTO_9H.md. Les notes plus anciennes ci-dessous ne remplacent pas ces instructions.

# Révision actuelle : interface Double Interface et raccourcis

Commencer par **RIVET_INTERFACE.md**. Sur le Mac, **Mettre_a_jour_sur_Mac.command** met à jour le projet déjà signé sans remplacer ses réglages de signature.

Les documents ci-dessous décrivent des étapes antérieures.

# Version actuelle : connexion Wi-Fi manuelle

Lire **README_WIFI_MANUEL.md**. Cette variante retire les demandes Hotspot et
Access Wi-Fi Information signalées comme non disponibles avec la Personal Team.
Sur iPhone, rejoindre le réseau dans Réglages → Wi-Fi, puis le confirmer dans l’app.
La signature et la compilation doivent être vérifiées dans Xcode.
Les anciennes instructions de connexion automatique ci-dessous sont remplacées.

# Version actuelle : Double Interface

Lire DEUX_ECRANS_GPX.md pour le prototype et ses limites.
Les documents précédents ci-dessous décrivent les étapes antérieures.

> **Version 2 du prototype** : commencer par [DEMARRER_SUR_MAC.md](DEMARRER_SUR_MAC.md).
> Diagnostic partageable, coordination des sources vidéo, reprise H.264 et commandes
> de compilation/installation ajoutés. Voir [CHANGEMENTS_V2.md](CHANGEMENTS_V2.md).
> Compilation iOS et essai Kove non réalisés ici.

> **Nouvelle variante expérimentale** : un rendu de navigation indépendant de l'écran
> a été ajouté pour essayer de transmettre les consignes GPS et un tracé simplifié
> pendant le verrouillage. Il nécessite une navigation lancée dans NicoMirror.
> Ce mode ne recopie pas les autres applications et n'a pas été testé sur appareil.
> Lire [NAVIGATION_VERROUILLEE.md](NAVIGATION_VERROUILLEE.md).

# NicoMirror — Kove 800X Rally

Projet iPhone pour transmettre l’image du téléphone vers **le compteur TFT d’origine de la Kove**, par le protocole ThinkerRide. Il n’est pas destiné au DMD NOR7E. L’application s’installe sur l’iPhone ; le compteur reçoit l’image par son Wi-Fi.

**Ce dossier contient le code source. Il ne contient pas de version iPhone compilée, signée ou installable. La connexion à ta moto n’a pas été testée.**

## Installer une version existante sans Mac

L’auteur de la base KoveMirror publie son application ici :

[Ouvrir l’invitation Kove Mirror dans TestFlight](https://testflight.apple.com/join/H85r5Zrx)

Ouvre le lien sur ton iPhone, accepte l’invitation et utilise le bouton d’installation dans TestFlight. Ce lien appartient au projet d’origine : **il ne distribue pas la version NicoMirror contenue dans ce dossier**. La page d’invitation a été consultée le 19 novembre 2026 et affichait « View Kove Mirror Beta ». La présence d’une version installable et la compatibilité finale se vérifient dans TestFlight puis sur la moto.

## Connexion à la Kove

1. Mets le contact et ouvre le mode navigation du compteur. Pour la 800X Rally, le guide de la base indique de maintenir **SET environ 5 secondes**, puis de choisir la navigation plein écran.
2. Ferme THINKERRIDE pour libérer la liaison Bluetooth.
3. Dans NicoMirror, touche **Scanner le QR code**. Scanne le code de connexion Wi-Fi affiché par le compteur, pas celui qui sert à télécharger THINKERRIDE.
4. Accepte les autorisations iOS de caméra, Bluetooth et réseau local, puis la connexion au Wi-Fi de la moto.
5. Attends la connexion Bluetooth, puis touche **Démarrer le miroir** si l’affichage ne démarre pas automatiquement.
6. Quand NicoMirror apparaît sur le compteur, touche **Diffuser tout l’écran**. Choisis **NicoMirror — écran complet** dans la fenêtre iOS, puis démarre la diffusion.
7. Ouvre l’application à afficher, par exemple Plans, Google Maps ou OsmAnd. Pour terminer, reviens dans NicoMirror et touche **Arrêter le miroir** ; la diffusion peut aussi être arrêtée depuis le contrôle d’enregistrement iOS.

Le profil 800X, repris du projet d’origine, utilise 600 × 1024 pixels. Les marges et les proportions sont réglables. La compatibilité du firmware de ton compteur reste à confirmer lors de l’essai réel.

## Fonctions préparées

- Interface française, nom NicoMirror et réglages 800X sélectionnés par défaut.
- Bouton QR accessible dès l’ouverture, même avant la connexion Bluetooth.
- Lecture des QR ThinkerRide au format `http://g.thinkerride.com/?SSID&MOT_DE_PASSE&ap=1` et des QR Wi-Fi standards WPA.
- Prise en charge des caractères encodés dans le nom ou le mot de passe du réseau.
- Demande native de connexion Wi-Fi, mémorisation du nom du réseau et reconnexion Bluetooth de la base.
- Diffusion de l’écran via ReplayKit, encodage H.264 et liaison locale attendue par le compteur.
- Réglages d’affichage partagés entre l’app et l’extension, et réception des réglages vidéo même quand TCP les découpe en plusieurs morceaux.
- Aucun achat intégré dans cette adaptation. La licence MIT de MapaX est conservée.

Le miroir transmet **l’image**. Il ne transforme pas le compteur en récepteur CarPlay certifié et ne permet pas de contrôler toutes les applications iPhone depuis le guidon. Les contenus qu’iOS protège contre la capture peuvent rester noirs. L’extension n’envoie pas le son ; garde ta liaison audio habituelle avec le téléphone. Le verrouillage réel de l’iPhone peut interrompre la capture : la réduction de luminosité proposée par la base n’équivaut pas à un verrouillage système.

## État de vérification

| Élément | État de cette livraison |
| --- | --- |
| Code source personnalisé | Inclus |
| Analyse syntaxique des sources Swift | Réalisée ; voir `VERIFICATION.json` |
| Structure du projet, plist et schémas Xcode | Vérifiée |
| Tests du QR et du découpage TCP | Inclus ; exécution Swift non réalisée ici |
| Compilation iOS et signature Apple | Non réalisées : Xcode et une identité de signature ne sont pas disponibles dans cet environnement |
| Installation de NicoMirror sur iPhone | Non réalisée |
| Essai sur ta Kove | À réaliser |
| Publication de NicoMirror sur TestFlight | Non réalisée ; aucun code d’invitation NicoMirror n’existe dans cette livraison |

## Compiler la version personnalisée

Le projet complet se trouve dans `NicoMirror.xcodeproj`. Le schéma partagé s’appelle **NicoMirror**. Les noms internes de certains dossiers et de la cible restent KoveMirror pour conserver la structure de la base.

Sur un environnement macOS disposant de Xcode compatible iOS 26 ou supérieur :

```sh
bash scripts/build-ios.sh
```

Le script exécute les tests portables, compile l’app et prépare `build/NicoMirror-non-signe.ipa`. Ce fichier éventuel est **non signé** : il n’est pas installable directement et ne constitue pas une publication TestFlight.

Le fichier `.github/workflows/ios.yml` permet de lancer ces étapes manuellement sur un environnement GitHub Actions macOS, une fois le projet placé dans un dépôt. Ce workflow n’a pas été lancé et aucun dépôt n’a été créé ou publié pour cette livraison. Il ne configure pas de signature et ne dépose rien sur TestFlight.

Pour une installation signée, le responsable de compilation doit sélectionner sa propre équipe Apple pour les cibles, utiliser les identifiants du projet ou ses propres identifiants, et activer les capacités correspondantes. Le projet n’utilise pas l’équipe de signature de l’auteur d’origine.

| Paramètre | Valeur préparée |
| --- | --- |
| App | `com.nicolasrivet.NicoMirror` |
| Extension de diffusion | `com.nicolasrivet.NicoMirror.Kove-broadcast-extension` |
| App Group de l’app et de l’extension | `group.com.nicolasrivet.NicoMirror` |
| URL d’ouverture | `nicomirror://start` |
| Capacités de l’app | Bluetooth en arrière-plan, accès au Wi-Fi, configuration de point d’accès, App Group ; navigation/localisation héritées de la base |

## Origine du code

Base : [MapaX/KoveMirror](https://github.com/MapaX/KoveMirror), licence MIT, Copyright © 2026 MapaX. Le commit exact est indiqué dans `PROVENANCE.json`. Les contributions et la licence de la base restent attribuées à leurs auteurs. NicoMirror est une adaptation personnelle et indépendante.

`UPSTREAM_README.md` conserve la documentation d’origine. Pour l’état réel de cette livraison et ses instructions, utilise le présent document.
