import Foundation

@MainActor
class CreateEventViewModel: ObservableObject {
    @Published var name = ""
    @Published var description = ""
    @Published var location = ""
    @Published var locationName: String?
    @Published var locationAddress: String?
    @Published var locationLat: Double?
    @Published var locationLng: Double?
    @Published var startDate = Date()
    @Published var startHour = Calendar.current.component(.hour, from: Date())
    @Published var startMinute = 0  // 0 or 30
    @Published var hasEndTime = false
    @Published var endDate = Date()
    @Published var endHour = Calendar.current.component(.hour, from: Date().addingTimeInterval(3600 * 4))
    @Published var endMinute = 0
    @Published var isCreating = false

    private let eventService = EventService()

    var startTime: Date {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: startDate)
        components.hour = startHour
        components.minute = startMinute
        return cal.date(from: components) ?? startDate
    }

    var endTime: Date? {
        guard hasEndTime else { return nil }
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: endDate)
        components.hour = endHour
        components.minute = endMinute
        return cal.date(from: components) ?? endDate
    }

    var isValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if hasEndTime {
            guard let end = endTime else { return false }
            return nameValid && end > startTime
        }
        return nameValid
    }

    func clearLocation() {
        location = ""
        locationName = nil
        locationAddress = nil
        locationLat = nil
        locationLng = nil
    }

    func setLocation(name: String, address: String, lat: Double, lng: Double) {
        locationName = name
        locationAddress = address
        locationLat = lat
        locationLng = lng
        location = name
    }

    func createEvent() async throws -> Event {
        isCreating = true
        defer { isCreating = false }

        // If no end time, default to 24 hours after start
        let resolvedEndTime = endTime ?? startTime.addingTimeInterval(3600 * 24)

        return try await eventService.createEvent(
            name: name,
            description: description.isEmpty ? nil : description,
            location: location.isEmpty ? nil : location,
            locationName: locationName,
            locationAddress: locationAddress,
            locationLat: locationLat,
            locationLng: locationLng,
            startTime: startTime,
            endTime: resolvedEndTime
        )
    }
}
