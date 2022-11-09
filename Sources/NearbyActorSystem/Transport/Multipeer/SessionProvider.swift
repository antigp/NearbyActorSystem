//
//  SessionProvider.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 20.08.2022.
//

import Foundation
import MultipeerConnectivity

actor SessionProvider {
    var currentPeer: MCPeerID
    var sessionsHandler = [MCPeerID: MCSession]()
    weak var sessionDelegate: MCSessionDelegate?
    
    init(currentPeer: MCPeerID) {
        self.currentPeer = currentPeer
    }
    
    func set(delegate: MCSessionDelegate) {
        sessionDelegate = delegate
    }
    
    func sessionFor(peer: MCPeerID) -> MCSession {
        if let session = sessionsHandler[peer] {
            return session
        }
        let newSession = MCSession(peer: currentPeer)
        newSession.delegate = sessionDelegate
        sessionsHandler[peer] = newSession
        return newSession
    }
}
