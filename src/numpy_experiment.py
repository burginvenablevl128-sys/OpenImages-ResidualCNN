from __future__ import annotations

import csv
import json
import math
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

from .config import IMAGE_SIZE, RANDOM_SEED, TARGET_CLASSES, ensure_dirs, project_root


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def load_images(root: Path, rows: list[dict[str, str]]) -> tuple[np.ndarray, np.ndarray, list[str]]:
    label_ids = [cls.label_id for cls in TARGET_CLASSES]
    label_to_idx = {label_id: idx for idx, label_id in enumerate(label_ids)}
    images = []
    labels = []
    kept_paths = []
    for row in rows:
        path = root / row["local_path"]
        if not path.exists():
            continue
        with Image.open(path) as img:
            img = img.convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE))
            arr = np.asarray(img, dtype=np.float32) / 255.0
        images.append(arr)
        labels.append(label_to_idx[row["label_id"]])
        kept_paths.append(row["local_path"])
    return np.stack(images), np.asarray(labels, dtype=np.int64), kept_paths


def stratified_split(y: np.ndarray, train_ratio: float = 0.7, val_ratio: float = 0.15) -> dict[str, np.ndarray]:
    rng = np.random.default_rng(RANDOM_SEED)
    train, val, test = [], [], []
    for label in sorted(set(y.tolist())):
        idx = np.where(y == label)[0]
        rng.shuffle(idx)
        n = len(idx)
        n_train = max(1, int(round(n * train_ratio)))
        n_val = max(1, int(round(n * val_ratio)))
        train.extend(idx[:n_train].tolist())
        val.extend(idx[n_train : n_train + n_val].tolist())
        test.extend(idx[n_train + n_val :].tolist())
    return {
        "train": np.asarray(train, dtype=np.int64),
        "validation": np.asarray(val, dtype=np.int64),
        "test": np.asarray(test, dtype=np.int64),
    }


def one_hot(y: np.ndarray, classes: int) -> np.ndarray:
    out = np.zeros((len(y), classes), dtype=np.float32)
    out[np.arange(len(y)), y] = 1.0
    return out


def standardize(train_x: np.ndarray, *arrays: np.ndarray) -> tuple[np.ndarray, ...]:
    mean = train_x.mean(axis=0, keepdims=True)
    std = train_x.std(axis=0, keepdims=True) + 1e-6
    return tuple((arr - mean) / std for arr in arrays)


def softmax(logits: np.ndarray) -> np.ndarray:
    logits = logits - logits.max(axis=1, keepdims=True)
    exp = np.exp(logits)
    return exp / exp.sum(axis=1, keepdims=True)


def macro_f1(y_true: np.ndarray, y_pred: np.ndarray, classes: int) -> tuple[float, list[dict[str, float]]]:
    rows = []
    for cls in range(classes):
        tp = int(((y_true == cls) & (y_pred == cls)).sum())
        fp = int(((y_true != cls) & (y_pred == cls)).sum())
        fn = int(((y_true == cls) & (y_pred != cls)).sum())
        support = int((y_true == cls).sum())
        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        rows.append({"precision": precision, "recall": recall, "f1": f1, "support": support})
    return float(np.mean([r["f1"] for r in rows])), rows


def confusion_matrix(y_true: np.ndarray, y_pred: np.ndarray, classes: int) -> list[list[int]]:
    matrix = np.zeros((classes, classes), dtype=int)
    for t, p in zip(y_true, y_pred):
        matrix[int(t), int(p)] += 1
    return matrix.tolist()


