import Combine
import Foundation
import SwiftUI

// MARK: - Persistence Models
struct SwimTimeRecord: Codable, Identifiable {
    let id: UUID
    let eventDistance: Double
    let eventUnit: DistanceUnit
    let timeInSeconds: TimeInterval
    let recordDate: Date

    init(id: UUID = UUID(), eventDistance: Double, eventUnit: DistanceUnit = .meters, timeInSeconds: TimeInterval, recordDate: Date) {
        self.id = id
        self.eventDistance = eventDistance
        self.eventUnit = eventUnit
        self.timeInSeconds = timeInSeconds
        self.recordDate = recordDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventDistance
        case eventUnit
        case timeInSeconds
        case recordDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventDistance = try container.decode(Double.self, forKey: .eventDistance)
        eventUnit = try container.decodeIfPresent(DistanceUnit.self, forKey: .eventUnit) ?? .meters
        timeInSeconds = try container.decode(TimeInterval.self, forKey: .timeInSeconds)
        recordDate = try container.decode(Date.self, forKey: .recordDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventDistance, forKey: .eventDistance)
        try container.encode(eventUnit, forKey: .eventUnit)
        try container.encode(timeInSeconds, forKey: .timeInSeconds)
        try container.encode(recordDate, forKey: .recordDate)
    }
}

// MARK: - Persistence Manager
class SwimTimePersistence {
    private let recordsKey = "hunter.swim.records"
    
    func loadRecords() -> [SwimTimeRecord] {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([SwimTimeRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    func saveRecords(_ records: [SwimTimeRecord]) {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
    }
    
    func addRecord(_ record: SwimTimeRecord) {
        var records = loadRecords()
        records.append(record)
        saveRecords(records)
    }
    
    func deleteRecord(_ record: SwimTimeRecord) {
        var records = loadRecords()
        records.removeAll { $0.id == record.id }
        saveRecords(records)
    }
    
    func getBestTimeForEvent(_ eventDistance: Double, unit: DistanceUnit) -> SwimTimeRecord? {
        let records = loadRecords()
        return records
            .filter { $0.eventDistance == eventDistance && $0.eventUnit == unit }
            .min(by: { $0.timeInSeconds < $1.timeInSeconds })
    }
    
    func getAllBestTimes() -> [SwimEventInput] {
        let records = loadRecords()
        var bestByEvent: [String: SwimTimeRecord] = [:]

        for record in records {
            let key = "\(record.eventUnit.rawValue)-\(record.eventDistance)"
            if let existing = bestByEvent[key], existing.timeInSeconds <= record.timeInSeconds {
                continue
            }
            bestByEvent[key] = record
        }

        return bestByEvent.values.compactMap { record in
            guard let definition = SwimEventDefinition.expandedCatalog.first(where: { $0.distance == record.eventDistance && $0.unit == record.eventUnit }) else {
                return nil
            }
            return SwimEventInput(
                definition: definition,
                personalRecordSeconds: record.timeInSeconds,
                recordDate: record.recordDate
            )
        }
    }
}

// MARK: - Input View Model
@MainActor
class SwimTimeInputViewModel: ObservableObject {
    @Published var selectedEvent: SwimEventDefinition?
    @Published var selectedUnit: DistanceUnit = .meters {
        didSet {
            if let event = selectedEvent, event.unit != selectedUnit {
                selectedEvent = nil
            }
        }
    }
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    @Published var milliseconds: Int = 0
    @Published var recordDate = Date()
    @Published var showSuccessAlert = false
    @Published var records: [SwimTimeRecord] = []

    private let persistence = SwimTimePersistence()

    let availableEvents = SwimEventDefinition.expandedCatalog.sorted {
        if $0.unit == $1.unit {
            return $0.distance < $1.distance
        }
        return $0.unit.sortOrder < $1.unit.sortOrder
    }

    var filteredEvents: [SwimEventDefinition] {
        availableEvents.filter { $0.unit == selectedUnit }
    }
    
    init() {
        loadRecords()
    }
    
    func loadRecords() {
        records = persistence.loadRecords().sorted { $0.recordDate > $1.recordDate }
    }
    
    var totalSeconds: TimeInterval {
        return Double(minutes * 60) + Double(seconds) + (Double(milliseconds) / 100.0)
    }
    
    var canSubmit: Bool {
        guard selectedEvent != nil else { return false }
        return totalSeconds > 0
    }
    
    func submitTime() {
        guard let event = selectedEvent else { return }
        
        let record = SwimTimeRecord(
            eventDistance: event.distance,
            eventUnit: event.unit,
            timeInSeconds: totalSeconds,
            recordDate: recordDate
        )
        
        persistence.addRecord(record)
        loadRecords()
        showSuccessAlert = true
        resetForm()
    }
    
    func deleteRecord(_ record: SwimTimeRecord) {
        persistence.deleteRecord(record)
        loadRecords()
    }
    
    private func resetForm() {
        minutes = 0
        seconds = 0
        milliseconds = 0
        recordDate = Date()
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        return seconds.formattedTime()
    }
    
    func getEventName(for record: SwimTimeRecord) -> String {
        return availableEvents.first { $0.distance == record.eventDistance && $0.unit == record.eventUnit }?.displayName ?? "Unknown Event"
    }
}
