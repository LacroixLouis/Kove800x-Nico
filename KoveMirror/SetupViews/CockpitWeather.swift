import Foundation

struct CockpitWeatherHour: Codable, Equatable, Identifiable {
    let timestamp: TimeInterval
    let temperature: Double
    let rainProbability: Int?
    let code: Int
    var id: TimeInterval { timestamp }
    var date: Date { Date(timeIntervalSince1970: timestamp) }
}

struct CockpitWeatherSnapshot: Codable, Equatable {
    let fetchedAt: Date
    let observationDate: Date
    let temperature: Double
    let windKmh: Double
    let code: Int
    let isDay: Bool
    let hours: [CockpitWeatherHour]

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > 7_200 || now.timeIntervalSince(observationDate) > 10_800
        || fetchedAt.timeIntervalSince(now) > 300
    }

    var condition: String { Self.condition(for: code) }
    var symbol: String { Self.symbol(for: code, isDay: isDay) }

    static func condition(for code: Int) -> String {
        switch code {
        case 0: return "Ciel dégagé"
        case 1: return "Peu nuageux"
        case 2: return "Éclaircies"
        case 3: return "Couvert"
        case 45, 48: return "Brouillard"
        case 51, 53, 55: return "Bruine"
        case 56, 57, 66, 67: return "Pluie verglaçante"
        case 61, 63, 65: return "Pluie"
        case 71, 73, 75, 77: return "Neige"
        case 80, 81, 82: return "Averses"
        case 85, 86: return "Averses de neige"
        case 95, 96, 99: return "Orage"
        default: return "Conditions indisponibles"
        }
    }
    static func symbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}

enum CockpitWeatherAPI {
    static func url(latitude: Double, longitude: Double) -> URL? {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        // Only this rounded position leaves the device. No coordinate is cached.
        parts.queryItems = [
            URLQueryItem(name: "latitude", value: String((latitude * 100).rounded() / 100)),
            URLQueryItem(name: "longitude", value: String((longitude * 100).rounded() / 100)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "forecast_hours", value: "8"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return parts.url
    }

    static func decode(_ data: Data, fetchedAt: Date = Date()) throws -> CockpitWeatherSnapshot {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let current = response.current
        let knownCodes: Set<Int> = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65,
                                   66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        guard (-100...70).contains(current.temperature), (0...500).contains(current.wind),
              knownCodes.contains(current.code), (0...1).contains(current.isDay),
              current.time.isFinite, current.time <= fetchedAt.timeIntervalSince1970 + 900,
              fetchedAt.timeIntervalSince1970 - current.time < 86_400 else { throw WeatherError.invalidResponse }
        var hours: [CockpitWeatherHour] = []
        if let hourly = response.hourly {
            for index in hourly.time.indices {
                guard index < hourly.temperature.count, index < hourly.code.count,
                      let temperature = hourly.temperature[index], (-100...70).contains(temperature),
                      let code = hourly.code[index], hourly.time[index] >= fetchedAt.timeIntervalSince1970 - 900 else { continue }
                let probability = index < hourly.rain.count ? hourly.rain[index] : nil
                hours.append(CockpitWeatherHour(timestamp: hourly.time[index], temperature: temperature,
                    rainProbability: probability.flatMap { (0...100).contains($0) ? $0 : nil }, code: code))
            }
        }
        return CockpitWeatherSnapshot(fetchedAt: fetchedAt, observationDate: Date(timeIntervalSince1970: current.time),
            temperature: current.temperature, windKmh: current.wind, code: current.code,
            isDay: current.isDay == 1, hours: Array(hours.prefix(6)))
    }

    enum WeatherError: Error { case invalidResponse }
    private struct Response: Decodable { let current: Current; let hourly: Hourly? }
    private struct Current: Decodable {
        let time: Double
        let temperature: Double
        let wind: Double
        let code: Int
        let isDay: Int
        enum CodingKeys: String, CodingKey {
            case time, temperature = "temperature_2m", wind = "wind_speed_10m", code = "weather_code", isDay = "is_day"
        }
    }
    private struct Hourly: Decodable {
        let time: [Double]
        let temperature: [Double?]
        let rain: [Int?]
        let code: [Int?]
        enum CodingKeys: String, CodingKey {
            case time, temperature = "temperature_2m", rain = "precipitation_probability", code = "weather_code"
        }
    }
}
