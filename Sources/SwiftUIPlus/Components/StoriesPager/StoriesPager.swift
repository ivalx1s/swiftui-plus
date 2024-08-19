import SwiftUI

public protocol IStoryModel: Identifiable {
    associatedtype Id: Hashable
    var id: Id { get }
}

public struct StoriesPager<Model, Page, SwitchModifier>: View
    where Model: IStoryModel, Page: View, SwitchModifier: ViewModifier {

    @Environment(\.bounds) private var bounds

    @Binding private var currentId: Model.Id

    private let models: [Model]
    private let pages: [Model.Id: Page]

    private let viewConfig: ViewConfig
    private let reactions: Reactions?

    public init(
        currentId: Binding<Model.Id>,
        models: [Model],
        viewConfig: ViewConfig,
        reactions: Reactions? = .none
    ) {
        self._currentId = currentId
        self.models = models
        self.viewConfig = viewConfig
        self.reactions = reactions

        self.pages = models
            .reduce(into: [Model.Id: Page]()) { store, next in
                store[next.id] = viewConfig.storyViewBuilder(next)
            }
    }

    public var body: some View {
        TabView(selection: $currentId) {
            ForEach(models) { model in
                Button(action: {}) {
                    if #available(iOS 16.0, *) {
                        pages[model.id]
                          .onTapGesture(perform: onTapContent)
                    } else {
                        pages[model.id]
                          .onTapGesture(perform: { reactions?.onForward })
                    }
                }
                    .buttonStyle(
                        PressHandleButtonStyle(props: .init(
                            pressed: reactions?.contentHolded ?? .constant(false),
                            pressConfig: viewConfig.contentOnHoldConfig,
                            minDuration: viewConfig.contentOnHoldMinDuration
                        ))
                    )
                    .tag(model.id)
                    .modifier(viewConfig.switchStoryModifier)
            }
        }
            .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// reactions
extension StoriesPager {
    private func reactOnBack() {
        guard let flag = reactions?.contentHolded?.wrappedValue, flag.not else { return }
        self.reactions?.onBack?()
    }

    private func reactOnForward() {
        guard let flag = reactions?.contentHolded?.wrappedValue, flag.not else { return }
        self.reactions?.onForward?()
    }

    private func onTapContent(_ location: CGPoint) {
        switch location.x < viewConfig.backToForwardAreaRatio * bounds.width {
            case true: reactOnBack()
            case false: reactOnForward()
        }
    }
}
