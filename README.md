# Prototype App - Setup Instructions

## 🚀 Getting Started

This project relies on a large dataset of motion recordings. While these files are tracked in Git LFS (Large File Storage), you may need to download them manually if you encounter missing file errors or "No Session" messages.

### 1. Check for Motion Data
After cloning the repository, check if the `Motion Recordings` folder exists in the root directory and contains data (not just empty folders).

If the folder is missing or empty, download the dataset manually:
**[Download Motion Recordings from Google Drive](https://drive.google.com/drive/u/1/folders/1_T5hksgCvnLerVvx_qC3QOqoJetMqo0u)**

### 2. Place the Data Folder
Unzip the downloaded file and place the `Motion Recordings` folder in the **root directory** of the project (next to `Prototype.xcodeproj`).

**Directory Structure:**
```
Prototype/
├── Prototype.xcodeproj
├── Prototype/              <-- Source code folder
├── Motion Recordings/      <-- PLACE FOLDER HERE
│   ├── Motions 1/
│   ├── Motions 2/
│   └── ...
└── ...
```

### 3. Troubleshooting "No Session" Error
If the app launches but shows "No Session" or fails to load data:

**Option A: Check File Location**
Ensure the folder is named exactly `Motion Recordings` (case-sensitive) and is located next to the `.xcodeproj` file.

**Option B: Add to Xcode (Recommended for Device Builds)**
If you are building for a real device (Vision Pro) instead of the Simulator, the app cannot access files on your Mac's hard drive. You must bundle the data with the app:
1. Open the project in Xcode.
2. Drag the `Motion Recordings` folder into the Xcode Project Navigator (left sidebar).
3. In the dialog that appears:
   - Select **"Create folder references"** (Blue folder icon).
   - **Do NOT** select "Create groups" (Yellow folder icon).
   - Ensure the "Prototype" target is checked.
4. Build and run.

### 4. Running the App
1. Open `Prototype.xcodeproj` in Xcode.
2. Select the **Prototype** scheme.
3. Choose a destination (Apple Vision Pro Simulator or Device).
4. Press **Cmd + R** to run.
5. In the main menu, select **"Motion Replay"** to view the animations.
