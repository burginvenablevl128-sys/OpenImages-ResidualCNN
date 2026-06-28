% generate_academic_figures.m
% Academic MATLAB figures for the Open Images + Residual CNN reproduction project.
% Run from the project root:
%   matlab -batch "run('matlab/generate_academic_figures.m')"

clear; clc; close all;

root = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(root, 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

dataCsv = fullfile(root, 'data', 'processed', 'openimages_pilot_images.csv');
metricsJson = fullfile(root, 'results', 'metrics.json');
trainingCsv = fullfile(root, 'results', 'training_log.csv');

T = readtable(dataCsv, 'TextType', 'string', 'Encoding', 'UTF-8');
trainLog = readtable(trainingCsv, 'TextType', 'string', 'Encoding', 'UTF-8');
metrics = jsondecode(fileread(metricsJson));

classOrder = ["Cat","Dog","Car","Bicycle","Motorcycle","Bird","Horse","Boat","Airplane","Chair","Truck","Flower"];
classOrderZh = ["猫","狗","汽车","自行车","摩托车","鸟","马","船","飞机","椅子","卡车","花"];
colors = academicColors(numel(classOrder));

set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 10);
set(groot, 'defaultLineLineWidth', 1.4);

makeFrameworkFigure(figDir);
makeDatasetMatrixFigure(T, metrics, classOrder, figDir);
makeRgbProfileFigure(T, classOrder, colors, root, figDir);
makePcaFigure(T, classOrder, colors, root, figDir);
makeTrainingFigure(trainLog, figDir);
makeResultHeatmapFigure(metrics, classOrder, figDir);

fprintf('Academic MATLAB figures saved to: %s\n', figDir);

function makeFrameworkFigure(figDir)
    f = figure('Color','w','Units','pixels','Position',[80 80 1700 980]);
    ax = axes(f, 'Position',[0 0 1 1]);
    axis(ax, 'off');
    title(ax, 'Research Framework: From Flattened Pixels to Residual CNN Reproduction', ...
        'FontWeight','bold','FontSize',15);

    nodes = {
        '1. Problem', sprintf('Flattened pixels weaken\\nlocal spatial relations');
        '2. Data Source', sprintf('Open Images V7\\nmetadata + labels + URLs');
        '3. Crawled Subset', sprintf('12 classes, 75 images\\ntraceable license fields');
        '4. Preprocessing', sprintf('RGB conversion, 64x64 resize\\nstratified train/val/test split');
        '5A. MLP Baseline', sprintf('Flatten pixels\\nfully-connected classifier');
        '5B. CNN-local Features', sprintf('Sobel/Laplacian filters\\npooled edge/color statistics');
        '5C. ResidualCNN', sprintf('Conv-BN-ReLU blocks\\nidentity shortcut learning');
        '6. Evaluation', sprintf('Accuracy, Macro-F1, PCA\\ntraining curves, confusion matrix');
        '7. Discussion', sprintf('Convolutional inductive bias\\nsmall-sample boundary + future scaling')
    };

    xy = [
        0.06 0.74 0.19 0.13
        0.29 0.74 0.19 0.13
        0.52 0.74 0.19 0.13
        0.75 0.74 0.19 0.13
        0.06 0.47 0.24 0.15
        0.38 0.47 0.24 0.15
        0.70 0.47 0.24 0.15
        0.27 0.25 0.46 0.13
        0.27 0.08 0.46 0.12
    ];
    fills = [0.96 0.98 1.00; 0.96 1.00 0.98; 1.00 0.98 0.92; 0.98 0.98 0.98; ...
             0.95 0.97 1.00; 0.93 0.99 0.98; 1.00 0.95 0.95; 0.98 0.96 1.00; 0.96 0.96 0.96];
    edge = [0.22 0.30 0.42];

    for i = 1:size(xy,1)
        rectangle(ax, 'Position', xy(i,:), 'Curvature', 0.06, ...
            'FaceColor', fills(i,:), 'EdgeColor', edge, 'LineWidth', 1.2);
        text(xy(i,1)+0.014, xy(i,2)+xy(i,4)-0.032, nodes{i,1}, ...
            'FontWeight','bold','FontSize',10.8, 'Color',[0.08 0.13 0.22], 'Interpreter','none');
        text(xy(i,1)+0.014, xy(i,2)+xy(i,4)-0.065, nodes{i,2}, ...
            'FontSize',9.1, 'Color',[0.24 0.29 0.36], 'Interpreter','none', ...
            'VerticalAlignment','top');
    end

    arrows = [
        0.25 0.805 0.29 0.805
        0.48 0.805 0.52 0.805
        0.71 0.805 0.75 0.805
        0.845 0.74 0.845 0.66
        0.845 0.66 0.18 0.66
        0.18 0.66 0.18 0.62
        0.845 0.66 0.50 0.66
        0.50 0.66 0.50 0.62
        0.845 0.66 0.82 0.66
        0.82 0.66 0.82 0.62
        0.18 0.47 0.40 0.38
        0.50 0.47 0.50 0.38
        0.82 0.47 0.60 0.38
        0.50 0.25 0.50 0.20
    ];
    for k = 1:size(arrows,1)
        annotation(f, 'arrow', arrows(k,[1 3]), arrows(k,[2 4]), ...
            'Color', edge, 'LineWidth', 1.1, 'HeadLength', 8, 'HeadWidth', 8);
    end

    exportgraphics(f, fullfile(figDir, 'matlab_framework_map.png'), 'Resolution', 300);
    close(f);
