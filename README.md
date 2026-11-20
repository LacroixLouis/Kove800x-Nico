# Double Interface

Projet iPhone de Nicolas pour afficher des cartes sur l’iPhone et le compteur
TFT d’origine de la Kove 800X Rally, via la liaison ThinkerRide.

**Livraison pour Louis — 20 novembre 2026.**
Sources complètes de la dernière révision « plein écran et centrage GPS »,
avec projet Xcode, tests et workflow GitHub Actions.

Commencer par **[REPRISE_LOUIS.md](REPRISE_LOUIS.md)** pour l’import dans GitHub
et les instructions de reprise.

| Repère | Chemin |
| --- | --- |
| Projet Xcode | `NicoMirror.xcodeproj` |
| Schéma partagé | `NicoMirror` |
| Workflow manuel | `.github/workflows/ios.yml` |
| Guide des deux cartes | [ESSAI_DEUX_ECRANS_WEB.md](ESSAI_DEUX_ECRANS_WEB.md) |
| Vérifications de la dernière révision | [VERIFICATION_ESSAI_WEB.json](VERIFICATION_ESSAI_WEB.json) |

La grande carte occupe l’écran, avec un menu flottant et une miniature déplaçable.
Toucher la miniature échange les deux cartes ; sa session devient la source du TFT.
Les cartes par défaut attendent une position récente avant leur premier centrage.

Ce mode utilise les **sites web Waze et Wikiloc** dans deux vues WebKit.
Le guidage des applications natives n’est pas intégré dans ces fenêtres.
Le point mobile et le suivi continu dépendent des possibilités des sites.

Les 84 sources Swift passent l’analyse syntaxique disponible et les 16 tests Python
passent. Les nouveaux tests Swift sont inclus ; leur exécution et la construction
iOS restent à effectuer sur un environnement Apple. Le plein écran, le centrage GPS
et le flux TFT de cette révision restent à vérifier sur l’appareil et la moto.

Base : **MapaX/KoveMirror**, licence MIT conservée dans [LICENSE](LICENSE).
Le commit d’origine figure dans [PROVENANCE.json](PROVENANCE.json).
Les anciens guides restent dans [HISTORIQUE_README.md](HISTORIQUE_README.md)
et [UPSTREAM_README.md](UPSTREAM_README.md).

