# Confidentialité — brouillon du prototype Double Interface

Mise à jour : 20 novembre 2026. Ce document remplace la politique de la base pour cette adaptation. L’identité complète de l’éditeur, son contact et une URL publique doivent être renseignés avant publication commerciale.

## Données locales et permissions

- Bluetooth et réseau local : association avec le compteur et échanges de commandes, télémétrie et images. Le miroir transmet au TFT le contenu visible du téléphone, qui peut inclure des notifications et données affichées dans d’autres apps. iOS contrôle le consentement au partage complet.
- Caméra : lecture du QR de connexion et, si l’option est activée, détection de faible lumière pour assombrir le téléphone. Le code ne conserve pas les images de la caméra.
- Localisation : position et vitesse GPS, altitude, carte, navigation et session de trajet lorsque le téléphone est en arrière-plan ou verrouillé. Les autorisations restent contrôlées dans les Réglages iOS.
- Traces : le dernier fichier GPX importé est conservé localement pour pouvoir le retrouver. Ses coordonnées peuvent être précises.
- Wi-Fi : le nom du réseau est conservé dans les préférences. Le mot de passe issu du QR est conservé dans le trousseau local de l’app, avec un accès limité à cet appareil après un premier déverrouillage. Une configuration Wi-Fi persistante peut être ajoutée au système si la signature de l’app et le consentement iOS le permettent.

- Cockpits : les dispositions, les widgets masqués et la langue sont enregistrés dans les préférences locales.
- Entretien : nom de la moto, kilométrage, échéances, coûts et notes sont conservés localement. Le menu permet d’en exporter une sauvegarde ou un historique ; les données ne sont partagées que par l’action choisie par l’utilisateur. La suppression de l’app peut supprimer ce carnet ; une sauvegarde exportée permet sa restauration.
- Icônes d’applications : images embarquées, sans interrogation du catalogue des applications installées ni requête App Store au lancement.

## Réseau et services externes

La liaison vidéo vers le TFT utilise le réseau local. Cela ne signifie pas que toutes les autres fonctions sont hors ligne :

- Les cartes, recherches et itinéraires intégrés utilisent les services Apple MapKit, selon leurs conditions et la disponibilité du réseau.
- La météo est désactivée par défaut. Si elle est activée, une position arrondie à deux décimales est transmise à Open-Meteo, qui reçoit aussi les informations réseau habituelles d’une requête Internet, dont l’adresse IP. Les conditions et prévisions horaires sont mises en cache sans coordonnées, avec leur date d’actualisation. Le widget demande un relevé de position au premier plan ; il ne démarre pas une session de trajet à cet effet. Le fournisseur peut conserver des journaux selon sa propre politique. Ce n’est pas une promesse d’anonymat.
- Les boutons ouvrant d’autres apps donnent accès à leurs propres services et politiques. Cette app ne récupère pas leur contenu indépendamment du mécanisme de partage d’écran fourni par iOS.

La version actuelle n’ajoute pas de publicité ni de suivi analytique commercial. Aucun achat intégré n’est implémenté dans cette adaptation.

## Journaux et rapports

L’enregistrement du journal est facultatif. Il sert au diagnostic des connexions et peut contenir noms de périphériques, événements techniques, altitude, météo et destinations provenant des fonctions de navigation. Les nouvelles requêtes météo n’ajoutent plus les coordonnées aux messages de journal ; les fichiers d’anciennes versions peuvent encore en contenir.

Le rapport JSON actuel exclut les coordonnées, les destinations, les mots de passe Wi-Fi et les identifiants de signature Apple. Il contient les états de connexion et les dates des dernières observations locales. Les journaux ou rapports sont transmis lorsque l’utilisateur choisit de les partager.

## Avant diffusion commerciale

Finaliser l’identité de l’éditeur, le contact, les durées de conservation, les modalités de suppression et les déclarations exigées pour les services réellement utilisés. Ce brouillon ne remplace pas la vérification du binaire et des déclarations App Store.
