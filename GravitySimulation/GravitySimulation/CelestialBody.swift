import SceneKit
import simd
import UIKit

class CelestialBody {
    var name: String
    var mass: Float
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var node: SCNNode
    var trailNodes: [SCNNode]=[]
    
    private var lastTrailPosition: SIMD3<Float>?
    var trailSpacing: Float=0.2
    
    init(
        name: String,
        mass: Float,
        position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        radius: CGFloat=1.0,
        color: UIColor
    ) {
        self.name=name
        self.mass=mass
        self.position=position
        self.velocity=velocity
        
        let sphere=SCNSphere(radius: radius)
        sphere.firstMaterial?.diffuse.contents=color
        self.node=SCNNode(geometry: sphere)
        self.node.position=SCNVector3(position.x, position.y, position.z)
        
        lastTrailPosition=position
    }
    
    func updateNodePosition() {
        node.position=SCNVector3(position.x, position.y, position.z)
    }
    
    func applyForce(_ force: SIMD3<Float>, dt: Float) {
        let acceleration=force / mass
        velocity += acceleration * dt
    }
    
    func updatePosition(dt: Float, in scene: SCNScene? = nil, showTrail: Bool=false) {
        position += velocity * dt
        updateNodePosition()
        
        guard showTrail, let scene=scene else { return }
        
        if let lastPos=lastTrailPosition {
            let dist=length(position-lastPos)
            if dist<trailSpacing { return }
        }
        
        let trailSphere=SCNSphere(radius: 0.05)
        trailSphere.firstMaterial?.diffuse.contents=node.geometry?.firstMaterial?.diffuse.contents
        let trailNode=SCNNode(geometry: trailSphere)
        trailNode.position=node.position
        scene.rootNode.addChildNode(trailNode)
        trailNodes.append(trailNode)
        
        lastTrailPosition=position
    }
    
    func clearTrail() {
        for t in trailNodes { t.removeFromParentNode() }
        trailNodes.removeAll()
        lastTrailPosition=position
    }
}

