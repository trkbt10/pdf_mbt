# SDD Draft

Generated from:
- `spec/extracted/7.11-file-specifications.spec.txt`

## Requirements

#### 0.1: 7.11.1          General
A PDF file can refer to the contents of another file by using a file specification (PDF 1.1), which shall
take either of two forms:
•    A simple file specification shall give just the name of the target file in a standard format,
independent of the naming conventions of any particular file system. It shall take the form of
either a string or a dictionary.
•    A full file specification shall include information related to one or more specific file systems. It
shall only be represented as a dictionary.
A file specification shall refer to a file external to the PDF file or to a file embedded within the referring
PDF file, allowing its contents to be stored or transmitted along with the PDF file. The file is considered
external to the PDF file in either case.

#### 0.2: 7.11.2.1        General
The standard format for representing a simple file specification in string form divides the string into
component substrings separated by the SOLIDUS character (2Fh) (/). The SOLIDUS is a generic

component separator that shall be mapped to the appropriate platform-specific separator when
generating a platform-dependent file name. Any of the components may be empty. If a component
contains one or more literal SOLIDIUS character, each shall be preceded by a REVERSE SOLIDUS (5Ch)
(\), which in turn shall be preceded by another REVERSE SOLIDUS to indicate that it is part of the
string and not an escape character.
EXAMPLE
(in\\/out)
represents the file name
in/out
The REVERSE SOLIDIUS character shall be removed in processing the string; they are needed only to
distinguish the component values from the component separators. The component substrings shall be
stored as bytes and shall be passed to the operating system without interpretation or conversion of
any sort.

#### 0.3: 7.11.2.2          Absolute and relative file specifications
A simple file specification that begins with a SOLIDUS shall be an absolute file specification. The last
component shall be the file name; the preceding components shall specify its context. In some file
specifications, the file name may be empty; for example, URL (uniform resource locator) specifications
can specify directories instead of files. A file specification that does not begin with a SOLIDUS shall be a
relative file specification giving the location of the file relative to that of the PDF file containing it.
In the case of a URL-based file system, the rules of Internet RFC 3986 shall be used to compute an
absolute URL from a relative file specification and the specification of the PDF file. Prior to this process,
the relative file specification shall be converted to a relative URL by using the escape mechanism of
Internet RFC 3986 to represent any bytes that would be either unsafe according to Internet RFC 3986 or
not representable in 7-bit U.S. ASCII. In addition, such URL-based relative file specifications shall be
limited to paths as defined in Internet RFC 3986. The scheme, network location/login, fragment
identifier, query information, and parameter sections shall not be allowed.
In the case of other file systems, a relative file specification shall be converted to an absolute file
specification by removing the file name component from the specification of the containing PDF file
and appending the relative file specification in its place.
EXAMPLE 1         The relative file specification
ArtFiles/Figure1.pdf
appearing in a PDF file whose specification is
/HardDisk/PDFDocuments/AnnualReport/Summary.pdf
yields the absolute specification
/HardDisk/PDFDocuments/AnnualReport/ArtFiles/Figure1.pdf
The special component . . (two PERIODs) (2Eh) can be used in a relative file specification to move up a
level in the file system hierarchy. After an absolute specification has been derived, when the
component immediately preceding . . is not another . ., the two cancel each other; both are eliminated
from the file specification and the process is repeated.
EXAMPLE 2      The relative file specification from Example 1 in this subclause using the .. (two PERIODs) special component
../../ArtFiles/Figure1.pdf
would yield the absolute specification
/HardDisk/ArtFiles/Figure1.pdf

