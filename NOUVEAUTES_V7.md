# Double Interface — Les deux écrans au centre, v7

L’accueil est consacré à l’iPhone et au TFT Kove. Les outils de voyage sont accessibles depuis **Outils** et ne prennent plus la place des commandes d’affichage.

Cette version conserve également les corrections v6.1 : kilométrage du compteur synchronisé automatiquement avec l’entretien, dernières lectures horodatées et protection contre l’association d’une autre moto.

## Choisir ce que reçoit chaque écran

| Choix | Sur l’iPhone | Sur le TFT | Diffusion complète iOS |
| --- | --- | --- | --- |
| Applications → Même application que l’iPhone | L’app choisie | Le miroir de cette app | Nécessaire, démarrée par l’utilisateur |
| Applications → Double Interface · Navigation / Trace GPX / Compteurs | L’app choisie | La vue Double Interface choisie | Non nécessaire |
| Vues Double Interface | La vue Double Interface choisie pour le téléphone | La vue Double Interface choisie pour le TFT | Non nécessaire |

Pour le deuxième mode, choisis d’abord **Sur le TFT → Double Interface · …**, puis touche l’icône de ton application. Le parcours attend la liaison vidéo, active le rendu Double Interface du TFT puis ouvre l’app iPhone. Waze et OsmAnd utilisent leur ouverture directe ; Plans utilise l’ouverture Apple ; Wikiloc utilise son lien d’application. DMD HUB et les apps personnelles sans raccourci conservent une ouverture guidée et manuelle.

Pour les vues internes, les deux sélecteurs sont directement sur l’accueil. **Afficher ces deux vues** ouvre la vue du téléphone et conserve le rendu TFT choisi. Le panneau du téléphone permet de préparer une destination, d’importer un GPX ou de consulter les compteurs.

Le TFT Double Interface présente un tracé simplifié et des consignes, sans fond cartographique. Une destination et une trace doivent être préparées avant de pouvoir être suivies. Les valeurs absentes restent indiquées par un tiret. Les cartes de l’accueil présentent des **choix enregistrés**, pas des captures du TFT ni une confirmation que l’image a été reçue.

Deux applications tierces différentes, chacune affichée indépendamment sur un écran, ne sont pas prises en charge. Le mode séparé proposé associe l’app iPhone au rendu de notre propre application sur le TFT.

## Finition et navigation

- Le nom de l’application est **Double Interface**, dans les écrans iPhone/TFT, l’icône, les langues, les exports et le menu de diffusion iOS. La mise à jour applique aussi ce nom au projet déjà signé, en conservant ses identifiants et droits Apple.
- Le nom du réseau Wi-Fi mémorisé n’est plus affiché dans « Connecter la Kove » : un réseau enregistré ne confirme pas une connexion active.
- Palette sombre unique : vert profond, citron, orange et blanc cassé sur l’accueil, les réglages, la connexion, les formulaires, la recherche et les cartes.
- Même palette pour les images Double Interface produites pour le TFT, avec tracé citron et position orange.
- Écrans et applications sont les premières destinations de la barre du bas. Météo, entretien, GPS, widgets et personnalisation restent dans les outils secondaires.
- Les fenêtres se ferment avant l’ouverture de la suivante ou d’une app externe. Une préparation annulée ne conserve pas une ouverture automatique en attente de reconnexion.
- Une perte de liaison juste avant l’ouverture revient à la préparation. Le mode miroir attend aussi la diffusion iOS ; le mode TFT Double Interface n’exige que la liaison vidéo.
- Retour au miroir : l’ancien suivi GPX indépendant est désactivé pour ne pas remplacer le miroir demandé.
- Le choix français/anglais reste disponible. Les nouveaux écrans sont traduits.

## Mettre à jour le projet déjà signé

1. Fermer Xcode et décompresser la nouvelle archive dans un dossier distinct.
2. Ouvrir **Mettre_a_jour_sur_Mac.command** et choisir le dossier du projet existant qui contient **NicoMirror.xcodeproj**.
3. Rouvrir ce projet dans Xcode, garder l’iPhone comme destination puis faire **Commande + R**.

L’outil sauvegarde les anciens fichiers. Les identifiants, l’équipe Apple, les droits et les groupes partagés ne sont pas remplacés. Les nouveaux fichiers d’interface sont inclus dans le manifeste de mise à jour.

## Vérifier sur les appareils

Cette version est du code source. L’environnement de préparation n’a ni Xcode ni SDK iOS : aucune compilation Apple, installation iPhone ou validation sur la moto n’a été réalisée ici. L’analyse syntaxique ne remplace pas la compilation.

Pour l’essai, commencer à l’arrêt :

1. Sans moto, vérifier le nouvel accueil, les menus sombres et l’ouverture des apps pour les régler.
2. Connecter le TFT. Choisir **Même application que l’iPhone**, démarrer la diffusion iOS puis ouvrir Waze ou OsmAnd. Vérifier l’image réellement reçue.
3. Revenir dans Double Interface. Choisir **Double Interface · Compteurs** sur le TFT, puis ouvrir Waze sur l’iPhone. Vérifier que le TFT garde les compteurs et que l’heure GPS évolue pendant plusieurs minutes.
4. Refaire avec un GPX chargé et suivi. Vérifier le maintien des mises à jour lorsque Double Interface passe en arrière-plan. Une éventuelle diffusion système déjà active ne doit pas remplacer la vue Double Interface.
5. Interrompre puis rétablir la liaison. Annuler une préparation, reconnecter et vérifier qu’aucune app ne s’ouvre après l’annulation.
6. Revenir au miroir après un suivi GPX indépendant et vérifier que le TFT reçoit bien la source choisie.

Le verrouillage réel de l’iPhone et l’encodage en arrière-plan restent des points d’essai, pas des garanties. En cas de gel, revenir dans Double Interface et consulter le diagnostic.

**Apercu_RIVET.html** est une référence interactive du design, pas une application iPhone ni une capture d’un essai réel. Ses états de connexion restent hors ligne.
