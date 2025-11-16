import Foundation
import SwiftUI

// MARK: - Expanded Swim Event Catalog
extension SwimEventDefinition {
    static let expandedCatalog: [SwimEventDefinition] = {
        var events: [SwimEventDefinition] = []
        
        // METERS - Freestyle
        events.append(SwimEventDefinition(distance: 25, displayName: "25m Freestyle", worldRecordSeconds: 10.5, unit: .meters))
        events.append(SwimEventDefinition(distance: 50, displayName: "50m Freestyle", worldRecordSeconds: 20.91, unit: .meters))
        events.append(SwimEventDefinition(distance: 100, displayName: "100m Freestyle", worldRecordSeconds: 46.86, unit: .meters))
        events.append(SwimEventDefinition(distance: 200, displayName: "200m Freestyle", worldRecordSeconds: 102.0, unit: .meters))
        events.append(SwimEventDefinition(distance: 400, displayName: "400m Freestyle", worldRecordSeconds: 220.07, unit: .meters))
        events.append(SwimEventDefinition(distance: 800, displayName: "800m Freestyle", worldRecordSeconds: 452.35, unit: .meters))
        events.append(SwimEventDefinition(distance: 1500, displayName: "1500m Freestyle", worldRecordSeconds: 870.95, unit: .meters))
        
        // METERS - Backstroke
        events.append(SwimEventDefinition(distance: 50.1, displayName: "50m Backstroke", worldRecordSeconds: 23.71, unit: .meters))
        events.append(SwimEventDefinition(distance: 100.1, displayName: "100m Backstroke", worldRecordSeconds: 51.60, unit: .meters))
        events.append(SwimEventDefinition(distance: 200.1, displayName: "200m Backstroke", worldRecordSeconds: 111.92, unit: .meters))
        
        // METERS - Breaststroke
        events.append(SwimEventDefinition(distance: 50.2, displayName: "50m Breaststroke", worldRecordSeconds: 25.95, unit: .meters))
        events.append(SwimEventDefinition(distance: 100.2, displayName: "100m Breaststroke", worldRecordSeconds: 56.88, unit: .meters))
        events.append(SwimEventDefinition(distance: 200.2, displayName: "200m Breaststroke", worldRecordSeconds: 125.95, unit: .meters))
        
        // METERS - Butterfly
        events.append(SwimEventDefinition(distance: 50.3, displayName: "50m Butterfly", worldRecordSeconds: 22.27, unit: .meters))
        events.append(SwimEventDefinition(distance: 100.3, displayName: "100m Butterfly", worldRecordSeconds: 49.45, unit: .meters))
        events.append(SwimEventDefinition(distance: 200.3, displayName: "200m Butterfly", worldRecordSeconds: 110.73, unit: .meters))
        
        // METERS - Individual Medley
        events.append(SwimEventDefinition(distance: 100.4, displayName: "100m IM", worldRecordSeconds: 51.30, unit: .meters))
        events.append(SwimEventDefinition(distance: 200.4, displayName: "200m IM", worldRecordSeconds: 110.34, unit: .meters))
        events.append(SwimEventDefinition(distance: 400.4, displayName: "400m IM", worldRecordSeconds: 240.54, unit: .meters))
        
        // YARDS - Freestyle (using 1000+ range for yards)
        events.append(SwimEventDefinition(distance: 1025, displayName: "25y Freestyle", worldRecordSeconds: 9.5, unit: .yards))
        events.append(SwimEventDefinition(distance: 1050, displayName: "50y Freestyle", worldRecordSeconds: 19.05, unit: .yards))
        events.append(SwimEventDefinition(distance: 1100, displayName: "100y Freestyle", worldRecordSeconds: 42.80, unit: .yards))
        events.append(SwimEventDefinition(distance: 1200, displayName: "200y Freestyle", worldRecordSeconds: 93.25, unit: .yards))
        events.append(SwimEventDefinition(distance: 1500, displayName: "500y Freestyle", worldRecordSeconds: 267.50, unit: .yards))
        events.append(SwimEventDefinition(distance: 11000, displayName: "1000y Freestyle", worldRecordSeconds: 537.53, unit: .yards))
        events.append(SwimEventDefinition(distance: 11650, displayName: "1650y Freestyle", worldRecordSeconds: 894.50, unit: .yards))
        
        // YARDS - Backstroke
        events.append(SwimEventDefinition(distance: 1050.1, displayName: "50y Backstroke", worldRecordSeconds: 21.66, unit: .yards))
        events.append(SwimEventDefinition(distance: 1100.1, displayName: "100y Backstroke", worldRecordSeconds: 47.08, unit: .yards))
        events.append(SwimEventDefinition(distance: 1200.1, displayName: "200y Backstroke", worldRecordSeconds: 102.13, unit: .yards))
        
        // YARDS - Breaststroke
        events.append(SwimEventDefinition(distance: 1050.2, displayName: "50y Breaststroke", worldRecordSeconds: 23.69, unit: .yards))
        events.append(SwimEventDefinition(distance: 1100.2, displayName: "100y Breaststroke", worldRecordSeconds: 51.90, unit: .yards))
        events.append(SwimEventDefinition(distance: 1200.2, displayName: "200y Breaststroke", worldRecordSeconds: 114.87, unit: .yards))
        
        // YARDS - Butterfly
        events.append(SwimEventDefinition(distance: 1050.3, displayName: "50y Butterfly", worldRecordSeconds: 20.32, unit: .yards))
        events.append(SwimEventDefinition(distance: 1100.3, displayName: "100y Butterfly", worldRecordSeconds: 45.19, unit: .yards))
        events.append(SwimEventDefinition(distance: 1200.3, displayName: "200y Butterfly", worldRecordSeconds: 101.27, unit: .yards))
        
        // YARDS - Individual Medley
        events.append(SwimEventDefinition(distance: 1100.4, displayName: "100y IM", worldRecordSeconds: 46.78, unit: .yards))
        events.append(SwimEventDefinition(distance: 1200.4, displayName: "200y IM", worldRecordSeconds: 100.79, unit: .yards))
        events.append(SwimEventDefinition(distance: 1400.4, displayName: "400y IM", worldRecordSeconds: 219.22, unit: .yards))
        
        return events
    }()
}

