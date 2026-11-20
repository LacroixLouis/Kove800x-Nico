# Essais sur la Kove à 9 h

Préparation sur le Mac, puis manipulations moto à l’arrêt. Une seconde personne observe les essais de déplacement éventuels.

## Installation

1. Mettre à jour le projet déjà signé avec Mettre_a_jour_sur_Mac.command.
2. Dans Xcode, garder l’iPhone comme destination et faire Commande + B, puis Commande + R.
3. Conserver tout message exact en cas d’échec de compilation ou de signature. Ne pas traiter les contrôles Linux comme une compilation iOS.
4. Vérifier l’icône Double Interface, les curseurs et le bouton Mes deux écrans. Activer le journal avant les essais.

## Ordre des contrôles

| Essai | Action | Résultat attendu à observer |
| --- | --- | --- |
| Première association | Contact, mode navigation TFT, association BLE, QR Wi-Fi et accord iOS ou Réglages → Wi-Fi | Bluetooth puis contrôle et vidéo reliés ; réseau enregistré pour une utilisation ultérieure |
| Bon service de partage | Utiliser le bouton rond dans l’app et le nom de service qu’elle indique | Notre extension reçoit les images ; un compteur de diffusion dans MotoMirror ne prouve rien pour NicoMirror |
| Curseurs | Déplacer les marges haute et basse, quitter puis rouvrir les réglages | Valeurs mémorisées ; effet visible sur le TFT ; remise à zéro fonctionnelle |
| Deux vues intégrées | Téléphone = Navigation ; TFT = Compteurs ; changer ensuite le téléphone sur Trace GPX | Le TFT garde les Compteurs ; seuls les boutons TFT changent sa sélection |
| Import GPX | Pendant une route, charger une autre trace dans la vue Trace GPX | La route reste active jusqu’au choix explicite de suivre la nouvelle trace |
| Échange avec les GPS | Mes GPS & mes fichiers → Choisir une trace → Ouvrir dans mon GPS ; choisir un GPS installé, puis partager une position récente | Le GPS choisi reçoit le fichier d’origine ; vérifier points et trace. Le partage de position ne doit pas utiliser une ancienne position ou se lancer tout seul |
| Verrouillage | Avec une vue intégrée sur le TFT, verrouiller pendant 1 min puis 5 min avec de nouveaux points GPS | Contrôle TFT présent, images réellement actualisées et heures GPS cohérentes ; relever séparément les erreurs d’encodage |
| Retour au téléphone | Déverrouiller, changer de vue et revenir au miroir | Reprise sans mélanger les flux ni présenter une autre app comme intégrée |
| Coupure et remise du contact | Couper, attendre la disparition du compteur puis remettre le contact | Reconnexion au périphérique connu ; vérifier aussi le Wi-Fi, puis la vidéo ; répéter 3 fois |
| App externe | Ouvrir une app prise en charge, puis DMD HUB depuis l’accueil si nécessaire | La diffusion suit l’écran du téléphone ; l’indépendance n’est pas attendue pour ces apps |
| GPS absent | Masquer la réception ou utiliser une simulation contrôlée | L’heure du dernier point reste visible ; une position périmée n’est pas présentée comme une position actuelle |

Une image fixe ou un total d’octets n’est pas un succès. À l’arrêt, le GPS peut ne pas produire de nouveau point : utiliser les heures du dernier contrôle et du dernier envoi vidéo pour distinguer la liaison de l’actualisation GPS. Tester le mouvement réel uniquement après les contrôles à l’arrêt.

## Rapport à conserver

Noter modèle de moto, version du TFT, iPhone et iOS, version Xcode, heure du verrouillage, heure de la coupure éventuelle, sélection Téléphone/TFT, présence de la diffusion iOS, dernière heure GPS visible et résultat de chaque contrôle. Partager Menu → Diagnostic et le journal de connexion. Les anciens journaux de la base peuvent contenir des coordonnées ; le rapport JSON actuel exclut coordonnées, mots de passe et identifiants Wi-Fi.

## Feu vert pour la suite

Les fonctions dont l’essai échoue restent marquées expérimentales. Aucune publication commerciale ne doit annoncer le verrouillage, une autre moto ou les apps tierces indépendantes comme acquis sur la seule base de ce code.


## Vérifications téléphone — cockpit v6

