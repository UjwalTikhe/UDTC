from fastapi import FastAPI, HTTPException, Header, UploadFile, File, Form, Depends
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any, Tuple
import hashlib
import json
import time
import os
import sqlite3

from security.hash_ledger import HashChainLedger
from security.legal_forensics import LegalForensicEngine

app = FastAPI(
    title='SIH26231 Field Drug Testing Server',
    description='Deterministic Colorimetry & Tamper-Evident Ledger',
    version='1.0.0'
)

DB_PATH = 'backend/server_vault.db'
os.makedirs('backend/uploads', exist_ok=True)
os.makedirs('backend', exist_ok=True)

def init_server_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS server_records (
    test_id TEXT PRIMARY KEY,
    timestamp_utc REAL,
    officer_id TEXT,
    device_id TEXT,
    kit_type TEXT,
    classification TEXT,
    delta_e2000 REAL,
    image_sha256 TEXT,
    card_serial TEXT,
    latitude REAL,
    longitude REAL,
    location_status TEXT,
    prev_hash TEXT,
    record_hash TEXT,
    device_sig_hex TEXT,
    officer_sig_hex TEXT,
    image_stored_path TEXT,
    merkle_batch_id TEXT,
    received_at REAL
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS merkle_roots (
    batch_id TEXT PRIMARY KEY,
    timestamp_utc REAL,
    record_count INTEGER,
    merkle_root_sha256 TEXT,
    leaf_hashes TEXT
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS server_audit_log (
    audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc REAL,
    actor_id TEXT,
    actor_role TEXT,
    action TEXT,
    target_id TEXT,
    prev_audit_hash TEXT,
    audit_hash TEXT
    )''')
    conn.commit()
    conn.close()

init_server_db()

def log_audit_event(actor_id: str, actor_role: str, action: str, target_id: str):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT audit_hash FROM server_audit_log ORDER BY audit_id DESC LIMIT 1')
    row = c.fetchone()
    prev_hash = row[0] if row else '0000000000000000000000000000000000000000000000000000000000000000'
    ts = time.time()
    payload = f'{ts}:{actor_id}:{actor_role}:{action}:{target_id}:{prev_hash}'.encode('utf-8')
    audit_hash = hashlib.sha256(payload).hexdigest()
    c.execute('''INSERT INTO server_audit_log (timestamp_utc, actor_id, actor_role, action, target_id, prev_audit_hash, audit_hash)
    VALUES (?, ?, ?, ?, ?, ?, ?)''', (ts, actor_id, actor_role, action, target_id, prev_hash, audit_hash))
    conn.commit()
    conn.close()

def build_merkle_tree(leaf_hashes: List[str]) -> Tuple[str, List[List[str]]]:
    if not leaf_hashes:
        return '0000000000000000000000000000000000000000000000000000000000000000', []
    current_level = [bytes.fromhex(h) if len(h)==64 else hashlib.sha256(h.encode()).digest() for h in leaf_hashes]
    tree = [[h.hex() for h in current_level]]
    while len(current_level) > 1:
        next_level = []
        for i in range(0, len(current_level), 2):
            left = current_level[i]
            right = current_level[i+1] if i+1 < len(current_level) else left
            combined = hashlib.sha256(left + right).digest()
            next_level.append(combined)
        current_level = next_level
        tree.append([h.hex() for h in current_level])
    return current_level[0].hex(), tree

class SyncMetadataPayload(BaseModel):
    test_id: str
    timestamp_utc: float
    officer_id: str
    device_id: str
    kit_type: str
    classification: str
    delta_e2000: float
    image_sha256: str
    card_serial: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_status: str
    prev_hash: str
    record_hash: str
    device_sig_hex: str
    officer_sig_hex: str

@app.post('/sync/stage1/metadata')
def sync_stage1_metadata(
    payload: SyncMetadataPayload,
    x_officer_id: str = Header('OFFICER-01'),
    x_role: str = Header('officer')
):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT test_id FROM server_records WHERE test_id = ?', (payload.test_id,))
    if c.fetchone():
        conn.close()
        return {'status': 'ALREADY_EXISTS', 'test_id': payload.test_id}

    c.execute('''INSERT INTO server_records (
    test_id, timestamp_utc, officer_id, device_id, kit_type,
    classification, delta_e2000, image_sha256, card_serial,
    latitude, longitude, location_status, prev_hash, record_hash,
    device_sig_hex, officer_sig_hex, received_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', (
    payload.test_id, payload.timestamp_utc, payload.officer_id, payload.device_id, payload.kit_type,
    payload.classification, payload.delta_e2000, payload.image_sha256, payload.card_serial,
    payload.latitude, payload.longitude, payload.location_status, payload.prev_hash, payload.record_hash,
    payload.device_sig_hex, payload.officer_sig_hex, time.time()
    ))
    conn.commit()
    conn.close()
    log_audit_event(x_officer_id, x_role, 'STAGE1_SYNC_METADATA', payload.test_id)
    return {'status': 'ANCHORED', 'test_id': payload.test_id, 'record_hash': payload.record_hash}

@app.post('/sync/stage2/image')
async def sync_stage2_image(
    test_id: str = Form(...),
    file: UploadFile = File(...),
    x_officer_id: str = Header('OFFICER-01'),
    x_role: str = Header('officer')
):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT image_sha256 FROM server_records WHERE test_id = ?', (test_id,))
    row = c.fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail='Stage 1 record must be anchored first.')

    expected_sha256 = row[0]
    img_bytes = await file.read()
    actual_sha256 = hashlib.sha256(img_bytes).hexdigest()

    if actual_sha256 != expected_sha256:
        conn.close()
        raise HTTPException(status_code=400, detail='Image SHA-256 hash does not match anchored Stage 1 hash!')

    stored_path = os.path.join('backend/uploads', f'{test_id}_{file.filename}')
    with open(stored_path, 'wb') as f:
        f.write(img_bytes)

    c.execute('UPDATE server_records SET image_stored_path = ? WHERE test_id = ?', (stored_path, test_id))
    conn.commit()
    conn.close()
    log_audit_event(x_officer_id, x_role, 'STAGE2_SYNC_IMAGE', test_id)
    return {'status': 'IMAGE_VERIFIED_AND_STORED', 'test_id': test_id, 'image_sha256': actual_sha256}

