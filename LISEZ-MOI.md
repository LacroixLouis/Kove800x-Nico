# Double Interface — applications et diffusion iPhone

Les deux fenêtres s’ouvrent directement. Touche le titre du grand écran ou la barre de titre de la miniature pour choisir. Touche l’image de la miniature pour échanger ; glisse-la pour la déplacer.

## Ouvrir une vraie application

Le choix affiche maintenant **Applications iPhone** avec Waze, Wikiloc, OsmAnd et Plans. Choisir une app ouvre son panneau de diffusion. **Ouvrir Waze / Wikiloc / OsmAnd / Plans** lance l’application sur l’iPhone, même avant de connecter la moto. Une application absente ou un lien refusé affiche un message ; aucun site web n’est ouvert à sa place.

Wikiloc utilise son lien officiel `https://www.wikiloc.com/openApp`, déclaré dans son association d’applications iOS. Waze et OsmAnd utilisent leurs liens d’applications ; Plans utilise MapKit.

## Envoyer cette application au TFT

1. Prépare la connexion au compteur dans **Connexion**.
2. Dans le choix du contenu, touche l’application ou **Écran complet de l’iPhone**.
3. Touche le bouton rond de diffusion iOS, puis confirme **Démarrer la diffusion** dans la fenêtre système.
4. Avec une application choisie, l’ouverture est déclenchée une fois le service de diffusion et le canal vidéo du TFT connectés. Le bouton **Ouvrir…** reste disponible. En mode écran complet sans app choisie, reviens à l’accueil de l’iPhone et ouvre l’app voulue.

Le mode choisi reste l’écran complet lorsque Double Interface passe en arrière-plan. Si la diffusion s’arrête, la sortie se met en pause. Le bouton rond permet aussi d’arrêter la diffusion iOS.

**Ce mode partage l’écran entier du téléphone**, y compris les menus et notifications visibles. Il ne place pas une application externe dans la miniature et ne conserve pas un site web indépendant au TFT pendant l’utilisation d’une autre application sur le téléphone. L’application tierce reste responsable de sa propre autorisation de localisation.

## Revenir aux deux fenêtres

Dans le panneau de diffusion, touche **Reprendre la petite fenêtre sur le TFT**, puis ferme les menus. Les contenus et la position sont conservés. Tu peux aussi sélectionner un site web ou la carte intégrée pour reprendre ce mode. Arrête la diffusion iOS avec le bouton rond lorsqu’elle n’est plus utilisée.

En mode deux fenêtres, seule la miniature est envoyée, à environ deux images par seconde. Les menus restent hors de ce flux. L’envoi de la miniature demande de garder Double Interface au premier plan. Les deux contenus disponibles dans ces fenêtres restent une carte intégrée et un site web Waze ou Wikiloc. La carte intégrée et les sites ne sont pas les applications tierces.

## Mise à jour

Décompresse puis ouvre **Mettre_a_jour_sur_Mac.command** et sélectionne ton projet habituel. Le script sauvegarde les fichiers remplacés et conserve les réglages de signature. Le nouveau fichier PhoneProjectionView.swift est ajouté automatiquement au groupe synchronisé Xcode.

## État des vérifications

Le contrôle de syntaxe Swift et les 22 tests Python des scripts sont exécutés ici. Un essai réel de mise à jour vers un projet copié contrôle l’ajout du fichier et la conservation des identifiants. Les nouveaux tests Swift de sélection du flux sont fournis, mais ne sont pas exécutés sans Swift. La compilation Apple, les ouvertures sur iPhone et la réception vidéo sur le TFT ne sont pas validées dans cet environnement.

La demande complète « app tierce interactive dans une fenêtre + autre contenu dans l’autre » reste **non réalisée**. Ce correctif ajoute l’ouverture des applications et réactive le chemin de diffusion de tout l’iPhone ; il ne déclare pas cette demande complète fonctionnelle.

Voir ATTENTES_DOUBLE_INTERFACE.md et VERIFICATION_ESSAI_WEB.json.

## Sources

- Waze : https://developers.google.com/waze/deeplinks/
- Association Wikiloc : https://www.wikiloc.com/.well-known/apple-app-site-association
- ReplayKit : https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview

Adaptation de KoveMirror, créé par MapaX (Matti Mustonen). Licence MIT et attributions conservées. Application indépendante de Kove, Apple, Waze et Wikiloc.
