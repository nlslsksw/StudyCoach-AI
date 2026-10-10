//
//  Lern_KalenderApp.swift
//  Lern Kalender
//
//  Created by Nils on 27.02.26.
//

import SwiftUI

@main
struct Lern_KalenderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Kaufstatus beim Start holen: erkennt auch Käufe von
                    // einem anderen Gerät und Nutzer, die die App noch
                    // bezahlt haben, als sie Geld kostete.
                    await PurchaseService.shared.statusPruefen()
                    await PurchaseService.shared.produktLaden()
                }
        }
    }
}
