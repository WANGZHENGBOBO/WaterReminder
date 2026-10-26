import Foundation

public struct FishPosition {
    public let x: Double
    public let y: Double
    public let facingRight: Bool
    public let scale: Double
    public let speed: Double

    public init(x: Double, y: Double, facingRight: Bool, scale: Double, speed: Double) {
        self.x = x
        self.y = y
        self.facingRight = facingRight
        self.scale = scale
        self.speed = speed
    }
}

public struct FishCommand {
    public let start: FishPosition
    public let targetX: Double
    public let targetY: Double
    public let startedAt: TimeInterval

    public init(start: FishPosition, targetX: Double, targetY: Double, startedAt: TimeInterval) {
        self.start = start
        self.targetX = targetX
        self.targetY = targetY
        self.startedAt = startedAt
    }
}

public struct FishLeap {
    public let start: FishPosition
    public let startedAt: TimeInterval
    public let direction: Double
    public let high: Bool
    public let index: Int
    public var duration: TimeInterval { 0.5 + (high ? 1.6 : 1.3) + 0.75 }

    public init(start: FishPosition, startedAt: TimeInterval, direction: Double, high: Bool, index: Int) {
        self.start = start
        self.startedAt = startedAt
        self.direction = direction
        self.high = high
        self.index = index
    }
}

public struct FishLeapFrame {
    public let x: Double
    public let y: Double
    public let angle: Double
    public let splash: Double
}

public enum FishBehavior: Equatable {
    case swim, rest, peck
}

public enum WaterMotion {
    public static func canTriggerLeap(level: Double, fishCount: Int, reduceMotion: Bool) -> Bool {
        level >= 0.3 && level < 1 && fishCount > 0 && !reduceMotion
    }

    public static func canLeap(level: Double, fishCount: Int, reduceMotion: Bool,
                               todayCount: Int, secondsSinceLast: Double) -> Bool {
        canTriggerLeap(level: level, fishCount: fishCount, reduceMotion: reduceMotion)
            && todayCount < 3 && secondsSinceLast >= 7_200
    }

    public static func leapFrame(_ leap: FishLeap, at time: TimeInterval, level: Double,
                                 width: Double, height: Double, phase: Double,
                                 amplitude: Double) -> FishLeapFrame? {
        guard width > 0, height > 0 else { return nil }
        let elapsed = max(time - leap.startedAt, 0)
        let rise = 0.5
        let flight = leap.high ? 1.6 : 1.3
        let landing = rise + flight
        let end = landing + 0.75
        guard elapsed < end else { return nil }
        let direction = leap.direction >= 0 ? 1.0 : -1.0
        let launchX = min(max(leap.start.x + direction * 0.015, 0.08), 0.92)
        let distance = leap.high ? 0.15 : 0.095
        let landingX = min(max(launchX + direction * distance, 0.08), 0.92)
        func waterline(_ x: Double) -> Double {
            surfaceY(x: x * width, width: width, height: height, level: level,
                     phase: phase, amplitude: amplitude) / height
        }
        if elapsed < rise {
            let u = elapsed / rise
            let eased = u * u * (3 - 2 * u)
            let x = leap.start.x + (launchX - leap.start.x) * eased
            let y = leap.start.y + (waterline(x) + 8 / height - leap.start.y) * eased
            return FishLeapFrame(x: x, y: y, angle: -18 * eased * direction, splash: 0)
        }
        if elapsed < landing {
            let u = (elapsed - rise) / flight
            let x = launchX + (landingX - launchX) * u
            let heightAbove = leap.high ? 42.0 : 24.0
            let y = waterline(x) + (8 - heightAbove * sin(.pi * u)) / height
            return FishLeapFrame(x: x, y: y, angle: -22 * cos(.pi * u) * direction, splash: 0)
        }
        let u = (elapsed - landing) / (end - landing)
        return FishLeapFrame(x: landingX, y: waterline(landingX) + (8 + 16 * u) / height,
                             angle: 18 * direction * (1 - u), splash: max(1 - u, 0))
    }

    public static func behavior(at time: TimeInterval, index: Int, hasCommand: Bool) -> FishBehavior {
        guard !hasCommand else { return .swim }
        let phase = (time + Double(index) * 11.37).truncatingRemainder(dividingBy: 80)
        if (50..<55).contains(phase) { return .rest }
        if (67..<73).contains(phase) { return .peck }
        return .swim
    }

