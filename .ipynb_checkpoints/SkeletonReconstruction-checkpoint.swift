import Foundation
import simd

/// Anthropometric body proportions based on user height
struct AnthropometricModel {
    let height: Float
    let neckLength: Float
    let shoulderWidth: Float
    let upperArmLength: Float
    let forearmLength: Float
    let spineLength: Float
    let upperSpineLength: Float
    let midSpineLength: Float
    let lowerSpineLength: Float
    
    init(heightMeters: Float = 1.75) {
        self.height = heightMeters
        
        // Body segment lengths as percentages of height
        self.neckLength = 0.05 * heightMeters          // 5% of height
        self.shoulderWidth = 0.25 * heightMeters       // 25% of height
        self.upperArmLength = 0.18 * heightMeters      // 18% of height
        self.forearmLength = 0.16 * heightMeters       // 16% of height
        self.spineLength = 0.30 * heightMeters         // 30% of height (total)
        
        // Spine segments (divide total spine into 3 segments)
        self.upperSpineLength = 0.10 * heightMeters
        self.midSpineLength = 0.10 * heightMeters
        self.lowerSpineLength = 0.10 * heightMeters
    }
}

/// Complete upper body skeleton with all joints
struct UpperBodySkeleton {
    var head: simd_float3?
    var neck: simd_float3?
    var upperSpine: simd_float3?
    var midSpine: simd_float3?
    var lowerSpine: simd_float3?
    var leftShoulder: simd_float3?
    var rightShoulder: simd_float3?
    var leftElbow: simd_float3?
    var rightElbow: simd_float3?
    var leftWrist: simd_float3?
    var rightWrist: simd_float3?
    var leftForearm: simd_float3?
    var rightForearm: simd_float3?
    
    init() {
        // All properties initialized as nil
    }
}

/// Main skeleton reconstruction class
class SkeletonReconstructor {
    let bodyModel: AnthropometricModel
    
    init(userHeight: Float = 1.75) {
        self.bodyModel = AnthropometricModel(heightMeters: userHeight)
    }
    
    // MARK: - Public API
    
    /// Reconstruct complete upper body skeleton for a single frame
    /// - Parameters:
    ///   - headPosition: 3D position of the head (x, y, z)
    ///   - headOrientation: Head orientation as quaternion (x, y, z, w)
    ///   - leftWristPosition: 3D position of left wrist
    ///   - rightWristPosition: 3D position of right wrist
    ///   - leftForearmPosition: 3D position of left forearm joint
    ///   - rightForearmPosition: 3D position of right forearm joint
    /// - Returns: Complete reconstructed skeleton with all joint positions
    func reconstructSkeleton(
        headPosition: simd_float3,
        headOrientation: simd_quatf,
        leftWristPosition: simd_float3,
        rightWristPosition: simd_float3,
        leftForearmPosition: simd_float3,
        rightForearmPosition: simd_float3
    ) -> UpperBodySkeleton {
        var skeleton = UpperBodySkeleton()
        
        // Known joints
        skeleton.head = headPosition
        skeleton.leftWrist = leftWristPosition
        skeleton.rightWrist = rightWristPosition
        skeleton.leftForearm = leftForearmPosition
        skeleton.rightForearm = rightForearmPosition
        
        // Estimate neck position
        skeleton.neck = estimateNeckPosition(
            headPosition: headPosition,
            headOrientation: headOrientation
        )
        
        // Estimate spine positions
        let spinePositions = estimateSpinePositions(
            neckPosition: skeleton.neck!,
            headOrientation: headOrientation
        )
        skeleton.upperSpine = spinePositions.upper
        skeleton.midSpine = spinePositions.mid
        skeleton.lowerSpine = spinePositions.lower
        
        // Estimate shoulder positions
        let shoulderPositions = estimateShoulderPositions(
            upperSpinePosition: skeleton.upperSpine!,
            headOrientation: headOrientation
        )
        skeleton.leftShoulder = shoulderPositions.left
        skeleton.rightShoulder = shoulderPositions.right
        
        // Estimate elbow positions using IK
        skeleton.leftElbow = estimateElbowPosition(
            shoulderPosition: skeleton.leftShoulder!,
            forearmPosition: leftForearmPosition,
            wristPosition: leftWristPosition,
            upperArmLength: bodyModel.upperArmLength
        )
        
        skeleton.rightElbow = estimateElbowPosition(
            shoulderPosition: skeleton.rightShoulder!,
            forearmPosition: rightForearmPosition,
            wristPosition: rightWristPosition,
            upperArmLength: bodyModel.upperArmLength
        )
        
        return skeleton
    }
    
