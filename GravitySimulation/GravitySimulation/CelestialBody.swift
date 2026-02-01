import SceneKit
import simd
import UIKit

enum ShapeType: String, CaseIterable {
    case sphere = "Сфера"
    case box = "Куб"
    case cylinder = "Цилиндр"
    case cone = "Конус"
    case torus = "Тор"
}

class CelestialBody {
    var name: String
    var mass: Float
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var node: SCNNode
    var trailNodes: [SCNNode] = []
    
    var shape: ShapeType
    var size: CGFloat
    var collisionRadius: Float
    
    var originalColor: UIColor
    
    var isDeleted: Bool = false

    private var lastTrailPosition: SIMD3<Float>?
    var trailSpacing: Float = 0.2

    init(
        name: String,
        mass: Float,
        position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        shape: ShapeType = .sphere,
        size: CGFloat = 1.0,
        color: UIColor
    ) {
        self.name = name
        self.mass = mass
        self.position = position
        self.shape = shape
        self.size = size
        self.velocity = velocity
        self.originalColor = color

        let geometry = CelestialBody.makeGeometry(shape: shape, size: size, color: color)
        self.node = SCNNode(geometry: geometry)
        self.node.position = SCNVector3(position.x, position.y, position.z)
        
                switch shape {
                case .sphere:
                    self.collisionRadius = Float(size)
                case .box:
                    self.collisionRadius = Float(size * sqrt(3))
                case .cylinder:
                    self.collisionRadius = Float(max(size, size))
                case .cone:
                    self.collisionRadius = Float(max(size, size))
                case .torus:
                    self.collisionRadius = Float(size + size*0.3)
                }

        lastTrailPosition = position
    }
    
        static func makeGeometry(shape: ShapeType, size: CGFloat, color: UIColor) -> SCNGeometry {
            let geometry: SCNGeometry
            switch shape {
            case .sphere:
                geometry = SCNSphere(radius: size)
            case .box:
                geometry = SCNBox(width: size * 2, height: size * 2, length: size * 2, chamferRadius: 0)
            case .cylinder:
                geometry = SCNCylinder(radius: size, height: size * 2)
            case .cone:
                geometry = SCNCone(topRadius: 0, bottomRadius: size, height: size * 2)
            case .torus:
                geometry = SCNTorus(ringRadius: size, pipeRadius: size * 0.3)
            }

            geometry.firstMaterial?.diffuse.contents = color
            geometry.firstMaterial?.emission.contents = UIColor.black
            return geometry
        }

    func updateNodePosition() {
        node.position = SCNVector3(position.x, position.y, position.z)
    }

    func applyForce(_ force: SIMD3<Float>, dt: Float) {
        let acceleration = force / mass
        velocity += acceleration * dt
    }

    func updatePosition(dt: Float, in scene: SCNScene? = nil, showTrail: Bool = false) {
        position += velocity * dt
        updateNodePosition()

        guard showTrail, let scene = scene else { return }

        if let lastPos = lastTrailPosition {
            let dist = length(position - lastPos)
            if dist < trailSpacing { return }
        }

        let trailSphere = SCNSphere(radius: 0.05)
        trailSphere.firstMaterial?.diffuse.contents = node.geometry?.firstMaterial?.diffuse.contents
        let trailNode = SCNNode(geometry: trailSphere)
        trailNode.position = node.position
        scene.rootNode.addChildNode(trailNode)
        trailNodes.append(trailNode)

        lastTrailPosition = position
    }

    func clearTrail() {
        for t in trailNodes { t.removeFromParentNode() }
        trailNodes.removeAll()
        lastTrailPosition = position
    }
    
    func showDeleteHighlightDashed() {
        removeDeleteHighlight()
        
        let outlineNode = SCNNode()
        outlineNode.name = "deleteHighlight"
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red.withAlphaComponent(0.85)
        material.emission.contents = UIColor.red
        material.lightingModel = .constant
        
        let _: CGFloat = size * 0.05
        
        switch shape {
        case .sphere:
            let sphere = SCNSphere(radius: size * 1.1)
            sphere.materials = [material]
            outlineNode.geometry = sphere
            
        case .box:
            let box = SCNBox(
                width: size * 2.1,
                height: size * 2.1,
                length: size * 2.1,
                chamferRadius: size * 0.1
            )
            box.materials = [material]
            outlineNode.geometry = box
            
        case .cylinder:
            let cyl = SCNCylinder(radius: size * 1.1, height: size * 2.1)
            cyl.materials = [material]
            outlineNode.geometry = cyl
            
        case .cone:
            let cone = SCNCone(topRadius: 0, bottomRadius: size * 1.1, height: size * 2.1)
            cone.materials = [material]
            outlineNode.geometry = cone
            
        case .torus:
            let torus = SCNTorus(ringRadius: size * 1.1, pipeRadius: size * 0.35)
            torus.materials = [material]
            outlineNode.geometry = torus
        }
        
        outlineNode.position = SCNVector3Zero
            outlineNode.opacity = 0.8
            node.addChildNode(outlineNode)
            
            let pulseUp = SCNAction.scale(to: 1.05, duration: 0.6)
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.6)
            let pulse = SCNAction.repeatForever(.sequence([pulseUp, pulseDown]))
            outlineNode.runAction(pulse)
            
            if shape != .box {
                let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.0)
                let repeatSpin = SCNAction.repeatForever(spin)
                outlineNode.runAction(repeatSpin)
            }
    }

    func removeDeleteHighlight() {
        if let highlight = node.childNode(withName: "deleteHighlight", recursively: false) {
            highlight.removeAllActions()
            highlight.removeFromParentNode()
        }
    }

}
