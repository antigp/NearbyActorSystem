//
//  ActorID.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 20.08.2022.
//

import Foundation
import Distributed
public typealias HostIdentity = UUID
public typealias LocalIdentity = UUID

public protocol ActorIdInitializable {
    init(hostID: HostIdentity, localID: LocalIdentity, type: String)
}

public struct ActorIdentity: Hashable, Sendable, Codable, CustomStringConvertible, CustomDebugStringConvertible, ActorIdInitializable {
    public let hostID: HostIdentity
    public let localID: LocalIdentity
    public let type: String
    
    public init(hostID: HostIdentity, localID: LocalIdentity, type: String) {
        self.hostID = hostID
        self.localID = localID
        self.type = type
    }
    
    public var id: String {
        return "\(type)-\(hostID)-\(localID)"
    }
        
    public var description: String {
        return "ActorID: \(id)"
    }

    public var debugDescription: String {
        return "\(Self.self)(\(self.description))"
    }
}
