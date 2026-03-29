"""Generate 4 notification audio files using Spark-TTS voice creation mode.

Runs inside Docker container. Uses SparkTTS API directly (not CLI)
for control over output file naming.

Volume mounts:
  - Model weights: /app/pretrained_models/Spark-TTS-0.5B
  - Output dir:    /output/ -> host ~/.claude/
"""
import os
import subprocess
from pathlib import Path

import torch
import soundfile as sf

# Voice creation parameters (D-04: female, low pitch, low speed)
VOICE_PARAMS = {
    "gender": "female",
    "pitch": "low",
    "speed": "low",
}

# 4 notification definitions (D-05)
NOTIFICATIONS = [
    {"name": "complete",  "text": "主人，任务完成了"},
    {"name": "confirm",   "text": "主人，请确认一下"},
    {"name": "error",     "text": "主人，出错了"},
    {"name": "progress",  "text": "主人，还在进行中"},
]

MODEL_DIR = os.environ.get("MODEL_DIR", "/app/pretrained_models/Spark-TTS-0.5B")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/output")

# Ensure huggingface cache is writable when running as non-root in Docker
_HF_CACHE = os.path.join(OUTPUT_DIR, ".hf_cache")
os.environ.setdefault("HF_HOME", _HF_CACHE)
os.environ.setdefault("TRANSFORMERS_CACHE", os.path.join(_HF_CACHE, "transformers"))
os.environ.setdefault("HF_HUB_CACHE", os.path.join(_HF_CACHE, "hub"))


def download_model(model_dir: str) -> None:
    """Download model weights via huggingface_hub if not present (D-02)."""
    # Check if model weights exist (look for actual safetensors, not just tokenizer files)
    llm_safetensors = os.path.join(model_dir, "LLM", "model.safetensors")
    if os.path.isfile(llm_safetensors):
        print(f"Model already exists at {model_dir}, skipping download.")
        return

    print(f"Downloading Spark-TTS-0.5B model to {model_dir}...")
    os.makedirs(model_dir, exist_ok=True)
    from huggingface_hub import snapshot_download
    snapshot_download(
        repo_id="SparkAudio/Spark-TTS-0.5B",
        local_dir=model_dir,
    )
    print("Model download complete.")


def generate_one(model, text: str, wav_path: str) -> None:
    """Generate a single WAV file using voice creation mode."""
    with torch.no_grad():
        wav = model.inference(
            text=text,
            gender=VOICE_PARAMS["gender"],
            pitch=VOICE_PARAMS["pitch"],
            speed=VOICE_PARAMS["speed"],
        )
    sf.write(wav_path, wav, samplerate=16000)


def wav_to_mp3(wav_path: str, mp3_path: str) -> None:
    """Convert WAV to MP3 using ffmpeg (D-06: libmp3lame, -qscale:a 2)."""
    subprocess.run([
        "ffmpeg", "-y", "-i", wav_path,
        "-codec:a", "libmp3lame", "-qscale:a", "2",
        mp3_path,
    ], check=True, capture_output=True)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Auto-download model if not present (D-02)
    download_model(MODEL_DIR)

    # Auto-detect device -- do NOT pass --device as int (Pitfall 1 from RESEARCH)
    if torch.cuda.is_available():
        device = torch.device("cuda:0")
        print(f"Using GPU: {device}")
    else:
        device = torch.device("cpu")
        print("Using CPU (no GPU detected)")

    # Import SparkTTS AFTER model download ensures files are present
    from cli.SparkTTS import SparkTTS
    model = SparkTTS(MODEL_DIR, device)
    print(f"Model loaded from {MODEL_DIR}")

    for notif in NOTIFICATIONS:
        wav_path = os.path.join(OUTPUT_DIR, f"notify-{notif['name']}.wav")
        mp3_path = os.path.join(OUTPUT_DIR, f"notify-{notif['name']}.mp3")

        print(f"Generating: {notif['name']} -- {notif['text']}")
        generate_one(model, notif["text"], wav_path)
        wav_to_mp3(wav_path, mp3_path)
        os.remove(wav_path)  # Clean up intermediate WAV
        print(f"  -> {mp3_path}")

    print("\nAll 4 notification audio files generated successfully.")


if __name__ == "__main__":
    main()
