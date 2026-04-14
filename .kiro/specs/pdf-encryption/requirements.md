# SDD Draft

Generated from:
- `spec/extracted/7.6-encryption.spec.txt`

## Requirements

#### 0.1: 7.6.1 General
A PDF file can be encrypted (PDF 1.1) to protect its contents from unauthorised access.

#### 0.2: 7.6.2 Application of encryption
Encryption applies to all strings and streams in the document's PDF file, with the following exceptions:
•    The values for the ID entry in the trailer
•    Any strings in an Encrypt dictionary
•    Any strings that are inside streams such as content streams and compressed object streams,
which themselves are encrypted
•    Any hexadecimal strings representing the value of the Contents key in a Signature dictionary
Encryption is not applied to other object types such as integers and boolean values, which are used
primarily to convey information about the document's structure rather than its contents. Leaving these
values unencrypted allows random access to the objects within a document, whereas encrypting the
strings and streams protects the document's contents.
When a PDF stream object (see 7.3.8, "Stream objects") refers to an external file, the stream’s contents
shall not be encrypted, since they are not part of the PDF file itself. However, if the contents of the
stream are embedded within the PDF file (see 7.11.4, "Embedded file streams"), they shall be
encrypted like any other stream in the file. Beginning with PDF 1.5, embedded files can be encrypted in
an otherwise unencrypted document (see 7.6.6, "Crypt filters").
Encryption-related information shall be stored in a document’s encryption dictionary, which shall be
the value of the Encrypt entry in the document’s trailer dictionary (see "Table 15 — Entries in the file
trailer dictionary"). The absence of this entry from the trailer dictionary means that a PDF processor
shall consider the document to be not encrypted. The entries shown in "Table 20 — Entries common to
all encryption dictionaries" are common to all encryption dictionaries. For document with multiple
versions the Encrypt entry should be identical in all copies of the trailer.
The encryption dictionary’s Filter entry identifies the file’s security handler, a software module that
implements various aspects of the encryption process and controls access to the contents of the
encrypted document. PDF specifies a standard password-based security handler that all PDF
processors shall support, but PDF processors can optionally provide additional security handlers of
their own.
The SubFilter entry specifies the syntax of the encryption dictionary contents. It allows
interoperability between handlers; that is, a document can be decrypted by a handler other than the
preferred one (the Filter entry) if they both support the format specified by SubFilter.
The V entry, in specifying which algorithm to use, determines the length of the file encryption key, on
which the encryption (and decryption) of data in a PDF file shall be based. For V values 2 and 3, the
Length entry specifies the exact length of the file encryption key. In PDF 1.5, a value of 4 for V permits
the security handler to use its own encryption and decryption algorithms and to specify crypt filters
with a key length of 128 bits (16 bytes) to use on specific streams (see 7.6.6, "Crypt filters"). A value of
5 for V permits the specification of crypt filters with a file encryption key length of 256 bits (32 bytes).
Values less than 5 for the V entry are deprecated in PDF 2.0.
The remaining contents of the encryption dictionary shall be determined by the security handler and
may vary from one handler to another. Entries for the standard security handler are described in 7.6.4,
"Standard security handler". Entries for public-key security handlers are described in 7.6.5, "Public-key
security handlers".
Table 20 — Entries common to all encryption dictionaries
Key      Type        Value
Filter   name        (Required) The name of the preferred security handler for this document. It shall
be the name of the security handler that was used to encrypt the document. If
SubFilter is not present, only this security handler shall be used when opening
the document. If it is present, a PDF processor can use any security handler that
implements the format specified by SubFilter.
Standard shall be the name of the built-in password-based security handler.
Names for other security handlers may be registered by using the procedure
described in Annex E, "Extending PDF".
SubFilter name       (Optional; PDF 1.3) A name that completely specifies the format and
interpretation of the contents of the encryption dictionary. It allows security
handlers other than the one specified by Filter to decrypt the document. If this
entry is absent, other security handlers shall not decrypt the document.

Key          Type          Value
V            integer       (Required) A code specifying the algorithm to be used in encrypting and
decrypting the document:
0    An algorithm that is undocumented. This value shall not be used.
1    (Deprecated in PDF 2.0) Indicates the use of 7.6.3.2, "Algorithm 1: Encryption
of data using the RC4 or AES algorithms" (deprecated in PDF 2.0) with a file
encryption key length of 40 bits; see below.
2    (PDF 1.4; deprecated in PDF 2.0) Indicates the use of 7.6.3.2, "Algorithm 1:
Encryption of data using the RC4 or AES algorithms" (deprecated in PDF 2.0)
but permitting file encryption key lengths greater than 40 bits.
3    (PDF 1.4; deprecated in PDF 2.0) An unpublished algorithm that permits file
encryption key lengths ranging from 40 to 128 bits. This value shall not
appear in a conforming PDF file.
4    (PDF 1.5; deprecated in PDF 2.0) The security handler defines the use of
encryption and decryption in the document, using the rules specified by the
CF, StmF, and StrF entries using 7.6.3.2, "Algorithm 1: Encryption of data
using the RC4 or AES algorithms" (deprecated in PDF 2.0) with a file
encryption key length of 128 bits.
5    (PDF 2.0) The security handler defines the use of encryption and decryption
in the document, using the rules specified by the CF, StmF, StrF and EFF
entries using 7.6.3.3, "Algorithm 1.A: Encryption of data using the AES
algorithms" with a file encryption key length of 256 bits.
Length       integer       (Optional; PDF 1.4; only if V is 2 or 3; deprecated in PDF 2.0) The length of the file
encryption key, in bits. The value shall be a multiple of 8, in the range 40 to 128.
Default value: 40.
CF           dictionary    (Optional; meaningful only when the value of V is 4 (PDF 1.5) or 5 (PDF 2.0)) A
dictionary whose keys shall be crypt filter names and whose values shall be the
corresponding crypt filter dictionaries (see "Table 25 — Entries common to all
crypt filter dictionaries"). Every crypt filter used in the document shall have an
entry in this dictionary, except for the standard crypt filter names (see "Table 26
— Standard crypt filter names").
Any keys in the CF dictionary that are listed in "Table 26 — Standard crypt filter
names" shall be ignored by a PDF processor. Instead, the PDF processor shall use
properties of the respective standard crypt filters.
StmF         name          (Optional; meaningful only when the value of V is 4 (PDF 1.5) or 5 (PDF 2.0)) The
name of the crypt filter that shall be used by default when decrypting streams.
The name shall be a key in the CF dictionary or a standard crypt filter name
specified in "Table 26 — Standard crypt filter names". All streams in the
document, except for cross-reference streams (see 7.5.8, "Cross-reference
streams") or streams that have a Crypt entry in their Filter array (see "Table 6 —
Standard filters"), shall be decrypted by the security handler, using this crypt
filter.
Default value: Identity.
StrF         name          (Optional; meaningful only when the value of V is 4 (PDF 1.5) or 5 (PDF 2.0)) The
name of the crypt filter that shall be used when decrypting all strings in the
document. The name shall be a key in the CF dictionary or a standard crypt filter
name specified in "Table 26 — Standard crypt filter names".
Default value: Identity.
Key      Type          Value
EFF      name          (Optional; meaningful only when the value of V is 4 (PDF 1.6) or 5 (PDF 2.0)) The
name of the crypt filter that shall be used when encrypting embedded file streams
that do not have their own crypt filter specifier; it shall correspond to a key in the
CF dictionary or a standard crypt filter name specified in "Table 26 — Standard
crypt filter names".
This entry shall be provided by the security handler. PDF writers shall respect
this value when encrypting embedded files, except for embedded file streams that
have their own crypt filter specifier. If this entry is not present, and the embedded
file stream does not contain a crypt filter specifier, the stream shall be encrypted
using the default stream crypt filter specified by StmF.
Unlike strings within the body of the document, those in the encryption dictionary shall be direct
objects. The values of the keys defined in "Table 20 — Entries common to all encryption dictionaries"
shall not be encrypted. However, a security handler may choose to encrypt any objects that are private
to itself.
NOTE       PDF writers have two choices if the encryption methods and syntax provided by PDF are not
sufficient for their needs: they can provide an alternative security handler or they can encrypt
whole PDF files themselves, not making use of PDF security.

#### 0.3: 7.6.3.1         General
One of the following algorithms shall be used when encrypting data in a PDF file:
•    A proprietary encryption algorithm known as RC4. RC4 is a symmetric stream cipher: the same
algorithm shall be used for both encryption and decryption, and the algorithm does not change
the length of the data. RC4 is a copyrighted, proprietary algorithm of RSA Security. The use of this
algorithm in PDF 2.0 is deprecated.
NOTE 1     The name RC4™ is a registered trademark of RSA Security Inc. and cannot be used by third
parties creating implementations of the algorithm. Proprietary implementations of the RC4
encryption algorithm are available under license from RSA Security Inc. For licensing
information, contact: RSA Security Inc. 2955 Campus Drive, Suite 400, San Mateo, CA 94403-
2507, USA, or http://www.rsasecurity.com/.
•    The AES (Advanced Encryption Standard) algorithm (beginning with PDF 1.6). AES is a symmetric
block cipher: the same algorithm shall be used for both encryption and decryption, and the length
of the data when encrypted is rounded up to a multiple of the block size, which is fixed to always
be 16 bytes, as specified in FIPS 197, Advanced Encryption Standard (AES).
Strings and streams encrypted with AES shall use a padding scheme that is described in Internet RFC
8018. For an original message length of M, the pad shall consist of 16 - (M modulo 16) bytes whose
value shall also be 16 - (M modulo 16).
EXAMPLE         A 9-byte message has a pad of 7 bytes, each with the value 0x07. The pad can be unambiguously removed to
determine the original message length when decrypting. Note that the pad is present when M is evenly
divisible by 16; it contains 16 bytes of 0x10.
NOTE 2     Since Encrypt versions 1 to 4 are deprecated in PDF 2.0, this has the effect of implicitly
deprecating the use of MD5 for key generation purposes.

For Encrypt versions 1-4, as defined by the V key of the encryption dictionary, PDF’s standard
encryption methods also make use of the MD5 message-digest algorithm for key generation purposes
(described in Internet RFC 1321). Encrypt version 5 does not use MD5.
The encryption of data in a PDF file shall be based on the use of an encryption key computed by the
security handler. Different security handlers compute the encryption key using their own mechanisms.
Encryption of data uses one of two algorithms. When the value of the V key of the encryption
dictionary is 1, 2, 3 or 4 (PDF 1.7), 7.6.3.2, "Algorithm 1: Encryption of data using the RC4 or AES
algorithms" (deprecated in PDF 2.0) shall be used. When the value of the V key of the encryption
dictionary is 5 (PDF 2.0) 7.6.3.3, "Algorithm 1.A: Encryption of data using the AES algorithms" shall be
used. The difference is that Algorithm 1.A uses the starting key directly and does not modify the file
encryption key at all. Algorithm 1.A is used only with the AES algorithm and 256-bit file encryption
keys.
Algorithms in 7.6, "Encryption" are uniquely numbered within this subclause in a manner that
maintains compatibility with previous documentation.

#### 0.4: 7.6.3.2           Algorithm 1: Encryption of data using the RC4 or AES algorithms
This algorithm is deprecated in PDF 2.0.
a) Obtain the object number and generation number from the object identifier of the string or stream to be
encrypted (see 7.3.10, "Indirect objects"). If the string is a direct object, use the identifier of the indirect
object containing it.
b) For all strings and streams without crypt filter specifier; treating the object number and generation
number as binary integers, extend the original n-byte file encryption key to n + 5 bytes by appending the
low-order 3 bytes of the object number and the low-order 2 bytes of the generation number in that
order, low-order byte first. (n is 5 unless the value of V in the encryption dictionary is greater than 1, in
which case n is the value of Length divided by 8.) For example, for object number 258 and generation
number 7, the hexadecimal values 0x02 0x01 0x00 0x07 0x00 would be appended to the file encryption
key.
If using the AES algorithm, extend the file encryption key an additional 4 bytes by adding the value
"sAlT", which corresponds to the hexadecimal values 0x73, 0x41, 0x6C, 0x54. (This addition is done
for backward compatibility and is not intended to provide additional security.)
c) Initialise the MD5 hash function and pass the result of step (b) as input to this function.
d) Use the first (n + 5) bytes, up to a maximum of 16, of the output from the MD5 hash as the key for the
RC4 or AES symmetric key algorithms, along with the string or stream data to be encrypted.
If using the AES algorithm, the Cipher Block Chaining (CBC) mode, which requires an initialization
vector, is used. The block size parameter is set to 16 bytes, and the initialization vector is a 16-byte
random number that is stored as the first 16 bytes of the encrypted stream or string.
The output is the encrypted data to be stored in the PDF file.

