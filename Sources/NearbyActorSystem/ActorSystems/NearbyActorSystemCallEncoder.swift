//
//  NearbyActorSystemCallEncoder.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 10.07.2022.
//

import Foundation
import Distributed
import os

public class NearbyActorSystemCallEncoder: DistributedTargetInvocationEncoder,
    @unchecked Sendable {
    public typealias SerializationRequirement = any Codable

    var genericSubs: [String] = []
    var argumentData: [Data] = []

    public func recordGenericSubstitution<T>(_ type: T.Type) throws {
        if let name = _mangledTypeName(T.self) {
            genericSubs.append(name)
        }
    }

    public func recordArgument<Value: Codable>(_ argument: RemoteCallArgument<Value>) throws {
        let data = try JSONEncoder().encode(argument.value)
        self.argumentData.append(data)
    }

    public func recordReturnType<R: Codable>(_ type: R.Type) throws {
        // noop, no need to record it in this system
    }

    public func recordErrorType<E: Error>(_ type: E.Type) throws {
        // noop, no need to record it in this system
    }

    public func doneRecording() throws {
        // noop, nothing to do in this system
    }

}

