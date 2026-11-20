# Version 2 — prototype de navigation verrouillée

## Gestion des flux

Un coordinateur choisit désormais une seule source vidéo : miroir intégré,
ReplayKit, navigation GPS, ou pause. Il réévalue ce choix au verrouillage/retour au
premier plan, à l'arrêt de la navigation, au changement d'option et à la connexion
ou perte du flux vidéo. Les deux encodeurs sont arrêtés avant un changement de
source. Le serveur rejette les données des sources non sélectionnées.
Une diffusion ReplayKit existante est conservée sans itinéraire interne lorsque
l’on ouvre une autre application. Le mode GPS est déclenché par le passage en
arrière-plan pendant une navigation interne ; il ne prétend pas distinguer un
verrouillage d’un changement d’application.

Après retour vers ReplayKit, un resynchroniseur attend le prochain en-tête SPS
H.264 au lieu de transmettre immédiatement une fin de paquet vidéo. Il sait gérer
les préfixes Annex B répartis sur plusieurs lectures TCP et ne conserve que quatre
octets pendant l'attente. La base de l'encodeur émet SPS/PPS avant les images clés.

## Navigation en arrière-plan

Le rendu GPS utilise une horloge monotone pour limiter sa cadence ; un changement
d'heure du téléphone ne doit plus bloquer la production d'images. Les positions
invalides, trop anciennes ou excessivement datées dans le futur sont écartées du
guidage présenté comme actuel. Le format d'image reste fixe pendant chaque session
du rendu GPS ; après un changement de résolution, refaire la connexion vidéo et
vérifier la négociation avant de valider le résultat.

L'encodeur renvoie ses erreurs de démarrage et d'encodage, y compris celles de son
callback. En cas d'échec, le mode GPS limite la reprise à trois tentatives espacées
d'au moins cinq secondes et déclenchées par les prochains événements GPS, pas par
un service qui contournerait les règles iOS. Déverrouiller/reverrouiller relance
une nouvelle session d'essai. La disponibilité réelle de l'encodeur après
verrouillage reste inconnue avant test sur appareil.

## Diagnostic

L'accueil comporte une carte indiquant le mode choisi, le nombre d'images de
navigation encodées, les octets vidéo dont l'envoi local est terminé, l'heure du
GPS et la dernière erreur. Un bouton exporte les observations en JSON. Ce rapport
n'inclut ni positions, ni destination, ni identifiants Wi-Fi ou de signature.
Les chiffres sont des observations locales, sans confirmation de décodage du TFT.

## Préparation Mac

Deux fichiers `.command` accompagnent les scripts : vérification du Mac et
compilation/installation signées. Cette dernière voie demande une équipe Apple
configurée et l'iPhone branché. Elle garde les journaux et s'arrête si les tests,
la compilation ou la vérification de signature échouent. L'installation est
effectuée par l'outil Apple, sans publication TestFlight.

## Limites conservées

Navigation interne et tracé simplifié uniquement quand le téléphone est verrouillé.
Pas de recopie d'une autre application après verrouillage, pas de fond de carte,
pas de garantie de continuité sur iOS. Le calcul de distance à la manœuvre et le
suivi d'itinéraire conservent les limites de la base. Les tests Swift sont inclus
mais restent à exécuter sur le Mac. Consulter le rapport de vérification pour les
contrôles réellement réalisés.
