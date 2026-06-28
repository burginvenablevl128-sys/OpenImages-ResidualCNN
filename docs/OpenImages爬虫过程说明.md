# Open Images 数据采集与爬虫过程

## 数据源

本项目使用 Open Images V7 官方公开数据：

- Open Images 官方主页：https://storage.googleapis.com/openimages/web/index.html
- Open Images V7 下载页：https://storage.googleapis.com/openimages/web/download_v7.html
- 类别描述文件：`oidv7-class-descriptions.csv`
- 验证集图像级人工标签：`oidv7-val-annotations-human-imagelabels.csv`
- 验证集图像 URL 清单：`validation-images-with-rotation.csv`

## 采集逻辑

1. 下载 Open Images 官方 CSV 元数据。
2. 在类别描述表中确定目标类别的 MID。
3. 在图像级标签表中筛选 `Confidence=1` 且属于目标类别的 `ImageID`。
4. 在图像 URL 清单中找到对应图像的 `Thumbnail300KURL`、原始 URL、作者、标题与许可证信息。
5. 按类别下载缩略图，统一转成 RGB，并 resize 到 `64×64×3`。
6. 保存本地图片路径、类别、MID、URL、作者、许可协议等字段到 `data/processed/openimages_pilot_images.csv`。
7. 下载失败的图片记录在 `logs/download_failures.csv`，便于复查远程链接失效或超时情况。

## 类别选择

目标类别覆盖动物、交通工具、日常物体和自然场景，包括：

`Cat, Dog, Car, Bicycle, Motorcycle, Bird, Horse, Boat, Airplane, Chair, Truck, Flower`

这些类别在 Open Images 验证集中样本较充足，语义较清楚，适合作为多类别图像分类任务。

## 运行命令

```powershell
python main.py --crawl --per-class 8
```

若希望扩大数据规模，可将 `--per-class` 调整为 1000 或更高：

```powershell
python main.py --crawl --per-class 1000
```

完整训练时建议在拥有 GPU 与 PyTorch 的环境中运行。
