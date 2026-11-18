// Генератор иконки Sarrof.
//
//   swift Tools/make_icon.swift Sarrof/Assets.xcassets
//
// Рисует три варианта 1024×1024 (обычный, тёмный, tinted) и логотип для настроек.
// Мотив: две стрелки обмена по кругу + восьмиконечная звезда узбекского орнамента.
// Цвета — бирюза самаркандских изразцов, лазурит и золото.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255,
        alpha,
    ])!
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
}

enum Variant: String, CaseIterable { case light, dark, tinted }

struct Palette {
    var background: [CGColor]
    var glow: CGColor
    var ornament: CGColor
    var upper: [CGColor]
    var lower: [CGColor]
    var star: [CGColor]
    var shadow: CGColor
}

func palette(_ variant: Variant) -> Palette {
    switch variant {
    case .light:
        Palette(
            background: [rgb(0x1CC8D4), rgb(0x0F84B8), rgb(0x0A2A6C)],
            glow: rgb(0xFFFFFF, 0.22),
            ornament: rgb(0xFFFFFF, 0.08),
            upper: [rgb(0xFFE6A3), rgb(0xF3A833)],
            lower: [rgb(0xFFFFFF), rgb(0xBFF1F6)],
            star: [rgb(0xFFEAB0), rgb(0xF0A42F)],
            shadow: rgb(0x020B2B, 0.45)
        )
    case .dark:
        Palette(
            background: [rgb(0x12364A), rgb(0x0B1B36), rgb(0x050914)],
            glow: rgb(0x22C3D6, 0.20),
            ornament: rgb(0xFFFFFF, 0.05),
            upper: [rgb(0xFFE29A), rgb(0xF2A42C)],
            lower: [rgb(0xE8FDFF), rgb(0x6FD7E4)],
            star: [rgb(0xFFE7A8), rgb(0xEFA02B)],
            shadow: rgb(0x000000, 0.6)
        )
    case .tinted:
        Palette(
            background: [rgb(0x2B2B2B), rgb(0x0B0B0B)],
            glow: rgb(0xFFFFFF, 0.06),
            ornament: rgb(0xFFFFFF, 0.05),
            upper: [rgb(0xFFFFFF), rgb(0xE2E2E2)],
            lower: [rgb(0xB8B8B8), rgb(0x8A8A8A)],
            star: [rgb(0xFFFFFF), rgb(0xD8D8D8)],
            shadow: rgb(0x000000, 0.5)
        )
    }
}

func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

/// Восьмиконечная звезда из двух квадратов (как в гирихе).
func octagram(center: CGPoint, radius: CGFloat, rotation: CGFloat = 0) -> CGPath {
    let inner = radius * cos(.pi / 4) / cos(.pi / 8)
    let path = CGMutablePath()
    for index in 0..<16 {
        let angle = radians(CGFloat(index) * 22.5 + 90 + rotation)
        let r = index.isMultiple(of: 2) ? radius : inner
        let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        index == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func fill(_ ctx: CGContext, _ path: CGPath, colors: [CGColor], from: CGPoint, to: CGPoint, evenOdd: Bool = false) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip(using: evenOdd ? .evenOdd : .winding)
    ctx.drawLinearGradient(gradient(colors), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

/// Дуга по часовой стрелке от `start` до `end` (градусы) со стрелкой на конце.
func arrow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat,
           start: CGFloat, end: CGFloat, colors: [CGColor], from: CGPoint, to: CGPoint) {
    let arc = CGMutablePath()
    arc.addArc(center: center, radius: radius, startAngle: radians(start), endAngle: radians(end), clockwise: true)
    let body = arc.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)

    let angle = radians(end)
    let tip = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    let normal = CGPoint(x: cos(angle), y: sin(angle))
    let tangent = CGPoint(x: sin(angle), y: -cos(angle))
    let halfWidth = width * 1.1
    let length = width * 1.5

    let head = CGMutablePath()
    head.move(to: CGPoint(x: tip.x + normal.x * halfWidth, y: tip.y + normal.y * halfWidth))
    head.addQuadCurve(
        to: CGPoint(x: tip.x + tangent.x * length, y: tip.y + tangent.y * length),
        control: CGPoint(x: tip.x + normal.x * halfWidth * 0.55 + tangent.x * length * 0.45,
                         y: tip.y + normal.y * halfWidth * 0.55 + tangent.y * length * 0.45)
    )
    head.addQuadCurve(
        to: CGPoint(x: tip.x - normal.x * halfWidth, y: tip.y - normal.y * halfWidth),
        control: CGPoint(x: tip.x - normal.x * halfWidth * 0.55 + tangent.x * length * 0.45,
                         y: tip.y - normal.y * halfWidth * 0.55 + tangent.y * length * 0.45)
    )
    head.closeSubpath()

    fill(ctx, body, colors: colors, from: from, to: to)
    fill(ctx, head, colors: colors, from: from, to: to)
}

func render(_ variant: Variant, size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let p = palette(variant)
    let center = CGPoint(x: 512, y: 512)

    // Фон: диагональный градиент и мягкий блик сверху слева.
    ctx.drawLinearGradient(gradient(p.background), start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    ctx.drawRadialGradient(gradient([p.glow, p.glow.copy(alpha: 0)!]),
                           startCenter: CGPoint(x: 220, y: 880), startRadius: 0,
                           endCenter: CGPoint(x: 220, y: 880), endRadius: 720, options: [])

    // Орнамент: большая звезда и кольцо едва заметным контуром.
    ctx.saveGState()
    ctx.setStrokeColor(p.ornament)
    ctx.setLineWidth(9)
    ctx.addPath(octagram(center: center, radius: 470))
    ctx.strokePath()
    ctx.addEllipse(in: CGRect(x: 512 - 404, y: 512 - 404, width: 808, height: 808))
    ctx.strokePath()
    ctx.restoreGState()

    // Знак: две стрелки обмена и звезда в центре, с общей тенью.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 44, color: p.shadow)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)

    let radius: CGFloat = 292
    let width: CGFloat = 94
    arrow(ctx, center: center, radius: radius, width: width, start: 166, end: 44,
          colors: p.upper, from: CGPoint(x: 200, y: 820), to: CGPoint(x: 820, y: 560))
    arrow(ctx, center: center, radius: radius, width: width, start: -14, end: 224,
          colors: p.lower, from: CGPoint(x: 820, y: 200), to: CGPoint(x: 200, y: 460))

    // Звезда-«медальон»: сплошная, с узким звёздным контуром внутри.
    let star = CGMutablePath()
    star.addPath(octagram(center: center, radius: 132, rotation: 22.5))
    star.addPath(octagram(center: center, radius: 84, rotation: 22.5))
    star.addPath(octagram(center: center, radius: 66, rotation: 22.5))
    fill(ctx, star, colors: p.star, from: CGPoint(x: 512, y: 650), to: CGPoint(x: 512, y: 374), evenOdd: true)

    ctx.endTransparencyLayer()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Не удалось записать \(url.path)") }
    print("✓ \(url.path)")
}

let assets = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Sarrof/Assets.xcassets")
let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
for variant in Variant.allCases {
    writePNG(render(variant, size: 1024), to: iconSet.appendingPathComponent("icon-\(variant.rawValue).png"))
}
writePNG(render(.light, size: 240), to: assets.appendingPathComponent("Logo.imageset/logo.png"))
