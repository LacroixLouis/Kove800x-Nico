# Double Interface — prototype deux affichages

Sources expérimentales, pas une application installable. Compilation, signature,
encodage en arrière-plan et essai iPhone/TFT non réalisés ici.

## Ce que cette version ajoute

- Import d’un fichier GPX depuis Fichiers (y enregistrer au préalable l’export Wikiloc).
- Lecture des traces et routes, avec séparation des segments ; les waypoints seuls
  ne constituent pas une trace. Maximum : 10 Mo et 30 000 points.
- Conservation locale de la dernière trace ; aucune reprise automatique d’un trajet.
- Suivi du GPS et écart approximatif à la trace, sans recalcul ni annonces de virages.
- Sortie TFT indépendante activée par défaut pour le suivi GPX : elle utilise le
  rendu CPU dédié même quand le téléphone affiche Double Interface au premier plan.
- Boutons pour ouvrir Waze et Plans sur le téléphone pendant ce suivi.
- Nom affiché sur l’iPhone : Double Interface. Les identifiants techniques, App Groups,
  cibles et noms de fichiers restent ceux du projet existant pour conserver la signature.

## Essai à effectuer sur appareil

1. Ouvrir NicoMirror.xcodeproj, schéma NicoMirror. Compiler, signer et installer
   en suivant le guide Mac existant. L’icône installée s’appelle Double Interface.
2. Établir la connexion au TFT et activer la vidéo comme dans la version précédente.
3. Ouvrir la carte intégrée, choisir Importer GPX, puis Suivre la trace.
4. Laisser TFT indépendant (essai) activé. Le TFT doit montrer un panneau dédié
   avec la trace schématique, la position, la vitesse et l’heure du point GPS.
5. Choisir Waze sur iPhone (si installé) ou Plans sur iPhone. Vérifier pendant
   plusieurs minutes en déplacement que l’heure GPS et la position évoluent encore
   sur le TFT pendant que l’iPhone affiche une autre application.
6. Revenir dans Double Interface : la sortie TFT doit rester la même. Arrêter le suivi
   et vérifier le retour au mode vidéo précédent. Tester déconnexion/reconnexion.
7. Si l’image ne s’actualise pas, consulter le diagnostic et relever l’erreur.
   Une image fixe ou un Bluetooth connecté ne valide pas le fonctionnement.

## Limites précises

Le contenu du TFT est la trace calculée et dessinée par Double Interface, pas une
instance d’OsmAnd, Waze ou Wikiloc déplacée sur un second écran. Le lanceur
personnalisable de toutes les apps et le déport indépendant d’une app tierce ne
sont pas implémentés. Cette version ne remplit donc pas encore la demande complète.

Le tracé schématique fonctionne sans téléchargement de tuiles ; aucun fond de
carte hors ligne n’est inclus. La carte Apple visible sur l’iPhone peut demander
une connexion. Pas d’estimation de temps ni de distance restante pour le GPX.
Les segments GPX ne fournissent pas d’instructions de virage fiables.

Le flux dépend des événements GPS et de la disponibilité de VideoToolbox et du
réseau en arrière-plan. Aucun timer artificiel ou faux audio n’est utilisé pour
maintenir l’app. Le test sans petite fenêtre est prévu, mais pas encore validé.
Lancer la navigation avant de quitter l’application. Ne pas la forcer à quitter
depuis le sélecteur d’apps pendant l’essai.

## Contrôles ici

Validation syntaxique Swift seulement (tree-sitter), lecture des plists et tests
Python des scripts Mac. Les nouveaux tests Swift de parsing GPX, de distance et
de sélection de sortie sont fournis, mais ne sont pas exécutés sans Swift/Xcode.
Sur Mac : swift test pour les tests portables ; Xcode pour compiler l’application.
