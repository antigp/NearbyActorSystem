//
//  PeerPath.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation

public struct PeerPath<Peer>: Hashable, Equatable {
    let peerID: Peer
    let hostID: HostIdentity
    let distance: Int
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hostID)
        hasher.combine(distance)
    }
    
    static public func ==(lhs: PeerPath<Peer>, rhs: PeerPath<Peer>) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
