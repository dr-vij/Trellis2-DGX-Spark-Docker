# TRELLIS.2 Docker (DGX SPARK)

Docker image optimized for DGX SPARK.

Original repository: [microsoft/TRELLIS.2](https://github.com/microsoft/TRELLIS.2)

### 1. Setup
```bash
# Initialize submodules
git submodule update --init --recursive

# Create .env with your Hugging Face token
echo "HF_TOKEN=your_huggingface_token_here" > .env
```
**Mandatory:** Request access to these models on Hugging Face:
- [DINOv3](https://huggingface.co/collections/facebook/dinov3)
- [RMBG-2.0](https://huggingface.co/briaai/RMBG-2.0)

### 2. Launch
```bash
docker compose up --build
```
Access: `http://localhost:7860`

**Note:** First build takes time (CUDA compilation + model downloads).
