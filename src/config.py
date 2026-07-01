from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


PROJECT_NAME = "人工智能论文"
IMAGE_SIZE = 64
PILOT_PER_CLASS = 12
FULL_PER_CLASS = 1000
RANDOM_SEED = 42

OPEN_IMAGES_URLS = {
    "class_descriptions": "https://storage.googleapis.com/openimages/v7/oidv7-class-descriptions.csv",
    "val_image_labels": "https://storage.googleapis.com/openimages/v7/oidv7-val-annotations-human-imagelabels.csv",
    "val_image_info": "https://storage.googleapis.com/openimages/2018_04/validation/validation-images-with-rotation.csv",
    "download_page": "https://storage.googleapis.com/openimages/web/download_v7.html",
    "overview_page": "https://storage.googleapis.com/openimages/web/index.html",
}


@dataclass(frozen=True)
class TargetClass:
    label_id: str
    zh: str
    en: str
    mid: str


TARGET_CLASSES = [
    TargetClass("cat", "猫", "Cat", "/m/01yrx"),
    TargetClass("dog", "狗", "Dog", "/m/0bt9lr"),
    TargetClass("car", "汽车", "Car", "/m/0k4j"),
    TargetClass("bicycle", "自行车", "Bicycle", "/m/0199g"),
    TargetClass("motorcycle", "摩托车", "Motorcycle", "/m/04_sv"),
    TargetClass("bird", "鸟", "Bird", "/m/015p6"),
    TargetClass("horse", "马", "Horse", "/m/03k3r"),
    TargetClass("boat", "船", "Boat", "/m/019jd"),
    TargetClass("airplane", "飞机", "Airplane", "/m/05czz6l"),
    TargetClass("chair", "椅子", "Chair", "/m/01mzpv"),
    TargetClass("truck", "卡车", "Truck", "/m/07r04"),
    TargetClass("flower", "花", "Flower", "/m/0c9ph5"),
]


def project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def ensure_dirs(root: Path | None = None) -> None:
    root = root or project_root()
    for rel in [
        "data/raw",
        "data/processed",
        "data/images",
        "docs",
        "figures",
        "logs",
        "paper",
        "results",
    ]:
        (root / rel).mkdir(parents=True, exist_ok=True)