#### 0.5: 7.6.3.3           Algorithm 1.A: Encryption of data using the AES algorithms
a) Use the 32-byte file encryption key for the AES-256 symmetric key algorithm, along with the string or
stream data to be encrypted.
Use the AES algorithm in Cipher Block Chaining (CBC) mode, which requires an initialization
vector. The block size parameter is set to 16 bytes, and the initialization vector is a 16-byte random
number that is stored as the first 16 bytes of the encrypted stream or string.
The output is the encrypted data to be stored in the PDF file.
Stream data shall be encrypted after applying all stream encoding filters and shall be decrypted before
applying any stream decoding filters. The number of bytes to be encrypted or decrypted shall be given
by the Length entry in the stream dictionary. Decryption of strings (other than those in the encryption
dictionary) shall be done after escape-sequence processing and hexadecimal decoding as appropriate
to the string representation described in 7.3.4, "String objects".

#### 0.6: 7.6.4.1         General
PDF’s standard security handler shall allow access permissions and up to two passwords to be specified
for a document: an owner password and a user password. An application’s decision to encrypt a
document shall be based on whether the user creating the document specifies any passwords or access
restrictions.
EXAMPLE         A PDF processor might have a security settings dialogue box that the user can invoke before saving the file.
If passwords or access restrictions are specified, the document shall be encrypted, and the permissions
and information required to validate the passwords shall be stored in the encryption dictionary.
Documents in which only file attachments are encrypted shall use the same user and owner passwords.
NOTE 1     A PDF processor can also create an encrypted document without any user interaction if it has
some other source of information about what passwords and permissions to use.
If a user attempts to open an encrypted document that has a user password, the PDF reader shall first
try to authenticate the encrypted document using the padding string defined in 7.6.4.3, "File
encryption key algorithm" (default user password):
•    If this authentication attempt is successful, the PDF reader may open, decrypt, render and
otherwise provide access to the document.
•    If this authentication attempt fails, the interactive PDF processor should prompt for a password.
Correctly supplying either password (owner or user password) should enable the user to gain
access to the document.
Whether additional operations shall be allowed on a decrypted document depends on which password
(if any) was supplied when the document was opened and on any access restrictions that were
specified when the document was created:
•    Opening the document with the correct owner password should allow full (owner) access to the
document. This unlimited access includes the ability to change the document’s passwords and
access permissions.
•    Opening the document with the correct user password (or opening a document with the default
password) should allow additional operations to be performed according to the user access
permissions specified in the document’s encryption dictionary.
Access permissions shall be specified in the form of flags corresponding to the various operations and
the set of operations to which they correspond shall depend on the security handler’s revision number
(also stored in the encryption dictionary). If the security handler’s revision number is 2 or greater, the

