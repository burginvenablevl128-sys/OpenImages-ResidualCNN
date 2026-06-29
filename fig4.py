import csv
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle
from PIL import Image, ImageDraw

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Arial Unicode MS"]
plt.rcParams["axes.unicode_minus"] = False

# 项目根目录
PROJECT_ROOT = Path(r"D:\wendang\人工智能\人工智能论文")
CSV_PATH = PROJECT_ROOT / "data" / "processed" / "openimages_pilot_images.csv"

W, H = 908, 565
bg_color = "#F4F8FB"
ink = "#101E36"
muted = "#6E7E91"
blue = "#2F66F2"
yellow = "#E0A015"

classes = [
    "狗", "汽车", "摩托车", "花",
    "自行车", "船", "鸟", "椅子",
    "卡车", "马", "猫", "飞机"
]


def build_image_paths():
    """从论文项目的样本表中，为每个类别选第一张本地图片。"""
    image_paths = {}

    with open(CSV_PATH, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)

        for row in reader:
            label = row["label_zh"]
            status = row.get("download_status", "")

            if label in classes and label not in image_paths and status == "ok":
                image_paths[label] = PROJECT_ROOT / row["local_path"]

    return image_paths


image_paths = build_image_paths()


def add_round_rect(ax, x, y, w, h, radius=12, color="white", z=1):
    patch = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0,rounding_size={radius}",
        linewidth=0,
        facecolor=color,
        edgecolor="none",
        zorder=z
    )
    ax.add_patch(patch)


def load_image(path, label, size=(96, 72)):
    """读取本地图片；如果缺失则生成占位图。"""
    path = Path(path)

    if path.exists():
        img = Image.open(path).convert("RGB")
    else:
        img = Image.new("RGB", size, "#EAF0F6")
        draw = ImageDraw.Draw(img)
        draw.rectangle([0, 0, size[0] - 1, size[1] - 1], outline="#D8E2EC")
        draw.text((size[0] / 2 - 10, size[1] / 2 - 8), label, fill="#52657A")

    target_w, target_h = size
    iw, ih = img.size
    target_ratio = target_w / target_h
    img_ratio = iw / ih

    if img_ratio > target_ratio:
        new_w = int(ih * target_ratio)
        left = (iw - new_w) // 2
        img = img.crop((left, 0, left + new_w, ih))
    else:
        new_h = int(iw / target_ratio)
        top = (ih - new_h) // 2
        img = img.crop((0, top, iw, top + new_h))

    img = img.resize(size, Image.LANCZOS)
    return np.asarray(img)


fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, W)
ax.set_ylim(H, 0)
ax.axis("off")

fig.patch.set_facecolor(bg_color)
ax.set_facecolor(bg_color)

# 标题
ax.text(
    36, 43,
    "Open Images Pilot 样本展示",
    fontsize=20,
    fontweight="bold",
    color=ink,
    va="center"
)

ax.add_patch(Rectangle((36, 53), 118, 4, color=blue, linewidth=0))
ax.add_patch(Rectangle((107, 53), 70, 4, color=yellow, linewidth=0))

ax.text(
    36, 72,
    "从真实 Open Images 缩略图构建的多类别视觉分类子集",
    fontsize=8,
    color=muted,
    va="center"
)

ax.text(
    768, 43,
    "Open Images · Residual CNN",
    fontsize=6.5,
    color=muted,
    ha="left",
    va="center"
)

# 样本卡片
card_w, card_h = 162, 124
img_w, img_h = 86, 72

x_positions = [48, 255, 462, 669]
y_positions = [96, 240, 384]

idx = 0
for y in y_positions:
    for x in x_positions:
        label = classes[idx]

        add_round_rect(ax, x, y, card_w, card_h, radius=10, color="white", z=1)

        img_x = x + (card_w - img_w) / 2
        img_y = y + 26

        img = load_image(image_paths[label], label, size=(img_w, img_h))

        ax.imshow(
            img,
            extent=[img_x, img_x + img_w, img_y + img_h, img_y],
            zorder=2
        )

        ax.text(
            x + card_w / 2,
            y + card_h - 13,
            label,
            fontsize=8,
            fontweight="bold",
            color=ink,
            ha="center",
            va="center"
        )

        idx += 1

plt.savefig(
    PROJECT_ROOT / "figures" / "figure_sample_grid_python.png",
    dpi=150,
    bbox_inches="tight",
    pad_inches=0
)





plt.show()
