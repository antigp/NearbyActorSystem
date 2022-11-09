//
//  RemoteCallEnvelope.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 20.08.2022.
//

import Foundation

public typealias CallID = UUID
public struct RemoteCallEnvelope: Sendable, Codable {
    let caller: HostIdentity
    let callee: ActorIdentity
    let callID: CallID
    let invocationTarget: String
    let genericSubs: [String]
    let args: [Data]
}
