import SwiftUI
import CoreLocation

struct CockpitWeatherWidget: View {
    @ObservedObject private var weather = TelemetrySyncManager.shared
    @ObservedObject private var navigation = LocationAndNavigationManager.shared
    @AppStorage(TelemetrySyncManager.weatherEnabledKey) private var enabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("LA MÉTÉO DE TA SORTIE", systemImage: "location.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                Spacer(minLength: 0)
                if enabled {
                    Button(action: refresh) {
                        Group {
                            if weather.isWeatherLoading { ProgressView().tint(RivetCockpit.lime) }
                            else { Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .bold)) }
                        }.frame(width: 44, height: 44)
                    }
                    .buttonStyle(RivetPressStyle())
                    .disabled(weather.isWeatherLoading)
                    .accessibilityLabel("Actualiser la météo")
                }
            }
            .foregroundStyle(RivetCockpit.secondary)

            if enabled, let snapshot = weather.cockpitWeather {
                weatherContent(snapshot)
                if let message = weather.weatherError {
                    Label(LocalizedStringKey(message), systemImage: "wifi.exclamationmark")
                        .font(.caption).foregroundStyle(RivetCockpit.orange)
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.palette).foregroundStyle(RivetCockpit.lime, RivetCockpit.paper)
                        .font(.system(size: 46))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(enabled ? "On regarde le ciel…" : "Avant de prendre le large."))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                        Text(LocalizedStringKey(enabled ? (weather.weatherError ?? "Recherche des conditions autour de toi.")
                             : "Température, vent et pluie pour les prochaines heures."))
                            .font(.caption).foregroundStyle(RivetCockpit.secondary)
                    }
                }
                if !enabled {
                    Button("Activer la météo", systemImage: "cloud.sun") {
                        enabled = true
                        navigation.requestDashboardWeatherLocation()
                    }
                    .font(.subheadline.weight(.bold)).foregroundStyle(RivetCockpit.asphalt)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RivetCockpit.lime).clipShape(RoundedRectangle(cornerRadius: 14))
                    .buttonStyle(RivetPressStyle())
                    Text("La position approximative est transmise à Open-Meteo.")
                        .font(.caption2).foregroundStyle(RivetCockpit.secondary)
                } else if navigation.authorizationStatus == .denied || navigation.authorizationStatus == .restricted {
                    Button("Autoriser la localisation dans Réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(RivetCockpit.lime)
                    .frame(minHeight: 44)
                }
            }

            if enabled {
                HStack {
                    Link("Open-Meteo · données météo", destination: URL(string: "https://open-meteo.com/")!)
                    Spacer(minLength: 0)
                    Button("Désactiver") { enabled = false }
                }
                .font(.caption2).foregroundStyle(RivetCockpit.secondary)
            }
        }
        .foregroundStyle(RivetCockpit.paper)
        .padding(20)
        .background(RivetCockpit.panel)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(RivetCockpit.line))
        .task(id: enabled) {
            guard enabled else { return }
            while !Task.isCancelled {
                if scenePhase == .active { refresh() }
                do { try await Task.sleep(for: .seconds(600)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active && enabled { refresh() } }
        .onChange(of: enabled) { _, value in weather.setWeatherEnabled(value) }
    }

    private func refresh() {
        guard enabled else { return }
        navigation.requestDashboardWeatherLocation()
        weather.refreshDashboardWeather()
    }

    private func weatherContent(_ snapshot: CockpitWeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(snapshot.temperature.rounded()))°")
                        .font(.system(size: 62, weight: .heavy, design: .rounded)).tracking(-3)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(Int(snapshot.temperature.rounded())) degrés Celsius")
                    Text(LocalizedStringKey(snapshot.condition)).font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: snapshot.symbol).symbolRenderingMode(.palette)
                    .foregroundStyle(RivetCockpit.lime, RivetCockpit.paper)
                    .font(.system(size: 57)).accessibilityHidden(true)
            }
            HStack(spacing: 14) {
                Label("\(Int(snapshot.windKmh.rounded())) km/h", systemImage: "wind")
                Text("Autour de toi")
            }
            .font(.caption.weight(.semibold)).foregroundStyle(RivetCockpit.secondary)
            HStack {
                Text("Actualisé à \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                if snapshot.isStale() {
                    Label("Anciennes données", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(RivetCockpit.orange)
                }
            }
            .font(.caption2).foregroundStyle(RivetCockpit.secondary)
            if !snapshot.hours.isEmpty {
                Divider().overlay(RivetCockpit.line)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 23) {
                        ForEach(snapshot.hours) { hour in
                            VStack(spacing: 8) {
                                Text(hour.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                                    .foregroundStyle(RivetCockpit.secondary)
                                Image(systemName: CockpitWeatherSnapshot.symbol(for: hour.code,
                                    isDay: Calendar.current.component(.hour, from: hour.date) >= 7
                                        && Calendar.current.component(.hour, from: hour.date) < 19))
                                    .foregroundStyle(RivetCockpit.lime).font(.system(size: 20))
                                Text("\(Int(hour.temperature.rounded()))°").fontWeight(.bold)
                                Text(hour.rainProbability.map { "\($0) %" } ?? "—")
                                    .foregroundStyle(RivetCockpit.secondary).font(.system(size: 10))
                            }
                            .font(.caption).frame(minWidth: 32)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}
