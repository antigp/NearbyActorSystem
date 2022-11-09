//
//  InFlightRequestsHolder.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 20.08.2022.
//

import Foundation

public actor InFlightRequestsHolder {
    public enum RequestError: Error {
        case timeOut
        case noPeerForCallee
        case sendError
        case cancel
        case unknownCallError
    }
    
    var requests = [CallID: CheckedContinuation<ReplyEnvelope, Error>]()
    
    func addRequest(id: CallID, continuation: CheckedContinuation<ReplyEnvelope, Error>) {
        requests[id] = continuation
    }
    
    func handleResponse(id: CallID, response: ReplyEnvelope) {
        requests.removeValue(forKey: id)?.resume(returning: response)
    }
    
    func handleError(id: CallID, error: RequestError) {
        requests.removeValue(forKey: id)?.resume(throwing: error)
    }
}
