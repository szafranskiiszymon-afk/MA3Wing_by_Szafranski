import SwiftUI

/// iPad "Całość" layout modelled on the grandMA3 onPC command wing XT:
/// executors | Prev/Next + 2 master faders + Pause/Go-/Go+ | 5 encoders + command section + level wheel.
/// Built at a fixed design size and scaled to the screen, so proportions stay like the hardware.
struct WingView: View {
    @EnvironmentObject var state: ConsoleState
    private let designSize = CGSize(width: 1164, height: 744)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / designSize.width, geo.size.height / designSize.height)
            HStack(alignment: .top, spacing: 18) {
                WingExecutors().frame(width: 430)
                WingMaster().frame(width: 104)
                WingCommand()
            }
            .padding(16)
            .frame(width: designSize.width, height: designSize.height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.10)))
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: designSize.width * s, height: designSize.height * s, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Building blocks

private let U: CGFloat = 38      // key size
private let GP: CGFloat = 4      // gap

private struct WKey: View {
    @EnvironmentObject var state: ConsoleState
    let label: String
    var sub: String? = nil
    var color: Color = .keyGray
    var text: Color = .white
    var w: CGFloat = U
    var h: CGFloat = U
    var down: () -> Void
    var up: () -> Void = {}
    var body: some View {
        ConsoleKey(label: label, sublabel: sub, color: color, textColor: text, height: h, onPress: down, onRelease: up)
            .frame(width: w)
    }
}

private extension View {
    func cmd(_ state: ConsoleState, _ c: String) -> () -> Void { { state.tick(); state.command(c) } }
}

private struct LED: View {
    var body: some View {
        Circle().stroke(Color(white: 0.23), lineWidth: 2)
            .background(Circle().fill(Color(white: 0.07)))
            .frame(width: 10, height: 10)
    }
}

// MARK: - Executors (rows 8/7: knob+key 4xx/3xx, 6: faders 2xx, 5: keys 2xx/1xx)

private struct WingExecutors: View {
    @EnvironmentObject var state: ConsoleState
    var body: some View {
        HStack(spacing: 16) {
            ForEach([Array(0..<5), Array(5..<10)], id: \.self) { block in
                HStack(spacing: 4) {
                    ForEach(block, id: \.self) { col in column(col) }
                }
            }
        }
    }

    @ViewBuilder private func column(_ col: Int) -> some View {
        let n = col + 1
        VStack(spacing: 5) {
            knob(400 + n); exKey(400 + n, "≡", 40)
            Spacer().frame(height: 8)
            knob(300 + n); exKey(300 + n, "≡", 40)
            Spacer().frame(height: 18)
            FaderView(value: state.faderValue(200 + n),
                      onTouch: { t in if t { state.touching.insert(200 + n) } else { state.touching.remove(200 + n) } },
                      onChange: { state.setFader(200 + n, $0) })
            Text("\(Int(state.faderValue(200 + n).rounded()))")
                .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.maYellow)
            Spacer().frame(height: 18)
            exKey(200 + n, "=", 42)
            exKey(100 + n, "–", 42)
        }
    }

    private func knob(_ exec: Int) -> some View {
        KnobView(value: state.faderValue(exec),
                 onTouch: { t in if t { state.touching.insert(exec) } else { state.touching.remove(exec) } },
                 onChange: { state.setFader(exec, $0) })
            .scaleEffect(0.6).frame(width: 28, height: 28)
    }

    private func exKey(_ exec: Int, _ marks: String, _ h: CGFloat) -> some View {
        ConsoleKey(label: "\(exec)", sublabel: marks, height: h,
                   onPress: { state.key(exec, pressed: true) },
                   onRelease: { state.key(exec, pressed: false) })
    }
}

// MARK: - Master area (1)

private struct WingMaster: View {
    @EnvironmentObject var state: ConsoleState
    var body: some View {
        VStack(spacing: 6) {
            Grid(horizontalSpacing: GP, verticalSpacing: GP) {
                GridRow { k("Prev", "Previous"); k("Next", "Next") }
                GridRow { k("Set", "Set"); k("Up", "Up") }
                GridRow { k("SelFix", "SelFix"); k("Down", "Down") }
            }
            Spacer().frame(height: 18)
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    FaderView(value: state.master, onChange: { state.setMaster($0) })
                    Text("Master \(Int(state.master.rounded()))").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    FaderView(value: state.grandMaster, onChange: { state.setGrandMaster($0) })
                    Text("GM \(Int(state.grandMaster.rounded()))").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer().frame(height: 16)
            VStack(spacing: 4) {
                ConsoleKey(label: "Pause", color: .keyAmber, textColor: .amberText, height: 40, onPress: { state.command("Pause") })
                ConsoleKey(label: "Go-", height: 40, onPress: { state.command("Go-") })
                ConsoleKey(label: "Go+", color: .keyGreen, height: 40, onPress: { state.command("Go+") })
            }
            .padding(.horizontal, 18)
        }
    }

