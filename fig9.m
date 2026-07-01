%% 图9：模型评价热力图与混淆矩阵（蓝色风格版）
clear; clc; close all;

projectRoot = pwd;

outDir = fullfile(projectRoot, "figures_matlab");
if ~exist(outDir, "dir")
    mkdir(outDir);
end

%% 读取 metrics.json
metricsJson = fullfile(projectRoot, "metrics.json");

if ~exist(metricsJson, "file")
    metricsJson = fullfile(projectRoot, "results", "metrics.json");
end

if ~exist(metricsJson, "file")
    error("找不到 metrics.json，请把它放在当前文件夹，或 results 文件夹中。");
end

metrics = jsondecode(fileread(metricsJson));

%% 类别名
className = ["猫","狗","汽车","自行车","摩托车","鸟", ...
             "马","船","飞机","椅子","卡车","花"];

%% 模型指标
modelDisplayNames = ["MLP 展平像素", "CNN 局部卷积特征"];

A = [[metrics.models.accuracy]' [metrics.models.macro_f1]'];

[~, bestIdx] = max([metrics.models.accuracy]);
C = metrics.models(bestIdx).confusion;

%% 第一张图风格：浅蓝底 + 深蓝强调
pageBg = [0.95 0.97 0.985];
blueMap = makeFirstStyleBlueMap(256);

f = figure("Color", pageBg, ...
    "Name", "模型评价热力图", ...
    "Position", [100 80 1550 760]);

tiledlayout(f, 1, 2, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

%% （a）模型指标热力图
nexttile;
imagesc(A);
colormap(gca, blueMap);
colorbar;

set(gca, ...
    "Color", pageBg, ...
    "XTick", 1:2, ...
    "XTickLabel", ["准确率", "宏平均 F1"], ...
    "YTick", 1:numel(modelDisplayNames), ...
    "YTickLabel", modelDisplayNames, ...
    "GridColor", [0.80 0.87 0.93], ...
    "LineWidth", 0.8);

title("（a）模型指标热力图", "FontWeight", "bold");

for i = 1:size(A,1)
    for j = 1:size(A,2)
        text(j, i, sprintf("%.3f", A(i,j)), ...
            "HorizontalAlignment", "center", ...
            "FontWeight", "bold", ...
            "Color", pickTextColorBlue(A(i,j), max(A(:))));
    end
end

%% （b）CNN 局部卷积特征模型混淆矩阵
nexttile;
imagesc(C);
colormap(gca, blueMap);
colorbar;
axis square;

set(gca, ...
    "Color", pageBg, ...
    "XTick", 1:numel(className), ...
    "XTickLabel", className, ...
    "YTick", 1:numel(className), ...
    "YTickLabel", className, ...
    "XTickLabelRotation", 45, ...
    "GridColor", [0.80 0.87 0.93], ...
    "LineWidth", 0.8);

xlabel("预测类别");
ylabel("真实类别");
title("（b）CNN 局部卷积特征模型混淆矩阵", "FontWeight", "bold");

for i = 1:size(C,1)
    for j = 1:size(C,2)
        if C(i,j) > 0
            text(j, i, num2str(C(i,j)), ...
                "HorizontalAlignment", "center", ...
                "FontWeight", "bold", ...
                "Color", pickTextColorBlue(C(i,j), max(C(:))));
        end
    end
end

outPath = fullfile(outDir, "图9_指标热力图与混淆矩阵.png");
print(f, outPath, "-dpng", "-r300");

fprintf("已保存：%s\n", outPath);

%% ===== 辅助函数 =====

function cmap = makeFirstStyleBlueMap(n)
    % 必须返回 n 行 3 列，每一行是 [R G B]
    anchors = [
        0.93 0.97 1.00
        0.84 0.91 0.97
        0.70 0.82 0.92
        0.47 0.64 0.80
        0.28 0.43 0.62
    ];

    x = linspace(0, 1, size(anchors, 1));
    xi = linspace(0, 1, n)';

    r = interp1(x, anchors(:,1), xi);
    g = interp1(x, anchors(:,2), xi);
    b = interp1(x, anchors(:,3), xi);

    cmap = [r g b];

    cmap(cmap < 0) = 0;
    cmap(cmap > 1) = 1;
end

function color = pickTextColorBlue(value, maxValue)
    if maxValue == 0
        color = [0.10 0.16 0.25];
    elseif value / maxValue > 0.55
        color = [1 1 1];
    else
        color = [0.10 0.16 0.25];
    end
end