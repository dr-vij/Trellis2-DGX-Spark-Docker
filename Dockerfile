FROM nvcr.io/nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04
ARG DEBIAN_FRONTEND=noninteractive

# ——— System prerequisites ———
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl wget build-essential \
    cmake ninja-build pkg-config \
    libssl-dev zlib1g-dev libbz2-dev libsqlite3-dev libffi-dev liblzma-dev \
    ffmpeg \
    python3 python3-pip python3-dev python3-venv \
    libx11-dev libxext-dev libxi-dev libxxf86vm-dev libxrender-dev libxfixes-dev \
    mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev \
    libegl1-mesa-dev libgles2-mesa-dev \
    libjpeg-dev libtiff-dev libopenjp2-7-dev liblcms2-dev libwebp-dev libfreetype6-dev libpng-dev \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ——— Create and use a dedicated virtual environment
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --upgrade pip setuptools wheel
ENV PATH="/opt/venv/bin:${PATH}"

# ——— CUDA 12.9 environment ———
ENV CUDA_HOME=/usr/local/cuda-12.9
ENV PATH="$CUDA_HOME/bin:${PATH}"
ENV LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH}"
# Blackwell arch, DGX Spark
ENV TORCH_CUDA_ARCH_LIST="12.1+PTX"

# Important for Triton: use system ptxas and enable cache
ENV TRITON_PTXAS_PATH="$CUDA_HOME/bin/ptxas"
ENV TRITON_CACHE_DIR="/root/.triton"

# ——— PyTorch nightly/cu129 and helpers ———
# Use PyTorch cu130 wheels (examples in existing images)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129

# Faster model downloads and common tooling
RUN pip install --no-cache-dir -U "huggingface_hub[hf_xet,cli]" psutil packaging ninja

#TRELLIS DEPENDENCIES START (taken from setup.sh but replaced Pillow)
# Install FlashAttention 2 in the image (no build isolation so it can find torch)
# THIS STEP IS VERY VERY VERY VERY LONG.
ENV PIP_PREFER_BINARY=1
RUN pip install flash_attn==2.7.4.post1 --no-build-isolation

RUN pip install --no-cache-dir \
    imageio imageio-ffmpeg tqdm easydict opencv-python-headless ninja \
    trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard \
    Pillow kornia timm \
    && pip install --no-cache-dir git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# ——— CUDA extensions: clone all repos ———
RUN mkdir -p /tmp/extensions \
    && git clone -b main --recursive https://github.com/microsoft/TRELLIS.2.git /tmp/extensions/TRELLIS.2 \
    && git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git /tmp/extensions/nvdiffrast \
    && git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/extensions/nvdiffrec \
    && git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/extensions/CuMesh \
    && git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/extensions/FlexGEMM

# ——— Install CUDA extensions ———
RUN pip install /tmp/extensions/nvdiffrast --no-build-isolation
RUN pip install /tmp/extensions/nvdiffrec --no-build-isolation
RUN pip install /tmp/extensions/CuMesh --no-build-isolation
RUN pip install /tmp/extensions/FlexGEMM --no-build-isolation
RUN pip install /tmp/extensions/TRELLIS.2/o-voxel --no-build-isolation

# Workspace
WORKDIR /workspace/TRELLIS.2

# Entrypoint (bump it to make docker rebuild from here if experimenting with entry point
ARG ENTRYPOINT_REV=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV ATTN_BACKEND=flash-attn

# No fixed ports required by TRELLIS.2; expose none by default
ENTRYPOINT ["/entrypoint.sh"]

LABEL authors="dr-vij (Viktor Grigorev)"
LABEL description="TRELLIS.2 environment (CUDA 12.9, PyTorch cu129 nightly) for DGX Spark/Blackwell"
