//
//  FeaturesModelProviderInterface.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

protocol FeaturesModelProviderDelegate: AnyObject, Sendable {
    func featuresProvider(_ provider: FeaturesModelProviderInterface, didUpdate featuresModel: DecryptedFeaturesDataModel)
    func featuresProvider(_ provider: FeaturesModelProviderInterface, didFailToUpdate error: Swift.Error)
}

protocol FeaturesModelProviderInterface: AnyObject, Sendable {
    var delegate: FeaturesModelProviderDelegate? { get set }

    func subscribeToFeaturesUpdates()
    func unsubscribeFromFeaturesUpdates()
}