operations to which user access can be controlled shall be as follows:
•    Modifying the document’s contents
•    Copying or otherwise extracting text, images and graphics from the document.
•    Adding or modifying text annotations (see 12.5.6.4, "Text annotations") and interactive form
fields (see 12.7, "Forms").
•    Printing the document
If the security handler’s revision number is 3 or greater, user access to the following operations shall
be controlled more selectively:
•    Filling in forms (that is, filling in existing interactive form fields) and signing the document (which
amounts to filling in existing signature fields, a type of interactive form field).
•    Assembling the document: inserting, rotating, or deleting pages and creating navigation elements
such as document outline items or thumbnail images (see 12.3, "Document-level navigation").
•    Printing to a representation from which a faithful digital copy of the PDF content could be
generated. Disallowing such printing may result in degradation of output quality.
In addition, security handlers of revisions 3 and greater shall enable the extraction of text, images and
graphics (in support of accessibility, or for other purposes) to be controlled separately.
If a security handler of revision 4 or 5 is specified, the standard security handler shall support crypt
filters (see 7.6.6, "Crypt filters"). The support shall be limited to the Identity crypt filter (see "Table 26
— Standard crypt filter names") and crypt filters named StdCF whose dictionaries contain an
AuthEvent value of DocOpen. For revision 4, the filter CFM value shall be V2 (RC4) or AESV2 (AES-
128). For revision 6, the filter CFM value shall be AESV3 (AES-256). Public-Key security handlers in this
case shall use crypt filters named DefaultCryptFilter when all document content is encrypted, and
shall use crypt filters named DefEmbeddedFile when file attachments only are encrypted in place of
StdCF name. This nomenclature shall not be used as an indicator of the type of the security handler or
encryption. Use of security handler revisions 1, 2, 3, 4 and 5 is deprecated in PDF 2.0.
Once the document has been opened and decrypted successfully, a PDF reader technically has access to
the entire contents of the document. There is nothing inherent in PDF encryption that enforces the
document permissions specified in the encryption dictionary. PDF readers shall respect the intent of
the document creator by restricting user access to an encrypted PDF file according to the permissions
contained in the file.
NOTE 2      PDF 1.5 introduces a set of access permissions that do not require the document to be encrypted
(see 12.8.6, "Permissions"). This enables limited access to a document when a user is not be able
to respond to a prompt for a password. For example, there can be non-interactive PDF readers
that do not have a person running them such as printing off-line or on a server.
All passwords for revision 6 shall be based on Unicode. Preprocessing of a user-provided password
consists first of normalizing its representation by applying the "SASLPrep" profile (Internet RFC 4013)
of the "stringprep" algorithm (Internet RFC 3454) to the supplied password using the Normalize and
BiDi options. Next, the password string shall be converted to UTF-8 encoding, and then truncated to
the first 127 bytes if the string is longer than 127 bytes (see 7.6.4.3.3, "Algorithm 2.A: Retrieving the
file encryption key from an encrypted document in order to decrypt it (revision 6 and later)", steps (a,
b)).
NOTE 3       The use of the “SASLPrep” profile (Internet RFC 4013) and the “stringprep” algorithm (Internet
RFC 3454) places limitations on the set of Unicode characters which can be used in PDF
passwords.

#### 0.7: 7.6.4.2           Standard encryption dictionary
"Table 21 — Additional encryption dictionary entries for the standard security handler" shows the
encryption dictionary entries for the standard security handler (in addition to those in "Table 20 —
Entries common to all encryption dictionaries").
Table 21 — Additional encryption dictionary entries for the standard security handler
Key                 Type      Value
R                   integer   (Required) A number specifying which revision of the standard security
handler shall be used to interpret this dictionary:
2   (Deprecated in PDF 2.0) if the document is encrypted with a V value
less than 2 (see "Table 20 — Entries common to all encryption
dictionaries") and does not have any of the access permissions set to 0
(by means of the P entry, below) that are designated "Security
handlers of revision 3 or greater" in "Table 22 — Standard security
handler user access permissions".
3   (Deprecated in PDF 2.0) if the document is encrypted with a V value of
2 or 3, or has any "Security handlers of revision 3 or greater" access
permissions set to 0.
4   (Deprecated in PDF 2.0) if the document is encrypted with a V value of
4.
5   (PDF 2.0; deprecated in PDF 2.0) Shall not be used. This value was used
by a deprecated proprietary Adobe extension.
6   (PDF 2.0) if the document is encrypted with a V value of 5.
O                   byte      (Required) A byte string, 32 bytes long if the value of R is 4 or less and 48
string    bytes long if the value of R is 6, based on both the owne r and user
passwords, that shall be used in computing the file encryption key and in
determining whether a valid owner password was entered.
For more information, see 7.6.4.3, "File encryption key algorithm" and
7.6.4.4, "Password algorithms".
U                   byte      (Required) A byte string, 32 bytes long if the value of R is 4 or less and 48
string    bytes long if the value of R is 6, based on the owner and user password, that
shall be used in determining whether to prompt the user for a password
and, if so, whether a valid user or owner password was entered. For more
information, see 7.6.4.4, "Password algorithms".
OE                  byte      (Required if R is 6 (PDF 2.0)) A 32-byte string, based on the owner and user
string    password, that shall be used in computing the file encryption key. For more
information, see 7.6.4.4, "Password algorithms".
UE                  byte      (Required if R is 6 (PDF 2.0)) A 32-byte string, based on the user password,
string    that shall be used in computing the file encryption key. For more
information, see 7.6.4.4, "Password algorithms".
P                   integer   (Required) A set of flags specifying which operations shall be permitted
when the document is opened with user access (see "Table 22 — Standard
security handler user access permissions").

Key                  Type       Value
Perms                byte       (Required if R is 6 (PDF 2.0)) A 16-byte string, encrypted with the file
string     encryption key, that contains an encrypted copy of the permissions flags.
For more information, see 7.6.4.4, "Password algorithms".
EncryptMetadata boolean (Optional; meaningful only when the value of V is 4 (PDF 1.5) or 5 (PDF 2.0))
Indicates whether the document-level metadata stream (see 14.3.2,
"Metadata streams") shall be encrypted. Default value: true.
The values of the O and U entries in this dictionary shall be used to determine whether a password
entered when the document is opened is the correct owner password, user password, or neither.
The value of the P entry shall be interpreted as an unsigned 32-bit quantity containing a set of flags
specifying which access permissions shall be granted when the document is opened with user access.
"Table 22 — Standard security handler user access permissions" shows the meanings of these flags. Bit
positions within the flag word shall be numbered from 1 (low-order) to 32 (high-order). A 1 bit in any
position shall enable the corresponding access permission. Which bits shall be meaningful, and in some
cases how they shall be interpreted, shall depend on the security handler’s revision number (specified
in the encryption dictionary’s R entry).
PDF readers shall ignore all flags other than those at bit positions 3, 4, 5, 6, 9, 10, 11, and 12.
NOTE          PDF integer objects can be interpreted as binary values in a signed twos-complement form. Since
all the reserved high-order flag bits in the encryption dictionary’s P value are required to be 1,
the integer value P is always specified as a negative integer. For example, assuming revision 2 of
the security handler, the value -44 permits printing and copying but disallows modifying the
contents and annotations.
Table 22 — Standard security handler user access permissions
Bit position     Meaning
1-2              Reserved. Must be zero (0).
3                (Security handlers of revision 2) Print the document.
(Security handlers of revision 3 or greater) Print the document (possibly not at the highest
quality level, depending on whether bit 12 is also set).
4                Modify the contents of the document by operations other than those controlled by bits 6, 9,
and 11.
5                Copy or otherwise extract text and graphics from the document. However, for the limited
purpose of providing this content to assistive technology, a PDF reader should behave as if this
bit was set to 1.
NOTE     For accessibility, ISO 32000-1 had this option restricted by bit 10, but that exception has been
deprecated in PDF 2.0.
6                Add or modify text annotations, fill in interactive form fields, and, if bit 4 is also set, create or
modify interactive form fields (including signature fields).
7-8              Reserved. Must be 1.
Bit position    Meaning
9               (Security handlers of revision 3 or greater) Fill in existing interactive form fields (including
signature fields), even if bit 6 is clear.
10              Not used. This bit was previously used to determine whether content could be extracted for
the purposes of accessibility, however, that restriction has been deprecated in PDF 2.0. PDF
readers shall ignore this bit and PDF writers shall always set this bit to 1 to ensure
compatibility with PDF readers following earlier specifications.
11              (Security handlers of revision 3 or greater) Assemble the document (insert, rotate, or delete
pages and create document outline items or thumbnail images), even if bit 4 is clear.
12              (Security handlers of revision 3 or greater) Print the document to a representation from which
a faithful digital copy of the PDF content could be generated, based on an implementation-
dependent algorithm. When this bit is clear (and bit 3 is set), printing shall be limited to a low-
level representation of the appearance, possibly of degraded quality.
13 - 32         (Security handlers of revision 3 or greater) Reserved. Must be 1.
NOTE         The above table was re-titled and corrected in this document (2020).

#### 0.8: 7.6.4.3.1         General
As noted earlier, one function of a security handler is to generate a file encryption key for use in
encrypting and decrypting the contents of a document. Given a password string, the standard security
handler computes a file encryption key. For revision 4 and earlier, the algorithm is as shown in
7.6.4.3.2, "Algorithm 2: Computing a file encryption key in order to encrypt a document (revision 4 and
earlier)" and for revision 6, the algorithm is as shown in 7.6.4.3.3, "Algorithm 2.A: Retrieving the file
encryption key from an encrypted document in order to decrypt it (revision 6 and later)".

#### 0.9: 7.6.4.3.2  Algorithm 2: Computing a file encryption key in order to encrypt a
document (revision 4 and earlier)
This algorithm is deprecated in PDF 2.0.
a) The password string is generated from host system codepage characters (or system scripts) by first
converting the string to PDFDocEncoding. If the input is Unicode, first convert to a codepage encoding,
and then to PDFDocEncoding for backward compatibility. Pad or truncate the resulting password string
to exactly 32 bytes. If the password string is more than 32 bytes long, use only its first 32 bytes; if it is
less than 32 bytes long, pad it by appending the required number of additional bytes from the beginning
of the following padding string:
<28 BF 4E 5E 4E 75 8A 41 64 00 4E 56 FF FA 01 08
2E 2E 00 B6 D0 68 3E 80 2F 0C A9 FE 64 53 69 7A>
That is, if the password string is n bytes long, append the first 32 - n bytes of the padding string to
the end of the password string. If the password string is empty (zero-length), meaning there is no
user password, substitute the entire padding string in its place.
b) Initialise the MD5 hash function and pass the result of step (a) as input to this function.
c) Pass the value of the encryption dictionary’s O entry to the MD5 hash function. (7.6.4.4.2, "Algorithm 3:

Computing the encryption dictionary’s O-entry value (revision 4 and earlier)" shows how the O value is
computed.)
d) Convert the integer value of the P entry to a 32-bit unsigned binary number and pass these bytes to the
MD5 hash function, low-order byte first.
e) Pass the first element of the file’s file identifier array (the value of the ID entry in the document’s trailer
dictionary; see "Table 15 — Entries in the file trailer dictionary") to the MD5 hash function.
f) (Security handlers of revision 4 or greater) If document metadata is not being encrypted, pass 4 bytes
with the value 0xFFFFFFFF to the MD5 hash function.
NOTE 1     This provision pertains only to document-level XMP metadata.
g) Finish the hash.
h) (Security handlers of revision 3 or greater) Do the following 50 times: Take the output from the previous
MD5 hash and pass the first n bytes of the output as input into a new MD5 hash, where n is the number
of bytes of the file encryption key as defined by the value of the encryption dictionary’s Length entry.
i) Set the file encryption key to the first n bytes of the output from the final MD5 hash, where n shall always
be 5 for security handlers of revision 2 but, for security handlers of revision 3 or greater, shall depend on
the value of the encryption dictionary’s Length entry.
NOTE 2     The first element of the ID array, as used in 7.6.4.3.2, "Algorithm 2: Computing a file encryption
key in order to encrypt a document (revision 4 and earlier)", step e, generally remains
unchanged across revisions of a given document. However, since this is not guaranteed, use of
the ID in computation of the file encryption key, as required when using 7.6.4.3.3, "Algorithm
2.A: Retrieving the file encryption key from an encrypted document in order to decrypt it
(revision 6 and later)Algorithm 2: Computing a file encryption key in order to encrypt a
document (revision 4 and earlier)", can complicate updates to the document. For this reason,
security handlers are encouraged to use Algorithm 2.A or higher, which do not use the ID in file
encryption key computation. This algorithm, when applied to the user password string, produces
the file encryption key used to encrypt or decrypt string and stream data according to 7.6.3.2,
"Algorithm 1: Encryption of data using the RC4 or AES algorithms". Parts of this algorithm are
also used in the algorithms described below.

