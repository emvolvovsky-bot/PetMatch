//
//  NewsView.swift
//  PetMatch
//
//  View for displaying pet news articles
//

import SwiftUI

struct NewsView: View {
    private let newsService = NewsService()
    @State private var articles: [NewsArticle] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var safariURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                PMColor.background
                    .ignoresSafeArea()
                
                content
            }
            .sheet(isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )) {
                if let url = safariURL {
                    SafariView(url: url, tintColor: UIColor(PMColor.coral))
                }
            }
            .task {
                await loadNews()
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if isLoading && articles.isEmpty {
            loadingView
        } else if articles.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(articles) { article in
                        NewsArticleCard(article: article) {
                            if let url = article.articleURL {
                                safariURL = url
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await loadNews()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(PMColor.coral)
            Text("Loading pet news...")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(PMColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PMColor.coral.opacity(0.2), PMColor.mint.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PMColor.coral, PMColor.coralSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 10) {
                Text("No pet news right now")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PMColor.textPrimary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(PMColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button {
                Task {
                    await loadNews()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LinearGradient.primaryPetGradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadNews() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedArticles = try await newsService.fetchPetNews()
            await MainActor.run {
                articles = fetchedArticles
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load news. Make sure the server is running."
                articles = []
            }
        }
    }
}

private struct NewsArticleCard: View {
    let article: NewsArticle
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            Haptics.lightImpact()
            onTap()
        } label: {
            VStack(spacing: 0) {
                // Image Section (optional thumbnail)
                if let imageURL = article.thumbnailURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                LinearGradient.primaryPetGradient
                                ProgressView()
                                    .tint(.white)
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            ZStack {
                                PMColor.secondarySurface
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(PMColor.textTertiary)
                            }
                        @unknown default:
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                }
                
                // Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !article.description.isEmpty {
                        Text(article.description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(PMColor.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack {
                        Text(article.source)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PMColor.textTertiary)
                        
                        Spacer()
                        
                        Text(article.formattedDate)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(PMColor.textTertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PMColor.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 16,
                x: 0,
                y: 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    NewsView()
}

