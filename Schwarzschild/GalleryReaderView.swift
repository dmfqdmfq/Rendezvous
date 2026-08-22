import SwiftUI
import UIKit

struct GalleryReaderView: View {

    let gallery: GalleryInfo

    private let resolver = HitomiImageResolver()

    @State private var isReady = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView(
                    "読み込みエラー",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )

            } else if !isReady {
                ProgressView("Reader Loading...")

            } else {
                reader
            }
        }
        .navigationTitle(gallery.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await prepareReader()
        }
    }

    // MARK: - Reader

    private var reader: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(
                    Array(gallery.files.enumerated()),
                    id: \.offset
                ) { index, file in

                    ReaderPageView(
                        pageNumber: index + 1,
                        file: file,
                        resolver: resolver
                    )
                }
            }
        }
        .background(.black)
    }

    // MARK: - Initialization

    // Readerで使用する最新のgg.js情報を取得する
    private func prepareReader() async {
        do {
            try await resolver.initialize()
            isReady = true

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Reader Page

private struct ReaderPageView: View {

    let pageNumber: Int
    let file: GalleryFile
    let resolver: HitomiImageResolver

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 4) {

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

            } else if loadFailed {
                ContentUnavailableView(
                    "Page \(pageNumber)",
                    systemImage: "photo.badge.exclamationmark"
                )
                .frame(height: 300)

            } else {
                ProgressView()
                    .tint(.white)
                    .frame(height: 300)
            }

            Text("\(pageNumber) / ?")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            await loadImage()
        }
    }

    // MARK: - Image Loading

    // ファイルハッシュからReader用画像を取得する
    private func loadImage() async {
        do {
            let request = try await resolver.imageRequest(
                for: file.hash
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                loadFailed = true
                return
            }

            guard let loadedImage = UIImage(data: data) else {
                loadFailed = true
                return
            }

            image = loadedImage

        } catch {
            loadFailed = true
        }
    }
}
