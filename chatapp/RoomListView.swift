import SwiftUI
import FirebaseFirestore
import UIKit

struct Room: Identifiable {
    let id: String
    let createdBy: String
    let title: String
}

struct RoomListView: View {
    let nickname: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @State private var selectedRoomID: String?
    @State private var navigateToChat = false
    @State private var rooms: [Room] = []
    @State private var filteredRooms: [Room] = []
    @State private var favoriteCodes: Set<String> = []
    @State private var showFavoritesOnly: Bool = false
    @State private var showEnteredOnly: Bool = false
    @State private var isLoading = true
    @State private var shareSheetIsPresented = false
    @State private var showNewRoomSheet = false
    @State private var newRoomTitle = ""
    @State private var newRoomPassword = ""
    @State private var showBackConfirmation = false
    @AppStorage("enteredRooms") var enteredRooms: String = "" // comma-separated
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Toggle("즐겨찾기만 보기", isOn: $showFavoritesOnly)
                    Spacer()
                    Toggle("입장한 방만 보기", isOn: $showEnteredOnly)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                List(filteredRooms) { room in
                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.title)
                                        .font(.headline)
                                    Text("생성자: \(room.createdBy)")
                                        .font(.subheadline)
                                }
                                Spacer()
                            }

                            HStack {
                                Spacer()
                                Button("입장하기") {
                                    if enteredRooms.contains(room.id) {
                                        goToChatRoom(room.id)
                                    } else {
                                        promptPasswordAndEnter(room)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 8)

                        Button(action: {
                            toggleFavorite(for: room.id)
                        }) {
                            Image(systemName: favoriteCodes.contains(room.id) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .padding(.top, 4)
                                .padding(.trailing, 4)
                        }
                    }
                }
                
                NavigationLink(
                    isActive: $navigateToChat,
                    destination: {
                        Group {
                            if let id = selectedRoomID {
                                ChatView(nickname: nickname, familyCode: id)
                            } else {
                                EmptyView()
                            }
                        }
                    },
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("방 목록")
            .onAppear(perform: loadRooms)
            .onChange(of: showFavoritesOnly) { _, _ in applyFilterAndSort() }
            .onChange(of: showEnteredOnly) { _, _ in applyFilterAndSort() }
            .sheet(isPresented: $showNewRoomSheet) {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("새 방 만들기")
                            .font(.headline)
                            .padding(.top, 20)
                        TextField("방 제목을 입력하세요", text: $newRoomTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        SecureField("비밀번호 (4자리 숫자)", text: $newRoomPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .padding(.horizontal)
                        HStack {
                            Button("취소") { showNewRoomSheet = false }
                            Spacer()
                            Button("생성") {
                                createRoom()
                                showNewRoomSheet = false
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding()
                }
            }
            .confirmationDialog("로그아웃", isPresented: $showBackConfirmation, titleVisibility: .visible) {
                Button("이동", role: .destructive) {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("로그아웃하시겠습니까?")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showBackConfirmation = true
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("방 만들기") {
                        showNewRoomSheet = true
                    }
                }
            }
        }
    }

    func loadRooms() {
        let db = Firestore.firestore()
        db.collection("users").document(nickname).collection("favorites").getDocuments { favSnap, _ in
            favoriteCodes = Set(favSnap?.documents.map { $0.documentID } ?? [])
            
            db.collection("rooms").getDocuments { snapshot, error in
                isLoading = false
                guard let docs = snapshot?.documents else { return }
                self.rooms = docs.compactMap { doc in
                    let data = doc.data()
                    guard let createdBy = data["created_by"] as? String,
                          let title = data["title"] as? String else { return nil }
                    return Room(id: doc.documentID, createdBy: createdBy, title: title)
                }
                applyFilterAndSort()
            }
        }
    }
    
    func applyFilterAndSort() {
        filteredRooms = rooms.filter { room in
            let isFavorite = favoriteCodes.contains(room.id)
            let isEntered = enteredRooms.contains(room.id)
            return (!showFavoritesOnly || isFavorite) && (!showEnteredOnly || isEntered)
        }
    }
    
    func goToChatRoom(_ code: String) {
        if !enteredRooms.contains(code) {
            enteredRooms += enteredRooms.isEmpty ? code : ",\(code)"
        }
        selectedRoomID = nil
        navigateToChat = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedRoomID = code
            navigateToChat = true
        }
    }
    
    func promptPasswordAndEnter(_ room: Room) {
        let db = Firestore.firestore()
        db.collection("rooms").document(room.id).getDocument { doc, _ in
            guard let doc = doc, let correctPassword = doc.data()?["password"] as? String else { return }

            let alert = UIAlertController(title: "비밀번호", message: "입장 비밀번호를 입력하세요", preferredStyle: .alert)
            alert.addTextField { $0.isSecureTextEntry = true }
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "입장", style: .default) { _ in
                let input = alert.textFields?.first?.text ?? ""
                if input == correctPassword {
                    goToChatRoom(room.id)
                } else {
                    let errorAlert = UIAlertController(title: "오류", message: "비밀번호가 틀렸습니다.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "확인", style: .default))
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(errorAlert, animated: true)
                    }
                }
            })

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(alert, animated: true)
            }
        }
    }
    
    func createRoom() {
        guard !newRoomTitle.isEmpty, newRoomPassword.count == 4 else { return }
        let db = Firestore.firestore()
        db.collection("rooms").document(newRoomTitle).setData([
            "title": newRoomTitle,
            "created_by": nickname,
            "password": newRoomPassword,
            "created_at": Date()
        ]) { _ in loadRooms() }
    }

    func toggleFavorite(for roomID: String) {
        let db = Firestore.firestore()
        let favRef = db.collection("users").document(nickname).collection("favorites").document(roomID)
        if favoriteCodes.contains(roomID) {
            favRef.delete()
            favoriteCodes.remove(roomID)
        } else {
            favRef.setData([:]) { _ in }
            favoriteCodes.insert(roomID)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
