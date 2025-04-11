import SwiftUI
import Firebase
import FirebaseFirestore

struct ContentView: View {
    @AppStorage("nickname") var nickname = ""
    @AppStorage("familyCode") var familyCode = ""
    @AppStorage("password") var password = ""

    @State private var goToChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                
                
                VStack(spacing: 8) {
                    Image("ic_chat_logo")
                        .resizable()
                        .frame(width: 147, height: 131)

                    Text("가족과 함께하는 프라이빗 채팅")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                VStack(spacing: 12) {
                    TextField("닉네임", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("비밀번호", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(spacing: 12) {
                    Button(action: joinRoom) {
                        Text("입장하기")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $goToChat) {
                RoomListView(nickname: nickname)
            }
        }
    }

    func joinRoom() {
        guard !nickname.isEmpty, !password.isEmpty else { return }

        familyCode = "\(nickname)_room"
        goToChat = true
    }
}
