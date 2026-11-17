"""Contact sheet of chosen holds: python sheet.py out.jpg i1 i2 ... | --smallest N"""
import json, sys
from pathlib import Path
import cv2, numpy as np
WORK = Path(__file__).parent / "work"
full = cv2.imread(str(WORK / "wall_full.png"))
meta = json.loads((WORK / "holds_v2_meta.json").read_text())
out = sys.argv[1]
if sys.argv[2] == "--smallest":
    n = int(sys.argv[3]); off = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    idx = sorted(range(len(meta)), key=lambda i: meta[i]["area"])[off:off + n]
else:
    idx = [int(a) for a in sys.argv[2:]]
r = 70
tiles = []
for i in idx:
    cx, cy = int(meta[i]["cx"]), int(meta[i]["cy"])
    X0, Y0 = max(0, cx - r), max(0, cy - r)
    crop = full[Y0:Y0 + 2 * r, X0:X0 + 2 * r].copy()
    crop = cv2.copyMakeBorder(crop, 0, 2 * r - crop.shape[0], 0, 2 * r - crop.shape[1], cv2.BORDER_CONSTANT)
    crop = cv2.resize(crop, None, fx=1.4, fy=1.4, interpolation=cv2.INTER_CUBIC)
    for j, h in enumerate(meta):
        if abs(h["cx"] - cx) > 3 * r or abs(h["cy"] - cy) > 3 * r:
            continue
        p = ((np.asarray(h["poly"]) - [X0, Y0]) * 1.4).astype(np.int32)
        cv2.polylines(crop, [p], True, (0, 255, 0) if j == i else (255, 200, 0), 2 if j == i else 1)
    t = f"{i} a{meta[i]['area']}"
    cv2.putText(crop, t, (3, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 0), 3)
    cv2.putText(crop, t, (3, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
    tiles.append(crop)
while len(tiles) % 8:
    tiles.append(np.zeros_like(tiles[0]))
cv2.imwrite(str(WORK / out), np.vstack([np.hstack(tiles[k:k + 8]) for k in range(0, len(tiles), 8)]))
print(len(idx))
