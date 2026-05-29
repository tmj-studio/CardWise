import SwiftUI

// MARK: - UserDefaults Keys

enum UserDefaultsKeys {
    static let userCards = "userCards"
    static let spendings = "spendings"
    static let searchHistory = "searchHistory"
    static let plaidLinkedAccounts = "plaidLinkedAccounts"
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count

        switch length {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }

    func toHex() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? Date()
    }

    var startOfQuarter: Date {
        let calendar = Calendar.current
        let quarter = (calendar.component(.month, from: self) - 1) / 3 + 1
        let startMonth = (quarter - 1) * 3 + 1
        var components = calendar.dateComponents([.year], from: self)
        components.month = startMonth
        components.day = 1
        return calendar.date(from: components) ?? Date()
    }

    var currentQuarter: Int {
        let month = Calendar.current.component(.month, from: self)
        return ((month - 1) / 3) + 1
    }
}

extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self / 100)) ?? "\(self)%"
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Card Image Cache

final class CardImageCache {
    static let shared = CardImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Card Image Loader

@MainActor
final class CardImageLoader: ObservableObject {
    @Published var uiImage: UIImage?
    @Published var isLoading = false
    private var urlString: String?

    func load(from urlString: String) {
        guard self.urlString != urlString else { return }
        self.urlString = urlString

        if let cached = CardImageCache.shared.image(for: urlString) {
            self.uiImage = cached
            return
        }

        guard let url = URL(string: urlString) else { return }
        isLoading = true

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let image = UIImage(data: data) {
                    CardImageCache.shared.setImage(image, for: urlString)
                    self.uiImage = image
                }
            } catch {
                // Fall through to fallback color
            }
            self.isLoading = false
        }
    }
}

// MARK: - Card Image View

struct CardImageView: View {
    let imageURL: String?
    let fallbackColor: String
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    @StateObject private var loader = CardImageLoader()

    var body: some View {
        Group {
            if let uiImage = loader.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if loader.isLoading {
                colorFallback
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            } else {
                colorFallback
            }
        }
        .onAppear {
            if let urlString = imageURL {
                loader.load(from: urlString)
            }
        }
    }

    private var colorFallback: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: fallbackColor) ?? .gray)
            .frame(width: width, height: height)
    }
}
