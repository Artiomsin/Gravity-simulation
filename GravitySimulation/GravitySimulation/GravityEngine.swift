import Foundation
import simd
import SceneKit

struct BodyState {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
}

class GravityEngine {
    var bodies: [CelestialBody]=[]
    var scene: SCNScene?
    
    let G: Float=1.0
    var dt: Float=0.02
    
    private(set) var timeline: [[BodyState]]=[]
    private(set) var currentIndex: Int=0
    
    init(bodies: [CelestialBody]=[], scene: SCNScene?=nil) {
        self.bodies=bodies
        self.scene=scene
    }
    
    func simulate(totalTime: Float) {
        
        for body in bodies { body.clearTrail() }
        
        timeline.removeAll()
        currentIndex=0
        
        let steps=Int(totalTime/dt)
        saveState()
        
        for _ in 0..<steps {
            step(showTrail: false)
            saveState()
        }
    }
    
    private func saveState() {
        let snapshot=bodies.map {
            BodyState(position: $0.position, velocity: $0.velocity)
        }
        timeline.append(snapshot)
    }
    
    
    private func step(showTrail: Bool) {
        var forces=Array(repeating: SIMD3<Float>(0, 0, 0), count: bodies.count)
        for i in 0..<bodies.count {
            for j in i+1..<bodies.count {
                let a=bodies[i]
                let b=bodies[j]
                
                let direction=b.position-a.position
                let distance=max(length(direction),0.1)
                let forceMagnitude=G*a.mass*b.mass/(distance*distance)
                let forceVector=normalize(direction)*forceMagnitude
                
                forces[i] += forceVector
                forces[j] -= forceVector
            }
        }
        
        for i in 0..<bodies.count {
            bodies[i].applyForce(forces[i], dt: dt)
        }
        
        for body in bodies {
            body.updatePosition(dt: dt, in: scene, showTrail: showTrail)
        }
    }
    
    
    func goTo(index: Int, showTrail: Bool=false) {
        guard index >= 0 && index < timeline.count else { return }
        currentIndex=index
        let snapshot=timeline[index]
        for i in 0..<bodies.count {
            bodies[i].position=snapshot[i].position
            bodies[i].velocity=snapshot[i].velocity
            bodies[i].updateNodePosition()
            if showTrail {
                bodies[i].updatePosition(dt: dt, in: scene, showTrail: true)
            }
        }
    }
    
    var totalFrames: Int { timeline.count }
}


