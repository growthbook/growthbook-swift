//
//  File.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/11/25.
//

import Foundation

protocol SystemStateObserverForTimerDelegate: AnyObject, Sendable {
    func systemDidBecomeActive()
    func systemWillBecomeInactive()
}

protocol SystemStateObserverForTimerInterface: AnyObject, Sendable {
    var delegate: SystemStateObserverForTimerDelegate? { get set }
    var canScheduleTimer: Bool { get }
}
