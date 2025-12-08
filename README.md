# Holosync Final - Prototype

## Repository Link
https://github.com/HoloSyncCapstone/Prototype/edit/main/README.md

## Setup Instructions

Setting up the project is straightforward. All required CSV datasets, video files, and 3D avatar resources are already included in the repository. No external tooling or preprocessing is required.

### Requirements
* macOS with Xcode 16 or newer
* visionOS SDK installed
* Swift 5.9 or later
* Ability to run the visionOS Simulator (Vision Pro)

### Steps to Run the Project
1. **Clone the repository**
2. **Open the project in Xcode**
3. **Ensure bundle resources are correctly assigned**
    * In Xcode, select all CSV files, the Motion Recordings folder, video files, and the `.usdz` avatar models.
    * Under File Inspector → Target Membership, confirm that the app target is checked.
    * This ensures the simulator can load the CSV and video data at runtime.
4. **Build and run**
    * Choose visionOS Simulator as your run target.
    * Press Run.
5. **Select a session**
    * The application automatically scans the included datasets.
    * Choose from the detected sessions in the UI and begin playback.

### Notes
* The project does not capture live Vision Pro motion data. All included motion files are pre-recorded and packaged inside the repository.
* Because of this, setup focuses entirely on running the playback system—no hardware, APIs, or external services are required.

## Overview of How the Code Works

The main functionality is split across two primary files:

### 1. HolosphereAnimationView.swift
This file contains the core real-time animation system and is responsible for:
* Loading the avatar model (`model_fV.usdz`)
* Attaching inverse kinematics solvers for wrists, arms, and head stabilization
* Loading CSV tracking data:
    * `device_pose.csv` for head motion
    * `hand_pose_local.csv` for finger joint rotations
    * `hand_pose_world.csv` for global wrist transforms
* Parsing each CSV into a per-frame dataset
* Rebuilding finger animation using RealityKit’s `SampledAnimation`
* Updating IK target entities and applying frame-specific transforms
* Running a timed playback loop using a manually controlled Timer
* Synchronizing the animation with session video playback
* Handling scrubbing, looping, and playback speed adjustments

Significant sections of commented-out code remain in this file. These represent experimentation, alternative approaches, coordinate-system debugging, and IK strategies. They were intentionally preserved for testing and future extension.

### 2. HolosphereViewModel.swift
The ViewModel oversees:
* Automatically scanning the included resource bundle for available sessions
* Loading and attaching CSV data to the animation system
* Managing user playback state such as:
    * current frame
    * total frames
    * frames per second
    * playback speed
    * play/pause/scrubbing
* Synchronizing the avatar animation to the associated session video
* Providing a unified loading state and progress reporting for the UI

The ViewModel also ensures that animation loading does not begin until a valid session has been detected, preventing race conditions between the UI and file scanning.

### 3. FullbodyimmersiveView.swift
This file contains previous versions of the animation and playback system. It includes experimental implementations of:
* Full-body IK attempts
* Environment-anchored immersive scenes
* Alternative skeletal animation pipelines

The file remains in the repository for reference and documentation but is not used in the final implementation.

### 4. SubtitleView.swift
This file implements a standalone view for rendering timed transcript data over the video playback timeline. It is ready for integration but currently not connected to the main playback pipeline.

## What Works & What Doesn’t

### What Works
* Automatic detection and loading of session folders and their associated tracking and video data
* Parsing CSV motion data for head poses, hand local rotations, and wrist global transforms
* Reconstructing avatar motion using skeletal animation and inverse kinematics
* Synchronized playback of avatar animation and session video
* Real-time scrubbing and adjustable playback speeds
* Stable initialization sequence that waits for the session to load before building the animation
* Successful finger articulation, wrist driving, and upper-body IK behavior

### What Does Not Work
* Full-body IK for lower body and spine remains incomplete
* Scene placement and anchoring are simplified; real environmental alignment is not implemented
* Hot-swapping between sessions without rebuilding the entire animation layer remains unsupported
* Fine-tuning of coordinate system offsets and scale factors is still required

## Future Work

If the project were to be continued, the next steps would include:
1. Completing full-body inverse kinematics (legs, hips, spine)
2. Supporting seamless switching between multiple captured sessions
3. Improving error reporting and loading feedback during session scanning
4. Supporting real-world anchoring, scaling, and environment-aware presentation
