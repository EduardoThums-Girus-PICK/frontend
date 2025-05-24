#!/bin/bash

# Ensure the public assets directory exists
mkdir -p public/assets/images

# Copy all images from src/assets to public/assets
cp -r src/assets/images/*.png public/assets/images/
cp -r src/assets/images/*.svg public/assets/images/ 2>/dev/null || :

# Create a symbolic link for assets for better access in development
if [ ! -L "public/assets" ]; then
  ln -sf $(pwd)/public/assets $(pwd)/node_modules/public/assets 2>/dev/null || :
fi

echo "Assets copied successfully!"
