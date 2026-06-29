# 人工智能论文：Open Images 图像分类与 Residual CNN 复现实验

本项目围绕人工智能课程论文的算法复现任务完成：从 Open Images V7 公开视觉数据库下载官方元数据，爬取真实图像样本，构建图像分类数据集，比较 MLP 基线与卷积特征模型，并提供可扩展的 Residual CNN 完整训练代码。

内容包括：爬虫代码、数据处理代码、模型复现代码、实验结果文件、学术可视化图片、Word 论文和论文自动生成脚本。当前压缩包内保存的是便于课程检查快速运行的 Pilot 子集；如果需要扩大实验规模，可把 `--per-class` 调整为 `1000` 或更高。

## 一键运行

在项目根目录执行：

```powershell
python -m pip install -r requirements.txt
python main.py --all --per-class 7
```

该命令会依次完成：

1. 下载 Open Images 官方元数据。
2. 根据目标类别爬取图像缩略图。
3. 运行 NumPy 快速复现实验。
4. 生成论文可视化图片。

完整 PyTorch Residual CNN 训练入口：

```powershell
pip install torch
python -m src.train_torch
```

## 项目结构

```text
人工智能论文/
  main.py                         一键运行入口
  requirements.txt                依赖列表
  README.md                       项目说明
  src/
    config.py                     数据源、类别、图像尺寸和项目配置
    openimages_crawler.py         Open Images 元数据下载与图像爬虫
    numpy_experiment.py           无 PyTorch 环境下的 MLP/CNN-local 快速实验
    torch_models.py               MLP 与 Residual CNN 的 PyTorch 模型定义
    train_torch.py                完整 PyTorch 训练与评估入口
    visualization.py              论文可视化图片生成
    report_builder.py             Word 论文自动生成脚本
  scripts/
    crawl_openimages.py           单独运行爬虫的脚本
    build_report.py               单独生成 Word 论文的脚本
  data/raw/                       Open Images 官方 CSV 元数据
  data/images/                    爬取得到的真实 Open Images 图像缩略图
  data/processed/                 样本索引 openimages_pilot_images.csv
  results/                        指标、训练日志、模型对比结果
  figures/                        论文图像
```

## 当前 Pilot 数据与结果

当前交付包内包含 12 类、75 张真实 Open Images 图像，主要用于快速验证完整复现链路。模型结果如下：

| 模型 | Accuracy | Macro-F1 | 说明 |
|---|---:|---:|---|
| MLP(flatten pixels) | 10.0% | 0.0556 | 展平像素输入的 MLP 基线 |
| CNN-local features | 20.0% | 0.0972 | 固定卷积滤波与池化特征的轻量 CNN 路径 |

完整 Residual CNN 代码采用 `Conv-BN-ReLU + Residual Block + Global Average Pooling + Linear` 结构，可在安装 PyTorch 后使用同一数据表训练。论文中对 Pilot 结果和完整 Residual CNN 训练入口做了区分说明，避免把小样本快速验证误写成大规模最终结论。

## 数据来源

Open Images V7 官方页面：

- https://storage.googleapis.com/openimages/web/index.html
- https://storage.googleapis.com/openimages/web/download_v7.html

项目使用官方 CSV 元数据筛选类别，并保留每张图片的 URL、作者和许可协议信息。论文中的统计图、框架图、模型结构图、曲线图和混淆矩阵均由 Python 脚本根据本地结果自行绘制。
