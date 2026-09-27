"""
SIH26231 - Local Tamper-Evident Hash-Chain Ledger
Part 1: DB Schema & Initialization
"""

import sqlite3
import hashlib
import json
import os
import time
from typing import Dict, Any, List, Optional, Tuple

GENESIS_HASH = "0000000000000000000000000000000000000000000000000000000000000000"

class HashChainLedger:
    def __init__(self, db_path: str = "security/ledger.db"):
        self.db_path = db_path
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS chain_ledger (
                    sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id TEXT UNIQUE NOT NULL,
                    timestamp_utc REAL NOT NULL,
                    officer_id TEXT NOT NULL,
                    device_id TEXT NOT NULL,
                    kit_type TEXT NOT NULL,
                    classification TEXT NOT NULL,
                    delta_e2000 REAL NOT NULL,
                    image_sha256 TEXT NOT NULL,
                    card_serial TEXT NOT NULL,
                    latitude REAL,
                    longitude REAL,
                    location_status TEXT NOT NULL,
                    prev_hash TEXT NOT NULL,
                    record_hash TEXT NOT NULL,
                    device_sig_hex TEXT NOT NULL,
                    officer_sig_hex TEXT NOT NULL,
                    synced_to_server INTEGER DEFAULT 0
                )
            """)
            conn.commit()

    def get_latest_record(self) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM chain_ledger ORDER BY sequence_id DESC LIMIT 1")
            row = cursor.fetchone()
            return dict(row) if row else None

    @staticmethod
    def canonical_hash(data_dict: Dict[str, Any], prev_hash: str) -> str:
        canonical_str = json.dumps(data_dict, sort_keys=True, separators=(',', ':'))
        payload = canonical_str.encode('utf-8') + prev_hash.encode('utf-8')
        return hashlib.sha256(payload).hexdigest()


    def append_record(
        self,
        test_id: str,
        officer_id: str,
        device_id: str,
        kit_type: str,
        classification: str,
        delta_e2000: float,
        image_bytes: bytes,
        card_serial: str,
        latitude: Optional[float],
        longitude: Optional[float],
        device_sig_hex: str,
        officer_sig_hex: str
    ) -> Dict[str, Any]:
        latest = self.get_latest_record()
        prev_hash = latest["record_hash"] if latest else GENESIS_HASH

        image_hash = hashlib.sha256(image_bytes).hexdigest()
        timestamp_utc = time.time()
        location_status = "CONFIRMED_GPS" if (latitude is not None and longitude is not None) else "LOCATION_UNCONFIRMED"

        data_payload = {
            "test_id": test_id,
            "timestamp_utc": round(timestamp_utc, 3),
            "officer_id": officer_id,
            "device_id": device_id,
            "kit_type": kit_type,
            "classification": classification,
            "delta_e2000": round(float(delta_e2000), 3),
            "image_sha256": image_hash,
            "card_serial": card_serial,
            "latitude": latitude,
            "longitude": longitude,
            "location_status": location_status
        }

        record_hash = self.canonical_hash(data_payload, prev_hash)

        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO chain_ledger (
                    test_id, timestamp_utc, officer_id, device_id, kit_type,
                    classification, delta_e2000, image_sha256, card_serial,
                    latitude, longitude, location_status, prev_hash, record_hash,
                    device_sig_hex, officer_sig_hex, synced_to_server
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            """, (
                test_id, data_payload["timestamp_utc"], officer_id, device_id, kit_type,
                classification, data_payload["delta_e2000"], image_hash, card_serial,
                latitude, longitude, location_status, prev_hash, record_hash,
                device_sig_hex, officer_sig_hex
            ))
            seq_id = cursor.lastrowid
            conn.commit()

        return {
            "sequence_id": seq_id,
            "test_id": test_id,
            "prev_hash": prev_hash,
            "record_hash": record_hash,
            "data_payload": data_payload
        }

    def verify_chain_integrity(self) -> Dict[str, Any]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM chain_ledger ORDER BY sequence_id ASC")
            records = cursor.fetchall()

        if not records:
            return {"is_valid": True, "record_count": 0, "status": "EMPTY_CHAIN"}

        expected_prev_hash = GENESIS_HASH

        for rec in records:
            seq_id = rec["sequence_id"]
            test_id = rec["test_id"]

            if rec["prev_hash"] != expected_prev_hash:
                return {
                    "is_valid": False,
                    "tamper_detected_at_sequence": seq_id,
                    "test_id": test_id,
                    "error": f"Broken chain link: expected prev_hash {expected_prev_hash[:10]}... got {rec['prev_hash'][:10]}..."
                }

            data_payload = {
                "test_id": rec["test_id"],
                "timestamp_utc": round(rec["timestamp_utc"], 3),
                "officer_id": rec["officer_id"],
                "device_id": rec["device_id"],
                "kit_type": rec["kit_type"],
                "classification": rec["classification"],
                "delta_e2000": round(float(rec["delta_e2000"]), 3),
                "image_sha256": rec["image_sha256"],
                "card_serial": rec["card_serial"],
                "latitude": rec["latitude"],
                "longitude": rec["longitude"],
                "location_status": rec["location_status"]
            }

            computed_hash = self.canonical_hash(data_payload, rec["prev_hash"])
            if computed_hash != rec["record_hash"]:
                return {
                    "is_valid": False,
                    "tamper_detected_at_sequence": seq_id,
                    "test_id": test_id,
                    "error": f"Payload modification detected: computed hash does not match stored hash!"
                }

            expected_prev_hash = rec["record_hash"]

        return {
            "is_valid": True,
            "record_count": len(records),
            "head_hash": expected_prev_hash,
            "status": "ALL_HASH_LINKS_CRYPTOGRAPHICALLY_VERIFIED"
        }


