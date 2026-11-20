import SwiftUI

struct HelpView: View {
    var body: some View {
        RideSheet("Un coup de main") {
            Text("Tes deux écrans.").font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                RideSectionTitle(number: "01", title: "Choisir les contenus")
                Text("Ouvre Mes deux écrans. Touche le grand écran vide pour choisir la navigation Double Interface ou un site web. Tu peux tout préparer sans connecter la moto.")
            }
            RideCard {
                RideSectionTitle(number: "02", title: "Échanger et déplacer")
                Text("Touche la petite fenêtre : le grand contenu devient petit, et le petit devient grand. Si l’autre fenêtre est vide, touche-la ensuite pour choisir le second contenu. Glisse la miniature pour la déplacer.")
            }
            RideCard {
                RideSectionTitle(number: "03", title: "Utiliser la navigation")
                Text("Affiche la navigation en grand. Destination permet de chercher un lieu et de lancer le guidage. Dans le menu, importe une trace GPX, affiche tout le tracé ou arrête le guidage.")
            }
            RideCard {
                RideSectionTitle(number: "04", title: "Connecter ta Kove")
                Text("Mets le contact et affiche le mode navigation du compteur. Ouvre Connexion, scanne son QR Wi-Fi et autorise la liaison. Retourne aux deux écrans : le TFT reçoit uniquement la miniature, agrandie.")
                Text("Les menus et le grand écran ne sont pas envoyés au TFT. L’envoi se met en pause quand tu quittes les deux écrans ou que l’iPhone passe en arrière-plan.")
            }
            RideCard {
                Label("Cartes et Internet", systemImage: "globe").font(.headline)
                Text("La navigation intégrée utilise les cartes Apple. Waze et Wikiloc sont affichés comme sites web. Le calcul routier et les cartes en ligne nécessitent Internet. Les fonctions disponibles sur les sites dépendent de leurs fournisseurs.")
                Text("Garde Double Interface au premier plan et l’iPhone déverrouillé pour l’envoi de la miniature.")
            }
            RideCard {
                Label("Une image reste figée ?", systemImage: "pause.rectangle").font(.headline)
                Text("Vérifie la liaison Wi-Fi et l’état de la miniature dans le menu État et aide. Une image préparée sur l’iPhone ne confirme pas sa réception par le TFT.")
            }
        }
    }
}
