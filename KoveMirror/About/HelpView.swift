import SwiftUI

struct HelpView: View {
    var body: some View {
        RideSheet("Un coup de main") {
            Text("Du téléphone\nau compteur.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                RideSectionTitle(number: "01", title: "Connecter ta Kove")
                Text("Mets le contact et affiche le mode navigation du compteur. Dans Connexion à la Kove, scanne une fois son QR Wi-Fi et autorise la connexion. Le réseau est enregistré pour la reconnexion au contact. Le réseau peut être indiqué « sans Internet ».")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
                Text("Si THINKERRIDE utilise déjà la connexion, ferme cette app. Reviens ici et ouvre Connexion à la Kove.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                RideSectionTitle(number: "02", title: "Choisir tes raccourcis")
                Text("Menu → Application à afficher → Ajouter une appli. Touche un nom dans la liste, ou saisis le nom d’une autre appli. Pour DMD HUB et les applis ajoutées par leur nom, ouvre-les normalement depuis l’accueil de l’iPhone pendant la diffusion.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                RideSectionTitle(number: "03", title: "Toucher, ouvrir, diffuser")
                Text("Touche un raccourci. Si nécessaire, termine la connexion et touche le bouton rond de diffusion, puis valide la fenêtre iOS. L’app choisie s’ouvre quand la diffusion et la liaison vidéo sont connectées.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
                Text("OsmAnd, Waze, Wikiloc et Plans ont une ouverture directe. Les autres boutons préparent la diffusion et t’indiquent d’ouvrir l’app sur l’iPhone. Les anciens raccourcis iOS déjà configurés sont conservés.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Label("Comprendre les deux modes", systemImage: "rectangle.on.rectangle").font(.headline)
                Text("Miroir : le TFT suit tout l’écran de l’iPhone, y compris les changements d’application.")
                Text("Carte & GPX : l’app peut produire son propre tracé pour le TFT. Ce mode d’essai ne déporte pas une autre app indépendamment.")
                Text("Écran verrouillé : la liaison utilise une session de trajet avec localisation en arrière-plan. Cela ne permet pas de transmettre l’écran verrouillé d’une autre application. Après l’arrêt du partage complet, iOS demande de le démarrer à nouveau.")
            }
            RideCard {
                Label("Une image reste figée ?", systemImage: "pause.rectangle").font(.headline)
                Text("Une image présente à l’écran ne suffit pas à prouver qu’elle s’actualise. Vérifie la diffusion iOS et la liaison Wi-Fi. Le menu Diagnostic aide à voir le mode de sortie et à partager un rapport.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
        }
    }
}