    private func k(_ label: String, _ c: String) -> some View {
        ConsoleKey(label: label, height: 36, onPress: { state.command(c) })
    }
}

// MARK: - Command area (2: encoders, 3: command section, 4: level wheel)

private struct WingCommand: View {
    @EnvironmentObject var state: ConsoleState

    private let xSubs = ["Clone", "Edit", "Grid", "Layout", "Step", "TC", "View", "DMX",
                         "", "", "", "", "Phaser", "Macro", "Page", "Exec"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 2 – dual encoders with their keys
            HStack {
                ForEach(1...5, id: \.self) { n in
                    EncoderView(number: n)
                    if n < 5 { Spacer(minLength: 0) }
                }
            }
            .frame(height: 104)

            upperBlock
            lowerBlock.padding(.top, 6)
        }
    }

    // On/Off… Highlt… Xkeys… Menu
    private var upperBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: GP) {
                dir("Highlt", "Highlight"); dir("Solo", "Solo"); dir("Freeze", "Freeze"); dir("Prvw", "Preview"); dir("Blind", "Blind")
            }
            Grid(horizontalSpacing: GP, verticalSpacing: GP) {
                GridRow { kw("On"); kw("Off") }
                GridRow { kw("Move"); kw("Copy") }
                GridRow { kw("Delete"); kw("Align") }
                GridRow { dir("Stomp", "Stomp"); dir("Help", "Help") }
                GridRow { dir("Select", "Select"); kw("Goto") }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: GP) { ForEach(0..<4, id: \.self) { _ in LED().frame(width: U) } }
                    }
                }
                xRow(0); xRow(8)
                Spacer().frame(height: 6)
                HStack(spacing: 10) {
                    HStack(spacing: GP) {
                        WKey(label: "Pause", sub: "Fix", color: .keyAmber, text: .amberText, w: U, down: cmd(state, "Pause"))
                        WKey(label: "Go-", sub: "Top", w: U, down: cmd(state, "Go-"))
                        WKey(label: "Go+", sub: "Temp", color: .keyGreen, w: U, down: cmd(state, "Go+"))
                    }
                    WKey(label: "MA", color: .black, w: U, down: { state.tick() })
                    HStack(spacing: GP) {
                        WKey(label: "Learn", sub: "Rate1", w: U, down: cmd(state, "Learn"))
                        WKey(label: "<<<", sub: "Black", w: U, down: cmd(state, "<<<"))
                        WKey(label: ">>>", sub: "Flash", w: U, down: cmd(state, ">>>"))
                    }
                }
            }
            VStack(spacing: GP) {
                WKey(label: "Xkeys", down: { state.tick() })
                WKey(label: "List", down: cmd(state, "List"))
            }
            .padding(.top, 16)
            VStack(spacing: 6) {
                LED()
                WKey(label: "Menu", down: cmd(state, "Menu"))
            }
        }
    }

    private func xRow(_ from: Int) -> some View {
        HStack(spacing: 10) {
            ForEach([from, from + 4], id: \.self) { start in
                HStack(spacing: GP) {
                    ForEach(start..<start + 4, id: \.self) { i in
                        let exec = i < 8 ? 291 + i : 191 + (i - 8)
                        WKey(label: "X\(i + 1)", sub: xSubs[i].isEmpty ? "\(exec)" : xSubs[i], w: U,
                             down: { state.key(exec, pressed: true) },
                             up: { state.key(exec, pressed: false) })
                    }
                }
            }
        }
    }

    // V+/V-, Page±, Fixture…Store, numeric pad, Oops/Esc/Clear, Full, level wheel
    private var lowerBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: GP) {
                kw("V+", w: U); kw("V-", w: U)
                Spacer().frame(height: U + 2 * GP)
                dir("Page+", "Page +", w: U); dir("Page-", "Page -", w: U)
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { kw("Fixture", .keyBlue, w: 48); kw("Channel", .keyBlue, w: 48); kw("Group", .keyBlue, w: 48) }
                GridRow { kw("Preset", .keyBlue, w: 48); kw("Sequ", .keyBlue, w: 48, word: "Sequence"); kw("Cue", .keyBlue, w: 48) }
                GridRow { kw("Edit", w: 48); kw("Assign", w: 48); kw("Time", w: 48) }
                GridRow { kw("Update", .keyRed, w: 48); Color.clear.frame(width: 48, height: U); kw("Store", .keyRed, w: 48) }
            }
            Grid(horizontalSpacing: GP, verticalSpacing: GP) {
                GridRow { num("7"); num("8"); num("9"); kw("+") }
                GridRow { num("4"); num("5"); num("6"); kw("Thru") }
                GridRow { num("1"); num("2"); num("3"); kw("-") }
                GridRow { num("0"); pad(KeypadKey(label: ".", kind: .dot, color: .keyNum)); kw("If")
                          pad(KeypadKey(label: "At", kind: .keyword("At"), color: .keyAmber, textColor: .amberText)) }
                GridRow { WKey(label: "MA", color: .black, down: { state.tick() }); kw("/ *", word: "/")
                          Color.clear.frame(width: U, height: U)
                          pad(KeypadKey(label: "Please", kind: .please, color: .keyGreen)) }
            }
            VStack(spacing: GP) {
                pad(.amber("Oops", .oops))
                Spacer().frame(height: 2 * U + 2 * GP)
                dir("Esc", "Escape")
                pad(.amber("Clear", .clear))
            }
            VStack(spacing: GP) {
                Spacer().frame(height: 4 * U + 3 * GP)
                kw("Full")
            }
            Spacer(minLength: 0)
            LevelWheel().padding(.top, 50)
        }
    }

    // helpers
    private func kw(_ label: String, _ color: Color = .keyGray, w: CGFloat = U, word: String? = nil) -> some View {
        WKey(label: label, color: color, w: w, down: { state.keypad(KeypadKey(label: label, kind: .keyword(word ?? label))) })
    }
    private func dir(_ label: String, _ c: String, w: CGFloat = U) -> some View {
        WKey(label: label, w: w, down: { state.keypad(KeypadKey(label: label, kind: .direct(c))) })
    }
    private func num(_ d: Character) -> some View {
        pad(.num(d))
    }
    private func pad(_ k: KeypadKey) -> some View {
        WKey(label: k.label, color: k.color, text: k.textColor, down: { state.keypad(k) })
    }
}

