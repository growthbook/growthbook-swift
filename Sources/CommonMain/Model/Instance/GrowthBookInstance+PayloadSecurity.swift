//
//  GrowthBookInstance+PayloadSecurity.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 2/28/25.
//

import Foundation

extension GrowthBookInstance
{
    /// GrowthBook payload type.
    public enum PayloadType: Sendable, Equatable
    {
        /// Plain text.
        ///
        /// Highly cacheable, but may leak sensitive info to users.
        case plainText

        /// Ciphered.
        ///
        /// Adds obfuscation while remaining cacheable.
        ///
        /// - Note: Requires GrowthBook subscription.
        case ciphered(encryptionKey: String)

        /// Remote evaluated.
        ///
        /// Completely hides business logic from users.
        ///
        /// - Note: Requires GrowthBook subscription.
        case remoteEvaluated(encryptionKey: String)

        // MARK: Public

        /// Default payload security: `.plainText`.
        public static let `default`: Self = .plainText

    }
}

extension GrowthBookInstance.PayloadType
{
  /// `true` if feature flags are remotely evaluated.
  public var isRemotelyEvaluated: Bool
  {
    switch self
    {
    case .remoteEvaluated:
      true
    case .ciphered,
         .plainText:
      false
    }
  }

  /// Encryption key.
  public var encryptionKey: String?
  {
    switch self
    {
    case let .ciphered(encryptionKey: encryptionKey),
         let .remoteEvaluated(encryptionKey: encryptionKey):
      encryptionKey
    case .plainText:
      .none
    }
  }
}
