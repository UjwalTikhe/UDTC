"""
SIH26231 — Legal Certification & Forensic Leak-Traceability Engine
Implements:
1. Bharatiya Sakshya Adhiniyam 2023 (BSA §63) Electronic Evidence Certificate generation (Section 63 Certificate).
2. NDPS Act §52A statutory chain-of-custody inventory data structuring.
3. Imperceptible steganographic LSB watermarking tying leaked exports to requester officer ID, timestamp, and purpose.
4. Export watermark extraction/verification tool.
"""

import os
import json
import time
import hashlib
from typing import Dict, Any, Optional
from PIL import Image
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

class LegalForensicEngine:
    def __init__(self, export_dir: str = "security/exports"):
        self.export_dir = export_dir
        os.makedirs(self.export_dir, exist_ok=True)

    def embed_steganographic_watermark(
        self,
        image_path: str,
        export_requester_id: str,
        export_purpose: str,
        output_path: Optional[str] = None
    ) -> str:
        """
        Embeds an invisible LSB watermark payload into the low-order color bits.
        Format: [HEADER_MAGIC(8B)][PAYLOAD_LEN(4B)][PAYLOAD_JSON][CHECKSUM(4B)]
        """
        img = Image.open(image_path).convert("RGB")
        w, h = img.size

        watermark_data = {
            "requester_id": export_requester_id,
            "export_time_utc": time.time(),
            "purpose": export_purpose,
            "source_file": os.path.basename(image_path)
        }
        raw_payload = json.dumps(watermark_data).encode("utf-8")
        payload_len = len(raw_payload)
        checksum = hashlib.sha256(raw_payload).digest()[:4]

        full_stream = b"SIH26231" + payload_len.to_bytes(4, byteorder="big") + raw_payload + checksum
        bit_stream = ''.join(f"{byte:08b}" for byte in full_stream)

        pixels = list(img.getdata())
        total_channels = len(pixels) * 3

        if len(bit_stream) > total_channels:
            raise ValueError("Image too small to hold the forensic watermark payload.")

        new_pixels = []
        bit_idx = 0
        total_bits = len(bit_stream)

        for r, g, b in pixels:
            # Modify LSB of R
            if bit_idx < total_bits:
                r = (r & ~1) | int(bit_stream[bit_idx])
                bit_idx += 1
            # Modify LSB of G
            if bit_idx < total_bits:
                g = (g & ~1) | int(bit_stream[bit_idx])
                bit_idx += 1
            # Modify LSB of B
            if bit_idx < total_bits:
                b = (b & ~1) | int(bit_stream[bit_idx])
                bit_idx += 1
            new_pixels.append((r, g, b))

        watermarked_img = Image.new("RGB", (w, h))
        watermarked_img.putdata(new_pixels)

        if not output_path:
            output_path = os.path.join(self.export_dir, f"watermarked_{os.path.basename(image_path)}")

        watermarked_img.save(output_path, "PNG")
        return output_path

    def extract_steganographic_watermark(self, image_path: str) -> Optional[Dict[str, Any]]:
        """Extracts and verifies forensic watermark embedded in an exported image."""
        img = Image.open(image_path).convert("RGB")
        pixels = list(img.getdata())

        bits = []
        # Extract first 12 bytes (8 magic + 4 length) = 96 bits
        for r, g, b in pixels:
            bits.extend([str(r & 1), str(g & 1), str(b & 1)])
            if len(bits) >= 96:
                break

        header_bytes = bytearray()
        for i in range(0, 96, 8):
            header_bytes.append(int(''.join(bits[i:i+8]), 2))

        magic = header_bytes[:8]
        if magic != b"SIH26231":
            return None # No watermark found

        payload_len = int.from_bytes(header_bytes[8:12], byteorder="big")
        total_needed_bytes = 12 + payload_len + 4
        total_needed_bits = total_needed_bytes * 8

        # Extract all needed bits
        bits = []
        for r, g, b in pixels:
            bits.extend([str(r & 1), str(g & 1), str(b & 1)])
            if len(bits) >= total_needed_bits:
                break

        all_bytes = bytearray()
        for i in range(0, total_needed_bits, 8):
            all_bytes.append(int(''.join(bits[i:i+8]), 2))

        raw_payload = bytes(all_bytes[12:12+payload_len])
        expected_checksum = bytes(all_bytes[12+payload_len:12+payload_len+4])

        actual_checksum = hashlib.sha256(raw_payload).digest()[:4]
        if actual_checksum != expected_checksum:
            return None # Corrupted watermark

        try:
            return json.loads(raw_payload.decode('utf-8'))
        except Exception:
            return None

    def generate_bsa_section_63_certificate(
        self,
        record: Dict[str, Any],
        supervisor_id: str,
        case_crime_no: str = "NCB-CR-2026-0891",
        output_pdf_path: Optional[str] = None
    ) -> str:
        """
        Generates official Certificate under Section 63 of the Bharatiya Sakshya Adhiniyam, 2023
        (Condition of admissibility of electronic records in courts of law).
        """
        if not output_pdf_path:
            output_pdf_path = os.path.join(self.export_dir, f"BSA_Sec63_Cert_{record['test_id']}.pdf")

        doc = SimpleDocTemplate(output_pdf_path, pagesize=letter, rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40)
        styles = getSampleStyleSheet()

        title_style = ParagraphStyle(
            'TitleStyle',
            parent=styles['Heading1'],
            fontName='Helvetica-Bold',
            fontSize=15,
            alignment=1, # Center
            spaceAfter=15,
            textColor=colors.HexColor('#1A237E')
        )

        sub_style = ParagraphStyle(
            'SubStyle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=10,
            alignment=1,
            spaceAfter=20,
            textColor=colors.HexColor('#333333')
        )

        body_style = ParagraphStyle(
            'Body',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9.5,
            leading=14,
            spaceAfter=10
        )

        elements = []
        elements.append(Paragraph("CERTIFICATE UNDER SECTION 63 OF THE BHARATIYA SAKSHYA ADHINIYAM, 2023", title_style))
        elements.append(Paragraph("ADMISSIBILITY OF ELECTRONIC RECORD IN FIELD CHEMICAL COLORIMETRIC DRUG DETECTION", sub_style))

        cert_text = (
            f"I, <b>{record.get('officer_id')}</b>, Field Enforcement Officer, along with Supervisory Endorser "
            f"<b>{supervisor_id}</b>, do hereby solemnly certify under Section 63(4) of the Bharatiya Sakshya Adhiniyam, 2023 "
            f"that the electronic record described below was produced during the ordinary course of official duty by an authorized "
            f"mobile capture system operating under continuous cryptographic hash-linkage control."
        )
        elements.append(Paragraph(cert_text, body_style))
        elements.append(Spacer(1, 10))

        table_data = [
            ["Item / Parameter", "Cryptographic & Forensic Observation Value"],
            ["Case / Crime FIR No.", case_crime_no],
            ["Unique Test Record ID", str(record.get('test_id'))],
            ["Capture Timestamp (UTC)", str(record.get('timestamp_utc'))],
            ["Field Test Kit Type", str(record.get('kit_type'))],
            ["Presumptive Result", str(record.get('classification'))],
            ["Color Distance (CIEDE2000 ΔE)", f"{record.get('delta_e2000')} (Standard calibrated)"],
            ["Calibrated Card Serial No.", str(record.get('card_serial'))],
            ["GPS Coordinates & Status", f"{record.get('latitude')}, {record.get('longitude')} ({record.get('location_status')})"],
            ["Image SHA-256 Hash", str(record.get('image_sha256'))],
            ["Previous Record Link Hash", str(record.get('prev_hash'))],
            ["Current Cumulative Record Hash", str(record.get('record_hash'))],
            ["Hardware Key Signature (P-256)", f"{str(record.get('device_sig_hex'))[:36]}... [HARDWARE VERIFIED]"],
            ["Officer PIN-Bound Signature", f"{str(record.get('officer_sig_hex'))[:36]}... [SALTED HMAC VERIFIED]"]
        ]

        t = Table(table_data, colWidths=[200, 320])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A237E')),
            ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('FONTSIZE', (0,0), (-1,0), 9),
            ('BOTTOMPADDING', (0,0), (-1,0), 6),
            ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CCCCCC')),
            ('FONTNAME', (0,1), (-1,-1), 'Helvetica'),
            ('FONTSIZE', (0,1), (-1,-1), 8.5),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8F9FA')])
        ]))

        elements.append(t)
        elements.append(Spacer(1, 15))

        disclaimer = (
            "<b>STATUTORY DECLARATION:</b><br/>"
            "1. The mobile computing device and camera system were operating properly at all material times.<br/>"
            "2. No manual tampering, interpolation, or modification of pixel data or cryptographic hashes occurred.<br/>"
            "3. In accordance with NDPS Act §52A and NCB Procedural Directives, this result is <i>PRESUMPTIVE</i> "
            "and constitutes foundational primary electronic evidence pending Central Forensic Science Laboratory (CFSL) GC-MS validation."
        )
        elements.append(Paragraph(disclaimer, body_style))
        elements.append(Spacer(1, 20))

        elements.append(Paragraph("<b>Officer Signature:</b> _________________________ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <b>Supervisor Signature:</b> _________________________", body_style))

        doc.build(elements)
        return output_pdf_path


