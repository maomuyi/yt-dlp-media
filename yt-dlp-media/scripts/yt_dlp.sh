#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
WORK_ROOT=$(pwd)
OUTPUT_ROOT=${YTDLP_MEDIA_ROOT:-"$WORK_ROOT/output/yt-dlp-media"}
JOBS_ROOT=${YTDLP_MEDIA_JOBS_ROOT:-"$SKILL_DIR/jobs"}
COOKIES_FROM_BROWSER=${YTDLP_COOKIES_FROM_BROWSER:-}

mkdir -p "$OUTPUT_ROOT" "$JOBS_ROOT"

emit_result() {
  local key=$1
  shift
  printf 'RESULT:%s=%s\n' "$key" "$*"
}

die() {
  local code=$1
  shift
  emit_result status failed
  emit_result error_code "$code"
  emit_result error_hint "$*"
  printf '%s: %s\n' "$code" "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_ytdlp() {
  need_cmd yt-dlp || die ERR_NO_YTDLP "Install yt-dlp and ensure it is available in PATH"
}

need_ffmpeg() {
  need_cmd ffmpeg || die ERR_NO_FFMPEG "Install ffmpeg before using this command"
  need_cmd ffprobe || die ERR_NO_FFMPEG "Install ffprobe before using this command"
}

classify_error() {
  local stderr_file=$1
  local content
  content=$(cat "$stderr_file" 2>/dev/null || true)

  if printf '%s' "$content" | grep -Eqi 'Unsupported URL|No video formats found|Unable to handle request|Unsupported URL scheme'; then
    printf 'ERR_UNSUPPORTED_URL|The URL is unsupported or yielded no usable media formats\n'
  elif printf '%s' "$content" | grep -Eqi 'Sign in|login required|members-only|private video|confirm your age|cookies'; then
    printf 'ERR_AUTH_REQUIRED|This media likely requires cookies or authenticated access\n'
  elif printf '%s' "$content" | grep -Eqi 'Video unavailable|This video is unavailable|not available in your country|has been removed|Private video'; then
    printf 'ERR_CONTENT_UNAVAILABLE|The media exists but is currently unavailable, removed, private, or region-restricted\n'
  elif printf '%s' "$content" | grep -Eqi 'HTTP Error 429|Too Many Requests|rate limit|temporarily blocked'; then
    printf 'ERR_RATE_LIMITED|The site is rate limiting requests; retry later or reduce concurrency\n'
  elif printf '%s' "$content" | grep -Eqi 'ExtractorError|Unsupported JS expression|Failed to extract|broken|nsig'; then
    printf 'ERR_EXTRACTOR_BROKEN|Update yt-dlp first; the upstream extractor may be broken\n'
  else
    printf 'ERR_DOWNLOAD_FAILED|Inspect stderr for the underlying yt-dlp failure\n'
  fi
}

infer_site_profile() {
  local url=$1
  case "$url" in
    *youtube.com*|*youtu.be*|*bilibili.com*) printf 'balanced\n' ;;
    *xiaohongshu.com*|*x.com*|*twitter.com*) printf 'mobile\n' ;;
    *) printf 'balanced\n' ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/yt_dlp.sh probe --url URL
  ./scripts/yt_dlp.sh video --url URL [--preset best|balanced|mobile] [--output-dir DIR]
  ./scripts/yt_dlp.sh audio --url URL [--preset audio_only] [--format mp3|m4a|wav|flac|opus] [--output-dir DIR]
  ./scripts/yt_dlp.sh subtitles --url URL [--mode write|embed] [--langs en,zh-Hans] [--output-dir DIR]
  ./scripts/yt_dlp.sh job submit <probe|video|audio|subtitles> [task options]
  ./scripts/yt_dlp.sh job status JOB_ID
  ./scripts/yt_dlp.sh job tail JOB_ID
  ./scripts/yt_dlp.sh job list
EOF
}

