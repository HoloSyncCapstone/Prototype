"""
Upper Body Skeleton Reconstruction from Apple Vision Pro Data
Fixed version - keeps ALL frames, handles missing hands gracefully
"""

import pandas as pd
import numpy as np
from scipy.spatial.transform import Rotation, Slerp
from scipy.interpolate import interp1d

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths to your data files
DEVICE_POSE_PATH = '/Users/Patron/Downloads/2025-10-15T16-00-09-D463287C-ABA4-46ED-924C-57A006479ED8.capture/tracking/device_pose.csv'
HAND_POSE_PATH = '/Users/Patron/Downloads/2025-10-15T16-00-09-D463287C-ABA4-46ED-924C-57A006479ED8.capture/tracking/hand_pose_world.csv'
OUTPUT_PATH = 'complete_skeleton_data.csv'

USER_HEIGHT = 1.75  # meters - adjust to your height

# ============================================================================
# ANTHROPOMETRIC MODEL
# ============================================================================

class AnthropometricModel:
    """Body proportions based on user height."""
    def __init__(self, height_m=1.75):
        self.height = height_m
        self.neck_length = 0.05 * height_m
        self.shoulder_width = 0.25 * height_m
        self.upper_arm_length = 0.18 * height_m
        self.forearm_length = 0.16 * height_m
        self.spine_length = 0.30 * height_m
        self.upper_spine_length = 0.10 * height_m
        self.mid_spine_length = 0.10 * height_m
        self.lower_spine_length = 0.10 * height_m

# ============================================================================
# DATA LOADING - KEEP ALL FRAMES
# ============================================================================

def load_and_organize_data():
    """Load and organize left/right hand data, keeping ALL frames."""
    print("Loading data files...")
    
    # Load raw data
    device_data = pd.read_csv(DEVICE_POSE_PATH)
    hand_data = pd.read_csv(HAND_POSE_PATH)
    
    print(f"Device data: {len(device_data)} frames")
    print(f"Hand data: {len(hand_data)} rows total")
    
    # Get all unique timestamps from hand data
    all_timestamps = sorted(hand_data['t_mono'].unique())
    print(f"Unique timestamps: {len(all_timestamps)}")
    
    # Create lookup dictionaries for each hand
    right_hand_dict = {}
    left_hand_dict = {}
    
    for _, row in hand_data.iterrows():
        t = row['t_mono']
        if row['chirality'] == 'right':
            right_hand_dict[t] = row
        elif row['chirality'] == 'left':
            left_hand_dict[t] = row
    
    print(f"Right hand timestamps: {len(right_hand_dict)}")
    print(f"Left hand timestamps: {len(left_hand_dict)}")
    
    # Build organized dataframe with ALL timestamps
    organized_data = []
    for t in all_timestamps:
        row_data = {'t_mono': t}
        
        # Add right hand data if available
        if t in right_hand_dict:
            right_row = right_hand_dict[t]
            for col in right_row.index:
                if col not in ['t_mono', 't_wall', 'chirality']:
                    row_data[f'{col}_right'] = right_row[col]
        
        # Add left hand data if available
        if t in left_hand_dict:
            left_row = left_hand_dict[t]
            for col in left_row.index:
                if col not in ['t_mono', 't_wall', 'chirality']:
                    row_data[f'{col}_left'] = left_row[col]
        
        organized_data.append(row_data)
    
    organized_df = pd.DataFrame(organized_data)
    
    print(f"\n✓ Organized data: {len(organized_df)} frames")
    print(f"  Frames with both hands: {organized_df[['forearmWrist_px_right', 'forearmWrist_px_left']].notna().all(axis=1).sum()}")
    print(f"  Frames with only right: {(organized_df['forearmWrist_px_right'].notna() & organized_df['forearmWrist_px_left'].isna()).sum()}")
    print(f"  Frames with only left: {(organized_df['forearmWrist_px_left'].notna() & organized_df['forearmWrist_px_right'].isna()).sum()}")
    
    return device_data, organized_df

