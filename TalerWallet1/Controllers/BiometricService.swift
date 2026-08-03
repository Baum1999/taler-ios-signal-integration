/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 *
 * @author Marc Stibane
 */
import SwiftUI
import LocalAuthentication

@MainActor
class BiometricService: ObservableObject {
    static let shared = BiometricService()
    @Published var canAuthenticate: Bool = true
    @Published var isAuthenticated = false
    @Published var authenticationError: String?

    @AppStorage("useAuthentication") var useAuthentication: Bool = false

    private var context: LAContext?

    func biometryType() -> LABiometryType {
        if context == nil {
            resetContext()
        }
        return context?.biometryType ?? .none
    }

    func authenticateUser() {
        let reason = resetContext()

        if useAuthentication {
            guard let context = context else {
                authenticationError = String(localized: "Failed to initialize authentication context.", comment: "FaceID")
                canAuthenticate = false
                return
            }
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
                authenticationError = String(localized: "Authentication is not available on this device.", comment: "FaceID")
                canAuthenticate = false
                return
            }
            canAuthenticate = true
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                Task { @MainActor in
                    if success {
                        self?.isAuthenticated = true
                        self?.authenticationError = nil
                    } else if let error = authenticationError as? LAError {
                        self?.authenticationError = self?.errorMessage(for: error)
                    } else {
                        self?.authenticationError = String(localized: "Unknown authentication error occurred.", comment: "FaceID")
                    }
                }
            }
        }
    }

    @discardableResult
    private func resetContext() -> String {
        let reason = String(localized: "Authenticate to access your money", comment: "FaceID")
        context = LAContext()
        context?.localizedReason = reason
        context?.localizedCancelTitle = String(localized: "Cancel", comment: "FaceID")
        context?.localizedFallbackTitle = String(localized: "Use Passcode", comment: "FaceID")
        return reason
    }

    private func errorMessage(for error: LAError) -> String {
        switch error.code {
            case .authenticationFailed:
                return String(localized: "Authentication failed. Please try again.", comment: "FaceID")
            case .userCancel:
                return String(localized: "You canceled the authentication.", comment: "FaceID")
            case .userFallback:
                return String(localized: "You chose to use the fallback option.", comment: "FaceID")
            case .systemCancel:
                return String(localized: "The system canceled the authentication.", comment: "FaceID")
            case .passcodeNotSet:
                return String(localized: "Passcode is not set on this device.", comment: "FaceID")
            case .biometryNotAvailable:
                return String(localized: "Biometric authentication is not available on this device.", comment: "FaceID")
            case .biometryNotEnrolled:
                return String(localized: "No biometrics are enrolled on this device.", comment: "FaceID")
            case .biometryLockout:
                return String(localized: "Biometric authentication is locked. Enter your passcode to unlock.", comment: "FaceID")
            default:
                return String(localized: "An unknown error occurred.", comment: "FaceID")
        }
    }
}