    public static func frontDigitIndices(count: Int) -> [Int] {
        Array(stride(from: 0, to: max(count, 0), by: 2))
    }

    public static func frontGlyphMask(for amount: String) -> [Bool] {
        var digit = 0
        return amount.map { character in
            guard character.isNumber else { return false }
            defer { digit += 1 }
            return digit.isMultiple(of: 2)
        }
    }

    public static func waveScale(position: Double, phase: Double) -> Double {
        0.95 + 0.18 * sin(position * 11 + phase)
             + 0.09 * sin(position * 21 - phase * 2)
    }

    public static func surfaceY(x: Double, width: Double, height: Double, level: Double,
                                phase: Double, amplitude: Double) -> Double {
        let clampedLevel = min(max(level, 0), 1)
        let surface = height * (1 - clampedLevel) + amplitude * 1.5 * (1 - clampedLevel)
        let angle = x / max(width, 1) * .pi * 3 + phase
        return surface + sin(angle) * amplitude * waveScale(position: x / max(width, 1), phase: phase)
            + sin(angle * 1.8 - phase) * amplitude * 0.22
    }

    public static func target(x: Double, y: Double, width: Double, height: Double, level: Double,
                              phase: Double, amplitude: Double) -> FishPosition? {
        guard level >= 0.3, width > 0, height > 0, (0...width).contains(x),
              y >= surfaceY(x: x, width: width, height: height, level: level,
                            phase: phase, amplitude: amplitude), y <= height else { return nil }
        let waterTop = surfaceY(x: x, width: width, height: height, level: level,
                                phase: phase, amplitude: amplitude)
        let normalizedY = min(max(y / height, (waterTop + 10) / height), (height - 10) / height)
        return FishPosition(x: min(max(x / width, 0.08), 0.92), y: normalizedY,
                            facingRight: true, scale: fishScale(y: normalizedY, level: level), speed: 0)
    }

    public static func fish(at time: TimeInterval, level: Double, command: FishCommand? = nil,
                            index: Int = 0) -> FishPosition? {
        guard level >= 0.3 else { return nil }
        guard let command else { return ambientFish(at: time, level: level, index: index) }
        let elapsed = max(time - command.startedAt, 0)
        let duration = travelDuration(from: command.start, toX: command.targetX, y: command.targetY)
        func point(_ t: Double) -> (Double, Double) {
            let dx = command.targetX - command.start.x
            let dy = command.targetY - command.start.y
            if t <= duration {
                let u = min(max(t / duration, 0), 1)
                // The slight side arc gives the turn a swimming line, not a UI tween.
                let progress = u + 0.06 * sin(.pi * u)
                let arc = 0.035 * sin(.pi * u) * (dx >= 0 ? 1.0 : -1.0)
                return (command.start.x + dx * progress,
                        command.start.y + dy * progress + arc)
            }
            let glide = t - duration
            let direction = dx >= 0 ? 1.0 : -1.0
            let roomX = min(0.085, command.targetX - 0.08, 0.92 - command.targetX)
            let roomY = min(0.055, command.targetY - (1 - level) - 0.05, 0.95 - command.targetY)
            let x = command.targetX + direction * max(roomX, 0) * sin(glide * 0.65)
            let y = command.targetY + max(roomY, 0) * sin(glide * 0.44)
            return (x, y)
        }
        let (x, y) = point(elapsed)
        let (nextX, nextY) = point(elapsed + 0.04)
        let speed = min(hypot(nextX - x, nextY - y) / 0.04 * 3, 1)
        return FishPosition(x: x, y: y, facingRight: abs(nextX - x) > 0.0002
                            ? nextX >= x : command.start.facingRight,
                            scale: fishScale(y: y, level: level), speed: speed)
    }

    public static func travelDuration(from start: FishPosition, toX x: Double, y: Double) -> Double {
        min(max(hypot(x - start.x, y - start.y) / 0.07, 2.1), 6.5)
    }

