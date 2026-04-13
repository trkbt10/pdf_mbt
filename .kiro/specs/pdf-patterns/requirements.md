# SDD Draft

Generated from:
- `spec/extracted/8.7-patterns.spec.txt`

## Requirements

#### 0.1: 8.7.1 General
Patterns come in two varieties:
•    Tiling patterns consist of a small graphical figure (called a pattern cell) that is replicated at fixed
horizontal and vertical intervals to fill the area to be painted. The graphics objects to use for tiling
shall be described by a content stream.
•    Shading patterns define a gradient fill that produces a smooth transition between colours across
the area.
The colour to use shall be specified as a function of position using any of a variety of methods.
NOTE 1      When operators such as S (stroke), f (fill), and Tj (show text) paint an area of the page with the
current colour, they ordinarily apply a single colour that covers the area uniformly. However,
"paint" can be applied that consists of a repeating graphical figure or a smoothly varying colour
gradient instead of a simple colour. Such a repeating figure or smooth gradient is called a
pattern. Patterns are quite general, and have many uses; for example, they can be used to create
various graphical textures, such as weaves, brick walls, sunbursts, and similar geometrical and
chromatic effects.
NOTE 2      Older techniques such as defining a pattern by using character glyphs in a special font and
painting them repeatedly with the Tj operator are not recommended. Another technique,
defining patterns as halftone screens, is also not recommended because the effects produced are
device-dependent.
Patterns shall be specified in a special family of colour spaces named Pattern. These spaces shall use
pattern objects as the equivalent of colour values instead of the numeric component values used with
other spaces. A pattern object shall be a dictionary or a stream, depending on the type of pattern; the
term pattern dictionary is used generically throughout this subclause to refer to either a dictionary
object or the dictionary portion of a stream object. (Those pattern objects that are streams are
specifically identified as such in the descriptions of particular pattern types; unless otherwise stated,
they are understood to be simple dictionaries instead.) This subclause describes Pattern colour spaces
and the specification of colour values within them.
NOTE 3      See 8.6, "Colour spaces", for information about colour spaces and colour values in general and
11.6.7, "Patterns and transparency", for further discussion of the treatment of patterns in the
transparent imaging model.

#### 0.2: 8.7.2 General properties of patterns
A pattern dictionary contains descriptive information defining the appearance and properties of a
pattern. All pattern dictionaries shall contain an entry named PatternType, whose value identifies the
kind of pattern the dictionary describes: Type 1 for a tiling pattern or Type 2 for a shading pattern. The
remaining contents of the dictionary depend on the pattern type and are detailed in the subclauses on
individual pattern types.
All patterns shall be treated as colours; a Pattern colour space shall be established with the CS or cs
operator just like other colour spaces, and a particular pattern shall be installed as the current colour
with the SCN or scn operator (see "Table 73 — Colour operators").
A pattern’s appearance is described with respect to its own internal coordinate system. Every pattern
has a pattern matrix, a transformation matrix that maps the pattern’s internal coordinate system to the
default coordinate system of the pattern’s parent content stream (the content stream in which the
pattern is defined as a resource). The concatenation of the pattern matrix with that of the parent
content stream establishes the pattern coordinate space, within which all graphics objects in the
pattern shall be interpreted.
If a pattern is used on a page, the pattern appears in the Pattern subdictionary of that page’s resource
dictionary, and the pattern matrix maps pattern space to the default (initial) coordinate space of the
page. Changes to the page’s transformation matrix that occur within the page’s content stream, such as
rotation and scaling, have no effect on the pattern; it maintains its original relationship to the page no
matter where on the page it is used. Similarly, if a pattern is used within a form XObject (see 8.10,
"Form XObjects"), the pattern matrix maps pattern space to the form’s default user space (that is, the
form coordinate space at the time the form is painted with the Do operator). A pattern can be used
within another pattern; the inner pattern’s matrix defines its relationship to the pattern space of the
outer pattern.
NOTE       The PostScript language allows a pattern to be defined in one context but used in another. For
example, a pattern can be defined on a page (that is, its pattern matrix maps the pattern
coordinate space to the user space of the page) but is used in a form on that page, so that its
relationship to the page is independent of each individual placement of the form. PDF does not
support this feature.

#### 0.3: 8.7.3.1         General
A tiling pattern consists of a small graphical figure called a pattern cell. Painting with the pattern
replicates the cell at fixed horizontal and vertical intervals to fill an area. The effect is as if the figure
were painted on the surface of a clear glass tile, identical copies of which were then laid down in an
array covering the area and trimmed to its boundaries. This process is called tiling the area.
The pattern cell can include graphical elements such as filled areas, text, and sampled images. Its shape
need not be rectangular, and the spacing of tiles can differ from the dimensions of the cell itself. When
performing painting operations such as S (stroke) or f (fill), the PDF processor shall paint the cell on
the current page as many times as necessary to fill an area. The order in which individual tiles
(instances of the cell) are painted is unspecified and unpredictable; figures on adjacent tiles should not
overlap.

The appearance of the pattern cell shall be defined by a content stream containing the painting
operators needed to paint one instance of the cell. Besides the usual entries common to all streams (see
"Table 5 — Entries common to all stream dictionaries"), this stream’s dictionary may contain the
additional entries listed in "Table 74 — Additional entries specific to a Type 1 pattern dictionary".
Table 74 — Additional entries specific to a Type 1 pattern dictionary
Key              Type         Value
Type             name         (Optional) The type of PDF object that this dictionary describes; if present, shall be
Pattern for a pattern dictionary.
PatternType integer           (Required) A code identifying the type of pattern that this dictionary describes; shall
be 1 for a tiling pattern.
PaintType        integer      (Required) A code that determines how the colour of the pattern cell shall be
specified:
1     Coloured tiling pattern. The pattern’s content stream shall specify the colours
used to paint the pattern cell. The current colours in use when the PDF
processor begins processing the content stream are the ones initially in effect in
the pattern’s parent content stream. This is similar to the definition of the
pattern matrix; see 8.7.2, "General properties of patterns".
2    Uncoloured tiling pattern. The pattern’s content stream shall not specify any
colour information. Instead, the entire pattern cell is painted with a separately
specified colour each time the pattern is used. Essentially, the content stream
describes a stencil through which the current nonstroking colour shall be
poured. The content stream shall not invoke operators that specify colours or
other colour-related parameters in the graphics state; otherwise, the operator is
ignored and processing of the stream continues without error (see 8.6.8,
"Colour operators"). The content stream may paint an image mask however,
since it does not specify any colour information (see 8.9.6.2, "Stencil masking").
TilingType       integer      (Required) A code that controls adjustments to the spacing of tiles relative to the
device pixel grid:
1    Constant spacing. Pattern cells shall be spaced consistently — that is, by a
multiple of a device pixel. To achieve this, the PDF processor may need to
distort the pattern cell slightly by making small adjustments to XStep, YStep,
and the transformation matrix. The amount of distortion shall not exceed 1
device pixel.
2    No distortion. The pattern cell shall not be distorted, but the spacing between
pattern cells may vary by as much as 1 device pixel, both horizontally and
vertically, when the pattern is painted. This achieves the spacing requested by
XStep and YStep on average but not necessarily for each individual pattern cell.
3    Constant spacing and faster tiling. Pattern cells shall be spaced consistently as in
tiling Type 1 but with additional distortion permitted to enable a more efficient
implementation.
BBox             rectangle (Required) An array of four numbers in the pattern coordinate system giving the
coordinates of the left, bottom, right, and top edges, respectively, of the pattern cell’s
bounding box. These boundaries shall be used to clip the pattern cell.
NOTE 1 A BBox of zero height or width will still paint one pixel (see 10.7.4, "Scan conversion
rules").
XStep            number       (Required) The desired horizontal spacing between pattern cells, measured in the
pattern coordinate system.
Key            Type        Value
YStep          number      (Required) The desired vertical spacing between pattern cells, measured in the
pattern coordinate system.
NOTE 2 XStep and YStep can differ from the dimensions of the pattern cell implied by the
BBox entry. This allows tiling with irregularly shaped figures.
XStep and YStep may be either positive or negative but shall not be zero.
Resources      dictionary (Required) A resource dictionary that shall contain all of the named resources
required by the pattern’s content stream (see 7.8.3, "Resource dictionaries").
Matrix         array       (Optional) An array of six numbers specifying the pattern matrix (see 8.7.2, "General
properties of patterns"). Default value: the identity matrix [1 0 0 1 0 0].
The pattern dictionary’s BBox, XStep, and YStep values shall be interpreted in the pattern coordinate
system, and the graphics objects in the pattern’s content stream shall be defined with respect to that
coordinate system. The placement of pattern cells in the tiling is based on the location of one key
pattern cell, which is then displaced by multiples of XStep and YStep to replicate the pattern. The
origin of the key pattern cell coincides with the origin of the pattern coordinate system. The phase of
the tiling can be controlled by the translation components of the Matrix entry in the pattern dictionary.
Prior to painting with a tiling pattern, the PDF writer shall establish the pattern as the current colour in
the graphics state. Subsequent painting operations tile the painted areas with the pattern cell
described by the pattern’s content stream. To obtain the pattern cell, the PDF processor shall perform
these steps:
a) Saves the current graphics state (as if by invoking the q operator)
b) Installs the graphics state that was in effect at the beginning of the pattern’s parent content stream, with
the current transformation matrix altered by the pattern matrix as described in 8.7.2, "General
properties of patterns"
c) Paints the graphics objects specified in the pattern’s content stream
d) Restores the saved graphics state (as if by invoking the Q operator)
The pattern’s content stream shall not set any of the device-dependent parameters in the graphics
state (see "Table 52 — Device-dependent graphics state parameters") because it can result in incorrect
output.

