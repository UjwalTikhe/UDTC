"""
SIH26231 — Out-of-Band SMS Anchor Simulator & Gateway Server
Section 4.4 / Section 8.1 of SIH26231 Specification:
- Instant 2G/GSM Out-of-band anchor witness (<140 chars)
- Encodes Test ID prefix, SHA-256 Record Hash prefix, Officer ID, and GPS Coordinate
- Emulates Android SmsManager hardware transmission
- Validates SMS witness payload against local/central hash ledger
"""

import time
import json
import sqlite3
import os
from typing import Dict, Any, Optional

class SMSAnchorSimulator:
    def __init__(self, db_path: str = "backend/sms_anchor_gateway.db", ncb_gateway_number: str = "+91-11-2617-NCB0"):
        self.db_path = db_path
        self.ncb_gateway_number = ncb_gateway_number
        self._init_db()

    def _init_db(self):
        os.makedirs(os.path.dirname(self.db_path) or ".", exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS sms_inbound_anchors (
            sms_id INTEGER PRIMARY KEY AUTOINCREMENT,
            received_timestamp_utc REAL,
            sender_sim_phone TEXT,
            gateway_number TEXT,
            raw_sms_body TEXT,
            test_id TEXT,
            record_hash_prefix TEXT,
            officer_id TEXT,
            classification TEXT,
            gps_coord TEXT,
            status TEXT
        )''')
        conn.commit()
        conn.close()

    def format_sms_payload(self, test_id: str, record_hash: str, officer_id: str, classification: str, lat: Optional[float] = None, lon: Optional[float] = None) -> str:
        """
        Formats strict 140-char standard GSM SMS payload for 2G out-of-band witness.
        Format: NCB#<test_id_short>#<hash_prefix_32>#<officer_short>#<res_code>#<gps>
        """
        # Compress fields to fit GSM 140-char SMS packet limit
        short_id = test_id.replace("TEST-", "").replace("NDPS-", "")[:12]
        hash_prefix = record_hash[:32]
        short_officer = officer_id.replace("OFFICER-", "")[:10]
        res_code = "POS" if "POS" in classification.upper() else ("NEG" if "NEG" in classification.upper() else "INC")
        gps_str = f"{lat:.3f},{lon:.3f}" if lat is not None and lon is not None else "NOGPS"
        
        # Payload format
        sms_text = f"NCB|{short_id}|{hash_prefix}|{short_officer}|{res_code}|{gps_str}"
        return sms_text

    def transmit_sms_from_device(self, sender_sim: str, sms_body: str) -> Dict[str, Any]:
        """
        Simulates Android SmsManager dispatching SMS over device GSM modem.
        """
        timestamp = time.time()
        
        # Parse fields from protocol
        parts = sms_body.split("|")
        if len(parts) >= 6 and parts[0] == "NCB":
            test_id_part = parts[1]
            hash_prefix = parts[2]
            officer_part = parts[3]
            res_code = parts[4]
            gps_part = parts[5]
            status = "VALID_NCB_ANCHOR"
        else:
            test_id_part = "UNKNOWN"
            hash_prefix = "UNKNOWN"
            officer_part = "UNKNOWN"
            res_code = "UNKNOWN"
            gps_part = "UNKNOWN"
            status = "MALFORMED_SMS"

        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute('''INSERT INTO sms_inbound_anchors (
            received_timestamp_utc, sender_sim_phone, gateway_number, raw_sms_body,
            test_id, record_hash_prefix, officer_id, classification, gps_coord, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', (
            timestamp, sender_sim, self.ncb_gateway_number, sms_body,
            test_id_part, hash_prefix, officer_part, res_code, gps_part, status
        ))
        sms_id = c.lastrowid
        conn.commit()
        conn.close()

        return {
            "sms_id": sms_id,
            "status": "DISPATCHED_AND_LOGGED",
            "sender_sim": sender_sim,
            "gateway_destination": self.ncb_gateway_number,
            "sms_body": sms_body,
            "char_count": len(sms_body),
            "timestamp_utc": timestamp
        }

    def verify_sms_anchor(self, full_record_hash: str) -> Dict[str, Any]:
        """
        Verifies if an out-of-band SMS anchor was received that matches the given record hash.
        """
        prefix = full_record_hash[:32]
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute('SELECT * FROM sms_inbound_anchors WHERE record_hash_prefix = ?', (prefix,))
        row = c.fetchone()
        conn.close()

        if row:
            return {
                "matched": True,
                "sms_id": row["sms_id"],
                "received_at": row["received_timestamp_utc"],
                "sender_sim": row["sender_sim_phone"],
                "classification_witnessed": row["classification"],
                "gps_coord": row["gps_coord"],
                "raw_sms": row["raw_sms_body"]
            }
        return {"matched": False, "reason": "No corresponding SMS anchor found for hash prefix."}

    def get_all_sms_logs(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute('SELECT * FROM sms_inbound_anchors ORDER BY sms_id DESC')
        rows = [dict(r) for r in c.fetchall()]
        conn.close()
        return rows