@app.post('/merkle/batch')
def trigger_merkle_batch(
    x_actor_id: str = Header('CRON-BATCHER'),
    x_role: str = Header('supervisor')
):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('SELECT test_id, record_hash FROM server_records WHERE merkle_batch_id IS NULL ORDER BY received_at ASC')
    rows = c.fetchall()

    if not rows:
        conn.close()
        return {'status': 'NO_PENDING_RECORDS', 'message': 'All records already anchored in Merkle roots.'}

    leaf_hashes = [r[1] for r in rows]
    test_ids = [r[0] for r in rows]
    root_hash, _ = build_merkle_tree(leaf_hashes)

    batch_id = f'BATCH-{int(time.time())}'
    c.execute('''INSERT INTO merkle_roots (batch_id, timestamp_utc, record_count, merkle_root_sha256, leaf_hashes)
    VALUES (?, ?, ?, ?, ?)''', (batch_id, time.time(), len(leaf_hashes), root_hash, json.dumps(leaf_hashes)))

    for tid in test_ids:
        c.execute('UPDATE server_records SET merkle_batch_id = ? WHERE test_id = ?', (batch_id, tid))

    conn.commit()
    conn.close()
    log_audit_event(x_actor_id, x_role, 'MERKLE_ROOT_CREATED', batch_id)
    return {
    'status': 'BATCH_ROOT_COMPUTED',
    'batch_id': batch_id,
    'record_count': len(leaf_hashes),
    'merkle_root_sha256': root_hash
    }

@app.get('/records/search')
def search_records(
    query: Optional[str] = None,
    kit_type: Optional[str] = None,
    x_officer_id: str = Header('OFFICER-01'),
    x_role: str = Header('officer')
):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    base_query = 'SELECT * FROM server_records WHERE 1=1'
    params = []

    if x_role.lower() == 'officer':
        base_query += ' AND officer_id = ?'
        params.append(x_officer_id)

    if query:
        base_query += ' AND (test_id LIKE ? OR card_serial LIKE ? OR classification LIKE ?)'
        wildcard = f'%{query}%'
        params.extend([wildcard, wildcard, wildcard])

    if kit_type:
        base_query += ' AND kit_type = ?'
        params.append(kit_type)

    base_query += ' ORDER BY timestamp_utc DESC'
    c.execute(base_query, tuple(params))
    records = [dict(row) for row in c.fetchall()]
    conn.close()
    log_audit_event(x_officer_id, x_role, 'SEARCH_RECORDS', f'Found {len(records)} records')
    return {'count': len(records), 'records': records}

@app.get('/audit/trail')
def get_audit_trail(
    x_actor_id: str = Header('AUDITOR-01'),
    x_role: str = Header('auditor')
):
    if x_role.lower() not in ['auditor', 'supervisor', 'admin']:
        raise HTTPException(status_code=403, detail='Audit log inspection restricted to Auditor role.')
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute('SELECT * FROM server_audit_log ORDER BY audit_id ASC')
    logs = [dict(r) for r in c.fetchall()]
    conn.close()
    return {'count': len(logs), 'audit_logs': logs}
from fastapi.responses import FileResponse
from sync_mesh.sms_anchor import SMSAnchorSimulator
from security.legal_forensics import LegalForensicEngine

sms_sim = SMSAnchorSimulator(db_path='backend/sms_gateway.db')
forensic_engine = LegalForensicEngine(export_dir='backend/exports')

class SMSInboundPayload(BaseModel):
    sender_sim: str
    sms_body: str

@app.post('/sms/inbound')
def receive_sms_anchor(payload: SMSInboundPayload):
    """
    Receives out-of-band GSM SMS hash anchor directly from field officer's SIM.
    """
    res = sms_sim.transmit_sms_from_device(payload.sender_sim, payload.sms_body)
    log_audit_event(payload.sender_sim, 'gsm_network', 'SMS_OUT_OF_BAND_ANCHOR', payload.sms_body)
    return res

