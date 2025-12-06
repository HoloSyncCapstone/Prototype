//
//  HolosphereAnimationView.swift
//  Prototype
//
//  Adapted from AnimationExample4.swift
//

import SwiftUI
import RealityKit
import RealityKitContent

// --- Mapping from CSV joint name → Skeleton joint name ---
private let fingerJointMap: [String: [String: String]] = [
    "left": [
        // 🧠 Thumb
        "thumbKnuckle": "left_handThumbStart_joint",
        "thumbIntermediateBase": "left_handThumb_1_joint",
        "thumbIntermediateTip": "left_handThumb_2_joint",
        "thumbTip": "left_handThumbEnd_joint",
        // ☝️ Index Finger
        "indexFingerMetacarpal": "left_handIndexStart_joint",
        "indexFingerKnuckle": "left_handIndex_1_joint",
        "indexFingerIntermediateBase": "left_handIndex_2_joint",
        "indexFingerIntermediateTip": "left_handIndex_3_joint",
        "indexFingerTip": "left_handIndexEnd_joint",
        // ✋ Middle Finger
        "middleFingerMetacarpal": "left_handMidStart_joint",
        "middleFingerKnuckle": "left_handMid_1_joint",
        "middleFingerIntermediateBase": "left_handMid_2_joint",
        "middleFingerIntermediateTip": "left_handMid_3_joint",
        "middleFingerTip": "left_handMidEnd_joint",
        // 💍 Ring Finger
        "ringFingerMetacarpal": "left_handRingStart_joint",
        "ringFingerKnuckle": "left_handRing_1_joint",
        "ringFingerIntermediateBase": "left_handRing_2_joint",
        "ringFingerIntermediateTip": "left_handRing_3_joint",
        "ringFingerTip": "left_handRingEnd_joint",
        // 🧒 Pinky
        "littleFingerMetacarpal": "left_handPinkyStart_joint",
        "littleFingerKnuckle": "left_handPinky_1_joint",
        "littleFingerIntermediateBase": "left_handPinky_2_joint",
        "littleFingerIntermediateTip": "left_handPinky_3_joint",
        "littleFingerTip": "left_handPinkyEnd_joint",
        
        "forearmArm": "left_forearm_joint"
    ],
    "right": [
        // 🧠 Thumb
        "thumbKnuckle": "right_handThumbStart_joint",
        "thumbIntermediateBase": "right_handThumb_1_joint",
        "thumbIntermediateTip": "right_handThumb_2_joint",
        "thumbTip": "right_handThumbEnd_joint",

        // ☝️ Index Finger
        "indexFingerMetacarpal": "right_handIndexStart_joint",
        "indexFingerKnuckle": "right_handIndex_1_joint",
        "indexFingerIntermediateBase": "right_handIndex_2_joint",
        "indexFingerIntermediateTip": "right_handIndex_3_joint",
        "indexFingerTip": "right_handIndexEnd_joint",

        // ✋ Middle Finger
        "middleFingerMetacarpal": "right_handMidStart_joint",
        "middleFingerKnuckle": "right_handMid_1_joint",
        "middleFingerIntermediateBase": "right_handMid_2_joint",
        "middleFingerIntermediateTip": "right_handMid_3_joint",
        "middleFingerTip": "right_handMidEnd_joint",

        // 💍 Ring Finger
        "ringFingerMetacarpal": "right_handRingStart_joint",
        "ringFingerKnuckle": "right_handRing_1_joint",
        "ringFingerIntermediateBase": "right_handRing_2_joint",
        "ringFingerIntermediateTip": "right_handRing_3_joint",
        "ringFingerTip": "right_handRingEnd_joint",

        // 🧒 Pinky
        "littleFingerMetacarpal": "right_handPinkyStart_joint",
        "littleFingerKnuckle": "right_handPinky_1_joint",
        "littleFingerIntermediateBase": "right_handPinky_2_joint",
        "littleFingerIntermediateTip": "right_handPinky_3_joint",
        "littleFingerTip": "right_handPinkyEnd_joint",

        "forearmArm": "right_forearm_joint"
    ]
]


struct HolosphereAnimationView: View {
    @StateObject private var viewModel = HolosphereViewModel()
    
    // --- tweakable global parameters ---
    private let scaleEstimate: Float = 1.0
    private let flipZ: Bool = true
    private let isMayaModel: Bool = true
    private let limitFrames: Bool = true
    
