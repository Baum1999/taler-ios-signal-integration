/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Controller
 *
 * @author Marc Stibane
 */
import Foundation
import SwiftUI

class NavigationModel: ObservableObject {
    @Published var tabBarHidden = 0

    @Published var tosView: Int? = nil {
        didSet {
            if tosView != nil {
                tabBarHidden += 1
            } else if actionSelected == nil {
                tabBarHidden = 0
            }
        }
    }

    @Published var actionSelected: Int? = nil {
        didSet {
            if actionSelected != nil {
                tabBarHidden += 1
            } else if tosView == nil {
                tabBarHidden = 0
            }
        }
    }
}
