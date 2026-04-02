#!/bin/bash

# 1. Save any current work you're doing in Cursor
echo "💾 Stashing your local changes in develop..."
git stash

# 2. Update the flutterflow branch with the latest UI from the cloud
echo "⬇️ Fetching latest UI from FlutterFlow..."
git checkout flutterflow
git pull origin flutterflow

# 3. Move back to develop and merge the new UI changes
echo "🔀 Merging FlutterFlow updates into develop..."
git checkout develop
git merge flutterflow

# 4. Bring your Cursor code back out of storage
echo "🔓 Restoring your local work..."
git stash pop

echo "✅ All set! You are now on 'develop' with the latest UI and your custom code."
