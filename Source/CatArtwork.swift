import SwiftUI

/// A tiny room painted from source-native pixels. Best at 296 × 130 or larger.
struct CatScene: View {
    var activity: String = "garden"
    var decor: String = "none"
    var level: Int = 1
    var reaction: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let factor = min(size.width / 296, size.height / 130)
                context.translateBy(x: (size.width - 296 * factor) / 2,
                                    y: (size.height - 130 * factor) / 2)
                context.scaleBy(x: factor, y: factor)
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                TinyRoom.draw(in: &context, time: t, activity: activity,
                              decor: decor, level: level, reaction: reaction)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity == "nap" ? "小猫正蜷着睡觉" : "窗边的小橘猫")
    }
}

/// Transparent 80 × 70 point companion; `scale` also expands its layout size.
struct PixelCat: View {
    var activity: String = "garden"
    var reaction: String = ""
    var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: reduceMotion)) { timeline in
            Canvas { context, _ in
                context.scaleBy(x: scale, y: scale)
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                TinyRoom.cat(in: &context, time: t, activity: activity, reaction: reaction)
            }
        }
        .frame(width: 80 * scale, height: 70 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("像素小橘猫")
    }
}

private enum TinyRoom {
    static let ink = Color(red: 0.32, green: 0.25, blue: 0.22)
    static let ginger = Color(red: 0.85, green: 0.53, blue: 0.32)
    static let lightGinger = Color(red: 0.97, green: 0.71, blue: 0.44)
    static let cream = Color(red: 1.0, green: 0.89, blue: 0.68)
    static let blush = Color(red: 0.91, green: 0.58, blue: 0.49)
    static let mint = Color(red: 0.61, green: 0.72, blue: 0.62)
    static let forest = Color(red: 0.36, green: 0.50, blue: 0.39)
    static let sage = Color(red: 0.72, green: 0.79, blue: 0.63)
    static let terracotta = Color(red: 0.73, green: 0.42, blue: 0.30)

