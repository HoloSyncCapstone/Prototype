//
//  IKhelper.swift
//  Holos
//
//  Created by Donghwan on 10/6/25.
//

import SwiftUI
import RealityKit
import simd

// actual code starts at line 161.
final class IKhelper {

    struct MeshSkeletonProbeResult {
        let hasModelComponent: Bool
        let hasMesh: Bool
        let foundContents: Bool
        let foundSkeletonsInContents: Bool
        let hasSkeletalPosesComponentOnEntity: Bool
    }

    // Avoid deep recursion: cap reflection depth and do a single pass
    func probeMeshForSkeletons(in model: ModelEntity) -> MeshSkeletonProbeResult {
        let modelComp = model.components[ModelComponent.self]
        let hasModelComponent = (modelComp != nil)
        let mesh = modelComp?.mesh
        let hasMesh = (mesh != nil)

        var foundContents = false
        var foundSkeletonsInContents = false

        if let mesh {
            let mirror = Mirror(reflecting: mesh)
            for child in mirror.children {
                if let label = child.label, label.localizedCaseInsensitiveContains("contents") {
                    foundContents = true
                    // Only one shallow + one deep level, no further recursion
                    let contentsMirror = Mirror(reflecting: child.value)
                    for sub in contentsMirror.children {
                        if let subLabel = sub.label, subLabel.localizedCaseInsensitiveContains("skeleton") {
                            foundSkeletonsInContents = true
                            break
                        }
                    }
                    if !foundSkeletonsInContents {
                        for sub in contentsMirror.children {
                            let deepMirror = Mirror(reflecting: sub.value)
                            for deepChild in deepMirror.children {
                                if let deepLabel = deepChild.label, deepLabel.localizedCaseInsensitiveContains("skeleton") {
                                    foundSkeletonsInContents = true
                                    break
                                }
                            }
                            if foundSkeletonsInContents { break }
                        }
                    }
                    break
                }
            }
        }

        let hasSkeletalPosesComponentOnEntity = (model.components[SkeletalPosesComponent.self] != nil)

        print("""
        probeMeshForSkeletons:
          hasModelComponent: \(hasModelComponent)
          hasMesh: \(hasMesh)
          foundContents: \(foundContents)
          foundSkeletonsInContents: \(foundSkeletonsInContents)
          hasSkeletalPosesComponentOnEntity: \(hasSkeletalPosesComponentOnEntity)
        """)

        return MeshSkeletonProbeResult(
            hasModelComponent: hasModelComponent,
            hasMesh: hasMesh,
            foundContents: foundContents,
            foundSkeletonsInContents: foundSkeletonsInContents,
            hasSkeletalPosesComponentOnEntity: hasSkeletalPosesComponentOnEntity
        )
    }
    
    // CODE STARTS HERE
    static func get_Skeleton(model: ModelEntity) -> MeshResource.Skeleton? {
        guard let mesh = model.components[ModelComponent.self]?.mesh else {
            return nil
        }
        let meshMirror = Mirror(reflecting: mesh)
        for child in meshMirror.children {
            guard let label = child.label, label.localizedCaseInsensitiveContains("contents") else { continue }
            let contentsMirror = Mirror(reflecting: child.value)
            func extractSkeleton(from any: Any) -> MeshResource.Skeleton? {
                if let skel = any as? MeshResource.Skeleton { return skel }
                let m = Mirror(reflecting: any)
                if !m.children.isEmpty {
                    for item in m.children {
                        if let sk = item.value as? MeshResource.Skeleton { return sk }
                        let itemMirror = Mirror(reflecting: item.value)
                        for inner in itemMirror.children {
                            if let sk = inner.value as? MeshResource.Skeleton { return sk }
                        }
                    }
                } else {
                    for inner in m.children {
                        if let sk = inner.value as? MeshResource.Skeleton { return sk }
                        let innerMirror = Mirror(reflecting: inner.value)
                        for deep in innerMirror.children {
                            if let sk = deep.value as? MeshResource.Skeleton { return sk }
                        }
                    }
                }
                return nil
            }
            for sub in contentsMirror.children {
                if let subLabel = sub.label, subLabel.localizedCaseInsensitiveContains("skeleton") {
                    if let found = extractSkeleton(from: sub.value) { return found }
                }
            }
            for sub in contentsMirror.children {
                let deepMirror = Mirror(reflecting: sub.value)
                for deepChild in deepMirror.children {
                    if let deepLabel = deepChild.label, deepLabel.localizedCaseInsensitiveContains("skeleton") {
                        if let found = extractSkeleton(from: deepChild.value) { return found }
                    }
                }
            }
        }
        return nil
    }
    
