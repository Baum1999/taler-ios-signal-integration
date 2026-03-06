/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import Foundation
import AVFoundation

extension ShapeStyle where Self == Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

struct HamburgerButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
//            Image(systemName: "sidebar.squares.leading")
        }
        .talerFont(.title)
        .accessibilityLabel(Text("Main Menu", comment: "a11y"))
    }
}

struct LinkButton: View {
    let destination: URL
    let hintTitle: String
    let buttonTitle: String
    let a11yHint: String
    let badge: String

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            if !minimalistic {      // show hint that the user should authorize on bank website
                Text(hintTitle)
                    .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                    .multilineTextAlignment(.leading)                   // otherwise
                    .listRowSeparator(.hidden)
            }
            Link(destination: destination) {
                HStack(spacing: 8.0) {
                    Image(systemName: "link")
                    Text(buttonTitle)
                }
            }
            .buttonStyle(TalerButtonStyle(type: .prominent, badge: badge))
            .accessibilityHint(a11yHint)
        }
    }
}

struct QRButton : View  {
    let hideTitle: Bool
    let action: () -> Void

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var showCameraAlert: Bool = false

    private var openSettingsButton: some View {
        Button("Open Settings") {
            showCameraAlert = false
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    let closingAnnouncement = String(localized: "Closing Camera", comment: "a11y")

    var defaultPriorityAnnouncement = String(localized: "Opening Camera", comment: "a11y")

    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString(localized: "Camera Active", comment: "a11y")
        if #available(iOS 17.0, *) {
            highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        }
        return highPriorityString
    }
    @MainActor
    private func checkCameraAvailable() -> Void {
        // Open Camera when QR-Button was tapped
        announce(defaultPriorityAnnouncement)

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                action()
                if #available(iOS 17.0, *) {
                    AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                } else {
                    let cameraActive = String(localized: "Camera Active", comment: "a11y")
                    announce(cameraActive)
                }
            } else {
                showCameraAlert = true
            }
        })
    }

    var body: some View {
        let dismissAlertButton = Button("Cancel", role: .cancel) {
            announce(closingAnnouncement)
            showCameraAlert = false
        }
        let scanText = String(localized: "Scan QR code", comment: "Button title, a11y")
        let qrImage = Image(systemName: QRBUTTON)
        let qrText = Text(qrImage)
        Button(action: checkCameraAvailable) {
            if hideTitle {
                qrImage
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.accentColor)
            } else if minimalistic {
                let width = UIScreen.screenWidth / 7
                qrText.talerFont(.largeTitle)
                    .padding(.horizontal, width)
            } else {
                HStack(spacing: 16) {
                    qrText.talerFont(.title)
                    Text(scanText)
                }.padding(.horizontal)
            }
        }
        .accessibilityLabel(scanText)
        .alert("Scanning QR-codes requires access to the camera",
               isPresented: $showCameraAlert,
                   actions: {   openSettingsButton
                                dismissAlertButton },
                   message: {   Text("Please allow camera access in settings.") }) // Scanning QR-codes
    }
}

struct DoneButton : View  {
    let titleStr: String?
    let accessibilityLabelStr: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let titleStr {
                Text(titleStr)
                    .tint(.accentColor)
            } else {
                Image(systemName: "checkmark")
            }
        }
        .tint(.accentColor)
        .talerFont(.title)
        .accessibilityLabel(accessibilityLabelStr)
    }
}

struct PlusButton : View  {
    let accessibilityLabelStr: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .tint(.accentColor)
        .talerFont(.title)
        .accessibilityLabel(accessibilityLabelStr)
    }
}

struct ZoomInButton : View  {
    let accessibilityLabelStr: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let name = ICONNAME_ZOOM_IN
            if UIImage(named: name) != nil {
                Image(name)
            } else {
                Image(systemName: SYSTEM_ZOOM_IN)
            }
        }
        .tint(.accentColor)
        .talerFont(.title)
        .accessibilityLabel(accessibilityLabelStr)
    }
}

struct ZoomOutButton : View  {
    let accessibilityLabelStr: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let name = ICONNAME_ZOOM_OUT
            if UIImage(named: name) != nil {
                Image(name)
            } else {
                Image(systemName: SYSTEM_ZOOM_OUT)
            }
        }
        .tint(.accentColor)
        .talerFont(.title)
        .accessibilityLabel(accessibilityLabelStr)
    }
}

struct BackButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let name = ICONNAME_INCOMING + ICONNAME_FILL
            let sysName = SYSTEM_INCOMING4 + ICONNAME_FILL
            if UIImage(named: name) != nil {
                Image(name)
            } else if UIImage(systemName: sysName) != nil {
                Image(systemName: sysName)
            } else {
                // TODO: ultralight vs black
                Image(systemName: FALLBACK_INCOMING)
            }
        }
        .tint(.accentColor)
        .talerFont(.largeTitle)
        .accessibilityLabel(Text("Back", comment: "a11y"))
    }
}

