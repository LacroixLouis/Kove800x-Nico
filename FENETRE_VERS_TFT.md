# Une fenêtre visible de l’iPhone vers le TFT

Ce mode envoie une zone choisie de l’image de l’iPhone, agrandie au format du compteur. Il fonctionne dans le flux de diffusion de l’écran ; il n’est pas limité à l’image de l’accueil de Double Interface.

## Ce qui est ajouté

- Menu → Cadrage du TFT, également accessible dans Réglages → L’écran du compteur.
- Choix de la position, de la largeur et de la hauteur de la zone. Quatre boutons facilitent le placement dans un coin de l’écran.
- Mémorisation du rectangle et de l’orientation de l’iPhone.
- Recadrage avant compression et mise à la taille réelle du TFT, avec conservation facultative des proportions.
- Transmission du réglage à la diffusion déjà active, sans nouvelle association Bluetooth ou Wi-Fi.
- Aucun retour automatique à une image de l’écran entier si le réglage est invalide, si l’orientation ne correspond plus ou si la diffusion s’arrête.

Le schéma de réglage représente la zone choisie. Il n’est pas présenté comme une capture en direct de l’iPhone.

## Condition nécessaire

L’application à cadrer doit déjà afficher une fenêtre flottante ou une autre zone visible que la diffusion iOS peut capturer. Double Interface ne peut pas créer le mode fenêtre flottante dans une autre application. Cette version ne force donc pas Waze, OsmAnd ou n’importe quel autre GPS à rester visible en miniature.

La présence et le rafraîchissement de cette fenêtre dans la capture doivent être vérifiés sur l’iPhone. Certains contenus peuvent ne pas être capturables. Une fenêtre absente, noire ou figée ne constitue pas un essai réussi.

La navigation propre à Double Interface peut déjà fournir une vue TFT indépendante. Ce mode de cadrage est une autre source vidéo et ne remplace pas cette navigation par l’image d’une application externe masquée.

## Premier essai, moto à l’arrêt

1. Installer cette mise à jour avec `Mettre_a_jour_sur_Mac.command`, puis lancer le projet habituel sur l’iPhone dans Xcode avec Commande + R.
2. Établir la vidéo TFT et démarrer une diffusion iOS avec le service Double Interface. Une diffusion déjà active est conservée.
3. Afficher un contenu qui possède une fenêtre flottante sur cet iPhone. Revenir à Double Interface et vérifier que cette fenêtre reste réellement visible.
4. Ouvrir Menu → Cadrage du TFT et activer « Agrandir une zone de l’écran ».
5. Régler la zone sur la position et la taille de la fenêtre visible. Le repère de cadrage aide à retrouver les dimensions ; il n’analyse pas automatiquement les bords de la fenêtre.
6. Toucher « Appliquer au TFT ». En mode miroir externe, le compteur reçoit maintenant la zone sélectionnée agrandie.
7. Vérifier que le contenu continue de changer sur le TFT pendant l’utilisation d’une autre application sur l’iPhone. Vérifier aussi ce qui se passe si la fenêtre est déplacée ou redimensionnée.
8. Garder la même orientation de l’iPhone. Pour changer d’orientation, régler à nouveau la zone puis relancer la diffusion si elle s’est arrêtée.

Pour reprendre le miroir de l’écran entier, désactiver explicitement « Agrandir une zone de l’écran » puis appliquer.

## Vérifications techniques

Des tests Swift portent sur les coordonnées, les bords, les différentes tailles de téléphone, les orientations, les réglages invalides et la conservation du mode recadré après chargement. Des tests iOS utilisent une image rouge et bleue pour vérifier que seule la moitié choisie remplit la sortie TFT.

Les vérifications de syntaxe et les tests Python de mise à jour peuvent être exécutés ici. Swift et Xcode ne sont pas installés dans cet environnement : les nouveaux tests Swift et iOS doivent encore être exécutés sur le Mac. Aucune compatibilité d’une fenêtre GPS externe avec la capture n’a été confirmée sur matériel.
