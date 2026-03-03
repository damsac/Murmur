---
name: icon-generator
description: >
  Generate app icons and images using AI image generation via PPQ.ai.
  Use when the user wants to create icons, logos, favicons, or other image assets.
  Triggers on "generate icon", "create icon", "make an icon", "app icon",
  "favicon", "generate image", "logo", or image generation requests.
---

# Icon & Image Generator

Generate images using PPQ.ai's OpenAI-compatible API with models like GPT-5 Image.

## Requirements

- `PPQ_API_KEY` environment variable (set in `project.local.yml` or shell)

## Script Location

`$SKILL_DIR/generate.py` — standalone Python 3 script, no dependencies beyond stdlib.

## How to Generate

```bash
PPQ_API_KEY="$PPQ_API_KEY" python3 "$SKILL_DIR/generate.py" <output.png> <model> <prompt>
```

### Models

| Model | Quality | Cost | Use for |
|-------|---------|------|---------|
| `openai/gpt-5-image` | Best | ~$0.22/img | Final assets, detailed work |
| `openai/gpt-5-image-mini` | Good | ~$0.05/img | Iteration, brainstorming |
| `google/gemini-3-pro-image-preview` | Good | Varies | Alternative style |

Default to `openai/gpt-5-image-mini` for brainstorming, `openai/gpt-5-image` for finals.

### PPQ API Notes

- Endpoint: `POST https://api.ppq.ai/chat/completions`
- **Must include** `"modalities": ["image", "text"]` in the request body
- Images are returned in `message.images[].image_url.url` as `data:image/png;base64,...`
- Images are NOT in the `content` field — this is PPQ-specific

## Workflow

### 1. Brainstorm iterations

Save iterations to `docs/brainstorms/icon-iterations/` with descriptive names:

```bash
mkdir -p docs/brainstorms/icon-iterations
PPQ_API_KEY="..." python3 "$SKILL_DIR/generate.py" \
  docs/brainstorms/icon-iterations/v1-description.png \
  openai/gpt-5-image-mini \
  "prompt here"
```

Show each result to the user with `Read` tool and iterate on the prompt.

### 2. Generate final version

Once the user picks a direction, generate the final at full quality:

```bash
PPQ_API_KEY="..." python3 "$SKILL_DIR/generate.py" \
  /tmp/final-icon.png \
  openai/gpt-5-image \
  "detailed final prompt"
```

### 3. Install as app icon

Copy to the Xcode asset catalog:

```bash
cp /tmp/final-icon.png Murmur/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Ensure `Contents.json` references the filename:
```json
{
  "images": [{
    "filename": "AppIcon.png",
    "idiom": "universal",
    "platform": "ios",
    "size": "1024x1024"
  }],
  "info": { "author": "xcode", "version": 1 }
}
```

### 4. Generate sized variants

Use macOS `sips` to create all needed sizes from the 1024x1024 source:

```bash
SRC=/tmp/final-icon.png
OUT=assets/icons

mkdir -p "$OUT"
sips -z 16 16 "$SRC" --out "$OUT/favicon-16.png"
sips -z 32 32 "$SRC" --out "$OUT/favicon-32.png"
sips -z 180 180 "$SRC" --out "$OUT/apple-touch-icon.png"
sips -z 192 192 "$SRC" --out "$OUT/icon-192.png"
sips -z 512 512 "$SRC" --out "$OUT/icon-512.png"
cp "$SRC" "$OUT/icon-1024.png"
```

## Prompting Tips for App Icons

- Always specify "1024x1024 square" and "NO rounded corners (iOS adds those)"
- Say "NO text, NO letters, NO words" explicitly (models love adding text)
- Reference specific hex colors for consistency across iterations
- Describe the composition spatially: "left group", "center gap", "mirrored"
- For dark backgrounds, specify the exact dark color (#0d0d1a works well)
- Mention "professional App Store quality" to push quality up
- Use `gpt-5-image` (not mini) for the final version — noticeably better detail

## Prompting Tips for General Images

- Be specific about dimensions and aspect ratio
- Describe lighting, mood, and style explicitly
- Reference real-world analogies ("like the Apple Podcasts icon style")
- Iterate: start cheap with `gpt-5-image-mini`, refine with `gpt-5-image`