    private static func ambientFish(at time: TimeInterval, level: Double, index: Int) -> FishPosition {
        let shifted = time + Double(index) * 11.37
        let phase = shifted.truncatingRemainder(dividingBy: 80)
        let natural = freeFish(at: shifted, level: level)
        let behavior = behavior(at: time, index: index, hasCommand: false)
        guard behavior != .swim else { return natural }
        let anchor: FishPosition
        let weight: Double
        if behavior == .rest {
            anchor = freeFish(at: shifted - phase + 50, level: level)
            weight = min(max((phase - 50) / 0.8, 0), max((55 - phase) / 1.2, 0), 1)
        } else {
            let peckTime = phase - 67
            let x = 0.24 + 0.012 * sin(max(peckTime - 1.8, 0) * .pi * 2)
            let y = min(max(0.70, 1 - level + 0.08), 0.9)
            anchor = FishPosition(x: x, y: y, facingRight: false,
                                  scale: fishScale(y: y, level: level), speed: 0.12)
            weight = min(max(peckTime / 1.8, 0), max((6 - peckTime) / 2.2, 0), 1)
        }
        let eased = weight * weight * (3 - 2 * weight)
        let x = natural.x + (anchor.x - natural.x) * eased
        let y = natural.y + (anchor.y - natural.y) * eased
        return FishPosition(x: x, y: y, facingRight: eased > 0.7 ? anchor.facingRight : natural.facingRight,
                            scale: fishScale(y: y, level: level),
                            speed: natural.speed * (1 - eased) + anchor.speed * eased)
    }

    private static func freeFish(at time: TimeInterval, level: Double) -> FishPosition {
        // Deterministic roaming waypoints keep the path varied without storing animation state.
        func track(_ t: Double) -> (Double, Double) {
            func random(_ n: Int, _ salt: Int) -> Double {
                let value = sin(Double(n * 127 + salt * 311) * 12.9898) * 43758.5453
                return value - floor(value)
            }
            func waypoint(_ n: Int) -> (Double, Double) {
                let previous = 0.16 + 0.68 * random(n - 1, 1)
                var x = 0.16 + 0.68 * random(n, 1)
                if abs(x - previous) < 0.22 {
                    x = previous < 0.5 ? min(previous + 0.32, 0.84) : max(previous - 0.32, 0.16)
                }
                return (x, 0.22 + 0.58 * random(n, 2))
            }
            let segment = Int(floor(t / 12))
            let u = (t / 12) - Double(segment)
            let a = waypoint(segment - 1)
            let b = waypoint(segment)
            let c = waypoint(segment + 1)
            let d = waypoint(segment + 2)
            func curve(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> Double {
                let m1 = (p2 - p0) * 0.35
                let m2 = (p3 - p1) * 0.35
                return (2*u*u*u - 3*u*u + 1)*p1 + (u*u*u - 2*u*u + u)*m1
                     + (-2*u*u*u + 3*u*u)*p2 + (u*u*u - u*u)*m2
            }
            let x = min(max(curve(a.0, b.0, c.0, d.0), 0.09), 0.91)
            let depth = min(max(curve(a.1, b.1, c.1, d.1), 0.22), 0.82)
            return (x, 1 - min(level, 1) * depth)
        }
        let (x, y) = track(roamingTime(at: time))
        let (nextX, nextY) = track(roamingTime(at: time + 0.08))
        let speed = min(hypot(nextX - x, nextY - y) / 0.08 * 2.5, 1)
        return FishPosition(x: x, y: y, facingRight: nextX >= x,
                            scale: fishScale(y: y, level: level), speed: speed)
    }

    public static func roamingTime(at time: TimeInterval) -> TimeInterval {
        time + 1.5 * sin(time * 0.23) + 0.6 * sin(time * 0.51 + 1)
    }

    private static func fishScale(y: Double, level: Double) -> Double {
        let depth = (y - (1 - min(level, 1))) / max(level, 0.01)
        return 0.65 + 0.65 * min(max(depth, 0), 1)
    }

    public static func tailAngle(at time: TimeInterval, chasing: Bool) -> Double {
        sin(time * (chasing ? 14 : 9)) * (chasing ? 26 : 18)
    }

    public static func tailSpread(angle: Double) -> Double {
        max(0.6, 1 - 0.4 * min(abs(angle) / 26, 1))
    }

    public static func pitch(dx: Double, dy: Double) -> Double {
        guard hypot(dx, dy) > 0.0001 else { return 0 }
        let angle = atan2(dy, abs(dx)) * 180 / .pi * (dx < 0 ? -1 : 1)
        return min(max(angle, -18), 18)
    }
}
