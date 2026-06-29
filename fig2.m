clear; clc; close all;

% 分层划分
classes = {'狗','汽车','摩托车','花','自行车','船','房子','鸟','椅子','卡车','马','飞机'};
splitNames = {'训练集','验证集','测试集'};

splitMat = [
    5 1 1;
    4 1 1;
    6 1 1;
    4 1 1;
    4 1 1;
    5 1 1;
    4 1 0;
    4 1 0;
    4 1 1;
    4 1 1;
    4 1 1;
    5 1 1
];

% 汇总
splitTotals = sum(splitMat, 1);
totalImages = sum(splitTotals);
splitPercent = splitTotals / totalImages * 100;

figure('Color','w','Position',[100 100 1100 520]);

sgtitle('Open Images Pilot 子集划分统计', ...
    'FontName','Microsoft YaHei', ...
    'FontSize',13, ...
    'FontWeight','bold');

% (a) 

subplot(1,2,1);

pieLabels = cell(1, numel(splitNames));
for i = 1:numel(splitNames)
    pieLabels{i} = sprintf('%s\n%d 张 / %.1f%%', ...
        splitNames{i}, splitTotals(i), splitPercent(i));
end

p = pie(splitTotals, pieLabels);


pieColors = [
    0.20 0.55 0.85;   % 训练集
    0.95 0.65 0.20;   % 验证集
    0.35 0.70 0.45    % 测试集
];

patchIdx = find(arrayfun(@(h) isa(h,'matlab.graphics.primitive.Patch'), p));
for i = 1:numel(patchIdx)
    p(patchIdx(i)).FaceColor = pieColors(i,:);
end

title('(a) 数据划分总体占比', ...
    'FontName','Microsoft YaHei', ...
    'FontWeight','bold');

set(gca, 'FontName','Microsoft YaHei', 'FontSize',10);
axis equal;


text(0, 0, sprintf('总计\n%d 张', totalImages), ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', ...
    'FontName','Microsoft YaHei', ...
    'FontSize',12, ...
    'FontWeight','bold');

% (b) 

subplot(1,2,2);

imagesc(splitMat);
colormap(parula);
caxis([0 6]);
cb = colorbar;
cb.Label.String = '图像数量';
cb.Label.FontName = 'Microsoft YaHei';

title('(b) 分层划分矩阵', ...
    'FontName','Microsoft YaHei', ...
    'FontWeight','bold');

xlabel('数据划分', 'FontName','Microsoft YaHei');
ylabel('类别', 'FontName','Microsoft YaHei');

set(gca, ...
    'XTick',1:numel(splitNames), ...
    'XTickLabel',splitNames, ...
    'YTick',1:numel(classes), ...
    'YTickLabel',classes, ...
    'FontName','Microsoft YaHei', ...
    'FontSize',9);

box on;


for r = 1:size(splitMat,1)
    for c = 1:size(splitMat,2)
        val = splitMat(r,c);

        if val >= 4
            txtColor = 'w';
        else
            txtColor = 'k';
        end

        text(c, r, num2str(val), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontWeight','bold', ...
            'FontSize',9, ...
            'Color',txtColor, ...
            'FontName','Microsoft YaHei');
    end
end