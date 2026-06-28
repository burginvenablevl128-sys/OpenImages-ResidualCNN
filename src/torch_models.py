from __future__ import annotations

try:
    import torch
    import torch.nn as nn
except ModuleNotFoundError:  # keeps the project importable without torch
    torch = None
    nn = None


if nn is not None:

    class ResidualBlock(nn.Module):
        def __init__(self, in_channels: int, out_channels: int, stride: int = 1):
            super().__init__()
            self.conv1 = nn.Conv2d(in_channels, out_channels, kernel_size=3, stride=stride, padding=1, bias=False)
            self.bn1 = nn.BatchNorm2d(out_channels)
            self.relu = nn.ReLU(inplace=True)
            self.conv2 = nn.Conv2d(out_channels, out_channels, kernel_size=3, padding=1, bias=False)
            self.bn2 = nn.BatchNorm2d(out_channels)
            if stride != 1 or in_channels != out_channels:
                self.shortcut = nn.Sequential(
                    nn.Conv2d(in_channels, out_channels, kernel_size=1, stride=stride, bias=False),
                    nn.BatchNorm2d(out_channels),
                )
            else:
                self.shortcut = nn.Identity()

        def forward(self, x):
            identity = self.shortcut(x)
            out = self.relu(self.bn1(self.conv1(x)))
            out = self.bn2(self.conv2(out))
            out = self.relu(out + identity)
            return out


    class ResidualCNN(nn.Module):
        def __init__(self, num_classes: int):
            super().__init__()
            self.stem = nn.Sequential(
                nn.Conv2d(3, 32, kernel_size=3, padding=1, bias=False),
                nn.BatchNorm2d(32),
                nn.ReLU(inplace=True),
            )
            self.stage1 = ResidualBlock(32, 32)
            self.stage2 = ResidualBlock(32, 64, stride=2)
            self.stage3 = ResidualBlock(64, 128, stride=2)
            self.stage4 = ResidualBlock(128, 256, stride=2)
            self.pool = nn.AdaptiveAvgPool2d((1, 1))
            self.classifier = nn.Linear(256, num_classes)

        def forward(self, x):
            x = self.stem(x)
            x = self.stage1(x)
            x = self.stage2(x)
            x = self.stage3(x)
            x = self.stage4(x)
            x = self.pool(x).flatten(1)
            return self.classifier(x)


    class MLPBaseline(nn.Module):
        def __init__(self, image_size: int, num_classes: int):
            super().__init__()
            input_dim = image_size * image_size * 3
            self.net = nn.Sequential(
                nn.Flatten(),
                nn.Linear(input_dim, 1024),
                nn.ReLU(inplace=True),
                nn.Dropout(0.35),
                nn.Linear(1024, 256),
                nn.ReLU(inplace=True),
                nn.Dropout(0.25),
                nn.Linear(256, num_classes),
            )

        def forward(self, x):
            return self.net(x)


def count_parameters(model) -> int:
    if torch is None:
        return 0
    return sum(p.numel() for p in model.parameters() if p.requires_grad)
