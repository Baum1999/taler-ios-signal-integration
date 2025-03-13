/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Controller
 *
 * @author Marc Stibane
 */
import Foundation
import SwiftUI

class TabBarModel: ObservableObject {
    @Published var tabBarHidden = 0
    @Published var oimActive = 0 {
        didSet {
            if oimActive == 0 {
                if actionSelected == nil && tosView == nil {
                    tabBarHidden = 0
                }
            } else {
                tabBarHidden += 1
            }
        }
    }

    @Published var tosView: Int? = nil {
        didSet {
            if tosView != nil {
                tabBarHidden += 1
            } else if actionSelected == nil {
                tabBarHidden = oimActive
            }
        }
    }

    @Published var actionSelected: Int? = nil {
        didSet {
            if actionSelected != nil {
                tabBarHidden += 1
            } else if tosView == nil {
                tabBarHidden = oimActive
            }
        }
    }
}