def interpolate_head_data(device_data, hand_timestamps):
    """Interpolate head position and orientation to match hand frame rate."""
    print("\nInterpolating head data to match hand frame rate...")
    
    head_positions_raw = device_data[['x', 'y', 'z']].values
    head_orientations_raw = device_data[['qx', 'qy', 'qz', 'qw']].values
    head_timestamps = device_data['t_mono'].values
    
    # Clip hand timestamps to head range
    head_min_time = head_timestamps.min()
    head_max_time = head_timestamps.max()
    hand_timestamps_clipped = np.clip(hand_timestamps, head_min_time, head_max_time)
    
    # Interpolate positions
    head_positions = np.zeros((len(hand_timestamps), 3))
    for i in range(3):
        interp_func = interp1d(head_timestamps, head_positions_raw[:, i],
                              kind='cubic', bounds_error=False, fill_value='extrapolate')
        head_positions[:, i] = interp_func(hand_timestamps_clipped)
    
    # Interpolate orientations using SLERP
    rotations = Rotation.from_quat(head_orientations_raw)
    slerp_interp = Slerp(head_timestamps, rotations)
    interpolated_rotations = slerp_interp(hand_timestamps_clipped)
    head_orientations = interpolated_rotations.as_quat()
    
    print(f"✓ Interpolated head data: {len(head_positions)} frames")
    
    return head_positions, head_orientations

def get_hand_position(row, hand, joint_name):
    """Safely extract hand position, returns None if missing."""
    suffix = f'_{hand}'
    px_col = f'{joint_name}_px{suffix}'
    py_col = f'{joint_name}_py{suffix}'
    pz_col = f'{joint_name}_pz{suffix}'
    
    if px_col in row.index and pd.notna(row[px_col]):
        return np.array([row[px_col], row[py_col], row[pz_col]])
    return None

# ============================================================================
# JOINT ESTIMATION FUNCTIONS
# ============================================================================

def quaternion_to_rotation_matrix(q):
    """Convert quaternion [qx, qy, qz, qw] to rotation matrix."""
    qx, qy, qz, qw = q
    return np.array([
        [1 - 2*(qy**2 + qz**2), 2*(qx*qy - qz*qw), 2*(qx*qz + qy*qw)],
        [2*(qx*qy + qz*qw), 1 - 2*(qx**2 + qz**2), 2*(qy*qz - qx*qw)],
        [2*(qx*qz - qy*qw), 2*(qy*qz + qx*qw), 1 - 2*(qx**2 + qy**2)]
    ])

def get_down_vector(head_quaternion):
    """Get the downward direction vector from head orientation."""
    rot_matrix = quaternion_to_rotation_matrix(head_quaternion)
    down_vector = -rot_matrix[:, 1]
    return down_vector / np.linalg.norm(down_vector)

def estimate_neck_position(head_pos, head_quat, body_model):
    """Estimate neck position as offset below head."""
    down_vector = get_down_vector(head_quat)
    neck_pos = head_pos + down_vector * body_model.neck_length
    return neck_pos

def estimate_spine_positions(neck_pos, head_quat, body_model):
    """Estimate upper, mid, and lower spine positions."""
    down_vector = get_down_vector(head_quat)
    upper_spine = neck_pos + down_vector * body_model.upper_spine_length
    mid_spine = upper_spine + down_vector * body_model.mid_spine_length
    lower_spine = mid_spine + down_vector * body_model.lower_spine_length
    return upper_spine, mid_spine, lower_spine

def estimate_shoulder_positions(upper_spine_pos, head_quat, body_model):
    """Estimate left and right shoulder positions."""
    rot_matrix = quaternion_to_rotation_matrix(head_quat)
    right_vector = rot_matrix[:, 0]
    right_vector = right_vector / np.linalg.norm(right_vector)
    
    left_shoulder = upper_spine_pos - right_vector * (body_model.shoulder_width / 2)
    right_shoulder = upper_spine_pos + right_vector * (body_model.shoulder_width / 2)
    
    return left_shoulder, right_shoulder

