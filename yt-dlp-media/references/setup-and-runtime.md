# Setup And Runtime

## Dependencies

Required:
- `yt-dlp` in `PATH`

Required for media downloads that merge or transcode:
- `ffmpeg`
- `ffprobe`

Recommended for broader YouTube compatibility:
- `yt-dlp[default]`
- a JavaScript runtime such as `deno` or `node`

## Install Paths

Example installs:

```bash
python -m pip install -U 'yt-dlp[default]'
# or
brew install yt-dlp ffmpeg
```

Verify:

```bash
yt-dlp --version
ffmpeg -version
ffprobe -version
```

## Runtime Layout

The facade script defaults to these roots:
- output root: `./output/yt-dlp-media`
- job root: `./jobs`

Override with:
- `YTDLP_MEDIA_ROOT`
- `YTDLP_MEDIA_JOBS_ROOT`
- `YTDLP_COOKIES_FROM_BROWSER`

## Authentication

Preferred order:
1. open content without auth
2. browser cookies via `YTDLP_COOKIES_FROM_BROWSER`
3. yt-dlp config or netrc for extractor-specific credentials

Example:

```bash
export YTDLP_COOKIES_FROM_BROWSER='chrome'
./scripts/yt_dlp.sh probe --url 'https://example.com/private-video'
```

## Safety And Legal Constraints

- Download only content the user is authorized to access and reuse.
- Do not claim DRM support. yt-dlp does not generally bypass DRM-protected media.
- Treat browser cookies as sensitive local credentials.
- Prefer official upstream yt-dlp releases or PyPI installs.

## Operating Model

Use this skill as a wrapper layer:
- yt-dlp handles extraction and download mechanics
- the facade handles presets, output structure, and job lifecycle
