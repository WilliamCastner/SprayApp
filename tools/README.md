# Hold detection for a new wall photo

These scripts trace every hold in a spray wall photo and write the outlines
into the app (`frontend/lib/wall/holds_v2.dart`).

## Setup (once)

```bash
python3 -m venv .venv-tools
.venv-tools/bin/pip install opencv-python-headless numpy torch torchvision segment-anything
curl -L -o tools/work/sam_vit_b.pth https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth
```

`detect_holds.py` runs on the Apple GPU (MPS) when available, else the CPU.

## Steps

1. Put the photo at `tools/work/wall_full.png` (5712x4284, the iPhone's full size).
2. `detect_holds.py` - colour-difference map gives ~10k prompt points; Segment
   Anything traces a mask at each one (full-res tiles for small holds, 0.4x tiles
   for volumes). About 10 minutes on an M-series Mac.
3. `merge_holds.py` - filters (T-nut holes, paint stripes, slivers, shadows),
   removes duplicates, allows small holds on volumes, and writes
   `holds_v2.json` plus review images `review_RC.jpg` and `misses_N.jpg`.
4. Review the images and correct by hand with `curate.py`:
   - `curate.py reject 12 40` - drop holds by the number in the review image
   - `curate.py add x,y` - prompt at a missed hold (keeps the smallest mask)
   - `curate.py addbig x,y` - same, but keeps the largest mask (volumes)
   - `curate.py manual x,y,x,y,...` - hand-drawn polygon
   Then `detect_holds.py candidates_extraN.json --extra-only --new` for new
   points, and `merge_holds.py` again. `sheet.py`, `which.py`, `shadows.py` and
   `dropped.py` help find problems.
5. `export_holds.py --image` - writes the Dart file and `assets/spray_wall_v2.jpg`.
6. `cd frontend && flutter test` - checks every hold can be tapped.

Hold numbers become permanent once climbs use them. For small fixes after
climbs exist, append new holds at the end of `holds_v2.dart` instead of
re-running the pipeline. For a new wall reset, add a new `SprayWall` (wall 3)
in `lib/wall/spray_wall.dart` and keep the old ones so old climbs still show.
