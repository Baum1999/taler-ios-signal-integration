/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI
import taler_swift

struct TextInputPopup: ViewModifier {
    @State var exchangeUrl: String = "https://"
    var onCancel: () -> Void
    var onOk: (String) -> Void
    
    init(cancel: @escaping () -> Void, ok: @escaping (String) -> Void) {
        self.onCancel = cancel
        self.onOk = ok
    }
    
    func body(content: Content) -> some View {
        return content
            .overlay(
                VStack {
                    Text("Add Exchange")
                    TextField("Exchange URL", text: $exchangeUrl)
                    HStack {
                        Button {
                            self.onCancel()
                        } label: {
                            Text("Cancel")
                        }
                        Button {
                            self.onOk(exchangeUrl)
                        } label: {
                            Text("Ok")
                        }
                    }
                }
                    .padding(8)
                    .frame(width: UIScreen.main.bounds.width - 100, height: 150, alignment: .center)
                    .background(Color.green)
                    .cornerRadius(8)
            , alignment: .center)
            .animation(.easeIn)
    }
}

extension View {
    func textInputPopup(cancel: @escaping () -> Void, ok: @escaping (String) -> Void, showing: Bool) -> some View {
        if showing {
            return AnyView(modifier(TextInputPopup(cancel: cancel, ok: ok)))
        } else {
            return AnyView(self)
        }
    }
}

struct PromptWithdrawView: View {
    let exchange: ExchangeItem
    let amount: Amount
    
    var body: some View {
        VStack {
            Text("Fees or something")
        }
            .navigationTitle("Withdraw Digital Cash")
    }
}

struct WithdrawView: View {
    let exchange: ExchangeItem
    @State var amount: String = ""
    
    var body: some View {
        VStack {
            Button {
                
            } label: {
                Text("Scan Taler QR Code")
            }
            Text("Or transfer manually:")
            HStack {
                TextField(exchange.currency, text: $amount)
            }
            NavigationLink {
                // TODO: Handle when the user inputs a non-valid amount
                /*do {
                    let am = try Amount.init(fromString: exchange.currency + ":" + amount)
                    PromptWithdrawView(exchange: exchange, amount: am)
                } catch {
                    
                }*/
            } label: {
                Text("Check Fees")
            }
        }
            .navigationTitle("Withdraw")
    }
}

struct ExchangeListView: View {
    @ObservedObject var exchangeManager: ExchangeManager
    @State var showPopup: Bool = false
    
    var body: some View {
        if exchangeManager.exchanges == nil {
            ProgressView()
                .navigationTitle("Exchanges")
                .onAppear {
                    exchangeManager.updateList()
                }
        } else if exchangeManager.loading {
            ProgressView()
                .navigationTitle("Exchanges")
        } else {
            let exchanges = exchangeManager.exchanges!
            if exchanges.count == 0 {
                Text("No Exchanges")
                    .navigationTitle("Exchanges")
                    .navigationBarItems(trailing: Button(action: {
                        withAnimation {
                            showPopup = true
                        }
                    }, label: {
                        Image(systemName: "plus")
                    }))
                    .textInputPopup(cancel: {
                        self.showPopup = false
                    }, ok: { exchangeUrl in
                        self.showPopup = false
                        exchangeManager.add(url: exchangeUrl)
                        print(exchangeUrl)
                    }, showing: showPopup)
            } else {
                List(exchanges, id: \.self) { exchange in
                    VStack {
                        Text(exchange.exchangeBaseUrl)
                            .frame(maxWidth: .infinity)
                        Text("Currency: " + exchange.currency)
                            .frame(maxWidth: .infinity)
                        NavigationLink {
                            WithdrawView(exchange: exchange)
                        } label: {
                            Text("Withdraw")
                        }
                    }
                }
                    .navigationTitle("Exchanges")
                    .navigationBarItems(trailing: Button(action: {
                        withAnimation {
                            showPopup = true
                        }
                    }, label: {
                        Image(systemName: "plus")
                    }))
                    .textInputPopup(cancel: {
                        self.showPopup = false
                    }, ok: { exchangeUrl in
                        self.showPopup = false
                        exchangeManager.add(url: exchangeUrl)
                        print(exchangeUrl)
                    }, showing: showPopup)
            }
        }
    }
}

/*
 * Exchanges
 * Manage list of exchanges known to this wallet
 *
 * Backup
 * Last backup: 5 hr. ago
 *
 * Developer Mode [toggle]
 * Shows more information intended for debugging
 *
 * Withdraw TESTKUDOS
 * Get money for testing
 *
 * Debug log
 * View/send internal log
 *
 * App Version
 * v0.9.0-dev.11 (fdroid 11)
 *
 * Wallet Core Version
 * v0.9.0-dev.11
 *
 * Supported Exchange Versions
 * 12:0:0
 *
 * Supported Merchant Versions
 * 2:0:1
 *
 * Reset Wallet (dangerous!)
 * Throws away your money
 */

struct SettingsItem<Content: View>: View {
    var name: String
    var description: String?
    var content: () -> Content
    
    init(name: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.name = name
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
            VStack {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.title2)
                if let desc = description {
                    Text(desc)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                }
            }
            content()
        }
            .padding([.bottom], 8)
    }
}

struct SettingsView: View {
    @EnvironmentObject var backend: BackendManager
    @AppStorage("developerMode") var developerMode: Bool = false
    
    var showSidebar: () -> Void
    var body: some View {
        NavigationView {
            VStack {
                SettingsItem(name: "Exchanges", description: "Manage list of exchanges known to this wallet") {
                    NavigationLink {
                        ExchangeListView(exchangeManager: backend.exchangeManager)
                    } label: {
                        Text("View")
                    }
                }
                SettingsItem(name: "Developer Mode", description: "Shows more information intended for debugging") {
                    Toggle(isOn: $developerMode) { }
                }
                if developerMode {
                    SettingsItem(name: "App Version") {
                        Text("v0.9.0-dev.11")
                    }
                    SettingsItem(name: "Wallet Core Version") {
                        Text("v0.9.0-dev.11")
                    }
                    SettingsItem(name: "Supported Exchange Versions") {
                        Text("12:0:0")
                    }
                    SettingsItem(name: "Supported Merchant Versions") {
                        Text("2:0:1")
                    }
                }
                Spacer()
            }
                .padding(16)
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
