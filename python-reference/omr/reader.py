"""マークシート画像 → 応答CSV（reader）。

処理: 位置決めマークで天地判定 → 太線枠（ID・解答2列）を検出 →
枠を自己スケールして config の格子から各セル中心を算出 → 塗り率を測って判定。
出力は既存下流互換の 82列スキーマ: source, ID1..IDn, M1..Mq。
"""
import cv2
import numpy as np
import sys
import csv
import glob
import os

from config import CONFIG_2026A, id_block_geometry, answer_block_geometry
from fiducials import detect as detect_fiducials


def _dedup_boxes(rects):
    """入れ子（外周/内周）の重複を大きい方に統合。"""
    rects = sorted(rects, key=lambda r: -r[2] * r[3])
    kept = []
    for (x, y, w, h) in rects:
        cx, cy = x + w / 2, y + h / 2
        dup = False
        for (X, Y, W, H) in kept:
            if X <= cx <= X + W and Y <= cy <= Y + H and abs(w * h - W * H) < 0.15 * W * H:
                dup = True
                break
        if not dup:
            kept.append((x, y, w, h))
    return kept


def find_boxes(gray):
    H, W = gray.shape
    _, b = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV)
    cnts, _ = cv2.findContours(b, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    rects = []
    for c in cnts:
        x, y, w, h = cv2.boundingRect(c)
        if w > 300 and h > 150 and w * h > 60000:
            peri = cv2.arcLength(c, True)
            approx = cv2.approxPolyDP(c, 0.03 * peri, True)
            if len(approx) == 4:
                rects.append((x, y, w, h))
    rects = _dedup_boxes(rects)

    # 分類: 背の高い2枠 = 解答（左右），上部左側の枠 = ID
    tall = sorted([r for r in rects if r[3] > 0.35 * H], key=lambda r: r[0])
    if len(tall) < 2:
        raise RuntimeError(f"解答枠が2つ検出できません（tall={len(tall)}）")
    ans_boxes = tall[:2]
    upper_left = [r for r in rects if r not in ans_boxes
                  and (r[1] + r[3] / 2) < 0.4 * H and (r[0] + r[2] / 2) < 0.5 * W]
    if not upper_left:
        raise RuntimeError("ID枠が検出できません")
    id_box = max(upper_left, key=lambda r: r[2] * r[3])
    return id_box, ans_boxes


def _cell_centers(box, box_local_w, box_local_h, cells, stroke_px=3.0):
    """検出枠(box=x,y,w,h)を自己スケールし，各セルの画素中心を返す。"""
    x, y, w, h = box
    # 検出はストローク外周bbox。中心線は外周から stroke/2 内側。
    ox = x + stroke_px / 2.0
    oy = y + stroke_px / 2.0
    sx = (w - stroke_px) / box_local_w
    sy = (h - stroke_px) / box_local_h
    out = []
    for (idA, opt, xoff, yoff) in cells:
        px = ox + xoff * sx
        py = oy + yoff * sy
        out.append((idA, opt, px, py))
    return out


def _fill_ratio(gray, px, py, rx, ry, dark_thr):
    x0, x1 = int(px - rx), int(px + rx)
    y0, y1 = int(py - ry), int(py + ry)
    patch = gray[max(0, y0):y1, max(0, x0):x1]
    if patch.size == 0:
        return 0.0
    return float(np.mean(patch < dark_thr))


def read_sheet(img, cfg, dpi=200, dark_thr=140, fill_thr=0.20, debug_path=None):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if img.ndim == 3 else img

    # 天地判定（左上が最大マークでなければ180度回転）
    centers, sides = detect_fiducials(img, dpi=dpi)
    if max(sides, key=sides.get) != 'TL':
        gray = cv2.rotate(gray, cv2.ROTATE_180)
        img = cv2.rotate(img, cv2.ROTATE_180)

    id_box, ans_boxes = find_boxes(gray)

    mm = dpi / 25.4
    rx, ry = 1.1 * mm, 0.8 * mm            # サンプリング窓（楕円 2.2x1.6mm の内側）

    vis = img.copy() if img.ndim == 3 else cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    # ---- ID ----
    idg = id_block_geometry(cfg)
    id_cells = _cell_centers(id_box, idg["box_w"], idg["box_h"], idg["cells"])
    id_result = {}
    per_digit = {}
    for (digit, opt, px, py) in id_cells:
        fr = _fill_ratio(gray, px, py, rx, ry, dark_thr)
        per_digit.setdefault(digit, []).append((opt, fr, px, py))
    for digit, lst in per_digit.items():
        opt, fr, px, py = max(lst, key=lambda t: t[1])
        id_result[digit] = opt if fr >= fill_thr else None
        for (o, f, X, Y) in lst:
            col = (0, 0, 255) if (o == opt and f >= fill_thr) else (0, 180, 0)
            cv2.circle(vis, (int(X), int(Y)), 4, col, -1)

    # ---- 解答 ----
    ans_geo = answer_block_geometry(cfg)
    ans_result = {}
    flags = {}
    for box, geo in zip(ans_boxes, ans_geo):
        cells = _cell_centers(box, geo["box_w"], geo["box_h"], geo["cells"])
        per_q = {}
        for (qnum, opt, px, py) in cells:
            fr = _fill_ratio(gray, px, py, rx, ry, dark_thr)
            per_q.setdefault(qnum, []).append((opt, fr, px, py))
        for qnum, lst in per_q.items():
            filled = [(o, f) for (o, f, X, Y) in lst if f >= fill_thr]
            opt, fr, px, py = max(lst, key=lambda t: t[1])
            if len(filled) == 0:
                ans_result[qnum] = None
                flags[qnum] = "blank"
            elif len(filled) > 1:
                ans_result[qnum] = opt          # 最濃を採用
                flags[qnum] = "multi"
            else:
                ans_result[qnum] = opt
            for (o, f, X, Y) in lst:
                col = (0, 0, 255) if (o == opt and f >= fill_thr) else (0, 180, 0)
                cv2.circle(vis, (int(X), int(Y)), 4, col, -1)

    for (x, y, w, h) in [id_box] + ans_boxes:
        cv2.rectangle(vis, (x, y), (x + w, y + h), (255, 0, 0), 2)
    if debug_path:
        cv2.imwrite(debug_path, vis)

    return id_result, ans_result, flags


def main():
    src = sys.argv[1]
    dbg = sys.argv[2] if len(sys.argv) > 2 else None
    cfg = CONFIG_2026A
    im = cv2.imread(src)
    id_r, ans_r, flags = read_sheet(im, cfg, debug_path=dbg)
    ndig = cfg["id"]["n_digits"]
    nq = cfg["answer"]["n_questions"]
    idstr = "".join(str(id_r.get(d, "?")) if id_r.get(d) is not None else "_"
                    for d in range(1, ndig + 1))
    print(f"file: {src}")
    print(f"  学籍番号: {idstr}")
    ansline = " ".join(f"M{q}={ans_r.get(q)}" for q in range(1, nq + 1))
    print("  " + ansline)
    if flags:
        print("  要目視:", {f"M{q}": v for q, v in sorted(flags.items())})


if __name__ == "__main__":
    main()
