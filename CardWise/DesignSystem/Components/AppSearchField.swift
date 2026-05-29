import SwiftUI

/// Tappable search bar that opens a sheet (Home dashboard).
struct SearchBarButton: View {
    let placeholder: String
    var text: String = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                Spacer()
                Image(systemName: "creditcard.fill").foregroundStyle(Theme.accent)
            }
            .font(.app(.body))
            .padding(14)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
            .softShadow()
        }
        .buttonStyle(.plain)
    }
}

/// Editable search field (Recommend / QuickRecommend).
struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .focused(focused)
                .autocorrectionDisabled()
                .font(.app(.body))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
        .softShadow()
    }
}
