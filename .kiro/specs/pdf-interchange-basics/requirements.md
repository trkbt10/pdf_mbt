# SDD Draft

Generated from:
- `spec/extracted/14.1-14.6-interchange-basics.spec.txt`

## Requirements

### Requirement 1: 14.1 General
The features described in this clause do not affect the final appearance of a document. Rather, these
features enable a document to include higher-level information useful to the interchange of documents
among PDF processors:
•   Procedure sets (14.2, "Procedure sets") that define the implementation of PDF operators
(deprecated in PDF 2.0)
•   Metadata (14.3, "Metadata") consisting of general information about a document or a component
of a document, such as its title, author, and creation and modification dates
•   File identifiers (14.4, “File identifiers") for reliable reference from one PDF file to another
•   Page-piece dictionaries (14.5, "Page-piece dictionaries") allow a PDF processor to embed private
data in a PDF document for its own use
•   Marked-content operators (14.6, "Marked content") for identifying portions of a content stream
and associating them with additional properties or externally specified objects
•   Logical structure facilities (14.7, "Logical structure") for imposing a hierarchical organisation on
the content of a document
•   Tagged PDF (14.8, "Tagged PDF"), a set of conventions for using marked-content and logical
structure facilities to enable the extraction and reuse of a document’s content for other purposes
•   Various ways of enhancing the repurposing and accessibility of a document (14.9, "Repurposing
and accessibility support"), including natural language identification of document content
•   The Web Capture extension (14.10, "Web capture"), which creates PDF files from Internet-based
or locally resident HTML, PDF, GIF, JPEG, and ASCII text files
•   Facilities supporting prepress production workflows (14.11, "Prepress support"), such as the
specification of page boundaries and the generation of printer’s marks, colour separations, output
intents, traps, and low-resolution proxies for high-resolution images
•   Subclause 14.12, “Document parts" describes how additional page-level grouping information can
be added to a PDF file. A primary use of document parts is to facilitate job ticket-based workflows
that process large documents section by section.
•   Subclause 14.13, "Associated files" describes a means to associate content in other formats with
selected objects of a PDF file and to identify the relationship between them.

### Requirement 2: 14.2 Procedure sets
This feature has been deprecated since PDF 1.4.
The PDF operators used in content streams are grouped into categories of related operators called
procedure sets (see "Table 346 — Predefined procedure set"). Each procedure set corresponds to a
named resource containing the implementations of the operators in that procedure set. The ProcSet
entry in a content stream’s resource dictionary (see 7.8.3, "Resource dictionaries") shall hold an array
consisting of the names of the procedure sets used in that content stream. These procedure sets shall
be used only when the content stream is printed to a PostScript language compatible output device.
The names identify PostScript language procedure sets that shall be sent to the device to interpret the
PDF operators in the content stream. Each element of this array shall be one of the predefined names
shown in "Table 346 — Predefined procedure set".
Table 346 — Predefined procedure set
Name              Category of operators
PDF               Painting and graphics state
Text              Text
ImageB            Grayscale images or image masks
ImageC            Colour images
ImageI            Indexed (colour-table) images

#### 2.1: 14.3.1          General
A PDF document may include general information, such as the document’s title, author, and creation
and modification dates. Such global information about the document (as opposed to its actual content
or structure) is called document metadata. Beginning with PDF 1.4, it is possible to include metadata
for individual objects in a document. Such object-specific metadata is called object-level metadata.
Metadata can be stored in a PDF document in the following ways:
•    For document data and for object-level metadata: In a metadata stream (PDF 1.4) associated with
the document or a component of the document (14.3.2, "Metadata streams"). Metadata streams
are the preferred method in PDF 2.0.
•    For document metadata only: In a document information dictionary associated with the document
(14.3.3, "Document information dictionary"). Except for the CreationDate and ModDate entries,
the use of the document information dictionary for document metadata is deprecated in PDF 2.0.
PDF’s document information dictionaries provided the initial means of including metadata in a PDF
file. When metadata streams began to be used in PDF 1.4, XMP was introduced to provide a much
richer mechanism to represent metadata entries. Using XMP, a document’s title can be in more than
one language or a document’s authors can be represented as a list. Machine-generated metadata for
date and time of creation or last modification of a PDF document can adequately be represented in the
document information dictionary and in the document’s metadata stream. In some cases document
information dictionary entries are required, such as when PieceInfo dictionaries (see "14.5, "Page-
piece dictionaries") are used; they can be present in both the document information dictionary and the
document-level metadata stream as needed.

#### 2.2: 14.3.2          Metadata streams
Metadata, both for an entire document and for objects within a document, can be stored in stream
dictionaries (PDF 1.4). These streams are called metadata streams. Besides the entries common to all
stream dictionaries (see "Table 5 — Entries common to all stream dictionaries"), a metadata stream
dictionary shall contain the additional entries listed in "Table 347 — Additional entries in a metadata
stream dictionary".

Table 347 — Additional entries in a metadata stream dictionary
Key               Type           Value
Type              name           (Required) The type of PDF object that this dictionary describes; shall
be Metadata for a metadata stream.
Subtype           name           (Required) The type of metadata stream that this dictionary describes;
shall be XML.
The contents of a metadata stream shall be the metadata represented in Extensible Markup Language
(XML) and the grammar of the XML representing the metadata shall be defined according to the
extensible metadata platform specification (ISO 16684-1).
A metadata stream representing document-level metadata can be attached to a PDF document through
the Metadata entry in the document catalog dictionary (see 7.7.2, "Document catalog dictionary").
A metadata stream representing object-level metadata can be attached to the object through the
Metadata entry in a stream or dictionary representing the object or associated with the object (see
"Table 348 — Additional entry for components having metadata").
Object level metadata can also be associated with marked-content within a content stream, by
including a metadata stream in the property list dictionary for this marked-content. Because a stream
dictionary is always an indirect object, a property list containing a metadata stream cannot be encoded
inline in the content stream, but needs to be encoded as a named resource (see 14.6.2, "Property lists").
In general, any PDF stream or dictionary may have metadata attached to it as long as the stream or
dictionary represents an actual information resource. When there is ambiguity about exactly which
stream or dictionary may bear the Metadata entry, the metadata shall be attached as closely as
possible to the object that actually stores the data resource described.
Table 348 — Additional entry for components having metadata
Key          Type         Value
Metadata stream           (Optional; PDF 1.4) A metadata stream containing metadata for the
component.
NOTE 1       Metadata describing an ICCBased colour space would be attached to the ICC profile stream
describing it, and metadata for embedded font files would be attached to font file streams rather
than to font dictionaries. Metadata describing a tiling pattern would be attached to the pattern
stream’s dictionary, but a shading needs to have metadata attached to the shading dictionary
rather than to the shading pattern dictionary that refers to it.
NOTE 2       In tables defining document objects, the Metadata entry is listed only for those document
objects in which it is most likely to be used. However, a Metadata entry can appear in other
objects as long as those objects are represented as streams or dictionaries.

#### 2.3: 14.3.3           Document information dictionary
The Info entry in the trailer of a PDF file (see 7.5.5, "File trailer") is optional. If present it shall hold a
document information dictionary (see "Table 349 — Entries in the document information dictionary").
Earlier versions of the PDF file format used the document information dictionary to represent
document level metadata. In PDF 2.0 such use is deprecated except for two entries, CreationDate and
ModDate. For any other document level metadata, a metadata stream (see 14.3.2 "Metadata streams")
should be used instead.
Where a document information dictionary contains keys other than CreationDate and ModDate, the
value associated with any such key shall be a text string.
Document information dictionaries are also used with Threads (see "Table 162 — Entries in a thread
dictionary").
Table 349 — Entries in the document information dictionary
Key            Type          Value
Title          text string   (Optional; PDF 1.1; deprecated in PDF 2.0) The document’s title.
NOTE 1 The dc:title entry in the document’s metadata stream can be used to
represent the document’s title.
Author         text string   (Optional; deprecated in PDF 2.0) The name of the person who created
the document.
NOTE 2 The dc:creator entry in the document’s metadata stream can be
used to represent the person or persons who created the document.
This note was corrected in this document (2020).
Subject        text string   (Optional; PDF 1.1; deprecated in PDF 2.0) The subject of the document.
NOTE 3 The dc:description entry in the document’s metadata stream can be
used to represent the subject the document.
Keywords       text string   (Optional; PDF 1.1; deprecated in PDF 2.0) Keywords associated with
the document.
NOTE 4 The pdf:Keywords entry in the document’s metadata stream can be
used to represent the keywords for the document.
Creator        text string   (Optional; deprecated in PDF 2.0) If the document was converted to PDF
from another format, the name of the PDF processor that created the
original document from which it was converted.
NOTE 5 The xmp:CreatorTool entry in the document’s metadata stream can
be used to represent the creation tool of the document.
Producer       text string   (Optional; deprecated in PDF 2.0) If the document was converted to PDF
from another format, the name of the PDF processor that converted it
to PDF.
NOTE 6 The pdf:Producer entry in the document’s metadata stream can be
used to represent the tool that saved the document as a PDF.

Key               Type           Value
CreationDate date                (Optional) The date and time the document was created, in human-
readable form (see 7.9.4, "Dates").
NOTE 7 The xmp:CreateDate entry in the document’s metadata stream can
be used to represent document’s creation date and time.
ModDate           date           (Required if PieceInfo is present in the document catalog dictionary;
otherwise optional; PDF 1.1) The date and time the document was most
recently modified, in human-readable form (see 7.9.4, "Dates").
NOTE 8 The xmp:ModifyDate entry in the document’s metadata stream can
be used to represent the date and time the document was most
recently modified.
Trapped           name           (Optional; PDF 1.3; deprecated in PDF 2.0) A name object indicating
whether the document has been modified to include trapping
information (see 14.11.6, "Trapping support"):
True           The document has been fully trapped; no further trapping
shall be needed. This shall be the name True, not the
boolean value true.
False          The document has not yet been trapped. This shall be the
name False, not the boolean value false.
Unknown        Either it is unknown whether the document has been
trapped or it has been partly but not yet fully trapped;
some additional trapping may still be needed.
Default value: Unknown.
NOTE 9 The value of this entry can be set automatically by the software
creating the document’s trapping information, or it can be known
only to a human operator and entered manually.
NOTE 10        The pdf:Trapped entry in the document’s metadata stream
can be used to represent the trapping information for the document.
EXAMPLE           This example shows a document information dictionary containing just the creation and last modification
date, together with the same document’s metadata stream containing the creation and last modification date
and several other document level metadata fields.
101 0 obj                              %document information dictionary
<</CreationDate (D:20140314124211+01'00)
/ModDate (D:20140924212303+02'00)
>>
endobj
102 0 obj                                         %document level metadata stream
<< /Type /Metadata
/Subtype /XML
/Length 103 0 R
>>
stream
<?xpacket begin="Ôªø" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="My XMP Tool Kit v3.7">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
<xmp:CreateDate>2014-03-14T12:42:11+01:00</xmp:CreateDate>
<xmp:ModifyDate>2014-09-24T21:23:03+02:00</xmp:ModifyDate>
<xmp:CreatorTool>My Word Processor v10.7</xmp:CreatorTool>
<xmp:MetadataDate>2014-09-24T21:23:03+02:00</xmp:MetadataDate>
</rdf:Description>
<rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
<pdf:Producer>My Word Processor PDF Exporter Module v2.1</pdf:Producer>
</rdf:Description>
<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:format>application/pdf</dc:format>
<dc:title>
<rdf:Alt>
<rdf:li xml:lang="x-default">Annual report 2014</rdf:li>
<rdf:li xml:lang="en">Annual report 2014</rdf:li>
<rdf:li xml:lang="de">Jahresbericht 2014</rdf:li>
</rdf:Alt>
</dc:title>
<dc:creator>
<rdf:Seq>
<rdf:li>John Doe</rdf:li>
<rdf:li>Mary Miller</rdf:li>
</rdf:Seq>
</dc:creator>
</rdf:Description>
</rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>
endstream
endobj

#### 2.4: 14.3.4          Reconciling two sources of document metadata
Information about time and date of creation might differ from the most recent modification of a PDF
document. If this is the case, the following rules shall apply when writing a PDF document:
•    When writing the time and date of creation for the first time, typically when a new document is
created, a PDF processor shall ensure that the data in the document information dictionary and
the document level metadata stream – if both are written – are fully equivalent.
•    When writing modifications to an existing PDF document, if the PDF document already contains
time and date of creation in both the document information dictionary and in the document’s
metadata stream, and the two are not equivalent, a PDF processor should leave the inconsistent
values unchanged.
•    When writing modifications to an existing PDF document, if the PDF document contains time and
date of creation only in the document information dictionary or in the document’s metadata
stream but not both, a PDF processor may add the information to the other, as long as both are
fully equivalent.
•    When writing the time and date of the most recent modification, typically when an existing
document has been modified, a PDF processor shall ensure that the data in the document
information dictionary and the document level metadata stream – if both are written – are fully
equivalent.
If a PDF processor encounters inconsistent data for time and date of creation or for most recent
modification in the document information dictionary and in the document’s metadata stream, it is at
the discretion of the PDF processor how to use this data.

### Requirement 3: 14.4 File identifiers
PDF file identifiers shall be defined by the ID entry in a PDF file’s trailer dictionary (see 7.5.5, "File
trailer"). The value of this entry shall be an array of two byte strings. The first byte string shall be a
permanent identifier based on the contents of the PDF file at the time it was originally created and
shall not change when the PDF file is updated. The second byte string shall be a changing identifier
based on the PDF file’s contents at the time it was last updated (see 7.5.6, "Incremental updates").
When a PDF file is first written, both identifiers shall be set to the same value. If the first identifier in
the reference matches the first identifier in the referenced file’s ID entry, and the last identifier in the
reference matches the last identifier in the referenced file’s ID entry, it is very likely that the correct
and unchanged PDF file has been found. If only the first identifier matches, a different version of the
correct PDF file has been found.
PDF writers should attempt to ensure the uniqueness of file identifiers. This may be achieved by
computing them by means of a message digest algorithm such as MD5 (described in Internet RFC
1321), using the following information:
•    The current time;
•    A string representation of the PDF file’s location;
•    The size of the PDF file in bytes.

### Requirement 4: 14.5 Page-piece dictionaries
A page-piece dictionary (PDF 1.3) may be used to hold private PDF processor data. The data may be
associated with a page or form XObject by means of the optional PieceInfo entry in the page object
(see "Table 31 — Entries in a page object") or form dictionary (see "Table 93 — Additional entries
specific to a Type 1 form dictionary"). Beginning with PDF 1.4, private data may also be associated with
the PDF document by means of the PieceInfo entry in the document catalog dictionary (see "Table 29
— Entries in the catalog dictionary").
NOTE        PDF writers can use this dictionary as a place to store private data in connection with that
document, page, or form. Such private data can convey information meaningful to the PDF
processor that produces it (such as information on object grouping for a graphics editor or the
layer information used by Adobe Photoshop®) but can be ignored by general-purpose PDF
processors.
As "Table 350 — Entries in a page-piece dictionary" shows, a page-piece dictionary may contain any
number of entries, each keyed by the name of a distinct PDF processor or of a well-known data type
recognised by a family of PDF processors. The value associated with each key shall be a data dictionary
containing the private data that shall be used by the PDF processor. The Private entry may have a
value of any data type, but typically it is a dictionary containing all of the private data needed by the
PDF processor other than the actual content of the document, page, or form.
Table 350 — Entries in a page-piece dictionary
Key                               Type          Value
any valid second-class name dictionary          A data dictionary (see "Table 351 — Entries in a data dictionary").
Table 351 — Entries in a data dictionary
Key              Type         Value
LastModified     date         (Required) The date and time when the contents of the document, page, or
form were most recently modified by this PDF processor.
Private          (any)        (Optional) Any private data appropriate to the PDF processor, typically in the
form of a dictionary.
The LastModified entry indicates when a PDF processor last altered the content of the document, page
or form. If the page-piece dictionary contains several data dictionaries, their modification dates can be
compared with those in the corresponding entry of the page object or form dictionary (see "Table 31
— Entries in a page object" and "Table 93 — Additional entries specific to a Type 1 form dictionary"),
or the ModDate entry of the document information dictionary (see "Table 349 — Entries in the
document information dictionary"), to ascertain whether the data dictionary corresponds to the
current content of the document, page or form. Because some platforms may use only an approximate
value for the date and time or may not deal correctly with differing time zones, modification dates shall
be compared only for equality and not for sequential ordering.

#### 4.1: 14.6.1              General
Marked-content operators (PDF 1.2) may identify a portion of a PDF content stream as a marked-
content element of interest to a particular PDF processor. Marked-content elements and the operators
that mark them shall fall into two categories:
•     The MP and DP operators shall designate a single marked-content point in the content stream.
•     The BMC, BDC, and EMC operators shall bracket a marked-content sequence of objects within the
content stream.
NOTE 1         This is a sequence not simply of bytes in the content stream but of complete graphics objects.
Each object is fully qualified by the parameters of the graphics state in which it is rendered.
NOTE 2         A graphics application, for example, can use marked-content to identify a set of related objects as
a group to be processed as a single unit. A text-processing application can use it to maintain a
connection between a footnote marker in the body of a document and the corresponding
footnote text at the bottom of the page. The PDF logical structure facilities use marked-content
sequences to associate graphical content with structure elements (see 14.7.5, "Structure
content").
All marked-content operators except EMC shall take a tag operand indicating the role or significance of
the marked-content element to the PDF processor. All such tags should have second-class names
registered with ISO (see Annex E, "Extending PDF") to avoid conflicts between different applications
marking the same content stream. In addition to the tag operand, the DP and BDC operators shall
specify a property list containing further information associated with the marked-content. Property
lists are discussed further in 14.6.2, "Property lists".
NOTE 3         The tag operand of marked-content operators have no relationship to Tagged PDF (see 14.8
"Tagged PDF") and thus is not rolemapped.

Marked-content operators may appear only between graphics objects in the content stream. They may
not occur within a graphics object or between a graphics state operator and its operands. Marked-
content sequences may be nested one within another, but each sequence shall be entirely contained
within a single content stream. "Table 352 — Marked-content operators" summarises the marked-
content operators.
NOTE 4      A marked-content sequence cannot cross page boundaries.
The Contents entry of a page object (see 7.7.3.3, "Page objects"), whether a single stream or an array of
streams, is considered a single stream with respect to marked-content sequences.
Table 352 — Marked-content operators
Operands           Operator Description
tag                MP             Designate a marked-content point. tag shall be a name object indicating the role
or significance of the point.
tag properties     DP             Designate a marked-content point with an associated property list. tag shall be a
name object indicating the role or significance of the point. properties shall be
either an inline dictionary representing the property list or a name object
associated with it in the Properties subdictionary of the current resource
dictionary (see 14.6.2, "Property lists").
Tag                BMC            Begin a marked-content sequence terminated by a balancing EMC operator. tag
shall be a name object indicating the role or significance of the sequence.
tag properties     BDC            Begin a marked-content sequence with an associated property list, terminated by
a balancing EMC operator. tag shall be a name object indicating the role or
significance of the sequence. properties shall be either an inline dictionary
representing the property list or a name object associated with it in the
Properties subdictionary of the current resource dictionary (see 14.6.2,
"Property lists").
—                  EMC            End a marked-content sequence begun by a BMC or BDC operator.

When the marked-content operators BMC, BDC, and EMC are combined with the text object operators
BT and ET (see 9.4, "Text objects"), each pair of matching operators (BMC…EMC, BDC…EMC, or
BT…ET) shall be properly (separately) nested. Therefore, the sequences
BMC
BT
…
ET
EMC
and
BT
BMC
…
EMC
ET
are valid, but
BMC
BT
…
EMC
ET
and
BT
BMC
…
ET
EMC
are not valid.

#### 4.2: 14.6.2           Property lists
The marked-content operators DP and BDC associate a property list with a marked-content element
within a content stream. The property list is a dictionary containing information (either private or of
types defined in this document) meaningful to the PDF processor. PDF processors should use the
dictionary entries in a consistent way; the values associated with a given key should always be of the
same type (or small set of types).
NOTE 1     Property lists are used by several PDF features, including optional content (see 8.11, "Optional
content", tagged PDF (see 14.8, "Tagged PDF"), object metadata (see 14.3.2, "Metadata streams")
and Associated Files (see 14.13.5, "Associated files linked to graphics objects").
If all of the values in a property list dictionary are direct objects, the dictionary may be written inline in
the content stream as a direct object. If any of the values are indirect references to objects outside the
content stream, the property list dictionary shall be defined as a named resource in the Properties
subdictionary of the current resource dictionary (see 7.8.3, "Resource dictionaries") and referenced by
name as the properties operand of the DP or BDC operator.
NOTE 2     (2020) This means that indirect references of the form of 10 0 R can never occur within content
streams.

