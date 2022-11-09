//
//  NearbyActorSystemResultHandler.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation
import Distributed

public struct NearbyActorSystemResultHandler<Tranport: NearbyTransport>: Distributed.DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = Codable
    
    let callID: CallID
    let caller: HostIdentity
    let callee: ActorIdentity
    let transport: Tranport
    
    public func onReturn<Success: SerializationRequirement>(value: Success) async throws {
        let encoder = JSONEncoder()
        let returnValue = try encoder.encode(value)
        let envelope = ReplyEnvelope(callID: callID, caller: caller, callee: callee, value: returnValue, error: nil)
        try await transport.sendRemoteReplay(envelope: envelope)
    }
    
    public func onReturnVoid() async throws {
        let envelope = ReplyEnvelope(callID: callID, caller: caller, callee: callee, value: nil, error: nil)
        try await transport.sendRemoteReplay(envelope: envelope)
    }
    
    public func onThrow<Err: Error>(error: Err) async throws {
        let envelope = ReplyEnvelope(callID: callID, caller: caller, callee: callee, value: nil, error: error.localizedDescription.data(using: .utf8) ?? Data())
        try await transport.sendRemoteReplay(envelope: envelope)
    }
}
