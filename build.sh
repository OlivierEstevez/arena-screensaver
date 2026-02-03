#!/bin/bash

set -e

SAVER_NAME="ArenaChannel"
SRC_DIR="src"
BUILD_DIR="build"
SAVER_BUNDLE="${BUILD_DIR}/${SAVER_NAME}.saver"
IMAGES_DIR="${BUILD_DIR}/images"
BUNDLE_IMAGES_DIR="${SAVER_BUNDLE}/Contents/Resources/images"

echo "Building ${SAVER_NAME}..."

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${SAVER_BUNDLE}/Contents/MacOS"
mkdir -p "${SAVER_BUNDLE}/Contents/Resources"
mkdir -p "${BUNDLE_IMAGES_DIR}"
mkdir -p "${IMAGES_DIR}"

# Copy Info.plist
cp "${SRC_DIR}/Info.plist" "${SAVER_BUNDLE}/Contents/"

# Copy thumbnail images
if [ -f "${SRC_DIR}/thumbnail.png" ]; then
    cp "${SRC_DIR}/thumbnail.png" "${SAVER_BUNDLE}/Contents/Resources/"
fi
if [ -f "${SRC_DIR}/thumbnail@2x.png" ]; then
    cp "${SRC_DIR}/thumbnail@2x.png" "${SAVER_BUNDLE}/Contents/Resources/"
fi

# Read config from YAML
CONFIG_FILE="channel.yaml"
CHANNEL_SLUG=$(grep "^channelURL:" "${CONFIG_FILE}" | sed 's/channelURL:[[:space:]]*//')
AUTH_TOKEN=$(grep "^authorizationToken:" "${CONFIG_FILE}" | sed 's/authorizationToken:[[:space:]]*//')

if [ -z "$CHANNEL_SLUG" ]; then
    echo "Error: channelURL not found in ${CONFIG_FILE}"
    exit 1
fi

# Fetch channel info to get total item count
echo "Fetching channel info: ${CHANNEL_SLUG}..."
CHANNEL_URL="http://api.are.na/v2/channels/${CHANNEL_SLUG}"

if [ -n "$AUTH_TOKEN" ]; then
    CHANNEL_RESPONSE=$(curl -sL -H "Authorization: Bearer ${AUTH_TOKEN}" "${CHANNEL_URL}")
else
    CHANNEL_RESPONSE=$(curl -sL "${CHANNEL_URL}")
fi

