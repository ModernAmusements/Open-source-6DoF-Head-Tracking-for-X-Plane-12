import Foundation

struct LidarSightPacket {
    var packetId: UInt32 = 0
    var flags: UInt8 = 0
    var timestampUs: Float = 0
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var pitch: Float = 0
    var yaw: Float = 0
    var roll: Float = 0
    
    static let size = 33
    
    var isTrackingValid: Bool {
        (flags & 0x02) != 0
    }
    
    static func parse(from data: Data) -> LidarSightPacket? {
        guard data.count >= size else { return nil }
        
        var packet = LidarSightPacket()
        packet.packetId = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        packet.flags = data.subdata(in: 4..<5).withUnsafeBytes { $0.load(as: UInt8.self) }
        packet.timestampUs = data.subdata(in: 5..<9).withUnsafeBytes { $0.load(as: Float.self) }
        packet.x = data.subdata(in: 9..<13).withUnsafeBytes { $0.load(as: Float.self) }
        packet.y = data.subdata(in: 13..<17).withUnsafeBytes { $0.load(as: Float.self) }
        packet.z = data.subdata(in: 17..<21).withUnsafeBytes { $0.load(as: Float.self) }
        packet.pitch = data.subdata(in: 21..<25).withUnsafeBytes { $0.load(as: Float.self) }
        packet.yaw = data.subdata(in: 25..<29).withUnsafeBytes { $0.load(as: Float.self) }
        packet.roll = data.subdata(in: 29..<33).withUnsafeBytes { $0.load(as: Float.self) }
        return packet
    }
}

struct OpenTrackPacket {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    var pitch: Double = 0
    var yaw: Double = 0
    var roll: Double = 0
    
    static let size = 48
    
    static func parse(from data: Data) -> OpenTrackPacket? {
        guard data.count >= size else { return nil }
        
        var packet = OpenTrackPacket()
        packet.x = data.subdata(in: 0..<8).withUnsafeBytes { $0.load(as: Double.self) }
        packet.y = data.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: Double.self) }
        packet.z = data.subdata(in: 16..<24).withUnsafeBytes { $0.load(as: Double.self) }
        packet.pitch = data.subdata(in: 24..<32).withUnsafeBytes { $0.load(as: Double.self) }
        packet.yaw = data.subdata(in: 32..<40).withUnsafeBytes { $0.load(as: Double.self) }
        packet.roll = data.subdata(in: 40..<48).withUnsafeBytes { $0.load(as: Double.self) }
        return packet
    }
}

class PacketParser {
    static func parse(_ data: Data) -> ParsedPacket? {
        if data.count >= LidarSightPacket.size {
            return parseLidarSight(data)
        } else if data.count >= OpenTrackPacket.size {
            return parseOpenTrack(data)
        }
        return nil
    }
    
    private static func parseLidarSight(_ data: Data) -> ParsedPacket? {
        guard let packet = LidarSightPacket.parse(from: data) else { return nil }
        
        let pose = HeadPose(
            pitch: packet.pitch,
            yaw: packet.yaw,
            roll: packet.roll,
            isValid: packet.isTrackingValid
        )
        
        return ParsedPacket(pose: pose, proto: .lidarSight)
    }
    
    private static func parseOpenTrack(_ data: Data) -> ParsedPacket? {
        guard let packet = OpenTrackPacket.parse(from: data) else { return nil }
        
        let pose = HeadPose(
            pitch: Float(packet.pitch * 180.0 / .pi),
            yaw: Float(packet.yaw * 180.0 / .pi),
            roll: Float(packet.roll * 180.0 / .pi),
            isValid: true
        )
        
        return ParsedPacket(pose: pose, proto: .openTrack)
    }
}