    static func set_humanoidIK(model: ModelEntity) -> IKResource? {
        guard let modelSkeleton = get_Skeleton(model: model) else {
            print("Unexpected: skeleton not found.")
            return nil
        }
        do {
            var rig = try IKRig(for:modelSkeleton)
            rig.maxIterations = 20
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint/left_arm_joint/left_forearm_joint/left_hand_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint/right_arm_joint/right_forearm_joint/right_hand_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/left_upLeg_joint/left_leg_joint/left_foot_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/right_upLeg_joint/right_leg_joint/right_foot_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/left_upLeg_joint/left_leg_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/right_upLeg_joint/right_leg_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/neck_1_joint/neck_2_joint/neck_3_joint/neck_4_joint/head_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint"]?.fkWeightPerAxis = .zero
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint"]?.fkWeightPerAxis = .one
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint/left_arm_joint"]?.fkWeightPerAxis = [0.0, 0.0, 0.0]
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint/left_arm_joint/left_forearm_joint"]?.fkWeightPerAxis = [0.2,0.2,0.2]
            //rig.joints["Hips/Spine/Spine1/Spine2/LeftShoulder/LeftArm/LeftForeArm"]?.rotationStiffness = [0.0, 0.0, 0.0]
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint"]?.fkWeightPerAxis = .one
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint/right_arm_joint"]?.fkWeightPerAxis = [0.0, 0.0, 0.0]
            rig.joints["root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint/right_arm_joint/right_forearm_joint"]?.fkWeightPerAxis = [0.2,0.2,0.2]
            //rig.joints["Hips/Spine/Spine1/Spine2/RightShoulder/RightArm/RightForeArm"]?.rotationStiffness = [1.0, 1.0, 1.0]

            rig.constraints = [
                .parent(
                    named: "head_target",
                    on: "root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/neck_1_joint/neck_2_joint/neck_3_joint/neck_4_joint/head_joint",
                    positionWeight: [1.0, 1.0, 1.0],
                    orientationWeight: [0.0, 0.0, 0.0]
                ),
                .parent(
                    named: "left_hand_target",
                    on: "root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint/left_arm_joint/left_forearm_joint/left_hand_joint",
                    positionWeight: [1.0, 1.0, 1.0],
                    orientationWeight: [1.0, 1.0, 1.0]
                ),
                .parent(
                    named: "left_forearm_target",
                    on: "root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/left_shoulder_1_joint/left_arm_joint/left_forearm_joint",
                    positionWeight: [0.5,0.5,0.5],
                    orientationWeight: [1.0, 1.0, 1.0]
                ),
                .parent(
                    named: "right_forearm_target",
                    on: "root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint/right_arm_joint/right_forearm_joint",
                    positionWeight: [0.5, 0.5, 0.5],
                    orientationWeight: [1.0, 1.0, 1.0]
                ),
                .parent(
                    named: "right_hand_target",
                    on: "root/hips_joint/spine_1_joint/spine_2_joint/spine_3_joint/spine_4_joint/spine_5_joint/spine_6_joint/spine_7_joint/right_shoulder_1_joint/right_arm_joint/right_forearm_joint/right_hand_joint",
                    positionWeight: [1.0, 1.0, 1.0],
                    orientationWeight: [1.0, 1.0, 1.0]
                ),
                .parent(
                    named: "left_foot_target",
                    on: "root/hips_joint/left_upLeg_joint/left_leg_joint/left_foot_joint",
                    positionWeight: [1.0, 1.0, 1.0],
                    orientationWeight: [1.0, 1.0, 1.0],
                ),
                .parent(
                    named: "right_foot_target",
                    on: "root/hips_joint/right_upLeg_joint/right_leg_joint/right_foot_joint",
                    positionWeight: [1.0, 1.0, 1.0],
                    orientationWeight: [1.0, 1.0, 1.0]
                ),
                .parent(
                    named: "right_leg_target",
                    on: "root/hips_joint/right_upLeg_joint/right_leg_joint",
                    positionWeight: .one,
                    orientationWeight: .zero
                ),
                .parent(
                    named: "left_leg_target",
                    on: "root/hips_joint/left_upLeg_joint/left_leg_joint",
                    positionWeight: .one,
                    orientationWeight: .zero
                ),
                .parent(
                    named: "hips_target",
                    on: "root/hips_joint",
                    positionWeight: [0.8, 0.8, 0.8],
                    orientationWeight: .zero
                )
            ]
            do {
                let ik_resource = try IKResource(rig: rig)
                return ik_resource
            } catch {
                print("failed creating IKResource using rig: \(error)")
                return nil
            }
        } catch {
            print("Failed to do IKRig()")
            return nil
        }
    }
    