#### 0.10: 7.6.4.3.3  Algorithm 2.A: Retrieving the file encryption key from an encrypted
document in order to decrypt it (revision 6 and later)
To understand the algorithm below, it is necessary to treat the 48-bytes of the O and U strings in the
Encrypt dictionary as made up of three sections, as described in Algorithms 8 and 9. The first 32 bytes
are a hash value (explained below). The next 8 bytes are called the Validation Salt. The final 8 bytes are
called the Key Salt. Whenever UTF-8 password is used below, steps (a) and (b) are to be applied to the
relevant password string to generate the UTF-8 password.
a) The UTF-8 password string shall be generated from Unicode input by processing the input string with
the SASLprep (Internet RFC 4013) profile of stringprep (Internet RFC 3454) using the Normalize and BiDi
options, and then converting to a UTF-8 representation.
b) Truncate the UTF-8 representation to 127 bytes if it is longer than 127 bytes.
c) Test the password against the owner key by computing a hash using algorithm 2.B with an input string
consisting of the UTF-8 password concatenated with the 8 bytes of owner Validation Salt, concatenated
with the 48-byte U string. If the 32-byte result matches the first 32 bytes of the O string, this is the owner
password.
d) Compute an intermediate owner key by computing a hash using algorithm 2.B with an input string
consisting of the UTF-8 owner password concatenated with the 8 bytes of owner Key Salt, concatenated
with the 48-byte U string. The 32-byte result is the key used to decrypt the 32-byte OE string using AES-
256 in CBC mode with no padding and an initialization vector of zero. The 32-byte result is the file
encryption key.
e) Compute an intermediate user key by computing a hash using algorithm 2.B with an input string
consisting of the UTF-8 user password concatenated with the 8 bytes of user Key Salt. The 32-byte result
is the key used to decrypt the 32-byte UE string using AES-256 in CBC mode with no padding and an
initialization vector of zero. The 32-byte result is the file encryption key.
f) Decrypt the 16-byte Perms string using AES-256 in ECB mode with an initialization vector of zero and
the file encryption key as the key. Verify that bytes 9-11 of the result are the characters "a", "d", "b". Bytes
0-3 of the decrypted Perms entry, treated as a little-endian integer, are the user permissions. They shall
match the value in the P key.

#### 0.11: 7.6.4.3.4        Algorithm 2.B: Computing a hash (revision 6 and later)
Take the SHA-256 hash of the original input to the algorithm and name the resulting 32 bytes, K.
Perform the following steps (a)-(d) 64 times:
a) Make a new string, K1, consisting of 64 repetitions of the sequence: input password, K, the 48-byte user
key. The 48 byte user key is only used when checking the owner password or creating the owner key. If
checking the user password or creating the user key, K1 is the concatenation of the input password and
K.
b) Encrypt K1 with the AES-128 (CBC, no padding) algorithm, using the first 16 bytes of K as the key and
the second 16 bytes of K as the initialization vector. The result of this encryption is E.
c) Taking the first 16 bytes of E as an unsigned big-endian integer, compute the remainder, modulo 3. If the
result is 0, the next hash used is SHA-256, if the result is 1, the next hash used is SHA-384, if the result is
2, the next hash used is SHA-512.
d) Using the hash algorithm determined in step c, take the hash of E. The result is a new value of K, which
will be 32, 48, or 64 bytes in length.
Repeat the process (a-d) with this new value for K. Following 64 rounds (round number 0 to round
number 63), do the following, starting with round number 64:
NOTE 2      The reason for multiple rounds is to defeat the possibility of running all paths in parallel. With 64
rounds (minimum) there are 3^64 paths through the algorithm.
e) Look at the very last byte of E. If the value of that byte (taken as an unsigned integer) is greater than the
round number - 32, repeat steps (a-d) again.
f) Repeat from steps (a-e) until the value of the last byte is ≤ (round number) - 32.
NOTE 3      Tests indicate that the total number of rounds will most likely be between 65 and 80.
The first 32 bytes of the final K are the output of the algorithm.

