# Double Interface — connexion et retour à l’accueil

## Comportement modifié

- Accueil → TFT Kove → application : une liaison vidéo et une diffusion déjà actives sont réutilisées. L’application choisie s’ouvre directement.
- Si la vidéo reprend, l’ouverture attend le canal vidéo automatiquement. Le téléphone ne doit plus demander de confirmer une connexion déjà établie.
- Si la diffusion complète de l’iPhone n’a pas encore été démarrée, le contrôle de diffusion iOS reste nécessaire. Il n’est pas redemandé à chaque changement d’application dans une diffusion active.
- Le retour iOS en haut à gauche ramène à l’accueil, sans arrêter volontairement la diffusion ou les connexions au TFT.
- La case iPhone ouvre maintenant son propre sélecteur d’applications. Ce choix ne déclenche pas une nouvelle connexion moto.
- Une connexion Bluetooth ou de contrôle déjà active est reconnue pendant l’attente de la vidéo. Elle n’est pas présentée comme une nouvelle association à faire.
- La reprise automatique ne réapplique plus la configuration Wi-Fi enregistrée. Une réapplication peut déclencher une nouvelle autorisation iOS ; elle est réservée au scan d’un QR ou au bouton explicite de nouvelle tentative.
- Les tentatives Bluetooth déjà en cours sont conservées. Une moto est mémorisée après une connexion Bluetooth réussie.

## Deux contenus différents

Le TFT reçoit notre flux H.264 : Double Interface peut donc lui envoyer sa propre vue virtuelle, indépendamment de son accueil affiché sur l’iPhone. Le mode avec vue intégrée sur le TFT conserve cette possibilité.

Le miroir d’une application externe utilise les images visibles de l’iPhone. Revenir à Double Interface ou ouvrir une autre application change aussi ce miroir. Ce correctif ne fournit pas les images d’OsmAnd ou de Waze en arrière-plan et ne présente pas ces applications comme indépendantes du téléphone.

## Installation sur le Mac

1. Décompresser `Double_Interface_source.zip`.
2. Ouvrir `Mettre_a_jour_sur_Mac.command` dans le dossier extrait et choisir le projet habituel déjà signé.
3. Dans Xcode, conserver l’iPhone comme destination et lancer Commande + R.

Le programme de mise à jour conserve les identifiants, l’équipe Apple et les droits de signature existants.

## Validation

Les vérifications réalisables ici portent sur la syntaxe Swift, les fichiers de configuration, l’intégrité de la mise à jour et ses tests Python. Des tests Swift couvrent les étapes de préparation et la conservation d’une liaison existante ; ils nécessitent Swift pour être exécutés.

La compilation iOS et les essais réels iPhone/TFT doivent encore être réalisés sur le Mac et la moto.