#### 0.4: 7.11.3         File specification dictionaries
The dictionary form of file specification provides more flexibility than the string form, allowing
different files to be specified for different file systems or platforms. "Table 43 — Entries in a file
specification dictionary" shows the entries in a file specification dictionary. PDF writers should use the
F entries to specify files. The UF entry is optional, but should be included because it enables cross-
platform and cross-language compatibility.
Table 43 — Entries in a file specification dictionary
Key                Type          Value
Type               name          (Required if an EF, EP or RF entry is present; recommended always) The type of
PDF object that this dictionary describes; shall be Filespec for a file
specification dictionary.
FS                 name          (Optional) The name of the file system that shall be used to interpret this file
specification. If this entry is present, all other entries in the dictionary shall
be interpreted by the designated file system. PDF shall define only one
standard file system name, URL (see 7.11.5, "URL specifications"); an
application can register other names (see Annex E, "Extending PDF"). This
entry shall be independent of the F and UF entries.
F                  string        (Required if the DOS, Mac, and Unix entries are all absent; amended with the UF
entry for PDF 1.7) A file specification string of the form described in 7.11.2,
"File specification strings" or (if the file system is URL) a uniform resource
locator, as described in 7.11.5, "URL specifications".
The UF entry should be used in addition to the F entry. The UF entry provides
cross-platform and cross-language compatibility and the F entry provides
backwards compatibility. A PDF reader shall use the value of the UF key,
when present, instead of the F key.
(PDF 2.0) For unencrypted wrapper documents for an encrypted payload
document (see 7.6.7, "Unencrypted wrapper document") the F entry shall not
contain or be derived from the encrypted payload’s actual file name. This is to
avoid potential disclosure of sensitive information in the original filename.
The value of F for encrypted payload documents should include the name of
the cryptographic filter needed to decrypt the document. See the example in
7.6.7, "Unencrypted wrapper document".

