"""Hand corrections that survive re-running the pipeline.

  python curate.py reject 633 634 ...    drop holds (by current index)
  python curate.py add 1059,3841 ...     prompt SAM at these full-res points
  python curate.py tile r c x,y ...      same as add, coords read off review_rc.jpg
  python curate.py manual x,y,x,y,...    add a hand-drawn polygon (full-res)

Rejections are stored as polygons (work/reject_polys.json) so they still
match after indices shift.
"""
import json
import sys
from pathlib import Path

WORK = Path(__file__).parent / "work"
meta = json.loads((WORK / "holds_v2_meta.json").read_text())


def load(name, default):
    p = WORK / name
    return json.loads(p.read_text()) if p.exists() else default


def save(name, data):
    (WORK / name).write_text(json.dumps(data))


cmd, args = sys.argv[1], sys.argv[2:]
if cmd == "reject":
    rej = load("reject_polys.json", [])
    for a in args:
        rej.append(meta[int(a)]["poly"])
    save("reject_polys.json", rej)
    print("rejected", len(args), "total", len(rej))
elif cmd in ("add", "tile"):
    pts = load("extra_points.json", [])
    new = []
    if cmd == "tile":
        r, c = int(args[0]), int(args[1])
        x0, y0 = max(0, c * 1428 - 60), max(0, r * 1071 - 60)
        for a in args[2:]:
            tx, ty = map(float, a.split(","))
            new.append([round(x0 + tx / 0.85), round(y0 + ty / 0.85)])
    else:
        new = [list(map(int, a.split(","))) for a in args]
    pts += new
    save("extra_points.json", pts)
    forced = load("forced_points.json", [])
    save("forced_points.json", forced + new)
    save("extra_points_new.json", new)
    print("added", new)
elif cmd == "addbig":
    # Prompt SAM here and keep the LARGEST good mask (volumes, big holds).
    new = [list(map(int, a.split(","))) for a in args]
    save("extra_points.json", load("extra_points.json", []) + new)
    save("forced_big_points.json", load("forced_big_points.json", []) + new)
    save("extra_points_new.json", new)
    print("added big", new)
elif cmd == "manual":
    man = load("manual_holds.json", [])
    v = list(map(int, args[0].split(",")))
    man.append([[v[i], v[i + 1]] for i in range(0, len(v), 2)])
    save("manual_holds.json", man)
    print("manual polygons", len(man))
