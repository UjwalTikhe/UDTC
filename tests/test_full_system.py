"""
SIH26231 — Comprehensive Automated Verification Suite (Part 1)
"""

import os
import cv2
import json
import sqlite3
import pytest
from fastapi.testclient import TestClient

from engine.colorimeter import ColorimeterEngine, REAGENT_PROFILES
from security.crypto_signer import CryptoSigner
from security.hash_ledger import HashChainLedger
from security.legal_forensics import LegalForensicEngine
from backend.server import app

client = TestClient(app)

def test_colorimeter_pipeline_positive():
    engine = ColorimeterEngine()
    img = cv2.imread("card_assets/field_sample_positive.png")
    assert img is not None
    result = engine.classify_test(img, kit_type="MARQUIS_OPIATE", reaction_elapsed_seconds=45)
    assert result["status"] == "SUCCESS"
    assert result["classification"] == "PRESUMPTIVE_POSITIVE"
    assert result["delta_e2000"] < 14.0

def test_colorimeter_gating_blurry():
    engine = ColorimeterEngine()
    img = cv2.imread("card_assets/field_sample_blurry.png")
    assert img is not None
    result = engine.classify_test(img, kit_type="MARQUIS_OPIATE", reaction_elapsed_seconds=45)
    assert result["status"] == "FAIL_CLOSED"
    assert result["classification"] == "INCONCLUSIVE"
    assert "blurry" in result["reason"].lower()

def test_colorimeter_premature_reaction_gating():
    engine = ColorimeterEngine()
    img = cv2.imread("card_assets/field_sample_positive.png")
    result = engine.classify_test(img, kit_type="MARQUIS_OPIATE", reaction_elapsed_seconds=5)
    assert result["status"] == "FAIL_CLOSED"
    assert result["classification"] == "INCONCLUSIVE"
    assert "premature" in result["reason"].lower()

def test_dual_cryptographic_signatures():
    signer = CryptoSigner(key_dir="security/test_keys")
    payload = b'{"test_id": "NDPS-TEST-99", "result": "PRESUMPTIVE_POSITIVE"}'
    bundle = signer.dual_sign_record(payload, officer_pin="5544", officer_id="OFFICER-77")
    
    assert "device_signature_hex" in bundle
    assert "officer_signature_hex" in bundle

    res_valid = signer.verify_signatures(payload, bundle, officer_pin="5544")
    assert res_valid["all_valid"] is True
def test_hash_chain_ledger_tamper_detection():
    test_db = "security/test_suite_ledger.db"
    if os.path.exists(test_db):
        try:
            os.remove(test_db)
        except Exception:
            pass

    ledger = HashChainLedger(db_path=test_db)
    ledger.append_record("T-1", "O-1", "D-1", "MARQUIS_OPIATE", "PRESUMPTIVE_POSITIVE", 2.5, b"img1", "C-1", 28.6, 77.2, "sig1", "osig1")
    ledger.append_record("T-2", "O-1", "D-1", "MARQUIS_OPIATE", "PRESUMPTIVE_NEGATIVE", 50.0, b"img2", "C-1", 28.6, 77.2, "sig2", "osig2")

    verify_clean = ledger.verify_chain_integrity()
    assert verify_clean["is_valid"] is True
    assert verify_clean["record_count"] == 2

    # Simulate tampering
    conn = sqlite3.connect(test_db)
    conn.execute("UPDATE chain_ledger SET classification='PRESUMPTIVE_POSITIVE' WHERE test_id='T-2'")
    conn.commit()
    conn.close()

    verify_tampered = ledger.verify_chain_integrity()
    assert verify_tampered["is_valid"] is False
    assert "Payload modification detected" in verify_tampered["error"]

