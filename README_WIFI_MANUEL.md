# Correctif Wi-Fi manuel pour ton projet Double Interface

Ce correctif traite le message Xcode : Personal Team ne prend pas en charge
Hotspot et Access Wi-Fi Information.

## L’appliquer sur le Mac

1. Quitte Xcode avec **Xcode → Quit Xcode** ou **Command + Q**.
2. Décompresse **Correctif_WiFi_Manuel.zip**.
3. Dans le dossier décompressé, ouvre **Appliquer_WiFi_Manuel.command**.
4. Quand le Mac demande un dossier, sélectionne **Téléchargements → Kove_Interface 2**,
   le dossier qui contient NicoMirror.xcodeproj, puis valide le choix.
5. Attends le message **Correctif Wi-Fi manuel appliqué**. Une sauvegarde est créée
   dans le dossier du projet. Le correctif conserve le fichier projet contenant
   tes équipes de signature et ton nom d’application.
6. Rouvre **NicoMirror.xcodeproj**. Dans **Signing & Capabilities**, utilise **Try Again**
   si le bouton est proposé. Transmets une photo de tout nouveau message.

Si le fichier .command n’est pas lancé au double-clic, ouvre Terminal, tape
`bash ` avec une espace, glisse le fichier .command dans Terminal et appuie sur
Entrée. Les fichiers du correctif doivent rester ensemble dans leur dossier.

Si le script signale une source différente de la version attendue, il ne remplace
rien : transmettre ConnectionStatusView.swift pour adapter le correctif.

## Utilisation sur l’iPhone, après compilation et installation

1. Affiche le réseau Wi-Fi de la moto et ses identifiants sur le compteur.
2. Dans **Réglages → Wi-Fi**, rejoins ce réseau.
3. Reviens dans **Double Interface**. La version corrigée détecte les canaux du compteur sans demander de confirmer à nouveau le Wi-Fi.
4. Choisis l’application depuis **TFT Kove**. La liaison existante est réutilisée ; si une reprise est nécessaire, l’envoi attend automatiquement le canal vidéo.

Le lecteur QR reste disponible pour lire le nom du réseau et le mot de passe.
La fenêtre propose de copier temporairement le mot de passe pour le coller dans
les réglages Wi-Fi. Le mot de passe n’est ni enregistré dans les réglages de
l’app ni écrit dans son journal.

La version corrigée utilise les canaux réellement établis avec le compteur pour
afficher l’état de la liaison. Le nom d’un réseau mémorisé n’est pas une preuve
de connexion. La réception de l’image par le compteur reste le test décisif.

## Modifications exactes

- Retrait des deux autorisations Wi-Fi du fichier KoveMirror.entitlements.
- Remplacement de ConnectionStatusView.swift pour gérer la connexion manuelle,
  sans appel à NEHotspotConfigurationManager ni NEHotspotNetwork.fetchCurrent.
- Les réglages Xcode, les identifiants et les autres capacités sont conservés.

Les cinq tests du programme d’application du correctif passent : sauvegarde,
préservation des réglages, seconde exécution sans effet supplémentaire, refus
d’une source différente ou d’un mauvais dossier et restauration après erreur
simulée d’écriture. La syntaxe de 48 fichiers Swift a été analysée.

**La signature Apple, la compilation iOS et l’essai sur iPhone/Kove ne sont pas
réalisés ici.** Ce correctif enlève la demande des deux capacités signalées ;
le profil Apple doit encore être généré et validé par Xcode. Le suivi GPX et la
sortie TFT conservent les limites du prototype.
