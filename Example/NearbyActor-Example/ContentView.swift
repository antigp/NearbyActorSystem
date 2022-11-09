//
//  ContentView.swift
//  NearbyActor-Example
//
//  Created by Eugene Antropov on 07.11.2022.
//

import SwiftUI
import Combine
import NearbyActorSystem

struct ContentView: View {
    @StateObject var model = ConentViewModel()
    @State var currentPeer = ""
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Text(currentPeer)
            ForEach(model.models) { peer in
                HStack {
                    Text(peer.name).foregroundColor(peer.isAvaliable ? Color.black : Color.red)
//                    Text("\(peer.path)")
                }
            }
        }.task {
            currentPeer = actorSystem.receptionist.id.hostID.uuidString
            await model.start()
        }
    }
}

class ConentViewModel: ObservableObject {
    struct Model: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let path: Int
        let isAvaliable: Bool
    }
    
    var peers = [MCDistributedActor]()
    
    @Published
    var models = [Model]()
    
    private var cancelables = Set<AnyCancellable>()
    let testActor = MCDistributedActor(actorSystem: actorSystem)
    
    func start() async {
        Task {
            await actorSystem.receptionist.publish(testActor, scope: .none)
            let nearbyActors = await actorSystem.receptionist.waitFor(of: MCDistributedActor.self, scope: .none)
            for try await other in nearbyActors {
                do {
                    peers.append(other)
                    await updateModels()
                    _ = try await other.startGameWith(opponent: testActor)
                }
                catch  let error as InFlightRequestsHolder.RequestError where error == .timeOut {
                    print("Losed actor")
                }
            }
        }
        await actorSystem.transport.peers.onHostChange.sink { _ in
            Task {
                await self.updateModels()
            }
        }.store(in: &cancelables)
    }
    
    @MainActor
    func updateModels() async {
        models = await withTaskGroup(of: Model.self, body: { group in
            for peer in peers {
                group.addTask {
                    Model(name: peer.id.hostID.uuidString, path: await (try? peer.distance) ?? -1, isAvaliable: await peer.isAvaliable)
                }
            }
            return await group.reduce(into: [Model]()) { partialResult, item in
                partialResult.append(item)
            }
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
