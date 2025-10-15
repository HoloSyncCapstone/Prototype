"""
Smooth 3D Skeleton Animation Viewer
Animates complete_skeleton_data.csv with all frames
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from mpl_toolkits.mplot3d import Axes3D

# ============================================================================
# CONFIGURATION
# ============================================================================

CSV_PATH = 'complete_skeleton_data.csv'
ANIMATION_INTERVAL = 33  # milliseconds per frame (~30 fps)

# ============================================================================
# SKELETON STRUCTURE
# ============================================================================

# Define skeleton connections (bones)
SKELETON_CONNECTIONS = [
    ('head', 'neck'),
    ('neck', 'upper_spine'),
    ('upper_spine', 'mid_spine'),
    ('mid_spine', 'lower_spine'),
    ('upper_spine', 'left_shoulder'),
    ('upper_spine', 'right_shoulder'),
    ('left_shoulder', 'left_elbow'),
    ('left_elbow', 'left_wrist'),
    ('right_shoulder', 'right_elbow'),
    ('right_elbow', 'right_wrist'),
]

# Define finger structure for both hands
FINGER_JOINTS = {
    'right': {
        'thumb': ['thumbKnuckle', 'thumbIntermediateBase', 'thumbIntermediateTip', 'thumbTip'],
        'index': ['indexFingerMetacarpal', 'indexFingerKnuckle', 'indexFingerIntermediateBase', 
                  'indexFingerIntermediateTip', 'indexFingerTip'],
        'middle': ['middleFingerMetacarpal', 'middleFingerKnuckle', 'middleFingerIntermediateBase',
                   'middleFingerIntermediateTip', 'middleFingerTip'],
        'ring': ['ringFingerMetacarpal', 'ringFingerKnuckle', 'ringFingerIntermediateBase',
                 'ringFingerIntermediateTip', 'ringFingerTip'],
        'little': ['littleFingerMetacarpal', 'littleFingerKnuckle', 'littleFingerIntermediateBase',
                   'littleFingerIntermediateTip', 'littleFingerTip'],
    },
    'left': {
        'thumb': ['thumbKnuckle', 'thumbIntermediateBase', 'thumbIntermediateTip', 'thumbTip'],
        'index': ['indexFingerMetacarpal', 'indexFingerKnuckle', 'indexFingerIntermediateBase',
                  'indexFingerIntermediateTip', 'indexFingerTip'],
        'middle': ['middleFingerMetacarpal', 'middleFingerKnuckle', 'middleFingerIntermediateBase',
                   'middleFingerIntermediateTip', 'middleFingerTip'],
        'ring': ['ringFingerMetacarpal', 'ringFingerKnuckle', 'ringFingerIntermediateBase',
                 'ringFingerIntermediateTip', 'ringFingerTip'],
        'little': ['littleFingerMetacarpal', 'littleFingerKnuckle', 'littleFingerIntermediateBase',
                   'littleFingerIntermediateTip', 'littleFingerTip'],
    }
}

# Color scheme
BODY_JOINT_COLOR = '#FF6B9D'
BODY_BONE_COLOR = '#00D9FF'
FINGER_COLORS = {
    'thumb': '#FF8C42',
    'index': '#FF6B9D',
    'middle': '#C780FA',
    'ring': '#00D9FF',
    'little': '#7FFF00',
}

# ============================================================================
# DATA LOADING AND HELPERS
# ============================================================================

def load_skeleton_data(csv_path):
    """Load skeleton data from CSV."""
    print(f"Loading skeleton data from {csv_path}...")
    df = pd.read_csv(csv_path)
    print(f"✓ Loaded {len(df)} frames")
    return df

def get_joint_position(row, joint_name):
    """Extract 3D position for a joint from a data row."""
    x_col = f'{joint_name}_x'
    y_col = f'{joint_name}_y'
    z_col = f'{joint_name}_z'
    
    if x_col in row.index and pd.notna(row[x_col]):
        return np.array([row[x_col], row[y_col], row[z_col]])
    return None

def calculate_axis_limits(df):
    """Calculate appropriate axis limits from all data."""
    print("Calculating axis limits...")
    
    # Collect all position columns
    x_cols = [col for col in df.columns if col.endswith('_x')]
    y_cols = [col for col in df.columns if col.endswith('_y')]
    z_cols = [col for col in df.columns if col.endswith('_z')]
    
    # Get min/max for each axis
    all_x = df[x_cols].values.flatten()
    all_y = df[y_cols].values.flatten()
    all_z = df[z_cols].values.flatten()
    
    # Remove NaN values
    all_x = all_x[~np.isnan(all_x)]
    all_y = all_y[~np.isnan(all_y)]
    all_z = all_z[~np.isnan(all_z)]
    
    # Add margin
    margin = 0.1
    x_limits = [all_x.min() - margin, all_x.max() + margin]
    y_limits = [all_y.min() - margin, all_y.max() + margin]
    z_limits = [all_z.min() - margin, all_z.max() + margin]
    
    print(f"  X: [{x_limits[0]:.2f}, {x_limits[1]:.2f}]")
    print(f"  Y: [{y_limits[0]:.2f}, {y_limits[1]:.2f}]")
    print(f"  Z: [{z_limits[0]:.2f}, {z_limits[1]:.2f}]")
    
    return x_limits, y_limits, z_limits

# ============================================================================
# ANIMATION SETUP
# ============================================================================

class SkeletonAnimator:
    """Handles the 3D skeleton animation."""
    
    def __init__(self, df):
        self.df = df
        self.num_frames = len(df)
        
        # Set up the figure and 3D axis
        self.fig = plt.figure(figsize=(14, 10), facecolor='#0A0A0F')
        self.ax = self.fig.add_subplot(111, projection='3d', facecolor='#0F0F14')
        
        # Remove grid and panes for clean look
        self.ax.grid(False)
        self.ax.xaxis.pane.fill = False
        self.ax.yaxis.pane.fill = False
        self.ax.zaxis.pane.fill = False
        
        # Set axis colors
        self.ax.xaxis.pane.set_edgecolor('#00D9FF')
        self.ax.yaxis.pane.set_edgecolor('#00FFA3')
        self.ax.zaxis.pane.set_edgecolor('#FF6B9D')
        self.ax.tick_params(colors='#888888')
        self.ax.xaxis.label.set_color('#00D9FF')
        self.ax.yaxis.label.set_color('#00FFA3')
        self.ax.zaxis.label.set_color('#FF6B9D')
        
        # Set labels
        self.ax.set_xlabel('X (m)', fontsize=10, weight='bold')
        self.ax.set_ylabel('Y (m)', fontsize=10, weight='bold')
        self.ax.set_zlabel('Z (m)', fontsize=10, weight='bold')
        
        # Set title
        self.fig.suptitle('MOTION CAPTURE - Full Body Skeleton Tracking', 
                         fontsize=16, weight='bold', color='#00D9FF', y=0.98)
        
        # Calculate and set axis limits
        x_lim, y_lim, z_lim = calculate_axis_limits(df)
        self.ax.set_xlim(x_lim)
        self.ax.set_ylim(y_lim)
        self.ax.set_zlim(z_lim)
        
        # Initialize plot elements
        self.body_lines = []
        self.body_joints = None
        self.finger_lines = {hand: {finger: [] for finger in FINGER_JOINTS[hand]} 
                           for hand in ['left', 'right']}
        self.finger_joints = {hand: {finger: None for finger in FINGER_JOINTS[hand]} 
                             for hand in ['left', 'right']}
        
        # Create initial body bone lines
        for _ in SKELETON_CONNECTIONS:
            line, = self.ax.plot([], [], [], color=BODY_BONE_COLOR, linewidth=3, alpha=0.7)
            self.body_lines.append(line)
        
        # Create body joints scatter
        self.body_joints = self.ax.scatter([], [], [], c=BODY_JOINT_COLOR, s=100, alpha=1.0, 
                                          edgecolors='white', linewidths=1)
        
        # Create finger lines and joints for both hands
        for hand in ['left', 'right']:
            for finger_name, joints in FINGER_JOINTS[hand].items():
                color = FINGER_COLORS[finger_name]
                # Lines for each bone segment
                for _ in range(len(joints) - 1):
                    line, = self.ax.plot([], [], [], color=color, linewidth=2, alpha=0.8)
                    self.finger_lines[hand][finger_name].append(line)
                # Scatter for joints
                scatter = self.ax.scatter([], [], [], c=color, s=30, alpha=0.9, 
                                        edgecolors='white', linewidths=0.5)
                self.finger_joints[hand][finger_name] = scatter
        
        # Frame counter text
        self.frame_text = self.ax.text2D(0.02, 0.98, '', transform=self.ax.transAxes, 
                                        fontsize=12, color='#00D9FF', weight='bold',
                                        verticalalignment='top')
        
        print("Animation setup complete!")
    
    def update_frame(self, frame_idx):
        """Update all plot elements for a given frame."""
        row = self.df.iloc[frame_idx]
        
        # Update body bones
        for i, (start_joint, end_joint) in enumerate(SKELETON_CONNECTIONS):
            start_pos = get_joint_position(row, start_joint)
            end_pos = get_joint_position(row, end_joint)
            
            if start_pos is not None and end_pos is not None:
                self.body_lines[i].set_data([start_pos[0], end_pos[0]], 
                                           [start_pos[1], end_pos[1]])
                self.body_lines[i].set_3d_properties([start_pos[2], end_pos[2]])
            else:
                self.body_lines[i].set_data([], [])
                self.body_lines[i].set_3d_properties([])
        
        # Update body joints
        body_joint_names = ['head', 'neck', 'upper_spine', 'mid_spine', 'lower_spine',
                           'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow',
                           'left_wrist', 'right_wrist']
        body_positions = []
        for joint_name in body_joint_names:
            pos = get_joint_position(row, joint_name)
            if pos is not None:
                body_positions.append(pos)
        
        if body_positions:
            body_positions = np.array(body_positions)
            self.body_joints._offsets3d = (body_positions[:, 0], 
                                          body_positions[:, 1], 
                                          body_positions[:, 2])
        else:
            self.body_joints._offsets3d = ([], [], [])
        
        # Update fingers
        for hand in ['left', 'right']:
            for finger_name, joints in FINGER_JOINTS[hand].items():
                # Update finger bones
                for i in range(len(joints) - 1):
                    joint1 = f'{hand}_{joints[i]}'
                    joint2 = f'{hand}_{joints[i+1]}'
                    
                    pos1 = get_joint_position(row, joint1)
                    pos2 = get_joint_position(row, joint2)
                    
                    if pos1 is not None and pos2 is not None:
                        self.finger_lines[hand][finger_name][i].set_data(
                            [pos1[0], pos2[0]], [pos1[1], pos2[1]])
                        self.finger_lines[hand][finger_name][i].set_3d_properties(
                            [pos1[2], pos2[2]])
                    else:
                        self.finger_lines[hand][finger_name][i].set_data([], [])
                        self.finger_lines[hand][finger_name][i].set_3d_properties([])
                
                # Update finger joints
                finger_positions = []
                for joint in joints:
                    joint_name = f'{hand}_{joint}'
                    pos = get_joint_position(row, joint_name)
                    if pos is not None:
                        finger_positions.append(pos)
                
                if finger_positions:
                    finger_positions = np.array(finger_positions)
                    self.finger_joints[hand][finger_name]._offsets3d = (
                        finger_positions[:, 0], 
                        finger_positions[:, 1], 
                        finger_positions[:, 2])
                else:
                    self.finger_joints[hand][finger_name]._offsets3d = ([], [], [])
        
        # Update frame counter
        self.frame_text.set_text(f'Frame: {frame_idx}/{self.num_frames}')
        
        # Return all artists that were modified
        artists = [self.body_joints, self.frame_text] + self.body_lines
        for hand in ['left', 'right']:
            for finger_name in FINGER_JOINTS[hand]:
                artists.extend(self.finger_lines[hand][finger_name])
                artists.append(self.finger_joints[hand][finger_name])
        
        return artists
    
    def animate(self):
        """Create and start the animation."""
        print(f"Creating animation for {self.num_frames} frames...")
        print("This may take a moment...")
        
        anim = FuncAnimation(
            self.fig, 
            self.update_frame,
            frames=self.num_frames,
            interval=ANIMATION_INTERVAL,
            blit=False,  # Set to False for 3D animations
            repeat=True
        )
        
        print("\n" + "="*70)
        print("✓ ANIMATION READY")
        print("="*70)
        print("Controls:")
        print("  - Click and drag to rotate view")
        print("  - Scroll to zoom")
        print("  - Animation will loop continuously")
        print("="*70)
        
        plt.tight_layout()
        plt.show()
        
        return anim

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("="*70)
    print("3D SKELETON ANIMATION VIEWER")
    print("="*70)
    print()
    
    # Load data
    df = load_skeleton_data(CSV_PATH)
    
    # Create animator
    animator = SkeletonAnimator(df)
    
    # Start animation
    anim = animator.animate()

if __name__ == "__main__":
    main()
