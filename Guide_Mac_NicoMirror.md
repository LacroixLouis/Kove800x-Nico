# NicoMirror : guide Mac, installation et protocole Kove

Préparé pour Nicolas Rivet — 19 novembre 2026.

## À lire d’abord

Le projet modifié est un **prototype expérimental**. Sa syntaxe Swift a été analysée, mais il n’a pas encore été compilé avec Xcode, signé ni essayé sur un iPhone et une Kove. La première compilation peut révéler des erreurs à corriger.

L’objectif est de lancer un itinéraire dans NicoMirror, verrouiller réellement l’iPhone et continuer à recevoir un affichage de navigation sur le compteur d’origine de la Kove 800X Rally. Le mode ajouté affiche des consignes, la vitesse, l’heure du GPS et un tracé simplifié. **Il ne recopie pas Google Maps, Plans ou OsmAnd lorsque l’iPhone est verrouillé.**

## 1. Quel Mac trouver ?

Prévoir :

- Un Mac pouvant installer une version de Xcode compatible avec la version iOS de ton iPhone.
- Une connexion Internet pour installer Xcode, les composants iOS et configurer la signature.
- Ton iPhone et un câble USB permettant le transfert de données.
- Un compte Apple utilisable dans Xcode. La personne qui possède le Mac peut aussi utiliser sa propre équipe de développement pour signer ton installation.

Avant d’emprunter le Mac, relève la version de l’iPhone dans **Réglages → Général → Informations → Version d’iOS** et la version du Mac dans **menu Apple → À propos de ce Mac**.

Le projet cible iOS 26.0 au minimum. Cela ne suffit pas à déterminer quelle version de Xcode conviendra à ton iPhone : vérifier aussi sa version iOS réelle. Par exemple, Apple indique que Xcode 27.2 inclut le SDK iOS 27.2 et demande macOS Tahoe 26.6 ou ultérieur. Vérifier le tableau Apple lié en fin de guide avant d’installer ou de mettre à jour quoi que ce soit.

**Signature :** un compte Apple gratuit permet certains essais via une « Personal Team », mais certaines capacités du projet peuvent être indisponibles pour cette équipe. Il faut une équipe et des profils autorisant les capacités utilisées. Ne pas supprimer des capacités uniquement pour faire disparaître une erreur : le Wi-Fi automatique ou le partage de réglages pourrait cesser de fonctionner. Relever d’abord le message exact de Xcode.

## 2. Récupérer le bon projet

Télécharger et décompresser **NicoMirror_navigation_verrouillee_source.zip**.

Lien vers les sources préparées :
https://chatgpt.com/library?file_id=libfile_fde3_f-dc6b3430359c819190f037cd14e2d9bb_0ec6e8d1ac6c81919bd3b43522e3d488&account_id=personal

Ouvrir le dossier **NicoMirror**, puis double-cliquer sur **NicoMirror.xcodeproj**.

Le bon projet contient le fichier :
`KoveMirror/Connection/LockedNavigationStream.swift`

Il contient aussi `NAVIGATION_VERROUILLEE.md`, avec les limites et les essais du nouveau mode. Le lien TestFlight du projet d’origine n’installe pas cette adaptation.

## 3. Préparer Xcode et l’iPhone

1. Installer Xcode depuis une source Apple et le lancer une première fois.
2. Accepter sa licence et installer les composants iOS demandés.
3. Dans **Xcode → Settings → Accounts**, ajouter le compte Apple qui signera le projet. Selon la version, cette rubrique peut être intitulée « Apple Accounts ».
4. Brancher l’iPhone au Mac, le déverrouiller et accepter **Faire confiance** si demandé.
5. Activer le **Mode développeur** sur l’iPhone lorsqu’il est demandé : **Réglages → Confidentialité et sécurité → Mode développeur**. Un redémarrage et une confirmation peuvent être nécessaires.
6. Attendre que Xcode ait terminé la préparation de l’iPhone.

Les mots de passe et codes Apple sont à saisir directement dans les fenêtres Apple, pas dans le code ni dans un message.

## 4. Régler la signature du projet

Dans Xcode, cliquer sur le projet bleu en haut de la colonne de gauche. Dans **TARGETS**, ouvrir chaque cible ci-dessous, puis **Signing & Capabilities** :

