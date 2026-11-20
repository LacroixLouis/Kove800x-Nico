import Foundation
import CoreLocation
import Combine
import UIKit

class TelemetrySyncManager: ObservableObject {
    static let shared = TelemetrySyncManager()
    static let weatherEnabledKey = "optionalWeatherEnabled"
    
    @Published var currentAltitudeMeters: Int = 0
    @Published var currentTemperatureCelsius: Int? = nil
    @Published var currentWeatherCode: Int = 1 // 1 = Clear/Sunny default
    @Published var currentWindPower: String = "0"
    @Published var weatherIconName: String = "questionmark.circle"
    @Published private(set) var cockpitWeather: CockpitWeatherSnapshot?
    @Published private(set) var isWeatherLoading = false
    @Published private(set) var weatherError: String?
    private let cockpitWeatherKey = "rivet.weather.snapshot.v1"
    
    private let cachedAltitudeKey = "cached_altitude_meters"
    private let cachedTempKey = "cached_temp_celsius"
    private let cachedWeatherCodeKey = "cached_weather_code"
    private let cachedWindPowerKey = "cached_wind_power"
    private let cachedWeatherIconKey = "cached_weather_icon"
    private let cachedLatKey = "cached_location_lat"
    private let cachedLonKey = "cached_location_lon"
    
    private var syncTimer: Timer?
    private var weatherFetchTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastFetchedCoordinate: CLLocationCoordinate2D?
    private var lastSentAltitude: Int?
    private var lastSentTelemetryDate: Date = Date.distantPast
    private var weatherTask: URLSessionDataTask?
    private var weatherGeneration = UUID()
    private var lastWeatherAttempt = Date.distantPast
    
    weak var bleController: BleController?
    
    private init() {
        loadCachedTelemetry()
        setupLocationObserver()
        if let data = UserDefaults.standard.data(forKey: cockpitWeatherKey),
           let snapshot = try? JSONDecoder().decode(CockpitWeatherSnapshot.self, from: data) {
            cockpitWeather = snapshot
        }
        if !UserDefaults.standard.bool(forKey: Self.weatherEnabledKey)
            || cockpitWeather?.isStale() != false {
            currentTemperatureCelsius = nil
            weatherIconName = "questionmark.circle"
        }
    }
    
    func loadCachedTelemetry() {
        UserDefaults.standard.removeObject(forKey: cachedLatKey)
        UserDefaults.standard.removeObject(forKey: cachedLonKey)
        if UserDefaults.standard.object(forKey: cachedAltitudeKey) != nil {
            self.currentAltitudeMeters = UserDefaults.standard.integer(forKey: cachedAltitudeKey)
        }
        if UserDefaults.standard.object(forKey: cachedTempKey) != nil {
            self.currentTemperatureCelsius = UserDefaults.standard.integer(forKey: cachedTempKey)
        }
        if UserDefaults.standard.object(forKey: cachedWeatherCodeKey) != nil {
            self.currentWeatherCode = UserDefaults.standard.integer(forKey: cachedWeatherCodeKey)
        }
        if let wind = UserDefaults.standard.string(forKey: cachedWindPowerKey) {
            self.currentWindPower = wind
        }
        if let icon = UserDefaults.standard.string(forKey: cachedWeatherIconKey) {
            self.weatherIconName = icon
        }
    }
    
