//
//  PeersContainer.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 21.08.2022.
//

import Foundation
import Combine

public actor PeersContainer<Peer> where Peer: Equatable {
    let insertHostSubject = PassthroughSubject<HostIdentity, Never>()
    let removeHostSubject = PassthroughSubject<HostIdentity, Never>()
    public var onHostChange: AnyPublisher<HostIdentity, Never> {
        Publishers.Merge(insertHostSubject, removeHostSubject).eraseToAnyPublisher()
    }
    
    var peers = Set<PeerPath<Peer>>()
    
    func allPeers() -> Set<PeerPath<Peer>> {
        peers
    }
    
    func add(path: PeerPath<Peer>) {
        peers.insert(path)
        insertHostSubject.send(path.hostID)
    }
    
    func addAll(paths: [PeerPath<Peer>]) {
        for path in paths {
            peers.insert(path)
            insertHostSubject.send(path.hostID)
        }        
    }
    
    func remove(path: PeerPath<Peer>) {
        peers.remove(path)
        removeHostSubject.send(path.hostID)
    }
    
    func remove(peer: Peer) {
        let toRemove = peers.filter({$0.peerID == peer})
        toRemove.forEach({ remove(path: $0) })
    }
    
    func removeAll(where predicate: (PeerPath<Peer>) -> Bool) {
        let toRemove = peers.filter(predicate)
        toRemove.forEach({ remove(path: $0) })
    }
}
