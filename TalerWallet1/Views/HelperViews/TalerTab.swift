/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
 */
import SwiftUI
import os.log
import SymLog
import AVFoundation
import taler_swift

// MARK: -
extension Label where Title == Text, Icon == Image {
    init(_ tab: TalerTab) {
        if #available(iOS 26.0, *) {
            switch tab {
                case .actions:  self.init(tab.title, image: TALER_LOGO)
                default:        self.init(tab.title, systemImage: tab.sysImg)
            }
        } else {
            self.init(EMPTYSTRING, systemImage: tab.sysImg)
        }
    }
}
// MARK: - TabBar
enum TalerTab: Int, Hashable, CaseIterable {
    case balances = 0
    case actions
    case settings

//    var index: Int { self.rawValue }

    var title: String {
        switch self {
            case .balances: String(localized: "TitleBalances", defaultValue: "Balances")
            case .actions:  String(localized: "TitleActions", defaultValue: "Actions")
            case .settings: String(localized: "TitleSettings", defaultValue: "Settings")
        }
    }

    var image: Image {
        switch self {
            case .balances: return Image(systemName: BALANCES)                  // 􀣉  "chart.bar.xaxis"
            case .actions:  return Image(TALER_LOGO)
            case .settings: return Image(systemName: SETTINGS)                  // 􀍟 "gear"
        }
    }

//    func tabImage(_ size: CGFloat) -> some View {
//        self.image
//            .resizable()
//            .renderingMode(.template)
//            .tint(.black)
//            .aspectRatio(contentMode: .fit)
//            .frame(width: size, height: size)
//    }

    var sysImg: String {
        switch self {
            case .balances: BALANCES                                            // 􀣉  "chart.bar.xaxis"
            case .actions:  "bolt"
            case .settings: SETTINGS                                            // 􀍟 "gear"
        }
    }

    var label: Label<Text, Image> {
        Label(self)
    }
}
