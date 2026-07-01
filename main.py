from __future__ import annotations

import argparse

from src.config import PILOT_PER_CLASS, ensure_dirs
from src.numpy_experiment import run_numpy_experiment
from src.openimages_crawler import build_pilot_dataset, download_metadata
from src.report_builder import build_report
from src.visualization import generate_all_figures


def main() -> None:
    parser = argparse.ArgumentParser(description="Open Images Residual CNN reproduction project")
    parser.add_argument("--all", action="store_true", help="Run metadata download, pilot crawling, NumPy experiment, figures and report")
    parser.add_argument("--metadata", action="store_true", help="Download Open Images official metadata files")
    parser.add_argument("--crawl", action="store_true", help="Build pilot Open Images subset")
    parser.add_argument("--experiment", action="store_true", help="Run NumPy quick experiment")
    parser.add_argument("--figures", action="store_true", help="Generate paper figures")
    parser.add_argument("--report", action="store_true", help="Generate the Word paper from current results and figures")
    parser.add_argument("--per-class", type=int, default=PILOT_PER_CLASS, help="Pilot images to download per class")
    args = parser.parse_args()

    ensure_dirs()
    if args.all or args.metadata:
        download_metadata()
    if args.all or args.crawl:
        build_pilot_dataset(per_class=args.per_class)
    if args.all or args.experiment:
        run_numpy_experiment()
    if args.all or args.figures:
        generate_all_figures()
    if args.all or args.report:
        build_report()


if __name__ == "__main__":
    main()
