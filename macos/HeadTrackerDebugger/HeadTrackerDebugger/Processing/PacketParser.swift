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
}

struct OpenTrackPacket {
    var x: Double = 0
    var y: Double = 0
    var z: Double = 0
    var pitch: Double = 0
    var yaw: Double = 0
    var roll: Double = 0
    
    static let size = 48
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
        guard data.count >= LidarSightPacket.size else { return nil }
        
        var packet = LidarSightPacket()
        _ = withUnsafeMutableBytes(of: &packet) { buffer in
            data.copyBytes(to: buffer)
        }
        
        let pose = HeadPose(
            pitch: packet.pitch,
            yaw: packet.yaw,
            roll: packet.roll,
            isValid: packet.isTrackingValid
        )
        
        return ParsedPacket(pose: pose, proto: .lidarSight)
    }
    
    private static func parseOpenTrack(_ data: Data) -> ParsedPacket? {
        guard data.count >= OpenTrackPacket.size else { return nil }
        
        var packet = OpenTrackPacket()
        _ = withUnsafeMutableBytes(of: &packet) { buffer in
            data.copyBytes(to: buffer)
        }
        
        let pose = HeadPose(
            pitch: Float(packet.pitch * 180.0 / .pi),
            yaw: Float(packet.yaw * 180.0 / .pi),
            roll: Float(packet.roll * 180.0 / .pi),
            isValid: true
        )
        
        return ParsedPacket(pose: pose, proto: .openTrack)
    }
}
