import SwiftUI
import Combine

public protocol IStoryModel: Identifiable {
    associatedtype Id: Hashable
    var id: Id { get }
}

extension StoriesPager {
    @MainActor
    final class LocalState: ObservableObject {
        private(set) var pagesRects: [Model.Id: CGRect] = [:]

        let activePageIdSub: PassthroughSubject<Model.Id?, Never> = .init()
        var activePageIdPub: AnyPublisher<Model.Id?, Never> {
            activePageIdSub
                .removeDuplicates()
                .eraseToAnyPublisher()
        }

        let navigationSub: PassthroughSubject<Reactions.NavigationType, Never> = .init()
        var navigationPub: AnyPublisher<StoriesPagerNavigationType, Never> {
            navigationSub
                .debounce(for: 0.15, scheduler: DispatchQueue.main)
                .map { $0.asStoriesNavType }
                .eraseToAnyPublisher()
        }

        func trackPageRects(currentPageId: Model.Id, targetPageId: Model.Id, rect: CGRect) {
            self.pagesRects[targetPageId] = rect
            if currentPageId == targetPageId {
                let placedInViewPort = rect.minX == 0
                self.activePageIdSub.send(placedInViewPort ? targetPageId : .none)
            }
        }
    }
}

public struct StoriesPager<Model, Page, SwitchModifier>: View
    where Model: IStoryModel, Page: View, SwitchModifier: ViewModifier {

    @Environment(\.bounds) private var bounds
    @StateObject private var ls: LocalState = .init()
    @Binding private var currentId: Model.Id
    @Binding private var activeId: Model.Id?

    private let models: [Model]
    private let pages: [Model.Id: Page]

    private let viewConfig: ViewConfig
    private let reactions: Reactions?

    public init(
        currentId: Binding<Model.Id>,
        activeId: Binding<Model.Id?> = .constant(.none),
        models: [Model],
        viewConfig: ViewConfig,
        reactions: Reactions? = .none
    ) {
        self._currentId = currentId
        self._activeId = activeId
        self.models = models
        self.viewConfig = viewConfig
        self.reactions = reactions

        self.pages = models
            .reduce(into: [Model.Id: Page]()) { store, next in
                store[next.id] = viewConfig.storyViewBuilder(next)
            }
    }

    public var body: some View {
        content
            .animation(.linear, value: currentId)
            .onReceive(ls.navigationPub) { self.reactions?.navigationSubject?.send($0) }
            .onReceive(ls.activePageIdPub) { self.activeId = $0 }
    }

    private var content: some View {
        TabView(selection: $currentId) {
            ForEach(models) { model in
                pageContent(model)
                    .tag(model.id)
                    .modifier(viewConfig.switchStoryModifier)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func pageContent(_ model: Model) -> some View {
        Button(action: {}) {
            Group {
                if #available(iOS 16.0, *) {
                    pages[model.id]
                        .onTapGesture { onTapContent(location: $0, activeId: currentId, triggeredId: model.id) }
                }
                else {
                    pages[model.id]
                        .onTapGesture { reactOnForward(activeId: currentId,triggeredId: model.id) }
                }
            }
            .frameOnChange(space: .global) { rect in
                ls.trackPageRects(currentPageId: currentId, targetPageId: model.id, rect: rect)
            }
            .transaction { $0.animation = .none } // removes default animations inherited from modals
        }
            .buttonStyle(
                PressHandleButtonStyle(props: .init(
                    pressed: reactions?.contentHeld ?? .constant(false),
                    pressConfig: viewConfig.contentOnHoldConfig,
                    minDuration: viewConfig.contentOnHoldMinDuration
                ))
            )
    }
}

// reactions
extension StoriesPager {
    private func reactOnBack(activeId: Model.Id, triggeredId: Model.Id) {
        guard ableToHandleNavigation(active: activeId, triggered: triggeredId, contentHeld: reactions?.contentHeld)
        else { return }
        self.ls.navigationSub.send(.backward(from: triggeredId))
    }

    private func reactOnForward(activeId: Model.Id, triggeredId: Model.Id) {
        guard ableToHandleNavigation(active: activeId, triggered: triggeredId, contentHeld: reactions?.contentHeld)
        else { return }
        self.ls.navigationSub.send(.forward(from: triggeredId))
    }

    private func ableToHandleNavigation(active: Model.Id, triggered: Model.Id, contentHeld: Binding<Bool>?) -> Bool {
        guard let flag = contentHeld?.wrappedValue,
              flag.not 
        else {
            print(">>>> handle tap while on hold: active: \(active), triggered: \(triggered)")
            return false
        }

        guard active == triggered
        else {
            print(">>>> unordinary switch try: active: \(active), triggered: \(triggered)")
            self.currentId = triggered // recovery mode
            return false
        }

        guard let rect = ls.pagesRects[triggered],
              rect.origin.x == 0
        else { 
            print(">>>> handle tap while animation xOffset: \(ls.pagesRects[triggered]?.minX): active: \(active), triggered: \(triggered)")
            return false
        }

        return true
    }

    private func onTapContent(location: CGPoint, activeId: Model.Id, triggeredId: Model.Id) {
        switch location.x < viewConfig.backToForwardAreaRatio * bounds.width {
            case true: reactOnBack(activeId: activeId, triggeredId: triggeredId)
            case false: reactOnForward(activeId: activeId, triggeredId: triggeredId)
        }
    }
}
