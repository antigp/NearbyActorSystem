//
//  NearbyActorSystem.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 16.07.2022.
//

import Foundation
import Distributed

public protocol NearbyActorSystem: DistributedActorSystem, AnyObject where ActorID == ActorIdentity, SerializationRequirement == Codable {
    associatedtype Transport: NearbyTransport
    associatedtype Receptionist: NearbyDistributedReceptionist
    var transport: Transport { get }
    var resolveLock: NSLock { get }
    // TODO: Переделать на актор
    var managedActors: [ActorIdentity: any DistributedActor] { get set }
    var receptionist: Receptionist { get }
}

extension NearbyActorSystem where Self: DistributedActorSystem,
                                  ActorID == ActorIdentity,
                                  InvocationEncoder == NearbyActorSystemCallEncoder,
                                  InvocationDecoder == NearbyActorSystemCallDecoder,
                                  ResultHandler == NearbyActorSystemResultHandler<Transport>,
                                  SerializationRequirement == any Codable {    
    func handleInbound() {
        Task {
            for await envelope in self.transport.inboundEnveloperHandler() {
                guard let anyRecipient = resolveAny(id: envelope.callee) else {
                    print("[warn] \(#function) failed to resolve \(envelope.callee)")
                    return
                }
                let target = RemoteCallTarget(envelope.invocationTarget)
                var decoder = Self.InvocationDecoder(system: self, envelope: envelope)
                let handler = Self.ResultHandler(
                    callID: envelope.callID,
                    caller: envelope.caller,
                    callee: envelope.callee,
                    transport: self.transport
                )
                do {
                    try await executeDistributedTarget(
                        on: anyRecipient,
                        target: target,
                        invocationDecoder: &decoder,
                        handler: handler
                    )
                } catch let error as (Codable & Error) {
                    print("[error] failed to executeDistributedTarget [\(target)] on [\(anyRecipient)], error: \(error)")
                    try? await handler.onThrow(error: error)
                } catch {
                    try? await handler.onThrow(error: InFlightRequestsHolder.RequestError.unknownCallError)
                    print("[error] failed to executeDistributedTarget [\(target)] on [\(anyRecipient)], error: \(error)")
                }
            }
        }
        Task {
            for await newHost in self.transport.peers.insertHostSubject.asyncStream() {
                await receptionist.onNewConnection(hostIdentity: newHost)
            }
        }
        Task {
            for await losedHost in self.transport.peers.removeHostSubject.asyncStream() {
                await receptionist.onLoseConnection(hostIdentity: losedHost)
            }
        }
    }
    
    func resolveAny(id: ActorIdentity) -> (any DistributedActor)? {
        if id.localID == .receptionist {
            return self.receptionist
        }
        
        return managedActors[id]
    }
    
    public func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act? where Act : DistributedActor, ActorID == Act.ID {
        resolveLock.lock()
        defer { resolveLock.unlock() }
        if actorType == Receptionist.self {
            return nil
        }
        
        guard let found = managedActors[id] else {
            return nil // definitely remote, we don't know about this ActorID
        }
        
        guard let wellTyped = found as? Act else {
            throw NearbyActorSystemError.resolveFailedToMatchActorType(found: type(of: found), expected: Act.self)
        }
        
        return wellTyped
    }
    
    public func assignID<Act>(_ actorType: Act.Type) -> ActorIdentity where Act : DistributedActor, Act.ID == ActorIdentity {
        let stringType = _mangledTypeName(actorType) ?? "Unknow type"
        if Act.self == Receptionist.self {
            return .init(hostID: transport.currentIdentity, localID: UUID.receptionist, type: stringType)
        }
        return .init(hostID: transport.currentIdentity, localID: UUID(), type: stringType)
    }
    
    public func resignID(_ id: ActorIdentity) {
        resolveLock.lock()
        defer {
            resolveLock.unlock()
        }
        
        self.managedActors.removeValue(forKey: id)
    }
    
    public func actorReady<Act>(_ actor: Act) where Act : DistributedActor, Act.ID == ActorIdentity {
        self.resolveLock.lock()
        defer {
            self.resolveLock.unlock()
        }
        
        self.managedActors[actor.id] = actor
    }
    
    
    func _remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorIdentity,
          Err: Error,
          Res: Codable {
              guard await !transport.peers.allPeers().isEmpty else {
                  throw NearbyActorSystemError.noPeers
              }
              
              let callEnvelope = RemoteCallEnvelope(
                caller: transport.currentIdentity,
                callee: actor.id,
                callID: UUID(),
                invocationTarget: target.identifier,
                genericSubs: invocation.genericSubs,
                args: invocation.argumentData
              )
              let reply = try await transport.sendRemoteCall(envelope: callEnvelope)
              
              
              let decoder = JSONDecoder()
              decoder.userInfo[.actorSystemKey] = self
              
              guard let replyData = reply.value else {
                  throw NearbyActorSystemError.recivedEmptyResponseForNonVoid
              }
              
              do {
                  return try decoder.decode(Res.self, from: replyData)
              } catch {
                  throw NearbyActorSystemError.failedDecodingResponse(data: replyData, error: error)
              }
          }

    
    func _remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error {
              let callEnvelope = RemoteCallEnvelope(
                caller: transport.currentIdentity,
                callee: actor.id,
                callID: UUID(),
                invocationTarget: target.identifier,
                genericSubs: invocation.genericSubs,
                args: invocation.argumentData
              )
              let result = try await transport.sendRemoteCall(envelope: callEnvelope)
              if let errorData = result.error {
                  if let errorString = String(data: errorData, encoding: .utf8) {
                      throw NearbyActorSystemError.remoteError(errorString)
                  } else {
                      throw NearbyActorSystemError.notParsedError
                  }
              }
          }
    
}