def estimate_elbow_position(shoulder_pos, forearm_pos, wrist_pos, upper_arm_length):
    """Estimate elbow position using three constraint points."""
    if forearm_pos is None or wrist_pos is None:
        return None
    
    shoulder_to_forearm = forearm_pos - shoulder_pos
    distance_to_forearm = np.linalg.norm(shoulder_to_forearm)
    
    if distance_to_forearm < 1e-6:
        return shoulder_pos + np.array([0, 0, upper_arm_length])
    
    direction = shoulder_to_forearm / distance_to_forearm
    elbow_pos = shoulder_pos + direction * upper_arm_length
    
    return elbow_pos

# ============================================================================
# SKELETON RECONSTRUCTION
# ============================================================================

class UpperBodySkeleton:
    """Complete upper body skeleton with all joints."""
    def __init__(self):
        self.head = None
        self.neck = None
        self.upper_spine = None
        self.mid_spine = None
        self.lower_spine = None
        self.left_shoulder = None
        self.right_shoulder = None
        self.left_elbow = None
        self.right_elbow = None
        self.left_wrist = None
        self.right_wrist = None
    
    def get_all_joints(self):
        """Return dictionary of all joint positions."""
        return {
            'head': self.head,
            'neck': self.neck,
            'upper_spine': self.upper_spine,
            'mid_spine': self.mid_spine,
            'lower_spine': self.lower_spine,
            'left_shoulder': self.left_shoulder,
            'right_shoulder': self.right_shoulder,
            'left_elbow': self.left_elbow,
            'right_elbow': self.right_elbow,
            'left_wrist': self.left_wrist,
            'right_wrist': self.right_wrist,
        }

def reconstruct_skeleton(head_pos, head_quat, left_wrist, right_wrist,
                         left_forearm, right_forearm, body_model):
    """Reconstruct complete upper body skeleton for a single frame."""
    skeleton = UpperBodySkeleton()
    
    # Known joints
    skeleton.head = head_pos
    skeleton.left_wrist = left_wrist
    skeleton.right_wrist = right_wrist
    
    # Estimate spine
    skeleton.neck = estimate_neck_position(head_pos, head_quat, body_model)
    upper, mid, lower = estimate_spine_positions(skeleton.neck, head_quat, body_model)
    skeleton.upper_spine = upper
    skeleton.mid_spine = mid
    skeleton.lower_spine = lower
    
    # Estimate shoulders
    skeleton.left_shoulder, skeleton.right_shoulder = estimate_shoulder_positions(
        skeleton.upper_spine, head_quat, body_model
    )
    
    # Estimate elbows using IK (only if hand data available)
    skeleton.left_elbow = estimate_elbow_position(
        skeleton.left_shoulder, left_forearm, left_wrist, body_model.upper_arm_length
    )
    skeleton.right_elbow = estimate_elbow_position(
        skeleton.right_shoulder, right_forearm, right_wrist, body_model.upper_arm_length
    )
    
    return skeleton

# ============================================================================
# MAIN RECONSTRUCTION PIPELINE
# ============================================================================

