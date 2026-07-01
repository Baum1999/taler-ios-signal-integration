/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI

private let MFA_CODE_DIGITS = 8

struct ChallengeSelectionData: Identifiable {
    let id = UUID()
    let challenges: [MfaChallenge]
}

private enum ConfigMode: String, CaseIterable {
    case manual
    case qr
}

struct ConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onConfigured: () -> Void

    @State private var configMode: ConfigMode = .manual
    @State private var merchantUrlText: String = ""
    @State private var usernameText: String = ""
    @State private var tokenText: String = ""
    @State private var saveToken: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: ConfigField?

    @State private var challengeSelectionData: ChallengeSelectionData? = nil
    @State private var mfaChallenges: [MfaChallenge] = []
    @State private var mfaCombiAnd = false
    @State private var tanChallenge: MfaChallenge? = nil
    @State private var tanDigits: [String] = Array(repeating: "", count: MFA_CODE_DIGITS)
    @State private var tanErrorMessage: String? = nil
    @State private var mfaSolvedChallengeIds: [String] = []
    @State private var mfaBaseUrl: String = ""
    @State private var mfaUsername: String = ""
    @State private var mfaInitialSecret: String = ""
    @State private var mfaRemainingChallenges: [MfaChallenge] = []

    private enum ConfigField: Hashable {
        case merchantUrl, username, token
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $configMode) {
                Text(S.configModeManual).tag(ConfigMode.manual)
                Text(S.configModeQr).tag(ConfigMode.qr)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            switch configMode {
            case .manual:
                manualConfigBody
            case .qr:
                qrConfigBody
            }
        }
        .navigationTitle(S.configLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { initializeState() }
        .onChange(of: configManager.configResult) { result in
            guard isSubmitting else { return }
            switch result {
            case .success:
                isSubmitting = false
                errorMessage = nil
                onConfigured()
            case .error(let msg):
                isSubmitting = false
                errorMessage = msg
            case .none:
                break
            }
        }
        .sheet(item: $challengeSelectionData) { data in
            challengeSelectionContent(challenges: data.challenges)
        }
        .sheet(item: $tanChallenge) { challenge in
            TanInputSheet(
                challenge: challenge,
                digits: $tanDigits,
                errorMessage: $tanErrorMessage,
                onConfirm: { confirmTanCode() },
                onCancel: {
                    tanChallenge = nil
                    isSubmitting = false
                },
                onResend: { resendChallenge() }
            )
        }
    }

    // MARK: - QR Config Mode

    private var qrConfigBody: some View {
        VStack(spacing: 16) {
            Text(S.configQrHint)
                .font(.subheadline)
                .foregroundColor(.posOnSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            QRScannerView { result in
                handleQRResult(result)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
            .padding(.horizontal, 20)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.posError)
                    .padding(.horizontal, 20)
            }

            Spacer().frame(height: 20)
        }
    }

    private func handleQRResult(_ result: Result<String, Error>) {
        switch result {
        case .success(let scannedString):
            if let parsed = parseTalerPosUri(scannedString) {
                errorMessage = nil
                isSubmitting = true
                let configUrl = parsed.configUrl
                let token = parsed.token
                configManager.savePassword = true
                configManager.fetchConfig(url: configUrl, token: token, save: true)
            } else {
                errorMessage = S.configQrError
            }
        case .failure:
            errorMessage = S.configCameraPermission
        }
    }

    private struct PosSetupUri {
        let configUrl: String
        let token: String
    }

    private func parseTalerPosUri(_ raw: String) -> PosSetupUri? {
        guard raw.hasPrefix("taler-pos://") else { return nil }
        let withScheme = "https://" + raw.dropFirst("taler-pos://".count)
        guard let url = URL(string: withScheme) else { return nil }
        let host = url.host ?? ""
        let port = url.port.map { ":\($0)" } ?? ""
        let path = url.path
        let configUrl = "https://\(host)\(port)\(path)"
        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "token" })?.value ?? ""
        guard !token.isEmpty else { return nil }
        return PosSetupUri(configUrl: configUrl, token: token)
    }

    // MARK: - Manual Config Mode

    private var manualConfigBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(S.configMerchantUrl)
                        .font(.caption)
                        .foregroundColor(.posOnSurfaceVariant)
                    HStack {
                        Text("https://")
                            .foregroundColor(.posOnSurfaceVariant)
                        TextField("backend.example.com", text: $merchantUrlText)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .merchantUrl)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .username }
                    }
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.posOutline, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(S.configUsername)
                        .font(.caption)
                        .foregroundColor(.posOnSurfaceVariant)
                    TextField("Instance name", text: $usernameText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .token }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.posOutline, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(S.configPassword)
                        .font(.caption)
                        .foregroundColor(.posOnSurfaceVariant)
                    HStack {
                        Group {
                            if showPassword {
                                TextField("", text: $tokenText)
                            } else {
                                SecureField("", text: $tokenText)
                            }
                        }
                        .focused($focusedField, equals: .token)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.posOnSurfaceVariant)
                        }
                    }
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.posOutline, lineWidth: 1)
                    )
                }

                HStack {
                    Toggle(S.configSavePassword, isOn: $saveToken)
                        .labelsHidden()
                    Text(S.configSavePassword)
                        .font(.subheadline)

                    Spacer()

                    Button(action: submitManualConfig) {
                        if isSubmitting {
                            ProgressView()
                                .padding(.horizontal, 8)
                        } else {
                            Text(S.configOk)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.posPrimary)
                    .foregroundColor(.posOnPrimary)
                    .disabled(isSubmitting)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.posError)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Challenge selection

    private func challengeSelectionContent(challenges: [MfaChallenge]) -> some View {
        NavigationStack {
            List {
                Section {
                    Text(S.mfaChooseTitle)
                        .font(.subheadline)
                        .foregroundColor(.posOnSurfaceVariant)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(challenges, id: \.challengeId) { challenge in
                        Button {
                            challengeSelectionData = nil
                            handleSelectedChallenge(challenge)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: challenge.tanChannel == .sms ? "message.fill" : "envelope.fill")
                                    .foregroundColor(.posPrimary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(challenge.tanChannel == .sms ? "SMS" : "Email")
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.posOnSurface)
                                    Text(challenge.tanInfo)
                                        .font(.subheadline)
                                        .foregroundColor(.posOnSurfaceVariant)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.posOnSurfaceVariant)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(S.mfaChallengeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.mfaCancel) {
                        challengeSelectionData = nil
                        isSubmitting = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func initializeState() {
        merchantUrlText = configManager.merchantUrl
        saveToken = configManager.savePassword

        if !merchantUrlText.isEmpty {
            sanitizeMerchantUrlAndUpdateFields()
        }
    }

    private func submitManualConfig() {
        focusedField = nil
        isSubmitting = true
        errorMessage = nil

        let baseUrl = sanitizeMerchantUrlAndUpdateFields()
        guard !baseUrl.isEmpty else {
            isSubmitting = false
            errorMessage = S.configErrorEmptyUrl
            return
        }

        let username = usernameText.trimmingCharacters(in: .whitespaces)
        let token = tokenText.trimmingCharacters(in: .whitespaces)

        guard !token.isEmpty else {
            isSubmitting = false
            errorMessage = S.configErrorEmptyToken
            return
        }

        if !username.isEmpty {
            mfaBaseUrl = baseUrl
            mfaUsername = username
            mfaInitialSecret = token
            mfaSolvedChallengeIds = []
            fetchLimitedAccessTokenWithMfa()
        } else {
            let configUrl = baseUrl
            configManager.savePassword = saveToken
            configManager.fetchConfig(url: configUrl, token: token, save: true)
        }
    }

    private func fetchLimitedAccessTokenWithMfa() {
        Task {
            do {
                let limitedToken = try await configManager.fetchLimitedAccessToken(
                    baseUrl: mfaBaseUrl,
                    username: mfaUsername,
                    initialSecret: mfaInitialSecret,
                    challengeIds: mfaSolvedChallengeIds
                )

                let configUrl = "\(mfaBaseUrl)/instances/\(mfaUsername)"
                await MainActor.run {
                    configManager.savePassword = saveToken
                    configManager.fetchConfig(url: configUrl, token: limitedToken, save: true)
                }
            } catch let error as ChallengeRequiredError {
                await MainActor.run {
                    handleChallengeResponse(error.challengeResponse)
                }
            } catch let error as ApiError where error.isUnauthorized {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = S.configAuthError
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = S.configErrorNetwork
                }
            }
        }
    }

    private func handleChallengeResponse(_ response: ChallengesResponse) {
        mfaChallenges = response.challenges
        mfaCombiAnd = response.combiAnd

        if mfaCombiAnd {
            mfaRemainingChallenges = response.challenges
            solveNextChallenge()
        } else {
            if response.challenges.count == 1 {
                handleSelectedChallenge(response.challenges[0])
            } else {
                challengeSelectionData = ChallengeSelectionData(challenges: response.challenges)
            }
        }
    }

    private func solveNextChallenge() {
        guard let next = mfaRemainingChallenges.first else {
            fetchLimitedAccessTokenWithMfa()
            return
        }
        handleSelectedChallenge(next)
    }

    private func handleSelectedChallenge(_ challenge: MfaChallenge) {
        tanDigits = Array(repeating: "", count: MFA_CODE_DIGITS)
        tanErrorMessage = nil

        Task {
            do {
                try await configManager.requestChallenge(
                    baseUrl: mfaBaseUrl,
                    username: mfaUsername,
                    challengeId: challenge.challengeId
                )
                await MainActor.run {
                    tanChallenge = challenge
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = S.mfaRequestFailed(error.localizedDescription)
                }
            }
        }
    }

    private func confirmTanCode() {
        guard let challenge = tanChallenge else { return }
        let code = tanDigits.joined()
        let digitsOnly = code.filter(\.isNumber)

        guard digitsOnly.count == MFA_CODE_DIGITS else {
            tanErrorMessage = S.mfaChallengeCodeIncomplete(MFA_CODE_DIGITS)
            return
        }

        tanErrorMessage = nil

        Task {
            do {
                try await configManager.confirmChallenge(
                    baseUrl: mfaBaseUrl,
                    username: mfaUsername,
                    challengeId: challenge.challengeId,
                    tan: digitsOnly
                )

                await MainActor.run {
                    mfaSolvedChallengeIds.append(challenge.challengeId)
                    tanChallenge = nil

                    if mfaCombiAnd {
                        mfaRemainingChallenges.removeAll { $0.challengeId == challenge.challengeId }
                        solveNextChallenge()
                    } else {
                        fetchLimitedAccessTokenWithMfa()
                    }
                }
            } catch let error as ApiError {
                await MainActor.run {
                    switch error {
                    case .http(409, _, _):
                        tanErrorMessage = S.mfaChallengeInvalid
                        tanDigits = Array(repeating: "", count: MFA_CODE_DIGITS)
                    case .http(429, _, _):
                        tanErrorMessage = S.mfaChallengeRetry
                    default:
                        tanChallenge = nil
                        isSubmitting = false
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    tanChallenge = nil
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resendChallenge() {
        guard let challenge = tanChallenge else { return }
        tanDigits = Array(repeating: "", count: MFA_CODE_DIGITS)
        tanErrorMessage = nil

        Task {
            do {
                try await configManager.requestChallenge(
                    baseUrl: mfaBaseUrl,
                    username: mfaUsername,
                    challengeId: challenge.challengeId
                )
                await MainActor.run {
                    tanErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    tanErrorMessage = S.mfaResendFailed(error.localizedDescription)
                }
            }
        }
    }

    @discardableResult
    private func sanitizeMerchantUrlAndUpdateFields() -> String {
        let rawInput = merchantUrlText.trimmingCharacters(in: .whitespaces)
        if rawInput.isEmpty { return "" }

        let normalizedInput: String
        if rawInput.hasPrefix("http://") || rawInput.hasPrefix("https://") {
            normalizedInput = rawInput
        } else {
            normalizedInput = "https://\(rawInput)"
        }

        guard let url = URL(string: normalizedInput) else { return "" }

        let host = url.host ?? ""
        let port = url.port.map { ":\($0)" } ?? ""
        let baseHost = "\(host)\(port)"

        let segments = url.pathComponents.filter { $0 != "/" }
        if segments.count >= 2,
           segments[0].caseInsensitiveCompare("instances") == .orderedSame {
            usernameText = segments[1]
        }

        merchantUrlText = baseHost
        return baseHost.isEmpty ? "" : "https://\(baseHost)"
    }
}

// MARK: - TAN Input Sheet

private struct TanInputSheet: View {
    let challenge: MfaChallenge
    @Binding var digits: [String]
    @Binding var errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onResend: () -> Void

    @State private var codeText: String = ""

    private var channelLabel: String {
        switch challenge.tanChannel {
        case .sms: return "SMS"
        case .email: return "Email"
        }
    }

    private var channelInfo: String {
        challenge.tanInfo
    }

    private var isComplete: Bool {
        codeText.filter(\.isNumber).count == MFA_CODE_DIGITS
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(S.mfaChallengeMessage(channelLabel, channelInfo))
                    .font(.subheadline)
                    .foregroundColor(.posOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if isPhone {
                    HStack(spacing: 8) {
                        digitBoxesView
                            .contentShape(Rectangle())
                            .onLongPressGesture {
                                if let pasted = UIPasteboard.general.string {
                                    let digitsOnly = pasted.filter(\.isNumber)
                                    let clamped = String(digitsOnly.prefix(MFA_CODE_DIGITS))
                                    codeText = clamped
                                    syncDigits()
                                }
                            }
                        Button(S.mfaResendCode) { onResend() }
                            .font(.caption)
                            .foregroundColor(.posPrimary)
                    }
                } else {
                    digitBoxesView
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            if let pasted = UIPasteboard.general.string {
                                let digitsOnly = pasted.filter(\.isNumber)
                                let clamped = String(digitsOnly.prefix(MFA_CODE_DIGITS))
                                codeText = clamped
                                syncDigits()
                            }
                        }

                    Button(S.mfaResendCode) { onResend() }
                        .font(.subheadline)
                        .foregroundColor(.posPrimary)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.posError)
                }

                digitNumpad
                    .padding(.horizontal, 20)

                Button(action: onConfirm) {
                    Text(S.mfaVerify)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.posPrimary)
                .foregroundColor(.posOnPrimary)
                .disabled(!isComplete)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
            .navigationTitle(S.mfaChallengeCodeHint)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(S.mfaCancel) { onCancel() }
                }
            }
            .onAppear {
                codeText = digits.joined()
            }
        }
        .presentationDetents([.large])
    }

    private func syncDigits() {
        let chars = Array(codeText)
        for i in 0..<MFA_CODE_DIGITS {
            digits[i] = i < chars.count ? String(chars[i]) : ""
        }
    }

    private func appendDigit(_ d: String) {
        guard codeText.count < MFA_CODE_DIGITS else { return }
        codeText.append(d)
        syncDigits()
    }

    private func deleteLastDigit() {
        guard !codeText.isEmpty else { return }
        codeText.removeLast()
        syncDigits()
    }

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    private var digitNumpad: some View {
        Group {
            if isPhone {
                phoneNumpad
            } else {
                tabletNumpad
            }
        }
    }

    private func numpadDigitButton(_ digit: String) -> some View {
        Button { appendDigit(digit) } label: {
            Text(digit)
                .font(isPhone ? .body : .title2)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: isPhone ? 44 : 52)
                .background(Color.posSurface)
                .foregroundColor(.posOnSurface)
                .cornerRadius(isPhone ? 10 : 12)
                .overlay(
                    RoundedRectangle(cornerRadius: isPhone ? 10 : 12)
                        .stroke(Color.posOutlineVariant, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func numpadIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(isPhone ? .body : .title3)
                .frame(maxWidth: .infinity)
                .frame(height: isPhone ? 44 : 52)
                .background(Color.posSurface)
                .foregroundColor(.posOnSurface)
                .cornerRadius(isPhone ? 10 : 12)
                .overlay(
                    RoundedRectangle(cornerRadius: isPhone ? 10 : 12)
                        .stroke(Color.posOutlineVariant, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var phoneNumpad: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { n in numpadDigitButton("\(n)") }
                numpadIconButton(icon: "doc.on.clipboard") {
                    if let pasted = UIPasteboard.general.string {
                        let digitsOnly = pasted.filter(\.isNumber)
                        codeText = String(digitsOnly.prefix(MFA_CODE_DIGITS))
                        syncDigits()
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(6...9, id: \.self) { n in numpadDigitButton("\(n)") }
                numpadDigitButton("0")
                numpadIconButton(icon: "delete.left") { deleteLastDigit() }
            }
        }
    }

    private var tabletNumpad: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { col in
                        numpadDigitButton("\(row * 3 + col)")
                    }
                }
            }
            HStack(spacing: 8) {
                numpadIconButton(icon: "doc.on.clipboard") {
                    if let pasted = UIPasteboard.general.string {
                        let digitsOnly = pasted.filter(\.isNumber)
                        codeText = String(digitsOnly.prefix(MFA_CODE_DIGITS))
                        syncDigits()
                    }
                }
                numpadDigitButton("0")
                numpadIconButton(icon: "delete.left") { deleteLastDigit() }
            }
        }
    }

    private var digitBoxesView: some View {
        HStack(spacing: 6) {
            ForEach(0..<MFA_CODE_DIGITS, id: \.self) { index in
                if index == 4 {
                    Text("-")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.posOnSurfaceVariant)
                }

                let digitChar = index < codeText.count
                    ? String(codeText[codeText.index(codeText.startIndex, offsetBy: index)])
                    : ""
                let isCurrent = codeText.count == index

                Text(digitChar.isEmpty ? " " : digitChar)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(width: 36, height: 48)
                    .background(Color.posSurface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.posPrimary : Color.posOutline, lineWidth: isCurrent ? 2 : 1)
                    )
            }
        }
    }
}
