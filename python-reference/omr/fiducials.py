"""四隅の位置決めマーク（黒塗り四角）を検出するモジュール。

マークシートは四隅に黒い四角を持ち，左上だけ大きい（向き判定用）。
Otsu二値化 → 輪郭抽出 → 四隅近傍の充填された正方形を選ぶ。
戻り値: {'TL':(x,y), 'TR':..., 'BL':..., 'BR':...} 画素座標（検出できた向きに正規化済み）。
"""
import cv2
import numpy as np
import sys


def _find_square_blobs(bin_img, min_side, max_side):
    """充填された正方形状の連結成分の (cx, cy, area, side) を返す。"""
    cnts, _ = cv2.findContours(bin_img, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    blobs = []
    for c in cnts:
        area = cv2.contourArea(c)
        if area < min_side * min_side * 0.5:
            continue
        x, y, w, h = cv2.boundingRect(c)
        if not (min_side <= w <= max_side and min_side <= h <= max_side):
            continue
        aspect = w / float(h)
        if not (0.7 <= aspect <= 1.4):
            continue
        extent = area / float(w * h)          # 充填率（塗り潰し四角なら高い）
        if extent < 0.75:
            continue
        blobs.append((x + w / 2.0, y + h / 2.0, area, (w + h) / 2.0))
    return blobs


def detect(img, dpi=200, debug_path=None):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if img.ndim == 3 else img
    H, W = gray.shape
    _, bin_img = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

    mm = dpi / 25.4                            # px per mm
    # 位置決めマークは年度でサイズが異なる（2026:9-12.8mm / 2025:5.5mm程度）ので下限を緩める
    blobs = _find_square_blobs(bin_img, min_side=4 * mm, max_side=18 * mm)
    if len(blobs) < 4:
        raise RuntimeError(f"位置決めマークが4個検出できません（{len(blobs)}個）")

    # 四隅それぞれに最も近いブロブを割り当てる
    corners_ref = {'TL': (0, 0), 'TR': (W, 0), 'BL': (0, H), 'BR': (W, H)}
    chosen = {}
    for name, (rx, ry) in corners_ref.items():
        best = min(blobs, key=lambda b: (b[0] - rx) ** 2 + (b[1] - ry) ** 2)
        chosen[name] = best

    if debug_path is not None:
        vis = img.copy() if img.ndim == 3 else cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        for name, (cx, cy, area, side) in chosen.items():
            cv2.circle(vis, (int(cx), int(cy)), 12, (0, 0, 255), 3)
            cv2.putText(vis, name, (int(cx) - 20, int(cy) - 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
        cv2.imwrite(debug_path, vis)

    sides = {k: v[3] for k, v in chosen.items()}
    centers = {k: (v[0], v[1]) for k, v in chosen.items()}
    return centers, sides


if __name__ == "__main__":
    path = sys.argv[1]
    dbg = sys.argv[2] if len(sys.argv) > 2 else None
    im = cv2.imread(path)
    print(f"image: {path}  shape={im.shape}")
    centers, sides = detect(im, debug_path=dbg)
    for k in ['TL', 'TR', 'BL', 'BR']:
        print(f"  {k}: center=({centers[k][0]:.1f},{centers[k][1]:.1f})  side={sides[k]:.1f}px")
    big = max(sides, key=sides.get)
    print(f"  最大マーク = {big}（左上=TL であれば天地正常）")
