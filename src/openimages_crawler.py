from __future__ import annotations

import csv
import time
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

from .config import (
    IMAGE_SIZE,
    OPEN_IMAGES_URLS,
    PILOT_PER_CLASS,
    TARGET_CLASSES,
    ensure_dirs,
    project_root,
)


USER_AGENT = "AI-course-reproduction/1.0"


def download_file(url: str, output: Path, timeout: int = 120) -> None:
    if output.exists() and output.stat().st_size > 0:
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        output.write_bytes(response.read())


def download_metadata(root: Path | None = None) -> dict[str, Path]:
    root = root or project_root()
    ensure_dirs(root)
    raw = root / "data" / "raw"
    files = {
        "class_descriptions": raw / "oidv7-class-descriptions.csv",
        "val_image_labels": raw / "oidv7-val-annotations-human-imagelabels.csv",
        "val_image_info": raw / "validation-images-with-rotation.csv",
    }
    for key, path in files.items():
        download_file(OPEN_IMAGES_URLS[key], path)
    return files


def read_image_info(path: Path) -> dict[str, dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return {row["ImageID"]: row for row in csv.DictReader(f)}


def read_positive_labels(path: Path, target_mids: set[str]) -> dict[str, list[str]]:
    labels: dict[str, list[str]] = defaultdict(list)
    with path.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("Confidence") == "1" and row.get("LabelName") in target_mids:
                labels[row["ImageID"]].append(row["LabelName"])
    return labels


def select_subset(
    root: Path | None = None,
    per_class: int = PILOT_PER_CLASS,
    allow_multi_target: bool = False,
) -> list[dict[str, str]]:
    root = root or project_root()
    files = download_metadata(root)
    target_by_mid = {cls.mid: cls for cls in TARGET_CLASSES}
    labels_by_image = read_positive_labels(files["val_image_labels"], set(target_by_mid))
    image_info = read_image_info(files["val_image_info"])

    selected: list[dict[str, str]] = []
    counts = Counter()
    for image_id in sorted(labels_by_image):
        mids = sorted(set(labels_by_image[image_id]))
        if not allow_multi_target and len(mids) != 1:
            continue
        primary_mid = mids[0]
        target = target_by_mid[primary_mid]
        if counts[target.label_id] >= per_class:
            continue
        info = image_info.get(image_id)
        if not info or not info.get("Thumbnail300KURL"):
            continue
        selected.append(
            {
                "image_id": image_id,
                "label_id": target.label_id,
                "label_zh": target.zh,
                "label_en": target.en,
                "mid": target.mid,
                "thumbnail_url": info["Thumbnail300KURL"],
                "original_url": info.get("OriginalURL", ""),
                "license": info.get("License", ""),
                "author": info.get("Author", ""),
                "title": info.get("Title", ""),
                "source_split": "validation",
            }
        )
        counts[target.label_id] += 1
        if all(counts[cls.label_id] >= per_class for cls in TARGET_CLASSES):
            break
    return selected


def fetch_and_resize_image(url: str, output: Path, size: int = IMAGE_SIZE, timeout: int = 30) -> bool:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and output.stat().st_size > 0:
        return True
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            with Image.open(response) as img:
                img = img.convert("RGB")
                img.thumbnail((size, size))
                canvas = Image.new("RGB", (size, size), (245, 247, 250))
                x = (size - img.width) // 2
                y = (size - img.height) // 2
                canvas.paste(img, (x, y))
                canvas.save(output, "JPEG", quality=88)
        return True
    except (urllib.error.URLError, OSError, TimeoutError):
        return False


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def build_pilot_dataset(root: Path | None = None, per_class: int = PILOT_PER_CLASS) -> Path:
    root = root or project_root()
    ensure_dirs(root)
    selected = select_subset(root, per_class=per_class)
    rows: list[dict[str, str]] = []
    failures: list[dict[str, str]] = []
    counts = Counter()
    for item in selected:
        rel = Path("data/images") / item["label_id"] / f"{item['image_id']}.jpg"
        ok = fetch_and_resize_image(item["thumbnail_url"], root / rel)
        record = dict(item)
        record["local_path"] = rel.as_posix()
        record["download_status"] = "ok" if ok else "failed"
        record["width"] = str(IMAGE_SIZE)
        record["height"] = str(IMAGE_SIZE)
        if ok:
            rows.append(record)
            counts[item["label_id"]] += 1
        else:
            failures.append(record)
        time.sleep(0.02)

    fieldnames = [
        "image_id",
        "label_id",
        "label_zh",
        "label_en",
        "mid",
        "local_path",
        "thumbnail_url",
        "original_url",
        "license",
        "author",
        "title",
        "source_split",
        "width",
        "height",
        "download_status",
    ]
    dataset_path = root / "data" / "processed" / "openimages_pilot_images.csv"
    write_csv(dataset_path, rows, fieldnames)
    write_csv(root / "logs" / "download_failures.csv", failures, fieldnames)

    with (root / "logs" / "crawler_summary.txt").open("w", encoding="utf-8") as f:
        f.write("Open Images V7 pilot subset download summary\n")
        f.write(f"Target classes: {len(TARGET_CLASSES)}\n")
        f.write(f"Requested per class: {per_class}\n")
        f.write(f"Downloaded images: {len(rows)}\n")
        f.write(f"Failures: {len(failures)}\n")
        for cls in TARGET_CLASSES:
            f.write(f"{cls.en},{cls.zh},{counts[cls.label_id]}\n")
    return dataset_path


if __name__ == "__main__":
    build_pilot_dataset()
