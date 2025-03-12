//
//  FeaturesModelProviderBuilder.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

enum FeaturesModelProviderBuilder {
    static func build(
        refreshPolicy: GrowthBookInstance.RefreshPolicy,
        serverSideEventsURL: URL,
        featuresDataParser: FeaturesDataParserInterface,
        featuresModelFetcher: FeaturesModelFetcherInterface
    ) -> FeaturesModelProviderInterface?
    {
        switch refreshPolicy {
        case .noRefresh:
            return .none
        case let .repetitivePolling(interval: interval):
            return FeaturesModelPollingProvider(
                featuresModelFetcher: featuresModelFetcher,
                pollingInterval: interval,
                mode: .repetitive
            )
        case let  .respectfulPolling(interval: interval):
            return FeaturesModelPollingProvider(
                featuresModelFetcher: featuresModelFetcher,
                pollingInterval: interval,
                mode: .respectful
            )
        case .serverSideEvents:
            return FeaturesModelServerSideEventsProvider(
                serverSideEventsURL: serverSideEventsURL,
                featuresDataParser: featuresDataParser
            )
        }
    }
}
