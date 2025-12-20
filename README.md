# TRELLIS.2 Docker

### 1. Setup
```bash
# Initialize submodules
git submodule update --init --recursive

# Create .env with your Hugging Face token
echo "HF_TOKEN=your_huggingface_token_here" > .env
```

### 2. Launch
```bash
docker compose up --build
```
Access the interface at `http://localhost:7860`.

**Note:** The first build will take some time due to CUDA extension compilation and model weight downloads.
