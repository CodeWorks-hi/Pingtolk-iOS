import Foundation

struct Message: Identifiable, Codable {
    var id: UUID = UUID()
    var sender: String
    var text: String
    var timestamp: Double
    var isDateSeparator: Bool?
    var isImage: Bool = false
    var profileImageUrl: String? = nil

    // ✅ Firestore 디코딩을 위해 기본 생성자가 있어야 함
    init(id: UUID = UUID(), sender: String, text: String, timestamp: Double, isDateSeparator: Bool? = false, isImage: Bool = false, profileImageUrl: String? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isDateSeparator = isDateSeparator
        self.isImage = isImage
        self.profileImageUrl = profileImageUrl
    }

    // ✅ 날짜 구분용 메시지 생성자
    static func createDateSeparator(timestamp: Double) -> Message {
        return Message(id: UUID(), sender: "", text: "", timestamp: timestamp, isDateSeparator: true)
    }
}