end

function makeDatasetMatrixFigure(T, metrics, classOrder, figDir)
    labels = string(T.label_en);
    splitNames = strings(height(T),1);
    splitNames(:) = "unused";
    if isfield(metrics, 'splits')
        splitNames(double(metrics.splits.train(:)) + 1) = "Train";
        splitNames(double(metrics.splits.validation(:)) + 1) = "Validation";
        splitNames(double(metrics.splits.test(:)) + 1) = "Test";
    end
    splitOrder = ["Train","Validation","Test"];
    M = zeros(numel(classOrder), numel(splitOrder));
    totalCounts = zeros(numel(classOrder),1);
    for i = 1:numel(classOrder)
        totalCounts(i) = sum(labels == classOrder(i));
        for j = 1:numel(splitOrder)
            M(i,j) = sum(labels == classOrder(i) & splitNames == splitOrder(j));
        end
    end

    f = figure('Color','w','Units','pixels','Position',[80 80 1450 820]);
    tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

    nexttile(1);
    b = bar(totalCounts, 'FaceColor',[0.24 0.49 0.78], 'EdgeColor','none');
    b.FaceAlpha = 0.88;
    grid on; box on;
    set(gca,'XTick',1:numel(classOrder),'XTickLabel',classOrder,'XTickLabelRotation',42);
    ylabel('Number of images');
    title('(a) Pilot subset class distribution','FontWeight','bold');
    ylim([0 max(totalCounts)+2]);
    for i = 1:numel(totalCounts)
        text(i, totalCounts(i)+0.25, num2str(totalCounts(i)), 'HorizontalAlignment','center', 'FontSize',8);
    end

    nexttile(2);
    imagesc(M);
    colormap(gca, academicBlueMap());
    colorbar;
    axis tight;
    set(gca,'XTick',1:numel(splitOrder),'XTickLabel',splitOrder, ...
        'YTick',1:numel(classOrder),'YTickLabel',classOrder);
    title('(b) Stratified split matrix','FontWeight','bold');
    xlabel('Split'); ylabel('Class');
    for i = 1:size(M,1)
        for j = 1:size(M,2)
            text(j, i, num2str(M(i,j)), 'HorizontalAlignment','center', ...
                'Color', chooseTextColor(M(i,j), max(M(:))), 'FontWeight','bold');
        end
    end
    sgtitle('Dataset Statistics from openimages\_pilot\_images.csv', 'FontWeight','bold', 'FontSize', 13);
    exportgraphics(f, fullfile(figDir, 'matlab_dataset_matrix.png'), 'Resolution', 300);
    close(f);
end

function makeRgbProfileFigure(T, classOrder, colors, root, figDir)
    chosen = ["Cat","Car","Bird","Flower"];
    f = figure('Color','w','Units','pixels','Position',[80 80 1400 850]);
    tiledlayout(f,4,1,'TileSpacing','compact','Padding','compact');
    for k = 1:numel(chosen)
        idx = find(string(T.label_en) == chosen(k), 1, 'first');
        img = im2double(imread(fullfile(root, strrep(T.local_path(idx), '/', filesep))));
        if size(img,3) == 1
            img = repmat(img, 1, 1, 3);
        end
        prof = squeeze(mean(img, 1));
        gray = mean(img,3);
        rmsVal = sqrt(mean(gray(:).^2));
        contrastVal = std(gray(:));
        nexttile(k);
        x = 1:size(prof,1);
        plot(x, prof(:,1), 'Color',[0.85 0.20 0.18], 'LineWidth',1.2); hold on;
        plot(x, prof(:,2), 'Color',[0.20 0.62 0.32], 'LineWidth',1.2);
        plot(x, prof(:,3), 'Color',[0.18 0.43 0.75], 'LineWidth',1.2);
        ylim([0 1]); xlim([1 size(prof,1)]);
        grid on; box on;
        ylabel(chosen(k));
        if k == numel(chosen)
            xlabel('Horizontal pixel coordinate');
        else
            set(gca, 'XTickLabel', []);
        end
        text(0.985, 0.82, sprintf('RMS=%.2f  Contrast=%.2f', rmsVal, contrastVal), ...
            'Units','normalized','HorizontalAlignment','right', ...
            'BackgroundColor','w','EdgeColor',[0.55 0.55 0.55], 'Margin',3, 'FontSize',8.5);
        if k == 1
            legend({'R channel','G channel','B channel'}, 'Location','southwest', 'Box','off', 'NumColumns',3);
        end
    end
    sgtitle('V1: Representative RGB Intensity Profiles — Open Images Pilot Subset', ...
        'FontWeight','bold', 'FontSize', 13);
    exportgraphics(f, fullfile(figDir, 'matlab_rgb_profiles.png'), 'Resolution', 300);
    close(f);