    var body: some View {
        ZStack {
            RealityView { content, attachments in
                let world = AnchorEntity(world: .zero)
                content.add(world)
                
                // Add controls attachment
                if let controls = attachments.entity(for: "controls") {
                    // Position controls to the left and up
                    controls.position = [-0.6, 1.2, -1.5]
                    
                    // Note: Removed InputTargetComponent/CollisionComponent from controls 
                    // to ensure SwiftUI buttons remain interactive.
                    
                    content.add(controls)
                }
                
                Task {
                    await MainActor.run {
                        viewModel.loadingStatus = "Loading Model..."
                        viewModel.loadingProgress = 0.1
                    }
                    
                    // Try to load model_fV
                    if let dummyAvatar = try? await ModelEntity(named: "model_fV", in: .main) {
                        // Position avatar to the right and raised up to avoid floor clipping
                        dummyAvatar.position = [0.6, 1.0, -2.0]
                        dummyAvatar.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                        
                        // Make avatar draggable
                        dummyAvatar.components.set(InputTargetComponent())
                        dummyAvatar.components.set(CollisionComponent(shapes: [.generateBox(size: [0.5, 2.0, 0.5])]))
                        
                        world.addChild(dummyAvatar)
                        
                        guard let skinned = findSkinnedNode(in: dummyAvatar),
                                    let spc = skinned.components[SkeletalPosesComponent.self],
                                    let basePose = spc.poses.first else {
                            print("❌ No skeletal poses found")
                            return
                        }
                        
                        let jointNames = basePose.jointNames
                        print("✅ Skeleton joints count:", jointNames.count)
                        
                        await MainActor.run {
                            viewModel.loadingStatus = "Loading Motion Data..."
                            viewModel.loadingProgress = 0.3
                        }
                        
                        // 3️⃣ Load motion-capture CSVs
                        var headPath = Bundle.main.path(forResource: "device_pose_01", ofType: "csv")
                        var handPath = Bundle.main.path(forResource: "hand_pose_merged", ofType: "csv")
                        var handGlobalPath = Bundle.main.path(forResource: "hand_pose_world_01", ofType: "csv")
                        
                        if headPath == nil { headPath = Bundle.main.path(forResource: "device_pose_01", ofType: "csv", inDirectory: "Data/tracking") }
                        if handPath == nil { handPath = Bundle.main.path(forResource: "hand_pose_merged", ofType: "csv", inDirectory: "Data/tracking") }
                        if handGlobalPath == nil { handGlobalPath = Bundle.main.path(forResource: "hand_pose_world_01", ofType: "csv", inDirectory: "Data/tracking") }

                        guard let headPath = headPath, let handPath = handPath, let handGlobalPath = handGlobalPath else {
                            print("❌ Missing CSVs")
                            await MainActor.run { viewModel.loadingStatus = "Error: Missing CSVs" }
                            return
                        }
                        
                        let headFrames = HeadPoseLoader.load(from: headPath)
                        await MainActor.run { viewModel.loadingProgress = 0.5 }
                        
                        let handData = HandPoseLoader.load(from: handPath)
                        await MainActor.run { viewModel.loadingProgress = 0.6 }
                        
                        let handGlobalData = HandPoseLoader.load(from: handGlobalPath)
                        await MainActor.run { viewModel.loadingProgress = 0.7 }
                        
                        print("Head frames:", headFrames.count, "Hands:", handData.keys.joined(separator: ","))
                        
                        // Calculate FPS from head frames if possible
                        var detectedFPS = 30.0
                        if headFrames.count > 1 {
                            let dt = headFrames[1].tMono - headFrames[0].tMono
                            if dt > 0 {
                                detectedFPS = 1.0 / dt
                                print("✅ Detected FPS: \(detectedFPS)")
                            }
                        }
                        
                        // 4️⃣ Find key joints in skeleton
                        guard let headIdx = jointNames.firstIndex(where: { $0.hasSuffix("head_joint") }) else {
                            print("❌ Head joint missing")
                            return
                        }
                        
                        // 5️⃣ Determine total frame count
                        var totalFrames = max(
                            headFrames.count,
                            handData["left"]?["forearmWrist"]?.count ?? 0,
                            handData["right"]?["forearmWrist"]?.count ?? 0
                        )
                        guard totalFrames > 0 else { return }
                        if(limitFrames && totalFrames > 800) {
                            totalFrames = 800
                        }
                        print("🎬 Building \(totalFrames) frames")
                        
                        await MainActor.run {
                            viewModel.loadingStatus = "Processing Animation..."
                            viewModel.loadingProgress = 0.8
                        }
                        
                        // Update ViewModel
                        await MainActor.run {
                            viewModel.setup(totalFrames: totalFrames, fps: detectedFPS)
                        }
                        
                        // 6️⃣ Create IK target entities
                        let leftHandTarget = Entity()
                        let rightHandTarget = Entity()
                        let leftForeArmTarget = Entity()
                        let rightForeArmTarget = Entity()
                        let hipsTarget = Entity()
                        let headTarget = Entity()
                        
                        leftHandTarget.name = "left_hand_target"
                        rightHandTarget.name = "right_hand_target"
                        hipsTarget.name = "hips_anchor"
                        headTarget.name = "head_target"
                        leftForeArmTarget.name = "left_forearm_target"
                        rightForeArmTarget.name = "right_forearm_target"
                        
                        var greenMat = SimpleMaterial()
                        var blueMat = SimpleMaterial()
                        var redMat = SimpleMaterial()
                        var pinkMat = SimpleMaterial()
                        var cyanMat = SimpleMaterial()
                        redMat.baseColor = .color(.red)
                        greenMat.baseColor = .color(.green)
                        blueMat.baseColor = .color(.blue)
                        pinkMat.baseColor = .color(.purple)
                        cyanMat.baseColor = .color(.cyan)
                        let mesh = MeshResource.generateCone(height: 0.2, radius: 0.05)
                        let sphere1 = ModelEntity(mesh: mesh, materials: [redMat])
                        let sphere2 = ModelEntity(mesh: mesh, materials: [greenMat])
                        let sphere3 = ModelEntity(mesh: mesh, materials: [blueMat])
                        let sphere4 = ModelEntity(mesh: mesh, materials: [pinkMat])
                        let sphere5 = ModelEntity(mesh: mesh, materials: [cyanMat])
                        
                        // Parent targets to the avatar so they move with it
                        dummyAvatar.addChild(leftHandTarget)
                        dummyAvatar.addChild(rightHandTarget)
                        dummyAvatar.addChild(hipsTarget)
                        dummyAvatar.addChild(headTarget)
                        dummyAvatar.addChild(leftForeArmTarget)
                        dummyAvatar.addChild(rightForeArmTarget)
                        
                        headTarget.addChild(sphere1)
                        leftHandTarget.addChild(sphere2)
                        rightHandTarget.addChild(sphere3)
                        leftForeArmTarget.addChild(sphere4)
                        rightForeArmTarget.addChild(sphere4)
                        
                        // Initialize hips position (relative to avatar)
                        hipsTarget.position = [0, 0, 0]
                        headTarget.position = [0, 1.6, 0]
                        
                        // 7️⃣ Set up IK
                        if let ikRes = IKhelper.set_humanoidIK(model: dummyAvatar) {
                            dummyAvatar.components.set(IKComponent(resource: ikRes))
                            print("✅ IK Component attached successfully")
                            
                            // 8️⃣ Build animation frames (HEAD + FINGERS only, IK handles arms)
                            var frames: [JointTransforms] = []
                            for i in 0..<totalFrames {
                                var frame = basePose.jointTransforms
                                
                                // --- HEAD ---
                                if i < headFrames.count {
                                    let h = headFrames[i]
                                    let r = h.rotation;
                                    let rot = isMayaModel ? simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real) : simd_quatf(ix: r.imag.z, iy: r.imag.y, iz: r.imag.x, r: r.real)
                                    frame[headIdx].rotation = simd_normalize(rot * frame[headIdx].rotation)
                                }
                                
                                // --- FINGERS ONLY --- + forearm rot
                                for side in ["left", "right"] {
                                    guard let fingers = handData[side] else { continue }
                                    for (csvJoint, samples) in fingers {
                                        // Skip forearm joints - IK handles these
                                        if csvJoint.contains("forearm") { continue }
                                        
                                        guard let skeletonName = fingerJointMap[side]?[csvJoint],
                                                    let idx = jointNames.firstIndex(where: { $0.contains(skeletonName) }),
                                                    i < samples.count else { continue }
                                        
                                        let s = samples[i]
                                        
                                        if let r = s.rotation {
                                            var rot = r
                                            if csvJoint.contains("forearm_debug") {
                                                rot = isMayaModel ? simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real) : simd_quatf(ix:    r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real)
                                            }
                                            else if flipZ {
                                                if(side == "right") {
                                                    rot = isMayaModel ? simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real) : simd_quatf(ix: r.imag.z, iy: -r.imag.y, iz: -r.imag.x, r: r.real)
                                                }
                                                else {
                                                    rot = isMayaModel ? simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real) : simd_quatf(ix: r.imag.z, iy: r.imag.y, iz: r.imag.x, r: r.real)
                                                }
                                            }
                                            frame[idx].rotation = simd_normalize(rot)
                                        }
                                    }
                                }
                                
                                frames.append(frame)
                            }
                            
                            await MainActor.run {
                                viewModel.loadingStatus = "Finalizing..."
                                viewModel.loadingProgress = 0.9
                            }
                            
                            // 9️⃣ Bake and play animation (head + fingers)
                            // NOTE: We are NOT playing the baked animation automatically anymore.
                            // We will manually set the pose based on the frame.
                            // However, RealityKit AnimationResource is efficient.
                            // To support scrubbing, we might need to manually apply joint transforms or use the animation controller's time.
                            // For simplicity in this integration, let's stick to the manual update loop for IK targets,
                            // but for the fingers/head (which are baked), we need to sync them.
                            
                            // Let's create the animation resource but NOT play it in a loop.
                            // We will scrub it.
                            var animResource: AnimationResource?
                            var animController: AnimationPlaybackController?
                            
                            var def = SampledAnimation(frames: frames, frameInterval: Float(1.0/detectedFPS), bindTarget: .jointTransforms)
                            def.jointNames = jointNames
                            do {
                                animResource = try AnimationResource.generate(with: def)
                                // skinned.playAnimation(anim.repeat(count: 1000), transitionDuration: 0.1)
                                print("✅ Animation resource generated")
                            } catch {
                                print("❌ Animation error:", error)
                            }
                            
                             // 🔟 Configure IK constraints
                             Task {
                                 try? await Task.sleep(nanoseconds: 100_000_000)
                                 
                                 guard var ikComponent = dummyAvatar.components[IKComponent.self],
                                 var solver = ikComponent.solvers.first else {
                                     print("❌ No IK solver found")
                                     return
                                 }
                                 
                                 // Set initial constraint targets
                                 if var leftConstraint = solver.constraints["left_hand_target"] {
                                     leftConstraint.animationOverrideWeight.position = 1.0
                                     leftConstraint.animationOverrideWeight.rotation = 1.0
                                     solver.constraints["left_hand_target"] = leftConstraint
                                 }
                                 
                                 if var rightConstraint = solver.constraints["right_hand_target"] {
                                     rightConstraint.animationOverrideWeight.position = 1.0
                                     rightConstraint.animationOverrideWeight.rotation = 1.0
                                     solver.constraints["right_hand_target"] = rightConstraint
                                 }

                                 if var leftFAConstraint = solver.constraints["left_forearm_target"] {
                                     leftFAConstraint.animationOverrideWeight.position = 1.0
                                     leftFAConstraint.animationOverrideWeight.rotation = 1.0
                                     solver.constraints["left_forearm_target"] = leftFAConstraint
                                 }

                                 if var rightFAConstraint = solver.constraints["right_forearm_target"] {
                                     rightFAConstraint.animationOverrideWeight.position = 1.0
                                     rightFAConstraint.animationOverrideWeight.rotation = 1.0
                                     solver.constraints["right_forearm_target"] = rightFAConstraint
                                 }

                                 //head_target
                                 if var headConstraint = solver.constraints["head_target"] {
                                     headConstraint.animationOverrideWeight.position = 1.0
                                     solver.constraints["head_target"] = headConstraint
                                 }
                                 
                                 ikComponent.solvers[0] = solver
                                 dummyAvatar.components.set(ikComponent)
                                 print("✅ IK constraints configured")
                                 
                                 await MainActor.run {
                                     viewModel.loadingProgress = 1.0
                                     viewModel.isLoading = false
                                 }
                             }
                             
                            // 1️⃣1️⃣ Start real-time IK target update loop
                            // Instead of a Timer here, we observe viewModel.currentFrame
                            
                            // We need a way to react to viewModel changes inside this RealityView context.
                            // We can use a Timer that polls the viewModel.
                            
                            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                                let currentFrame = viewModel.currentFrame
                                
                                // Sync Animation Controller (Fingers/Head baked animation)
                                if let res = animResource {
                                    if animController == nil {
                                        animController = skinned.playAnimation(res, transitionDuration: 0)
                                        animController?.speed = 0 // We manually scrub
                                    }
                                    let time = Double(currentFrame) / detectedFPS
                                    animController?.time = time
                                }
                                
                                // Sync IK Targets (Arms/Head Position)
                                 if currentFrame < headFrames.count {
                                     let h = headFrames[currentFrame]
                                     headTarget.position = h.position * scaleEstimate
                                 }
                                 
                                // Update left hand target from CSV data
                                if let leftData = handGlobalData["left"],
                                     let leftWristSamples = leftData["forearmWrist"],
                                     let leftForearmSamples = leftData["forearmArm"],
                                     currentFrame < leftWristSamples.count {
                                    let s = leftWristSamples[currentFrame]
                                    let s2 = leftForearmSamples[currentFrame]
                                    var pos = s.position * scaleEstimate
                                    var pos2 = s2.position * scaleEstimate
                                    if flipZ {
                                        pos.z = -pos.z
                                        pos.x = -pos.x
                                    }
                                    
                                    // Convert to world space relative to avatar
                                    leftHandTarget.position = pos
                                    leftForeArmTarget.position = pos2
                                    
                                    if let r = s.rotation {
                                        var rot = r
                                        if flipZ {
                                            rot = isMayaModel ? simd_quatf(ix: -r.imag.x, iy: r.imag.y, iz: -r.imag.z, r: r.real) : simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real)
                                        }
                                        leftHandTarget.orientation = simd_normalize(rot)
                                    }
                                }
                                
                                // Update right hand target from CSV data
                                if let rightData = handGlobalData["right"],
                                     let rightWristSamples = rightData["forearmWrist"],
                                     currentFrame < rightWristSamples.count {
                                    let s = rightWristSamples[currentFrame]
                                    var pos = s.position * scaleEstimate
                                    if flipZ {
                                        pos.z = -pos.z
                                        pos.x = -pos.x
                                    }
                                    
                                    rightHandTarget.position = pos
                                    
                                    if let r = s.rotation {
                                        var rot = r
                                        if flipZ {
                                            rot = isMayaModel ? simd_quatf(ix: -r.imag.x, iy: r.imag.y, iz: -r.imag.z, r: r.real) : simd_quatf(ix: r.imag.x, iy: r.imag.y, iz: r.imag.z, r: r.real)
                                        }
                                        rightHandTarget.orientation = simd_normalize(rot)
                                    }
                                }
                                
                                // Update IK solver with new target positions
                                if var ikComp = dummyAvatar.components[IKComponent.self],
                                     var slv = ikComp.solvers.first {
                                    if var hc = slv.constraints["head_target"] {
                                        hc.target = Transform(
                                            rotation: headTarget.orientation,
                                            translation: headTarget.position
                                        )
                                        slv.constraints["head_target"] = hc
                                    }
                                    // Update left hand constraint
                                    if var lc = slv.constraints["left_hand_target"] {
                                        lc.target = Transform(
                                            rotation: leftHandTarget.orientation,
                                            translation: leftHandTarget.position - SIMD3<Float>(0.0,1.0,0.0)
                                        )
                                        slv.constraints["left_hand_target"] = lc
                                    }
                                    if var lc = slv.constraints["left_forearm_target"] {
                                        lc.target = Transform(
                                            rotation: leftHandTarget.orientation,
                                        )
                                        slv.constraints["left_forearm_target"] = lc
                                    }
                                    // Update right hand constraint
                                    if var rc = slv.constraints["right_hand_target"] {
                                        rc.target = Transform(
                                            rotation: rightHandTarget.orientation,
                                            translation: rightHandTarget.position - SIMD3<Float>(0.0,1.0,0.0)
                                        )
                                        slv.constraints["right_hand_target"] = rc
                                    }
                                    ikComp.solvers[0] = slv
                                    dummyAvatar.components.set(ikComp)
                                }
                            }
                        } else {
                            print("❌ Failed to create IKResource for model")
                        }
                    } else {
                        print("❌ Failed to load model_fV")
                    }
                } // task end
            } attachments: {
                Attachment(id: "controls") {
                    if viewModel.isLoading {
                        // Show loading in the controls attachment space
                        VStack(spacing: 20) {
                            ProgressView(value: viewModel.loadingProgress) {
                                Text(viewModel.loadingStatus)
                                    .font(.headline)
                            }
                            .progressViewStyle(.linear)
                            .frame(width: 300)
                            .padding()
                            .glassBackgroundEffect()
                        }
                    } else {
                        HolospherePlaybackControls(viewModel: viewModel)
                    }
                }
            }
            .gesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        value.entity.position = value.convert(value.location3D, from: .local, to: value.entity.parent!)
                    }
            )
            
            // Removed separate Loading Overlay to prevent floor positioning
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    } // body end
    
    // Helper function to find skinned node
    func findSkinnedNode(in entity: Entity) -> Entity? {
        if entity.components[SkeletalPosesComponent.self] != nil {
            return entity
        }
        for child in entity.children {
            if let found = findSkinnedNode(in: child) {
                return found
            }
        }
        return nil
    }
} // Main struct : view ends here
