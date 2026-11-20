# Parcours vers un produit commercial

Préparation du 20 novembre 2026. Aucun brevet déposé, compte payant souscrit, achat, publication TestFlight ou mise en vente réalisés dans cette session.

## 1. Fixer une promesse techniquement démontrée

Le souhait de Nicolas est un conteneur multi-applications avec sorties indépendantes et téléphone verrouillé. Cette fonction n’a pas été réalisée. Apple isole les applications et réserve les échanges aux services fournis par le système. La documentation iOS de ScreenCaptureKit présente une capture de l’écran complet ou du contenu de l’app elle-même. Les règles App Review demandent des API publiques et des apps contenues dans leur espace. Ces textes ne constituent pas une méthode pour héberger les autres applications : il faut démontrer une intégration autorisée avant d’en faire la promesse commerciale.

La priorité confirmée par Nicolas est de compléter les GPS existants, pas de développer un autre GPS. Le prototype inclut donc un accès aux favoris et un partage de traces GPX et de positions. Les trois vues intégrées sont un banc d’essai distinct. La décision de vendre dépendra des résultats des essais et d’une promesse limitée aux fonctions démontrées.

Sources Apple :

- https://support.apple.com/en-ie/guide/security-pdf/sec15bfe098e/1/web/1
- https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios
- https://developer.apple.com/app-store/review/guidelines/

## 2. Valider la fiabilité et la compatibilité

Exécuter TESTS_MOTO_9H.md, corriger les échecs, puis répéter des trajets complets, des arrêts, des redémarrages, des pertes de GPS et des reconnections. Consigner les appareils et firmwares effectivement testés. Les profils de résolution fournis dans le code ne prouvent pas la compatibilité de chaque compteur. Commencer par la Kove de Nicolas, puis élargir la matrice à d’autres modèles seulement avec des essais.

La fonction de base à démontrer est : première association compréhensible, mise du contact, reconnexion, sélection de la vue, actualisation et retour après coupure. Le support client, les diagnostics et une procédure de retour à l’affichage habituel font partie du produit.

## 3. Droits sur la base et identité

Le fichier LICENSE fourni porte la licence MIT de MapaX. Il autorise notamment la modification et la vente sous réserve de conserver la notice de copyright et l’autorisation. Conserver les attributions de la base et documenter les modifications. Cette licence ne permet pas d’affirmer que les mécanismes préexistants constituent une invention de Nicolas.

L’icône Double Interface ne vaut pas une vérification de disponibilité d’une marque. La disponibilité du nom commercial, des signes utilisés et des noms de domaine reste à étudier avant tout dépôt ou lancement. Aucun contrôle de disponibilité n’est déclaré effectué ici.

## 4. Brevet éventuel

L’INPI distingue le programme seul et une invention technique qui l’utilise. Une invention doit notamment être nouvelle et inventive. L’OEB décrit, pour les programmes concernés, un effet technique supplémentaire. Cela n’établit pas que ce projet est brevetable.

La première analyse ne contient pas encore d’invention technique précise démontrée ni de recherche d’antériorités exhaustive. Le simple souhait « plusieurs applications et plusieurs écrans » ne suffit pas à conclure à la possibilité d’un brevet. Préparer d’abord une description de la méthode nouvelle, du problème technique, de l’effet mesuré et de ce qui diffère de KoveMirror et des autres systèmes connus. Un conseil en propriété industrielle pourra examiner les éléments et les résultats de recherche avant une décision de dépôt. Aucun formulaire n’a été soumis.

Sources consultées :

- https://www.inpi.fr/realiser-demarches/propriete-intellectuelle/cas-particulier-logiciels
- https://www.inpi.fr/realiser-demarches/propriete-intellectuelle/criteres-de-brevetabilite
- https://www.epo.org/en/legal/guidelines-epc/2026/g_ii_3_6.html

## 5. Vie privée et services

La politique de la base affirmait à tort que la position ne quittait jamais le téléphone, alors que le code météo envoyait les coordonnées à Open-Meteo. La politique a été réécrite pour refléter les flux ; la météo devient facultative et envoie une position arrondie. Le code retire l’écriture de nouvelles coordonnées dans le cache météo et les messages de journal correspondants.

La version utilise encore un endpoint météo de prototype. Open-Meteo distingue l’usage non commercial de l’API gratuite et les offres commerciales. Avant la vente, choisir et configurer un service adapté et son attribution ; aucun abonnement n’a été acheté. Compléter aussi l’éditeur, le contact de confidentialité, l’URL publique de politique, les déclarations App Store et les éventuels manifestes de confidentialité requis par les API réellement utilisées.

Sources :

- https://open-meteo.com/
- https://open-meteo.com/en/pricing
- https://developer.apple.com/app-store/submitting/

## 6. Bêta et distribution

Compiler avec le SDK Apple, signer, installer, puis préparer une bêta TestFlight dans App Store Connect avec des notes précises sur le matériel et les fonctions expérimentales. Un lien TestFlight de la base ne distribue pas cette adaptation. La publication commerciale vient après les essais, la documentation, les éléments éditeur et la décision sur les fonctions réellement proposées.

Préparer alors la fiche de vente, les captures prises sur la version réelle, la liste des motos testées, les permissions expliquées et le support. Le prix et le modèle économique restent à définir après la bêta ; aucun revenu ou volume de vente n’est présumé.

Sources :

- https://developer.apple.com/testflight/
- https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/

## État des livrables

| Élément | État |
| --- | --- |
| Sources de prototype et mise à jour Mac | Inclus dans l’archive |
| Procédure d’essais | Préparée |
| Compilation, signature et essais réels | Non réalisés ici |
| Faisabilité du conteneur d’apps tierces | Non établie avec les API publiques |
| Politique de confidentialité | Brouillon adapté au code, à finaliser avec l’éditeur |
| Recherche de brevet complète et liberté d’exploitation | Non réalisées |
| Dépôt, commercialisation et publication | Non engagés |
