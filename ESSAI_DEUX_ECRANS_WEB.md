# Essai deux écrans — Waze et Wikiloc sur le Web

## Installation sur ton Mac

1. Ferme l’application sur l’iPhone et décompresse ce nouveau dossier.
2. Dans le dossier, ouvre `Mettre_a_jour_sur_Mac.command`.
3. Choisis ton ancien dossier de projet, celui déjà signé dans Xcode.
4. Branche l’iPhone, garde-le comme destination dans Xcode puis fais **Commande + R**.

La mise à jour sauvegarde le projet existant et conserve ses identifiants de signature.

## Ce qui est ajouté

Sur l’accueil de Double Interface, ouvre **Deux écrans · essai web**.
Deux fenêtres apparaissent immédiatement : Wikiloc en grand, Waze en miniature.
La grande carte occupe tout l’écran, sans cadre ni bande de texte. Le menu
flottant « … » regroupe le choix des cartes, l’actualisation, l’aide et la fermeture.
La miniature reste déplaçable et sa position tient compte de l’encoche et des bords.
La connexion TFT existante est réutilisée ; le contenu de la miniature devient
automatiquement la seule source vidéo de ce mode. Aucun cadrage à régler, aucune
diffusion iOS supplémentaire à démarrer pour ce mode.

- Touche directement la miniature : elle passe en grand, l’autre carte devient
  la miniature et sa source est alors envoyée au TFT.
- Fais glisser la miniature : elle reste dans l’écran. Sa position ne modifie
  pas la source du TFT.
- Les deux sessions web conservent leurs pages pendant les échanges.
- Le grand écran reste utilisable : déplacement de carte, zoom, liens et champs
  que le site permet d’utiliser.
- Le menu « … », puis « Choisir les cartes web », permet de choisir une carte ou de coller un lien/code
  d’intégration de trace Wikiloc. Les réglages ne sont pas envoyés au TFT.
- « Fermer les deux écrans » dans le menu rétablit le mode vidéo précédent.

## Localisation

Les cartes par défaut attendent une position récente de l’iPhone avant de
s’ouvrir autour de celle-ci. Accepter la localisation pendant l’utilisation de
Double Interface avec « Position exacte » activé, puis la demande éventuelle
du site Waze ou Wikiloc.
Les liens de traces déjà choisis ne sont pas remplacés à chaque nouvelle position.

La flèche flottante ouvre la carte du fournisseur autour de la position actuelle.
Elle ouvre les réglages de Double Interface si la localisation a été refusée.
En attente de GPS, « Afficher la carte sans position » permet de consulter la
carte générale. Le menu « … », puis « État et aide », indique la précision reçue.

Ce recentrage à l’ouverture ne constitue pas un guidage continu : l’affichage
du point mobile et le suivi d’une trace dépendent des fonctions du site.

## Portée exacte de l’essai

Il s’agit des **pages et cartes web officielles**, dans deux fenêtres WebKit.
Ce mode n’héberge pas les applications iPhone Waze ou Wikiloc et ne donne pas
leur guidage natif, leur mode hors connexion ou leurs abonnements dans nos fenêtres.
La carte Waze présente le trafic ; le site Wikiloc permet de consulter des traces
selon les fonctions qu’il autorise dans son affichage web. Un lien destiné à
ouvrir l’application iPhone est bloqué avec un message explicite dans cet essai.

Internet est nécessaire : vérifier que l’iPhone garde accès à Internet lorsqu’il
est connecté au Wi-Fi de la moto. Un refus du site, une page de consentement ou
une demande de connexion peuvent apparaître. Aucun contournement n’est installé.

Le flux utilise des instantanés de la fenêtre web miniature, environ deux par
seconde. La miniature n’est pas un faux aperçu. Une date récente signifie qu’une
image a été préparée localement, pas que sa réception sur le TFT a été confirmée.
L’essai demande de garder Double Interface au premier plan et l’iPhone déverrouillé.

## Vérification à faire sur la moto à l’arrêt

1. Ouvrir l’essai : vérifier que le TFT affiche Waze, sans recopier l’accueil.
2. Déplacer/zoomer la grande carte Wikiloc : vérifier que le TFT reste sur Waze.
3. Déplacer la miniature : vérifier que son contenu reste affiché sur le TFT.
4. Toucher la miniature : vérifier que Wikiloc devient la nouvelle source du TFT
   et que Waze reste utilisable en grand sur l’iPhone.
5. Échanger plusieurs fois et ouvrir/fermer les réglages : vérifier que les pages
   restent ouvertes et qu’aucun écran de réglages n’est envoyé au TFT.
6. Fermer puis rouvrir l’essai, interrompre/reconnecter le TFT et tester une perte
   d’Internet. Noter les erreurs réellement affichées.
7. Autoriser la localisation : vérifier le centrage autour du lieu réel dans les
   deux cartes. Tester aussi un refus, puis l’autorisation depuis les réglages.
8. Vérifier le plein écran en portrait et paysage, déplacer la miniature vers les
   bords, puis ouvrir le menu flottant et fermer l’essai.

**Ce dossier n’a pas été compilé avec le SDK Apple, installé sur l’iPhone ou validé
sur le TFT dans l’environnement de préparation.** Les contrôles disponibles sont
décrits dans `VERIFICATION_ESSAI_WEB.json`.

Documentation des affichages intégrés utilisés :
- https://developers.google.com/waze/iframe
- https://help.wikiloc.com/article/259-share-embed-iframe-insert-embed-trail-route-wikiloc-web-blog-digital-online-html
- https://help.wikiloc.com/article/917-activate-location-permissions
- https://developer.apple.com/documentation/webkit/wkuidelegate
