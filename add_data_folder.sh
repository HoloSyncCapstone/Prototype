#!/bin/bash
# add_data_folder.sh - Script to add Data folder to Xcode project

echo "🔧 Adding Data folder to Xcode project..."

PROJECT_DIR="/Users/Patron/Documents/Prototype"
DATA_FOLDER="$PROJECT_DIR/Prototype/Data"

# Check if Data folder exists
if [ ! -d "$DATA_FOLDER" ]; then
    echo "❌ Data folder not found at: $DATA_FOLDER"
    exit 1
fi

echo "✅ Found Data folder"
echo "📁 Contents:"
find "$DATA_FOLDER" -type f | head -20

echo ""
echo "⚠️  MANUAL STEPS REQUIRED:"
echo ""
echo "1. Open Xcode project: $PROJECT_DIR/Prototype.xcodeproj"
echo ""
echo "2. In Xcode Project Navigator:"
echo "   - Right-click on 'Prototype' folder (yellow folder icon)"
echo "   - Select 'Add Files to \"Prototype\"...'"
echo ""
echo "3. In the file picker:"
echo "   - Navigate to: $PROJECT_DIR/Prototype/"
echo "   - Select the 'Data' folder"
echo "   - ✅ Check: 'Create folder references' (NOT 'Create groups')"
echo "   - ✅ Check: 'Copy items if needed'"
echo "   - ✅ Check: Target 'Prototype' is selected"
echo "   - Click 'Add'"
echo ""
echo "4. Verify in Xcode:"
echo "   - Data folder should appear as BLUE folder (not yellow)"
echo "   - Expand it to see: audio/, transcripts/, etc."
echo ""
echo "5. Build and run!"
echo ""
echo "📝 Note: The blue folder icon indicates a 'folder reference' which"
echo "    preserves the directory structure in the app bundle."
echo ""
