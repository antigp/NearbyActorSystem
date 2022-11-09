//
//  NearbyActorSystemCallDecoder.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 10.07.2022.
//

import Foundation
import Distributed
import os

public class NearbyActorSystemCallDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = Codable
    
    let decoder: JSONDecoder
    let envelope: RemoteCallEnvelope
    var argumentsIterator: Array<Data>.Iterator

    init(system: any DistributedActorSystem, envelope: RemoteCallEnvelope) {
        self.envelope = envelope
        self.argumentsIterator = envelope.args.makeIterator()
        let decoder = JSONDecoder()
        decoder.userInfo[.actorSystemKey] = system
        self.decoder = decoder
    }

    public  func decodeGenericSubstitutions() throws -> [Any.Type] {
        envelope.genericSubs.compactMap { name in
            _typeByName(name)
        }
    }

    public  func decodeNextArgument<Argument: Codable>() throws -> Argument {
        guard let data = argumentsIterator.next() else {
            throw NearbyActorSystemError.notEnoughArgumentsInEnvelope(expected: Argument.self)
        }

        return try decoder.decode(Argument.self, from: data)
    }

    public func decodeErrorType() throws -> Any.Type? {
        nil // not encoded, ok
    }

    public func decodeReturnType() throws -> Any.Type? {
        nil // not encoded, ok
    }
}
