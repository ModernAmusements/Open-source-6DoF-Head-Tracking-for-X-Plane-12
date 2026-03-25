import Foundation

struct HeadPosePacket {
    var packetId: UInt32 = 0
    var flags: UInt8 = 0
    var timestampUs: Double = 0
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var pitch: Float = 0
    var yaw: Float = 0
    var roll: Float = 0
    
    static let size = 24
    
    enum Flag: UInt8 {
        case calibrated = 0x01
        case trackingValid = 0x02
    }
    
    mutating func setFlag(_ flag: Flag, _ value: Bool) {
        if value {
            flags |= flag.rawValue
        } else {
            flags &= ~flag.rawValue
        }
    }
    
    func isFlagSet(_ flag: Flag) -> Bool {
        return (flags & flag.rawValue) != 0
    }
    
    func toData() -> Data {
        var packet = self
        return Data(bytes: &packet, count: HeadPosePacket.size)
    }
    
    static func fromData(_ data: Data) -> HeadPosePacket? {
        guard data.count >= size else { return nil }
        
        var packet = HeadPosePacket()
        _ = withUnsafeMutableBytes(of: &packet) { buffer in
            data.copyBytes(to: buffer)
        }
        return packet
    }
}
