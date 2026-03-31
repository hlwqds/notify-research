"""Generate 4 notification audio files using Spark-TTS voice creation mode.

Runs inside Docker container. Uses SparkTTS API directly (not CLI)
for control over output file naming.

Volume mounts:
  - Model weights: /app/pretrained_models/Spark-TTS-0.5B
  - Output dir:    /output/ -> host ~/.claude/
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import torch
import soundfile as sf

# Default voice params (used when --voice is not specified, per D-10)
VOICE_PARAMS = {
    "gender": "female",
    "pitch": "low",
    "speed": "low",
}


def load_voice_config(voice_name: str) -> dict:
    """Load voice parameters from voices/{name}.json config file."""
    config_path = Path(__file__).parent / "voices" / f"{voice_name}.json"
    if not config_path.exists():
        print(f"错误：语音配置文件不存在: {config_path}")
        sys.exit(1)
    with open(config_path) as f:
        config = json.load(f)
    # Validate required fields
    required = {"gender", "pitch", "speed"}
    missing = required - set(config.keys())
    if missing:
        print(f"错误：语音配置缺少字段: {', '.join(missing)}")
        sys.exit(1)
    return config

# 4 notification definitions (D-05)
NOTIFICATIONS = [
    {"name": "complete",  "text": "主人，任务完成了"},
    {"name": "confirm",   "text": "主人，请确认一下"},
    {"name": "error",     "text": "主人，出错了"},
    {"name": "progress",  "text": "主人，还在进行中"},
]

MODEL_DIR = os.environ.get("MODEL_DIR", "/app/pretrained_models/Spark-TTS-0.5B")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/output")
GENERATE_TYPES = os.environ.get("GENERATE_TYPES", None)
GENERATE_VOICE = os.environ.get("GENERATE_VOICE", None)

# Ensure huggingface cache is writable when running as non-root in Docker
_HF_CACHE = os.path.join(OUTPUT_DIR, ".hf_cache")
os.environ.setdefault("HF_HOME", _HF_CACHE)
os.environ.setdefault("TRANSFORMERS_CACHE", os.path.join(_HF_CACHE, "transformers"))
os.environ.setdefault("HF_HUB_CACHE", os.path.join(_HF_CACHE, "hub"))


def parse_args():
    """Parse command-line arguments for selective notification generation."""
    parser = argparse.ArgumentParser(
        description="生成 Claude Code 语音通知音频",
    )
    parser.add_argument(
        "--type", "-t",
        type=str,
        default=GENERATE_TYPES,
        help="要生成的通知类型，逗号分隔 (complete,confirm,error,progress)。默认全部生成。",
    )
    parser.add_argument(
        "--voice", "-v",
        type=str,
        default=GENERATE_VOICE,
        help="语音风格名称，从 voices/<name>.json 加载配置。默认使用内置参数。",
    )
    return parser.parse_args()


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


def generate_one(model, text: str, wav_path: str, voice_params: dict) -> None:
    """Generate a single WAV file using voice creation mode."""
    with torch.no_grad():
        wav = model.inference(
            text=text,
            gender=voice_params["gender"],
            pitch=voice_params["pitch"],
            speed=voice_params["speed"],
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
    # Parse arguments for selective generation
    args = parse_args()

    # Load voice config if specified, otherwise use default VOICE_PARAMS
    if args.voice:
        voice_params = load_voice_config(args.voice)
    else:
        voice_params = VOICE_PARAMS

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Voice-aware output directory (per D-08)
    if args.voice:
        output_subdir = os.path.join(OUTPUT_DIR, args.voice)
    else:
        output_subdir = OUTPUT_DIR
    os.makedirs(output_subdir, exist_ok=True)

    # Build notification list based on --type filter
    valid_names = set(n["name"] for n in NOTIFICATIONS)
    notifications = NOTIFICATIONS
    if args.type is not None:
        requested = [t.strip() for t in args.type.split(",")]
        invalid = [t for t in requested if t not in valid_names]
        if invalid:
            print(f"错误：未知的通知类型: {', '.join(invalid)}")
            print(f"有效类型: {', '.join(sorted(valid_names))}")
            sys.exit(1)
        notifications = [n for n in NOTIFICATIONS if n["name"] in requested]

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

    for notif in notifications:
        wav_path = os.path.join(output_subdir, f"notify-{notif['name']}.wav")
        mp3_path = os.path.join(output_subdir, f"notify-{notif['name']}.mp3")

        print(f"Generating: {notif['name']} -- {notif['text']}")
        generate_one(model, notif["text"], wav_path, voice_params)
        wav_to_mp3(wav_path, mp3_path)
        os.remove(wav_path)  # Clean up intermediate WAV
        print(f"  -> {mp3_path}")

    print(f"\n{len(notifications)} 个通知音频文件生成完毕。")


if __name__ == "__main__":
    main()
