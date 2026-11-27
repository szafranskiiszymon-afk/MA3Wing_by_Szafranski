import SwiftUI

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var state: ConsoleState
    @Environment(\.horizontalSizeClass) var hSize
    @State private var mode: Mode = .faders
    @State private var showSettings = false

    enum Mode: String, CaseIterable, Identifiable {
        case faders = "Fadery", keypad = "Klawiatura", full = "Całość"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 8) {
            TopBar(mode: $mode, showSettings: $showSettings)
            Group {
                switch mode {
                case .faders:
                    HStack(spacing: 8) {
                        ExecutorSection()
                        MasterSection().frame(width: 130)
                    }
                case .keypad:
                    CommandSection()
                case .full:
                    if hSize == .regular {
                        WingView()          // iPad: layout of grandMA3 onPC command wing XT
                    } else {
                        HStack(spacing: 8) {
                            ExecutorSection()
                            CommandSection().frame(width: 340)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.consoleBG.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .sheet(isPresented: $showSettings, onDismiss: { state.connect() }) {
            SettingsView().environmentObject(state)
        }
        .onAppear {
            state.connect()
            UIApplication.shared.isIdleTimerDisabled = true
            if hSize == .regular { mode = .full }
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var state: ConsoleState
    @Binding var mode: ContentView.Mode
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 10, height: 10)
            Text(state.host).font(.caption.monospaced()).foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ConsoleKey(label: "◀︎", height: 30) { state.changePage(by: -1) }.frame(width: 36)
                Text("Page \(state.page)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.maYellow)
                    .frame(minWidth: 70)
                ConsoleKey(label: "▶︎", height: 30) { state.changePage(by: 1) }.frame(width: 36)
            }

            // command line display
            HStack {
                Text("[\(state.page)]>").foregroundStyle(Color.maYellow)
                Text(state.commandLine.isEmpty ? " " : state.commandLine).foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 8).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black))

            Picker("", selection: $mode) {
                ForEach(ContentView.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
    }

    private var dotColor: Color {
        switch state.connState {
        case .ready: return .green
        case .connecting: return .orange
        case .failed: return .red
        case .idle: return .gray
        }
    }
}

// MARK: - Executor section
// MA3 column, top to bottom: knob+key 4xx, knob+key 3xx, fader 2xx with its key below, key 1xx.
// Columns are grouped in blocks of 5, like on the console.

struct ExecutorSection: View {
    @EnvironmentObject var state: ConsoleState

    private var blocks: [[Int]] {
        stride(from: 0, to: state.columns.count, by: 5).map {
            Array(state.columns[$0..<min($0 + 5, state.columns.count)])
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(blocks, id: \.self) { block in
                Panel {
                    HStack(spacing: 5) {
                        ForEach(block, id: \.self) { col in ExecutorColumn(col: col) }
                    }
                }
            }
        }
    }
}

struct ExecutorColumn: View {
    @EnvironmentObject var state: ConsoleState
    @Environment(\.verticalSizeClass) var vSize   // iPhone landscape = .compact -> no room for knobs
    let col: Int   // 0-based

    private var faderExec: Int { (state.faderRow / 100) * 100 + col + 1 }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(state.upperRowBases, id: \.self) { base in
                let exec = base + col + 1
                if vSize != .compact { KnobView(
                    value: state.faderValue(exec),
                    onTouch: { t in if t { state.touching.insert(exec) } else { state.touching.remove(exec) } },
                    onChange: { state.setFader(exec, $0) }
                ) }
                execKey(exec)
            }
            FaderView(
                value: state.faderValue(faderExec),
                onTouch: { t in
                    if t { state.touching.insert(faderExec) } else { state.touching.remove(faderExec) }
                },
                onChange: { state.setFader(faderExec, $0) }
            )
            Text("\(Int(state.faderValue(faderExec).rounded()))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.maYellow)
            execKey(faderExec, color: .keyNum, height: 40)   // key of the fader executor, below the fader
            ForEach(state.lowerRowBases, id: \.self) { base in
                execKey(base + col + 1, height: 40)
            }
        }
        .frame(minWidth: 46, maxWidth: 80)
    }

    /// MA3 marks rows with 1–4 horizontal lines on the key caps.
    private func execKey(_ exec: Int, color: Color = .keyGray, height: CGFloat = 36) -> some View {
        let lines = String(repeating: "–", count: max(1, min(4, exec / 100)))
        return ConsoleKey(label: "\(exec)", sublabel: lines, color: color, height: height,
                          onPress: { state.key(exec, pressed: true) },
                          onRelease: { state.key(exec, pressed: false) })
    }
}

// MARK: - Compact master section (Fadery mode)

struct MasterSection: View {
    @EnvironmentObject var state: ConsoleState

    var body: some View {
        Panel {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    ConsoleKey(label: "<<<", height: 34) { state.command("<<<") }
                    ConsoleKey(label: ">>>", height: 34) { state.command(">>>") }
                }
                HStack(spacing: 5) {
                    ConsoleKey(label: "Go-", height: 44) { state.command("Go-") }
                    ConsoleKey(label: "Pause", color: .keyAmber, textColor: .amberText, height: 44) { state.command("Pause") }
                }
                ConsoleKey(label: "Go+", color: .keyGreen, height: 56) { state.command("Go+") }
                GrandMaster()
            }
        }
    }
}

