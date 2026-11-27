import SwiftUI

// MARK: - Momentary console key (press on touch-down, release on touch-up)

struct ConsoleKey: View {
    let label: String
    var sublabel: String? = nil
    var color: Color = .keyGray
    var textColor: Color = .white
    var height: CGFloat = 44
    var onPress: () -> Void
    var onRelease: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(pressed ? color.opacity(1.0) : color.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(pressed ? Color.maYellow : Color.black.opacity(0.6), lineWidth: pressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.6), radius: pressed ? 0 : 2, y: pressed ? 0 : 2)
            .overlay(
                VStack(spacing: 1) {
                    Text(label).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.5)
                    if let s = sublabel {
                        Text(s).font(.system(size: 9, weight: .regular, design: .monospaced)).opacity(0.7)
                    }
                }
                .foregroundStyle(textColor)
                .padding(.horizontal, 2)
            )
            .frame(height: height)
            .scaleEffect(pressed ? 0.96 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed { pressed = true; onPress() }
                    }
                    .onEnded { _ in
                        pressed = false; onRelease()
                    }
            )
            .animation(.easeOut(duration: 0.06), value: pressed)
    }
}

// MARK: - Fader (relative drag – the cap doesn't jump to the finger)

struct FaderView: View {
    let value: Double                      // 0...100
    var label: String = ""
    var onTouch: (Bool) -> Void = { _ in }
    var onChange: (Double) -> Void

    @State private var startValue: Double? = nil
    let capHeight: CGFloat = 46

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.height - capHeight, 1)
            let y = travel * (1 - value / 100)
            ZStack(alignment: .top) {
                // scale ticks
                VStack(spacing: 0) {
                    ForEach(0..<11) { i in
                        HStack {
                            Rectangle().fill(Color.white.opacity(i % 5 == 0 ? 0.5 : 0.2))
                                .frame(width: i % 5 == 0 ? 10 : 6, height: 1)
                            Spacer()
                            Rectangle().fill(Color.white.opacity(i % 5 == 0 ? 0.5 : 0.2))
                                .frame(width: i % 5 == 0 ? 10 : 6, height: 1)
                        }
                        if i < 10 { Spacer() }
                    }
                }
                .padding(.vertical, capHeight / 2)

                // slot + level fill
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.black)
                    Capsule().fill(Color.maYellow.opacity(0.85))
                        .frame(height: max(0, (geo.size.height - capHeight) * value / 100))
                }
                .frame(width: 6)
                .padding(.vertical, capHeight / 2)
                .frame(maxWidth: .infinity)

                // cap
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.25), Color(white: 0.45)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle().fill(Color.white.opacity(0.9)).frame(height: 2))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(startValue != nil ? Color.maYellow : .black, lineWidth: 1.5))
                    .frame(width: min(geo.size.width * 0.8, 52), height: capHeight)
                    .shadow(color: .black, radius: 3, y: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: y)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if startValue == nil { startValue = value; onTouch(true) }
                        let delta = -Double(g.translation.height / travel) * 100
                        onChange(min(max((startValue ?? 0) + delta, 0), 100))
                    }
                    .onEnded { _ in startValue = nil; onTouch(false) }
            )
        }
    }
}

// MARK: - Executor knob (rows 301/401) – vertical drag, relative

struct KnobView: View {
    let value: Double          // 0...100
    var onTouch: (Bool) -> Void = { _ in }
    var onChange: (Double) -> Void

    @State private var startValue: Double? = nil

    var body: some View {
        ZStack {
            Circle().stroke(Color(white: 0.17), lineWidth: 5)
            Circle().trim(from: 0, to: value / 100)
                .stroke(Color.maYellow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(Color(white: 0.23)).padding(6)
                .overlay(Circle().stroke(Color.black).padding(6))
            Text("\(Int(value.rounded()))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if startValue == nil { startValue = value; onTouch(true) }
                    onChange(min(max((startValue ?? 0) - Double(g.translation.height) * 0.6, 0), 100))
                }
                .onEnded { _ in startValue = nil; onTouch(false) }
        )
    }
}

// MARK: - Panel container

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.panelBG))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06)))
    }
}
