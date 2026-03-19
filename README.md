# yt-dlp-media

`yt-dlp-media` is a Codex skill that wraps `yt-dlp` behind a stable facade for probing, downloading, audio extraction, subtitle retrieval, and lightweight background jobs.

The skill keeps `yt-dlp` as the extraction core and adds:
- stable subcommands instead of raw parameter soup
- reusable presets
- structured `RESULT:key=value` outputs
- error classification and recovery hints
- a directory-backed job model for long-running tasks

## Repo Layout

```text
yt-dlp-media/
  SKILL.md
  agents/openai.yaml
  scripts/yt_dlp.sh
  references/
  jobs/.gitkeep
```

## Requirements

Required:
- `yt-dlp`

Required for merge/transcode/embed paths:
- `ffmpeg`
- `ffprobe`

## Install As A Skill

If this repository is published on GitHub as `<owner>/<repo>`, install it with the GitHub skill installer by pointing at the `yt-dlp-media` folder.

Example:

```bash
python /path/to/install-skill-from-github.py --repo <owner>/<repo> --path yt-dlp-media
```

Or install manually by copying `yt-dlp-media/` into `$CODEX_HOME/skills/`.

## Quick Validation

```bash
python3 /path/to/quick_validate.py yt-dlp-media
./yt-dlp-media/scripts/yt_dlp.sh --help
./yt-dlp-media/scripts/yt_dlp.sh probe --url 'https://vimeo.com/76979871'
```

## Verified Public Example

These flows were verified against:
- `https://vimeo.com/76979871`

Example:

```bash
./yt-dlp-media/scripts/yt_dlp.sh probe --url 'https://vimeo.com/76979871'
./yt-dlp-media/scripts/yt_dlp.sh video --url 'https://vimeo.com/76979871' --preset mobile
./yt-dlp-media/scripts/yt_dlp.sh audio --url 'https://vimeo.com/76979871' --preset audio_only --format mp3
```

## License

This repository is licensed under the MIT License.
