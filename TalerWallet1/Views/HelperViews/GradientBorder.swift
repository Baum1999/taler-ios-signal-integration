/* MIT License
 * Copyright (c) 2024 Sucodee
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

fileprivate let nfcLogo = Image(systemName: NFCLOGO)        // 􀭹 "wave.3.right.circle"

struct NFCbutton: View {
    let title: String
    let action: () -> Void

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let logo = nfcLogo
        Button(minimalistic ? "\(logo)"
                            : "\(logo) \(title)") {
            action()
        }.buttonStyle(TalerButtonStyle(type: .prominent))
    }
}

@available(iOS 17.7, *)
struct BorderWithHCE<Content: View>: View {
    let talerURI: String
    let nfcHint: Bool
    let size: CGFloat
    let scanHints: (String, String)?
    var content: () -> Content

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true   // iOS 16 doesn't have NFC emulation
    @AppStorage("showQRauto17") var showQRauto17: Bool = false  // but iOS 17 does
    @StateObject private var tagEmulation = TagEmulation.shared
    @State private var showQRcode = false

    var body: some View {
//        let _ = Self._printChanges()
        let qrCode = Image(systemName: QRCODE)                                  // 􀖂 "qrcode"
        let qrButton = Button(minimalistic ? "\(qrCode)"
                                           : "\(qrCode) Show QR code") {
            withAnimation { showQRcode = true }
        }

        let hint = Group {
            if let scanHints {
                Text(scanHints.0)
                    .accessibilityLabel(scanHints.1)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
            }
        }

        if tagEmulation.canUseHCE {
            VStack {
                if nfcHint {    // QRCodeDetailView
                    if showQRcode {
                        if !minimalistic {
                            Text("\(nfcLogo) Tap for NFC")
                                .talerFont(.subheadline)
                                .padding(.vertical, -4)
                        }
//                        let screenWidth = UIScreen.screenWidth
                        content()
                            .onTapGesture(count: 1) { tagEmulation.emulateTag(talerURI) }
                        hint
                    } else {
                        NFCbutton(title: String(localized: "Start NFC")) {
                            tagEmulation.emulateTag(talerURI)
                        }
                        qrButton.buttonStyle(TalerButtonStyle(type: .bordered))
                    }
                } else {        // AboutView
                    content()
                        .onTapGesture(count: 2) { tagEmulation.emulateTag(talerURI) }
                }
            }.listRowSeparator(.hidden)
            .onDisappear() {
                tagEmulation.killEmulation()
            }.task {
                withAnimation {
                    if #available(iOS 17.7, *) {
                        showQRcode = showQRauto17
                    } else {
                        showQRcode = showQRauto16
                    }
                }
            }
        } else if showQRcode {
            content()
            hint
        } else {
            qrButton.buttonStyle(TalerButtonStyle(type: .prominent))
        }
    }
}
// MARK: -
extension FixedWidthInteger {
    var data: Data {
        let data = withUnsafeBytes(of: self) { Data($0) }
        return data
    }
}

struct BorderWithNFC<Content: View>: View {
    let totpString: String                    // might be a TOTP code
    let nfcHint: Bool
    let automaticNfc: Bool?
    let size: CGFloat
    let scanHints: (String, String)?
    var content: () -> Content

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true   // iOS 16 doesn't have NFC emulation
    @AppStorage("showQRauto17") var showQRauto17: Bool = false  // but iOS 17 does
    @State private var showTOTP = false
    @State private var didWriteTOTP = false
    @ObservedObject var nfcWriter = NFCWriter()

    var lockImage: Image {             // 􂆉 "lock.badge.clock"
        Image(ICONNAME_LOCKCLOCK, SYSTEM_LOCKCLOCK, fallback: FALLBACK_LOCK)
    }

    private var MAGIC_HEADER: Data {
        Data(fromUInt8Array: [
            0x42,   //  totp magic header
        ])
    } // 42

    var totpData: Data {
        var data = MAGIC_HEADER                     // 0x42 = "B"
        let totpArray = totpString.components(separatedBy: "\n")
        for totpCode in totpArray {
            if let totpInt = UInt32(totpCode) {
                let intData = totpInt.data
//                print(data, totpInt, intData)
                data.append(intData)
            }
        }
//        print(data)
        return data
    }

    var body: some View {
//        let _ = Self._printChanges()
        let totpCode = lockImage
        let totpButton = Button(minimalistic ? "\(totpCode)" : "\(totpCode) Show TOTP code") {
            withAnimation { showTOTP = true }
        }

        let hint = Group {
            if let scanHints {
                Text(scanHints.0)
                    .accessibilityLabel(scanHints.1)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
            }
        }

        if true {   // TODO: check for write capabilities
            VStack {
                if let automaticNfc, automaticNfc, !didWriteTOTP {
                    Text("\(nfcLogo) Point your iPhone to the NFC device")
                        .tint(WalletColors().primaryAccent)
                        .task {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                nfcWriter.write(totpData)
                                didWriteTOTP = true
                            }
                        }
                } else if nfcHint {    // QRCodeDetailView
                    if showTOTP {
                        if !minimalistic {
                            Text("\(nfcLogo) Tap for NFC")
                                .talerFont(.subheadline)
                                .padding(.vertical, -4)
                        }
//                        let screenWidth = UIScreen.screenWidth
                        GradientBorder(size: size + 20.0,
                                      color: WalletColors().primaryAccent,
                                 background: WalletColors().backgroundColor)
                        {
                            content()
                                .onTapGesture(count: 1) { nfcWriter.write(totpData) }
                        }
                        hint
                    } else {
                        NFCbutton(title: String(localized: "Write NFC")) {
                            nfcWriter.write(totpData)
                        }
                        totpButton.buttonStyle(TalerButtonStyle(type: .bordered))
                    }
                }
            }.listRowSeparator(.hidden)
                .onDisappear() {

                }.task {
                    withAnimation {
                        if #available(iOS 17.7, *) {
                            showTOTP = showQRauto17
                        } else {
                            showTOTP = showQRauto16
                        }
                    }
                }
        } else {
            if showTOTP {
                content()
                hint
            } else {
                totpButton.buttonStyle(TalerButtonStyle(type: .prominent))
            }
        }
    }
}
// MARK: -
// Use radius: 0 for rect instead of rounded rect
struct GradientBorder<Content: View>: View {
    let size: CGFloat
    let radius: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let background: Color
    var content: () -> Content

    @State var rotation: CGFloat = 0

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .frame(width: size, height: size).foregroundStyle(background)
                    .shadow(color: background.opacity(0.5), radius: 10, x: 0, y: 10)
                let gradient = Gradient(colors: [
                    color.opacity(INVISIBLE),
                    color,
                    color,
                    color.opacity(INVISIBLE)]
                )
                let linearGradient = LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom)
                let rotatingRect = Rectangle()
                    .frame(width: size*2, height: size/2)
                    .foregroundStyle(linearGradient)
                    .rotationEffect(.degrees(rotation))
                let border = lineWidth - 0.5
                rotatingRect
                    .mask {
                        RoundedRectangle(cornerRadius: radius - lineWidth/2, style: .continuous)
                            .stroke(lineWidth: lineWidth)
                            .frame(width: size - border, height: size - border)
                    }
                content()
            }
            .frame(width: size, height: size)
            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 720
            }
        }
    }
}
extension GradientBorder {
    init(size: CGFloat, radius: CGFloat = 20.0, lineWidth: CGFloat = 4.0, color: Color, background: Color, content: @escaping () -> Content) {
        self.size = size
        self.radius = radius
        self.lineWidth = lineWidth
        self.color = color
        self.background = background
        self.content = content
    }
}
// MARK: -
struct GradientBorder_Previews: PreviewProvider {
    static var previews: some View {

        GradientBorder(size: 260,
//                     radius: 1,
//                  lineWidth: 2,
                      color: .blue,
                 background: .yellow) {
            Text(verbatim: "Preview")
        }
    }
}