// MARK: - Persistence Models
struct SwimTimeRecord: Codable, Identifiable {
    let id: UUID
    let eventDistance: Double
    let timeInSeconds: TimeInterval
    let recordDate: Date
    
    init(id: UUID = UUID(), eventDistance: Double, timeInSeconds: TimeInterval, recordDate: Date) {
        self.id = id
        self.eventDistance = eventDistance
        self.timeInSeconds = timeInSeconds
        self.recordDate = recordDate
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
    
    func getBestTimeForEvent(_ eventDistance: Double) -> SwimTimeRecord? {
        let records = loadRecords()
        return records
            .filter { $0.eventDistance == eventDistance }
            .min(by: { $0.timeInSeconds < $1.timeInSeconds })
    }
    
    func getAllBestTimes() -> [SwimEventInput] {
        let records = loadRecords()
        var bestByEvent: [Double: SwimTimeRecord] = [:]
        
        for record in records {
            if let existing = bestByEvent[record.eventDistance],
               existing.timeInSeconds <= record.timeInSeconds {
                continue
            }
            bestByEvent[record.eventDistance] = record
        }
        
        return bestByEvent.values.compactMap { record in
            guard let definition = SwimEventDefinition.expandedCatalog.first(where: { $0.distance == record.eventDistance }) else {
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
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    @Published var milliseconds: Int = 0
    @Published var recordDate = Date()
    @Published var showSuccessAlert = false
    @Published var records: [SwimTimeRecord] = []
    
    private let persistence = SwimTimePersistence()
    
    let availableEvents = SwimEventDefinition.expandedCatalog.sorted { $0.distance < $1.distance }
    
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
    
    func getEventName(for distance: Double) -> String {
        return availableEvents.first { $0.distance == distance }?.displayName ?? "Unknown Event"
    }
}
