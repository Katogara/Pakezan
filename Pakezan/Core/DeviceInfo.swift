import Darwin
import Foundation

/// iOS の通信カウンタ (getifaddrs) を読む
enum InterfaceCounters {
    static func read() -> RawCounters {
        var values: [String: UInt32] = [:]
        var list: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&list) == 0 {
            var cursor = list
            while let entry = cursor?.pointee {
                cursor = entry.ifa_next
                // 送受信のバイト数は AF_LINK の項目の ifa_data に入っている
                guard let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                      let data = entry.ifa_data else { continue }
                let name = String(cString: entry.ifa_name)
                guard CounterMath.network(ofInterface: name) != nil else { continue }
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                values["\(name).in"] = stats.ifi_ibytes
                values["\(name).out"] = stats.ifi_obytes
            }
            freeifaddrs(list)
        }
        return RawCounters(values: values, bootTime: bootTime())
    }

    static func bootTime() -> Date {
        var time = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &time, &size, nil, 0) == 0 else { return .distantPast }
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000)
    }
}

/// アプリの署名の期限 (Sideloadly で入れたアプリに入っている embedded.mobileprovision から読む)
enum SigningInfo {
    static let expiry: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return parseExpiry(data)
    }()

    /// 署名データの中の plist 部分から ExpirationDate を取り出す
    static func parseExpiry(_ data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }
}
