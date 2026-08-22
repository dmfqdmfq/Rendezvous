import Foundation
import Network

final class NetworkMonitor: @unchecked Sendable {

    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wiredEthernet
        case other
        case unavailable
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let lock = NSLock()

    private var currentConnectionType: ConnectionType = .unavailable

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else {
                return
            }

            let type = Self.connectionType(for: path)
            self.setConnectionType(type)
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // 現在の接続方式をスレッドセーフに取得する
    var connectionType: ConnectionType {
        lock.lock()
        defer { lock.unlock() }

        return currentConnectionType
    }

    // 接続方式をスレッドセーフに更新する
    private func setConnectionType(_ type: ConnectionType) {
        lock.lock()
        currentConnectionType = type
        lock.unlock()
    }

    // NWPathから現在の接続方式を判定する
    private static func connectionType(for path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .unavailable
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        }

        if path.usesInterfaceType(.cellular) {
            return .cellular
        }

        if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }

        return .other
    }
}