    /// Reconstruct skeletons for multiple frames
    /// - Parameters:
    ///   - headPositions: Array of head positions for each frame
    ///   - headOrientations: Array of head orientations (quaternions) for each frame
    ///   - leftWristPositions: Array of left wrist positions for each frame
    ///   - rightWristPositions: Array of right wrist positions for each frame
    ///   - leftForearmPositions: Array of left forearm positions for each frame
    ///   - rightForearmPositions: Array of right forearm positions for each frame
    /// - Returns: Array of reconstructed skeletons, one per frame
    func reconstructSkeletons(
        headPositions: [simd_float3],
        headOrientations: [simd_quatf],
        leftWristPositions: [simd_float3],
        rightWristPositions: [simd_float3],
        leftForearmPositions: [simd_float3],
        rightForearmPositions: [simd_float3]
    ) -> [UpperBodySkeleton] {
        let frameCount = min(
            headPositions.count,
            headOrientations.count,
            leftWristPositions.count,
            rightWristPositions.count,
            leftForearmPositions.count,
            rightForearmPositions.count
        )
        
        var skeletons: [UpperBodySkeleton] = []
        
        for i in 0..<frameCount {
            let skeleton = reconstructSkeleton(
                headPosition: headPositions[i],
                headOrientation: headOrientations[i],
                leftWristPosition: leftWristPositions[i],
                rightWristPosition: rightWristPositions[i],
                leftForearmPosition: leftForearmPositions[i],
                rightForearmPosition: rightForearmPositions[i]
            )
            skeletons.append(skeleton)
        }
        
        return skeletons
    }
    
    // MARK: - Private Helper Functions
    
    /// Get the downward direction vector from head orientation
    private func getDownVector(headOrientation: simd_quatf) -> simd_float3 {
        // Create rotation matrix from quaternion
        let rotationMatrix = simd_float3x3(headOrientation)
        
        // Down vector is negative Y in local frame
        let downVector = -rotationMatrix.columns.1
        
        // Normalize the vector
        return simd_normalize(downVector)
    }
    
    /// Estimate neck position as offset below head
    private func estimateNeckPosition(
        headPosition: simd_float3,
        headOrientation: simd_quatf
    ) -> simd_float3 {
        let downVector = getDownVector(headOrientation: headOrientation)
        return headPosition + downVector * bodyModel.neckLength
    }
    
    /// Estimate upper, mid, and lower spine positions
    private func estimateSpinePositions(
        neckPosition: simd_float3,
        headOrientation: simd_quatf
    ) -> (upper: simd_float3, mid: simd_float3, lower: simd_float3) {
        let downVector = getDownVector(headOrientation: headOrientation)
        
        let upperSpine = neckPosition + downVector * bodyModel.upperSpineLength
        let midSpine = upperSpine + downVector * bodyModel.midSpineLength
        let lowerSpine = midSpine + downVector * bodyModel.lowerSpineLength
        
        return (upper: upperSpine, mid: midSpine, lower: lowerSpine)
    }
    
