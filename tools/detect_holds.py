"""Find hold outlines in the spray wall photo.

Step 1: a colour-difference map (pixel vs. local wall colour) gives candidate
        points wherever something is not bare wall.
Step 2: Segment Anything (vit_b) traces a mask for each candidate point,
        at two scales (full-res tiles for small holds, 0.4x tiles for big
        holds and volumes).
Output: work/candidates.json - every plausible mask with quality stats.
        merge_holds.py turns these into the final hold list.

Extra prompt points (for holds the automatic pass misses) can be listed in
work/extra_points.json as [[x, y], ...] in full-res pixels.
"""
import json
import sys
import time
from pathlib import Path

import cv2
import numpy as np
import torch
from segment_anything import SamPredictor, sam_model_registry

ROOT = Path(__file__).parent
WORK = ROOT / "work"
IMG = WORK / "wall_full.png"
OUT = WORK / (sys.argv[1] if len(sys.argv) > 1 else "candidates.json")
ONLY_EXTRA = "--extra-only" in sys.argv

device = "mps" if torch.backends.mps.is_available() else "cpu"
sam = sam_model_registry["vit_b"](checkpoint=str(WORK / "sam_vit_b.pth")).to(device)
pred = SamPredictor(sam)

full_bgr = cv2.imread(str(IMG))
full = cv2.cvtColor(full_bgr, cv2.COLOR_BGR2RGB)
H, W = full.shape[:2]
full_lab = cv2.cvtColor(full_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)

