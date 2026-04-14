# SDD Draft

Generated from:
- `spec/extracted/14.7-14.13-structure-tagged.spec.txt`

## Requirements

#### 0.1: 14.7.1           General
PDF’s logical structure facilities (PDF 1.3) shall provide a mechanism for incorporating structural
information about a document’s content into a PDF file. Such information may include the organisation
of the document into chapters and sections or the identification of special elements such as figures,
tables, and footnotes. The logical structure facilities shall be extensible, allowing PDF writers to choose
what structural information to include and how to represent it, while enabling PDF processors to
navigate a PDF file without knowing the producer’s structural conventions.
PDF logical structure shares basic features with standard document markup languages such as HTML
and XML. A document’s logical structure shall be expressed as a hierarchy of structure elements, each
represented by a dictionary object. Like their counterparts in other markup languages, PDF structure
elements may have content and attributes. In PDF, rendered document content takes over the role
occupied by text in HTML and XML.
A PDF document’s logical structure shall be stored separately from its visible content, with pointers
from each to the other. This separation allows the ordering and nesting of logical elements to be
entirely independent of the order and location of graphics objects on the document’s pages. The

MarkInfo entry in the document catalog dictionary (see 7.7.2, "Document catalog dictionary") shall
specify a mark information dictionary, whose entries are shown in "Table 353 — Entries in the mark
information dictionary". It provides additional information relevant to specialised uses of structured
PDF documents.
Table 353 — Entries in the mark information dictionary
Key                    Type                Value
Marked                 boolean             (Optional) A flag indicating whether the document conforms to
tagged PDF conventions (see 14.8, "Tagged PDF"). Default value:
false.
If Suspects is true, the document may not completely conform to
tagged PDF conventions.
UserProperties         boolean             (Optional; PDF 1.6) A flag indicating the presence of structure
elements that contain user properties attributes (see 14.7.6.4,
"User properties"). Default value: false.
Suspects               boolean             (Optional; PDF 1.6; deprecated in PDF 2.0) A flag indicating the
presence of tag suspects. Default value: false.

