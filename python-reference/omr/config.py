"""マークシートのレイアウト定義（single source of truth）。

このファイル1つから (1) marksheet.tex の格子と (2) reader のセル座標が決まる。
年度で変わるのは主に n_questions と col_split，n_id_digits。
座標は TikZ content フレームの「ローカル単位」（1単位 = 0.98mm，ただし
reader は枠を検出して自己スケールするので絶対mmは不要）。
"""

CONFIG_2026A = {
    "name": "2026a",
    "n_options": 10,
    "option_labels": [1, 2, 3, 4, 5, 6, 7, 8, 9, 0],  # 列1..10 に対応（10列目が「0」）

    # ---- 学籍番号ブロック ----
    "id": {
        "n_digits": 6,
        "idtop": -53.0, "idleft": 5.0, "idcolwidth": 7.5, "idrowheight": 5.3,
    },

    # ---- 解答ブロック ----
    "answer": {
        "n_questions": 75,
        "col_split": [(1, 38), (39, 75)],   # (qstart, qend) を列ごとに
        "anstop": -100.0, "optwidth": 7.0, "labeloffset": 10.0,
        "ansrowheight": 4.3, "colgap": 2.5, "colwidth": 83.5,
    },
}


def id_block_geometry(cfg):
    """ID枠のローカル矩形と各セルを返す。
    return: dict(box_w, box_h, cells=[(digit, opt_value, xoff, yoff), ...])
    xoff/yoff は枠の左上（ローカル）からの右方向/下方向オフセット（ローカル単位）。
    """
    g = cfg["id"]
    idtop, idleft, cw, rh = g["idtop"], g["idleft"], g["idcolwidth"], g["idrowheight"]
    n_opt = cfg["n_options"]
    labels = cfg["option_labels"]
    # 枠: (idleft-5, idtop+7) 〜 (idleft+10.5*cw, idtop-n_digits*rh+2)
    box_left = idleft - 5.0
    box_top = idtop + 7.0
    box_w = (idleft + 10.5 * cw) - box_left
    box_h = box_top - (idtop - g["n_digits"] * rh + 2.0)
    cells = []
    for digit in range(1, g["n_digits"] + 1):
        ypos = idtop - (digit - 1) * rh
        yoff = box_top - ypos
        for col in range(1, n_opt + 1):
            xpos = idleft + col * cw
            xoff = xpos - box_left
            cells.append((digit, labels[col - 1], xoff, yoff))
    return {"box_w": box_w, "box_h": box_h, "cells": cells}


def answer_block_geometry(cfg):
    """解答枠（列ごと）のローカル矩形と各セルを返す。
    return: list（列ごと） of dict(qstart,qend,box_w,box_h,cells=[(qnum,opt_value,xoff,yoff)])
    """
    g = cfg["answer"]
    anstop, optw, labo = g["anstop"], g["optwidth"], g["labeloffset"]
    rh, colgap, colw = g["ansrowheight"], g["colgap"], g["colwidth"]
    n_opt = cfg["n_options"]
    labels = cfg["option_labels"]
    out = []
    for colindex, (qstart, qend) in enumerate(g["col_split"]):
        colstart = 5.0 + colindex * (colw + colgap)
        nrows = qend - qstart + 1
        box_left = colstart
        box_top = anstop + 6.0
        box_w = labo + 10.5 * optw
        box_h = box_top - (anstop - nrows * rh + 2.0)
        cells = []
        for i in range(1, nrows + 1):
            qnum = qstart + i - 1
            ypos = anstop - (i - 1) * rh
            yoff = box_top - ypos
            for col in range(1, n_opt + 1):
                xpos = labo + col * optw          # colstart 基準
                xoff = (colstart + xpos) - box_left
                cells.append((qnum, labels[col - 1], xoff, yoff))
        out.append({"qstart": qstart, "qend": qend, "nrows": nrows,
                    "box_w": box_w, "box_h": box_h, "cells": cells})
    return out
