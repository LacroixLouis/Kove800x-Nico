> Révision actuelle : lire NOUVEAUTES_V6.md et TESTS_MOTO_9H.md. Les notes plus anciennes ci-dessous ne remplacent pas ces instructions.

# Démarrer sur le Mac — version 2 expérimentale

Ce dossier contient les sources de NicoMirror, pas une application installable.
Le mode iPhone verrouillé reste à valider sur l'iPhone et le compteur de la Kove.

## Chemin simple avec Xcode

1. Décompresser l'archive et ouvrir `NicoMirror.xcodeproj`.
2. Installer les composants demandés par Xcode et brancher l'iPhone par câble.
3. Ajouter le compte Apple dans les réglages de Xcode et configurer la signature
   automatique avec la même équipe pour l'application et ses extensions.
4. Vérifier les capacités et le groupe partagé avec `Guide_Mac_NicoMirror.md`.
5. Choisir le schéma **NicoMirror**, puis l'iPhone réel comme destination.
6. Faire **Commande + B** pour compiler, puis **Commande + R** pour installer/lancer.

Une version de Xcode compatible avec l'iPhone et le Mac est nécessaire. Le projet
cible iOS 26 au minimum. Une Personal Team peut bloquer sur certaines capacités :
conserver le message exact, ne pas supprimer les capacités au hasard.

## Commandes préparées

- `Verifier_Mac.command` : vérifie macOS, Xcode, ses composants iOS et les
  destinations de compilation. Ce script ne change pas les réglages Apple.
- `Installer_sur_iPhone.command` : demande le Team ID et l'identifiant de l'iPhone,
  exécute les tests portables, compile avec la signature automatique de Xcode,
  vérifie la signature et tente l'installation par l'outil Apple `devicectl`.

Ces fichiers peuvent être ouverts depuis Terminal si macOS ne les lance pas au
double-clic. Depuis le dossier NicoMirror :

```bash
bash scripts/check-mac.sh
```

La signature doit d'abord être configurée dans Xcode. Le Team ID est l'identifiant
de dix caractères de l'équipe Apple ; l'UDID se relève dans les appareils de Xcode.
Pour utiliser la voie en ligne de commande :

```bash
bash scripts/build-and-install.sh TEAM_ID UDID_IPHONE
```

Remplacer les deux valeurs. Le script peut créer/mettre à jour les profils Apple
et enregistrer l'iPhone via la signature automatique. Les mots de passe et codes
Apple se saisissent uniquement dans Xcode. Le script ne publie pas sur TestFlight.

Un dossier `build-signed-…` contient les journaux des tests, de compilation et
d'installation, ainsi que le résultat Xcode `.xcresult`. Si une étape échoue, les
suivantes ne doivent pas s'exécuter. Une installation réussie ne garantit pas que
le compteur décode la vidéo ni qu'iOS la maintient après verrouillage.

## Essai sur l'iPhone et la Kove

1. Connecter NicoMirror, autoriser réseau local/Bluetooth/localisation et vérifier
   d'abord le miroir téléphone déverrouillé.
2. Activer **Navigation iPhone verrouillé (expérimental)** dans les réglages.
3. Démarrer un itinéraire dans la carte NicoMirror ; ouvrir seulement l'app ne
   suffit pas. Le mode ne recopie pas Google Maps ou une autre app verrouillée.
4. Verrouiller avec le bouton latéral. Avec des événements GPS, le nouveau chemin
   de code tente de transmettre un tracé simplifié, des consignes et la vitesse.
5. Déverrouiller et consulter **Diagnostic du mode verrouillé** sur l'accueil.
   Le bouton de partage produit un rapport JSON sans coordonnées ni destination.

Les compteurs indiquent les images encodées et les octets dont l'envoi local a été
confirmé. Ils ne prouvent pas que le compteur affiche ces images. Vérifier l'heure
GPS sur le compteur avec de nouvelles positions ; à l'arrêt, l'image peut rester
fixe faute d'événement GPS. Manipulations à l'arrêt ou par un passager testeur.

Tester : verrouillage/déverrouillage répété, arrêt de navigation, perte de GPS,
perte/reconnexion vidéo, option désactivée, avec et sans ReplayKit. En cas de gel,
déverrouiller et exporter le diagnostic. La dernière erreur peut rester visible
après une récupération ; utiliser les heures et le rapport pour l'interpréter.

## Contrôles et limites de cette livraison

- Analyse syntaxique Swift, vérification des plist/schémas et syntaxe des scripts.
- Tests Python exécutés sur les scripts avec outils Apple simulés : espaces dans
  les chemins, échecs des tests/de compilation/de signature, identifiants invalides.
- Tests Swift ajoutés pour les transitions, la fraîcheur GPS et la reprise H.264
  après un découpage TCP arbitraire ; **non exécutés ici**, faute de Swift/Xcode.
- **Aucune compilation iOS, signature Apple, installation ou validation Kove ici.**

Consulter `VERIFICATION.json`, `CHANGEMENTS_V2.md` et `NAVIGATION_VERROUILLEE.md`.
