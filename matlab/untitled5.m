clear; clc;

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

classOrder = ["Cat","Dog","Car","Bicycle","Motorcycle","Bird","Horse","Boat","Airplane","Chair","Truck","Flower"];
colors = lines(numel(classOrder));

set(groot, "defaultAxesFontName", "Times New Roman");
set(groot, "defaultTextFontName", "Times New Roman");
set(groot, "defaultAxesFontSize", 10);
set(groot, "defaultLineLineWidth", 1.4);

%% 图1：论文整体框架图
f = figure("Color","w","Name","Framework Map","Position",[100 80 1400 780]);
ax = axes(f, "Position",[0 0 1 1]);
axis(ax, "off");

title(ax, "Research Framework: From Flattened Pixels to Residual CNN Reproduction", ...
    "FontWeight","bold","FontSize",15);

nodes = {
    "1. Problem", "Flattened pixels weaken local spatial relations";
    "2. Open Images V7", "Official metadata, image-level labels and image URLs";
    "3. Crawled Subset", "12 classes, 75 images, traceable license fields";
    "4. Preprocessing", "RGB conversion, 64x64 resize, stratified split";
    "5A. MLP Baseline", "Flatten pixels + fully-connected classifier";
    "5B. CNN-local Features", "Sobel/Laplacian filters + pooled statistics";
    "5C. ResidualCNN", "Conv-BN-ReLU blocks + residual shortcuts";
    "6. Evaluation", "Accuracy, Macro-F1, PCA, curves, confusion matrix";
    "7. Discussion", "Convolutional bias, small-sample boundary, scaling"
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

saveFig(f, outDir, "matlab_framework_map.png");

%% 图2：数据集类别分布 + 划分矩阵
labels = string(T.label_en);

splitNames = strings(height(T),1);
splitNames(:) = "Unused";
splitNames(double(metrics.splits.train(:)) + 1) = "Train";
splitNames(double(metrics.splits.validation(:)) + 1) = "Validation";
splitNames(double(metrics.splits.test(:)) + 1) = "Test";

splitOrder = ["Train","Validation","Test"];
M = zeros(numel(classOrder), numel(splitOrder));
totalCounts = zeros(numel(classOrder),1);

for i = 1:numel(classOrder)
    totalCounts(i) = sum(labels == classOrder(i));
    for j = 1:numel(splitOrder)
        M(i,j) = sum(labels == classOrder(i) & splitNames == splitOrder(j));
    end
end

f = figure("Color","w","Name","Dataset Matrix","Position",[100 80 1450 760]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
bar(totalCounts, "FaceColor",[0.25 0.49 0.78], "EdgeColor","none");
grid on; box on;
set(gca,"XTick",1:numel(classOrder),"XTickLabel",classOrder,"XTickLabelRotation",42);
ylabel("Number of images");
title("(a) Pilot subset class distribution","FontWeight","bold");
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
    "YTick",1:numel(classOrder),"YTickLabel",classOrder);
xlabel("Split"); ylabel("Class");
title("(b) Stratified split matrix","FontWeight","bold");

for i = 1:size(M,1)
    for j = 1:size(M,2)
        text(j, i, num2str(M(i,j)), "HorizontalAlignment","center", ...
            "FontWeight","bold", "Color", pickTextColor(M(i,j), max(M(:))));
    end
end

sgtitle("Dataset Statistics from openimages_pilot_images.csv","FontWeight","bold");
saveFig(f, outDir, "matlab_dataset_matrix.png");

%% 图3：RGB 强度剖面图
chosen = ["Cat","Car","Bird","Flower"];

f = figure("Color","w","Name","RGB Profiles","Position",[100 80 1500 850]);
tiledlayout(f,4,1,"TileSpacing","compact","Padding","compact");

for k = 1:numel(chosen)
    idx = find(labels == chosen(k), 1, "first");
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
    ylabel(chosen(k));

    if k == numel(chosen)
        xlabel("Horizontal pixel coordinate");
    else
        set(gca,"XTickLabel",[]);
    end

    text(0.985,0.82,sprintf("RMS=%.2f  Contrast=%.2f",rmsVal,contrastVal), ...
        "Units","normalized","HorizontalAlignment","right", ...
        "BackgroundColor","w","EdgeColor",[0.55 0.55 0.55],"Margin",3,"FontSize",8.5);

    if k == 1
        legend({"R channel","G channel","B channel"}, ...
            "Location","southwest","Box","off","NumColumns",3);
    end
end

sgtitle("Representative RGB Intensity Profiles — Open Images Pilot Subset", ...
    "FontWeight","bold");
saveFig(f, outDir, "matlab_rgb_profiles.png");

%% 图4：PCA 2D / 3D 特征空间
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
[~, score, latent] = pca(Xz);
explained = latent / sum(latent) * 100;

f = figure("Color","w","Name","PCA Feature Space","Position",[100 80 1500 720]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
hold on; grid on; box on;
for c = 1:numel(classOrder)
    idx = labels == classOrder(c);
    scatter(score(idx,1), score(idx,2), 32, colors(c,:), "filled", ...
        "MarkerFaceAlpha",0.78, "MarkerEdgeColor","w");
end
xlabel(sprintf("PC1 (%.1f%%)", explained(1)));
ylabel(sprintf("PC2 (%.1f%%)", explained(2)));
title(sprintf("(a) 2D PCA projection (var=%.1f%%)", sum(explained(1:2))), ...
    "FontWeight","bold");
legend(classOrder, "Location","eastoutside","FontSize",7.5);

nexttile;
hold on; grid on; box on; view(45,22);
for c = 1:numel(classOrder)
    idx = labels == classOrder(c);
    scatter3(score(idx,1), score(idx,2), score(idx,3), 34, colors(c,:), "filled", ...
        "MarkerFaceAlpha",0.78, "MarkerEdgeColor","w");
end
xlabel("PC1"); ylabel("PC2"); zlabel("PC3");
title(sprintf("(b) 3D PCA projection (var=%.1f%%)", sum(explained(1:3))), ...
    "FontWeight","bold");

sgtitle("Feature Space Visualization from Color, Texture and Pooled Edge Features", ...
    "FontWeight","bold");
saveFig(f, outDir, "matlab_pca_feature_space.png");

%% 图5：训练日志曲线
models = unique(string(trainLog.model), "stable");
palette = [0.18 0.38 0.86; 0.10 0.45 0.40];

f = figure("Color","w","Name","Training Diagnostics","Position",[100 80 1450 650]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
hold on; grid on; box on;
for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);
    plot(trainLog.epoch(rows), trainLog.loss(rows), ...
        "Color", palette(i,:), "LineWidth",1.6);
end
xlabel("Epoch"); ylabel("Training loss");
title("(a) Training loss curves","FontWeight","bold");
legend(models, "Interpreter","none", "Location","northeast");

nexttile;
hold on; grid on; box on;
for i = 1:numel(models)
    rows = string(trainLog.model) == models(i);
    plot(trainLog.epoch(rows), trainLog.train_accuracy(rows), "--", ...
        "Color", palette(i,:), "LineWidth",1.1);
    plot(trainLog.epoch(rows), trainLog.val_accuracy(rows), "-", ...
        "Color", palette(i,:), "LineWidth",1.8);
end
xlabel("Epoch"); ylabel("Accuracy");
ylim([0 1.05]);
title("(b) Train/validation accuracy","FontWeight","bold");
legend({"MLP train","MLP val","CNN-local train","CNN-local val"}, ...
    "Location","southeast");

sgtitle("Training Diagnostics from results/training_log.csv","FontWeight","bold");
saveFig(f, outDir, "matlab_training_diagnostics.png");

%% 图6：指标热力图 + 混淆矩阵
modelNames = string({metrics.models.model});
A = [[metrics.models.accuracy]' [metrics.models.macro_f1]'];
[~, bestIdx] = max([metrics.models.accuracy]);
C = metrics.models(bestIdx).confusion;

f = figure("Color","w","Name","Evaluation Heatmap","Position",[100 80 1550 760]);
tiledlayout(f,1,2,"TileSpacing","compact","Padding","compact");

nexttile;
imagesc(A);
colormap(gca, parula);
colorbar;
set(gca,"XTick",1:2,"XTickLabel",["Accuracy","Macro-F1"], ...
    "YTick",1:numel(modelNames),"YTickLabel",modelNames);
title("(a) Model metric heatmap","FontWeight","bold");

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
set(gca,"XTick",1:numel(classOrder),"XTickLabel",classOrder, ...
    "YTick",1:numel(classOrder),"YTickLabel",classOrder, ...
    "XTickLabelRotation",45);
xlabel("Predicted class"); ylabel("True class");
title("(b) Confusion matrix: CNN-local features","FontWeight","bold");

for i = 1:size(C,1)
    for j = 1:size(C,2)
        if C(i,j) > 0
            text(j,i,num2str(C(i,j)), ...
                "HorizontalAlignment","center","FontWeight","bold", ...
                "Color",pickTextColor(C(i,j),max(C(:))));
        end
    end
end

sgtitle("Quantitative Evaluation from metrics.json","FontWeight","bold");
saveFig(f, outDir, "matlab_result_heatmap_confusion.png");

disp("全部图片已保存到：");
disp(outDir);

%% ===== local functions =====

function saveFig(figHandle, outDir, fileName)
    outPath = fullfile(outDir, fileName);
    drawnow;

    try
        exportgraphics(figHandle, outPath, "Resolution", 300);
    catch
        print(figHandle, outPath, "-dpng", "-r300");
    end

    fprintf("Saved: %s\n", outPath);
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

function color = pickTextColor(value, maxValue)
    if maxValue == 0
        color = [0 0 0];
    elseif value / maxValue > 0.55
        color = [1 1 1];
    else
        color = [0 0 0];
    end
end
