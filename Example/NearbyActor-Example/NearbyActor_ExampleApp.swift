//
//  NearbyActor_ExampleApp.swift
//  NearbyActor-Example
//
//  Created by Eugene Antropov on 07.11.2022.
//

import SwiftUI
import NearbyActorSystem

let actorSystem = MultipeerActorSystem()

@main
struct NearbyActor_ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
