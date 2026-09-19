#!/usr/bin/env python3
"""Normalize the AI-generated rideable-biter and orbital-astronaut sheets.

The source images were generated with different grid shapes and cell sizes.  This
tool splits each image using its real grid, preserves row-major frame order, and
centers every frame on a consistent transparent canvas that Factorio can load as
one animation sheet.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass(frozen=True)
class SourceSheet:
    filename: str
    columns: int
    rows: int


@dataclass(frozen=True)
class OutputSheet:
    filename: str
    sources: tuple[SourceSheet, ...]
    frame_width: int
    frame_height: int
    columns: int


SHEETS = {
    "rideable-biter": OutputSheet(
        filename="entities/rideable-biter/run.png",
        sources=tuple(SourceSheet(f"rideable-biter-{index}.png", 8, 8) for index in range(1, 5)),
        frame_width=192,
        frame_height=144,
        columns=16,
    ),
    "astronaut-run": OutputSheet(
        filename="entities/orbital-astronaut/run.png",
        sources=tuple(SourceSheet(f"astronaut-run-{index}.png", 8, 8) for index in range(1, 5)),
        frame_width=192,
        frame_height=144,
        columns=16,
    ),
    "astronaut-attack": OutputSheet(
        filename="entities/orbital-astronaut/attack.png",
        sources=(
            SourceSheet("astronaut-attack-1.png", 11, 4),
            SourceSheet("astronaut-attack-2.png", 10, 4),
            SourceSheet("astronaut-attack-3.png", 11, 4),
            SourceSheet("astronaut-attack-4.png", 12, 4),
        ),
        frame_width=192,
        frame_height=240,
        columns=11,
    ),
}


def clear_nearly_transparent_noise(frame: Image.Image) -> Image.Image:
    """Drop invisible chroma garbage left in the generated PNG alpha fringe."""
    cleaned = frame.copy()
    cleaned.putalpha(frame.getchannel("A").point(lambda alpha: 0 if alpha <= 3 else alpha))
    return cleaned


def split_frames(source_dir: Path, sources: tuple[SourceSheet, ...]) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for source in sources:
        image = Image.open(source_dir / source.filename).convert("RGBA")
        if image.width % source.columns or image.height % source.rows:
            raise ValueError(
                f"{source.filename}: {image.size} is not divisible by "
                f"{source.columns}x{source.rows}"
            )
        width = image.width // source.columns
        height = image.height // source.rows
        for row in range(source.rows):
            for column in range(source.columns):
                frames.append(
                    clear_nearly_transparent_noise(image.crop(
                        (
                            column * width,
                            row * height,
                            (column + 1) * width,
                            (row + 1) * height,
                        )
                    ))
                )
    return frames


def split_direction_rows(
    source_dir: Path,
    sources: tuple[SourceSheet, ...],
    target_frame_count: int,
) -> list[Image.Image]:
    """Read sheets where every row is one direction with a variable duration."""
    frames: list[Image.Image] = []
    for source in sources:
        image = Image.open(source_dir / source.filename).convert("RGBA")
        if image.width % source.columns or image.height % source.rows:
            raise ValueError(
                f"{source.filename}: {image.size} is not divisible by "
                f"{source.columns}x{source.rows}"
            )
        width = image.width // source.columns
        height = image.height // source.rows
        for row in range(source.rows):
            direction_frames = [
                clear_nearly_transparent_noise(image.crop(
                    (
                        column * width,
                        row * height,
                        (column + 1) * width,
                        (row + 1) * height,
                    )
                ))
                for column in range(source.columns)
            ]
            # Preserve both endpoints while evenly duplicating or dropping the
            # interior frames.  The generated attack rows contain 10, 11 or 12
            # frames, while Factorio needs one frame count for every direction.
            for target_index in range(target_frame_count):
                source_index = round(
                    target_index * (len(direction_frames) - 1) / (target_frame_count - 1)
                )
                frames.append(direction_frames[source_index])
    return frames


def normalize_frames(frames: list[Image.Image], spec: OutputSheet) -> Image.Image:
    rows = (len(frames) + spec.columns - 1) // spec.columns
    output = Image.new(
        "RGBA",
        (spec.columns * spec.frame_width, rows * spec.frame_height),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        if frame.width > spec.frame_width or frame.height > spec.frame_height:
            raise ValueError(
                f"frame {index} ({frame.size}) exceeds the "
                f"{spec.frame_width}x{spec.frame_height} target"
            )
        column = index % spec.columns
        row = index // spec.columns
        x = column * spec.frame_width + (spec.frame_width - frame.width) // 2
        y = row * spec.frame_height + (spec.frame_height - frame.height) // 2
        output.alpha_composite(frame, (x, y))
    return output


def make_icon(frame: Image.Image, output_path: Path) -> None:
    alpha_box = frame.getchannel("A").getbbox()
    if not alpha_box:
        raise ValueError("cannot make an icon from a fully transparent frame")
    subject = frame.crop(alpha_box)
    subject.thumbnail((224, 224), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    icon.alpha_composite(subject, ((256 - subject.width) // 2, (256 - subject.height) // 2))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(output_path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_graphics_dir", type=Path, nargs="?", default=Path("graphics"))
    args = parser.parse_args()

    first_frames: dict[str, Image.Image] = {}
    for name, spec in SHEETS.items():
        frames = (
            split_direction_rows(args.source_dir, spec.sources, 11)
            if name == "astronaut-attack"
            else split_frames(args.source_dir, spec.sources)
        )
        expected = 256 if name != "astronaut-attack" else 176
        if len(frames) != expected:
            raise ValueError(f"{name}: expected {expected} frames, found {len(frames)}")
        first_frames[name] = frames[0]
        output_path = args.output_graphics_dir / spec.filename
        output_path.parent.mkdir(parents=True, exist_ok=True)
        normalize_frames(frames, spec).save(output_path, optimize=True)
        print(f"{name}: {len(frames)} frames -> {output_path}")

    make_icon(first_frames["astronaut-run"], args.output_graphics_dir / "icons/orbital-astronaut.png")


if __name__ == "__main__":
    main()
