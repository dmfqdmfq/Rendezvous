import SwiftUI

struct GalleryDetailView: View {
    
    @EnvironmentObject private var settings: AppSettings
    
    let gallery: GalleryInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 作品のサムネイルを表示する
                if let firstFile = gallery.files.first {
                    HitomiThumbnailView(
                        hash: firstFile.hash
                    )
                    .frame(maxWidth: .infinity)
                }

                // 作品タイトルを表示する
                Text(gallery.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Divider()

                // ギャラリーの基本情報を表示する
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gallery ID: \(gallery.id)")

                    if let language = gallery.languageLocalname {
                        Text("Language: \(language)")
                    }

                    Text("Pages: \(gallery.files.count)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                NavigationLink {
                    GalleryReaderView(
                        gallery: gallery
                    )
                } label: {
                    HStack {
                        Spacer()

                        Image(systemName: "book.pages")
                        Text(settings.galleryLanguage.readButtonTitle)

                        Spacer()
                    }
                    .font(.headline)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
