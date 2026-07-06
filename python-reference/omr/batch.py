"""複数ページのスキャン（PDF or 画像フォルダ）を一括読み取りしてCSV出力。

出力は既存下流互換の82列スキーマ:  source, ID1..IDn, M1..Mq
使い方:
  python batch_read.py 20260724.pdf responses.csv
  python batch_read.py scans_dir/  responses.csv
要目視（ID読取不能・複数塗り・空欄多数）は review.csv に別出し。
"""
import cv2
import sys
import os
import csv
import glob
import subprocess
import tempfile

from config import CONFIG_2026A
from reader import read_sheet


def _pages_from_pdf(pdf, dpi, workdir):
    prefix = os.path.join(workdir, "page")
    subprocess.run(["pdftoppm", "-r", str(dpi), "-png", pdf, prefix], check=True)
    return sorted(glob.glob(prefix + "*.png"))


def _collect_images(src, dpi, workdir):
    if os.path.isdir(src):
        imgs = []
        for ext in ("*.png", "*.jpg", "*.jpeg", "*.tif", "*.tiff"):
            imgs += glob.glob(os.path.join(src, ext))
            imgs += glob.glob(os.path.join(src, ext.upper()))
        return sorted(imgs)
    if src.lower().endswith(".pdf"):
        return _pages_from_pdf(src, dpi, workdir)
    return [src]


def run(src, out_csv, cfg=CONFIG_2026A, dpi=200, review_csv=None):
    ndig = cfg["id"]["n_digits"]
    nq = cfg["answer"]["n_questions"]
    header = ["source"] + [f"ID{i}" for i in range(1, ndig + 1)] + [f"M{i}" for i in range(1, nq + 1)]

    with tempfile.TemporaryDirectory() as wd:
        pages = _collect_images(src, dpi, wd)
        n = len(pages)
        if n == 0:
            raise SystemExit(f"読み取り対象がありません: {src}")
        base = os.path.basename(src)

        rows, reviews = [], []
        for idx, p in enumerate(pages, 1):
            im = cv2.imread(p)
            try:
                id_r, ans_r, flags = read_sheet(im, cfg, dpi=dpi)
            except Exception as e:
                reviews.append({"source": f"{base} [{idx}/{n}]", "problem": f"読取失敗:{e}"})
                rows.append([f"{base} [{idx}/{n}]"] + [""] * (ndig + nq))
                print(f"[{idx}/{n}] ERROR {e}")
                continue

            idcells = [id_r.get(d) for d in range(1, ndig + 1)]
            idstr = "".join(str(x) if x is not None else "_" for x in idcells)
            anscells = [ans_r.get(q) for q in range(1, nq + 1)]

            row = [f"{base} [{idx}/{n}]"]
            row += [("" if x is None else x) for x in idcells]
            row += [("" if x is None else x) for x in anscells]
            rows.append(row)

            n_blank = sum(1 for x in anscells if x is None)
            problems = []
            if any(x is None for x in idcells):
                problems.append("ID不明桁あり")
            multi = [f"M{q}" for q, v in flags.items() if v == "multi"]
            if multi:
                problems.append("複数塗り:" + ",".join(multi))
            if problems:
                reviews.append({"source": f"{base} [{idx}/{n}]", "id": idstr,
                                "problem": " / ".join(problems), "blanks": n_blank})
            print(f"[{idx}/{n}] ID={idstr}  塗り={nq - n_blank}/{nq}"
                  + (f"  ★{'; '.join(problems)}" if problems else ""))

    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"\n書き出し: {out_csv}  ({len(rows)}枚)")

    if review_csv is None:
        review_csv = os.path.splitext(out_csv)[0] + "_review.csv"
    if reviews:
        keys = ["source", "id", "problem", "blanks"]
        with open(review_csv, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=keys)
            w.writeheader()
            for r in reviews:
                w.writerow({k: r.get(k, "") for k in keys})
        print(f"要目視: {review_csv}  ({len(reviews)}枚)")
    else:
        print("要目視: なし")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: python batch_read.py <pdf|dir|image> <out.csv>")
        raise SystemExit(1)
    run(sys.argv[1], sys.argv[2])
