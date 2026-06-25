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
import CoreImage.CIFilterBuiltins


private let qrCornerRadius: CGFloat = 0.08
private let qrStripeWidth: CGFloat = 0.025
private let qrDataFraction: CGFloat = 0.88
private let qrLogoFraction: CGFloat = 0.30 * qrDataFraction

struct PosQRView: View {
    let text: String?
    let size: CGFloat

    @State private var qrImage: UIImage?
    @State private var showQR = false

    var body: some View {
        let cornerRadius = size * qrCornerRadius
        let qrSize = size * qrDataFraction
        let logoWidth = size * qrLogoFraction

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white)
                .frame(width: size, height: size)

            SpinningBorder(size: size)

            if showQR, let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrSize, height: qrSize)
                    .transition(.opacity)

                Image("taler-logo-qr")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoWidth)
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(.easeIn(duration: 0.3), value: showQR)
        .onAppear {
            if let text {
                generateQRAsync(from: text)
            }
        }
        .onChange(of: text) { newText in
            if let newText {
                generateQRAsync(from: newText)
            } else {
                showQR = false
                qrImage = nil
            }
        }
    }

    private func generateQRAsync(from string: String) {
        let targetSize = size * qrDataFraction
        Task.detached(priority: .userInitiated) {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(string.utf8)
            filter.correctionLevel = "H"
            guard let ciImage = filter.outputImage else { return }

            let modules = ciImage.extent.width
            let scale = max(1, Int(ceil(Double(targetSize) / modules)))
            let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))

            guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return }
            let image = UIImage(cgImage: cgImage)

            await MainActor.run {
                qrImage = image
                showQR = true
            }
        }
    }
}

private struct SpinningBorder: View {
    let size: CGFloat
    @State private var rotation: Double = 0

    private let stripeColor = Color(red: 0.188, green: 0.278, blue: 0.639)

    private var stripeSoft: Color {
        Color(
            red: 1.0 * 0.45 + 0.188 * 0.55,
            green: 1.0 * 0.45 + 0.278 * 0.55,
            blue: 1.0 * 0.45 + 0.639 * 0.55
        )
    }

    var body: some View {
        let cornerRadius = size * qrCornerRadius
        let stripeWidth = size * qrStripeWidth

        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white, location: 0.05),
                        .init(color: stripeSoft, location: 0.09),
                        .init(color: stripeColor, location: 0.12),
                        .init(color: stripeSoft, location: 0.16),
                        .init(color: .white, location: 0.21),
                        .init(color: .white, location: 0.50),
                        .init(color: stripeSoft, location: 0.55),
                        .init(color: stripeColor, location: 0.59),
                        .init(color: stripeSoft, location: 0.62),
                        .init(color: .white, location: 0.66),
                        .init(color: .white, location: 1.00),
                    ]),
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: stripeWidth
            )
            .frame(width: size, height: size)
            .onAppear {
                withAnimation(.linear(duration: 5.25).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
