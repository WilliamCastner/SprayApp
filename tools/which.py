"""python which.py x,y ...  -> index of the hold containing each point (or nearest)"""
import json, sys
from pathlib import Path
import cv2, numpy as np
meta = json.loads((Path(__file__).parent / "work/holds_v2_meta.json").read_text())
for a in sys.argv[1:]:
    x, y = map(float, a.split(","))
    best = None
    for i, h in enumerate(meta):
        d = cv2.pointPolygonTest(np.asarray(h["poly"], np.float32).reshape(-1, 1, 2), (x, y), True)
        # smallest containing hold wins (same rule as the app); else nearest edge
        key = (0, h["area"]) if d >= 0 else (1, -d)
        if best is None or key < best[2]:
            best = (i, d, key)
    print(a, "->", best[0], "inside" if best[1] >= 0 else f"nearest, {-best[1]:.0f}px away", meta[best[0]]["area"])
