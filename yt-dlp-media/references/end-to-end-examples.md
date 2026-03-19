# End To End Examples

## Probe First

```bash
./scripts/yt_dlp.sh probe --url 'https://vimeo.com/76979871'
```

Use when the site, title, live status, or auth requirement is unknown.

## Balanced Video Archive

```bash
./scripts/yt_dlp.sh video \
  --url 'https://vimeo.com/76979871' \
  --preset balanced \
  --output-dir './output/archive'
```

## Mobile-Friendly Clip Download

```bash
./scripts/yt_dlp.sh video \
  --url 'https://www.xiaohongshu.com/explore/example' \
  --preset mobile
```

## Podcast Audio Extraction

```bash
./scripts/yt_dlp.sh audio \
  --url 'https://vimeo.com/76979871' \
  --preset audio_only \
  --format mp3
```

## Subtitle Retrieval

```bash
./scripts/yt_dlp.sh subtitles \
  --url 'https://example.com/video-with-subtitles' \
  --mode write \
  --langs 'en,zh-Hans'
```

Use a source URL that is known to expose subtitles or automatic captions.

## Async Job Submission

```bash
./scripts/yt_dlp.sh job submit video \
  --url 'https://vimeo.com/76979871' \
  --preset balanced
./scripts/yt_dlp.sh job status JOB_ID
./scripts/yt_dlp.sh job tail JOB_ID
```

## Transcript Prep Pattern

```bash
./scripts/yt_dlp.sh job submit audio \
  --url 'https://vimeo.com/76979871' \
  --preset audio_only \
  --format wav
```

Then pass the emitted audio artifact into the downstream ASR workflow.
