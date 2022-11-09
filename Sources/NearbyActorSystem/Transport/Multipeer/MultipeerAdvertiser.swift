//
//  MultipeerAdvertiser.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation
import MultipeerConnectivity

public class MultipeerAdvertiser: NSObject, MCNearbyServiceAdvertiserDelegate {
    public typealias Peer = MCPeerID
    let currentPeer: MCPeerID
    let advertiser: MCNearbyServiceAdvertiser
    let sessionProvider: SessionProvider
    let startTime = Date()
    
    init(currentPeer: MCPeerID, service: String, sessionProvider: SessionProvider) {
        self.sessionProvider = sessionProvider
        self.currentPeer = currentPeer
        self.advertiser = MCNearbyServiceAdvertiser(peer: currentPeer, discoveryInfo: ["startTime": "\(startTime.timeIntervalSinceReferenceDate)"], serviceType: service)
        super.init()
        self.advertiser.delegate = self
    }
    
    public func start() {
        advertiser.startAdvertisingPeer()
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task {
            let runningTime = -startTime.timeIntervalSinceNow
            let peerRunningTime = context?.withUnsafeBytes({ (rawPtr: UnsafeRawBufferPointer) in
                return rawPtr.load(as: TimeInterval.self)
            }) ?? .greatestFiniteMagnitude
            let isPeerOlder = (peerRunningTime > runningTime)
            let session = await sessionProvider.sessionFor(peer: peerID)
            invitationHandler(isPeerOlder, session)
        }
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print(error)
    }
}
