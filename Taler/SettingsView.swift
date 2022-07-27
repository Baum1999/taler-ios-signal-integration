//
//  SettingsView.swift
//  Taler
//
//  Created by Jonathan Buchanan on 7/27/22.
//  Copyright © 2022 Taler. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    var showSidebar: () -> Void
    var body: some View {
        NavigationView {
            Text("Settings")
                .navigationTitle("Settings")
                .navigationBarItems(
                    leading: Button(action: self.showSidebar, label: {
                        Image(systemName: "line.3.horizontal")
                    })
                )
        }
    }
    
    init(_showSidebar: @escaping () -> Void) {
        self.showSidebar = _showSidebar
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView {
            
        }
    }
}
