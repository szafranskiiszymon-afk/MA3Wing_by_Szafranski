import Foundation
import Network

// MARK: - OSC message (OSC 1.0/1.1, no bundles – grandMA3 doesn't accept them)

enum OSCArg {
    case int(Int32)
    case float(Float)
    case string(String)
    case bool(Bool)

    var doubleValue: Double? {
        switch self {
        case .int(let v): return Double(v)
        case .float(let v): return Double(v)
        case .bool(let b): return b ? 1 : 0
        case .string(let s): return Double(s)
        }
    }
}

struct OSCMessage {
    var address: String
    var args: [OSCArg]

    func encoded() -> Data {
        var data = Data()
        data.append(Self.paddedString(address))
        var tags = ","
        for a in args {
            switch a {
            case .int: tags += "i"
            case .float: tags += "f"
            case .string: tags += "s"
            case .bool(let b): tags += b ? "T" : "F"
            }
        }
        data.append(Self.paddedString(tags))
        for a in args {
            switch a {
            case .int(let v):
                var be = v.bigEndian
                data.append(Data(bytes: &be, count: 4))
            case .float(let v):
                var be = v.bitPattern.bigEndian
                data.append(Data(bytes: &be, count: 4))
            case .string(let s):
                data.append(Self.paddedString(s))
            case .bool:
                break
            }
        }
        return data
    }

    static func paddedString(_ s: String) -> Data {
        var d = Data(s.utf8)
        d.append(0)
        while d.count % 4 != 0 { d.append(0) }
        return d
    }

    static func decode(_ data: Data) -> OSCMessage? {
        let bytes = [UInt8](data)
        var i = 0
        func readString() -> String? {
            guard i < bytes.count, let end = bytes[i...].firstIndex(of: 0) else { return nil }
            let s = String(decoding: bytes[i..<end], as: UTF8.self)
            i = (end + 4) & ~3
            return s
        }
        func readUInt32() -> UInt32? {
            guard i + 4 <= bytes.count else { return nil }
            let v = bytes[i..<i+4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            i += 4
            return v
        }
        guard let address = readString(), address.hasPrefix("/") else { return nil }
        guard let tags = readString(), tags.hasPrefix(",") else {
            return OSCMessage(address: address, args: [])
        }
        var args: [OSCArg] = []
        for t in tags.dropFirst() {
            switch t {
            case "i": guard let v = readUInt32() else { return nil }; args.append(.int(Int32(bitPattern: v)))
            case "f": guard let v = readUInt32() else { return nil }; args.append(.float(Float(bitPattern: v)))
            case "s": guard let s = readString() else { return nil }; args.append(.string(s))
            case "T": args.append(.bool(true))
            case "F": args.append(.bool(false))
            default: return OSCMessage(address: address, args: args)
            }
        }
        return OSCMessage(address: address, args: args)
    }
}

// MARK: - UDP transport

final class OSCClient {
    enum State: Equatable { case idle, connecting, ready, failed(String) }

    private var connection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "osc.udp")

    var onState: ((State) -> Void)?
    var onMessage: ((OSCMessage) -> Void)?

    func connect(host: String, port: UInt16) {
        connection?.cancel()
        connection = nil
        guard !host.isEmpty, let p = NWEndpoint.Port(rawValue: port) else {
            onState?(.idle); return
        }
        let c = NWConnection(host: NWEndpoint.Host(host), port: p, using: .udp)
        c.stateUpdateHandler = { [weak self] st in
            switch st {
            case .ready: self?.onState?(.ready)
            case .failed(let e): self?.onState?(.failed(e.localizedDescription))
            case .waiting(let e): self?.onState?(.failed(e.localizedDescription))
            case .preparing, .setup: self?.onState?(.connecting)
            default: break
            }
        }
        onState?(.connecting)
        c.start(queue: queue)
        connection = c
    }

    func send(_ msg: OSCMessage) {
        connection?.send(content: msg.encoded(), completion: .contentProcessed { _ in })
    }

    /// Listen for feedback from the console (Send enabled in MA3 OSC settings).
    func listen(port: UInt16) {
        listener?.cancel()
        listener = nil
        guard port > 0, let p = NWEndpoint.Port(rawValue: port),
              let l = try? NWListener(using: .udp, on: p) else { return }
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.queue ?? .main)
            self?.receive(on: conn)
        }
        l.start(queue: queue)
        listener = l
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data, let msg = OSCMessage.decode(data) {
                self?.onMessage?(msg)
            }
            if error == nil { self?.receive(on: conn) }
        }
    }

    func stop() {
        connection?.cancel(); connection = nil
        listener?.cancel(); listener = nil
    }
}