#### 0.12: 7.6.4.4.1        General
In addition to the file encryption key, the standard security handler shall provide the contents of the
encryption dictionary ("Table 20 — Entries common to all encryption dictionaries" and "Table 21 —
Additional encryption dictionary entries for the standard security handler"). The values of the Filter, V,
Length, R, and P entries are straightforward. The computation of the values for the O (owner
password) and the U (user password) entries for encryption revision 4 and earlier, and the O, U, OE
(owner encryption), UE (user encryption) and Perms (permissions) values for encryption revision 6

require more explanation.
Algorithms 3 through 5 show how the values of the owner password and user password are computed
for revision 4 and earlier. Algorithm 6 and 7 show how to determine if a password is valid. Algorithms
8 through 10 show how to compute the values stored in the PDF (by writers) to determine if a revision
6 password is valid. Algorithms 11 through 13 describe how to validate a password provided by a user
or owner to read the PDF.
Passwords for revision 4 and earlier are up to 32 characters in length, and are limited to characters in
the PDFDocEncoding character set (see Annex D, "Character sets and encodings").
In revision 4 and earlier, the result of running the password algorithm was the file encryption key. In
revision 6, the file encryption key is decoupled from the password algorithm to make the owner and
user keys independent. For algorithms 8 to 13, the file encryption key shall be a 256-bit (32-byte)
value generated with a strong random number generator.

#### 0.13: 7.6.4.4.2    Algorithm 3: Computing the encryption dictionary’s O-entry value
(revision 4 and earlier)
This algorithm is deprecated in PDF 2.0.
a) Pad or truncate the owner password string as described in step (b) of 7.6.4.3.2, "Algorithm 2: Computing
a file encryption key in order to encrypt a document (revision 4 and earlier)". If there is no owner
password, use the user password instead.
b) Initialise the MD5 hash function and pass the result of step (a) as input to this function.
c) (Security handlers of revision 3 or greater) Do the following 50 times: Take the output from the previous
MD5 hash and pass it as input into a new MD5 hash.
d) Create an RC4 file encryption key using the first n bytes of the output from the final MD5 hash, where n
shall always be 5 for security handlers of revision 2 but, for security handlers of revision 3 or greater,
shall depend on the value of the encryption dictionary’s Length entry.
e) Pad or truncate the user password string as described in step (b) of 7.6.4.3.2, "Algorithm 2: Computing a
file encryption key in order to encrypt a document (revision 4 and earlier)".
f) Encrypt the result of step (e), using an RC4 encryption function with the file encryption key obtained in
step (d).
g) (Security handlers of revision 3 or greater) Do the following 19 times: Take the output from the previous
invocation of the RC4 function and pass it as input to a new invocation of the function; use a file
encryption key generated by taking each byte of the encryption key obtained in step (d) and performing
an XOR (exclusive or) operation between that byte and the single-byte value of the iteration counter
(from 1 to 19).
h) Store the output from the final invocation of the RC4 function as the value of the O entry in the
encryption dictionary.

#### 0.14: 7.6.4.4.3    Algorithm 4: Computing the encryption dictionary’s U-entry value
(Security handlers of revision 2)
This algorithm is deprecated in PDF 2.0.
a) Create a file encryption key based on the user password string, as described in 7.6.4.3.2, "Algorithm 2:
Computing a file encryption key in order to encrypt a document (revision 4 and earlier)".
b) Encrypt the 32-byte padding string shown in step (b) of 7.6.4.3.2, "Algorithm 2: Computing a file
encryption key in order to encrypt a document (revision 4 and earlier)", using an RC4 encryption
function with the file encryption key from the preceding step.
c) Store the result of step (b) as the value of the U entry in the encryption dictionary.

#### 0.15: 7.6.4.4.4    Algorithm 5: Computing the encryption dictionary’s U (user password)
value (Security handlers of revision 3 or 4)
This algorithm is deprecated in PDF 2.0.
a) Create a file encryption key based on the user password string, as described in 7.6.4.3.2, "Algorithm 2:
Computing a file encryption key in order to encrypt a document (revision 4 and earlier)".
b) Initialise the MD5 hash function and pass the 32-byte padding string shown in step (b) of 7.6.4.3.2,
"Algorithm 2: Computing a file encryption key in order to encrypt a document (revision 4 and earlier)"
as input to this function.
c) Pass the first element of the file’s file identifier array (the value of the ID entry in the document’s trailer
dictionary; see "Table 15 — Entries in the file trailer dictionary") to the hash function and finish the hash.
d) Encrypt the 16-byte result of the hash, using an RC4 encryption function with the encryption key from
step (a).
e) Do the following 19 times: Take the output from the previous invocation of the RC4 function and pass it
as input to a new invocation of the function; use a file encryption key generated by taking each byte of
the original file encryption key obtained in step (a) and performing an XOR (exclusive or) operation
between that byte and the single-byte value of the iteration counter (from 1 to 19).
f) Append 16 bytes of arbitrary padding to the output from the final invocation of the RC4 function and
store the 32-byte result as the value of the U entry in the encryption dictionary.
NOTE       The standard security handler uses the algorithms 6 and 7 that follow, to determine whether a
supplied password string is the correct user or owner password. Note too that algorithm 6 can
be used to determine whether a document’s user password is the empty string, and therefore
whether to suppress prompting for a password when the document is opened.

#### 0.16: 7.6.4.4.5    Algorithm 6: Authenticating the user password (Security handlers of
revision 4 and earlier)
This algorithm is deprecated in PDF 2.0.
a) Perform all but the last step of 7.6.4.4.3, "Algorithm 4: Computing the encryption dictionary’s U-entry
value (Security handlers of revision 2)" or 7.6.4.4.4, "Algorithm 5: Computing the encryption dictionary’s
U (user password) value (Security handlers of revision 3 or 4)" using the supplied password string.
b) If the result of step (a) is equal to the value of the encryption dictionary’s U entry (comparing on the first
16 bytes in the case of security handlers of revision 3 or greater), the password supplied is the correct
user password. The file encryption key obtained in step (a) (that is, in the first step of 7.6.4.4.3,
"Algorithm 4: Computing the encryption dictionary’s U-entry value (Security handlers of revision 2)" or
7.6.4.4.4, "Algorithm 5: Computing the encryption dictionary’s U (user password) value (Security
handlers of revision 3 or 4)") shall be used to decrypt the document.

#### 0.17: 7.6.4.4.6    Algorithm 7: Authenticating the owner password (Security handlers of
revision 4 and earlier)
This algorithm is deprecated in PDF 2.0.
a) Compute a file encryption key from the supplied password string, as described in step (a) to step (d) of

"Algorithm 3: Computing the encryption dictionary’s O-entry value (revision 4 and earlier)".
b) (Security handlers of revision 2 only) Decrypt the value of the encryption dictionary’s O entry, using an
RC4 encryption function with the file encryption key computed in step (a).
(Security handlers of revision 3 or greater) Do the following 20 times: Decrypt the value of the
encryption dictionary’s O entry (first iteration) or the output from the previous iteration (all
subsequent iterations), using an RC4 encryption function with a different encryption key at each
iteration. The key shall be generated by taking the original key (obtained in step (a)) and
performing an XOR (exclusive or) operation between each byte of the key and the single-byte value
of the iteration counter (from 19 to 0).
c) The result of step (b) purports to be the user password. Authenticate this user password using 7.6.4.4.5,
"Algorithm 6: Authenticating the user password (Security handlers of revision 4 and earlier)". If it is
correct, the password supplied is the correct owner password.

#### 0.18: 7.6.4.4.7    Algorithm 8: Computing the encryption dictionary’s U (user password) and
UE (user encryption) values (Security handlers of revision 6)
a) Generate 16 random bytes of data using a strong random number generator. The first 8 bytes are the
User Validation Salt. The second 8 bytes are the User Key Salt. Compute the 32-byte hash using algorithm
2.B with an input string consisting of the UTF-8 password concatenated with the User Validation Salt.
The 48- byte string consisting of the 32-byte hash followed by the User Validation Salt followed by the
User Key Salt is stored as the U key.
b) Compute the 32-byte hash using algorithm 2.B with an input string consisting of the UTF-8 password
concatenated with the User Key Salt. Using this hash as the key, encrypt the file encryption key using
AES-256 in CBC mode with no padding and an initialization vector of zero. The resulting 32-byte string is
stored as the UE key.

