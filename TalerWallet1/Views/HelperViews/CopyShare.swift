/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import UniformTypeIdentifiers
import SwiftUI
import SymLog

@MainActor
struct FeedbackButton: View {
    private let symLog = SymLogV(0)
    let title: String?
    let image: UIImage?
    let isDisabled: Bool
    let action: () -> Void

    @EnvironmentObject private var controller: Controller
    @State private var scale: CGFloat = 1.0

    public init(_ title: String? = nil,
                  image: UIImage? = nil,
               disabled: Bool = false,
                 action: @escaping @MainActor () -> Void) {
        self.title = title
        self.image = image
        self.isDisabled = disabled
        self.action = action
    }

    private func triggerPulse() {
        // First scale down quickly
        withAnimation(.easeIn(duration: 0.1)) {
            scale = 0.8
        }
        // Then bounce back bigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.25)) {
                scale = 1.15
            }
        }
        // Finally settle to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.25)) {
                scale = 1.0
            }
        }
    }

    var body: some View {
        Button(title ?? EMPTYSTRING) {
            symLog.log(title ?? EMPTYSTRING)
            controller.hapticFeedback(.medium)
            action()
            triggerPulse()
        }
            .buttonStyle(TalerButtonStyle(type: .bordered, disabled: isDisabled))
    }
}
// MARK: -
@MainActor
struct CopyButton: View {
    private let symLog = SymLogV(0)
    let textToCopy: String
    @Binding var isCopied: Bool
    let image: UIImage?
    let vertical: Bool
    let title: String?

    @Environment(\.isEnabled) private var isEnabled: Bool
    @EnvironmentObject private var controller: Controller

    @State private var scale: CGFloat = 1.0

    init(textToCopy: String, isCopied: Binding<Bool>, vertical: Bool, image: UIImage? = nil) {
        self.textToCopy = textToCopy
        self._isCopied = isCopied
        self.image = image
        self.vertical = vertical
        self.title = nil
    }

    init(textToCopy: String, isCopied: Binding<Bool>, title: String, image: UIImage? = nil) {
        self.textToCopy = textToCopy
        self._isCopied = isCopied
        self.image = image
        self.vertical = false
        self.title = title
    }

    func copyAction() -> Void {
        symLog.log(textToCopy)
        triggerPulse()
        controller.hapticFeedback(.medium)
        let strings = [UTType.plainText.identifier : textToCopy]
        var items: [[String : Any]] = [strings]
        if let image {
            let images = [UTType.image.identifier : image]
            items.append(images)
        }
        UIPasteboard.general.setItems(items)
        isCopied = true
    }

    private func triggerPulse() {
        // First scale down quickly
        withAnimation(.easeIn(duration: 0.1)) {
            scale = 0.8
        }
        // Then bounce back bigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.25)) {
                scale = 1.15
            }
        }
        // Finally settle to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.25)) {
                scale = 1.0
            }
        }
    }

    var body: some View {
        Button(action: copyAction) {
            let image = Image(systemName: COPY1)    // 􀉁
                .accessibility(hidden: true)

            if vertical {
                VStack {
                    let shortCopy = String(localized: "Copy.short", defaultValue: "Copy", comment: "5 letters max, else abbreviate")
                    image
                    Text(shortCopy)
                }
            } else {
                let longCopy = String(localized: "Copy.long", defaultValue: "Copy", comment: "may be a bit longer")
                HStack {
                    image
                    Text(title ?? longCopy)
                }
            }
        }
        .tint(WalletColors().talerColor)
        .talerFont(.body)
        .scaleEffect(scale)
        .disabled(!isEnabled)
    }
}
// MARK: -
struct ShareType: Hashable {
    let textToShare: String
    let image: UIImage?
}
// MARK: -
@MainActor
struct ShareButton: View {
    private let symLog = SymLogV(0)
    let textToShare: String
    let image: UIImage?
    let title: String

    @State private var scale: CGFloat = 1.0

    init(textToShare: String, image: UIImage? = nil) {
        self.textToShare = textToShare
        self.image = image
        self.title = String(localized: "Share")
    }
    init(textToShare: String, title: String, image: UIImage? = nil) {
        self.textToShare = textToShare
        self.image = image
        self.title = title
    }

    @Environment(\.isEnabled) private var isEnabled: Bool
    @EnvironmentObject private var controller: Controller

    @MainActor
    func dismissAndPost() {
        dismissTop()
        let shareType = ShareType(textToShare: textToShare, image: image)
        let userInfo = [NOTIFICATIONSHARE: shareType]
        NotificationCenter.default.post(name: .ShareAction, object: nil, userInfo: userInfo)                // will trigger NavigationLink
    }

    func shareAction() -> Void {
        symLog.log(textToShare)
        controller.hapticFeedback(.soft)
        Task {
            // First scale down quickly
            withAnimation(.easeIn(duration: 0.1)) {
                scale = 0.8
            }
            // Then bounce back bigger
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.25)) {
                    scale = 1.15
                }
//              ShareSheet.shareSheet(textToShare: textToShare, image: image)
                dismissAndPost()
            }
            // Finally settle to normal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    scale = 1.0
                }
            }
        }
    }

    var body: some View {
        Button(action: shareAction) {
            HStack {
                Image(systemName: SHARE)        // 􀈂
                    .accessibility(hidden: true)
                Text(title)
            }
        }
        .tint(WalletColors().talerColor)
        .talerFont(.body)
        .scaleEffect(scale)
        .disabled(!isEnabled)
    }
}
// MARK: -
struct CopyShare: View {
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State var isCopied: Bool = false

    let textToCopy: String
    let image: UIImage?

    var body: some View {
        HStack {
            CopyButton(textToCopy: textToCopy, isCopied: $isCopied, vertical: false, image: image)
                .buttonStyle(TalerButtonStyle(type: .bordered))
            ShareButton(textToShare: textToCopy, image: image)
                .buttonStyle(TalerButtonStyle(type: .bordered))
        } // two buttons
    }
}
// MARK: -
struct CopyShare_Previews: PreviewProvider {
    static var previews: some View {
        CopyShare(textToCopy: "Hallö", image: nil)
    }
}
