# Interface actuelle — cockpit v6

L’accueil utilise désormais le thème sombre Double Interface, les icônes originales, deux dispositions de widgets, la météo facultative et l’atelier. Le choix de langue est disponible dans le menu. Voir **NOUVEAUTES_V6.md** pour l’utilisation et la mise à jour.

# Interface Double Interface — version candidate actuelle

La version actuelle est décrite dans NOUVEAUTES_V5.md.

- L’icône à deux écrans porte Double Interface en bas à gauche et est appliquée aussi aux extensions de diffusion.
- Mes GPS & mes fichiers réunit l’import d’une trace, le partage du GPX d’origine vers les GPS qui l’acceptent et le partage d’une position récente.
- Mes deux écrans permet de choisir Navigation, Trace GPX ou Compteurs séparément pour le téléphone et le TFT. Il s’agit de nos propres vues intégrées.
- Menu → Application à afficher → Ajouter une appli : une liste ou un seul nom à saisir. La création d’un raccourci iOS n’est plus demandée pour les nouveaux boutons.
- Les apps dotées d’un lien pris en charge s’ouvrent directement. Les autres, dont DMD HUB, doivent être ouvertes depuis l’accueil de l’iPhone pendant la diffusion. Les anciens raccourcis déjà préparés restent utilisables.
- Réglages : curseurs des marges, connexion au contact, maintien de liaison et météo facultative.

Pour installer la modification du code sur le Mac déjà configuré : lancer Mettre_a_jour_sur_Mac.command dans le nouveau dossier, choisir le projet existant, puis Commande + R dans Xcode avec l’iPhone connecté. La sauvegarde conserve les fichiers remplacés. La mise à jour ne remplace pas les équipes ou les identifiants Apple, ne force pas une capacité incompatible et ne change pas le nom choisi sur le Mac.

Voir TESTS_MOTO_9H.md pour les essais. Aucune compatibilité matérielle ni continuité écran verrouillé n’est déclarée validée avant ces essais. Cette version ne contient pas de conteneur capable d’héberger librement les autres apps iPhone.
