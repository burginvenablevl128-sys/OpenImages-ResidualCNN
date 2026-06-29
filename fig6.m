%% 训练过程诊断图
clear; clc; close all;

projectRoot = pwd;
trainingCsv = fullfile(projectRoot,"training_log.csv");
outDir = fullfile(projectRoot, "figures");

if ~exist(outDir, "dir")
    mkdir(outDir);
end

trainLog = readtable(trainingCsv);

models = unique(string(trainLog.model), "stable");
modelNameCn = ["MLP 展平像素", "CNN 局部卷积特征"];
palette = [0.18 0.38 0.86; 0.10 0.45 0.40];

f = figure("Color","w", ...
    "Name","训练日志曲线", ...
    "Position",[100 80 1450 650]);

tiledlayout(f, 1, 2, ...
    "TileSpacing","compact", ...
    "Padding","compact");

%% （a）训练损失曲线
nexttile;
hold on; grid on; box on;

for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);
    plot(trainLog.epoch(rows), trainLog.loss(rows), ...
        "Color", palette(i,:), ...
        "LineWidth", 1.6);
end

xlabel("训练轮次");
ylabel("训练损失");
title("（a）训练损失曲线", "FontWeight","bold");
legend(modelNameCn, "Location","northeast");

%% （b）训练集与验证集准确率
nexttile;
hold on; grid on; box on;

for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);

    plot(trainLog.epoch(rows), trainLog.train_accuracy(rows), "--", ...
        "Color", palette(i,:), ...
        "LineWidth", 1.1);

    plot(trainLog.epoch(rows), trainLog.val_accuracy(rows), "-", ...
        "Color", palette(i,:), ...
        "LineWidth", 1.8);
end

xlabel("训练轮次");
ylabel("准确率");
ylim([0 1.05]);
title("（b）训练集与验证集准确率", "FontWeight","bold");

legend({ ...
    "MLP 训练集", "MLP 验证集", ...
    "CNN-local 训练集", "CNN-local 验证集"}, ...
    "Location","southeast");

sgtitle("基于 training_log.csv 的训练过程诊断图", "FontWeight","bold");

exportgraphics(f, fullfile(outDir, "图5_训练过程诊断图.png"), "Resolution", 300);