class MLPClassifier:
    def __init__(self, input_dim: int, hidden: int, classes: int, seed: int = RANDOM_SEED):
        rng = np.random.default_rng(seed)
        self.w1 = rng.normal(0, math.sqrt(2 / input_dim), size=(input_dim, hidden)).astype(np.float32)
        self.b1 = np.zeros((1, hidden), dtype=np.float32)
        self.w2 = rng.normal(0, math.sqrt(2 / hidden), size=(hidden, classes)).astype(np.float32)
        self.b2 = np.zeros((1, classes), dtype=np.float32)

    def forward(self, x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        h = np.maximum(0, x @ self.w1 + self.b1)
        logits = h @ self.w2 + self.b2
        return h, logits

    def fit(
        self,
        x_train: np.ndarray,
        y_train: np.ndarray,
        x_val: np.ndarray,
        y_val: np.ndarray,
        epochs: int = 80,
        lr: float = 0.03,
        weight_decay: float = 1e-4,
    ) -> list[dict[str, float]]:
        y_onehot = one_hot(y_train, self.b2.shape[1])
        log = []
        n = len(x_train)
        for epoch in range(1, epochs + 1):
            h, logits = self.forward(x_train)
            probs = softmax(logits)
            loss = -np.mean(np.sum(y_onehot * np.log(probs + 1e-9), axis=1))
            loss += weight_decay * (np.sum(self.w1 * self.w1) + np.sum(self.w2 * self.w2))
            grad_logits = (probs - y_onehot) / n
            grad_w2 = h.T @ grad_logits + 2 * weight_decay * self.w2
            grad_b2 = grad_logits.sum(axis=0, keepdims=True)
            grad_h = grad_logits @ self.w2.T
            grad_h[h <= 0] = 0
            grad_w1 = x_train.T @ grad_h + 2 * weight_decay * self.w1
            grad_b1 = grad_h.sum(axis=0, keepdims=True)
            self.w2 -= lr * grad_w2
            self.b2 -= lr * grad_b2
            self.w1 -= lr * grad_w1
            self.b1 -= lr * grad_b1
            train_pred = self.predict(x_train)
            val_pred = self.predict(x_val)
            log.append(
                {
                    "epoch": epoch,
                    "loss": float(loss),
                    "train_accuracy": float((train_pred == y_train).mean()),
                    "val_accuracy": float((val_pred == y_val).mean()),
                }
            )
        return log

    def predict_proba(self, x: np.ndarray) -> np.ndarray:
        return softmax(self.forward(x)[1])

    def predict(self, x: np.ndarray) -> np.ndarray:
        return self.predict_proba(x).argmax(axis=1)


def flatten_features(images: np.ndarray) -> np.ndarray:
    return images.reshape(images.shape[0], -1).astype(np.float32)


def pooled_conv_features(images: np.ndarray) -> np.ndarray:
    gray = images.mean(axis=3)
    filters = np.asarray(
        [
            [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]],
            [[-1, -2, -1], [0, 0, 0], [1, 2, 1]],
            [[0, 1, 0], [1, -4, 1], [0, 1, 0]],
            [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
        ],
        dtype=np.float32,
    )
    filters[-1] /= 9.0
    n, h, w = gray.shape
    feats = []
    for f in filters:
        conv = np.zeros((n, h - 2, w - 2), dtype=np.float32)
        for i in range(3):
            for j in range(3):
                conv += gray[:, i : i + h - 2, j : j + w - 2] * f[i, j]
        conv = np.maximum(conv, 0)
        grid = 8
        usable_h = ((h - 2) // grid) * grid
        usable_w = ((w - 2) // grid) * grid
        conv = conv[:, :usable_h, :usable_w]
        pooled = conv.reshape(n, grid, usable_h // grid, grid, usable_w // grid).mean(axis=(2, 4))
        feats.append(pooled.reshape(n, -1))
    color_mean = images.reshape(n, -1, 3).mean(axis=1)
    color_std = images.reshape(n, -1, 3).std(axis=1)
    return np.concatenate(feats + [color_mean, color_std], axis=1).astype(np.float32)


def evaluate_model(name: str, model: MLPClassifier, x: np.ndarray, y: np.ndarray, classes: int) -> dict[str, object]:
    pred = model.predict(x)
    f1, per_class = macro_f1(y, pred, classes)
    return {
        "model": name,
        "accuracy": float((pred == y).mean()),
        "macro_f1": f1,
        "confusion": confusion_matrix(y, pred, classes),
        "per_class": per_class,
    }


def run_numpy_experiment(root: Path | None = None) -> dict[str, object]:
    root = root or project_root()
    ensure_dirs(root)
    dataset_csv = root / "data" / "processed" / "openimages_pilot_images.csv"
    rows = read_csv(dataset_csv)
    images, labels, paths = load_images(root, rows)
    splits = stratified_split(labels)
    class_count = len(TARGET_CLASSES)

    flat = flatten_features(images)
    conv = pooled_conv_features(images)
    flat_train, flat_val, flat_test = standardize(
        flat[splits["train"]], flat[splits["train"]], flat[splits["validation"]], flat[splits["test"]]
    )
    conv_train, conv_val, conv_test = standardize(
        conv[splits["train"]], conv[splits["train"]], conv[splits["validation"]], conv[splits["test"]]
    )

    y_train = labels[splits["train"]]
    y_val = labels[splits["validation"]]
    y_test = labels[splits["test"]]

    mlp = MLPClassifier(flat_train.shape[1], hidden=96, classes=class_count)
    mlp_log = mlp.fit(flat_train, y_train, flat_val, y_val, epochs=80, lr=0.025)
    conv_model = MLPClassifier(conv_train.shape[1], hidden=96, classes=class_count, seed=RANDOM_SEED + 1)
    conv_log = conv_model.fit(conv_train, y_train, conv_val, y_val, epochs=80, lr=0.04)

    mlp_eval = evaluate_model("MLP(flatten pixels)", mlp, flat_test, y_test, class_count)
    conv_eval = evaluate_model("CNN-local features", conv_model, conv_test, y_test, class_count)
    labels_meta = [
        {"index": idx, "label_id": cls.label_id, "zh": cls.zh, "en": cls.en}
        for idx, cls in enumerate(TARGET_CLASSES)
    ]
    result = {
        "dataset": {
            "images": int(len(images)),
            "classes": class_count,
            "image_size": IMAGE_SIZE,
            "train": int(len(splits["train"])),
            "validation": int(len(splits["validation"])),
            "test": int(len(splits["test"])),
            "class_counts": Counter(labels.tolist()),
        },
        "labels": labels_meta,
        "models": [mlp_eval, conv_eval],
        "training_log": {
            "MLP(flatten pixels)": mlp_log,
            "CNN-local features": conv_log,
        },
        "splits": {k: v.tolist() for k, v in splits.items()},
        "paths": paths,
    }

    clean_result = json.loads(json.dumps(result, default=lambda x: int(x)))
    with (root / "results" / "metrics.json").open("w", encoding="utf-8") as f:
        json.dump(clean_result, f, ensure_ascii=False, indent=2)

    rows_out = []
    for model in clean_result["models"]:
        rows_out.append(
            {
                "model": model["model"],
                "accuracy": model["accuracy"],
                "macro_f1": model["macro_f1"],
                "note": "Pilot NumPy experiment on downloaded Open Images thumbnails",
            }
        )
    write_csv(root / "results" / "model_comparison.csv", rows_out, ["model", "accuracy", "macro_f1", "note"])

    log_rows = []
    for model_name, model_log in clean_result["training_log"].items():
        for row in model_log:
            log_rows.append({"model": model_name, **row})
    write_csv(root / "results" / "training_log.csv", log_rows, ["model", "epoch", "loss", "train_accuracy", "val_accuracy"])
    return clean_result


if __name__ == "__main__":
    run_numpy_experiment()
