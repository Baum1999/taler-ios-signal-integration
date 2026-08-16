/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
    @Binding var isCopied: Bool?
    let image: UIImage?
    let vertical: Bool
    let title: String?

    @Environment(\.isEnabled) private var isEnabled: Bool
    @EnvironmentObject private var controller: Controller

    @State private var scale: CGFloat = 1.0

    init(_ textToCopy: String, isCopied: Binding<Bool?>? = nil,
             vertical: Bool, image: UIImage? = nil) {
        self.textToCopy = textToCopy
        self._isCopied = isCopied ?? Binding.constant(nil)
        self.image = image
        self.vertical = vertical
        self.title = nil
    }

    init(_ textToCopy: String, isCopied: Binding<Bool?>? = nil,
         title: String, image: UIImage? = nil) {
        self.textToCopy = textToCopy
        self._isCopied = isCopied ?? Binding.constant(nil)
        self.image = image
        self.vertical = false
        self.title = title
    }

    func copyAction() -> Void {
        symLog.log(textToCopy)
        triggerPulse()
        controller.hapticFeedback(.medium)
        let pasteboard = UIPasteboard.general
        if let image {
//            pasteboard.image = image
            let strItem = [UTType.plainText.identifier : textToCopy]
            let imgItem = [UTType.image.identifier : image]
            pasteboard.items = [imgItem, strItem]       // iOS27 Notes.app crashes if text comes first!
        } else {
            pasteboard.string = textToCopy
        }
        if isCopied != nil {
            isCopied = true
        }
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
        .tint(WalletColors().primaryAccent)
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

    init(_ textToShare: String, image: UIImage? = nil) {
        self.textToShare = textToShare
        self.image = image
        self.title = String(localized: "Share")
    }
    init(_ textToShare: String, title: String, image: UIImage? = nil) {
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
        .tint(WalletColors().primaryAccent)
        .talerFont(.body)
        .scaleEffect(scale)
        .disabled(!isEnabled)
    }
}
// MARK: -
struct CopyShare: View {
    @Environment(\.isEnabled) private var isEnabled: Bool

    let textToCopy: String
    let image: UIImage?

    init(_ string: String, image: UIImage? = nil) {
        self.textToCopy = string
        self.image = image
    }

    var body: some View {
        let copyB = CopyButton(textToCopy, vertical: false, image: image)
                .buttonStyle(TalerButtonStyle(type: .bordered))
        let share = ShareButton(textToCopy, image: image)
                .buttonStyle(TalerButtonStyle(type: .bordered))

        let vLayout = VStack {
            copyB
            share
        }

        if #available(iOS 16.0, *) {
            let hLayout = HStack(spacing: HSPACING) {
                copyB
                share
            }
            ViewThatFits(in: .horizontal) {
                hLayout
                vLayout
            }
        } else {
            vLayout
        }
    }
}
// MARK: -
struct CopyShare_Previews: PreviewProvider {
    static var previews: some View {
        CopyShare("Hallö", image: nil)
    }
}
