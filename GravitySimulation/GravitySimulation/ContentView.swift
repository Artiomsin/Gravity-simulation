import SwiftUI
import SceneKit
import simd

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct SceneViewWrapper: UIViewRepresentable {
    var scene: SCNScene
    var onTapNode: ((SCNNode) -> Void)?
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: SceneViewWrapper
        init(_ parent: SceneViewWrapper) { self.parent = parent }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: nil)
            if let node = hits.first?.node {
                parent.onTapNode?(node)
            }
        }
    }
}

struct ContentView: View {
    @State var bodies: [CelestialBody] = []
    @State private var showControls = false
    
    @State private var massInput = ""
    @State private var posXInput = ""
    @State private var posYInput = ""
    @State private var posZInput = ""
    @State private var velXInput = ""
    @State private var velYInput = ""
    @State private var velZInput = ""
    @State private var sizeInput = ""
    
    @State private var scene = SCNScene()
    @State private var engine: GravityEngine!
    
    @State private var totalTimeInput: String = "10"
    @State private var dtInput: String = "0.02"
    @State private var timeScale: Float = 1.0
    @State private var currentFrame: Int = 0
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?
    
    @State private var selectedBody: CelestialBody? = nil
    @State private var showBodyInfo = false
    
    @State private var newBodyColor: Color = .orange

    @State private var selectedShape: ShapeType = .sphere
    
    @State private var selectedForce: SIMD3<Float> = .zero
    @State private var selectedAcceleration: SIMD3<Float> = .zero

    var canAddBody: Bool {
        Float(massInput) != nil && Float(sizeInput) != nil
    }
    
