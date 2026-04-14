# SDD Draft

Generated from:
- `spec/extracted/12.5-annotations.spec.txt`

## Requirements

#### 0.1: 12.5.1            General
An annotation associates an object such as a note, link or rich media with a location on a page of a PDF
document, or provides a way to interact with the user by means of the mouse and keyboard. PDF
includes a wide variety of standard annotation types, described in detail in 12.5.6, "Annotation types".
Many of the standard annotation types may be displayed in either the open or the closed state. When
closed, they appear on the page in some distinctive form, such as an icon, a box, or a rubber stamp,
depending on the specific annotation type. When the user activates the annotation by clicking it, it
exhibits its associated object, such as by opening a popup window displaying a text note ("Figure 77 —
Open annotation") or by playing a sound or a movie.
Figure 77 — Open annotation
Interactive PDF processors may permit the user to navigate through the annotations on a page by
using the keyboard (in particular, the tab key). Beginning with PDF 1.5, PDF producers may make the
navigation order explicit with the optional Tabs entry in a page object (see "Table 31 — Entries in a
page object"). This entry has the following values:
•    R (row order): Annotations shall be visited in rows running horizontally across the page. The
direction within a row is defined by the Direction entry in the viewer preferences dictionary (see
12.2, "Viewer preferences"). The first annotation that shall be visited is the first annotation in the
topmost row. When the end of a row is encountered, the first annotation in the next row shall be
visited.
•    C (column order): Annotations shall be visited in columns running vertically up and down the
page. Columns shall be ordered by the Direction entry in the viewer preferences dictionary (see
12.2, "Viewer preferences"). The first annotation that shall be visited is the one at the top of the
first column. When the end of a column is encountered, the first annotation in the next column
shall be visited.
•    S (structure order): Annotations shall be visited in the order in which they appear in the structure
tree (see 14.7, "Logical structure"). The order for annotations that are not included in the
structure tree is determined in a manner of the interactive PDF processor's choosing.
•    A (annotation array order): All annotations shall be visited in the order in which they appear in
the page Annots array. New in PDF 2.0. (See "Table 31 — Entries in a page object".)
•    W (widgets order): Widget annotations shall be visited in the order in which they appear in the
page Annots array, followed by other annotation types in row order. (See "Table 31 — Entries in

a page object".) New in PDF 2.0. For information about row order, see the R (row order)
description.
These descriptions assume the page is being viewed in the orientation specified by the Rotate entry.
Conceptually, the behaviour of each annotation type may be implemented by a software module called
an annotation handler. A PDF processor shall provide annotation handlers for all of the conforming
annotation types. The set of annotation types is extensible. An interactive PDF processor shall provide
certain expected behaviour for all annotation types that it does not recognise, as documented in 12.5.2,
"Annotation dictionaries".

#### 0.2: 12.5.2            Annotation dictionaries
The optional Annots entry in a page object (see 7.7.3, "Page tree") holds an array of annotation
dictionaries, each representing an annotation associated with the given page. "Table 166 — Entries
common to all annotation dictionaries" shows the required and optional entries that are common to all
annotation dictionaries. The dictionary may contain additional entries specific to a particular
annotation type; see the descriptions of individual annotation types in 12.5.6, "Annotation types" for
details. A given annotation dictionary shall be referenced from the Annots array of only one page. This
requirement applies only to the annotation dictionary itself, not to subsidiary objects, which may be
shared among multiple annotations.
Table 166 — Entries common to all annotation dictionaries
Key              Type            Value
Type             name            (Optional) The type of PDF object that this dictionary describes; if present, shall
be Annot for an annotation dictionary.
Subtype          name            (Required) The type of annotation that this dictionary describes; see "Table 171
— Annotation types" for specific values.
Rect             rectangle       (Required) The annotation rectangle, defining the location of the annotation on
the page in default user space units.
Contents         text string     (Optional) Text that shall be displayed for the annotation or, if this type of
annotation does not display text, an alternative description of the annotation’s
contents in human-readable form. In either case, this text is useful when
extracting the document’s contents in support of accessibility to users with
disabilities or for other purposes (see 14.9.3, "Alternate descriptions"). See
12.5.6, "Annotation types" for more details on the meaning of this entry for each
annotation type.
P                dictionary      (Optional except as noted below; PDF 1.3; not used in FDF files) An indirect
reference to the page object with which this annotation is associated.
This entry shall be present in screen annotations associated with rendition
actions (PDF 1.5; see 12.5.6.18, "Screen annotations" and 12.6.4.14, "Rendition
actions").
NM               text string     (Optional; PDF 1.4) The annotation name, a text string uniquely identifying it
among all the annotations on its page.
M                date or text (Optional; PDF 1.1) The date and time when the annotation was most recently
string       modified. The format should be a date string as described in 7.9.4, "Dates" but
interactive PDF processors shall accept and display a string in any format.
Key        Type         Value
F          integer      (Optional; PDF 1.1) A set of flags specifying various characteristics of the
annotation (see 12.5.3, "Annotation flags"). Default value: 0.
AP         dictionary   (Optional; PDF 1.2) An appearance dictionary specifying how the annotation
shall be presented visually on the page (see 12.5.5, "Appearance streams"). A
PDF writer shall include an appearance dictionary when writing or updating the
PDF file except for the two cases listed below.
Every annotation (including those whose Subtype value is Widget, as used for
form fields), except for the two cases listed below, shall have at least one
appearance dictionary.
•    Annotations where the value of the Rect key consists of an array where the
value at index 1 is equal to the value at index 3 and the value at index 2 is
equal to the value at index 4.
NOTE     (2020) The bullet point above was changed from “or” to “and” in this document
to match requirements in other published ISO PDF standards (such as PDF/A).
•    Annotations whose Subtype value is Popup, Projection or Link.
AS         name         (Required if the appearance dictionary AP contains one or more subdictionaries;
PDF 1.2) The annotation’s appearance state, which selects the applicable
appearance stream from an appearance subdictionary (see 12.5.5, "Appearance
streams").
Border     array        (Optional) An array specifying the characteristics of the annotation’s border,
which shall be drawn as a rounded rectangle.
(PDF 1.0) The array consists of three numbers defining the horizontal corner
radius, vertical corner radius, and border width, all in default user space units. If
the corner radii are 0, the border has square (not rounded) corners; if the
border width is 0, no border is drawn.
(PDF 1.1) The array may have a fourth element, an optional dash array defining a
pattern of dashes and gaps that shall be used in drawing the border. The dash
array shall be specified in the same format as in the line dash pattern parameter
of the graphics state (see 8.4.3.6, "Line dash pattern"). The dash phase shall not
be specified and shall be assumed to be 0.
EXAMPLE           A Border value of [0 0 1 [3 2]] specifies a border 1 unit wide, with
square corners, drawn with 3-unit dashes alternating with 2- unit gaps.
NOTE     (PDF 1.2) The dictionaries for some annotation types (such as free text and
polygon annotations) can include the BS entry. That entry specifies a border
style dictionary that has more settings than the array specified for the Border
entry. If an annotation dictionary includes the BS entry, then the Border entry
is ignored.
Default value: [0 0 1].

Key              Type            Value
C                array           (Optional; PDF 1.1) An array of numbers in the range 0.0 to 1.0, representing a
colour used for the following purposes:
The background of the annotation’s icon when closed
The title bar of the annotation’s popup window
The border of a link annotation
The number of array elements determines the colour space in which the colour
shall be defined:
0     No colour; transparent
1     DeviceGray
3     DeviceRGB
4     DeviceCMYK
StructParent integer             (Required if the annotation is a structural content item; PDF 1.3) The integer key
of the annotation’s entry in the structural parent tree (see 14.7.5.4, "Finding
structure elements from content items").
OC               dictionary      (Optional; PDF 1.5) An optional content group or optional content membership
dictionary (see 8.11, "Optional content") specifying the optional content
properties for the annotation. Before the annotation is drawn, its visibility shall
be determined based on this entry as well as the annotation flags specified in the
F entry (see 12.5.3, "Annotation flags"). If it is determined to be invisible, the
annotation shall not be drawn. (See 8.11.3.3, "Optional content in XObjects and
annotations".)
AF               array of     (Optional; PDF 2.0) An array of one or more file specification dictionaries (7.11.3,
dictionaries "File specification dictionaries") which denote the associated files for this
annotation). See 14.13, "Associated files" and 14.13.9, "Associated files linked to
an annotation dictionary" for more details.
ca               number          (Optional; PDF 2.0) When regenerating the annotation's appearance stream, this
is the opacity value (11.2, "Overview of transparency") that shall be used for all
nonstroking operations on all visible elements of the annotation in its closed
state (including its background and border) but not the popup window that
appears when the annotation is opened.
Default value: 1.0
The specified value shall not be used if the annotation has an appearance stream
(see 12.5.5, "Appearance streams"); in that case, the appearance stream shall
specify any transparency.
If no explicit appearance stream is defined for the annotation, and the processor
is not able to regenerate the appearance, the annotation may be painted by
implementation-dependent means that do not necessarily conform to the PDF
imaging model; in this case, the effect of this entry is implementation-dependent
as well.
Key           Type          Value
CA            number        (Optional; PDF 1.4, PDF 2.0 for non-markup annotations) When regenerating the
annotation's appearance stream, this is the opacity value (11.2, "Overview of
transparency") that shall be used for stroking all visible elements of the
annotation in its closed state, including its background and border, but not the
popup window that appears when the annotation is opened.
If a ca entry is not present in this dictionary, then the value of this CA entry shall
also be used for nonstroking operations as well. Default Value: 1.0
The specified value shall not be used if the annotation has an appearance stream
(12.5.5, "Appearance streams"); in that case, the appearance stream shall specify
any transparency.
If no explicit appearance stream is defined for the annotation, and the processor
is not able to regenerate the appearance, the annotation may be painted by
implementation-dependent means that do not necessarily conform to the PDF
imaging model; in this case, the effect of this entry is implementation-dependent
as well.
BM            name          (Optional; PDF 2.0) The blend mode that shall be used when painting the
annotation onto the page (see 11.3.5, "Blend Mode" and 11.6.3, "Specifying
Blending Colour Space and Blend Mode"). If this key is not present, blending
shall take place using the Normal blend mode. The value shall be a name object,
designating one of the standard blend modes listed in "Table 134 — Standard
separable blend modes" and "Table 135 — Standard non-separable blend
modes" in 11.3.5, "Blend mode".
Lang          text string   (Optional; PDF 2.0) A language identifier overriding the document’s language
identifier to specify the natural language for all text in the annotation except
where overridden by other explicit language specifications (see 14.9.2, "Natural
language specification").
A PDF reader shall render the appearance dictionary without regard to any other keys and values in
the annotation dictionary and shall ignore the values of the C, IC, Border, BS, BE, BM, CA, ca, H, DA, Q,
DS, LE, LL, LLE, and Sy keys.
NOTE      Requiring an appearance dictionary for each annotation ensures the reliable rendering of the
annotations.

#### 0.3: 12.5.3         Annotation flags
The value of the annotation dictionary’s F entry is an integer interpreted as one-bit flags specifying
various characteristics of the annotation. Bit positions within the flag word shall be numbered from
low-order to high-order, with the lowest-order bit numbered 1. "Table 167 — Annotation flags" shows
the meanings of the flags; all other bits of the integer shall be set to 0.

Table 167 — Annotation flags
Bit position     Name                Meaning
1                Invisible           Applies only to annotations which do not belong to one of the standard
annotation types and for which no annotation handler is available. If set, do
not render the unknown annotation and do not print it even if the Print flag is
set. If clear, render such an unknown annotation using an appearance stream
specified by its appearance dictionary, if any (see 12.5.5, "Appearance
streams").
2                Hidden              (PDF 1.2) If set, do not render the annotation or allow it to interact with the
user, regardless of its annotation type or whether an annotation handler is
available.
NOTE 1 In cases where screen space is limited, the ability to hide and show
annotations selectively can be used in combination with appearance
streams (see 12.5.5, "Appearance streams") to render auxiliary popup
information similar in function to online help systems.
3                Print               (PDF 1.2) If set, print the annotation when the page is printed unless the
Hidden flag is also set. If clear, never print the annotation, regardless of
whether it is rendered on the screen. If the annotation does not contain any
appearance streams this flag shall be ignored.
NOTE 2 This can be useful for annotations representing interactive push-buttons,
which would serve no meaningful purpose on the printed page.
4                NoZoom              (PDF 1.3) If set, do not scale the annotation’s appearance to match the
magnification of the page. The location of the annotation on the page (defined
by the upper-left corner of its annotation rectangle) shall remain fixed,
regardless of the page magnification. See further discussion following this
table.
5                NoRotate            (PDF 1.3) If set, do not rotate the annotation’s appearance to match the
rotation of the page. The upper-left corner of the annotation rectangle shall
remain in a fixed location on the page, regardless of the page rotation. See
further discussion following this table.
6                NoView              (PDF 1.3) If set, do not render the annotation on the screen or allow it to
interact with the user. The annotation may be printed (depending on the
setting of the Print flag) but should be considered hidden for purposes of on-
screen display and user interaction.
7                ReadOnly            (PDF 1.3) If set, do not allow the annotation to interact with the user. The
annotation may be rendered or printed (depending on the settings of the
NoView and Print flags) but should not respond to mouse clicks or change its
appearance in response to mouse motions.
This flag shall be ignored for widget annotations; its function is subsumed by
the ReadOnly flag of the associated form field (see "Table 226 — Entries
common to all field dictionaries").
8                Locked              (PDF 1.4) If set, do not allow the annotation to be deleted or its properties
(including position and size) to be modified by the user. However, this flag
does not restrict changes to the annotation’s contents, such as the value of a
form field.
Bit position   Name              Meaning
9              ToggleNoView      (PDF 1.5) If set, invert the interpretation of the NoView flag for annotation
selection and mouse hovering, causing the annotation to be visible when the
mouse pointer hovers over the annotation or when the annotation is selected.
10             LockedContents (PDF 1.7) If set, do not allow the contents of the annotation to be modified by
the user. This flag does not restrict deletion of the annotation or changes to
other annotation properties, such as position and size.
If the NoZoom flag is set, the annotation shall always maintain the same fixed size on the screen and
shall be unaffected by the magnification level at which the page itself is displayed. Similarly, if the
NoRotate flag is set, the annotation shall retain its original orientation on the screen when the page is
rotated (by changing the Rotate entry in the page object; see 7.7.3, "Page tree").
In either case, the annotation’s position is defined by the coordinates of the upper-left corner of its
annotation rectangle, as defined by the Rect entry in the annotation dictionary and interpreted in the
default user space of the page. When the default user space is scaled or rotated, the positions of the
other three corners of the annotation rectangle are different in the altered user space than they were in
the original user space. The PDF processor shall perform this alteration automatically. However, it
shall not actually change the annotation’s Rect entry, which continues to describe the annotation’s
relationship with the unscaled, unrotated user space.
NOTE       "Figure 78 — Coordinate adjustment with the NoRotate flag" shows how an annotation whose
NoRotate flag is set remains upright when the page it is on is rotated 90 degrees clockwise. The
upper-left corner of the annotation remains at the same point in default user space; the
annotation pivots around that point.
Figure 78 — Coordinate adjustment with the NoRotate flag

#### 0.4: 12.5.4          Border styles
An annotation may optionally be surrounded by a border when displayed or printed. If present, the
border shall be drawn completely inside the annotation rectangle. In PDF 1.1, the characteristics of the
border shall be specified by the Border entry in the annotation dictionary ("Table 166 — Entries

common to all annotation dictionaries"). Beginning with PDF 1.2, the border characteristics for some
types of annotations may instead be specified in a border style dictionary designated by the
annotation’s BS entry. Such dictionaries may also be used to specify the width and dash pattern for the
lines drawn by line, square, circle, and ink annotations. "Table 168 — Entries in a border style
dictionary" summarises the contents of the border style dictionary. If neither the Border nor the BS
entry is present, the border shall be drawn as a solid line with a width of 1 point.
Table 168 — Entries in a border style dictionary
Key        Type            Value
Type       name            (Optional) The type of PDF object that this dictionary describes; if
present, shall be Border for a border style dictionary.
W          number          (Optional) The border width in points. If this value is 0, no border shall be
drawn. Default value: 1.
S          name            (Optional) The border style:
S    (Solid) A solid rectangle surrounding the annotation. Default value.
D    (Dashed) A dashed rectangle surrounding the annotation. The dash
pattern may be specified by the D entry.
B    (Beveled) A simulated embossed rectangle that appears to be raised
above the surface of the page.
I    (Inset) A simulated engraved rectangle that appears to be recessed
below the surface of the page.
U    (Underline) A single line along the bottom of the annotation
rectangle.
An interactive PDF processor shall tolerate other border styles that it
does not recognise and shall use the default value (which is S).
D          array           (Optional) A dash array defining a pattern of dashes and gaps that shall be
used in drawing a dashed border (border style D in the S entry). The dash
array shall be specified in the same format as in the line dash pattern
parameter of the graphics state (see 8.4.3.6, "Line dash pattern"). The
dash phase shall not be specified and shall be assumed to be 0.
EXAMPLE           A D entry of [3 2] specifies a border drawn with 3-point dashes
alternating with 2-point gaps.
Default value: [3].
Beginning with PDF 1.5, some annotations (square, circle, and polygon) may have a BE entry, which is
a border effect dictionary that specifies an effect that shall be applied to the border of the annotations.
Beginning with PDF 1.6, free text annotations may also have a BE entry "Table 169 — Entries in a
border effect dictionary" that describes the entries in a border effect dictionary.
Table 169 — Entries in a border effect dictionary
Key      Type          Value
S        name          (Optional) A name representing the border effect to apply. Values are:
C    The border should appear "cloudy"; that is, the border should be
drawn as a series of convex curved line segments in a manner that
simulates the appearance of a cloud. The width and dash array
specified by BS shall be honoured. Default value: S.
S    No effect: the border shall be as described by the annotation
dictionary’s BS entry.
I        number        (Optional; valid only if the value of S is C) A number describing the
intensity of the effect, in the range 0 to 2. Default value: 0.

#### 0.5: 12.5.5         Appearance streams
Beginning with PDF 1.2, an annotation may specify one or more appearance streams as an alternative
to the simple border and colour characteristics available in earlier versions. Appearance streams
enable the annotation to be presented visually in different ways to reflect its interactions with the user.
Each appearance stream is a form XObject (see 8.10, "Form XObjects"): a self-contained content stream
that shall be rendered inside the annotation rectangle.
The algorithm outlined in this subclause shall be used to map from the coordinate system of the
appearance XObject (as defined by its Matrix entry; see "Table 93 — Additional entries specific to a
Type 1 form dictionary") to the annotation’s rectangle in default user space:
Algorithm: appearance streams
1. The appearance’s bounding box (specified by its BBox entry) shall be transformed, using
Matrix, to produce a quadrilateral with arbitrary orientation. The transformed appearance box
is the smallest upright rectangle that encompasses this quadrilateral.
2. A matrix A shall be computed that scales and translates the transformed appearance box to
align with the edges of the annotation’s rectangle (specified by the Rect entry). A maps the
lower-left corner (the corner with the smallest x and y coordinates) and the upper-right corner
(the corner with the greatest x and y coordinates) of the transformed appearance box to the
corresponding corners of the annotation’s rectangle.
3. Matrix shall be concatenated with A to form a matrix AA that maps from the appearance’s
coordinate system to the annotation’s rectangle in default user space:
𝐴𝐴 = 𝑀𝑎𝑡𝑟𝑖𝑥 × 𝐴
The annotation may be further scaled and rotated if either the NoZoom or NoRotate flag is set (see
12.5.3, "Annotation flags"). Any transformation applied to the annotation as a whole shall be applied to
the appearance within it.
Starting with PDF 1.4, an annotation appearance may include transparency. If the appearance’s stream
dictionary does not contain a Group entry, it shall be treated as a non-isolated, non-knockout

transparency group. Otherwise, the isolated and knockout values specified in the group dictionary (see
11.6.6, "Transparency group XObjects") shall be used.
The transparency group shall be composited with a backdrop consisting of the page content along with
any previously painted annotations, using the values of the BM, ca and CA entries in the annotation
dictionary (see "Table 166 — Entries common to all annotation dictionaries") and a soft mask of None.
NOTE 1       If a transparent annotation appearance is painted over an annotation that is drawn without
using an appearance stream, the effect is implementation-dependent. This is because such
annotations are sometimes drawn by means that do not conform to the PDF imaging model. Also,
the effect of highlighting a transparent annotation appearance is implementation-dependent.
An annotation may define as many as three separate appearances:
•    The normal appearance shall be used when the annotation is not interacting with the user. This
appearance is also used for printing the annotation.
•    The rollover appearance shall be used when the user moves the cursor into the annotation’s active
area without pressing the mouse button.
•    The down appearance shall be used when the mouse button is pressed or held down within the
annotation’s active area.
NOTE 2       As used here, the term mouse denotes a generic pointing device that controls the location of a
cursor on the screen and has at least one button that can be pressed, held down, and released.
See 12.6.3, "Trigger events" for further discussion.
The normal, rollover, and down appearances shall be defined in an appearance dictionary, which in
turn is the value of the AP entry in the annotation dictionary (see "Table 166 — Entries common to all
annotation dictionaries"). "Table 170 — Entries in an appearance dictionary" shows the contents of the
appearance dictionary.
Table 170 — Entries in an appearance dictionary
Key     Type                       Value
N       stream or dictionary       (Required) The annotation’s normal appearance.
R       stream or dictionary       (Optional) The annotation’s rollover appearance. Default value: the
value of the N entry.
D       stream or dictionary       (Optional) The annotation’s down appearance. Default value: the
value of the N entry.
Each entry in the appearance dictionary may contain either a single appearance stream or an
appearance subdictionary. In the latter case, the subdictionary shall define multiple appearance
streams corresponding to different appearance states of the annotation.
EXAMPLE           An annotation representing an interactive check box may have two appearance states named On and Off. Its
appearance dictionary may be defined as
/AP      <</N <</On formXObject1
/Off formXObject2
>>
/D <</On formXObject3
/Off formXObject4
>>
>>
where formXObject1 and formXObject2 define the check box’s normal appearance in its checked and
unchecked states, and formXObject3 and formXObject4 provide visual feedback, such as emboldening
its outline, when the user clicks it. (No R entry is defined because no special appearance is needed
when the user moves the cursor over the check box without pressing the mouse button.) The choice
between the checked and unchecked appearance states is determined by the AS entry in the
annotation dictionary (see "Table 166 — Entries common to all annotation dictionaries").
If a PDF processor does not have native support for a particular annotation type, the PDF processor
shall render the annotation with its normal (N) appearance. PDF processors shall also attempt to
provide reasonable behaviour (such as displaying nothing) if an annotation’s AS entry designates an
appearance state for which no appearance is defined in the appearance dictionary.
For convenience in managing appearance streams that are used repeatedly, the AP entry in a PDF
document’s name dictionary (see 7.7.4, "Name dictionary") may contain a name tree mapping name
strings to appearance streams. The name strings have no standard meanings; no PDF objects may refer
to appearance streams by name.

#### 0.6: 12.5.6.1         General
PDF supports the standard annotation types listed in "Table 171 — Annotation types". The following
subclauses describe each of these types in detail.
The values in the first column of "Table 171 — Annotation types" represent the value of the annotation
dictionary’s Subtype entry. The third column indicates whether the annotation is a markup
annotation, as described in 12.5.6.2, "Markup annotations" The subclause also provides more
information about the value of the Contents entry for different annotation types.
Table 171 — Annotation types
Annotation type        Description                              Markup        Discussed in subclause
Text                   Text annotation                          Yes           12.5.6.4, "Text annotations"
Link                   Link annotation                          No            12.5.6.5, "Link annotations"
FreeText               (PDF 1.3) Free text annotation           Yes           12.5.6.6, "Free text annotations"
Line                   (PDF 1.3) Line annotation                Yes           12.5.6.7, "Line annotations"
Square                 (PDF 1.3) Square annotation              Yes           12.5.6.8, "Square and circle
annotations"
Circle                 (PDF 1.3) Circle annotation              Yes           12.5.6.8, "Square and circle
annotations"
Polygon                (PDF 1.5) Polygon annotation             Yes           12.5.6.9, "Polygon and polyline
annotations"

Annotation type       Description                                Markup        Discussed in subclause
PolyLine              (PDF 1.5) Polyline annotation              Yes           12.5.6.9, "Polygon and polyline
annotations"
Highlight             (PDF 1.3) Highlight annotation             Yes           12.5.6.10, "Text markup annotations"
Underline             (PDF 1.3) Underline annotation             Yes           12.5.6.10, "Text markup annotations"
Squiggly              (PDF 1.4) Squiggly-underline               Yes           12.5.6.10, "Text markup annotations"
annotation
StrikeOut             (PDF 1.3) Strikeout annotation             Yes           12.5.6.10, "Text markup annotations"
Caret                 (PDF 1.5) Caret annotation                 Yes           12.5.6.11, "Caret annotations"
Stamp                 (PDF 1.3) Rubber stamp                     Yes           12.5.6.12, "Rubber stamp annotations"
annotation
Ink                   (PDF 1.3) Ink annotation                   Yes           12.5.6.13, "Ink annotations"
Popup                 (PDF 1.3) Popup annotation                 No            12.5.6.14, "Popup annotations"
FileAttachment        (PDF 1.3) File attachment                  Yes           12.5.6.15, "File attachment
annotation                                               annotations"
Sound                 (PDF 1.2; deprecated in PDF 2.0)           Yes           12.5.6.16, "Sound annotations"
Sound annotation
Movie                 (PDF 1.2; deprecated in PDF 2.0)           No            12.5.6.17, "Movie annotations"
Movie annotation
Screen                (PDF 1.5) Screen annotation                No            12.5.6.18, "Screen annotations"
Widget                (PDF 1.2) Widget annotation                No            12.5.6.19, "Widget annotations"
PrinterMark           (PDF 1.4) Printer’s mark                   No            12.5.6.20, "Printer’s mark annotations"
annotation
TrapNet               (PDF 1.3; deprecated in PDF 2.0)           No            12.5.6.21, "Trap network annotations"
Trap network annotation
Watermark             (PDF 1.6) Watermark annotation             No            12.5.6.22, "Watermark annotations"
3D                    (PDF 1.6) 3D annotation                    No            13.6.2, "3D Annotations"
Redact                (PDF 1.7) Redact annotation                Yes           12.5.6.23, "Redaction annotations"
Projection            (PDF 2.0) Projection annotation            Yes           12.5.6.24, "Projection annotations"
RichMedia             (PDF 2.0) RichMedia annotation             No            13.7.2, "RichMedia annotations"

#### 0.7: 12.5.6.2          Markup annotations
As mentioned in 12.5.2, "Annotation dictionaries", the meaning of an annotation’s Contents entry
varies by annotation type. Typically, it is the text that shall be displayed for the annotation or, if the
annotation does not display text, an alternative description of the annotation’s contents in human-
readable form. In either case, the Contents entry is useful when extracting the document’s contents in
support of accessibility to users with disabilities or for other purposes (see 14.9.3, "Alternate
descriptions").
Many annotation types are defined as markup annotations because they are used primarily to mark up
PDF documents (see "Table 172 — Additional entries in an annotation dictionary specific to markup
annotations"). These annotations have text that appears as part of the annotation and may be
displayed in other ways by an interactive PDF processor, such as in a comments pane. Markup
annotations may be divided into the following groups:
•    Free text annotations display text directly on the page. The annotation’s Contents entry specifies
the displayed text.
•    Most other markup annotations have an associated popup window that may contain text. The
annotation’s Contents entry specifies the text that shall be displayed when the popup window is
opened. These include text, line, square, circle, polygon, polyline, highlight, underline, squiggly-
underline, strikeout, rubber stamp, caret, ink, and file attachment annotations.
•    Sound annotations do not have a popup window but may also have associated text specified by
the Contents entry.
•    Projection annotations valid within the context of an associated run-time environment, such as an
activated 3D model (see 12.5.6.24, "Projection annotations").
NOTE 1     The RC entry performs a similar role to the Contents entry except that the content’s textual
representation is formatted. When both Contents and RC entries are present, it is expected that
the contents of both entries are textually equivalent.
When separating text into paragraphs, a CARRIAGE RETURN (0Dh) shall be used and not, for example,
a LINE FEED character (0Ah).
NOTE 2     A subset of markup annotations is called text markup annotations (12.5.6.10, "Text markup
annotations").
The remaining annotation types are not considered markup annotations:
•    The popup annotation type shall not appear by itself; it shall be associated with a markup
annotation that uses it to display text.
NOTE 3     The Contents entry for a popup annotation is relevant only if it has no parent; in that case, it
represents the text of the annotation.
•    For all other annotation types (Link, Movie, Widget, RichMedia, PrinterMark, and TrapNet),
the Contents entry may provide an alternative representation of the annotation’s contents in
human-readable form, which is useful when extracting the document’s contents in support of
accessibility to users with disabilities or for other purposes (see 14.9.3, "Alternate descriptions").
"Table 172 — Additional entries in an annotation dictionary specific to markup annotations" lists
annotation dictionary entries that apply to all markup annotations.

Table 172 — Additional entries in an annotation dictionary specific to markup annotations
Key                 Type            Value
T                   text string     (Optional; PDF 1.1) The text label that shall be displayed in the title
bar of the annotation’s popup window when open and active. This
entry shall identify the user who added the annotation.
Popup               dictionary      (Optional; PDF 1.3) An indirect reference to a popup annotation for
entering or editing the text associated with this annotation.
RC                  text string     (Optional; PDF 1.5) A rich text string (see Adobe XML Architecture,
or text         XML Forms Architecture (XFA) Specification, version 3.3) that shall be
stream          displayed in the popup window when the annotation is opened.
CreationDate        date            (Optional; PDF 1.5) The date and time (7.9.4, "Dates") when the
annotation was created.
IRT                 dictionary      (Required if an RT entry is present, otherwise optional; PDF 1.5) A
reference to the annotation that this annotation is "in reply to." Both
annotations shall be on the same page of the document. The
relationship between the two annotations shall be specified by the
RT entry.
If this entry is present in an FDF file (see 12.7.8, "Forms data
format"), its type shall not be a dictionary but a text string containing
the contents of the NM entry of the annotation being replied to, to
allow for a situation where the annotation being replied to is not in
the same FDF file.
Subj                text string     (Optional; PDF 1.5) Text representing a short description of the
subject being addressed by the annotation.
RT                  name            (Optional; meaningful only if IRT is present; PDF 1.6) A name
specifying the relationship (the "reply type") between this annotation
and one specified by IRT. Valid values are:
R        The annotation is considered a reply to the annotation
specified by IRT. Interactive PDF processors shall not display
replies to an annotation individually but together in the form
of threaded comments.
Group The annotation shall be grouped with the annotation
specified by IRT; see the discussion following this Table.
Default value: R.
Key              Type          Value
IT               name          (Optional; PDF 1.6) A name describing the intent of the markup
annotation. Intents allow interactive PDF processors to distinguish
between different uses and behaviours of a single markup annotation
type. If this entry is not present or its value is the same as the
annotation type, the annotation shall have no explicit intent and
should behave in a generic manner in an interactive PDF processor.
Free text annotations ("Table 177 — Additional entries specific to a
free text annotation"), line annotations ("Table 178 — Additional
entries specific to a line annotation"), polygon annotations ("Table
181 — Additional entries specific to a polygon or polyline
annotation"), (PDF 1.7) polyline annotations ("Table 181 —
Additional entries specific to a polygon or polyline annotation") and
stamp annotations (“Table 184 — Additional entries specific to a
rubber stamp annotation") have defined intents, whose values are
enumerated in the corresponding tables.
In PDF 1.6, a set of annotations may be grouped so that they function as a single unit when a user
interacts with them. The group consists of a primary annotation, which shall not have an IRT entry,
and one or more subordinate annotations, which shall have an IRT entry that refers to the primary
annotation and an RT entry whose value is Group.
Some entries in the primary annotation are treated as "group attributes" that shall apply to the group
as a whole; the corresponding entries in the subordinate annotations shall be ignored. These entries
are Contents (or RC and DS), M, C, T, Popup, CreationDate, Subj, and Open. Operations that
manipulate any annotation in a group, such as movement, cut, and copy, shall be treated by interactive
PDF processors as acting on the entire group.
NOTE 4      A primary annotation can have replies that are not subordinate annotations; that is, that do not
have an RT value of Group.
2D markup annotations may be applied to specific views of the 3D artwork, using the ExData entry to
identify the 3D annotation and the 3D view in that annotation. "Table 173 — Additional entries in
markup annotation dictionaries specific to external data" lists additional markup annotation dictionary
entries that apply to external data.

Table 173 — Additional entries in markup annotation dictionaries specific to external data
Key        Type             Value
ExData     dictionary       (Optional; PDF 1.7) An external data dictionary specifying data that shall be
associated with the annotation. This dictionary contains the following entries:
Type             (Required) shall be ExData.
NOTE     (2020) This document clarified that the Type key is always required.
Subtype           (Required) a name specifying the type of data that the
markup annotation shall be associated with. Values are:
- Markup3D (PDF 1.7) for a 3D comment. Additional
entries in this dictionary are listed in "Table 309 —
Additional entries specific to a 3D annotation"
- 3DM (PDF 2.0) for a 3D measurement. Additional entries
in this dictionary are listed in "Table 331 — Additional
entries in a 3D measurement/markup dictionary for a
3D comment note and "Table 332 — Entries in the
external data dictionary of a projection annotation".
- MarkupGeo (PDF 2.0) for geospatial markup. This
Subtype does not define any additional entries.

#### 0.8: 12.5.6.3          Annotation states
Beginning with PDF 1.5, annotations may have an author-specific state associated with them. The state
is not specified in the annotation itself but in a separate text annotation that refers to the original
annotation by means of its IRT ("in reply to") entry (see "Table 176 — Additional entries specific to a
link annotation"). States shall be grouped into a number of state models, as shown in "Table 174 —
Annotation states".
Table 174 — Annotation states
State model       State             Description
Marked            Marked            The annotation has been marked by the user.
Unmarked          The annotation has not been marked by the user (the default).
Review            Accepted          The user agrees with the change.
Rejected          The user disagrees with the change.
Cancelled         The change has been cancelled.
Completed         The change has been completed.
None              The user has indicated nothing about the change (the default).
State changes made by a user shall be indicated in a text annotation with the following entries:
•     The T entry (see "Table 172 — Additional entries in an annotation dictionary specific to markup
annotations") shall specify the user.
•   The IRT entry (see "Table 176 — Additional entries specific to a link annotation") shall refer to
the original annotation.
•   State and StateModel (see "Table 175 — Additional entries specific to a text annotation") shall
update the state of the original annotation for the specified user.
Additional state changes shall be made by adding text annotations in reply to the previous reply for a
given user.

#### 0.9: 12.5.6.4         Text annotations
A text annotation represents a "sticky note" attached to a point in the PDF document. When closed, the
annotation shall appear as an icon; when open, it shall display a popup window containing the text of
the note in a font and size chosen by the interactive PDF processor. Text annotations shall not scale and
rotate with the page; they shall behave as if the NoZoom and NoRotate annotation flags (see "Table 167
— Annotation flags") were always set. "Table 175 — Additional entries specific to a text annotation"
shows the annotation dictionary entries specific to this type of annotation.
Table 175 — Additional entries specific to a text annotation
Key            Type            Value
Subtype        name            (Required) The type of annotation that this dictionary describes; shall
be Text for a text annotation.
Open           boolean         (Optional) A flag specifying whether the annotation shall initially be
displayed open. Default value: false (closed).
Name           name            (Optional) The name of an icon that shall be used in displaying the
annotation. Interactive PDF processors shall provide predefined icon
appearances for at least the following standard names:
Comment, Key, Note, Help, NewParagraph, Paragraph, Insert
Additional names may be supported as well. Default value: Note.
State          text string     (Optional; PDF 1.5) The state to which the original annotation shall be
set; see 12.5.6.3, "Annotation states".
Default: Unmarked if StateModel is Marked; None if StateModel is
Review.
StateModel text string         (Required if State is present, otherwise optional; PDF 1.5) The state
model corresponding to State; see 12.5.6.3, "Annotation states"
EXAMPLE          The following example shows the definition of a text annotation.
22 0 obj
<</Type /Annot
/Subtype /Text
/Rect [266 116 430 204]
/Contents (The quick brown fox ate the lazy mouse .)
>>
endobj

#### 0.10: 12.5.6.5         Link annotations
A link annotation represents either a hypertext link to a destination elsewhere in the document (see
12.3.2, "Destinations") or an action to be performed (12.6, "Actions"). "Table 176 — Additional entries

specific to a link annotation" shows the annotation dictionary entries specific to this type of
annotation.
Table 176 — Additional entries specific to a link annotation
Key              Type             Value
Subtype          name             (Required) The type of annotation that this dictionary describes; shall be
Link for a link annotation.
A                dictionary       (Optional; PDF 1.1) An action that shall be performed when the link
annotation is activated (see 12.6, "Actions").
Dest             array, name    (Optional; not permitted if an A entry is present) A destination that shall be
or byte string displayed when the annotation is activated (12.3.2, "Destinations").
H                name             (Optional; PDF 1.2) The annotation’s highlighting mode, the visual effect
that shall be used when the mouse button is pressed or held down inside
its active area:
N (None) No highlighting.
I     (Invert) Invert the contents of the annotation rectangle.
O     (Outline) Invert the annotation’s border.
P     (Push) Display the annotation as if it were being pushed below the
surface of the page.
Default value: I.
PA               dictionary       (Optional; PDF 1.3) A URI action (see 12.6.4.8, "URI actions") formerly
associated with this annotation. When a PDF processor changes an
annotation from a URI (12.6.4.8, "URI actions") to a go-to action (12.6.4.2,
"Go-To actions"), it may use this entry to save the data from the original
URI action so that it can be changed back in case the target page for the
go-to action is subsequently deleted.
QuadPoints array                  (Optional; PDF 1.6) An array of 8 × 𝑛 numbers specifying the coordinates
of n quadrilaterals in default user space that comprise the region in which
the link should be activated. The coordinates for each quadrilateral are
given in the order:
𝑥1 𝑦1 𝑥2 𝑦2 𝑥3 𝑦3 𝑥4 𝑦4
specifying the four vertices of the quadrilateral in counterclockwise order.
For orientation purposes, such as when applying an underline border
style, the bottom of a quadrilateral is the line formed by (x1, y1) and (x2, y2).
If this entry is not present, or the PDF processor does not recognise it, or if
any coordinates in the QuadPoints array lie outside the region specified
by Rect then the activation region for the link annotation shall be defined
by its Rect entry.
NOTE     The last paragraph above was clarified in this document (2020).
BS               dictionary       (Optional; PDF 1.6) A border style dictionary (see "Table 168 — Entries in
a border style dictionary") specifying the line width and dash pattern that
shall be used in drawing the annotation’s border.
EXAMPLE            The following example shows a link annotation that jumps to a destination elsewhere in the document.
93 0 obj
<</Type /Annot
/Subtype /Link
/Rect [71 717 190 734]
/Border [16 16 1]
/Dest [3 0 R /FitR –4 399 199 533]
>>
endobj

#### 0.11: 12.5.6.6         Free text annotations
A free text annotation (PDF 1.3) displays text directly on the page. Unlike an ordinary text annotation
(see 12.5.6.4, "Text annotations"), a free text annotation has no open or closed state; instead of being
displayed in a popup window, the text shall be always visible. "Table 177 — Additional entries specific
to a free text annotation" shows the annotation dictionary entries specific to this type of annotation.
Subclause 12.7.4.3, "Variable text", describes the process of using these entries to generate the
appearance of the text in these annotations.
Table 177 — Additional entries specific to a free text annotation
Key         Type          Value
Subtype name              (Required) The type of annotation that this dictionary describes; shall be
FreeText for a free text annotation.
DA          string        (Required) The default appearance string that shall be used in formatting the text
(see 12.7.4.3, "Variable text").
The annotation dictionary’s AP entry, if present, shall take precedence over the
DA entry (see “Table 170 — Entries in an appearance dictionary” and 12.5.5,
“Appearance streams”).
Q           integer       (Optional; PDF 1.4) A code specifying the form of quadding (justification)
that shall be used in displaying the annotation’s text:
0     Left-justified
1     Centred
2     Right-justified
Default value: 0 (left-justified).
RC          text string   (Optional; PDF 1.5) A rich text string (see Adobe XML Architecture, XML Forms
or text       Architecture (XFA) Specification, version 3.3) that shall be used to generate the
stream        appearance of the annotation.
NOTE    As freetext annotations do not have an open state this cannot apply to the
popup window as described for the RC key in "Table 172 — Additional entries
in an annotation dictionary specific to markup annotations".
DS          text string   (Optional; PDF 1.5) A default style string, as described in Adobe XML Architecture,
XML Forms Architecture (XFA) Specification, version 3.3.
CL          array         (Optional; meaningful only if IT is FreeTextCallout; PDF 1.6) An array of four or six
numbers specifying a callout line attached to the free text annotation. Six
numbers [x1 y1 x2 y2 x3 y3] represent the starting, knee point, and ending
coordinates of the line in default user space, as shown in "Figure 79 — Free text
annotation with callout". Four numbers [x1 y1 x2 y2] represent the starting and
ending coordinates of the line.

Key         Type            Value
IT          name            (Optional; PDF 1.6) A name describing the intent of the free text annotation (see
also the IT entry in "Table 172 — Additional entries in an annotation dictionary
specific to markup annotations"). The following values shall be valid:
FreeText                 The annotation is intended to function as a plain free-text
annotation. A plain free-text annotation is also known as
a text box comment.
FreeTextCallout          The annotation is intended to function as a callout. The
callout is associated with an area on the page through the
callout line specified in CL.
FreeTextTypeWriter       The annotation is intended to function as a click-to-type
or typewriter object and no callout line is drawn.
Default value: FreeText
BE          dictionary      (Optional; PDF 1.6) A border effect dictionary (see "Table 169 — Entries in a
border effect dictionary") used in conjunction with the border style dictionary
specified by the BS entry.
RD          rectangle       (Optional; PDF 1.6) A set of four numbers describing the numerical differences
between two rectangles: the Rect entry of the annotation and a rectangle
contained within that rectangle. The inner rectangle is where the annotation’s
text should be displayed. Any border styles and/or border effects specified by BS
and BE entries, respectively, shall be applied to the border of the inner rectangle.
The four numbers correspond to the differences in default user space between
the left, top, right, and bottom coordinates of Rect and those of the inner
rectangle, respectively. Each value shall be greater than or equal to 0. The sum of
the top and bottom differences shall be less than the height of Rect, and the sum
of the left and right differences shall be less than the width of Rect.
BS          dictionary      (Optional; PDF 1.6) A border style dictionary (see "Table 168 — Entries in a
border style dictionary") specifying the line width and dash pattern that shall be
used in drawing the annotation’s border.
LE          name            (Optional; meaningful only if CL is present; PDF 1.6) A name specifying the line
ending style that shall be used in drawing the callout line specified in CL. The
name shall specify the line ending style for the endpoint defined by the pairs of
coordinates (x1, y1). "Table 179 — Line ending styles" shows the possible line
ending styles.
Default value: None.
Free text with callouts
x2, y2
x3, y3
x1, y1
Figure 79 — Free text annotation with callout

#### 0.12: 12.5.6.7       Line annotations
The purpose of a line annotation (PDF 1.3) is to display a single straight line on the page. When opened,
it shall display a popup window containing the text of the associated note. "Table 178 — Additional
entries specific to a line annotation" shows the annotation dictionary entries specific to this type of
annotation.
Table 178 — Additional entries specific to a line annotation
Key        Type       Value
Subtype    name       (Required) The type of annotation that this dictionary describes; shall be Line for a line
annotation.
L          array      (Required) An array of four numbers, [x1 y1 x2 y2], specifying the starting and ending
coordinates of the line in default user space.
If the LL entry is present, this value shall represent the endpoints of the leader lines
rather than the endpoints of the line itself; see "Figure 80 — Leader lines".
BS         dictionary (Optional) A border style dictionary (see "Table 168 — Entries in a border style
dictionary") specifying the width and dash pattern that shall be used in drawing the
line.
LE         array      (Optional; PDF 1.4) An array of two names specifying the line ending styles that shall be
used in drawing the line. The first and second elements of the array shall specify the
line ending styles for the endpoints defined, respectively, by the first and second pairs
of coordinates, (x1, y1 ) and (x2, y2 ), in the L array. "Table 179 — Line ending styles"
shows the permitted values. Default value: [ /None /None ].
IC         array      (Optional; PDF 1.4) An array of numbers in the range 0.0 to 1.0 specifying the interior
colour that shall be used to fill the annotation’s line endings (see "Table 179 — Line
ending styles"). The number of array elements shall determine the colour space in
which the colour is defined:
0    No colour; transparent
1    DeviceGray
3    DeviceRGB
4    DeviceCMYK
LL         number     (Required if LLE is present, otherwise optional; PDF 1.6) The length of leader lines in
default user space that extend from each endpoint of the line perpendicular to the line
itself, as shown in "Figure 80 — Leader lines". A positive value shall mean that the
leader lines appear in the direction that is clockwise when traversing the line from its
starting point to its ending point (as specified by L); a negative value shall indicate the
opposite direction.
Default value: 0 (no leader lines).
LLE        number     (Optional; PDF 1.6) A non-negative number that shall represents the length of leader
line extensions that extend from the line proper 180 degrees from the leader lines, as
shown in "Figure 80 — Leader lines".
Default value: 0 (no leader line extensions).

Key          Type         Value
Cap          boolean      (Optional; PDF 1.6) If true, the text specified by the Contents or RC entries shall be
replicated as a caption in the appearance of the line, as shown in "Figure 81 — Lines
with captions appearing as part of the line" and "Figure 82 — Line with a caption
appearing as part of the offset". The text shall be rendered in a manner appropriate to
the content, taking into account factors such as writing direction.
Default value: false.
IT           name         (Optional; PDF 1.6) A name describing the intent of the line annotation (see also "Table
172 — Additional entries in an annotation dictionary specific to markup annotations").
Valid values shall be LineArrow, which means that the annotation is intended to
function as an arrow, and LineDimension, which means that the annotation is intended
to function as a dimension line.
LLO          number       (Optional; PDF 1.7) A non-negative number that shall represent the length of the leader
(capital                  line offset, which is the amount of empty space between the endpoints of the
letters                   annotation and the beginning of the leader lines.
LLO)
CP           name         (Optional; meaningful only if Cap is true; PDF 1.7) A name describing the annotation’s
caption positioning. Valid values are Inline, meaning the caption shall be centred inside
the line, and Top, meaning the caption shall be on top of the line.
Default value: Inline
Measure dictionary (Optional; PDF 1.7) A measure dictionary (see "Table 266 — Entries in a measure
dictionary") that shall specify the scale and units that apply to the line annotation.
CO           array        (Optional; meaningful only if Cap is true; PDF 1.7) An array of two numbers that shall
(capital                  specify the offset of the caption text from its normal position. The first value shall be
letters                   the horizontal offset along the annotation line from its midpoint, with a positive value
CO)                       indicating offset to the right and a negative value indicating offset to the left. The
second value shall be the vertical offset perpendicular to the annotation line, with a
positive value indicating a shift up and a negative value indicating a shift down.
Default value: [0, 0] (no offset from normal positioning)
Figure 80 — Leader lines
"Figure 81 — Lines with captions appearing as part of the line" illustrates the effect of including a
caption to a line annotation, which is specified by setting Cap to true.
Figure 81 — Lines with captions appearing as part of the line
"Figure 82 — Line with a caption appearing as part of the offset" illustrates the effect of applying a
caption to a line annotation that has a leader offset.

Figure 82 — Line with a caption appearing as part of the offset
Table 179 — Line ending styles
Name             Appearance                       Description
Square                                            A square filled with the annotation’s interior colour, if any
Circle                                            A circle filled with the annotation’s interior colour, if any
Diamond                                           A diamond shape filled with the annotation’s interior colour, if any
OpenArrow                                         Two short lines meeting in an acute angle to form an open
arrowhead
ClosedArrow                                       Two short lines meeting in an acute angle as in the OpenArrow style
and connected by a third line to form a triangular closed arrowhead
filled with the annotation’s interior colour, if any
None                                              No line ending
Butt                                              (PDF 1.5) A short line at the endpoint perpendicular to the line itself
ROpenArrow                                        (PDF 1.5) Two short lines in the reverse direction from OpenArrow
RClosedArrow                                      (PDF 1.5) A triangular closed arrowhead in the reverse direction
from ClosedArrow
Slash                                             (PDF 1.6) A short line at the endpoint approximately 30 degrees
clockwise from perpendicular to the line itself

#### 0.13: 12.5.6.8          Square and circle annotations
Square and circle annotations (PDF 1.3) shall display, respectively, a rectangle or an ellipse on the page.
When opened, they shall display a popup window containing the text of the associated note. The
rectangle or ellipse shall be inscribed within the annotation rectangle defined by the annotation
dictionary’s Rect entry (see "Table 170 — Entries in an appearance dictionary").
"Figure 83 — Square and circle annotations" shows two annotations, each with a border width of 18
points. Despite the names square and circle, the width and height of the annotation rectangle need not
be equal. "Table 180 — Additional entries specific to a square or circle annotation" shows the
annotation dictionary entries specific to these types of annotations.
Figure 83 — Square and circle annotations
Table 180 — Additional entries specific to a square or circle annotation
Key         Type           Value
Subtype     name           (Required) The type of annotation that this dictionary describes; shall
be Square or Circle for a square or circle annotation, respectively.
BS          dictionary     (Optional) A border style dictionary (see "Table 168 — Entries in a
border style dictionary") specifying the line width and dash pattern
that shall be used in drawing the rectangle or ellipse.
IC          array          (Optional; PDF 1.4) An array of numbers that shall be in the range 0.0
to 1.0 and shall specify the interior colour with which to fill the
annotation’s rectangle or ellipse. The number of array elements
determines the colour space in which the colour shall be defined:
0     No colour; transparent
1     DeviceGray
3     DeviceRGB
4     DeviceCMYK
BE          dictionary     (Optional; PDF 1.5) A border effect dictionary describing an effect
applied to the border described by the BS entry (see "Table 169 —
Entries in a border effect dictionary").
RD          rectangle      (Optional; PDF 1.5) A set of four numbers that shall describe the
numerical differences between two rectangles: the Rect entry of the
annotation and the actual boundaries of the underlying square or
circle. Such a difference may occur in situations where a border effect
(described by BE) causes the size of the Rect to increase beyond that
of the square or circle.
The four numbers shall correspond to the differences in default user
space between the left, top, right, and bottom coordinates of Rect and
those of the square or circle, respectively. Each value shall be greater
than or equal to 0. The sum of the top and bottom differences shall be
less than the height of Rect, and the sum of the left and right
differences shall be less than the width of Rect.

#### 0.14: 12.5.6.9           Polygon and polyline annotations
Polygon annotations (PDF 1.5) display closed polygons on the page. Such polygons may have many
vertices connected by straight lines. Polyline annotations (PDF 1.5) are similar to polygons, except that
the first and last vertex are not implicitly connected.
Table 181 — Additional entries specific to a polygon or polyline annotation
Key             Type            Value
Subtype         name            (Required) The type of annotation that this dictionary describes; shall
be Polygon or PolyLine for a polygon or polyline annotation,
respectively.
Vertices        array           (Required unless a Path key is present, in which case it shall be
ignored) An array of numbers specifying the alternating horizontal
and vertical coordinates, respectively, of each vertex, in default user
space.
LE              array           (Optional; meaningful only for polyline annotations) An array of two
names that shall specify the line ending styles. The first and second
elements of the array shall specify the line ending styles for the
endpoints defined, respectively, by the first and last pairs of
coordinates in the Vertices array. "Table 179 — Line ending styles"
shows the allowed values. Default value: [/None /None].
BS              dictionary      (Optional) A border style dictionary (see "Table 168 — Entries in a
border style dictionary") specifying the width and dash pattern that
shall be used in drawing the line.
IC              array           (Optional) An array of numbers that shall be in the range 0.0 to 1.0
and shall specify the interior color with which to fill the annotation’s
line endings (see "Table 179 — Line ending styles"). The number of
array elements determines the colour space in which the colour shall
be defined:
0     No colour; transparent
1     DeviceGray
3     DeviceRGB
4     DeviceCMYK
For Polyline annotations, the value of the IC key is used to fill only the
line ending. However, for Polygon annotations, the value of the IC key
is used to fill the entire shape, much as the F operator would fill a
shape in a content stream.
BE              dictionary      (Optional; meaningful only for polygon annotations) A border effect
dictionary that shall describe an effect applied to the border
described by the BS entry (see "Table 169 — Entries in a border
effect dictionary").
Key           Type         Value
IT            name         (Optional; PDF 1.6) A name that shall describe the intent of the
polygon or polyline annotation (see also "Table 172 — Additional
entries in an annotation dictionary specific to markup annotations").
The following values shall be valid:
PolygonCloud            The annotation is intended to function as a
cloud object.
PolyLineDimension       (PDF 1.7) The polyline annotation is intended
to function as a dimension.
PolygonDimension        (PDF 1.7) The polygon annotation is intended
to function as a dimension.
Measure       dictionary   (Optional; PDF 1.7) A measure dictionary (see "Table 266 — Entries
in a measure dictionary") that shall specify the scale and units that
apply to the annotation.
Path          array        (Optional; PDF 2.0) An array of n arrays, each supplying the operands
for a path building operator (m, l or c).
If this key is present the Vertices key shall not be present.
Each of the n arrays shall contain pairs of values specifying the points
(x and y values) for a path drawing operation.
The first array shall be of length 2 and specifies the operand of a
moveto operator which establishes a current point.
Subsequent arrays of length 2 specify the operands of lineto
operators. Arrays of length 6 specify the operands for curveto
operators.
Each array is processed in sequence to construct the path.
The current graphics state shall control the path width, dash pattern,
etc.

#### 0.15: 12.5.6.10        Text markup annotations
Text markup annotations shall appear as highlights, underlines, strikeouts (all PDF 1.3), or jagged
("squiggly") underlines (PDF 1.4) in the text of a document. When opened, they shall display a popup
window containing the text of the associated note. "Table 182 — Additional entries specific to text
markup annotations" shows the annotation dictionary entries specific to these types of annotations.
Table 182 — Additional entries specific to text markup annotations
Key             Type         Value
Subtype         name         (Required) The type of annotation that this dictionary describes;
shall be Highlight, Underline, Squiggly, or StrikeOut for a highlight,
underline, squiggly-underline, or strikeout annotation,
respectively.

Key                Type             Value
QuadPoints         array            (Required) An array of 8 × 𝑛 numbers specifying the coordinates
of n quadrilaterals in default user space. Each quadrilateral shall
encompasses a word or group of contiguous words in the text
underlying the annotation. The coordinates for each quadrilateral
shall be given in the order:
𝑥1 𝑦1 𝑥2 𝑦2 𝑥3 𝑦3 𝑥4 𝑦4
specifying the quadrilateral’s four vertices in counterclockwise
order (see "Figure 84 — QuadPoints specification"). The text shall
be oriented with respect to the edge connecting points (x1, y1) and
(x2, y2).
Figure 84 — QuadPoints specification

#### 0.16: 12.5.6.11         Caret annotations
A caret annotation (PDF 1.5) is a visual symbol that indicates the presence of text edits. "Table 183 —
Additional entries specific to a caret annotation" lists the entries specific to caret annotations.
Table 183 — Additional entries specific to a caret annotation
Key             Type             Value
Subtype         name             (Required) The type of annotation that this dictionary describes; shall
be Caret for a caret annotation.
RD              rectangle        (Optional; PDF 1.5) A set of four numbers that shall describe the
numerical differences between two rectangles: the Rect entry of the
annotation and the actual boundaries of the underlying caret. Such a
difference can occur. When a paragraph symbol specified by Sy is
displayed along with the caret.
The four numbers shall correspond to the differences in default user
space between the left, top, right, and bottom coordinates of Rect and
those of the caret, respectively. Each value shall be greater than or
equal to 0. The sum of the top and bottom differences shall be less
than the height of Rect, and the sum of the left and right differences
shall be less than the width of Rect.
Key          Type         Value
Sy           name         (Optional) A name specifying a symbol that shall be associated with
the caret:
P        A new paragraph symbol (¶) shall be associated with the
caret.
None No symbol shall be associated with the caret.
Default value: None.

#### 0.17: 12.5.6.12        Rubber stamp annotations
A rubber stamp annotation (PDF 1.3) displays text or graphics intended to look as if they were stamped
on the page with a rubber stamp. When opened, it shall display a popup window containing the text of
the associated note. "Table 184 — Additional entries specific to a rubber stamp annotation" shows the
annotation dictionary entries specific to this type of annotation.
Table 184 — Additional entries specific to a rubber stamp annotation
Key          Type         Value
Subtype      name         (Required) The type of annotation that this dictionary describes; shall
be Stamp for a rubber stamp annotation.
Name         name         (Optional) The name of an icon that shall be used in displaying the
annotation. PDF writers should include this entry and PDF readers
should provide predefined icon appearances for at least the following
standard names:
Approved, Experimental, NotApproved, AsIs, Expired,
NotForPublicRelease, Confidential, Final, Sold, Departmental,
ForComment, TopSecret, Draft, ForPublicRelease
Additional names may be supported as well. Default value: Draft.
If the IT key is present and its value is not Stamp, this Name key shall
not be present.
IT           name         (Optional; PDF 2.0) A name that shall describe the intent of the stamp.
The following values shall be valid:
StampSnapshot        The appearance of this annotation has been
taken from preexisting PDF content.
StampImage           The appearance of this annotation is an Image.
Stamp                The appearance of this annotation is a rubber
stamp.
Default value: Stamp

#### 0.18: 12.5.6.13        Ink annotations
An ink annotation (PDF 1.3) represents a freehand "scribble" composed of one or more disjoint paths.
When opened, it shall display a popup window containing the text of the associated note. "Table 185 —
Additional entries specific to an ink annotation" shows the annotation dictionary entries specific to this
type of annotation.

Table 185 — Additional entries specific to an ink annotation
Key             Type            Value
Subtype         name            (Required) The type of annotation that this dictionary describes; shall be
Ink for an ink annotation.
InkList         array           (Required) An array of n arrays, each representing a stroked path. Each
array shall be a series of alternating horizontal and vertical coordinates
in default user space, specifying points along the path. When drawn, the
points shall be connected by straight lines or curves in an
implementation-dependent way.
BS              dictionary      (Optional) A border style dictionary (see "Table 168 — Entries in a
border style dictionary") specifying the line width and dash pattern that
shall be used in drawing the paths.
Path            array           (Optional; PDF 2.0) An array of n arrays, each supplying the operands for
a path building operator (m, l or c).
Each of the n arrays shall contain pairs of values specifying the points (x
and y values) for a path drawing operation.
The first array shall be of length 2 and specifies the operand of a moveto
operator which establishes a current point.
Subsequent arrays of length 2 specify the operands of lineto operators.
Arrays of length 6 specify the operands for curveto operators.
Each array is processed in sequence to construct the path.
The current graphics state shall control the path width, dash pattern, etc.

#### 0.19: 12.5.6.14         Popup annotations
A popup annotation (PDF 1.3) displays text in a popup window for entry and editing. It shall not appear
alone but is associated with a markup annotation, its parent annotation, and shall be used for editing
the parent’s text. It shall have no appearance stream or associated actions of its own and shall be
identified by the Popup entry in the parent’s annotation dictionary (see "Table 172 — Additional
entries in an annotation dictionary specific to markup annotations"). "Table 186 — Additional entries
specific to a popup annotation" shows the annotation dictionary entries specific to this type of
annotation.
Table 186 — Additional entries specific to a popup annotation
Key           Type                 Value
Subtype       name                 (Required) The type of annotation that this dictionary describes;
shall be Popup for a popup annotation.
Parent        dictionary           (Optional; shall be an indirect reference) The parent annotation
with which this popup annotation shall be associated.
If this entry is present, the parent annotation’s Contents, M, C, and
T entries (see "Table 170 — Entries in an appearance dictionary")
shall override those of the popup annotation itself.
NOTE      See also the Popup entry in "Table 172 — Additional entries in
an annotation dictionary specific to markup annotations".
Key          Type               Value
Open         boolean            (Optional) A flag specifying whether the popup annotation shall
initially be displayed open. Default value: false (closed).

#### 0.20: 12.5.6.15        File attachment annotations
A file attachment annotation (PDF 1.3) contains a reference to a file, which typically shall be embedded
in the PDF file (see 7.11.4, "Embedded file streams").
NOTE        A table of data can use a file attachment annotation to link to a spreadsheet file based on that
data; activating the annotation extracts the embedded file and gives the user an opportunity to
view it or store it in the file system. "Table 187 — Additional entries specific to a file attachment
annotation" shows the annotation dictionary entries specific to this type of annotation.
The Contents entry of the annotation dictionary may specify descriptive text relating to the attached
file. Interactive PDF processors shall use this entry rather than the optional Desc entry (PDF 1.6) in the
file specification dictionary (see "Table 43 — Entries in a file specification dictionary") identified by the
annotation’s FS entry.
Table 187 — Additional entries specific to a file attachment annotation
Key         Type               Value
Subtype     name               (Required) The type of annotation that this dictionary describes; shall
be FileAttachment for a file attachment annotation.
FS          file specification (Required) The file associated with this annotation.
Name        name               (Optional) The name of an icon that shall be used in displaying the
annotation. PDF writers should include this entry and PDF readers
should provide predefined icon appearances for at least the following
standard names:
Graph, PushPin, Paperclip, Tag
Additional names may be supported as well. Default value: PushPin.

#### 0.21: 12.5.6.16        Sound annotations
The features described in this subclause are deprecated in PDF 2.0. They are superseded by the general
multimedia framework described in 13.2, "Multimedia".
A sound annotation (PDF 1.2) is analogous to a text annotation except that instead of a text note, it
contains sound recorded from the computer’s microphone or imported from a file. When the
annotation is activated, the sound shall be played. The annotation shall behave like a text annotation in
most ways, with a different icon (by default, a speaker) to indicate that it represents a sound. "Table
188 — Additional entries specific to a sound annotation" shows the annotation dictionary entries
specific to this type of annotation. Sound objects are discussed in 13.3, "Sounds".

Table 188 — Additional entries specific to a sound annotation
Key           Type            Value
Subtype       name            (Required) The type of annotation that this dictionary describes; shall
be Sound for a sound annotation.
Sound         stream          (Required) A sound object defining the sound that shall be played
when the annotation is activated (see 13.3, "Sounds").
Name          name            (Optional) The name of an icon that shall be used in displaying the
annotation. PDF writers should include this entry and PDF readers
should provide predefined icon appearances for at least the standard
names Speaker and Mic. Additional names may be supported as well.
Default value: Speaker.

#### 0.22: 12.5.6.17           Movie annotations
The features described in this subclause are deprecated in PDF 2.0. They are superseded by the general
multimedia framework described in 13.2, "Multimedia".
A movie annotation (PDF 1.2) contains animated graphics and sound to be presented on the computer
screen and through the speakers. When the annotation is activated, the movie shall be played. "Table
189 — Additional entries specific to a movie annotation" shows the annotation dictionary entries
specific to this type of annotation. Movies are discussed in 13.4, "Movies".
Table 189 — Additional entries specific to a movie annotation
Key            Type             Value
Subtype        name             (Required) The type of annotation that this dictionary describes; shall be
Movie for a movie annotation.
T              text string      (Optional) The title of the movie annotation. Movie actions (12.6.4.10,
"Movie actions") may use this title to reference the movie annotation.
Movie          dictionary       (Required) A movie dictionary that shall describe the movie’s static
characteristics (see 13.4, "Movies").
A              boolean or       (Optional) A flag or dictionary specifying whether and how to play the
dictionary       movie when the annotation is activated. If this value is a dictionary, it
shall be a movie activation dictionary (see 13.4, "Movies") specifying
how to play the movie. If the value is the boolean true, the movie shall be
played using default activation parameters. If the value is false, the
movie shall not be played. Default value: true.

#### 0.23: 12.5.6.18           Screen annotations
A screen annotation (PDF 1.5) specifies a region of a page upon which media clips may be played. It also
serves as an object from which actions can be triggered. 12.6.4.14, "Rendition actions" discusses the
relationship between screen annotations and rendition actions. "Table 190 — Additional entries
specific to a screen annotation" shows the annotation dictionary entries specific to this type of
annotation.
Table 190 — Additional entries specific to a screen annotation
Key          Type           Value
Subtype      name           (Required) The type of annotation that this dictionary describes; shall
be Screen for a screen annotation.
T            text string    (Optional) The title of the screen annotation.
MK           dictionary     (Optional) An appearance characteristics dictionary (see "Table 192
— Entries in an appearance characteristics dictionary"). The I entry
of this dictionary provides the icon used in generating the
appearance referred to by the screen annotation’s AP entry.
A            dictionary     (Optional; PDF 1.1) An action that shall be performed when the
annotation is activated (see 12.6, "Actions").
AA           dictionary     (Optional; PDF 1.2) An additional-actions dictionary defining the
screen annotation’s behaviour in response to various trigger events
(see 12.6.3, "Trigger events").
In addition to the entries in "Table 190 — Additional entries specific to a screen annotation", screen
annotations may use the common entries in the annotation dictionary (see "Table 166 — Entries
common to all annotation dictionaries") in the following ways:
•    The P entry shall be used for a screen annotation referenced by a rendition action. It shall
reference a valid page object, and the annotation shall be present in the page’s Annots array for
the action to be valid.
•    The AP entry refers to an appearance dictionary (see "Table 170 — Entries in an appearance
dictionary") whose normal appearance provides the visual appearance for a screen annotation
that shall be used for printing and default display when a media clip is not being played. If AP is
not present, the screen annotation shall not have a default visual appearance and shall not be
printed.

#### 0.24: 12.5.6.19         Widget annotations
Interactive forms (see 12.7, "Forms") use widget annotations (PDF 1.2) to represent the appearance of
fields and to manage user interactions. As a convenience, when a field has only a single associated
widget annotation, the contents of the field dictionary (12.7.4, "Field dictionaries") and the annotation
dictionary may be merged into a single dictionary containing entries that pertain to both a field and an
annotation.
NOTE         This presents no ambiguity, since the contents of the two kinds of dictionaries do not conflict.
"Table 191 — Additional entries specific to a widget annotation" shows the annotation dictionary
entries specific to this type of annotation; interactive forms and fields are discussed at length in 12.7.4,
"Field dictionaries".

Table 191 — Additional entries specific to a widget annotation
Key           Type              Value
Subtype       name              (Required) The type of annotation that this dictionary describes; shall
be Widget for a widget annotation.
H             name              (Optional) The annotation’s highlighting mode, the visual effect that
shall be used when the mouse button is pressed or held down inside
its active area:
N (None) No highlighting.
I     (Invert) Invert the colours used to display the contents of the
annotation rectangle.
O     (Outline) Stroke the colours used to display the annotation
border. That is, for each colour channel in the colour space used
for display of the annotation value, colour values shall be
transformed by the function 𝑓 (𝑥) = 1 – 𝑥 for display.
P     (Push) Display the annotation’s down appearance, if any (see
12.5.5, "Appearance streams"). If no down appearance is
defined, the contents of the annotation rectangle shall be offset
to appear as if it were being pushed below the surface of the
page.
T     (Toggle) Same as P (which is preferred).
A highlighting mode other than P shall override any down
appearance defined for the annotation. Default value: I.
MK            dictionary        (Optional) An appearance characteristics dictionary (see "Table 192
— Entries in an appearance characteristics dictionary") that shall be
used in constructing a dynamic appearance stream specifying the
annotation’s visual presentation on the page.
The name MK for this entry is of historical significance only and has
no direct meaning.
A             dictionary        (Optional; PDF 1.1) An action that shall be performed when the
annotation is activated (see 12.6, "Actions").
AA            dictionary        (Optional; PDF 1.2) An additional-actions dictionary defining the
annotation’s behaviour in response to various trigger events (see
12.6.3, "Trigger events").
BS            dictionary        (Optional; PDF 1.2) A border style dictionary (see "Table 168 —
Entries in a border style dictionary") specifying the width and dash
pattern that shall be used in drawing the annotation’s border.
Parent        dictionary        (Required if this widget annotation is one of multiple children in a field;
optional otherwise) An indirect reference to the widget annotation’s
parent field. A widget annotation may have at most one parent; that
is, it can be included in the Kids array of at most one field
The MK entry may be used to provide an appearance characteristics dictionary containing additional
information for constructing the annotation’s appearance stream. "Table 192 — Entries in an
appearance characteristics dictionary" shows the contents of this dictionary.
Table 192 — Entries in an appearance characteristics dictionary
Key     Type          Value
R       integer       (Optional) The number of degrees by which the widget annotation
shall be rotated counterclockwise relative to the page. The value shall
be a multiple of 90. Default value: 0.
BC      array         (Optional) An array of numbers that shall be in the range 0.0 to 1.0
specifying the colour of the widget annotation’s border. The number
of array elements determines the colour space in which the colour
shall be defined:
0     No colour; transparent
1     DeviceGray
3     DeviceRGB
4     DeviceCMYK
BG      array         (Optional) An array of numbers that shall be in the range 0.0 to 1.0
specifying the colour of the widget annotation’s background. The
number of array elements shall determine the colour space, as
described for BC.
CA      text string   (Optional; button fields only) The widget annotation’s normal caption,
which shall be displayed when it is not interacting with the user.
Unlike the remaining entries listed in this Table, which apply only to
widget annotations associated with push-button fields (see
12.7.5.2.2, "Push-buttons"), the CA entry may be used with any type
of button field, including check boxes (see 12.7.5.2.3, "Check boxes")
and radio buttons (12.7.5.2.4, "Radio buttons").
RC      text string   (Optional; push-button fields only) The widget annotation’s rollover
caption, which shall be displayed when the user rolls the cursor into
its active area without pressing the mouse button.
AC      text string   (Optional; push-button fields only) The widget annotation’s alternate
(down) caption, which shall be displayed when the mouse button is
pressed within its active area.
I       stream        (Optional; push-button fields only; shall be an indirect reference) A
form XObject defining the widget annotation’s normal icon, which
shall be displayed when it is not interacting with the user.
RI      stream        (Optional; push-button fields only; shall be an indirect reference) A
form XObject defining the widget annotation’s rollover icon, which
shall be displayed when the user rolls the cursor into its active area
without pressing the mouse button.
IX      stream        (Optional; push-button fields only; shall be an indirect reference) A
form XObject defining the widget annotation’s alternate (down) icon,
which shall be displayed when the mouse button is pressed within its
active area.
IF      dictionary    (Optional; push-button fields only) An icon fit dictionary (see "Table
250 — Entries in an icon fit dictionary") specifying how the widget
annotation’s icon shall be displayed within its annotation rectangle. If
present, the icon fit dictionary shall apply to all of the annotation’s
icons (normal, rollover, and alternate).

Key           Type              Value
TP            integer           (Optional; push-button fields only) A code indicating where to position
the text of the widget annotation’s caption relative to its icon:
0    No icon; caption only
1    No caption; icon only
2    Caption below the icon
3    Caption above the icon
4    Caption to the right of the icon
5    Caption to the left of the icon
6    Caption overlaid directly on the icon
Default value: 0.

#### 0.25: 12.5.6.20         Printer’s mark annotations
A printer’s mark annotation (PDF 1.4) represents a graphic symbol, such as a registration target, colour
bar, or cut mark, that may be added to a page to assist production personnel in identifying components
of a multiple-plate job and maintaining consistent output during production. See 14.11.3, "Printer’s
marks" for further discussion.

#### 0.26: 12.5.6.21         Trap network annotations
The features described in this subclause are deprecated in PDF 2.0.
A trap network annotation (PDF 1.3) may be used to define the trapping characteristics for a page of a
PDF document.
NOTE         Trapping is the process of adding marks to a page along colour boundaries to avoid unwanted
visual artifacts resulting from misregistration of colourants when the page is printed.
A page shall have no more than one trap network annotation, whose Subtype entry has the value
TrapNet and which shall always be the last element in the page object’s Annots array (see 7.7.3.3,
"Page objects"). See 14.11.6, "Trapping support" for further discussion.

#### 0.27: 12.5.6.22         Watermark annotations
A watermark annotation (PDF 1.6) with a Fixed Print dictionary shall be used to represent graphics
that are to be printed at a fixed size relative to the target media, and fixed relative position on the
target media, regardless of the dimensions of that media. The FixedPrint entry of a watermark
annotation dictionary (see "Table 193 — Additional entries specific to a watermark annotation") shall
be a dictionary that contains values for specifying the size and position of the annotation (see "Table
194 — Entries in a fixed print dictionary").
Watermark annotations shall have no popup window nor other interactive elements. When displaying
a watermark annotation on-screen, interactive PDF processors shall use the dimensions of the media
box (see "Table 29 — Entries in the catalog dictionary") as the media dimensions so that the scroll and
zoom behaviour is the same as for other annotations.
NOTE 1       Since many printing devices have nonprintable margins, such margins need to be taken into
consideration when positioning watermark annotations near the edge of a page.
Table 193 — Additional entries specific to a watermark annotation
Key            Type         Value
Subtype        name         (Required) The type of annotation that this dictionary describes; shall be
Watermark for a watermark annotation.
FixedPrint     dictionary   (Optional) A fixed print dictionary (see "Table 194 — Entries in a fixed
print dictionary") that specifies how this annotation shall be drawn
relative to the dimensions of the target media. If this entry is not
present, the annotation shall be drawn without any special
consideration for the dimensions of the target media.
If the dimensions of the target media are not known at the time of
drawing, drawing shall be done relative to the dimensions specified by
the page’s MediaBox entry (see "Table 31 — Entries in a page object").
Table 194 — Entries in a fixed print dictionary
Key         Type       Value
Type        name       (Required) Shall be FixedPrint.
Matrix      array      (Optional) The matrix used to transform the annotation’s rectangle before
rendering.
Default value: the identity matrix [1 0 0 1 0 0].
When positioning content near the edge of the media, this entry should be
used to provide a reasonable offset to allow for unprintable margins.
H           number     (Optional) The amount to translate the associated content horizontally, as
a percentage of the width of the target media (or if unknown, the width of
the page’s MediaBox). 1.0 represents 100% and 0.0 represents 0%.
Negative values should not be used, since they may cause content to be
drawn off the media.
Default value: 0.
V           number     (Optional) The amount to translate the associated content vertically, as a
percentage of the height of the target media (or if unknown, the height of
the page’s MediaBox). 1.0 represents 100% and 0.0 represents 0%.
Negative values should not be used, since they may cause content to be
drawn off the media.
Default value: 0.
When rendering a watermark annotation with a FixedPrint entry, the following behaviour shall occur:
•    The annotation’s rectangle (as specified by its Rect entry) shall be translated to the origin and
transformed by the Matrix entry of its FixedPrint dictionary to produce a quadrilateral with
arbitrary orientation.
•    The transformed annotation rectangle shall be defined as the smallest upright rectangle that
encompasses this quadrilateral; it shall be used in place of the annotation rectangle referred to in
steps 2 and 3 of "Algorithm: appearance streams" (see 12.5.5, "Appearance streams").
In addition, given a matrix B that maps a scaled and rotated page into the default user space, a new
matrix shall be computed that cancels out B and translates the origin of the media (e.g., printed page)

to the origin of the default user space. This transformation shall be applied to ensure the correct
scaling and alignment.
EXAMPLE            The following example shows a watermark annotation that prints a text string one inch from the left and
one inch from the top of the printed page.
8 0 obj                                           %Watermark appearance
<<
/Length …
/Subtype /Form
/Resources …
/BBox …
>>
stream
…
BT
/F1 1 Tf
36 0 0 36 0 -36 Tm
(Do Not Build) Tx
ET
…
endstream
endobj
9 0 obj                                           %Watermark annotation
<<
/Rect …
/Type /Annot
/Subtype /Watermark
/FixedPrint 10 0 R
/AP <</N 8 0 R>>
>>
%in the page dictionary
/Annots [9 0 R]
10 0 obj                                          %Fixed print dictionary
<<
/Type /FixedPrint
/Matrix [1 0 0 1 72 -72]              %Translate one inch right and one inch down
/H 0
/V 1.0                                %Translate the full height of the page vertically
>>
endobj
In situations other than the usual case where the PDF page size equals the media size, watermark
annotations with a FixedPrint entry shall be printed in the following manner:
•    When page tiling is selected in a PDF processor (that is, a single PDF page is printed on multiple
pages), watermark annotations shall be printed at the specified size and position on each page to
ensure that the content of the watermark annotation is present and legible on each printed page.
•    When n-up printing is selected (that is, multiple PDF pages are printed on a single page), the
annotations shall be printed at the specified size and shall be positioned as if the dimensions of
the printed page were limited to a single portion of the page. This ensures that any content of the
watermark annotation does not overlap content from other pages, thus rendering it illegible.
NOTE 2      There is no guarantee that the location of a fixed print annotation on any given output page will
cover content.

#### 0.28: 12.5.6.23       Redaction annotations
A redaction annotation (PDF 1.7) identifies content that is intended to be removed from the document.
The intent of redaction annotations is to enable the following process:
a) Content identification. A user applies redact annotations that specify the pieces or regions of content that
should be removed. Up until the next step is performed, the user can see, move and redefine these
annotations.
b) Content removal. The user instructs the viewer application to apply the redact annotations, after which
the content in the area specified by the redact annotations is removed. In the removed content’s place,
some marking appears to indicate the area has been redacted. Also, the redact annotations are removed
from the PDF document.
Redaction annotations provide a mechanism for the first step in the redaction process (content
identification). This allows content to be marked for redaction in a non-destructive way, thus enabling
a review process for evaluating potential redactions prior to removing the specified content.
Redaction annotations shall provide enough information to be used in the second phase of the
redaction process (content removal). This phase is application-specific and requires the PDF processor
to remove all content identified by the redaction annotation, as well as the annotation itself. Interactive
PDF processors that support redaction annotations shall provide a mechanism for applying content
removal, and they shall remove all traces of the specified content. If a portion of an image is contained
in a redaction region, that portion of the image data shall be destroyed; clipping or image masks shall
not be used to hide that data. Such interactive PDF processors shall also be diligent in their
consideration of all content that can exist in a PDF document. “Table 195 — Additional entries specific
to a redaction annotation” shows the additional entries specific to redaction annotations.
Table 195 — Additional entries specific to a redaction annotation
Key           Type        Value
Subtype       name        (Required) The type of annotation that this dictionary describes; shall be Redact
for a redaction annotation.
QuadPoints array          (Optional) An array of 8 x n numbers specifying the coordinates of n
quadrilaterals in default user space, as described in "Table 182 — Additional
entries specific to text markup annotations" for text markup annotations. If
present, these quadrilaterals denote the content region that is intended to be
removed. If this entry is not present, the Rect entry denotes the content region
that is intended to be removed.
IC            array       (Optional) An array of three numbers in the range 0.0 to 1.0 specifying the
components, in the DeviceRGB colour space, of the interior colour with which
to fill the redacted region after the affected content has been removed. If this
entry is absent, the interior of the redaction region is left transparent. This
entry is ignored if the RO entry is present.

Key              Type           Value
RO               stream         (Optional) A form XObject specifying the overlay appearance for this redaction
annotation. After this redaction is applied and the affected content has been
removed, the overlay appearance should be drawn such that its origin lines up
with the lower-left corner of the annotation rectangle. This form XObject is not
necessarily related to other annotation appearances, and may or may not be
present in the AP dictionary. This entry takes precedence over the IC,
OverlayText, DA, and Q entries.
OverlayText text                (Optional) A text string specifying the overlay text that should be drawn over
string              the redacted region after the affected content has been removed. This entry is
ignored if the RO entry is present.
Repeat           boolean        (Optional) If true, then the text specified by OverlayText should be repeated to
fill the redacted region after the affected content has been removed. This entry
is ignored if the RO entry is present. Default value: false.
DA               byte           (Required if OverlayText is present, ignored otherwise) The appearance string
string         that shall be used in formatting the overlay text when it is drawn after the
affected content has been removed (see 12.7.4.3, "Variable text"). This entry is
ignored if the RO entry is present.
Q                integer        (Optional) A code specifying the form of quadding (justification) that shall be
used in laying out the overlay text:
0    Left-justified
1    Centred
2    Right-justified
This entry is ignored if the RO entry is present. Default value: 0 (left-justified).

#### 0.29: 12.5.6.24         Projection annotations
A projection annotation (PDF 2.0) is a markup annotation subtype (see 12.5.6.2, "Markup annotations")
that has much of the functionality of other markup annotations. However, a projection annotation is
only valid within the context of an associated run-time environment, such as an activated 3D model.
A projection annotation shall have a Subtype of Projection. The entries of a annotation dictionary for a
projection annotation are those listed in "Table 166 — Entries common to all annotation dictionaries"
and "Table 172 — Additional entries in an annotation dictionary specific to markup annotations".
Projection annotations provide a way to save 3D and other specialised measurements and comments
as markup annotations. These measurements and comments then persist in the document.
When a projection annotation is used in conjunction with a 3D measurement (13.6.7.4, "3D
measurements and projection annotations"), it has an ExData dictionary with a Subtype of 3DM. (See
"Table 332 — Entries in the external data dictionary of a projection annotation".) Otherwise, the
ExData dictionary is optional.
A projection annotation with a Rect entry that has zero height or zero width shall not have an AP
dictionary.

