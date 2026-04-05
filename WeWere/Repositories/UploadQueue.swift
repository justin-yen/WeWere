import SwiftData
import Foundation

@Model
class QueuedUpload {
    var id: UUID
    var eventId: UUID
    var imageData: Data
    var status: String  // "pending", "uploading", "completed", "failed"
    var retryCount: Int
    var createdAt: Date

    init(eventId: UUID, imageData: Data) {
        self.id = UUID()
        self.eventId = eventId
        self.imageData = imageData
        self.status = "pending"
        self.retryCount = 0
        self.createdAt = Date()
    }
}

@MainActor
class UploadQueueManager: ObservableObject {
    @Published var pendingCount: Int = 0
    private var modelContext: ModelContext?
    private let photoService = PhotoService()

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func enqueue(eventId: UUID, imageData: Data) throws {
        guard let context = modelContext else { return }
        let upload = QueuedUpload(eventId: eventId, imageData: imageData)
        context.insert(upload)
        try context.save()
        pendingCount += 1
        Task { await processQueue() }
    }

    func processQueue() async {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<QueuedUpload>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "failed" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let uploads = try? context.fetch(descriptor) else { return }

        for upload in uploads where upload.retryCount < 5 {
            upload.status = "uploading"
            do {
                _ = try await photoService.uploadPhoto(eventId: upload.eventId, imageData: upload.imageData)
                upload.status = "completed"
                pendingCount = max(0, pendingCount - 1)
            } catch {
                upload.retryCount += 1
                upload.status = upload.retryCount >= 5 ? "failed" : "pending"
            }
            try? context.save()
        }
    }
}
