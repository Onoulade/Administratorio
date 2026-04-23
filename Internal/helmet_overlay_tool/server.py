#!/usr/bin/env python3
import argparse
import io
import json
import mimetypes
import shutil
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent
STATIC_DIR = TOOL_DIR / "static"
OFFSET_PATH = TOOL_DIR / "helmet-offsets.json"
SETTINGS_PATH = TOOL_DIR / "helmet-settings.json"
SOURCE_DIR = TOOL_DIR / "source"
WORKER_DIR = ROOT / "graphics" / "entities" / "worker-biter"
BITER_DIR = ROOT / "graphics" / "entities" / "rideable-biter"

HELMET_PREFIX = "biter-helmet"
BASE_PREFIX = "biter-run"
SHEET_COUNT = 4
SHEET_COLS = 8
SHEET_ROWS = 8
FRAMES_PER_SHEET = SHEET_COLS * SHEET_ROWS
TOTAL_FRAMES = SHEET_COUNT * FRAMES_PER_SHEET
HELMET_W = 177
HELMET_H = 138
BASE_W = 398
BASE_H = 310


def helmet_file(directory, sheet):
    return directory / f"{HELMET_PREFIX}-{sheet}.png"


def base_file(sheet):
    return BITER_DIR / f"{BASE_PREFIX}-{sheet}.png"


def ensure_source_images():
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    copied = []
    for sheet in range(1, SHEET_COUNT + 1):
        source = helmet_file(SOURCE_DIR, sheet)
        current = helmet_file(WORKER_DIR, sheet)
        if not source.exists():
            if not current.exists():
                raise FileNotFoundError(f"Missing helmet sheet: {current}")
            shutil.copy2(current, source)
            copied.append(str(source.relative_to(ROOT)))
    return copied


def default_offsets():
    return [{"x": 0, "y": 0} for _ in range(TOTAL_FRAMES)]


def default_settings():
    return [{"grow": 0} for _ in range(TOTAL_FRAMES)]


def normalize_settings(raw):
    settings = default_settings()
    if not isinstance(raw, dict):
        return settings
    if "frames" in raw:
        raw = raw.get("frames", [])
        if not isinstance(raw, list):
            return settings
        for index, value in enumerate(raw[:TOTAL_FRAMES]):
            if isinstance(value, dict):
                grow = int(value.get("grow", 0))
            else:
                grow = int(value)
            settings[index] = {"grow": max(-64, min(64, grow))}
        return settings

    grow = max(-64, min(64, int(raw.get("grow", 0))))
    return [{"grow": grow} for _ in range(TOTAL_FRAMES)]


def normalize_offsets(raw):
    offsets = default_offsets()
    if isinstance(raw, dict):
        raw = raw.get("frames", [])
    if not isinstance(raw, list):
        return offsets
    for index, value in enumerate(raw[:TOTAL_FRAMES]):
        if not isinstance(value, dict):
            continue
        offsets[index] = {
            "x": int(value.get("x", 0)),
            "y": int(value.get("y", 0)),
        }
    return offsets


def load_offsets():
    if not OFFSET_PATH.exists():
        return default_offsets()
    with OFFSET_PATH.open("r", encoding="utf-8") as handle:
        return normalize_offsets(json.load(handle))


def load_settings():
    if not SETTINGS_PATH.exists():
        return default_settings()
    with SETTINGS_PATH.open("r", encoding="utf-8") as handle:
        return normalize_settings(json.load(handle))


def save_offsets(offsets):
    OFFSET_PATH.write_text(
        json.dumps({"frames": normalize_offsets(offsets)}, indent=2) + "\n",
        encoding="utf-8",
    )


def save_settings(settings):
    SETTINGS_PATH.write_text(
        json.dumps({"frames": normalize_settings({"frames": settings})}, indent=2) + "\n",
        encoding="utf-8",
    )


def frame_location(index):
    if index < 0 or index >= TOTAL_FRAMES:
        raise ValueError(f"Frame index must be 0-{TOTAL_FRAMES - 1}")
    sheet = index // FRAMES_PER_SHEET + 1
    local = index % FRAMES_PER_SHEET
    col = local % SHEET_COLS
    row = local // SHEET_COLS
    return sheet, col, row


def crop_frame(path, index, width, height):
    sheet, col, row = frame_location(index)
    with Image.open(path(sheet)).convert("RGBA") as sheet_image:
        return sheet_image.crop((col * width, row * height, (col + 1) * width, (row + 1) * height))