#### 0.4: 8.7.3.2         Coloured tiling patterns
A coloured tiling pattern is a pattern whose colour is self-contained. In the course of painting the
pattern cell, the pattern’s content stream explicitly sets the colour of each graphical element it paints. A
single pattern cell may contain elements that are painted different colours; it may also contain sampled
grayscale or colour images. This type of pattern is identified by a pattern type of 1 and a paint type of 1
in the pattern dictionary.
When the current colour space is a Pattern space, a coloured tiling pattern shall be selected as the
current colour by supplying its name as the single operand to the SCN or scn operator. This name shall
be the key of an entry in the Pattern subdictionary of the current resource dictionary (see 7.8.3,
"Resource dictionaries"), whose value shall be the stream object representing the pattern. Since the

pattern defines its own colour information, no additional operands representing colour components
shall be specified to SCN or scn.
EXAMPLE 1         If P1 is the name of a pattern resource in the current resource dictionary, the following code establishes it
as the current nonstroking colour:
/Pattern cs
/P1 scn
NOTE 1      Subsequent executions of nonstroking painting operators, such as f (fill), Tj (show text), or Do
(paint external object) with an image mask, use the designated pattern to tile the areas to be
painted.
NOTE 2      The following defines a page (object 5) that paints three circles and a triangle using a coloured
tiling pattern (object 15) over a yellow background. The pattern consists of the symbols for the
four suits of playing cards (spades, hearts, diamonds, and clubs), which are character glyphs
taken from the ZapfDingbats font (see D.6, "ZapfDingbats set and encoding"); the pattern’s
content stream specifies the colour of each glyph. "Figure 31 — Coloured tiling pattern" shows
the pattern cell on the left side and the patterned shapes on the right side.
EXAMPLE 2
5 0 obj                                                              %Page object
<</Type /Page
/Parent 2 0 R
/Resources 10 0 R
/Contents 30 0 R
/CropBox [0 0 225 225]
>>
endobj
10 0 obj                                                             %Resource dictionary for page
<</Pattern      <</P1 15 0 R>>
>>
endobj
15 0 obj                                                             %Pattern definition
<</Type /Pattern
/PatternType 1                                              %Tiling pattern
/PaintType 1                                                %Coloured
/TilingType 2
/BBox [0 0 100 100]
/XStep 100
/YStep 100
/Resources 16 0 R
/Matrix [0.4 0.0 0.0 0.4 0.0 0.0]
/Length 183
>>
stream
BT                                                             %Begin text object
/F1 1 Tf                                                    %Set text font and size
64 0 0 64 7.1771 2.4414 Tm                                  %Set text matrix
0 Tc                                                        %Set character spacing
0 Tw                                                        %Set word spacing
1.0 0.0 0.0 rg                                              %Set nonstroking colour to red
(\001) Tj                                                   %Show spade glyph
0.7478 -0.007 TD                                          %Move text position
0.0   1.0   0.0        rg                                 %Set nonstroking colour to green
(\002) Tj                                                 %Show heart glyph
-0.7323 0.7813 TD                                         %Move text position
0.0 0.0 1.0 rg                                            %Set nonstroking colour to blue
(\003) Tj                                                 %Show diamond glyph
0.6913 0.007 TD                                        %Move text position
0.0   0.0 0.0 rg                                       %Set nonstroking colour to black
(\004) Tj                                              %Show club glyph
ET                                                    %End text object
endstream
endobj
16 0 obj                                                       %Resource dictionary for pattern
<</Font <</F1 20 0 R>>
>>
endobj
20 0 obj                                                       %Font for pattern
<</Type /Font
/Subtype /Type1
/Encoding 21 0 R
/BaseFont /ZapfDingbats
>>
endobj
21 0 obj                                                       %Font encoding
<</Type /Encoding
/Differences [1 /a109 /a110 /a111 /a112]
>>
endobj
30 0 obj                                                       %Contents of page
<</Length 1252>>
stream
0.0   G                                                  %Set stroking colour to black
1.0 1.0 0.0 rg                                           %Set nonstroking colour to yellow
25 175 175 -150 re                                       %Construct rectangular path
f                                                        %Fill path
/Pattern cs                                               %Set pattern colour space
/P1 scn                                                   %Set pattern as nonstroking colour
99.92 49.92 m                                             %Start new path
99.92 77.52 77.52 99.92 49.92 99.92 c                     %Construct lower-left circle
22.32 99.92 -0.08 77.52 -0.08 49.92 c
-0.08 22.32 22.32 -0.08 49.92 -0.08 c
77.52 -0.08 99.92 22.32 99.92 49.92 c
B                                                         %Fill and stroke path
224.96 49.92 m                                            %Start new path
224.96 77.52 202.56 99.92 174.96 99.92 c                  %Construct lower-right circle
147.36 99.92 124.96 77.52 124.96 49.92 c
124.96 22.32 147.36 -0.08 174.96 -0.08 c
202.56 -0.08 224.96 22.32 224.96 49.92 c
B                                                         %Fill and stroke path
87.56 201.70 m                                            %Start new path
63.66 87.90 55.46 157.32 69.26 133.40 c                   %Construct upper circle
83.06 109.50 113.66 101.30 137.56 115.10 c
161.46 128.90 169.66 159.50 155.86 183.40 c
142.06 207.30 111.46 215.50 87.56 201.70 c
B                                                         %Fill and stroke path
50 50 m                                                  %Start new path
175 50 l                                                 %Construct triangular path
112.5 158.253 l
b                                                        %Close, fill, and stroke path
endstream
endobj
NOTE 3   Several features of Example 2 in this subclause are noteworthy:

The three circles and the triangle are painted with the same pattern. The pattern cells align, even
though the circles and triangle are not aligned with respect to the pattern cell. For example, the
position of the blue diamonds varies relative to the three circles.
The pattern cell does not completely cover the tile: it leaves the spaces between the glyphs
unpainted. When the tiling pattern is used as a colour, the existing background (the yellow
rectangle) shows through these unpainted areas.
Figure 31 — Coloured tiling pattern

