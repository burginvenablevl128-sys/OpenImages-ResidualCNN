clear; clc;

% 本脚本用于根据项目运行结果绘制论文用学术图片
% 请从项目根目录运行本脚本。

projectRoot = pwd;
outDir = fullfile(projectRoot, "figures_matlab");
if ~exist(outDir, "dir")
    mkdir(outDir);
end

dataCsv = fullfile(projectRoot, "data", "processed", "openimages_pilot_images.csv");
metricsJson = fullfile(projectRoot, "results", "metrics.json");
trainingCsv = fullfile(projectRoot, "results", "training_log.csv");

T = readtable(dataCsv, "TextType", "string", "Encoding", "UTF-8");
trainLog = readtable(trainingCsv, "TextType", "string", "Encoding", "UTF-8");
metrics = jsondecode(fileread(metricsJson));

classKey = ["Cat","Dog","Car","Bicycle","Motorcycle","Bird","Horse","Boat","Airplane","Chair","Truck","Flower"];
className = ["猫","狗","汽车","自行车","摩托车","鸟","马","船","飞机","椅子","卡车","花"];

colors = lines(numel(classKey));

set(groot, "defaultAxesFontName", "Microsoft YaHei");
set(groot, "defaultTextFontName", "Microsoft YaHei");
set(groot, "defaultAxesFontSize", 10);
set(groot, "defaultLineLineWidth", 1.4);

%% 图1：论文整体研究框架图
f = figure("Color","w","Name","论文整体研究框架图","Position",[100 80 1400 780]);
ax = axes(f, "Position",[0 0 1 1]);
axis(ax, "off");

title(ax, "论文整体思路：从像素展平到残差卷积神经网络复现", ...
    "FontWeight","bold","FontSize",15);

nodes = {
    "1. 问题提出", "图像展平成向量会削弱空间邻域关系";
    "2. 数据来源", "Open Images V7 官方元数据、标签与图像链接";
    "3. 爬取子集", "12 个类别、75 张图像、保留许可与来源字段";
    "4. 数据预处理", "RGB 转换、64×64 缩放、分层划分训练集/验证集/测试集";
    "5A. MLP 基线", "展平像素 + 全连接分类器";
    "5B. 局部卷积特征", "Sobel/Laplacian 滤波 + 池化统计特征";
    "5C. ResidualCNN", "卷积块 + 批归一化 + 残差捷径连接";
    "6. 实验评价", "准确率、Macro-F1、PCA、训练曲线、混淆矩阵";
    "7. 结果讨论", "卷积归纳偏置、小样本边界与后续扩展"
};

xy = [
    0.06 0.75 0.20 0.12
    0.30 0.75 0.20 0.12
    0.54 0.75 0.20 0.12
    0.78 0.75 0.20 0.12
    0.08 0.45 0.24 0.14
    0.38 0.45 0.24 0.14
    0.68 0.45 0.24 0.14
    0.28 0.23 0.44 0.12
    0.28 0.07 0.44 0.12
];

fills = [
    0.96 0.98 1.00
    0.96 1.00 0.98
    1.00 0.98 0.92
    0.98 0.98 0.98
    0.95 0.97 1.00
    0.93 0.99 0.98
    1.00 0.95 0.95
    0.98 0.96 1.00
    0.96 0.96 0.96
];

edge = [0.20 0.28 0.40];

for i = 1:size(xy,1)
    rectangle(ax, "Position", xy(i,:), "Curvature", 0.05, ...
        "FaceColor", fills(i,:), "EdgeColor", edge, "LineWidth", 1.2);
    text(xy(i,1)+0.012, xy(i,2)+xy(i,4)-0.035, nodes{i,1}, ...
        "FontWeight","bold","FontSize",10.5, "Color",[0.08 0.13 0.22]);
    text(xy(i,1)+0.012, xy(i,2)+xy(i,4)-0.075, nodes{i,2}, ...
        "FontSize",8.8, "Color",[0.24 0.29 0.36]);
end

