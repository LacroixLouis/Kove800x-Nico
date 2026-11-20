# Version candidate v5 — réunir les GPS et fiabiliser la connexion

Cette archive contient du code source. Elle n’est pas un IPA signé et n’a pas été compilée ou installée dans cet environnement Linux.

Correctif 5.1 : le retour de compilation du Mac a révélé un mauvais libellé dans l’appel FileManager.setAttributes de BleController. Le paramètre est corrigé en ofItemAtPath. La compilation Apple complète reste à relancer sur le Mac.

## Reprendre sur le Mac

1. Décompresser le ZIP.
2. Lancer Mettre_a_jour_sur_Mac.command et choisir le dossier du projet déjà signé.
3. La mise à jour sauvegarde les anciens fichiers et garde les identifiants, les équipes, les droits Apple et le nom existant. Aucun ajout automatique de Hotspot Configuration n’est imposé.
4. Dans Xcode, sélectionner l’iPhone et lancer Commande + R. Voir TESTS_MOTO_9H.md.

## Fonctions ajoutées au code

- Mes GPS & mes fichiers : charger une trace puis l’ouvrir dans un GPS via le partage iOS. Le document GPX d’origine est conservé, avec ses points et ses extensions. Une position GPS récente peut également être partagée. Les applications proposées dépendent des formats qu’elles acceptent ; ces échanges ne les intègrent pas dans notre fenêtre.
- Mes deux écrans : trois vues intégrées et un choix séparé pour le téléphone et le TFT. Le TFT utilise notre rendu CPU, pas une capture d’une autre app. Le rendu de navigation du TFT reste simplifié, sans fond de carte ni noms de rues.
- Charger un GPX pour l’autre vue ne doit plus interrompre une navigation routière en cours. Choisir de suivre ce GPX remplace en revanche l’unique navigation active.
- La perte du Bluetooth ne ferme plus par principe les connexions Wi-Fi actives du TFT. Une reconnexion BLE conserve le statut de projection si le canal TFT existe encore.
- Réarmer les serveurs ne ferme plus les sockets actifs. La reconnexion utilise le périphérique BLE connu et évite un nouveau scan concurrent.
- Une session de trajet utilise la localisation pour la navigation, la vitesse et l’altitude lorsque la liaison TFT est active. Elle est indépendante de l’arrêt éventuel du miroir.
- Les réglages d’écran utilisent deux curseurs de 0 à 300 pixels et une remise à zéro.
- L’ajout d’applications utilise la liste ou un seul champ. Les anciens raccourcis déjà configurés sont conservés. DMD HUB et les nouvelles apps saisies par leur nom s’ouvrent normalement depuis l’accueil de l’iPhone ; le bouton prépare la diffusion et indique cette étape.
- L’icône Double Interface existante est fournie aux deux extensions embarquées, avec les tailles iPhone/iPad. Le nom exact du service embarqué est indiqué pour éviter la confusion avec MotoMirror.
- Le diagnostic distingue Bluetooth, contrôle TFT, vidéo et localisation en arrière-plan ; il enregistre le dernier paquet de contrôle et le dernier envoi vidéo terminé côté iPhone.
- La météo est facultative et désactivée par défaut. Si activée, les coordonnées envoyées sont arrondies à deux décimales ; leur écriture dans le journal et leur nouveau stockage dans le cache météo sont retirés. La politique de confidentialité a été corrigée.

## Wi-Fi et signature Apple

Le profil utilisé sur le Mac a déjà pu refuser certaines capacités. Cette livraison garde donc les droits existants. Si l’équipe Apple permet Hotspot Configuration, activer cette capacité pour la cible principale dans Xcode permet à l’API de configuration Wi-Fi d’enregistrer le réseau après accord iOS. Sinon, associer une fois le Wi-Fi du compteur dans les Réglages et conserver Connexion auto pour ce réseau. Le système peut ensuite retrouver le réseau connu ; l’app ne peut pas imposer silencieusement un changement de réseau lorsqu’elle est suspendue.

L’enregistrement Wi-Fi et le partage d’écran sont deux opérations différentes. Après l’arrêt d’un partage complet, iOS demande de démarrer une nouvelle diffusion. Le cockpit intégré produit ses propres images et ne dépend pas d’une diffusion ReplayKit pour ces vues.

## Limites à conserver dans les échanges

Aucune compilation Apple, signature, installation ou validation sur la moto n’est attestée par cette livraison. Les tests Python concernent la mise à jour et les scripts ; l’analyse Swift ne remplace pas la vérification des types avec Xcode. Le fonctionnement des vues intégrées écran verrouillé reste expérimental, notamment la disponibilité de VideoToolbox, de la localisation et du réseau.

Le conteneur d’applications tierces sur écrans virtuels n’est pas réalisé. Le projet ne doit pas être vendu sur cette promesse. Lire OBJECTIF_PRODUIT.md et COMMERCIALISATION.md avant de préparer une publication.
