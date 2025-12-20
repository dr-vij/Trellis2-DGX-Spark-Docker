#!/bin/bash
set -e

echo "========================================"
echo "TRELLIS.2 Docker Environment start"
echo "========================================"

# Ensure CUDA env
export CUDA_HOME=${CUDA_HOME:-/usr/local/cuda-12.9}
export PATH="$CUDA_HOME/bin:${PATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
export ATTN_BACKEND=${ATTN_BACKEND:-flash-attn}

WORKDIR=/workspace/TRELLIS.2
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Clone repo if not mounted/present
if [ ! -d .git ]; then
  echo "Cloning TRELLIS.2 repository..."
  git clone -b main --recursive https://github.com/microsoft/TRELLIS.2.git tmp_clone
  shopt -s dotglob nullglob
  mv tmp_clone/* .
  rmdir tmp_clone || true
fi

echo "Repository ready at: $(pwd)"

# Print basic runtime info
echo "Python: $(python --version)"
echo "PyTorch: $(python -c 'import torch; print(torch.__version__)')"
echo "CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())')"
echo "CUDA Home: ${CUDA_HOME}"
echo "ATTN_BACKEND: ${ATTN_BACKEND}"

echo "========================================"
echo "Environment ready!"
echo "Working directory: $(pwd)"
echo "========================================"

# Patch app.py to bind to 0.0.0.0, demo gradio app.
sed -i 's/demo\.launch(css=css, head=head)/demo.launch(css=css, head=head, server_name="0.0.0.0")/' app.py

# run app.py default
if [ $# -eq 0 ]; then
  python app.py
else
  exec "$@"
fi