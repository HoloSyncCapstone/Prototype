# Body Skeleton Reconstruction from Apple Vision Pro Data

## Objective
Reconstruct the upper body joints and limbs for the human skeletal model using the partial data captured from the Apple Vision Pro.

**Scope:**
- Focus on upper body skeleton (head, neck, shoulders, arms, spine, torso)
- Use available head tracking and hand tracking data
- Estimate missing joint positions through inverse kinematics
- Create anatomically plausible poses for animation

## Current Data

### Device Pose Data
- **Head position and orientation** captured as spatial coordinates (x, y, z) and rotation (quaternion)

### Hand Tracking Data
- **Complete hand skeleton** for both left and right hands
- Each hand includes spatial positions (x, y, z) and orientations (quaternion) for:
  - **Wrist joint** - connection point to forearm
  - **Forearm joint** - provides elbow region information
  - **Fingers** - full skeletal data for all five fingers

**Data Format:**
All joints provide:
- **3D Position:** (x, y, z) spatial coordinates in world space
- **Orientation:** Quaternion (qx, qy, qz, qw) for joint rotation
- **Timestamps:** Monotonic and wall clock time for synchronization

## Data to Solve For

### Missing Upper Body Joints
- **Neck** - connection between head and spine
- **Shoulders** (left and right) - connection between arms and torso
- **Elbows** (left and right) - refinement/estimation from forearm data
- **Spine/Torso** - upper, mid, and lower spine segments
- **Chest** - upper torso/sternum region

### Required Output
For each estimated joint:
- 3D position (x, y, z)
- Orientation (quaternion)
- Anatomically plausible placement
- Smooth temporal transitions between frames

## IK Idea to Use

### Joint Classification

#### Can HARDCODE (using user height + anthropometric ratios):
- **Neck position** - fixed offset below head based on neck length ratio (~5-6% of height)
- **Spine segments** (upper, mid, lower) - fixed offsets based on torso proportion (~30% of height)
- **Shoulder width** - fixed distance based on body proportion (~25% of height)
- **Bone lengths** - upper arm length (~18% of height), forearm length (~16% of height) - constant per user

#### Can ESTIMATE (using IK/positioning from known data):
- **Shoulder positions (left/right)** - positioned at shoulder width from spine, adjusted for arm movement/rotation
- **Elbow positions (left/right)** - using IK with THREE known points:
  - Shoulder (estimated position)
  - Forearm joint (known from hand data)
  - Wrist (known from hand data)
  - **Key insight:** Two constraint points (forearm + wrist) make elbow estimation more accurate than standard two-joint IK

#### Already KNOWN (from Vision Pro data):
- **Head** position and orientation
- **Wrist** positions (both hands)
- **Forearm** positions (both hands) - provides elbow region information
- **Fingers** (all joints)

### Implementation Strategy

#### 1. Hardcode Fixed Joints
**Neck & Spine (from head position + height):**
- Neck = Head position - (neck_length × head_down_vector)
- Upper spine = Neck - upper_spine_segment
- Mid spine = Upper spine - mid_spine_segment
- Lower spine = Mid spine - lower_spine_segment

**Shoulders (from spine + body proportions):**
- Shoulder center = Upper spine position
- Left shoulder = Shoulder center + (shoulder_width/2 × left_vector)
- Right shoulder = Shoulder center - (shoulder_width/2 × right_vector)

#### 2. Estimate Elbows with Enhanced IK
**For each arm (left/right):**
- Given: Shoulder (estimated), Forearm joint (known), Wrist (known)
- Solve: Elbow position using three-point constraint
- Method: Position elbow between shoulder and forearm joint, maintaining upper arm bone length
- Validation: Check that forearm joint to wrist matches expected forearm length
- Apply natural elbow bend constraints (0-150° flexion)

#### 3. Constraints & Refinement
- Maintain constant bone lengths per frame
- Apply joint angle limits
- Use temporal smoothing to reduce jitter
- Ensure physically plausible poses
