from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "test" / "cutout" / "aurelia_v01"
SOURCE_NAME = "aurelia_full.png"


def polygon_mask(size: tuple[int, int], polygons: list[list[tuple[int, int]]]) -> np.ndarray:
    image = Image.new("L", size, 0)
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    return np.asarray(image)


def color_mask_hsv(source: np.ndarray, ranges: list[tuple[tuple[int, int, int], tuple[int, int, int]]]) -> np.ndarray:
    hsv = cv2.cvtColor(source[:, :, :3], cv2.COLOR_RGB2HSV)
    result = np.zeros(hsv.shape[:2], dtype=np.uint8)
    for lower, upper in ranges:
        result = cv2.bitwise_or(result, cv2.inRange(hsv, np.array(lower), np.array(upper)))
    return result


def largest_components(mask: np.ndarray, minimum_area: int = 18) -> np.ndarray:
    count, labels, stats, _ = cv2.connectedComponentsWithStats((mask > 0).astype(np.uint8), 8)
    kept = np.zeros_like(mask)
    for index in range(1, count):
        if stats[index, cv2.CC_STAT_AREA] >= minimum_area:
            kept[labels == index] = 255
    return kept


def despill(image: Image.Image) -> tuple[Image.Image, dict[str, int]]:
    rgba = np.asarray(image.convert("RGBA")).copy()
    alpha = rgba[:, :, 3]
    occupied = (alpha > 0).astype(np.uint8)
    eroded = cv2.erode(occupied, np.ones((3, 3), np.uint8), iterations=1)
    boundary = (occupied > eroded) | ((alpha > 0) & (alpha < 245))

    rgb = rgba[:, :, :3].astype(np.float32)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    green_key = boundary & (green > np.maximum(red, blue) * 1.04 + 5)
    green[green_key] = np.maximum(red, blue)[green_key] * 1.02 + 3

    yellow_key = boundary & (red > blue * 1.30 + 10) & (green > blue * 1.35 + 10)
    warm_limit = blue * 1.20 + 20
    red[yellow_key] = np.minimum(red[yellow_key], warm_limit[yellow_key])
    green[yellow_key] = np.minimum(green[yellow_key], warm_limit[yellow_key])

    severe = boundary & ((green - blue > 70) | ((red + green) * 0.5 - blue > 90)) & (alpha < 220)
    alpha[severe] = (alpha[severe].astype(np.float32) * 0.55).astype(np.uint8)
    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA"), {
        "green_pixels_corrected": int(green_key.sum()),
        "yellow_pixels_corrected": int(yellow_key.sum()),
        "severe_fringe_pixels_deopaqued": int(severe.sum()),
    }


def crop_layer(source: np.ndarray, mask: np.ndarray) -> tuple[Image.Image, tuple[int, int, int, int]]:
    mask = largest_components(mask)
    ys, xs = np.where(mask > 0)
    if not len(xs):
        raise RuntimeError("empty layer mask")
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    rgba = source.copy()
    rgba[:, :, 3] = np.where(mask > 0, source[:, :, 3], 0)
    return Image.fromarray(rgba, "RGBA").crop(box), box


def checker(size: tuple[int, int], cell: int = 20) -> Image.Image:
    result = Image.new("RGBA", size, (226, 229, 234, 255))
    draw = ImageDraw.Draw(result)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(188, 194, 203, 255))
    return result