    static func box(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
                    _ w: CGFloat, _ h: CGFloat, _ color: Color) {
        c.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }
    static func polygon(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)], _ color: Color) {
        guard let first = points.first else { return }
        var p = Path()
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in points.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.closeSubpath()
        c.fill(p, with: .color(color))
    }
    static func oval(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat,
                     _ w: CGFloat, _ h: CGFloat, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }
    static func star(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat, color: Color, size: CGFloat = 2) {
        box(&c, x, y - size, size, size * 3, color)
        box(&c, x - size, y, size * 3, size, color)
    }
    static func heart(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat, color: Color) {
        box(&c, x + 1, y, 3, 2, color)
        box(&c, x + 6, y, 3, 2, color)
        box(&c, x, y + 2, 10, 3, color)
        box(&c, x + 2, y + 5, 6, 2, color)
        box(&c, x + 4, y + 7, 2, 2, color)
    }

    static func draw(in c: inout GraphicsContext, time: Double, activity: String,
                     decor: String, level: Int, reaction: String) {
        // A quiet, warm room: horizontal bands keep every edge crisp at tiny sizes.
        box(&c, 0, 0, 296, 130, Color(red: 0.965, green: 0.940, blue: 0.875))
        box(&c, 0, 105, 296, 25, Color(red: 0.91, green: 0.87, blue: 0.78))
        box(&c, 0, 105, 296, 2, Color(red: 0.84, green: 0.79, blue: 0.69))
        box(&c, 0, 108, 296, 2, Color.white.opacity(0.30))
        box(&c, 19, 122, 50, 1, Color(red: 0.81, green: 0.76, blue: 0.67).opacity(0.48))
        box(&c, 88, 115, 29, 1, Color(red: 0.81, green: 0.76, blue: 0.67).opacity(0.38))
        box(&c, 245, 124, 31, 1, Color(red: 0.81, green: 0.76, blue: 0.67).opacity(0.48))
        // Recessed window, sunset and little distant tree silhouettes.
        box(&c, 23, 14, 130, 72, Color(red: 0.79, green: 0.82, blue: 0.69))
        box(&c, 20, 11, 130, 72, forest.opacity(0.72))
        box(&c, 22, 13, 126, 68, mint)
        box(&c, 27, 18, 116, 58, Color(red: 0.98, green: 0.80, blue: 0.65))
        box(&c, 27, 42, 116, 18, Color(red: 0.97, green: 0.84, blue: 0.69))
        box(&c, 27, 60, 116, 16, Color(red: 0.81, green: 0.82, blue: 0.67))
        box(&c, 121, 24, 9, 9, Color(red: 1, green: 0.94, blue: 0.76))
        box(&c, 119, 26, 13, 5, Color(red: 1, green: 0.94, blue: 0.76))
        box(&c, 42, 31, 19, 3, Color.white.opacity(0.40))
        box(&c, 38, 34, 31, 3, Color.white.opacity(0.40))
        box(&c, 94, 46, 19, 2, Color.white.opacity(0.32))
        for (x, h) in [(CGFloat(28), CGFloat(9)), (40, 15), (53, 11), (112, 12), (127, 19), (139, 8)] {
            box(&c, x, 76 - h, 8, h, mint.opacity(0.60))
            box(&c, x + 2, 72 - h, 4, 4, mint.opacity(0.60))
        }
        box(&c, 82, 16, 5, 62, mint)
        box(&c, 83, 18, 1, 58, Color.white.opacity(0.35))
        box(&c, 25, 49, 119, 4, mint)
        box(&c, 27, 49, 114, 1, Color.white.opacity(0.35))
        // Glass reflection on only two panes.
        polygon(&c, [(33, 19), (38, 19), (27, 36), (27, 29)], Color.white.opacity(0.20))
        polygon(&c, [(100, 53), (104, 53), (88, 74), (88, 68)], Color.white.opacity(0.15))
        box(&c, 17, 80, 139, 5, Color(red: 0.75, green: 0.65, blue: 0.50))
        box(&c, 17, 80, 139, 2, Color(red: 0.90, green: 0.82, blue: 0.66))
        box(&c, 24, 85, 125, 2, Color(red: 0.57, green: 0.49, blue: 0.39).opacity(0.16))
        plant(&c, x: 38, y: 65, variant: 0, growth: min(level, 5))
        plant(&c, x: 114, y: 66, variant: 1, growth: min(level, 5))
        // A tiny folded book and warm wall picture balance the scene.
        box(&c, 74, 74, 23, 6, Color(red: 0.72, green: 0.49, blue: 0.39))
        box(&c, 76, 74, 20, 3, cream.opacity(0.8))
        box(&c, 73, 72, 20, 2, sage)
        box(&c, 183, 14, 25, 24, Color(red: 0.76, green: 0.66, blue: 0.50))
        box(&c, 185, 16, 21, 20, Color(red: 1, green: 0.97, blue: 0.87))
        box(&c, 193, 21, 6, 7, blush.opacity(0.75))
        box(&c, 190, 24, 12, 4, blush.opacity(0.75))
        box(&c, 195, 28, 2, 5, forest.opacity(0.65))
        box(&c, 197, 29, 3, 2, forest.opacity(0.65))
        // Floor cushion gives the little cat a place in the room.
        oval(&c, 159, 109, 94, 11, ink.opacity(0.10))
        box(&c, 165, 108, 81, 7, Color(red: 0.64, green: 0.69, blue: 0.54))
        box(&c, 161, 109, 89, 3, Color(red: 0.64, green: 0.69, blue: 0.54))
        box(&c, 165, 106, 81, 5, Color(red: 0.79, green: 0.82, blue: 0.67))
        box(&c, 169, 106, 71, 1, cream.opacity(0.50))
        if decor == "rug" {
            box(&c, 140, 119, 119, 5, blush.opacity(0.44))
            for x in stride(from: 144, to: 259, by: 8) { box(&c, CGFloat(x), 117, 2, 9, blush.opacity(0.33)) }
        }
        if decor == "lamp" {
            box(&c, 260, 68, 3, 38, ink.opacity(0.62))
            box(&c, 251, 104, 21, 3, ink.opacity(0.62))
            polygon(&c, [(251, 48), (269, 48), (276, 68), (245, 68)], Color(red: 0.88, green: 0.70, blue: 0.41))
            box(&c, 248, 66, 25, 3, cream)
            oval(&c, 246, 73, 32, 28, cream.opacity(0.14))
        } else if decor == "plant" {
            plant(&c, x: 262, y: 95, variant: 2, growth: 5)
        } else {
            // Always one small seedling, upgraded into a taller plant above.
            plant(&c, x: 268, y: 99, variant: 0, growth: 1)
        }
        if decor == "stars" {
            for (x, y) in [(CGFloat(229), CGFloat(22)), (251, 34), (269, 17)] {
                box(&c, x + 1, 0, 1, y - 3, mint.opacity(0.60))
                star(&c, x: x, y: y, color: Color(red: 0.82, green: 0.63, blue: 0.35), size: 2)
            }
        }
        var catContext = c
        catContext.translateBy(x: 163, y: 48)
        cat(in: &catContext, time: time, activity: activity, reaction: reaction)
        // A few airy motes; deliberately low contrast, with slow motion.
        for i in 0..<3 {
            let phase = time * 0.35 + Double(i) * 2.2
            let x = CGFloat(151 + i * 43) + CGFloat(sin(phase)) * 3
            let y = CGFloat(29 + i * 16) + CGFloat(cos(phase * 0.7)) * 3
            box(&c, x.rounded(), y.rounded(), 2, 2, Color(red: 0.79, green: 0.65, blue: 0.40).opacity(0.35))
        }
        if activity == "explore" {
            let x = CGFloat(229 + sin(time * 0.8) * 7).rounded()
            let y = CGFloat(57 + cos(time * 0.8) * 5).rounded()
            star(&c, x: x, y: y, color: Color(red: 0.86, green: 0.61, blue: 0.28), size: 2)
            box(&c, x - 6, y + 6, 2, 2, blush.opacity(0.75))
        }
    }

    static func plant(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat, variant: Int, growth: Int) {
        let h: CGFloat = variant == 2 ? 26 : 13 + CGFloat(min(growth, 5))
        box(&c, x - 1, y - h, 2, h, forest)
        box(&c, x - 7, y - h + 5, 7, 3, forest)
        box(&c, x - 9, y - h + 3, 5, 3, sage)
        box(&c, x + 1, y - h + 9, 7, 3, forest)
        box(&c, x + 4, y - h + 7, 5, 3, sage)
        if variant == 1 {
            box(&c, x - 5, y - h - 4, 9, 9, blush)
            box(&c, x - 7, y - h - 2, 13, 5, blush)
            box(&c, x - 2, y - h - 1, 3, 3, cream)
        } else {
            box(&c, x - 4, y - h, 5, 4, forest)
            box(&c, x - 2, y - h - 3, 3, 4, sage)
        }
        box(&c, x - 9, y, 18, 4, terracotta)
        box(&c, x - 7, y + 4, 14, 9, terracotta)
        box(&c, x - 5, y + 13, 10, 2, terracotta)
        box(&c, x - 9, y, 18, 2, Color(red: 0.88, green: 0.59, blue: 0.41))
        box(&c, x - 6, y + 4, 2, 7, Color(red: 0.91, green: 0.65, blue: 0.46).opacity(0.65))
        box(&c, x + 5, y + 4, 2, 8, ink.opacity(0.13))
    }

    static func cat(in c: inout GraphicsContext, time: Double, activity: String, reaction: String) {
        oval(&c, 14, 61, 59, 7, ink.opacity(0.12))
        let nap = activity == "nap"
        let breathing: CGFloat = time == 0 ? 0 : (sin(time * 1.6) > 0.6 ? -1 : 0)
        var p = c
        p.translateBy(x: 0, y: breathing)
        if nap { sleepingCat(&p, time: time) } else { sittingCat(&p, time: time, happy: !reaction.isEmpty) }
        if !reaction.isEmpty {
            let rise = time == 0 ? 0 : CGFloat(sin(time * 2)) * 2
            if reaction == "feed" || reaction == "food" {
                star(&c, x: 9, y: 23 + rise, color: blush, size: 2)
                star(&c, x: 67, y: 12 - rise, color: lightGinger, size: 2)
            } else {
                heart(&c, x: 64, y: 6 + rise, color: blush)
                box(&c, 10, 19 - rise, 2, 2, blush.opacity(0.65))
            }
        }
    }

    static func sittingCat(_ c: inout GraphicsContext, time: Double, happy: Bool) {
        // Upright curled tail, silhouette, then warm fur.
        polygon(&c, [(57, 46), (64, 46), (64, 42), (68, 42), (68, 34), (66, 34), (66, 28), (70, 28), (70, 30), (74, 30), (74, 42), (72, 42), (72, 48), (68, 48), (68, 52), (57, 52)], ink)
        polygon(&c, [(58, 48), (66, 48), (66, 44), (70, 44), (70, 32), (72, 32), (72, 41), (70, 41), (70, 47), (66, 47), (66, 50), (58, 50)], lightGinger)
        box(&c, 70, 36, 2, 4, ginger)
        polygon(&c, [(24, 34), (55, 34), (55, 38), (59, 38), (59, 42), (61, 42), (61, 58), (57, 58), (57, 62), (22, 62), (22, 58), (18, 58), (18, 44), (20, 44), (20, 39), (24, 39)], ink)
        polygon(&c, [(25, 36), (53, 36), (53, 40), (57, 40), (57, 44), (59, 44), (59, 56), (55, 56), (55, 60), (24, 60), (24, 56), (20, 56), (20, 45), (22, 45), (22, 41), (25, 41)], lightGinger)
        box(&c, 21, 46, 7, 3, ginger)
        box(&c, 54, 45, 5, 3, ginger)
        box(&c, 53, 51, 6, 3, ginger)
        polygon(&c, [(33, 40), (46, 40), (46, 43), (50, 43), (50, 55), (47, 55), (47, 59), (31, 59), (31, 54), (29, 54), (29, 45), (33, 45)], cream)
        box(&c, 24, 55, 2, 5, ginger)
        box(&c, 53, 55, 2, 5, ginger)
        box(&c, 35, 57, 2, 4, ink)
        box(&c, 43, 57, 2, 4, ink)
        box(&c, 24, 59, 11, 1, cream)
        box(&c, 45, 59, 10, 1, cream)
        // Stepped ears make the small silhouette read instantly as a cat.
        polygon(&c, [(17, 6), (21, 6), (21, 8), (25, 8), (25, 11), (29, 11), (29, 14), (47, 14), (47, 11), (51, 11), (51, 8), (55, 8), (55, 6), (59, 6), (59, 25), (62, 25), (62, 36), (59, 36), (59, 40), (54, 40), (54, 43), (24, 43), (24, 41), (18, 41), (18, 38), (15, 38), (15, 28), (17, 28)], ink)
        polygon(&c, [(19, 8), (21, 8), (21, 11), (25, 11), (25, 14), (28, 14), (28, 16), (48, 16), (48, 14), (52, 14), (52, 11), (55, 11), (55, 9), (57, 9), (57, 27), (60, 27), (60, 35), (57, 35), (57, 38), (53, 38), (53, 41), (25, 41), (25, 39), (20, 39), (20, 36), (17, 36), (17, 29), (19, 29)], lightGinger)
        polygon(&c, [(21, 13), (23, 13), (23, 16), (26, 16), (26, 19), (21, 19)], blush)
        polygon(&c, [(53, 15), (55, 13), (55, 20), (50, 20), (50, 17), (53, 17)], blush)
        box(&c, 33, 17, 3, 7, ginger)
        box(&c, 39, 16, 3, 6, ginger)
        box(&c, 45, 17, 3, 7, ginger)
        box(&c, 17, 30, 7, 3, ginger)
        box(&c, 55, 29, 5, 3, ginger)
        box(&c, 53, 34, 7, 2, ginger)
        polygon(&c, [(27, 32), (34, 32), (34, 30), (45, 30), (45, 32), (52, 32), (52, 38), (48, 38), (48, 41), (29, 41), (29, 39), (24, 39), (24, 35), (27, 35)], cream)
        let blink = time != 0 && time.truncatingRemainder(dividingBy: 5.7) < 0.24
        if blink || happy {
            box(&c, 26, 28, 7, 2, ink)
            box(&c, 46, 28, 7, 2, ink)
            if happy {
                box(&c, 28, 26, 3, 2, ink)
                box(&c, 48, 26, 3, 2, ink)
            }
        } else {
            box(&c, 28, 26, 4, 6, ink)
            box(&c, 47, 26, 4, 6, ink)
            box(&c, 28, 26, 1, 2, cream)
            box(&c, 47, 26, 1, 2, cream)
        }
        box(&c, 37, 33, 5, 2, blush)
        box(&c, 39, 35, 2, 3, ink)
        box(&c, 35, 37, 4, 1, ink)
        box(&c, 41, 37, 4, 1, ink)
        box(&c, 24, 33, 4, 2, blush.opacity(0.58))
        box(&c, 51, 33, 4, 2, blush.opacity(0.58))
        box(&c, 10, 34, 10, 1, ink.opacity(0.65))
        box(&c, 12, 38, 8, 1, ink.opacity(0.65))
        box(&c, 59, 33, 9, 1, ink.opacity(0.65))
        box(&c, 58, 37, 8, 1, ink.opacity(0.65))
    }

    static func sleepingCat(_ c: inout GraphicsContext, time: Double) {
        polygon(&c, [(22, 32), (31, 32), (31, 28), (54, 28), (54, 30), (61, 30), (61, 34), (67, 34), (67, 40), (70, 40), (70, 54), (66, 54), (66, 60), (58, 60), (58, 63), (20, 63), (20, 60), (13, 60), (13, 55), (10, 55), (10, 43), (14, 43), (14, 37), (22, 37)], ink)
        polygon(&c, [(24, 34), (33, 34), (33, 30), (53, 30), (53, 32), (59, 32), (59, 36), (65, 36), (65, 42), (68, 42), (68, 53), (64, 53), (64, 58), (57, 58), (57, 61), (22, 61), (22, 58), (15, 58), (15, 53), (12, 53), (12, 44), (16, 44), (16, 39), (24, 39)], lightGinger)
        box(&c, 45, 31, 4, 8, ginger)
        box(&c, 53, 33, 4, 7, ginger)
        box(&c, 61, 39, 5, 4, ginger)
        // Curled tail wraps around the outside of the sleeping body.
        polygon(&c, [(61, 44), (66, 44), (66, 54), (60, 54), (60, 58), (37, 58), (37, 55), (56, 55), (56, 51), (61, 51)], ginger)
        box(&c, 38, 54, 18, 3, cream)
        polygon(&c, [(15, 26), (19, 26), (19, 28), (23, 28), (23, 32), (35, 32), (35, 29), (39, 29), (39, 27), (43, 27), (43, 40), (46, 40), (46, 51), (43, 51), (43, 55), (17, 55), (17, 53), (12, 53), (12, 48), (10, 48), (10, 40), (14, 40), (14, 31), (15, 31)], ink)
        polygon(&c, [(17, 28), (19, 30), (21, 30), (21, 34), (36, 34), (36, 32), (39, 32), (39, 30), (41, 30), (41, 42), (44, 42), (44, 50), (41, 50), (41, 53), (18, 53), (18, 51), (14, 51), (14, 46), (12, 46), (12, 42), (16, 42)], lightGinger)
        box(&c, 17, 32, 3, 5, blush)
        box(&c, 37, 33, 3, 4, blush)
        box(&c, 25, 35, 3, 5, ginger)
        box(&c, 31, 35, 3, 4, ginger)
        box(&c, 19, 45, 20, 8, cream)
        box(&c, 18, 43, 7, 2, ink)
        box(&c, 32, 43, 7, 2, ink)
        box(&c, 26, 46, 4, 2, blush)
        box(&c, 28, 48, 1, 3, ink)
        box(&c, 8, 48, 8, 1, ink.opacity(0.65))
        box(&c, 40, 48, 8, 1, ink.opacity(0.65))
        // Pixel 'z' shape drawn as a motif, rather than tiny font rendering.
        let drift: CGFloat = time == 0 ? 0 : CGFloat(sin(time * 0.7) * 2).rounded()
        box(&c, 52, 16 + drift, 7, 2, forest.opacity(0.65))
        box(&c, 55, 18 + drift, 2, 2, forest.opacity(0.65))
        box(&c, 53, 20 + drift, 2, 2, forest.opacity(0.65))
        box(&c, 52, 22 + drift, 7, 2, forest.opacity(0.65))
        box(&c, 63, 8 + drift, 5, 1, forest.opacity(0.40))
        box(&c, 66, 9 + drift, 1, 1, forest.opacity(0.40))
        box(&c, 65, 10 + drift, 1, 1, forest.opacity(0.40))
        box(&c, 64, 11 + drift, 1, 1, forest.opacity(0.40))
        box(&c, 63, 12 + drift, 5, 1, forest.opacity(0.40))
    }
}
