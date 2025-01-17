//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Combine
import Foundation

class CallingViewModel: ObservableObject {
    @Published var isConfirmLeaveListDisplayed = false
    @Published var isParticipantGridDisplayed: Bool
    @Published var isVideoGridViewAccessibilityAvailable = false
    @Published var appState: AppStatus = .foreground
    @Published var isInPip = false
    @Published var allowLocalCameraPreview = false

    private let compositeViewModelFactory: CompositeViewModelFactoryProtocol
    private let logger: Logger
    private let store: Store<AppState, Action>
    private let localizationProvider: LocalizationProviderProtocol
    private let accessibilityProvider: AccessibilityProviderProtocol
    private let callType: CompositeCallType

    private var cancellables = Set<AnyCancellable>()
    private var callHasConnected = false
    private var callClientRequested = false
    private var leaveCallConfirmationMode: LeaveCallConfirmationMode?

    let localVideoViewModel: LocalVideoViewModel
    let participantGridsViewModel: ParticipantGridViewModel
    let bannerViewModel: BannerViewModel
    let lobbyOverlayViewModel: LobbyOverlayViewModel
    let loadingOverlayViewModel: LoadingOverlayViewModel
    var onHoldOverlayViewModel: OnHoldOverlayViewModel!
    let isRightToLeft: Bool

    var controlBarViewModel: ControlBarViewModel!
    var infoHeaderViewModel: InfoHeaderViewModel!
    var lobbyWaitingHeaderViewModel: LobbyWaitingHeaderViewModel!
    var lobbyActionErrorViewModel: LobbyErrorHeaderViewModel!
    var errorInfoViewModel: ErrorInfoViewModel!
    var callDiagnosticsViewModel: CallDiagnosticsViewModel!
    var bottomToastViewModel: BottomToastViewModel!
    var supportFormViewModel: SupportFormViewModel!
    var capabilitiesManager: CapabilitiesManager!
    var eventButtonClick:((_ event:String) -> Void)? = nil
    var listButtonClick:(() -> Void)? = nil
    init(compositeViewModelFactory: CompositeViewModelFactoryProtocol,
         logger: Logger,
         store: Store<AppState, Action>,
         localizationProvider: LocalizationProviderProtocol,
         accessibilityProvider: AccessibilityProviderProtocol,
         isIpadInterface: Bool,
         allowLocalCameraPreview: Bool,
         leaveCallConfirmationMode: LeaveCallConfirmationMode,
         callType: CompositeCallType,
         capabilitiesManager: CapabilitiesManager,
         eventButtonClick:((_ event:String) -> Void)? = nil,listButtonClick:(() -> Void)? = nil
    ) {
        self.logger = logger
        self.store = store
        self.compositeViewModelFactory = compositeViewModelFactory
        self.localizationProvider = localizationProvider
        self.isRightToLeft = localizationProvider.isRightToLeft
        self.accessibilityProvider = accessibilityProvider
        self.allowLocalCameraPreview = allowLocalCameraPreview
        self.leaveCallConfirmationMode = leaveCallConfirmationMode
        self.capabilitiesManager = capabilitiesManager
        self.callType = callType
        let actionDispatch: ActionDispatch = store.dispatch
        self.eventButtonClick=eventButtonClick
        self.listButtonClick=listButtonClick

        supportFormViewModel = compositeViewModelFactory.makeSupportFormViewModel()

        localVideoViewModel = compositeViewModelFactory.makeLocalVideoViewModel(dispatchAction: actionDispatch)
        participantGridsViewModel = compositeViewModelFactory.makeParticipantGridsViewModel(isIpadInterface:
                                                                                                isIpadInterface)
        bannerViewModel = compositeViewModelFactory.makeBannerViewModel()
        lobbyOverlayViewModel = compositeViewModelFactory.makeLobbyOverlayViewModel()
        loadingOverlayViewModel = compositeViewModelFactory.makeLoadingOverlayViewModel()
        infoHeaderViewModel = compositeViewModelFactory
            .makeInfoHeaderViewModel(dispatchAction: actionDispatch,
                                     localUserState: store.state.localUserState)
        lobbyWaitingHeaderViewModel = compositeViewModelFactory
            .makeLobbyWaitingHeaderViewModel(localUserState: store.state.localUserState,
            dispatchAction: actionDispatch)
        lobbyActionErrorViewModel = compositeViewModelFactory
            .makeLobbyActionErrorViewModel(localUserState: store.state.localUserState,
            dispatchAction: actionDispatch)

        let isCallConnected = store.state.callingState.status == .connected
        let callingStatus = store.state.callingState.status
        let isOutgoingCall = CallingViewModel.isOutgoingCallDialingInProgress(callType: callType,
                                                                              callingStatus: callingStatus)
        let isRemoteHold = store.state.callingState.status == .remoteHold

        isParticipantGridDisplayed = (isCallConnected || isOutgoingCall || isRemoteHold) &&
            CallingViewModel.hasRemoteParticipants(store.state.remoteParticipantsState.participantInfoList)
        controlBarViewModel = compositeViewModelFactory
            .makeControlBarViewModel(dispatchAction: actionDispatch, endCallConfirm: { [weak self] in
                guard let self = self else {
                    return
                }
                self.endCall()
            }, localUserState: store.state.localUserState,
            leaveCallConfirmationMode: leaveCallConfirmationMode,
            capabilitiesManager: capabilitiesManager,eventButtonClick: eventButtonClick,listButtonClick: listButtonClick )

        onHoldOverlayViewModel = compositeViewModelFactory.makeOnHoldOverlayViewModel(resumeAction: { [weak self] in
            guard let self = self else {
                return
            }
            self.resumeOnHold()
        })

        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.receive(state)
            }.store(in: &cancellables)

