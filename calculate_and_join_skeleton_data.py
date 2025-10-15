#!/usr/bin/env python3
"""
Skeleton Data Calculator and Joiner

This script reads the original Vision Pro tracking data (device pose and hand data),
calculates skeleton joints and angles, and outputs a joined CSV with all data aligned
by timestamps.

Usage:
    python calculate_and_join_skeleton_data.py [options]

Input Files:
    - Prototype/Data/device_pose_data .csv (head tracking)
    - Prototype/Data/hand_data_pivoted.csv (hand tracking)

Output Files:
    - calculated_skeleton_with_angles.csv (calculated joints and angles)
    - joined_skeleton_data.csv (all data joined on timestamps)
"""

import pandas as pd
import numpy as np
import argparse
from pathlib import Path


class AnthropometricModel:
    """Anthropometric body proportions based on user height."""
    
    def __init__(self, height_m=1.75):
        self.height = height_m
        
        # Body segment lengths as percentages of height
        self.neck_length = 0.05 * height_m          # 5% of height
        self.shoulder_width = 0.25 * height_m       # 25% of height
        self.upper_arm_length = 0.18 * height_m     # 18% of height
        self.forearm_length = 0.16 * height_m       # 16% of height
        self.spine_length = 0.30 * height_m         # 30% of height (total)
        
        # Spine segments (divide total spine into 3 segments)
        self.upper_spine_length = 0.10 * height_m
        self.mid_spine_length = 0.10 * height_m
        self.lower_spine_length = 0.10 * height_m


class SkeletonCalculator:
    """Calculate skeleton joints from Vision Pro tracking data."""
    
    def __init__(self, body_model):
        self.body_model = body_model
    
    @staticmethod
    def quaternion_to_rotation_matrix(q):
        """Convert quaternion [qx, qy, qz, qw] to rotation matrix."""
        qx, qy, qz, qw = q
        return np.array([
            [1 - 2*(qy**2 + qz**2), 2*(qx*qy - qz*qw), 2*(qx*qz + qy*qw)],
            [2*(qx*qy + qz*qw), 1 - 2*(qx**2 + qz**2), 2*(qy*qz - qx*qw)],
            [2*(qx*qz - qy*qw), 2*(qy*qz + qx*qw), 1 - 2*(qx**2 + qy**2)]
        ])
    
    def get_down_vector(self, head_quaternion):
        """Get the downward direction vector from head orientation."""
        rot_matrix = self.quaternion_to_rotation_matrix(head_quaternion)
        down_vector = -rot_matrix[:, 1]
        return down_vector / np.linalg.norm(down_vector)
    
    def estimate_neck_position(self, head_pos, head_quat):
        """Estimate neck position as offset below head."""
        down_vector = self.get_down_vector(head_quat)
        return head_pos + down_vector * self.body_model.neck_length
    
    def estimate_spine_positions(self, neck_pos, head_quat):
        """Estimate upper, mid, and lower spine positions."""
        down_vector = self.get_down_vector(head_quat)
        
        upper_spine = neck_pos + down_vector * self.body_model.upper_spine_length
        mid_spine = upper_spine + down_vector * self.body_model.mid_spine_length
        lower_spine = mid_spine + down_vector * self.body_model.lower_spine_length
        
        return upper_spine, mid_spine, lower_spine
    
    def estimate_shoulder_positions(self, upper_spine_pos, head_quat):
        """Estimate left and right shoulder positions."""
        rot_matrix = self.quaternion_to_rotation_matrix(head_quat)
        right_vector = rot_matrix[:, 0]
        right_vector = right_vector / np.linalg.norm(right_vector)
        
        left_shoulder = upper_spine_pos - right_vector * (self.body_model.shoulder_width / 2)
        right_shoulder = upper_spine_pos + right_vector * (self.body_model.shoulder_width / 2)
        
        return left_shoulder, right_shoulder
    
    def estimate_elbow_position(self, shoulder_pos, forearm_pos, wrist_pos):
        """Estimate elbow position using three constraint points."""
        shoulder_to_forearm = forearm_pos - shoulder_pos
        distance_to_forearm = np.linalg.norm(shoulder_to_forearm)
        
        direction = shoulder_to_forearm / distance_to_forearm
        elbow_pos = shoulder_pos + direction * self.body_model.upper_arm_length
        
        return elbow_pos
    
    def reconstruct_skeleton(self, head_pos, head_quat, 
                            left_wrist, right_wrist,
                            left_forearm, right_forearm):
        """Reconstruct complete upper body skeleton."""
        joints = {}
        
        # Known joints
        joints['head'] = head_pos
        joints['left_wrist'] = left_wrist
        joints['right_wrist'] = right_wrist
        joints['left_forearm'] = left_forearm
        joints['right_forearm'] = right_forearm
        
        # Estimate neck and spine
        joints['neck'] = self.estimate_neck_position(head_pos, head_quat)
        upper, mid, lower = self.estimate_spine_positions(joints['neck'], head_quat)
        joints['upper_spine'] = upper
        joints['mid_spine'] = mid
        joints['lower_spine'] = lower
        
        # Estimate shoulders
        left_shoulder, right_shoulder = self.estimate_shoulder_positions(
            joints['upper_spine'], head_quat
        )
        joints['left_shoulder'] = left_shoulder
        joints['right_shoulder'] = right_shoulder
        
        # Estimate elbows
        joints['left_elbow'] = self.estimate_elbow_position(
            left_shoulder, left_forearm, left_wrist
        )
        joints['right_elbow'] = self.estimate_elbow_position(
            right_shoulder, right_forearm, right_wrist
        )
        
        return joints


