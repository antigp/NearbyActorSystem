//
//  UUID+Receptionist.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation

extension UUID {
    static var receptionist: UUID {
        UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    }
}
