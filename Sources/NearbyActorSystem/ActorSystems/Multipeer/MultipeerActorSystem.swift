//
//  MultipeerActorSystem.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 16.07.2022.
//

import Foundation
import Distributed

@available(iOS 16.0, *)
public final class MultipeerActorSystem: NearbyActorSystem, DistributedActorSystem, @unchecked Sendable {
    public typealias ActorID = ActorIdentity
    public typealias Receptionist = MultipeerReceptionist
    public typealias InvocationEncoder = NearbyActorSystemCallEncoder
    public typealias InvocationDecoder = NearbyActorSystemCallDecoder
    public typealias ResultHandler = NearbyActorSystemResultHandler<Transport>
    public typealias SerializationRequirement = any Codable

    public let transport = MultipeerTransport()
    public let resolveLock = NSLock()
    public var managedActors = [ActorIdentity : any DistributedActor]()
    public lazy var receptionist: MultipeerReceptionist = {
        MultipeerReceptionist(actorSystem: self)
    }()
    
    public init() {
        handleInbound()
        transport.startTransport()
    }
    
    public func makeInvocationEncoder() -> NearbyActorSystemCallEncoder { .init() }
    
    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error,
          Res: Codable {
              try await _remoteCall(on: actor, target: target, invocation: &invocation, throwing: throwing, returning: returning)
          }
    
    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws
      where Act: DistributedActor,
            Act.ID == ActorID,
            Err: Error {
              try await _remoteCallVoid(on: actor, target: target, invocation: &invocation, throwing: throwing)
          }
    
}