parse_common_args() {
  URL=""
  PRESET=""
  MODE=""
  LANGS="en.*"
  AUDIO_FORMAT="mp3"
  OUTPUT_DIR=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)
        URL=${2:-}
        shift 2
        ;;
      --preset)
        PRESET=${2:-}
        shift 2
        ;;
      --mode)
        MODE=${2:-}
        shift 2
        ;;
      --langs)
        LANGS=${2:-}
        shift 2
        ;;
      --format)
        AUDIO_FORMAT=${2:-}
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR=${2:-}
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die ERR_DOWNLOAD_FAILED "Unknown option: $1"
        ;;
    esac
  done
  [[ -n "$URL" ]] || die ERR_DOWNLOAD_FAILED "Pass --url URL"
}

append_cookies_args() {
  if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
    YTDLP_ARGS+=(--cookies-from-browser "$COOKIES_FROM_BROWSER")
  fi
}

run_yt_dlp() {
  local out_dir=$1
  shift
  local stderr_file stdout_file err_code err_hint
  stderr_file=$(mktemp)
  stdout_file=$(mktemp)

  mkdir -p "$out_dir"
  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    emit_result status succeeded
    emit_result log "$stdout_file"
    return 0
  fi

  cat "$stdout_file" >&2 || true
  cat "$stderr_file" >&2 || true
  IFS='|' read -r err_code err_hint < <(classify_error "$stderr_file")
  emit_result status failed
  emit_result log "$stderr_file"
  emit_result error_code "$err_code"
  emit_result error_hint "$err_hint"
  return 1
}

probe_cmd() {
  parse_common_args "$@"
  need_ytdlp

  local profile out_dir stderr_file stdout_file
  local extractor title live_status availability err_code err_hint
  profile=$(infer_site_profile "$URL")
  out_dir=${OUTPUT_DIR:-"$OUTPUT_ROOT/probe"}
  mkdir -p "$out_dir"
  stderr_file=$(mktemp)
  stdout_file=$(mktemp)

  local -a cmd=(yt-dlp --dump-single-json --skip-download --no-warnings)
  if [[ -n "$COOKIES_FROM_BROWSER" ]]; then
    cmd+=(--cookies-from-browser "$COOKIES_FROM_BROWSER")
  fi
  cmd+=("$URL")

  if "${cmd[@]}" >"$stdout_file" 2>"$stderr_file"; then
    extractor=$(sed -n 's/.*"extractor_key": *"\([^"]*\)".*/\1/p' "$stdout_file" | head -n1)
    title=$(sed -n 's/.*"title": *"\([^"]*\)".*/\1/p' "$stdout_file" | head -n1)
    live_status=$(sed -n 's/.*"live_status": *"\([^"]*\)".*/\1/p' "$stdout_file" | head -n1)
    availability=$(sed -n 's/.*"availability": *"\([^"]*\)".*/\1/p' "$stdout_file" | head -n1)
    emit_result status succeeded
    emit_result url "$URL"
    emit_result site_profile "$profile"
    emit_result info_json "$stdout_file"
    [[ -n "$extractor" ]] && emit_result extractor "$extractor"
    [[ -n "$title" ]] && emit_result title "$title"
    [[ -n "$live_status" ]] && emit_result live_status "$live_status"
    [[ -n "$availability" ]] && emit_result availability "$availability"
    return 0
  fi

  cat "$stderr_file" >&2 || true
  IFS='|' read -r err_code err_hint < <(classify_error "$stderr_file")
  emit_result status failed
  emit_result url "$URL"
  emit_result site_profile "$profile"
  emit_result error_code "$err_code"
  emit_result error_hint "$err_hint"
  emit_result log "$stderr_file"
  return 1
}