    // Replaces the gentle vertical bob with a more dynamic multi-axis motion.
    // Produces aggressive, non-repetitive feeling motion using different frequencies and phases.
    static func playAggressiveDynamicMotion(on entity: Entity,
                                            basePosition: SIMD3<Float>,
                                            amplitude: SIMD3<Float> = [0.20, 0.15, 0.12],
                                            period: SIMD3<Float> = [2.0, 1.4, 1.8],
                                            phase: SIMD3<Float> = [0.0, .pi/3, .pi/2],
                                            speed: Float = 1.3)
    {
        // Build a sampled animation path using Lissajous-like motion.
        let keyCount = 180
        var frames: [Transform] = []
        frames.reserveCapacity(keyCount + 1)

        for i in 0...keyCount {
            let t = Float(i) / Float(keyCount)

            // time scaling for aggression
            let tx = t * (2.0 * .pi) * (1.0 / max(0.001, period.x)) * speed
            let ty = t * (2.0 * .pi) * (1.0 / max(0.001, period.y)) * speed
            let tz = t * (2.0 * .pi) * (1.0 / max(0.001, period.z)) * speed

            let xOffset = amplitude.x * sin(tx + phase.x) + 0.35 * amplitude.x * sin(2.4 * tx + 0.7)
            let yOffset = amplitude.y * sin(ty + phase.y) + 0.25 * amplitude.y * sin(3.0 * ty + 1.2)
            let zOffset = amplitude.z * sin(tz + phase.z) + 0.30 * amplitude.z * sin(1.6 * tz + 2.1)

            var tf = Transform()
            tf.translation = SIMD3<Float>(basePosition.x + xOffset,
                                          basePosition.y + yOffset,
                                          basePosition.z + zOffset)
            // Add a subtle orientation change to feel more dynamic
            let yaw   = 0.15 * sin(tx * 0.9)
            let pitch = 0.10 * sin(ty * 1.1 + 0.3)
            let roll  = 0.12 * sin(tz * 0.8 + 0.6)
            let qx = simd_quatf(angle: pitch, axis: [1,0,0])
            let qy = simd_quatf(angle: yaw,   axis: [0,1,0])
            let qz = simd_quatf(angle: roll,  axis: [0,0,1])
            tf.rotation = qz * qy * qx
            tf.scale = .one
            frames.append(tf)
        }

        var def = SampledAnimation(frames: frames,
                                   frameInterval: 0.016, // ~60 FPS
                                   bindTarget: .transform)

        guard let anim = try? AnimationResource.generate(with: def) else {
            print("Failed to generate aggressive dynamic animation.")
            return
        }

        func playOnce() {
            let controller = entity.playAnimation(anim, transitionDuration: 0)
            controller.speed = 1.0
        }

        playOnce()

        // Loop it by replaying the same sampled animation periodically.
        Task.detached { [weak weakEntity = entity] in
            let durationSeconds = Double(def.frameInterval) * Double(frames.count)
            let sleepNanos = UInt64(max(0.01, durationSeconds) * 1_000_000_000)
            while let e = weakEntity, e.scene != nil {
                try? await Task.sleep(nanoseconds: sleepNanos)
                if e.scene != nil {
                    e.stopAllAnimations()
                    let controller = e.playAnimation(anim, transitionDuration: 0)
                    controller.speed = 1.0
                } else {
                    break
                }
            }
        }
    }
}
