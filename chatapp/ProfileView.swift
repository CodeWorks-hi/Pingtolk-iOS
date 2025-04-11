//
//  ProfileView.swift
//  chatapp
//
//  Created by ENZO on 4/9/25.
//

import SwiftUI
import PhotosUI
import UserNotifications
import FirebaseStorage
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("nickname") private var storedNickname: String = ""
    @AppStorage("profile_image_url") private var storedProfileImageUrl: String = ""
    @State private var nickname = ""
    @State private var isEditingNickname = false
    @State private var isDarkMode = false
    @State private var isNotificationOn = true
    @State private var selectedImageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    
    var profileImage: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(width: 120, height: 120)
            } else {
                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                } else if !storedProfileImageUrl.isEmpty {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        .onAppear {
                            isLoading = true
                            if let url = URL(string: storedProfileImageUrl) {
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    if let data = data {
                                        DispatchQueue.main.async {
                                            selectedImageData = data
                                            isLoading = false
                                        }
                                    }
                                }.resume()
                            }
                        }
                } else {
                    Image("ic_chat_logo") // 기본 이미지
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    profileImage
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            uploadToFirebase(data)
                        }
                    }
                }

                HStack {
                    if isEditingNickname {
                        TextField("닉네임", text: $nickname)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(nickname)
                            .font(.title2)
                    }
                    Button(isEditingNickname ? "완료" : "수정") {
                        isEditingNickname.toggle()
                    }
                }

                Toggle("다크모드", isOn: $isDarkMode)
                    .onChange(of: isDarkMode) { value in
                        let mode: UIUserInterfaceStyle = value ? .dark : .light
                        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = mode
                    }

                Toggle("알림 받기", isOn: $isNotificationOn)
                    .onChange(of: isNotificationOn) { value in
                        if value {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                                if granted {
                                    let content = UNMutableNotificationContent()
                                    content.title = "알림 설정 완료"
                                    content.body = "이제 알림을 받을 수 있습니다"

                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                                    UNUserNotificationCenter.current().add(request)
                                } else {
                                    print("알림 권한 거부됨")
                                }
                            }
                        } else {
                            print("알림이 꺼졌습니다")
                        }
                    }

                Divider()

                VStack(spacing: 12) {
                    Button("개인정보 보호") {
                        print("개인정보 보호 클릭됨")
                    }
                    Button("도움말") {
                        print("도움말 클릭됨")
                    }
                }

                Spacer()

                Button("저장") {
                    storedNickname = nickname
                    UserDefaults.standard.set(nickname, forKey: "nickname")
                    // 닉네임 저장 완료 메시지 표시 후 이전 화면으로 돌아가기
                    let alert = UIAlertController(title: "저장됨", message: "프로필이 저장되었습니다", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                        dismiss()
                    })
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(alert, animated: true)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("프로필")
            .onAppear {
                nickname = storedNickname.isEmpty ? UserDefaults.standard.string(forKey: "nickname") ?? "사용자" : storedNickname

                if let url = URL(string: storedProfileImageUrl) {
                    isLoading = true
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data {
                            DispatchQueue.main.async {
                                selectedImageData = data
                                isLoading = false
                            }
                        }
                    }.resume()
                }
            }
        }
    }
    
    func uploadToFirebase(_ data: Data) {
        let storage = Storage.storage()
        let ref = storage.reference().child("profile_images/\(UUID().uuidString).jpg")

        ref.putData(data, metadata: nil) { metadata, error in
            guard error == nil else {
                print("이미지 업로드 실패: \(error!.localizedDescription)")
                return
            }
            ref.downloadURL { url, error in
                if let url = url {
                    print("업로드 완료, URL: \(url.absoluteString)")
                    storedProfileImageUrl = url.absoluteString
                    
                    // Firestore에 URL 저장
                    let db = Firestore.firestore()
                    db.collection("users").document(storedNickname).setData(["profile_image_url": url.absoluteString], merge: true) { error in
                        if let error = error {
                            print("Firestore에 URL 저장 실패: \(error.localizedDescription)")
                        } else {
                            print("Firestore에 URL 저장 성공")
                        }
                    }
                }
            }
        }
    }
}
