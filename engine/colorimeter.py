"""
SIH26231 — Computer Vision & Deterministic Colorimetric Engine
Part 1: Profiles and Setup
"""

import cv2
import numpy as np
from typing import Tuple, Dict, Any, Optional

REAGENT_PROFILES = {
    "MARQUIS_OPIATE": {
        "name": "Marquis (Opiates/Heroin/Morphine)",
        "expected_lab": [26.0, 48.0, -32.0],
        "threshold_positive": 14.0,
        "threshold_inconclusive": 22.0,
        "min_reaction_time_s": 15,
        "max_reaction_time_s": 90
    },
    "SCOTT_COCAINE": {
        "name": "Scott Reagent (Cocaine)",
        "expected_lab": [38.0, -12.0, -45.0],
        "threshold_positive": 12.0,
        "threshold_inconclusive": 20.0,
        "min_reaction_time_s": 10,
        "max_reaction_time_s": 60
    },
    "DUQUENOIS_THC": {
        "name": "Duquenois-Levine (Cannabinoids)",
        "expected_lab": [32.0, 36.0, -22.0],
        "threshold_positive": 15.0,
        "threshold_inconclusive": 25.0,
        "min_reaction_time_s": 30,
        "max_reaction_time_s": 120
    }
}

class ColorimeterEngine:
    def __init__(self, blur_threshold: float = 75.0, clip_ratio_threshold: float = 0.08):
        self.blur_threshold = blur_threshold
        self.clip_ratio_threshold = clip_ratio_threshold
        self.aruco_dict = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
        self.aruco_detector = cv2.aruco.ArucoDetector(self.aruco_dict, cv2.aruco.DetectorParameters())

    def assess_image_quality(self, img_bgr: np.ndarray) -> Dict[str, Any]:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        clipped_pixels = np.count_nonzero(gray >= 252)
        clip_ratio = float(clipped_pixels / gray.size)

        is_sharp = laplacian_var >= self.blur_threshold
        is_exposure_valid = clip_ratio <= self.clip_ratio_threshold

        return {
            "is_valid": is_sharp and is_exposure_valid,
            "laplacian_variance": laplacian_var,
            "is_sharp": is_sharp,
            "clip_ratio": clip_ratio,
            "is_exposure_valid": is_exposure_valid,
            "rejection_reason": None if (is_sharp and is_exposure_valid) else (
                "Image too blurry" if not is_sharp else "Excessive specular glare / overexposed"
            )
        }

    def detect_and_rectify_card(self, img_bgr: np.ndarray, target_w: int = 1000, target_h: int = 700) -> Tuple[Optional[np.ndarray], Dict[str, Any]]:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        corners, ids, rejected = self.aruco_detector.detectMarkers(gray)

        if ids is None or len(ids) < 4:
            found_ids = ids.flatten().tolist() if ids is not None else []
            return None, {
                "success": False,
                "error": f"Card not fully in frame. Need 4 markers (0,1,2,3), found: {found_ids}"
            }

        id_list = ids.flatten().tolist()
        id_map = {id_list[i]: corners[i][0] for i in range(len(id_list))}
        required_ids = [0, 1, 2, 3]
        if not all(k in id_map for k in required_ids):
            return None, {
                "success": False,
                "error": f"Missing required markers. Found: {list(id_map.keys())}"
            }

        src_pts = np.float32([
            id_map[0][0], # TL
            id_map[1][1], # TR
            id_map[2][2], # BR
            id_map[3][3]  # BL
        ])

        dst_pts = np.float32([
            [40, 40],
            [target_w - 40, 40],
            [target_w - 40, target_h - 40],
            [40, target_h - 40]
        ])

        matrix = cv2.getPerspectiveTransform(src_pts, dst_pts)
        rectified = cv2.warpPerspective(img_bgr, matrix, (target_w, target_h), flags=cv2.INTER_LANCZOS4)

        return rectified, {
            "success": True,
            "detected_ids": [0, 1, 2, 3],
            "transform_matrix": matrix.tolist()
        }

    def calibrate_illumination_white_patch(self, rectified_bgr: np.ndarray) -> Tuple[np.ndarray, Dict[str, float]]:
        h, w = rectified_bgr.shape[:2]
        patch_w = int((w * 0.55) / 6)
        x0 = int(w * 0.22) + int(patch_w * 0.2)
        x1 = x0 + int(patch_w * 0.6)
        y0 = int(h * 0.18) + int(h * 0.03)
        y1 = y0 + int(h * 0.09)

        white_roi = rectified_bgr[y0:y1, x0:x1]
        mean_b, mean_g, mean_r = np.mean(white_roi, axis=(0, 1))

        target_val = 242.0
        gain_b = target_val / max(mean_b, 1.0)
        gain_g = target_val / max(mean_g, 1.0)
        gain_r = target_val / max(mean_r, 1.0)

        calibrated = rectified_bgr.astype(np.float32)
        calibrated[:, :, 0] = np.clip(calibrated[:, :, 0] * gain_b, 0, 255)
        calibrated[:, :, 1] = np.clip(calibrated[:, :, 1] * gain_g, 0, 255)
        calibrated[:, :, 2] = np.clip(calibrated[:, :, 2] * gain_r, 0, 255)
        calibrated = calibrated.astype(np.uint8)

        return calibrated, {
            "observed_white_bgr": [float(mean_b), float(mean_g), float(mean_r)],
            "gains_bgr": [float(gain_b), float(gain_g), float(gain_r)]
        }

    def extract_reaction_zone_lab(self, calibrated_bgr: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        h, w = calibrated_bgr.shape[:2]
        cx = int(w * 0.45)
        cy = int(h * 0.62)
        r = int(w * 0.06)

        roi = calibrated_bgr[cy - r:cy + r, cx - r:cx + r]
        lab_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2Lab)
        
        mean_lab_cv = np.mean(lab_roi, axis=(0, 1))
        cie_l = (mean_lab_cv[0] * 100.0) / 255.0
        cie_a = mean_lab_cv[1] - 128.0
        cie_b = mean_lab_cv[2] - 128.0

        return np.array([cie_l, cie_a, cie_b], dtype=np.float64), roi

    @staticmethod
    def calculate_ciede2000(lab1: np.ndarray, lab2: np.ndarray) -> float:
        L1, a1, b1 = lab1
        L2, a2, b2 = lab2

        C1 = np.sqrt(a1**2 + b1**2)
        C2 = np.sqrt(a2**2 + b2**2)
        C_bar = (C1 + C2) / 2.0
        G = 0.5 * (1.0 - np.sqrt((C_bar**7) / (C_bar**7 + 25**7 + 1e-12)))

        a1_prime = (1.0 + G) * a1
        a2_prime = (1.0 + G) * a2

        C1_prime = np.sqrt(a1_prime**2 + b1**2)
        C2_prime = np.sqrt(a2_prime**2 + b2**2)

        h1_prime = np.degrees(np.arctan2(b1, a1_prime)) % 360.0
        h2_prime = np.degrees(np.arctan2(b2, a2_prime)) % 360.0

        delta_L_prime = L2 - L1
        delta_C_prime = C2_prime - C1_prime

        if C1_prime * C2_prime == 0:
            delta_h_prime = 0.0
        else:
            diff = h2_prime - h1_prime
            if abs(diff) <= 180.0:
                delta_h_prime = diff
            elif diff > 180.0:
                delta_h_prime = diff - 360.0
            else:
                delta_h_prime = diff + 360.0

        delta_H_prime = 2.0 * np.sqrt(C1_prime * C2_prime) * np.sin(np.radians(delta_h_prime / 2.0))

        L_bar_prime = (L1 + L2) / 2.0
        C_bar_prime = (C1_prime + C2_prime) / 2.0

        if C1_prime * C2_prime == 0:
            h_bar_prime = h1_prime + h2_prime
        else:
            diff = abs(h1_prime - h2_prime)
            if diff <= 180.0:
                h_bar_prime = (h1_prime + h2_prime) / 2.0
            elif (h1_prime + h2_prime) < 360.0:
                h_bar_prime = (h1_prime + h2_prime + 360.0) / 2.0
            else:
                h_bar_prime = (h1_prime + h2_prime - 360.0) / 2.0

        T = (1.0 
             - 0.17 * np.cos(np.radians(h_bar_prime - 30.0))
             + 0.24 * np.cos(np.radians(2.0 * h_bar_prime))
             + 0.32 * np.cos(np.radians(3.0 * h_bar_prime + 6.0))
             - 0.20 * np.cos(np.radians(4.0 * h_bar_prime - 63.0)))

        delta_theta = 30.0 * np.exp(-(((h_bar_prime - 275.0) / 25.0)**2))
        R_C = 2.0 * np.sqrt((C_bar_prime**7) / (C_bar_prime**7 + 25**7 + 1e-12))
        S_L = 1.0 + (0.015 * ((L_bar_prime - 50.0)**2)) / np.sqrt(20.0 + (L_bar_prime - 50.0)**2)
        S_C = 1.0 + 0.045 * C_bar_prime
        S_H = 1.0 + 0.015 * C_bar_prime * T
        R_T = -np.sin(np.radians(2.0 * delta_theta)) * R_C

        de00 = np.sqrt(
            (delta_L_prime / S_L)**2 +
            (delta_C_prime / S_C)**2 +
            (delta_H_prime / S_H)**2 +
            R_T * (delta_C_prime / S_C) * (delta_H_prime / S_H)
        )
        return float(de00)

    def classify_test(
        self,
        img_bgr: np.ndarray,
        kit_type: str = "MARQUIS_OPIATE",
        reaction_elapsed_seconds: int = 45
    ) -> Dict[str, Any]:
        if kit_type not in REAGENT_PROFILES:
            return {
                "status": "ERROR",
                "classification": "INCONCLUSIVE",
                "reason": f"Unknown kit type: {kit_type}"
            }

        profile = REAGENT_PROFILES[kit_type]

        if reaction_elapsed_seconds < profile["min_reaction_time_s"]:
            return {
                "status": "FAIL_CLOSED",
                "classification": "INCONCLUSIVE",
                "reason": f"Premature reading: elapsed {reaction_elapsed_seconds}s < min {profile['min_reaction_time_s']}s"
            }
        if reaction_elapsed_seconds > profile["max_reaction_time_s"]:
            return {
                "status": "FAIL_CLOSED",
                "classification": "INCONCLUSIVE",
                "reason": f"Over-developed reading: elapsed {reaction_elapsed_seconds}s > max {profile['max_reaction_time_s']}s"
            }

        quality = self.assess_image_quality(img_bgr)
        if not quality["is_valid"]:
            return {
                "status": "FAIL_CLOSED",
                "classification": "INCONCLUSIVE",
                "quality_metrics": quality,
                "reason": quality["rejection_reason"]
            }

        rectified, rect_info = self.detect_and_rectify_card(img_bgr)
        if not rect_info["success"]:
            return {
                "status": "FAIL_CLOSED",
                "classification": "INCONCLUSIVE",
                "reason": rect_info["error"]
            }

        calibrated, calib_info = self.calibrate_illumination_white_patch(rectified)
        measured_lab, well_roi = self.extract_reaction_zone_lab(calibrated)

        expected_lab = np.array(profile["expected_lab"], dtype=np.float64)
        delta_e = self.calculate_ciede2000(measured_lab, expected_lab)

        pos_thresh = profile["threshold_positive"]
        inc_thresh = profile["threshold_inconclusive"]

        if delta_e <= pos_thresh:
            classification = "PRESUMPTIVE_POSITIVE"
            confidence = max(0.5, 1.0 - (delta_e / (pos_thresh * 2.0)))
        elif delta_e <= inc_thresh:
            classification = "INCONCLUSIVE"
            confidence = 0.5
        else:
            classification = "PRESUMPTIVE_NEGATIVE"
            confidence = min(0.99, (delta_e - inc_thresh) / 40.0 + 0.6)

        return {
            "status": "SUCCESS",
            "kit_type": kit_type,
            "kit_name": profile["name"],
            "classification": classification,
            "delta_e2000": round(delta_e, 3),
            "threshold_positive": pos_thresh,
            "threshold_inconclusive": inc_thresh,
            "confidence": round(float(confidence), 3),
            "measured_lab": [round(x, 2) for x in measured_lab.tolist()],
            "expected_lab": profile["expected_lab"],
            "reaction_elapsed_seconds": reaction_elapsed_seconds,
            "calibration_metadata": calib_info,
            "quality_metrics": quality,
            "legal_disclaimer": "PRESUMPTIVE FIELD TEST ONLY - MANDATORY CONFIRMATORY TESTING REQUIRED UNDER NDPS ACT §52A"
        }