def main() -> None:
    source_image = Image.open(ASSET_DIR / SOURCE_NAME).convert("RGBA")
    source = np.asarray(source_image).copy()
    source_alpha = source[:, :, 3]
    size = source_image.size

    # These selections deliberately describe only visible authored pixels.  The
    # flattened concept art contains no shoulder sockets, hidden wrists, hair
    # roots or cape overlap margins, so the masks are conservative.
    regions = {
        "arm_back": [[(345, 300), (438, 300), (452, 405), (423, 500), (354, 493), (324, 396)]],
        "arm_front": [[(618, 295), (698, 306), (735, 438), (790, 627), (742, 686), (687, 567), (649, 460)]],
        "hand_front": [[(716, 618), (795, 615), (818, 727), (741, 742), (713, 683)]],
        "cloth_front": [
            [(298, 500), (455, 493), (447, 614), (394, 813), (310, 1025), (219, 1207), (154, 1175), (231, 876)],
            [(568, 490), (682, 495), (717, 611), (818, 838), (899, 1122), (842, 1211), (746, 1002), (666, 796)],
        ],
        "cloth_back": [
            [(224, 559), (367, 557), (426, 673), (382, 991), (304, 1130), (228, 998), (176, 799)],
            [(587, 554), (731, 552), (824, 759), (907, 1005), (853, 1150), (757, 1028), (684, 790)],
        ],
        "hair_back": [
            [(262, 121), (405, 68), (619, 57), (773, 157), (852, 396), (817, 581), (714, 649), (652, 542), (616, 366), (399, 367), (356, 567), (271, 641), (244, 424)],
        ],
        "hair_front": [[(400, 42), (620, 42), (652, 148), (616, 251), (561, 304), (459, 296), (393, 219), (376, 121)]],
    }

    raw_masks = {name: polygon_mask(size, polygons) for name, polygons in regions.items()}

    # Hair is constrained by the authored auburn/red palette so face, blouse
    # and pale trim inside the broad silhouette are not stolen into hair layers.
    hair_color = color_mask_hsv(source, [((0, 55, 25), (18, 255, 230)), ((165, 45, 20), (179, 255, 220))])
    raw_masks["hair_front"] = cv2.bitwise_and(raw_masks["hair_front"], hair_color)
    raw_masks["hair_back"] = cv2.bitwise_and(raw_masks["hair_back"], hair_color)

    # Every layer must be an authored, non-transparent source pixel.
    for name in raw_masks:
        raw_masks[name] = cv2.bitwise_and(raw_masks[name], np.where(source_alpha > 0, 255, 0).astype(np.uint8))

    # Priority resolves deliberate mask overlap: hands above arm, front cloth
    # above back cloth, front hair above back hair.
    priority = ["hair_front", "hair_back", "hand_front", "arm_front", "arm_back", "cloth_front", "cloth_back"]
    claimed = np.zeros_like(source_alpha, dtype=np.uint8)
    masks: dict[str, np.ndarray] = {}
    for name in priority:
        current = cv2.bitwise_and(raw_masks[name], cv2.bitwise_not(claimed))
        current = largest_components(current)
        masks[name] = current
        claimed = cv2.bitwise_or(claimed, current)

    pivots = {
        "arm_back": ((384, 329), "shoulder center; small rotation only"),
        "arm_front": ((665, 329), "shoulder center; small rotation only"),
        "hand_front": ((748, 649), "visible wrist edge; no hidden wrist pixels"),
        "hair_front": ((512, 112), "upper-head attachment"),
        "hair_back": ((512, 224), "top of visible back-hair mass; hidden root absent"),
        "cloth_front": ((512, 536), "waist/coat attachment"),
        "cloth_back": ((512, 570), "rear waist attachment"),
    }
    limits = {
        "arm_back": "Visible sleeve only; torso-overlapped shoulder and inner elbow are absent. Recommended rotation <= 8 degrees.",
        "arm_front": "Visible sleeve/forearm only; no authored shoulder overlap margin. Recommended rotation <= 8 degrees.",
        "hand_front": "Detached visible hand only; no connected wrist bridge. Recommended rotation <= 12 degrees.",
        "hair_front": "Color-selected visible bangs only. Face-overlapped hair roots are absent; use subtle secondary motion.",
        "hair_back": "Visible auburn mass only; torso-hidden center sections are absent. Recommended sway <= 10 pixels at 1024x1536.",
        "cloth_front": "Visible white coat tails only; waist overlap is flattened. Recommended sway <= 12 pixels.",
        "cloth_back": "Visible colored rear ribbons/panels only; hidden attachment geometry is absent. Recommended sway <= 16 pixels.",
    }

    manifest_layers = []
    rendered: list[tuple[str, Image.Image, tuple[int, int], str]] = []
    despill_stats = {}
    for name in priority:
        image, box = crop_layer(source, masks[name])
        image, stats = despill(image)
        filename = f"{name}.png"
        image.save(ASSET_DIR / filename)
        despill_stats[name] = stats
        pivot_source, semantics = pivots[name]
        pivot_local = (pivot_source[0] - box[0], pivot_source[1] - box[1])
        manifest_layers.append({
            "file": filename,
            "dimensions": [image.width, image.height],
            "source_box": list(box),
            "pivot_source_pixels": list(pivot_source),
            "pivot_pixels": list(pivot_local),
            "pivot_normalized": [round(pivot_local[0] / image.width, 6), round(pivot_local[1] / image.height, 6)],
            "pivot_semantics": semantics,
            "source_fidelity": "Visible source pixels only; no generated pixels.",
            "limitation": limits[name],
        })
        rendered.append((name, image, pivot_local, limits[name]))

    # Remove the newly separated regions from the existing body layer.  This
    # keeps reconstruction deterministic without inventing pixels behind them.
    body_path = ASSET_DIR / "body_no_sword_no_head.png"
    body = np.asarray(Image.open(body_path).convert("RGBA")).copy()
    body[:, :, 3] = np.where(claimed > 0, 0, body[:, :, 3])
    clean_body, body_stats = despill(Image.fromarray(body, "RGBA"))
    clean_body.save(body_path)

    manifest_path = ASSET_DIR / "extraction_manifest.json"
    old = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    generated_files = {f"{name}.png" for name in priority}
    retained = [layer for layer in old.get("layers", []) if layer.get("file") not in generated_files]
    for layer in retained:
        if layer.get("file") == "body_no_sword_no_head.png":
            layer["notes"] = "Full-canvas residual body after head, weapon/hand, arms, visible hair and visible cloth panels are removed. No hidden pixels are synthesized."
    old["asset"] = "Aurelia cutout v02 conservative formal layers"
    old["processing"]["method_v2"] = "Deterministic visible-pixel partition from aurelia_full.png; conservative polygon and palette masks; no inpaint or foreign puppet parts."
    old["processing"]["despill_stats_v3"] = {"body": body_stats, **despill_stats}
    old["layers"] = retained + manifest_layers
    old["contact_sheet"] = "layer_contact_sheet_v2.png"
    old["contact_sheet_v2"] = "layer_contact_sheet_v2.png"
    old["limitations"] = [
        "The source is a flattened illustration and contains no pixels behind overlapping face, torso, shoulders, wrists, hair roots or waist cloth.",
        "The v02 layers are minimal-motion layers for a prototype, not production puppet parts with overlap margins.",
        "No inpaint was used because generated hidden pixels could not be proven style- and anatomy-consistent with the approved source.",
        "Large limb rotations, foreshortening or full walk cycles require purpose-drawn front/back limbs and joint overlap artwork.",
    ]
    manifest_path.write_text(json.dumps(old, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    panel_size = (360, 520)
    columns = 4
    rows = 2
    sheet = Image.new("RGBA", (panel_size[0] * columns, panel_size[1] * rows), (30, 33, 40, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    entries = [("body_residual", clean_body, (512, 1376), "Residual body; separated regions transparent")] + rendered
    for index, (name, image, pivot, limitation) in enumerate(entries):
        x0 = (index % columns) * panel_size[0]
        y0 = (index // columns) * panel_size[1]
        panel = checker(panel_size)
        work = image.copy()
        work.thumbnail((panel_size[0] - 28, panel_size[1] - 92), Image.Resampling.LANCZOS)
        ox = (panel_size[0] - work.width) // 2
        oy = 42 + (panel_size[1] - 92 - work.height) // 2
        panel.alpha_composite(work, (ox, oy))
        sheet.alpha_composite(panel, (x0, y0))
        draw.text((x0 + 12, y0 + 10), name.upper(), fill=(18, 20, 25, 255), font=font)
        draw.text((x0 + 12, y0 + panel_size[1] - 37), limitation[:55], fill=(55, 58, 66, 255), font=font)
        if name != "body_residual":
            scale = min((panel_size[0] - 28) / image.width, (panel_size[1] - 92) / image.height)
            px = x0 + ox + int(pivot[0] * scale)
            py = y0 + oy + int(pivot[1] * scale)
            draw.ellipse((px - 5, py - 5, px + 5, py + 5), outline=(255, 38, 76, 255), width=2)
    sheet.convert("RGB").save(ASSET_DIR / "layer_contact_sheet_v2.png", quality=95)


if __name__ == "__main__":
    main()
