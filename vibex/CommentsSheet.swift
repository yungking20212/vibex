//
//  CommentsSheet.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI

struct CommentsSheet: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var social = SocialStore()
    
    let videoId: UUID
    
    @State private var comments: [VideoComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isPosting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments List
                List(comments) { comment in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(comment.username ?? "User")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(comment.created_at, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(comment.text)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                
                // New Comment Input
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .disabled(isPosting)
                    
                    Button(action: {
                        Task { await postComment() }
                    }) {
                        if isPosting {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                        }
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 2)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadComments()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            comments = try await social.fetchComments(videoId: videoId)
        } catch {
            // Handle error - could show an alert or log it
            print("Error loading comments: \(error)")
            comments = []
        }
    }
    
    private func postComment() async {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let userId = auth.currentUserId else {
            return
        }
        
        isPosting = true
        defer { isPosting = false }
        
        do {
            let newComment = try await social.addComment(
                videoId: videoId,
                userId: userId,
                body: text
            )
            
            // Add to local list
            comments.insert(newComment, at: 0)
            
            // Clear input
            newCommentText = ""
            
        } catch {
            // Show error somehow
            print("Error posting comment: \(error)")
        }
    }
}

#Preview {
    CommentsSheet(videoId: UUID())
        .environmentObject(AuthManager.shared)
}
