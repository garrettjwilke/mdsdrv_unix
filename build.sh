#!/usr/bin/env bash
set -euo pipefail

# Check if directory argument is provided
if [ $# -eq 0 ]; then
  echo "ERROR: Directory argument is required" >&2
  echo "Usage: $0 <directory>" >&2
  echo "Example: $0 /path/to/mdsdrv (or base dir like /path/to/build)" >&2
  exit 1
fi

TARGET_DIR="$1"

# Expand ~ to home directory if present and drop trailing slash
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
TARGET_DIR="${TARGET_DIR%/}"

# If user passes a base directory (e.g., ~/build), append MDSDRV automatically
TARGET_BASENAME="$(basename "${TARGET_DIR}")"
if [ "${TARGET_BASENAME}" != "MDSDRV" ]; then
  BASE_DIR="${TARGET_DIR}"
  TARGET_NAME="MDSDRV"
else
  BASE_DIR="$(dirname "${TARGET_DIR}")"
  TARGET_NAME="${TARGET_BASENAME}"
fi

# Validate base directory
if [ -e "${BASE_DIR}" ] && [ ! -d "${BASE_DIR}" ]; then
  echo "ERROR: '${BASE_DIR}' exists but is not a directory" >&2
  exit 1
fi

if [ ! -d "${BASE_DIR}" ]; then
  echo "ERROR: Base directory '${BASE_DIR}' does not exist" >&2
  exit 1
fi

# Normalize to absolute paths
BASE_DIR="$(cd "${BASE_DIR}" && pwd)"
MDSDRV_DIR="${BASE_DIR}/${TARGET_NAME}"

# Validate target directory if it already exists
if [ -e "${MDSDRV_DIR}" ] && [ ! -d "${MDSDRV_DIR}" ]; then
  echo "ERROR: '${MDSDRV_DIR}' exists but is not a directory" >&2
  exit 1
fi

# Clone MDSDRV if it doesn't exist
if [ ! -d "${MDSDRV_DIR}" ]; then
  echo "Cloning MDSDRV repository to: ${MDSDRV_DIR}"
  git clone https://github.com/superctr/MDSDRV.git "${MDSDRV_DIR}"
else
  echo "MDSDRV directory already exists at ${MDSDRV_DIR}"
  echo "Updating repository..."
  pushd "${MDSDRV_DIR}" > /dev/null || exit 1
  git fetch origin
  git pull origin master || true
  popd > /dev/null || exit 1
fi

# Change to MDSDRV directory
cd "${MDSDRV_DIR}" || exit 1

# Set SCRIPT_DIR to the MDSDRV directory
SCRIPT_DIR="${MDSDRV_DIR}"

BUILD_DIR=${SCRIPT_DIR}/out
DEPS_DIR=${SCRIPT_DIR}/deps
BIN_DIR=${SCRIPT_DIR}/bin

# Pinned commit hashes for reproducible builds
SJASMPLUS_COMMIT="9d18ee7575fefee97cd8866361770b44a2966a67"
SJASMPLUS_LUABRIDGE_COMMIT="c19931b48bdd413dd54ec7852bc32c6468668f81"
CLOWNASM_COMMIT="1a3f6c6a0253c98214d3a611f0fc20348185897f"
CLOWNASM_CLOWNCOMMON_COMMIT="37d1efd90725a7c30dce5f38ea14f1bc3c29a52f"
SALVADOR_COMMIT="1662b625a8dcd6f3f7e3491c88840611776533f5"

error-message() {
  echo "ERROR: $1" >&2
  exit 1
}

check-command() {
  if ! command -v "$1" &> /dev/null; then
    error-message "Required command '$1' is not installed or not in PATH"
  fi
}

check-file() {
  if [ ! -f "$1" ]; then
    error-message "Required file '$1' does not exist"
  fi
}

check-directory() {
  if [ ! -d "$1" ]; then
    error-message "Required directory '$1' does not exist"
  fi
}

run-command() {
  local cmd="$1"
  shift
  echo "Running: $cmd $*"
  if ! "$cmd" "$@"; then
    error-message "Command failed: $cmd $*"
  fi
}

clean-deps-build() {
  local dep_dir="$1"
  if [ -d "$dep_dir" ]; then
    echo "Cleaning build artifacts in $dep_dir"
    pushd "$dep_dir" > /dev/null || error-message "Failed to enter directory: $dep_dir"
    
    # Clean common build artifacts
    find . -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".build" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name "obj" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.o" -delete 2>/dev/null || true
    find . -type f -name "*.a" -delete 2>/dev/null || true
    find . -type f -name "*.so" -delete 2>/dev/null || true
    find . -type f -name "*.dylib" -delete 2>/dev/null || true
    find . -type f -name "CMakeCache.txt" -delete 2>/dev/null || true
    find . -type d -name "CMakeFiles" -exec rm -rf {} + 2>/dev/null || true
    
    popd > /dev/null || error-message "Failed to return from directory: $dep_dir"
  fi
}

install-sjasmplus() {
  echo "Installing sjasmplus..."
  pushd "$DEPS_DIR" > /dev/null || error-message "Failed to enter deps directory"
  
  if [ ! -d "sjasmplus" ]; then
    echo "Cloning sjasmplus repository..."
    run-command git clone https://github.com/garrettjwilke/sjasmplus
  fi
  
  cd sjasmplus || error-message "Failed to enter sjasmplus directory"
  
  # Clean build artifacts
  make clean 2>/dev/null || true
  rm -f sjasmplus 2>/dev/null || true
  
  echo "Fetching latest changes..."
  run-command git fetch origin
  
  echo "Checking out pinned commit ${SJASMPLUS_COMMIT}..."
  run-command git checkout "${SJASMPLUS_COMMIT}"
  
  echo "Updating LuaBridge submodule to pinned commit..."
  run-command git submodule update --init LuaBridge
  cd LuaBridge || error-message "Failed to enter LuaBridge directory"
  run-command git checkout "${SJASMPLUS_LUABRIDGE_COMMIT}"
  cd .. || error-message "Failed to return from LuaBridge directory"
  
  echo "Building sjasmplus..."
  run-command make
  
  check-file "sjasmplus"
  echo "Copying sjasmplus to bin directory..."
  run-command cp sjasmplus "$BIN_DIR/"
  
  popd > /dev/null || error-message "Failed to return from deps directory"
  echo "sjasmplus installation complete"
}

install-salvador() {
  echo "Installing salvador..."
  pushd "$DEPS_DIR" > /dev/null || error-message "Failed to enter deps directory"
  
  if [ ! -d "salvador" ]; then
    echo "Cloning salvador repository..."
    run-command git clone https://github.com/emmanuel-marty/salvador.git
  else
    echo "salvador directory already exists, skipping clone"
  fi
  
  cd salvador || error-message "Failed to enter salvador directory"
  
  # Clean build artifacts
  make clean 2>/dev/null || true
  rm -f salvador 2>/dev/null || true
  
  echo "Fetching latest changes..."
  run-command git fetch origin
  
  echo "Checking out pinned commit ${SALVADOR_COMMIT}..."
  run-command git checkout "${SALVADOR_COMMIT}"
  
  echo "Building salvador..."
  run-command make
  
  check-file "salvador"
  echo "Copying salvador to bin directory..."
  run-command cp salvador "$BIN_DIR/"
  
  popd > /dev/null || error-message "Failed to return from deps directory"
  echo "salvador installation complete"
}

install-clownasm() {
  echo "Installing clownassembler..."
  pushd "$DEPS_DIR" > /dev/null || error-message "Failed to enter deps directory"
  
  if [ ! -d "clownassembler" ]; then
    echo "Cloning clownassembler repository..."
    run-command git clone https://github.com/garrettjwilke/clownassembler
  else
    echo "clownassembler directory already exists, skipping clone"
  fi
  
  cd clownassembler || error-message "Failed to enter clownassembler directory"
  
  # Clean build artifacts
  if [ -d "build" ]; then
    echo "Removing old build directory..."
    rm -rf build
  fi
  
  echo "Fetching latest changes..."
  run-command git fetch origin
  
  echo "Checking out pinned commit ${CLOWNASM_COMMIT}..."
  run-command git checkout "${CLOWNASM_COMMIT}"
  
  echo "Updating clowncommon submodule to pinned commit..."
  run-command git submodule update --init clowncommon
  cd clowncommon || error-message "Failed to enter clowncommon directory"
  run-command git checkout "${CLOWNASM_CLOWNCOMMON_COMMIT}"
  cd .. || error-message "Failed to return from clowncommon directory"
  
  echo "Creating build directory..."
  run-command mkdir -p build
  
  cd build || error-message "Failed to enter build directory"
  
  echo "Running cmake..."
  run-command cmake ..
  
  echo "Building clownassembler..."
  run-command cmake --build .
  
  check-file "clownassembler_asm68k"
  echo "Copying clownassembler_asm68k to bin directory..."
  run-command cp clownassembler_asm68k "$BIN_DIR/"
  
  popd > /dev/null || error-message "Failed to return from deps directory"
  echo "clownassembler installation complete"
}

# Check for required commands
echo "Checking for required tools..."
check-command git
check-command make
check-command cmake

# Setup directories
echo "Setting up directories..."
if [ -d "$BUILD_DIR" ]; then
  echo "Cleaning build directory..."
  rm -rf "$BUILD_DIR"
fi
run-command mkdir -p "$BUILD_DIR"

if [ -d "$BIN_DIR" ]; then
  echo "Cleaning bin directory..."
  rm -rf "$BIN_DIR"
fi
run-command mkdir -p "$BIN_DIR"

# Keep deps directory but clean build artifacts
if [ ! -d "$DEPS_DIR" ]; then
  echo "Creating deps directory..."
  run-command mkdir -p "$DEPS_DIR"
else
  echo "Cleaning build artifacts in deps directory..."
  clean-deps-build "$DEPS_DIR"
fi

# Install dependencies
install-sjasmplus
install-salvador
install-clownasm

# Verify binaries exist
echo "Verifying binaries..."
check-file "$BIN_DIR/sjasmplus"
check-file "$BIN_DIR/salvador"
check-file "$BIN_DIR/clownassembler_asm68k"

# Build project
echo "Building project..."

echo "Assembling mdssub.z80..."
run-command "$BIN_DIR/sjasmplus" src/mdssub.z80 --raw="${BUILD_DIR}/mdssub.bin"
check-file "${BUILD_DIR}/mdssub.bin"

echo "Compressing mdssub.bin..."
run-command "$BIN_DIR/salvador" "${BUILD_DIR}/mdssub.bin" "${BUILD_DIR}/mdssub.zx0"
check-file "${BUILD_DIR}/mdssub.zx0"

echo "Assembling mdsdrv.bin..."
run-command "$BIN_DIR/clownassembler_asm68k" /k /p /o ae- src/blob.68k,"${BUILD_DIR}/mdsdrv.bin"
check-file "${BUILD_DIR}/mdsdrv.bin"

echo "Verifying mdsdrv.bin SHA-256 hash..."
EXPECTED_HASH="34682d2b994409c3a3f0508bcf97c521c9b9873a6779e1f80b90755a16b1a617"
ACTUAL_HASH=$(shasum -a 256 "${BUILD_DIR}/mdsdrv.bin" | cut -d' ' -f1)
if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
  error-message "SHA-256 hash mismatch for mdsdrv.bin. Expected: $EXPECTED_HASH, Got: $ACTUAL_HASH"
fi
echo "SHA-256 hash verification passed: $ACTUAL_HASH"

echo "Build complete!"

