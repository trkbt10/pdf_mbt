# pdf-common-data validate_text_stream_bytes requirements

This SDD Draft records ISO 32000-2 clause 7.9 common data requirements
implemented by the `src/common_data` validators for text strings, dates,
rectangles, name trees, number trees, and `validate_text_stream_bytes`.

## Requirements validate_text_stream_bytes

The requirements below map to the common-data value model, diagnostics, string
qualification, text stream validation, date parsing, rectangle validation, and
tree key and pair-array validation APIs, including `validate_text_stream_bytes`.

#### 0.1: 7.9.1 General
As mentioned at the beginning of this clause, there are some general-purpose data structures that are
built from the basic object types described in 7.3, "Objects" and used throughout PDF technology. This
subclause describes data structures for text strings, dates, rectangles, name trees, and number trees.
More complex data structures are described in 7.10, "Functions" and 7.11, "File specifications".
All of these data structures are meaningful only as part of the document hierarchy; they may not
appear within content streams. In particular, the special conventions for interpreting the values of
string objects apply only to strings outside content streams. An entirely different convention is used
within content streams for using strings to select sequences of glyphs to be painted on the page (see
clause 9, "Text"). "Table 35 — PDF data types" summarises the basic and higher-level data types that
are used throughout this document to describe the values of dictionary entries and other PDF data
values.
Table 35 — PDF data types
Type                               Description                                  Subclause
ASCII string                       Bytes containing ASCII characters            7.9.2
array                              Array object                                 7.3.6
boolean                            Boolean value                                7.3.2
byte string                        A series of bytes that shall represent       7.9.2
characters or other binary data. If          7.9.2.4
such a type represents characters,
the encoding shall be determined by
the context.
date                               Date (ASCII string)                          7.9.4
dictionary                         Dictionary object                            7.3.7
file specification                 File specification (string or                7.11
dictionary)
function                           Function (dictionary or stream)              7.10