arrowList = [
    0.26 0.81 0.30 0.81
    0.50 0.81 0.54 0.81
    0.74 0.81 0.78 0.81
    0.88 0.75 0.88 0.65
    0.88 0.65 0.20 0.65
    0.20 0.65 0.20 0.59
    0.50 0.65 0.50 0.59
    0.80 0.65 0.80 0.59
    0.20 0.45 0.42 0.35
    0.50 0.45 0.50 0.35
    0.80 0.45 0.58 0.35
    0.50 0.23 0.50 0.19
];

for k = 1:size(arrowList,1)
    annotation(f, "arrow", arrowList(k,[1 3]), arrowList(k,[2 4]), ...
        "Color", edge, "LineWidth", 1.1);
end

saveFig(f, outDir, "图1_论文整体研究框架图.png");

%% 图2：数据集类别分布与分层划分矩阵
labels = string(T.label_en);

splitNames = strings(height(T),1);
splitNames(:) = "未使用";
splitNames(double(metrics.splits.train(:)) + 1) = "训练集";
splitNames(double(metrics.splits.validation(:)) + 1) = "验证集";
splitNames(double(metrics.splits.test(:)) + 1) = "测试集";

splitOrder = ["训练集","验证集","测试集"];
M = zeros(numel(classKey), numel(splitOrder));
totalCounts = zeros(numel(classKey),1);

for i = 1:numel(classKey)
    totalCounts(i) = sum(labels == classKey(i));
    for j = 1:numel(splitOrder)
        M(i,j) = sum(labels == classKey(i) & splitNames == splitOrder(j));
    end
end