// MARK: - Encoder & level wheel

private struct EncoderView: View {
    @EnvironmentObject var state: ConsoleState
    let number: Int
    @State private var angle: Double = 0
    @State private var last: CGFloat? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Circle().fill(Color(white: 0.17)).overlay(Circle().stroke(Color.black, lineWidth: 2))
                Circle().fill(Color(white: 0.11)).padding(20).overlay(Circle().stroke(Color.black).padding(20))
                Capsule().fill(Color.maYellow).frame(width: 2, height: 10).offset(y: -20)
            }
            .frame(width: 92, height: 92)
            .rotationEffect(.degrees(angle))
            .shadow(color: .black, radius: 3, y: 2)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let y = g.translation.height
                    let prev = last ?? y
                    let steps = Int((prev - y) / 6)
                    if steps != 0 {
                        last = prev - CGFloat(steps) * 6
                        angle += Double(steps) * 6
                        state.encoder(number, step: steps)
                    } else if last == nil { last = y }
                }
                .onEnded { _ in last = nil })
            .frame(width: 92, height: 104, alignment: .top)

            ConsoleKey(label: "", color: .keyGray, height: 22, onPress: { state.tick() })
                .frame(width: 22).clipShape(Circle())
                .offset(x: -4)
        }
    }
}

private struct LevelWheel: View {
    @EnvironmentObject var state: ConsoleState
    @State private var offset: CGFloat = 0
    @State private var last: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 0.17))
            .overlay(
                VStack(spacing: 3) { ForEach(0..<20, id: \.self) { _ in Rectangle().fill(Color(white: 0.11)).frame(height: 3) } }
                    .offset(y: offset.truncatingRemainder(dividingBy: 6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black))
            .frame(width: 34, height: 120)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let y = g.translation.height
                    let prev = last ?? y
                    let steps = Int((prev - y) / 8)
                    offset = -y
                    if steps != 0 { last = prev - CGFloat(steps) * 8; state.levelWheel(step: steps) }
                    else if last == nil { last = y }
                }
                .onEnded { _ in last = nil })
    }
}
