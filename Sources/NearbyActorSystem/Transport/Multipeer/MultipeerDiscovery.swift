//
//  MultipeerDiscovery.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation
import MultipeerConnectivity

public class MultipeerDiscovery: NSObject, MCNearbyServiceBrowserDelegate {
    public typealias Peer = MCPeerID
    
    let browser: MCNearbyServiceBrowser
    let currentPeer: MCPeerID
    let sessionProvider: SessionProvider
    let startTime = Date()
    
    init(currentPeer: MCPeerID, service: String, sessionProvider: SessionProvider) {
        self.sessionProvider = sessionProvider
        self.currentPeer = currentPeer
        browser = MCNearbyServiceBrowser(peer: currentPeer, serviceType: service)
        super.init()
        browser.delegate = self
    }

    public func start() {
        browser.startBrowsingForPeers()
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print(peerID)
        Task {
            let runningTime = -startTime.timeIntervalSinceNow
            let context = withUnsafeBytes(of: runningTime) { Data($0) }
            let session = await sessionProvider.sessionFor(peer: peerID)
            browser.invitePeer(peerID, to: session, withContext: context, timeout: 30)
        }
    }
    
    // A nearby peer has stopped advertising.
    @available(iOS 7.0, *)
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    
    // Browsing did not start due to an error.
    @available(iOS 7.0, *)
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print(error)
    }
}