struct GrandMaster: View {
    @EnvironmentObject var state: ConsoleState
    var body: some View {
        VStack(spacing: 6) {
            Text("GM").font(.caption2.bold()).foregroundStyle(.secondary)
            FaderView(value: state.grandMaster, onChange: { state.setGrandMaster($0) })
            Text("\(Int(state.grandMaster.rounded()))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.maYellow)
            ConsoleKey(label: "B.O.", color: .keyRed, height: 44) { state.command(state.blackoutCmd) }
        }
    }
}

// MARK: - Command section: Xkeys, master keys, function keys, keypad + Grand Master

struct CommandSection: View {
    @EnvironmentObject var state: ConsoleState

    private let xColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        Panel {
            HStack(spacing: 8) {
                VStack(spacing: 8) {
                    LazyVGrid(columns: xColumns, spacing: 4) {
                        ForEach(XKey.all) { x in
                            ConsoleKey(label: x.label, sublabel: x.sub, color: .keyX, height: 38,
                                       onPress: { state.key(x.id, pressed: true) },
                                       onRelease: { state.key(x.id, pressed: false) })
                        }
                    }
                    HStack(spacing: 5) {
                        ConsoleKey(label: "<<<", height: 34) { state.command("<<<") }
                        ConsoleKey(label: ">>>", height: 34) { state.command(">>>") }
                        ConsoleKey(label: "Learn", height: 34) { state.command("Learn") }
                    }
                    HStack(spacing: 5) {
                        ConsoleKey(label: "Go-", height: 54) { state.command("Go-") }
                        ConsoleKey(label: "Pause", color: .keyAmber, textColor: .amberText, height: 54) { state.command("Pause") }
                        ConsoleKey(label: "Go+", color: .keyGreen, height: 54) { state.command("Go+") }
                            .layoutPriority(1)
                    }
                    grid(KeyLayout.functions, height: 40)
                    GeometryReader { geo in
                        let rows = CGFloat(KeyLayout.keypad.count)
                        grid(KeyLayout.keypad, height: max(36, (geo.size.height - (rows - 1) * 5) / rows))
                    }
                }
                GrandMaster().frame(width: 64)
            }
        }
    }

    private func grid(_ rows: [[KeypadKey]], height: CGFloat) -> some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(rows[r]) { k in
                        ConsoleKey(label: k.label, color: k.color, textColor: k.textColor, height: height) { state.keypad(k) }
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var state: ConsoleState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Połączenie (OSC / UDP)") {
                    LabeledContent("IP konsoli / onPC") {
                        TextField("192.168.1.100", text: $state.host)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper("Port wysyłania: \(state.sendPort)", value: $state.sendPort, in: 1...65535)
                    Stepper("Port odbioru (feedback): \(state.receivePort)", value: $state.receivePort, in: 0...65535)
                    LabeledContent("Prefix") {
                        TextField("gma3", text: $state.prefix)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Wartości faderów jako float", isOn: $state.useFloat)
                }

                Section("Układ") {
                    Stepper("Liczba faderów: \(state.faderCount)", value: $state.faderCount, in: 1...30)
                    Stepper("Pierwsza kolumna: \(state.firstColumn)", value: $state.firstColumn, in: 1...90)
                    Stepper("Rząd faderów: \(state.faderRow)", value: $state.faderRow, in: 101...901, step: 100)
                    LabeledContent("Rzędy przycisków nad") {
                        TextField("401,301", text: $state.upperRows).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Rzędy przycisków pod") {
                        TextField("101", text: $state.lowerRows).multilineTextAlignment(.trailing)
                    }
                }

                Section("Komendy (edytowalne)") {
                    LabeledContent("Grand Master ($ = wartość)") {
                        TextField("Master 2.1 At $", text: $state.grandMasterCmd).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Master ($ = wartość)") {
                        TextField("Master 1.1 At $", text: $state.masterCmd).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Enkodery – adres OSC") {
                        TextField("np. /Encoder{n} (puste = nie wysyłaj)", text: $state.encoderAddr)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Level wheel – adres OSC") {
                        TextField("puste = nie wysyłaj", text: $state.levelWheelAddr)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("B.O.") {
                        TextField("Black Master 2.1", text: $state.blackoutCmd).multilineTextAlignment(.trailing)
                    }
                    Toggle("Wysyłaj „Page N” przy zmianie strony", isOn: $state.sendPageCmd)
                    Toggle("Haptyka", isOn: $state.haptics)
                }

                Section("Diagnostyka") {
                    LabeledContent("Ostatnio wysłane") {
                        Text(state.lastSent).font(.caption.monospaced()).lineLimit(2)
                    }
                    Button("Test: wyślij „Fixture 1 At Full”") { state.command("Fixture 1 At Full") }
                }

                Section("Konfiguracja w grandMA3") {
                    Text("Menu → In & Out → OSC: dodaj linię z IP iPhone'a/iPada, port \(state.sendPort), prefix „\(state.prefix)”, włącz Receive, Receive Command i Enable Input. Dla feedbacku faderów włącz też Send na porcie \(state.receivePort).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ustawienia")
            .toolbar { Button("Gotowe") { dismiss() } }
        }
    }
}
