FROM nvcr.io/nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04
ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl wget build-essential \
    cmake ninja-build pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libsqlite3-dev libffi-dev liblzma-dev \
    ffmpeg \
    python3 python3-pip python3-dev python3-venv \
    # X11 and OpenGL libraries (required for rendering) \
    libx11-dev libxext-dev libxi-dev libxxf86vm-dev libxrender-dev libxfixes-dev \
    mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
    libegl1-mesa-dev libgles2-mesa-dev \
    # Image processing libraries \
    libjpeg-dev libtiff-dev libopenjp2-7-dev liblcms2-dev libwebp-dev libfreetype6-dev libpng-dev \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create and activate Python virtual environment
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --upgrade pip setuptools wheel
ENV PATH="/opt/venv/bin:${PATH}"

# Configure CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda-12.9
ENV PATH="$CUDA_HOME/bin:${PATH}"
ENV LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
# List of CUDA architectures for PyTorch compilation (Blackwell and PTX for compatibility)
ENV TORCH_CUDA_ARCH_LIST="12.1+PTX"

# Triton settings: ptxas path and cache directory
ENV TRITON_PTXAS_PATH="$CUDA_HOME/bin/ptxas"
ENV TRITON_CACHE_DIR="/root/.triton"

# Install PyTorch (nightly build with CUDA 12.9 support)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129

# Install auxiliary tools for Hugging Face and optimization
RUN pip install --no-cache-dir -U "huggingface_hub[hf_xet,cli]" psutil packaging ninja

# Install TRELLIS dependencies
# NOTE: FlashAttention installation may take a long time (30+ minutes)
ENV PIP_PREFER_BINARY=1
RUN pip install flash_attn==2.7.4.post1 --no-build-isolation

# 1. Uninstall preinstalled binary torchvision
# 2. Build and install from source for architecture 12.1
RUN pip uninstall -y torchvision && \
    git clone --branch main https://github.com/pytorch/vision.git /tmp/torchvision && \
    cd /tmp/torchvision && \
    # Install system dependencies for build (if missing)
    apt-get update && apt-get install -y libpng-dev libjpeg-dev && \
    # Build: FORCE_CUDA=1 ensures kernel compilation,
    # --no-build-isolation uses already installed nightly-torch
    FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST="12.1" pip install --no-build-isolation . && \
    rm -rf /tmp/torchvision

# Install core Python packages for data processing and visualization
RUN pip install --no-cache-dir \
    imageio imageio-ffmpeg tqdm easydict opencv-python-headless ninja \
    trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard \
    Pillow kornia timm==1.0.12 \
    && pip install --no-cache-dir git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# Clone repositories with CUDA extensions to a temporary directory
RUN mkdir -p /tmp/extensions \
    && git clone -b main --recursive https://github.com/microsoft/TRELLIS.2.git /tmp/extensions/TRELLIS.2 \
    && git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git /tmp/extensions/nvdiffrast \
    && git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/extensions/nvdiffrec \
    && git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/extensions/CuMesh \
    && git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/extensions/FlexGEMM

# Build and install CUDA extensions
RUN pip install /tmp/extensions/nvdiffrast --no-build-isolation
RUN pip install /tmp/extensions/nvdiffrec --no-build-isolation
RUN pip install /tmp/extensions/CuMesh --no-build-isolation
RUN pip install /tmp/extensions/FlexGEMM --no-build-isolation
RUN pip install /tmp/extensions/TRELLIS.2/o-voxel --no-build-isolation

# Set working directory
WORKDIR /workspace/TRELLIS.2

# Argument to force entrypoint layer update (used for debugging the entry script)
ARG ENTRYPOINT_REV=0

# Copy and set permissions for the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set default attention backend
ENV ATTN_BACKEND=flash-attn

# Ports are not exposed by default. Start via entrypoint.sh.
ENTRYPOINT ["/entrypoint.sh"]

LABEL authors="dr-vij (Viktor Grigorev)"
LABEL description="TRELLIS.2 environment (CUDA 12.9, PyTorch cu129 nightly) for DGX Spark/Blackwell"
