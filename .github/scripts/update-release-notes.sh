#!/usr/bin/env bash
set -euo pipefail

# This script updates the releaseNotes field in umbrel-app.yml
# It fetches release notes from GitHub API for the new version

UMBREL_APP_FILE="bnussbau-trmnl-byos-laravel/umbrel-app.yml"
REPO="usetrmnl/byos_laravel"

# Get the new version from Renovate's data file
if [ -z "${RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE:-}" ] || [ ! -f "$RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE" ]; then
  echo "Error: RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE not found"
  exit 1
fi

NEW_VERSION=$(jq -r '.[0].newValue // empty' "$RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE")
if [ -z "$NEW_VERSION" ]; then
  echo "Error: Could not extract new version from data file"
  exit 1
fi

echo "Updating release notes for version: $NEW_VERSION"

# Fetch release notes from GitHub API
TOKEN="${RENOVATE_TOKEN:-${GITHUB_TOKEN:-}}"
CURL_OPTS=(-s -H "Accept: application/vnd.github.v3+json")
if [ -n "$TOKEN" ]; then
  CURL_OPTS+=(-H "Authorization: token ${TOKEN}")
fi

RELEASE_NOTES=$(curl "${CURL_OPTS[@]}" \
  "https://api.github.com/repos/${REPO}/releases/tags/${NEW_VERSION}" | \
  jq -r '.body // ""')

if [ -z "$RELEASE_NOTES" ] || [ "$RELEASE_NOTES" = "null" ]; then
  echo "Warning: No release notes found for version ${NEW_VERSION}, keeping existing release notes"
  exit 0
fi

# Clean up release notes: remove markdown links, limit length
RELEASE_NOTES=$(echo "$RELEASE_NOTES" | sed 's/\[\([^]]*\)\]([^)]*)/\1/g' | head -c 500)
if [ ${#RELEASE_NOTES} -eq 500 ]; then
  RELEASE_NOTES="${RELEASE_NOTES}..."
fi

# Update YAML file using yq
# yq will handle multiline strings appropriately
yq eval ".releaseNotes = \"$RELEASE_NOTES\"" -i "$UMBREL_APP_FILE"

echo "Successfully updated release notes in $UMBREL_APP_FILE"
