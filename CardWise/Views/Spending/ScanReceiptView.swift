import SwiftUI
import PhotosUI

struct ScanReceiptView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @EnvironmentObject private var subscription: SubscriptionManager

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var receiptData: ReceiptData?
    @State private var errorMessage: String?
    @State private var showCamera = false

    // Editable fields (pre-filled from OCR)
    @State private var merchant = ""
    @State private var amount = ""
    @State private var selectedCategory: SpendingCategory = .other
    @State private var selectedCardId: String?
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image selection
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous)
                                    .stroke(Theme.separator, lineWidth: 1)
                            )

                        if isProcessing {
                            ProgressView("Processing receipt...")
                                .foregroundStyle(Theme.textSecondary)
                        } else if let data = receiptData {
                            // Show confidence
                            HStack {
                                Image(systemName: data.confidence > 0.7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(data.confidence > 0.7 ? Theme.success : Theme.warning)
                                Text("Confidence: \(Int(data.confidence * 100))%")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    } else {
                        // No-image empty state + picker buttons
                        VStack(spacing: 16) {
                            AppEmptyState(
                                icon: "camera.viewfinder",
                                title: "Scan a Receipt",
                                message: "Choose a photo from your library or take a new one"
                            )

                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                            .buttonStyle(SoftButtonStyle())
                        }
                        .padding()
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
                        .softShadow()
                    }

                    // Editable form (shown after OCR or manual entry)
                    if selectedImage != nil || receiptData != nil {
                        VStack(spacing: 16) {
                            // Merchant
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Merchant")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("Store name", text: $merchant)
                                    .font(.app(.body))
                                    .padding(10)
                                    .background(Theme.surfaceAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
                            }

                            // Amount
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                                HStack {
                                    Text("$")
                                        .foregroundStyle(Theme.textSecondary)
                                    TextField("0.00", text: $amount)
                                        .keyboardType(.decimalPad)
                                        .font(.app(.body))
                                }
                                .padding(10)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
                            }

                            // Category
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)

                                Menu {
                                    ForEach(SpendingCategory.allCases) { category in
                                        Button {
                                            selectedCategory = category
                                        } label: {
                                            Label(category.displayName, systemImage: category.icon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Label(selectedCategory.displayName, systemImage: selectedCategory.icon)
                                            .font(.app(.body))
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(12)
                                    .background(Theme.surfaceAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
                                }
                            }

                            // Date
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .font(.app(.body))
                                .tint(Theme.accent)

                            // Card selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Used")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)

                                ForEach(cardViewModel.userCards) { userCard in
                                    if let card = cardViewModel.getCard(for: userCard) {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(hex: card.imageColor) ?? .gray)
                                                .frame(width: 32, height: 20)

                                            Text(userCard.nickname ?? card.name)
                                                .font(.app(.subheadline))
                                                .foregroundStyle(Theme.textPrimary)

                                            Spacer()

                                            if selectedCardId == card.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Theme.accent)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(selectedCardId == card.id ? Theme.accentSoft() : Theme.surfaceAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
                                        .onTapGesture {
                                            selectedCardId = card.id
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.app(.caption))
                            .foregroundStyle(Theme.danger)
                            .padding()
                    }

                    // Raw text (expandable)
                    if let data = receiptData, !data.rawText.isEmpty {
                        DisclosureGroup("Raw Text") {
                            Text(data.rawText)
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
                        .softShadow()
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSpending()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        await processImage(image)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage, selectedItem == nil {
                    Task {
                        await processImage(image)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !merchant.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        selectedCardId != nil
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let data = try await OCRService.shared.processReceipt(image: image)
            receiptData = data

            // Pre-fill form
            if let m = data.merchant {
                merchant = m
                // Auto-detect category
                if let detectedCategory = MerchantDatabase.suggestCategory(for: m) {
                    selectedCategory = detectedCategory
                }
            }
            if let a = data.amount {
                amount = String(format: "%.2f", a)
            }
            if let d = data.date {
                date = d
            }

            // Auto-select best card
            updateRecommendedCard()

        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func updateRecommendedCard() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: selectedCategory,
            amount: Double(amount) ?? 100,
            userCards: cardViewModel.userCards,
            allCards: cardViewModel.allCards
        )

        if let best = recommendations.first {
            selectedCardId = best.card.id
        }
    }

    private func saveSpending() {
        guard let cardId = selectedCardId,
              let amountValue = Double(amount) else { return }

        try? spendingViewModel.addSpending(
            amount: amountValue,
            merchant: merchant,
            category: selectedCategory,
            cardUsed: cardId,
            date: date,
            note: "Scanned from receipt",
            cardViewModel: cardViewModel,
            notifyCapAlerts: NotificationService.shared.shouldSendSpendingCapAlerts(isPro: subscription.isPro)
        )

        dismiss()
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ScanReceiptView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
