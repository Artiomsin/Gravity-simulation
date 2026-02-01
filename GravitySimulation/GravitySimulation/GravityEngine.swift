import Foundation
import simd
import SceneKit
import UIKit

struct BodyState {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var collisionWith: [Int] = []
}

class GravityEngine {
    var bodies: [CelestialBody] = []
    var scene: SCNScene?

    let G: Float = 1.0
    var dt: Float = 0.02

    private(set) var timeline: [[BodyState]] = []
    private(set) var currentIndex: Int = 0

    init(bodies: [CelestialBody] = [], scene: SCNScene? = nil) {
        self.bodies = bodies
        self.scene = scene
    }

    func simulate(totalTime: Float) {
        for body in bodies { body.clearTrail() }
        timeline.removeAll()
        currentIndex = 0

        let steps = Int(totalTime / dt)
        saveState()

        for _ in 0..<steps {
            step(showTrail: false)
        }
    }

    private func step(showTrail: Bool) {
        var forces = Array(repeating: SIMD3<Float>(0,0,0), count: bodies.count)
        for i in 0..<bodies.count {
            for j in i+1..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                let dir = b.position - a.position
                let dist = max(length(dir), 0.1)
                let fMag = G * a.mass * b.mass / (dist * dist)
                let fVec = normalize(dir) * fMag
                forces[i] += fVec
                forces[j] -= fVec
            }
        }

        for i in 0..<bodies.count {
            bodies[i].applyForce(forces[i], dt: dt)
        }

        for body in bodies {
            body.updatePosition(dt: dt, in: scene, showTrail: showTrail)
        }

        var collisions: [(Int,Int)] = []
        for i in 0..<bodies.count {
            for j in i+1..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                let minDist = a.collisionRadius + b.collisionRadius
                let dist = length(a.position - b.position)
                
                if dist < minDist {
                    collisions.append((i,j))

                    let normal = normalize(b.position - a.position)
                    let relVel = a.velocity - b.velocity
                    let velAlongNormal = dot(relVel, normal)
                    guard velAlongNormal < 0 else { continue }
                    let restitution: Float = 0.8
                    let impulse = -(1+restitution)*velAlongNormal / (1/a.mass + 1/b.mass)
                    let impulseVector = impulse * normal
                    a.velocity += impulseVector / a.mass
                    b.velocity -= impulseVector / b.mass
                }
            }
        }

        var snapshot: [BodyState] = []
        for i in 0..<bodies.count {
            let collidedWith = collisions.filter { $0.0 == i }.map {$0.1} + collisions.filter { $0.1 == i }.map {$0.0}
            snapshot.append(BodyState(position: bodies[i].position, velocity: bodies[i].velocity, collisionWith: collidedWith))
        }
        timeline.append(snapshot)
    }
    
    private func saveState() {
        let snapshot = bodies.map { BodyState(position: $0.position, velocity: $0.velocity) }
        timeline.append(snapshot)
    }

    func flashNode(_ body: CelestialBody) {
        let node = body.node
        node.geometry?.firstMaterial?.emission.contents = UIColor.yellow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            node.geometry?.firstMaterial?.emission.contents = body.originalColor
        }
    }

    private func shockwaveSize(for a: CelestialBody, _ b: CelestialBody) -> CGFloat {
        let massFactor = sqrt(a.mass + b.mass)
        let radiusFactor = a.collisionRadius + b.collisionRadius
        let size = CGFloat(radiusFactor * massFactor * 0.5)
        return max(size, 0.1)
    }

    func showShockwave(at position: SIMD3<Float>, size: CGFloat, in parent: SCNNode?) {
        guard let parent = parent else { return }
        let ring = SCNTorus(ringRadius: size, pipeRadius: size * 0.15)
        ring.firstMaterial?.diffuse.contents = UIColor.white
        ring.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.6)
        let node = SCNNode(geometry: ring)
        node.position = SCNVector3(position.x, position.y, position.z)
        parent.addChildNode(node)

        let scale = SCNAction.scale(to: 1.5, duration: 0.4)
        let fade = SCNAction.fadeOut(duration: 0.4)
        let group = SCNAction.group([scale, fade])
        let seq = SCNAction.sequence([group, .removeFromParentNode()])
        node.runAction(seq)
    }

    func goTo(index: Int, showTrail: Bool = false) {
        guard index >= 0 && index < timeline.count else { return }
        currentIndex = index
        let snapshot = timeline[index]

        for i in 0..<bodies.count {
            bodies[i].position = snapshot[i].position
            bodies[i].velocity = snapshot[i].velocity
            bodies[i].updateNodePosition()

            if showTrail, let scene = scene {
                bodies[i].updatePosition(dt: dt, in: scene, showTrail: true)
            }

            for j in snapshot[i].collisionWith {
                if i < j {
                    flashNode(bodies[i])
                    flashNode(bodies[j])
                    let size = shockwaveSize(for: bodies[i], bodies[j])
                    showShockwave(at: (bodies[i].position + bodies[j].position)/2, size: size, in: bodies[i].node.parent)

                }
            }
        }
    }
    
    func gravitationalForce(on body: CelestialBody) -> SIMD3<Float> {
        var totalForce = SIMD3<Float>(0, 0, 0)

        for other in bodies {
            guard other !== body else { continue }
            let dir = other.position - body.position
            let dist = max(length(dir), 0.1)
            let fMag = G * body.mass * other.mass / (dist * dist)
            let fVec = normalize(dir) * fMag
            totalForce += fVec
        }

        return totalForce
    }

    func forceAndAcceleration(for body: CelestialBody) -> (force: SIMD3<Float>, acceleration: SIMD3<Float>) {
        let force = gravitationalForce(on: body)
        let acceleration = force / body.mass
        return (force, acceleration)
    }

    var totalFrames: Int { timeline.count }
}