    func setWeatherEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.weatherEnabledKey)
        weatherGeneration = UUID()
        weatherTask?.cancel()
        weatherTask = nil
        isWeatherLoading = false
        weatherError = nil
        if enabled { fetchWeatherIfNeeded(force: true) }
        else {
            currentTemperatureCelsius = nil; lastFetchedCoordinate = nil; cockpitWeather = nil
            weatherIconName = "questionmark.circle"
            UserDefaults.standard.removeObject(forKey: cockpitWeatherKey)
        }
    }

    func refreshDashboardWeather() { fetchWeatherIfNeeded(force: true) }

    private func saveCachedTelemetry(temp: Int, weatherCode: Int, windPower: String, icon: String) {
        UserDefaults.standard.set(temp, forKey: cachedTempKey)
        UserDefaults.standard.set(weatherCode, forKey: cachedWeatherCodeKey)
        UserDefaults.standard.set(windPower, forKey: cachedWindPowerKey)
        UserDefaults.standard.set(icon, forKey: cachedWeatherIconKey)
        // Forecast responses are cached without writing location coordinates.
    }
    
    private func saveCachedAltitude(_ altitude: Int) {
        UserDefaults.standard.set(altitude, forKey: cachedAltitudeKey)
    }
    
    func startSync(bleController: BleController) {
        self.bleController = bleController
        
        syncTimer?.invalidate()
        weatherFetchTimer?.invalidate()
        
        // Start background location updates immediately
        LocationAndNavigationManager.shared.startUpdating()
        
        // Send initial telemetry packet immediately from cached/current state
        sendTelemetryPackets()
        
        // Fetch weather immediately if needed
        fetchWeatherIfNeeded(force: true)
        
        // Periodic sync to refresh TFT altitude & weather display every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendTelemetryPackets()
        }
        
        // Refresh weather API data every 10 minutes (600s)
        weatherFetchTimer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
            self?.fetchWeatherIfNeeded()
        }
        
        print("🌡️ Telemetry Sync Manager started (Periodic sync every 30s).")
        bleController.log("🌡️ Telemetry Sync Manager started. Initial Alt: \(currentAltitudeMeters)m, Temp: \(currentTemperatureCelsius.map { "\($0)°C" } ?? "pending").")
    }
    
    func stopSync() {
        syncTimer?.invalidate()
        weatherFetchTimer?.invalidate()
        syncTimer = nil
        weatherFetchTimer = nil
        print("🌡️ Telemetry Sync Manager stopped.")
        bleController?.log("🌡️ Telemetry Sync Manager stopped.")
    }
    
    private func setupLocationObserver() {
        LocationAndNavigationManager.shared.$userLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self else { return }
                let alt = Int(location.altitude)
                if alt != self.currentAltitudeMeters {
                    DispatchQueue.main.async {
                        self.currentAltitudeMeters = alt
                        self.saveCachedAltitude(alt)
                        // If altitude changed significantly (>= 5m), at least 10s elapsed, and BLE is active
                        let now = Date()
                        if let lastAlt = self.lastSentAltitude, abs(alt - lastAlt) >= 5,
                           now.timeIntervalSince(self.lastSentTelemetryDate) >= 10.0,
                           self.bleController?.connectionState == .connected {
                            self.sendTelemetryPackets()
                        }
                    }
                }
                self.fetchWeatherIfNeeded(location: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Optional weather (prototype API; commercial service still to configure)
    
    private func fetchWeatherIfNeeded(location: CLLocation? = LocationAndNavigationManager.shared.userLocation, force: Bool = false) {
        guard UserDefaults.standard.bool(forKey: Self.weatherEnabledKey), weatherTask == nil else { return }
        guard Date().timeIntervalSince(lastWeatherAttempt) >= (force ? 5 : 60) else { return }
        guard let location,
              ProjectionPolicy.isFresh(timestamp: location.timestamp, accuracy: location.horizontalAccuracy, now: Date()) else {
            weatherError = "Attends une position GPS récente pour charger la météo autour de toi."
            return
        }
        if !force, let lastCoordinate = lastFetchedCoordinate, let snapshot = cockpitWeather,
           Date().timeIntervalSince(snapshot.fetchedAt) < 600,
           location.distance(from: CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)) < 5_000 {
            return
        }
        guard let url = CockpitWeatherAPI.url(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) else { return }
        lastWeatherAttempt = Date()
        isWeatherLoading = true
        weatherError = nil
        let requestedCoordinate = location.coordinate
        let requestGeneration = weatherGeneration
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        bleController?.log("Météo : chargement Open-Meteo.")
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self, self.weatherGeneration == requestGeneration,
                      UserDefaults.standard.bool(forKey: Self.weatherEnabledKey) else { return }
                self.weatherTask = nil
                self.isWeatherLoading = false
                guard error == nil, let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode), let data, data.count <= 500_000 else {
                    self.weatherError = "Météo indisponible. Vérifie ta connexion Internet, puis réessaie."
                    return
                }
                do {
                    let snapshot = try CockpitWeatherAPI.decode(data)
                    self.cockpitWeather = snapshot
                    self.lastFetchedCoordinate = requestedCoordinate
                    self.currentTemperatureCelsius = Int(snapshot.temperature.rounded())
                    self.currentWeatherCode = self.mapOpenMeteoToKoveWeather(code: snapshot.code)
                    self.currentWindPower = String(Int(snapshot.windKmh.rounded()))
                    self.weatherIconName = snapshot.symbol
                    if let cached = try? JSONEncoder().encode(snapshot) {
                        UserDefaults.standard.set(cached, forKey: self.cockpitWeatherKey)
                    }
                    self.saveCachedTelemetry(temp: Int(snapshot.temperature.rounded()), weatherCode: self.currentWeatherCode,
                                             windPower: self.currentWindPower, icon: snapshot.symbol)
                    self.sendTelemetryPackets()
                } catch {
                    self.weatherError = "Les données météo reçues ne sont pas exploitables. Réessaie plus tard."
                }
            }
        }
        weatherTask = task
        task.resume()
    }

    // MARK: - Telemetry JSON Packet Formatting (Matching ThinkerRide / TinkerAPP)
    
    func sendTelemetryPackets() {
        guard let ble = bleController, ble.connectionState == .connected else {
            return
        }
        
        let alt = currentAltitudeMeters
        lastSentAltitude = alt
        lastSentTelemetryDate = Date()
        
        // 1. Elevation & Altitude Packet (JsonManager.sendElevationAndPond: msg_id 25, msg_type 9)
        let altJson = "{\"msg_id\":25,\"msg_type\":9,\"msg_source\":2,\"altitude\":\(alt),\"ave_altitude\":0,\"max_altitude\":0,\"pond_distance\":0.0,\"pond_time\":0,\"head\":0}"
        ble.sendJsonPacket(altJson)
        
        // 2. Weather & Temperature Packets (matching TinkerAPP: sendWeatherWithWindPower and sendWeather)
        if UserDefaults.standard.bool(forKey: Self.weatherEnabledKey),
           cockpitWeather?.isStale() == false, let temp = currentTemperatureCelsius {
            let tempStr = "\(temp)" // Integer string (e.g. "20" or "-5") without "°C"
            let wCode = currentWeatherCode
            let windStr = currentWindPower
            
            // Format A: Extended Weather with Wind Power (JsonManager.sendWeatherWithWindPower: msg_id 25, msg_type 11)
            let weatherWindJson = "{\"msg_id\":25,\"msg_type\":11,\"msg_source\":2,\"weather\":\(wCode),\"temperature\":\"\(tempStr)\",\"wind_power\":\"\(windStr)\"}"
            ble.sendJsonPacket(weatherWindJson)
            
            // Format B: Standard Weather (JsonManager.sendWeather: msg_id 8)
            let weatherJson = "{\"msg_id\":8,\"weather\":\(wCode),\"temperature\":\"\(tempStr)\"}"
            ble.sendJsonPacket(weatherJson)
            
            ble.log("📤 Telemetry Synced to TFT -> Alt: \(alt)m | Temp: \(tempStr)°C | Weather Code: \(wCode)")
            print("📤 Telemetry Synced to TFT -> Alt: \(alt)m | Temp: \(tempStr)°C | Weather Code: \(wCode)")
        } else {
            ble.log("📤 Telemetry Synced to TFT -> Alt: \(alt)m (Temperature pending)")
            print("📤 Telemetry Synced to TFT -> Alt: \(alt)m (Temperature pending)")
        }
    }
    
    // MARK: - Protocol Mappings
    
    private func mapOpenMeteoToKoveWeather(code: Int) -> Int {
        switch code {
        case 0, 1:
            return 1 // Sunny / Clear
        case 2:
            return 2 // Partly Cloudy
        case 3:
            return 3 // Overcast / Cloudy
        case 45, 48:
            return 18 // Fog
        case 51, 53, 55, 56, 57:
            return 7 // Light Rain / Drizzle
        case 61, 63:
            return 8 // Moderate Rain
        case 65, 66, 67:
            return 9 // Heavy Rain
        case 71, 73, 75, 77, 85, 86:
            return 14 // Snow
        case 80, 81, 82:
            return 10 // Showers
        case 95, 96, 99:
            return 4 // Thunderstorm
        default:
            return 1 // Default to Clear
        }
    }
    
    private func mapWeatherCodeToIcon(koveCode: Int) -> String {
        switch koveCode {
        case 1:
            return "sun.max.fill"
        case 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 4:
            return "cloud.bolt.rain.fill"
        case 7, 8:
            return "cloud.rain.fill"
        case 9, 10:
            return "cloud.heavyrain.fill"
        case 14:
            return "snowflake"
        case 18:
            return "cloud.fog.fill"
        default:
            return "sun.max.fill"
        }
    }
}
