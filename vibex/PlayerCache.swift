//
//  PlayerCache.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI
import AVKit
import Combine

@MainActor
final class PlayerCache: ObservableObject {
    private var players: [UUID: AVPlayer] = [:]

    // Create or return a cached player. Uses AVPlayerItem + AVURLAsset so we
    // can prime asset loading and control buffering behavior.
    func player(for item: FeedVideo) -> AVPlayer {
        if let p = players[item.id] { return p }
        let url = URL(string: item.video_url)!
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: playerItem)
        p.actionAtItemEnd = .pause
        p.automaticallyWaitsToMinimizeStalling = false
        players[item.id] = p
        return p
    }

    // Prime the asset by loading the "playable" key asynchronously. This
    // reduces first-play jank without starting playback immediately.
    func preload(_ item: FeedVideo) {
        let p = player(for: item)
        guard let asset = p.currentItem?.asset as? AVURLAsset else { return }
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            // intentionally empty - the load primes the system
        }
    }

    func pauseAll(except keepId: UUID?) {
        for (id, p) in players where id != keepId {
            p.pause()
            p.seek(to: .zero)
        }
    }

    func clear(keeping ids: Set<UUID>) {
        players.keys
            .filter { !ids.contains($0) }
            .forEach { players[$0] = nil }
    }
}
