"""List holds that look like shadows: wall-coloured but darker, touching a hold."""
import json, sys
from pathlib import Path
import cv2, numpy as np
WORK = Path(__file__).parent / "work"
full = cv2.imread(str(WORK / "wall_full.png"))
H, W = full.shape[:2]
meta = json.loads((WORK / "holds_v2_meta.json").read_text())
sm = cv2.resize(full, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
lab8 = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB)
bg = np.dstack([cv2.medianBlur(lab8[:, :, i], 75) for i in range(3)]).astype(np.float32)
lab = cv2.cvtColor(full, cv2.COLOR_BGR2LAB).astype(np.float32)
masks = []
out = []
for i, h in enumerate(meta):
    p = np.asarray(h["poly"], np.int32)
    x, y, w, hh = cv2.boundingRect(p)
    m = np.zeros((hh, w), np.uint8)
    cv2.fillPoly(m, [p - [x, y]], 1)
    reg = lab[y:y + hh, x:x + w][m > 0]
    b = bg[min(H // 4 - 1, int(h["cy"] / 4)), min(W // 4 - 1, int(h["cx"] / 4))]
    dL = reg[:, 0].mean() - b[0]
    dc = np.hypot(reg[:, 1].mean() - b[1], reg[:, 2].mean() - b[2])
    tex = reg[:, 0].std()
    if h["area"] < 20000 and dc < 7 and -70 < dL < -6:
        out.append((i, round(float(dL)), round(float(dc), 1), round(float(tex), 1)))
print(len(out))
print(" ".join(str(o[0]) for o in out))
json.dump(out, open(WORK / "shadow_like.json", "w"))
