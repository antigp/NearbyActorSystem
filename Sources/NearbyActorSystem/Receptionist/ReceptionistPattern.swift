//
//  ReceptionistPattern.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 10.07.2022.
//

import Foundation
import Distributed
import Combine

public struct ReceptionistScope: OptionSet, Codable {
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public let rawValue: Int
    
    static public let none = ReceptionistScope(rawValue: 1 << 0)
}

public struct ScopedActor {
    let actor: any NearbyDistributedActor
    let scope: ReceptionistScope
}

public protocol NearbyDistributedActor<ActorSystem>: DistributedActor, Codable where ActorSystem: NearbyActorSystem, ActorSystem.SerializationRequirement == Codable, ActorSystem.ActorID == ActorIdentity, SerializationRequirement == Codable, ID == ActorIdentity {
    associatedtype ActorSystem
}

extension NearbyDistributedActor {
    nonisolated public var isAvaliable: Bool {
        get async {
            await actorSystem.transport.peers.allPeers().contains(where: { $0.hostID == id.hostID })
        }
    }
    
    nonisolated public var distance: Int {
        get async throws {
            guard let path = await actorSystem.transport.peers.allPeers().first(where: { $0.hostID == id.hostID })?.distance else {
                throw NearbyActorSystemError.noPeers
            }
            return path
        }
    }
}

public protocol NearbyDistributedReceptionist: NearbyDistributedActor {
    var toPublisActors: [ScopedActor] { get set }
    var publishedActors: [ActorIdentity: [any NearbyDistributedActor]] { get set }
    var knownReceptionist: [any NearbyDistributedReceptionist] { get set }
    var knownActors: [ScopedActor] { get set }
    var actorsSubject: PassthroughSubject<ScopedActor, Never> { get }
    distributed func inform<Act>(about actor: Act, scope: ReceptionistScope) where Act: NearbyDistributedActor
}

extension NearbyDistributedReceptionist {
    nonisolated func onNewConnection(hostIdentity: HostIdentity) async {
        let executionResult = await whenLocal {
            await $0._onNewConnection(hostIdentity: hostIdentity)
            return true
        }
        assert(executionResult ?? false, "onNewConnection can be executed only on local actor")
    }
    
    private func _onNewConnection(hostIdentity: HostIdentity) async {
        do {
            let remoteReceptionist = try Self.resolve(id: .init(hostID: hostIdentity, localID: .receptionist, type: "receptionist"), using: self.actorSystem)
            knownReceptionist.append(remoteReceptionist)
            for toPublishActor in toPublisActors {
                Task {
                    try await remoteReceptionist.inform(about: toPublishActor.actor, scope: toPublishActor.scope)                    
                }
            }
        } catch {
            fatalError("Failed add remote receptionist")
        }
    }
    
    nonisolated func onLoseConnection(hostIdentity: HostIdentity) async {
        let executionResult = await whenLocal {
            $0._onLoseConnection(hostIdentity: hostIdentity)
            return true
        }
        assert(executionResult ?? false, "onLoseConnection can be executed only on local actor")
    }
    
    private func _onLoseConnection(hostIdentity: HostIdentity) {
        publishedActors.removeValue(forKey: .init(hostID: hostIdentity, localID: .receptionist, type: "receptionist"))
        knownReceptionist.removeAll(where: { $0.id.hostID == hostIdentity })
        knownActors.removeAll(where: { $0.actor.id.hostID == hostIdentity })
    }
    
    nonisolated public func publish<Act>(_ actor: Act, scope: ReceptionistScope) async where Act: NearbyDistributedActor {
        let executionResult = await whenLocal {
            await $0._publish(actor, scope: scope)
            return true
        }
        assert(executionResult ?? false, "Publish can be executed only on local actor")
    }
    
    private func _publish<Act>(_ actor: Act, scope: ReceptionistScope) async where Act: NearbyDistributedActor {
        toPublisActors.append(.init(actor: actor, scope: scope))
        for remoteActor in knownReceptionist {
            do {
                try await remoteActor.inform(about: actor, scope: scope)
                publishedActors[remoteActor.id, default: []].append(actor)
            } catch {
                print("Failed inform actor to remote \(actor) \(error)")
            }
        }
    }
    
    nonisolated public func waitFor<Act>(of type: Act.Type, scope: ReceptionistScope) async -> AsyncStream<Act> where Act: NearbyDistributedActor {
        let executionResult = await whenLocal {
            await $0._waitFor(of: type, scope: scope)
        }
        guard let executionResult = executionResult else {
            preconditionFailure("Waiting can be executed only on local actor")
        }
        return executionResult
    }
    
    private func _waitFor<Act>(of type: Act.Type, scope: ReceptionistScope) async -> AsyncStream<Act> where Act: NearbyDistributedActor {
        Publishers.Merge(
            knownActors.publisher.filter({$0.scope.contains(scope)}).compactMap({ $0.actor as? Act }),
            actorsSubject.filter({$0.scope.contains(scope)}).compactMap({ $0.actor as? Act })
        )
        .eraseToAnyPublisher()
        .asyncStream()
    }
    
    fileprivate func _inform<Act>(about actor: Act, scope: ReceptionistScope) where Act: NearbyDistributedActor {
        self.knownActors.append(.init(actor: actor, scope: scope))
        self.actorsSubject.send(.init(actor: actor, scope: scope))
    }
}

@available(iOS 16.0, *)
public distributed actor MultipeerReceptionist: NearbyDistributedReceptionist {
    public typealias ActorSystem = MultipeerActorSystem
    public typealias ID = ActorIdentity
    public typealias SerializationRequirement = any Codable
    
    public var toPublisActors = [ScopedActor]()
    public var publishedActors = [ActorIdentity: [any NearbyDistributedActor]]()
    public var knownReceptionist = [any NearbyDistributedReceptionist]()
    public var knownActors = [ScopedActor]()
    public let actorsSubject = PassthroughSubject<ScopedActor, Never>()
    
    distributed public func inform<Act>(about actor: Act, scope: ReceptionistScope) where Act: NearbyDistributedActor {
        _inform(about: actor, scope: scope)
    }
}
