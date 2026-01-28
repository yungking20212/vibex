//
//  VideoPage.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI
import AVKit

struct VideoPage: View {
    let video: FeedVideo
    let player: AVPlayer

    var body: some View {
        ZStack {
            // Background gradient to avoid black flash while buffering
            LinearGradient(
                colors: [Color.vbPurple.opacity(0.28), Color.vbBlue.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            // Fade for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    // Left: caption
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.caption ?? "")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(3)

                        Text(video.created_at.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.footnote)
                    }

                    Spacer()

                    // Right: actions
                    VStack(spacing: 18) {
                        action(icon: "heart.fill", text: "\(video.like_count)")
                        action(icon: "message.fill", text: "\(video.comment_count)")
                        action(icon: "arrowshape.turn.up.right.fill", text: "Share")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private func action(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
