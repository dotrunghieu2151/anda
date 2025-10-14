#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/vcpkg-configuration.json"
VCPKG_DIR="$ROOT_DIR/.vcpkg"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Missing vcpkg-configuration.json"
  exit 1
fi

# Parse registry kind and baseline from JSON
REGISTRY_KIND=$(jq -r '.["default-registry"].kind' "$CONFIG_FILE")
BASELINE=$(jq -r '.["default-registry"].baseline' "$CONFIG_FILE")

# Set REPO_URL based on registry kind
if [ "$REGISTRY_KIND" == "builtin" ]; then
  REPO_URL="https://github.com/microsoft/vcpkg"
elif [ "$REGISTRY_KIND" == "git" ]; then
  REPO_URL=$(jq -r '.["default-registry"].repository' "$CONFIG_FILE")
else
  echo "❌ Unknown registry kind: $REGISTRY_KIND"
  exit 1
fi

if [ -z "$REPO_URL" ] || [ -z "$BASELINE" ] || [ "$REPO_URL" == "null" ] || [ "$BASELINE" == "null" ]; then
  echo "❌ Invalid vcpkg-configuration.json (missing repository or baseline)"
  exit 1
fi

# Clone vcpkg if missing
if [ ! -d "$VCPKG_DIR" ]; then
  echo "📦 Cloning vcpkg..."
  git clone "$REPO_URL" "$VCPKG_DIR"
fi

cd "$VCPKG_DIR"

# Fetch latest commits
echo "🔄 Fetching latest commits..."
git fetch origin

# Detect current version
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")

# Decide whether to update
if [ "$CURRENT_COMMIT" != "$BASELINE" ]; then
  echo "📘 Updating vcpkg to baseline $BASELINE..."
  git checkout "$BASELINE"

  echo "⚙️ Rebootstrapping vcpkg..."
  if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux"* ]]; then
    ./bootstrap-vcpkg.sh -disableMetrics
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    ./bootstrap-vcpkg.bat -disableMetrics
  else
    echo "⚠️ Unknown OS type: $OSTYPE — please bootstrap manually"
  fi
else
  echo "✅ vcpkg already at baseline $BASELINE"
  if [ ! -f "./vcpkg" ]; then
    echo "⚙️ Bootstrapping (first time)..."
    ./bootstrap-vcpkg.sh -disableMetrics
  fi
fi

echo "✅ vcpkg setup complete at $VCPKG_DIR"
echo "   Baseline: $BASELINE"
