#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="spark-tts-notify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$HOME/.cache/spark-tts"
OUTPUT_DIR="$HOME/.claude"

trap 'echo "错误：脚本执行失败，请检查上方输出" >&2' ERR

FORCE_REBUILD=""
NOTIFY_TYPES=""
VOICE_NAME=""

show_help() {
    cat <<'EOF'
Claude Code 语音通知生成脚本

用法: ./generate.sh [选项]

选项:
  --type, -t <类型>    要生成的通知类型，逗号分隔
                      可选: complete, confirm, error, progress
                      默认: 全部生成
  --voice, -v <名称>    语音风格名称，从 voices/<name>.json 加载配置
                      输出到 audio/voices/<name>/
  --force-rebuild     强制重建 Docker 镜像
  --help, -h          显示此帮助信息

示例:
  ./generate.sh                        # 生成全部 4 种通知
  ./generate.sh --type confirm,error   # 只生成确认和错误通知
  ./generate.sh --voice deep           # 使用 deep 语音风格生成
  ./generate.sh --force-rebuild        # 强制重建镜像后生成
EOF
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --type|-t)
            if [[ $# -lt 2 ]]; then
                echo "错误：--type 需要一个参数" >&2
                exit 1
            fi
            NOTIFY_TYPES="$2"
            shift 2
            ;;
        --voice|-v)
            if [[ $# -lt 2 ]]; then
                echo "错误：--voice 需要一个参数" >&2
                exit 1
            fi
            VOICE_NAME="$2"
            shift 2
            ;;
        --force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "错误：未知选项: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Override output directory when --voice is specified (per D-09)
if [[ -n "$VOICE_NAME" ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/audio/voices/$VOICE_NAME"
    echo "==> 语音风格: $VOICE_NAME"
    echo "==> 输出目录: $OUTPUT_DIR"
fi

# Step 1: Docker build
if [[ "$FORCE_REBUILD" == "true" ]]; then
    echo "==> 强制重建 Docker 镜像..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
elif docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "==> Docker 镜像已存在，跳过构建"
else
    echo "==> Docker 镜像不存在，开始构建..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Step 2: Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Step 3: Run TTS generation
DOCKER_ARGS=(
    --rm
    --user "$(id -u):$(id -g)"
    -v "$MODEL_DIR:/app/pretrained_models/Spark-TTS-0.5B:z"
    -v "$OUTPUT_DIR:/output:z"
)

if [[ -n "$NOTIFY_TYPES" ]]; then
    DOCKER_ARGS+=(--env "GENERATE_TYPES=$NOTIFY_TYPES")
    echo "==> 开始生成通知音频: $NOTIFY_TYPES..."
else
    echo "==> 开始生成通知音频..."
fi

if [[ -n "$VOICE_NAME" ]]; then
    DOCKER_ARGS+=(--env "GENERATE_VOICE=$VOICE_NAME")
fi

docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME"

# Step 4: Verify output
verify_output() {
    local name="$1"
    local filepath="$OUTPUT_DIR/notify-${name}.mp3"
    if [[ ! -f "$filepath" ]]; then
        echo "  [FAIL] notify-${name}.mp3 -- 文件不存在"
        return 1
    fi
    if ! file "$filepath" | grep -qi "MPEG.*layer III"; then
        echo "  [FAIL] notify-${name}.mp3 -- 文件格式无效"
        file "$filepath"
        return 1
    fi
    echo "  [OK] notify-${name}.mp3"
}

if [[ -n "$NOTIFY_TYPES" ]]; then
    IFS=',' read -ra VERIFY_TYPES <<< "$NOTIFY_TYPES"
else
    VERIFY_TYPES=(complete confirm error progress)
fi

echo "==> 验证输出文件..."
for t in "${VERIFY_TYPES[@]}"; do
    verify_output "$t"
done

echo "==> 验证通过"
echo "==> 全部完成！"
