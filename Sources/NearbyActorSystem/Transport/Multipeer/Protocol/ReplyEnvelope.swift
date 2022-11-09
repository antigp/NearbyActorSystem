//
//  ReplyEnvelope.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 20.08.2022.
//

import Foundation

public struct ReplyEnvelope: Sendable, Codable {
    let callID: CallID
    let caller: HostIdentity
    let callee: ActorIdentity
    let value: Data?
    let error: Data?
}
