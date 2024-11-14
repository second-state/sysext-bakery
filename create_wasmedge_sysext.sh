#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasmedge release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# clean and obtain the specified version
rm -f "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
curl -o "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -L "https://github.com/WasmEdge/WasmEdge/releases/download/${VERSION}/WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
rm -f "WasmEdge-plugin-wasi_nn-ggml-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
curl -o "WasmEdge-plugin-wasi_nn-ggml-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -L "https://github.com/WasmEdge/WasmEdge/releases/download/${VERSION}/WasmEdge-plugin-wasi_nn-ggml-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
rm -f "WasmEdge-plugin-wasi_nn-whisper-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
curl -o "WasmEdge-plugin-wasi_nn-whisper-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -L "https://github.com/WasmEdge/WasmEdge/releases/download/${VERSION}/WasmEdge-plugin-wasi_nn-whisper-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
rm -f "llama-api-server.wasm"
curl -o "llama-api-server.wasm" -L "https://github.com/LlamaEdge/LlamaEdge/releases/download/0.14.15/llama-api-server.wasm"
rm -f "whisper-api-server.wasm"
curl -o "whisper-api-server.wasm" -L "https://github.com/LlamaEdge/whisper-api-server/releases/download/0.3.2/whisper-api-server.wasm"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasmedge into SYSEXTNAME/
tar --force-local -xvf "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -C "${SYSEXTNAME}"

# ends up in WasmEdge-${VERSION}-Linux/bin/wasmedge -- there's bin/ include/ lib/ to clean up

# clean downloaded tarball
rm "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin # binary
mkdir -p "${SYSEXTNAME}"/usr/lib/wasmedge # .so files
mkdir -p "${SYSEXTNAME}"/usr/lib/plugin-ggml # wasi-nn-ggml
mkdir -p "${SYSEXTNAME}"/usr/lib/plugin-whisper # wasi-nn-whisper
mkdir -p "${SYSEXTNAME}"/usr/lib/wasm # for wasm applications


# extract plugins
tar --force-local -xvf "WasmEdge-plugin-wasi_nn-ggml-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -C "${SYSEXTNAME}/usr/lib/plugin-ggml"
tar --force-local -xvf "WasmEdge-plugin-wasi_nn-whisper-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -C "${SYSEXTNAME}/usr/lib/plugin-whisper"

rm -f "WasmEdge-plugin-wasi_nn-ggml-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
rm -f "WasmEdge-plugin-wasi_nn-whisper-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"

mv "${SYSEXTNAME}"/WasmEdge-"${VERSION}"-Linux/bin/wasmedge "${SYSEXTNAME}"/usr/bin/
mv "${SYSEXTNAME}"/WasmEdge-"${VERSION}"-Linux/lib/* "${SYSEXTNAME}"/usr/lib/wasmedge/
mv "llama-api-server.wasm" "${SYSEXTNAME}"/usr/lib/wasm
mv "whisper-api-server.wasm" "${SYSEXTNAME}"/usr/lib/wasm

# clean up any extracted mess # currently in WasmEdge-"${VERSION}"-Linux/bin/wasmedge -- there's bin/ include/ lib/ to clean up
rm -rf "${SYSEXTNAME}"/WasmEdge-"${VERSION}"-Linux/bin/ "${SYSEXTNAME}"/WasmEdge-"${VERSION}"-Linux/include/ "${SYSEXTNAME}"/WasmEdge-"${VERSION}"-Linux/lib

echo "============= Show the current sysext contents ============="
tree "${SYSEXTNAME}"
echo "============================================================"

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}" 