end

function makePcaFigure(T, classOrder, colors, root, figDir)
    labels = string(T.label_en);
    X = zeros(height(T), 6 + 24 + 9 + 16);
    for i = 1:height(T)
        img = im2double(imread(fullfile(root, strrep(T.local_path(i), '/', filesep))));
        if size(img,3) == 1
            img = repmat(img, 1, 1, 3);
        end
        X(i,:) = imageFeatureVector(img);
    end
    mu = mean(X,1);
    sigma = std(X,0,1);
    sigma(sigma < 1e-8) = 1;
    Xz = (X - mu) ./ sigma;
    [~,S,V] = svd(Xz, 'econ');
    score = Xz * V;
    latent = diag(S).^2 / max(size(Xz,1)-1,1);
    explained = latent / sum(latent) * 100;

    f = figure('Color','w','Units','pixels','Position',[80 80 1500 750]);
    tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

    nexttile(1);
    hold on; grid on; box on;
    for c = 1:numel(classOrder)
        idx = labels == classOrder(c);
        scatter(score(idx,1), score(idx,2), 32, colors(c,:), 'filled', ...
            'MarkerFaceAlpha',0.78, 'MarkerEdgeColor','w', 'LineWidth',0.35);
    end
    xlabel(sprintf('PC1 (%.1f%%)', explained(1)));
    ylabel(sprintf('PC2 (%.1f%%)', explained(2)));
    title(sprintf('(a) 2D PCA projection (var=%.1f%%)', sum(explained(1:2))), 'FontWeight','bold');
    legend(classOrder, 'Location','eastoutside', 'FontSize',7.5);

    nexttile(2);
    hold on; grid on; box on; view(45,22);
    for c = 1:numel(classOrder)
        idx = labels == classOrder(c);
        scatter3(score(idx,1), score(idx,2), score(idx,3), 34, colors(c,:), 'filled', ...
            'MarkerFaceAlpha',0.78, 'MarkerEdgeColor','w', 'LineWidth',0.35);
    end
    xlabel('PC1'); ylabel('PC2'); zlabel('PC3');
    title(sprintf('(b) 3D PCA projection (var=%.1f%%)', sum(explained(1:3))), 'FontWeight','bold');
    sgtitle('V2: Feature Space Visualization from Color, Texture and Pooled Edge Features', ...
        'FontWeight','bold', 'FontSize', 13);
    exportgraphics(f, fullfile(figDir, 'matlab_pca_feature_space.png'), 'Resolution', 300);
    close(f);
end

function makeTrainingFigure(trainLog, figDir)
    models = unique(string(trainLog.model), 'stable');
    palette = [0.18 0.38 0.86; 0.10 0.45 0.40; 0.85 0.33 0.10];
    f = figure('Color','w','Units','pixels','Position',[80 80 1450 650]);
    tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

    nexttile(1); hold on; grid on; box on;
    for i = 1:numel(models)
        rows = string(trainLog.model) == models(i);
        plot(trainLog.epoch(rows), trainLog.loss(rows), 'Color', palette(i,:), 'LineWidth',1.6);
    end
    xlabel('Epoch'); ylabel('Training loss');
    title('(a) Training loss curves','FontWeight','bold');
    legend(models, 'Interpreter','none', 'Location','northeast');

    nexttile(2); hold on; grid on; box on;
    for i = 1:numel(models)
        rows = string(trainLog.model) == models(i);
        plot(trainLog.epoch(rows), trainLog.train_accuracy(rows), '--', 'Color', palette(i,:), 'LineWidth',1.1);
        plot(trainLog.epoch(rows), trainLog.val_accuracy(rows), '-', 'Color', palette(i,:), 'LineWidth',1.8);
    end
    xlabel('Epoch'); ylabel('Accuracy');
    ylim([0 1.05]);
    title('(b) Train/validation accuracy','FontWeight','bold');
    legend({'MLP train','MLP val','CNN-local train','CNN-local val'}, 'Location','southeast');
    sgtitle('V3: Training Diagnostics from results/training\_log.csv', 'FontWeight','bold', 'FontSize', 13);
    exportgraphics(f, fullfile(figDir, 'matlab_training_diagnostics.png'), 'Resolution', 300);
    close(f);