f = figure("Color","w","Name","数据集统计图","Position",[100 80 1450 760]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
bar(totalCounts, "FaceColor",[0.25 0.49 0.78], "EdgeColor","none");
grid on; box on;
set(gca,"XTick",1:numel(className),"XTickLabel",className,"XTickLabelRotation",42);
ylabel("图像数量");
title("（a）Pilot 子集类别分布","FontWeight","bold");
ylim([0 max(totalCounts)+2]);
for i = 1:numel(totalCounts)
    text(i, totalCounts(i)+0.25, num2str(totalCounts(i)), ...
        "HorizontalAlignment","center","FontSize",8);
end

nexttile;
imagesc(M);
colormap(gca, parula);
colorbar;
set(gca,"XTick",1:numel(splitOrder),"XTickLabel",splitOrder, ...
    "YTick",1:numel(className),"YTickLabel",className);
xlabel("数据划分"); ylabel("类别");
title("（b）分层划分矩阵","FontWeight","bold");

for i = 1:size(M,1)
    for j = 1:size(M,2)
        text(j, i, num2str(M(i,j)), "HorizontalAlignment","center", ...
            "FontWeight","bold", "Color", pickTextColor(M(i,j), max(M(:))));
    end
end

sgtitle("Open Images Pilot 子集数据统计","FontWeight","bold");
saveFig(f, outDir, "图2_数据集统计与划分矩阵.png");

%% 图3：代表性图像 RGB 强度剖面
chosenKey = ["Cat","Car","Bird","Flower"];
chosenName = ["猫","汽车","鸟","花"];

f = figure("Color","w","Name","RGB强度剖面图","Position",[100 80 1500 850]);
tiledlayout(f,4,1,"TileSpacing","compact","Padding","compact");

for k = 1:numel(chosenKey)
    idx = find(labels == chosenKey(k), 1, "first");
    imgPath = fullfile(projectRoot, replace(T.local_path(idx), "/", filesep));
    img = im2double(imread(imgPath));
    if size(img,3) == 1
        img = repmat(img,1,1,3);
    end

    prof = squeeze(mean(img,1));
    gray = mean(img,3);
    rmsVal = sqrt(mean(gray(:).^2));
    contrastVal = std(gray(:));

    nexttile;
    x = 1:size(prof,1);
    plot(x, prof(:,1), "Color",[0.86 0.18 0.16]); hold on;
    plot(x, prof(:,2), "Color",[0.20 0.60 0.30]);
    plot(x, prof(:,3), "Color",[0.18 0.42 0.76]);

    ylim([0 1]); xlim([1 size(prof,1)]);
    grid on; box on;
    ylabel(chosenName(k));

    if k == numel(chosenKey)
        xlabel("水平像素坐标");
    else
        set(gca,"XTickLabel",[]);
    end

    text(0.985,0.82,sprintf("均方根=%.2f  对比度=%.2f",rmsVal,contrastVal), ...
        "Units","normalized","HorizontalAlignment","right", ...
        "BackgroundColor","w","EdgeColor",[0.55 0.55 0.55],"Margin",3,"FontSize",8.5);

    if k == 1
        legend({"R 通道","G 通道","B 通道"}, ...
            "Location","southwest","Box","off","NumColumns",3);
    end
end

sgtitle("代表性图像 RGB 强度剖面图", "FontWeight","bold");
saveFig(f, outDir, "图3_RGB强度剖面图.png");

%% 图4：PCA 特征空间二维与三维投影
X = zeros(height(T), 55);

for i = 1:height(T)
    imgPath = fullfile(projectRoot, replace(T.local_path(i), "/", filesep));
    img = im2double(imread(imgPath));
    if size(img,3) == 1
        img = repmat(img,1,1,3);
    end
    X(i,:) = imageFeatureVector(img);
end

Xz = normalize(X);
[score, explained] = pcaBySvd(Xz);

f = figure("Color","w","Name","PCA特征空间可视化","Position",[100 80 1500 720]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
hold on; grid on; box on;
for c = 1:numel(classKey)
    idx = labels == classKey(c);
    scatter(score(idx,1), score(idx,2), 32, colors(c,:), "filled", ...
        "MarkerFaceAlpha",0.78, "MarkerEdgeColor","w");
end
xlabel(sprintf("主成分1（%.1f%%）", explained(1)));
ylabel(sprintf("主成分2（%.1f%%）", explained(2)));
title(sprintf("（a）二维 PCA 投影（累计方差 %.1f%%）", sum(explained(1:2))), ...
    "FontWeight","bold");
legend(className, "Location","eastoutside","FontSize",7.5);

nexttile;
hold on; grid on; box on; view(45,22);
for c = 1:numel(classKey)
    idx = labels == classKey(c);
    scatter3(score(idx,1), score(idx,2), score(idx,3), 34, colors(c,:), "filled", ...
        "MarkerFaceAlpha",0.78, "MarkerEdgeColor","w");
end
xlabel("主成分1"); ylabel("主成分2"); zlabel("主成分3");
title(sprintf("（b）三维 PCA 投影（累计方差 %.1f%%）", sum(explained(1:3))), ...
    "FontWeight","bold");

sgtitle("颜色、纹理与池化边缘特征的 PCA 空间可视化", "FontWeight","bold");
saveFig(f, outDir, "图4_PCA特征空间可视化.png");

%% 图5：训练日志曲线
models = unique(string(trainLog.model), "stable");
modelNameCn = ["MLP 展平像素","CNN 局部卷积特征"];
palette = [0.18 0.38 0.86; 0.10 0.45 0.40];

f = figure("Color","w","Name","训练日志曲线","Position",[100 80 1450 650]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
hold on; grid on; box on;
for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);
    plot(trainLog.epoch(rows), trainLog.loss(rows), ...
        "Color", palette(i,:), "LineWidth",1.6);
end
xlabel("训练轮次"); ylabel("训练损失");
title("（a）训练损失曲线","FontWeight","bold");
legend(modelNameCn, "Location","northeast");

nexttile;
hold on; grid on; box on;
for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);
    plot(trainLog.epoch(rows), trainLog.train_accuracy(rows), "--", ...
        "Color", palette(i,:), "LineWidth",1.1);
    plot(trainLog.epoch(rows), trainLog.val_accuracy(rows), "-", ...
        "Color", palette(i,:), "LineWidth",1.8);
end
xlabel("训练轮次"); ylabel("准确率");
ylim([0 1.05]);
title("（b）训练集与验证集准确率","FontWeight","bold");
legend({"MLP 训练集","MLP 验证集","CNN-local 训练集","CNN-local 验证集"}, ...
    "Location","southeast");

sgtitle("基于 training_log.csv 的训练过程诊断图","FontWeight","bold");
saveFig(f, outDir, "图5_训练过程诊断图.png");

%% 图6：指标热力图与混淆矩阵
rawModelNames = string({metrics.models.model});
modelDisplayNames = ["MLP 展平像素","CNN 局部卷积特征"];
A = [[metrics.models.accuracy]' [metrics.models.macro_f1]'];
[~, bestIdx] = max([metrics.models.accuracy]);
C = metrics.models(bestIdx).confusion;

f = figure("Color","w","Name","模型评价热力图","Position",[100 80 1550 760]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
imagesc(A);
colormap(gca, parula);
colorbar;
set(gca,"XTick",1:2,"XTickLabel",["准确率","宏平均 F1"], ...
    "YTick",1:numel(modelDisplayNames),"YTickLabel",modelDisplayNames);
title("（a）模型指标热力图","FontWeight","bold");

for i = 1:size(A,1)
    for j = 1:size(A,2)
        text(j,i,sprintf("%.3f",A(i,j)), ...
            "HorizontalAlignment","center","FontWeight","bold", ...
            "Color",pickTextColor(A(i,j),max(A(:))));
    end
end

nexttile;
imagesc(C);
colormap(gca, parula);
colorbar;
axis square;
set(gca,"XTick",1:numel(className),"XTickLabel",className, ...
    "YTick",1:numel(className),"YTickLabel",className, ...
    "XTickLabelRotation",45);
xlabel("预测类别"); ylabel("真实类别");
title("（b）CNN 局部卷积特征模型混淆矩阵","FontWeight","bold");

for i = 1:size(C,1)
    for j = 1:size(C,2)
        if C(i,j) > 0
            text(j,i,num2str(C(i,j)), ...
                "HorizontalAlignment","center","FontWeight","bold", ...
                "Color",pickTextColor(C(i,j),max(C(:))));
        end
    end
end

sgtitle("基于 metrics.json 的定量评价可视化","FontWeight","bold");
saveFig(f, outDir, "图6_指标热力图与混淆矩阵.png");

disp("全部图片已保存到：");
disp(outDir);

%% ===== 本地函数 =====

function saveFig(figHandle, outDir, fileName)
    outPath = fullfile(outDir, fileName);
    drawnow;

    try
        exportgraphics(figHandle, outPath, "Resolution", 300);
    catch
        print(figHandle, outPath, "-dpng", "-r300");
    end

    fprintf("已保存：%s\n", outPath);
end

function feat = imageFeatureVector(img)
    pixels = reshape(img, [], 3);
    colorMean = mean(pixels, 1);
    colorStd = std(pixels, 0, 1);

    histFeat = [];
    edges = linspace(0, 1, 9);
    for ch = 1:3
        h = histcounts(img(:,:,ch), edges, "Normalization", "probability");
        histFeat = [histFeat h]; %#ok<AGROW>
    end

    gray = mean(img,3);
    sx = [-1 0 1; -2 0 2; -1 0 1];
    sy = sx';
    lap = [0 1 0; 1 -4 1; 0 1 0];

    gx = conv2(gray, sx, "same");
    gy = conv2(gray, sy, "same");
    gl = conv2(gray, lap, "same");

    edgeMag = sqrt(gx.^2 + gy.^2);

    stats = [
        mean(abs(gx(:))) std(gx(:)) max(abs(gx(:))) ...
        mean(abs(gy(:))) std(gy(:)) max(abs(gy(:))) ...
        mean(abs(gl(:))) std(gl(:)) max(abs(gl(:)))
    ];

    pooled = zeros(1,16);
    n = 1;
    for r = 1:4
        for c = 1:4
            block = edgeMag((r-1)*16+1:r*16, (c-1)*16+1:c*16);
            pooled(n) = mean(block(:));
            n = n + 1;
        end
    end

    feat = [colorMean colorStd histFeat stats pooled];
end

function [score, explained] = pcaBySvd(X)
    X = X - mean(X,1);
    [~,S,V] = svd(X, "econ");
    score = X * V;
    latent = diag(S).^2 / max(size(X,1)-1,1);
    explained = latent / sum(latent) * 100;
end

function color = pickTextColor(value, maxValue)
    if maxValue == 0
        color = [0 0 0];
    elseif value / maxValue > 0.55
        color = [1 1 1];
    else
        color = [0 0 0];
    end
end
