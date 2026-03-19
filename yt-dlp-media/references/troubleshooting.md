# Troubleshooting

## Error Classes

### `ERR_NO_YTDLP`

Cause:
- `yt-dlp` is not installed or not in `PATH`

Action:
- install yt-dlp and retry

### `ERR_NO_FFMPEG`

Cause:
- `ffmpeg` or `ffprobe` is missing for merge, transcode, or embed operations

Action:
- install both binaries and retry

### `ERR_UNSUPPORTED_URL`

Cause:
- no extractor matched the URL, or the site is not supported

Action:
- run `probe` first, confirm the URL is valid, then check upstream yt-dlp support

### `ERR_AUTH_REQUIRED`

Cause:
- the media requires login, membership, age verification, or cookies

Action:
- configure cookies or extractor credentials, then retry

### `ERR_CONTENT_UNAVAILABLE`

Cause:
- the media exists but is removed, private, blocked by region, or otherwise unavailable at the source

Action:
- confirm the URL still works in a browser, then check whether cookies, region, or the source itself is the blocker

### `ERR_RATE_LIMITED`

Cause:
- the site throttled requests or temporarily blocked access

Action:
- retry later, reduce concurrency, or switch network identity if appropriate

### `ERR_EXTRACTOR_BROKEN`

Cause:
- upstream site changes broke the extractor

Action:
- update yt-dlp first; if still failing, inspect upstream issues before inventing local workarounds

### `ERR_DOWNLOAD_FAILED`

Cause:
- catch-all download failure without a more specific classification

Action:
- inspect `stderr.log` for the job or rerun with a narrower command

## Recovery Rules

- Prefer updating upstream yt-dlp over adding fragile local hacks.
- Prefer cookies over raw username/password prompts.
- Prefer `job submit` for long retries so logs and status remain inspectable.
- Prefer stable `RESULT:` keys over parsing human-readable console output.