        updateIsLocalCameraOn(with: store.state)
        errorInfoViewModel = compositeViewModelFactory.makeErrorInfoViewModel(title: "",
                                                                              subtitle: "")
        callDiagnosticsViewModel = compositeViewModelFactory
            .makeCallDiagnosticsViewModel(dispatchAction: store.dispatch)

        bottomToastViewModel = compositeViewModelFactory.makeBottomToastViewModel(
            toastNotificationState: store.state.toastNotificationState, dispatchAction: store.dispatch)
    }

    func dismissConfirmLeaveDrawerList() {
        self.isConfirmLeaveListDisplayed = false
    }

    func endCall() {
        store.dispatch(action: .callingAction(.callEndRequested))
        dismissConfirmLeaveDrawerList()
    }

    func resumeOnHold() {
        store.dispatch(action: .callingAction(.resumeRequested))
    }

    func receive(_ state: AppState) {
        if appState != state.lifeCycleState.currentStatus {
            appState = state.lifeCycleState.currentStatus
        }

        guard state.lifeCycleState.currentStatus == .foreground
                || state.visibilityState.currentStatus != .visible else {
            return
        }

        supportFormViewModel.update(state: state)
        controlBarViewModel.update(localUserState: state.localUserState,
                                   permissionState: state.permissionState,
                                   callingState: state.callingState,
                                   visibilityState: state.visibilityState)
        infoHeaderViewModel.update(localUserState: state.localUserState,
                                   remoteParticipantsState: state.remoteParticipantsState,
                                   callingState: state.callingState,
                                   visibilityState: state.visibilityState)
        localVideoViewModel.update(localUserState: state.localUserState,
                                   visibilityState: state.visibilityState)
        lobbyWaitingHeaderViewModel.update(localUserState: state.localUserState,
                                           remoteParticipantsState: state.remoteParticipantsState,
                                           callingState: state.callingState,
                                           visibilityState: state.visibilityState)
        lobbyActionErrorViewModel.update(localUserState: state.localUserState,
                                         remoteParticipantsState: state.remoteParticipantsState,
                                         callingState: state.callingState)
        participantGridsViewModel.update(callingState: state.callingState,
                                         remoteParticipantsState: state.remoteParticipantsState,
                                         visibilityState: state.visibilityState, lifeCycleState: state.lifeCycleState)
        bannerViewModel.update(callingState: state.callingState)
        lobbyOverlayViewModel.update(callingStatus: state.callingState.status)
        onHoldOverlayViewModel.update(callingStatus: state.callingState.status,
                                      audioSessionStatus: state.audioSessionState.status)

        let newIsCallConnected = state.callingState.status == .connected
        let isOutgoingCall = CallingViewModel.isOutgoingCallDialingInProgress(callType: callType,
                                                                              callingStatus: state.callingState.status)
        let isRemoteHold = store.state.callingState.status == .remoteHold
        let shouldParticipantGridDisplayed = (newIsCallConnected || isOutgoingCall || isRemoteHold) &&
            CallingViewModel.hasRemoteParticipants(state.remoteParticipantsState.participantInfoList)
        if shouldParticipantGridDisplayed != isParticipantGridDisplayed {
            isParticipantGridDisplayed = shouldParticipantGridDisplayed
        }
        if callHasConnected != newIsCallConnected && newIsCallConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else {
                    return
                }
                self.accessibilityProvider.postQueuedAnnouncement(
                    self.localizationProvider.getLocalizedString(.joinedCallAccessibilityLabel))
            }
            callHasConnected = newIsCallConnected
        }

        updateIsLocalCameraOn(with: state)
        errorInfoViewModel.update(errorState: state.errorState)
        isInPip = state.visibilityState.currentStatus == .pipModeEntered
        callDiagnosticsViewModel.update(diagnosticsState: state.diagnosticsState)
        bottomToastViewModel.update(toastNotificationState: state.toastNotificationState)
    }

    private static func hasRemoteParticipants(_ participants: [ParticipantInfoModel]) -> Bool {
        return participants.filter({ participant in
            participant.status != .inLobby && participant.status != .disconnected
        }).count > 0
    }

    private func updateIsLocalCameraOn(with state: AppState) {
        let isLocalCameraOn = state.localUserState.cameraState.operation == .on
        let displayName = state.localUserState.displayName ?? ""
        let isLocalUserInfoNotEmpty = isLocalCameraOn || !displayName.isEmpty
        isVideoGridViewAccessibilityAvailable = !lobbyOverlayViewModel.isDisplayed
        && !onHoldOverlayViewModel.isDisplayed
        && (isLocalUserInfoNotEmpty || isParticipantGridDisplayed)
    }

    private static func isOutgoingCallDialingInProgress(callType: CompositeCallType,
                                                        callingStatus: CallingStatus?) -> Bool {
        let isOutgoingCall = (callType == .oneToNOutgoing && (callingStatus == nil
                                                              || callingStatus == .connecting
                                                              || callingStatus == .ringing
                                                              || callingStatus == .earlyMedia))
        return isOutgoingCall
    }
}