1. Vérifier les cinq icônes d’applications et ouvrir le menu de configuration par appui long.
2. Déplacer un widget vers le début puis la fin ; le masquer et le réafficher dans Personnaliser.
3. Configurer différemment Cockpit 1 et Cockpit 2, fermer puis rouvrir l’app : chaque disposition doit être conservée.
4. Activer la météo avec Internet et la localisation. Vérifier température, unités, heure et prévisions. Couper Internet et vérifier l’état d’erreur / anciennes données.
5. Dans Entretien, connecter la Kove et comparer le kilométrage synchronisé avec l’ODO total affiché sur le compteur. Utiliser « Actualiser depuis la moto », puis couper et remettre le contact. Vérifier la dernière lecture horodatée hors connexion et la reprise automatique. Programmer une échéance, enregistrer une intervention avec coût et vérifier l’historique ainsi que le calcul du prochain terme.
6. Exporter la sauvegarde JSON et le CSV, puis vérifier la restauration après confirmation.
7. Passer en anglais puis en français sans interrompre volontairement la liaison TFT. Les vues principales doivent changer de langue et conserver le carnet et les dispositions.
8. Vérifier le plus grand texte d’accessibilité et Réduire les animations.
9. Ouvrir Réglages, Personnaliser le cockpit, Langue, Mes applications, Entretien → Modifier, Échéance et Fait, Aide, À propos, Diagnostic, Journal, scanner QR, carte et recherche de destination. Vérifier les fonds sombres, le contraste des champs et des boutons, puis les feuilles ouvertes depuis ces pages.

Aucun de ces essais sur matériel n’a été exécuté dans l’environnement Linux.

## Reconnexion et choix des applications — correctif du 20 novembre

1. Avec une vidéo TFT et une diffusion iOS actives, toucher TFT Kove sur l’accueil puis une application prise en charge. Elle doit s’ouvrir sans nouvelle étape de connexion.
2. Revenir avec le petit lien iOS en haut à gauche. L’accueil doit réapparaître et la connexion doit rester ouverte. En miroir externe, le TFT suit désormais cet accueil ; il ne continue pas à afficher l’application passée en arrière-plan.
3. Choisir une deuxième application côté TFT pendant la même diffusion. Elle doit s’ouvrir sans nouvelle demande Bluetooth, Wi-Fi ou démarrage de diffusion.
4. Toucher la case iPhone : retrouver un sélecteur d’applications, puis ouvrir l’application choisie sans demande de connexion moto.
5. En mode vue intégrée TFT indépendante, ouvrir une application depuis la case iPhone et revenir à l’accueil. Vérifier que la vue intégrée du TFT est conservée.
6. Arrêter seulement la diffusion iOS, puis sélectionner une application TFT. Le contrôle iOS doit permettre de relancer la diffusion sans demander de refaire l’association moto.
7. Couper puis remettre le contact. Vérifier la reprise de la moto mémorisée sans réapplication automatique de sa configuration Wi-Fi. Si l’iPhone ne rejoint pas son réseau, vérifier Connexion auto dans les Réglages Wi-Fi.
8. Désactiver « Se reconnecter au contact » puis arrêter manuellement la connexion. Revenir à l’accueil ne doit pas annuler cet arrêt ; une action explicite sur une application TFT peut relancer la connexion.

## Fenêtre vers TFT — essais de cadrage

Suivre `FENETRE_VERS_TFT.md`. Vérifier sur l’iPhone que le contenu dispose réellement d’une fenêtre flottante et qu’elle apparaît dans le flux capturé avant de conclure à une compatibilité GPS.

- Choisir successivement une zone en haut puis en bas et vérifier le sens du cadrage.
- Vérifier les quatre coins et les réglages extrêmes de largeur et de hauteur.
- Appliquer un cadrage pendant une diffusion active : la liaison TFT doit rester ouverte.
- Modifier la taille ou déplacer la fenêtre : la zone ne doit pas prétendre suivre automatiquement le contenu.
- Tourner l’iPhone : l’ancienne zone ne doit pas capturer une autre partie de l’écran. Ajuster ensuite le cadrage dans la nouvelle orientation.
- Arrêter la diffusion iOS avec un cadrage actif : le flux doit se mettre en pause et ne pas envoyer l’écran entier de Double Interface.
- Revenir au miroir entier par une action explicite dans Cadrage du TFT.
- Choisir une vue intégrée indépendante : elle doit rester utilisable même si un cadrage est enregistré pour les diffusions externes.
