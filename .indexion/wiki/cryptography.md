# Cryptography

The `src/crypto/` and `src/encryption/` packages provide PDF encryption support, all implemented in pure MoonBit.

## Primitives (`src/crypto/`)

| Algorithm | File | Purpose |
|-----------|------|---------|
| AES-128 block cipher | `aes.mbt` | `aes_encrypt_block`/`aes_decrypt_block`, 10-14 rounds, SubBytes/ShiftRows/MixColumns/AddRoundKey |
| AES-CBC mode | `aes_modes.mbt` | CBC encrypt/decrypt with PKCS#7 padding for stream/string encryption |
| RC4 stream cipher | `rc4.mbt` | Key Scheduling Algorithm + PRGA, used by §7.6 revision 2-4 |
| MD5 digest | `md5.mbt` | RFC 1321, 64-round compression, used for password validation and key derivation |
| SHA-256/384/512 | `sha2.mbt` | FIPS 180-4, used by §7.6 revision 6 encryption |
| PKCS#7 padding | `padding.mbt` | Block cipher padding/unpadding |
| Byte utilities | `bytes.mbt` | XOR, concatenation, constant-time comparison |

## Encryption Type Model (`src/encryption/`)

Defines the type model for PDF standard and public-key security handlers: encryption dictionary parsing, permission flags (printing, copying, modifying), authentication/decryption workflow types. Covers §7.6 standard security handler revisions 2 through 6.

## See Also

- wiki://file-reading
- wiki://overview
