import SwiftUI

struct SleepSummaryView: View {
    let sleepData: SleepData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Summary")
                .font(.headline)
            
            if let sleep = sleepData {
                VStack(spacing: 16) {
                    // Total sleep
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        Text("Total Sleep")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(formatHours(sleep.totalDuration))
                            .font(.headline)
                    }
                    
                    // Sleep stages
                    if sleep.hasDetailedStages {
                        Divider()
                        
                        VStack(spacing: 12) {
                            SleepStageRow(
                                title: "Deep Sleep",
                                duration: sleep.deepSleepDuration,
                                color: .purple,
                                icon: "moon.zzz.fill"
                            )
                            
                            SleepStageRow(
                                title: "REM Sleep",
                                duration: sleep.remSleepDuration,
                                color: .indigo,
                                icon: "brain.head.profile"
                            )
                            
                            SleepStageRow(
                                title: "Core Sleep",
                                duration: sleep.coreSleepDuration,
                                color: .cyan,
                                icon: "cloud.moon.fill"
                            )
                        }
                    }
                    
                    // Sleep quality indicator
                    Divider()
                    
                    HStack {
                        Text("Sleep Quality")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        sleepQualityBadge(sleep.totalDuration)
                    }
                }
            } else {
                Text("No sleep data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        return "\(h)h \(minutes)m"
    }
    
    private func sleepQualityBadge(_ totalHours: Double) -> some View {
        let (text, color): (String, Color) = {
            switch totalHours {
            case 7...9: return ("Optimal", .green)
            case 6..<7, 9..<10: return ("Good", .yellow)
            default: return ("Poor", .red)
            }
        }()
        
        return Text(text)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

struct SleepStageRow: View {
    let title: String
    let duration: Double // in hours
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Text(formatHours(duration))
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    SleepSummaryView(sleepData: SleepData(
        startDate: Date().addingTimeInterval(-28800),
        endDate: Date(),
        totalDuration: 8.0,
        inBedDuration: 8.5,
        deepSleepDuration: 2.0,
        remSleepDuration: 1.5,
        coreSleepDuration: 4.0,
        awakeDuration: 0.5
    ))
    .padding()
}
