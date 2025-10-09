import SwiftUI

struct StressGaugeView: View {
    let stressLevel: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 20)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            Circle()
                .trim(from: 0.0, to: min(stressLevel / 3.0, 1.0))
                .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .foregroundColor(getGaugeColor())
                .rotationEffect(Angle(degrees: -90))
            
            Text(String(format: "%.1f", stressLevel))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(getGaugeColor())
        }
        .frame(width: 150, height: 150)
    }
    
    private func getGaugeColor() -> Color {
        switch stressLevel {
        case 0.0..<1.0:
            return Color.green
        case 1.0..<2.0:
            return Color.yellow
        case 2.0...3.0:
            return Color.red
        default:
            return Color.gray
        }
    }
}

#Preview {
    StressGaugeView(stressLevel: 1.5)
}