#### 0.5: 8.7.3.3           Uncoloured tiling patterns
An uncoloured tiling pattern is a pattern that has no inherent colour: the colour shall be specified
separately whenever the pattern is used. It provides a way to tile different regions of the page with
pattern cells having the same shape but different colours. This type of pattern shall be identified by a
pattern type of 1 and a paint type of 2 in the pattern dictionary. The pattern’s content stream shall not
explicitly specify any colours (see 8.6.8, "Colour operators"); it may paint an image mask (see 8.9.6.2,
"Stencil masking") but no other kind of image.
A Pattern colour space representing an uncoloured tiling pattern shall have a parameter: an object
identifying the underlying colour space in which the actual colour of the pattern shall be specified. The
underlying colour space shall be given as the second element of the array that defines the Pattern
colour space.
EXAMPLE 1         The array
[/Pattern /DeviceRGB]
defines a Pattern colour space with DeviceRGB as its underlying colour space.
NOTE        The underlying colour space cannot be another Pattern colour space.
Operands supplied to the SCN or scn operator in such a colour space shall include a colour value in the
underlying colour space, specified by one or more numeric colour components, as well as the name of a
pattern object representing an uncoloured tiling pattern.
EXAMPLE 2     If the current resource dictionary (see 7.8.3, "Resource dictionaries") defines Cs3 as the name of a
ColorSpace resource whose value is the Pattern colour space shown above and P2 as a Pattern resource
denoting an uncoloured tiling pattern, the code
/Cs3 cs
0.30 0.75 0.21 /P2 scn
establishes Cs3 as the current nonstroking colour space and P2 as the current nonstroking colour, to be
painted in the colour represented by the specified components in the DeviceRGB colour space. Subsequent
executions of nonstroking painting operators, such as f (fill), Tj (show text), and Do (paint external object)
with an image mask, use the designated pattern and colour to tile the areas to be painted. The same pattern
can be used repeatedly with a different colour each time.
EXAMPLE 3     This example is similar to Example 2 in 8.7.3.2, "Coloured tiling patterns", except that it uses an uncoloured
tiling pattern to paint the three circles and the triangle, each in a different colour (see "Figure 32 —
Uncoloured tiling pattern". To do so, it supplies four operands each time it invokes the scn operator: three
numbers denoting the colour components in the underlying DeviceRGB colour space, along with the name
of the pattern.
5 0 obj                                                           %Page object
<</Type /Page
/Parent 2 0 R
/Resources 10 0 R
/Contents 30 0 R
/CropBox [0 0 225 225]
>>
endobj
10 0 obj                                                          %Resource dictionary for page
<</ColorSpace <</Cs12 12 0 R>>
/Pattern <</P1 15 0 R>>
>>
endobj
12 0 obj                                                          %Colour space
[/Pattern /DeviceRGB]
endobj
15 0 obj                                                          %Pattern definition
<</Type /Pattern
/PatternType 1                                           %Tiling pattern
/PaintType 2                                             %Uncoloured
/TilingType 2
/BBox [0 0 100 100]
/XStep 100
/YStep 100
/Resources 16 0 R
/Matrix [0.4 0.0 0.0 0.4 0.0 0.0]
/Length 127
>>
stream
BT                                                          %Begin text object
/F1 1 Tf                                                 %Set text font and size
64 0 0 64 7.1771 2.4414 Tm                               %Set text matrix
0 Tc                                                     %Set character spacing
0 Tw                                                     %Set word spacing
(001) Tj                                                  %Show spade glyph
0.7478 -0.007 TD                                          %Move text position
(\002) Tj                                                 %Show heart glyph
-0.7323 0.7813 TD                                         %Move text position
(\003) Tj                                                 %Show diamond glyph
0.6913 0.007 TD                                           %Move text position
(\004) Tj                                                 %Show club glyph

ET                                                             %End text object
endstream
endobj
16 0 obj                                                             %Resource dictionary for pattern
<</Font <</F1 20 0 R>>
>>
endobj
20 0 obj                                                             %Font for pattern
<</Type /Font
/Subtype /Type1
/Encoding 21 0 R
/BaseFont /ZapfDingbats
>>
endobj
21 0 obj                                                             %Font encoding
<</Type /Encoding
/Differences [1 /a109 /a110 /a111 /a112]
>>
endobj
30 0 obj                                                             %Contents of page
<</Length 1316>>
stream
0.0 G                                                          %Set stroking colour to black
1.0 1.0 0.0 rg                                                 %Set nonstroking colour to yellow
25 175 175 -150 re                                             %Construct rectangular path
f                                                              %Fill path
/Cs12 cs                                                      %Set pattern colour space
0.77 0.20 0.00 /P1 scn                                        %Set nonstroking colour and pattern
99.92 49.92 m                                                 %Start new path
99.92 77.52 77.52 99.92 49.92 99.92 c                         %Construct lower-left circle
22.32 99.92 -0.08 77.52 -0.08 49.92 c
-0.08 22.32 22.32 -0.08 49.92 -0.08 c
77.52 -0.08 99.92 22.32 99.92 49.92 c
B                                                             %Fill and stroke path
0.2 0.8 0.4 /P1 scn                                           %Change nonstroking colour
224.96 49.92 m                                                %Start new path
224.96 77.52 202.56 99.92 174.96 99.92 c                      %Construct lower-right circle
147.36 99.92 124.96 77.52 124.96 49.92 c
124.96 22.32 147.36 -0.08 174.96 -0.08 c
202.56 -0.08 224.96 22.32 224.96 49.92 c
B                                                             %Fill and stroke path
0.3 0.7 1.0 /P1 scn                                           %Change nonstroking colour
87.56 201.70 m                                                %Start new path
63.66 187.90 55.46 157.30 69.26 133.40 c                      %Construct upper circle
83.06 109.50 113.66 101.30 137.56 115.10 c
161.46 128.90 169.66 159.50 155.86 183.40 c
142.06 207.30 111.46 215.50 87.56 201.70 c
B                                                             %Fill and stroke path
0.5 0.2 1.0 /P1 scn                                            %Change nonstroking colour
50 50 m                                                        %Start new path
175 50 l                                                       %Construct triangular path
112.5 158.253 l
b                                                              %Close, fill, and stroke path
endstream
endobj
Figure 32 — Uncoloured tiling pattern

#### 0.6: 8.7.4.1           General
Shading patterns (PDF 1.3) provide a smooth transition between colours across an area to be painted,
independent of the resolution of any particular output device and without specifying the number of
steps in the colour transition. Patterns of this type shall be described by pattern dictionaries with a
pattern type of 2. "Table 75 — Entries in a Type 2 pattern dictionary" shows the contents of this type of
dictionary.
Table 75 — Entries in a Type 2 pattern dictionary
Key            Type         Value
Type           name         (Optional) The type of PDF object that this dictionary describes; if present,
shall be Pattern for a pattern dictionary.
PatternType    integer      (Required) A code identifying the type of pattern that this dictionary
describes; shall be 2 for a shading pattern.
Shading        dictionary   (Required) A shading object (see below) defining the shading pattern’s
or stream    gradient fill. The contents of the dictionary shall consist of the entries in
"Table 77 — Entries common to all shading dictionaries" and those in one
of Table 78 to Table 83.
Matrix         array        (Optional) An array of six numbers specifying the pattern matrix (see
8.7.2, "General properties of patterns"). Default value: the identity matrix
[1 0 0 1 0 0].
ExtGState      dictionary   (Optional) A graphics state parameter dictionary (see 8.4.5, "Graphics
state parameter dictionaries") containing graphics state parameters to be
put into effect temporarily while the shading pattern is painted. Any
parameters that are not so specified shall be inherited from the graphics
state that was in effect at the beginning of the pattern’s parent content
stream, and as modified by clause 11.6.7, "Patterns and transparency".

The most significant entry is Shading, whose value shall be a shading object defining the properties of
the shading pattern’s gradient fill. This is a complex "paint" that determines the type of colour
transition the shading pattern produces when painted across an area. A shading object shall be a
dictionary or a stream, depending on the type of shading; the term shading dictionary is used
generically throughout this subclause to refer to either a dictionary object or the dictionary portion of
a stream object. (Those shading objects that are streams are specifically identified as such in the
descriptions of particular shading types; unless otherwise stated, they are understood to be simple
dictionaries instead.)
By setting a shading pattern as the current colour in the graphics state, a PDF content stream may use
it with painting operators such as f (fill), S (stroke), Tj (show text), or Do (paint external object) with
an image mask to paint a path, character glyph, or mask with a smooth colour transition. When a
shading is used in this way, the geometry of the gradient fill is independent of that of the object being
painted.

#### 0.7: 8.7.4.2           Shading operator
When the area to be painted is a relatively simple shape whose geometry is the same as that of the
gradient fill itself, the sh operator may be used instead of the usual painting operators. sh accepts a
shading dictionary as an operand and applies the corresponding gradient fill directly to current user
space. This operator does not require the creation of a pattern dictionary or a path and works without
reference to the current colour in the graphics state. "Table 76 — Shading operator" describes the sh
operator.
NOTE        Patterns defined by Type 2 pattern dictionaries do not tile. To create a tiling pattern containing a
gradient fill, invoke the sh operator from within the content stream of a Type 1 (tiling) pattern.
Table 76 — Shading operator
Operands           Operator           Description
name               sh                 (PDF 1.3) Paint the shape and colour shading described by a shading
dictionary, subject to the current clipping path. The current colour in the
graphics state is neither used nor altered. The effect is different from that
of painting a path using a shading pattern as the current colour. name is
the name of a shading dictionary resource in the Shading subdictionary of
the current resource dictionary (see 7.8.3, "Resource dictionaries"). All
coordinates in the shading dictionary are interpreted relative to the
current user space. (By contrast, when a shading dictionary is used in a
Type 2 pattern, the coordinates are expressed in pattern space.) All
colours are interpreted in the colour space identified by the shading
dictionary’s ColorSpace entry (see "Table 77 — Entries common to all
shading dictionaries"). The Background entry, if present, is ignored.
This operator should be applied only to bounded or geometrically defined
shadings. If applied to an unbounded shading, it paints the shading’s
gradient fill across the entire clipping region, which may be time-
consuming.

#### 0.8: 8.7.4.3            Shading dictionaries
A shading dictionary specifies details of a particular gradient fill, including the type of shading to be
used, the geometry of the area to be shaded, and the geometry of the gradient fill. Various shading
types are available, depending on the value of the dictionary’s ShadingType entry:
•     Function-based shadings (Type 1) define the colour of every point in the domain using a
mathematical function (not necessarily smooth or continuous).
•     Axial shadings (Type 2) define a colour blend along a line between two points, optionally
extended beyond the boundary points by continuing the boundary colours.
•     Radial shadings (Type 3) define a blend between two circles, optionally extended beyond the
boundary circles by continuing the boundary colours. This type of shading is commonly used to
represent three-dimensional spheres and cones.
•     Free-form Gouraud-shaded triangle meshes (Type 4) define a common construct used by many
three-dimensional applications to represent complex coloured and shaded shapes. Vertices are
specified in free-form geometry.
•     Lattice-form Gouraud-shaded triangle meshes (Type 5) are based on the same geometrical
construct as Type 4 but with vertices specified as a pseudorectangular lattice.
•     Coons patch meshes (Type 6) construct a shading from one or more colour patches, each bounded
by four cubic Bézier curves.
•     Tensor-product patch meshes (Type 7) are similar to Type 6 but with additional control points in
each patch, affording greater control over colour mapping.
NOTE 1      "Table 77 — Entries common to all shading dictionaries" shows the entries that all shading
dictionaries share in common; entries specific to particular shading types are described in the
relevant subclause.
NOTE 2      The term target coordinate space, used in many of the following descriptions, refers to the
coordinate space into which a shading is painted. For shadings used with a Type 2 pattern
dictionary, this is the pattern coordinate space, discussed in 8.7.2, "General properties of
patterns". For shadings used directly with the sh operator, it is the current user space.
Table 77 — Entries common to all shading dictionaries
Key            Type      Value
ShadingType    integer   (Required) The shading type:
1   Function-based shading
2   Axial shading
3   Radial shading
4   Free-form Gouraud-shaded triangle mesh
5   Lattice-form Gouraud-shaded triangle mesh
6   Coons patch mesh
7   Tensor-product patch mesh
ColorSpace     name or   (Required) The colour space in which colour values shall be expressed. This may
array     be any device, CIE-based, or special colour space except a Pattern space. See
8.7.4.4, "Colour space: special considerations" for further information.

Key            Type       Value
Background     array      (Optional) An array of colour components appropriate to the colour space,
specifying a single background colour value. If present, this colour shall be used,
before any painting operation involving the shading, to fill those portions of the
area to be painted that lie outside the bounds of the shading object.
NOTE 1 In the opaque imaging model, the effect is as if the painting operation were
performed twice: first with the background colour and then with the shading.
The background colour shall be applied only when the shading is used as part of
a shading pattern, not when painted directly with the sh operator.
BBox           rectangle (Optional) An array of four numbers giving the left, bottom, right, and top
coordinates, respectively, of the shading’s bounding box. The coordinates shall
be interpreted in the shading’s target coordinate space. If present, this
bounding box shall be applied as a temporary clipping boundary when the
shading is painted, in addition to the current clipping path and any other
clipping boundaries in effect at that time.
NOTE 2 A BBox of zero height or width will still paint one pixel (see 10.7.4, "Scan
conversion rules").
AntiAlias      boolean    (Optional) A flag indicating whether to filter the shading function to prevent
aliasing artifacts.
NOTE 3 The shading operators sample shading functions at a rate determined by the
resolution of the output device. Aliasing can occur if the function is not smooth
— that is, if it has a high spatial frequency relative to the sampling rate. Anti-
aliasing can be computationally expensive and is usually unnecessary, since
most shading functions are smooth enough or are sampled at a high enough
frequency to avoid aliasing effects.
Default value: false.
Shading types 4 to 7 shall be defined by a stream containing descriptive data characterising the
shading’s gradient fill. In these cases, the shading dictionary is also a stream dictionary and may
contain any of the standard entries common to all streams (see "Table 5 — Entries common to all
stream dictionaries"). In particular, the stream dictionary shall include a Length entry.
In addition, some shading dictionaries also include a Function entry whose value shall be a function
object (dictionary or stream) defining how colours vary across the area to be shaded. In such cases, the
shading dictionary usually defines the geometry of the shading, and the function defines the colour
transitions across that geometry. The function is required for some types of shading and optional for
others. Functions are described in detail in 7.10, "Functions".
NOTE 3    Discontinuous colour transitions, or those with high spatial frequency, can exhibit aliasing
effects when painted at low effective resolutions.

#### 0.9: 8.7.4.4        Colour space: special considerations
Conceptually, a shading determines a colour value for each individual point within the area to be
painted. In practice, however, PDF processors may actually compute colour values only for some
subset of the points in the target area, with the colours of the intervening points determined by
interpolation between the ones computed. PDF processors are free to use this strategy as long as the
interpolated colour values approximate those defined by the shading to within the smoothness
tolerance specified in the graphics state (see 10.7.3, "Smoothness tolerance"). The ColorSpace entry
common to all shading dictionaries not only defines the colour space in which the shading specifies its
colour values but also determines the colour space in which colour interpolation is performed.
NOTE 1      Some types of shading (4 to 7) perform interpolation on a parametric value supplied as input to
the shading’s colour function, as described in the relevant subclause. This form of interpolation
is conceptually distinct from the interpolation described here, which operates on the output
colour values produced by the colour function and takes place within the shading’s target colour
space.
Gradient fills between colours defined by most shadings may be implemented using a variety of
interpolation algorithms, and these algorithms may be sensitive to the characteristics of the colour
space.
NOTE 2      Linear interpolation, for example, can have observably different results when applied in a
DeviceCMYK colour space than in a Lab colour space, even if the starting and ending colours are
perceptually identical. The difference arises because the two colour spaces are not linear relative
to each other.
Shadings shall be rendered according to the following rules:
•    If ColorSpace is a device colour space different from the native colour space of the output device,
colour values in the shading shall be converted to the native colour space using the standard
conversion formulas described in 10.4, "Conversions among device colour spaces". To optimise
performance, these conversions may take place at any time (before or after any interpolation on
the colour values in the shading). Thus, shadings defined with device colour spaces may have
colour gradient fills that are less accurate and somewhat device-dependent.
NOTE 3:     This does not apply to shadings having a Function entry in their shading dictionary because
those shading perform gradient fill calculations on a single variable and then convert to
parametric colours.
•    If ColorSpace is a CIE-based colour space, all gradient fill calculations shall be performed in that
space. Conversion to device colours shall occur only after all interpolation calculations have been
performed. Thus, the colour gradients are device-independent for the colours generated at each
point.
•    If ColorSpace is a Separation or DeviceN colour space, a colour conversion (to the alternate
colour space) occurs only if one or more of the specified colourants is not supported by the
device. In that case, gradient fill calculations shall be performed in the designated Separation or
DeviceN colour space before conversion to the alternate space. Thus, nonlinear tint
transformation functions shall be accommodated for an optimal representation of the shading.
•    If ColorSpace is an Indexed colour space, all colour values specified in the shading shall be
immediately converted to the base colour space. Depending on whether the base colour space is a
device or CIE-based space, gradient fill calculations shall be performed as stated above.
Interpolation shall never occur in an Indexed colour space, which is quantised and therefore
inappropriate for calculations that assume a continuous range of colours. For similar reasons, an
Indexed colour space shall not be used in any shading whose colour values are generated by a
function; this rule applies to any shading dictionary that contains a Function entry.

#### 0.10: 8.7.4.5.1        General
In addition to the entries listed in "Table 77 — Entries common to all shading dictionaries", all shading
dictionaries have entries specific to the type of shading they represent, as indicated by the value of

their ShadingType entry. The following subclauses describe the available shading types and the
dictionary entries specific to each.

#### 0.11: 8.7.4.5.2         Type 1 (function-based) shadings
In Type 1 (function-based) shadings, the colour at every point in the domain is defined by a specified
mathematical function. The function need not be smooth or continuous. This type is the most general
of the available shading types and is useful for shadings that cannot be adequately described with any
of the other types. "Table 78 — Additional entries specific to a Type 1 shading dictionary" shows the
shading dictionary entries specific to this type of shading, in addition to those common to all shading
dictionaries (see "Table 77 — Entries common to all shading dictionaries").
This type of shading shall not be used with an Indexed colour space.
Table 78 — Additional entries specific to a Type 1 shading dictionary
Key           Type         Value
Domain        array        (Optional) An array of four numbers [xmin xmax ymin ymax] specifying the rectangular
domain of coordinates over which the colour function(s) are defined. Default value:
[0 1 0 1].
Matrix        array        (Optional) An array of six numbers specifying a transformation matrix mapping the
coordinate space specified by the Domain entry into the shading’s target coordinate
space.
NOTE      To map the domain rectangle [0 1 0 1] to a 1-inch square with lower-left corner at
coordinates (100, 100) in default user space, the Matrix value would be [72 0 0 72
100 100].
Default value: the identity matrix [1 0 0 1 0 0].
Function      function     (Required) A 2-in, n-out function or an array of n 2-in, 1-out functions (where n is
or array     the number of colour components in the shading dictionary’s colour space). Each
function’s domain shall be a superset of that of the shading dictionary. If the value
returned by the function for a given colour component is out of range, it shall be
adjusted to the nearest valid value.
The domain rectangle (Domain) establishes an internal coordinate space for the shading that is
independent of the target coordinate space in which it shall be painted. The colour function(s)
(Function) specify the colour of the shading at each point within this domain rectangle. The
transformation matrix (Matrix) then maps the domain rectangle into a corresponding rectangle or
parallelogram in the target coordinate space. Points within the shading’s bounding box (BBox) that fall
outside this transformed domain rectangle shall be painted with the shading’s background colour
(Background); if the shading dictionary has no Background entry, such points shall be left unpainted.
If the function is undefined at any point within the declared domain rectangle, an error may occur,
even if the corresponding transformed point falls outside the shading’s bounding box.

#### 0.12: 8.7.4.5.3         Type 2 (axial) shadings
Type 2 (axial) shadings define a colour blend that varies along a linear axis between two endpoints and
extends indefinitely perpendicular to that axis. The shading may optionally be extended beyond either
or both endpoints by continuing the boundary colours indefinitely. "Table 79 — Additional entries
specific to a Type 2 shading dictionary" shows the shading dictionary entries specific to this type of
shading, in addition to those common to all shading dictionaries (see "Table 77 — Entries common to
all shading dictionaries").
This type of shading shall not be used with an Indexed colour space.
Table 79 — Additional entries specific to a Type 2 shading dictionary
Key         Type       Value
Coords      array      (Required) An array of four numbers [x0 y0 x1 y1] specifying the starting and ending
coordinates of the axis, expressed in the shading’s target coordinate space. If the
starting and ending coordinates are coincident (x0=x1 and y0=y1) nothing shall be
painted.
Domain      array      (Optional) An array of two numbers [t0 t1] specifying the limiting values of a
parametric variable t. The variable is considered to vary linearly between these
two values as the colour gradient varies between the starting and ending points of
the axis. The variable t becomes the input argument to the colour function(s).
Default value: [0.0 1.0].
Function    function   (Required) A 1-in, n-out function or an array of n 1-in, 1-out functions (where n is
or array   the number of colour components in the shading dictionary’s colour space). The
function(s) shall be called with values of the parametric variable t in the domain
defined by the Domain entry. Each function’s domain shall be a superset of that of
the shading dictionary. If the value returned by the function for a given colour
component is out of range, it shall be adjusted to the nearest valid value.
Extend      array      (Optional) An array of two boolean values specifying whether to extend the
shading beyond the starting and ending points of the axis, respectively. Default
value: [false false].
The colour blend shall be accomplished by linearly mapping each point (x, y) along the axis between
the endpoints (x0, y0) and (x1, y1) to a corresponding point in the domain specified by the shading
dictionary’s Domain entry. The points (0, 0) and (1, 0) in the domain correspond respectively to (x0,
y0) and (x1, y1) on the axis. Since all points along a line in domain space perpendicular to the line from
(0, 0) to (1, 0) have the same colour, only the new value of x needs to be computed:
(𝑥1 − 𝑥0 ) × (𝑥 − 𝑥0 ) + (𝑦1 − 𝑦0 ) × (𝑦 − 𝑦0 )
𝑥′ =
(𝑥1 − 𝑥0 )2 + (𝑦1 − 𝑦0 )2
For 0 ≤ 𝑥 ′ ≤ 1, t = t 0 + (t1 − t 0 ) × 𝑥 ′ .
The value of the parametric variable t is then determined from x′ as follows:
•     For 0 ≤ x′ ≤ 1, 𝑡 = 𝑡0 + (𝑡1 − 𝑡0 ) × x′.
•     For x′ < 0, if the first element of the Extend array is true, then t = t0 ; otherwise, t is undefined and
the point shall be left unpainted.
•     For x′> 1, if the second element of the Extend array is true, then t = t1 ; otherwise, t is undefined
and the point shall be left unpainted.

The resulting value of t shall be passed as input to the function(s) defined by the shading dictionary’s
Function entry, yielding the component values of the colour with which to paint the point (x, y).
NOTE        "Figure 33 — Axial shading" shows three examples of the use of an axial shading to fill a
rectangle and display text. The area to be filled extends beyond the shading’s bounding box. The
shading is the same in all three cases, except for the values of the Background and Extend
entries in the shading dictionary. In the first example, the shading is not extended at either end
and no background colour is specified; therefore, the shading is clipped to its bounding box at
both ends. The second example still has no background colour specified, but the shading is
extended at both ends; the result is to fill the remaining portions of the filled area with the
colours defined at the ends of the shading. In the third example, the shading is not extended at
both ends and a background colour is specified; therefore, the background colour is used for the
portions of the filled area beyond the ends of the shading.
Extend = [false false], Background not specified
Extend = [true true], Background not specified
Extend = [true true], Background specified
Figure 33 — Axial shading

#### 0.13: 8.7.4.5.4         Type 3 (radial) shadings
Type 3 (radial) shadings define a colour blend that varies between two circles. Shadings of this type are
commonly used to depict three-dimensional spheres and cones. Shading dictionaries for this type of
shading contain the entries shown in "Table 80 — Additional entries specific to a Type 3 shading
dictionary", as well as those common to all shading dictionaries (see "Table 77 — Entries common to
all shading dictionaries").
This type of shading shall not be used with an Indexed colour space.
Table 80 — Additional entries specific to a Type 3 shading dictionary
Key          Type        Value
Coords       array       (Required) An array of six numbers [x0 y0 r0 x1 y1 r1] specifying the centres and radii of
the starting and ending circles, expressed in the shading’s target coordinate space.
The radii r0 and r1 shall both be greater than or equal to 0. If one radius is 0, the
corresponding circle shall be treated as a point; if both are 0, nothing shall be
painted.
Domain       array       (Optional) An array of two numbers [t0 t1] specifying the limiting values of a
parametric variable t. The variable is considered to vary linearly between these two
values as the colour gradient varies between the starting and ending circles. The
variable t becomes the input argument to the colour function(s). Default value: [0 1].
Function     function (Required) A 1-in, n-out function or an array of n 1-in, 1-out functions (where n is the
or array number of colour components in the shading dictionary’s colour space). The
function(s) shall be called with values of the parametric variable t in the domain
defined by the shading dictionary’s Domain entry. Each function’s domain shall be a
superset of that of the shading dictionary. If the value returned by the function for a
given colour component is out of range, it shall be adjusted to the nearest valid value.
Extend       array       (Optional) An array of two boolean values specifying whether to extend the shading
beyond the starting and ending circles, respectively. Default value: [false false].
The colour blend is based on a family of blend circles interpolated between the starting and ending
circles that shall be defined by the shading dictionary’s Coords entry. The blend circles shall be defined
in terms of a subsidiary parametric variable. The appearance of the shading shall be as if an infinite
number of such circles are painted in turn, each with an infinitely narrow stroke.
t − t0
s=
t1 − t 0
which varies linearly between 0.0 and 1.0 as t varies across the domain from t0 to t1, as specified by the
dictionary’s Domain entry. The centre and radius of each blend circle shall be given by the following
parametric equations:
𝑥c (s) = 𝑥0 + s × (𝑥1 − 𝑥0 )
𝑦c (s) = 𝑦0 + s × (𝑦1 − 𝑦0 )
r(s) = r0 + s × (r1 − r0 )
Each value of s between 0.0 and 1.0 determines a corresponding value of t, which is passed as the input
argument to the function(s) defined by the shading dictionary’s Function entry. This yields the
component values of the colour with which to paint the corresponding blend circle. For values of s not
lying between 0.0 and 1.0, the boolean elements of the shading dictionary’s Extend array determine
whether and how the shading is extended. If the first of the two elements is true, the shading shall be
extended beyond the defined starting circle to values of s less than 0.0; if the second element is true,
the shading shall be extended beyond the defined ending circle to s values greater than 1.0 unless radii
r0 and r1 in the Coords array are both zero.

NOTE 1      Either of the starting and ending circles can be larger than the other. If the shading is extended at
the smaller end, the family of blend circles continues as far as that value of s for which the radius
of the blend circle r (s) = 0. If the shading is extended at the larger end, the blend circles continue
as far as that s value for which r (s) is large enough to encompass the shading’s entire bounding
box (BBox). Extending the shading can thus cause painting to extend beyond the areas defined
by the two circles themselves. The two examples in the rightmost column of "Figure 34 — Radial
shadings depicting a cone" depict the results of extending the shading at the smaller and larger
ends, respectively.
Figure 34 — Radial shadings depicting a cone
Conceptually, all of the blend circles shall be painted in order of increasing values of s, from smallest to
largest. Blend circles extending beyond the starting circle shall be painted in the same colour defined
by the shading dictionary’s Function entry for the starting circle (t = t0, s = 0.0). Blend circles extending
beyond the ending circle shall be painted in the colour defined for the ending circle (t = t1, s = 1.0). The
painting is opaque, with the colour of each circle completely overlaying those preceding it. Therefore, if
a point lies on more than one blend circle, its final colour shall be that of the last of the enclosing circles
to be painted, corresponding to the greatest value of s.
NOTE 2      If one of the starting and ending circles entirely contains the other, the shading depicts a sphere,
as in "Figure 35 — Radial shadings depicting a sphere" and "Figure 36 — Radial shadings with
extension". In "Figure 35 — Radial shadings depicting a sphere", the inner circle has zero radius;
it is the starting circle in the figure on the left and the ending circle in the figure on the right.
Neither shading is extended at either the smaller or larger end. In "Figure 36 — Radial shadings
with extension", the inner circle in both figures has a non-zero radius and the shading is
extended at the larger end. In each plate, a background colour is specified for the figure on the
right but not for the figure on the left.
Figure 35 — Radial shadings depicting a sphere
Figure 36 — Radial shadings with extension
NOTE 3      If neither circle contains the other, the shading depicts a cone. If the starting circle is larger, the
cone appears to point out of the page. If the ending circle is larger, the cone appears to point into
the page (see "Figure 34 — Radial shadings depicting a cone").
EXAMPLE 1       This example shows the shading used for the objects in the leaf-covered branch in "Figure 37 — Radial
shading effect" (8.7.4.5.4, "Type 3 (radial) shadings"). Each leaf is filled with the same radial shading (object
number 5). The colour function (object 10) is a stitching function (described in 7.10.4, "Type 3 (stitching)
functions") whose two subfunctions (objects 11 and 12) are both exponential interpolation functions (see
7.10.3, "Type 2 (exponential interpolation) functions").
5 0 obj                                                                        %Shading dictionary
<</ShadingType 3
/ColorSpace /DeviceCMYK
/Coords [0.0 0.0 0.096 0.0 0.0                    1.0]                %Concentric circles
/Function 10 0 R
/Extend [true true]
>>
endobj
10 0 obj                                                                       %Colour function
<</FunctionType 3
/Domain [0.0 1.0]
/Functions [11 0 R 12 0 R]
/Bounds [0.708]
/Encode [1.0 0.0 0.0 1.0]
>>
endobj
11 0 obj                                                                       %First subfunction
<</FunctionType 2
/Domain [0.0 1.0]
/C0 [0.929 0.357 1.0 0.298]
/C1 [0.631 0.278 1.0 0.027]
/N 1.048
>>
endobj
12 0 obj                                                                       %Second subfunction
<</FunctionType 2

/Domain [0.0 1.0]
/C0 [0.929 0.357 1.0 0.298]
/C1 [0.941 0.400 1.0 0.102]
/N 1.374
>>
endobj
EXAMPLE 2          This example shows how each leaf shown in "Figure 37 — Radial shading effect" is drawn as a path and then
filled with the shading (where the name Sh1 is associated with object 5 by the Shading subdictionary of the
current resource dictionary; see 7.8.3, "Resource dictionaries").
316.789 140.311 m                                                             %Move to start of leaf
303.222 146.388 282.966 136.518 279.122 121.983 c                             %Curved segment
277.322 120.182 l                                                             %Straight line
285.125 122.688 291.441 121.716 298.156 119.386 c                             %Curved segment
336.448 119.386 l                                                             %Straight line
331.072 128.643 323.346 137.376 316.789 140.311 c                             %Curved segment
W n                                                                           %Set clipping path
q                                                                             %Save graphics state
27.7843 0.00 0.00 -27.7843 310.2461 121.1521 cm                               %Set matrix
/Sh1 sh                                                                       %Paint shading
Q                                                                             %Restore graphics state
Figure 37 — Radial shading effect

#### 0.14: 8.7.4.5.5          Type 4 (free-form Gouraud-shaded triangle mesh) shadings
Type 4 (free-form Gouraud-shaded triangle mesh) shadings are commonly used to represent complex
coloured and shaded three-dimensional shapes. The area to be shaded is defined by a path composed
entirely of triangles. The colour at each vertex of the triangles is specified, and a technique known as
Gouraud interpolation is used to colour the interiors. "Table 81 — Additional entries specific to a Type
4 shading dictionary" shows the entries specific to this type of shading dictionary, in addition to those
common to all shading dictionaries (see "Table 77 — Entries common to all shading dictionaries") and
stream dictionaries (see "Table 5 — Entries common to all stream dictionaries").
Table 81 — Additional entries specific to a Type 4 shading dictionary
Key                       Type       Value
BitsPerCoordinate integer            (Required) The number of bits used to represent each vertex coordinate.
The value shall be 1, 2, 4, 8, 12, 16, 24, or 32.
BitsPerComponent integer             (Required) The number of bits used to represent each colour component.
The value shall be 1, 2, 4, 8, 12, or 16.
Key                  Type      Value
BitsPerFlag          integer   (Required) The number of bits used to represent the edge flag for each
vertex (see below). The value shall be 2, 4, or 8, but only the least
significant 2 bits in each flag value shall be used. The value for the edge flag
shall be 0, 1, or 2.
Decode               array     (Required) An array of numbers specifying how to map vertex coordinates
and colour components into the appropriate ranges of values. The decoding
method is similar to that used in image dictionaries (see 8.9.5.2, "Decode
arrays"). The ranges shall be specified as follows:
[xmin xmax ymin ymax c1,min c1,max… cn,min cn,max]
Only one pair of c values shall be specified if a Function entry is present.
Function             function (Optional) A 1-in, n-out function or an array of n 1-in, 1-out functions
or array (where n is the number of colour components in the shading dictionary’s
colour space). If this entry is present, the colour data for each vertex shall
be specified by a single parametric variable rather than by n separate
colour components. The designated function(s) shall be called with each
interpolated value of the parametric variable to determine the actual colour
at each point. Each input value shall be forced into the range interval
specified for the corresponding colour component in the shading
dictionary’s Decode array. Each function’s domain shall be a superset of
that interval. If the value returned by the function for a given colour
component is out of range, it shall be adjusted to the nearest valid value.
This entry shall not be used with an Indexed colour space.
Unlike shading types 1 to 3, types 4 to 7 shall be represented as streams. Each stream contains a
sequence of vertex coordinates and colour data that defines the triangle mesh. In a Type 4 shading,
each vertex is specified by the following values, in the order shown:
f x y c1… cn
where
f is the vertex’s edge flag (discussed below)
x and y are its horizontal and vertical coordinates
c1… cn are its colour components
All vertex coordinates shall be expressed in the shading’s target coordinate space. If the shading
dictionary includes a Function entry, only a single parametric value, t, shall be specified for each
vertex in place of the colour components c1… cn.
The edge flag associated with each vertex determines the way it connects to the other vertices of the
triangle mesh. A vertex va with an edge flag value fa = 0 begins a new triangle, unconnected to any other.
At least two more vertices (vb and vc) shall be provided, but their edge flags shall be ignored. These
three vertices define a triangle (va, vb, vc), as shown in "Figure 38 — Starting a new triangle in a free-
form Gouraud-shaded triangle mesh".

Figure 38 — Starting a new triangle in a free-form Gouraud-shaded triangle mesh
Subsequent triangles shall be defined by a single new vertex combined with two vertices of the
preceding triangle. Given triangle (va, vb, vc), where vertex va precedes vertex vb in the data stream and vb
precedes vc, a new vertex vd can form a new triangle on side vbc or side vac, as shown in "Figure 39 —
Connecting triangles in a free-form Gouraud-shaded triangle mesh". (Side vab is assumed to be shared
with a preceding triangle and therefore is not available for continuing the mesh.) If the edge flag is fd =
1 (side vbc), the next vertex forms the triangle (vb, vc, vd); if the edge flag is fd = 2 (side vac), the next vertex
forms the triangle (va, vc, vd). An edge flag of fd = 0 starts a new triangle, as described above.
Figure 39 — Connecting triangles in a free-form Gouraud-shaded triangle mesh
Complex shapes can be created by using the edge flags to control the edge on which subsequent
triangles are formed.
EXAMPLE           "Figure 40 — Varying the value of the edge flag to create different shapes" shows two simple examples.
Mesh1 begins with triangle 1 and uses the following edge flags to draw each succeeding triangle:
1 (𝑓𝑎 = 𝑓𝑏 = 𝑓𝑐 = 0)                              7 (𝑓𝑖 = 2)
2 (𝑓𝑑 = 1)                                        8 (𝑓𝑗 = 2)
3 (𝑓𝑒 = 1)                                        9 (𝑓𝑘 = 2)
4 (𝑓𝑓 = 1)                                        10 (𝑓𝑙 = 1)
5 (𝑓𝑔 = 1)                                        11 (𝑓𝑚 = 1)
6 (𝑓ℎ = 1)
Mesh 2 again begins with triangle 1 and uses the following edge flags:
1 (𝑓𝑎 = 𝑓𝑏 = 𝑓𝑐 = 0)                              4 (𝑓𝑓 = 2)
2 (𝑓𝑑 = 1)                                        5 (𝑓𝑔 = 2)
3 (𝑓𝑒 = 2)                                         6 (𝑓ℎ = 2)
The stream shall provide vertex data for a whole number of triangles with appropriate edge flags;
otherwise, an error occurs.
Figure 40 — Varying the value of the edge flag to create different shapes
The data for each vertex consists of the following items, reading in sequence from higher-order to
lower-order bit positions:
•    An edge flag, expressed in BitsPerFlag bits
•    A pair of horizontal and vertical coordinates, expressed in BitsPerCoordinate bits each
•    A set of n colour components (where n is the number of components in the shading’s colour
space), expressed in BitsPerComponent bits each, in the order expected by the sc operator
Each set of vertex data shall occupy a whole number of bytes. If the total number of bits required is not
divisible by 8, the last data byte for each vertex is padded at the end with extra bits, which shall be
ignored. The coordinates and colour values shall be decoded according to the Decode array in the
same way as in an image dictionary (see 8.9.5.2, "Decode arrays").
If the shading dictionary contains a Function entry, the colour data for each vertex shall be specified
by a single parametric value t rather than by n separate colour components. All linear interpolation
within the triangle mesh shall be done using the t values. After interpolation, the results shall be passed
to the function(s) specified in the Function entry to determine the colour at each point.

#### 0.15: 8.7.4.5.6       Type 5 (lattice-form Gouraud-shaded triangle mesh) shadings
Type 5 (lattice-form Gouraud-shaded triangle mesh) shadings are similar to Type 4, but instead of
using free-form geometry, their vertices are arranged in a pseudorectangular lattice, which is
topologically equivalent to a rectangular grid. The vertices are organised into rows, which need not be

geometrically linear (see "Figure 41 — Lattice-form triangle meshes").
Figure 41 — Lattice-form triangle meshes
"Table 82 — Additional entries specific to a Type 5 shading dictionary" shows the shading dictionary
entries specific to this type of shading, in addition to those common to all shading dictionaries (see
"Table 77 — Entries common to all shading dictionaries") and stream dictionaries (see "Table 5 —
Entries common to all stream dictionaries").
The data stream for a Type 5 shading has the same format as for Type 4, except that Type 5 does not
use edge flags to define the geometry of the triangle mesh. The data for each vertex thus consists of the
following values, in the order shown:
x y c1… cn
where
x and y shall be the vertex’s horizontal and vertical coordinates
c1… cn shall be its colour components
Table 82 — Additional entries specific to a Type 5 shading dictionary
Key                       Type          Value
BitsPerCoordinate         integer       (Required) The number of bits used to represent each vertex coordinate.
The value shall be 1, 2, 4, 8, 12, 16, 24, or 32.
BitsPerComponent          integer       (Required) The number of bits used to represent each colour component.
The value shall be 1, 2, 4, 8, 12, or 16.
VerticesPerRow            integer       (Required) The number of vertices in each row of the lattice; the value
shall be greater than or equal to 2. The number of rows need not be
specified.
Decode                    array         (Required) An array of numbers specifying how to map vertex
coordinates and colour components into the appropriate ranges of
values. The decoding method is similar to that used in image dictionaries
(see 8.9.5.2, "Decode arrays"). The ranges shall be specified as follows:
[xmin xmax ymin ymax c1,min c1,max… cn,min cn,max]
Only one pair of c values shall be specified if a Function entry is present.
Key                  Type             Value
Function             function         (Optional) A 1-in, n-out function or an array of n 1-in, 1-out functions
or array         (where n is the number of colour components in the shading dictionary’s
colour space). If this entry is present, the colour data for each vertex shall
be specified by a single parametric variable rather than by n separate
colour components. The designated function(s) shall be called with each
interpolated value of the parametric variable to determine the actual
colour at each point. Each input value shall be forced into the range
interval specified for the corresponding colour component in the shading
dictionary’s Decode array. Each function’s domain shall be a superset of
that interval. If the value returned by the function for a given colour
component is out of range, it shall be adjusted to the nearest valid value.
This entry shall not be used with an Indexed colour space.
All vertex coordinates shall be expressed in the shading’s target coordinate space. If the shading
dictionary includes a Function entry, only a single parametric value, t, shall be specified for each
vertex in place of the colour components c1… cn.
The VerticesPerRow entry in the shading dictionary gives the number of vertices in each row of the
lattice. All of the vertices in a row shall be specified sequentially, followed by those for the next row.
Given m rows of k vertices each, the triangles of the mesh shall be constructed using the following
triplets of vertices, as shown in "Figure 41 — Lattice-form triangle meshes":
(𝑉𝑖,𝑗 , 𝑉𝑖,𝑗+1 , 𝑉𝑖+1,𝑗 )                        for 0 ≤ 𝑖 ≤ 𝑚 − 2, 0 ≤ 𝑗 ≤ 𝑘 − 2
(𝑉𝑖,𝑗+1 , 𝑉𝑖+1,𝑗 , 𝑉𝑖+1,𝑗+1 )
See 8.7.4.5.5, "Type 4 (free-form Gouraud-shaded triangle mesh) shadings" for further details on the
format of the vertex data.
8.7.4.5.7        Type 6 (Coons patch mesh) shadings

#### 0.16: 8.7.4.5.7        Type 6 (Coons patch mesh) shadings
by four cubic Bézier curves. Degenerate Bézier curves are allowed and are useful for certain graphical
effects. At least one complete patch shall be specified.
A Coons patch generally has two independent aspects:
•     Colours are specified for each corner of the unit square, and bilinear interpolation is used to fill in
colours over the entire unit square (see the upper figure in "Figure 42 — Coons patch mesh").
•     Coordinates are mapped from the unit square into a four-sided patch whose sides are not
necessarily linear (see the lower figure in "Figure 42 — Coons patch mesh". The mapping is
continuous: the corners of the unit square map to corners of the patch and the sides of the unit
square map to sides of the patch, as shown in "Figure 43 — Coordinate mapping from a unit
square to a four-sided Coons Patch".

Figure 42 — Coons patch mesh
The sides of the patch are given by four cubic Bézier curves, C1, C2, D1, and D2, defined over a pair of
parametric variables, u and v, that vary horizontally and vertically across the unit square. The four
corners of the Coons patch satisfy the following equations:
C1 (0) = D1 (0)
C1 (1) = D2 (0)
C2 (0) = D1 (1)
C2 (1) = D2 (1)
Figure 43 — Coordinate mapping from a unit square to a four-sided Coons Patch
Two surfaces can be described that are linear interpolations between the boundary curves. Along the u
axis, the surface SC is defined by
SC (u, v) = (1 − v) × C1 (u) + v × C2 (u)
Along the v axis, the surface SD is given by
SD (u, v) = (1 − u) × D1 (v) + u × D2 (v)
A third surface is the bilinear interpolation of the four corners:
SB (u, v) = (1 − v) × [(1 − u) × C1 (0) + u × C1 (1)] + v × [(1 − u) × C2 (0) + u × C2 (1)]
The coordinate mapping for the shading is given by the surface S, defined as
S = SC + SD − SB
This defines the geometry of each patch. A patch mesh is constructed from a sequence of one or more
such coloured patches.
Patches can sometimes appear to fold over on themselves — for example, if a boundary curve
intersects itself. As the value of parameter u or v increases in parameter space, the location of the
corresponding pixels in device space may change direction so that new pixels are mapped onto
previous pixels already mapped. If more than one point (u, v) in parameter space is mapped to the
same point in device space, the point selected shall be the one with the largest value of v. If multiple
points have the same v, the one with the largest value of u shall be selected. If one patch overlaps
another, the patch that appears later in the data stream shall paint over the earlier one.
NOTE       The patch is a control surface rather than a painting geometry. The outline of a projected square
(that is, the painted area) need not be the same as the patch boundary if, for example, the patch
folds over on itself, as shown in "Figure 44 — Painted area and boundary of a Coons Patch".

Figure 44 — Painted area and boundary of a Coons Patch
"Table 83 — Additional entries specific to a Type 6 shading dictionary" shows the shading dictionary
entries specific to this type of shading, in addition to those common to all shading dictionaries (see
"Table 77 — Entries common to all shading dictionaries") and stream dictionaries (see "Table 5 —
Entries common to all stream dictionaries").
Table 83 — Additional entries specific to a Type 6 shading dictionary
Key                      Type        Value
BitsPerCoordinate integer            (Required) The number of bits used to represent each geometric
coordinate. The value shall be 1, 2, 4, 8, 12, 16, 24, or 32.
BitsPerComponent integer             (Required) The number of bits used to represent each colour component.
The value shall be 1, 2, 4, 8, 12, or 16.
BitsPerFlag              integer     (Required) The number of bits used to represent the edge flag for each
patch (see below). The value shall be 2, 4, or 8, but only the least significant
2 bits in each flag value shall be used. Valid values for the edge flag shall be
0, 1, 2, and 3.
Decode                   array       (Required) An array of numbers specifying how to map coordinates and
colour components into the appropriate ranges of values. The decoding
method is similar to that used in image dictionaries (see 8.9.5.2, "Decode
arrays"). The ranges shall be specified as follows:
[xmin xmax ymin ymax c1,min c1,max… cn,min cn,max]
Only one pair of c values shall be specified if a Function entry is present.
Key                   Type       Value
Function              function (Optional) A 1-in, n-out function or an array of n 1-in, 1-out functions
or array (where n is the number of colour components in the shading dictionary’s
colour space). If this entry is present, the colour data for the corner points
of each patch shall be specified by a single parametric variable rather than
by n separate colour components. The designated function(s) shall be
called with each interpolated value of the parametric variable to determine
the actual colour at each point. Each input value shall be forced into the
range interval specified for the corresponding colour component in the
shading dictionary’s Decode array. Each function’s domain shall be a
superset of that interval. If the value returned by the function for a given
colour component is out of range, it shall be adjusted to the nearest valid
value.
This entry shall not be used with an Indexed colour space.
The data stream provides a sequence of Bézier control points and colour values that define the shape
and colours of each patch. All of a patch’s control points shall be given first, followed by the colour
values for its corners. This differs from a triangle mesh (shading types 4 and 5), in which the
coordinates and colour of each vertex are given together. All control point coordinates shall be
expressed in the shading’s target coordinate space. See 8.7.4.5.5, "Type 4 (free-form Gouraud-shaded
triangle mesh) shadings" for further details on the format of the data.
As in free-form triangle meshes (Type 4), each patch has an edge flag that indicates which edge, if any,
it shares with the previous patch. An edge flag of 0 begins a new patch, unconnected to any other. This
shall be followed by 12 pairs of coordinates, x1 y1 x2 y2…x12 y12, which specify the Bézier control points
that define the four boundary curves. "Figure 45 — Colour values and edge flags in Coons Patch
meshes" shows how these control points correspond to the cubic Bézier curves C1, C2, D1, and D2
identified in "Figure 43 — Coordinate mapping from a unit square to a four-sided Coons Patch". Colour
values shall be given for the four corners of the patch, in the same order as the control points
corresponding to the corners. Thus, c1 is the colour at coordinates (x1, y1), c2 at (x4, y4), c3 at (x7, y7), and
c4 at (x10, y10), as shown in the figure.
Figure 45 — Colour values and edge flags in Coons Patch meshes

"Figure 45 — Colour values and edge flags in Coons Patch meshes" also shows how non-zero values of
the edge flag (f = 1, 2, or 3) connect a new patch to one of the edges of the previous patch. In this case,
some of the previous patch’s control points serve implicitly as control points for the new patch as well
(see "Figure 46 — Edge connections in a Coons Patch Mesh"), and therefore shall not be explicitly
repeated in the data stream. "Table 84 — Data Values in a Coons Patch Mesh" summarises the required
data values for various values of the edge flag.
Figure 46 — Edge connections in a Coons Patch Mesh
If the shading dictionary contains a Function entry, the colour data for each corner of a patch shall be
specified by a single parametric value t rather than by n separate colour components c1… cn. All linear
interpolation within the mesh shall be done using the t values. After interpolation, the results shall be
passed to the function(s) specified in the Function entry to determine the colour at each point.
Table 84 — Data Values in a Coons Patch Mesh
Edge Flag          Next Set of Data Values
f=0                   𝑥1 𝑦1 𝑥2 𝑦2 𝑥3 𝑦3 𝑥4 𝑦4 𝑥5 𝑦5 𝑥6 𝑦6
𝑥7 𝑦7 𝑥8 𝑦8 𝑥9 𝑦9 𝑥10 𝑦10 𝑥11 𝑦11 𝑥12 𝑦12
c1 c2 c3 c4
New patch; no implicit values
Edge Flag       Next Set of Data Values
f=1             𝑥5 𝑦5 𝑥6 𝑦6 𝑥7 𝑦7 𝑥8 𝑦8 𝑥9 𝑦9 𝑥10 𝑦10 𝑥11 𝑦11 𝑥12 𝑦12
c3 c4
Implicit values:
(𝑥1 , 𝑦1 ) = (𝑥4, 𝑦4 ) previous                 c1 = c2 previous
(𝑥2 , 𝑦2 ) = (𝑥5, 𝑦5 ) previous                 c2 = c3 previous
(𝑥3 , 𝑦3 ) = (𝑥6, 𝑦6 ) previous
(𝑥4 , 𝑦4 ) = (𝑥7, 𝑦7 ) previous
f=2             𝑥5 𝑦5 𝑥6 𝑦6 𝑥7 𝑦7 𝑥8 𝑦8 𝑥9 𝑦9 𝑥10 𝑦10 𝑥11 𝑦11 𝑥12 𝑦12
c3 c4
Implicit values:
(𝑥1 , 𝑦1 ) = (𝑥7, 𝑦7 ) previous                 c1 = c3 previous
(𝑥2 , 𝑦2 ) = (𝑥8, 𝑦8 ) previous                 c2 = c4 previous
(𝑥3 , 𝑦3 ) = (𝑥9, 𝑦9 ) previous
(𝑥4 , 𝑦4 ) = (𝑥10, 𝑦10 ) previous
f=3              𝑥5 𝑦5 𝑥6 𝑦6 𝑥7 𝑦7 𝑥8 𝑦8 𝑥9 𝑦9 𝑥10 𝑦10 𝑥11 𝑦11 𝑥12 𝑦12
c3 c4
Implicit values:
(𝑥1 , 𝑦1 ) = (𝑥10, 𝑦10 ) previous     c1 = c4 previous
(𝑥2 , 𝑦2 ) = (𝑥11, 𝑦11 ) previous     c2 = c1 previous
(𝑥3 , 𝑦3 ) = (𝑥12, 𝑦12 ) previous
(𝑥4 , 𝑦4 ) = (𝑥1, 𝑦1 ) previous
8.7.4.5.8          Type 7 (tensor-product patch mesh) shadings
Type 7 (tensor-product patch mesh) shadings are identical to Type 6, except that they are based on a

#### 0.17: 8.7.4.5.8          Type 7 (tensor-product patch mesh) shadings
Coons patch. The shading dictionaries representing the two patch types differ only in the value of the
ShadingType entry and in the number of control points specified for each patch in the data stream.
NOTE        Although the Coons patch is more concise and easier to use, the tensor-product patch affords
greater control over colour mapping.
Like the Coons patch mapping, the tensor-product patch mapping is controlled by the location and
shape of four cubic Bézier curves marking the boundaries of the patch. However, the tensor-product
patch has four additional, "internal" control points to adjust the mapping. The 16 control points can be
arranged in a 4-by-4 array indexed by row and column, as follows (see "Figure 47 — Control points in
a tensor-product patch"):

p03     p13       p23     p33
p02     p12       p22     p32
p01     p11       p21     p31
p00     p10       p20     p30
Figure 47 — Control points in a tensor-product patch
As in a Coons patch mesh, the geometry of the tensor-product patch is described by a surface defined
over a pair of parametric variables, u and v, which vary horizontally and vertically over the unit square.
The surface is defined by the equation
3     3
S(u, v) = ∑ ∑ pij × Bi (u) × Bj (v)
i=0 j=0
where pij is the control point in column i and row j of the tensor, and Bi and Bj are the Bernstein
polynomials
B0 (t) = (1 − t)3
B1 (t) = 3t × (1 − t)2
B2 (t) = 3t 2 × (1 − t)
B3 (t) = t 3
Since each point pij is actually a pair of coordinates (xij, yij), the surface can also be expressed as
3     3
𝑥(u, v) = ∑ ∑ 𝑥ij × Bi (u) × Bj (v)
i=0 j=0
3 3
𝑦(u, v) = ∑ ∑ 𝑦ij × Bi (u) × Bj (v)
i=0 j=0
The geometry of the tensor-product patch can be visualized in terms of a cubic Bézier curve moving
from the bottom boundary of the patch to the top. At the bottom and top, the control points of this
curve coincide with those of the patch’s bottom (p00…p30) and top (p03…p33) boundary curves,
respectively. As the curve moves from the bottom edge of the patch to the top, each of its four control
points follows a trajectory that is in turn a cubic Bézier curve defined by the four control points in the
corresponding column of the array. That is, the starting point of the moving curve follows the
trajectory defined by control points p00…p03, the trajectory of the ending point is defined by points
p30…p33, and those of the two intermediate control points by p10…p13 and p20…p23. Equivalently, the patch
can be considered to be traced by a cubic Bézier curve moving from the left edge to the right, with its
control points following the trajectories defined by the rows of the coordinate array instead of the
columns.
The Coons patch (Type 6) is actually a special case of the tensor-product patch (Type 7) in which the
four internal control points (p11, p12, p21, p22) are implicitly defined by the boundary curves. The values
of the internal control points are given by these equations
𝑝11 = (−4 × 𝑝00 + 6 × (𝑝01 + 𝑝10 ) − 2 × (𝑝03 + 𝑝30 ) + 3 × (𝑝31 + 𝑝13 ) − 1 × 𝑝33 )
𝑝12 = (−4 × 𝑝03 + 6 × (𝑝02 + 𝑝13 ) − 2 × (𝑝00 + 𝑝33 ) + 3 × (𝑝32 + 𝑝10 ) − 1 × 𝑝30 )
𝑝21 = (−4 × 𝑝30 + 6 × (𝑝31 + 𝑝20 ) − 2 × (𝑝33 + 𝑝00 ) + 3 × (𝑝01 + 𝑝23 ) − 1 × 𝑝03 )
𝑝22 = (−4 × 𝑝33 + 6 × (𝑝32 + 𝑝23 ) − 2 × (𝑝30 + 𝑝03 ) + 3 × (𝑝02 + 𝑝20 ) − 1 × 𝑝00 )
In the more general tensor-product patch, the values of these four points are unrestricted.
The coordinates of the control points in a tensor-product patch shall be specified in the shading’s data
stream in the following order:
4     5      6       7
3     14     15      8
2     13     16      9
1     12     11      10
All control point coordinates shall be expressed in the shading’s target coordinate space. These shall be
followed by the colour values for the four corners of the patch, in the same order as the corners
themselves. If the patch’s edge flag f is 0, all 16 control points and four corner colours shall be explicitly
specified in the data stream. If f is 1, 2, or 3, the control points and colours for the patch’s shared edge
are implicitly understood to be the same as those along the specified edge of the previous patch and
shall not be repeated in the data stream. "Table 85 — Data values in a tensor-product patch mesh"
summarises the data values for various values of the edge flag f, expressed in terms of the row and
column indices used in "Figure 47 — Control points in a tensor-product patch". See 8.7.4.5.5, "Type 4
(free-form Gouraud-shaded triangle mesh) shadings" for further details on the format of the data.