# ---------- step 1: candidate points ----------
def candidate_points():
    s = 0.5
    sm = cv2.resize(full_bgr, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
    lab8 = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB)
    bg = np.dstack([cv2.medianBlur(lab8[:, :, i], 151) for i in range(3)]).astype(np.float32)
    d = lab8.astype(np.float32) - bg
    dist = np.sqrt(0.5 * d[:, :, 0] ** 2 + d[:, :, 1] ** 2 + d[:, :, 2] ** 2)
    fg = (dist > 18).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lbl, stats, cents = cv2.connectedComponentsWithStats(fg)
    pts = []
    step = 14  # half-res px -> 28 full-res px
    for i in range(1, n):
        x, y, w, h, a = stats[i]
        if a < 40:  # < ~160 full-res px^2: T-nut holes, specks
            continue
        cx, cy = cents[i]
        if lbl[int(cy), int(cx)] == i:
            pts.append((cx / s, cy / s, float(dist[int(cy), int(cx)])))
        # Distance transform peaks inside the component make good prompts.
        comp = (lbl[y:y + h, x:x + w] == i).astype(np.uint8)
        dt = cv2.distanceTransform(comp, cv2.DIST_L2, 3)
        for yy in range(step // 2, h, step):
            for xx in range(step // 2, w, step):
                if comp[yy, xx] and dt[yy, xx] >= 3:
                    pts.append(((x + xx) / s, (y + yy) / s, float(dist[y + yy, x + xx])))
    return pts


# ---------- step 2: SAM ----------
def ring_contrast(mask_full, x0, y0):
    """Lab distance between mask interior and a thin ring around it."""
    m = mask_full.astype(np.uint8)
    k = max(5, int(np.sqrt(m.sum()) * 0.15))
    ring = cv2.dilate(m, np.ones((k, k), np.uint8)) - m
    if ring.sum() < 5 or m.sum() < 5:
        return 0.0
    ys, xs = np.nonzero(m)
    region = full_lab[y0:y0 + m.shape[0], x0:x0 + m.shape[1]]
    inner = region[m > 0].mean(0)
    outer = region[ring > 0].mean(0)
    d = inner - outer
    return float(np.sqrt(0.5 * d[0] ** 2 + d[1] ** 2 + d[2] ** 2))


def run_scale(points, scale, tile, stride, min_area, max_area, tag):
    img = full if scale == 1.0 else cv2.resize(full, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    h, w = img.shape[:2]
    ys = sorted(set(list(range(0, max(1, h - tile), stride)) + [max(0, h - tile)]))
    xs = sorted(set(list(range(0, max(1, w - tile), stride)) + [max(0, w - tile)]))
    out = []
    for ty in ys:
        for tx in xs:
            sub = img[ty:ty + tile, tx:tx + tile]
            sh, sw = sub.shape[:2]
            # Points inside this tile, away from interior edges.
            margin = 24
            tp = []
            for (px, py, strength) in points:
                lx, ly = px * scale - tx, py * scale - ty
                if margin <= lx < sw - margin or (tx == 0 and 0 <= lx < sw) or (tx + sw >= w and 0 <= lx < sw):
                    if margin <= ly < sh - margin or (ty == 0 and 0 <= ly < sh) or (ty + sh >= h and 0 <= ly < sh):
                        if 0 <= lx < sw and 0 <= ly < sh:
                            tp.append((lx, ly, strength))
            if not tp:
                continue
            t0 = time.time()
            pred.set_image(sub)
            tp.sort(key=lambda p: -p[2])
            covered = np.zeros((sh, sw), bool)
            kept = 0
            B = 16
            i = 0
            while i < len(tp):
                batch = [p for p in tp[i:i + B] if not covered[int(p[1]), int(p[0])]]
                i += B
                if not batch:
                    continue
                pts = torch.tensor([[[p[0], p[1]]] for p in batch], dtype=torch.float32, device=device)
                lbl = torch.ones((len(batch), 1), device=device)
                pts_t = pred.transform.apply_coords_torch(pts, (sh, sw))
                logits, scores, _ = pred.predict_torch(pts_t, lbl, multimask_output=True, return_logits=True)
                hi = (logits > 1.0)
                lo = (logits > -1.0)
                inter = hi.flatten(2).sum(-1).float()
                union = lo.flatten(2).sum(-1).float().clamp(min=1)
                stab = (inter / union).cpu().numpy()
                masks = (logits > 0).cpu().numpy()
                scores = scores.cpu().numpy()
                del logits, hi, lo
                if device == "mps":
                    torch.mps.empty_cache()
                for bi, p in enumerate(batch):
                    best = None
                    for mi in range(3):
                        m = masks[bi, mi]
                        area_full = m.sum() / (scale * scale)
                        if area_full < min_area or area_full > max_area:
                            continue
                        if scores[bi, mi] < 0.70 or stab[bi, mi] < 0.80:
                            continue
                        ysx = np.nonzero(m.any(1))[0]
                        xsx = np.nonzero(m.any(0))[0]
                        y0, y1, x0, x1 = ysx[0], ysx[-1], xsx[0], xsx[-1]
                        edge = 2
                        if (x0 <= edge and tx > 0) or (y0 <= edge and ty > 0) or \
                           (x1 >= sw - 1 - edge and tx + sw < w) or (y1 >= sh - 1 - edge and ty + sh < h):
                            continue
                        cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
                        c = max(cs, key=cv2.contourArea)
                        if cv2.contourArea(c) < 0.5 * m.sum():
                            continue  # fragmented mask
                        # contrast in full-res coordinates
                        poly = (c.reshape(-1, 2).astype(np.float32) + [tx, ty]) / scale
                        bx, by, bw, bh = cv2.boundingRect(poly.astype(np.int32))
                        pad = int(max(bw, bh) * 0.3) + 6
                        X0, Y0 = max(0, bx - pad), max(0, by - pad)
                        X1, Y1 = min(W, bx + bw + pad), min(H, by + bh + pad)
                        mf = np.zeros((Y1 - Y0, X1 - X0), np.uint8)
                        cv2.fillPoly(mf, [(poly - [X0, Y0]).astype(np.int32)], 1)
                        con = ring_contrast(mf, X0, Y0)
                        cand = {
                            "poly": poly.round(1).tolist(),
                            "area": float(area_full), "iou": float(scores[bi, mi]),
                            "stab": float(stab[bi, mi]), "con": con, "mi": mi,
                            "pt": [p[0] / scale + tx / scale, p[1] / scale + ty / scale], "src": tag,
                        }
                        out.append(cand)
                        q = cand["iou"] + 0.01 * min(con, 30)
                        if best is None or q > best[0]:
                            best = (q, m)
                    if best is not None:
                        covered |= best[1]
                        kept += 1
            print(f"{tag} tile ({tx},{ty}): {len(tp)} pts -> {kept} masks, {time.time() - t0:.1f}s", flush=True)
    return out


if __name__ == "__main__":
    extra = []
    ep = WORK / ("extra_points_new.json" if "--new" in sys.argv else "extra_points.json")
    if ep.exists():
        extra = [(x, y, 999.0) for x, y in json.loads(ep.read_text())]
    pts = extra if ONLY_EXTRA else candidate_points() + extra
    print("candidate points:", len(pts), flush=True)
    cands = []
    cands += run_scale(pts, 1.0, 1024, 640, 300, 160_000, "s1")
    cands += run_scale(pts, 0.4, 1024, 640, 20_000, 1_200_000, "s04")
    OUT.write_text(json.dumps(cands))
    print("candidates:", len(cands))
