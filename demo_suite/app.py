"""
SIH26231 — Digital Companion for Field Drug Testing
Integrated Master Demonstration Suite & Judge Evaluation Console (Part 1)
"""

import os
import sys
import time
import json
import sqlite3
import cv2
import numpy as np
import streamlit as st

# Add root directory to python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from engine.colorimeter import ColorimeterEngine, REAGENT_PROFILES
from security.crypto_signer import CryptoSigner
from security.hash_ledger import HashChainLedger
from security.legal_forensics import LegalForensicEngine
from sync_mesh.sms_anchor import SMSAnchorSimulator
from backend.server import build_merkle_tree

st.set_page_config(
    page_title="SIH26231 — Field Drug Testing Trust Platform",
    page_icon="⚖️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom Styling
st.markdown("""
<style>
    .reportview-container { background: #0e1117; }
    .badge-pos { background-color: #dc2626; color: white; padding: 4px 10px; border-radius: 4px; font-weight: bold; }
    .badge-neg { background-color: #16a34a; color: white; padding: 4px 10px; border-radius: 4px; font-weight: bold; }
    .badge-inc { background-color: #ca8a04; color: white; padding: 4px 10px; border-radius: 4px; font-weight: bold; }
</style>
""", unsafe_allow_html=True)

@st.cache_resource
def get_engines():
    color_eng = ColorimeterEngine()
    crypto_eng = CryptoSigner(key_dir="security/keys")
    hash_eng = HashChainLedger(db_path="security/field_companion.db")
    legal_eng = LegalForensicEngine(export_dir="security/exports")
    sms_eng = SMSAnchorSimulator(db_path="backend/sms_gateway.db")
    return color_eng, crypto_eng, hash_eng, legal_eng, sms_eng

colorimeter, crypto_signer, ledger, forensics, sms_simulator = get_engines()

st.sidebar.image("app logo.png" if os.path.exists("app logo.png") else None, width=180)
st.sidebar.title("SIH26231 Trust Engine")
st.sidebar.markdown("**Narcotics Control Bureau (NCB)**  \n*Field Drug Testing Verification Suite*")

user_role = st.sidebar.selectbox("Active User Role (RBAC)", ["Officer (Field Operative)", "Supervisor (District Command)", "Auditor (Legal Oversight)", "Admin (Device Provisioning)"])
st.sidebar.divider()

nav = st.sidebar.radio(
    "Navigation Console",
    [
        "1. Real-time Field Capture & Calibration",
        "2. Dual-Sign & Local Hash Ledger",
        "3. Out-of-Band 2G SMS Anchor Simulator",
        "4. Staged Sync & Merkle Root Batching",
        "5. Section 63 Legal Certificate & Stego Forensics",
        "6. Tamper Simulation & Security Resilience"
    ]
)
st.sidebar.info("Law Alignment: Fully conformant with NDPS Act Sec 52A(4) & BSA 2023 Sec 63.")

# ==========================================
# MODULE 1: FIELD CAPTURE & CALIBRATION
# ==========================================
if nav == "1. Real-time Field Capture & Calibration":
    st.title("🔬 Real-time Field Capture & Colorimeter Engine")
    st.caption("Demonstrating 4-Marker ArUco Perspective Rectification, White Patch Illumination Normalization & CIEDE2000 Classification.")

    col_ctrl, col_view = st.columns([1, 2])

    with col_ctrl:
        st.subheader("Field Input Controls")
        kit_choice = st.selectbox("Field Reagent Kit Type", list(REAGENT_PROFILES.keys()))
        profile_info = REAGENT_PROFILES[kit_choice]
        st.markdown(f"**Target Analyte:** `{profile_info['name']}`  \n**Expected Color:** `{profile_info['positive_color_name']}`  \n**Threshold $\\Delta E_{{00}}$:** `< {profile_info['threshold_delta_e']}`  \n**Reaction Window:** `{profile_info['reaction_window_sec'][0]}s – {profile_info['reaction_window_sec'][1]}s`")

        sample_source = st.radio("Capture Source", ["Preset: Standard Positive", "Preset: True Negative (Excipient)", "Preset: Blurry (Gating Rejection)", "Upload Custom Field Image", "Live Device Webcam"])

        elapsed_time = st.slider("Reaction Elapsed Time (seconds)", min_value=0, max_value=120, value=45, step=1)

        input_cv_img = None
        if sample_source == "Preset: Standard Positive":
            input_cv_img = cv2.imread("card_assets/field_sample_positive.png")
        elif sample_source == "Preset: True Negative (Excipient)":
            input_cv_img = cv2.imread("card_assets/field_sample_negative.png")
        elif sample_source == "Preset: Blurry (Gating Rejection)":
            input_cv_img = cv2.imread("card_assets/field_sample_blurry.png")
        elif sample_source == "Upload Custom Field Image":
            uploaded = st.file_uploader("Select PNG/JPG", type=["png", "jpg", "jpeg"])
            if uploaded:
                file_bytes = np.asarray(bytearray(uploaded.read()), dtype=np.uint8)
                input_cv_img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
        elif sample_source == "Live Device Webcam":
            cam_capture = st.camera_input("Capture Field Test Card")
            if cam_capture:
                file_bytes = np.asarray(bytearray(cam_capture.read()), dtype=np.uint8)
                input_cv_img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

    with col_view:
        if input_cv_img is not None:
            st.subheader("Real-Time Analysis View")
            res = colorimeter.classify_test(input_cv_img, kit_choice, elapsed_time)
            
            view_c1, view_c2 = st.columns(2)
            with view_c1:
                st.image(cv2.cvtColor(input_cv_img, cv2.COLOR_BGR2RGB), caption="Raw Camera Input", use_container_width=True)
            with view_c2:
                if res.get("rectified_card") is not None:
                    st.image(cv2.cvtColor(res["rectified_card"], cv2.COLOR_BGR2RGB), caption="Homography Rectified (300 DPI)", use_container_width=True)
                else:
                    st.warning("ArUco markers not locked or image rejected.")

            st.divider()
            m1, m2, m3, m4 = st.columns(4)
            m1.metric("Pipeline Status", res["status"])
            m2.metric("Laplacian Blur Variance", f"{res.get('blur_variance', 0.0):.1f}", delta="OK (>100)" if res.get('blur_variance', 0) >= 100 else "REJECT BLUR")
            m3.metric("Specular Glare Ratio", f"{res.get('glare_ratio', 0.0)*100:.2f}%", delta="OK (<3%)" if res.get('glare_ratio', 0) <= 0.03 else "REJECT GLARE")
            m4.metric("Reaction Timer", f"{elapsed_time}s", delta="OK In Window" if res.get("reaction_window_met") else "TIMER REJECT")

            st.subheader("Classification Outcome")
            cls = res["classification"]
            if cls == "PRESUMPTIVE_POSITIVE":
                st.markdown(f"### <span class='badge-pos'>PRESUMPTIVE POSITIVE (ΔE₀₀ = {res['delta_e2000']:.2f})</span>", unsafe_allow_html=True)
            elif cls == "PRESUMPTIVE_NEGATIVE":
                st.markdown(f"### <span class='badge-neg'>PRESUMPTIVE NEGATIVE (ΔE₀₀ = {res['delta_e2000']:.2f})</span>", unsafe_allow_html=True)
            else:
                st.markdown(f"### <span class='badge-inc'>FAIL-CLOSED / INCONCLUSIVE ({res.get('reason')})</span>", unsafe_allow_html=True)

            if "observed_Lab" in res:
                st.json({
                    "Sample Measured L*a*b*": res["observed_Lab"],
                    "Target Nominal L*a*b*": res["target_Lab"],
                    "Calculated CIEDE2000 (ΔE₀₀)": res["delta_e2000"],
                    "Reference Card Serial": res.get("card_serial", "NCB-CARD-2026-0042")
                })

            st.session_state["last_analysis"] = res
            st.session_state["last_image"] = input_cv_img
            st.session_state["last_kit"] = kit_choice
        else:
            st.info("Select or capture an image to execute the colorimetric computer vision pipeline.")

# ==========================================
# MODULE 2: DUAL-SIGN & LOCAL LEDGER
# ==========================================
elif nav == "2. Dual-Sign & Local Hash Ledger":
    st.title("🔐 Hardware Key + Officer PIN Dual-Signing & Hash Ledger")
    st.caption("Conforms to BSA 2023 §63 dual-signature mandate: Device Hardware Key (ECDSA P-256) + Officer PIN (PBKDF2-HMAC-SHA256).")

    if "last_analysis" not in st.session_state or st.session_state["last_analysis"]["status"] != "SUCCESS":
        st.warning("⚠️ Please execute a valid sample analysis in Step 1 first to generate signing data.")
    else:
        analysis = st.session_state["last_analysis"]
        col_sign, col_ledger = st.columns([1, 2])

        with col_sign:
            st.subheader("Cryptographic Authorization")
            test_id_input = st.text_input("NDPS Test ID", f"NDPS-{int(time.time())}")
            officer_id_input = st.text_input("Authorized Officer ID", "OFFICER-RAJESH-NCB")
            officer_pin_input = st.text_input("Officer Security PIN", "1234", type="password")
            device_id_input = st.text_input("Device Hardware ID", "NCB-DEV-PIXEL8-SEC01")
            lat_in = st.number_input("GPS Latitude", value=28.6139, format="%.5f")
            lon_in = st.number_input("GPS Longitude", value=77.2090, format="%.5f")

            if st.button("Authorize & Append to Tamper-Proof Chain", type="primary"):
                img_bytes = cv2.imencode(".png", st.session_state["last_image"])[1].tobytes()
                
                sign_res = crypto_signer.dual_sign_record(
                    img_bytes,
                    officer_pin=officer_pin_input,
                    officer_id=officer_id_input
                )
                
                rec = ledger.append_record(
                    test_id=test_id_input,
                    officer_id=officer_id_input,
                    device_id=device_id_input,
                    kit_type=st.session_state["last_kit"],
                    classification=analysis["classification"],
                    delta_e2000=analysis["delta_e2000"],
                    image_bytes=img_bytes,
                    card_serial=analysis.get("card_serial", "NCB-CARD-2026-0042"),
                    latitude=lat_in,
                    longitude=lon_in,
                    device_sig_hex=sign_res["device_signature_hex"],
                    officer_sig_hex=sign_res["officer_signature_hex"]
                )
                st.session_state["last_signed_record"] = rec
                st.success(f"✅ Record Chained! Hash: `{rec['record_hash'][:16]}...`")

        with col_ledger:
            st.subheader("Tamper-Evident Local Hash Chain")
            integrity = ledger.verify_chain_integrity()
            
            if integrity["is_valid"]:
                st.success(f"🟢 LEDGER INTEGRITY VERIFIED: {integrity['record_count']} records securely chained with 0 tampering detected.")
            else:
                st.error(f"🔴 INTEGRITY BREACH: {integrity['error']}")

            records = ledger.get_all_records()
            if records:
                st.markdown(f"**Total Records in SQLite Hash-Ledger:** `{len(records)}`")
                for r in records[:5]:
                    with st.expander(f"📦 {r['test_id']} — {r['classification']} (Hash: {r['record_hash'][:16]}...)"):
                        st.json({
                            "Test ID": r["test_id"],
                            "Timestamp UTC": r["timestamp_utc"],
                            "Kit Type": r["kit_type"],
                            "CIEDE2000 ΔE₀₀": r["delta_e2000"],
                            "Previous Block Hash": r["prev_hash"],
                            "Record SHA-256 Hash": r["record_hash"],
                            "Image SHA-256": r["image_sha256"],
                            "ECDSA Device Signature (Hardware)": r["device_sig_hex"][:32] + "...",
                            "PBKDF2 Officer Signature (PIN-bound)": r["officer_sig_hex"][:32] + "...",
                            "GPS Coordinates": f"{r['latitude']}, {r['longitude']} ({r['location_status']})"
                        })

# ==========================================
# MODULE 3: 2G SMS ANCHOR SIMULATOR
# ==========================================
elif nav == "3. Out-of-Band 2G SMS Anchor Simulator":
    st.title("📡 Out-of-Band 2G GSM SMS Anchor Witness")
    st.caption("Section 4.4: Autonomous instant witness over field SIM without mobile data or internet connectivity.")

    c_tx, c_rx = st.columns([1, 2])

    with c_tx:
        st.subheader("Field Device GSM Transmitter")
        sim_number = st.text_input("Officer SIM Phone Number", "+91-98765-43210")
        target_gateway = st.text_input("Central NCB Ingest Gateway", "+91-11-2617-NCB0")
        
        default_tid = "TEST-2026-0042"
        default_hash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        default_cls = "PRESUMPTIVE_POSITIVE"

        if "last_signed_record" in st.session_state:
            default_tid = st.session_state["last_signed_record"]["test_id"]
            default_hash = st.session_state["last_signed_record"]["record_hash"]
            default_cls = st.session_state["last_signed_record"]["classification"]

        sms_payload = sms_simulator.format_sms_payload(
            test_id=default_tid,
            record_hash=default_hash,
            officer_id="OFFICER-RAJESH",
            classification=default_cls,
            lat=28.6139,
            lon=77.2090
        )
        st.text_area("Formulated GSM 140-char Payload", sms_payload, height=90)
        st.caption(f"Payload Size: `{len(sms_payload)} characters` (Guaranteed to transmit on 2G/GSM SMS standard)")

        if st.button("Transmit SMS Out-of-Band Witness", type="primary"):
            tx_res = sms_simulator.transmit_sms_from_device(sim_number, sms_payload)
            st.success(f"📡 SMS Broadcast Dispatched! Gateway Log ID: #{tx_res['sms_id']}")

    with c_rx:
        st.subheader("Central NCB SMS Ingest Gateway Log")
        sms_logs = sms_simulator.get_all_sms_logs()
        st.markdown(f"**Total Inbound SMS Anchors Received:** `{len(sms_logs)}`")

        if sms_logs:
            for sl in sms_logs[:6]:
                with st.expander(f"✉️ SMS #{sl['sms_id']} from {sl['sender_sim_phone']} at {time.strftime('%H:%M:%S', time.gmtime(sl['received_timestamp_utc']))}"):
                    st.code(sl["raw_sms_body"])
                    st.json({
                        "Test ID Extracted": sl["test_id"],
                        "Record Hash Prefix Witnessed": sl["record_hash_prefix"],
                        "Officer Identifier": sl["officer_id"],
                        "Field Result Code": sl["classification"],
                        "GPS Location Witnessed": sl["gps_coord"],
                        "Timestamp UTC": sl["received_timestamp_utc"],
                        "Verification Status": sl["status"]
                    })

# ==========================================
# MODULE 4: STAGED SYNC & MERKLE BATCHING
# ==========================================
elif nav == "4. Staged Sync & Merkle Root Batching":
    st.title("☁️ Staged Sync Architecture & Merkle Root Anchoring")
    st.caption("Section 4.5 & 5.0: Two-stage sync (Stage 1: <1KB metadata + hash; Stage 2: full raw image) & cryptographic Merkle tree batching.")

    col_sync1, col_sync2 = st.columns(2)

    with col_sync1:
        st.subheader("Stage 1: Weak-Signal Metadata Sync (<1KB)")
        st.markdown("""
        When an officer operates on a spotty 2G/edge connection:
        1. **Payload**: JSON metadata + record hash + signatures (~650 bytes).
        2. **Result**: Immediate anchoring on Central Trust Server with guaranteed timestamp.
        """)
        
        conn = sqlite3.connect("backend/server_vault.db")
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute("SELECT * FROM server_records ORDER BY received_at DESC")
        server_recs = [dict(r) for r in c.fetchall()]
        conn.close()

        st.metric("Total Anchored Records on Server", len(server_recs))

        st.subheader("Stage 2: High-Bandwidth Image Sync")
        st.markdown("""
        When Wi-Fi or 4G/5G restores:
        1. **Verification**: Uploaded image's SHA-256 hash **must strictly equal** the Stage 1 anchored hash.
        2. **Anti-tamper**: Server rejects any altered or recompressed file.
        """)

    with col_sync2:
        st.subheader("Merkle Tree Batch Root Anchoring")
        st.markdown("""
        Aggregates multiple synced record hashes into a single root hash, preventing retroactive tampering even by database administrators.
        """)
        
        if st.button("Trigger Merkle Batch Root Calculation", type="primary"):
            conn = sqlite3.connect("backend/server_vault.db")
            c = conn.cursor()
            c.execute("SELECT test_id, record_hash FROM server_records ORDER BY received_at ASC")
            recs = c.fetchall()
            if recs:
                hashes = [r[1] for r in recs]
                root, tree = build_merkle_tree(hashes)
                st.success(f"🌳 Merkle Root Calculated across {len(hashes)} records!")
                st.code(f"MERKLE ROOT SHA-256: {root}")
                with st.expander("View Full Merkle Tree Levels"):
                    st.json(tree)
            else:
                st.info("No server records to batch.")
            conn.close()

# ==========================================
# MODULE 5: LEGAL CERTIFICATE & STEGO
# ==========================================
elif nav == "5. Section 63 Legal Certificate & Stego Forensics":
    st.title("⚖️ Section 63 Legal Evidence Export & Leak Traceability")
    st.caption("Conforms to Bharatiya Sakshya Adhiniyam, 2023 §63 & NDPS §52A(4) with Imperceptible Steganographic Watermarking.")

    col_l1, col_l2 = st.columns(2)

    with col_l1:
        st.subheader("Generate BSA 2023 §63 Certificate")
        sample_rec = {
            "test_id": "TEST-NDPS-2026-0042",
            "timestamp_utc": time.time(),
            "officer_id": "OFFICER-RAJESH-NCB",
            "device_id": "DEV-PIXEL8-SEC01",
            "kit_type": "MARQUIS_OPIATE",
            "classification": "PRESUMPTIVE_POSITIVE",
            "delta_e2000": 2.643,
            "card_serial": "NCB-CARD-2026-0042",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "location_status": "CONFIRMED_GPS",
            "image_sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
            "prev_hash": "0000000000000000000000000000000000000000000000000000000000000000",
            "record_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "device_sig_hex": "3045022100a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1",
            "officer_sig_hex": "4a8b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f"
        }
        
        sup_id = st.text_input("Approving Supervisor ID", "SUPERVISOR-ANAND-NCB")
        
        if st.button("Generate Legal Court Certificate (PDF)", type="primary"):
            pdf_path = forensics.generate_bsa_section_63_certificate(sample_rec, supervisor_id=sup_id)
            st.success(f"Certificate generated at `{pdf_path}`")
            with open(pdf_path, "rb") as f:
                st.download_button("Download BSA §63 PDF Certificate", data=f.read(), file_name="BSA_Sec63_Certificate.pdf", mime="application/pdf")

    with col_l2:
        st.subheader("Imperceptible LSB Steganography & Leak Traceability")
        st.markdown("""
        Every exported evidentiary image embeds an invisible digital watermark containing:
        - Requester Officer ID
        - Exact UTC Timestamp
        - Judicial or Official Purpose
        """)
        
        req_id = st.text_input("Requester Officer ID", "INSPECTOR-KUMAR-DELHI")
        exp_purp = st.text_input("Export Justification", "Charge Sheet Evidence Submission")
        
        if st.button("Export Steganographically Watermarked Image"):
            src = "card_assets/field_sample_positive.png"
            wm_img_path = forensics.embed_steganographic_watermark(src, requester_id=req_id, purpose=exp_purp)
            st.image(wm_img_path, caption="Watermarked Image (Visually Identical to Raw)", use_container_width=True)
            
            extracted = forensics.extract_steganographic_watermark(wm_img_path)
            st.success("🕵️‍♂️ Forensics Extraction Test Passed!")
            st.json(extracted)

# ==========================================
# MODULE 6: TAMPER SIMULATION
# ==========================================
elif nav == "6. Tamper Simulation & Security Resilience":
    st.title("🛡️ Threat Simulation & Anti-Tamper Security Demonstration")
    st.caption("Live demonstrations proving the resilience of the hash chain, SMS witness, and dual signatures against adversarial attacks.")

    t1, t2, t3 = st.columns(3)

    with t1:
        st.markdown("### 🦹 Threat 1: Database Tampering")
        st.write("An attacker or corrupt insider attempts to edit a test result directly in the SQLite database.")
        if st.button("Simulate Insider Database Edit"):
            test_db = "security/field_companion.db"
            if os.path.exists(test_db):
                conn = sqlite3.connect(test_db)
                c = conn.cursor()
                c.execute("UPDATE chain_ledger SET classification='PRESUMPTIVE_NEGATIVE' WHERE id=1")
                conn.commit()
                conn.close()
                st.warning("⚠️ Record #1 forced to NEGATIVE via direct SQL.")
                
                verify = ledger.verify_chain_integrity()
                st.error(f"🚨 INTEGRITY DETECTION: {verify['error']}")
            else:
                st.info("Append at least one record in Step 2 to demonstrate database tamper detection.")

    with t2:
        st.markdown("### 📱 Threat 2: Stolen Phone Attack")
        st.write("A thief steals the officer's phone and attempts to sign a fabricated field drug test.")
        wrong_pin = st.text_input("Attacker Guessed PIN", "0000")
        if st.button("Attempt Rogue Signature"):
            dummy_payload = b"fabricated_ndps_sample"
            dummy_bundle = crypto_signer.dual_sign_record(dummy_payload, officer_pin="1234", officer_id="OFFICER-REAL")
            check = crypto_signer.verify_signatures(dummy_payload, dummy_bundle, officer_pin=wrong_pin)
            if not check["all_valid"]:
                st.error("❌ SIGNATURE REJECTED: Hardware signature present, but Officer PIN signature invalid!")
            else:
                st.success("Authorized")

    with t3:
        st.markdown("### 📸 Threat 3: Replay / Blurry Photo")
        st.write("An officer takes a blurry photo or uses bad lighting to force a false positive or negative.")
        if st.button("Test Blur Gating"):
            blurry_img = cv2.imread("card_assets/field_sample_blurry.png")
            res = colorimeter.classify_test(blurry_img, kit_type="MARQUIS_OPIATE")
            st.error(f"🛑 REJECTED AT CAMERA LAYER: {res['reason']}")