| Cible | Action |
| --- | --- |
| KoveMirror | Cocher « Automatically manage signing » et choisir l’équipe |
| Kove broadcast extension | Choisir la même équipe et la signature automatique |
| Kove broadcast extensionSetupUI | Choisir la même équipe et la signature automatique |
| KoveMirrorTests / KoveMirrorUITests | Utiliser aussi cette équipe si Xcode le demande pour les tests |

Le nom de la cible principale reste **KoveMirror** ; le nom affiché sur l’iPhone est **NicoMirror**.

### Identifiants préparés

| Élément | Identifiant |
| --- | --- |
| Application | `com.nicolasrivet.NicoMirror` |
| Extension vidéo | `com.nicolasrivet.NicoMirror.Kove-broadcast-extension` |
| Interface de préparation de diffusion | `com.nicolasrivet.NicoMirror.Kove-broadcast-extensionSetupUI` |
| Groupe partagé | `group.com.nicolasrivet.NicoMirror` |

Si Xcode indique qu’un identifiant est déjà pris, la personne qui compile devra choisir une base unique et garder les identifiants des extensions rattachés à celui de l’application.

**Si le groupe partagé change**, mettre exactement le même nouveau groupe dans :

- la capacité App Groups de l’application ;
- la capacité App Groups de l’extension vidéo ;
- `KoveMirror/KoveMirror.entitlements` ;
- `Kove broadcast extension/Broadcast.entitlements` ;
- la constante `appGroupSuiteName` de `KoveMirror/SetupViews/KoveScreenPreset.swift`.

### Capacités attendues

| Cible | Capacités ou réglages |
| --- | --- |
| Application | Hotspot Configuration ; Access WiFi Information ; App Groups |
| Application | Background Modes : Location updates et Uses Bluetooth LE accessories |
| Extension vidéo | App Groups, identique à celui de l’application |

Xcode doit générer un profil de signature compatible. En cas de refus de capacité avec la Personal Team, conserver le message exact pour décider de l’adaptation ou de l’équipe appropriée.

## 5. Compiler et installer directement

1. En haut de Xcode, sélectionner le **schéma NicoMirror**.
2. Choisir **ton iPhone réel** comme destination, plutôt qu’un simulateur.
3. Faire **Product → Build**, ou **Commande + B**.
4. Si la compilation réussit, faire **Product → Run**, ou **Commande + R**.
5. Accepter les éventuelles confirmations Apple sur l’iPhone.

Cette installation directe ne demande pas de code TestFlight. Le simulateur ne valide pas la connexion Bluetooth/Wi-Fi au compteur ni le fonctionnement réel après verrouillage.

Le script `scripts/build-ios.sh` produit uniquement une compilation non signée. Il peut servir à vérifier le projet, mais son IPA non signé n’est pas installable directement. Pour le premier essai, utiliser **Run sur l’iPhone avec signature automatique**.

### Si la compilation échoue

Ouvrir le navigateur d’erreurs avec **Commande + 5**, puis relever :

- le premier message d’erreur complet ;
- le nom du fichier et le numéro de ligne ;
- la version de Xcode, la version de macOS et la version iOS ;
- si le blocage concerne la compilation Swift, la signature ou la préparation de l’iPhone.

Une erreur Swift doit être corrigée dans le code. Une erreur de profil ou de capacité ne se corrige pas en changeant au hasard les fichiers Swift.

## 6. Connecter la Kove

1. Mettre le contact et afficher le mode navigation du compteur.
2. Fermer THINKERRIDE s’il utilise déjà la liaison avec la moto.
3. Ouvrir NicoMirror et accepter les autorisations **Bluetooth**, **réseau local**, **caméra** et **localisation** nécessaires.
4. Scanner le QR de connexion Wi-Fi affiché par le compteur, et accepter la connexion au réseau de la moto. Ne pas scanner le QR de téléchargement de THINKERRIDE.
5. Sélectionner le profil **Kove 800X / Rally — 600 × 1024**.
6. Démarrer le miroir si nécessaire et vérifier d’abord l’image téléphone déverrouillé.