def transformed_helmet_frame(source, offset, settings):
    grow = max(-64, min(64, int(settings.get("grow", 0))))
    if grow:
        resized_width = max(1, source.width + grow)
        resized_height = max(1, source.height + grow)
        source = source.resize((resized_width, resized_height), Image.Resampling.LANCZOS)

    output = Image.new("RGBA", (HELMET_W, HELMET_H), (0, 0, 0, 0))
    output.alpha_composite(
        source,
        (
            offset["x"] - ((source.width - HELMET_W) // 2),
            offset["y"] - ((source.height - HELMET_H) // 2),
        ),
    )
    return output


def shifted_helmet_frame(index, offsets, settings):
    ensure_source_images()
    source = crop_frame(lambda sheet: helmet_file(SOURCE_DIR, sheet), index, HELMET_W, HELMET_H)
    return transformed_helmet_frame(source, offsets[index], settings[index])


def regenerate_sheets():
    ensure_source_images()
    offsets = load_offsets()
    settings = load_settings()
    written = []
    for sheet in range(1, SHEET_COUNT + 1):
        source_path = helmet_file(SOURCE_DIR, sheet)
        with Image.open(source_path).convert("RGBA") as source:
            output = Image.new("RGBA", source.size, (0, 0, 0, 0))
            for local in range(FRAMES_PER_SHEET):
                index = (sheet - 1) * FRAMES_PER_SHEET + local
                col = local % SHEET_COLS
                row = local // SHEET_COLS
                box = (col * HELMET_W, row * HELMET_H, (col + 1) * HELMET_W, (row + 1) * HELMET_H)
                frame = source.crop(box)
                adjusted = transformed_helmet_frame(frame, offsets[index], settings[index])
                output.alpha_composite(adjusted, (col * HELMET_W, row * HELMET_H))

        target_path = helmet_file(WORKER_DIR, sheet)
        output.save(target_path)
        written.append(str(target_path.relative_to(ROOT)))
    return written


def json_response(handler, payload, status=200):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def png_response(handler, image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    body = buffer.getvalue()
    handler.send_response(200)
    handler.send_header("Content-Type", "image/png")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        try:
            if parsed.path == "/api/state":
                copied = ensure_source_images()
                json_response(
                    self,
                    {
                        "offsets": load_offsets(),
                        "settings": load_settings(),
                        "copiedSourceFiles": copied,
                        "frameCount": TOTAL_FRAMES,
                        "framesPerDirection": 16,
                        "directionCount": 16,
                        "helmet": {"width": HELMET_W, "height": HELMET_H},
                        "base": {"width": BASE_W, "height": BASE_H},
                    },
                )
                return

            if parsed.path.startswith("/api/frame/base/") and parsed.path.endswith(".png"):
                index = int(Path(parsed.path).stem)
                png_response(self, crop_frame(base_file, index, BASE_W, BASE_H))
                return

            if parsed.path.startswith("/api/frame/helmet/") and parsed.path.endswith(".png"):
                index = int(Path(parsed.path).stem)
                png_response(self, shifted_helmet_frame(index, load_offsets(), load_settings()))
                return

            path = parsed.path
            if path == "/":
                path = "/index.html"
            static_path = (STATIC_DIR / path.lstrip("/")).resolve()
            if STATIC_DIR.resolve() not in static_path.parents and static_path != STATIC_DIR.resolve():
                self.send_error(403)
                return
            if not static_path.exists() or not static_path.is_file():
                self.send_error(404)
                return
            body = static_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", mimetypes.guess_type(str(static_path))[0] or "application/octet-stream")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as exc:
            json_response(self, {"error": str(exc)}, status=500)

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = {}
            if length:
                payload = json.loads(self.rfile.read(length).decode("utf-8"))

            if parsed.path == "/api/offset":
                offsets = load_offsets()
                index = int(payload["index"])
                if index < 0 or index >= TOTAL_FRAMES:
                    raise ValueError(f"Frame index must be 0-{TOTAL_FRAMES - 1}")
                offsets[index] = {"x": int(payload.get("x", 0)), "y": int(payload.get("y", 0))}
                save_offsets(offsets)
                json_response(self, {"offsets": offsets})
                return

            if parsed.path == "/api/bulk-offset":
                offsets = load_offsets()
                indices = payload.get("indices", [])
                dx = int(payload.get("dx", 0))
                dy = int(payload.get("dy", 0))
                for index in indices:
                    index = int(index)
                    if 0 <= index < TOTAL_FRAMES:
                        offsets[index]["x"] += dx
                        offsets[index]["y"] += dy
                save_offsets(offsets)
                json_response(self, {"offsets": offsets})
                return

            if parsed.path == "/api/cumulative-correction":
                offsets = load_offsets()
                indices = payload.get("indices", [])
                step_x = int(payload.get("stepX", 0))
                step_y = int(payload.get("stepY", 0))
                sign = -1 if payload.get("invert") else 1
                anchor = payload.get("anchor", "start")

                for index in indices:
                    index = int(index)
                    if not (0 <= index < TOTAL_FRAMES):
                        continue
                    _, col, _ = frame_location(index)
                    if anchor == "end":
                        multiplier = col - (SHEET_COLS - 1)
                    else:
                        multiplier = col
                    offsets[index]["x"] += sign * step_x * multiplier
                    offsets[index]["y"] += sign * step_y * multiplier
                save_offsets(offsets)
                json_response(self, {"offsets": offsets})
                return

            if parsed.path == "/api/settings":
                settings = load_settings()
                indices = payload.get("indices", [])
                grow = max(-64, min(64, int(payload.get("grow", 0))))
                for index in indices:
                    index = int(index)
                    if 0 <= index < TOTAL_FRAMES:
                        settings[index] = {"grow": grow}
                save_settings(settings)
                json_response(self, {"settings": settings})
                return

            if parsed.path == "/api/reset":
                indices = payload.get("indices", list(range(TOTAL_FRAMES)))
                offsets = load_offsets()
                for index in indices:
                    index = int(index)
                    if 0 <= index < TOTAL_FRAMES:
                        offsets[index] = {"x": 0, "y": 0}
                save_offsets(offsets)
                json_response(self, {"offsets": offsets})
                return

            if parsed.path == "/api/regenerate":
                written = regenerate_sheets()
                json_response(self, {"written": written})
                return

            self.send_error(404)
        except Exception as exc:
            json_response(self, {"error": str(exc)}, status=500)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


def run_server(port):
    ensure_source_images()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Helmet overlay alignment tool: http://127.0.0.1:{port}")
    print("Press Ctrl-C to stop.")
    server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description="Adjust and regenerate worker biter helmet overlay sheets.")
    parser.add_argument("--port", type=int, default=8765, help="Local web UI port.")
    parser.add_argument("--regenerate", action="store_true", help="Regenerate helmet sheets from saved offsets and exit.")
    args = parser.parse_args()

    if args.regenerate:
        for path in regenerate_sheets():
            print(path)
        return

    run_server(args.port)


if __name__ == "__main__":
    main()
