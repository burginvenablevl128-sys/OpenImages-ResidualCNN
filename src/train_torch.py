from __future__ import annotations

import csv
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from .config import IMAGE_SIZE, RANDOM_SEED, TARGET_CLASSES, project_root
from .torch_models import MLPBaseline, ResidualCNN, count_parameters, torch


if torch is not None:
    from torch.utils.data import DataLoader, Dataset


class OpenImagesTorchDataset(Dataset if torch is not None else object):
    def __init__(self, root: Path, rows: list[dict[str, str]], indices: list[int], train: bool = False):
        self.root = root
        self.rows = rows
        self.indices = indices
        self.train = train
        self.label_to_idx = {cls.label_id: idx for idx, cls in enumerate(TARGET_CLASSES)}

    def __len__(self) -> int:
        return len(self.indices)

    def __getitem__(self, item: int):
        row = self.rows[self.indices[item]]
        image = Image.open(self.root / row["local_path"]).convert("RGB").resize((IMAGE_SIZE, IMAGE_SIZE))
        if self.train and random.random() < 0.5:
            image = ImageOps.mirror(image)
        arr = np.asarray(image, dtype=np.float32) / 255.0
        arr = (arr - np.asarray([0.485, 0.456, 0.406])) / np.asarray([0.229, 0.224, 0.225])
        arr = np.transpose(arr, (2, 0, 1))
        return torch.tensor(arr, dtype=torch.float32), torch.tensor(self.label_to_idx[row["label_id"]], dtype=torch.long)


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def make_splits(rows: list[dict[str, str]]) -> dict[str, list[int]]:
    rng = random.Random(RANDOM_SEED)
    by_label: dict[str, list[int]] = {}
    for idx, row in enumerate(rows):
        by_label.setdefault(row["label_id"], []).append(idx)
    splits = {"train": [], "validation": [], "test": []}
    for indices in by_label.values():
        rng.shuffle(indices)
        n = len(indices)
        n_train = max(1, round(n * 0.7))
        n_val = max(1, round(n * 0.15))
        splits["train"].extend(indices[:n_train])
        splits["validation"].extend(indices[n_train : n_train + n_val])
        splits["test"].extend(indices[n_train + n_val :])
    return splits


def evaluate(model, loader, device, classes: int) -> dict[str, object]:
    model.eval()
    true, pred = [], []
    with torch.no_grad():
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            logits = model(x)
            true.extend(y.cpu().numpy().tolist())
            pred.extend(logits.argmax(dim=1).cpu().numpy().tolist())
    true_arr = np.asarray(true)
    pred_arr = np.asarray(pred)
    confusion = np.zeros((classes, classes), dtype=int)
    per_class = []
    for t, p in zip(true_arr, pred_arr):
        confusion[int(t), int(p)] += 1
    for cls in range(classes):
        tp = int(confusion[cls, cls])
        fp = int(confusion[:, cls].sum() - tp)
        fn = int(confusion[cls, :].sum() - tp)
        precision = tp / (tp + fp) if tp + fp else 0.0
        recall = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        per_class.append({"precision": precision, "recall": recall, "f1": f1, "support": int(confusion[cls, :].sum())})
    return {
        "accuracy": float((true_arr == pred_arr).mean()) if len(true_arr) else 0.0,
        "macro_f1": float(np.mean([x["f1"] for x in per_class])),
        "confusion": confusion.tolist(),
        "per_class": per_class,
    }


def train_one(model, train_loader, val_loader, device, epochs: int, lr: float, name: str) -> tuple[object, list[dict[str, float]]]:
    criterion = torch.nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    best_state = None
    best_acc = -1.0
    log = []
    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        total = 0
        correct = 0
        for x, y in train_loader:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            logits = model(x)
            loss = criterion(logits, y)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item()) * len(y)
            total += len(y)
            correct += int((logits.argmax(dim=1) == y).sum().item())
        val_eval = evaluate(model, val_loader, device, len(TARGET_CLASSES))
        train_acc = correct / total if total else 0.0
        if val_eval["accuracy"] > best_acc:
            best_acc = val_eval["accuracy"]
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
        log.append(
            {
                "model": name,
                "epoch": epoch,
                "loss": total_loss / total if total else 0.0,
                "train_accuracy": train_acc,
                "val_accuracy": val_eval["accuracy"],
                "val_macro_f1": val_eval["macro_f1"],
            }
        )
    if best_state is not None:
        model.load_state_dict(best_state)
    return model, log


def run_torch_training(root: Path | None = None, epochs: int = 20, batch_size: int = 32) -> dict[str, object]:
    if torch is None:
        raise RuntimeError("PyTorch is not installed. Install torch first or run src.numpy_experiment instead.")
    root = root or project_root()
    random.seed(RANDOM_SEED)
    np.random.seed(RANDOM_SEED)
    torch.manual_seed(RANDOM_SEED)
    rows = read_rows(root / "data" / "processed" / "openimages_pilot_images.csv")
    splits = make_splits(rows)
    train_ds = OpenImagesTorchDataset(root, rows, splits["train"], train=True)
    val_ds = OpenImagesTorchDataset(root, rows, splits["validation"], train=False)
    test_ds = OpenImagesTorchDataset(root, rows, splits["test"], train=False)
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=0)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False, num_workers=0)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    models = {
        "MLP": MLPBaseline(IMAGE_SIZE, len(TARGET_CLASSES)).to(device),
        "ResidualCNN": ResidualCNN(len(TARGET_CLASSES)).to(device),
    }
    results = {"models": [], "training_log": [], "splits": splits}
    for name, model in models.items():
        model, log = train_one(model, train_loader, val_loader, device, epochs, lr=1e-3, name=name)
        test_eval = evaluate(model, test_loader, device, len(TARGET_CLASSES))
        test_eval["model"] = name
        test_eval["parameters"] = count_parameters(model)
        results["models"].append(test_eval)
        results["training_log"].extend(log)

    out = root / "results" / "torch_metrics.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    return results


if __name__ == "__main__":
    run_torch_training()