Le Wi-Fi de la moto peut être signalé « sans Internet » : il sert à transmettre l’image. Le calcul initial d’itinéraire peut néanmoins avoir besoin d’un accès Internet ; le préparer avant l’essai si nécessaire.

## 7. Tester le verrouillage réel

1. Dans les réglages de NicoMirror, activer **Navigation iPhone verrouillé (expérimental)**.
2. Dans la carte de NicoMirror, choisir une destination et **démarrer la navigation**. Ouvrir seulement l’application ne suffit pas.
3. Vérifier la connexion et le miroir sur le compteur.
4. Appuyer sur le bouton latéral de l’iPhone pour le verrouiller réellement.
5. Vérifier si le compteur affiche le panneau de navigation et si **l’heure GPS se renouvelle** lorsque des positions sont reçues.
6. Déverrouiller : l’affichage habituel doit revenir.

Le panneau prévu contient les instructions, la vitesse, un tracé orienté nord et l’heure du dernier point GPS. Il n’a pas de fond de carte. La distance vers la manœuvre est calculée à vol d’oiseau dans cette base du projet.

**Une image restée fixe n’est pas une preuve de fonctionnement.** À l’arrêt, sans nouveaux événements GPS, elle peut ne pas changer. La continuité de l’encodeur et du Wi-Fi après verrouillage reste à vérifier sur appareil. Faire manipuler le téléphone par un passager testeur ou effectuer les manipulations à l’arrêt.

Pour valider le mode : essayer plusieurs minutes avec déplacement, puis une pause, une perte de GPS, un déverrouillage et une déconnexion/reconnexion. Répéter avec puis sans diffusion ReplayKit active. Si l’image se fige, déverrouiller et récupérer les journaux.

## 8. Diagnostic rapide

| Symptôme | Première vérification |
| --- | --- |
| Xcode ne voit pas l’iPhone | Câble de données, confiance, iPhone déverrouillé, compatibilité de Xcode |
| Erreur de signature | Même équipe pour toutes les cibles, identifiants disponibles, capacités autorisées |
| Connexion Bluetooth mais aucune image | Wi-Fi de la moto, autorisation réseau local, mode navigation du compteur, connexions TCP |
| Image correcte avant verrouillage puis figée | Navigation NicoMirror active, option activée, événements GPS, erreur VideoToolbox dans le journal |
| Réglages vidéo différents dans l’extension | App Group et `appGroupSuiteName` identiques |
| Google Maps cesse d’être recopié au verrouillage | Le nouveau mode transmet sa propre navigation ; il ne maintient pas la capture de Google Maps |

Les messages utiles incluent « Control connection ready », « Video connection established », « Essai navigation verrouillée » et « Navigation verrouillée : erreur encodeur ». Conserver le code numérique de l’erreur d’encodeur.

---

## Annexe technique : protocole implémenté dans le projet

Cette annexe décrit le code fourni, issu d’une base KoveMirror/ThinkerRide. Ce n’est pas une spécification officielle de Kove. La compatibilité du firmware du compteur et les détails d’échanges doivent être confirmés par les essais.

### Rôle des liaisons

| Liaison | Rôle dans le code |
| --- | --- |
| Bluetooth LE | Découverte, appairage applicatif, commandes, activation de la projection et navigation par consignes |
| Wi-Fi du compteur | Réseau de transport de la vidéo et du contrôle TCP |
| TCP 17818 sur l’iPhone | Serveur de contrôle auquel le compteur se connecte |
| TCP 15456 sur l’iPhone | Serveur vidéo H.264 auquel le compteur se connecte |
| TCP 15457 sur l’iPhone | Serveur d’entretien de liaison auquel le compteur se connecte |
| TCP 15455 sur `127.0.0.1` | Relais local entre l’extension ReplayKit et l’application ; non destiné au compteur |

Le code ne fixe pas une adresse IP universelle du compteur. Ne pas inventer une adresse à saisir : l’association Bluetooth/Wi-Fi et la négociation existantes sont utilisées.

### Bluetooth

Service principal recherché : `0000e0ff-3c17-d293-8e48-14fe2e4da212`.

Le code prévoit aussi trois variantes de service selon le modèle. Caractéristique d’écriture : `0000ffe1-0000-1000-8000-00805f9b34fb`. Notifications : `0000ffe2-0000-1000-8000-00805f9b34fb`.