class AngleCalculator:
    """Calculate joint angles from skeleton positions."""
    
    @staticmethod
    def calculate_angle_3_points(p1, p2, p3):
        """
        Calculate angle at p2 formed by p1-p2-p3.
        Returns angle in degrees.
        """
        v1 = p1 - p2
        v2 = p3 - p2
        
        cos_angle = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2))
        cos_angle = np.clip(cos_angle, -1.0, 1.0)
        angle_rad = np.arccos(cos_angle)
        
        return np.degrees(angle_rad)
    
    @staticmethod
    def calculate_skeleton_angles(joints):
        """Calculate all relevant joint angles."""
        angles = {}
        
        try:
            # Left elbow angle (shoulder-elbow-wrist)
            if all(k in joints for k in ['left_shoulder', 'left_elbow', 'left_wrist']):
                angles['left_elbow_angle'] = AngleCalculator.calculate_angle_3_points(
                    joints['left_shoulder'], joints['left_elbow'], joints['left_wrist']
                )
            
            # Right elbow angle (shoulder-elbow-wrist)
            if all(k in joints for k in ['right_shoulder', 'right_elbow', 'right_wrist']):
                angles['right_elbow_angle'] = AngleCalculator.calculate_angle_3_points(
                    joints['right_shoulder'], joints['right_elbow'], joints['right_wrist']
                )
            
            # Left shoulder angle (upper_spine-shoulder-elbow)
            if all(k in joints for k in ['upper_spine', 'left_shoulder', 'left_elbow']):
                angles['left_shoulder_angle'] = AngleCalculator.calculate_angle_3_points(
                    joints['upper_spine'], joints['left_shoulder'], joints['left_elbow']
                )
            
            # Right shoulder angle (upper_spine-shoulder-elbow)
            if all(k in joints for k in ['upper_spine', 'right_shoulder', 'right_elbow']):
                angles['right_shoulder_angle'] = AngleCalculator.calculate_angle_3_points(
                    joints['upper_spine'], joints['right_shoulder'], joints['right_elbow']
                )
            
            # Spine bend angle (neck-mid_spine-lower_spine)
            if all(k in joints for k in ['neck', 'mid_spine', 'lower_spine']):
                angles['spine_bend_angle'] = AngleCalculator.calculate_angle_3_points(
                    joints['neck'], joints['mid_spine'], joints['lower_spine']
                )
            
        except Exception as e:
            print(f"Warning: Error calculating angles: {e}")
        
        return angles


def extract_joint_positions(hand_df, joint_name, chirality='right'):
    """Extract position and orientation for a specific joint."""
    filtered = hand_df[hand_df['chirality'] == chirality]
    
    position = filtered[[f'{joint_name}_px', f'{joint_name}_py', f'{joint_name}_pz']].values
    orientation = filtered[[f'{joint_name}_qx', f'{joint_name}_qy', f'{joint_name}_qz', f'{joint_name}_qw']].values
    
    return position, orientation


