import SwiftUI
import Combine

@MainActor
public class KeyboardObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    @Published public private(set) var shown: Bool = false
    @Published public private(set) var currentHeight: CGFloat = 0 {
        didSet { print(">>> KeyboardObserver didset currentHeight: \(currentHeight)") }
    }

    let keyboardWillShow = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }

    let keyboardWillHide = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ -> CGFloat in 0 }

    public init() {
        Publishers
            .Merge(keyboardWillShow, keyboardWillHide)
            .subscribe(on: DispatchQueue.main)
            .assign(to: &$currentHeight)

        $currentHeight
            .map{$0 != 0 }
            .assign(to: &$shown)
    }
}