    var body: some View {
        ZStack {
            SceneViewWrapper(scene: scene) { tappedNode in
                if let body = bodies.first(where: { $0.node == tappedNode || $0.node.childNodes.contains(tappedNode) }) {
                    selectedBody = body
                    showBodyInfo = true
                    
                            if let engine = engine {
                                let result = engine.forceAndAcceleration(for: body)
                                selectedForce = result.force
                                selectedAcceleration = result.acceleration
                            }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            if showBodyInfo, let body = selectedBody {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(body.name)").font(.headline)
                    Text("Фигура: \(body.shape.rawValue)")
                    Text("Размер: \(String(format: "%.2f", body.size))")
                    Text("Масса: \(String(format: "%.2f", body.mass))")
                    Text("Позиция: x \(String(format: "%.2f", body.position.x)), y \(String(format: "%.2f", body.position.y)), z \(String(format: "%.2f", body.position.z))")
                    Text("Скорость: vx \(String(format: "%.2f", body.velocity.x)), vy \(String(format: "%.2f", body.velocity.y)), vz \(String(format: "%.2f", body.velocity.z))")
                    Text("Сила:")
                    Text("Fx \(String(format: "%.2f", selectedForce.x))  Fy \(String(format: "%.2f", selectedForce.y))  Fz \(String(format: "%.2f", selectedForce.z))")
                    
                    Text("Ускорение:")
                    Text("ax \(String(format: "%.2f", selectedAcceleration.x))  ay \(String(format: "%.2f", selectedAcceleration.y))  az \(String(format: "%.2f", selectedAcceleration.z))")
                    
                    Button("Закрыть") { showBodyInfo = false }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .frame(maxWidth: 260)
                .padding(.bottom, 40)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        withAnimation { showControls = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
            
            if showControls {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showControls = false }
                    }
            }
            
            VStack {
                Spacer()
                bottomSheet
            }
            .ignoresSafeArea(edges: .bottom)
            
            VStack {
                HStack {
                    Button("Рассчитать") {
                        calculateSimulation()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Button(isPlaying ? "Пауза" : "Play") {
                        togglePlayback()
                    }
                    .padding()
                    .background(isPlaying ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Общее время:")
                        TextField("20", text: $totalTimeInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("сек")
                    }
                    
                    HStack {
                        Text("Шаг dt:")
                        TextField("0.02", text: $dtInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    Text("Скорость воспроизведения: x\(String(format: "%.2f", timeScale))")
                    
                    Slider(value: Binding(
                        get: { Double(timeScale) },
                        set: { timeScale = Float($0) }
                    ), in: 0.25...5.0)
                    
                    if let engine = engine {
                        Slider(value: Binding(
                            get: { Double(currentFrame) },
                            set: { newValue in
                                currentFrame = Int(newValue)
                                engine.goTo(index: currentFrame)
                            }
                        ), in: 0...Double(max(engine.totalFrames - 1, 0)))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            setupScene()
            setupInitialBodies()
            engine = GravityEngine(bodies: bodies, scene: scene)

        }
    }
    
    var bottomSheet: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            Text("Добавить тело")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("X", text: $posXInput)
                    TextField("Y", text: $posYInput)
                    TextField("Z", text: $posZInput)
                }
                HStack(spacing: 8) {
                    TextField("Vx", text: $velXInput)
                    TextField("Vy", text: $velYInput)
                    TextField("Vz", text: $velZInput)
                }
                HStack(spacing: 8) {
                    TextField("M", text: $massInput)
                    TextField("Размер", text: $sizeInput)
                    Text("Цвет:")
                    ColorPicker("", selection: $newBodyColor)
                    .labelsHidden()
                }
                Picker("Фигура", selection: $selectedShape) {
                ForEach(ShapeType.allCases, id: \.self) { shape in
                Text(shape.rawValue).tag(shape)
                                   }
                               }
                        .pickerStyle(.segmented)
                           }
                           .keyboardType(.decimalPad)
                           .textFieldStyle(.roundedBorder)
            
            Button("Добавить") {
                guard !isPlaying && currentFrame == 0 else { return }
                addBody()
                withAnimation(.easeOut) { showControls = false }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canAddBody ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!canAddBody || isPlaying || currentFrame != 0)
            
            Button("Отмена") {
                withAnimation(.easeOut) { showControls = false }
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(radius: 12)
        .offset(y: showControls ? 0 : 600)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showControls)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { hideKeyboard() }
            }
        }
    }

    func calculateSimulation() {
            guard let totalTime = Float(totalTimeInput),
                  let dt = Float(dtInput),
                  totalTime > 0, dt > 0 else { return }

            engine.dt = dt
            engine.scene = scene
        
            for body in bodies { body.clearTrail() }
        
            engine.simulate(totalTime: totalTime)
            currentFrame = 0
            engine.goTo(index: 0)
            isPlaying = false
            playbackTimer?.invalidate()
        }
    
    func togglePlayback() {
        guard let engine = engine else { return }
        
        if isPlaying {
            playbackTimer?.invalidate()
            playbackTimer = nil
            isPlaying = false
        } else {
            isPlaying = true
            playbackTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(engine.dt / timeScale), repeats: true) { _ in
                if currentFrame < engine.totalFrames - 1 {
                    currentFrame += 1
                    engine.goTo(index: currentFrame, showTrail: true)
                    if let body = selectedBody {
                        let result = engine.forceAndAcceleration(for: body)
                        selectedForce = result.force
                        selectedAcceleration = result.acceleration
                    }

                } else {
                    isPlaying = false
                    playbackTimer?.invalidate()
                }
            }
        }
    }
    
    func setupScene() {
        setupCamera(scene: scene)
        setupLight(scene: scene)
        setupAxes(scene: scene)
    }
    
    func setupInitialBodies() {
            func uniqueColor(index: Int, total: Int) -> UIColor {
                return UIColor(
                    hue: CGFloat(index) / CGFloat(total),
                    saturation: 0.8,
                    brightness: 0.9,
                    alpha: 1.0
                )
            }
            
            let positions: [SIMD3<Float>] = [
                SIMD3<Float>(2, 0, 0),
                SIMD3<Float>(10, 0, 0),
                SIMD3<Float>(0, 5, 0)
            ]
            
            let velocities: [SIMD3<Float>] = [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(0, 0, 0)
            ]
            
            let masses: [Float] = [10, 15, 8]
            let sizes: [CGFloat] = [1.0, 1.2, 0.8]
            let shapes: [ShapeType] = [.sphere, .box, .cylinder]

            bodies = []

            for i in 0..<3 {
                let color = uniqueColor(index: i, total: 3)
                let body = CelestialBody(
                    name: "Body\(i+1)",
                    mass: masses[i],
                    position: positions[i],
                    velocity: velocities[i],
                    shape: shapes[i],
                    size: sizes[i],
                    color: color
                )
                
                bodies.append(body)
                scene.rootNode.addChildNode(body.node)
            }
        }

    func addBody() {
            guard let mass = Float(massInput),
                  let sizeValue = Float(sizeInput) else { return }
            
            let x = Float(posXInput) ?? 0
            let y = Float(posYInput) ?? 0
            let z = Float(posZInput) ?? 0
            let vx = Float(velXInput) ?? 0
            let vy = Float(velYInput) ?? 0
            let vz = Float(velZInput) ?? 0
            let size = CGFloat(sizeValue)
            
            let body = CelestialBody(
                name: "Body\(bodies.count + 1)",
                mass: mass,
                position: SIMD3<Float>(x, y, z),
                velocity: SIMD3<Float>(vx, vy, vz),
                shape: selectedShape,
                size: size,
                color: UIColor(newBodyColor)
            )
            
            bodies.append(body)
            scene.rootNode.addChildNode(body.node)
            engine = GravityEngine(bodies: bodies, scene: scene)
            
            currentFrame = 0
            isPlaying = false
            playbackTimer?.invalidate()
            
            massInput = ""
            posXInput = ""
            posYInput = ""
            posZInput = ""
            velXInput = ""
            velYInput = ""
            velZInput = ""
            sizeInput = ""
            newBodyColor = .orange
        }
    
    func setupCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(5, 10, 80)
        scene.rootNode.addChildNode(cameraNode)
        
        let cameraMarker = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0)
        cameraMarker.firstMaterial?.diffuse.contents = UIColor.blue
        let markerNode = SCNNode(geometry: cameraMarker)
        markerNode.position = cameraNode.position
        scene.rootNode.addChildNode(markerNode)
    }
    
    func setupLight(scene: SCNScene) {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 70, 60)
        scene.rootNode.addChildNode(lightNode)
        
        let lightMarker = SCNSphere(radius: 0.3)
        lightMarker.firstMaterial?.diffuse.contents = UIColor.green
        let lightMarkerNode = SCNNode(geometry: lightMarker)
        lightMarkerNode.position = lightNode.position
        scene.rootNode.addChildNode(lightMarkerNode)
    }
    
    func setupAxes(scene: SCNScene) {
        let axisLength: Float = 100
        
        let xAxis = SCNCylinder(radius: 0.05, height: CGFloat(axisLength))
        xAxis.firstMaterial?.diffuse.contents = UIColor.red
        let xNode = SCNNode(geometry: xAxis)
        xNode.position = SCNVector3(axisLength / 2, 0, 0)
        xNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        scene.rootNode.addChildNode(xNode)
        
        let yAxis = SCNCylinder(radius: 0.05, height: CGFloat(axisLength))
        yAxis.firstMaterial?.diffuse.contents = UIColor.green
        let yNode = SCNNode(geometry: yAxis)
        yNode.position = SCNVector3(0, axisLength / 2, 0)
        scene.rootNode.addChildNode(yNode)
        
        let zAxis = SCNCylinder(radius: 0.05, height: CGFloat(axisLength))
        zAxis.firstMaterial?.diffuse.contents = UIColor.blue
        let zNode = SCNNode(geometry: zAxis)
        zNode.position = SCNVector3(0, 0, axisLength / 2)
        zNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(zNode)
    }
}

#Preview {
    ContentView()
}