#### 0.19: 7.6.4.4.8   Algorithm 9: Computing the encryption dictionary’s O (owner password)
and OE (owner encryption) values (Security handlers of revision 6)
a) Generate 16 random bytes of data using a strong random number generator. The first 8 bytes are the
Owner Validation Salt. The second 8 bytes are the Owner Key Salt. Compute the 32-byte hash using
algorithm 2.B with an input string consisting of the UTF-8 password concatenated with the Owner
Validation Salt and then concatenated with the 48-byte U string as generated in Algorithm 8. The 48-byte
string consisting of the 32-byte hash followed by the Owner Validation Salt followed by the Owner Key
Salt is stored as the O key.
b) Compute the 32-byte hash using 7.6.4.3.4, "Algorithm 2.B: Computing a hash (revision 6 and later)" with
an input string consisting of the UTF-8 password concatenated with the Owner Key Salt and then
concatenated with the 48-byte U string as generated in 7.6.4.4.7, "Algorithm 8: Computing the
encryption dictionary’s U (user password) and UE (user encryption) values (Security handlers of
revision 6)". Using this hash as the key, encrypt the file encryption key using AES-256 in CBC mode with
no padding and an initialization vector of zero. The resulting 32-byte string is stored as the OE key.

#### 0.20: 7.6.4.4.9    Algorithm 10: Computing the encryption dictionary’s Perms (permissions)
value (Security handlers of revision 6)
Fill a 16-byte block as follows:
a) Extend the permissions (contents of the P integer) to 64 bits by setting the upper 32 bits to all 1’s.
NOTE        This allows for future extension without changing the format.
b) Record the 8 bytes of permission in the bytes 0-7 of the block, low order byte first.
c) Set byte 8 to the ASCII character "T" or "F" according to the EncryptMetadata boolean.
d) Set bytes 9-11 to the ASCII characters '"a", "d", "b".
e) Set bytes 12-15 to 4 bytes of random data, which will be ignored.
f) Encrypt the 16-byte block using AES-256 in ECB mode with an initialization vector of zero, using the file
encryption key as the key. The result (16 bytes) is stored as the Perms string, and checked for validity
when the file is opened.

#### 0.21: 7.6.4.4.10   Algorithm 11: Authenticating the user password (Security handlers of
revision 6)
a) Test the password against the user key by computing the 32-byte hash using 7.6.4.3.4, "Algorithm 2.B:
Computing a hash (revision 6 and later)" with an input string consisting of the UTF-8 password
concatenated with the 8 bytes of User Validation Salt (see 7.6.4.4.7, "Algorithm 8: Computing the
encryption dictionary’s U (user password) and UE (user encryption) values (Security handlers of
revision 6)"). If the 32- byte result matches the first 32 bytes of the U string, this is the user password.

#### 0.22: 7.6.4.4.11   Algorithm 12: Authenticating the owner password (Security handlers of
revision 6)
a) Test the password against the owner key by computing the 32-byte hash using algorithm 2.B with an
input string consisting of the UTF-8 password concatenated with the 8 bytes of Owner Validation Salt
and the 48 byte U string. If the 32 byte result matches the first 32 bytes of the O string, this is the owner
password.

#### 0.23: 7.6.4.4.12       Algorithm 13: Validating the permissions (Security handlers of revision 6)
a) Decrypt the 16 byte Perms string using AES-256 in ECB mode with an initialization vector of zero and
the file encryption key as the key. Verify that bytes 9-11 of the result are the characters "a", "d", "b". Bytes
0-3 of the decrypted Perms entry, treated as a little-endian integer, are the user permissions. They
should match the value in the P key. Byte 8 should match the ASCII character "T" or "F" according to the
boolean value of the EncryptMetadata key.

#### 0.24: 7.6.5.1          General
Security handlers may use public-key encryption technology to encrypt a document (or strings and
streams within a document). When doing so, specifying one or more lists of recipients, where each list
has its own unique access permissions may be done. Only specified recipients shall open the encrypted
document or content, unlike the standard security handler, where a password determines access. The
permissions defined for public-key security handlers are shown in "Table 24 — Public-key security
handler user access permissions" in 7.6.5.2, "Public-key encryption dictionary".
Public-key security handlers use the industry standard Public Key Cryptographic Standard Number 7
(CMS) binary encoding syntax to encode recipient list, decryption key, and access permission
information. The CMS specification is in Internet RFC 5652.
When encrypting the data, each recipient’s X.509 public key certificate (as described in ITU-T
Recommendation X.509) shall be available. When decrypting the data, the PDF reader shall scan the
recipient list for which the content is encrypted and shall attempt to find a match with a certificate that
belongs to the user. If a match is found, the user requires access to the corresponding private key,
which may require authentication, possibly using a password. Once access is obtained, the private key

shall be used to decrypt the encrypted data.

#### 0.25: 7.6.5.2           Public-key encryption dictionary
Encryption dictionaries for public-key security handlers contain the common entries shown in "Table
20 — Entries common to all encryption dictionaries", whose values are described above. In addition,
they may contain the entry shown in "Table 23 — Additional encryption dictionary entries for public-
key security handlers" as described below.
The Filter entry shall be the name of a public-key security handler. This filter entry shall be the name
of the public key handler used to encrypt the document. See "Table 20 — Entries common to all
encryption dictionaries".
NOTE         Examples of existing security handlers that support public-key encryption are Entrust.PPKEF,
Adobe.PPKLite, and Adobe.PubSec.
Permitted values of the SubFilter entry for use with conforming public-key security handlers are
adbe.pkcs7.s3, adbe.pkcs7.s4, which shall be used when not using crypt filters (see 7.6.6, "Crypt filters")
and adbe.pkcs7.s5, which shall be used when using crypt filters.
The CF, StmF, and StrF entries may be present when SubFilter is adbe.pkcs7.s5.
“Table 23 — Additional encryption dictionary entries for public-key security handlers” defines
additional encryption dictionary entries for public-key security handlers.
Table 23 — Additional encryption dictionary entries for public-key security handlers
Key             Type        Value
Recipients      array       (Required when SubFilter is adbe.pkcs7.s3 or adbe.pkcs7.s4; PDF 1.3) An
array of byte-strings, where each string is a CMS object listing recipients
who have been granted equal access rights to the document. The data
contained in the CMS object shall include both a cryptographic key that
shall be used to decrypt the encrypted data and the access permissions
(see "Table 24 — Public-key security handler user access permissions")
that apply to the recipient list. There shall be only one CMS object per
unique set of access permissions; if a recipient appears in more than one
list, the permissions used shall be those in the first matching list.
When SubFilter is adbe.pkcs7.s5, recipient lists shall be specified in the
crypt filter dictionary; see "Table 27 — Additional crypt filter dictionary
entries for public-key security handlers".
NOTE         (2020) "Table 23 — Additional encryption dictionary entries for public-key security handlers"
previously specified a P key which was removed in this document due to errors that prohibited
interoperable implementations.
The access permissions shall be interpreted as an unsigned 32-bit quantity containing a set of flags
specifying which access permissions shall be granted when the document is opened with user access.
"Table 24 — Public-key security handler user access permissions" shows the meanings of these flags.
Bit positions within the flag word shall be numbered from 1 (low-order) to 32 (high-order). A 1 bit in
any position shall enable the corresponding access permission.
PDF processors shall ignore all flags other than those at bit positions 2, 3, 4, 5, 6, 9, 10, 11, and 12.
Table 24 — Public-key security handler user access permissions
Bit position    Meaning
2               When set permits change of encryption and enables all other permissions.
3               Print the document (possibly not at the highest quality level, depending on
whether bit 12 is also set).
4               Modify the contents of the document by operations other than those controlled by
bits 6, 9, and 11.
5               Copy or otherwise extract text and graphics from the document. However, for the
limited purpose of providing this content to assistive technology, a PDF reader
shall behave as if this bit was set to 1.
NOTE    ISO 32000-1 had this option restricted by bit 10, for accessibility, but that
exception has been deprecated in PDF 2.0.
6               Add or modify text annotations, fill in interactive form fields, and, if bit 4 is also
set, create or modify interactive form fields (including signature fields).
9               Fill in existing interactive form fields (including signature fields), even if bit 6 is
clear.
10              Not used. This bit was previously used to determine whether content could be
extracted for the purposes of accessibility, however, that restriction has been
deprecated in PDF 2.0. PDF readers shall ignore this bit and PDF writers shall
always set this bit to 1 to ensure compatibility with PDF readers supporting older
specifications.
11              Assemble the document (insert, rotate, or delete pages and create document
outline items or thumbnail images), even if bit 4 is clear.
12              Print the document to a representation from which a faithful digital copy of the
PDF content could be generated, based on an implementation-dependent
algorithm. When this bit is clear (and bit 3 is set), printing shall be limited to a
low-level representation of the appearance, possibly of degraded quality.
NOTE        "Table 24 — Public-key security handler user access permissions" is different to "Table 22 —
Standard security handler user access permissions".

