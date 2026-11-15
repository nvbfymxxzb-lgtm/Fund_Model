import Foundation
import Darwin

/// One clock for everything: MIDI input, playback and grading all use the device's host time.
enum Clock {
    static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Microseconds for a host-time stamp (the unit Core MIDI uses).
    static func microseconds(hostTime: UInt64) -> Int64 {
        Int64(hostTime / UInt64(timebase.denom) * UInt64(timebase.numer) / 1000)
            + Int64(hostTime % UInt64(timebase.denom) * UInt64(timebase.numer) / UInt64(timebase.denom) / 1000)
    }

    static var nowUs: Int64 { microseconds(hostTime: mach_absolute_time()) }

    static func hostTime(microseconds us: Int64) -> UInt64 {
        UInt64(max(us, 0)) * 1000 * UInt64(timebase.denom) / UInt64(timebase.numer)
    }
}
