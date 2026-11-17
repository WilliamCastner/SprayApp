"""Merge SAM candidates into one clean hold list and render review images.

Inputs : work/candidates*.json (all files are merged), work/manual_holds.json
         (optional hand-drawn polygons), work/reject_points.json (optional
         points; any hold containing one is dropped).
Outputs: work/holds_v2.json   - final polygons, sorted top-left to bottom-right
         work/review_*.jpg    - numbered overlay tiles for visual review
         work/misses.json     - foreground blobs no hold covers
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np

WORK = Path(__file__).parent / "work"
full = cv2.imread(str(WORK / "wall_full.png"))
H, W = full.shape[:2]
lab = cv2.cvtColor(full, cv2.COLOR_BGR2LAB)

cands = []
for f in sorted(WORK.glob("candidates*.json")):
    cands += json.loads(f.read_text())
print("raw candidates", len(cands))

MIN_CON = float(sys.argv[1]) if len(sys.argv) > 1 else 9.0


def bbox(poly):
    p = np.asarray(poly)
    x0, y0 = np.floor(p.min(0)).astype(int)
    x1, y1 = np.ceil(p.max(0)).astype(int)
    return max(0, x0), max(0, y0), min(W, x1 + 1), min(H, y1 + 1)


def raster(poly, bb):
    x0, y0, x1, y1 = bb
    m = np.zeros((y1 - y0, x1 - x0), np.uint8)
    cv2.fillPoly(m, [(np.asarray(poly) - [x0, y0]).round().astype(np.int32)], 1)
    return m


items = []
for c in cands:
    if c["iou"] < 0.78 or c["stab"] < 0.85:
        continue
    if c["con"] < MIN_CON:
        continue
    bb = bbox(c["poly"])
    m = raster(c["poly"], bb)
    a = int(m.sum())
    if a < 300:
        continue
    x0, y0, x1, y1 = bb
    reg = lab[y0:y1, x0:x1][m > 0].astype(np.float32)
    L = reg[:, 0].mean()
    chroma = np.hypot(reg[:, 1] - 128, reg[:, 2] - 128).mean()
    pts = np.asarray(c["poly"], np.float32)
    per = cv2.arcLength(pts.reshape(-1, 1, 2), True)
    circ = 4 * np.pi * a / max(per * per, 1)
    rect = cv2.minAreaRect(pts)
    short, long_ = min(rect[1]), max(rect[1])
    hull_a = max(cv2.contourArea(cv2.convexHull(pts)), 1)
    sol = a / hull_a
    # T-nut holes: small, round, grey (dark hole with a white rim).
    if a < 650 and chroma < 9:
        continue
    # Very thin slivers (stripe edges, cracks between panels).
    if short < 12:
        continue
    # Painted stripes / floor: longer than any hold, or big and touching the photo edge.
    if long_ > 900:
        continue
    touches = x0 <= 2 or y0 <= 2 or x1 >= W - 2 or y1 >= H - 2
    if touches and a > 30_000:
        continue
    # Crescent shadows hugging a hold.
    if sol < 0.55 and a > 3000:
        continue
    q = c["iou"] * c["stab"] + 0.004 * min(c["con"], 40)
    items.append({"poly": c["poly"], "bb": bb, "m": m, "a": a, "q": q, "con": c["con"], "src": c["src"]})

manual = []
mp = WORK / "manual_holds.json"
if mp.exists():
    for poly in json.loads(mp.read_text()):
        bb = bbox(poly)
        m = raster(poly, bb)
        manual.append({"poly": poly, "bb": bb, "m": m, "a": int(m.sum()), "q": 99, "con": 99, "src": "manual"})

# Hand-picked prompt points (curate.py add): take the most specific good mask
# from each and keep it even when it sits on a bigger hold.
forced_items = []
fp = WORK / "forced_points.json"
if fp.exists():
    for fx, fy in json.loads(fp.read_text()):
        best = None
        for c in cands:
            if abs(c["pt"][0] - fx) > 2 or abs(c["pt"][1] - fy) > 2:
                continue
            if c["iou"] < 0.85 or c["stab"] < 0.85 or c["area"] < 300:
                continue
            if best is None or c["area"] < best["area"]:
                best = c
        if best is None:
            print("forced point without a mask:", fx, fy)
            continue
        bb = bbox(best["poly"])
        m = raster(best["poly"], bb)
        forced_items.append({"poly": best["poly"], "bb": bb, "m": m, "a": int(m.sum()), "q": 50,
                             "con": 99, "src": "forced", "forced": True})

fbp = WORK / "forced_big_points.json"
if fbp.exists():
    for fx, fy in json.loads(fbp.read_text()):
        best = None
        for c in cands:
            if abs(c["pt"][0] - fx) > 2 or abs(c["pt"][1] - fy) > 2:
                continue
            if c["iou"] < 0.7 or c["stab"] < 0.85 or c["area"] > 400_000:
                continue
            if best is None or c["area"] > best["area"]:
                best = c
        if best is None:
            print("big point without a mask:", fx, fy)
            continue
        bb = bbox(best["poly"])
        m = raster(best["poly"], bb)
        forced_items.append({"poly": best["poly"], "bb": bb, "m": m, "a": int(m.sum()), "q": 50,
                             "con": 99, "src": "forced_big", "forced": True, "manual": True})

items.sort(key=lambda d: -d["q"])
print("filtered", len(items))


def overlap(a, b):
    ax0, ay0, ax1, ay1 = a["bb"]
    bx0, by0, bx1, by1 = b["bb"]
    x0, y0, x1, y1 = max(ax0, bx0), max(ay0, by0), min(ax1, bx1), min(ay1, by1)
    if x0 >= x1 or y0 >= y1:
        return 0
    ma = a["m"][y0 - ay0:y1 - ay0, x0 - ax0:x1 - ax0]
    mb = b["m"][y0 - by0:y1 - by0, x0 - bx0:x1 - bx0]
    return int((ma & mb).sum())


# Spatial grid for fast neighbour lookups.
CELL = 256
grid = {}


def cells(bb):
    x0, y0, x1, y1 = bb
    for gy in range(y0 // CELL, (y1 - 1) // CELL + 1):
        for gx in range(x0 // CELL, (x1 - 1) // CELL + 1):
            yield (gx, gy)


accepted = []


def neighbours_idx(bb):
    seen = set()
    for c in cells(bb):
        for idx in grid.get(c, []):
            if idx not in seen:
                seen.add(idx)
                yield idx, accepted[idx]


def accept(it):
    accepted.append(it)
    for c in cells(it["bb"]):
        grid.setdefault(c, []).append(len(accepted) - 1)


for it in manual:
    it["manual"] = True
    accept(it)
for it in forced_items:
    accept(it)

def is_volume_pair(big, small):
    return big["a"] > 40_000 and big["a"] > 6 * small["a"] and small["a"] >= 500 and small["con"] > 14


removed = set()
for it in items:
    ok = True
    drop = []
    for k, acc in neighbours_idx(it["bb"]):
        if k in removed:
            continue
        inter = overlap(it, acc)
        if inter == 0:
            continue
        iou = inter / (it["a"] + acc["a"] - inter)
        if iou > 0.45:
            ok = False
            break
        in_acc = inter / it["a"]   # share of the new mask inside the accepted one
        acc_in = inter / acc["a"]  # share of the accepted mask inside the new one
        if acc.get("manual") and acc["a"] > 2.5 * it["a"]:
            continue  # hold on a hand-drawn volume
        if acc.get("forced") and it["a"] > 3 * acc["a"]:
            continue  # parent hold of a hand-picked small hold
        if in_acc > 0.6:
            # New mask is part of an accepted one: keep only a hold on a volume.
            if not is_volume_pair(acc, it):
                ok = False
                break
        elif acc_in > 0.6:
            if is_volume_pair(it, acc):
                continue
            if acc["a"] < 0.2 * it["a"]:
                drop.append(k)  # accepted one was a bolt hole / texture patch
                continue
            ok = False  # new mask merges several holds
            break
        elif in_acc > 0.25:
            if is_volume_pair(acc, it):
                continue  # small hold partly under a volume's outline
            ok = False
            break
    if ok:
        removed.update(drop)
        accept(it)

accepted = [a for k, a in enumerate(accepted) if k not in removed]

# Rejections by polygon (curate.py reject): drop holds matching a rejected shape.
rpp = WORK / "reject_polys.json"
if rpp.exists():
    rej_items = []
    for poly in json.loads(rpp.read_text()):
        bb = bbox(poly)
        rej_items.append({"bb": bb, "m": raster(poly, bb), "a": None})
    for r in rej_items:
        r["a"] = int(r["m"].sum())
    keep = []
    for it in accepted:
        bad = False
        for r in ([] if it.get("forced") or it.get("manual") else rej_items):
            inter = overlap(it, r)
            if inter and inter / (it["a"] + r["a"] - inter) > 0.6:
                bad = True
                break
        if not bad:
            keep.append(it)
    print("rejected by hand", len(accepted) - len(keep))
    accepted = keep

# Rejections by point.
rp = WORK / "reject_points.json"
if rp.exists():
    rej = json.loads(rp.read_text())
    keep = []
    for it in accepted:
        poly = np.asarray(it["poly"], np.float32).reshape(-1, 1, 2)
        if any(cv2.pointPolygonTest(poly, (float(x), float(y)), False) >= 0 for x, y in rej):
            continue
        keep.append(it)
    accepted = keep

print("accepted", len(accepted))


def simplify(poly):
    c = np.asarray(poly, np.float32).reshape(-1, 1, 2)
    per = cv2.arcLength(c, True)
    eps = max(1.2, min(6.0, per * 0.006))
    s = cv2.approxPolyDP(c, eps, True).reshape(-1, 2)
    if len(s) < 3:
        s = cv2.convexHull(c).reshape(-1, 2)
    return s


holds = []
for it in accepted:
    s = simplify(it["poly"])
    m = cv2.moments(s.astype(np.float32))
    cx, cy = (m["m10"] / m["m00"], m["m01"] / m["m00"]) if m["m00"] else s.mean(0)
    holds.append({"poly": s.round().astype(int).tolist(), "cx": float(cx), "cy": float(cy),
                  "area": it["a"], "src": it["src"]})

# Stable order: rows of 200px from top, left to right.
holds.sort(key=lambda h: (int(h["cy"] // 200), h["cx"]))
(WORK / "holds_v2.json").write_text(json.dumps([h["poly"] for h in holds]))
(WORK / "holds_v2_meta.json").write_text(json.dumps(holds))

# ---------- misses: coloured blobs no hold covers ----------
covered = np.zeros((H, W), np.uint8)
for h in holds:
    cv2.fillPoly(covered, [np.asarray(h["poly"], np.int32)], 1)
sm = cv2.resize(full, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
lab8 = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB)
bg = np.dstack([cv2.medianBlur(lab8[:, :, i], 151) for i in range(3)]).astype(np.float32)
d = lab8.astype(np.float32) - bg
chroma_d = np.hypot(d[:, :, 1], d[:, :, 2])
# Coloured things, or much darker than the wall (black holds); shadows are
# only a little darker and keep the wall's hue.
fg = ((chroma_d > 16) | (d[:, :, 0] < -55)).astype(np.uint8)
fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
cov_s = cv2.resize(covered, (fg.shape[1], fg.shape[0]), interpolation=cv2.INTER_NEAREST)
cov_s = cv2.dilate(cov_s, np.ones((9, 9), np.uint8))
unc = fg & (1 - cov_s)
n, lbl, st, ce = cv2.connectedComponentsWithStats(unc)
misses = []
for i in range(1, n):
    x, y, w, h, a = st[i]
    if a < 90 or max(w, h) > 160 or min(w, h) < 7:
        continue
    if a / float(w * h) < 0.35:
        continue
    misses.append([int(ce[i][0] * 2), int(ce[i][1] * 2), int(a * 4), int(x * 2), int(y * 2), int(w * 2), int(h * 2)])
(WORK / "misses.json").write_text(json.dumps(misses))
print("possible misses", len(misses))

# Contact sheet of each possible miss for quick review.
tiles = []
for k, (mx, my, a, x, y, w, hh) in enumerate(misses):
    r = 110
    X0, Y0 = max(0, mx - r), max(0, my - r)
    crop = full[Y0:Y0 + 2 * r, X0:X0 + 2 * r].copy()
    for h in holds:
        p = np.asarray(h["poly"], np.int32) - [X0, Y0]
        cv2.polylines(crop, [p], True, (0, 255, 0), 1)
    cv2.rectangle(crop, (x - X0 - 4, y - Y0 - 4), (x - X0 + w + 4, y - Y0 + hh + 4), (0, 0, 255), 2)
    crop = cv2.copyMakeBorder(crop, 0, 2 * r - crop.shape[0], 0, 2 * r - crop.shape[1], cv2.BORDER_CONSTANT)
    cv2.putText(crop, f"m{k} {mx},{my}", (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 0), 3)
    cv2.putText(crop, f"m{k} {mx},{my}", (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
    tiles.append(crop)
per_sheet = 30
for s_i in range(0, len(tiles), per_sheet):
    chunk = tiles[s_i:s_i + per_sheet]
    while len(chunk) % 6:
        chunk.append(np.zeros_like(tiles[0]))
    rows = [np.hstack(chunk[r:r + 6]) for r in range(0, len(chunk), 6)]
    cv2.imwrite(str(WORK / f"misses_{s_i // per_sheet}.jpg"), np.vstack(rows))

# ---------- review images ----------
vis = full.copy()
rng = np.random.default_rng(1)
for i, h in enumerate(holds):
    col = tuple(int(v) for v in rng.integers(60, 256, 3))
    p = np.asarray(h["poly"], np.int32)
    cv2.polylines(vis, [p], True, (0, 0, 0), 7)
    cv2.polylines(vis, [p], True, col, 3)
for mx, my, a, x, y, w, hh in misses:
    cv2.rectangle(vis, (x - 6, y - 6), (x + w + 6, y + hh + 6), (0, 0, 255), 6)
for i, h in enumerate(holds):
    t = str(i)
    org = (int(h["cx"]) - 10 * len(t), int(h["cy"]) + 10)
    cv2.putText(vis, t, org, cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 0), 5)
    cv2.putText(vis, t, org, cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 255), 2)
cv2.imwrite(str(WORK / "review_full.jpg"), cv2.resize(vis, None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA))
R, C = 4, 4
th, tw = H // R, W // C
for r in range(R):
    for c in range(C):
        y0, x0 = max(0, r * th - 60), max(0, c * tw - 60)
        crop = vis[y0:min(H, (r + 1) * th + 60), x0:min(W, (c + 1) * tw + 60)]
        cv2.imwrite(str(WORK / f"review_{r}{c}.jpg"), cv2.resize(crop, None, fx=0.85, fy=0.85, interpolation=cv2.INTER_AREA))
print("holds", len(holds))
