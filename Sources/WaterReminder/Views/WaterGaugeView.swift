import SwiftUI
import WaterCore

func waveColor(_ hex: String, fallback: Color = .white) -> Color {
    guard WaveAppearance.isHexColor(hex), let rgb = UInt32(hex.dropFirst(), radix: 16) else { return fallback }
    return Color(red: Double((rgb >> 16) & 255) / 255,
                 green: Double((rgb >> 8) & 255) / 255,
                 blue: Double(rgb & 255) / 255)
}

private struct WaveLayers: View {
    let level: CGFloat
    let time: TimeInterval
    let appearance: WaveAppearance

    var body: some View {
        ZStack {
            if level > 0 {
                WaterWave(level: level + 0.012,
                          phase: CGFloat((time * appearance.frontSpeed).truncatingRemainder(dividingBy: 2 * .pi) + 1.7),
                          amplitude: appearance.frontHeight)
                    .fill(waveColor(appearance.frontHex).opacity(appearance.frontOpacity))
                WaterWave(level: level, phase: CGFloat((time * appearance.speed).truncatingRemainder(dividingBy: 2 * .pi)),
                          amplitude: appearance.height)
                    .fill(waveColor(appearance.baseHex, fallback: Color(red: 0, green: 0.5, blue: 1))
                        .opacity(appearance.baseOpacity))
            }
        }
    }
}

private struct WaterWave: Shape {
    var level: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(level, phase) }
        set { level = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func surfaceY(_ x: CGFloat) -> CGFloat {
            CGFloat(WaterMotion.surfaceY(x: Double(x), width: Double(rect.width), height: Double(rect.height),
                                         level: Double(level), phase: Double(phase), amplitude: Double(amplitude)))
        }
        path.move(to: CGPoint(x: 0, y: surfaceY(0)))
        for x in stride(from: CGFloat(3), to: rect.width, by: 3) {
            path.addLine(to: CGPoint(x: x, y: surfaceY(x)))
        }
        path.addLine(to: CGPoint(x: rect.width, y: surfaceY(rect.width)))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct SwimmingFish: View {
    let level: CGFloat
    let time: TimeInterval
    let command: FishCommand?
    let reduceMotion: Bool
    let appearance: WaveAppearance
    let index: Int

    var body: some View {
        GeometryReader { geometry in
            if let fish = WaterMotion.fish(at: reduceMotion ? 4.5 : time,
                                           level: Double(level), command: reduceMotion ? nil : command,
                                           index: index) {
                let next = WaterMotion.fish(at: reduceMotion ? 4.5 : time + 0.04,
                                            level: Double(level), command: reduceMotion ? nil : command,
                                            index: index) ?? fish
                let mode = WaterMotion.behavior(at: time, index: index, hasCommand: command != nil)
                FishSilhouette(tailBend: reduceMotion ? 0 : WaterMotion.tailAngle(
                    at: time, chasing: command != nil) * (0.35 + fish.speed)
                    * (mode == .rest ? 0.12 : mode == .peck ? 1.2 : 1))
                    .fill(Color(red: 0.015, green: 0.075, blue: 0.14).opacity(0.94))
                    .frame(width: 19, height: 9.5)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(.white.opacity(mode == .rest ? 0.12 : 0.52))
                            .frame(width: 1.1, height: 1.1)
                            .padding(.top, 3.1).padding(.trailing, 1.8)
                    }
                    .scaleEffect(x: fish.facingRight ? 1 : -1, y: 1)
                    .scaleEffect(fish.scale)
                    .rotationEffect(.degrees(WaterMotion.pitch(dx: next.x - fish.x, dy: next.y - fish.y)))
                    .position(x: geometry.size.width * CGFloat(fish.x),
                              y: geometry.size.height * CGFloat(fish.y))
            }
        }
        .mask(WaterWave(level: level,
                        phase: CGFloat((time * appearance.speed).truncatingRemainder(dividingBy: 2 * .pi)),
                        amplitude: appearance.height))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FishDigitOverlay: View {
    let amountText: String
    let cardSize: CGSize
    let time: TimeInterval
    let level: CGFloat
    let appearance: WaveAppearance
    let commands: [Int: FishCommand]
    let leapingIndex: Int?
    let reduceMotion: Bool

    private var glyphMask: Text {
        var text = Text("")
        for (character, isFront) in zip(amountText, WaterMotion.frontGlyphMask(for: amountText)) {
            text = text + Text(String(character)).foregroundColor(isFront ? .white : .clear)
        }
        return text
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("waterGauge"))
            ZStack {
                ForEach(0..<appearance.fishCount, id: \.self) { index in
                    if index != leapingIndex, let fish = WaterMotion.fish(at: reduceMotion ? 4.5 : time,
                                                   level: Double(level), command: reduceMotion ? nil : commands[index],
                                                   index: index), fish.scale >= 1 {
                        let next = WaterMotion.fish(at: reduceMotion ? 4.5 : time + 0.04,
                                                    level: Double(level), command: reduceMotion ? nil : commands[index],
                                                    index: index) ?? fish
                        FishSilhouette(tailBend: reduceMotion ? 0 : WaterMotion.tailAngle(
                            at: time, chasing: commands[index] != nil) * (0.35 + fish.speed))
                            .fill(Color(red: 0.015, green: 0.075, blue: 0.14).opacity(0.94))
                            .frame(width: 19, height: 9.5)
                            .scaleEffect(x: fish.facingRight ? 1 : -1, y: 1)
                            .scaleEffect(fish.scale)
                            .rotationEffect(.degrees(WaterMotion.pitch(dx: next.x - fish.x, dy: next.y - fish.y)))
                            .position(x: cardSize.width * CGFloat(fish.x) - frame.minX,
                                      y: cardSize.height * CGFloat(fish.y) - frame.minY)
                    }
                }
            }
            .mask(glyphMask.font(.system(size: 43, weight: .semibold, design: .rounded)).monospacedDigit())
        }
        .allowsHitTesting(false)
    }
}