def main():
    print("=" * 70)
    print("UPPER BODY SKELETON RECONSTRUCTION")
    print("=" * 70)
    
    # Load and organize data
    device_data, organized_hand_data = load_and_organize_data()
    
    # Get timestamps
    hand_timestamps = organized_hand_data['t_mono'].values
    
    # Interpolate head data
    head_positions, head_orientations = interpolate_head_data(device_data, hand_timestamps)
    
    # Create body model
    body_model = AnthropometricModel(USER_HEIGHT)
    print(f"\nBody model created for height: {USER_HEIGHT}m")
    
    # Reconstruct all frames
    print(f"\nReconstructing skeleton for {len(hand_timestamps)} frames...")
    
    output_data = []
    finger_joints = [
        'thumbKnuckle', 'thumbIntermediateBase', 'thumbIntermediateTip', 'thumbTip',
        'indexFingerMetacarpal', 'indexFingerKnuckle', 'indexFingerIntermediateBase',
        'indexFingerIntermediateTip', 'indexFingerTip',
        'middleFingerMetacarpal', 'middleFingerKnuckle', 'middleFingerIntermediateBase',
        'middleFingerIntermediateTip', 'middleFingerTip',
        'ringFingerMetacarpal', 'ringFingerKnuckle', 'ringFingerIntermediateBase',
        'ringFingerIntermediateTip', 'ringFingerTip',
        'littleFingerMetacarpal', 'littleFingerKnuckle', 'littleFingerIntermediateBase',
        'littleFingerIntermediateTip', 'littleFingerTip'
    ]
    
    for frame_idx in range(len(hand_timestamps)):
        hand_row = organized_hand_data.iloc[frame_idx]
        
        # Get hand positions (may be None if missing)
        left_wrist = get_hand_position(hand_row, 'left', 'forearmWrist')
        right_wrist = get_hand_position(hand_row, 'right', 'forearmWrist')
        left_forearm = get_hand_position(hand_row, 'left', 'forearmArm')
        right_forearm = get_hand_position(hand_row, 'right', 'forearmArm')
        
        # Reconstruct skeleton
        skeleton = reconstruct_skeleton(
            head_positions[frame_idx],
            head_orientations[frame_idx],
            left_wrist,
            right_wrist,
            left_forearm,
            right_forearm,
            body_model
        )
        
        # Create row dictionary
        row = {
            'frame': frame_idx,
            't_mono': hand_timestamps[frame_idx]
        }
        
        # Add reconstructed joint positions
        for joint_name, joint_pos in skeleton.get_all_joints().items():
            if joint_pos is not None:
                row[f'{joint_name}_x'] = joint_pos[0]
                row[f'{joint_name}_y'] = joint_pos[1]
                row[f'{joint_name}_z'] = joint_pos[2]
        
        # Add head orientation
        row['head_qx'] = head_orientations[frame_idx][0]
        row['head_qy'] = head_orientations[frame_idx][1]
        row['head_qz'] = head_orientations[frame_idx][2]
        row['head_qw'] = head_orientations[frame_idx][3]
        
        # Add finger joints for both hands from organized data
        for hand in ['right', 'left']:
            for joint in finger_joints:
                suffix = f'_{hand}'
                px_col = f'{joint}_px{suffix}'
                py_col = f'{joint}_py{suffix}'
                pz_col = f'{joint}_pz{suffix}'
                qx_col = f'{joint}_qx{suffix}'
                qy_col = f'{joint}_qy{suffix}'
                qz_col = f'{joint}_qz{suffix}'
                qw_col = f'{joint}_qw{suffix}'
                
                if px_col in hand_row.index and pd.notna(hand_row[px_col]):
                    row[f'{hand}_{joint}_x'] = hand_row[px_col]
                    row[f'{hand}_{joint}_y'] = hand_row[py_col]
                    row[f'{hand}_{joint}_z'] = hand_row[pz_col]
                    row[f'{hand}_{joint}_qx'] = hand_row[qx_col]
                    row[f'{hand}_{joint}_qy'] = hand_row[qy_col]
                    row[f'{hand}_{joint}_qz'] = hand_row[qz_col]
                    row[f'{hand}_{joint}_qw'] = hand_row[qw_col]
        
        output_data.append(row)
        
        if (frame_idx + 1) % 500 == 0:
            print(f"  Processed {frame_idx + 1}/{len(hand_timestamps)} frames...")
    
    # Create DataFrame and save
    output_df = pd.DataFrame(output_data)
    output_df.to_csv(OUTPUT_PATH, index=False)
    
    print(f"\n{'=' * 70}")
    print(f"✓ RECONSTRUCTION COMPLETE")
    print(f"{'=' * 70}")
    print(f"Output file: {OUTPUT_PATH}")
    print(f"Total frames: {len(output_df)}")
    print(f"Total columns: {len(output_df.columns)}")
    print(f"\nFirst few rows:")
    print(output_df.head())

if __name__ == "__main__":
    main()
