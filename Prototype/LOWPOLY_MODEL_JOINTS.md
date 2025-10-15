# Low Poly Character Model - Joint Structure

## Overview
The `lowpoly.usdz` model contains a rigged humanoid character with **41 joints** organized in a hierarchical skeleton structure.

## Joint Hierarchy

### Main Structure (3 primary chains):

#### Chain 1: Upper Body & Arms (joints 0-31)
Starting from root `n9`:
```
n9 (Root/Hip)
└── n10 (Spine Base)
    ├── n11 (Spine/Torso)
    │   └── n12 (Upper Spine/Chest)
    │
    ├── n14 (Left Shoulder Base)
    │   └── n15 (Left Shoulder)
    │       └── n16 (Left Upper Arm)
    │           └── n17 (Left Elbow/Forearm)
    │               ├── n18 (Left Wrist)
    │               │   └── n19 (Left Hand/Fingers)
    │               ├── n21 (Left Finger 1)
    │               │   └── n22 (Left Finger 1 tip)
    │               ├── n24 (Left Finger 2)
    │               │   └── n25 (Left Finger 2 tip)
    │               ├── n27 (Left Finger 3)
    │               │   └── n28 (Left Finger 3 tip)
    │               └── n30 (Left Finger 4)
    │                   └── n31 (Left Finger 4 tip)
    │
    └── n33 (Right Shoulder Base)
        └── n34 (Right Shoulder)
            └── n35 (Right Upper Arm)
                └── n36 (Right Elbow/Forearm)
                    ├── n37 (Right Wrist)
                    │   └── n38 (Right Hand/Fingers)
                    ├── n40 (Right Finger 1)
                    │   └── n41 (Right Finger 1 tip)
                    ├── n43 (Right Finger 2)
                    │   └── n44 (Right Finger 2 tip)
                    ├── n46 (Right Finger 3)
                    │   └── n47 (Right Finger 3 tip)
                    └── n49 (Right Finger 4)
                        └── n50 (Right Finger 4 tip)
```

#### Chain 2: Left Leg (joints 32-36)
```
n52 (Left Hip/Pelvis)
└── n53 (Left Thigh)
    └── n54 (Left Knee)
        └── n55 (Left Shin/Lower Leg)
            └── n56 (Left Ankle/Foot)
```

#### Chain 3: Right Leg (joints 37-40)
```
n52/n58 (Right Hip - branches from left hip)
└── n59 (Right Thigh)
    └── n60 (Right Knee)
        └── n61 (Right Shin/Lower Leg/Foot)
```

## Joint Index Reference

| Index | Joint Path | Likely Body Part |
|-------|-----------|------------------|
| 0 | n9 | Root/Hip |
| 1 | n9/n10 | Spine Base |
| 2 | n9/n10/n11 | Spine/Torso |
| 3 | n9/n10/n11/n12 | Upper Spine/Chest |
| 4 | n9/n10/n14 | Left Shoulder Base |
| 5 | n9/n10/n14/n15 | Left Shoulder |
| 6 | n9/n10/n14/n15/n16 | Left Upper Arm |
| 7 | n9/n10/n14/n15/n16/n17 | Left Elbow/Forearm |
| 8 | n9/n10/n14/n15/n16/n17/n18 | Left Wrist |
| 9 | n9/n10/n14/n15/n16/n17/n18/n19 | Left Hand |
| 10 | n9/n10/n14/n15/n16/n17/n21 | Left Finger 1 Base |
| 11 | n9/n10/n14/n15/n16/n17/n21/n22 | Left Finger 1 Tip |
| 12 | n9/n10/n14/n15/n16/n17/n24 | Left Finger 2 Base |
| 13 | n9/n10/n14/n15/n16/n17/n24/n25 | Left Finger 2 Tip |
| 14 | n9/n10/n14/n15/n16/n17/n27 | Left Finger 3 Base |
| 15 | n9/n10/n14/n15/n16/n17/n27/n28 | Left Finger 3 Tip |
| 16 | n9/n10/n14/n15/n16/n17/n30 | Left Finger 4 Base |
| 17 | n9/n10/n14/n15/n16/n17/n30/n31 | Left Finger 4 Tip |
| 18 | n9/n10/n33 | Right Shoulder Base |
| 19 | n9/n10/n33/n34 | Right Shoulder |
| 20 | n9/n10/n33/n34/n35 | Right Upper Arm |
| 21 | n9/n10/n33/n34/n35/n36 | Right Elbow/Forearm |
| 22 | n9/n10/n33/n34/n35/n36/n37 | Right Wrist |
| 23 | n9/n10/n33/n34/n35/n36/n37/n38 | Right Hand |
| 24 | n9/n10/n33/n34/n35/n36/n40 | Right Finger 1 Base |
| 25 | n9/n10/n33/n34/n35/n36/n40/n41 | Right Finger 1 Tip |
| 26 | n9/n10/n33/n34/n35/n36/n43 | Right Finger 2 Base |
| 27 | n9/n10/n33/n34/n35/n36/n43/n44 | Right Finger 2 Tip |
| 28 | n9/n10/n33/n34/n35/n36/n46 | Right Finger 3 Base |
| 29 | n9/n10/n33/n34/n35/n36/n46/n47 | Right Finger 3 Tip |
| 30 | n9/n10/n33/n34/n35/n36/n49 | Right Finger 4 Base |
| 31 | n9/n10/n33/n34/n35/n36/n49/n50 | Right Finger 4 Tip |
| 32 | n52 | Left Hip/Pelvis |
| 33 | n52/n53 | Left Thigh |
| 34 | n52/n53/n54 | Left Knee |
| 35 | n52/n53/n54/n55 | Left Shin |
| 36 | n52/n53/n54/n55/n56 | Left Ankle/Foot |
| 37 | n52/n58 | Right Hip |
| 38 | n52/n58/n59 | Right Thigh |
| 39 | n52/n58/n59/n60 | Right Knee |
| 40 | n52/n58/n59/n60/n61 | Right Shin/Foot |

## Key Joints for Animation Mapping

Based on your skeleton reconstruction, here are the most relevant joints:

### Upper Body Mapping
- **Head/Neck**: Joint 3 (`n9/n10/n11/n12`) - Upper Spine/Chest area (no dedicated head joint visible)
- **Left Shoulder**: Joint 5 (`n9/n10/n14/n15`)
- **Right Shoulder**: Joint 19 (`n9/n10/n33/n34`)
- **Left Elbow**: Joint 7 (`n9/n10/n14/n15/n16/n17`)
- **Right Elbow**: Joint 21 (`n9/n10/n33/n34/n35/n36`)
- **Left Wrist**: Joint 8 (`n9/n10/n14/n15/n16/n17/n18`)
- **Right Wrist**: Joint 22 (`n9/n10/n33/n34/n35/n36/n37`)

### Spine Joints
- **Spine Base**: Joint 1 (`n9/n10`)
- **Mid Spine**: Joint 2 (`n9/n10/n11`)
- **Upper Spine**: Joint 3 (`n9/n10/n11/n12`)


