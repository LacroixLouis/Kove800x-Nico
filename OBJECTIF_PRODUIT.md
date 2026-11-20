# Objectif produit — Nicolas RIVET

État au 20 novembre 2026. Prototype personnel, pas encore un produit commercial validé.

Nicolas veut une application de référence pour les motards : mise du contact et connexion automatique, commandes simples, plusieurs applications que l’on peut utiliser sans quitter l’interface, choix indépendant de l’image du téléphone et de celle du TFT, continuité téléphone réellement verrouillé. Il demande un prototype pour des essais sur la moto à 9 h, puis le parcours jusqu’à la vente et l’étude d’un brevet si une véritable invention technique le justifie.

La priorité confirmée est de réunir les bons GPS existants : favoris, échange de traces et de positions, affichage et connexion moto. Le projet ne doit pas dériver vers un concurrent des GPS. Les vues intégrées servent de banc d’essai pour le transport et les deux écrans.

## Écart entre l’objectif et cette version

| Demande | Code présent | Validation disponible |
| --- | --- | --- |
| Compléter les GPS existants | Mes GPS & mes fichiers : import GPX, partage du document d’origine et partage d’une position récente | Sources ; applications proposées par le partage iOS selon les formats acceptés, à tester sur l’iPhone |
| Héberger librement Waze, OsmAnd, DMD HUB et d’autres apps dans des écrans virtuels | Non réalisé ; aucune API publique iPhone adaptée n’a été établie | Blocage de faisabilité, pas une fonction à déclarer terminée |
| Deux affichages intégrés distincts | Sélecteurs Téléphone/TFT pour Navigation, Trace GPX et Compteurs | Sources et analyse syntaxique ; essais matériels nécessaires |
| iPhone verrouillé avec la navigation intégrée | Rendu CPU sur les événements GPS, session de trajet, envoi H.264 | Non compilé avec le SDK Apple, non vérifié sur iPhone/TFT |
| Miroir d’une autre app alors que l’iPhone est verrouillé | Non garanti, non réalisé comme un affichage indépendant | Le partage iOS peut s’interrompre |
| Reconnexion au contact | Connexion BLE persistante au périphérique connu, serveurs TCP réarmés sans fermer les canaux actifs ; Wi-Fi enregistré par iOS | À tester sur la moto et dans les conditions réelles de verrouillage |
| Connexion Wi-Fi initiale | QR, trousseau local, configuration persistante si la signature autorise Hotspot Configuration ; association dans Réglages sinon | Ne pas ajouter automatiquement une capacité incompatible avec la Personal Team du Mac |
| Ajout simple d’applications | Liste prédéfinie ou un seul nom à saisir ; plus de préparation obligatoire dans Raccourcis | Les apps sans lien public fiable doivent être ouvertes normalement sur l’iPhone |
| DMD HUB | Ne tente plus un raccourci iOS inexistant ; ouverture manuelle guidée | Aucun lien natif public fiable confirmé ; ne pas annoncer une ouverture automatique réparée |
| Icône Double Interface | Icône existante à deux écrans appliquée à l’app et aux deux extensions de diffusion | Ressources vérifiées ; rendu installé à contrôler |
| Réglage d’écran par curseurs | Marges haute/basse et remise à zéro | Sources ; interface native à contrôler après compilation |
| Brevet et vente | Dossier préparatoire, provenance et premières références officielles | Aucun brevet déposé ; aucune publication ni vente lancée |

## Conditions pour considérer le prototype utilisable

La compilation iOS doit réussir. L’application doit être installée et les essais de TESTS_MOTO_9H.md doivent être exécutés. Une image fixe, un Bluetooth connecté ou des octets remis au réseau ne prouvent pas que le TFT décode et actualise la vidéo.

Le cockpit intégré est une réalisation distincte du conteneur multi-applications souhaité. Il ne doit jamais être présenté comme une intégration de Waze, OsmAnd ou DMD HUB. Un seul moteur de navigation intégré est actif à la fois ; les vues sont indépendantes, les itinéraires ne constituent pas trois applications autonomes.

## Mode de travail demandé

Nicolas a demandé de poursuivre le travail dans la session et a refusé les reprises programmées. L’automatisation créée a été désactivée. Ne pas annoncer de traitement continu après la fin d’une session. Ne pas recréer de reprises sans nouvelle demande.
