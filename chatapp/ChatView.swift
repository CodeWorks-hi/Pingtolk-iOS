import SwiftUI
import Firebase
import FirebaseStorage
import Foundation

struct ChatView: View {
    let nickname: String
    let familyCode: String
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var lastDateString = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    private var messageListView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        if message.isDateSeparator == true {
                            Text(formattedDate(from: message.timestamp))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 4)
                        } else {
                            ChatBubbleView(message: message, isCurrentUser: message.sender == nickname)
                        }
                    }
                }
                .onChange(of: messages.count) { _ in
                    if let lastIndex = messages.indices.last {
                        withAnimation {
                            scrollProxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var messageInputView: some View {
        HStack {
            Button(action: {
                showImagePicker = true
            }) {
                Image(systemName: "photo")
            }
            TextField("메시지 입력", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
            }
        }
        .padding()
    }

    var body: some View {
        VStack {
            messageListView
            messageInputView
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(familyCode)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("Ping Room")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let message = "\(nickname)님이 PingTalk에 참여 중입니다.\n\n앱 설치하기: https://play.google.com/store/apps/details?id=com.example.pingtolk"
                    let av = UIActivityViewController(activityItems: [message], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(av, animated: true)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
                .onDisappear {
                    if let image = selectedImage {
                        uploadImage(image)
                    }
                }
        }
        .onAppear {
            messages = []
            listenForMessages()

            let db = Firestore.firestore()
            let userDoc = db.collection("rooms").document(familyCode).collection("enteredUsers").document(nickname)

            userDoc.getDocument { document, _ in
                if document?.exists != true {
                    let welcomeMessage = Message(sender: "SYSTEM", text: "\(nickname)님이 입장하셨습니다", timestamp: Date().timeIntervalSince1970 * 1000)
                    db.collection("rooms").document(familyCode).collection("messages").addDocument(data: [
                        "sender": welcomeMessage.sender,
                        "text": welcomeMessage.text,
                        "timestamp": welcomeMessage.timestamp,
                        "isDateSeparator": welcomeMessage.isDateSeparator ?? false
                    ])
                    userDoc.setData(["entered": true])
                }
            }
        }
        .onChange(of: familyCode) { _ in
            messages = []
            listenForMessages()
        }
    }

    private func listenForMessages() {
        let db = Firestore.firestore()
        db.collection("rooms").document(familyCode).collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                var newMessages: [Message] = []
                var lastDate = ""
                for doc in docs {
                    let data = doc.data()
                    guard let sender = data["sender"] as? String,
                          let timestamp = data["timestamp"] as? TimeInterval else { continue }
                    let imageUrl = data["imageUrl"] as? String ?? ""
                    let text = data["text"] as? String ?? ""
                    let content = imageUrl.isEmpty ? text : imageUrl
                    let isDateSeparator = data["isDateSeparator"] as? Bool ?? false
                    let isImage = data["isImage"] as? Bool ?? (imageUrl.hasSuffix(".jpg") || imageUrl.hasSuffix(".png"))
                    let profileImageUrl = data["profileImageUrl"] as? String
                    let message = Message(sender: sender, text: content, timestamp: timestamp, isDateSeparator: isDateSeparator, isImage: isImage, profileImageUrl: profileImageUrl)

                    let dateStr = formattedDate(from: timestamp)
                    if dateStr != lastDate {
                        newMessages.append(Message(sender: "", text: "", timestamp: timestamp, isDateSeparator: true))
                        lastDate = dateStr
                    }

                    newMessages.append(message)
                }
                messages = newMessages.filter { !$0.text.isEmpty || $0.isImage }.sorted { $0.timestamp < $1.timestamp }
            }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let db = Firestore.firestore()
        let timestamp = Date().timeIntervalSince1970 * 1000 + Double.random(in: 0...0.999)
        let message = Message(sender: nickname, text: messageText, timestamp: timestamp)
        db.collection("rooms").document(familyCode).collection("messages").addDocument(data: [
            "sender": message.sender,
            "text": message.text,
            "timestamp": message.timestamp,
            "isDateSeparator": message.isDateSeparator ?? false
        ])
        messageText = ""
    }

    private func uploadImage(_ image: UIImage) {
        let resized = resizedImage(image)
        guard let data = resized.jpegData(compressionQuality: 0.5) else { return }
        let storageRef = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
        let timestamp = Date().timeIntervalSince1970 * 1000 + Double.random(in: 0...0.999)

        storageRef.putData(data, metadata: nil as StorageMetadata?) { _, error in
            guard error == nil else { return }
            storageRef.downloadURL { url, _ in
                guard let url = url else { return }
                let message = Message(sender: nickname, text: url.absoluteString, timestamp: timestamp, isImage: true)
                Firestore.firestore().collection("rooms").document(familyCode).collection("messages").addDocument(data: [
                    "sender": message.sender,
                    "imageUrl": message.text,
                    "timestamp": timestamp,
                    "isDateSeparator": message.isDateSeparator ?? false,
                    "isImage": true
                ])
            }
        }
    }

    private func resizedImage(_ image: UIImage, maxSize: CGFloat = 800) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        let newWidth = min(image.size.width, maxSize)
        let newHeight = newWidth / aspectRatio
        let size = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.7)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }

    private func formattedDate(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }
}
