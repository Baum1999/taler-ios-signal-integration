/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
        .accessibilityLabel("Main Menu")
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
    let isNavBarItem: Bool
    let action: () -> Void

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var showCameraAlert: Bool = false

    private var openSettingsButton: some View {
        Button("Open Settings") {
            showCameraAlert = false
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    let closingAnnouncement = AttributedString(localized: "Closing Camera")
    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            if #available(iOS 17.0, *) {
                AccessibilityNotification.Announcement(closingAnnouncement).post()
            }
            showCameraAlert = false
        }
    }
    var defaultPriorityAnnouncement = AttributedString(localized: "Opening Camera")
    var lowPriorityAnnouncement: AttributedString {
        var lowPriorityString = AttributedString ("Camera Loading")
        if #available(iOS 17.0, *) {
            lowPriorityString.accessibilitySpeechAnnouncementPriority = .low
        }
        return lowPriorityString
    }
    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString("Camera Active")
        if #available(iOS 17.0, *) {
            highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        }
        return highPriorityString
    }
    private func checkCameraAvailable() -> Void {
        // Open Camera when QR-Button was tapped
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(defaultPriorityAnnouncement).post()
        }
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                action()
                if #available(iOS 17.0, *) {
                    AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                }
            } else {
                showCameraAlert = true
            }
        })
    }

    var body: some View {
        let scanText = String(localized: "Scan QR code", comment: "Button title, a11y")
        let qr = "qrcode.viewfinder"
        let qrImage = Text("\(Image(systemName: qr))", comment: "QR Image")
        Button(action: checkCameraAvailable) {
            if isNavBarItem {
                if !minimalistic {
                    Text("Scan QR", comment: "Button title")
                        .talerFont(.title3)
                }
                qrImage.talerFont(.title2)
            } else if minimalistic {
                let width = UIScreen.screenWidth / 7
                qrImage.talerFont(.largeTitle)
                    .padding(.horizontal, width)
//                    .padding(.vertical)
            } else {
                HStack(spacing: 16) {
                    qrImage.talerFont(.title)
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

struct PlusButton : View  {
    let accessibilityLabelStr: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .talerFont(.title)
        .accessibilityLabel(accessibilityLabelStr)
    }
}

struct ArrowUpButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
        .talerFont(.title2)
        .accessibilityLabel("Scroll up")
    }
}

struct ArrowDownButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
        .talerFont(.title2)
        .accessibilityLabel("Scroll down")
    }
}

struct ReloadButton : View  {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
        .talerFont(.title)
        .accessibilityLabel("Reload")
        .disabled(disabled)
    }
}

struct TalerButtonStyle: ButtonStyle {
    enum TalerButtonStyleType {
        case plain
        case balance
        case bordered
        case prominent
    }
    var type: TalerButtonStyleType = .plain
    var dimmed: Bool = false
    var narrow: Bool = false
    var disabled: Bool = false
    var aligned: TextAlignment = .center
    var badge: String = EMPTYSTRING

    public func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        //        configuration.role = type == .prominent ? .primary : .normal          Only on macOS
        MyBigButton(foreColor: foreColor(type: type, pressed: configuration.isPressed, disabled: disabled),
                    backColor: backColor(type: type, pressed: configuration.isPressed, disabled: disabled),
                       dimmed: dimmed,
                configuration: configuration,
                     disabled: disabled,
                       narrow: narrow,
                      aligned: aligned,
                        badge: badge)
    }

    func foreColor(type: TalerButtonStyleType, pressed: Bool, disabled: Bool) -> Color {
        if type == .plain {
            return WalletColors().fieldForeground      // primary text color
        }
        return WalletColors().buttonForeColor(pressed: pressed,
                                             disabled: disabled,
                                            prominent: type == .prominent,
                                              balance: type == .balance)
    }
    func backColor(type: TalerButtonStyleType, pressed: Bool, disabled: Bool) -> Color {
        if type == .plain && !pressed {
            return Color.clear
        }
        return WalletColors().buttonBackColor(pressed: pressed,
                                             disabled: disabled,
                                            prominent: type == .prominent,
                                              balance: type == .balance)
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
            .buttonStyle(TalerButtonStyle(type: .balance, aligned: .trailing))
    }
}
#endif
