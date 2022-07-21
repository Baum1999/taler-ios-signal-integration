//
//  ContentView.swift
//  Taler
//
//  Created by Jonathan Buchanan on 7/20/22.
//  Copyright © 2022 Taler. All rights reserved.
//

import SwiftUI

struct SidebarView: View {
    var onClose: () -> Void
    
    init(_onClose: @escaping () -> Void) {
        self.onClose = _onClose
    }
    
    var body: some View {
        VStack {
            Button(action: self.onClose) {
                Text("Close")
            }
            Divider()
            Text("Hello, World!")
            Divider()
            Spacer()
        }
        .background(Color.gray)
    }
}

struct ContentView: View {
    @State var sidebarVisible: Bool = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            Button {
                sidebarVisible = !sidebarVisible
            } label: {
                Text("dothething")
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            SidebarView {
                self.sidebarVisible = false
            }
                .frame(width: 100, alignment: .center)
                .offset(x: sidebarVisible ? 0 : -100)
                .animation(.easeInOut, value: sidebarVisible)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
