> Révision actuelle : lire NOUVEAUTES_V5.md et TESTS_MOTO_9H.md. Les notes plus anciennes ci-dessous ne remplacent pas ces instructions.

# NicoMirror - essai de navigation iPhone verrouillé

Cette livraison contient les sources modifiées, pas une application installable.
Le mode reste expérimental : aucune compilation iOS, signature Apple ou validation
sur iPhone/Kove n'a été réalisée ici.

## Utilisation après compilation et installation

1. Connecter NicoMirror au compteur comme auparavant.
2. Dans Réglages, laisser « Navigation iPhone verrouillé (expérimental) » activé.
3. Autoriser la localisation et démarrer un itinéraire dans la carte de NicoMirror.
4. Vérifier la réception du miroir, puis verrouiller l'iPhone avec le bouton latéral.
5. Le nouveau chemin de code tente d'envoyer un panneau de navigation avec
   instructions, vitesse, heure du dernier point GPS et tracé simplifié orienté nord.
6. Déverrouiller pour retrouver l'affichage habituel.

Ouvrir l'application seule ne suffit pas : une navigation doit être en cours.
Ce mode ne transmet pas l'écran de Google Maps, Plans, OsmAnd ou d'une autre app.
Le tracé ne contient ni fond de carte, ni noms de rues. La distance affichée vers
la manoeuvre est à vol d'oiseau, conformément au calcul existant ; elle ne doit
pas être confondue avec une distance routière. Le suivi d'itinéraire et le
recalcul restent ceux, limités, de la base du projet.

## Mécanisme et limites

- Rendu CPU CoreGraphics/CoreText dans un tampon BGRA, indépendant des vues UIKit.
- Envoi H.264 par le protocole TCP existant du compteur.
- Actualisation sur les événements GPS, au maximum une image par seconde.
- Pas de timer destiné à empêcher iOS de suspendre l'app ; localisation liée à
  une vraie navigation et capacités location/bluetooth-central déjà déclarées.
- Le flux ReplayKit est écarté pendant le rendu de navigation pour éviter le
  mélange des flux vidéo ; le miroir est rétabli au retour au premier plan.
- Les erreurs d'encodage synchrones sont ajoutées au journal de connexion.
- L'encodage VideoToolbox, le comportement du décodeur du compteur à faible cadence,
  la liaison Wi-Fi et l'exécution en arrière-plan doivent être validés sur appareil.
- À l'arrêt ou sans événement GPS, l'image peut rester affichée : l'heure du point
  GPS permet de voir si elle est figée. Une position périmée reçue est signalée.
- Aucune promesse de continuité écran verrouillé n'est faite avant ces essais.

## Recette sur appareil, à l'arrêt puis avec un passager testeur

1. Compiler avec Xcode, signer avec une équipe Apple et installer. La validation
   syntaxique fournie ne remplace pas la compilation et la vérification des types.
2. Démarrer un trajet NicoMirror : écran allumé, vérifier les données habituelles.
3. Verrouiller pendant au moins 5 minutes avec des mises à jour de position :
   vérifier que l'heure GPS, la vitesse et le tracé changent réellement au compteur.
4. Tester arrêt prolongé, perte GPS, fin de navigation, déconnexion/reconnexion du
   compteur et changement de résolution. Aucun ancien flux ne doit reprendre.
5. Déverrouiller : le miroir intégré doit revenir sans données vidéo corrompues.
6. Répéter avec puis sans diffusion ReplayKit active, et option désactivée.
7. Relever les erreurs de journal en cas d'image figée. Ne pas considérer une
   connexion Bluetooth maintenue ou une image fixe comme un succès du test.

## État des contrôles locaux

Voir VERIFICATION.json. Xcode/Swift et la signature ne sont pas disponibles
sur le poste Linux utilisé pour cette livraison. Aucun IPA n'est fourni.
Le lien TestFlight de la base, mentionné dans README.md, n'installe pas ce code.

## Références techniques

- https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates
- https://developer.apple.com/documentation/mapkit/mkmapsnapshotter/start(completionhandler:)
- https://developer.apple.com/documentation/videotoolbox/kvtvideoencodernotavailablenowerr