#### 0.26: 7.6.5.3         Public-key encryption algorithms
"Figure 4 — Public-key encryption algorithm" illustrates how CMS objects shall be used when
encrypting PDF files. A CMS object is designed to encapsulate and encrypt what is referred to as the
enveloped data.

Figure 4 — Public-key encryption algorithm
The enveloped data in the CMS object contains keying material that shall be used to decrypt the
document (or individual strings or streams in the document, when crypt filters are used; see 7.6.6,
"Crypt filters"). A key shall be used to encrypt (and decrypt) the enveloped data. This key (the plaintext
key in "Figure 4 — Public-key encryption algorithm") shall be encrypted for each recipient, using that
recipient’s public key, and shall be stored in the CMS object (as the encrypted key for each recipient).
To decrypt the document, that key shall be decrypted using the recipient’s private key, which yields a
decrypted (plaintext) key. That key, in turn, shall be used to decrypt the enveloped data in the CMS
object, resulting in a byte array that includes the following information:
•    A 20-byte seed that shall be used to create the file encryption key that is used by "Algorithm 1:
Encryption of data using the RC4 or AES algorithms" or "Algorithm 1.A: Encryption of data using
the AES algorithms". The seed shall be a unique random number generated by the security
handler that encrypted the document.
•    A 4-byte value defining the permissions, most significant byte first. See "Table 24 — Public-key
security handler user access permissions" for the possible permission values.
NOTE        The above bullet was corrected in this document (2020).
•    When SubFilter is adbe.pkcs7.s3, the relevant permissions shall be only those specified for
revision 2 of the standard security handler.
•    For adbe.pkcs7.s4, security handlers of revision 3 permissions shall apply.
•    For adbe.pkcs7.s5, which supports the use of crypt filters, the permissions shall be the same as
adbe.pkcs7.s4 when the crypt filter is referenced from the StmF or StrF entries of the encryption
dictionary. When referenced from the Crypt filter decode parameter dictionary of a stream object
(see "Table 14 — Optional parameters for Crypt filters"), the 4 bytes of permissions shall be
absent from the enveloped data.
The algorithms that shall be used to encrypt the enveloped data in the CMS object are:
•    RC4 with key lengths up to 256-bits (deprecated in PDF 2.0);
•    DES, Triple DES, RC2 with key lengths up to 128 bits (deprecated in PDF 2.0);
•    128-bit AES in Cipher Block Chaining (CBC) mode (deprecated in PDF 2.0);
•    192-bit AES in CBC mode (deprecated in PDF 2.0);
•   256-bit AES in CBC mode.
The CMS specification is in Internet RFC 5652, Cryptographic Message Syntax.
The file encryption key used by 7.6.3.2, "Algorithm 1: Encryption of data using the RC4 or AES
algorithms" shall be calculated by means of an SHA-1 message digest operation, for a key length of 128
bits. For the file encryption key used by 7.6.3.3 "Algorithm 1.A: Encryption of data using the AES
algorithms", a SHA-256 digest operation shall be used for a key length of 256 bits. These operations
digest the following data, in order:
a) The 20 bytes of seed.
b) The bytes of each item in the Recipients array of CMS objects in the order in which they appear in the
array.
c) 4 bytes with the value 0xFF if the key being generated is intended for use in document-level encryption
and the document metadata is being left as plaintext.
d) The first n/8 bytes of the resulting digest shall be used as the file encryption key, where n is the bit length
of the file encryption key.

#### 0.27: 7.6.6 Crypt filters
PDF 1.5 introduces crypt filters, which provide finer granularity control of encryption within a PDF file.
The use of crypt filters involves the following structures:
•   The encryption dictionary (see "Table 20 — Entries common to all encryption dictionaries")
contains entries that enumerate the crypt filters in the document (CF) and specify which ones are
used by default to decrypt all the streams (StmF) and strings (StrF) in the document. In addition,
the value of the V entry shall be 4 to use crypt filters.
•   Each crypt filter specified in the CF entry of the encryption dictionary shall be represented by a
crypt filter dictionary, whose entries are shown in "Table 25 — Entries common to all crypt filter
dictionaries".
•   A stream filter type, the Crypt filter (see 7.4.10, "Crypt filter") can be specified for any stream in
the document to override the default filter for streams. A PDF processor shall provide a standard
Identity filter which shall pass the data unchanged (see "Table 26 — Standard crypt filter names")
to allow specific streams, such as document metadata, to be unencrypted in an otherwise
encrypted document. The stream’s DecodeParms entry shall contain a Crypt filter decode
parameters dictionary (see "Table 14 — Optional parameters for Crypt filters") whose Name
entry specifies the particular crypt filter that shall be used (if missing, Identity is used). Different
streams may specify different crypt filters.
Authorization to decrypt a stream shall always be obtained before the stream can be accessed. This
typically occurs when the document is opened, as specified by a value of DocOpen for the AuthEvent
entry in the crypt filter dictionary. PDF readers and security handlers shall treat any attempt to access
a stream for which authorization has failed as an error. AuthEvent can also be EFOpen, which
indicates the presence of an embedded file that is encrypted with a crypt filter that may be different
from the crypt filters used by default to encrypt strings and streams in the document.
In the file specification dictionary (see 7.11.3, "File specification dictionaries"), related files (RF) shall
use the same crypt filter as the embedded file (EF).
A value of None for the CFM entry in the crypt filter dictionary allows the security handler to do its own
decryption. This allows the handler to tightly control key management and use any preferred

