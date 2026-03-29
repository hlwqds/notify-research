FROM python:3.12-slim

# System dependencies (D-11: ffmpeg for WAV->MP3 conversion, libsndfile1 for soundfile)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# PyTorch CPU-only (D-10: separate index to avoid CUDA bloat)
RUN pip install --no-cache-dir \
    torch==2.5.1 torchaudio==2.5.1 \
    --index-url https://download.pytorch.org/whl/cpu

# Spark-TTS Python dependencies (excludes gradio, includes huggingface_hub)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Clone Spark-TTS source (needed for cli/ and sparktts/ packages)
RUN git clone --depth 1 https://github.com/SparkAudio/Spark-TTS.git /tmp/spark-tts && \
    cp -r /tmp/spark-tts/cli /app/cli && \
    cp -r /tmp/spark-tts/sparktts /app/sparktts && \
    rm -rf /tmp/spark-tts

# Copy generation script
COPY generate.py .

# Create output directory (mounted at runtime)
RUN mkdir -p /output

# Model directory created at runtime via volume mount (D-01, D-03)
# ~/.cache/spark-tts/ -> /app/pretrained_models/Spark-TTS-0.5B
# ~/.claude/ -> /output/

CMD ["python", "generate.py"]