def calculate_skeleton_data(device_data_path, hand_data_path, user_height=1.75):
    """
    Calculate skeleton joints and angles from input data.
    
    Args:
        device_data_path: Path to device pose CSV
        hand_data_path: Path to hand data CSV
        user_height: User height in meters
    
    Returns:
        DataFrame with calculated joints and angles
    """
    print("="*70)
    print("SKELETON DATA CALCULATOR")
    print("="*70)
    
    # Load data
    print(f"\n1. Loading input data...")
    device_data = pd.read_csv(device_data_path)
    hand_data = pd.read_csv(hand_data_path)
    print(f"   ✓ Device data: {device_data.shape}")
    print(f"   ✓ Hand data: {hand_data.shape}")
    
    # Initialize calculators
    body_model = AnthropometricModel(user_height)
    skeleton_calc = SkeletonCalculator(body_model)
    
    print(f"\n2. Extracting joint positions...")
    # Extract positions
    right_wrist_pos, right_wrist_ori = extract_joint_positions(hand_data, 'forearmWrist', 'right')
    left_wrist_pos, left_wrist_ori = extract_joint_positions(hand_data, 'forearmWrist', 'left')
    right_forearm_pos, right_forearm_ori = extract_joint_positions(hand_data, 'forearmArm', 'right')
    left_forearm_pos, left_forearm_ori = extract_joint_positions(hand_data, 'forearmArm', 'left')
    
    head_positions = device_data[['x', 'y', 'z']].values
    head_orientations = device_data[['qx', 'qy', 'qz', 'qw']].values
    
    print(f"   ✓ Extracted {len(head_positions)} frames")
    
    # Calculate skeleton for each frame
    print(f"\n3. Calculating skeleton joints and angles...")
    all_frames_data = []
    
    for frame_idx in range(len(head_positions)):
        # Reconstruct skeleton
        joints = skeleton_calc.reconstruct_skeleton(
            head_positions[frame_idx],
            head_orientations[frame_idx],
            left_wrist_pos[frame_idx],
            right_wrist_pos[frame_idx],
            left_forearm_pos[frame_idx],
            right_forearm_pos[frame_idx]
        )
        
        # Calculate angles
        angles = AngleCalculator.calculate_skeleton_angles(joints)
        
        # Create frame data
        frame_data = {
            'frame': frame_idx,
            't_mono': device_data.iloc[frame_idx]['t_mono'],
            't_wall': device_data.iloc[frame_idx]['t_wall'],
        }
        
        # Add joint positions
        for joint_name, joint_pos in joints.items():
            if joint_pos is not None:
                frame_data[f'{joint_name}_x'] = joint_pos[0]
                frame_data[f'{joint_name}_y'] = joint_pos[1]
                frame_data[f'{joint_name}_z'] = joint_pos[2]
        
        # Add angles
        for angle_name, angle_value in angles.items():
            frame_data[angle_name] = angle_value
        
        all_frames_data.append(frame_data)
        
        # Progress indicator
        if (frame_idx + 1) % 100 == 0 or frame_idx == len(head_positions) - 1:
            print(f"   Progress: {frame_idx + 1}/{len(head_positions)} frames...")
    
    df = pd.DataFrame(all_frames_data)
    print(f"   ✓ Calculated {len(df)} frames with {len(df.columns)} columns")
    
    return df


