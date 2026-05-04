import XCTest
@testable import GrowthBook

class DecryptionUtilsTests: XCTestCase {

    // Vectors taken from the GrowthBook standard test suite (json.json "decrypt" section).
    let validPayload  = "m5ylFM6ndyOJA2OPadubkw==.Uu7ViqgKEt/dWvCyhI46q088PkAEJbnXKf3KPZjf9IEQQ+A8fojNoxw4wIbPX3aj"
    let validKey      = "Zvwv/+uhpFDznZ6SX28Yjg=="
    let expectedPlain = "{\"feature\":{\"defaultValue\":true}}"

    // Same payload, slightly different key (last two chars differ) — should fail.
    let wrongKey      = "Zvwv/+uhpFDznZ6SX39Yjg=="

    // MARK: - Happy path

    func testDecryptValidPayloadReturnsExpectedPlaintext() throws {
        let result = try DecryptionUtils.decrypt(payload: validPayload, encryptionKey: validKey)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), expectedPlain)
    }

    // MARK: - Invalid payload (no "." separator)

    func testDecryptPayloadWithoutDotThrowsInvalidPayload() {
        XCTAssertThrowsError(try DecryptionUtils.decrypt(payload: "nodothere", encryptionKey: validKey)) { error in
            guard let decryptionError = error as? DecryptionUtils.DecryptionError else {
                return XCTFail("Expected DecryptionError, got \(error)")
            }
            XCTAssertEqual(decryptionError, .invalidPayload)
        }
    }

    func testDecryptEmptyPayloadThrowsInvalidPayload() {
        XCTAssertThrowsError(try DecryptionUtils.decrypt(payload: "", encryptionKey: validKey)) { error in
            XCTAssertTrue(error is DecryptionUtils.DecryptionError)
        }
    }

    // MARK: - Wrong key produces decryption failure

    func testDecryptWithWrongKeyThrows() {
        XCTAssertThrowsError(try DecryptionUtils.decrypt(payload: validPayload, encryptionKey: wrongKey))
    }

    // MARK: - Invalid IV (not valid base64) → invalidPayload

    func testDecryptInvalidIVThrows() {
        XCTAssertThrowsError(
            try DecryptionUtils.decrypt(payload: "!!!notbase64!!!.validciphertext", encryptionKey: validKey)
        )
    }

    // MARK: - AESCryptor edge cases

    func testAESCryptorWithNilDataThrows() {
        let key = Data(repeating: 0x00, count: 16)
        let iv  = Data(repeating: 0x00, count: 16)
        XCTAssertThrowsError(try AESCryptor.decrypt(data: nil, key: key, iv: iv))
    }

    func testAESCryptorWithInvalidKeyLengthThrows() {
        let key  = Data(repeating: 0x00, count: 8)   // AES requires 16, 24, or 32 bytes
        let iv   = Data(repeating: 0x00, count: 16)
        let data = Data(repeating: 0x41, count: 16)
        XCTAssertThrowsError(try AESCryptor.decrypt(data: data, key: key, iv: iv))
    }
}
