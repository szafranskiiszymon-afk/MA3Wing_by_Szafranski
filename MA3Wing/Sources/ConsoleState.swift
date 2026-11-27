import Foundation
import UIKit
import SwiftUI

@MainActor
final class ConsoleState: ObservableObject {

    // MARK: Settings (persisted)
    @AppStorage("host") var host: String = "192.168.1.100"
    @AppStorage("sendPort") var sendPort: Int = 8000
    @AppStorage("receivePort") var receivePort: Int = 9000
    @AppStorage("prefix") var prefix: String = "gma3"
    @AppStorage("faderCount") var faderCount: Int = 10
    @AppStorage("useFloat") var useFloat: Bool = false
    @AppStorage("grandMasterCmd") var grandMasterCmd: String = "Master 2.1 At $"
    @AppStorage("blackoutCmd") var blackoutCmd: String = "Black Master 2.1"
    @AppStorage("haptics") var haptics: Bool = true
    @AppStorage("sendPageCmd") var sendPageCmd: Bool = true
    @AppStorage("firstColumn") var firstColumn: Int = 1          // 1 -> executors x01
    @AppStorage("upperRows") var upperRows: String = "401,301"   // button rows above faders
    @AppStorage("lowerRows") var lowerRows: String = "101"       // button rows below faders
    @AppStorage("faderRow") var faderRow: Int = 201
    @AppStorage("masterCmd") var masterCmd: String = "Master 1.1 At $"
    /// OSC addresses for encoders / level wheel – unknown in MA3 docs, empty = don't send.
    /// Use {n} for the encoder number, e.g. "/Encoder{n}". The value sent is a relative step (i).
    @AppStorage("encoderAddr") var encoderAddr: String = ""
    @AppStorage("levelWheelAddr") var levelWheelAddr: String = ""

    var upperRowBases: [Int] { Self.parseRows(upperRows) }
    var lowerRowBases: [Int] { Self.parseRows(lowerRows) }
    var columns: [Int] { Array(0..<max(1, min(faderCount, 30))).map { firstColumn - 1 + $0 } }

