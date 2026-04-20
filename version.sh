#!/bin/bash

FILE="pubspec.yaml"

# Ambil version sekarang
CURRENT=$(grep '^version:' $FILE | awk '{print $2}')

# Pisahkan version dan build number
NAME=$(echo $CURRENT | cut -d'+' -f1)
BUILD=$(echo $CURRENT | cut -d'+' -f2)

# Tambah build number
NEW_BUILD=$((BUILD + 1))

NEW_VERSION="$NAME+$NEW_BUILD"

# Replace di pubspec.yaml
sed -i "s/version: $CURRENT/version: $NEW_VERSION/" $FILE

echo "Version updated to $NEW_VERSION"