video_cmd() {
  parse_common_args "$@"
  need_ytdlp
  need_ffmpeg

  local profile out_dir template
  local format_sort format_selector concurrent filepath
  profile=$(infer_site_profile "$URL")
  PRESET=${PRESET:-$profile}
  out_dir=${OUTPUT_DIR:-"$OUTPUT_ROOT/video"}
  template="$out_dir/%(title).180B [%(id)s].%(ext)s"

  case "$PRESET" in
    best)
      format_selector="bv*+ba/b"
      format_sort="res,fps,hdr:12,vcodec,acodec,size,br"
      concurrent=4
      ;;
    balanced)
      format_selector="bv*+ba/b"
      format_sort="res:1080,fps,vcodec,acodec,size,br"
      concurrent=4
      ;;
    mobile)
      format_selector="b/bv+ba"
      format_sort="+size,+br,res:720,fps"
      concurrent=2
      ;;
    *)
      die ERR_DOWNLOAD_FAILED "Unknown video preset: $PRESET"
      ;;
  esac

  YTDLP_ARGS=(
    yt-dlp
    --no-warnings
    --write-info-json
    --write-thumbnail
    --embed-metadata
    --restrict-filenames
    --concurrent-fragments "$concurrent"
    -f "$format_selector"
    -S "$format_sort"
    -o "$template"
  )
  append_cookies_args
  YTDLP_ARGS+=("$URL")

  if run_yt_dlp "$out_dir" "${YTDLP_ARGS[@]}"; then
    filepath=$(find "$out_dir" -type f ! -name '*.info.json' ! -name '*.jpg' ! -name '*.png' ! -name '*.webp' | head -n1 || true)
    emit_result preset "$PRESET"
    emit_result site_profile "$profile"
    [[ -n "$filepath" ]] && emit_result file "$filepath"
    emit_result output_dir "$out_dir"
  else
    emit_result preset "$PRESET"
    emit_result site_profile "$profile"
    return 1
  fi
}

audio_cmd() {
  parse_common_args "$@"
  need_ytdlp
  need_ffmpeg

  local profile out_dir template filepath
  profile=$(infer_site_profile "$URL")
  PRESET=${PRESET:-audio_only}
  out_dir=${OUTPUT_DIR:-"$OUTPUT_ROOT/audio"}
  template="$out_dir/%(title).180B [%(id)s].%(ext)s"

  case "$PRESET" in
    audio_only) ;;
    *)
      die ERR_DOWNLOAD_FAILED "Unknown audio preset: $PRESET"
      ;;
  esac

  YTDLP_ARGS=(
    yt-dlp
    --no-warnings
    --restrict-filenames
    --write-info-json
    --write-thumbnail
    --embed-metadata
    --extract-audio
    --audio-format "$AUDIO_FORMAT"
    --audio-quality 0
    -f "ba/b"
    -o "$template"
  )
  append_cookies_args
  YTDLP_ARGS+=("$URL")

  if run_yt_dlp "$out_dir" "${YTDLP_ARGS[@]}"; then
    filepath=$(find "$out_dir" -type f ! -name '*.info.json' ! -name '*.jpg' ! -name '*.png' ! -name '*.webp' | head -n1 || true)
    emit_result preset "$PRESET"
    emit_result site_profile "$profile"
    [[ -n "$filepath" ]] && emit_result file "$filepath"
    emit_result output_dir "$out_dir"
  else
    emit_result preset "$PRESET"
    emit_result site_profile "$profile"
    return 1
  fi
}

subtitles_cmd() {
  parse_common_args "$@"
  need_ytdlp

  local out_dir
  out_dir=${OUTPUT_DIR:-"$OUTPUT_ROOT/subtitles"}
  MODE=${MODE:-write}

  YTDLP_ARGS=(
    yt-dlp
    --no-warnings
    --restrict-filenames
    --sub-langs "$LANGS"
    -o "$out_dir/%(title).180B [%(id)s].%(ext)s"
  )
  append_cookies_args

  case "$MODE" in
    write)
      YTDLP_ARGS+=(--skip-download --write-subs --write-auto-subs)
      ;;
    embed)
      need_ffmpeg
      YTDLP_ARGS+=(--write-subs --write-auto-subs --embed-subs -f "bv*+ba/b")
      ;;
    *)
      die ERR_DOWNLOAD_FAILED "Unknown subtitles mode: $MODE"
      ;;
  esac

  YTDLP_ARGS+=("$URL")

  if run_yt_dlp "$out_dir" "${YTDLP_ARGS[@]}"; then
    emit_result mode "$MODE"
    emit_result subtitles "$out_dir"
  else
    emit_result mode "$MODE"
    return 1
  fi
}

job_dir() {
  printf '%s/%s\n' "$JOBS_ROOT" "$1"
}

