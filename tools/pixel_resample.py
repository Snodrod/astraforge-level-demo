"""Пиксельные листы студии -> один масштаб для карты.

Студия рендерит каждый ассет со своей плотностью (16-160 px/м), чтобы у мелочи была детализация.
На одной карте все спрайты должны быть в одной сетке пикселей, поэтому каждую клетку листа
уменьшаем до целевой плотности (Lanczos с учётом прозрачности), альфу режем по 50 %
и цвета прижимаем к палитре этого же ассета (palette.png из студии) — пиксели остаются чистыми.

Запуск:  py tools/pixel_resample.py   (из папки level_demo)
Результат: assets_px/<id>/<лист>.png + px.json (клетка, якорь, клипы, виды).
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets")
DST = os.path.join(ROOT, "assets_px")

# целевая плотность, px/м (карта — 16 px/м; мелочь и животные чуть крупнее, как в играх-фермах)
TARGET = {
    "tree_oak_1": 16, "tree_oak_2": 16, "tree_oak_3": 16, "tree_spruce_1": 16, "tree_spruce_2": 16,
    "tree_spruce_3": 16, "tree_birch_1": 16, "tree_birch_2": 16, "tree_birch_3": 16, "tree_apple_1": 16,
    "tree_apple_2": 16, "house": 16, "bridge": 32,
    "bush_1": 20, "fern": 22, "flower_1": 26, "flower_2": 26, "grass_1": 24, "grass_2": 24,
    "rock_3": 20, "rock_5": 20, "rock_6": 18, "log": 20, "barrel": 22, "crate": 22, "chest": 22, "campfire": 24, "torch_1": 30, "torch_2": 30,
    "deer": 22, "fox": 28, "hare": 28, "sparrow": 56, "crow": 34,
}


def palette(dir_):
    p = os.path.join(dir_, "palette.png")
    if not os.path.exists(p):
        return None
    im = np.asarray(Image.open(p).convert("RGB")).reshape(-1, 3)
    return np.unique(im, axis=0).astype(np.int32)


def snap(img, pal):
    a = np.asarray(img).copy()
    alpha = a[..., 3]
    a[..., 3] = np.where(alpha >= 110, 255, 0)
    if pal is not None:
        rgb = a[..., :3].reshape(-1, 3).astype(np.int32)
        d = ((rgb[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
        a[..., :3] = pal[d.argmin(1)].reshape(a.shape[0], a.shape[1], 3).astype(np.uint8)
    a[a[..., 3] == 0] = 0
    return Image.fromarray(a, "RGBA")


def scale_cell(cell, k, pal):
    w, h = cell.size
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    if k >= 2.0 - 1e-6 and abs(k - round(k)) < 1e-6:
        return cell.resize((nw, nh), Image.NEAREST)          # целое увеличение — пиксели как есть
    return snap(cell.resize((nw, nh), Image.LANCZOS), pal)


def main():
    os.makedirs(DST, exist_ok=True)
    for aid, tgt in TARGET.items():
        pdir = os.path.join(SRC, aid, "pixel")
        meta = json.load(io.open(os.path.join(pdir, "sprites.json"), encoding="utf-8"))
        ppm = float(meta["px_per_meter"])
        k = tgt / ppm
        pal = palette(pdir)
        cw, ch = meta["cell"]
        ncw, nch = max(1, round(cw * k)), max(1, round(ch * k))
        out = {"id": aid, "ppm": tgt, "src_ppm": ppm, "k": k, "cell": [ncw, nch],
               "anchor": [meta["anchor"][0] * ncw / cw, meta["anchor"][1] * nch / ch],
               "views": [v["name"] for v in meta["views"]], "clips": {}}
        od = os.path.join(DST, aid)
        os.makedirs(od, exist_ok=True)
        for cname, c in meta["clips"].items():
            views = c.get("views") or {}
            sheet_name = None
            for v in views.values():
                sheet_name = v.get("sheet")
                break
            if sheet_name is None:
                sheet_name = "static.png" if cname == "static" else cname + ".png"
            src = Image.open(os.path.join(pdir, sheet_name)).convert("RGBA")
            frames = int(c.get("frames", 1))
            nviews = len(meta["views"])
            sheet = Image.new("RGBA", (ncw * frames, nch * nviews), (0, 0, 0, 0))
            for vi in range(nviews):
                for fi in range(frames):
                    box = (fi * cw, vi * ch, fi * cw + cw, vi * ch + ch)
                    if box[2] > src.size[0] or box[3] > src.size[1]:
                        continue
                    sheet.paste(scale_cell(src.crop(box), k, pal), (fi * ncw, vi * nch))
            sheet.save(os.path.join(od, cname + ".png"))
            out["clips"][cname] = {"frames": frames, "fps": float(c.get("fps", 8.0)),
                                   "source_duration_s": float(c.get("source_duration_s", 0.0)),
                                   "loop": bool(c.get("loop", True))}
        json.dump(out, io.open(os.path.join(od, "px.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"{aid:14s} {ppm:>5.0f} -> {tgt:>3d} px/м  клетка {cw}x{ch} -> {ncw}x{nch}  клипы {list(out['clips'])}")


if __name__ == "__main__" and "--bridge" not in sys.argv:
    main()



def bridge_flat():
    """Мост поперёк русла: рендер пакета студии под ракурс карты (tools/render_bridge_px.gd), 64 -> 16 px/м."""
    od = os.path.join(DST, "bridge_flat")
    raw = os.path.join(od, "raw.png")
    if not os.path.exists(raw):
        print("bridge_flat: нет raw.png — сначала godot --path . --script tools/render_bridge_px.gd")
        return
    im = Image.open(raw).convert("RGBA")
    small = snap(im.resize((im.size[0] // 4, im.size[1] // 4), Image.LANCZOS), palette(os.path.join(SRC, "bridge", "pixel")))
    box = small.getbbox()
    small = small.crop(box)
    small.save(os.path.join(od, "static.png"))
    cx, cy = im.size[0] / 8.0, im.size[1] / 8.0          # точка опоры — центр кадра рендера
    out = {"id": "bridge_flat", "ppm": 16, "src_ppm": 64, "k": 0.25, "cell": list(small.size),
           "anchor": [cx - box[0], cy - box[1]], "views": ["S"],
           "clips": {"static": {"frames": 1, "fps": 1.0, "source_duration_s": 0.0, "loop": True}}}
    json.dump(out, io.open(os.path.join(od, "px.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("bridge_flat", small.size, out["anchor"])


if __name__ == "__main__":
    bridge_flat()