# Get channel length and check for errors
CHANNEL_INFO=$(echo "$CHANNEL_RESPONSE" | python3 -c "
import json
import sys

response_text = sys.stdin.read()
if not response_text.strip():
    print('ERROR:EMPTY_RESPONSE')
    sys.exit(0)

try:
    data = json.loads(response_text)
except json.JSONDecodeError:
    print('ERROR:INVALID_JSON')
    sys.exit(0)

# Check for API errors
if 'code' in data and 'length' not in data:
    code = data.get('code', 0)
    message = data.get('message', 'Unknown error')

    if code == 401 or code == 403 or 'Unauthorized' in str(message):
        print('ERROR:UNAUTHORIZED')
    elif code == 404 or 'not found' in str(message).lower():
        print('ERROR:NOT_FOUND')
    else:
        print(f'ERROR:{message}')
    sys.exit(0)

length = data.get('length', 0)
if length == 0:
    print('ERROR:NO_CONTENTS')
    sys.exit(0)

print(f'LENGTH:{length}')
")

# Check for errors from channel info request
if echo "$CHANNEL_INFO" | grep -q "^ERROR:"; then
    ERROR_TYPE=$(echo "$CHANNEL_INFO" | sed 's/^ERROR://')

    if [ "$ERROR_TYPE" = "UNAUTHORIZED" ]; then
        if [ -z "$AUTH_TOKEN" ]; then
            echo "Error: This channel is private. Please add an authorizationToken to ${CONFIG_FILE}"
        else
            echo "Error: Invalid authorization token. Please check your authorizationToken in ${CONFIG_FILE}"
        fi
    elif [ "$ERROR_TYPE" = "NOT_FOUND" ]; then
        echo "Error: Channel '${CHANNEL_SLUG}' not found"
    elif [ "$ERROR_TYPE" = "NO_CONTENTS" ]; then
        echo "Error: Channel '${CHANNEL_SLUG}' has no contents"
    elif [ "$ERROR_TYPE" = "EMPTY_RESPONSE" ]; then
        echo "Error: API returned empty response. The server may be temporarily unavailable."
    elif [ "$ERROR_TYPE" = "INVALID_JSON" ]; then
        echo "Error: API returned invalid response. The server may be temporarily unavailable or rate limiting."
    else
        echo "Error: Failed to fetch channel - ${ERROR_TYPE}"
    fi
    exit 1
fi

# Extract length
CHANNEL_LENGTH=$(echo "$CHANNEL_INFO" | sed 's/^LENGTH://')
echo "Channel has ${CHANNEL_LENGTH} items"

# Calculate number of pages needed (100 items per page)
PER_PAGE=100
TOTAL_PAGES=$(( (CHANNEL_LENGTH + PER_PAGE - 1) / PER_PAGE ))
echo "Fetching ${TOTAL_PAGES} page(s) of content..."

# Fetch all pages and collect image URLs
IMAGE_URLS=""
for PAGE in $(seq 1 $TOTAL_PAGES); do
    echo "  Fetching page ${PAGE}/${TOTAL_PAGES}..."
    API_URL="http://api.are.na/v2/channels/${CHANNEL_SLUG}/contents?per=${PER_PAGE}&page=${PAGE}"

    if [ -n "$AUTH_TOKEN" ]; then
        API_RESPONSE=$(curl -sL -H "Authorization: Bearer ${AUTH_TOKEN}" "${API_URL}")
    else
        API_RESPONSE=$(curl -sL "${API_URL}")
    fi

    # Extract image URLs from this page
    PAGE_URLS=$(echo "$API_RESPONSE" | python3 -c "
import json
import sys

response_text = sys.stdin.read()
if not response_text.strip():
    sys.exit(0)

try:
    data = json.loads(response_text)
except json.JSONDecodeError:
    print('Error: Invalid JSON response from API', file=sys.stderr)
    sys.exit(0)

contents = data.get('contents', [])

for item in contents:
    image = item.get('image')
    if image:
        # Prefer original, then large, then display, then square
        url = None
        for size in ['original', 'large', 'display', 'square']:
            if image.get(size) and image[size].get('url'):
                url = image[size]['url']
                break
        if url:
            # Skip GIF images
            if '.gif' not in url.lower():
                print(url)
")

    if [ -n "$PAGE_URLS" ]; then
        if [ -n "$IMAGE_URLS" ]; then
            IMAGE_URLS="${IMAGE_URLS}
${PAGE_URLS}"
        else
            IMAGE_URLS="${PAGE_URLS}"
        fi
    fi
done

# Check if we got any images
if [ -z "$IMAGE_URLS" ]; then
    echo "Error: No images found in channel '${CHANNEL_SLUG}'"
    exit 1
fi

# Download images
echo "Downloading images..."
IMAGE_COUNT=0
while IFS= read -r url; do
    if [ -n "$url" ]; then
        FILENAME=$(printf "%03d" $IMAGE_COUNT)
        EXTENSION="${url##*.}"
        EXTENSION="${EXTENSION%%\?*}"
        if [[ ! "$EXTENSION" =~ ^(jpg|jpeg|png)$ ]]; then
            EXTENSION="jpg"
        fi
        echo "  Downloading image ${IMAGE_COUNT}..."
        curl -sL -A "Mozilla/5.0" "$url" -o "${IMAGES_DIR}/${FILENAME}.${EXTENSION}"
        IMAGE_COUNT=$((IMAGE_COUNT + 1))
    fi
done <<< "$IMAGE_URLS"

echo "Downloaded ${IMAGE_COUNT} images to ${IMAGES_DIR}/"

# Copy images to bundle
echo "Copying images to bundle..."
cp "${IMAGES_DIR}"/* "${BUNDLE_IMAGES_DIR}/" 2>/dev/null || echo "No images to copy"

# Compile the Swift file into a dynamic library
swiftc -emit-library \
    -o "${SAVER_BUNDLE}/Contents/MacOS/${SAVER_NAME}" \
    -module-name "${SAVER_NAME}" \
    -target arm64-apple-macos12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework ScreenSaver \
    -framework AppKit \
    "${SRC_DIR}/${SAVER_NAME}.swift"

echo "Build complete: ${SAVER_BUNDLE}"
echo ""
echo "To install the screensaver:"
echo "  1. Double-click ${SAVER_BUNDLE} in Finder, or"
echo "  2. Copy to ~/Library/Screen Savers/"
echo ""
echo "To install system-wide, copy to /Library/Screen Savers/"