@app.get('/sms/logs')
def get_sms_logs(
    x_actor_id: str = Header('SUPERVISOR-01'),
    x_role: str = Header('supervisor')
):
    if x_role.lower() not in ['supervisor', 'auditor', 'admin']:
        raise HTTPException(status_code=403, detail='Access restricted to Supervisory roles.')
    logs = sms_sim.get_all_sms_logs()
    return {'count': len(logs), 'sms_logs': logs}

@app.get('/records/{test_id}/bsa-certificate')
def download_bsa_certificate(
    test_id: str,
    x_actor_id: str = Header('OFFICER-01'),
    x_role: str = Header('officer')
):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute('SELECT * FROM server_records WHERE test_id = ?', (test_id,))
    row = c.fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail='Record not found.')

    record_dict = dict(row)
    pdf_path = forensic_engine.generate_bsa_section_63_certificate(record_dict, supervisor_id=x_actor_id)
    log_audit_event(x_actor_id, x_role, 'EXPORT_BSA_CERTIFICATE', test_id)
    return FileResponse(pdf_path, media_type='application/pdf', filename=f'BSA_Sec63_{test_id}.pdf')

@app.get('/records/{test_id}/watermarked-image')
def download_watermarked_image(
    test_id: str,
    purpose: str = 'Magistrate Court Submission',
    x_actor_id: str = Header('OFFICER-01'),
    x_role: str = Header('officer')
):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute('SELECT image_stored_path FROM server_records WHERE test_id = ?', (test_id,))
    row = c.fetchone()
    conn.close()

    if not row or not row['image_stored_path'] or not os.path.exists(row['image_stored_path']):
        raise HTTPException(status_code=404, detail='Verified image not found on server.')

    wm_path = forensic_engine.embed_steganographic_watermark(row['image_stored_path'], x_actor_id, purpose)
    log_audit_event(x_actor_id, x_role, 'EXPORT_WATERMARKED_IMAGE', f'{test_id} for {purpose}')
    return FileResponse(wm_path, media_type='image/png', filename=f'WM_{test_id}.png')

class DeviceProvisionPayload(BaseModel):
    device_id: str
    hardware_key_fingerprint: str
    assigned_officer: str
    issued_card_serials: List[str] = []
    status: str = "ACTIVE"

@app.post('/devices/provision')
def provision_device(
    payload: DeviceProvisionPayload,
    x_actor_id: str = Header('ADMIN-01'),
    x_role: str = Header('admin')
):
    if x_role.lower() != 'admin':
        raise HTTPException(status_code=403, detail='Device provisioning requires Admin role authority.')
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS provisioned_devices (
        device_id TEXT PRIMARY KEY,
        hardware_key_fingerprint TEXT,
        assigned_officer TEXT,
        issued_cards TEXT,
        status TEXT,
        provisioned_at REAL
    )''')
    c.execute('''INSERT OR REPLACE INTO provisioned_devices 
        (device_id, hardware_key_fingerprint, assigned_officer, issued_cards, status, provisioned_at)
        VALUES (?, ?, ?, ?, ?, ?)''',
        (payload.device_id, payload.hardware_key_fingerprint, payload.assigned_officer, json.dumps(payload.issued_card_serials), payload.status, time.time())
    )
    conn.commit()
    conn.close()
    log_audit_event(x_actor_id, x_role, 'PROVISION_DEVICE', payload.device_id)
    return {'status': 'PROVISIONED', 'device_id': payload.device_id, 'assigned_officer': payload.assigned_officer}

# Verbatim Section 5 Key Endpoint Route Aliases
@app.post('/anchor/merkle')
def anchor_merkle_alias(x_actor_id: str = Header('CRON-BATCHER'), x_role: str = Header('supervisor')):
    return trigger_merkle_batch(x_actor_id, x_role)

@app.get('/audit')
def audit_alias(x_actor_id: str = Header('AUDITOR-01'), x_role: str = Header('auditor')):
    return get_audit_trail(x_actor_id, x_role)

@app.get('/records')
def get_records_alias(query: Optional[str] = None, kit_type: Optional[str] = None, x_officer_id: str = Header('OFFICER-01'), x_role: str = Header('officer')):
    return search_records(query, kit_type, x_officer_id, x_role)

@app.post('/records/{test_id}/export')
def export_record_alias(test_id: str, purpose: str = 'Magistrate Court Submission', x_actor_id: str = Header('OFFICER-01'), x_role: str = Header('officer')):
    return download_bsa_certificate(test_id, x_actor_id, x_role)

@app.get('/portal')
@app.get('/')
def serve_portal():
    portal_path = os.path.join(os.path.dirname(__file__), '..', 'web_portal', 'index.html')
    if os.path.exists(portal_path):
        return FileResponse(portal_path, media_type='text/html')
    return FileResponse('web_portal/index.html', media_type='text/html')

@app.get('/app_logo.png')
def serve_logo():
    logo_path = os.path.join(os.path.dirname(__file__), '..', 'app_logo.png')
    if os.path.exists(logo_path):
        return FileResponse(logo_path, media_type='image/png')
    return FileResponse('app_logo.png', media_type='image/png')



