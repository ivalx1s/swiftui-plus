import SwiftUI
import Combine

extension StoriesPager {
    @MainActor
    final class LocalState: ObservableObject {
        private var pipelines: Set<AnyCancellable> = []
        private(set) var pagesRects: [Model.Id: CGRect] = [:]
        private let viewConfig: StoriesPager.ViewConfig
        private let reactions: StoriesPager.Reactions?
        private var initialOffsetY: CGFloat?
        @Published private(set) var inAnimation: Bool = true
        private var disableInAnimationTask: Task<Void, any Error>?

        init(
            viewConfig: StoriesPager.ViewConfig,
            reactions: StoriesPager.Reactions?
        ) {
            self.viewConfig = viewConfig
            self.reactions = reactions

            initPipelines(reactions: reactions)
        }

        func delayForAnimation() {
            inAnimation = true
            disableInAnimationTask?.cancel()
            disableInAnimationTask = Task.delayed(byTimeInterval: 0.3) { @MainActor in
                self.inAnimation = false
            }
        }

        let activePageIdSub: PassthroughSubject<Model.Id?, Never> = .init()
        var activePageIdPub: AnyPublisher<Model.Id?, Never> {
            activePageIdSub
                .print(">>> stories ls: active page sub: ")
                .debounce(
                    for: .init(floatLiteral: viewConfig.activePageDebounceDuration),
                    scheduler: DispatchQueue.main
                )
                .removeDuplicates()
                .eraseToAnyPublisher()
        }

        let navigationSub: PassthroughSubject<Reactions.NavigationType, Never> = .init()
        var navigationPub: AnyPublisher<StoriesPagerNavigationType, Never> {
            navigationSub
                .print(">>> stories ls: nav sub: ")
                .debounce(
                    for: .init(floatLiteral: viewConfig.navigationDebounceDuration),
                    scheduler: DispatchQueue.main
                )
                .map { $0.asStoriesNavType }
                .eraseToAnyPublisher()
        }

        func onContentFrameChange(_ rect: CGRect, bounds: CGRect, models: [Model]) {
            if self.initialOffsetY == nil { self.initialOffsetY = rect.minY }

            guard inAnimation.not else { return }

            let progress = abs(rect.minX / bounds.width)
            let progressIntPart = progress.asIntTruncating
            let progressFloatingPart = progress.truncatingRemainder(dividingBy: 1)

            guard let id = models[safe: progressIntPart]?.id
            else { return }

            let yOffset = 0  // let yOffset = rect.minY - (self.initialOffsetY ?? 0)

            let inTransition = progressFloatingPart != 0 || yOffset != 0

            let activeModelId = inTransition ? nil : id

            activePageIdSub.send(activeModelId)
        }

        func trackPageRects(currentPageId: Model.Id, targetPageId: Model.Id, rect: CGRect) {
            self.pagesRects[targetPageId] = rect
            if self.initialOffsetY == nil { self.initialOffsetY = rect.minY }

            if currentPageId == targetPageId {
                let startPoint = CGPoint(x: rect.minX, y: rect.minY - (self.initialOffsetY ?? 0))
                let placedInViewPort = startPoint.distance == 0
                self.activePageIdSub.send(placedInViewPort ? targetPageId : .none)
            }
        }

        private func initPipelines(reactions: StoriesPager.Reactions?) {
            activePageIdPub
                .receive(on: DispatchQueue.main)
                .sink { reactions?.activeId.wrappedValue = $0 }
                .store(in: &pipelines)

            navigationPub
                .receive(on: DispatchQueue.main)
                .sink { reactions?.navigationSubject?.send($0) }
                .store(in: &pipelines)
        }
    }
}
