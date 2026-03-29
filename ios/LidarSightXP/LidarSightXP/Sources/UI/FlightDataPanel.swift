import SwiftUI

struct FlightDataPanel: View {
    @EnvironmentObject var flightDataManager: FlightDataManager
    
    private func formatValue(_ value: Double) -> String {
        if value == 0 && !flightDataManager.isConnected {
            return "--"
        }
        return String(format: "%.0f", value)
    }
    
    private func formatValueSigned(_ value: Double) -> String {
        if value == 0 && !flightDataManager.isConnected {
            return "--"
        }
        return String(format: "%+.0f", value)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                FlightDataItem(title: "IAS", value: formatValue(flightDataManager.airspeed), unit: "kts")
                FlightDataItem(title: "ALT", value: formatValue(flightDataManager.altitude), unit: "ft")
            }
            
            HStack {
                FlightDataItem(title: "HDG", value: formatValue(flightDataManager.heading), unit: "°")
                FlightDataItem(title: "VS", value: formatValueSigned(flightDataManager.verticalSpeed), unit: "fpm")
            }
            
            HStack {
                FlightDataItem(title: "PCH", value: formatValue(flightDataManager.pitch), unit: "°")
                FlightDataItem(title: "ROL", value: formatValue(flightDataManager.roll), unit: "°")
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

struct FlightDataItem: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(value == "--" ? .gray : .white)
                
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 80)
    }
}
