# SDD Draft

Generated from:
- `spec/extracted/12.1-12.4-interactive-navigation.spec.txt`

## Requirements

### Requirement 1: 12.1 General
This clause describes the PDF features that allow a user to interact with a document on the screen
(with the exception of multimedia features, which are described in 13, "Multimedia features"):
•    Preference settings to control the way the document is presented on the screen (12.2, "Viewer
preferences")
•    Navigation facilities for moving through the document in a variety of ways (subclauses 12.3,
"Document-level navigation" and 12.4, "Page-level navigation")
•    Annotations for adding text notes, links, rich media and other ancillary information to the
document (12.5, "Annotations")
•    Actions that can be triggered by specified events (12.6, "Actions")
•    Interactive forms for gathering information from the user (12.7, "Forms")
•    Digital signatures that authenticate the identity of a user and the validity of the document’s
contents (12.8, "Digital signatures")
•    Measurement properties that enable the display of real-world units corresponding to objects on a
page (12.9, "Measurement properties")
•    A geospatial coordinate system is introduced in subclause 12.10, "Geospatial features" along with a
number of PDF constructs to support geospatially registered content.
•    Subclause 12.11, "Document requirements" describes how a document may specify requirements
that an interactive PDF processor should satisfy in order for the document to function as intended
by the author.

### Requirement 2: 12.2 Viewer preferences
The ViewerPreferences entry in a document’s catalog dictionary (see 7.7.2, "Document catalog
dictionary") designates a viewer preferences dictionary (PDF 1.2) controlling the way the document
shall be presented on the screen or in print. If no such dictionary is specified, PDF processors should
behave in accordance with their own current user preference settings. "Table 147 — Entries in a
viewer preferences dictionary" shows the contents of the viewer preferences dictionary.
Table 147 — Entries in a viewer preferences dictionary
Key                               Type         Value
HideToolbar                       boolean      (Optional) A flag specifying whether to hide the interactive PDF
processor’s tool bars when the document is active.
Default value: false.
HideMenubar                       boolean      (Optional) A flag specifying whether to hide the interactive PDF
processor’s menu bar when the document is active.
Default value: false.
Key                     Type       Value
HideWindowUI            boolean    (Optional) A flag specifying whether to hide user interface elements
in the document’s window (such as scroll bars and navigation
controls), leaving only the document’s contents displayed. D
efault value: false.
FitWindow               boolean    (Optional) A flag specifying whether to resize the document’s
window to fit the size of the first displayed page. Default value: false.
CenterWindow            boolean    (Optional) A flag specifying whether to position the document’s
window in the centre of the screen. Default value: false.
DisplayDocTitle         boolean    (Optional; PDF 1.4) A flag specifying whether the window’s title bar
should display the document title taken from the dc:title element of
the XMP metadata stream (see 14.3.2, "Metadata streams"). If false,
the title bar should instead display the name of the PDF file
containing the document. Default value: false.
NonFullScreenPageMode   name       (Optional) The document’s page mode, specifying how to display the
document on exiting full-screen mode:
UseNone        Neither document outline nor thumbnail images visible
UseOutlines Document outline visible
UseThumbs Thumbnail images visible
UseOC          Optional content group panel visible
This entry is meaningful only if the value of the PageMode entry in
the catalog dictionary (see 7.7.2, "Document catalog dictionary") is
FullScreen; it shall be ignored otherwise. Default value: UseNone.
Direction               name       (Optional; PDF 1.3) The predominant logical content order for text:
L2R     Left to right
R2L     Right to left (including vertical writing systems, such as
Chinese, Japanese, and Korean)
This entry has no direct effect on the document’s contents or page
numbering but may be used to determine the relative positioning of
pages when displayed side by side or printed n-up. Default value:
L2R.
ViewArea                name       (Optional; PDF 1.4; deprecated in PDF 2.0) The name of the page
boundary representing the area of a page that shall be displayed
when viewing the document on the screen. The value is the key
designating the relevant page boundary in the page object (see
7.7.3, "Page tree" and 14.11.2, "Page boundaries"). If the specified
page boundary is not defined in the page object, its default value
shall be used, as specified in "Table 31 — Entries in a page object".
Default value: CropBox.
This entry is intended primarily for use by prepress applications
that interpret or manipulate the page boundaries as described in
14.11.2, "Page boundaries".
The presence of this value in a PDF may cause a PDF to display
differently from how it will be printed.

Key                               Type         Value
ViewClip                          name         (Optional; PDF 1.4; deprecated in PDF 2.0) The name of the page
boundary to which the contents of a page shall be clipped when
viewing the document on the screen. The value is the key
designating the relevant page boundary in the page object (see
7.7.3, "Page tree" and 14.11.2, "Page boundaries"). If the specified
page boundary is not defined in the page object, its default value
shall be used, as specified in "Table 31 — Entries in a page object".
Default value: CropBox.
This entry is intended primarily for use by prepress applications
that interpret or manipulate the page boundaries as described in
14.11.2, "Page boundaries".
The presence of this value in a PDF may cause a PDF to display
differently from how it will be printed.
PrintArea                         name         (Optional; PDF 1.4; deprecated in PDF 2.0) The name of the page
boundary representing the area of a page that shall be rendered
when printing the document. The value is the key designating the
relevant page boundary in the page object (see 7.7.3, "Page tree"
and 14.11.2, "Page boundaries"). If the specified page boundary is
not defined in the page object, its default value shall be used, as
specified in "Table 31 — Entries in a page object". Default value:
CropBox.
This entry is intended primarily for use by prepress applications
that interpret or manipulate the page boundaries as described in
14.11.2, "Page boundaries".
The presence of this value in a PDF may cause a PDF to display
differently from how it will be printed.
PrintClip                         name         (Optional; PDF 1.4; deprecated in PDF 2.0) The name of the page
boundary to which the contents of a page shall be clipped when
printing the document. The value is the key designating the relevant
page boundary in the page object (see 7.7.3, "Page tree" and 14.11.2,
"Page boundaries"). If the specified page boundary is not defined in
the page object, its default value shall be used, as specified in "Table
31 — Entries in a page object". Default value: CropBox.
This entry is intended primarily for use by prepress applications
that interpret or manipulate the page boundaries as described in
14.11.2, "Page boundaries".
The presence of this value in a PDF may cause a PDF to display
differently from how it will be printed.
PrintScaling                      name         (Optional; PDF 1.6) The page scaling option that shall be selected
when a print dialogue is displayed for this document. Valid values
are None, which indicates no page scaling, and AppDefault, which
indicates the interactive PDF processor’s default print scaling. If this
entry has an unrecognised value, AppDefault shall be used. Default
value: AppDefault.
If the print dialogue is suppressed and its parameters are provided
from some other source, this entry nevertheless shall be honoured.
Key                          Type          Value
Duplex                       name          (Optional; PDF 1.7) The paper handling option that shall be used
when printing the PDF file from the print dialogue. The following
values are valid:
Simplex                 Print single-sided
DuplexFlipShortEdge Duplex and flip on the short edge of the
sheet
DuplexFlipLongEdge Duplex and flip on the long edge of the sheet
Default value: implementation dependent
PickTrayByPDFSize            boolean       (Optional; PDF 1.7) A flag specifying whether the PDF page size shall
be used to select the input paper tray. This setting influences only
the preset values used to populate the print dialogue presented by
an interactive PDF processor. If PickTrayByPDFSize is true, the
check box in the print dialogue associated with input paper tray
shall be checked.
This setting has no effect on operating systems that do not provide
the ability to pick the input tray by size.
Default value: implementation dependent
PrintPageRange               array         (Optional; PDF 1.7) The page numbers used to initialise the print
dialogue box when the PDF file is printed. The array shall contain an
even number of integers to be interpreted in pairs, with each pair
specifying the first and last pages in a sub-range of pages to be
printed. The first page of the PDF file shall be denoted by 1.
Default value: implementation dependent
NOTE     Although PrintPageRange uses 1-based page numbering, other
features of PDF use zero-based page numbering.
NumCopies                    integer       (Optional; PDF 1.7) The number of copies that shall be printed when
the print dialog is opened for this PDF file.
Default value: implementation dependent, but typically 1
Enforce                      array         (Optional; PDF 2.0) An array of names of Viewer preference settings
that shall be enforced by PDF processors and that shall not be
overridden by subsequent selections in the application user
interface. "Table 148 — Names defined for an Enforce array"
specifies names that shall be valid to use in this array.
The Enforce array shall only include names that occur in "Table 148 — Names defined for an Enforce
array". Future additions to this table shall be limited to keys in the viewer preferences dictionary with
the following qualities:
•    can be assigned values (default or specified) that cannot be used in a denial-of-service attack, and
•    have default values that cannot be overridden using the application user interface.

Table 148 — Names defined for an Enforce array
Name              Description
PrintScaling      (Optional; PDF 2.0) This name may appear in the Enforce array only if the corresponding
entry in the viewer preferences dictionary ("Table 147 — Entries in a viewer preferences
dictionary") specifies a valid value other than AppDefault.

#### 2.1: 12.3.1              General
The features described in this subclause allow an interactive PDF processor to present the user with an
interactive, global overview of a document in either of two forms:
•     As a hierarchical outline showing the document’s internal structure
•     As a collection of thumbnail images representing the pages of the document in miniature form
Each item in the outline or each thumbnail image may be associated with a corresponding destination
in the document, so that the user can jump directly to the destination by clicking with the mouse.

#### 2.2: 12.3.2.1            General
A destination defines a particular view of a document, consisting of the following items:
•     The page of the document that shall be displayed
•     The location of the document window on that page
•     The magnification (zoom) factor
Destinations may be associated with outline items (see 12.3.3, "Document outline"), annotations
(12.5.6.5, "Link annotations"), or actions (12.6.4.2, "Go-To actions" and 12.6.4.3, "Remote Go-To
actions"). In each case, the destination specifies the view of the document that shall be presented when
the outline item or annotation is opened or the action is performed. In addition, the optional
OpenAction entry in a document’s catalog dictionary (7.7.2, "Document catalog dictionary") may
specify a destination that shall be displayed when the document is opened. A destination may be
specified either explicitly by an array of parameters defining its properties or indirectly by name.

#### 2.3: 12.3.2.2            Explicit destinations
"Table 149 — Destination syntax" shows the allowed syntactic forms for specifying a destination
explicitly in a PDF file. In each case, page is an indirect reference to a page object (except in a remote
go-to action; see 12.6.4.3, "Remote Go-To actions", or an embedded go-to action; see 12.6.4.4,
"Embedded Go-To actions"). All coordinate values (left, right, top, and bottom) shall be expressed in the
default user space coordinate system. The page’s bounding box is the smallest rectangle enclosing all of
its contents. (If any side of the bounding box lies outside the page’s crop box, the corresponding side of
the crop box shall be used instead; see 14.11.2, "Page boundaries" for further discussion of the crop
box.)
NOTE       The above paragraph was corrected to also include embedded go-to actions (2020).
No page object can be specified for a destination associated with a remote go-to action (see 12.6.4.3,
"Remote Go-To actions") because the destination page is in a different PDF document. In this case, the
page parameter specifies an integer page number within the remote document instead of a page object
in the current document.
Table 149 — Destination syntax
Syntax                              Meaning
[page /XYZ left top zoom]           Display the page designated by page, with the coordinates (left, top)
positioned at the upper-left corner of the window and the contents of the
page magnified by the factor zoom. A null value for any of the parameters
left, top, or zoom specifies that the current value of that parameter shall be
retained unchanged. A zoom value of 0 has the same meaning as a null
value.
[page /Fit]                         Display the page designated by page, with its contents magnified just
enough to fit the entire page within the window both horizontally and
vertically. If the required horizontal and vertical magnification factors are
different, use the smaller of the two, centring the page within the window
in the other dimension.
[page /FitH top]                    Display the page designated by page, with the vertical coordinate top
positioned at the top edge of the window and the contents of the page
magnified just enough to fit the entire width of the page within the
window. A null value for top specifies that the current value of that
parameter shall be retained unchanged.
[page /FitV left]                   Display the page designated by page, with the horizontal coordinate left
positioned at the left edge of the window and the contents of the page
magnified just enough to fit the entire height of the page within the
window. A null value for left specifies that the current value of that
parameter shall be retained unchanged.
[page /FitR left bottom right top] Display the page designated by page, with its contents magnified just
enough to fit the rectangle specified by the coordinates left, bottom, right,
and top entirely within the window both horizontally and vertically. If the
required horizontal and vertical magnification factors are different, use
the smaller of the two, centring the rectangle within the window in the
other dimension.
[page /FitB]                        (PDF 1.1) Display the page designated by page, with its contents magnified
just enough to fit its bounding box entirely within the window both
horizontally and vertically. If the required horizontal and vertical
magnification factors are different, use the smaller of the two, centring the
bounding box within the window in the other dimension.
[page /FitBH top]                   (PDF 1.1) Display the page designated by page, with the vertical
coordinate top positioned at the top edge of the window and the contents
of the page magnified just enough to fit the entire width of its bounding
box within the window. A null value for top specifies that the current
value of that parameter shall be retained unchanged.

Syntax                                 Meaning
[page /FitBV left]                     (PDF 1.1) Display the page designated by page, with the horizontal
coordinate left positioned at the left edge of the window and the contents
of the page magnified just enough to fit the entire height of its bounding
box within the window. A null value for left specifies that the current
value of that parameter shall be retained unchanged.

#### 2.4: 12.3.2.3          Structure destinations
A destination provides a view within a given document, however there is no direct connection between
the location of the view on the page and the content displayed. Structure elements (see 14.7.2,
"Structure hierarchy") allow specific sequences of content on a page to be identified. A structure
destination provides the same view mechanism as a destination, but references a structure element
instead of a page. A structure destination shall use the same syntax as a destination (see "Table 149 —
Destination syntax"), except that the first entry in the array shall be an indirect reference to a structure
element dictionary instead of to a page dictionary.
EXAMPLE           A regular destination of the following syntax [page /FitH 500] could be represented as a structure
destination with the following syntax [elem /FitH 500] where elem represents an indirect reference to a
structure element dictionary.
The structure element shall be used to identify the page to which the content belongs and, using that
page, the structure destination shall behave identically to a destination. To identify the page to which a
structure destination refers, the following algorithm shall be used. The kids of the structure element
shall be processed in linear array order. If the first kid is a marked-content reference or an object
reference (see 14.6, "Marked content"), then the page to which that reference belongs shall be used as
the page. If the first kid is a structure element, then processing shall continue down to that element
using the same algorithm recursively. If no content or object reference is found under the first entry,
processing should proceed to next entry, repeating the process. This shall continue until all entries
have been processed or until the first page is identified. In the case where no page content is identified,
then the page reference shall be assumed to be the first page in the document.
No structure element dictionary can be specified for a structure destination associated with a remote
go-to action (see 12.6.4.3, "Remote Go-To actions") or embedded go-to actions (see 12.6.4.4,
"Embedded Go-To actions") because the destination structure element is in a different PDF document.
In this case, the indirect reference to the structure element dictionary shall be replaced by a byte string
representing a structure element ID (see "Table 355 — Entries in a structure element dictionary").
NOTE 1      The above paragraph was corrected to also include embedded go-to actions (2020).
NOTE 2      There is no requirement that a given structure element will have an ID associated with it, nor
that it will remain consistent across edits to a PDF document. For remote go-to actions which
rely on a target PDF having an ID, it is important that such an ID exist and that it remain
consistent across versions of the target document.

#### 2.5: 12.3.2.4          Named destinations
Instead of being defined directly with the explicit syntax shown in "Table 149 — Destination syntax", a
destination may be referred to indirectly by means of a name object (PDF 1.1) or a byte string (PDF
1.2). This capability is especially useful when the destination is located in another PDF document.
NOTE 1     A link to the beginning of Chapter 6 in another document can refer to the destination by a name,
such as Chap6.begin, instead of by an explicit page number in the other document. Then, the
location of the chapter in the other document could change without invalidating the link. If an
annotation or outline item that refers to a named destination has an associated action, such as a
remote go-to action (see 12.6.4.3, "Remote Go-To actions") or a thread action (12.6.4.7, "Thread
actions"), the destination is in the PDF file specified by the action’s F entry, if any; if there is no F
entry, the destination is in the current PDF file.
In PDF 1.1, the correspondence between name objects and destinations shall be defined by the Dests
entry in the document catalog dictionary (see 7.7.2, "Document catalog dictionary"). The value of this
entry shall be a dictionary in which each key is a destination name and the corresponding value is
either an array defining the destination, using the syntax shown in "Table 149 — Destination syntax",
or a dictionary with a D entry whose value is such an array and may optionally contain an SD entry as
defined in "Table 201 — Action types".
NOTE 2     The latter form allows additional attributes to be associated with the destination, as well as
enabling a go-to action (see 12.6.4.2, "Go-To actions") that can be used as the target of a named
destination.
In PDF 1.2 and later, the correspondence between strings and destinations may alternatively be
defined by the Dests entry in the document’s name dictionary (see 7.7.4, "Name dictionary"). The value
of this entry shall be a name tree (7.9.6, "Name trees") mapping name strings to destinations. (The keys
in the name tree may be treated as text strings for display purposes.) The destination value associated
with a key in the name tree may be either an array or a dictionary, as described in the preceding
paragraph.
When trying to locate a named destination in a names tree, either in the same or in remote PDF files,
the algorithms specified in J.3.3, "String objects" or J.3.4, "Name objects" shall be used (depending on
the type of object being compared).
NOTE 3     The above paragraph was added in this document (2020).
NOTE 4     The use of strings as destination names is a PDF 1.2 feature. If compatibility with versions of PDF
prior to PDF 1.2 is required, only name objects can be used to refer to named destinations. A
document that supports PDF 1.2 or later can contain both types. However, if backward
compatibility to PDF 1.2 is not a consideration, it is recommended that applications use the
string form of representation in the Dests name tree.

#### 2.6: 12.3.3          Document outline
A PDF document may contain a document outline that the interactive PDF processor may display on the
screen, allowing the user to navigate interactively from one part of the document to another. The
outline consists of a tree-structured hierarchy of outline items (sometimes called bookmarks), which
serve as a visual table of contents to display the document’s structure to the user. The user may
interactively open and close individual items by clicking them with the mouse. When an item is open,
its immediate children in the hierarchy shall become visible on the screen; each child may in turn be
open or closed, selectively revealing or hiding further parts of the hierarchy. When an item is closed, all
of its descendants in the hierarchy shall be hidden. Clicking the text of any visible item activates the
item, causing the interactive PDF processor to jump to a destination or trigger an action associated
with the item.
The root of a document’s outline hierarchy is an outline dictionary specified by the Outlines entry in
the document catalog dictionary (see 7.7.2, "Document catalog dictionary"). "Table 150 — Entries in

the outline dictionary" shows the contents of this dictionary. Each individual outline item within the
hierarchy shall be defined by an outline item dictionary ("Table 151 — Entries in an outline item
dictionary"). The items at each level of the hierarchy form a linked list, chained together through their
Prev and Next entries and accessed through the First and Last entries in the parent item (or in the
outline dictionary in the case of top-level items). When displayed on the screen, the items at a given
level shall appear in the order in which they occur in the linked list.
Table 150 — Entries in the outline dictionary
Key           Type                  Value
Type          name                  (Optional) The type of PDF object that this dictionary describes; if
present, shall be Outlines for an outline dictionary.
First         dictionary            (Required if there are any open or closed outline entries; shall be an
indirect reference) An outline item dictionary representing the first
top-level item in the outline.
Last          dictionary            (Required if there are any open or closed outline entries; shall be an
indirect reference) An outline item dictionary representing the last
top-level item in the outline.
Count         integer               (Required if the document has any open outline entries) Total
number of visible outline items at all levels of the outline. The
value cannot be negative.
This entry shall be omitted if there are no open outline items.
Table 151 — Entries in an outline item dictionary
Key           Type                  Value
Title         text string           (Required) The text that shall be displayed on the screen for this
item.
Parent        dictionary            (Required; shall be an indirect reference) The parent of this item in
the outline hierarchy. The parent of a top-level item shall be the
outline dictionary itself.
Prev          dictionary            (Required for all but the first item at each level; shall be an indirect
reference) The previous item at this outline level.
Next          dictionary            (Required for all but the last item at each level; shall be an indirect
reference) The next item at this outline level.
First         dictionary            (Required if the item has any descendants; shall be an indirect
reference) The first of this item’s immediate children in the outline
hierarchy.
Last          dictionary            (Required if the item has any descendants; shall be an indirect
reference) The last of this item’s immediate children in the outline
hierarchy.
Key            Type                  Value
Count          integer               (Required if the item has any descendants) If the outline item is
open, Count is the sum of the number of visible descendent outline
items at all levels. The number of visible descendent outline items
shall be determined by the following recursive process:
Step 1. Initialize Count to zero.
Step 2. Add to Count the number of immediate children. During
repetitions of this step, update only the Count of the
original outline item.
Step 3. For each of those immediate children whose Count is
positive and non-zero, repeat steps 2 and 3.
If the outline item is closed, Count is negative and its absolute
value is the number of descendants that would be visible if the
outline item were opened.
Dest           name, byte            (Optional; shall not be present if an A entry is present) The
string, or array      destination that shall be displayed when this item is activated (see
12.3.2, "Destinations").
A              dictionary            (Optional; PDF 1.1; shall not be present if a Dest entry is present)
The action that shall be performed when this item is activated (see
12.6, "Actions").
SE             dictionary            (Optional; PDF 1.3; shall be an indirect reference) The structure
element to which the item refers (see 14.7.2, "Structure
hierarchy").
NOTE     This value is not intended for navigation. Structure Destinations
(Dest entry) are the method to provide structure-based
navigation.
C              array                 (Optional; PDF 1.4) An array of three numbers in the range 0.0 to
1.0, representing the components in the DeviceRGB colour space
of the colour that shall be used for the outline entry’s text. Default
value: [0.0 0.0 0.0].
F              integer               (Optional; PDF 1.4) A set of flags specifying style characteristics for
displaying the outline item’s text (see "Table 152 — Outline item
flags"). Default value: 0.
The value of the outline item dictionary’s F entry (PDF 1.4) shall be an integer interpreted as one-bit
flags specifying style characteristics for displaying the item. Bit positions within the flag word are
numbered from low-order to high-order bits, with the lowest-order bit numbered 1. "Table 152 —
Outline item flags" shows the meanings of the flags; all other bits of the integer shall be 0.
Table 152 — Outline item flags
Bit position       Name           Meaning
1                  Italic         If set to 1, display the item in italic.
2                  Bold           If set to 1, display the item in bold.

EXAMPLE           The following example shows a typical outline dictionary and outline item dictionary. See H.6, "Outline
hierarchy example" for an example of a complete outline hierarchy.
21 0 obj
<</Count 6
/First 22 0 R
/Last 29 0 R
>>
endobj
22 0 obj
<</Title ( Chapter 1 )
/Parent 21 0 R
/Next 26 0 R
/First 23 0 R
/Last 25 0 R
/Count 3
/Dest [3 0 R /XYZ 0 792 0]
>>
endobj

#### 2.7: 12.3.4            Thumbnail images
A PDF document may contain thumbnail images representing the contents of its pages in miniature
form. An interactive PDF processor may display these images on the screen, allowing the user to
navigate to a page by clicking its thumbnail image:
NOTE        Thumbnail images are not required, and can be included for some pages and not for others.
The thumbnail image for a page shall be an image XObject specified by the Thumb entry in the page
object (see 7.7.3, "Page tree"). It has the usual structure for an image dictionary (8.9.5, "Image
dictionaries"), but only the Width, Height, ColorSpace, BitsPerComponent, and Decode entries are
significant; all of the other entries listed in "Table 87 — Additional entries specific to an image
dictionary" shall be ignored if present. (If a Subtype entry is specified, its value shall be Image.) The
image’s colour space shall be either DeviceGray or DeviceRGB, or an Indexed colour space based on
one of these.
EXAMPLE           This example shows a typical thumbnail image definition.
12 0 obj
<</Width 76
/Height 99
/ColorSpace /DeviceRGB
/BitsPerComponent 8
/Length 13 0 R
/Filter [/ASCII85Decode /DCTDecode]
>>
stream
s4IA>!"M;*Ddm8XA,lT0!!3,S!/(=R!<E3%!<N<(!WrK*!WrN,
… Omitted data …
endstream
endobj
13 0 obj                                                                       %Length of stream
…
endobj

#### 2.8: 12.3.5.1        General
Beginning with PDF 1.7, PDF documents may specify how an interactive PDF processor’s user interface
presents collections of file attachments, where the attachments are related in structure or content. Such
a presentation is called a portable collection.
NOTE 1     The intent of portable collections is to present, sort, and search collections of related documents
embedded in the containing PDF document, such as email archives, photo collections, and
engineering bid sets. There is no requirement that documents in a collection have an implicit
relationship or even a similarity; however, showing differentiating characteristics of related
documents can be helpful for document navigation.
A collection dictionary specifies the viewing and organisational characteristics of portable collections. If
this dictionary is present in a PDF document, the interactive PDF processor shall present the document
as a portable collection. The EmbeddedFiles name tree specifies file attachments (see "Table 32 —
Entries in the name dictionary").
When an interactive PDF processor first opens a PDF document containing a collection, it shall display
the contents according to the View key of the collection dictionary. The initial document may be the
container PDF or one of the embedded documents as specified by the D key in the collection dictionary.
NOTE 2     The page content in the initial document needs to contain information that helps the user
understand what is contained in the collection, such as a title and an introductory paragraph.
The file attachments comprising a collection shall be located in the EmbeddedFiles name tree. All
attachments in that tree are in the collection; any attachments not in that tree are not. For a PDF
document that is an unencrypted wrapper for an encrypted payload document (see 7.6.7,
"Unencrypted wrapper document"), the EmbeddedFiles name tree shall contain exactly one entry, for
the encrypted payload document.
Beginning with PDF 2.0, a portable collection may include an interactive layout, or presentation, of the
collection contents. The collection layout or presentation is called a navigator. For more information
about navigators, see 12.3.6, "Navigators".
When a navigator is used the collection dictionary shall contain some entries that support navigators.
The Navigator entry shall be an indirect reference to a navigator dictionary that describes the
interactive layout. The value of the Colors entry shall be a collection colors dictionary that specifies a
suggested set of colours for use by a collection layout. The Folders entry shall be an indirect reference
to the root folder of the collection’s folder structure.
“Table 153 — Entries in a collection dictionary” describes the entries in a collection dictionary.
Table 153 — Entries in a collection dictionary
Key           Type          Value
Type          name          (Optional) The type of PDF object that this dictionary describes; if
present, shall be Collection for a collection dictionary.

Key             Type            Value
Schema          dictionary      (Optional) A collection schema dictionary (see "Table 154 — Entries
in a collection schema dictionary"). If absent, the interactive PDF
processor may choose useful defaults that are known to exist in a file
specification dictionary, such as the file name, file size, and modified
date.
D               byte string     (Optional) A string that identifies an entry in the EmbeddedFiles
name tree, determining the document that shall be initially
presented in the user interface. If the D entry is missing or is not a
valid byte string, the initial document shall be the one that contains
the collection dictionary. If the D entry is a valid byte string that does
not match any file in the EmbeddedFiles name tree, the interactive
PDF processor shall select the first item from the list of files to
display in its user interface; if no files exist in the name tree, the
interactive PDF processor shall display an empty preview window.
(PDF 2.0) For unencrypted wrapper documents for an encrypted
payload document (see 7.6.7, "Unencrypted wrapper document") the
D entry is required, and shall identify the encrypted payload entry in
the EmbeddedFiles name tree.
View            name            (Optional) The initial view. The following values are valid:
D    The collection view shall be presented in details mode, with all
information in the Schema dictionary presented in a multi-
column format. This mode provides the most information to the
user.
T    The collection view shall be presented in tile mode, with each
file in the collection denoted by a small icon and a subset of
information from the Schema dictionary. This mode provides
top-level information about the file attachments to the user.
H The collection view shall be initially hidden. The interactive PDF
processor shall provide means for the user to view the
collection by some explicit action. The PDF processor should
display the document specified by the D entry.
NOTE How the PDF processor chooses to display the collection
is implementation specific.
C    (PDF 2.0, valid only when Navigator is present) The collection
view shall be presented by the navigator specified by the
Navigator entry.
Default value: D
(PDF 2.0) For unencrypted wrapper documents for an encrypted
payload document (see 7.6.7, "Unencrypted wrapper document") the
View entry is required, and shall have a value of H.
Navigator       dictionary      (Required if the value of View is C; PDF 2.0) An indirect reference to
the navigator dictionary that describes the navigator that provides
the collection view. See "Table 160 — Entries in a navigator
dictionary".
Colors          dictionary      (Optional; PDF 2.0) A collection colors dictionary specifying a
suggested set of colours for use by a collection layout. See "Table 157
— Entries in a collection colors dictionary".
NOTE     It is recommended that a layout use the colours provided.
Key           Type          Value
Sort          dictionary    (Optional) A collection sort dictionary, which specifies the order in
which items in the collection shall be sorted in the user interface (see
"Table 156 — Entries in a collection sort dictionary").
Folders       dictionary    (Required if the collection has folders; PDF 2.0) An indirect reference
to a folder dictionary that is the single common ancestor of all other
folders in a portable collection. See "Table 159 — Entries in a folder
dictionary".
Split         dictionary    (Optional; PDF 2.0) A collection split dictionary that specifies the
orientation of the splitter bar in the user interface provided by the
interactive PDF processor. See "Table 158 — Entries in a collection
split dictionary".
If Split is not present, the preferred orientation is determined by the
value of the View key. A value of D (or no value) shall indicate a
horizontal orientation, while a value of T shall indicate a vertical
orientation. No splitter shall be used if the View key has a value of H
or C.
A collection schema dictionary consists of a variable number of individual collection field dictionaries.
Each collection field dictionary has a key chosen by the interactive PDF writer, which shall be used to
associate a field with data in a file specification. "Table 154 — Entries in a collection schema
dictionary" describes the entries in a collection schema dictionary.
Table 154 — Entries in a collection schema dictionary
Key                        Type         Value
Type                       name         (Optional) The type of PDF object that this dictionary
describes; if present, shall be CollectionSchema for a
collection schema dictionary.
Other keys                 dictionary   (Optional) A collection field dictionary. Each key name is
chosen at the discretion of the PDF writer. The key name
shall be used to identify a corresponding collection item
dictionary referenced from the file specification
dictionary's CI entry (see CI key in "Table 43 — Entries in
a file specification dictionary").
A collection field dictionary describes the attributes of a particular field in a portable collection,
including the type of data stored in the field and the lookup key used to locate the field data in the file
specification dictionary. "Table 155 — Entries in a collection field dictionary" describes the entries in a
collection field dictionary.

Table 155 — Entries in a collection field dictionary
Key          Type          Value
Type         name          (Optional) The type of PDF object that this dictionary describes; if present, shall be
CollectionField for a collection field dictionary.
Subtype      name          (Required) The subtype of collection field or file-related field that this dictionary
describes. This entry identifies the type of data that shall be stored in the field.
The following values identify the types of fields in the collection item or collection
subitem dictionary:
S    A text field. The field data shall be stored as a PDF text string.
D    A date field. The field data shall be stored as a PDF date string (see 7.9.4,
"Dates").
N    A number field. The field data shall be stored as a PDF number.
The following values identify the types of file-related fields:
F                     The field data shall be the file name of the embedded file stream,
as identified by the UF entry of the file specification, if present;
otherwise by the F entry of the file specification (see "Table 43 —
Entries in a file specification dictionary").
Desc                  The field data shall be the description of the embedded file
stream, as identified by the Desc entry in the file specification
dictionary (see "Table 43 — Entries in a file specification
dictionary").
ModDate               The field data shall be the modification date of the embedded file
stream, as identified by the ModDate entry in the embedded file
parameter dictionary (see "Table 45 — Entries in an embedded
file parameter dictionary").
CreationDate          The field data shall be the creation date of the embedded file
stream, as identified by the CreationDate entry in the embedded
file parameter dictionary (see "Table 45 — Entries in an
embedded file parameter dictionary").
Size                  The field data shall be the size of the embedded file, as identified
by the Size entry in the embedded file parameter dictionary (see
"Table 45 — Entries in an embedded file parameter dictionary").
CompressedSize        (PDF 2.0) The field data shall be the length of the embedded file
stream, as identified by the Length entry in the embedded file
stream dictionary (see 7.11.4, "Embedded file streams"), and the
two values shall be identical.
N            text string   (Required) The textual field name that shall be presented to the user by the interactive
PDF processor.
O            integer       (Optional) The relative order of the field name in the user interface. Fields shall be
sorted by the interactive PDF processor in ascending order.
V            boolean       (Optional) The initial visibility of the field in the user interface. Default value: true.
E            boolean       (Optional) A flag indicating whether the interactive PDF processor should provide
support for editing the field value. Default value: false.
A collection sort dictionary identifies the fields that shall be used to sort items in the collection. The
type of sorting depends on the type of data:
•    Text strings shall be ordered lexically from smaller to larger, if ascending order is specified.
NOTE 3       Lexical ordering is an implementation dependency for interactive PDF processors.
•    Numbers shall be ordered numerically from smaller to larger, if ascending order is specified.
•    Dates shall be ordered from oldest to newest, if ascending order is specified.
"Table 156 — Entries in a collection sort dictionary" describes the entries in a collection sort
dictionary.
Table 156 — Entries in a collection sort dictionary
Key      Type        Value
Type     name        (Optional) The type of PDF object that this dictionary describes; if present, shall
be CollectionSort for a collection sort dictionary.
S        name or     (Required) The name or names of fields that the interactive PDF processor shall
array       use to sort the items in the collection. If the value is a name, it identifies a field
described in the parent collection dictionary.
If the value is an array, each element of the array shall be a name that identifies a
field described in the parent collection dictionary. The array form shall be used
to allow additional fields to contribute to the sort, where each additional field
shall be used to break ties. More specifically, if multiple collection item
dictionaries have the same value for the first field named in the array, the values
for successive fields named in the array shall be used for sorting, until a unique
order is determined or until the named fields are exhausted.
A        boolean or (Optional) If the value is a boolean, it specifies whether the interactive PDF
array      processor shall sort the items in the collection in ascending order (true) or
descending order (false). If the value is an array, each element of the array shall
be a boolean value that specifies whether the entry at the same index in the S
array shall be sorted in ascending or descending order.
If the number of entries in the A array is larger than the number of entries in the
S array the extra entries in the A array shall be ignored. If the number of entries
in the A array is less than the number of entries in the S array the missing entries
in the A array shall be assumed to be true.
Default value: true.
Table 157 — Entries in a collection colors dictionary
Key                  Type       Value
Type                 name       (Optional; PDF 2.0) The type of PDF object that this dictionary describes;
if present, shall be CollectionColors for a collection colors dictionary.
Background           array      (Optional; PDF 2.0) An array of three numbers in the range 0.0 to 1.0,
representing a DeviceRGB colour used for the background of the view.
CardBackground       array      (Optional; PDF 2.0) An array of three numbers in the range 0.0 to 1.0,
representing a DeviceRGB colour used for the background of the card.
CardBorder           array      (Optional; PDF 2.0) An array of three numbers in the range 0.0 to 1.0,
representing a DeviceRGB colour used for the border of the card.

Key                    Type        Value
PrimaryText            array       (Optional; PDF 2.0) An array of three numbers in the range 0.0 to 1.0,
representing a DeviceRGB colour used for the primary text in a
navigator.
SecondaryText          array       (Optional; PDF 2.0) An array of three numbers in the range 0.0 to 1.0,
representing a DeviceRGB colour used for other text in a navigator.
When displaying a collection, an interactive PDF processor presents an initial view in which the
available display area may be divided by a splitter bar into two areas; one area containing a display of
the navigation controls of the collection as defined by the View and related entries of the collection
dictionary, and one area containing a preview of the initial or currently selected document of the
collection. The visibility, orientation or position of the splitter bar may be interactively adjusted by
user action subsequent to its initial view as defined by the collection split dictionary, if provided.
Table 158 — Entries in a collection split dictionary
Key                    Type           Value
Type                   name           (Optional; PDF 2.0) The type of PDF object that this dictionary
describes; if present, shall be CollectionSplit for a collection split
dictionary.
Direction              name           (Optional; PDF 2.0) The orientation of the splitter bar. The
following values are valid:
H indicates that the window is split horizontally
V    indicates that the window is split vertically.
N indicates that the window is not split. The entire window
region shall be dedicated to the file navigation view.
Position               number         (Optional; PDF 2.0) The initial position of the splitter bar,
specified as a percentage of the available window area. Values
shall range from 0 to 100. The entry shall be ignored if Direction
is set to N.

#### 2.9: 12.3.5.2          Collection hierarchical folders
Beginning with PDF 2.0, a portable collection can contain a Folders object for the purpose of organising
files into a hierarchical structure. The structure is represented by a tree with a single root folder acting
as the common ancestor for all other folders and files in the collection. The single root folder is
referenced in the Folders entry of "Table 153 — Entries in a collection dictionary".
Table 159 — Entries in a folder dictionary
Key                    Type           Value
Type                   name           (Optional; PDF 2.0) The type of PDF object that this dictionary
describes; if present, shall be Folder for a folder dictionary.
Key                 Type           Value
ID                  integer        (Required; PDF 2.0) A non-negative integer value representing the
unique folder identification number. Two folders, in the same PDF
document, shall not share the same ID value.
The folder ID value appears as part of the name tree key of any
file associated with this folder. A detailed description of the
association between folder and files can be found after this table.
Name                text string    (Required; PDF 2.0) A file name representing the name of the
folder. Two sibling folders shall not share the same name
following case normalization.
NOTE     Descriptions of file name and case normalization follow this
table.
Parent              dictionary     (Required for child folders; PDF 2.0) An indirect reference to the
parent folder of this folder.
This entry shall be absent for a root folder.
Child               dictionary     (Required if the folder has any descendents; PDF 2.0) An indirect
reference to the first child folder of this folder.
Next                dictionary     (Required for all but the last item at each level; PDF 2.0) An
indirect reference to the next sibling folder at this level.
Siblings should be ordered according to the collection Sort key
("Table 153 — Entries in a collection dictionary") or by folder
name if no collection Sort key is present.
CI                  dictionary     (Optional; PDF 2.0) The collection item dictionary. Beginning with
(uppercase ci)                     PDF 1.7, a collection item dictionary shall contain the data
described by the collection schema dictionary for a particular file
in a collection (see 12.3.5, "Collections"). "Table 46 — Entries in a
collection item dictionary" describes the entries in a collection
item dictionary.
Desc                text string    (Optional; PDF 2.0) A text description associated with this folder.
CreationDate        date           (Optional; PDF 2.0) The date the folder was first created.
ModDate             date           (Optional; PDF 2.0) The date of the most recent change to
immediate child files or folders of this folder.
Thumb               stream         (Optional; PDF 2.0) A stream object defining the thumbnail image
for the folder See 12.3.4, "Thumbnail images".
Free                array          (Optional; only used by root folder; PDF 2.0) An array containing
ID values that are not currently in use by the folder structure. The
array shall contains zero or more pairs of numbers, a low value
followed by a high value. Each pair represents an endpoint-
inclusive range of values that are available for use when a new
folder is added. Each low value shall be less than or equal to its
corresponding high value.
New values for the ID key shall be obtained by an interactive PDF processor by accessing the Free
entry in the root folder. If an ID value is used from the Free entry array, the array shall be updated.

As previously described, the Name entry is a file name for a folder. A folder, as well as its associated
files, have naming restrictions. Strings that conform to these restrictions are known as file names. A
valid file name conforms to the following requirements:
•    The string shall be a PDF text string.
•    The string shall not contain any embedded NULL (U+0000) characters.
•    The number of characters in the string shall be between 1 and 255 inclusive.
•    The string shall not contain any of the eight special characters: SOLIDUS (U+002F) (/), REVERSE
SOLIDUS (U+005C) (\), COLON (U+003A) (:), ASTERISK (U+002A) (*), QUOTATION MARK
(U+0022) ("), LESS-THAN SIGN (U+003C) (<), GREATER-THAN SIGN (U+003E) (>) and VERTICAL
LINE (U+007C) (|).
•    The last character shall not be a FULL STOP (U+002E) (.).
An interactive PDF processor may choose to support invalid names or not. If not, an appropriate error
message shall be provided.
In addition to the restriction on naming folders, as just described, it is further required that two file
names in the same folder do not map to the same string following case normalization. Two file names
that differ only in case are disallowed within the same folder. See "Unicode Standard Annex #21, Case
Mappings" for information on case normalization.
The CI entry, a collection item dictionary, allows user-defined metadata to be associated with a folder,
just as it does for embedded files in a collection.
Folders are indirect objects, and relationships between folders in the tree are specified using Parent,
Child, and Next keys.
When folders are used, all files in the EmbeddedFiles name tree (see "Table 32 — Entries in the name
dictionary") shall be treated as members of the folder structure by an interactive PDF processor. The
association between files and folders is accomplished using a special naming convention on the key
strings of the name tree. See 7.9.6, "Name trees", for a discussion of the key strings. If no folder
structure is specified, interactive PDF processors should show all files in the collection in a flat list.
As previously mentioned, files in the EmbeddedFiles name tree are associated with folders by a
special naming convention applied to the name tree key strings. Strings that conform to the following
rules serve to associate the corresponding file with a folder:
•    The name tree keys are PDF text strings.
•    The first character, excluding any byte order marker, is LESS-THAN SIGN (U+003C) (<).
•    The following characters shall be one or more digits (0 to 9) followed by the closing GREATER-
THAN SIGN (U+003E) (>)
•    The remainder of the string is a file name.
The section of the string enclosed by LESS-THAN SIGN GREATER-THAN SIGN(<>) is interpreted as a
numeric value that specifies the ID value of the folder with which the file is associated. The value shall
correspond to a folder ID. The section of the string following the folder ID tag shall represent the file
name of the embedded file.
Files in the EmbeddedFiles name tree that do not conform to these rules shall be treated as associated
with the root folder.
EXAMPLE 1      This example shows a collection dictionary representing an email in-box, where each item in the collection
is an email message. The actual email messages are contained in file specification dictionaries. The
organisational data associated with each email is described in a collection schema dictionary. Most actual
organisational data (from, to, date, and subject) is provided in a collection item dictionary, but the size data
comes from the embedded file parameter dictionary.
/Collection <<
/Type /Collection
/Schema <<
/Type /CollectionSchema
/from <</Subtype /S /N (From) /O 1 /V true /E false>>
/to <</Subtype /S /N (To) /O 2 /V true /E false>>
/date <</Subtype /D /N (Date received) /O 3 /V true /E false>>
/subject <</Subtype /S /N (Subject) /O 4 /V true /E false>>
/size <</Subtype /Size /N (Size) /O 5 /V true /E false>>
>>
/D (Doc1)
/View /D
/Sort <</S /date /A false>>
>>
EXAMPLE 2      This example shows a collection item dictionary and a collection subitem dictionary. These dictionaries
contain entries that correspond to the schema entries specified in the Example in 12.4.2, "Page labels".
7.11.6, "Collection items" specifies the collection item and collection subitem dictionaries.
/CI <<
/Type /CollectionItem
/from (Tom Jones)
/to (Marry Jones)
/subject <<
/Type /CollectionSubitem
/P (Re:)
/D (Let's have lunch on Friday!)
>>
/date (D:20050621094703-07’00)
>>

#### 2.10: 12.3.6         Navigators
A portable collection can include an interactive layout, or presentation, for the collection contents (PDF
2.0) called a navigator. When a navigator is specified, a PDF processor should display that interactive
layout and allow it to drive the presentation of the collection.
Navigators are specified by identifying a named layout, used to identify a presentation for the content
within a collection. These interactive layouts provide more choice in presenting the collection contents
than the simple views specified by the View key in the collection dictionary (see "Table 153 — Entries
in a collection dictionary"). When a navigator dictionary is present, a PDF processor should use the
value of the Layout entry to present the collection to the user.
Named layouts provide a number of options for presenting the contents of the collection to a user.
These options are provided to allow the choice of a navigator that is best suited to presenting the
collection’s contents, including the folder structures and file attachments. The Layout key may consist
of a single name value, to specify the named layout, or an array of names. When an array of names is
provided, a PDF processor should select the first named layout it recognises. This mechanism is
inherently extensible and allows inclusion of custom named layouts, but at least one of the values of

the Layout entry shall be one of the values listed in the entry (see "Table 160 — Entries in a navigator
dictionary").
Table 160 — Entries in a navigator dictionary
Key        Type        Value
Type       name        (Optional; PDF 2.0) The type of PDF object that this dictionary describes; if present,
shall be Navigator for a navigator dictionary.
Layout     name or (Required; PDF 2.0) One or more names specifying the named layout of the
array of navigator that should be used. When multiple names are provided, an interactive
names    PDF processor should present the first one it is capable of displaying in the order
present in the array. One of the following names shall always be present, either
singly or as the final entry in the array.
D    Corresponding to the value of D in the View key in "Table 153 — Entries in a
collection dictionary".
T    Corresponding to the value of T in the View key in "Table 153 — Entries in a
collection dictionary".
H    Corresponding to the value of H in the View key in "Table 153 — Entries in a
collection dictionary".
FilmStrip      A layout which displays a strip of thumbnails, providing an index to
the file attachments within the collection. The selected attachment
should be previewed alongside the index.
FreeForm       A layout which places thumbnails of the file attachments within the
collection randomly in the view.
Linear         A layout which provides a large size preview of one file attachment in
the collection and displays alongside the preview the metadata for the
file attachment, including the name, description and other collection
schema entries.
Tree           A layout presenting the contents of the collection in a tree view,
showing the folder structure and the files as leaf nodes of the tree,
akin to a traditional file system folder view.
The D, T and H values for the Layout entry match those present in the View entry of a collection
dictionary (see "Table 153 — Entries in a collection dictionary"). An interactive PDF processor should
present the same display mode when encountering these values as it would if processing the View
entry.
The FilmStrip layout describes a presentation of the collection contents in the form of a single strip of
thumbnails. These thumbnails provide an index into the files and folders present within the collection.
When a user selects a file from the index, an interactive PDF processor should either display that file or
provide a preview of the file.
NOTE 1      A common implementation for this is to have the strip of thumbnails across the bottom of the
view and a large preview of the selected file or folder shown above it.
The FreeForm layout provides a simple layout, in which thumbnails for each item in the collection
contents are displayed at a random location on the view. When a thumbnail is selected, an interactive
PDF processor should display the attachment.
The Linear layout provides a view of an attachment, which is usually larger than just a thumbnail, with
the metadata for the file displayed alongside it. An interactive PDF should display the first page of the
file and should use the file schema and file specification dictionary to provide information about the
attachment.
The Tree layout is intended to provide a classic folder view of the contents of a collection, akin to that
found on many operating systems. An interactive PDF should present the folder structure as the nodes
of the tree, with the attachments being presented as the leaves of the tree.

#### 2.11: 12.4.1          General
This subclause describes PDF facilities that enable the user to navigate from page to page within a
document:
•    Page labels for numbering or otherwise identifying individual pages (see 12.4.2, "Page labels").
•    Article threads, which chain together items of content within the document that are logically
connected but not physically sequential (see 12.4.3, "Articles").
•    Presentations that display the document in the form of a slide show, advancing from one page to
the next either automatically or under user control (see 12.4.4, "Presentations").
For another important form of page-level navigation, see 12.5.6.5, "Link annotations".

#### 2.12: 12.4.2          Page labels
Each page in a PDF document shall be identified by an integer page index that expresses the page’s
relative position within the document. In addition, a document may optionally define page labels (PDF
1.3) to identify each page visually on the screen or in print. Page labels and page indices need not
coincide: the indices shall be fixed, running consecutively through the document starting from 0 for the
first page, but the labels may be specified in any way that is appropriate for the particular document.
NOTE 1     If the document begins with 12 pages of front matter numbered in Roman numerals and the
remainder of the document is numbered in Arabic numerals, the first page would have a page
index of 0 and a page label of i, the twelfth page would have index 11 and label xii, and the
thirteenth page would have index 12 and label 1.
For purposes of page labelling, a document shall be divided into labelling ranges, each of which is a
series of consecutive pages using the same numbering system. Labelling ranges shall not overlap, so
that each page shall have only one label. Pages within a range shall be numbered sequentially in
ascending order. A page’s label consists of a numeric portion based on its position within its labelling
range, optionally preceded by a label prefix denoting the range itself.
NOTE 2     The pages in an appendix can be labelled with decimal numeric portions prefixed with the string
A-; the resulting page labels would be A-1, A-2, and so on.
A document’s labelling ranges shall be defined by the PageLabels entry in the document catalog
dictionary (see 7.7.2, "Document catalog dictionary"). The value of this entry shall be a number tree
(7.9.7, "Number trees"), each of whose keys is the page index of the first page in a labelling range. The
corresponding value shall be a page label dictionary defining the labelling characteristics for the pages

in that range. The tree shall include a value for page index 0. "Table 161 — Entries in a page label
dictionary" shows the contents of a page label dictionary.
Table 161 — Entries in a page label dictionary
Key      Type                Value
Type     name                (Optional) The type of PDF object that this dictionary describes; if present,
shall be PageLabel for a page label dictionary.
S        name                (Optional) The numbering style that shall be used for the numeric portion of
each page label:
D    Decimal Arabic numerals
R    Uppercase Roman numerals
r    Lowercase Roman numerals
A    Uppercase letters (A to Z for the first 26 pages, AA to ZZ for the next 26,
and so on)
a    Lowercase letters (a to z for the first 26 pages, aa to zz for the next 26,
and so on)
There is no default numbering style; if no S entry is present, page labels shall
consist solely of a label prefix with no numeric portion.
NOTE     If the P entry (next) specifies the label prefix Contents, each page is simply
labelled Contents with no page number. (If the P entry is also missing or
empty, the page label is an empty string.)
P        text string         (Optional) The label prefix for page labels in this range.
St       integer             (Optional) The value of the numeric portion for the first page label in the
range. Subsequent pages shall be numbered sequentially from this value,
which shall be greater than or equal to 1. Default value: 1.
EXAMPLE           The following example shows a document with pages labelled i, ii, iii, iv, 1, 2, 3, A-8, A-9, …
1 0 obj
<</Type /Catalog
/PageLabels <</Nums [   0 <</S /r>>                           %A number tree containing
4 <</S /D>>                                 %three page label dictionaries
7 <</S /D
/P ( A- )
/St 8
>>
]
>>
…
>>
endobj

#### 2.13: 12.4.3            Articles
Some types of documents may contain sequences of content items that are logically connected but not
physically sequential.
EXAMPLE 1         A news story may begin on the first page of a newsletter and run over onto one or more nonconsecutive
interior pages.
To represent such sequences of physically discontiguous but logically related items, a PDF document
may define one or more articles (PDF 1.1). The sequential flow of an article shall be defined by an
article thread; the individual content items that make up the article are called beads on the thread.
Interactive PDF processors may provide navigation facilities to allow the user to follow a thread from
one bead to the next.
The optional Threads entry in the document catalog dictionary (see 7.7.2, "Document catalog
dictionary") holds an array of thread dictionaries ("Table 162 — Entries in a thread dictionary")
defining the document’s articles. Each individual bead within a thread shall be represented by a bead
dictionary ("Table 163 — Entries in a bead dictionary"). The thread dictionary’s F entry shall refer to
the first bead in the thread; the beads shall be chained together sequentially in a doubly linked list
through their N (next) and V (previous) entries. In addition, for each page on which article beads
appear, the page object (see 7.7.3, "Page tree") shall contain a B entry whose value is an array of
indirect references to the beads on the page, in drawing order.
Table 162 — Entries in a thread dictionary
Key        Type            Value
Type       name            (Optional) The type of PDF object that this dictionary describes; if
present, shall be Thread for a thread dictionary.
F          dictionary      (Required; shall be an indirect reference) The first bead in the thread.
I          dictionary      (Optional) A thread information dictionary containing information about
the thread, such as its title, author, and creation date. The contents of this
dictionary shall conform to the syntax for the document information
dictionary (see 14.3.3, "Document information dictionary").
Metadata stream            (Optional; PDF 2.0; shall be an indirect reference) A metadata stream
containing information about the thread, such as its title, author, and
creation date (see 14.3.2, "Metadata streams").
Table 163 — Entries in a bead dictionary
Key      Type             Value
Type     name             (Optional) The type of PDF object that this dictionary describes; if
present, shall be Bead for a bead dictionary.
T        dictionary       (Required for the first bead of a thread; optional for all others; shall be an
indirect reference) The thread to which this bead belongs.
(PDF 1.1) This entry shall be permitted only for the first bead of a thread.
(PDF 1.2) It shall be permitted for any bead but required only for the first.
N        dictionary       (Required; shall be an indirect reference) The next bead in the thread. In
the last bead, this entry shall refer to the first bead.
V        dictionary       (Required; shall be an indirect reference) The previous bead in the thread.
In the first bead, this entry shall refer to the last bead.

Key        Type            Value
P          dictionary      (Required; shall be an indirect reference) The page object representing the
page on which this bead appears.
R          rectangle       (Required) A rectangle specifying the location of this bead on the page in
default user space.
EXAMPLE 2         The following example shows a thread with three beads.
22 0 obj
<</F 23 0 R
/I <</Title (Man Bites Dog)>>
>>
endobj
23 0 obj
<</T 22 0 R
/N 24 0 R
/V 25 0 R
/P 8 0 R
/R [158 247 318 905]
>>
endobj
24 0 obj
<</T 22 0 R
/N 25 0 R
/V 23 0 R
/P 8 0 R
/R [322 246 486 904]
>>
endobj
25 0 obj
<</T 22 0 R
/N 23 0 R
/V 24 0 R
/P 10 0 R
/R [157 254 319 903]
>>
endobj

#### 2.14: 12.4.4.1          General
Some interactive PDF processors may allow a document to be displayed in the form of a presentation
or slide show, advancing from one page to the next either automatically or under user control. In
addition, PDF 1.5 introduces the ability to advance between different states of the same page (12.4.4.2,
"Sub-page navigation").
A page object (see 7.7.3, "Page tree") may contain two optional entries, Dur and Trans (PDF 1.1), to
specify how to display that page in presentation mode. The Trans entry shall contain a transition
dictionary describing the style and duration of the visual transition to use when moving from another
page to the given page during a presentation. "Table 164 — Entries in a transition dictionary" shows
the contents of the transition dictionary. (Some of the entries shown are needed only for certain
transition styles, as indicated in the table.)
The Dur entry in the page object specifies the page’s display duration (also called its advance timing):
the maximum length of time, in seconds, that the page shall be displayed before the presentation
automatically advances to the next page.
NOTE 1    The user can advance the page manually before the specified time has expired.
If no Dur entry is specified in the page object, the page shall not advance automatically.
Table 164 — Entries in a transition dictionary
Key     Type     Value
Type    name     (Optional) The type of PDF object that this dictionary describes; if present, shall be
Trans for a transition dictionary.
S       name     (Optional) The transition style that shall be used when moving to this page from another
during a presentation. Default value: R.
Split         Two lines sweep across the screen, revealing the new page. The lines may
be either horizontal or vertical and may move inward from the edges of the
page or outward from the centre, as specified by the Dm and M entries,
respectively.
Blinds        Multiple lines, evenly spaced across the screen, synchronously sweep in the
same direction to reveal the new page. The lines may be either horizontal
or vertical, as specified by the Dm entry. Horizontal lines move downward;
vertical lines move to the right.
Box           A rectangular box sweeps inward from the edges of the page or outward
from the centre, as specified by the M entry, revealing the new page.
Wipe          A single line sweeps across the screen from one edge to the other in the
direction specified by the Di entry, revealing the new page.
Dissolve      The old page dissolves gradually to reveal the new one.
Glitter       Similar to Dissolve, except that the effect sweeps across the page in a wide
band moving from one side of the screen to the other in the direction
specified by the Di entry.
R             The new page simply replaces the old one with no special transition effect;
the D entry shall be ignored.
Fly           (PDF 1.5) Changes are flown out or in (as specified by M), in the direction
specified by Di, to or from a location that is offscreen except when Di is
None.
Push          (PDF 1.5) The old page slides off the screen while the new page slides in,
pushing the old page out in the direction specified by Di.
Cover         (PDF 1.5) The new page slides on to the screen in the direction specified by
Di, covering the old page.
Uncover       (PDF 1.5) The old page slides off the screen in the direction specified by Di,
uncovering the new page in the direction specified by Di.
Fade          (PDF 1.5) The new page gradually becomes visible through the old one.
D       number (Optional) The duration of the transition effect, in seconds. Default value: 1.

Key       Type      Value
Dm        name      (Optional; Split and Blinds transition styles only) The dimension in which the specified
transition effect shall occur:
H Horizontal
V    Vertical
Default value: H.
M         name      (Optional; Split, Box and Fly transition styles only) The direction of motion for the
specified transition effect:
I    Inward from the edges of the page (upper case i)
O    Outward from the centre of the page (upper case o)
Default value: I.
Di        number (Optional; Wipe, Glitter, Fly, Cover, Uncover and Push transition styles only) The direction
or     in which the specified transition effect shall moves, expressed in degrees
name   counterclockwise starting from a left-to-right direction. (This differs from the page
object’s Rotate entry, which is measured clockwise from the top.)
If the value is a number, it shall be one of:
0         Left to right
90        Bottom to top (Wipe only)
180       Right to left (Wipe only)
270       Top to bottom
315       Top-left to bottom-right (Glitter only)
If the value is a name, it shall be None, which is relevant only for the Fly transition when
the value of SS is not 1.0.
Default value: 0.
SS        number (Optional; PDF 1.5; Fly transition style only) The starting or ending scale at which the
changes shall be drawn. If M specifies an inward transition, the scale of the changes
drawn shall progress from SS to 1.0 over the course of the transition. If M specifies an
outward transition, the scale of the changes drawn shall progress from 1.0 to SS over the
course of the transition
Default: 1.0.
B         boolean (Optional; PDF 1.5; Fly transition style only) If true, the area that shall be flown in is
rectangular and opaque. Default: false.
NOTE 2      "Figure 76 — Presentation timing" illustrates the relationship between transition duration (D in
the transition dictionary) and display duration (Dur in the page object). Note that the transition
duration specified for a page (page 2 in the figure) governs the transition to that page from
another page; the transition from the page is governed by the next page’s transition duration.
Figure 76 — Presentation timing
EXAMPLE         The following example shows the presentation parameters for a page to be displayed for 5 seconds. Before
the page is displayed, there is a 3.5-second transition in which two vertical lines sweep outward from the
centre to the edges of the page.
10 0 obj
<</Type /Page
/Parent 4 0 R
/Contents 16 0 R
/Dur 5
/Trans <<   /Type /Trans
/D 3.5
/S /Split
/Dm /V
/M /O
>>
>>
endobj

#### 2.15: 12.4.4.2         Sub-page navigation
Sub-page navigation (PDF 1.5) provides the ability to navigate not only between pages but also
between different states of the same page.
NOTE 1      A single page in a PDF presentation could have a series of bullet points that could be individually
turned on and off. In such an example, the bullets would be represented by optional content (see
8.11.2, "Optional content groups"), and each state of the page would be represented as a
navigation node.
NOTE 2      Interactive PDF processors need to save the state of optional content groups when a user enters
presentation mode and restore it when presentation mode ends. This ensures, for example, that
transient changes to bullets do not affect the printing of the document.
A navigation node dictionary (see "Table 165 — Entries in a navigation node dictionary") specifies
actions to execute when the user makes a navigation request.
EXAMPLE         Pressing an arrow key.
The navigation nodes on a page form a doubly linked list by means of their Next and Prev entries. The
primary node on a page shall be determined by the optional PresSteps entry in a page dictionary (see
"Table 31 — Entries in a page object").
NOTE 3      An interactive PDF processor needs to respect navigation nodes only when in presentation mode
(see 12.4.4, "Presentations").
Table 165 — Entries in a navigation node dictionary
Key      Type              Value
Type     name              (Optional) The type of PDF object that this dictionary describes; shall be
NavNode for a navigation node dictionary.
NA       dictionary        (Optional) An action (which may be the first in a sequence of actions)
that shall be executed when a user navigates forward.
PA       dictionary        (Optional) An action (which may be the first in a sequence of actions)
that shall be executed when a user navigates backward.
Next     dictionary        (Optional) The next navigation node, if any.

