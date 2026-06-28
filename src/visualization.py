from __future__ import annotations

import csv
import json
import math
import textwrap
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .config import IMAGE_SIZE, OPEN_IMAGES_URLS, TARGET_CLASSES, ensure_dirs, project_root


COLORS = {
    "bg": (247, 250, 252),
    "panel": (255, 255, 255),
    "ink": (21, 34, 56),
    "muted": (91, 107, 124),
    "grid": (221, 229, 237),
    "blue": (37, 99, 235),
    "teal": (33, 107, 97),
    "gold": (217, 154, 0),
    "coral": (214, 85, 63),
    "violet": (98, 89, 199),
    "cyan": (8, 145, 178),
    "green": (22, 163, 74),
    "soft_blue": (234, 242, 255),
    "soft_teal": (231, 245, 241),
    "soft_gold": (255, 247, 218),
    "soft_gray": (238, 242, 246),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def canvas(width: int, height: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (width, height), COLORS["bg"])
    return image, ImageDraw.Draw(image)


def rounded(draw: ImageDraw.ImageDraw, xy, radius=20, fill=COLORS["panel"], outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_title(draw: ImageDraw.ImageDraw, title: str, subtitle: str, width: int) -> None:
    draw.text((70, 52), title, fill=COLORS["ink"], font=font(36, True))
    draw.rounded_rectangle((70, 100, 290, 106), radius=3, fill=COLORS["blue"])
    draw.rounded_rectangle((210, 100, 350, 106), radius=3, fill=COLORS["gold"])
    draw.text((70, 122), subtitle, fill=COLORS["muted"], font=font(18))
    draw.text((width - 70, 70), "Open Images · Residual CNN", fill=COLORS["muted"], font=font(15), anchor="ra")


def draw_card(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, label: str, value: str, accent, note: str = "") -> None:
    rounded(draw, (x, y, x + w, y + h), 18, COLORS["panel"])
    draw.rounded_rectangle((x, y, x + 8, y + h), radius=4, fill=accent)
    draw.text((x + 28, y + 24), label, fill=COLORS["muted"], font=font(15))
    draw.text((x + 28, y + 54), value, fill=COLORS["ink"], font=font(31, True))
    if note:
        draw.text((x + 28, y + 94), note, fill=COLORS["muted"], font=font(13))


def draw_wrapped(draw: ImageDraw.ImageDraw, xy, text: str, width_chars: int, fill, size=16, bold=False, line_gap=7):
    x, y = xy
    for line in textwrap.wrap(text, width=width_chars):
        draw.text((x, y), line, fill=fill, font=font(size, bold))
        y += size + line_gap
    return y


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def load_metrics(root: Path) -> dict:
    path = root / "results" / "metrics.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def save(image: Image.Image, root: Path, name: str) -> None:
    out = root / "figures" / name
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, "PNG", quality=95)


def bar_chart(draw: ImageDraw.ImageDraw, data, x, y, w, h, color, label_key="label", value_key="value", max_value=None):
    max_value = max_value or max([float(d[value_key]) for d in data] + [1])
    gap = 16
    bw = (w - gap * (len(data) - 1)) / max(1, len(data))
    draw.line((x, y + h, x + w, y + h), fill=COLORS["grid"], width=2)
    for i, item in enumerate(data):
        value = float(item[value_key])
        bh = int((value / max_value) * (h - 35))
        bx = int(x + i * (bw + gap))
        by = y + h - bh
        draw.rounded_rectangle((bx, by, int(bx + bw), y + h), radius=8, fill=color)
        draw.text((bx + bw / 2, by - 24), str(item[value_key]), fill=COLORS["ink"], font=font(14, True), anchor="ma")
        draw.text((bx + bw / 2, y + h + 12), str(item[label_key]), fill=COLORS["muted"], font=font(12), anchor="ma")


def figure_framework(root: Path, rows: list[dict[str, str]], metrics: dict) -> None:
    img, draw = canvas(1800, 1080)
    draw_title(draw, "课程论文整体框架", "从公开视觉数据库到模型复现、对照实验与结果讨论的完整链路", 1800)
    stages = [
        ("课程要求", "来源说明、摘要、引言、算法、数据、实验、结果、截图、讨论、结论、参考文献", COLORS["blue"]),
        ("Open Images V7", "从官方元数据筛选目标类别，下载图像缩略图并记录来源与授权信息", COLORS["teal"]),
        ("数据处理", "Resize、归一化、划分训练/验证/测试集，并生成数据分布可视化", COLORS["gold"]),
        ("模型复现", "MLP 基线与 Residual CNN；当前环境另提供 NumPy 快速实验校验", COLORS["coral"]),
        ("评估分析", "Accuracy、Macro-F1、训练曲线、混淆矩阵、错误案例和适用性讨论", COLORS["violet"]),
    ]
    x0, y0, box_w, box_h, gap = 105, 230, 300, 250, 45
    for idx, (title, body, color) in enumerate(stages):
        x = x0 + idx * (box_w + gap)
        rounded(draw, (x, y0, x + box_w, y0 + box_h), 22, COLORS["panel"])
        draw.ellipse((x + 24, y0 + 24, x + 72, y0 + 72), fill=color)
        draw.text((x + 48, y0 + 48), str(idx + 1), fill=(255, 255, 255), font=font(18, True), anchor="mm")
        draw.text((x + 24, y0 + 96), title, fill=COLORS["ink"], font=font(22, True))
        draw_wrapped(draw, (x + 24, y0 + 134), body, 15, COLORS["muted"], 15)
        if idx < len(stages) - 1:
            draw.line((x + box_w + 8, y0 + 125, x + box_w + gap - 10, y0 + 125), fill=COLORS["grid"], width=5)
            draw.polygon(
                [(x + box_w + gap - 10, y0 + 125), (x + box_w + gap - 24, y0 + 116), (x + box_w + gap - 24, y0 + 134)],
                fill=COLORS["grid"],
            )
    draw_card(draw, 120, 610, 360, 120, "当前 Pilot 图像", str(len(rows)), COLORS["teal"], "真实 Open Images 缩略图")
    draw_card(draw, 520, 610, 360, 120, "目标类别", str(len(TARGET_CLASSES)), COLORS["blue"], "动物 / 交通 / 物体 / 场景")
    best = max(metrics.get("models", []), key=lambda x: x.get("accuracy", 0), default={"accuracy": 0, "macro_f1": 0, "model": "-"})
    draw_card(draw, 920, 610, 360, 120, "Pilot 最优模型", best["model"], COLORS["gold"], f"Accuracy {best.get('accuracy', 0)*100:.1f}%")
    draw_card(draw, 1320, 610, 360, 120, "完整目标规模", "≥12k", COLORS["coral"], "默认每类 1000 张")
    rounded(draw, (120, 800, 1680, 960), 24, COLORS["soft_blue"], outline=(207, 222, 242))
    draw.text((150, 836), "说明", fill=COLORS["ink"], font=font(21, True))
    draw_wrapped(
        draw,
        (150, 874),
        "项目代码支持从 Open Images V7 扩展到每类 1000 张以上的图像子集；交付包为避免体积过大，包含每类少量真实缩略图的 pilot 数据和完整实验管线。",
        78,
        COLORS["muted"],
        17,
    )
    save(img, root, "figure_overall_framework.png")


def figure_dataset_dashboard(root: Path, rows: list[dict[str, str]]) -> None:
    img, draw = canvas(1800, 1120)
    draw_title(draw, "Open Images 数据库与子集画像", "使用官方元数据筛选视觉类别，保留图像来源、作者、许可协议和本地路径", 1800)
    counts = Counter(row["label_zh"] for row in rows)
    cards = [
        ("官方图像规模", "9,178,275", COLORS["blue"], "Open Images V7 全量图像"),
        ("官方类别规模", "20,638", COLORS["teal"], "图像级标签类别"),
        ("官方标签量", "61,404,966", COLORS["gold"], "image-level labels"),
        ("Pilot 图像数", str(len(rows)), COLORS["coral"], "随包提供，可快速复现"),
        ("Pilot 类别数", str(len(counts)), COLORS["violet"], "均衡筛选目标类"),
        ("图像尺寸", f"{IMAGE_SIZE}×{IMAGE_SIZE}×3", COLORS["cyan"], "Resize 后输入模型"),
    ]
    for idx, card in enumerate(cards):
        draw_card(draw, 80 + (idx % 3) * 560, 168 + (idx // 3) * 138, 500, 112, *card)
    rounded(draw, (80, 480, 800, 970), 22, COLORS["panel"])
    draw.text((112, 520), "Pilot 类别分布", fill=COLORS["ink"], font=font(23, True))
    chart_data = [{"label": k, "value": v} for k, v in counts.items()]
    bar_chart(draw, chart_data, 125, 575, 620, 300, COLORS["teal"], max_value=max(counts.values()) if counts else 1)
    draw_wrapped(draw, (112, 922), "每个类别由爬虫从验证集图像级标签中筛选，并下载官方缩略图。完整模式可将 per_class 参数调整为 1000 或更高。", 36, COLORS["muted"], 15)
    rounded(draw, (850, 480, 1720, 970), 22, COLORS["panel"])
    draw.text((888, 520), "数据文件结构", fill=COLORS["ink"], font=font(23, True))
    files = [
        ("oidv7-class-descriptions.csv", "官方类别描述表", "MID 与类别名称映射"),
        ("oidv7-val-human-imagelabels.csv", "图像级人工标签", "ImageID、LabelName、Confidence"),
        ("validation-images-with-rotation.csv", "图像 URL 清单", "OriginalURL、Thumbnail300KURL、License"),
        ("openimages_pilot_images.csv", "本项目样本表", "本地路径、类别、来源、作者与授权"),
    ]
    y = 570
    for idx, (a, b, c) in enumerate(files):
        fill = COLORS["soft_teal"] if idx % 2 == 0 else COLORS["soft_blue"]
        rounded(draw, (890, y, 1660, y + 78), 14, fill, outline=(211, 224, 236))
        draw.text((915, y + 18), a, fill=COLORS["ink"], font=font(17, True))
        draw.text((1260, y + 18), b, fill=COLORS["teal"], font=font(16))
        draw.text((915, y + 48), c, fill=COLORS["muted"], font=font(14))
        y += 96
    save(img, root, "figure_dataset_dashboard.png")


def figure_sample_grid(root: Path, rows: list[dict[str, str]]) -> None:
    img, draw = canvas(1800, 1120)
    draw_title(draw, "Open Images Pilot 样本展示", "从真实 Open Images 缩略图构建的多类别视觉分类子集", 1800)
    by_label = {}
    for row in rows:
        by_label.setdefault(row["label_zh"], row)
    x0, y0 = 96, 190
    cell_w, cell_h = 260, 220
    for idx, (label, row) in enumerate(list(by_label.items())[:12]):
        x = x0 + (idx % 4) * 410
        y = y0 + (idx // 4) * 285
        rounded(draw, (x, y, x + 320, y + 245), 20, COLORS["panel"])
        path = root / row["local_path"]
        if path.exists():
            sample = Image.open(path).convert("RGB").resize((170, 170))
            img.paste(sample, (x + 75, y + 24))
        draw.text((x + 160, y + 214), label, fill=COLORS["ink"], font=font(18, True), anchor="ma")
    save(img, root, "figure_sample_grid.png")


def figure_model_architecture(root: Path) -> None:
    img, draw = canvas(1800, 1040)
    draw_title(draw, "MLP 与 Residual CNN 模型结构对比", "同一图像输入下，展平全连接路径与卷积残差路径的信息流差异", 1800)
    rounded(draw, (90, 190, 830, 880), 24, COLORS["panel"])
    rounded(draw, (970, 190, 1710, 880), 24, COLORS["panel"])
    draw.text((130, 230), "MLP Baseline", fill=COLORS["ink"], font=font(26, True))
    draw.text((1010, 230), "Residual CNN", fill=COLORS["ink"], font=font(26, True))
    mlp = [
        ("64×64×3 图像", COLORS["soft_blue"]),
        ("Flatten → 12288维", COLORS["soft_gray"]),
        ("FC 12288→1024 + ReLU", COLORS["soft_teal"]),
        ("FC 1024→256 + ReLU", COLORS["soft_teal"]),
        ("FC 256→C + Softmax", COLORS["soft_gold"]),
    ]
    cnn = [
        ("Conv3×3 + BN + ReLU", COLORS["soft_blue"]),
        ("Residual Block 32", COLORS["soft_teal"]),
        ("Residual Block 64 / stride=2", COLORS["soft_teal"]),
        ("Residual Block 128 / stride=2", COLORS["soft_teal"]),
        ("Residual Block 256 / stride=2", COLORS["soft_teal"]),
        ("Global Average Pooling", COLORS["soft_gray"]),
        ("Linear 256→C + Softmax", COLORS["soft_gold"]),
    ]
    for blocks, x in [(mlp, 160), (cnn, 1040)]:
        y = 300
        for idx, (text, fill) in enumerate(blocks):
            rounded(draw, (x, y, x + 560, y + 66), 16, fill, outline=(210, 222, 235))
            draw.text((x + 280, y + 33), text, fill=COLORS["ink"], font=font(17, True), anchor="mm")
            if idx < len(blocks) - 1:
                draw.line((x + 280, y + 68, x + 280, y + 96), fill=COLORS["grid"], width=4)
                draw.polygon([(x + 280, y + 100), (x + 270, y + 84), (x + 290, y + 84)], fill=COLORS["grid"])
            y += 96
    draw_wrapped(draw, (140, 790), "MLP 把图像展平成一维向量，直接学习全局像素关系，容易丢失空间局部性。", 34, COLORS["muted"], 15)
    draw_wrapped(draw, (1020, 790), "Residual CNN 保留局部邻域与通道结构，通过残差连接缓解深层训练困难。", 34, COLORS["muted"], 15)
    save(img, root, "figure_model_architecture.png")


def figure_metrics(root: Path, metrics: dict) -> None:
    img, draw = canvas(1800, 1040)
    draw_title(draw, "模型结果对比", "Pilot 数据上的快速复现实验：展平像素 MLP 与局部卷积特征路径", 1800)
    models = metrics.get("models", [])
    x, y, w = 420, 250, 1050
    for idx, model in enumerate(models):
        yy = y + idx * 160
        color = [COLORS["blue"], COLORS["teal"], COLORS["gold"]][idx % 3]
        draw.text((120, yy + 24), model["model"], fill=COLORS["ink"], font=font(23, True))
        for off, key, label in [(0, "accuracy", "Accuracy"), (52, "macro_f1", "Macro-F1")]:
            value = float(model.get(key, 0))
            draw.rounded_rectangle((x, yy + off, x + w, yy + off + 26), radius=13, fill=COLORS["soft_gray"])
            draw.rounded_rectangle((x, yy + off, x + int(w * value), yy + off + 26), radius=13, fill=color)
            draw.text((x - 20, yy + off + 14), label, fill=COLORS["muted"], font=font(14), anchor="ra")
            draw.text((x + w + 24, yy + off + 16), f"{value*100:.1f}%", fill=COLORS["ink"], font=font(18, True), anchor="lm")
    rounded(draw, (120, 720, 1680, 880), 22, COLORS["soft_gold"], outline=(241, 217, 138))
    draw.text((156, 760), "读图说明", fill=COLORS["ink"], font=font(22, True))
    draw_wrapped(
        draw,
        (156, 804),
        "Pilot 实验规模较小，数值主要用于验证代码和比较趋势。完整 Residual CNN 训练代码会在安装 PyTorch 后使用相同数据表运行，可扩大 per_class 参数得到更稳定结果。",
        78,
        COLORS["muted"],
        16,
    )
    save(img, root, "figure_metrics_comparison.png")


def figure_training_curves(root: Path, metrics: dict) -> None:
    img, draw = canvas(1800, 1040)
    draw_title(draw, "训练过程曲线", "左侧展示验证准确率，右侧展示训练损失，数据来自 results/training_log.csv", 1800)
    log = metrics.get("training_log", {})
    panel_y, panel_h = 230, 600
    left = (95, panel_y, 850, panel_y + panel_h)
    right = (950, panel_y, 1705, panel_y + panel_h)
    rounded(draw, (left[0], left[1], left[2], left[3]), 24, COLORS["panel"])
    rounded(draw, (right[0], right[1], right[2], right[3]), 24, COLORS["panel"])
    draw.text((left[0] + 36, left[1] + 28), "验证准确率", fill=COLORS["ink"], font=font(22, True))
    draw.text((right[0] + 36, right[1] + 28), "训练损失", fill=COLORS["ink"], font=font(22, True))
    palette = [COLORS["blue"], COLORS["teal"], COLORS["coral"], COLORS["violet"]]

    def plot_panel(box, key: str, percent: bool, upper: float | None = None) -> None:
        x0, y0, x1, y1 = box
        margin_l, margin_t, margin_r, margin_b = 76, 86, 42, 82
        cx, cy = x0 + margin_l, y0 + margin_t
        cw, ch = x1 - x0 - margin_l - margin_r, y1 - y0 - margin_t - margin_b
        values = []
        for rows in log.values():
            values.extend(float(r.get(key, 0)) for r in rows)
        vmax = upper if upper is not None else max(values + [1.0])
        if not percent:
            vmax = max(vmax, 0.1)
        for i in range(5):
            yy = cy + ch - i * ch / 4
            draw.line((cx, yy, cx + cw, yy), fill=COLORS["grid"], width=1)
            tick = vmax * i / 4
            label = f"{tick*100:.0f}%" if percent else f"{tick:.2f}"
            draw.text((cx - 14, yy), label, fill=COLORS["muted"], font=font(12), anchor="ra")
        for sidx, (model_name, rows) in enumerate(log.items()):
            color = palette[sidx % len(palette)]
            points = []
            max_epoch = max(r["epoch"] for r in rows) if rows else 1
            for r in rows:
                value = float(r.get(key, 0))
                px = cx + (r["epoch"] - 1) / max(1, max_epoch - 1) * cw
                py = cy + ch - min(value / vmax, 1.0) * ch
                points.append((px, py))
            if len(points) > 1:
                draw.line(points, fill=color, width=4, joint="curve")
            if points:
                draw.ellipse((points[-1][0] - 5, points[-1][1] - 5, points[-1][0] + 5, points[-1][1] + 5), fill=color)
        draw.text((cx + cw / 2, cy + ch + 42), "Epoch", fill=COLORS["muted"], font=font(14), anchor="ma")

    plot_panel(left, "val_accuracy", True, 1.0)
    max_loss = max([float(r.get("loss", 0)) for rows in log.values() for r in rows] + [1.0])
    plot_panel(right, "loss", False, max_loss)

    legend_y = 875
    for sidx, (model_name, rows) in enumerate(log.items()):
        color = palette[sidx % len(palette)]
        draw.rounded_rectangle((705 + sidx * 245, legend_y, 725 + sidx * 245, legend_y + 20), 4, fill=color)
        draw.text((738 + sidx * 245, legend_y - 1), model_name, fill=COLORS["muted"], font=font(15))
    draw_wrapped(
        draw,
        (120, 930),
        "训练集准确率很快达到高位，而验证准确率受 Pilot 样本量限制波动明显；这一现象在论文讨论部分用于说明小样本复现实验的泛化边界。",
        86,
        COLORS["muted"],
        15,
    )
    save(img, root, "figure_training_curves.png")


def figure_confusion(root: Path, metrics: dict) -> None:
    img, draw = canvas(1600, 1180)
    draw_title(draw, "分类混淆矩阵", "展示 Pilot 测试集上模型的类别混淆情况", 1600)
    models = metrics.get("models", [])
    if not models:
        save(img, root, "figure_confusion_matrix.png")
        return
    best = max(models, key=lambda m: m.get("accuracy", 0))
    matrix = best["confusion"]
    labels = [cls.zh for cls in TARGET_CLASSES]
    cell = 62
    x0, y0 = 430, 245
    max_v = max([v for row in matrix for v in row] + [1])
    rounded(draw, (80, 205, 355, 330), 18, COLORS["panel"])
    draw.text((110, 235), "最佳 Pilot 模型", fill=COLORS["muted"], font=font(15))
    draw.text((110, 268), best["model"], fill=COLORS["ink"], font=font(20, True))
    draw.text((110, 300), f"Acc={best['accuracy']*100:.1f}%  Macro-F1={best['macro_f1']:.3f}", fill=COLORS["muted"], font=font(13))
    draw.text((x0 + cell * 6, y0 - 60), "预测类别", fill=COLORS["muted"], font=font(15), anchor="ma")
    draw.text((x0 - 95, y0 + cell * 6), "真实类别", fill=COLORS["muted"], font=font(15), anchor="mm")
    for i, row in enumerate(matrix):
        draw.text((x0 - 18, y0 + i * cell + cell / 2), labels[i], fill=COLORS["muted"], font=font(13), anchor="rm")
        draw.text((x0 + i * cell + cell / 2, y0 - 18), labels[i], fill=COLORS["muted"], font=font(13), anchor="ma")
        for j, v in enumerate(row):
            t = v / max_v if max_v else 0
            fill = (
                int(235 - 130 * t),
                int(245 - 105 * t),
                int(255 - 75 * t),
            )
            draw.rounded_rectangle((x0 + j * cell, y0 + i * cell, x0 + j * cell + 58, y0 + i * cell + 58), radius=10, fill=fill)
            draw.text((x0 + j * cell + 29, y0 + i * cell + 29), str(v), fill=COLORS["ink"], font=font(17, True), anchor="mm")
    rounded(draw, (100, 1035, 1500, 1125), 18, COLORS["soft_blue"], outline=(207, 221, 239))
    draw_wrapped(
        draw,
        (130, 1060),
        "混淆矩阵主要用于观察相似视觉类别之间的错误分布。由于 Pilot 测试集样本很小，单个样本会显著改变比例；扩大 per_class 后，交通工具类、动物类和日常物体类的混淆关系会更稳定。",
        92,
        COLORS["muted"],
        15,
    )
    save(img, root, "figure_confusion_matrix.png")


def figure_code_run(root: Path, metrics: dict) -> None:
    img, draw = canvas(1700, 900)
    draw_title(draw, "代码运行结果记录", "核心命令、数据文件与实验结果摘要", 1700)
    rounded(draw, (120, 210, 1580, 760), 24, (21, 34, 56))
    lines = [
        "PS> python main.py --all --per-class 12",
        "[1/4] Download Open Images metadata ... ok",
        "[2/4] Build pilot image subset ... ok",
        "[3/4] Run NumPy quick experiment ... ok",
        "[4/4] Generate figures and report assets ... ok",
        "",
        f"Images: {metrics.get('dataset', {}).get('images', 0)}",
        f"Classes: {len(TARGET_CLASSES)}",
    ]
    for model in metrics.get("models", []):
        lines.append(f"{model['model']}: acc={model['accuracy']:.4f}, macro_f1={model['macro_f1']:.4f}")
    y = 250
    for line in lines:
        draw.text((160, y), line, fill=(232, 240, 248), font=font(18))
        y += 36
    save(img, root, "figure_code_run_result.png")


def generate_all_figures(root: Path | None = None) -> None:
    root = root or project_root()
    ensure_dirs(root)
    rows_path = root / "data" / "processed" / "openimages_pilot_images.csv"
    rows = read_csv(rows_path) if rows_path.exists() else []
    metrics = load_metrics(root)
    figure_framework(root, rows, metrics)
    figure_dataset_dashboard(root, rows)
    figure_sample_grid(root, rows)
    figure_model_architecture(root)
    figure_metrics(root, metrics)
    figure_training_curves(root, metrics)
    figure_confusion(root, metrics)
    figure_code_run(root, metrics)


if __name__ == "__main__":
    generate_all_figures()
