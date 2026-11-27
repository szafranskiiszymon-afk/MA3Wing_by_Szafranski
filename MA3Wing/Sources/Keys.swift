import SwiftUI

struct KeypadKey: Identifiable {
    enum Kind {
        case digit(Character)
        case dot
        case keyword(String)   // appended to the local command line
        case direct(String)    // sent to the console immediately
        case please, clear, oops, backspace
    }
    let id = UUID()
    let label: String
    let kind: Kind
    var color: Color = .keyGray
    var textColor: Color = .white
    var span: Int = 1

    static func kw(_ w: String, _ c: Color = .keyGray) -> KeypadKey { .init(label: w, kind: .keyword(w), color: c) }
    static func dir(_ label: String, _ cmd: String, _ c: Color = .keyGray) -> KeypadKey { .init(label: label, kind: .direct(cmd), color: c) }
    static func num(_ d: Character) -> KeypadKey { .init(label: String(d), kind: .digit(d), color: .keyNum) }
    static func amber(_ label: String, _ kind: Kind) -> KeypadKey { .init(label: label, kind: kind, color: .keyAmber, textColor: .amberText) }
}

/// Xkeys: X1–X8 = executors 291–298 (upper row), X9–X16 = 191–198 (lower row).
struct XKey: Identifiable {
    let id: Int        // executor number
    let label: String
    let sub: String

    static let all: [XKey] = {
        let subs = ["", "", "Grid", "Layout", "Step", "TC", "View", "DMX",
                    "", "", "", "", "Phaser", "Macro", "Page", "Exec"]
        return (0..<16).map { i in
            let exec = i < 8 ? 291 + i : 191 + (i - 8)
            return XKey(id: exec, label: "X\(i + 1)", sub: subs[i].isEmpty ? "\(exec)" : subs[i])
        }
    }()
}

extension Color {
    static let consoleBG   = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let panelBG     = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let keyGray     = Color(red: 0.24, green: 0.24, blue: 0.26)
    static let keyNum      = Color(red: 0.35, green: 0.35, blue: 0.38)
    static let keyAmber    = Color(red: 0.88, green: 0.59, blue: 0.12)
    static let amberText   = Color(red: 0.17, green: 0.10, blue: 0.00)
    static let keyRed      = Color(red: 0.69, green: 0.18, blue: 0.16)
    static let keyGreen    = Color(red: 0.12, green: 0.48, blue: 0.24)
    static let keyBlue     = Color(red: 0.18, green: 0.40, blue: 0.75)
    static let keyX        = Color(red: 0.18, green: 0.23, blue: 0.29)
    static let maYellow    = Color(red: 1.00, green: 0.78, blue: 0.10)
}

/// Layout of the MA3 command section (programming keys + numeric keypad).
enum KeyLayout {
    /// Function keys – 6 columns.
    static let functions: [[KeypadKey]] = [
        [.kw("Store", .keyRed), .kw("Update", .keyRed), .kw("Assign"), .kw("Edit"), .kw("Delete", .keyRed), .kw("Copy")],
        [.kw("Move"), .kw("Label"), .kw("On"), .kw("Off"), .kw("Time"), .kw("Goto")],
        [.kw("Fixture", .keyBlue), .kw("Channel", .keyBlue), .kw("Group", .keyBlue), .kw("Preset", .keyBlue), .kw("Sequence", .keyBlue), .kw("Cue", .keyBlue)],
        [.dir("Highlt", "Highlight"), .dir("Solo", "Solo"), .dir("Blind", "Blind"), .dir("Freeze", "Freeze"), .dir("Preview", "Preview"), .kw("Exec", .keyBlue)],
        [.amber("Oops", .oops), .amber("Clear", .clear), .kw("Fade"), .kw("Delay"), .dir("Prev", "Previous"), .dir("Next", "Next")],
    ]

    /// Numeric keypad – 4 columns.
    static let keypad: [[KeypadKey]] = [
        [.kw("If"), .init(label: "At", kind: .keyword("At"), color: .keyAmber, textColor: .amberText), .kw("Thru"), .init(label: "⌫", kind: .backspace)],
        [.num("7"), .num("8"), .num("9"), .kw("+")],
        [.num("4"), .num("5"), .num("6"), .kw("-")],
        [.num("1"), .num("2"), .num("3"), .kw("/")],
        [.num("0"), .init(label: ".", kind: .dot, color: .keyNum), .kw("Zero"), .kw("Full")],
        [.init(label: "Please", kind: .please, color: .keyGreen, span: 4)],
    ]
}