Type                                 Description                               Subclause
integer                              Integer number                            7.3.3
name                                 Name object                               7.3.5
name tree                            Name tree (dictionary)                    7.9.6
null                                 Null object                               7.3.9
number                               Number (integer or real)                  7.3.3
number tree                          Number tree (dictionary)                  7.9.7
PDFDocEncoded string                 Bytes containing a string that shall      7.9.2
be encoded using PDFDocEncoding           7.9.2.3
rectangle                            Rectangle (array)                         7.9.5
stream                               Stream object                             7.3.8
string                               Any string that is not a text string.     7.9.2
Beginning with PDF 1.7, this type is
further qualified as the types:
ASCII string and byte string.
text string                          Bytes that represent characters that 7.9.2
shall be encoded using either          7.9.2.2
PDFDocEncoding, UTF-16BE or UTF-
8 (as defined in 7.9.2.2, "Text string
type".)
text stream                          Text stream                               7.9.3

#### 0.2: 7.9.2.1           General
PDF supports one fundamental string object (see 7.3.4, "String objects"). The string object shall be
further qualified as a text string, ASCII string, or byte string. The further qualification reflects the
encoding used to represent the characters or glyphs described by the string.
The string types described in "Table 35 — PDF data types" specify increasingly specific encoding
schemes, as shown in "Figure 7 — Relationship between string types".
Figure 7 — Relationship between string types

#### 0.3: 7.9.2.2.1           General
The text string type shall be used for character strings that contain information intended to be human-
readable, such as text annotations, document outline item names, article names, and so forth.
NOTE 1        Text string type is a subtype of string type and represents data encoded using specific
conventions.
The text string type shall be used for character strings that shall be encoded in PDFDocEncoding, the
UTF-16BE Unicode character encoding scheme, or (PDF 2.0) the UTF-8 Unicode character encoding
scheme. PDFDocEncoding can encode all of the ISO Latin 1 character set and is documented in Annex
D, "Character sets and encodings". UTF-16BE and UTF-8 can encode all Unicode characters. UTF-16BE,
UTF-8 and Unicode character encoding are described in The Unicode Standard by the Unicode
Consortium.
EXAMPLE 1           A PDF dictionary containing key ‘Key’ with the value that is the text string "text‰" will look like
<</Key(text?)>>
where the character ‘?’ after the ‘text’ is represented by the hex code 8B (octal code 213 - that is according
to "D.2 Latin character set and encodings").
NOTE 2        PDFDocEncoding does not support all Unicode characters whereas UTF-16BE and UTF-8 do.
For text strings encoded in UTF-16BE, the first two bytes shall be 254 followed by 255. These two
bytes represent the Unicode byte order marker, ZERO WIDTH NO-BREAK SPACE (U+FEFF), indicating
that the string is encoded in the UTF-16BE (big-endian) encoding scheme specified in Unicode.
EXAMPLE 2           A PDF dictionary containing key ‘Key’ with the value that is the text string "тест" (that is what the word in
Russian with the translation to English as ‘test’) will look like
<</Key(??????????)>>
where the characters in parentheses is the sequence of bytes with hex codes FE, FF, 04,
42, 04, 35, 04, 41, 04, 42.
NOTE 3        This mechanism precludes beginning a string using PDFDocEncoding with the two characters
thorn ydieresis, which is unlikely to be a meaningful beginning of a word or phrase.
For text strings encoded in UTF-8, the first three bytes shall be 239 followed by 187, followed by 191.
These three bytes represent the Unicode byte order marker indicating that the string is encoded in the
UTF-8 encoding scheme specified in Unicode.

NOTE 4      This mechanism precludes beginning a string using PDFDocEncoding with the three characters
dieresis, guillemotright, questiondown, which is unlikely to be a meaningful beginning of a word
or phrase.
PDF readers that process PDF files containing Unicode text strings shall be prepared to handle
supplementary characters; that is, characters requiring more than two bytes to represent.
NOTE 5      It is important not to confuse UTF-16BE with UCS2 (i.e. wchar_t). UTF-16 is not a fixed width
encoding scheme.

Implementation alignment: `parse_text_string` returns a `PdfTextString` with raw bytes, decoded text,
selected encoding, and `PdfLanguageSpan` metadata where Unicode language escape sequences are
present.

#### 0.4: 7.9.2.2.2         Text string language escape sequences
Escape sequences may appear anywhere in a Unicode text string to indicate the language in which
subsequent text shall be written.
NOTE 1      This is useful when the language cannot be determined from the character codes used in the text.
The escape sequence shall consist of the following elements, in order:
a) The Unicode value ESCAPE (U+001B) (that is, for strings encoded in UTF-16BE, the byte sequence 0
followed by 27; for strings encoded in UTF-8 the byte value 27).
b) A 2- byte BCP 47 language code.
EXAMPLE 1         en for English or ja for Japanese encoded as ASCII characters.
c) (Optional) A 2-byte ISO 3166 country code.
EXAMPLE 2         US for the United States or JP for Japan encoded as ASCII characters.
d) The Unicode value ESCAPE (U+001B).
NOTE 2      The complete list of codes defined by BCP 47 and ISO 3166 can be obtained from the Internet
Engineering Task Force and the International Organization for Standardization.
NOTE 3      Since Unicode defines an escape sequence for indicating the language of the text, this mechanism
enables the alternate description to change from the language specified by the prevailing Lang
entry.

#### 0.5: 7.9.2.3           PDFDocEncoded string type
A PDFDocEncoded string is a character string in which the characters shall be represented in a single
byte using PDFDocEncoding.
NOTE        PDFDocEncoding does not support all Unicode characters whereas UTF-16BE or UTF-8 do.

#### 0.6: 7.9.2.4           Byte string type
The byte string type shall be used for binary data that shall be represented as a series of bytes, where
each byte may be any value representable in 8 bits. Byte string type is a subtype of string type. For
example, byte strings are used to define a file identifier (see 14.4, "File identifiers") that is specified in
ID entry of PDF file trailer (see "Table 15 — Entries in the file trailer dictionary"). In such case byte
string is written in hexadecimal form (see 7.3.4.3, "Hexadecimal strings") and looks like
<B6FB54F3F8554D478DC874F11DAD0F11>
NOTE        The string can represent characters but the encoding is not known. The bytes of the string do not
have to represent characters.

