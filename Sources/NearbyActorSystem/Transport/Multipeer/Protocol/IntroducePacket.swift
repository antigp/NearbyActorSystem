//
//  IntroducePacket.swift
//  MultipeerActor
//
//  Created by Eugene Antropov on 19.08.2022.
//

import Foundation

struct IntroducePacket: Codable {
    let currentHost: HostIdentity
    let khnownHosts: [Host]
    struct Host: Codable {
        let hostID: HostIdentity
        let distance: Int
    }
}