job_submit_cmd() {
  local task=${1:-}
  shift || true
  [[ -n "$task" ]] || die ERR_DOWNLOAD_FAILED "Pass a task after job submit"

  case "$task" in
    probe|video|audio|subtitles) ;;
    *)
      die ERR_DOWNLOAD_FAILED "Unsupported job task: $task"
      ;;
  esac

  local job_id dir script_abs
  job_id=$(date +%Y%m%d%H%M%S)-$$-$RANDOM
  dir=$(job_dir "$job_id")
  script_abs=$(cd -- "$SCRIPT_DIR" && pwd)/yt_dlp.sh
  mkdir -p "$dir"

  printf 'queued\n' >"$dir/status"
  printf 'task=%q\n' "$task" >"$dir/meta.env"
  printf 'submitted_at=%q\n' "$(date -Iseconds)" >>"$dir/meta.env"
  printf '%q ' "$script_abs" "$task" "$@" >"$dir/command.sh"
  printf '\n' >>"$dir/command.sh"
  chmod +x "$dir/command.sh"
  : >"$dir/stdout.log"
  : >"$dir/stderr.log"
  printf 'running\n' >"$dir/status"

  nohup bash -lc '
    set -euo pipefail
    dir=$1
    shift
    if "$@" >"$dir/stdout.log" 2>"$dir/stderr.log"; then
      printf "succeeded\n" >"$dir/status"
    else
      printf "failed\n" >"$dir/status"
    fi
  ' _ "$dir" "$script_abs" "$task" "$@" >/dev/null 2>&1 &

  sleep 0.2

  emit_result status "$(cat "$dir/status")"
  emit_result job_id "$job_id"
  emit_result log "$dir/stdout.log"
  emit_result stderr "$dir/stderr.log"
}

job_status_cmd() {
  local job_id=${1:-}
  local dir
  [[ -n "$job_id" ]] || die ERR_DOWNLOAD_FAILED "Pass JOB_ID to job status"
  dir=$(job_dir "$job_id")
  [[ -d "$dir" ]] || die ERR_DOWNLOAD_FAILED "Unknown job id: $job_id"

  local status
  status=$(cat "$dir/status")

  emit_result job_id "$job_id"
  emit_result status "$status"
  emit_result log "$dir/stdout.log"
  emit_result stderr "$dir/stderr.log"
  emit_result command "$dir/command.sh"
}

job_tail_cmd() {
  local job_id=${1:-}
  local dir
  [[ -n "$job_id" ]] || die ERR_DOWNLOAD_FAILED "Pass JOB_ID to job tail"
  dir=$(job_dir "$job_id")
  [[ -d "$dir" ]] || die ERR_DOWNLOAD_FAILED "Unknown job id: $job_id"

  emit_result job_id "$job_id"
  emit_result status "$(cat "$dir/status")"
  tail -n 40 "$dir/stdout.log" "$dir/stderr.log"
}

job_list_cmd() {
  local found=0
  local dir
  while IFS= read -r dir; do
    found=1
    printf '%s\t%s\n' "$(basename "$dir")" "$(cat "$dir/status" 2>/dev/null || printf unknown)"
  done < <(find "$JOBS_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)

  if [[ $found -eq 0 ]]; then
    emit_result status empty
    emit_result jobs_root "$JOBS_ROOT"
  fi
}

main() {
  local command=${1:-}
  [[ -n "$command" ]] || {
    usage
    exit 0
  }
  shift || true

  case "$command" in
    probe)
      probe_cmd "$@"
      ;;
    video)
      video_cmd "$@"
      ;;
    audio)
      audio_cmd "$@"
      ;;
    subtitles)
      subtitles_cmd "$@"
      ;;
    job)
      local sub=${1:-}
      shift || true
      case "$sub" in
        submit) job_submit_cmd "$@" ;;
        status) job_status_cmd "$@" ;;
        tail) job_tail_cmd "$@" ;;
        list) job_list_cmd "$@" ;;
        -h|--help|"")
          usage
          ;;
        *)
          die ERR_DOWNLOAD_FAILED "Unknown job subcommand: $sub"
          ;;
      esac
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die ERR_DOWNLOAD_FAILED "Unknown command: $command"
      ;;
  esac
}

main "$@"
