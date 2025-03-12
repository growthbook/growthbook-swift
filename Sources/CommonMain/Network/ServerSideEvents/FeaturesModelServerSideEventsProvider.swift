//
//  FeaturesModelServerSideEventsProvider.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

final class FeaturesModelServerSideEventsProvider {
    private class MutableState {
        var isEnabled = false
        var serverSideEventsHandler: SSEHandler?
        weak var delegate: FeaturesModelProviderDelegate?

        deinit {
            serverSideEventsHandler?.disconnect()
        }
    }

    private let mutableState: Protected<MutableState> = .init(.init())
    private let serverSideEventsURL: URL
    private let eventName: String
    private let featuresDataParser: FeaturesDataParserInterface
    private let systemStateObserver: SystemStateObserverForTimerInterface

    init(
        serverSideEventsURL: URL,
        eventName: String = "features",
        featuresDataParser: FeaturesDataParserInterface,
        systemStateObserver: SystemStateObserverForTimerInterface = SystemStateObserverForTimer()
    ) {
        self.serverSideEventsURL = serverSideEventsURL
        self.eventName = eventName
        self.featuresDataParser = featuresDataParser
        self.systemStateObserver = systemStateObserver
        systemStateObserver.delegate = self
    }

    deinit {
        unsubscribeFromFeaturesUpdates()
    }

    private func disconnectServerSideEventsStream() {
        mutableState.write { mutableState in
            guard let serverSideEventsHandler = mutableState.serverSideEventsHandler else { return }
            serverSideEventsHandler.removeEventListener(event: eventName)
            mutableState.serverSideEventsHandler = .none
        }
    }

    private func _connectServerSideEventsStream() -> SSEHandler {
        let serverSideEventsHandler = SSEHandler(url: serverSideEventsURL)

        serverSideEventsHandler.addEventListener(event: "features") { [weak self] eventID, eventName, eventPayloadString in
            self?.handleEventPayload(eventID: eventID, eventName: eventName, eventPayloadString: eventPayloadString)
        }

        serverSideEventsHandler.onComplete { [weak serverSideEventsHandler, weak self] statusCode, shouldReconnect, error in
            self?.handleSSEConnectionStatusChange(for: serverSideEventsHandler, statusCode: statusCode, shouldReconnect: shouldReconnect, error: error)
        }

        serverSideEventsHandler.connect()

        return serverSideEventsHandler
    }

    private func connectServerSideEventsStream() {
        disconnectServerSideEventsStream()
        
        mutableState.write { mutableState in
            guard mutableState.isEnabled else { return }

            mutableState.serverSideEventsHandler = _connectServerSideEventsStream()
        }
    }

    private func handleSSEConnectionStatusChange(for serverSideEventsHandler: SSEHandler?, statusCode: Int?, shouldReconnect: Bool?, error: Swift.Error?) {
        guard let serverSideEventsHandler else { return }

        if shouldReconnect == true {
            serverSideEventsHandler.connect()
        }
    }

    private func notifyDelegateAboutFailure(_ error: ServerSideEventsError) {
        delegate?.featuresProvider(self, didFailToUpdate: error)
    }

    private func handleEventPayload(eventID: String?, eventName: String?, eventPayloadString: String?) {
        guard let eventPayloadString, !eventPayloadString.isEmpty else { return }

        guard let payloadData = eventPayloadString.data(using: .utf8) else {
            let error: ServerSideEventsError = .eventPayloadStringIsNotAValidUTF8Data(
                eventID: eventID,
                eventName: eventName,
                eventPayloadString: eventPayloadString
            )
            return notifyDelegateAboutFailure(error)
        }

        let decryptedFeaturesModel: DecryptedFeaturesDataModel
        do {
            decryptedFeaturesModel = try featuresDataParser.parseFeaturesData(payloadData)
        } catch {
            let error: ServerSideEventsError = .payloadParsingFailed(
                eventID: eventID,
                eventName: eventName,
                eventPayloadString: eventPayloadString,
                underlyingError: error
            )
            return notifyDelegateAboutFailure(error)
        }

        delegate?.featuresProvider(self, didUpdate: decryptedFeaturesModel)
    }
}

extension FeaturesModelServerSideEventsProvider: FeaturesModelProviderInterface {
    var delegate: (any FeaturesModelProviderDelegate)? {
        get { mutableState.read(\.delegate) }
        set { mutableState.write(\.delegate, newValue) }
    }

    func subscribeToFeaturesUpdates() {
        mutableState.write(\.isEnabled, true)
        connectServerSideEventsStream()
    }

    func unsubscribeFromFeaturesUpdates() {
        mutableState.write(\.isEnabled, false)
        disconnectServerSideEventsStream()
    }
}

extension FeaturesModelServerSideEventsProvider: SystemStateObserverForTimerDelegate {
    func systemDidBecomeActive() {
        connectServerSideEventsStream()
    }

    func systemWillBecomeInactive() {
        disconnectServerSideEventsStream()
    }
}

extension FeaturesModelServerSideEventsProvider {
    struct ServerSideEventsError: Swift.Error, Sendable {
        enum ErrorType: Sendable {
            case eventPayloadStringIsNotAValidUTF8Data
            case payloadParsingFailed
        }

        let errorType: ErrorType
        let eventID: String?
        let eventName: String?
        let eventPayloadString: String?
        let underlyingError: Error?

        static func eventPayloadStringIsNotAValidUTF8Data(eventID: String?, eventName: String?, eventPayloadString: String?) -> Self {
            .init(
                errorType: .eventPayloadStringIsNotAValidUTF8Data,
                eventID: eventID,
                eventName: eventName,
                eventPayloadString: eventPayloadString,
                underlyingError: nil
            )
        }

        static func payloadParsingFailed(eventID: String?, eventName: String?, eventPayloadString: String?, underlyingError: Error) -> Self {
            .init(
                errorType: .payloadParsingFailed,
                eventID: eventID,
                eventName: eventName,
                eventPayloadString: eventPayloadString,
                underlyingError: nil
            )
        }
    }
}
