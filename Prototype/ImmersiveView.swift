import SwiftUI
import RealityKit
import simd
import Combine

// MARK: - Immersive View
struct ImmersiveView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var modelEntity: ModelEntity?
    @State private var keyframes: [Keyframe] = []
    @State private var mapper: JointMapper?
    @State private var updateSubscription: AnyCancellable?

    // Visual spheres for debug
    @State private var jointSpheres: [String: ModelEntity] = [:]

    // Joint prefixes (same as before)
    private let prefixes: [String] = [
        "head","neck","upper_spine","mid_spine","lower_spine",
        "left_shoulder","right_shoulder",
        "left_elbow","right_elbow",
        "left_wrist","right_wrist",
        "right_thumbKnuckle","right_thumbIntermediateBase","right_thumbIntermediateTip","right_thumbTip",
        "right_indexFingerMetacarpal","right_indexFingerKnuckle","right_indexFingerIntermediateBase","right_indexFingerIntermediateTip","right_indexFingerTip",
        "right_middleFingerMetacarpal","right_middleFingerKnuckle","right_middleFingerIntermediateBase","right_middleFingerIntermediateTip","right_middleFingerTip",
        "right_ringFingerMetacarpal","right_ringFingerKnuckle","right_ringFingerIntermediateBase","right_ringFingerIntermediateTip","right_ringFingerTip",
        "right_littleFingerMetacarpal","right_littleFingerKnuckle","right_littleFingerIntermediateBase","right_littleFingerIntermediateTip","right_littleFingerTip",
        "left_thumbKnuckle","left_thumbIntermediateBase","left_thumbIntermediateTip","left_thumbTip",
        "left_indexFingerMetacarpal","left_indexFingerKnuckle","left_indexFingerIntermediateBase","left_indexFingerIntermediateTip","left_indexFingerTip",
        "left_middleFingerMetacarpal","left_middleFingerKnuckle","left_middleFingerIntermediateBase","left_middleFingerIntermediateTip","left_middleFingerTip",
        "left_ringFingerMetacarpal","left_ringFingerKnuckle","left_ringFingerIntermediateBase","left_ringFingerIntermediateTip","left_ringFingerTip",
        "left_littleFingerMetacarpal","left_littleFingerKnuckle","left_littleFingerIntermediateBase","left_littleFingerIntermediateTip","left_littleFingerTip"
    ]

    var body: some View {
        RealityView { content, attachments in
            do {
                // --- Load the model ---
                let model = try await ModelEntity(named: "racer-4")
                model.scale = [1, 1, 1]

                // Center on ground
                let vb = model.visualBounds(relativeTo: nil)
                let bottomY = vb.center.y - vb.extents.y/2
                model.position = [0, -bottomY * model.scale.y, -2]

                // Add lighting
                let light = DirectionalLight()
                light.position = [3, 5, 3]
                light.light.intensity = 4000
                light.look(at: [0,0,0], from: light.position, relativeTo: nil)
                content.add(light)

                // Add both model and debug spheres
                content.add(model)
                createJointSpheres(in: content)

                // Attach playback UI
                if let controls = attachments.entity(for: "controls") {
                    controls.position = [0.8, 1.2, -2]
                    content.add(controls)
                }

                self.modelEntity = model

                // Load animation and start playback
                Task { @MainActor in
                    await loadAnimationData(model: model)
                    startUpdateLoop(for: model)
                }
            } catch {
                print("❌ setup error: \(error)")
            }
        } attachments: {
            Attachment(id: "controls") {
                PlaybackControlsView()
            }
        }
    }

    // MARK: - Load animation
    @MainActor
    private func loadAnimationData(model: ModelEntity) async {
        do {
            let frames = try CSVAnimationLoader.loadFromBundle(
                resource: "complete_skeleton_data",
                expectedPrefixes: prefixes,
                defaultFPS: 90.0
            )
            keyframes = frames
            mapper = JointMapper(model: model)
            viewModel.totalTime = frames.last?.time ?? 0
            viewModel.currentTime = 0
            viewModel.isPlaying = true
            print("✅ Loaded \(frames.count) keyframes, mapped \(mapper?.prefixToIndex.count ?? 0) joints.")
        } catch {
            print("❌ load error: \(error)")
        }
    }

    // MARK: - Debug sphere creation
    private func createJointSpheres(in content: RealityViewContent) {
        for prefix in prefixes {
            let sphere = MeshResource.generateSphere(radius: 0.01)
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: prefix.contains("right") ? .systemBlue : .systemGreen)
            mat.emissiveColor = .init(color: prefix.contains("right") ? .blue : .green)
            mat.emissiveIntensity = 1.5
            let e = ModelEntity(mesh: sphere, materials: [mat])
            e.name = "debug_\(prefix)"
            content.add(e)
            jointSpheres[prefix] = e
        }
        print("✅ Created \(jointSpheres.count) debug joint spheres")
    }

    // MARK: - Scene Update-driven animation
    private func startUpdateLoop(for model: ModelEntity) {
        guard let scene = model.scene else { return }

        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { event in
            self.viewModel.updateTime(event.deltaTime)
            let t = self.viewModel.currentTime
            guard !self.keyframes.isEmpty, let mapper = self.mapper else { return }

            self.applyInterpolatedPose(to: model, at: t, mapper: mapper)
            self.updateDebugSpheres(at: t)
        } as! AnyCancellable
    }

    // MARK: - Pose interpolation
    private func applyInterpolatedPose(to model: ModelEntity, at time: TimeInterval, mapper: JointMapper) {
        guard let (k1, k2) = findKeyframes(for: time) else { return }
        let range = max(k2.time - k1.time, 1e-6)
        let alpha = Float((time - k1.time) / range)
        let eased = easeInOutBack(alpha)

        var newTransforms = model.jointTransforms

        for (prefix, idx) in mapper.prefixToIndex {
            guard let t1 = k1.pose.transforms[prefix] else { continue }
            let t2 = k2.pose.transforms[prefix] ?? t1

            // Interpolate rotation
            let interpRotation = simd_slerp(t1.rotation, t2.rotation, eased)
            var jt = model.jointTransforms[idx]
            jt.rotation = interpRotation

            // Optional: translation debug only
//            jt.translation = simd_mix(t1.translation, t2.translation, SIMD3<Float>(repeating: eased))

            newTransforms[idx] = jt
        }

        model.jointTransforms = newTransforms
    }

    private func updateDebugSpheres(at time: TimeInterval) {
        guard let (k1, k2) = findKeyframes(for: time) else { return }
        let range = max(k2.time - k1.time, 1e-6)
        let alpha = Float((time - k1.time) / range)
        for (prefix, sphere) in jointSpheres {
            guard let t1 = k1.pose.transforms[prefix] else { continue }
            let t2 = k2.pose.transforms[prefix] ?? t1
            let pos = simd_mix(t1.translation, t2.translation, SIMD3<Float>(repeating: alpha))
            sphere.position = pos
        }
    }

    private func findKeyframes(for time: TimeInterval) -> (Keyframe, Keyframe)? {
        guard !keyframes.isEmpty else { return nil }
        if time <= keyframes.first!.time { return (keyframes.first!, keyframes.first!) }
        if time >= keyframes.last!.time { return (keyframes.last!, keyframes.last!) }
        for i in 0..<(keyframes.count - 1) {
            let a = keyframes[i], b = keyframes[i + 1]
            if time >= a.time && time <= b.time { return (a, b) }
        }
        return nil
    }

    private func easeInOutBack(_ t: Float) -> Float {
        let c1: Float = 1.70158
        let c2 = c1 * 1.525
        if t < 0.5 {
            return (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
        } else {
            return (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
        }
    }
}