Activation de projection, via le transport encadré du code :

```json
{"msg_id":25,"msg_type":23,"msg_source":2,"status":1}
{"msg_id":25,"msg_type":21,"msg_source":2,"status":1}
```

Le JSON n’est pas simplement écrit tel quel sur Bluetooth. `frameJsonPacket` ajoute une somme des octets UTF-8 modulo 256, encodée dans deux octets dont le bit haut est positionné, puis un octet nul. Le résultat est découpé en fragments de 100 octets au maximum. Chaque trame fait 104 octets : `FE`, compteur de séquence sur deux octets en ordre big-endian, fragment, `FF`, puis bourrage nul si nécessaire.

### Wi-Fi et contrôle

Le lecteur QR accepte notamment `http://g.thinkerride.com/?SSID&MOT_DE_PASSE&ap=1` et certains QR Wi-Fi standards. Le code extrait les identifiants sans ouvrir cette URL, puis demande à iOS la connexion Wi-Fi.

Sur le port 17818, le code envoie des requêtes binaires initiales et des requêtes JSON `INSIDENAVI`, `CAR_INFO` et `TUC`. L’encadrement JSON TCP est différent du Bluetooth : préfixe `EE FD`, longueur UTF-8 sur quatre octets big-endian, JSON, puis `FF`.

La séquence de négociation complète se trouve dans `sendControlInitSequence` et `sendControlHandshake`, dans `TcpServerManager.swift`. Utiliser ces méthodes comme référence plutôt que reconstituer la négociation de mémoire.

L’entretien dédié sur 15457 envoie `02 01 00 00 00 00` toutes les 200 ms. Le code prévoit également des impulsions sur la liaison vidéo toutes les deux secondes et l’écho de certains messages sur la liaison de contrôle. Ces timers n’accordent aucune autorisation supplémentaire d’exécution à iOS.

### Vidéo

La connexion vidéo commence par un en-tête de 69 octets. Le nom `android` commence à l’octet 1, et sert ici de valeur de compatibilité attendue par la base du protocole ; il ne change pas l’état de verrouillage de l’iPhone. Largeur aux octets 65–66, hauteur aux octets 67–68, en big-endian.

L’encodeur produit du H.264, profil High 4.1, sans images B. Le flux envoyé utilise des unités NAL Annex B précédées de `00 00 00 01`, avec les paramètres SPS/PPS associés aux images clés. Le profil 800X utilise 600 × 1024 pixels. La capture habituelle vise 30 images/seconde ; le nouveau panneau GPS vise au maximum une image/seconde lors des événements de position.

### Mode verrouillé ajouté

`LockedNavigationStream.swift` dessine un tampon BGRA avec CoreGraphics/CoreText, sans capturer de fenêtre UIKit ni demander une image de carte MapKit en arrière-plan. Il réutilise l’encodeur H.264 et la liaison vidéo TCP.

À l’entrée en arrière-plan, si le mode est activé, la navigation en cours et le flux connecté, le code arrête la capture intégrée et tente de démarrer ce panneau. Le relais ReplayKit est écarté pour éviter de mélanger les deux flux vidéo. Au retour au premier plan, le panneau s’arrête et le chemin habituel reprend.

Les mises à jour proviennent des événements GPS de navigation. `NavigationSyncManager.updateProgress` a aussi été adapté pour envoyer les consignes Bluetooth à partir de ces événements sans dépendre uniquement d’un timer au premier plan.

**Point à valider en priorité :** iOS peut limiter les ressources en arrière-plan et l’encodeur peut être indisponible. L’existence de ce code ne prouve pas que la vidéo restera active après verrouillage. La validation nécessite l’iPhone, le compteur, des positions réellement actualisées et les journaux.

## Références Apple

- Compatibilité Xcode/macOS/iOS : https://developer.apple.com/xcode/system-requirements/
- Signature et capacités : https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app
- Mode développeur : https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- Groupes partagés : https://developer.apple.com/documentation/xcode/configuring-app-groups
- Capacités selon l’équipe : https://developer.apple.com/help/account/reference/supported-capabilities-ios
- Localisation en arrière-plan : https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
