"""
SIH26231 - Calibration Card Generator
Generates a printable, standardized reference card containing:
1. Four corner ArUco markers (DICT_4X4_50, IDs 0, 1, 2, 3) for robust perspective rectification.
2. Standardized colorimetric calibration patches (White, Neutral Grays, Black, Primary Reagent anchors).
3. Central reagent test reaction well target zone.
4. Unique serial number and forensic tracking QR code.
"""

import cv2
import numpy as np
import qrcode
from PIL import Image, ImageDraw, ImageFont
import os

def create_reference_card(
    serial_number: str = "NCB-CARD-2026-0042",
    output_path: str = "card_assets/reference_card_print.png",
    dpi: int = 300,
    width_mm: int = 100,
    height_mm: int = 70
):
    # Calculate pixel dimensions for standard physical card size (100mm x 70mm)
    w_px = int((width_mm / 25.4) * dpi)
    h_px = int((height_mm / 25.4) * dpi)

    card = np.ones((h_px, w_px, 3), dtype=np.uint8) * 255

    # 1. Setup ArUco dictionary (DICT_4X4_50)
    aruco_dict = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
    marker_size = int(w_px * 0.13) # ~13mm marker

    marker_ids = [0, 1, 2, 3] # Top-Left, Top-Right, Bottom-Right, Bottom-Left
    marker_imgs = [cv2.aruco.generateImageMarker(aruco_dict, m_id, marker_size) for m_id in marker_ids]

    margin = int(w_px * 0.04)

    # Place Corner ArUco Markers
    # TL (ID 0)
    card[margin:margin+marker_size, margin:margin+marker_size] = cv2.cvtColor(marker_imgs[0], cv2.COLOR_GRAY2BGR)
    # TR (ID 1)
    card[margin:margin+marker_size, w_px-margin-marker_size:w_px-margin] = cv2.cvtColor(marker_imgs[1], cv2.COLOR_GRAY2BGR)
    # BR (ID 2)
    card[h_px-margin-marker_size:h_px-margin, w_px-margin-marker_size:w_px-margin] = cv2.cvtColor(marker_imgs[2], cv2.COLOR_GRAY2BGR)
    # BL (ID 3)
    card[h_px-margin-marker_size:h_px-margin, margin:margin+marker_size] = cv2.cvtColor(marker_imgs[3], cv2.COLOR_GRAY2BGR)

    # Convert to PIL for sharp typography and layout
    pil_card = Image.fromarray(card)
    draw = ImageDraw.Draw(pil_card)

    # 2. Draw Forensic Calibration Patch Strip (6 key patches: 95% White, 70% Gray, 50% Gray, 30% Gray, 5% Black, Reagent Standard Violet)
    patch_colors = [
        (242, 242, 242), # 95% White patch (illumination / white balance reference)
        (179, 179, 179), # 70% Gray
        (128, 128, 128), # 50% Neutral Gray
        (77, 77, 77),    # 30% Gray
        (25, 25, 25),    # Black patch (black level / dynamic range)
        (110, 35, 120),  # Standard Reagent Anchor (Marquis Alkaloid reference)
    ]
    patch_labels = ["W95", "G70", "G50", "G30", "K05", "REF-V"]

    strip_top = int(h_px * 0.18)
    strip_h = int(h_px * 0.15)
    strip_w_total = int(w_px * 0.55)
    start_x = int(w_px * 0.22)
    patch_w = int(strip_w_total / len(patch_colors))

    for idx, (color, label) in enumerate(zip(patch_colors, patch_labels)):
        x0 = start_x + (idx * patch_w)
        y0 = strip_top
        x1 = x0 + patch_w - 4
        y1 = y0 + strip_h
        draw.rectangle([x0, y0, x1, y1], fill=color, outline=(40, 40, 40), width=2)
        draw.text((x0 + 4, y1 + 3), label, fill=(50, 50, 50))

    # 3. Draw Reaction Well Target Zone
    well_cx = int(w_px * 0.45)
    well_cy = int(h_px * 0.62)
    well_r = int(w_px * 0.12)
    draw.ellipse([well_cx - well_r, well_cy - well_r, well_cx + well_r, well_cy + well_r], 
                 outline=(180, 0, 0), width=3)
    draw.line([well_cx - well_r - 10, well_cy, well_cx + well_r + 10, well_cy], fill=(180, 0, 0), width=1)
    draw.line([well_cx, well_cy - well_r - 10, well_cx, well_cy + well_r + 10], fill=(180, 0, 0), width=1)
    draw.text((well_cx - 45, well_cy + well_r + 8), "REACTION ZONE", fill=(180, 0, 0))

    # 4. Generate & Place Forensic Card QR Code
    qr = qrcode.QRCode(box_size=4, border=1)
    qr.add_data(f"NCB-CARD-VERIFY:{serial_number}")
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    qr_w, qr_h = qr_img.size
    qr_x = int(w_px * 0.68)
    qr_y = int(h_px * 0.48)
    pil_card.paste(qr_img, (qr_x, qr_y))

    # 5. Header and Serial Text
    draw.text((start_x, int(h_px * 0.05)), "NCB FIELD TEST CALIBRATION REFERENCE CARD", fill=(20, 20, 20))
    draw.text((start_x, int(h_px * 0.10)), "SIH26231 COMPLIANT - DETERMINISTIC COLORIMETRY", fill=(100, 100, 100))
    draw.text((qr_x - 10, qr_y + qr_h + 5), f"SERIAL: {serial_number}", fill=(30, 30, 30))
    draw.text((margin, h_px - margin + 5), "TL: ID 0", fill=(120, 120, 120))
    draw.text((w_px - margin - 50, h_px - margin + 5), "BR: ID 2", fill=(120, 120, 120))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    pil_card.save(output_path, "PNG", dpi=(dpi, dpi))
    print(f"Calibration Reference Card saved: {output_path} ({w_px}x{h_px} px)")
    return output_path

if __name__ == "__main__":
    create_reference_card()