symmetric-key cryptographic algorithm.
Table 25 — Entries common to all crypt filter dictionaries
Key              Type       Value
Type             name       (Optional) If present, shall be CryptFilter for a crypt filter dictionary.
CFM              name       (Optional) The method used, if any, by the PDF reader to decrypt data.
The following values shall be supported:
None The application shall not decrypt data but shall direct the input
stream to the security handler for decryption.
V2        (Deprecated in PDF 2.0) The application shall ask the security
handler for the file encryption key and shall implicitly decrypt
data with 7.6.3.2, "Algorithm 1: Encryption of data using the
RC4 or AES algorithms", using the RC4 algorithm.
AESV2 (PDF 1.6; deprecated in PDF 2.0) The application shall ask the
security handler for the file encryption key and shall implicitly
decrypt data with 7.6.3.2, "Algorithm 1: Encryption of data
using the RC4 or AES algorithms", using the AES algorithm in
Cipher Block Chaining (CBC) mode with a 16-byte block size
and an initialization vector that shall be randomly generated
and placed as the first 16 bytes in the stream or string. The key
size (Length) shall be 128 bits.
AESV3 (PDF 2.0) The application shall ask the security handler for the
file encryption key and shall implicitly decrypt data with 7.6.3.3,
"Algorithm 1.A: Encryption of data using the AES algorithms",
using the AES-256 algorithm in Cipher Block Chaining (CBC)
with padding mode with a 16-byte block size and an
initialization vector that is randomly generated and placed as
the first 16 bytes in the stream or string. The key size (Length)
shall be 256 bits.
When the value is V2, AESV2 or AESV3, the application may ask once for
this file encryption key and cache the key for subsequent use for
streams that use the same crypt filter. Therefore, there shall be a one-to-
one relationship between a crypt filter name and the corresponding file
encryption key.
Only the values listed here shall be supported. Applications that
encounter other values shall report that the file is encrypted with an
unsupported algorithm.
Default value: None.
AuthEvent        name       (Optional) The event that shall be used to trigger the authorization that
is required to access file encryption keys used by this filter. If
authorization fails, the event shall fail. Valid values shall be:
DocOpen        Authorization shall be required when a document is
opened.
EFOpen         Authorization shall be required when accessing embedded
files.
Default value: DocOpen.
If this filter is used as the value of StrF or StmF in the encryption
dictionary (see "Table 20 — Entries common to all encryption
dictionaries"), the PDF reader shall ignore this key and behave as if the
value is DocOpen.
Key           Type      Value
Length        integer   (Required; deprecated in PDF 2.0) Security handlers may define their
own use of the Length entry and should use it to define the bit length of
the file encryption key. The bit length of the file encryption key shall be
a multiple of 8 in the range of 40 to 256. The standard security handler
expresses the Length entry in bytes (e.g., 32 means a length of 256 bits)
and public-key security handlers express it as is (e.g., 256 means a
length of 256 bits).
When CFM is AESV2, the Length key shall have the value of 128. When
CFM is AESV3, the Length key shall have a value of 256.
NOTE    (2020) The Length key was corrected to be required and the
descriptive text updated.
Security handlers may add their own private data to crypt filter dictionaries. Names for private data
entries shall conform to the PDF name registry (see Annex E, "Extending PDF").
Table 26 — Standard crypt filter names
Name           Description
Identity       Input data shall be passed through without any processing.
"Table 27 — Additional crypt filter dictionary entries for public-key security handlers" lists the
additional crypt filter dictionary entries used by public-key security handlers (see 7.6.5, "Public-key
security handlers"). When these entries are present, the value of CFM shall be V2 or AESV2 or AESV3.
NOTE          The allowed values of CFM were corrected in this document (2020).
Table 27 — Additional crypt filter dictionary entries for public-key security handlers
Key                 Type       Value
Recipients          string or (Required) If the crypt filter is referenced from StmF or StrF in the
array     encryption dictionary, this entry shall be an array of byte strings, where
each string shall be a binary-encoded CMS object that shall list recipients
that have been granted equal access rights to the document. The enveloped
data contained in the CMS object shall include both a 20-byte seed value
that shall be used to compute the file encryption key (see 7.6.5.3, "Public-
key encryption algorithms") followed by 4 bytes of permissions settings
(see "Table 24 — Public-key security handler user access permissions")
that shall apply to the recipient list. There shall be only one object per
unique set of access permissions. If a recipient appears in more than one
list, the permissions used shall be those in the first matching list.
NOTE    (2020) The cross-reference to Table 24 in the above paragraph was
corrected.
If the crypt filter is referenced from a Crypt filter decode parameter
dictionary (see "Table 14 — Optional parameters for Crypt filters"), this
entry shall be a string that shall be a binary-encoded CMS object that shall
contain a list of all recipients who are permitted to access the
corresponding encrypted stream. The enveloped data contained in the CMS

Key                   Type        Value
object shall be a 20-byte seed value that shall be used to create the file
encryption key that shall be used by the algorithm in "Algorithm 1:
Encryption of data using the RC4 or AES algorithms".
EncryptMetadata boolean           (Optional; used only by crypt filters that are referenced from StmF in an
encryption dictionary) Indicates whether the document-level metadata
stream (see 14.3.2, "Metadata streams") shall be encrypted. PDF processors
shall respect this value when determining whether metadata shall be
encrypted. The value of the EncryptMetadata entry is set by the security
handler rather than the PDF processor. Default value: true.
EXAMPLE           The following shows the use of crypt filters in an encrypted document containing a plaintext document-level
metadata stream. The metadata stream is left as is by applying the Identity crypt filter. The remaining
streams and strings are decrypted using the default filters.
%PDF–2.0
%… at least four binary characters > 127
1 0 obj                                           %Document catalog
<</Type /Catalog
/Pages 2 0 R
/Metadata 6 0 R
>>
endobj
2 0 obj                                                    %Page tree
<</Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj                                                    %1st page
<</Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj                                       %Page contents
<</Length 35>>
stream
… Encrypted Page-marking operators …
endstream
endobj
5 0 obj
<</Title ($#*#%*$#^&##)>>                            %Info dictionary: encrypted text string
endobj
6 0 obj
<</Type /Metadata
/Subtype /XML
/Length 15
/Filter [/Crypt]                                  %Uses a crypt filter
/DecodeParms                                      %with these parameters
<</Type /CryptFilterDecodeParms
/Name /Identity                                %Indicates no encryption
>>
>>
stream
… XML metadata…                                   %Unencrypted metadata
endstream
endobj
8 0 obj                                              %Encryption dictionary
<</Filter /MySecurityHandlerName
/V 4                                        %Version 4: allow crypt filters
/CF                                         %List of crypt filters
<</MyFilter0
<</Type /CryptFilter
/CFM V2>>                             %Uses the standard algorithm
>>
/StrF /MyFilter0                         %Strings are decrypted using /MyFilter0
/StmF /MyFilter0                         %Streams are decrypted using /MyFilter0
…                                        %Private data for /MySecurityHandlerName
/MyUnsecureKey (12345678)
/EncryptMetadata false
>>
endobj
xref
…
trailer
<< /Size 8
/Root 1 0 R
/Info 5 0 R
/Encrypt 8 0 R
/ID [<1379F4B0AA2C1B40B3F1A63E4B8C7810> <4C9F4FF0E656CF40AD95CDEA3E720E1B> ]
%ID is not encrypted
>>
startxref
%%EOF

#### 0.28: 7.6.7 Unencrypted wrapper document
This document allows PDF writers to use custom security handlers that encrypt the strings and
streams within a PDF file using algorithms that are not specified in this standard. This allows PDF
producers the flexibility to adapt to changes in encryption technology and respond to customer needs.
However, when PDF files are encrypted using such non-standard security handlers, users attempting
to open such documents may not have enough information to identify a security handler for the user’s
PDF processor that would enable the document to be decrypted.
To enable PDF producers using non-standard security handlers to provide users with information to
help them identify and install necessary security handler(s) the producer may embed the encrypted
PDF file within an unencrypted PDF file (an unencrypted wrapper). An unencrypted wrapper should
provide guidance informing users of the security handler that is needed to decrypt the embedded
encrypted PDF file (encrypted payload). This subclause specifies use of the collection dictionary and
associated files to identify the encrypted payload in a way that allows PDF processors that already
have the necessary security handler to immediately present the encrypted payload, although PDF
processors without the custom security handler will present the unencrypted wrapper document with
helpful instructions to the user.
To enable automatic display of an encrypted payload within an unencrypted wrapper the PDF
producer shall include a Collection dictionary (as described in 12.3.5, "Collections") identifying the
encrypted payload as the initial document in the collection and setting the collection View to H
(hidden). In addition, the PDF producer shall include the file specification dictionary for the encrypted

payload in the EmbeddedFiles name tree, and as an entry in the AF array in the document catalog. The
file specification dictionary for the encrypted payload shall include the AFRelationship key with a
value of EncryptedPayload, and shall include an encrypted payload dictionary (see "Table 28 — Entries
in an encrypted payload dictionary") with details of the cryptographic filter needed to decrypt the
encrypted payload. For a PDF file that is an unencrypted wrapper for an encrypted payload document,
the EmbeddedFiles name tree shall contain exactly one entry, for the encrypted payload document.
Table 28 — Entries in an encrypted payload dictionary
Key                 Type          Value
Type                name          (Optional) The type of PDF object that this dictionary describes; if present,
shall be EncryptedPayload for an encrypted payload file specification.
Subtype             name          (Required) The name of the cryptographic filter used to encrypt the encrypted
payload document. This allows a PDF processor to easily determine whether
it has the appropriate cryptographic filter.
Version             name          (Optional) The version number of the cryptographic filter used to encrypt the
encrypted payload referenced by this dictionary.
NOTE     The value of Version is not to be interpreted as a real number but as
integers with a PERIOD (2Eh) between them.
EXAMPLE            This example shows details of an unencrypted wrapper document containing an encrypted payload
document.
%PDF-2.0
15 0 obj
<</Length 377 /Filter /FlateDecode>>
stream
…
endstream
endobj
17 0 obj                                         %File Specification Dictionary
<<
/Desc (This embedded file is encrypted using the Acme Custom Crypto filter)
/EF <</F 18 0 R>>
/F (AcmeCustomCrypto Protected PDF.pdf)
/Type /Filespec
/UF (AcmeCustomCrypto Protected PDF.pdf)
/EP
<<
/Type /EncryptedPayload
/Subtype /AcmeCustomCrypto
/Version /1.0
>>
/AFRelationship /EncryptedPayload
>>
endobj
18 0 obj                                         %Embedded File stream
<<
/Type /EmbeddedFile
/DL 123456
/Filter /FlateDecode
/Length 123456
/Params
<<
/CheckSum <01234567890123456789012345678901>

