//
//  FeaturesModelPollingProvider.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

final class FeaturesModelPollingProvider {
    enum Mode {
        case respectful
        case repetitive
    }

    private class MutableState {
        var isEnabled: Bool = false
        var timer: TimerInterface?
        var featuresResponseStaleInSeconds: Int?
        weak var delegate: FeaturesModelProviderDelegate?

        deinit {
            timer?.disable()
        }
    }

    private let mutableState: Protected<MutableState> = .init(.init())
    private let featuresModelFetcher: FeaturesModelFetcherInterface
    private let pollingInterval: TimeInterval
    private let mode: Mode

    init(
        featuresModelFetcher: FeaturesModelFetcherInterface,
        pollingInterval: TimeInterval,
        mode: Mode
    ) {
        self.featuresModelFetcher = featuresModelFetcher
        self.pollingInterval = pollingInterval
        self.mode = mode

        let timer = CrossPlatformTimer(timerInterval: pollingInterval) { [weak self] in
            self?.fetchFeatures()
        }

        mutableState.write(\.timer, timer)
    }

    deinit {
        unsubscribeFromFeaturesUpdates()
        mutableState.write(\.timer, .none)
    }

    private func handleFeaturesResponseStaleInSeconds(_ staleInSeconds: Int) {
        guard mode == .respectful else { return }
        mutableState.read(\.timer)?.rescheduleNotEarlierThan(in: staleInSeconds)
    }

    private func fetchFeatures() {
        featuresModelFetcher.fetchFeatures { [weak self] result in
            guard let self, let delegate = self.delegate else { return }

            switch result {
            case let .success(response):
                logger.debug("Successfully fetched features")
                delegate.featuresProvider(self, didUpdate: response.decryptedFeaturesDataModel)
                self.handleFeaturesResponseStaleInSeconds(response.expiresInSeconds)
            case let .failure(error):
                logger.error("Failed to fetch features: \(error)")
                delegate.featuresProvider(self, didFailToUpdate: error)
            }
        }
    }
}

extension FeaturesModelPollingProvider: FeaturesModelProviderInterface {
    var delegate: (any FeaturesModelProviderDelegate)? {
        get { mutableState.read(\.delegate) }
        set { mutableState.write(\.delegate, newValue) }
    }

    func subscribeToFeaturesUpdates() {
        mutableState.write { mutableState in
            mutableState.isEnabled = true
            mutableState.timer?.enable()
        }
    }

    func unsubscribeFromFeaturesUpdates() {
        mutableState.write { mutableState in
            mutableState.isEnabled = false
            mutableState.timer?.disable()
        }
    }
}

extension FeaturesModelPollingProvider {
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