struct ForwardButton : View  {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        let myAction = {
            if enabled {
                action()
            }
        }
        Button(action: myAction) {
            let imageName = enabled ? ICONNAME_OUTGOING + ICONNAME_FILL
                                    : ICONNAME_OUTGOING
            let sysName   = enabled ? SYSTEM_OUTGOING4 + ICONNAME_FILL
                                    : SYSTEM_OUTGOING4
            if UIImage(named: imageName) != nil {
                Image(imageName)
            } else if UIImage(systemName: sysName) != nil {
                Image(systemName: sysName)
            } else {
                // TODO: ultralight vs black
                Image(systemName: FALLBACK_OUTGOING)
            }
        }
        .tint(.accentColor)
        .talerFont(.largeTitle)
        .accessibilityLabel(Text("Continue", comment: "a11y"))
    }
}

struct ArrowUpButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
        .tint(.accentColor)
        .talerFont(.title2)
        .accessibilityLabel(Text("Scroll up", comment: "a11y"))
    }
}

struct ArrowDownButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
        .tint(.accentColor)
        .talerFont(.title2)
        .accessibilityLabel(Text("Scroll down", comment: "a11y"))
    }
}

struct ReloadButton : View  {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
        .tint(.accentColor)
        .talerFont(.title)
        .accessibilityLabel(Text("Reload", comment: "a11y"))
        .disabled(disabled)
    }
}

struct TalerButtonStyle: ButtonStyle {
    enum TalerButtonStyleType {
        case plain
        case bordered
        case prominent
    }
    var type: TalerButtonStyleType = .plain
    var dimmed: Bool = false
    var narrow: Bool = false
    var disabled: Bool = false
    var aligned: TextAlignment = .center
    var badge: String = EMPTYSTRING

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        //        configuration.role = type == .prominent ? .primary : .normal          Only on macOS
        MyBigButton(foreColor: foreColor(type: type, pressed: configuration.isPressed,
                                       scheme: colorScheme, contrast: colorSchemeContrast, disabled: disabled),
                    backColor: backColor(type: type, pressed: configuration.isPressed, disabled: disabled),
                       dimmed: dimmed,
                configuration: configuration,
                     disabled: disabled,
                       narrow: narrow,
                      aligned: aligned,
                        badge: badge,
                       scheme: colorScheme,
                     contrast: colorSchemeContrast)
    }

    func foreColor(type: TalerButtonStyleType,
                pressed: Bool,
                 scheme: ColorScheme,
               contrast: ColorSchemeContrast,
               disabled: Bool) -> Color {
        if type == .plain {
            return WalletColors().fieldForeground      // primary text color
        }
        return WalletColors().buttonForeColor(pressed: pressed,
                                             disabled: disabled,
                                               scheme: scheme,
                                             contrast: contrast,
                                            prominent: type == .prominent)
    }
    func backColor(type: TalerButtonStyleType, pressed: Bool, disabled: Bool) -> Color {
        if type == .plain && !pressed {
            return Color.clear
        }
        return WalletColors().buttonBackColor(pressed: pressed,
                                             disabled: disabled,
                                            prominent: type == .prominent)
    }

    struct BackgroundView: View {
        let color: Color
        let dimmed: Bool
        var body: some View {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(color)
            .opacity(dimmed ? 0.6 : 1.0)
        }
    }

    struct MyBigButton: View {
//        var type: TalerButtonStyleType
        let foreColor: Color
        let backColor: Color
        let dimmed: Bool
        let configuration: ButtonStyle.Configuration
        let disabled: Bool
        let narrow: Bool
        let aligned: TextAlignment
        var badge: String
        var scheme: ColorScheme
        var contrast: ColorSchemeContrast

        var body: some View {
            let aligned2: Alignment = (aligned == .center) ? Alignment.center
                                    : (aligned == .leading) ? Alignment.leading
                                    : Alignment.trailing
            let hasBadge = badge.count > 0
            let buttonLabel = configuration.label
                                .multilineTextAlignment(aligned)
                                .talerFont(.title3)         //   narrow ? .title3 : .title2
                                .frame(maxWidth: narrow ? nil : .infinity, alignment: aligned2)
                                .padding(.vertical, 10)
                                .padding(.horizontal, hasBadge ? 0 : 6)
                                .foregroundColor(foreColor)
                                .background(BackgroundView(color: backColor, dimmed: dimmed))
                                .contentShape(Rectangle())      // make sure the button can be pressed even if backgroundColor == clear
                                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                                .animation(.spring(response: 0.1), value: configuration.isPressed)
                                .disabled(disabled)
            if hasBadge {
                let badgeColor: Color = (badge == CONFIRM_BANK) ? WalletColors().confirm
                                                                : WalletColors().attention
                let badgeV = Image(systemName: badge)
                                .talerFont(.caption)
                HStack(alignment: .top, spacing: 0) {
                    badgeV.foregroundColor(.clear)
                    buttonLabel
                    badgeV.foregroundColor(badgeColor)
                }
            } else {
                buttonLabel
            }
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let testButtonTitle = String("Placeholder")
        Button(testButtonTitle) {}
            .buttonStyle(TalerButtonStyle(type: .bordered, aligned: .trailing))
    }
}
#endif
