# Double Interface — Cockpit v6.1

Cette version modifie l’application iPhone existante. Le projet Xcode et ses identifiants sont conservés.

## Correction du 20 novembre 2026

- Le carnet reçoit automatiquement le kilométrage total transmis par le compteur en Bluetooth. Il demande une lecture à la connexion, à l’ouverture de l’entretien et au retour dans l’app, puis toutes les deux minutes pendant la connexion. La réponse ODO et le trajet partiel sont traités séparément.
- La dernière lecture et son heure sont enregistrées sur l’iPhone et affichées hors connexion. En attente d’une première réponse, l’écran indique « En attente du compteur ». Le bouton « Actualiser depuis la moto » relance la demande.
- Les sauvegardes précédentes sont compatibles. Le premier kilométrage reçu remplace l’ancienne saisie manuelle. Une lecture qui diminue ou vient d’une autre moto est écartée pour le carnet. Le menu de l’entretien permet d’associer explicitement le carnet à la moto connectée.
- Les réglages, formulaires, pages d’aide, journal, personnalisation des widgets, scanner et commandes de carte utilisent la palette sombre Double Interface. Les cartes intégrées suivent également le mode sombre.
- Les fichiers `.command` de l’archive disposent du droit d’exécution.

Les contrôles de syntaxe et de mise à jour sont exécutés dans cet environnement. Cette correction nécessite encore une compilation sur le Mac et une comparaison du kilométrage reçu avec l’ODO affiché par la Kove.

## Dans cette version

- Accueil sombre avec une identité rallye Double Interface : vert profond, citron et orange, courbes topographiques décoratives, boutons animés et retours tactiles. Les animations respectent Réduire les animations.
- Vraies icônes originales d’OsmAnd, Waze, Wikiloc, Plans et DMD HUB, embarquées pour être visibles hors ligne. Les applications personnelles utilisent leurs initiales : iOS ne fournit pas un catalogue des icônes des apps installées.
- Deux dispositions de cockpit indépendantes. **Menu → Personnaliser le cockpit** affiche les widgets disponibles et permet de les réordonner avec les poignées. **Déplacer les widgets** active aussi le déplacement directement sur l’accueil. Les widgets peuvent être masqués et réaffichés ; chaque disposition est enregistrée.
- Widgets Applications, Météo, Entretien, GPS & fichiers, Connexion, Deux écrans et Carte intégrée. La barre du bas donne toujours accès au cockpit, aux GPS, à l’entretien et aux écrans.
- Météo facultative via Open-Meteo : température, vent en km/h, conditions, jusqu’à six échéances horaires et probabilité de précipitations. L’heure d’actualisation et l’état des données sont indiqués. Une erreur réseau ne fabrique aucune météo. Données de plus de deux heures signalées et exclues de la télémétrie météo du TFT. La météo n’affirme pas être un système officiel d’alerte.
- Entretien avec nom de la moto, kilométrage du compteur synchronisé en Bluetooth, opérations personnalisables, prochaine échéance par kilomètres/date, répétition facultative, historique, coûts exacts en centimes et notes. Huit opérations sont proposées sans intervalle constructeur inventé. Sauvegarde JSON, restauration confirmée et export CSV de l’historique.
- Choix **Français / English / Langue de l’iPhone** dans Menu → Langue et dans Réglages. La langue des écrans principaux, des widgets et de l’entretien change immédiatement sans recréer le contrôleur Bluetooth. Les noms personnels et les notes sont conservés. Les anciennes traductions de la base sont conservées, mais seules les interfaces française et anglaise sont proposées dans ce sélecteur. Les dialogues appartenant à iOS restent pilotés par iOS.

## Installation sur le Mac

1. Décompresser **Kove_Interface_source.zip**.
2. Fermer Xcode puis ouvrir **Mettre_a_jour_sur_Mac.command** et choisir le dossier de ton projet déjà signé. L’outil sauvegarde les anciens fichiers et conserve le projet, les identifiants et les droits de signature.
3. Rouvrir le projet, sélectionner l’iPhone et lancer **Run** dans Xcode.

L’aperçu HTML est une référence visuelle du design, pas une capture de l’application exécutée sur un iPhone.

## Vérification restant sur appareil

La syntaxe Swift et les contrôles de fichiers sont vérifiés ici. Les tests Swift/Xcode nécessitent le Mac. Cette version n’a pas été compilée avec le SDK Apple, signée, installée sur l’iPhone ni testée sur la moto dans cet environnement Linux.

Les deux cockpits sont deux dispositions de l’accueil. Les règles existantes de diffusion ne changent pas : le miroir d’une app externe suit l’écran visible de l’iPhone ; ces widgets ne créent pas un second conteneur pour Waze ou DMD HUB. DMD HUB conserve son ouverture guidée sur l’iPhone.

## Références consultées

- DMD2, dispositions d’accueil : https://docs.dmdnavigation.com/dmdnext/home/
- DMD2, structure : https://docs.dmdnavigation.com/dmdnext/app-structure/
- Beeline, commandes : https://support.beeline.co/en/articles/9389552-device-buttons-user-interface
- Open-Meteo, API : https://open-meteo.com/en/docs
- Provenance des icônes : KoveMirror/ApplicationIconSources.json
