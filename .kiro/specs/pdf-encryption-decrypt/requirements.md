# SDD Draft: PDF Decryption

Reference: ISO 32000-2 §7.6

## Requirements

### Requirement 1: Standard security handler authentication
The reader SHALL authenticate against the Standard security handler
(revision 2, 3, 4, 5, 6) using owner or user passwords.

#### 1.1: Password verification
Given an Encrypt dictionary with /Filter /Standard, the reader SHALL
compute the encryption key using the password, /O, /U, /P values and
verify the password against /U (user) and /O (owner) entries.

#### 1.2: Revision 2-4 key derivation
For revisions 2-4, the reader SHALL derive the encryption key using
MD5-based key derivation per §7.6.3.3 (Algorithm 2).

#### 1.3: Revision 5-6 key derivation (AES-256)
For revisions 5-6, the reader SHALL derive the encryption key using
SHA-256/SHA-384/SHA-512 based key derivation per §7.6.3.3 (Algorithm 2.A/2.B).

### Requirement 2: String and stream decryption
The reader SHALL decrypt encrypted strings and streams using the
derived encryption key.

#### 2.1: RC4 decryption (V=1, V=2)
For encryption versions 1 and 2, the reader SHALL decrypt streams and
strings using RC4 with the per-object encryption key derived from the
file encryption key + object number + generation number.

#### 2.2: AES-128 decryption (V=4)
For encryption version 4 with /CFM /AESV2, the reader SHALL decrypt
using AES-128-CBC with the initialization vector from the first 16
bytes of the encrypted data.

#### 2.3: AES-256 decryption (V=5)
For encryption version 5 with /CFM /AESV3, the reader SHALL decrypt
using AES-256-CBC.

### Requirement 3: Transparent decryption in object loading
`PdfFile::load_object` SHALL transparently decrypt strings and streams
when the document is encrypted, so that all downstream consumers
(text extraction, image extraction, etc.) receive decrypted data
without explicit decrypt calls.

### Requirement 4: Permission flags
The reader SHALL parse the /P permission flags and expose them so
callers can check printing, copying, and modification permissions.
