import SwiftUI
import UIKit

struct SwipeBackEnabler: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

private final class SwipeBackViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 戻るボタンを非表示にしていても、
        // iOS標準の左端スワイプによる戻る操作を有効にする
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}
