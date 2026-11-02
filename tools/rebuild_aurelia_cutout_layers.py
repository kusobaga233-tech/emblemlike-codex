from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "test" / "cutout" / "aurelia_v01"


def despill_sem透明_boundary(image: Image.Image) -> tuple[Image.Image, int]:
    rgba = np.asarray(image.convert("RGBA")).copy()
    alpha = rgba[:, :, 3]
    occupied = (alpha > 0).astype(np.uint8)
    eroded = cv2.erode(occupied, np.ones((3, 3), np.uint8), iterations=1)
    boundary = (occupied > eroded) & (alpha < 250)

    rgb = rgba[:, :, :3].astype(np.float32)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    neutral_ceiling = np.maximum(red, blue) * 1.05 + 6.0
    contaminated = boundary & (green > neutral_ceiling)
    green[contaminated] = neutral_ceiling[contaminated]

    yellow_key = boundary & (red > blue * 1.35) & (green > blue * 1.45)
    warm_ceiling = blue * 1.28 + 18.0
    red[yellow_key] = np.minimum(red[yellow_key], warm_ceiling[yellow_key])
    green[yellow_key] = np.minimum(green[yellow_key], warm_ceiling[yellow_key])

    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), int((contaminated | yellow_key).sum())


def polygon_mask(size: tuple[int, int], polygons: list[list[tuple[int, int]]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    return mask


def checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    w, h = size
    out = Image.new("RGBA", size, (226, 229, 234, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(190, 196, 205, 255))
    return out


def fit_panel(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    panel = checker(size)
    work = image.copy()
    work.thumbnail((size[0] - 24, size[1] - 48), Image.Resampling.LANCZOS)
    panel.alpha_composite(work, ((size[0] - work.width) // 2, 36 + (size[1] - 48 - work.height) // 2))
    return panel


def main() -> None:
    source = Image.open(ASSET_DIR / "aurelia_full.png").convert("RGBA")
    width, height = source.size

    body = Image.open(ASSET_DIR / "body_no_sword_no_head.png").convert("RGBA")
    body_rgba = np.asarray(body).copy()
    body_alpha = body_rgba[:, :, 3]

    # Remove the isolated right-hand component and nearby key-fringe specks. The
    # sleeve remains intact; this source has no drawn wrist bridge between them.
    hand_fragment = polygon_mask(source.size, [[(718, 620), (807, 620), (816, 744), (718, 744)]])
    body_alpha[np.asarray(hand_fragment) > 0] = 0
    # Keep only the connected torso/body silhouette. This also removes small
    # detached keying remnants that cannot be rigged as meaningful body parts.
    count, labels, stats, _ = cv2.connectedComponentsWithStats((body_alpha > 0).astype(np.uint8), 8)
    if count > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        body_alpha[labels != largest] = 0
    body_rgba[:, :, 3] = body_alpha
    clean_body, body_despill = despill_sem透明_boundary(Image.fromarray(body_rgba, "RGBA"))
    clean_body.save(ASSET_DIR / "body_no_sword_no_head.png")

    # The formal weapon layer keeps the visible blade, guard, grip, glove and
    # short cuff as a single source-faithful animation layer. The narrow lower
    # blade selection avoids the detached cape/ribbon shapes beside the sword.
    # Reuse the already verified narrow sword silhouette as a mask, then widen
    # only around the authored guard/glove/cuff. RGB always comes from source.
    verified_sword = Image.open(ASSET_DIR / "clean_oathblade.png").convert("RGBA")
    weapon_mask = Image.new("L", source.size, 0)
    weapon_mask.paste(verified_sword.getchannel("A"), (172, 240))
    guard_hand_mask = polygon_mask(source.size, [[(96, 414), (253, 414), (253, 590), (96, 590)]])
    weapon_mask = Image.fromarray(
        np.maximum(np.asarray(weapon_mask), np.asarray(guard_hand_mask)).astype(np.uint8), "L"
    )
    weapon_rgba = np.asarray(source).copy()
    weapon_rgba[:, :, 3] = np.where(np.asarray(weapon_mask) > 0, weapon_rgba[:, :, 3], 0)

    ys, xs = np.where(weapon_rgba[:, :, 3] > 0)
    crop_box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    weapon = Image.fromarray(weapon_rgba, "RGBA").crop(crop_box)
    weapon, weapon_despill = despill_sem透明_boundary(weapon)
    weapon.save(ASSET_DIR / "clean_weapon_hand.png")

    # Grip/wrist pivot in source coordinates, then localized to the cropped layer.
    pivot_source = (207, 482)
    pivot_local = (pivot_source[0] - crop_box[0], pivot_source[1] - crop_box[1])

    manifest_path = ASSET_DIR / "extraction_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    manifest["processing"]["method"] = "Deterministic source-alpha masking; no generated or invented pixels."
    manifest["processing"]["edge_despill"] = (
        "Stronger green/yellow-key correction restricted to semi-transparent boundary pixels; "
        "opaque authored colors and alpha are unchanged."
    )
    manifest["processing"]["despill_stats_v2"] = {
        "body_boundary_pixels_corrected": body_despill,
        "weapon_hand_boundary_pixels_corrected": weapon_despill,
    }
    manifest["layers"][0]["notes"] = (
        "Full-canvas body layer with head and weapon removed. The disconnected floating right-hand "
        "fragment at source x=718..816, y=620..744 is explicitly removed."
    )
    manifest["layers"] = [
        layer
        for layer in manifest["layers"]
        if layer.get("file") not in {"clean_oathblade.png", "clean_weapon_hand.png"}
    ]
    manifest["layers"].append(
        {
            "file": "clean_weapon_hand.png",
            "dimensions": [weapon.width, weapon.height],
            "source_box": list(crop_box),
            "pivot_pixels": list(pivot_local),
            "pivot_normalized": [round(pivot_local[0] / weapon.width, 6), round(pivot_local[1] / weapon.height, 6)],
            "pivot_source_pixels": list(pivot_source),
            "pivot_semantics": "wrist / visible grip center",
            "notes": (
                "Source-faithful sword, guard, visible gripping glove and cuff. Narrow lower-blade mask "
                "excludes neighboring cape/ribbon fragments."
            ),
        }
    )
    manifest["contact_sheet"] = "layer_contact_sheet.png"
    manifest["limitations"] = [
        "The assembled source has no independently drawn pixels behind overlapping parts.",
        "The weapon-hand layer uses the visible glove/cuff authored around the grip; hidden wrist geometry is not invented.",
        "The detached right-side hand in the source has no connected wrist artwork and is intentionally absent from the cleaned body.",
        "Extreme skeletal deformation still requires a purpose-drawn layered source with overlap margins.",
    ]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    head = Image.open(ASSET_DIR / "clean_head.png").convert("RGBA")
    panel_size = (480, 720)
    sheet = Image.new("RGBA", (panel_size[0] * 3, panel_size[1]), (28, 31, 38, 255))
    items = [(clean_body, "BODY — fragment removed"), (head, "HEAD"), (weapon, "WEAPON + HAND — pivot at grip")]
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (image, label) in enumerate(items):
        panel = fit_panel(image, panel_size)
        sheet.alpha_composite(panel, (index * panel_size[0], 0))
        draw.text((index * panel_size[0] + 16, 12), label, fill=(20, 22, 28, 255), font=font)
        if index == 2:
            scale = min((panel_size[0] - 24) / weapon.width, (panel_size[1] - 48) / weapon.height)
            ox = index * panel_size[0] + (panel_size[0] - int(weapon.width * scale)) // 2
            oy = 36 + (panel_size[1] - 48 - int(weapon.height * scale)) // 2
            px = ox + int(pivot_local[0] * scale)
            py = oy + int(pivot_local[1] * scale)
            draw.ellipse((px - 7, py - 7, px + 7, py + 7), outline=(255, 44, 80, 255), width=3)
            draw.line((px - 11, py, px + 11, py), fill=(255, 44, 80, 255), width=2)
            draw.line((px, py - 11, px, py + 11), fill=(255, 44, 80, 255), width=2)
    sheet.convert("RGB").save(ASSET_DIR / "layer_contact_sheet.png", quality=95)


if __name__ == "__main__":
    main()
