#!/usr/bin/env python3
"""Generate images via PPQ.ai (OpenAI-compatible API).

Usage:
  python3 generate.py <output_path> [model] [prompt]

Environment:
  PPQ_API_KEY  - Required. Your PPQ.ai API key.

Models (image-capable):
  openai/gpt-5-image        - Best quality, ~$0.22/image
  openai/gpt-5-image-mini   - Good quality, ~$0.05/image
  google/gemini-3-pro-image-preview
  google/gemini-2.5-flash-image

Response format:
  PPQ returns images in message.images[] as data: URIs (not in content).
  Must include "modalities": ["image", "text"] in the request.
"""
import urllib.request
import json
import base64
import os
import sys

API_KEY = os.environ.get("PPQ_API_KEY", "")
if not API_KEY:
    print("Error: PPQ_API_KEY not set", file=sys.stderr)
    sys.exit(1)

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <output.png> [model] [prompt]", file=sys.stderr)
    sys.exit(1)

output_path = sys.argv[1]
model = sys.argv[2] if len(sys.argv) > 2 else "openai/gpt-5-image-mini"
prompt = sys.argv[3] if len(sys.argv) > 3 else None

if not prompt:
    print("Error: prompt required as 3rd argument", file=sys.stderr)
    sys.exit(1)

url = "https://api.ppq.ai/chat/completions"
payload = {
    "model": model,
    "modalities": ["image", "text"],
    "messages": [{"role": "user", "content": prompt}]
}
headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}

print(f"Generating with {model}...")
req = urllib.request.Request(
    url, data=json.dumps(payload).encode("utf-8"),
    headers=headers, method="POST"
)

try:
    resp = urllib.request.urlopen(req, timeout=180)
    data = json.loads(resp.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8")
    print(f"API error {e.code}: {body[:2000]}", file=sys.stderr)
    sys.exit(1)

choices = data.get("choices", [])
if not choices:
    print("No choices in response", file=sys.stderr)
    sys.exit(1)

msg = choices[0].get("message", {})

# PPQ returns images in message.images[]
images = msg.get("images", [])
for img in images:
    img_url = img.get("image_url", {}).get("url", "")
    if img_url.startswith("data:"):
        b64 = img_url.split(",", 1)[1]
        img_bytes = base64.b64decode(b64)
        with open(output_path, "wb") as f:
            f.write(img_bytes)
        size_kb = len(img_bytes) / 1024
        print(f"Saved: {output_path} ({size_kb:.0f} KB)")
        usage = data.get("usage", {})
        cost = usage.get("cost", 0)
        if cost:
            print(f"Cost: ${cost:.4f}")
        sys.exit(0)

# Fallback: check content as list of parts
content = msg.get("content", "")
if isinstance(content, list):
    for part in content:
        if isinstance(part, dict) and part.get("type") == "image_url":
            img_url = part.get("image_url", {}).get("url", "")
            if img_url.startswith("data:"):
                b64 = img_url.split(",", 1)[1]
                img_bytes = base64.b64decode(b64)
                with open(output_path, "wb") as f:
                    f.write(img_bytes)
                print(f"Saved: {output_path} ({len(img_bytes)} bytes)")
                sys.exit(0)

print("No image found in response.", file=sys.stderr)
sys.exit(1)
