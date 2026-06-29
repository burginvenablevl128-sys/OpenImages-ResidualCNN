%% 图4：PCA 特征空间二维与三维投影
clear; clc; close all;

projectRoot = pwd;

outDir = fullfile(projectRoot, "figures_matlab");
if ~exist(outDir, "dir")
    mkdir(outDir);
end

%% 读取 CSV
dataCsv = fullfile(projectRoot, "openimages_pilot_images.csv");

if ~exist(dataCsv, "file")
    dataCsv = fullfile(projectRoot, "data", "processed", "openimages_pilot_images.csv");
end

if ~exist(dataCsv, "file")
    error("找不到 openimages_pilot_images.csv，请把它放在当前文件夹，或 data/processed 文件夹中。");
end

T = readtable(dataCsv, "TextType", "string", "Encoding", "UTF-8");

%% 类别名称
classEn = ["Cat","Dog","Car","Bicycle","Motorcycle","Bird", ...
           "Horse","Boat","Airplane","Chair","Truck","Flower"];

classZh = ["猫","狗","汽车","自行车","摩托车","鸟", ...
           "马","船","飞机","椅子","卡车","花"];

vars = string(T.Properties.VariableNames);

if any(vars == "label_en")
    labels = string(T.label_en);
    classKey = classEn;
    className = classZh;
elseif any(vars == "label_id")
    labels = lower(string(T.label_id));
    classKey = lower(classEn);
    className = classZh;
elseif any(vars == "label_zh")
    labels = string(T.label_zh);
    classKey = classZh;
    className = classZh;
else
    error("CSV 中没有 label_en、label_id 或 label_zh 列。");
end

colors = lines(numel(classKey));

set(groot, "defaultAxesFontName", "Microsoft YaHei");
set(groot, "defaultTextFontName", "Microsoft YaHei");
set(groot, "defaultAxesFontSize", 10);

%% 提取图像特征
X = zeros(height(T), 55);
valid = false(height(T), 1);

for i = 1:height(T)
    imgPath = getImagePath(projectRoot, T, i);

    if imgPath == ""
        fprintf("跳过第 %d 行：找不到图片。\n", i);
        continue;
    end

    img = im2double(imread(imgPath));

    if size(img, 3) == 1
        img = repmat(img, 1, 1, 3);
    end

    img = imresize(img, [64 64]);

    X(i, :) = imageFeatureVector(img);
    valid(i) = true;
end

X = X(valid, :);
labels = labels(valid);

if isempty(X)
    error("没有成功读取任何图片。请确认图片文件夹存在。");
end

%% PCA
mu = mean(X, 1);
sigma = std(X, 0, 1);
sigma(sigma == 0) = 1;
Xz = (X - mu) ./ sigma;

[score, explained] = pcaBySvd(Xz);

%% 绘图
f = figure("Color", "w", ...
    "Name", "PCA特征空间可视化", ...
    "Position", [100 80 1500 720]);

tiledlayout(f, 1, 2, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

%% （a）二维 PCA 投影
nexttile;
hold on; grid on; box on;

for c = 1:numel(classKey)
    idx = labels == classKey(c);

    if any(idx)
        scatter(score(idx,1), score(idx,2), ...
            32, colors(c,:), "filled", ...
            "MarkerEdgeColor", "w");
    end
end

xlabel(sprintf("主成分1（%.1f%%）", explained(1)));
ylabel(sprintf("主成分2（%.1f%%）", explained(2)));

title(sprintf("（a）二维 PCA 投影（累计方差 %.1f%%）", ...
    sum(explained(1:2))), ...
    "FontWeight", "bold");

legend(className, ...
    "Location", "eastoutside", ...
    "FontSize", 7.5);

%% （b）三维 PCA 投影
nexttile;
hold on; grid on; box on;
view(45, 22);

for c = 1:numel(classKey)
    idx = labels == classKey(c);

    if any(idx)
        scatter3(score(idx,1), score(idx,2), score(idx,3), ...
            34, colors(c,:), "filled", ...
            "MarkerEdgeColor", "w");
    end
end

xlabel("主成分1");
ylabel("主成分2");
zlabel("主成分3");

title(sprintf("（b）三维 PCA 投影（累计方差 %.1f%%）", ...
    sum(explained(1:3))), ...
    "FontWeight", "bold");

sgtitle("颜色、纹理与池化边缘特征的 PCA 空间可视化", ...
    "FontWeight", "bold");

outPath = fullfile(outDir, "图4_PCA特征空间可视化.png");
print(f, outPath, "-dpng", "-r300");

fprintf("已保存：%s\n", outPath);

%% ===== 辅助函数 =====

function imgPath = getImagePath(projectRoot, T, rowIndex)
    imgPath = "";

    vars = string(T.Properties.VariableNames);

    if any(vars == "local_path")
        rawPath = string(T.local_path(rowIndex));
    elseif any(vars == "image_path")
        rawPath = string(T.image_path(rowIndex));
    else
        error("CSV 中没有 local_path 或 image_path 列。");
    end

    p = char(rawPath);
    p = strrep(p, "/", filesep);
    p = strrep(p, "\", filesep);

    % 1. 按 CSV 中的相对路径查找
    candidate = fullfile(projectRoot, p);
    if exist(candidate, "file")
        imgPath = string(candidate);
        return;
    end

    % 2. 如果 CSV 是 data/images/...，但当前目录只有 images/...
    p2 = erase(string(p), "data" + filesep);
    candidate = fullfile(projectRoot, p2);
    if exist(candidate, "file")
        imgPath = string(candidate);
        return;
    end

    % 3. 在当前目录下递归搜索同名图片
    [~, name, ext] = fileparts(p);
    targetName = name + ext;

    files = dir(fullfile(projectRoot, "**", char(targetName)));
    if ~isempty(files)
        imgPath = string(fullfile(files(1).folder, files(1).name));
        return;
    end

    % 4. 如果还找不到，让用户手动选择 images 文件夹
    persistent imageRoot

    if isempty(imageRoot) || ~exist(imageRoot, "dir")
        imageRoot = uigetdir(projectRoot, "请选择 images 文件夹，例如 data/images");
        if isequal(imageRoot, 0)
            return;
        end
    end

    parts = split(string(p), filesep);
    idx = find(parts == "images", 1);

    if ~isempty(idx) && idx < numel(parts)
        relParts = parts(idx+1:end);
        candidate = imageRoot;
        for k = 1:numel(relParts)
            candidate = fullfile(candidate, relParts(k));
        end
    else
        candidate = fullfile(imageRoot, targetName);
    end

    if exist(candidate, "file")
        imgPath = string(candidate);
        return;
    end
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

    gray = mean(img, 3);

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

    pooled = zeros(1, 16);
    n = 1;

    for r = 1:4
        for c = 1:4
            block = edgeMag((r-1)*16+1:r*16, ...
                            (c-1)*16+1:c*16);
            pooled(n) = mean(block(:));
            n = n + 1;
        end
    end

    feat = [colorMean colorStd histFeat stats pooled];
end

function [score, explained] = pcaBySvd(X)
    X = X - mean(X, 1);

    [~, S, V] = svd(X, "econ");

    score = X * V;
    latent = diag(S).^2 / max(size(X,1)-1, 1);
    explained = latent / sum(latent) * 100;
end