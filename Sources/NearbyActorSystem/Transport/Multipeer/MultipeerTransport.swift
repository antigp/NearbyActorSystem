//
//  MultipeerTransport.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 12.07.2022.
//

import Foundation
import MultipeerConnectivity
import Combine

public class MultipeerTransport: NSObject, NearbyTransport {
    public typealias Peer = MCPeerID
    
    let currentPeer: MCPeerID
    let sessionProvider: SessionProvider
    public let currentIdentity: HostIdentity
    public let discovery: MultipeerDiscovery
    public let advertiser: MultipeerAdvertiser
    public let inboundEnveloperSubject = PassthroughSubject<RemoteCallEnvelope, Never>()
    public let inboundReplaySubject = PassthroughSubject<ReplyEnvelope, Never>()
    public var peers = PeersContainer<Peer>()
    private var connectedHosts = Set<Peer>()
    var inFlightRequest = InFlightRequestsHolder()
    let subject = PassthroughSubject<Peer, Never>()
    
    override init() {
        currentIdentity = UUID()
        currentPeer = MCPeerID(displayName: currentIdentity.uuidString)
        sessionProvider = SessionProvider(currentPeer: currentPeer)
        discovery = MultipeerDiscovery(currentPeer: currentPeer, service: "mlt-trsprt", sessionProvider: sessionProvider)
        advertiser = MultipeerAdvertiser(currentPeer: currentPeer, service: "mlt-trsprt", sessionProvider: sessionProvider)
        
        super.init()
        Task {
            await sessionProvider.set(delegate: self)
        }
    }
    
    private func informKnowingPeers(to host: Peer) async throws {
        let knowingHost = await peers.allPeers()
            .filter({ $0.peerID != host })
            .filter({$0.distance < Int.max })
            .map( { IntroducePacket.Host(hostID: $0.hostID, distance: $0.distance )} )
        let introducePacket = IntroducePacket(currentHost: currentIdentity, khnownHosts: knowingHost)
        try await send(object: introducePacket, to: host)
    }
    
    private func shortestPeer(for host: HostIdentity) async -> PeerPath<Peer>? {
        return await peers.allPeers().sorted(by: { $0.distance < $1.distance }).first(where: { $0.hostID == host })
    }
    
    public func startTransport() {
        discovery.start()
        advertiser.start()
    }
    
    public func sendRemoteCall(envelope: RemoteCallEnvelope) async throws -> ReplyEnvelope {
        try await withTaskCancellationHandler {
            Task {
                await inFlightRequest.handleError(id: envelope.callID, error: .cancel)
            }
        } operation: {
            try await withThrowingTaskGroup(of: ReplyEnvelope.self) { group in
                group.addTask {[inFlightRequest] in
                    try await withCheckedThrowingContinuation { continuation in
                        Task {
                            await inFlightRequest.addRequest(id: envelope.callID, continuation: continuation)
                            
                            guard let peer = await self.shortestPeer(for: envelope.callee.hostID) else {
                                await inFlightRequest.handleError(id: envelope.callID, error: .noPeerForCallee)
                                return
                            }
                            do {
                                try await self.send(object: envelope, to: peer.peerID)
                            } catch {
                                await inFlightRequest.handleError(id: envelope.callID, error: .sendError)
                            }
                        }
                    }
                }
                group.addTask { [inFlightRequest] in
                    let timeOut = 10
                    try await Task.sleep(nanoseconds: UInt64(timeOut * 1_000_000_000))
                    try Task.checkCancellation()
                    await inFlightRequest.handleError(id: envelope.callID, error: .timeOut)
                    throw InFlightRequestsHolder.RequestError.timeOut
                }
                guard let result = try await group.next() else { fatalError("What did happen here?") }
                group.cancelAll()
                return result
            }
            
        }
    }
    
    private func send(object: Codable, to peer: Peer) async throws {
        let session = await sessionProvider.sessionFor(peer: peer)
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(object)
        try session.send(data, toPeers: [peer], with: .reliable)
    }
    
    public func sendRemoteReplay(envelope: ReplyEnvelope) async throws {
        guard let peer = await shortestPeer(for: envelope.caller) else { fatalError("No peer") }
        try await send(object: envelope, to: peer.peerID)
    }
    
}

extension MultipeerTransport: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task {
            switch(state) {
            case .notConnected:
                print("State - Not connected \(peerID)")
                connectedHosts.remove(peerID)
                await peers.remove(peer: peerID)
            case .connecting:
                print("State - Connecting \(peerID)")
            case .connected:
                print("State - Connected \(peerID)")
                connectedHosts.insert(peerID)
                try await self.informKnowingPeers(to: peerID)
            @unknown default:
                fatalError()
            }
        }
        
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task {
            let jsonDecoder = JSONDecoder()
            if let remoteCall = try? jsonDecoder.decode(RemoteCallEnvelope.self, from: data) {
                if remoteCall.callee.hostID == currentIdentity {
                    if await shortestPeer(for: remoteCall.caller) == nil {
                        await peers.add(path: PeerPath(peerID: peerID, hostID: remoteCall.caller, distance: Int.max))
                    }
                    inboundEnveloperSubject.send(remoteCall)
                } else {
                    Task {
                        guard let peer = await shortestPeer(for: remoteCall.callee.hostID) else {
                            try await send(
                                object: ReplyEnvelope(
                                    callID: remoteCall.callID,
                                    caller: remoteCall.caller,
                                    callee: remoteCall.callee,
                                    value: nil,
                                    error: NearbyActorSystemError.noPeers.localizedDescription.data(using: .utf8) ?? Data()
                                ),
                                to: peerID
                            )
                            return
                        }
                        do {
                            try await send(object: remoteCall, to: peer.peerID)
                        } catch {
                            try await send(
                                object: ReplyEnvelope(
                                    callID: remoteCall.callID,
                                    caller: remoteCall.caller,
                                    callee: remoteCall.callee,
                                    value: nil,
                                    error: NearbyActorSystemError.noPeers.localizedDescription.data(using: .utf8) ?? Data()
                                ),
                                to: peerID
                            )
                        }
                    }
                }
                return
            }
            if let remoteReplay = try? jsonDecoder.decode(ReplyEnvelope.self, from: data) {
                Task {
                    if remoteReplay.caller == currentIdentity {
                        await inFlightRequest.handleResponse(id: remoteReplay.callID, response: remoteReplay)
                    } else {
                        guard let peer = await shortestPeer(for: remoteReplay.caller) else {
                            fatalError("Should infrom bad way")
                        }
                        try await send(object: remoteReplay, to: peer.peerID)
                    }
                }
                return
            }
            if let introduce = try? jsonDecoder.decode(IntroducePacket.self, from: data) {
                await peers.removeAll(where: { $0.peerID == peerID } )
                await peers.addAll(paths: introduce.khnownHosts.map({ host in
                    PeerPath<Peer>.init(peerID: peerID, hostID: host.hostID, distance: host.distance + 1)
                }) + [PeerPath<Peer>(peerID: peerID, hostID: introduce.currentHost, distance: 0)])
                return
            }
            assertionFailure("Unknown data recived")
        }
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        assertionFailure("Non optional delegate function, should not be called")
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        assertionFailure("Non optional delegate function, should not be called")
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        assertionFailure("Non optional delegate function, should not be called")
    }
}