private struct FishSilhouette: Shape {
    let tailBend: Double

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 38
        let sy = rect.height / 19
        let swing = CGFloat(tailBend / 26)
        let spread = CGFloat(WaterMotion.tailSpread(angle: tailBend))
        let tailCenter = 9.5 + swing * 5
        let tailX = abs(swing) * 3
        var path = Path()
        path.move(to: CGPoint(x: 37 * sx, y: 9.5 * sy))
        path.addCurve(to: CGPoint(x: 8 * sx, y: (6.8 + swing) * sy),
                      control1: CGPoint(x: 36 * sx, y: 1 * sy),
                      control2: CGPoint(x: 17 * sx, y: (3 + swing * 1.4) * sy))
        path.addLine(to: CGPoint(x: tailX * sx, y: (tailCenter - 8 * spread) * sy))
        path.addQuadCurve(to: CGPoint(x: 5.5 * sx, y: tailCenter * sy),
                          control: CGPoint(x: 2.6 * sx, y: (tailCenter - 3.5 * spread) * sy))
        path.addQuadCurve(to: CGPoint(x: tailX * sx, y: (tailCenter + 8 * spread) * sy),
                          control: CGPoint(x: 2.6 * sx, y: (tailCenter + 3.5 * spread) * sy))
        path.addLine(to: CGPoint(x: 8 * sx, y: (12.2 + swing) * sy))
        path.addCurve(to: CGPoint(x: 37 * sx, y: 9.5 * sy),
                      control1: CGPoint(x: 18 * sx, y: (16 + swing * 1.4) * sy),
                      control2: CGPoint(x: 36 * sx, y: 18 * sy))
        path.closeSubpath()
        return path
    }
}

private struct LeapingFish: View {
    let leap: FishLeap
    let time: TimeInterval
    let level: CGFloat
    let appearance: WaveAppearance

