//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI
import FluentUI

struct CompositeParticipantsList: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var isInfoHeaderDisplayed: Bool
    @ObservedObject var viewModel: ParticipantsListViewModel
    let sourceView: UIView

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented,
                    isInfoHeaderDisplayed: $isInfoHeaderDisplayed)
    }

    func makeUIViewController(context: Context) -> DrawerContainerViewController<ParticipantsListCellViewModel> {
        let controller = ParticipantsListViewController(items: getParticipantsList(),
                                                        sourceView: sourceView)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DrawerContainerViewController<ParticipantsListCellViewModel>,
                                context: Context) {
        uiViewController.updateDrawerList(items: getParticipantsList())
    }

    static func dismantleUIViewController(_ controller: DrawerContainerViewController<ParticipantsListCellViewModel>,
                                          coordinator: Coordinator) {
        controller.dismissDrawer()
    }

    private func getParticipantsList() -> [ParticipantsListCellViewModel] {
        return viewModel.sortedParticipants()
    }

    class Coordinator: NSObject, DrawerControllerDelegate {
        @Binding var isPresented: Bool
        @Binding var isInfoHeaderDisplayed: Bool

        init(isPresented: Binding<Bool>,
             isInfoHeaderDisplayed: Binding<Bool>) {
            self._isPresented = isPresented
            self._isInfoHeaderDisplayed = isInfoHeaderDisplayed
        }

        func drawerControllerDidDismiss(_ controller: DrawerController) {
            isPresented = false
            isInfoHeaderDisplayed = false
        }
    }
}