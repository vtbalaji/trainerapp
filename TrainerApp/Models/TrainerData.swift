import Foundation

/// Real-time data received from the trainer via FTMS Indoor Bike Data characteristic
struct TrainerData {
    var instantaneousSpeed: Double = 0.0   // km/h
    var instantaneousCadence: Double = 0.0 // rpm
    var instantaneousPower: Int16 = 0      // watts
    var heartRate: UInt8 = 0               // bpm (if trainer has HR sensor)
    var totalDistance: UInt32 = 0           // meters
    var elapsedTime: UInt16 = 0            // seconds
    var resistanceLevel: Int16 = 0         // current resistance level

    /// Parse Indoor Bike Data characteristic value per FTMS spec (0x2AD2)
    /// The first 2 bytes are flags indicating which fields are present.
    static func parse(from data: Data) -> TrainerData {
        var result = TrainerData()
        guard data.count >= 2 else { return result }

        let flags: UInt16 = data.readLE(at: 0)
        var offset = 2

        // Bit 0: More Data (0 = speed present, 1 = speed NOT present — inverted!)
        if flags & 0x0001 == 0 {
            if offset + 2 <= data.count {
                let raw: UInt16 = data.readLE(at: offset)
                result.instantaneousSpeed = Double(raw) * 0.01 // resolution 0.01 km/h
                offset += 2
            }
        }

        // Bit 1: Average Speed present
        if flags & 0x0002 != 0 {
            offset += 2 // skip average speed
        }

        // Bit 2: Instantaneous Cadence present
        if flags & 0x0004 != 0 {
            if offset + 2 <= data.count {
                let raw: UInt16 = data.readLE(at: offset)
                result.instantaneousCadence = Double(raw) * 0.5 // resolution 0.5 rpm
                offset += 2
            }
        }

        // Bit 3: Average Cadence present
        if flags & 0x0008 != 0 {
            offset += 2
        }

        // Bit 4: Total Distance present
        if flags & 0x0010 != 0 {
            if offset + 3 <= data.count {
                let b0: UInt8 = data.readLE(at: offset)
                let b1: UInt8 = data.readLE(at: offset + 1)
                let b2: UInt8 = data.readLE(at: offset + 2)
                result.totalDistance = UInt32(b0) | (UInt32(b1) << 8) | (UInt32(b2) << 16)
                offset += 3
            }
        }

        // Bit 5: Resistance Level present
        if flags & 0x0020 != 0 {
            if offset + 2 <= data.count {
                result.resistanceLevel = data.readLE(at: offset)
                offset += 2
            }
        }

        // Bit 6: Instantaneous Power present
        if flags & 0x0040 != 0 {
            if offset + 2 <= data.count {
                result.instantaneousPower = data.readLE(at: offset)
                offset += 2
            }
        }

        // Bit 7: Average Power present
        if flags & 0x0080 != 0 {
            offset += 2
        }

        // Bit 8: Expended Energy present
        if flags & 0x0100 != 0 {
            offset += 5 // total energy (2) + energy per hour (2) + energy per minute (1)
        }

        // Bit 9: Heart Rate present
        if flags & 0x0200 != 0 {
            if offset + 1 <= data.count {
                result.heartRate = data.readLE(at: offset)
                offset += 1
            }
        }

        // Bit 12: Elapsed Time present
        if flags & 0x1000 != 0 {
            // Skip bits 10 (metabolic equivalent) and 11 (remaining time) first
            if flags & 0x0400 != 0 { offset += 1 }
            if flags & 0x0800 != 0 { offset += 2 }
            if offset + 2 <= data.count {
                result.elapsedTime = data.readLE(at: offset)
            }
        }

        return result
    }

    /// Parse Tacx FE-C over BLE data.
    /// FE-C packets are ANT+ data pages. The BLE wrapper sends raw ANT+ page bytes.
    /// Key pages: 0x19 (General FE Data), 0x31 (Specific Trainer Data)
    static func parseFEC(from data: Data, previous: TrainerData) -> TrainerData {
        var result = previous
        guard data.count >= 1 else { return result }

        // FE-C over BLE: first byte after sync may be the data page number
        // The format can vary; typically the ANT+ payload starts at byte 0 or after a header
        // Common format: [sync] [channel] [pageNumber] [data...]
        // Tacx BLE wraps it as: [pageNumber] [data bytes...]

        // Try to find the page number
        let pageNumber: UInt8
        if data.count >= 13 {
            // Full ANT+ message with header: byte 4 is the data page
            pageNumber = data[4]
        } else if data.count >= 8 {
            // Raw page data: byte 0 is the page number
            pageNumber = data[0]
        } else {
            return result
        }

        let offset = data.count >= 13 ? 4 : 0 // offset to page start

        switch pageNumber {
        case 0x10: // General FE Data (page 16)
            if offset + 7 < data.count {
                // Byte 4 (from page start): speed LSB, Byte 5: speed MSB
                let speedRaw: UInt16 = data.readLE(at: offset + 4)
                result.instantaneousSpeed = Double(speedRaw) * 0.001 * 3.6 // mm/s → km/h
            }

        case 0x19: // General FE Data (page 25) — Specific Trainer/Stationary Bike
            if offset + 7 < data.count {
                // Byte 5-6: instantaneous power (little-endian, 12 bits)
                let powerLSB: UInt8 = data[offset + 5]
                let powerMSB: UInt8 = data[offset + 6]
                let power = Int16(powerLSB) | (Int16(powerMSB & 0x0F) << 8)
                result.instantaneousPower = power
                // Byte 4: instantaneous cadence
                result.instantaneousCadence = Double(data[offset + 4])
            }

        case 0x31: // Specific Trainer Data (page 49) — Tacx extended
            if offset + 7 < data.count {
                let powerLSB: UInt8 = data[offset + 5]
                let powerMSB: UInt8 = data[offset + 6]
                let power = Int16(powerLSB) | (Int16(powerMSB & 0x0F) << 8)
                result.instantaneousPower = power
                result.instantaneousCadence = Double(data[offset + 4])
            }

        default:
            break
        }

        return result
    }
}

// MARK: - Data Helpers

extension Data {
    /// Read a little-endian value at the given byte offset
    func readLE<T: FixedWidthInteger>(at offset: Int) -> T {
        let size = MemoryLayout<T>.size
        guard offset + size <= count else { return 0 }
        var value: T = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { dest in
            copyBytes(to: dest, from: offset..<(offset + size))
        }
        return T(littleEndian: value)
    }
}
