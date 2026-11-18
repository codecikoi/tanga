import SwiftUI

/// Флаг страны, иконка монеты или «слиток» металла — одного размера для всех строк.
struct CurrencyBadge: View {
    let code: String
    let currency: Currency?
    var width: CGFloat = 44
    var height: CGFloat = 30

    var body: some View {
        Group {
            switch currency?.kind ?? .fiat {
            case .fiat: fiat
            case .crypto: crypto
            case .metal: metal
            }
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder private var fiat: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        if let region = CurrencyRegion.region(for: code) {
            RemoteIcon(key: "flag-\(region.lowercased())", urls: [Endpoints.flag(region)]) {
                Text(CurrencyRegion.flagEmoji(region))
                    .font(.system(size: height * 0.95))
            }
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        } else {
            shape.fill(Theme.key)
                .overlay(
                    Text(code)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                )
        }
    }

    private var crypto: some View {
        RemoteIcon(key: "crypto-\(code.lowercased())", urls: Endpoints.cryptoIcons(code), contentMode: .fit) {
            Circle()
                .fill(currency?.colorHex.flatMap(Color.init(hexString:)) ?? Theme.accent)
                .overlay(
                    Text(String(code.prefix(4)))
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .padding(3)
                )
        }
        .frame(width: height, height: height)
    }

    private var metal: some View {
        let colors: [Color] = switch code {
        case "XAU": [Color(rgb: 0xFFE596), Color(rgb: 0xC98E1C)]
        case "XAG": [Color(rgb: 0xF5F7F9), Color(rgb: 0x98A1AB)]
        case "XPT": [Color(rgb: 0xE6EDF1), Color(rgb: 0x7B8994)]
        default: [Color(rgb: 0xF0E2D2), Color(rgb: 0x9A836D)]
        }
        let symbol = switch code {
        case "XAU": "Au"
        case "XAG": "Ag"
        case "XPT": "Pt"
        default: "Pd"
        }
        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(symbol)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(.black.opacity(0.65))
            )
            .frame(width: height, height: height)
    }
}

/// Картинка из сети с кэшем и заглушкой.
struct RemoteIcon<Placeholder: View>: View {
    let key: String
    let urls: [URL]
    let contentMode: ContentMode
    let placeholder: () -> Placeholder
    @State private var image: UIImage?

    init(key: String, urls: [URL], contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.key = key
        self.urls = urls
        self.contentMode = contentMode
        self.placeholder = placeholder
        _image = State(initialValue: ImageLoader.shared.cached(key))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: key) {
            image = ImageLoader.shared.cached(key)
            if image == nil {
                image = await ImageLoader.shared.image(key: key, urls: urls)
            }
        }
    }
}
