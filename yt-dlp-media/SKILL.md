---
name: yt-dlp-media
description: Use when Codex needs to probe, download, extract audio or subtitles from online media with yt-dlp, especially when the task needs a stable wrapper, structured outputs, reusable presets, cookies-aware recovery, or lightweight background jobs instead of raw one-off yt-dlp commands.
---

# YT-DLP Media

## Overview

Wrap yt-dlp behind a stable facade so media work is reproducible, debuggable, and composable.
Prefer the bundled script over raw yt-dlp commands unless the user explicitly asks for low-level flags.

## Workflow

1. Start with `scripts/yt_dlp.sh probe --url URL` to inspect extractor, title, live status, and output path hints.
2. Pick the narrowest high-frequency action:
- `video` for a normal download
- `audio` for extraction/transcode
- `subtitles` for subtitle retrieval or embedding
- `job submit` when the task may run long or needs later polling
3. Use presets instead of rebuilding large flag bundles.
4. Read structured `RESULT:key=value` lines instead of scraping raw yt-dlp logs.
5. If execution fails, read `references/troubleshooting.md` and recover by error class rather than ad hoc retries.

## Command Map

### Probe

Use for discovery before committing to a download.

```bash
./scripts/yt_dlp.sh probe --url 'https://example.com/video'
```

Probe is the default first step when any of the following is unknown:
- whether the site is supported
- whether auth is required
- which preset is appropriate
- whether the target is live, playlist, or single media

### Video

Use for standard video downloads.

```bash
./scripts/yt_dlp.sh video --url 'https://example.com/video' --preset balanced
```

Presets:
- `best`: highest practical quality
- `balanced`: default for archival without wasting storage
- `mobile`: smaller files for lightweight reuse

### Audio

Use for podcast-style extraction or ASR preparation.

```bash
./scripts/yt_dlp.sh audio --url 'https://example.com/video' --preset audio_only --format mp3
```

### Subtitles

Use when the user needs subtitle files or wants them embedded.

```bash
./scripts/yt_dlp.sh subtitles --url 'https://example.com/video' --mode write --langs en,zh-Hans
```

Modes:
- `write`: emit subtitle artifacts
- `embed`: download media and embed subtitles when possible

### Job

Use for long-running tasks or when the workflow needs polling.

```bash
./scripts/yt_dlp.sh job submit video --url 'https://example.com/video' --preset balanced
./scripts/yt_dlp.sh job status JOB_ID
./scripts/yt_dlp.sh job tail JOB_ID
```

The job system is directory-backed, not database-backed. Treat the generated files as the source of truth.

## Presets And Profiles

Do not expose yt-dlp parameter soup unless the user explicitly asks for it.
Use the script presets first, then override only the specific option that matters.

Site profile bias:
- YouTube and Bilibili: default to `balanced`
- Xiaohongshu, X, Twitter: default to `mobile`
- Unknown sites: default to `balanced`

## Structured Results

Consume these keys when present:
- `RESULT:status=...`
- `RESULT:file=...`
- `RESULT:info_json=...`
- `RESULT:thumbnail=...`
- `RESULT:subtitles=...`
- `RESULT:job_id=...`
- `RESULT:log=...`
- `RESULT:error_code=...`
- `RESULT:error_hint=...`

Treat raw stderr as supporting evidence, not the integration contract.

## References

Read only what is needed:
- Setup and runtime requirements: `references/setup-and-runtime.md`
- Copyable workflows: `references/end-to-end-examples.md`
- Error classes and recovery actions: `references/troubleshooting.md`

## Guardrails

- Keep yt-dlp as the extraction core. Do not reimplement extractor logic.
- Prefer `probe` before `video` when auth, site support, or media type is unclear.
- Prefer presets over arbitrary low-level flags.
- Use jobs for long-running downloads instead of blocking the foreground by default.
- Do not promise DRM bypass. If a site requires DRM, stop and say so.
- Respect copyright, platform terms, and user credentials boundaries.