#### 0.2: 14.7.2            Structure hierarchy
The logical structure of a document shall be described by a hierarchy of objects called the structure
hierarchy or structure tree. At the root of the hierarchy shall be a dictionary object called the structure
tree root, located by means of the StructTreeRoot entry in the document catalog dictionary (see 7.7.2,
"Document catalog dictionary"). "Table 354 — Entries in the structure tree root" shows the entries in
the structure tree root dictionary. The K entry shall specify the immediate children of the structure
tree root, which shall be structure elements.
Table 354 — Entries in the structure tree root
Key                          Type              Value
Type                         name              (Required) The type of PDF object that this dictionary describes; shall
be StructTreeRoot for a structure tree root.
K                            dictionary or (Optional) The immediate child or children of the structure tree root in
array         the structure hierarchy. The value may be either a dictionary
representing a single structure element or an array of such
dictionaries.
IDTree                       name tree         (Required if any structure elements have element identifiers) A name
tree (see 7.9.6, "Name trees") that maps element identifiers (see
"Table 355 — Entries in a structure element dictionary") to the
structure elements they denote.
Key                      Type              Value
ParentTree               number tree       (Required if any structure element contains content items) A number
tree (see 7.9.7, "Number trees") used in finding the structure elements
to which content items belong. Each integer key in the number tree
shall correspond to a single page of the document or to an individual
object (such as an annotation or an XObject) that is a content item in
its own right. The integer key shall be the value of the StructParent or
StructParents entry in that object (see 14.7.5.4, "Finding structure
elements from content items"). The form of the associated value shall
depend on the nature of the object: For an object that is a content item
in its own right, the value shall be an indirect reference to the object’s
parent element (the structure element that contains it as a content
item). For a page object or content stream containing marked-content
sequences that are content items, the value shall be an array of
references to the parent elements of those marked-content sequences.
See 14.7.5.4, "Finding structure elements from content items" for
further discussion.
ParentTreeNextKey        integer           (Optional) An integer greater than any key in the parent tree
ParentTree and that shall be used as the key for the next entry added
to the parent tree.
RoleMap                  dictionary        (Optional) A dictionary that shall map name objects designating names
of structure types used in the document to a name object designating
the name of their approximate equivalents in the set of standard
structure types (see 14.8.4, "Standard structure types").
ClassMap                 dictionary        (Optional) A dictionary that shall map name objects designating
attribute classes to the corresponding attribute objects or arrays of
attribute objects (see 14.7.6.2, "Attribute classes").
Namespaces               array             (Required if any structure elements have namespace identifiers; PDF 2.0)
An array of namespaces used within the document (see 14.7.4.2,
"Namespace dictionary").
PronunciationLexicon array of file  (Optional; PDF 2.0) An array containing one or more indirect
specifications references to file specification dictionaries, where each specified file
shall be a pronunciation lexicon, which is an XML file conforming to
the Pronunciation Lexicon Specification (PLS) Version 1.0. These
pronunciation lexicons may be used as pronunciation hints when the
document’s content is presented via text-to-speech. Where two or
more pronunciation lexicons apply to the same text, the first match –
as defined by the order of entries in the array and the order of entries
inside the pronunciation lexicon file – should be used.
See 14.9.6, "Pronunciation hints" for further discussion.
AF                       array of          (Optional; PDF 2.0) An array of one or more file specification
dictionaries      dictionaries (7.11.3, "File specification dictionaries") which denote the
associated files for the entire structure tree. See 14.13, "Associated
files".
Structure elements shall be represented by a dictionary, whose entries are shown in "Table 355 —
Entries in a structure element dictionary". The K entry shall specify the children of the structure
element, which may be zero or more items of the following kinds:

•    Other structure elements
•    References to content items, which are either marked-content sequences (see 14.6, "Marked
content") or complete PDF objects such as XObjects and annotations. These content items
represent the graphical content, if any, associated with a structure element. Content items are
discussed in detail in 14.7.5, "Structure content".
Table 355 — Entries in a structure element dictionary
Key                    Type            Value
Type                   name            (Optional) The type of PDF object that this dictionary describes; if present,
shall be StructElem for a structure element.
S                      name            (Required) The structure type, a name object identifying the nature of the
structure element and its role within the document, such as a chapter,
paragraph, or footnote (see 14.7.3, "Structure types"). Names of structure
types shall conform to the guidelines described in Annex E, "Extending PDF".
P                      dictionary      (Required; shall be an indirect reference) The structure element or the
structure tree root that is the immediate parent of this structure element in
the structure hierarchy.
ID                     byte string     (Optional) The element identifier, a byte string designating this structure
element. The string shall be unique among all elements in the document’s
structure hierarchy. The IDTree entry in the structure tree root (see "Table
354 — Entries in the structure tree root") defines the correspondence
between element identifiers and the structure elements they denote.
Ref                    array           (Optional; PDF 2.0) An array containing zero, one or more indirect references
to structure elements. A Ref identifies the structure element or elements to
which the item of content, contained within this structure element, refers
(e.g. footnotes, endnotes, sidebars, etc.).
Pg                     dictionary      (Optional; required if K is an integer object or an array containing integer
objects; shall be an indirect reference) A page object representing a page on
which some or all of the content items designated by the K entry shall be
rendered.
K                      (various)       (Optional) The children of this structure element. The value of this entry may
be one of the following objects or an array consisting of one or more of the
following objects in any combination:
•    A structure element dictionary denoting another structure element
•    An integer marked-content identifier denoting a marked-content sequence
•    A marked-content reference dictionary denoting a marked-content sequence
(see “Table 357 — Entries in a marked-content reference dictionary")
•    An object reference dictionary denoting a PDF object (see “Table 358 — Entries
in an object reference dictionary")
Each of these objects other than the first (structure element dictionary) shall
be considered to be a content item; see 14.7.5, "Structure content" for further
discussion of each of these forms of representation.
If the value of K is a dictionary containing no Type entry, it shall be assumed
to be a structure element dictionary.
Key            Type          Value
A              (various)     (Optional) A single attribute object or array of attribute objects associated
with this structure element. Each attribute object shall be either a dictionary
or a stream. If the value of this entry is an array, each attribute object in the
array may be followed by an integer representing its revision number (see
14.7.6, "Structure attributes" and 14.7.6.3, "Attribute revision numbers").
C              name or       (Optional) An attribute class name or array of class names associated with
array         this structure element. If the value of this entry is an array, each class name
in the array may be followed by an integer representing its revision number
(see 14.7.6.2, "Attribute classes" and 14.7.6.3, "Attribute revision numbers").
If both the A and C entries are present and a given attribute is specified by
both, the one specified by the A entry shall take precedence.
R              integer       (Optional) The current revision number of this structure element (see
14.7.6.3, "Attribute revision numbers"). The value shall be a non-negative
integer. Default value: 0.
T              text string   (Optional) The title of the structure element, a text string representing it in
human-readable form. The title should characterise the specific structure
element, such as Chapter 1, rather than merely a generic element type, such
as Chapter.
Lang           text string   (Optional; PDF 1.4) A language identifier specifying the natural language for
all text in the structure element except where overridden by language
specifications for nested structure elements or marked-content (see 14.9.2,
"Natural language specification").
Alt            text string   (Optional) An alternative description of the structure element and its
children in human-readable form, which is useful when extracting the
document’s contents in support of accessibility to users with disabilities or
for other purposes (see 14.9.3, "Alternate descriptions").
E              text string   (Optional; PDF 1.5) The expanded form of an abbreviation or an acronym.
ActualText     text string   (Optional; PDF 1.4) Text that is an exact replacement for the content enclosed
by the structure element and its children. This replacement text (which
should apply to as small a piece of content as possible) is useful when
extracting the document’s contents in support of accessibility to users with
disabilities or for other purposes (see 14.9.4, "Replacement text").
AF             array of     (Optional; PDF 2.0) An array of one or more file specification dictionaries
dictionaries (7.11.3, "File specification dictionaries") which denote the associated files for
this entire structure element. See 14.13, "Associated files".
NS             dictionary    (Optional; PDF 2.0) An indirect reference to a namespace dictionary defining
the namespace this element belongs to (see 14.7.4, "Namespaces"). If not
present, the element shall be considered to be in the default standard
structure namespace (see 14.8.6, "Standard structure namespaces").

Key                    Type            Value
PhoneticAlphabet Name                  (Optional; PDF 2.0) Property for a structure element that indicates the
phonetic alphabet used by a Phoneme property. Applies to the structure
element and its children, except where overridden by a child structure
element.
Currently defined values are:
•    ipa for the International Phonetic Alphabet by the International Phonetic
Association
•    x-sampa for Extended Speech Assessment Methods Phonetic Alphabet (X-
SAMPA)
•    zh-Latn-pinyin for Pinyin Latin romanization (Mandarin)
•    zh-Latn-wadegile for Wade-Giles romanization (Mandarin)
Other values may be used.
Default value: ipa.
See 14.9.6, "Pronunciation hints" for further discussion.
Phoneme                text string     (Optional; PDF 2.0) Property for a structure element that may be used as
pronunciation hint. It is an exact replacement for content enclosed by the
structure element and its children.
The value for a Phoneme property is to be interpreted based on the
PhoneticAlphabet property in effect.
See 14.9.6, "Pronunciation hints" for further discussion.

#### 0.3: 14.7.3            Structure types
Every structure element shall have a structure type, a name object that identifies the nature of the
structure element and its role within the document (such as a chapter, paragraph, or footnote). To
facilitate the interchange of content among PDF processors, PDF defines a set of standard structure
types; see 14.8.4, "Standard structure types". PDF writers are not required to adopt them, however,
and may use any names for their structure types.
Where names other than the standard ones are used, a role map should be provided in the structure
tree root using the RoleMap entry or, in the case of namespaces, the RoleMapNS entry within an NS
entry, to map the structure types used in the document to their nearest equivalents in the standard set.
The RoleMap dictionary shall be comprised of a set of keys representing structure element types
rolemapped to other structure element types. The corresponding value for each of these keys shall be a
single name identifying the target structure element type.
A structure type shall always be mapped to its corresponding name in the role map, if there is one,
even if the original name is one of the standard types. This shall be done to allow the element, for
example, to represent a structure type with the same name as a standard role, even though its use
differs from the standard role.
NOTE 1      A structure type named Advertising can be mapped to the standard type Part. The equivalence
need not be exact; the role map merely indicates an approximate analogy between types,
allowing PDF processors to share nonstandard structure elements in a reasonable way.
NOTE 2     The same structure type can occur as both a key and a value in the role map, and circular chains
of association are explicitly permitted. Therefore, a single role map can define a bidirectional
mapping. A PDF processor using the role map needs to follow the chain of associations until it
either finds a structure type it recognises or returns to one it has already encountered.
NOTE 3     In PDF versions earlier than 1.5, standard element types were never remapped.

#### 0.4: 14.7.4.1        General
PDF documents are used to represent many classes of documents as well as many classes of content
within those documents. The standard structure types (see 14.8.4, "Standard structure types") address
many classes of documents. The mechanism for providing a role mapping for custom structure types
allows the inclusion of non-standard, custom, types. However, prior to PDF 2.0, there has been no
mechanism for identifying and exchanging these custom structure types, other than to use their
mapping to the standard structure types.
The concept of namespaces is well understood in the XML world, allowing custom XML tagsets to be
interchanged and identified. Schemata are often defined for these namespaces using a variety of
schema languages to allow programmatic exchange of tagsets. Many PDF documents are authored by
conversion from other formats, many of which have rich structures and content with their own
structures. PDF 2.0 introduces the namespace mechanism as a component of its logical structure,
where one or more namespaces may be specified as being used within the document (see 14.7.4.2,
"Namespace dictionary").

#### 0.5: 14.7.4.2        Namespace dictionary
A namespace dictionary shall be used to define a namespace (see 14.7.4, "Namespaces") within the
structure tree (see 14.7.2, "Structure hierarchy"). "Table 356 — Entries in a namespace dictionary"
shows the entries in the namespace dictionary. The NS entry shall specify the namespace name, which
should take the form of a uniform resource identifier (URI).
NOTE 1     It is not generally expected that a URI for a namespace name will resolve. It is instead used for
uniqueness. A URI specified here can correspond to an existing XML namespace (e.g.
"http://www.w3.org/1998/Math/MathML" for MathML 3.0).
An optional Schema entry may be provided to identify the schema file for the namespace.
NOTE 2     There is no requirement that the schema be provided in any specific format (e.g. RelaxNG or
W3C Schema), though the expectation is that the format would be machine readable.
A RoleMapNS entry may also be provided to map the entries in the namespace to those of another
namespace. For a document that is compliant with tagged PDF see 14.8.6, "Standard structure
namespaces" for namespace requirements.
NOTE 3     Role mapping to one of the standard structure namespaces can be achieved either directly in the
provided role map or transitively through one or more namespaces which eventually provide a
role map to one of the standard structure namespaces.

Table 356 — Entries in a namespace dictionary
Key               Type            Value
Type              name            (Optional; PDF 2.0) The type of PDF object that this dictionary describes. If
present, shall be Namespace.
NS                text string     (Required; PDF 2.0) The string defining the namespace name which this entry
identifies (conventionally a uniform resource identifier, or URI).
Schema            file          (Optional; PDF 2.0) A file specification identifying the schema file, which defines
specification this namespace.
RoleMapNS         dictionary      (Optional; PDF 2.0) A dictionary that shall, if present, map the names of
structure types used in the namespace to their approximate equivalents in
another namespace. The dictionary shall be comprised of a set of keys
representing structure element types in the namespace defined within this
namespace dictionary. The corresponding value for each of these keys shall
either be a single name identifying a structure element type in the default
standard structure namespace or an array where the first value shall be a
structure element type name in a target namespace with the second value being
an indirect reference to the target namespace dictionary.
When the owner of an attribute object (see Table 360 — Entries common to all attribute object
dictionaries) is specified by an NS entry, the namespace name shall be considered as identifying the
owner. For common namespace names which correspond to the values of owner entries defined in
Table 376 — Standard structure attribute owners, they shall be considered equivalent.

#### 0.6: 14.7.5.1          General
Any structure element may have associated graphical content, consisting of one or more content items.
Content items shall be graphical objects that exist in the document independently of the structure tree
but are associated with structure elements as described in the following subclauses.

#### 0.7: 14.7.5.1.1        Content items
Content items are of two kinds:
•     Marked-content sequences within content streams (14.7.5.2, "Marked-content sequences as
content items")
•     Complete PDF objects such as annotations and XObjects (see 14.7.5.3, "PDF objects as content
items")
The K entry in a structure element dictionary (see "Table 355 — Entries in a structure element
dictionary") specifies the children of the structure element, which may include any number of content
items, as well as child structure elements that may in turn have content items of their own.
Content items shall be leaf nodes of the structure tree; that is, they shall not have other content items
nested within them for purposes of logical structure. The hierarchical relationship among structure
elements shall be represented entirely by the K entries of the structure element dictionaries, not by
nesting of the associated content items. Therefore, the following restrictions shall apply:
•    A marked-content sequence corresponding to a structure content item shall not have another
marked-content sequence for a structure content item nested within it though non-structural
marked-content shall be allowed.
•    A structure content item shall not invoke (with the Do operator) an XObject that is itself a
structure content item. Logical structure information associated with a page may be ignored
when importing that page into another document with a reference XObject (see 8.10.4.3 "Special
considerations").

#### 0.8: 14.7.5.2        Marked-content sequences as content items
A sequence of graphics operators in a content stream may be specified as a content item of a structure
element in the following way:
•    The operators shall be bracketed as a marked-content sequence between BDC and EMC operators
(see 14.6, "Marked content"). Although the tag associated with a marked-content sequence is not
directly related to the document’s logical structure, it should be the same as the structure type of
the associated structure element.
•    The marked-content sequence shall contain a property list (see 14.6.2, "Property lists")
containing an MCID entry, which shall be an integer marked-content identifier that uniquely
identifies the marked-content sequence within its content stream, as shown in the following
example:
EXAMPLE 1
2 0 obj                                              %Page object
<</Type /Page
/Contents 3 0 R                                %Content stream
…
>>
endobj
3 0 obj                                              %Page's content stream
<</Length …>>
stream
…
/P <</MCID 0>>                                    %Start of marked-content sequence
BDC
…
(Here is some text) Tj
…
EMC                                            %End of marked-content sequence
…
endstream
endobj
NOTE        This example and the following examples omit required StructParents entries in the objects
used as content items (see 14.7.5.4, "Finding structure elements from content items").
A structure element dictionary may include one or more marked-content sequences as content items
by referring to them in its K entry (see "Table 355 — Entries in a structure element dictionary"). This
reference may have two forms:
•    A dictionary object called a marked-content reference. "Table 357 — Entries in a marked-content
reference dictionary" shows the contents of this type of dictionary, which shall specify the

marked-content identifier, as well as other information identifying the stream in which the
sequence is contained. Example 2 in this subclause illustrates the use of a marked-content
reference to the marked-content sequence shown in Example 1.
•    An integer that specifies the marked-content identifier. This may be done in the common case
where the marked-content sequence is contained in the content stream of the page that is
specified in the Pg entry of the structure element dictionary. Example 3 shows a structure
element that has three children: a marked-content sequence specified by a marked-content
identifier, as well as two other structure elements.
Table 357 — Entries in a marked-content reference dictionary
Key               Type                Value
Type              name                (Required) The type of PDF object that this dictionary describes;
shall be MCR for a marked-content reference.
Pg                dictionary          (Optional; shall be an indirect reference) The page object
representing the page on which the graphics objects in the
marked-content sequence shall be rendered. This entry overrides
any Pg entry in the structure element containing the marked-
content reference; it shall be required if the structure element has
no such entry.
Stm               stream              (Optional; shall be an indirect reference) The content stream
containing the marked-content sequence. This entry should be
present only if the marked-content sequence resides in a content
stream other than the content stream for the page (see 8.10,
"Form XObjects" and 12.5.5, "Appearance streams").
If this entry is absent, the marked-content sequence shall be
contained in the content stream of the page identified by Pg
(either in the marked-content reference dictionary or in the
parent structure element).
StmOwn            (any)               (Optional; shall be an indirect reference) The indirect reference to
the PDF object referencing the stream identified by the Stm key.
NOTE      A common use for this would be to identify the annotation
dictionary owning the appearance stream.
MCID              integer             (Required) The marked-content identifier of the marked-content
sequence within its content stream.
EXAMPLE 2
1 0 obj                                                              %Structure element
<</Type /StructElem
/S /P                                                          %Structure type
/P …                                                           %Parent in structure hierarchy
/K <</Type /MCR
/Pg 2 0 R                                                   %Page containing marked-content sequence
/MCID 0                                                     %Marked-content identifier
>>
>>
endobj
EXAMPLE 3
1 0 obj                                                              %Containing structure element
<</Type /StructElem
/S /MixedContainer                                   %Structure type
/P …                                                 %Parent in structure hierarchy
/Pg 2 0 R                                            %Page containing marked-content sequence
/K [4 0 R                                            %Three children: a structure element
0                                                 %a marked-content identifier
5 0 R                                             %another structure element
]
>>
endobj
2 0 obj                                                       %Page object
<</Type /Page
/Contents 3 0 R                                      %Content stream
…
>>
endobj
3 0 obj                                                       %Page's content stream
<</Length …>>
stream
…
/P <</MCID 0>>                                          %Start of marked-content sequence
BDC
( Here is some text ) Tj
…
EMC                                                  %End of marked-content sequence
…
endstream
endobj
Content streams other than page contents may also contain marked-content sequences that are
content items of structure elements. The content of form XObjects may be incorporated into structure
elements in one of the following ways:
•    A Do operator that paints a form XObject may be part of a marked-content sequence that is
associated with a structure element (see Example 4 in this subclause). In this case, the entire form
XObject is part of the structure element’s content, as if it were inserted into the marked-content
sequence at the point of the Do operator. The form XObject shall not, in turn, contain any marked-
content sequences associated with this or other structure elements.
•    The content stream of a form XObject may contain one or more marked-content sequences that
are associated with structure elements (see Example 5 in this subclause). The form XObject may
have arbitrary substructure, containing any number of marked-content sequences associated
with logical structure elements. However, any Do operator that paints the form XObject shall not
be part of a logical structure content item.
A form XObject that is painted with multiple invocations of the Do operator shall be incorporated into
the document’s logical structure only by the first method, with each invocation of Do individually
associated with a structure element.
EXAMPLE 4
1 0 obj                                              %Structure element
<</Type /StructElem
/S /P                                       %Structure type
/P …                                        %Parent in structure hierarchy
/Pg 2 0 R                                   %Page containing marked-content sequence
/K 0                                        %Marked-content identifier
>>
endobj

2 0 obj                                                    %Page object
<</Type /Page
/Resources    <</XObject <</Fm4 4 0 R>> %Resource dictionary
>>                        %containing form XObject
/Contents 3 0 R                       %Content stream
…
>>
endobj
3 0 obj                                                    %Page's content stream
<</Length …>>
stream
…
/P <</MCID 0>>                                       %Start of marked-content sequence
BDC
/Fm4 Do                                     %Paint form XObject
EMC                                            %End of marked-content sequence
…
endstream
endobj
4 0 obj                                                    %Form XObject
<</Type /XObject
/Subtype /Form
/Length …
>>
stream
…
(Here is some text) Tj
…
endstream
endobj
EXAMPLE 5
1 0 obj                                                    %Structure element
<</Type /StructElem
/S /P                                             %Structure type
/P …                                              %Parent in structure hierarchy
/K <</Type /MCR
/Pg 2 0 R                                   %Page containing marked-content sequence
/Stm 4 0 R                                  %Stream containing marked-content sequence
/MCID 0                                     %Marked-content identifier
>>
>>
endobj
2 0 obj                                                    %Page object
<</Type /Page
/Resources <</XObject          <</Fm4 4 0 R>> %Resource dictionary
>>                                 %containing form XObject
/Contents 3 0 R                               %Content stream
…
>>
endobj
3 0 obj                                                    %Page's content stream
<</Length …>>
stream
…
/Fm4 Do                                              %Paint form XObject
…
endstream
endobj
4 0 obj                                                    %Form XObject
<</Type /XObject
/Subtype /Form
/Length …
>>
stream
…
/P <</MCID 0>>                                    %Start of marked-content sequence
BDC
…
(Here is some text) Tj
…
EMC                                         %End of marked-content sequence
…
endstream
endobj

#### 0.9: 14.7.5.3          PDF objects as content items
When a structure element’s content consists of an entire PDF object, such as an XObject directly or
indirectly referenced by a page description or an annotation, the object shall be identified in the
structure element’s K entry by an object reference dictionary ("Table 358 — Entries in an object
reference dictionary").
NOTE 1       This form of reference is used only for entire objects. If the referenced content forms only part of
the object’s content stream, it is instead handled as a marked-content sequence, as described in
14.7.5.2, "Marked-content sequences as content items".
Table 358 — Entries in an object reference dictionary
Key        Type         Value
Type       name         (Required) The type of PDF object that this dictionary describes; shall be OBJR
for an object reference.
Pg         dictionary   (Optional; shall be an indirect reference) The page object of the page on which
the object shall be rendered. This entry overrides any Pg entry in the structure
element containing the object reference; it shall be used if the structure element
has no such entry.
Obj        (any)        (Required; shall be an indirect reference) The referenced object.
NOTE 2       If the referenced object is rendered on multiple pages, each rendering requires a separate object
reference. However, if it is rendered multiple times on the same page, just a single object
reference suffices to identify all of them. (If it is important to distinguish between multiple
renditions of the same XObject on the same page, they need to be accessed by means of marked-
content sequences enclosing particular invocations of the Do operator rather than through
object references.)

#### 0.10: 14.7.5.4          Finding structure elements from content items
Because a stream cannot contain object references, there is no way for content items that are marked-
content sequences to refer directly back to their parent structure elements (the ones to which they
belong as content items). Instead, a different mechanism, the structural parent tree, shall be provided
for this purpose. For consistency, content items that are entire PDF objects, such as XObjects, shall also
use the parent tree to refer to their parent structure elements.

The parent tree is a number tree (see 7.9.7, "Number trees"), accessed from the ParentTree entry in a
document’s structure tree root ("Table 354 — Entries in the structure tree root"). The tree shall
contain an entry for each object that is a content item of at least one structure element and for each
content stream containing at least one marked-content sequence that is a content item. The key for
each entry shall be an integer given as the value of the StructParent or StructParents entry in the
object (see "Table 359 — Additional dictionary entries for structure element access"). The values of
these entries shall be as follows:
•    For an object identified as a content item by means of an object reference (see 14.7.5.3, "PDF
objects as content items"), the value shall be an indirect reference to the parent structure element.
•    For a content stream containing marked-content sequences that are content items, the value shall
be an array of indirect references to the sequences’ parent structure elements. The array element
corresponding to each sequence shall be found by using the sequence’s marked-content identifier
as a zero-based index into the array.
NOTE         Because marked-content identifiers serve as indices into an array in the structural parent tree,
their assigned values need to be as small as possible to conserve space in the array.
The ParentTreeNextKey entry in the structure tree root shall hold an integer value greater than any
that is currently in use as a key in the structural parent tree. Whenever a new entry is added to the
parent tree, the current value of ParentTreeNextKey shall be used as its key. The value shall be then
incremented to prepare for the next new entry to be added.
To locate the relevant parent tree entry, each object or content stream that is represented in the tree
shall contain a special dictionary entry, StructParent or StructParents (see "Table 359 — Additional
dictionary entries for structure element access"). Depending on the type of content item, this entry
may appear in the page object of a page containing marked-content sequences, in the stream dictionary
of a form or image XObject, or in an annotation dictionary. Its value shall be the integer key under
which the entry corresponding to the object shall be found in the structural parent tree.
Table 359 — Additional dictionary entries for structure element access
Key               Type      Value
StructParent      integer (Required for all objects that are structural content items; PDF 1.3) The
integer key of this object’s entry in the structural parent tree.
StructParents integer (Required for all content streams containing marked-content sequences that
are structural content items; PDF 1.3) The integer key of this object’s entry
in the structural parent tree. At most one of these two entries shall be
present in a given object. An object may be either a content item in its
entirety or a container for marked-content sequences that are content
items, but not both.
For a content item identified by an object reference, the parent structure element may be found by
using the value of the StructParent entry in the item’s object dictionary as a retrieval key in the
structural parent tree (found in the ParentTree entry of the structure tree root). The corresponding
value in the parent tree shall be a reference to the parent structure element (see Example 1).
EXAMPLE 1
1 0 obj                                                    %Parent structure element
<</Type /StructElem
…
/K <</Type /OBJR                            %Object reference
/Pg 2 0 R                             %Page containing form XObject
/Obj 4 0 R                            %Reference to form XObject
>>
>>
endobj
2 0 obj                                              %Page object
<</Type /Page
/Resources    <</XObject   <</Fm4 4 0 R>>%Resource dictionary
>>                         %containing form XObject
/Contents 3 0 R                        %Content stream
…
>>
endobj
3 0 obj                                              %Page's content stream
<</Length …>>
stream
…
/Fm4 Do                                        %Paint form XObject
…
endstream
endobj
4 0 obj                                              %Form XObject
<</Type /XObject
/Subtype /Form
/Length …
/StructParent 6                             %Parent tree key
>>
stream
…
endstream
endobj
100 0 obj                                            %Parent tree (accessed from structure tree root)
<</Nums [0 101 0 R
1 102 0 R
…
6 1 0 R                               %Entry for page object 2; points back
…                                     %to parent structure element
]
>>
endobj
For a content item that is a marked-content sequence, the retrieval method is similar but slightly more
complicated. Because a marked-content sequence is not an object in its own right, its parent tree key
shall be found in the StructParents entry of the page object or other content stream in which the
sequence resides. The value retrieved from the parent tree shall not be a reference to the parent
structure element itself but to an array of such references — one for each marked-content sequence
contained within that content stream. The parent structure element for the given sequence shall be
found by using the sequence’s marked-content identifier as an index into this array (see Example 2).
EXAMPLE 2
1 0 obj                                    %Parent structure element
<</Type /StructElem
…
/Pg 2 0 R                         %Page containing marked-content sequence
/K 0                              %Marked-content identifier

>>
endobj
2 0 obj                                           %Page object
<</Type /Page
/Contents 3 0 R                          %Content stream
/StructParents 6                         %Parent tree key
…
>>
endobj
3 0 obj                                           %Page's content stream
<</Length …>>
stream
…
/P <</MCID 0>>                              %Start of marked-content sequence
BDC
(Here is some text) TJ
…
EMC                                   %End of marked-content sequence
…
endstream
endobj
100 0 obj                                         %Parent tree (accessed from structure tree root)
<</Nums [0 101 0 R
1 102 0 R
…
6 [1 0 R]                          %Entry for page object 2; array element at index 0
…                                  %points back to parent structure element
]
>>
endobj

#### 0.11: 14.7.6.1          General
A PDF processor that processes logical structure may attach additional information, called attributes,
to any structure element. The attribute information shall be held in one or more attribute objects
associated with the structure element. An attribute object shall be a dictionary or stream that includes
an O entry (see "Table 360 — Entries common to all attribute object dictionaries") identifying the
conforming product that owns the attribute information. Other entries, except the NS entry, shall
represent the attributes: the keys shall be attribute names, and values shall be the corresponding
attribute values. To facilitate the interchange of content among conforming products, PDF defines a set
of standard structure attributes identified by specific standard owners; see 14.8.5, "Standard structure
attributes". In addition, attributes may be used to represent user properties (see 14.7.6.4, "User
properties").
NOTE        Earlier versions of PDF also provided for the use of streams as attributes.
Table 360 — Entries common to all attribute object dictionaries
Key      Type         Value
O        name         (Required) The name of the PDF processor creating the attribute data. The value shall
either be a NSO, UserProperties (see "Table 361 — Additional entries in an attribute
object dictionary for user properties"), one of the values from 14.8.5, "Standard
structure attributes", or conform to the guidelines described in Annex E, "Extending
PDF".
If the value for the O entry is NSO then the NS entry shall be present, and shall identify
the owner of the attribute object.
NS       dictionary   (Required if the value of the O entry is NSO; not permitted otherwise; PDF 2.0) An
indirect reference to a namespace dictionary defining the namespace that attributes
with this attribute object dictionary belong to (see 14.7.4, "Namespaces"). If not
present, the attributes in this attribute object dictionary do not have a namespace.
NOTE    Because the NS entry is now reserved within the attribute object dictionary, attributes
from existing namespaces with a matching name will not be able to be used.
Any PDF processor may attach attributes to any structure element, even one created by another PDF
processor. Multiple PDF processors may attach attributes to the same structure element. The A entry in
the structure element dictionary (see "Table 355 — Entries in a structure element dictionary") shall
hold either a single attribute object or an array of at least one object.
When an array of attribute objects is provided, the value of the O and NS keys may be repeated across
attribute objects. If a given attribute is specified more than once, the later (in array order) entry shall
take precedence.

#### 0.12: 14.7.6.2          Attribute classes
If many structure elements share the same set of attribute values, they may be defined as an attribute
class sharing the identical attribute object. Structure elements shall refer to the class by name. The
association between class names and attribute objects shall be defined by a dictionary called the class
map, that shall be kept in the ClassMap entry of the structure tree root (see "Table 354 — Entries in
the structure tree root"). Each key in the class map shall be a name object denoting the name of a class.
The corresponding value shall be an attribute object or an array of such objects.
NOTE       PDF attribute classes are unrelated to the concept of a class in object-oriented programming
languages such as Java and C++. Attribute classes are strictly a mechanism for storing attribute
information in a more compact form; they have no inheritance properties like those of true
object-oriented classes.
The C entry in a structure element dictionary (see "Table 355 — Entries in a structure element
dictionary") shall contain a class name or an array of class names (typically accompanied by revision
numbers as well; see 14.7.6.3, "Attribute revision numbers"). For each class named in the C entry, the
corresponding attribute object or objects shall be considered to be attached to the given structure
element, along with those identified in the element’s A entry. If both the A and C entries are present
and a given attribute is specified by both, the one specified by the A entry shall take precedence.

#### 0.13: 14.7.6.3          Attribute revision numbers
The features described in this subclause are deprecated with PDF 2.0.
When a PDF processor modifies a structure element or its contents, the change may affect the validity
of attribute information attached to that structure element by other PDF processors. A system of
revision numbers shall allow PDF processors to detect such changes and update their own attribute
information accordingly, as described in this subclause.
A structure element shall have a revision number, that shall be stored in the R entry in the structure
element dictionary (see "Table 355 — Entries in a structure element dictionary") or default to 0 if no R
entry is present. Initially, the revision number shall be 0. When a PDF processor modifies the structure
element or any of its content items, it may signal the change by incrementing the revision number.
NOTE 1      The revision number is unrelated to the generation number associated with an indirect object
(see 7.3.10, "Indirect objects").
NOTE 2      If there is no R entry and the revision number is to be incremented from the default value of 0 to
1, an R entry will have to be created in the structure element dictionary in order to record the 1.
Each attribute object attached to a structure element shall have an associated revision number. The
revision number shall be stored in the array that associates the attribute object with the structure
element or if not stored in the array that associates the attribute object with the structure element
shall default to 0.
Each attribute object in a structure element’s A array shall be represented by a single or a pair of array
elements, the first or only element shall contain the attribute object itself and the second (when
present) shall contain the integer revision number associated with it in this structure element.
The structure element’s C array shall contain a single or a pair of elements for each attribute class, the
first or only shall contain the class name and the second (when present) shall contain the associated
revision number.
The revision numbers are optional in both the A and C arrays. An attribute object or class name that is
not followed by an integer array element shall have a revision number of 0 and is represented by a
single entry in the array.
NOTE 3      The revision number is not stored directly in the attribute object because a single attribute
object can be associated with more than one structure element (whose revision numbers can
differ). Since an attribute object reference is distinct from an integer, that distinction is used to
determine whether the attribute object is represented in the array by a single or a pair of entries.
NOTE 4      When an attribute object is created or modified, its revision number is set to the current value of
the structure element’s R entry. By comparing the attribute object’s revision number with that of
the structure element, an application can determine whether the contents of the attribute object
are still current or whether they have been outdated by more recent changes in the underlying
structure element.
Changes in an attribute object shall not change the revision number of the associated structure
element, which shall change only when the structure element itself or any of its content items is
modified.
Occasionally, a PDF processor may make extensive changes to a structure element that are likely to
invalidate all previous attribute information associated with it. In this case, instead of incrementing the
structure element’s revision number, the PDF processor may choose to delete all unknown attribute
objects from its A and C arrays. These two actions shall be mutually exclusive: the PDF processor
should either increment the structure element’s revision number or remove its attribute objects, but it
shall not do both.
NOTE 5       Any PDF processor creating attribute objects needs to be prepared for the possibility that they
can be deleted at any time by another PDF processor.

#### 0.14: 14.7.6.4            User properties
Most structure attributes (see 14.8.5, "Standard structure attributes") specify information that is
reflected in the element’s appearance; for example, BackgroundColor or BorderStyle.
Some PDF writers, such as CAD applications, may use objects that have a standardized appearance,
each of which contains non-graphical information that distinguishes the objects from one another. For
example, several transistors might have the same appearance but different attributes such as type and
part number.
User properties (PDF 1.6) may be used to contain such information. Any graphical object that
corresponds to a structure element may have associated user properties, specified by means of an
attribute object dictionary that shall have a value of UserProperties for the O entry (see "Table 361 —
Additional entries in an attribute object dictionary for user properties").
Table 361 — Additional entries in an attribute object dictionary for user properties
Key     Type     Value
O       name     (Required) The attribute owner. Shall be UserProperties.
P       array    (Required) An array of dictionaries, each of which represents a user property (see
"Table 362 — Entries in a user property dictionary").
The P entry shall be an array specifying the user properties. Each element in the array shall be a user
property dictionary representing an individual property (see "Table 362 — Entries in a user property
dictionary").
Table 362 — Entries in a user property dictionary
Key       Type          Value
N         text string   (Required) The name of the user property.
V         any           (Required) The value of the user property.
While the value of this entry shall be any type of PDF object, PDF writers should use
only text string, number, and boolean values. PDF processors should display text,
number and boolean values to users but need not display values of other types;
however, they should not treat other values as errors.
F         text string   (Optional) A formatted representation of the value of V, that shall be used for
special formatting; for example "($123.45)" for the number -123.45. If this entry is
absent, PDF processors should use a default format.

Key       Type          Value
H         boolean       (Optional) If true, the attribute shall be hidden; that is, it shall not be shown in any
user interface element that presents the attributes of an object. Default value: false.
PDF documents that contain user properties shall provide a UserProperties entry with a value of true
in the document’s mark information dictionary (see "Table 353 — Entries in the mark information
dictionary". This entry allows PDF processors to quickly determine whether it is necessary to search
the structure tree for elements containing user properties.
EXAMPLE           The following example shows a structure element containing user properties called Part Name, Part
Number, Supplier, and Price.
100 0 obj
<</Type /StructElem
/S /Figure                                                 %Structure type
/P 50 0 R                                                  %Parent in structure tree
/A << /O /UserProperties                                   %Attribute object
/P [                                                    %Array of user properties
<</N (Part Name) /V (Framostat) >>
<</N (Part Number) /V 11603 >>
<</N (Supplier) /V (Just Framostats) /H true >>     %Hidden attribute
<</N (Price) /V -37.99 /F ($37.99) >>        %Formatted value
]
>>
>>
endobj

### Requirement 1: 1.1333 TL T*
(goodbye universe.) Tj
EMC                            %End of marked-content sequence 0
/Span <</MCID 1>>                 %Start of marked-content sequence1
BDC
/F12 1 Tf
14 0 0 14 18 660.8 Tm
(This is the first paragraph, which spans pages. It has four fairly short and \
concise sentences. This is the next to last ) Tj
EMC                               %End of marked-content sequence 1
ET                                   %End of text object
endstream
endobj
102 0 obj                                               %Second page object
<</Type /Page
/Parent 100 0 R                                %Parent is the page tree
/Resources <</Font <</F1 6 0 R                 %Font resources
/F12 7 0 R
>>
>>
/MediaBox [0 0 612 792]                        %Media box
/Contents 202 0 R                              %Content stream
/StructParents 1                               %Parent tree key
>>
endobj
202 0 obj                                               %Content stream for second page
<</Length …>>
stream
1 1 1 rg
0 0 612 792 re f
BT                                                %Start of text object
/Para   <</MCID 0>>                          %Start of marked-content sequence 0

BDC
0 0 0 rg
/F12 1 Tf
14 0 0 14 18 732 Tm
(sentence. This is the very last sentence of the first paragraph.) Tj
EMC                                %End of marked-content sequence 0
/Span    <</MCID 1>>                            %Start of marked-content sequence 1
BDC
/F12 1 Tf
14 0 0 14 18 570.8 Tm
( This is the second paragraph. It has four fairly short and concise sentences
. \ This is the next to last ) Tj
EMC                                   %End of marked-content sequence 1
/Span <</MCID 2>>                    %Start of marked-content sequence 2
BDC
1.1429 TL
T*
(sentence. This is the very last sentence of the second paragraph.) Tj
EMC                                  %End of marked-content sequence 2
ET                                                   %End of text object
endstream
endobj
300 0 obj                                                  %Structure tree root
<</Type /StructTreeRoot
/K [301 0 R                                       %Two children: a chapter
304 0 R                                        %and a paragraph
]
/RoleMap  <</Chap /Sect                         %Mapping to standard structure types
/Head1 /H
/Para /P
>>
/ClassMap    <</Normal 305 0 R>>                %Class map containing one attribute class
/ParentTree 400 0 R                             %Number tree for parent elements
/ParentTreeNextKey 2                            %Next key to use in parent tree
/IDTree 403 0 R                                 %Name tree for element identifiers
>>
endobj
301 0 obj                                                  %Structure element for a chapter
<</Type /StructElem
/S /Chap
/ID (Chap1)                                       %Element identifier
/T (Chapter 1)                                    %Human-readable title
/P 300 0 R                                        %Parent is the structure tree root
/K [302 0 R                                       %Two children: a section head
303 0 R                                        %and a paragraph
]
>>
endobj
302 0 obj                                                  %Structure element for a section head
<</Type /StructElem
/S /Head1
/ID (Sec1.1)                                      %Element identifier
/T (Section 1.1)                                  %Human-readable title
/P 301 0 R                                        %Parent is the chapter
/Pg 101 1 R                                       %Page containing content items
/A <</O /Layout                                   %Attribute owned by Layout
/SpaceAfter 25
/SpaceBefore 0
/TextIndent 12.5
>>
/K 0                                        %Marked-content sequence 0
>>
endobj
303 0 obj                                              %Structure element for a paragraph
<</Type /StructElem
/S /Para
/ID (Para1)                                   %Element identifier
/P 301 0 R                                    %Parent is the chapter
/Pg 101 1 R                                   %Page containing first content item
/C /Normal                                    %Class containing this element’s attributes
/K [1                                         %Marked-content sequence 1
<</Type /MCR                            %Marked-content reference to 2nd item
/Pg 102 0 R                          %Page containing second item
/MCID 0                              %Marked-content sequence 0
>>
]
>>
endobj
304 0 obj                                              %Structure element for another paragraph
<< /Type /StructElem
/S /Para
/P 300 0 R                                    %Parent is the structure tree root
/Pg 102 0 R                                   %Page containing content items
/C /Normal                                    %Class containing this element’s attributes
/A << /O /Layout
/TextAlign /Justify                     %Overrides attribute provided by classmap
>>
/K [1 2]                                      %Marked-content sequences 1 and 2
>>
endobj
305 0 obj                                              %Attribute class
<< /O /Layout                                    %Owned by Layout
/EndIndent 0
/StartIndent 0
/WritingMode /LrTb
/TextAlign /Start
>>
endobj
400 0 obj                                              %Parent tree (number tree)
<</Nums [0 401 0 R                               %Parent elements for first page
1 402 0 R                               %Parent elements for second page
]
>>
endobj
401 0 obj                                              %Array of parent elements for first page
[302 0 R                                         %Parent of marked-content sequence 0
303 0 R                                         %Parent of marked-content sequence 1
]
endobj
402 0 obj                                              %Array of parent elements for second page
[303 0 R                                         %Parent of marked-content sequence 0
304 0 R                                         %Parent of marked-content sequence 1
304 0 R                                         %Parent of marked-content sequence 2
]
endobj
403 0 obj                                              %ID tree root node
<</Kids [404 0 R]>>                             %Reference to leaf node
endobj

404 0 obj                                                  %ID tree leaf node
<</Limits [(Chap1) (Sec1.3)]                         %Least and greatest keys in tree
/Names [(Chap1) 301 0 R                           %Mapping from element identifiers
(Sec1.1) 302 0 R                           %to structure elements
(Sec1.2) 303 0 R
(Sec1.3) 304 0 R
]
>>
endobj

#### 1.1: 14.8.1            General
Tagged PDF (PDF 1.4) is a stylised use of PDF that builds on the logical structure framework described
in 14.7, "Logical structure". It defines a set of standard structure types and attributes that allow page
content (text, graphics and images, as well as annotations and form fields) to be extracted and reused
for other purposes.
A tagged PDF document is one that conforms to all rules described in all of the subclauses in 14.8,
"Tagged PDF".
A tagged PDF document shall contain a mark information dictionary (see "Table 353 — Entries in the
mark information dictionary") with a value of true for the Marked entry.
NOTE        Tagged PDF is intended for use by tools that perform operations such as:
•    Extraction of text and graphics for pasting into other applications
•    Automatic reflow of page contents – text as well as associated graphics and images or
annotations and form fields – to fit a display area of a different size than was assumed for
the original layout
•    Processing of content for such purposes as searching, indexing, and spell-checking
•    Conversion to other common file formats (such as HTML, XML, and RTF) with document
structure preserved
•    Making content accessible to users with disabilities

#### 1.2: 14.8.2.1          General
Like all PDF documents, a tagged PDF document consists of a sequence of self-contained pages, each of
which is described by one or more page content streams (including any subsidiary streams such as
form XObjects), annotations and form fields. Tagged PDF defines some further rules for organising and
marking content streams so that additional information may be derived from them:
•    Distinguishing between the author’s original content and artifacts of the layout process (see
14.8.2.2, "Real content and Artifacts").
•    Specifying the content order as intended by the content author to guide the layout process if the
PDF processor repurposes the page content (see 14.8.2.5, "Page content order and logical content
order").
•    Guaranteeing that the logical order of content can be deterministically derived from a
combination of logical structure and page content (see 14.8.2.5, "Page content order and logical
content order").
•    Representing text in a form from which a Unicode representation may be unambiguously derived
(see 14.8.2.6, "Unicode mapping in tagged PDF").
•    Representing word breaks unambiguously (see 14.8.2.6.2, "Identifying word breaks").
•    Marking all content with information for making it accessible to users with visual impairments or
other disabilities (see 14.9, "Repurposing and accessibility support").

#### 1.3: 14.8.2.2.1      General
The content in a document may be divided into two classes:
•    The real content of a document comprises graphics objects, annotations and form fields
representing material intentionally introduced by the document’s author and necessary to
understand the content of the document.
•    All other content is considered to be artifacts, whether generated by the PDF writer in the course
of pagination, layout, or other mechanical processes or introduced by the document author for
decoration or other purposes that are not relevant for understanding the content of the
document.
The document’s logical structure encompasses all real content and describes how real content objects
relate to one another. Where artifacts are to be included in the structure tree, they shall be included
through the Artifact structure element type, and shall not be considered real content.
A document’s real content may include graphics objects in the page content stream and subsidiary
XObjects and annotations, including widget annotations.
NOTE 1     The above paragraph was clarified in this document (2020).
To support PDF processors in providing accessibility to users with disabilities, tagged PDF documents
should use the natural language specification (Lang), alternate description (Alt), replacement text
(ActualText), and abbreviation expansion text (E) facilities as described in 14.9, "Repurposing and
accessibility support".
NOTE 2     ISO 14289 (PDF/UA) specifies the use of tagged PDF to accommodate the needs of users with
disabilities.
Tagged PDF processors may make various choices about what page content to consider relevant in a
tagged PDF document. A text-to-speech engine, for instance, may decide not to speak running heads or
page numbers when the page is turned. In general, PDF processors may do any of the following:
•    Disregard elements of page content (for example, skip Link annotations) that are not of interest
•    Treat some page elements as terminals that are not to be examined further (for example, to treat
an illustration as a unit for repurposing)
•    Substitute an element with its alternative description (see 14.9.3, "Alternate descriptions")
NOTE 3     Depending on their goals, different PDF processors can make different decisions in this regard.
The purpose of tagged PDF is not to prescribe what the PDF processor does, but to provide
sufficient declarative and descriptive information to allow it to make appropriate choices about
how to process the content.

#### 1.4: 14.8.2.2.2        Specification of Artifacts
For tagged PDF files, an artifact should be explicitly distinguished from real content through either of
the following methods:
•    By enclosing it in a marked-content sequence with the tag Artifact:
EXAMPLE 1
/Artifact BMC
EMC
EXAMPLE 2 (marked-content sequence Artifact with a property list entry)
/Artifact <<propertyList>> BDC
EMC
•    By inclusion in the logical structure tree through the use of the Artifact structure element type
(see "Table 375 — standard structure type Artifact").
NOTE 1      The purpose of the Artifact structure element type is to accommodate artifact content in cases
that have positional context relative to real content within the structure tree. An example of such
content is line numbers.
For artifacts defined using the marked-content sequence method, the form indicated in EXAMPLE 1
shall be used to identify a generic artifact; the form indicated in EXAMPLE 2 shall be used for those
artifacts that have an associated property list. "Table 363 — Property list entries for artifacts" shows
the properties that may be included in such a property list.
Any content that is not included in the structure tree is an artifact even when not enclosed in a marked-
content sequence using the tag Artifact.
NOTE 2      The phrase “any content” above refers to all page content as well as annotations.
Table 363 — Property list entries for artifacts
Key              Type              Value
Type             name              (Optional) The type of artifact that this property list describes; if present, shall be
one of the names Pagination, Layout, Page or Background.
•    Pagination artifacts are ancillary page features such as running heads, folios (page
numbers) or Bates Numbering.
•    Layout artifacts are purely cosmetic typographical or design elements such as
footnote rules or decorative ornaments.
•    Page artifacts are production aids extraneous to the document itself, such as cut
marks and colour bars.
•    Background artifacts can occur from document templates that are often repeated
unchanged across many pages and include images, patterns or coloured blocks that
either run the entire length and/or width of the page or the entire dimensions of a
structural element.
BBox             rectangle         (Optional) An array of four numbers in default user space units giving the
coordinates of the left, bottom, right, and top edges, respectively, of the artifact’s
bounding box (the rectangle that completely encloses its visible extent).
Key           Type          Value
Attached      array          (Optional; pagination and full-page background artifacts only) An
array of name objects containing one to four of the names Top,
Bottom, Left, and Right, specifying the edges of the page, if any, to
which the artifact is logically attached. Page edges shall be defined
by the page’s crop box (see 14.11.2, "Page boundaries"). The
ordering of names within the array is immaterial. Including both
Left and Right or both Top and Bottom indicates a full-width or full
height artifact, respectively.
Use of this entry for background artifacts shall be limited to full-
page artifacts. Background artifacts that are not full-page take their
dimensions from their parent structural element.
NOTE             (2020) The Attached key was accidently omitted from
the earlier PDF 2.0 specification and was reinstated in
this document.
Subtype       name          (Optional; PDF 1.7) The subtype of the artifact. This entry should appear only
when the Type entry has a value of Pagination. Valid values are Header, Footer,
Watermark, PageNum (PDF 2.0), LineNum (PDF 2.0), Redaction (PDF 2.0) and
Bates (PDF 2.0). Additional values may be specified for this entry, provided they
comply with the naming conventions described in Annex E, "Extending PDF".
Some properties defined elsewhere may also be used as entries in the property list of an artifact,
including Alt (see 14.9.3, "Alternate descriptions"), ActualText (see 14.9.4, "Replacement text"), E (see
14.9.5, "Expansion of abbreviations and acronyms") or Lang (see 14.9.2, "Natural language
specification").
Where it is necessary to represent the content of an artifact as text, the property ActualText can be
used, for instance, to contain the page number for an artifact with a Subtype of PageNum or the Bates
number for an artifact of subtype Bates.
NOTE 3     Bates numbering is used in the legal, medical, and business fields in some countries to place
identifying numbers and/or date/time-marks on images and documents. For example, it is added
during the discovery stage of preparations for trial or when identifying business receipts. This
process provides identification, protection, and automatic consecutive numbering.

#### 1.5: 14.8.2.3       Soft hyphens
In tagged PDF, the visible hyphen that is introduced through the incidental division of a word at the
end of a line but which would not be present otherwise, may be represented as a soft hyphen, mapped
to the Unicode value U+00AD, in one of the ways described in 14.8.2.6, "Unicode mapping in tagged
PDF".
NOTE 1     The soft hyphen character represented by the Unicode value U+00AD is distinct from an
ordinary hard hyphen, whose Unicode value is U+002D.
The writer of a tagged PDF document shall distinguish explicitly between soft and hard hyphens so that
a PDF processor can unambiguously determine which type a given character represents.

NOTE 2      In some languages, the situation is more complicated: there can be multiple characters affected
by hyphenation, and hyphenation can change the spelling of words. See the Example in 14.9.4,
"Replacement text".

#### 1.6: 14.8.2.4          Hidden or invisible page content
For a variety of reasons, elements of a document’s real content can be invisible on the page: they can be
clipped; their colour can match the background; or they can be obscured by other, overlapping objects.
For the purposes of tagged PDF, page content shall be considered to include all graphics objects in their
entirety, regardless of whether they are visible when the document is displayed or printed.
NOTE        For example, invisible elements can become visible when content is repurposed, or a text-to-
speech engine could choose to speak invisible text.

#### 1.7: 14.8.2.5.1        General
Page content order shall be defined by the sequencing of graphics objects within a page’s content
stream.
Logical content order – the ordering for semantic purposes – shall be defined by a depth-first traversal
of the document’s logical structure hierarchy.
The page content order in a tagged PDF should coincide with the logical content order.
NOTE 1      Page content order is constrained by the need to render objects in an order that produces the
desired visual appearance. Logical content order is constrained by the need to reflect the order
of the content as intended by its author. For example, the running text of a page, as encoded in
the page’s content stream, can contain places where it is not possible to make the order in which
the text progresses match the logical content order.
Content within a single marked-content sequence (see 14.6, "Marked content") shall be in logical
content order for that item of content.
NOTE 2      Both in terms of how page content is encoded in a tagged PDF as well as in terms of how a PDF
processor can process that content, efficiency can be impacted if the page content order and
logical content order sequences do not coincide. In some cases it is not feasible to make the
sequences coincide:
•    Regarding the sequence of page objects within a given page, page objects can visually
overlap in a way that requires reverse ordering.
•    A logical object can extend over more than one PDF page, such as in the case of a headline
spanning two pages in a facing pages layout.
•    A page can contain the beginnings of two separate articles, each of which is continued onto
a later page of the document. In logical content order terms, the last words of the first
article appearing on the page are not followed by the first words of the second article on the
same page, but rather by the continuation of the first article on a different page.
NOTE 3      Artifacts not contained within an Artifact structure element are not considered part of the
logical content order because only structure elements are part of the logical content order.

#### 1.8: 14.8.2.5.2      Sequencing of annotations
Annotations associated with a page are not interleaved within the page’s content stream but are listed
in the Annots array in its page object (see 7.7.3.3, "Page objects"). The position of an annotation in the
logical content order is determined from the document’s logical structure.
Both page content (marked-content sequences) and annotations may be treated as content items that
are referenced from structure elements (see 14.7.5, "Structure content"). Structure elements of type
Annot, Link, or Form (see 14.8.4.7, "Inline level structure types") explicitly specify the association
between a marked-content sequence and a corresponding annotation through an object reference
dictionary as described in 14.7.5.3, "PDF objects as content items".

#### 1.9: 14.8.2.5.3      Reverse-order show strings
The marked-content tag ReversedChars informs the PDF processor that show strings within a
marked-content sequence contain characters in reverse order. In order for such text to be extracted or
read out aloud, the sequence of the characters as found in the show string operator shall be reversed
before using them. If the sequence encompasses multiple show strings, only the individual characters
within each string shall be reversed.
NOTE 1     In writing systems that are read from right to left (such as Arabic or Hebrew), one expects that
the glyphs in a font would have their origins at the lower right and their widths (rightward
horizontal displacements) specified as negative. For various technical and historical reasons,
however, many such fonts follow the same conventions as those designed for Western writing
systems, with glyph origins at the lower left and positive widths, as shown in "Figure 54 — Glyph
metrics". Consequently, showing text in such right-to-left writing systems requires either
positioning each glyph individually (which is tedious and costly) or representing text with show
strings (see 9.2, "Organisation and use of fonts") whose character codes are given in reverse
order.
The show strings in a ReversedChars block may have a SPACE (U+0020) character or other white-
space characters at the beginning or end to indicate a word break (see 14.8.2.6.2, "Identifying word
breaks") but shall not contain interior SPACE characters or other white-space characters.
NOTE 2     This limitation is not serious, since a SPACE or other white-space character typically provides an
opportunity to realign the typography without visible effect, and it serves the valuable purpose
of limiting the scope of reversals for word-processing interactive PDF processors.
EXAMPLE        The sequence
/ReversedChars
BMC
( olleH) Tj
-200 0 Td
( .dlrow) Tj
EMC
represents the text
Hello world.

#### 1.10: 14.8.2.6.1        General
PDF documents conforming with 14.8, "Tagged PDF" should map every character code in any of the
content streams or appearance streams of a document to a corresponding Unicode value. Every
character code that belongs to a structure element in the structure tree shall map to Unicode, except
where an associated Alt or ActualText entry applies to the content to which the character code
belongs.
NOTE 1      These Unicode values can then be used for such operations as copy-and-paste, searching, text-to-
speech conversion, and exporting to other applications or file formats.
NOTE 2      Unicode defines scalar values for most of the characters used in the world’s languages and
writing systems, as well as providing a private use area for application-specific characters.
Information about Unicode can be found in the Unicode Standard.
The methods for mapping a character code to a Unicode value are described in 9.10.2, "Mapping
character codes to Unicode values".
Private Use Area Unicode values should only be used if no other Unicode value is available, as no pre-
defined meaning is associated with the Unicode values in the Private Use Area.
NOTE 3      An Alt, ActualText, or E entry specified in a structure element dictionary or a marked-content
property list (see 14.9.3, "Alternate descriptions" 14.9.4, "Replacement text" and 14.9.5,
"Expansion of abbreviations and acronyms") can affect the character stream used by PDF
processors. For example, some PDF processors could choose to use the Alt or ActualText entry
and ignore all text and other content associated with the structure element and its descendants.
In some cases a required character may not be available in a given font, for example the soft hyphen
character. Such a character may be represented either by adding it to the font’s encoding or CMap and
using ToUnicode to map it to the appropriate Unicode value, or by using an ActualText entry in the
associated structure element to provide substitute characters.

#### 1.11: 14.8.2.6.2        Identifying word breaks
A document’s text content defines not only the characters in a page’s text but also the words. Unlike a
character, which is defined unambiguously, a word is defined by script and context. A repurposing tool
needs to determine where it can break the running text into lines; a text-to-speech engine needs to
identify the words to be vocalised; spelling checkers and other applications have varying definitions
for what constitutes a word. It is not important for a tagged PDF document to identify the words within
the text stream according to a single, unambiguous definition that satisfies all of these clients. What is
important is that there be enough information available for each client to make that determination for
itself.
A PDF processor of a tagged PDF document may find words by sequentially examining the Unicode
character stream, as augmented by replacement text specified with ActualText (see 14.9.4,
"Replacement text").
For this purpose any white-space characters that would be present to separate words in a pure text
representation shall be present in the tagged PDF representation of the text.
NOTE 1     As a consequence, the PDF processor can determine word breaks without having to rely on
heuristics based on information such as glyph positioning on the page, font changes, or glyph
sizes.
The identification of what constitutes a word shall be unrelated to how the text happens to be grouped
into show strings. The division into show strings shall have no semantic significance. In particular, a
SPACE (U+0020) or other word-breaking character shall be present in a character stream even if a
word break happens to fall at the end of a show string.
NOTE 2     Some PDF processors identify words by simply separating them at every SPACE character.
Others can be slightly more sophisticated and treat punctuation marks such as hyphens or Em
dashes as word separators as well. Still others can identify line-break opportunities by using an
algorithm similar to the one in Unicode Standard Annex #29, Unicode Text Segmentation.

#### 1.12: 14.8.3.1        General
Tagged PDF’s standard structure types and attributes can be interpreted in the context of a basic
layout model that describes the arrangement of structure elements on the page. This model is designed
to capture the general intent of the document’s underlying structure and does not necessarily
correspond to the one actually used for page layout by the application creating the document (the PDF
content stream specifies the exact appearance).
NOTE 1     The goal is to provide sufficient information for PDF processors to make their own layout
decisions while preserving the authoring application’s intent as closely as their own layout
models allow.
NOTE 2     The tagged PDF layout model resembles the ones used in markup languages such as HTML, XML,
and RTF, but does not correspond exactly to any of them. The model is deliberately defined
loosely to allow reasonable latitude in the interpretation of structure elements and attributes
when converting to other document formats. Some degree of variation in the resulting layout
from one format to another is to be expected.

#### 1.13: 14.8.3.2        Reference area
The basic layout model begins with the notion of a reference area. This is a rectangular region used as a
frame or guide in which to place the document’s content. Some of the standard structure attributes,
such as StartIndent and EndIndent (see 14.8.5.4.3, "Layout Attributes for BLSEs"), shall be measured
from the boundaries of the reference area. Reference areas are not specified explicitly but are inferred
from context. Those of interest are generally the column area or areas in a general text layout, the
outer bounding box of a table and those of its component cells, and the bounding box of a Figure, Form
or Formula, or other floating element.
The standard structure types can be divided into four main categories according to the roles they play
in page layout:
•    Grouping elements (see 14.8.4.4, "Grouping level structure types") group other elements into
sequences or hierarchies but hold no content directly and have no direct effect on layout.
•    Block-level structure elements (BLSEs) (see 14.8.4.5, "Block level structure types") describe the
overall layout of content on the page, proceeding in the block-progression direction.
•    Inline-level structure elements (ILSEs) (see 14.8.4.7, "Inline level structure types") describe the
layout of content within a BLSE, proceeding in the inline-progression direction.

•    Some elements can be grouping elements, BLSEs or ILSEs, depending on context or usage. For
example, a Figure structure element can be treated as either a grouping element, a BLSE or an
ILSE.

#### 1.14: 14.8.3.3          Progression direction
The meaning of the terms block-progression direction and inline-progression direction depends on the
writing system in use, as specified by the standard attribute WritingMode (see 14.8.5.4.2, "General
Layout Attributes"). In Western writing systems, the block direction is from top to bottom and the
inline direction is from left to right. Other writing systems use different directions for laying out
content.
Because the progression directions can vary depending on the writing system, edges of areas and
directions on the page are identified by terms that are neutral with respect to the progression order
rather than by familiar terms such as up, down, left, and right. Block layout proceeds from before to
after, inline from start to end. Thus, for example, in Western writing systems, the before and after
edges of a reference area are at the top and bottom, respectively, and the start and end edges are at the
left and right. Another term, shift direction (the direction of shift for a superscript), refers to the
direction opposite that for block progression — that is, from after to before (in Western writing
systems, from bottom to top).
BLSEs shall be stacked within a reference area in block-progression order. In general, the first BLSE
shall be placed against the before edge of the reference area. Subsequent BLSEs shall be stacked
against preceding ones, progressing toward the after edge, until no more BLSEs fit in the reference
area. If the overflowing BLSE allows itself to be split — such as a paragraph that can be split between
lines of text — a portion of it may be included in the current reference area and the remainder carried
over to a subsequent reference area (either elsewhere on the same page or on another page of the
document). Once the amount of content that fits in a reference area is determined, the placements of
the individual BLSEs may be adjusted to bias the placement toward the before edge, the middle, or the
after edge of the reference area, or the spacing within or between BLSEs may be adjusted to fill the full
extent of the reference area.
BLSEs may be nested, with child BLSEs stacked within a parent BLSE in the same manner as BLSEs
within a reference area. Except in a few instances noted (the BlockAlign and InlineAlign elements),
such nesting of BLSEs does not result in the nesting of reference areas; a single reference area prevails
for all levels of nested BLSEs.
Within a BLSE, child ILSEs shall be packed into lines. Direct content items — those that are immediate
children of a BLSE rather than contained within a child ILSE — shall be implicitly treated as ILSEs for
packing purposes. Each line shall be treated as a synthesized BLSE and shall be stacked within the
parent BLSE. Lines may be intermingled with other BLSEs within the parent area. This line-building
process is analogous to the stacking of BLSEs within a reference area, except that it proceeds in the
inline-progression rather than the block-progression direction: a line shall be packed with ILSEs
beginning at the start edge of the containing BLSE and continuing until the end edge shall be reached
and the line is full. The overflowing ILSE may allow itself to be broken at linguistically determined or
explicitly marked break points (such as hyphenation points within a word), and the remaining
fragment shall be carried over to the next line.
Certain values of an element’s Placement attribute remove the element from the normal stacking or
packing process and allow it instead to float to a specified edge of the enclosing reference area or
parent BLSE; see "General Layout Attributes" in 14.8.5.4, "Layout Attributes" for further discussion.
Two enclosing rectangles shall be associated with each BLSE and ILSE (including direct content items
that are treated implicitly as ILSEs):
•    The content rectangle shall be derived from the shape of the enclosed content and defines the
bounds used for the layout of any included child elements.
•    The allocation rectangle includes any additional borders or spacing surrounding the element,
affecting how it shall be positioned with respect to adjacent elements and the enclosing content
rectangle or reference area.
The definitions of these rectangles shall be determined by layout attributes associated with the
structure element; see 14.8.5.4.5, "Content and Allocation Rectangles" for further discussion.

#### 1.15: 14.8.4.1         General
Standard structure types are divided into categories:
•    "Document level structure types" identify a whole document or a fragment of a document. In most
cases a tagged PDF will contain exactly one document, but in some other cases a tagged PDF
contains several documents that have been merged together into one PDF file, or the tagged PDF
is a document containing document fragments which have been inserted into the document.
•    "Grouping level structure types" make it possible to organise the overall structure of content in a
tagged PDF. For example, a book typically consists of chapters, or a newspaper page consists of
several parts called articles, and a scientific publication typically contains sections and several
levels of sub-sections.
•    "Block level structure types" are structure types that enclose actual content, like a heading or
paragraph.
•    "Inline level structure types" are structure types that enable structural organisation of content
inside block level elements and inside specialised structure elements used as block level elements.
Some structure types — for example Table or Figure — may be used as block level types or as inline
types, whereas others (e.g., H1) may only be used as block level types. Whenever a provision in clause
14.8, "Tagged PDF", refers to block level types, all structure elements used as block level elements shall
be included. Whenever a provision in clause 14.8, "Tagged PDF", refers to inline level types, all
structure elements used as inline level elements shall be included.
To determine the category that is applicable to a structure element that may either be a block level
structure element or an inline level structure element, the following applies:
•    If the structure element is used inside a block level element, it is an inline level structure element
•    In all other cases it is a block level structure element.
All structure elements occurring within a tagged PDF document shall have a type matching one of
those defined as a Standard Structure Type, or a role map providing a mapping from the non-standard
type to a Standard Structure Type.

#### 1.16: 14.8.4.2          Nesting of standard structure elements
Annex L, "Parent-child relationships between the standard structure elements in the standard
structure namespace for PDF 2.0" defines the nesting rules for standard structure elements. In
addition, supplemental rules apply for some standard structure elements. These supplemental rules
are defined in the subclauses specific to each of the standard structure types.
Structure elements other than the standard structure elements identified in clause 14.8.4 "Standard
structure types" or in the standard structure namespaces (see 14.8.6.2, "Role maps and namespaces")
shall nest in relation to standard structure elements according to the requirements of the structure
elements to which they are role mapped.
NOTE        The nesting rules detailed in Annex L, "Parent-child relationships between the standard
structure elements in the standard structure namespace for PDF 2.0" address in detail the
following system model:
o   Structure elements can be empty.
o   If a structure element contains neither structure elements nor real content it is
empty.
o   Unless specifically constrained in 14.8, "Tagged PDF", any number of structure
elements can exist in any order inside a parent structure element.
o   Real content is contained inside block level or inline level structure elements.
o   Document level structure elements that are not empty contain other document
level, grouping or block level elements, and cannot contain inline level structure
elements or content.
o   Grouping structure elements that are not empty contain other document level,
grouping or block level elements, and cannot contain inline level structure elements
or content.
o   Inline level elements can contain other inline level structure elements but cannot
contain any other type of structure element.

#### 1.17: 14.8.4.3          Document level structure types
In a tagged PDF file a logical document is a portion of content typically perceived as a semantically self
contained document of any granularity. Examples range from short memos to articles, presentations or
fillable forms to comprehensive publications like magazines or books.
A logical document fragment is a portion of content that constitutes – or is intended or perceived as –
just a part of a logical document, regardless of whether it was extracted from a logical document or
originated as a document fragment. A tagged PDF file may consist of one or more logical documents or
logical document fragments as described in "Table 364 — Document level structure types".
Table 364 — Document level structure types
Structure Type       Category       Description
Document             Document       Encloses a logical document.
EXAMPLE 1         A mail merge PDF typically contains a number of
letters to different recipients. This implies that the
PDF at the top level is one document, containing
multiple documents at its child level where each such
document is a letter to a recipient.
EXAMPLE 2         A Proceedings PDF generally includes individual
papers given at a conference. This implies that the
PDF at the top level is one document containing
several documents.
DocumentFragment     Document       (PDF 2.0) Encloses a logical document fragment.
A document fragment is typically created by extracting it as a
part from an original complete document. As a consequence the
structure of the fragment may be incomplete, and content may
start at an arbitrary point within the original logical content
structure.
EXAMPLE 3         The following are just two possible types of
document fragments:
•    an extract from an original document is inserted
into a new containing document
•    extracts   from     original documents        are
concatenated into a new document
NOTE 1     A logical document can contain any number of DocumentFragment elements, including nested
logical document fragments.
Each logical document fragment shall define its own logical structure. The logical structure of a logical
document fragment may start in the middle of what was the parent document’s logical structure. For
example, it could start at an arbitrary paragraph or at a heading level 2 or 3 instead of heading level 1
or even in the middle of a list.
NOTE 2     DocumentFragments are especially useful when hierarchical aspects of logical structure from
the original document are to be maintained but are incomplete and thus would be difficult to
understand or process.
Within each Document or DocumentFragment structure element, all heading structure elements
shall either be Hn or H. See "Table 366 — Block level structure types" for more information on heading
structure elements.
An XMP metadata stream (see 14.3.2, "Metadata streams") in a Document or DocumentFragment
structure element may be used to include document metadata for a logical document nested inside a
tagged PDF.

#### 1.18: 14.8.4.4          Grouping level structure types
This subclause describes structure types for grouping elements, as detailed in "Table 365 — Grouping
level structure types", that are used to organise the overall structure of content in a tagged PDF.
Table 365 — Grouping level structure types
Structure       Category       Description
Type
Part            Grouping       Encloses a grouping of structure elements without consideration for their
hierarchy.
NOTE 1 Part is the semantic equivalent of Div.
A structure element with the type of Part shall inherit the containment
requirements and limitations of its parent element. Where the parent
element is itself a structure element of type Part, then the inheritance shall
recurse to the first parent element whose type is not Part.
EXAMPLE 1         The following are just a few of the possible types of content that
could be marked as Part:
•   frontmatter or backmatter in a book
•   a table of contents or bibliography section in a document
•   main body of content in a document
•   advertising section in a magazine
•   a group of pages (for example, a spread in a magazine)
•   a group of form fields
•   a group of Figure standard structure elements
•   a publisher’s indicia
Sect            Grouping       Encloses a grouping of structure elements with consideration for their
hierarchy.
EXAMPLE 2         The following are just a few of the possible types of content that
could be marked as Sect:
•   clauses in a technical document
•   components of an article in a newspaper or magazine
•   Elements of a recipe          (e.g.,   “name”,   “instructions”,
“ingredients”, etc.)
Structure      Category    Description
Type
Div            Grouping    Encloses content structured in fashion that is orthogonal to the semantic
structure. It can be used as a role mapping target for custom tags for which
no suitable standard structure element is available, or where attributes are
applied in a non-semantic fashion.
NOTE 2 Nesting Div structure elements allows content to be subdivided.
A structure element with the type of Div shall inherit the containment
requirements and limitations of its parent element. Where the parent
element is itself a structure element of type Div, then the inheritance shall
recurse to the first parent element whose type is not Div.
NOTE 3 Div does not change the semantic level of the structure hierarchy.
EXAMPLE 3        The following is just one of the possible types of content that
could be marked as Div:
•    associating a language attribute to group of content items
without implying any semantic aspects
Aside          Grouping    (PDF 2.0) Encloses content that is distinct from other content within its
parent structure element.
EXAMPLE 4        The following are just a few of the possible types of content that
could be marked as Aside:
•    Callout elements
•    Sidebar elements
•    Commentary accompanying an article
•    Background information for a section in a text book
NonStruct      Grouping    (Non-structural element) A grouping element having no inherent
structural significance; it serves solely for grouping purposes. This type of
element differs from a division (structure type Div) in that it should not be
interpreted or exported to other document formats. Its descendants shall
be processed normally.
A structure element with the type of NonStruct shall inherit the
containment requirements and limitations of its parent element. Where the
parent element is itself a structure element of type NonStruct, then the
inheritance shall recurse to the first parent element whose type is not
NonStruct.
NOTE          (2020) This document updated the definition of Part and returned Sect and NonStruct to the
above table with revised definitions.

#### 1.19: 14.8.4.5          Block level structure types
This subclause describes structure types for paragraph-like elements, as detailed in "Table 366 —
Block level structure types", that consist of running text and other content laid out in the form of
conventional paragraphs (as opposed to more specialised types of content such as lists and tables).

Table 366 — Block level structure types
Structure       Category      Description
Type
P               Block         (Paragraph) A low-level division of content. Although in many cases it will
be used for paragraphs it may enclose any low-level division of content.
EXAMPLE            The following is just one of the possible types of content that
could be marked as P:
•    A paragraph in a newspaper article or a paragraph in the
chapter of a novel.
Hn              Block         (With n being a sequence of digits representing an unsigned integer greater
than or equal to 1) Encloses a low-level division of content usually referred
to as a heading.
NOTE 1 Low-level content would typically be perceived as a sub-section of a
document, whether a section heading, chapter or any other identifiable
subdivision of content within a logical document. See the Title element
regarding high-level division of content.
Any such heading structure element shall always consist of the uppercase
letter "H" and one or more digits, representing an unsigned integer greater
than or equal to 1, without leading zeroes or any other prefix or postfix.
The heading level is indicated through the chosen structure element type,
for example H1 indicates a heading at the topmost level within a document,
H2 a heading at the second level, and so forth.
NOTE 2 This implies that H7 can be used to indicate a heading on the seventh
level, whereas h7, H07, H-7 or H_7 cannot be used as heading structure
elements.
The heading level indicated by a heading should reflect the heading level of
the tagged content.
NOTE 3 The Lbl structure element can be used to enclose section enumeration
content or its functional equivalent present inside the heading.
EXAMPLE            A section heading in a text book or newspaper article is one
example where a heading level would be indicated.
Structure   Category    Description
Type
H           Block       Encloses a low-level division of content usually referred to as a heading. The
heading level is not indicated through this structure element, but instead is
derived from the nesting of the logical structure within a given Document
or DocumentFragment structure element. The H heading structure
elements should always be the first structure element within its parent
structure element. The H heading structure element shall always be the
only heading structure element within its parent structure element.
NOTE 1 This implies that within a given logical document it is not acceptable that
an H heading structure element is used if a H1, H2, H3 etc. heading
structure element is also used inside the same DocumentFragment
structure element.
NOTE 2 The Lbl structure element can be used to enclose a section number or
similar present inside the heading.
EXAMPLE 1         As the use of the H heading structure element requires strict
document structuring it is typically used only for machine
generated documents, documents created from a well structured
content data set or documents whose creation is fully controlled
by a program such that its structure is strictly guaranteed.
EXAMPLE 2         Scientific publications and technical specifications often follow
very strict structuring rules and thus are suitable candidates for
use of the H heading structure element.
Title       Grouping    (PDF 2.0) Encloses content that is usually referred to as the title of a
or Block    document or high-level division of content.
NOTE 3 High-level content would typically be perceived as the title of an article,
section, chapter or any other identifiable top-level subdivision of content
within a logical document. See the Hn and H elements regarding low-level
division of content.
It should occur only once inside the parent grouping structure element, and
it should occur at or near the beginning of the content inside that grouping
structure element.
EXAMPLE 3         The title of a book, brochure or leaflet are some types of content
that can be marked with the Title structure element.
FENote      Grouping,   (PDF 2.0) Used to markup footnotes and endnotes. Footnotes and endnotes
Block or    are content that is not normally read as part of the enclosing content from
Inline      which it is referenced, but rather consulted at the reading person’s
discretion. In order for text to be considered a footnote or endnote, there
should be a reference from the enclosing content to the footnote or
endnote. Such reference may be achieved by means of a Link structure
element through a structure destination in its link annotation (see "Table
368 — General inline level structure types"), or use of Ref in structure
elements (see "Table 355 — Entries in a structure element dictionary").
NOTE 4 Text that is labelled as a note – like this paragraph –but is intended to be
normally read together with the enclosing content is not a footnote or
endnote.

#### 1.20: 14.8.4.6          Sub-block level structure type
"Table 367 — Sub-block level structure type" defines a structure type similar to block level types but
intended for use in an inline context. An example of this usage is provided in H.8.4, "Example of Sub
standard structure type".
Table 367 — Sub-block level structure type
Structure       Category       Description
Type
Sub             Inline         (PDF 2.0) (Sub-division of a block level element) Encloses content typically
perceived as a sub-division inside a block level structure element.
A Lbl structure element may be used inside a Sub structure element to
enclose a line number, verse number or similar, if present.
If a Sub structure element is used, all other content inside the same block
level element that is the parent of the Sub structure element, should also
be enclosed in Sub structure elements.
Examples:
•    a verse in a poem or sacred scripture
•    a line-numbered document
•    a line of source code
•    a line in a postal address

#### 1.21: 14.8.4.7.1        General
Unless otherwise noted in 14.8.4.2, “Nesting of standard structure elements”, any inline structure
element is optional. It may occur once or more than once inside its parent structure element. The other
children of its parent structure element, if any are present, may be other inline structure elements or
actual content. Inline structure elements and portions of actual content inside a parent structure
element may occur in any combination and in any order.
Unless restricted by their type, structure elements and portions of actual content inside a parent
structure element may occur in any combination and in any order.

#### 1.22: 14.8.4.7.2        General inline level structure types
"Table 368 — General inline level structure types" defines standard structure types for inline level
structure types.
Table 368 — General inline level structure types
Structure   Category   Description
Type
Lbl         Inline     (Label) Encloses content that distinguishes it from other content inside the same
parent element.
In a list item (see 14.8.4, "Standard structure types") the Lbl structure element
may enclose the bullet for list items in unordered lists or digits and characters
used for numbering of list items in ordered lists. For headings it may be the
number of the chapter. For a definition list it may enclose the term to be defined.
For key value pairs it may enclose the key for which a value is provided. For an
entry in a table of contents there may be two Lbl structure elements, one for a
chapter number, and one for the page number at which the chapter starts, whereas
the actual text for the chapter heading is the remaining portion of the table of
contents list item.
EXAMPLE 1        The following are just a few of the possible types of content that could be
marked as Lbl:
•    bullets for list items in an unordered list
•    digits or characters used for numbering list items in an ordered list
•    the number in the Caption for a Figure or Table
•    in a form, the label of a form field
•    in footnotes, the number or symbol matching the reference from the
text
•    in headings, the enumeration of the headings
•    in a dictionary, the word for which a translation is provided
•    in a definition list, the term for which a definition is provided
•    in key value pairs, the key for which a value is provided
•    in a question and answer sequence in an interview, visual cues for
designating questions and answer
Span        Inline     A generic inline portion of content having no particular inherent characteristics. It
can be used, for example, to delimit a range of text with certain attributes.
EXAMPLE 4        A word inside a sentence is in a different language than the surrounding
text, and is contained in a Span with a Lang attribute indicating the
applicable language.
EXAMPLE 5        A custom set of structure element types defines custom inline structure
elements which are mapped to the Span structure element in the
RoleMap to enable a PDF processor unaware of the custom set of
structure element types to essentially ignore the structure element.

Structure    Category      Description
Type
Em           Inline        (PDF 2.0) (Emphasis) Encloses content for the purpose of emphasis. The level of
stress that a particular piece of content has is given by its number of ancestor Em
structure elements.
The placement of stress emphasis changes the meaning of the sentence. The
element thus forms an integral part of the content. The precise way in which stress
is used in this way depends on the language.
EXAMPLE 2         These examples show how changing the stress emphasis changes the
meaning. First, a general statement of fact, with no stress:
<P>Cats are cute animals.</P>
By emphasizing the first word, the statement implies that the kind
of animal under discussion is in question (maybe someone is
asserting that dogs are cute):
<P><Em>Cats</Em> are cute animals.</P>
By moving it to the adjective, the exact nature of the cats is
reasserted (maybe someone suggested cats were mean animals):
<P>Cats are <Em>cute</Em> animals.</P>
Strong       Inline        (PDF 2.0) Encloses content for the purpose of strong importance, seriousness or
urgency for its contents.
EXAMPLE 3         In this example the Strong element is used to denote the content that the
user is intended to read first:
<P>Your tasks for today:</P>
<L>
<LI><LBody><Strong>Turn off the oven.</Strong></LBody>
</LI>
<LI><LBody>Put out the trash.</LBody></LI>
<LI><LBody>Do the laundry.</LBody></LI>
</L>
Link         Grouping, An association between content enclosed by the Link structure element and a
Block or  corresponding link annotation (see 12.5.6.5, "Link annotations").
Inline
Structure   Category   Description
Type
Annot       Grouping, Either an association between the content enclosed by the Annot structure
Block or  element and one or more corresponding PDF annotations (see 12.5,
Inline    "Annotations"), or a mechanism to include one or more PDF annotations in the
structure tree.
If more than one annotation is referenced in an Annot structure element, they
shall be of the same annotation type.
Annot shall not be used for link annotations (see the Link structure element) or
widget annotations (see the Form structure element). All other annotation types
may be referenced by this structure element.
EXAMPLE 6        The following are just a couple of the possible types of content that could
be marked as Annot:
•    Markup annotations indicating change requests like requests for
deletions, modifications or insertions.
•    Highlighting of certain content.
Form        Grouping, Either an association between content enclosed by the Form structure element and
Block or  a corresponding widget annotation or a mechanism to include a widget annotation
Inline    in the structure tree.
In a tagged PDF, Form shall be used for each PDF widget annotation that belongs
to the real content of the document.
NOTE             Form structure elements often include Lbl structure elements to mark up
a form field’s label (if any).
EXAMPLE 7        The following are the possible types of content that could be marked as
Form:
•    Form fields in a PDF containing a fillable form would be marked as
Form structure element.
•    Non-interactive forms, that is, content enclosed in a structure element
with the PrintField attribute, would be marked with Form structure
elements.
NOTE 1       (2020) This document redefined available categories for Link and Annot structure elements
types.
Tagged PDF link elements (standard structure type Link) use PDF’s logical structure facilities to
establish the association between content items and link annotations, providing functionality
comparable to HTML hypertext links. The following items may be children of a link element:
•     One or more content items or other ILSEs (except other links) if A, Dest and PA keys of all of them
have identical values
•     One object reference (see 14.7.5.3, "PDF objects as content items") to one link annotation
associated with the content
NOTE 2       An SD entry in the GoTo or GoToR action in a Link annotation facilitates linking directly to a
target structure element as opposed to just targeting an area on a page.

#### 1.23: 14.8.4.7.3        Ruby and warichu elements
Ruby text is a side note, written in a smaller text size and placed adjacent to the base text to which it
refers. It is used in Japanese and Chinese to describe the pronunciation of unusual words or to describe
such items as abbreviations and logos.
Warichu text is a comment or annotation, written in a smaller text size and formatted onto two smaller
lines within the height of the containing text line and placed following (inline) the base text to which it
refers. It is used in Japanese for descriptive comments and for ruby annotation text that is too long to
be aesthetically formatted as a ruby.
"Table 369 — Ruby and Warichu structure types" defines standard structure types for Ruby and
warichu text.
Table 369 — Ruby and Warichu structure types
Structure        Category       Description
Type
Ruby             Inline         Structure element that wraps around an entire ruby assembly.
It shall contain one RB element followed by either an RT element or a
three-element sequence consisting of RP, RT, and RP.
Ruby structure elements and their content elements shall not break
across multiple lines.
RB               Inline         (Ruby base text) The full-size text to which the ruby annotation is applied.
RB may contain text, other inline elements, or a mixture of both.
It may have the RubyAlign attribute.
RT               Inline         (Ruby annotation text) The smaller-size text that shall be placed adjacent
to the ruby base text. It may contain text, other inline elements, or a
mixture of both. It may have the RubyAlign and RubyPosition attributes.
RP               Inline         (Ruby punctuation) Punctuation surrounding the ruby annotation text. It
is used only when a ruby annotation cannot be properly formatted in a
ruby style and instead is formatted as a normal comment, or when it is
formatted as a warichu. It contains text (usually a single LEFT
PARENTHESIS or RIGHT PARENTHESIS or similar bracketing character).
Warichu          Inline         (Warichu) The wrapper around the entire warichu assembly. It shall
contain a three-element sequence consisting of WP, WT, and WP.
Warichu structure elements (and their child structure elements) may
wrap across multiple lines, according to the warichu breaking rules
described in the Japanese Industrial Standard (JIS) X 4051-2004.
WT               Inline         (Warichu text) The smaller-size text of a warichu comment that is
formatted into two lines and placed between surrounding WP elements.
WP               Inline         (Warichu punctuation) The punctuation that surrounds the content in the
WT structure element. It typically contains text (usually a single LEFT
PARENTHESIS or RIGHT PARENTHESIS or similar bracketing character).
According to JIS X 4051-2004, the parentheses surrounding a warichu
may be converted to a SPACE (nominally 1/4 EM in width) at the
discretion of the formatter.

#### 1.24: 14.8.4.8.1        General
There are a number of other structure types that have a distinct internal structure on their own, or that
may be used as grouping level structure elements, as block level structure elements or as inline level
structure elements, depending on the context in which they are used.

#### 1.25: 14.8.4.8.2        Standard structure types for lists
This clause describes structure types for organising the content of lists. H.8.3, "Hierarchical lists"
provides an example of hierarchical list entries. "Table 370 — List standard structure types" defines
standard structure types for lists.
Table 370 — List standard structure types
Structure    Category           Description
Type
L            Block or Inline    (List) Encloses content consisting of a sequence of items that are
semantically related with each other.
If a Caption is present, it shall be either the first or last child in the L
(list) structure element.
The ListNumbering attribute (see 14.8.5.5, "List attribute") may be
used to indicate the type of ordered or unordered list.
The ContinuedList and ContinuedFrom attributes (see 14.8.5.5,
"List attributes") may be used to indicate relationships with other L
(list) structure elements.
EXAMPLE 1         Bulleted lists, numbered lists, tables of contents, indexes,
dictionaries, and lists of key value pairs are all examples of
content that would use the L structure element.
LI           Internal to L      (List Item) Encloses content for an individual member of a list.
(List) structure   Children (see Annex L, "Parent-child relationships between the
elements           standard structure elements in the standard structure namespace for
PDF 2.0") of the list item may occur in any order or combination.
NOTE              LI structure elements often include Lbl structure elements
(see Table 368 — General inline level structure types) to
mark up a list item's label (if any).
LBody        Internal to LI     (List Item Body) Encloses the actual content of a list item.
(List item)
structure          EXAMPLE 2         In a dictionary list the list item body contains the
elements                             translation or definition of the term.
To represent hierarchical lists, the child L (list) structure elements shall be a direct child of its parent L
(list) structure element or contained within a Div structure element belonging to the parent L (list).

NOTE         Lists can occur within the content of an LBody structure element. Such lists are not considered
part of the hierarchy.

#### 1.26: 14.8.4.8.3        Table structure types
"Table 371 — Table standard structure types" defines standard structure types for tables.
Table 371 — Table standard structure types
Structure       Category        Description
Type
Table           Block           A two-dimensional logical structure of cells, possibly including a complex
substructure.
If a Caption is present, it shall be either the first or last child of the Table
structure element.
TR              Internal to a A row of table header cells (TH) or table data cells (TD) in a table.
Table
structure
TH              Internal to a A table header cell containing content describing one or more rows,
Table         columns or rows and columns of the table.
structure     The following attributes can be used with the TH structure element:
•    RowSpan
•    ColSpan
•    Headers
•    Scope
•    Short
TD              Internal to a A table cell containing content that is part of the table’s content.
Table         The following attributes can be used with the TD structure element:
structure
•    RowSpan
•    ColSpan
•    Headers
THead           Internal to a (Optional) A group of TR structure elements that constitute the header of
Table         a table.
structure     The THead structure element is optional insofar as when rows of header
cells are present they may, but are not required to be, so enclosed.
TBody           Internal to a (Optional) A group of TR structure elements that constitute the main body
Table         portion of a table.
structure     The TBody structure element is optional insofar as when rows of cells are
present they may, but are not required to be, so enclosed.
TFoot           Internal to a (Optional) A group of TR structure elements that constitute the footer of a
Table         table.
structure     The TFoot structure element is optional insofar as when rows of cells
belonging to footer row(s) are present they may, but are not required to
be, so enclosed.
If the Headers attribute (see 14.8.5, "Standard structure attributes") is not specified, any cell in a table
may have multiple headers associated with it. These headers are defined either explicitly by the
Headers attribute, or implicitly, by the following algorithm:
To find headers for any data or header cell, begin from the current cell position and use the current
value of WritingMode to search towards the first cell in the appropriate horizontal/vertical direction.
The search terminates when any of these conditions is reached:
•    the edge of the table is reached
•    a data cell is found after a header cell
•    a header cell has the Headers attribute set — the headers that are specified are appended to the
row/ column list that is being built
When a header cell is found in the search and the (implicit or explicit) Scope attribute of the header
cell is either Both or Row/Column, the header cell is appended to the end of the list of row/column
headers, resulting in a list of headers ordered from most specific to most general.
NOTE       This algorithm works for languages with different intrinsic directionality of the script (such as
right-to-left) because the structure always reflects the logical content order of the table.

#### 1.27: 14.8.4.8.4        Caption structure type
The standard structure type Caption, defined in "Table 372 — Standard structure type Caption",
encloses content that serves as a caption for tables, lists, images, formulas, media objects or other types
of content.
Table 372 — Standard structure type Caption
Structure    Category       Description
Type
Caption      Grouping or    For lists and tables a Caption structure element may be used as defined
Block          for the L (list) and Table structure elements. In addition a Caption may
be used for a structure element or several structure elements.
A structure element is understood to be "captioned" when a Caption
structure element exists as an immediate child of that structure element.
The Caption shall be the first or the last structure element inside its
parent structure element. The number of captions cannot exceed 1.
While captions are often used with figures or formulas, they may be
associated with any type of content.
NOTE    In principle, captions can appear in a nested fashion. For example,
several smaller images belonging to a group of images can each be
accompanied by a caption, and the group of these images as a whole is
accompanied by a caption as well.
EXAMPLE           The following are just a few of the possible types of content
that could be marked as Caption:
•    Caption for an image, list, table, or formula
•    Caption for a group of images or a sequence of graphics
•    Group of images with a caption, plus a caption for each of
the images inside the group of images

#### 1.28: 14.8.4.8.5        Figure structure type
"Table 373 — Standard structure type Figure" defines the Figure standard structure type.
The standard structure type Figure encloses content that represents one or more complete graphics
objects. It shall not appear between the BT and ET operators delimiting a text object (see 9.4, "Text
objects").
A Figure element may have logical substructure, including other Figure elements. For repurposing
purposes it may be treated as visually static, without examining its internal contents. It should have a
BBox attribute (see 14.8.5, "Standard structure attributes").
For repurposing and accessibility purposes, a Figure element should have either an Alt entry or an
ActualText entry in its structure element dictionary (see 14.9.3, "Alternate descriptions" and 14.9.4,
"Replacement text").
NOTE        Alt is a description of the graphics objects enclosed by the Figure element, whereas ActualText
gives the exact text equivalent of a graphical illustration that has the appearance of text.
Table 373 — Standard structure type Figure
Structure       Category         Description
Type
Figure          Grouping,        Encloses graphical content.
Block or         The BBox attribute (see 14.8.5, "Standard structure attributes") should
Inline           be present for a figure appearing in its entirety on a single page to
indicate the area of the figure on the page.
EXAMPLE 1          Some examples of content that would be marked as Figure
include:
•   an image
•   a drawing
•   a chart, including the text that denotes values on each axis

#### 1.29: 14.8.4.8.6        Formula structure type
"Table 374 — Standard structure type Formula" defines the Formula standard structure type.
The standard structure type Formula shall not appear between the BT and ET operators delimiting a
text object (see 9.4, "Text objects").
A Formula element may have logical substructure, including other Formula elements. For
repurposing purposes it may be treated as visually static, without examining its internal contents. It
should have a BBox attribute (see 14.8.5, "Standard structure attributes").
For repurposing and accessibility purposes, a Formula element should have either an Alt entry or an
ActualText entry in its structure element dictionary (see 14.9.3, "Alternate descriptions" and 14.9.4,
"Replacement text").
NOTE        Alt is a description of the content enclosed by the Formula element, whereas ActualText gives
the exact text equivalent of a formula has the appearance of text.
Table 374 — Standard structure type Formula
Structure     Category       Description
Type
Formula       Grouping,      Encloses a formula.
Block or       The BBox attribute ("see 14.8.5, "Standard structure attributes") should
Inline         be present for a formula appearing in its entirety on a single page to
indicate the area of the formula on the page.
EXAMPLE           Some examples of content that would be marked as Formula
include:
•    a mathematical equation or a part thereof
•    a chemical formula
•    a mathematical proof

#### 1.30: 14.8.4.8.7        Artifact structure type
"Table 375 — standard structure type Artifact" defines the Artifact standard structure type.
Table 375 — standard structure type Artifact
Structure    Category        Description
Type
Artifact     Grouping,       (PDF 2.0) Encloses content for which semantics require a reference in the
Block or        structure tree even when such content is not part of the document’s real
Inline          content.
The Artifact structure type may be used to enclose content that would not
otherwise be tagged based on the rules of tagged PDF.
A processor of tagged PDF should normally ignore any content items and
structure elements that are direct or indirect descendants of an Artifact
structure element.
EXAMPLE           Some documents include pages with line numbers. Whereas for
tagged PDF such line numbers would typically be considered
artifacts, the Artifact structure element allows authors to
ensure context is maintained by making it possible to place the
line numbers in the logical structure without forcing end users
to consume them as part of the logical content order.

#### 1.31: 14.8.5.1          General
In addition to the standard structure types, PDF defines standard structure attributes for standard
structure elements in addition to those attributes in a structure element dictionary that are already
defined in "Table 355 — Entries in a structure element dictionary".
The example in 14.7.7, "Example of logical structure" illustrates the use of standard structure
attributes.
As discussed in 14.7.6, "Structure attributes" attributes shall be defined in attribute objects, which are
dictionaries or streams attached to a structure element in either of two ways:
The A entry in the structure element dictionary identifies an attribute object or an array of such
objects.
The C entry in the structure element dictionary gives the name of an attribute class or an array of such
names. The class name is in turn looked up in the class map, a dictionary identified by the ClassMap
entry in the structure tree root, yielding an attribute object or array of objects corresponding to the
class.
In addition to the standard structure attributes described in 14.8.5.2, "Standard Attribute Owners"
there are several other optional entries – Lang, Alt, ActualText, and E – that are described in 14.9,
"Repurposing and accessibility support" but are useful to other PDF consumers as well. They appear in
the following places in a PDF file (rather than in attribute dictionaries):
•    As entries in the structure element dictionary (see "Table 355 — Entries in a structure element
dictionary");
•    As entries in property lists attached to marked-content sequences with the tag Span (see 14.6,
"Marked content").

#### 1.32: 14.8.5.2          Standard attribute owners
Each attribute object has an owner, specified by the object’s O entry, or, if the value of O is NSO, by the
object’s NS entry, which determines the interpretation of the attributes defined in the object’s
dictionary. Multiple owners may define like-named attributes with different value types or
interpretations. Tagged PDF defines a set of standard attribute owners as shown in "Table 376 —
Standard structure attribute owners".
Table 376 — Standard structure attribute owners
Owner value for         Description
the attribute
object’s O entry
Layout                  Attributes governing the layout of content
List                    Attributes governing the numbering of lists
PrintField              Attributes governing Form structure elements for non-interactive form fields
Owner value for        Description
the attribute
object’s O entry
Table                  Attributes governing the organisation of cells in tables
Artifact               Attributes governing Artifact structure elements
XML-1.00               Additional attributes governing translation to XML, version 1.00
HTML-3.20              Additional attributes governing translation to HTML, version 3.20
HTML-4.01              Additional attributes governing translation to HTML, version 4.0
HTML-5.00              Additional attributes governing translation to HTML, version 5.0
OEB-1.00               Additional attributes governing translation to OEB (Open eBook), version 1.0
RTF-1.05               Additional attributes governing translation to Microsoft Rich Text Format, version 1.05
CSS-1                  Additional attributes governing translation to a format using CSS, version 1
CSS-2                  Additional attributes governing translation to a format using CSS, version 2.1
CSS-3                  Additional attributes governing translation to a format using CSS, version 3
RDFa-1.10              Additional attributes governing translation to a format using RDFa version 1.1
ARIA-1.1               Additional attributes governing translation to a format using WAI-ARIA version 1.1
NOTE         (2020) The three owner values for CSS were changed in the above table to better reflect CSS
numbering.
An attribute object owned by a specific export format, such as XML-1.00, shall be applied only when
processing PDF content based on that format. Such format-specific attributes shall override any
corresponding attributes owned by Layout, List, PrintField, Table or Artifact. There may also be
additional format-specific attributes; the set of possible attributes is open-ended and is not explicitly
specified or limited by tagged PDF.

#### 1.33: 14.8.5.3          Attribute values and inheritance
Some attributes are defined as inheritable. Inheritable attributes propagate down the structure tree;
that is, an attribute that is specified for an element shall apply to all the descendants of the element in
the structure tree unless a descendent element specifies an explicit value for the attribute.
NOTE 1       The description of each of the standard attributes in this subclause specifies whether their
values are inheritable.
An inheritable attribute may be specified for an element for the purpose of propagating its value to
child elements, even if the attribute is not meaningful for the parent element. Non-inheritable
attributes may be specified only for elements on which they would be meaningful.
The following list shows the priority for determining attribute values. A PDF processor determines an
attribute’s value to be the first item in the following list that applies:

•    The value of the attribute specified in the element’s A entry, owned by an owner as specified by
the O entry, or, if the value of the O entry is NSO, the NS entry, excluding Layout, PrintField,
Table, List and Artifact, if present, and if processing based on the format indicated by the owner
value
•    The value of the attribute specified in the element’s A entry, owned by Layout, PrintField, Table,
List or Artifact, if present
•    The value of the attribute specified in a class map associated with the element’s C entry, if there is
one
•    The resolved value of the parent structure element, if the attribute is inheritable
•    The default value for the attribute, if there is one
NOTE 2      The properties Lang, Alt, ActualText, and E do not appear in attribute dictionaries. The rules
governing their application are discussed in 14.9, "Repurposing and accessibility support".
There is no semantic distinction between attributes that are specified explicitly and ones that are
inherited. Logically, the structure tree has attributes fully bound to each element, even though some
may be inherited from an ancestor element. This is consistent with the behaviour of properties (such
as font characteristics) that are not specified by structure attributes but shall be derived from the
content.

#### 1.34: 14.8.5.4.1        General
Layout attributes specify parameters of the layout process used to produce the appearance described
by a document’s PDF content. Attributes in this category shall be defined in attribute objects whose O
(owner) entry has the value Layout or whose owner is any other owner excluding List, Table,
PrintField and Artifact.
NOTE 1      The intent is that these parameters can be used to repurpose the content or export it to some
other document format with at least basic styling preserved.
"Table 377 — Standard layout attributes" summarizes the standard layout attributes and the structure
elements to which they apply.
As described in 14.8.5.3, "Attribute Values and Inheritance" an inheritable attribute may be specified
for any element to propagate it to descendants, regardless of whether it is meaningful for that element.
Table 377 — Standard layout attributes                     Goto errata
Structure Elements                         Attributes                       Inheritable
Any structure element                      Placement                        No
WritingMode                      Yes
BackgroundColor                  No
BorderColor                      Yes
BorderStyle                      No
Structure Elements                 Attributes                       Inheritable
BorderThickness                  Yes
Color                            Yes
Padding                          No
Any BLSE;                          SpaceBefore                      No
ILSEs with Placement other than
Inline                             SpaceAfter                       No
StartIndent                      Yes
EndIndent                        Yes
BLSEs containing text              TextIndent                       Yes
TextAlign                        Yes
Figure, Form, Formula and Table    BBox                             No
elements
Width                            No
Height                           No
TH (Table header); TD (Table       Width                            No
data)
Height                           No
BlockAlign                       Yes
InlineAlign                      Yes
TBorderStyle                     Yes
TPadding                         Yes
Any ILSE;                          LineHeight                       Yes
BLSEs containing ILSEs or
containing direct or nested        BaselineShift                    No
content items
TextDecorationType               Yes, only for directly nested ILSEs
TextPosition                     Yes
TextDecorationColor              Yes
TextDecorationThickness          Yes
Grouping elements                  ColumnCount                      No
ColumnWidths                     No
ColumnGap                        No
Vertical text                      GlyphOrientationVertical         Yes

Structure Elements                         Attributes                       Inheritable
Ruby text                                  RubyAlign                        Yes
RubyPosition                     Yes
NOTE 2      TextPosition was corrected in the above table (2020).

#### 1.35: 14.8.5.4.2        General layout attributes
The layout attributes described in "Table 378 — Standard layout attributes common to all standard
structure types" may apply to structure elements of any of the standard at the block level (BLSEs) or
the inline level (ILSEs).
Table 378 — Standard layout attributes common to all standard structure types
Key                Type     Value
Placement          name     (Optional; not inheritable) The positioning of the element with respect
to the enclosing reference area and other content. The value shall be
one of the following:
Block Stacked in the block-progression direction within an enclosing
reference area or parent BLSE.
Inline Packed in the inline-progression direction within an enclosing
BLSE.
Before Placed so that the before edge of the element’s allocation
rectangle (see 14.8.5.4.5, "Content and Allocation Rectangles")
coincides with that of the nearest enclosing reference area.
The element may float, if necessary, to achieve the specified
placement. The element shall be treated as a block occupying
the full extent of the enclosing reference area in the inline
direction. Other content shall be stacked so as to begin at the
after edge of the element’s allocation rectangle.
Start     Placed so that the start edge of the element’s allocation
rectangle (see 14.8.5.4.5, "Content and Allocation Rectangles")
coincides with that of the nearest enclosing reference area.
The element may float, if necessary, to achieve the specified
placement. Other content that would intrude into the
element’s allocation rectangle shall be laid out as a runaround.
End       Placed so that the end edge of the element’s allocation
rectangle (see 14.8.5.4.5, "Content and Allocation Rectangles")
coincides with that of the nearest enclosing reference area.
The element may float, if necessary, to achieve the specified
placement. Other content that would intrude into the
element’s allocation rectangle shall be laid out as a runaround.
When applied to an ILSE, any value except Inline shall cause the
element to be treated as a BLSE instead.
Default value: Block for BLSEs, Inline for ILSEs.
Elements with Placement values of Before, Start, or End shall be
removed from the normal stacking or packing process and allowed to
float to the specified edge of the enclosing reference area or parent
BLSE. Multiple such floating elements may be positioned adjacent to
one another against the specified edge of the reference area or placed
serially against the edge, in the order encountered. Complex cases such
as floating elements that interfere with each other or do not fit on the
same page may be handled differently by different PDF processors.
Tagged PDF merely identifies the elements as floating and indicates
their desired placement.

Key                    Type         Value
WritingMode            name         (Optional; inheritable) Indicates the directions of layout progression
inside Block Level Structure Elements (BLSEs) (inline progression)
and regarding the sequence of BLSEs (block progression).
WritingMode may be used as an attribute for any structure element.
The value shall be one of the following:
LrTb     Inline progression from left to right; block progression from
top to bottom. This is the typical writing mode for Western
writing systems.
RlTb     Inline progression from right to left; block progression from
top to bottom. This is the typical writing mode for Arabic and
Hebrew writing systems.
TbRl     Inline progression from top to bottom; block progression from
right to left. This is the typical writing mode for Chinese and
Japanese writing systems.
TbLr     Inline progression from top to bottom; block progression from
left to right. This is the typical writing mode for writing
systems like classical Mongolian.
LrBt     Inline progression from left to right; block progression from
bottom to top. There is currently no known writing system to
which this writing mode applies.
RlBt     Inline progression from right to left; block progression from
bottom to top. There is currently no known writing system to
which this writing mode applies.
BtRl     Inline progression from bottom to top; block progression from
right to left. This is the typical writing mode for the Ancient
Berber writing system.
BtLr     Inline progression from bottom to top; block progression from
left to right. This is the typical writing mode for the Batak
writing system.
The specified layout directions shall apply to the given structure
element and all of its descendants.
Default value: LrTb.
For elements that are represented in multiple columns, the writing
mode defines the direction of column progression within the reference
area: the inline direction determines the stacking direction for columns
and the default flow order of text from column to column.
For tables, the writing mode controls the layout of rows and columns:
table rows (structure type TR) shall be stacked in the block direction,
cells within a row (structure types TH and TD) in the inline direction.
The inline-progression direction specified by the writing mode is
subject to local override within the text being laid out, as described in
Unicode Standard Annex #9, Unicode Bidirectional Algorithm, available
from the Unicode Consortium.
BackgroundColor array               (Optional; not inheritable; PDF 1.5) The colour to be used to fill the
background of a table cell or any element’s content rectangle (possibly
adjusted by the Padding attribute). The value shall be an array of three
numbers in the range 0.0 to 1.0, representing the red, green, and blue
values, respectively, of an RGB colour space. If this attribute is not
specified, the element shall be treated as if its background were
transparent.
Key           Type      Value
BorderColor   array     (Optional; inheritable; PDF 1.5) The colour of the border drawn on the
edges of a table cell or any element’s content rectangle (possibly
adjusted by the Padding attribute). The value of each edge shall be an
array of three numbers in the range 0.0 to 1.0, representing the red,
green, and blue values, respectively, of an RGB colour space. There are
two forms:
•      A single array of three numbers representing the RGB values to apply to
all four edges.
•      An array of four arrays, each specifying the RGB values for one edge of
the border, in the order of the before, after, start, and end edges. A value
of null for any of the edges means that it shall not be drawn.
If this attribute is not specified, the border colour for this element shall
be the current text fill colour in effect at the start of its associated
content.
BorderStyle   name or   (Optional; not inheritable; PDF 1.5) The style of an element’s border.
array     Specifies the stroke pattern of each edge of a table cell or any element’s
content rectangle (possibly adjusted by the Padding attribute). There
are two forms:
•      An array of four entries, each entry specifying the style for one edge of
the border in the order of the before, after, start, and end edges. A value
of null for any of the edges means that it shall not be drawn.
•      A name from the list below representing the border style to apply to all
four edges.
Valid values are:
None No border. Forces the computed value of BorderThickness to
be 0.
Hidden Same as None, except in terms of border conflict resolution for
table elements.
Dotted The border is a series of dots.
Dashed The border is a series of short line segments.
Solid    The border is a single line segment.
Double The border is two solid lines. The sum of the two lines and the
space between them equals the value of BorderThickness.
Groove The border looks as though it were carved into the canvas.
Ridge The border looks as though it were coming out of the canvas
(the opposite of Groove).
Inset    The border makes the entire box look as though it were
embedded in the canvas.
Outset The border makes the entire box look as though it were
coming out of the canvas (the opposite of Inset).
Default value: None
All borders shall be drawn on top of the box’s background. The colour
of borders drawn for values of Groove, Ridge, Inset, and Outset shall
depend on the structure element’s BorderColor attribute and the
colour of the background over which the border is being drawn.
NOTE Conforming HTML applications may interpret Dotted, Dashed,
Double, Groove, Ridge, Inset, and Outset to be Solid.

Key                    Type         Value
BorderThickness        number       (Optional; inheritable; PDF 1.5) The thickness of the border drawn on
or array     the edges of a table cell or any element’s content rectangle (possibly
adjusted by the Padding attribute). The value of each edge shall be a
positive number in default user space units representing the border’s
thickness (a value of 0 indicates that the border shall not be drawn).
There are two forms:
•    A number representing the border thickness for all four edges.
•    An array of four entries, each entry specifying the thickness for one edge
of the border, in the order of the before, after, start, and end edges. A
value of null for any of the edges means that it shall not be drawn.
Default value: 0.
Padding                number       (Optional; not inheritable; PDF 1.5) Specifies an offset to account for the
or array     separation between the element’s content rectangle and the
surrounding border (see 14.8.5.4.5, "Content and Allocation
Rectangles"). A positive value enlarges the background area; a negative
value trims it, possibly allowing the border to overlap the element’s
text or graphic.
There are two forms:
•    A number representing the width of the padding for all four edges.
•    An array of four entries, each entry specifying the width of the padding
for one edge, in the order of the before, after, start and end edges.
Default value: 0.
Color                  array        (Optional; inheritable; PDF 1.5) The colour to be used for drawing text
and the default value for the colour of table borders and text
decorations. The value shall be an array of three numbers in the range
0.0 to 1.0, representing the red, green, and blue values, respectively, of
an RGB colour space. If this attribute is not specified, the border colour
for this element shall be the current text fill colour in effect at the start
of its associated content.

#### 1.36: 14.8.5.4.3        Layout Attributes for BLSEs
"Table 379 — Additional standard layout attributes specific to block-level structure elements"
describes layout attributes that shall apply only to block-level structure elements (BLSEs).
Table 379 — Additional standard layout attributes specific to block-level structure elements
Key           Type     Value
SpaceBefore   number   (Optional; not inheritable) The amount of extra space preceding the before
edge of the BLSE, measured in default user space units in the block-
progression direction. This value shall be added to any adjustments induced
by the LineHeight attributes of ILSEs within the first line of the BLSE (see
14.8.5.4.4, "Layout Attributes for ILSEs"). If the preceding BLSE has a
SpaceAfter attribute, the greater of the two attribute values shall be used.
Default value: 0.
This attribute shall be disregarded for the first BLSE placed in a given
reference area.
SpaceAfter    number   (Optional; not inheritable) The amount of extra space following the after
edge of the BLSE, measured in default user space units in the block-
progression direction. This value shall be added to any adjustments induced
by the LineHeight attributes of ILSEs within the last line of the BLSE (see
14.8.5.4, "Layout Attributes"). If the following BLSE has a SpaceBefore
attribute, the greater of the two attribute values shall be used.
Default value: 0.
This attribute shall be disregarded for the last BLSE placed in a given
reference area.
StartIndent   number   (Optional; inheritable) The distance from the start edge of the reference
area to that of the BLSE, measured in default user space units in the inline-
progression direction. This attribute shall apply only to structure elements
with a Placement attribute of Block or Start (see 14.8.5.4.2, "General
Layout Attributes"). The attribute shall be disregarded for elements with
other Placement values.
Default value: 0.
A negative value for this attribute places the start edge of the BLSE outside
that of the reference area. The results are implementation-dependent and
may not be supported by all conforming products that process tagged PDF
or by particular export formats.
If a structure element with a StartIndent attribute is placed adjacent to a
floating element with a Placement attribute of Start, the actual value used
for the element’s starting indent shall be its own StartIndent attribute or
the inline extent of the adjacent floating element, whichever is greater. This
value may be further adjusted by the element’s TextIndent attribute, if any.
EndIndent     number   (Optional; inheritable) The distance from the end edge of the BLSE to that of
the reference area, measured in default user space units in the inline-
progression direction. This attribute shall apply only to structure elements
with a Placement attribute of Block or End (see 14.8.5.4.2, "General Layout
Attributes"). The attribute shall be disregarded for elements with other
Placement values.
Default value: 0.
A negative value for this attribute places the end edge of the BLSE outside
that of the reference area. The results are implementation-dependent and
may not be supported by all conforming products that process tagged PDF
or by particular export formats.
If a structure element with an EndIndent attribute is placed adjacent to a
floating element with a Placement attribute of End, the actual value used
for the element’s ending indent shall be its own EndIndent attribute or the
inline extent of the adjacent floating element, whichever is greater.

Key               Type        Value
TextIndent        number      (Optional; inheritable; applies only to some BLSEs) The additional distance,
measured in default user space units in the inline-progression direction,
from the start edge of the BLSE, as specified by StartIndent, to that of the
first line of text. A negative value shall indicate a hanging indent.
Default value: 0.
This attribute shall apply only to paragraphlike BLSEs and those of
structure types LI (List item), TH (Table header), and TD (Table data),
provided that they contain content other than nested BLSEs.
TextAlign         name        (Optional; inheritable; applies only to BLSEs containing text) The alignment,
in the inline-progression direction, of text and other content within lines of
the BLSE. Valid values are:
Start    Aligned with the start edge.
Center Centred between the start and end edges.
End      Aligned with the end edge.
Justify Aligned with both the start and end edges, with internal spacing
within each line expanded, if necessary, to achieve such alignment.
The last (or only) line shall be aligned with the start edge only.
Default value: Start.
BBox              rectangle (Optional; not inheritable) An array of four numbers in default user space
units that shall give the coordinates of the left, bottom, right, and top edges,
respectively, of the structure element’s bounding box (the rectangle that
completely encloses its visible content).
The BBox attribute should be present for structure elements whose content
does not lend itself to reflow or any other visual rearrangement of the
content inside it.
NOTE 1 Examples of types of structure elements that do not lend themselves to
reflow include Figure and Formula structure elements.
NOTE 2 The semantics of the visual presentation of charts, illustrations consisting
of more than one graphics object, or formulas can suffer if the objects
inside them are rearranged, as is typical for content reflow.
A structure element with a BBox attribute may contain other structure
elements inside it.
NOTE 3 A formula, for example, can lose its meaning if the parts in the formula are
visually rearranged. At the same time, the parts inside the formula could
be individually tagged, for example with inline level structure elements.
EXAMPLE           Formulas, graphic art, vector drawings, images are types of
structure elements for which a BBox attribute is appropriate.
Key          Type      Value
Width        number    (Optional; not inheritable; illustrations, tables, and table cells only; should be
or name   used for table cells; sometimes required for Figure, Form or Formula
elements with Placement attribute) The width of the element’s content
rectangle (see 14.8.5.4.5, "Content and Allocation Rectangles"), measured in
default user space units in the inline-progression direction. This attribute
shall apply only to elements of structure type Figure, Formula, Table, TH
(Table header), or TD (Table data).
The name Auto in place of a numeric value shall indicate that no specific
width constraint is to be imposed; the element’s width is determined by the
intrinsic width of its content.
Default value: Auto.
Height       number    (Optional; not inheritable; illustrations, tables, table headers, and table cells
or name   only; sometimes required for Figure, Form or Formula elements with
Placement attribute) The height of the element’s content rectangle (see
14.8.5.4.5, "Content and Allocation Rectangles"), measured in default user
space units in the block-progression direction. This attribute shall apply
only to elements of structure type Figure, Formula, Table, TH (Table
header), or TD (Table data).
The name Auto in place of a numeric value shall indicate that no specific
height constraint is to be imposed; the element’s height is determined by
the intrinsic height of its content.
Default value: Auto.
BlockAlign   name      (Optional; inheritable; table cells only) The alignment, in the block-
progression direction, of content within the table cell. Valid values are:
Before Before edge of the first child’s allocation rectangle aligned with that
of the table cell’s content rectangle.
Middle Children centred within the table cell. The distance between the
before edge of the first child’s allocation rectangle and that of the
table cell’s content rectangle shall be the same as the distance
between the after edge of the last child’s allocation rectangle and
that of the table cell’s content rectangle.
After    After edge of the last child’s allocation rectangle aligned with that
of the table cell’s content rectangle.
Justify Children aligned with both the before and after edges of the table
cell’s content rectangle. The first child shall be placed as described
for Before and the last child as described for After, with equal
spacing between the children. If there is only one child, it shall be
aligned with the before edge only, as for Before.
This attribute shall apply only to elements of structure type TH (Table
header) or TD (Table data) and shall control the placement of all BLSEs that
are children of the given element. The table cell’s content rectangle (see
14.8.5.4.5, "Content and Allocation Rectangles") shall become the reference
area for all of its descendants.
Default value: Before.

Key               Type        Value
InlineAlign       name        (Optional; inheritable; table cells only) The alignment, in the inline-
progression direction, of content within the table cell. Valid values are:
Start    Start edge of each child’s allocation rectangle aligned with that of
the table cell’s content rectangle.
Center Each child centred within the table cell. The distance between the
start edges of the child’s allocation rectangle and the table cell’s
content rectangle shall be the same as the distance between their
end edges.
End      End edge of each child’s allocation rectangle aligned with that of
the table cell’s content rectangle.
This attribute shall apply only to elements of structure type TH (Table
header) or TD (Table data) and controls the placement of all ILSEs that are
children of the given element. The table cell’s content rectangle (see
14.8.5.4.5, "Content and Allocation Rectangles") shall become the reference
area for all of its descendants.
Default value: Start.
TBorderStyle name or          (Optional; inheritable; PDF 1.5) The style of the border drawn on each edge
array            of a table cell. Allowed values shall be the same as those specified for
BorderStyle (see "Table 379 — Additional standard layout attributes
specific to block-level structure elements"). If both TBorderStyle and
BorderStyle apply to a given table cell, BorderStyle shall supersede
TBorderStyle.
Default value: None.
TPadding          integer     (Optional; inheritable; PDF 1.5) Specifies an offset to account for the
or array    separation between the table cell’s content rectangle and the surrounding
border (see 14.8.5.4.5, "Content and Allocation Rectangles"). If both
TPadding and Padding apply to a given table cell, Padding shall supersede
TPadding. A positive value shall enlarge the background area; a negative
value shall trim it, and the border may overlap the element’s text or graphic.
The value shall be either a single number representing the width of the
padding, in default user space units, that applies to all four edges of the
table cell, or a 4-entry array representing the padding width for the before
edge, after edge, start edge, and end edge, respectively, of the content
rectangle.
Default value: 0.

#### 1.37: 14.8.5.4.4        Layout Attributes for ILSEs
The attributes described in "Table 380 — Standard layout attributes specific to inline-level structure
elements" apply to inline-level structure elements (ILSEs). They may also be specified for a block-level
element (BLSE) and may apply to any content items that are its immediate children.
Table 380 — Standard layout attributes specific to inline-level structure elements
Key                       Type      Value
BaselineShift             number    (Optional; not inheritable) The distance, in default user space units,
by which the element’s baseline shall be shifted relative to that of its
parent element. The shift direction shall be the opposite of the
block-progression direction specified by the prevailing
WritingMode attribute (see "General Layout Attributes" in 14.8.5.4,
"Layout Attributes"). Thus, positive values shall shift the baseline
toward the before edge and negative values toward the after edge of
the reference area (upward and downward, respectively, in
Western writing systems).
Default value: 0.
The shifted element may be a superscript, a subscript, or an inline
graphic. The shift shall apply to the element, its content, and all of
its descendants. Any further baseline shift applied to a child of this
element shall be measured relative to the shifted baseline of this
(parent) element.
LineHeight                number (Optional; inheritable) The element’s preferred height, measured in
or name default user space units in the block-progression direction. The
height of a line of text is determined by the largest LineHeight
value for any complete or partial ILSE that it contains.
The name Normal or Auto in place of a numeric value shall indicate
that no specific height constraint is to be imposed. The element’s
height shall be set to a reasonable value based on the content’s font
size:
Normal Adjust the line height to include any non-zero value
specified for BaselineShift.
Auto      Adjustment for the value of BaselineShift shall not be
made.
Default value: Normal.
The meaning of the term "reasonable value" is left to the PDF
processor to determine. It should be approximately 1.2 times the
font size, but this value may vary depending on the export format.
This attribute applies to all ILSEs (including implicit ones) that are
children of this element or of its nested ILSEs, if any. It shall not
apply to nested BLSEs.
When translating to a specific export format, the values Normal and
Auto, if specified, shall be used directly if they are available in the
target format.
NOTE 1 In the absence of a numeric value for LineHeight or an explicit
value for the font size, a reasonable method of calculating the line
height from the information in a tagged PDF file is to find the
difference between the associated font’s Ascent and Descent
values (see 9.8, "Font descriptors"), map it from glyph space to
default user space (see 9.4.4, "Text space details"), and use the
maximum resulting value for any character in the line.

Key                              Type        Value
TextPosition                     name        (Optional; inheritable; PDF 2.0) The position of the element relative
the immediately surrounding content. Valid values are:
Sup      Position is elevated, like for superscript.
Sub      Position is lowered, like for subscript
Normal Position is neither elevated nor lowered.
Default value: Normal
TextPosition does not imply any specific semantic.
NOTE 2 As a consequence, it cannot be determined whether text with a
TextPosition attribute of Sup is a footnote number, an exponent,
an index or some other use of the text. For mathematical
expressions, MathML structure elements provide a richer
semantic for superscripted or subscripted content.
TextDecorationColor              array       (Optional; inheritable; PDF 1.5) The colour to be used for drawing
text decorations. The value shall be an array of three numbers in the
range 0.0 to 1.0, representing the red, green, and blue values,
respectively, of an RGB colour space. If this attribute is not specified,
the text decoration colour for this element shall be the current fill
colour in effect at the start of its associated content.
TextDecorationThickness number               (Optional; inheritable; PDF 1.5) The thickness of each line drawn as
part of the text decoration. The value shall be a non-negative
number in default user space units representing the thickness (0 is
interpreted as the thinnest possible line). If this attribute is not
specified, it shall be derived from the current stroke thickness in
effect at the start of the element’s associated content, transformed
into default user space units.
TextDecorationType               name        (Optional; inheritable only for directly nested ILSEs) The text
decoration, if any, to be applied to the element’s text. Valid values
are:
None                No text decoration
Underline           A line below the text
Overline            A line above the text
LineThrough       A line through the middle of the text
Default value: None.
This attribute shall apply to all text content items that are children
of this element or of its nested ILSEs, if any. The attribute shall not
apply to nested BLSEs or to content items other than text.
The colour, position, and thickness of the decoration shall be
uniform across all children, regardless of changes in colour, font
size, or other variations in the content’s text characteristics.
Key                  Type      Value
RubyAlign            name      (Optional; inheritable; PDF 1.5) The justification of the lines within a
ruby assembly. Valid values are:
Start          The content shall be aligned on the start edge in the
inline-progression direction.
Center         The content shall be centred in the inline-progression
direction.
End            The content shall be aligned on the end edge in the
inline-progression direction.
Justify        The content shall be expanded to fill the available
width in the inline-progression direction.
Distribute     The content shall be expanded to fill the available
width in the inline-progression direction. However,
space shall also be inserted at the start edge and end
edge of the text. The spacing shall be distributed using
a 1:2:1 (start:infix:end) ratio. It shall be changed to a
0:1:1 ratio if the ruby appears at the start of a text line
or to a 1:1:0 ratio if the ruby appears at the end of the
text line.
Default value: Distribute.
This attribute may be specified on the RB and RT elements. When a
ruby is formatted, the attribute shall be applied to the shorter line of
these two elements. For example, if the RT element has a shorter
width than the RB element, the RT element shall be aligned as
specified in its RubyAlign attribute.
RubyPosition         name      (Optional; inheritable; PDF 1.5) The placement of the RT structure
element relative to the RB element in a ruby assembly. Valid values
are:
Before The RT content shall be aligned along the before edge of the
element.
After    The RT content shall be aligned along the after edge of the
element.
WarichuThe RT and associated RP elements shall be formatted as a
warichu, following the RB element.
Inline The RT and associated RP elements shall be formatted as a
parenthesis comment, following the RB element.
Default value: Before.

Key                         Type       Value
GlyphOrientationVertical number (Optional; inheritable; PDF 1.5) Specifies the orientation of glyphs
or name when the inline-progression direction is top to bottom or bottom to
top. Valid values are:
angle A number representing the clockwise rotation in degrees of
the top of the glyphs relative to the top of the reference
area. Shall be a multiple of 90 degrees between -180 and
+360.
Auto     Specifies a default orientation for text, depending on
whether it is fullwidth (as wide as it is high). Fullwidth
Latin and fullwidth ideographic text (excluding ideographic
punctuation) shall be set with an angle of 0. Ideographic
punctuation and other ideographic characters having
alternate horizontal and vertical forms shall use the vertical
form of the glyph. Non-fullwidth text shall be set with an
angle of 90.
Default value: Auto.
NOTE 3 This attribute is used most commonly to differentiate between
the preferred orientation of alphabetic (non-ideographic) text in
vertically written Japanese documents (Auto or 90) and the
orientation of the ideographic characters and/or alphabetic (non-
ideographic) text in western signage and advertising (90).
This attribute shall affect both the alignment and width of the
glyphs. If a glyph is perpendicular to the vertical baseline, its
horizontal alignment point shall be aligned with the alignment
baseline for the script to which the glyph belongs. The width of the
glyph area shall be determined from the horizontal width font
characteristic for the glyph.

#### 1.38: 14.8.5.4.5        Content and allocation rectangles
As defined in 14.8.3, "Basic Layout Model" an element’s content rectangle is an enclosing rectangle
derived from the shape of the element’s content, which shall define the bounds used for the layout of
any included child elements. The allocation rectangle includes any additional borders or spacing
surrounding the element, affecting how it shall be positioned with respect to adjacent elements and the
enclosing content rectangle or reference area.
The exact definition of the content rectangle shall depend on the element’s structure type:
•     For a table cell (structure type TH or TD), the content rectangle is determined from the bounding
box of all graphics objects in the cell’s content, taking into account any explicit bounding boxes
(such as the BBox entry in a form XObject). This implied size may be explicitly overridden by the
cell’s Width and Height attributes. The cell’s height shall be adjusted to equal the maximum
height of any cell in its row; its width shall be adjusted to the maximum width of any cell in its
column.
•     For any other BLSE other than TH and TD, the height of the content rectangle shall be the sum of
the heights of all BLSEs it contains, plus any additional spacing adjustments between these
elements.
•   For an ILSE that contains text, the height of the content rectangle shall be set by the LineHeight
attribute. The width shall be determined by summing the widths of the contained characters,
adjusted for any indents, letter spacing, word spacing, or line-end conditions.
•    For an ILSE that contains an illustration or table, the content rectangle shall be determined from
the bounding box of all graphics objects in the content, and shall take into account any explicit
bounding boxes (such as the BBox entry in a form XObject). This implied size may be explicitly
overridden by the element’s Width and Height attributes.
•    For an ILSE that contains a mixture of elements, the height of the content rectangle shall be
determined by aligning the child objects relative to one another based on their text baseline (for
text ILSEs) or end edge (for non-text ILSEs), along with any applicable BaselineShift attribute
(for all ILSEs), and finding the extreme top and bottom for all elements.
NOTE         PDF processors can apply this process to all elements within the block or apply it on a line-by-
line basis.
The allocation rectangle shall be derived from the content rectangle in a way that also depends on the
structure type:
•    For a BLSE, the allocation rectangle shall be equal to the content rectangle with its before and
after edges adjusted by the element’s SpaceBefore and SpaceAfter attributes, if any, but with no
changes to the start and end edges.
•    For an ILSE, the allocation rectangle is the same as the content rectangle.

#### 1.39: 14.8.5.4.6        Figure, Form and Formula attributes
Particular uses of Figure, Form or Formula elements shall have additional restrictions:
•    When a Figure, Form or Formula element has a Placement attribute of Block, it shall have a
Height attribute with an explicitly specified numerical value (not Auto). This value shall be the
sole source of information about the element’s extent in the block-progression direction.
•    When a Figure, Form or Formula element has a Placement attribute of Inline, it shall have a
Width attribute with an explicitly specified numerical value (not Auto). This value shall be the
sole source of information about the element’s extent in the inline-progression direction.
•    When a Figure, Form or Formula element has a Placement attribute of Inline, Start, or End, the
value of its BaselineShift attribute shall be used to determine the position of its after edge
relative to the text baseline; BaselineShift shall be ignored for all other values of Placement. (A
Figure, Form or Formula element with a Placement value of Start may be used to create a
dropped capital; one with a Placement value of Inline may be used to create a raised capital.)

#### 1.40: 14.8.5.4.7        Column attributes
The attributes described in "Table 381 — Standard layout attributes specific to standard column
attributes" shall be present for the grouping elements (see 14.8.4.4, "Grouping level structure types") if
the content in the grouping element is divided into columns.
Table 381 — Standard layout attributes specific to standard column attributes
Key                Type            Value
ColumnCount        integer         (Optional; not inheritable; PDF 1.6) The number of columns in the
content of the grouping element.
Default value: 1.

Key                  Type                Value
ColumnGap            number or           (Optional; not inheritable; PDF 1.6) The desired space between
array               adjacent columns, measured in default user space units in the
inline-progression direction. If the value is a number, it specifies
the space between all columns. If the value is an array, it should
contain numbers, the first element specifying the space between
the first and second columns, the second specifying the space
between the second and third columns, and so on. If there are
fewer than ColumnCount - 1 numbers, the last element shall
specify all remaining spaces; if there are more than ColumnCount
- 1 numbers, the excess array elements shall be ignored.
ColumnWidths         number or           (Optional; not inheritable; PDF 1.6) The desired width of the
array               columns, measured in default user space units in the inline-
progression direction. If the value is a number, it specifies the
width of all columns. If the value is an array, it shall contain
numbers, representing the width of each column, in order. If there
are fewer than ColumnCount numbers, the last element shall
specify all remaining widths; if there are more than ColumnCount
numbers, the excess array elements shall be ignored.

#### 1.41: 14.8.5.5          List attributes
If present, the List attributes described in "Table 382 — Standard list attributes" shall appear in an L
(List) element. These attributes control the interpretation of the Lbl (Label) elements (see “Table 368
— General inline level structure types” within the list’s LI (List Item) elements (see 14.8.4.8.2,
"Standard structure types for Lists"). These attributes may only be defined in attribute objects whose O
(owner) entry has the value List or whose owner is any other owner excluding Layout, Table,
PrintField and Artifact.
The ContinuedList and the ContinuedFrom attributes described in "Table 382 — Standard list
attributes" control the interpretation of the L element as it relates to other L elements that are not its
immediate parent.
Table 382 — Standard list attributes
Key                Type      Value
ListNumbering      name      (Optional; inheritable) The numbering system used to generate the content
of the Lbl (Label) elements in a numbered list, or the type of symbol in the
content of the Lbl (Label) elements used to identify list items in an
unnumbered list (see "Table 368 — General inline level structure types").
The value of the ListNumbering shall be one of the following, and shall be
applied as described here.
None              No numbering system; Lbl elements (if present) contain
arbitrary text not subject to any numbering scheme
Unordered         (PDF 2.0) Unordered list with unspecified bullets
Description       (PDF 2.0) A list of terms for corresponding definitions
NOTE    The Description value was added in this document (2020).
Disc              Solid circular bullet
Circle            Open circular bullet
Square            Solid square
Ordered           (PDF 2.0) Ordered lists with unspecified numbering
Decimal           Decimal Arabic numerals (1–9, 10–99, … )
UpperRoman        Uppercase Roman numerals (I, II, III, IV, … )
LowerRoman        Lowercase Roman numerals (i, ii, iii, iv, … )
UpperAlpha        Uppercase letters (A, B, C, .. )
LowerAlpha        Lowercase letters (a, b, c, … )
Default value: None.
A list is an unordered list unless the ListNumbering attribute is present
with one of the following values: Ordered, Decimal, UpperRoman,
LowerRoman, UpperAlpha or LowerAlpha, in which case the list is an
ordered list.
The alphabet used for UpperAlpha and LowerAlpha is determined by the
prevailing Lang entry (see 14.9.2, "Natural language specification").
ContinuedList      boolean   (Optional; PDF 2.0) A flag specifying whether the list is a continuation of a
previous list in the structure tree (true), or not (false). Default value: false.
If the ContinuedFrom attribute is not present, the continuation is from the
preceding list at the same level in the structure hierarchy.
ContinuedFrom ID (byte       (Optional; PDF 2.0) The ID (see “Table 355 — Entries in a structure
string)        element dictionary") of the list for which this list is a continuation.
NOTE       The ListNumbering attribute allows a content extraction tool to autonumber a list. However, the
list’s Lbl structure elements can contain the resulting numbers explicitly, so that the document
can be reused without autonumbering.

#### 1.42: 14.8.5.6       PrintField attributes
The attributes described in the next table define the accessibility mechanism for non-interactive PDF
forms (see 12.7.9, "Non-interactive forms"). Such forms may have originally contained interactive
fields such as text fields and radio buttons but were then converted into non-interactive PDF files, or
they may have been designed to be printed out and filled in manually. Since the form’s fields cannot be
determined from interactive elements, form field roles and values in a non-interactive form field are
defined using a PrintField attribute on respective Form elements (see "Table 383 — PrintField

attributes") enclosing each set of content representing a non-interactive form field. This attribute may
only be defined in attribute objects whose O (owner) entry has the value PrintField or whose owner is
any other owner excluding Layout, List, Table and Artifact.
Table 383 — PrintField attributes
Key              Type           Value
Role             name           (Optional; not inheritable; PDF 1.7) The type of form field represented. The
value of Role shall be one of the following:
rb Radio button
cb    Check box
pb    Push button
tv Text-value field
lb Listbox field
The tv role shall be used for non-interactive fields with textual values. The
text that is the value of the field shall be the content of the Form structure
element (see "Table 368 — General inline level structure types").
NOTE 1 Examples include text edit fields, numeric fields, password fields, digital
signature fields and combo box fields.
Semantic groupings of non-interactive form fields and associated content
(for example, a set of radio button fields associated with a label) should be
enclosed within a Part structure element.
Default value: None specified.
Checked,         name           (Optional; not inheritable; PDF 1.7; lower case form is deprecated in PDF 2.0)
checked                         The state of a radio button or check box field. The value shall be one of: on,
off, or neutral.
NOTE 2 In earlier versions of PDF the case (capitalization) used for this key did
not conform to the same conventions used elsewhere in this standard.
Default value: off.
Desc             text string    (Optional; not inheritable; PDF 1.7) The alternate name of the field.
NOTE 3 Similar to the value supplied in the TU entry of the field dictionary for
interactive fields (see "Table 226 — Entries common to all field
dictionaries").

#### 1.43: 14.8.5.7          Table attributes
The table attributes, as described in "Table 384 — Standard table attributes", may only be defined in
attribute objects whose O (owner) entry has the value Table or whose owner is any other owner
excluding Layout, List, PrintField and Artifact.
Table 384 — Standard table attributes
Key       Type      Value
RowSpan   integer   (Optional; not inheritable) The number of rows in the enclosing table that shall
be spanned by the cell.
The cell shall expand by adding rows in the block-progression direction specified
by the table’s WritingMode attribute.
Default value: 1.
This entry shall only have an effect for structure elements of type of TH or TD.
ColSpan   integer   (Optional; not inheritable) The number of columns in the enclosing table that
shall be spanned by the cell.
The cell shall expand by adding columns in the inline-progression direction
specified by the table’s WritingMode attribute.
Default value: 1.
This entry shall only have an effect for structure elements of type of TH or TD.
Headers   array     (Optional; not inheritable) An array of byte strings, where each string shall be the
element identifier (see the ID entry in "Table 355 — Entries in a structure
element dictionary") for a TH structure element that shall be used as a header
associated with this cell.
This entry shall only have an effect for structure elements of type of TH or TD.
The order in which the entries in the Headers array are listed shall be row IDs
followed by column IDs. The row and column IDs shall be ordered from most
specific to most general.
If the scope for any cells with an ID listed in the Headers attribute of a cell
cannot be determined by the default algorithm defined in 14.8.4.8.3, "Table
structure types", those header cells shall specify a Scope so that the header can
be determined to be either a row header, a column header or both.
This attribute may apply to header cells (TH) as well as data cells (TD).
Therefore, the headers associated with any cell shall be those in its Headers
array plus those in the Headers array of any TH cells in that array, and so on
recursively.
Scope     name      (Optional; not inheritable; PDF 1.5) A name whose value shall be one of the
following: Row, Column, or Both.
This entry shall only have an effect for structure elements of type of TH.
If a Scope is not specified for a TH structure element, then the assumed value for
the Scope shall be determined as follows, taking into account the current value
for WritingMode:
•   if it is in the first row and column, the Scope is assumed to be Both;
•   otherwise, if it is in the first row, the Scope is assumed to be Column.
•   otherwise, if it is in the first column, the Scope is assumed to be Row.
•   otherwise, the Scope is assumed to be Both.
These assumptions are used by the algorithm following "Table 371 — Table
standard structure types" for determining which headers are associated with a
cell.

Key           Type       Value
Summary       text       (Optional; not inheritable; PDF 1.7) A summary of the table’s purpose and
string     structure. This entry shall only be used within Table structure elements (see
Table 371 — Table standard structure types”.
NOTE    For use in non-visual rendering such as speech or braille. The Summary key
was restored in this document (2020).
Short         text       (Optional; not inheritable; PDF 2.0) Contains a short form of the content of a TH
string     structure element’s content.
This entry shall only have an effect for structure elements of type of TH.
EXAMPLE             When accessed by means of a screen reader, for each table cell the
applicable header cells are read to the user in order to allow that user
to understand the content of the table cell. It can become cumbersome
for a user to repeatedly have to listen to the full contents of a TH
structure element. An option to have the short form of the content of
the TH structure element read out aloud is sometimes preferred.

#### 1.44: 14.8.5.8          Artifact attributes
The artifact attributes described in "Table 385 — Standard artifact attributes" may only be defined in
attribute objects whose O (owner) entry has the value Artifact or whose owner is any other owner
excluding Layout, List, PrintField and Table.
Table 385 — Standard artifact attributes
Key             Type            Value
Type            Name            (Optional) The type of artifact that this attribute describes; if present, shall
be one of the names Pagination, Layout, Page or Inline (PDF 2.0).
•    Pagination artifacts are ancillary page features such as running heads or
folios (page numbers)
•    Layout artifacts are purely cosmetic typographical or design elements such as
footnote rules or decorative ornaments
•    Page artifacts are production aids extraneous to the document itself, such as
cut marks and print control patches
•    Inline artifacts enclose artifact content that has context in the document’s
logical structure, typically, artifacts of subtype LineNum or Redaction
NOTE     Inline artifacts can be used to provide context in the logical structure to
any artifact. This is similar to an inline structure element.
BBox            rectangle       (Optional) An array of four numbers in default user space units giving the
coordinates of the left, bottom, right, and top edges, respectively, of
the artifact’s bounding box (the rectangle that completely encloses its
visible extent).
Key          Type        Value
Subtype      Name        (Optional; PDF 1.7) The subtype of the artifact. This entry should appear
only when the Type entry has a value of Pagination or Inline. Valid values
are Header, Footer, Watermark, PageNum (PDF 2.0), Bates (PDF 2.0),
LineNum (PDF 2.0) and Redaction (PDF 2.0). Additional values may be
specified for this entry, provided they comply with the naming conventions
described in Annex E, "Extending PDF".

#### 1.45: 14.8.6.1        Namespaces for standard structure types and attributes
The namespace mechanism defined as part of logical structure (see 14.7.4, "Namespaces") in PDF 2.0
defines a more robust means of interchanging tagsets than was previously possible. The standard
structure types and attributes defined within the previous clauses (see 14.8.4, "Standard structure
types" and 14.8.5, "Standard structure attributes") effectively define a schema for a tagset in PDF. This
schema is called the standard structure namespace for PDF 2.0, which shall be defined by the
namespace name:
"http://iso.org/pdf2/ssn"

and attributes that were defined prior to PDF 2.0 and the rules for processing documents tagged using
them. This schema shall be known as the standard structure namespace for PDF 1.7, and shall be
defined by the namespace name:
"http://iso.org/pdf/ssn"
To facilitate conversion of documents created against versions of the PDF standard earlier than PDF
2.0, the default standard structure namespace shall be "http://iso.org/pdf/ssn". When a namespace is
not explicitly specified for a given structure element or attribute, it shall be assumed to be within this
default standard structure namespace.
NOTE        Annex M, "Differences between the standard structure namespaces" lists the standard structure
types defined in the default (PDF 1.7) namespace.
The term standard structure namespaces refers to either of the two namespaces defined above.

#### 1.46: 14.8.6.2        Role maps and namespaces
Role maps prior to the introduction of namespaces identify a given structure element and map it to
another structure element. This can be applied transitively to allow a structure element to be mapped
through multiple steps to a final structure element. Tagged PDF requires that all structure elements be
role mapped to a standard structure type except where explicitly stated in this subclause.
The introduction of namespaces adds complexity here, since there may be multiple structure element
dictionaries specifying the same structure type name (see "Table 355 — Entries in a structure element
dictionary"), but from a different namespace, which require different mappings. To enable support for
this, a namespace dictionary (see 14.7.4.2, "Namespace dictionary") can define a role map specific to it.

When processing a structure element dictionary within a tagged PDF document, if the structure
element does not explicitly identify its namespace using an NS entry, it should use the RoleMap entry
in the Structure Tree Root dictionary (see "Table 354 — Entries in the structure tree root") to
determine its role mapping, if any. If the structure element is in an explicit namespace, then that
namespace shall be identified in the structure tree root dictionary’s Namespaces array entry and the
RoleMapNS entry within that namespace dictionary shall provide the role mapping, if any.
In a tagged PDF, all structure elements shall be in at least one of the standard structure namespaces or
in a namespace identified in 14.8.6.3, “Other namespaces”. An element shall be considered to be in one
of these namespaces if:
•    they directly identify one of these namespaces through their NS entry;
•    they are in the default standard structure namespace;
•    they are role mapped into the namespace, either directly or transitively.
NOTE 1      This provision facilitates interoperability by allowing a structure element to be in multiple
namespaces, including the standard structure namespace for PDF 1.7 and the standard structure
namespace for PDF 2.0.
NOTE 2      The above paragraph and bullets were rewritten in this document (2020).

#### 1.47: 14.8.6.3          Other namespaces
The standard structure types (see 14.8.4, "Standard structure types") address many of the structural
elements that commonly exist within general documents. However, the ILSEs defined do not provide
sufficient structure to support domain specific languages. An example of such a language is
mathematics, which is common to many classes of documents. This subclause identifies any domain
specific languages that are common within broad ranges of documents types. Namespaces identified in
this subclause do not require a RoleMapNS entry in their respective namespace dictionary.
MathML 3.0 defines a domain specific schema for representing mathematics. The namespace name
(see 14.7.4.2, "Namespace dictionary"), as would be identified by the NS entry in a namespace
dictionary, shall have the value:
“http://www.w3.org/1998/Math/MathML”
NOTE 1      MathML is the only domain-specific namespace defined in PDF 2.0.
When including mathematics structured as MathML 3.0, the math structure element type as defined in
MathML 3.0 shall be used, and shall have its namespace explicitly defined (see 14.7.4.2, "Namespace
dictionary").
NOTE 2      The math structure element type is all lowercase to match the MathML 3.0 specification.
Any other namespaces can be specified within a PDF document, but shall meet the requirements of role
mapping described in 14.8.6.2, "Role maps and namespaces".

#### 1.48: 14.9.1          General
PDF includes several facilities in support of accessibility of documents to users with disabilities. In
particular, many computer users with visual impairments use screen readers to read documents aloud.
To enable proper vocalisation, either through a screen reader or by some more direct invocation of a
text-to-speech engine, PDF supports the following features:
•    Specifying the natural language used for text in a PDF document — for example, as English or
Spanish (see 14.9.2, "Natural language specification")
•    Providing textual descriptions for images or other items that do not translate naturally into text
(14.9.3, "Alternate descriptions"), or replacement text for content that does translate into text but
is represented in a nonstandard way (such as with a ligature or illuminated character; see 14.9.4,
"Replacement text")
•    Specifying the expansion of abbreviations or acronyms (14.9.5, "Expansion of abbreviations and
acronyms")
•    Specifying pronunciation (14.9.6, "Pronunciation hints")

#### 1.49: 14.9.2.1        General
Natural language may be specified for content in a document.
The natural language used for content in a document shall be determined in a hierarchical fashion,
based on whether an optional Lang entry (PDF 1.4) is present in any of several possible locations. At
the highest level, the document’s default language (which applies to both text strings and text within
content streams) may be specified by a Lang entry in the document catalog dictionary (see 7.7.2,
"Document catalog dictionary"). This applies to both content within content streams and any text
strings, including text strings not included in the structure hierarchy such as, for example, entries in
metadata, outline entries and names for optional content groups. Below this, the language may be
specified for the following items:
•    Structure elements of any type (see 14.7.2, "Structure hierarchy"), through a Lang entry in the
structure element dictionary. The language specified by a Lang entry shall apply to any content
within content streams enclosed or referenced by the respective structure elements, to any
ActualText, Alt, or E properties of the respective structure elements.
•    Marked-content sequences that are not in the structure hierarchy (see 14.6, "Marked content"),
through a Lang entry in a property list attached to the marked-content sequence with a Span tag.
NOTE 1     Although Span is also a standard structure type, as described under 14.8.4.7, "Inline level
structure types", a marked-content sequence whose tag is Span is entirely independent of logical
structure.
•    Text strings encoded in Unicode may include an escape sequence using a language tag indicating
the language of the text and overriding the prevailing Lang entry (see 7.9.2.2.2 "Text string
language escape sequences").
NOTE 2     The natural language used for optional content allows content to be hidden or revealed based on
the Lang entry (PDF 1.5) in the Language dictionary of an optional content usage dictionary (see
"Table 100 — Entries in an optional content usage dictionary").

