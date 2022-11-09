# NearbyActorSystem

This library provides an easy to use implementation of a *DistributedActorSystem* Swift 5.7 language feature based on MultiPeer Connectivity framework.

### What are Distributed Actors?

Distributed actors are an extension of the "local only" actor model offered by Swift with its *actor* keyword.

Distributed actors are declared using the *distributed actor* keywords (and importing the *Distributed* module),
and enable the declaring of *distributed func* methods inside such actor. Such methods may then be invoked remotely,
from other peers in a distributed actor system.

The distributed actor _language feature_ does not include any specific _runtime_, and only defines the language and semantic rules surrounding distributed actors.
# Usage
### Create actor system
```swift
 let actorSystem = MultipeerActorSystem()
```

### Create Actor
```swift
distributed actor DistributedActor: NearbyDistributedActor {
    public typealias ActorSystem = MultipeerActorSystem
    typealias SerializationRequirement = any Codable
    
    distributed func actorFunc() async {
        //...
    }
}
```
### Find nearby actors
You can easily discover all nearby peers with *receptionist* or choose to transfer actor id manually in any other way.

### Receptionist
Implements all the logic needed to discover nearby peers.

Register your actor with *receptionist* on one device
```swift
    await actorSystem.receptionist.publish(testActor, scope: .none)
```
Discover your actor via receptionist on another device
```swift
    let nearbyActors = await actorSystem.receptionist.waitFor(of: MCDistributedActor.self, scope: .none)
    for try await other in nearbyActors {
    //...
    }
```

# Plans
- [x] Actor via MultiPeer Connectivity framework
- [ ] Chain communication through multiple peers
- [ ] Actor via Bluetooth LE 
- [ ] Encryption
