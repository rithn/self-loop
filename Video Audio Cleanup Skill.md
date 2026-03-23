# Video Audio Cleanup Skill

## Overview

Processes a video file through a full audio cleanup pipeline:
noise removal → reverb reduction → EQ → normalization → reattach to video.

Output is a new file with `_clean` appended to the original filename, placed alongside the original.

The pipeline script lives at `~/Documents/audio-pipeline/process_video_audio.sh`.

---

## Prerequisites

- `ffmpeg` and `sox` installed via Homebrew (`brew install ffmpeg sox`)
- Scripts present at `~/Documents/audio-pipeline/`

If either tool is missing, install before proceeding.

---

## Invocation

The user can invoke this skill with or without a file path:

- **"clean up the audio on this video: /path/to/file.mov"** — process the specified file
- **"process the latest screen recording"** — use `process_latest_recording.sh`
- **"run audio cleanup"** — ask the user for a file path or confirm Desktop latest

---

## Phase 1: Identify Input File

If no path provided, find the latest `.mov` on the Desktop:

```bash
ls -t ~/Desktop/*.mov | grep -v _clean | head -1
```

Confirm the filename with the user before proceeding if ambiguous.

---

## Phase 2: Run the Pipeline

```bash
LATEST=$(ls -t ~/Desktop/*.mov | grep -v _clean | head -1)
OUTPUT="${LATEST%.*}_clean.mov"
bash ~/Documents/audio-pipeline/process_video_audio.sh "$LATEST" "$OUTPUT"
```

Or for an explicit path:

```bash
bash ~/Documents/audio-pipeline/process_video_audio.sh "/path/to/input.mov" "/path/to/output_clean.mov"
```

### What the pipeline does (in order):

1. **Extract audio** — lossless WAV at 48kHz via ffmpeg
2. **Noise profile** — built from first 2 seconds via sox
3. **Noise removal × 2** — sox `noisered` at strength 0.21 then 0.18
4. **Reverb reduction** — `agate` (threshold 0.026, ratio 3.3, attack 3ms, release 188ms)
5. **EQ** — high-pass 80Hz, bass shelf +3dB at 120Hz, presence +1.5dB at 3kHz, treble +2.5dB at 8kHz
6. **Loudness normalize** — EBU R128 at -16 LUFS, true peak -1.5dB
7. **Reattach** — video stream copied losslessly, audio re-encoded as AAC 192k

---

## Phase 3: Confirm Output

After the pipeline completes, confirm the output file exists and report its location to the user.

Ask the user to listen and provide feedback on:
- **Noise** — too much remaining / over-processed?
- **Reverb** — still roomy / too choppy?
- **EQ** — too bright / too muddy?

---

## Tuning Guide

If the user reports issues, adjust these parameters in `process_video_audio.sh`:

| Issue | Parameter | Direction |
|---|---|---|
| Still choppy | `release` in agate | Increase (e.g. 188 → 210) |
| Reverb crept back | `release` + `ratio` | Decrease release, increase ratio |
| Too much noise remaining | noisered strength | Increase (e.g. 0.21 → 0.25) |
| Audio sounds hollow/artefacted | noisered strength | Decrease |
| Too bright | treble equalizer `g` | Decrease |
| Too muddy | bass lowshelf `g` | Decrease |

Make incremental changes (~10%) and re-run after each adjustment.

---

## Cleanup

Old `_clean` files can be removed before re-running:

```bash
rm ~/Desktop/"filename_clean.mov"
```