#### 0.7: 7.9.3 Text streams
A text stream (PDF 1.5) shall be a PDF stream object (7.3.8, "Stream objects") whose unencoded bytes
shall meet the same requirements as a text string (7.9.2.2, "Text string type") with respect to encoding,
byte order, and lead bytes.

#### 0.8: 7.9.4 Dates
Date values used in a PDF shall conform to a standard date format, which closely follows that of the
international standard ASN.1 (Abstract Syntax Notation One), defined in ISO/IEC 8824-1. A date shall
be a text string value containing no white-space, of the form:
(D:YYYYMMDDHHmmSSOHH'mm)
where:
YYYY shall be the year
MM shall be the month (01–12)
DD shall be the day (01–31)
HH shall be the hour (00–23)
mm shall be the minute (00–59)
SS shall be the second (00–59)
O shall be the relationship of local time to Universal Time (UT), and shall be denoted by one of the
characters PLUS SIGN (U+002B) (+), HYPHEN-MINUS (U+002D) (-), or LATIN CAPITAL LETTER Z
(U+005A) (Z) (see below)
HH followed by APOSTROPHE (U+0027) (') shall be the absolute value of the offset from UT in
hours (00–23)
mm shall be the absolute value of the offset from UT in minutes (00–59)
The prefix “D:” shall be present, the year field (YYYY) shall be present and all other fields may be
present but only if all of their preceding fields are also present. The APOSTROPHE following the hour
offset field (HH) shall only be present if the HH field is present. The minute offset field (mm) shall only
be present if the APOSTROPHE following the hour offset field (HH) is present. The default values for
MM and DD shall be both 01; all other numerical fields shall default to zero values. A PLUS SIGN as the
value of the O field signifies that local time is now and later than UT, a HYPHEN-MINUS signifies that
local time is earlier than UT, and the LATIN CAPITAL LETTER Z signifies that local time is equal to UT.
If no UT information is specified, the relationship of the specified time to UT shall be considered to be
GMT. Regardless of whether the time zone is specified, the rest of the date shall be specified in local
time.
EXAMPLE        For example, December 23, 1998, at 7:52 PM, U.S. Pacific Standard Time, is represented by the string:
D:199812231952-08'00
NOTE 1     A date string can be any valid PDF string object as described in 7.3.4, "String objects". The
description above relates to the text string value after appropriate processing.

NOTE 2        PDF versions up to and including 1.7 defined a date string to include a terminating apostrophe.
PDF processors are recommended to accept date strings that still follow that convention.
NOTE 3        The letter Z can optionally be followed by hour and minute offsets, which are zero in this case.

Implementation alignment: `PdfUtcOffset` records omitted GMT information, equality with UT, and
local time later than or earlier than UT without converting the local date fields to system time.

#### 0.9: 7.9.5 Rectangles
Rectangles are used to describe locations on a page and bounding boxes for a variety of objects. A
rectangle shall be written as an array of four numbers giving the coordinates of a pair of diagonally
opposite corners.
Typically, the array takes the form
[llx lly urx ury]
specifying the lower-left x, lower-left y, upper-right x, and upper-right y coordinates of the rectangle, in
that order. The other two corners of the rectangle are then assumed to have coordinates (llx, ury) and
(urx, lly).
NOTE          Rectangles can have a width of zero or height of zero.

Implementation alignment: parsing preserves the source rectangle coordinate order. Any
`PdfRectangle::normalized` helper is an explicit caller opt-in and is not applied by rectangle
validation.

#### 0.10: 7.9.6 Name trees
A name tree serves a similar purpose to a dictionary — associating keys and values — but by different
means. A name tree differs from a dictionary in the following important ways:
•    Unlike the keys in a dictionary, which are name objects, those in a name tree are strings.
•    The keys are ordered.
•    The values associated with the keys may be objects of any type. Stream objects shall be specified
by indirect object references (7.3.8, "Stream objects"). The dictionary, array, and string objects
should be specified by indirect object references, and other PDF objects (null objects, numbers,
booleans, and names) should be specified as direct objects.
•    The data structure can represent an arbitrarily large collection of key-value pairs, which can be
looked up efficiently without requiring the entire data structure to be read from the PDF file. (In
contrast, a dictionary can be subject to an implementation limit on the number of entries it can
contain.)
A name tree shall be constructed of nodes, each of which shall be a dictionary object. "Table 36 —
Entries in a name tree node dictionary" shows the entries in a node dictionary. The nodes shall be of
three kinds, depending on the specific entries they contain. The tree shall always have exactly one root
node, which shall contain a single entry: either Kids or Names but not both. If the root node has a
Names entry, it shall be the only node in the tree. If it has a Kids entry, each of the remaining nodes
shall be either an intermediate node, that shall contain a Limits entry and a Kids entry, or a leaf node,
that shall contain a Limits entry and a Names entry.
Table 36 — Entries in a name tree node dictionary
Key        Type       Value
Kids       array      (Root and intermediate nodes only; required in intermediate nodes; present in
the root node if and only if Names is not present) Shall be an array of indirect
references to the immediate children of this node. The children may be
intermediate or leaf nodes.
Names      array      (Root and leaf nodes only; required in leaf nodes; present in the root node if
and only if Kids is not present) Shall be an array of the form
[key1 value1 key2 value2 …keyn valuen]
where each keyi shall be a string and the corresponding valuei shall be the
object associated with that key. The keys shall be sorted in lexical order, as
described below.
Limits     array      (Required for intermediate and leaf nodes; not permitted in root nodes) Shall
be an array of two strings, that shall specify the (lexically) least and greatest
keys included in the Names array of a leaf node or in the Names arrays of
any leaf nodes that are descendants of an intermediate node.
The Kids entries in the root and intermediate nodes define the tree’s structure by identifying the
immediate children of each node. The Names entries in the leaf (or root) nodes shall contain the tree’s
keys and their associated values, arranged in key-value pairs and shall be sorted lexically in ascending
order by key. Shorter keys shall appear before longer ones beginning with the same byte sequence.
Any encoding of the keys may be used as long as it is self-consistent; keys shall be compared for
equality on a simple byte-by-byte basis.
The keys contained within the various nodes’ Names entries shall not overlap; each Names entry shall
contain a single contiguous range of all the keys in the tree. In a leaf node, the Limits entry shall specify
the least and greatest keys contained within the node’s Names entry. In an intermediate node, it shall
specify the least and greatest keys contained within the Names entries of any of that node’s
descendants. The value associated with a given key can thus be found by walking the tree in order,
searching for the leaf node whose Names entry contains that key.

Implementation alignment: `compare_name_tree_keys` implements byte-by-byte lexical order, and
`PdfNameTreeEntry` preserves each string key with the associated raw object value.

EXAMPLE 1       The following is an abbreviated outline, showing object numbers and nodes, of a name tree that maps the
names of all the chemical elements, from actinium to zirconium, to their atomic numbers.
Example of a name tree
1: Root node
2: Intermediate node: Actinium to Gold
5: Leaf node: Actinium = 25,…, Astatine = 31
25: Integer: 89
…
31: Integer: 85
…
11: Leaf node: Gadolinium = 56,…, Gold = 59
56: Integer: 64
…
59: Integer: 79
3: Intermediate node: Hafnium to Protactinium
12: Leaf node: Hafnium = 60,…, Hydrogen = 65
60: Integer: 72

…
65: Integer: 1
…
19: Leaf node: Palladium = 92,…, Protactinium = 100
92: Integer: 46
…
100:Integer: 91
4: Intermediate node: Radium to Zirconium
20: Leaf node: Radium = 101,…, Ruthenium = 107
101:Integer: 89
…
107:Integer: 85
…
24: Leaf node: Xenon = 129,…, Zirconium = 133
129:Integer: 54
…
133:Integer: 40
EXAMPLE 2         The following shows the representation of this tree in a PDF file:
1 0 obj
<</Kids [2 0 R                                       %Root node
3 0 R
4 0 R
]
>>
endobj
2 0 obj
<</Limits [(Actinium) (Gold)]                        %Intermediate node
/Kids [5 0 R
6 0 R
7 0 R
8 0 R
9 0 R
10 0 R
11 0 R
]
>>
endobj
3 0 obj
<</Limits [(Hafnium) (Protactinium)]                   %Intermediate node
/Kids [12 0 R
13 0 R
14 0 R
15 0 R
16 0 R
17 0 R
18 0 R
19 0 R
]
>>
endobj
4 0 obj
<</Limits [(Radium) (Zirconium)]                               %Intermediate node
/Kids [20 0 R
21 0 R
22 0 R
23 0 R
24 0 R
]
>>
endobj
5 0 obj
<</Limits [(Actinium) (Astatine)]                 `        %Leaf node
/Names [(Actinium) 25 0 R
(Aluminum) 26 0 R
(Americium) 27 0 R
(Antimony) 28 0 R
(Argon) 29 0 R
(Arsenic) 30 0 R
(Astatine) 31 0 R
]
>>
endobj
…
24 0 obj
<</Limits [(Xenon) (Zirconium)]                            %Leaf node
/Names [(Xenon) 129 0 R
(Ytterbium) 130 0 R
(Yttrium) 131 0 R
(Zinc) 132 0 R
(Zirconium) 133 0 R
]
>>
endobj
25 0 obj
89                                                         %Atomic number (Actinium)
endobj
…
133 0 obj
40                                                         %Atomic number (Zirconium)
endobj

#### 0.11: 7.9.7 Number trees
A number tree is similar to a name tree (see 7.9.6, "Name trees"), except that its keys shall be integers
instead of strings and shall be sorted in ascending numerical order. The entries in the leaf (or root)
nodes containing the key-value pairs shall be named Nums instead of Names as in a name tree. "Table
37 — Entries in a number tree node dictionary" shows the entries in a number tree’s node dictionaries.
Table 37 — Entries in a number tree node dictionary
Key        Type      Value
Kids       array     (Root and intermediate nodes only; required in intermediate nodes; present in
the root node if and only if Nums is not present) Shall be an array of indirect
references to the immediate children of this node. The children may be
intermediate or leaf nodes.
Nums       array     (Root and leaf nodes only; shall be required in leaf nodes; present in the root
node if and only if Kids is not present) Shall be an array of the form:
[key1 value1 key2 value2 …keyn valuen]
where each keyi is an integer and the corresponding valuei shall be the object
associated with that key. The keys shall be sorted in numerical order,
analogously to the arrangement of keys in a name tree as described in 7.9.6,
"Name trees".

Implementation alignment: `compare_number_tree_keys` implements ascending integer key order, and
`PdfNumberTreeEntry::compare_key` compares a stored number-tree key with a caller-supplied key for
lookup and enumeration helpers.

#### API alignment: compare_name_tree_keys
The public `compare_name_tree_keys` helper is part of the name tree requirement because name-tree
keys are strings ordered by byte-by-byte lexical comparison.

#### API alignment: compare_number_tree_keys
The public `compare_number_tree_keys` helper is part of the number tree requirement because
number-tree keys are integers sorted in ascending numerical order.

#### API alignment: PdfLanguageSpan
The public `PdfLanguageSpan` value is part of the Unicode language escape requirement because it
records the ESCAPE-delimited BCP 47 language code and optional ISO 3166 country code.

#### API alignment: PdfTextString
The public `PdfTextString` value is part of the text string requirement because it preserves raw
bytes, decoded text, selected PDFDocEncoding, UTF-16BE, or UTF-8 encoding, and language spans.

#### API alignment: PdfUtcOffset
The public `PdfUtcOffset` value is part of the date requirement because it records whether local time
is equal to UT, later than UT, earlier than UT, or has omitted GMT information.

#### API alignment: PdfRectangle::normalized
The public `PdfRectangle::normalized` helper is outside rectangle parsing semantics: validation
preserves lower-left and upper-right coordinate order, while normalization is an explicit caller
operation.

#### API alignment: PdfNumberTreeEntry::compare_key
The public `PdfNumberTreeEntry::compare_key` helper is part of number-tree lookup support because
it compares an entry key with a caller-supplied integer key.

#### API alignment: parse_text_string
The public `parse_text_string` helper is part of text string decoding because it selects UTF-16BE
from leading bytes 254 and 255, UTF-8 from leading bytes 239, 187, and 191, and PDFDocEncoding
otherwise.
