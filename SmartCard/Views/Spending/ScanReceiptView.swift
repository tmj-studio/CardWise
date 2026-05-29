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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )

                        if isProcessing {
                            ProgressView("Processing receipt...")
                        } else if let data = receiptData {
                            // Show confidence
                            HStack {
                                Image(systemName: data.confidence > 0.7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(data.confidence > 0.7 ? .green : .orange)
                                Text("Confidence: \(Int(data.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        // Image picker buttons
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Editable form (shown after OCR or manual entry)
                    if selectedImage != nil || receiptData != nil {
                        VStack(spacing: 16) {
                            // Merchant
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Merchant")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Store name", text: $merchant)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Amount
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text("$")
                                    TextField("0.00", text: $amount)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            // Category
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

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
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }

                            // Date
                            DatePicker("Date", selection: $date, displayedComponents: .date)

                            // Card selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Used")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(cardViewModel.userCards) { userCard in
                                    if let card = cardViewModel.getCard(for: userCard) {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(hex: card.imageColor) ?? .gray)
                                                .frame(width: 32, height: 20)

                                            Text(userCard.nickname ?? card.name)
                                                .font(.subheadline)

                                            Spacer()

                                            if selectedCardId == card.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(selectedCardId == card.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }

                    // Raw text (expandable)
                    if let data = receiptData, !data.rawText.isEmpty {
                        DisclosureGroup("Raw Text") {
                            Text(data.rawText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
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
