//
//  NearbyTransport.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 12.07.2022.
//

import Foundation
import Combine

public protocol NearbyTransport: AnyObject where Peer: Equatable {
    associatedtype Peer
    
    var peers: PeersContainer<Peer> { get }
    var currentIdentity: HostIdentity { get }
    var inboundEnveloperSubject: PassthroughSubject<RemoteCallEnvelope, Never> { get }
    
    func sendRemoteCall(envelope: RemoteCallEnvelope) async throws -> ReplyEnvelope
    func sendRemoteReplay(envelope: ReplyEnvelope) async throws
    func inboundEnveloperHandler() -> AsyncStream<RemoteCallEnvelope>
    
    func startTransport()
}

extension NearbyTransport {
    public func inboundEnveloperHandler() -> AsyncStream<RemoteCallEnvelope> {
        return inboundEnveloperSubject.asyncStream()
    }
}


