import SwiftUI
import UIKit

struct HitomiThumbnailView: View {

    let hash: String

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            } else if loadFailed {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)

            } else {
                ProgressView()
            }
        }
        .frame(
            width: 90,
            height: 125
        )
        .background(.gray.opacity(0.15))
        .clipShape(
            RoundedRectangle(cornerRadius: 8)
        )
        .task {
            await loadThumbnail()
        }
    }

    // MARK: - Thumbnail Loading

    // ファイルハッシュからサムネイル画像を取得する
    private func loadThumbnail() async {

        guard let url = makeThumbnailURL(
            hash: hash
        ) else {
            loadFailed = true
            return
        }

        var request = URLRequest(url: url)

        // CDNへのアクセスに必要なRefererを設定する
        request.setValue(
            "https://hitomi.la/",
            forHTTPHeaderField: "Referer"
        )

        do {
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

    // ファイルハッシュからサムネイルCDNのURLを生成する
    private func makeThumbnailURL(
        hash: String
    ) -> URL? {

        guard hash.count >= 3 else {
            return nil
        }

        let lastCharacter = hash.suffix(1)

        let beforeLastIndex = hash.index(
            hash.endIndex,
            offsetBy: -3
        )

        let lastTwoStart = beforeLastIndex
        let lastTwoEnd = hash.index(
            hash.endIndex,
            offsetBy: -1
        )

        let lastTwo = hash[
            lastTwoStart..<lastTwoEnd
        ]

        // 例:
        // hash末尾が "7b3" の場合
        // /3/7b/{hash}.avif となる
        let urlString =
            "https://atn.gold-usergeneratedcontent.net/" +
            "avifsmallbigtn/" +
            "\(lastCharacter)/\(lastTwo)/" +
            "\(hash).avif"

        return URL(string: urlString)
    }
}