    /// Estimate left and right shoulder positions
    private func estimateShoulderPositions(
        upperSpinePosition: simd_float3,
        headOrientation: simd_quatf
    ) -> (left: simd_float3, right: simd_float3) {
        // Create rotation matrix from quaternion
        let rotationMatrix = simd_float3x3(headOrientation)
        
        // Right vector in local frame
        let rightVector = simd_normalize(rotationMatrix.columns.0)
        
        // Shoulders are at shoulder width apart
        let halfShoulderWidth = bodyModel.shoulderWidth / 2.0
        let leftShoulder = upperSpinePosition - rightVector * halfShoulderWidth
        let rightShoulder = upperSpinePosition + rightVector * halfShoulderWidth
        
        return (left: leftShoulder, right: rightShoulder)
    }
    
    /// Estimate elbow position using three constraint points
    /// Strategy:
    /// - Elbow should be between shoulder and forearm joint
    /// - Distance from shoulder to elbow = upperArmLength
    /// - Elbow positioned along the shoulder-to-forearm direction
    private func estimateElbowPosition(
        shoulderPosition: simd_float3,
        forearmPosition: simd_float3,
        wristPosition: simd_float3,
        upperArmLength: Float
    ) -> simd_float3 {
        // Direction from shoulder to forearm
        let shoulderToForearm = forearmPosition - shoulderPosition
        let distanceToForearm = simd_length(shoulderToForearm)
        
        // Calculate elbow position
        let direction = simd_normalize(shoulderToForearm)
        let elbowPosition = shoulderPosition + direction * upperArmLength
        
        return elbowPosition
    }
}

// MARK: - Helper Extensions

extension simd_float3 {
    /// Create a simd_float3 from x, y, z components
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(x: x, y: y, z: z)
    }
}

extension simd_quatf {
    /// Create a quaternion from x, y, z, w components (scalar last convention)
    init(x: Float, y: Float, z: Float, w: Float) {
        // simd_quatf uses (ix, iy, iz, r) convention where r is the scalar part
        self.init(ix: x, iy: y, iz: z, r: w)
    }
    
    /// Create a quaternion from an array [x, y, z, w]
    init(components: [Float]) {
        precondition(components.count == 4, "Quaternion must have 4 components")
        self.init(x: components[0], y: components[1], z: components[2], w: components[3])
    }
}

// MARK: - Example Usage

/*
 Example of how to use the SkeletonReconstructor:
 
 // Initialize reconstructor with user height
 let reconstructor = SkeletonReconstructor(userHeight: 1.75)
 
 // For a single frame:
 let headPos = simd_float3(0.0, 1.6, 0.0)
 let headQuat = simd_quatf(x: 0.0, y: 0.0, z: 0.0, w: 1.0)
 let leftWrist = simd_float3(-0.3, 1.0, 0.2)
 let rightWrist = simd_float3(0.3, 1.0, 0.2)
 let leftForearm = simd_float3(-0.2, 1.2, 0.1)
 let rightForearm = simd_float3(0.2, 1.2, 0.1)
 
 let skeleton = reconstructor.reconstructSkeleton(
     headPosition: headPos,
     headOrientation: headQuat,
     leftWristPosition: leftWrist,
     rightWristPosition: rightWrist,
     leftForearmPosition: leftForearm,
     rightForearmPosition: rightForearm
 )
 
 // Access joint positions
 if let leftElbow = skeleton.leftElbow {
     print("Left elbow position: \(leftElbow)")
 }
 
 // For multiple frames:
 let headPositions: [simd_float3] = [...]
 let headOrientations: [simd_quatf] = [...]
 let leftWristPositions: [simd_float3] = [...]
 let rightWristPositions: [simd_float3] = [...]
 let leftForearmPositions: [simd_float3] = [...]
 let rightForearmPositions: [simd_float3] = [...]
 
 let skeletons = reconstructor.reconstructSkeletons(
     headPositions: headPositions,
     headOrientations: headOrientations,
     leftWristPositions: leftWristPositions,
     rightWristPositions: rightWristPositions,
     leftForearmPositions: leftForearmPositions,
     rightForearmPositions: rightForearmPositions
 )
 */
