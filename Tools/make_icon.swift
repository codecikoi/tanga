// Генератор иконки Tanga.
//
//   swift Tools/make_icon.swift Tanga/Assets.xcassets
//
// Рисует три варианта 1024×1024 (обычный, тёмный, tinted) и логотип для настроек.
// Знак: строчная «t.» скруглёнными штрихами — первая буква названия и точка,
// как в конце суммы. Обычный вариант белый на ярко-оранжевом, тёмный оранжевый
// на почти чёрном, tinted белый на чёрном (iOS сам перекрашивает его в оттенок).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255,
        1,
    ])!
}

enum Variant: String, CaseIterable {
    case light, dark, tinted

    var background: CGColor {
        switch self {
        case .light: rgb(0xFF5A1F)
        case .dark: rgb(0x17181C)
        case .tinted: rgb(0x000000)
        }
    }

    var mark: CGColor {
        switch self {
        case .light, .tinted: rgb(0xFFFFFF)
        case .dark: rgb(0xFF6A2E)
        }
    }
}

/// Знак «t.»: ножка с закруглённым хвостиком вправо, перекладина и точка.
func mark() -> CGPath {
    let width: CGFloat = 132

    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: 0, y: 560))
    stem.addLine(to: CGPoint(x: 0, y: 150))
    stem.addArc(center: CGPoint(x: 170, y: 150), radius: 170, startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
    stem.addLine(to: CGPoint(x: 222, y: -20))

    let bar = CGMutablePath()
    bar.move(to: CGPoint(x: -150, y: 372))
    bar.addLine(to: CGPoint(x: 196, y: 372))

    let shape = CGMutablePath()
    shape.addPath(stem.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    shape.addPath(bar.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    shape.addEllipse(in: CGRect(x: 410 - 66, y: -20 - 66, width: 132, height: 132))

    // По центру холста, с полями: знак занимает ~58% ширины иконки.
    let box = shape.boundingBoxOfPath
    var fit = CGAffineTransform(translationX: 512, y: 512)
        .scaledBy(x: 0.84, y: 0.84)
        .translatedBy(x: -box.midX, y: -box.midY)
    return shape.copy(using: &fit)!
}

func render(_ variant: Variant, size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    ctx.setShouldAntialias(true)

    ctx.setFillColor(variant.background)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    ctx.addPath(mark())
    ctx.setFillColor(variant.mark)
    ctx.fillPath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Не удалось записать \(url.path)") }
    print("✓ \(url.path)")
}

let assets = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Tanga/Assets.xcassets")
let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
for variant in Variant.allCases {
    writePNG(render(variant, size: 1024), to: iconSet.appendingPathComponent("icon-\(variant.rawValue).png"))
}
writePNG(render(.light, size: 240), to: assets.appendingPathComponent("Logo.imageset/logo.png"))
