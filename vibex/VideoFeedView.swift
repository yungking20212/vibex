//
//  VideoFeedView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI
import AVKit

struct VideoFeedView: View {
    @StateObject private var vm = VideoFeedViewModel()
    @StateObject private var players = PlayerCache()

    @State private var index: Int = 0

    var body: some View {
        ZStack {
            // Use branded background instead of solid black for next-gen look
            Color.vbBackground.ignoresSafeArea()

            if vm.items.isEmpty && vm.isLoading {
                ProgressView().tint(.white)
            } else if vm.items.isEmpty {
                VStack(spacing: 14) {
                    // Neon-branded placeholder when no videos are available
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient.primaryNeon)
                        .neonGlow(intensity: 1.1, spread: 1.2)
                        .pulsingBloom(scale: 1.06, glowRadius: 36)

                    Text("No videos... yet")
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundStyle(.white.opacity(0.95))
                        .neonGlow(intensity: 0.9, spread: 1.0)

                    if let err = vm.errorText {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else {
                        Text("Create your first vibe or pull to refresh the feed.")
                            .foregroundStyle(.white.opacity(0.75))
                            .font(.subheadline)
                    }

                    Button("Refresh") { Task { await vm.refresh() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 36)
            } else {
                GeometryReader { geo in
                    TabView(selection: $index) {
                        ForEach(vm.items.indices, id: \.self) { i in
                            VideoPage(
                                video: vm.items[i],
                                player: players.player(for: vm.items[i])
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .rotationEffect(.degrees(-90))
                            .tag(i)
                            .onAppear {
                                Task {
                                    await vm.loadMoreIfNeeded(currentIndex: i)

                                    // Preload next / previous for smooth swipes
                                    if i + 1 < vm.items.count { players.preload(vm.items[i + 1]) }
                                    if i > 0 { players.preload(vm.items[i - 1]) }

                                    // Keep cache small (prevents memory issues)
                                    let keep = Set(vm.items[max(0, i-2)...min(vm.items.count-1, i+2)].map { $0.id })
                                    players.clear(keeping: keep)
                                }
                            }
                        }
                    }
                    .rotationEffect(.degrees(90))
                    .frame(width: geo.size.height, height: geo.size.width)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                    .onChange(of: index) { _, newIndex in
                        playOnly(index: newIndex)
                    }
                    .onAppear {
                        playOnly(index: index)
                    }
                }
            }

            if vm.isLoading && !vm.items.isEmpty {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                        .padding(.bottom, 32)
                }
            }
        }
        .task { await vm.refresh() }
    }

    private func playOnly(index: Int) {
        guard vm.items.indices.contains(index) else { return }
        let current = vm.items[index]
        players.pauseAll(except: current.id)
        let p = players.player(for: current)
        // Ensure the asset is primed for playback then play muted
        players.preload(current)
        p.isMuted = true
        p.play()
    }
}
