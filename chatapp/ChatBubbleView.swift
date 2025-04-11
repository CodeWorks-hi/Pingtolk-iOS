//
//  ChatBubbleView.swift
//  chatapp
//
//  Created by ENZO on 4/9/25.
//

import SwiftUI

struct ChatBubbleView: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        if message.isDateSeparator == true {
            Text(formattedDate(from: message.timestamp))
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        } else {
            HStack {
                if isCurrentUser {
                    Spacer()
                } else {
                    // 프로필 이미지
                    if message.sender == "SYSTEM" {
                        // System default image
                        Image("ic_chat_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .padding(.trailing, 8)
                    } else {
                        AsyncImage(url: URL(string: message.profileImageUrl ?? "")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 36, height: 36)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            case .failure:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 36, height: 36)
                        .padding(.trailing, 8)
                    }
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    if !isCurrentUser {
                        Text(message.sender)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if message.isImage, let url = URL(string: message.text) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: 200, maxHeight: 200)
                                    .clipped()
                                    .cornerRadius(16)
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: 200, height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Text(message.text)
                            .padding(12)
                            .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(isCurrentUser ? .white : .black)
                            .cornerRadius(16)
                    }
                    Text(formattedTime(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                if !isCurrentUser {
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
    }

    func formattedTime(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000) // Android와 통일
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        return formatter.string(from: date)
    }

    func formattedDate(from timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일"
        return formatter.string(from: date)
    }
}