Key                  Type            Value
UF                   text string     (Optional, but recommended if the F entry exists in the dictionary; PDF 1.7) A
Unicode text string that provides file specification of the form described in
7.11.2, "File specification strings". This is a text string as defined in 7.9.2.2,
"Text string type". The F entry should be included along with this entry for
backwards compatibility reasons. A PDF reader shall use the value of the UF
key, when present, instead of the F key.
(PDF 2.0) For unencrypted wrapper documents for an encrypted payload
document (see 7.6.7, "Unencrypted wrapper document") the UF entry shall
not contain or be derived from the encrypted payload’s actual file name. This
is to avoid potential disclosure of sensitive information in the original
filename.
DOS                  byte string (Optional; deprecated in PDF 2.0) A file specification string (see 7.11.2, "File
specification strings") representing a DOS file name.
Mac                  byte string (Optional; deprecated in PDF 2.0) A file specification string (see 7.11.2, "File
specification strings") representing a Mac OS file name.
Unix                 byte string (Optional; deprecated in PDF 2.0) A file specification string (see 7.11.2, "File
specification strings") representing a UNIX file name.
ID                   array           (Optional) An array of two byte strings constituting a file identifier (see 14.4,
"File identifiers") that should be included in the referenced file.
NOTE 1 The use of this entry improves a PDF processor’s chances of finding the
intended file, and allows a PDF processor to warn the user if the file has
changed since the link was made.
V                    boolean         (Optional; PDF 1.2) A flag indicating whether the file referenced by the file
specification is volatile (changes frequently with time). If the value is true,
applications shall not cache a copy of the file. For example, a movie
annotation referencing a URL to a live video camera could set this flag to true
to notify the PDF reader that it should re-acquire the movie each time it is
played. Default value: false.
EF                   dictionary      (Required if RF is present; PDF 1.3; amended to include the UF key in PDF 1.7) A
dictionary containing a subset of the F and UF keys corresponding to the
entries by those names in the file specification dictionary. The value of each
such key shall be an embedded file stream (see 7.11.4, "Embedded file
streams") containing the corresponding file. If this entry is present, the Type
entry is required and the file specification dictionary shall be indirectly
referenced.
(PDF 2.0) For unencrypted wrapper documents for an encrypted payload
document (see 7.6.7, "Unencrypted wrapper document") the EF dictionary is
required for the file stream containing the encrypted payload.
RF                   dictionary      (Optional; PDF 1.3) A dictionary with the same structure as the EF dictionary,
which shall be present. For each key in this dictionary, the same key shall
appear in the EF dictionary of this file specification dictionary. Each value
shall be a related files array (see 7.11.4.2, "Related files arrays") identifying
files that are related to the corresponding file in the EF dictionary. If this
entry is present, the Type entry is required and the file specification
dictionary shall be indirectly referenced.
Key          Type          Value
Desc         text string   (Optional; PDF 1.6) Descriptive text associated with the file specification. It
shall be used for file specification dictionaries referenced from the
EmbeddedFiles name tree (see 7.7.4, "Name dictionary").
CI           dictionary    (Optional; shall be indirect reference; PDF 1.7) A collection item dictionary,
which shall be used to create the user interface for portable collections (see
7.11.6, "Collection items").
Thumb        stream        (Optional; PDF 2.0) A stream object defining the thumbnail image for the file
specification. (See 12.3.4, "Thumbnail images")
EP           dictionary    (PDF 2.0; Required if this file specification references an encrypted payload
document as described in 7.6.7, "Unencrypted wrapper document") The value
of this key is an encrypted payload dictionary which identifies that the file
specified in the EF dictionary is an encrypted payload.

Key                  Type          Value
AFRelationship       name          (Optional; PDF 2.0) A name value that represents the relationship between
the component of this PDF document that refers to this file specification and
the associated file denoted by this file specification dictionary. See 14.13,
"Associated files" for more details. These values represent the following
relationships:
Source                shall be used if this file specification is the original source
material for the associated content.
Data                  shall be used if this file specification represents
information used to derive a visual presentation – such
as for a table or a graph.
Alternative           shall be used if this file specification is an alternative
representation of content, for example audio.
Supplement            shall be used if this file specification represents a
supplemental representation of the original source or
data that may be more easily consumable (e.g., A MathML
version of an equation).
EncryptedPayload shall be used if this file specification is an encrypted
payload document that should be displayed to the user if
the PDF processor has the cryptographic filter needed to
decrypt the document.
FormData              shall be used if this file specification is the data
associated with the AcroForm (see 12.7.3, "Interactive
form dictionary") of this PDF.
Schema                shall be used if this file specification is a schema
definition for the associated object (e.g. an XML schema
associated with a metadata stream).
Unspecified           shall be used when the relationship is not known or
cannot be described using one of the other values.
NOTE 2 Unspecified is to be used only when no other value correctly reflects the
relationship.
Second-class names (see Annex E, “Extending PDF") should be used to
represent other types of relationships.
Default: Unspecified
NOTE 3 The value of AFRelationship does not explicitly provide any processing
instructions for a PDF processor. It is provided for information and
semantic purposes for those processors that are able to use such additional
information.

#### 0.5: 7.11.4.1          General
If a PDF file contains file specifications that refer to an external file and the PDF file is archived or
transmitted, some provision should be made to ensure that the external references will remain valid.
One way to do this is to arrange for the external files to accompany the PDF file. Embedded file streams
(PDF 1.3) address this problem by allowing the contents of referenced files to be embedded directly
within the body of the PDF file. This makes the PDF file a self-contained unit that can be stored or
transmitted as a single entity. (The embedded files are included purely for convenience and need not
be directly processed by any PDF processor.)
NOTE        If the file contains OPI (Open Prepress Interface) dictionaries that refer to externally stored high-
resolution images (see 14.11.7, "Open prepress interface (OPI)"), the image data can be
incorporated into the PDF file with embedded file streams.
An embedded file stream shall be included in a PDF file in one of the following ways:
•     Any file specification dictionary in the document may have an EF entry that specifies an
embedded file stream. The stream data shall still be associated with a location in the file system.
In particular, this method shall be used for file attachment annotations (see 12.5.6.15, "File
attachment annotations"), which associate the embedded file with a location on a page in the
document.
•     Embedded file streams may be associated with the document as a whole through the
EmbeddedFiles entry in the PDF file’s name dictionary (see 7.7.4, "Name dictionary"). The
associated name tree shall map name strings to file specifications that refer to embedded file
streams through their EF entries.
Beginning with PDF 1.6, the Desc entry of the file specification dictionary (see "Table 43 — Entries in a
file specification dictionary") should be used to provide a textual description of the embedded file,
which can be displayed in the user interface of an interactive PDF processor. Previously, it was
necessary to identify document-level embedded files by the name string provided in the name
dictionary associated with an embedded file stream in much the same way that the ECMAScript name
tree associates name strings with document-level ECMAScript actions (see 12.6.4.17, "ECMAScript
actions").
The stream dictionary describing an embedded file shall contain the standard entries for any stream,
such as Length and Filter (see "Table 5 — Entries common to all stream dictionaries"), as well as the
additional entries shown in "Table 44 — Additional entries in an embedded file stream dictionary".
Table 44 — Additional entries in an embedded file stream dictionary
Key       Type           Value
Type      name           (Optional) The type of PDF object that this dictionary describes; if present, shall
be EmbeddedFile for an embedded file stream.
Subtype   name           (Optional, required in the case of an embedded file stream used as an associated
file) The subtype of the embedded file. The value of this entry shall conform to the
MIME media type names defined in Internet RFC 2046, with the provision that
characters not permitted in names shall use the 2-character hexadecimal code
format described in 7.3.5, "Name objects".
NOTE The media type for PDF is defined by Internet RFC 8118.
Params    dictionary     (Optional, required in the case of an embedded file stream used as an associated
file) An embedded file parameter dictionary that shall contain additional file-
specific information (see "Table 45 — Entries in an embedded file parameter
dictionary").
Table 45 — Entries in an embedded file parameter dictionary
Key            Type           Value
Size           integer        (Optional) The size of the uncompressed embedded file, in bytes. See "Table
155 — Entries in a collection field dictionary".

Key               Type            Value
CreationDate      date            (Optional) The date and time when the embedded file was created. See
"Table 155 — Entries in a collection field dictionary".
ModDate           date            (Optional, required in the case of an embedded file stream used as an
associated file) The date and time when the embedded file was last modified.
See "Table 155 — Entries in a collection field dictionary".
Mac               dictionary      (Optional; deprecated in PDF 2.0) A subdictionary containing additional
information specific to Mac OS files.
CheckSum          string          (Optional) A 16-byte string that is the checksum of the bytes of the
uncompressed embedded file. The checksum shall be calculated by applying
the standard MD5 message-digest algorithm (defined in Internet RFC 1321)
to the bytes of the embedded file stream.
NOTE     This is strictly a checksum, and is not used for security purposes.

#### 0.6: 7.11.4.2          Related files arrays
In some circumstances, a PDF file can refer to a group of related files, such as the set of five files that
make up a DCS 1.0 colour-separated image. The file specification explicitly names only one of the files;
the rest shall be identified by some systematic variation of that file name (such as by altering the
extension). When such a file is to be embedded in a PDF file, the related files shall be embedded as well.
This is accomplished by including a related files array (PDF 1.3) as the value of the RF entry in the file
specification dictionary. The array shall have 2 × n elements, which shall be paired in the form
[        string1 stream1
string2 stream2
…
stringn streamn
]
The first element of each pair shall be a string giving the name of one of the related files; the second
element shall be an embedded file stream holding the file’s contents.

#### 0.7: 7.11.5          URL specifications
When the FS entry in a file specification dictionary has the value URL, the value of the F entry in that
dictionary is not a file specification string, but a uniform resource locator (URL) of the form defined in
Internet RFC 3986.
The URL shall adhere to the character-encoding requirements specified in Internet RFC 3986. Because
7-bit U.S. ASCII is a strict subset of PDFDocEncoding, this value shall also be considered to be in
PDFDocEncoding.

#### 0.8: 7.11.6          Collection items
Beginning with PDF 1.7, a collection item dictionary shall contain the data described by the collection
schema dictionary for a particular file in a collection (see 12.3.5, "Collections"). "Table 46 — Entries in
a collection item dictionary" describes the entries in a collection item dictionary.
Table 46 — Entries in a collection item dictionary
Key          Type        Value
Type         name        (Optional) The type of PDF object that this dictionary describes; if present, shall be
CollectionItem for a collection item dictionary.
