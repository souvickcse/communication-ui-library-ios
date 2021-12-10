//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine

enum ViewType {
    case setupView
    case callingView
}

class NavigationRouter: ObservableObject {
    private let store: Store<AppState>
    private let logger: Logger
    private var isDismissed: Bool = false
    @Published var currentView: ViewType = .setupView

    var cancellables = Set<AnyCancellable>()
    private var dismissCompositeHostingVC: (() -> Void)?

    init(store: Store<AppState>, logger: Logger) {
        self.store = store
        self.logger = logger

        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.receive(state)
            }.store(in: &cancellables)
    }

    func receive(_ state: AppState) {
        var viewToNavigateTo: ViewType?

        switch state.navigationState.status {
        case .setup:
            viewToNavigateTo = .setupView
        case .inCall:
            viewToNavigateTo = .callingView
        case .exit:
            guard !self.isDismissed else {
                return
            }
            dismissCompositeHostingVC?()
            isDismissed = true
        }

        if viewToNavigateTo != nil,
           currentView != viewToNavigateTo! {
            logger.debug("Navigating to: \(viewToNavigateTo!)" )
            currentView = viewToNavigateTo!
        }
    }

    func setDismissComposite(_ closure: @escaping () -> Void) {
        self.dismissCompositeHostingVC = closure
    }
}
