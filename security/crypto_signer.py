"""
SIH26231 - Cryptographic Ledger & Dual-Bound Signature Module
Part 1: Key Management and Signing

Implements:
1. Device Hardware Key (ECDSA P-256) simulation/interop (Keystore / Secure Enclave).
2. Officer Key derivation via PBKDF2 (SHA-256, 100,000 rounds) from PIN + salt.
3. Dual-bound signature creation and verification.
"""

import os
import hmac
import hashlib
import json
from typing import Tuple, Dict, Any, Optional
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

class CryptoSigner:
    def __init__(self, key_dir: str = "security/keys"):
        self.key_dir = key_dir
        os.makedirs(self.key_dir, exist_ok=True)
        self.device_private_key_path = os.path.join(self.key_dir, "device_p256_private.pem")
        self.device_public_key_path = os.path.join(self.key_dir, "device_p256_public.pem")
        self._init_device_key()

    def _init_device_key(self):
        """Loads or generates hardware-bound ECDSA P-256 key pair."""
        if os.path.exists(self.device_private_key_path):
            with open(self.device_private_key_path, "rb") as f:
                self.device_private_key = serialization.load_pem_private_key(f.read(), password=None)
        else:
            self.device_private_key = ec.generate_private_key(ec.SECP256R1())
            with open(self.device_private_key_path, "wb") as f:
                f.write(self.device_private_key.private_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PrivateFormat.PKCS8,
                    encryption_algorithm=serialization.NoEncryption()
                ))
            with open(self.device_public_key_path, "wb") as f:
                f.write(self.device_private_key.public_key().public_bytes(
                    encoding=serialization.Encoding.PEM,
                    format=serialization.PublicFormat.SubjectPublicKeyInfo
                ))

    def get_device_public_key_pem(self) -> str:
        return self.device_private_key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        ).decode("utf-8")

    def derive_officer_key(self, officer_pin: str, salt: bytes) -> bytes:
        """Derives a deterministic 256-bit signing key from the officer's secret PIN."""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100_000
        )
        return kdf.derive(officer_pin.encode("utf-8"))

    def dual_sign_record(self, canonical_payload: bytes, officer_pin: str, officer_id: str) -> Dict[str, Any]:
        """Signs payload with both the Device Hardware Key (ECDSA P-256) and Officer Key (HMAC-SHA256)."""
        device_signature = self.device_private_key.sign(
            canonical_payload,
            ec.ECDSA(hashes.SHA256())
        )

        salt = hashlib.sha256(officer_id.encode("utf-8")).digest()[:16]
        officer_key = self.derive_officer_key(officer_pin, salt)
        officer_signature = hmac.new(officer_key, canonical_payload, hashlib.sha256).hexdigest()

        return {
            "device_signature_hex": device_signature.hex(),
            "device_public_key_pem": self.get_device_public_key_pem(),
            "officer_id": officer_id,
            "officer_signature_hex": officer_signature,
            "signature_scheme": "ECDSA_P256_WITH_SHA256 + PBKDF2_HMAC_SHA256"
        }

    def verify_signatures(self, canonical_payload: bytes, sig_bundle: Dict[str, Any], officer_pin: str) -> Dict[str, bool]:
        """Verifies both signatures independently."""
        # 1. Verify Device ECDSA Signature
        device_sig = bytes.fromhex(sig_bundle["device_signature_hex"])
        pub_key = serialization.load_pem_public_key(sig_bundle["device_public_key_pem"].encode("utf-8"))
        
        try:
            pub_key.verify(device_sig, canonical_payload, ec.ECDSA(hashes.SHA256()))
            device_valid = True
        except Exception:
            device_valid = False

        # 2. Verify Officer Signature
        salt = hashlib.sha256(sig_bundle["officer_id"].encode("utf-8")).digest()[:16]
        officer_key = self.derive_officer_key(officer_pin, salt)
        expected_officer_sig = hmac.new(officer_key, canonical_payload, hashlib.sha256).hexdigest()
        officer_valid = hmac.compare_digest(expected_officer_sig, sig_bundle["officer_signature_hex"])

        return {
            "device_signature_valid": device_valid,
            "officer_signature_valid": officer_valid,
            "all_valid": device_valid and officer_valid
        }