def join_datasets(device_data_path, hand_data_path, calculated_data, output_path):
    """
    Join calculated skeleton data with original data on timestamps.
    
    Args:
        device_data_path: Path to device pose CSV
        hand_data_path: Path to hand data CSV
        calculated_data: DataFrame with calculated joints and angles
        output_path: Path for output joined CSV
    
    Returns:
        DataFrame with joined data
    """
    print(f"\n4. Joining datasets on timestamps...")
    
    # Load original data
    device_data = pd.read_csv(device_data_path)
    hand_data = pd.read_csv(hand_data_path)
    
    # Prepare device data (rename columns to avoid conflicts)
    device_data_renamed = device_data.rename(columns={
        'x': 'head_tracked_x',
        'y': 'head_tracked_y', 
        'z': 'head_tracked_z',
        'qx': 'head_qx',
        'qy': 'head_qy',
        'qz': 'head_qz',
        'qw': 'head_qw'
    })
    
    # Join calculated data with device data on timestamps
    joined = calculated_data.merge(
        device_data_renamed,
        on=['t_mono', 't_wall'],
        how='left',
        suffixes=('', '_device')
    )
    
    print(f"   ✓ Joined with device data: {joined.shape}")
    
    # Join with hand data (aggregate by timestamp if needed)
    # Since hand data has left/right entries, we'll pivot or join separately
    hand_left = hand_data[hand_data['chirality'] == 'left'].copy()
    hand_right = hand_data[hand_data['chirality'] == 'right'].copy()
    
    # Rename hand columns to indicate side
    for col in hand_left.columns:
        if col not in ['t_mono', 't_wall', 'frame', 'chirality']:
            hand_left = hand_left.rename(columns={col: f'left_{col}'})
    
    for col in hand_right.columns:
        if col not in ['t_mono', 't_wall', 'frame', 'chirality']:
            hand_right = hand_right.rename(columns={col: f'right_{col}'})
    
    # Drop chirality column
    hand_left = hand_left.drop(columns=['chirality'], errors='ignore')
    hand_right = hand_right.drop(columns=['chirality'], errors='ignore')
    
    # Join with left hand data
    joined = joined.merge(
        hand_left,
        on=['t_mono', 't_wall'],
        how='left',
        suffixes=('', '_hand_left')
    )
    
    # Join with right hand data
    joined = joined.merge(
        hand_right,
        on=['t_mono', 't_wall'],
        how='left',
        suffixes=('', '_hand_right')
    )
    
    print(f"   ✓ Joined with hand data: {joined.shape}")
    
    # Save to CSV
    joined.to_csv(output_path, index=False)
    print(f"   ✓ Saved to: {output_path}")
    
    return joined


def main():
    parser = argparse.ArgumentParser(
        description='Calculate skeleton joints and angles, then join with original data'
    )
    parser.add_argument(
        '--device-data',
        default='Prototype/Data/device_pose_data .csv',
        help='Path to device pose CSV file'
    )
    parser.add_argument(
        '--hand-data',
        default='Prototype/Data/hand_data_pivoted.csv',
        help='Path to hand data CSV file'
    )
    parser.add_argument(
        '--output-calculated',
        default='calculated_skeleton_with_angles.csv',
        help='Output path for calculated skeleton data'
    )
    parser.add_argument(
        '--output-joined',
        default='joined_skeleton_data.csv',
        help='Output path for joined data'
    )
    parser.add_argument(
        '--user-height',
        type=float,
        default=1.75,
        help='User height in meters (default: 1.75)'
    )
    
    args = parser.parse_args()
    
    # Calculate skeleton data
    calculated_data = calculate_skeleton_data(
        args.device_data,
        args.hand_data,
        args.user_height
    )
    
    # Save calculated data
    calculated_data.to_csv(args.output_calculated, index=False)
    print(f"\n   ✓ Saved calculated data to: {args.output_calculated}")
    print(f"     Size: {calculated_data.memory_usage(deep=True).sum() / 1024:.2f} KB")
    print(f"     Shape: {calculated_data.shape}")
    
    # Join with original data
    joined_data = join_datasets(
        args.device_data,
        args.hand_data,
        calculated_data,
        args.output_joined
    )
    
    print(f"\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(f"Calculated skeleton data: {args.output_calculated}")
    print(f"  - Frames: {len(calculated_data)}")
    print(f"  - Columns: {len(calculated_data.columns)}")
    print(f"  - Includes: joints (x,y,z) + angles")
    print(f"\nJoined data: {args.output_joined}")
    print(f"  - Frames: {len(joined_data)}")
    print(f"  - Columns: {len(joined_data.columns)}")
    print(f"  - Includes: calculated + device + hand data")
    print(f"\n✓ Processing complete!")
    print("="*70)


if __name__ == '__main__':
    main()