def test_legal_forensics_stego_and_bsa_cert():
    forensics = LegalForensicEngine(export_dir="security/test_exports")
    src_img = "card_assets/field_sample_positive.png"
    
    # Steganography test
    wm_img = forensics.embed_steganographic_watermark(src_img, "INSPECTOR-RAO", "Magistrate Submission")
    assert os.path.exists(wm_img)
    payload = forensics.extract_steganographic_watermark(wm_img)
    assert payload is not None
    assert payload["requester_id"] == "INSPECTOR-RAO"
    assert payload["purpose"] == "Magistrate Submission"

    # BSA Certificate test
    record = {
        "test_id": "TEST-BSA-01",
        "timestamp_utc": 1790448100.0,
        "officer_id": "OFFICER-RAO",
        "kit_type": "MARQUIS_OPIATE",
        "classification": "PRESUMPTIVE_POSITIVE",
        "delta_e2000": 3.12,
        "card_serial": "NCB-CARD-2026-0042",
        "latitude": 28.61,
        "longitude": 77.20,
        "location_status": "CONFIRMED_GPS",
        "image_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "prev_hash": "0000000000000000000000000000000000000000000000000000000000000000",
        "record_hash": "abcdef123456",
        "device_sig_hex": "3045022100",
        "officer_sig_hex": "4a8b1c2d"
    }
    cert_path = forensics.generate_bsa_section_63_certificate(record, "SUPERVISOR-ANAND")
    assert os.path.exists(cert_path)
    assert os.path.getsize(cert_path) > 1000

def test_backend_staged_sync_and_merkle():
    meta = {
        "test_id": "TEST-STAGE-FLOW-01",
        "timestamp_utc": 1790448200.0,
        "officer_id": "OFFICER-TEST",
        "device_id": "DEV-TEST",
        "kit_type": "SCOTT_COCAINE",
        "classification": "PRESUMPTIVE_POSITIVE",
        "delta_e2000": 3.5,
        "image_sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        "card_serial": "NCB-CARD-2026-0042",
        "latitude": 19.0760,
        "longitude": 72.8777,
        "location_status": "CONFIRMED_GPS",
        "prev_hash": "0000000000000000000000000000000000000000000000000000000000000000",
        "record_hash": "fe1234567890abcdef",
        "device_sig_hex": "sig_dev",
        "officer_sig_hex": "sig_off"
    }
    r1 = client.post("/sync/stage1/metadata", json=meta, headers={"x-officer-id": "OFFICER-TEST", "x-role": "officer"})
    assert r1.status_code == 200
    assert r1.json()["status"] in ["ANCHORED", "ALREADY_EXISTS"]

    r2 = client.post(
        "/sync/stage2/image",
        data={"test_id": "TEST-STAGE-FLOW-01"},
        files={"file": ("raw.png", b"test", "image/png")},
        headers={"x-officer-id": "OFFICER-TEST", "x-role": "officer"}
    )
    assert r2.status_code == 200
    assert r2.json()["status"] == "IMAGE_VERIFIED_AND_STORED"

    r3 = client.post("/merkle/batch", headers={"x-actor-id": "SUPERVISOR-TEST", "x-role": "supervisor"})
    assert r3.status_code == 200
    assert "status" in r3.json()

def test_admin_device_provisioning_and_spec_endpoints():
    # 1. Test Admin Provisioning
    prov_payload = {
        "device_id": "NCB-DEV-S24-IND01",
        "hardware_key_fingerprint": "KS-P256:4C98B2A109E2FA81",
        "assigned_officer": "OFFICER-RAJESH-04",
        "issued_card_serials": ["NCB-CARD-2026-0081", "NCB-CARD-2026-0082"],
        "status": "ACTIVE"
    }
    r_prov = client.post("/devices/provision", json=prov_payload, headers={"x-actor-id": "ADMIN-01", "x-role": "admin"})
    assert r_prov.status_code == 200
    assert r_prov.json()["status"] == "PROVISIONED"

    # 2. Test Section 5 Key Endpoint Aliases
    r_audit = client.get("/audit", headers={"x-actor-id": "AUDITOR-01", "x-role": "auditor"})
    assert r_audit.status_code == 200
    assert "audit_logs" in r_audit.json()

    r_records = client.get("/records", headers={"x-officer-id": "OFFICER-TEST", "x-role": "officer"})
    assert r_records.status_code == 200
    assert "records" in r_records.json()

    r_merkle = client.post("/anchor/merkle", headers={"x-actor-id": "SUPERVISOR-01", "x-role": "supervisor"})
    assert r_merkle.status_code == 200

    r_export = client.post("/records/TEST-STAGE-FLOW-01/export", headers={"x-officer-id": "OFFICER-TEST", "x-role": "officer"})
    assert r_export.status_code == 200
    assert r_export.headers["content-type"] == "application/pdf"