    var body: some View {
        GeometryReader { geometry in
            let phase = (time * appearance.speed).truncatingRemainder(dividingBy: 2 * .pi)
            if let frame = WaterMotion.leapFrame(leap, at: time, level: Double(level),
                                                  width: Double(geometry.size.width), height: Double(geometry.size.height),
                                                  phase: phase, amplitude: appearance.height) {
                let waterMask = WaterWave(level: level, phase: CGFloat(phase), amplitude: appearance.height)
                let fishX = geometry.size.width * CGFloat(frame.x)
                let fishY = geometry.size.height * CGFloat(frame.y)
                let tail = WaterMotion.tailAngle(at: time, chasing: false) * (0.35 + leap.start.speed)
                fish(color: waveColor(appearance.baseHex, fallback: .blue), tail: tail, angle: frame.angle)
                    .position(x: fishX, y: fishY)
                ZStack {
                    fish(color: Color(red: 0.015, green: 0.075, blue: 0.14), tail: tail, angle: frame.angle)
                        .position(x: fishX, y: fishY)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .mask(waterMask)
                if frame.splash > 0 {
                    let surface = WaterMotion.surfaceY(x: Double(fishX), width: Double(geometry.size.width),
                                                       height: Double(geometry.size.height), level: Double(level),
                                                       phase: phase, amplitude: appearance.height)
                    ForEach(0..<4, id: \.self) { index in
                        let spread = Double(index) - 1.5
                        Circle()
                            .fill(waveColor(appearance.frontHex).opacity(frame.splash * 0.75))
                            .frame(width: index.isMultiple(of: 2) ? 3 : 2,
                                   height: index.isMultiple(of: 2) ? 3 : 2)
                            .position(x: fishX + CGFloat(spread * 11 * (1 - frame.splash)),
                                      y: CGFloat(surface - 4 - (10 - abs(spread) * 2)
                                                 * sin(.pi * (1 - frame.splash))))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fish(color: Color, tail: Double, angle: Double) -> some View {
        FishSilhouette(tailBend: tail)
            .fill(color)
            .frame(width: 19, height: 9.5)
            .overlay(alignment: .topTrailing) {
                Circle().fill(.white.opacity(0.38))
                    .frame(width: 1.1, height: 1.1)
                    .padding(.top, 3.1).padding(.trailing, 1.8)
            }
            .scaleEffect(x: leap.direction >= 0 ? 1 : -1, y: 1)
            .scaleEffect(leap.start.scale)
            .rotationEffect(.degrees(angle))
    }
}

struct WaterGaugeView: View {
    let total: Int
    let goal: Int
    let count: Int
    let date: Date
    let appearance: WaveAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedLevel: CGFloat = 0
    @State private var fishCommands: [Int: FishCommand] = [:]
    @State private var activeLeap: FishLeap?
    @State private var waterTaps = ConsecutiveTapTracker()
    @State private var leapLoop: Task<Void, Never>?
    @State private var leapFinish: Task<Void, Never>?
    @State private var gaugeSize = CGSize(width: 314, height: 218)
    @AppStorage("fishLeapDay") private var leapDay = ""
    @AppStorage("fishLeapCount") private var leapCount = 0
    @AppStorage("fishLeapLastAt") private var leapLastAt = 0.0

    private var level: CGFloat { min(CGFloat(total) / CGFloat(max(goal, 1)), 1) }
    private var amountText: String { total.formatted(.number) }
    private var dailyText: DailyCardText { .forDate(date) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || level == 0)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color(red: 0.035, green: 0.065, blue: 0.12)
                    WaveLayers(level: displayedLevel, time: time, appearance: appearance)
                    ForEach(0..<appearance.fishCount, id: \.self) { index in
                        if activeLeap?.index != index || activeLeap.map({ time - $0.startedAt >= $0.duration }) == true {
                            SwimmingFish(level: displayedLevel, time: time, command: fishCommands[index],
                                         reduceMotion: reduceMotion, appearance: appearance, index: index)
                        }
                    }
                    if let activeLeap, !reduceMotion {
                        LeapingFish(leap: activeLeap, time: time, level: displayedLevel,
                                    appearance: appearance)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Label("喝水BO～", systemImage: "drop.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(dailyText.dateLine)
                                .font(.system(size: 11, weight: .semibold))
                            Text(dailyText.lunarLine)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.white.opacity(0.72))
                    }
                    Text(dailyText.phrase)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 12)
                    Spacer()
                    Text("今日饮水")
                        .font(.caption).foregroundStyle(.white.opacity(0.72))
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(amountText)
                            .font(.system(size: 43, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .overlay {
                                FishDigitOverlay(amountText: amountText, cardSize: geometry.size, time: time,
                                                 level: displayedLevel, appearance: appearance,
                                                 commands: fishCommands,
                                                 leapingIndex: activeLeap?.index, reduceMotion: reduceMotion)
                            }
                        Text("/ \(goal) ml")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                    HStack(alignment: .bottom) {
                        Text("今天喝了 \(count) 次")
                            .font(.caption).foregroundStyle(.white.opacity(0.78))
                        Spacer()
                        Text("\(Int(Double(total) / Double(max(goal, 1)) * 100))%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.top, 4)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                }
                .coordinateSpace(name: "waterGauge")
                .contentShape(Rectangle())
                .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                    let stamp = Date().timeIntervalSinceReferenceDate
                    let phase = (stamp * appearance.speed).truncatingRemainder(dividingBy: 2 * .pi)
                    guard let target = WaterMotion.target(
                        x: Double(tap.location.x), y: Double(tap.location.y),
                        width: Double(geometry.size.width), height: Double(geometry.size.height),
                        level: Double(displayedLevel), phase: phase, amplitude: appearance.height
                    ) else { return }
                    let nearest = (0..<appearance.fishCount).compactMap { index -> (Int, FishPosition)? in
                        guard let position = WaterMotion.fish(at: stamp, level: Double(displayedLevel),
                                                               command: fishCommands[index], index: index) else { return nil }
                        return (index, position)
                    }.min { first, second in
                        hypot(first.1.x - target.x, first.1.y - target.y)
                            < hypot(second.1.x - target.x, second.1.y - target.y)
                    }
                    guard let (index, current) = nearest else { return }
                    fishCommands[index] = FishCommand(start: current, targetX: target.x,
                                                       targetY: target.y, startedAt: stamp)
                    if waterTaps.register(at: stamp) {
                        beginLeap(index: index, stamp: stamp, high: false, countsTowardDailyLimit: false)
                    }
                })
                .onAppear { gaugeSize = geometry.size }
            }
            .frame(height: 218)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("今日喝水 \(total) 毫升，目标 \(goal) 毫升，完成 \(Int(Double(total) / Double(max(goal, 1)) * 100))%，记录 \(count) 次")
            .help("点击水面，小鱼会游过来")
        }
        .onAppear {
            displayedLevel = level
            startLeapLoop()
        }
        .onDisappear {
            leapLoop?.cancel()
            leapFinish?.cancel()
            leapLoop = nil
            leapFinish = nil
            activeLeap = nil
        }
        .onChange(of: level) { newLevel in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 2)) { displayedLevel = newLevel }
        }
    }

    private func startLeapLoop() {
        leapLoop?.cancel()
        leapLoop = Task { @MainActor in
            var firstCheck = true
            while !Task.isCancelled {
                let delay = firstCheck ? Double.random(in: 6...18) : Double.random(in: 90...240)
                firstCheck = false
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
                let now = Date()
                let stamp = now.timeIntervalSinceReferenceDate
                let components = Calendar.current.dateComponents([.year, .month, .day], from: now)
                let day = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
                if leapDay != day {
                    leapDay = day
                    leapCount = 0
                }
                guard activeLeap == nil, Int.random(in: 0..<4) == 0,
                      WaterMotion.canLeap(level: Double(displayedLevel), fishCount: appearance.fishCount,
                                          reduceMotion: reduceMotion, todayCount: leapCount,
                                          secondsSinceLast: leapLastAt == 0 || leapCount == 0
                                              ? .infinity : stamp - leapLastAt) else { continue }
                let index = Int.random(in: 0..<appearance.fishCount)
                beginLeap(index: index, stamp: stamp,
                          high: displayedLevel < 0.75 && Int.random(in: 0..<6) == 0,
                          countsTowardDailyLimit: true)
            }
        }
    }

    private func beginLeap(index: Int, stamp: TimeInterval, high: Bool,
                           countsTowardDailyLimit: Bool) {
        guard activeLeap == nil,
              WaterMotion.canTriggerLeap(level: Double(displayedLevel),
                                         fishCount: appearance.fishCount,
                                         reduceMotion: reduceMotion),
              let fish = WaterMotion.fish(at: stamp, level: Double(displayedLevel),
                                          command: fishCommands[index], index: index) else { return }
        let direction = fish.x < 0.3 ? 1.0 : fish.x > 0.7 ? -1.0 : (Bool.random() ? 1.0 : -1.0)
        let leap = FishLeap(start: fish, startedAt: stamp, direction: direction,
                            high: high, index: index)
        activeLeap = leap
        if countsTowardDailyLimit {
            leapCount += 1
            leapLastAt = stamp
        }
        leapFinish?.cancel()
        leapFinish = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(leap.duration)) }
            catch { return }
            let endTime = Date().timeIntervalSinceReferenceDate
            let phase = (endTime * appearance.speed).truncatingRemainder(dividingBy: 2 * .pi)
            if let landing = WaterMotion.leapFrame(leap, at: leap.startedAt + leap.duration - 0.01,
                                                    level: Double(displayedLevel),
                                                    width: Double(gaugeSize.width), height: Double(gaugeSize.height),
                                                    phase: phase, amplitude: appearance.height) {
                let position = FishPosition(x: landing.x, y: landing.y,
                                            facingRight: direction > 0, scale: fish.scale, speed: 0.1)
                fishCommands[index] = FishCommand(start: position,
                                                   targetX: min(max(landing.x + direction * 0.08, 0.08), 0.92),
                                                   targetY: min(landing.y + 0.03, 0.95), startedAt: endTime)
            }
            activeLeap = nil
        }
    }
}

struct WaterWavePreview: View {
    let appearance: WaveAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Color(red: 0.035, green: 0.065, blue: 0.12)
                WaveLayers(level: 0.55, time: time, appearance: appearance)
                ForEach(0..<appearance.fishCount, id: \.self) { index in
                    SwimmingFish(level: 0.55, time: time, command: nil,
                                 reduceMotion: reduceMotion, appearance: appearance, index: index)
                }
                HStack {
                    Text("水波预览")
                    Spacer()
                    Text("55%")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
