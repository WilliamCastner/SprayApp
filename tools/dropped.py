"""High-confidence SAM masks that ended up in no final hold and no rejection."""
import json
from pathlib import Path
import cv2, numpy as np
WORK = Path(__file__).parent / "work"
H, W = 4284, 5712
meta = json.loads((WORK / "holds_v2_meta.json").read_text())
cands = []
for f in sorted(WORK.glob("candidates*.json")):
    cands += json.loads(f.read_text())
lab = np.zeros((H, W), np.int32) - 1
for i, h in sorted(enumerate(meta), key=lambda t: -t[1]["area"]):
    cv2.fillPoly(lab, [np.asarray(h["poly"], np.int32)], i)
rej = np.zeros((H, W), np.uint8)
for p in json.loads((WORK / "reject_polys.json").read_text()):
    cv2.fillPoly(rej, [np.asarray(p, np.int32)], 1)
out = []
for c in cands:
    if not (c["iou"] > 0.92 and c["stab"] > 0.93 and c["con"] > 18 and 500 < c["area"] < 60000):
        continue
    p = np.asarray(c["poly"], np.int32)
    x, y, w, h = cv2.boundingRect(p)
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [p - [x, y]], 1)
    a = m.sum()
    cov = (lab[y:y + h, x:x + w][m > 0] >= 0).mean()
    rj = rej[y:y + h, x:x + w][m > 0].mean()
    if cov < 0.5 and rj < 0.5:
        cx, cy = p.mean(0)
        if all(abs(cx - o[0]) > 25 or abs(cy - o[1]) > 25 for o in out):
            out.append((int(cx), int(cy), int(a), round(c["con"])))
print(len(out))
json.dump(out, open(WORK / "dropped.json", "w"))
full = cv2.imread(str(WORK / "wall_full.png"))
tiles = []
for k, (cx, cy, a, con) in enumerate(out):
    r = 80
    X0, Y0 = max(0, cx - r), max(0, cy - r)
    crop = full[Y0:Y0 + 2 * r, X0:X0 + 2 * r].copy()
    for h in meta:
        if abs(h["cx"] - cx) < 300 and abs(h["cy"] - cy) < 300:
            cv2.polylines(crop, [np.asarray(h["poly"], np.int32) - [X0, Y0]], True, (0, 255, 0), 1)
    cv2.drawMarker(crop, (cx - X0, cy - Y0), (0, 0, 255), cv2.MARKER_CROSS, 14, 2)
    crop = cv2.copyMakeBorder(crop, 0, 2 * r - crop.shape[0], 0, 2 * r - crop.shape[1], cv2.BORDER_CONSTANT)
    cv2.putText(crop, f"d{k}", (3, 14), 0, 0.45, (255, 255, 255), 1)
    tiles.append(cv2.resize(crop, None, fx=1.2, fy=1.2))
for s in range(0, len(tiles), 40):
    ch = tiles[s:s + 40]
    while len(ch) % 8:
        ch.append(np.zeros_like(tiles[0]))
    cv2.imwrite(str(WORK / f"dropped_{s // 40}.jpg"), np.vstack([np.hstack(ch[i:i + 8]) for i in range(0, len(ch), 8)]))
