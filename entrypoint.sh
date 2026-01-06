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

# Determine which app to run
APP_SCRIPT=${APP_SCRIPT:-app.py}

# Run the specified app or custom command
if [ $# -eq 0 ]; then
  exec python "$APP_SCRIPT"
else
  exec "$@"
fi