    private static func parseRows(_ s: String) -> [Int] {
        s.split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Int($0) }
            .map { ($0 / 100) * 100 }   // 401 -> 400
    }

    // MARK: Live state
    @Published var page: Int = 1
    @Published var faders: [Int: Double] = [:]      // exec number -> 0...100
    @Published var grandMaster: Double = 100
    @Published var master: Double = 100
    @Published var commandLine: String = ""
    @Published var connState: OSCClient.State = .idle
    @Published var lastSent: String = ""

    /// Faders that the user is currently touching – feedback is ignored for them.
    var touching: Set<Int> = []

    private let client = OSCClient()
    private var lastSentValue: [String: Int] = [:]

    init() {
        client.onState = { [weak self] st in
            Task { @MainActor in self?.connState = st }
        }
        client.onMessage = { [weak self] msg in
            Task { @MainActor in self?.handleFeedback(msg) }
        }
    }

    func connect() {
        client.connect(host: host.trimmingCharacters(in: .whitespaces), port: UInt16(clamping: sendPort))
        client.listen(port: UInt16(clamping: receivePort))
    }

    // MARK: Address helpers

    private var base: String {
        let p = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return p.isEmpty ? "" : "/\(p)"
    }

    private func send(_ address: String, _ args: [OSCArg]) {
        client.send(OSCMessage(address: address, args: args))
        lastSent = address + " " + args.map { a -> String in
            switch a {
            case .int(let v): return "\(v)"
            case .float(let v): return String(format: "%.1f", v)
            case .string(let s): return "\"\(s)\""
            case .bool(let b): return b ? "T" : "F"
            }
        }.joined(separator: " ")
    }

    // MARK: Executors

    func setFader(_ exec: Int, _ value: Double) {
        let v = min(max(value, 0), 100)
        faders[exec] = v
        let addr = "\(base)/Page\(page)/Fader\(exec)"
        let rounded = Int(v.rounded())
        if !useFloat, lastSentValue[addr] == rounded { return }   // throttle duplicates
        lastSentValue[addr] = rounded
        send(addr, [useFloat ? .float(Float(v)) : .int(Int32(rounded))])
    }

    func key(_ exec: Int, pressed: Bool) {
        if pressed { tick() }
        send("\(base)/Page\(page)/Key\(exec)", [.int(pressed ? 1 : 0)])
    }

    func faderValue(_ exec: Int) -> Double { faders[exec] ?? 0 }

    // MARK: Pages

    func changePage(by delta: Int) { setPage(page + delta) }

    func setPage(_ p: Int) {
        let new = max(1, min(p, 9999))
        guard new != page else { return }
        page = new
        faders.removeAll()
        lastSentValue.removeAll()
        tick()
        if sendPageCmd { command("Page \(new)") }
    }

    // MARK: Command line

    func command(_ cmd: String) {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        send("\(base)/cmd", [.string(c)])
    }

    func setGrandMaster(_ v: Double) {
        grandMaster = min(max(v, 0), 100)
        let cmd = grandMasterCmd.replacingOccurrences(of: "$", with: "\(Int(grandMaster.rounded()))")
        let key = "GM"
        let r = Int(grandMaster.rounded())
        if lastSentValue[key] == r { return }
        lastSentValue[key] = r
        command(cmd)
    }

    func setMaster(_ v: Double) {
        master = min(max(v, 0), 100)
        let r = Int(master.rounded())
        if lastSentValue["M"] == r { return }
        lastSentValue["M"] = r
        command(masterCmd.replacingOccurrences(of: "$", with: "\(r)"))
    }

    func encoder(_ n: Int, step: Int) {
        guard step != 0 else { return }
        let a = encoderAddr.trimmingCharacters(in: .whitespaces)
        if a.isEmpty { lastSent = "Enkoder \(n) \(step > 0 ? "+" : "")\(step) (brak adresu OSC w ustawieniach)"; return }
        send(base + a.replacingOccurrences(of: "{n}", with: "\(n)"), [.int(Int32(step))])
    }

    func levelWheel(step: Int) {
        guard step != 0 else { return }
        let a = levelWheelAddr.trimmingCharacters(in: .whitespaces)
        if a.isEmpty { lastSent = "Level wheel \(step > 0 ? "+" : "")\(step) (brak adresu OSC w ustawieniach)"; return }
        send(base + a, [.int(Int32(step))])
    }

    /// Keypad input – builds the command line locally, sent on Please.
    func keypad(_ k: KeypadKey) {
        tick()
        switch k.kind {
        case .digit(let d):
            if let last = commandLine.last, last.isNumber || last == "." {
                commandLine.append(d)
            } else {
                appendToken(String(d))
            }
        case .dot:
            commandLine.append(".")
        case .keyword(let w):
            appendToken(w)
        case .please:
            if commandLine.isEmpty { command("Please") } else { command(commandLine) }
            commandLine = ""
        case .clear:
            if commandLine.isEmpty { command("Clear") } else { commandLine = "" }
        case .oops:
            if commandLine.isEmpty { command("Oops") } else { removeLastToken() }
        case .backspace:
            if !commandLine.isEmpty { commandLine.removeLast() }
            commandLine = commandLine.trimmingCharacters(in: .whitespaces)
        case .direct(let c):
            command(c)
        }
    }

    private func appendToken(_ t: String) {
        if commandLine.isEmpty { commandLine = t } else { commandLine += " " + t }
    }

    private func removeLastToken() {
        var parts = commandLine.split(separator: " ")
        if !parts.isEmpty { parts.removeLast() }
        commandLine = parts.joined(separator: " ")
    }

    // MARK: Feedback

    private func handleFeedback(_ msg: OSCMessage) {
        // Accept e.g. /gma3/Page1/Fader201 or /Page1/Fader201 with i/f value
        let comps = msg.address.split(separator: "/")
        guard let last = comps.last, last.hasPrefix("Fader"),
              let exec = Int(last.dropFirst(5)),
              let value = msg.args.first?.doubleValue else { return }
        if let pageComp = comps.first(where: { $0.hasPrefix("Page") }),
           let p = Int(pageComp.dropFirst(4)), p != page { return }
        guard !touching.contains(exec) else { return }
        faders[exec] = min(max(value, 0), 100)
    }

    // MARK: Haptics

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    func tick() { if haptics { haptic.impactOccurred() } }
}
