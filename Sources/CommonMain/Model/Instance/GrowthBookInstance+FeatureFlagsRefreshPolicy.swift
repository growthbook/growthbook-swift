//
//  GrowthBookInstance+FeatureFlagsRefreshPolicy.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 2/28/25.
//

import Foundation

extension GrowthBookInstance {
    /// GrowthBook feature flags refresh policy.
    public enum RefreshPolicy: Sendable, Equatable {
        /// No feature flags refresh.
        ///
        /// Will fetch feature flags once on SDK init.
        case noRefresh

        /// Refresh with polling requests.
        ///
        /// Will do polling request each interval.
        case repetitivePolling(interval: TimeInterval)

        /// Refresh with polling requests with respect to TTL in responses.
        ///
        /// Will do polling request each interval,
        /// but not earlier than the cache expiration date parsed from the API response.
        case respectfulPolling(interval: TimeInterval)

        /// Update with Server Side Events.
        case serverSideEvents

        // MARK: Public

        /// Default poling policy: `.respectfulPolling(interval: 3600.0)` (1 hour refresh rate).
        public static let `default`: Self = .respectfulPolling(interval: 60.0 * 60.0)

    }
}