end

function makeResultHeatmapFigure(metrics, classOrder, figDir)
    modelNames = string({metrics.models.model});
    A = [[metrics.models.accuracy]' [metrics.models.macro_f1]'];
    [~, bestIdx] = max([metrics.models.accuracy]);
    C = metrics.models(bestIdx).confusion;
    if iscell(C)
        C = cell2mat(C);
    end

    f = figure('Color','w','Units','pixels','Position',[80 80 1550 760]);
    tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

    nexttile(1);
    imagesc(A);
    colormap(gca, academicBlueMap());
    colorbar;
    set(gca, 'XTick',1:2, 'XTickLabel',["Accuracy","Macro-F1"], ...
        'YTick',1:numel(modelNames), 'YTickLabel',modelNames);
    caxis([0 max(0.25, max(A(:)))]);
    title('(a) Model metric heatmap','FontWeight','bold');
    for i = 1:size(A,1)
        for j = 1:size(A,2)
            text(j, i, sprintf('%.3f', A(i,j)), 'HorizontalAlignment','center', ...
                'FontWeight','bold', 'Color', chooseTextColor(A(i,j), max(A(:))));
        end
    end

    nexttile(2);
    imagesc(C);
    colormap(gca, academicBlueMap());
    colorbar;
    axis square;
    set(gca, 'XTick',1:numel(classOrder), 'XTickLabel',classOrder, ...
        'YTick',1:numel(classOrder), 'YTickLabel',classOrder, 'XTickLabelRotation',45);
    xlabel('Predicted class'); ylabel('True class');
    title(sprintf('(b) Confusion matrix: %s', modelNames(bestIdx)), 'FontWeight','bold', 'Interpreter','none');
    for i = 1:size(C,1)
        for j = 1:size(C,2)
            if C(i,j) > 0
                text(j, i, num2str(C(i,j)), 'HorizontalAlignment','center', ...
                    'FontWeight','bold', 'Color', chooseTextColor(C(i,j), max(C(:))));
            end
        end
    end
    sgtitle('V4: Quantitative Evaluation from metrics.json', 'FontWeight','bold', 'FontSize', 13);
    exportgraphics(f, fullfile(figDir, 'matlab_result_heatmap_confusion.png'), 'Resolution', 300);
    close(f);
end

function feat = imageFeatureVector(img)
    pixels = reshape(img, [], 3);
    colorMean = mean(pixels, 1);
    colorStd = std(pixels, 0, 1);
    histFeat = [];
    edges = linspace(0, 1, 9);
    for ch = 1:3
        h = histcounts(img(:,:,ch), edges, 'Normalization', 'probability');
        histFeat = [histFeat h]; %#ok<AGROW>
    end
    gray = mean(img, 3);
    sx = [-1 0 1; -2 0 2; -1 0 1];
    sy = sx';
    lap = [0 1 0; 1 -4 1; 0 1 0];
    gx = conv2(gray, sx, 'same');
    gy = conv2(gray, sy, 'same');
    gl = conv2(gray, lap, 'same');
    edgeMag = sqrt(gx.^2 + gy.^2);
    stats = [mean(abs(gx(:))) std(gx(:)) max(abs(gx(:))) ...
             mean(abs(gy(:))) std(gy(:)) max(abs(gy(:))) ...
             mean(abs(gl(:))) std(gl(:)) max(abs(gl(:)))];
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

function C = academicColors(n)
    base = [
        0.20 0.63 0.79
        0.91 0.29 0.24
        0.25 0.70 0.45
        0.95 0.60 0.18
        0.45 0.38 0.78
        0.55 0.55 0.55
        0.12 0.47 0.71
        0.80 0.35 0.62
        0.60 0.45 0.20
        0.30 0.65 0.62
        0.70 0.40 0.90
        0.10 0.55 0.25
    ];
    if n <= size(base,1)
        C = base(1:n,:);
    else
        C = lines(n);
    end
end

function cmap = academicBlueMap()
    x = linspace(0,1,256)';
    c1 = [0.96 0.98 1.00];
    c2 = [0.34 0.56 0.78];
    c3 = [0.06 0.23 0.42];
    cmap = zeros(256,3);
    for i = 1:256
        if x(i) < 0.55
            t = x(i) / 0.55;
            cmap(i,:) = (1-t)*c1 + t*c2;
        else
            t = (x(i)-0.55) / 0.45;
            cmap(i,:) = (1-t)*c2 + t*c3;
        end
    end
end

function color = chooseTextColor(value, maxValue)
    if maxValue == 0
        color = [0.05 0.08 0.12];
    elseif value / maxValue > 0.55
        color = [1 1 1];
    else
        color = [0.05 0.08 0.12];
    end
end
