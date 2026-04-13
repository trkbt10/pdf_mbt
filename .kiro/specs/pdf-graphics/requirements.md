# SDD Draft

Generated from:
- `spec/extracted/8.1-8.5-graphics-state.spec.txt`

## Requirements

### Requirement 1: 8.1      General
The graphics operators used in PDF content streams describe the appearance of pages that are to be
reproduced on an output device. The facilities described in this clause are intended for both printer
and display applications.
The graphics operators form six main groups:
•    Graphics state operators manipulate the data structure called the graphics state, the global
framework within which the other graphics operators execute. The graphics state includes the
current transformation matrix (CTM), which maps user space coordinates used within a PDF
content stream into output device coordinates. It also includes the current colour, the current
clipping path, and many other parameters that are implicit operands of the painting operators.
•    Path construction operators specify paths, which define shapes, line trajectories, and regions of
various sorts. They include operators for beginning a new path, adding line segments and curves
to it, and closing it.
•    Path-painting operators fill a path with a colour, paint a stroke along it, or use it as a clipping
boundary.
•    Other painting operators paint certain self-describing graphics objects. These include sampled
images, geometrically defined shadings, and entire content streams that in turn contain sequences
of graphics operators.
•    Text operators select and show character glyphs from fonts (descriptions of typefaces for
representing text characters). Because PDF treats glyphs as general graphical shapes, many of the
text operators could be grouped with the graphics state or painting operators. However, the data
structures and mechanisms for dealing with glyph and font descriptions are sufficiently
specialised that clause 9, "Text" focuses on them.
•    Marked-content operators associate higher-level logical information with objects in the content
stream. This information does not affect the rendered appearance of the content (although it may
determine if the content should be presented at all; see 8.11, "Optional content"); it is useful to
applications that use PDF for document interchange. Marked-content is described in 14.6,
"Marked content".
This clause presents general information about device-independent graphics in PDF: how a PDF
content stream describes the abstract appearance of a page. Rendering — the device-dependent part of
graphics — is covered in clause 10, "Rendering". The Bibliography lists a number of books that give
details of these computer graphics concepts and their implementation.

### Requirement 2: 8.2      Graphics objects
As discussed in 7.8.2, "Content streams", the data in a content stream shall be interpreted as a
sequence of operators and their operands, expressed as basic data objects according to standard PDF
syntax. A content stream can describe the appearance of a page, or it can be treated as a graphical
element in certain other contexts.
The operands and operators shall be written sequentially using postfix notation. Although this notation
resembles the sequential execution model of the PostScript language, a PDF content stream is not a
program to be interpreted; rather, it is a static description of a sequence of graphics objects. There are
specific rules, described below, for writing the operands and operators that describe a graphics object.
PDF provides five types of graphics objects:
•   A path object is an arbitrary shape made up of straight lines, rectangles, and cubic Bézier curves. A
path may intersect itself and may have disconnected sections and holes. A path object ends with
one or more painting operators that specify whether the path shall be stroked, filled, used as a
clipping boundary, or some combination of these operations.
•   A text object consists of one or more character strings that identify sequences of glyphs to be
painted. Like a path, text can be stroked, filled, or used as a clipping boundary.
•   An external object (XObject) is an object defined outside the content stream and referenced as a
named resource (see 7.8.3, "Resource dictionaries"). The interpretation of an XObject depends on
its type. An image XObject defines a rectangular array of colour samples to be painted; a form
XObject is an entire content stream to be treated as a single graphics object. Specialised types of
form XObjects shall be used to import content from one PDF file into another (reference XObjects)
and to group graphical elements together as a unit for various purposes (group XObjects). In
particular, the latter are used to define transparency groups for use in the transparent imaging
model (transparency group XObjects, discussed in detail in clause 11, "Transparency").
•   An inline image object uses a special syntax to express the data for a small image directly within
the content stream.
•   A shading object describes a geometric shape whose colour is an arbitrary function of position
within the shape. (A shading can also be treated as a colour when painting other graphics objects;
it is not considered to be a separate graphics object in that case.)
PDF 1.3 and earlier versions use an opaque imaging model in which each graphics object is painted in
sequence, completely obscuring any previous marks it may overlay on the page. PDF 1.4 introduced a
transparent imaging model in which objects can be less than fully opaque, allowing previously painted
marks to show through. Each object is painted on the page with a specified opacity, which may be
constant at every point within the object’s shape or may vary from point to point. The previously
existing contents of the page form a backdrop with which the new object is composited, producing
results that combine the colours of the object and backdrop according to their respective opacity
characteristics. The objects at any given point on the page form a transparency stack, where the
stacking order is defined to be the order in which the objects shall be specified, bottommost object
first. All objects in the stack can potentially contribute to the result, depending on their colours, shapes,
and opacities.
PDF’s graphics parameters are so arranged that objects shall be painted by default with full opacity,
reducing the behaviour of the transparent imaging model to that of the opaque model. Accordingly, the
material in this clause applies to both the opaque and transparent models except where explicitly
stated otherwise; the transparent model is described in its full generality in clause 11, "Transparency".
Although the painting behaviour described above is often attributed to individual operators making up
an object, it is always the object as a whole that is painted. "Figure 9 — Graphics objects" shows the
ordering rules for the operations that define graphics objects. Only those operators that are listed in
"Figure 9 — Graphics objects" for each type of graphics object or in the intervals between graphics
objects (called the content stream level in the figure) shall be used in that context. Every content stream
begins at the content stream level, where changes may be made to the graphics state, such as colours
and text attributes, as discussed in the following subclauses.
In "Figure 9 — Graphics objects", arrows indicate the operators that mark the beginning or end of each

type of graphics object. Some operators are identified individually, others by general category. "Table
50 — Operator categories" summarises these categories for all PDF operators.
Table 50 — Operator categories
Category                        Operators                           Location
General graphics state          w, J, j, M, d, ri, i, gs, q, Q      "Table 56 — Graphics state operators"
Special graphics state          cm                                  "Table 56 — Graphics state operators"
Path construction               m, l, c, v, y, h, re                "Table 58 — Path construction operators"
Path painting                   S, s, f, F, f*, B, B*, b, b*, n     "Table 59 — Path-painting operators"
Clipping paths                  W, W*                               "Table 60 — Clipping path operators"
Text objects                    BT, ET                              "Table 105 — Text object operators"
Text state                      Tc, Tw, Tz, TL, Tf, Tr, Ts          "Table 103 — Text state operators"
Text positioning                Td, TD, Tm, T*                      "Table 106 — Text-positioning operators"
Text showing                    Tj, TJ, ', "                        "Table 107 — Text-showing operators"
Type 3 fonts                    d0, d1                              "Table 111 — Type 3 font operators"
Colour                          CS, cs, SC, SCN, sc, scn, G, g,     "Table 73 — Colour operators"
RG, rg, K, k
Shading patterns                Sh                                  "Table 76 — Shading operator"
Inline images                   BI, ID, EI                          "Table 90 — Inline image operators"
XObjects                        Do                                  "Table 86 — XObject operator"
Marked-content                  MP, DP, BMC, BDC, EMC               "Table 351 — Entries in a data dictionary"
Compatibility                   BX, EX                              "Table 33 — Compatibility operators"
Figure 9 — Graphics objects
EXAMPLE        The path construction operators m and re signal the beginning of a path object. Inside the path object,
additional path construction operators are permitted, as are the clipping path operators W and W*, but not
general graphics state operators such as w or J. A path-painting operator, such as S or f, ends the path object
and returns to the content stream level.
NOTE 1    "Table 50 — Operator categories" and "Figure 9 — Graphics objects" were updated in this
document (2020).
NOTE 2    A PDF reader can process a content stream whose operations violate these rules for describing
graphics objects and can produce unpredictable behaviour, even though it can display and print
the stream correctly. PDF processors that attempt to extract graphics objects for editing or other
purposes often depend on the objects being well formed. The rules for graphics objects are also
important for the proper interpretation of marked-content (see 14.6, "Marked content").
A graphics object also implicitly includes all graphics state parameters that affect its behaviour. For
instance, a path object depends on the value of the current colour parameter at the moment the path

object is defined. The effect shall be as if this parameter were specified as part of the definition of the
path object. However, the operators that are invoked at the content stream level to set graphics state
parameters shall not be considered to belong to any particular graphics object. Graphics state
parameters should be specified only when they change. A graphics object can depend on parameters
that were defined much earlier.
Similarly, the individual character strings within a text object implicitly include the graphics state
parameters on which they depend. Most of these parameters may be set inside or outside the text
object. The effect is as if they were separately specified for each text string.
The important point is that there is no semantic significance to the exact arrangement of graphics state
operators. When processing a PDF content stream a PDF processor may change an arrangement of
graphics state operators to any other arrangement that achieves the same values of the relevant
graphics state parameters for each graphics object. PDF processors shall not infer any higher-level
logical semantics from the arrangement of tokens constituting a graphics object. A separate
mechanism, marked-content (see 14.6, "Marked content"), allows such higher-level information to be
explicitly associated with the graphics objects.

#### 2.1: 8.3.1 General
Coordinate systems define the canvas on which all painting occurs. They determine the position,
orientation, and size of the text, graphics, and images that appear on a page. This subclause describes
each of the coordinate systems used in PDF, how they are related, and how transformations among
them are specified.
NOTE        The coordinate systems discussed in this subclause apply to two-dimensional graphics. PDF 1.6
introduced the ability to display 3D artwork, in which objects are described in a three-
dimensional coordinate system, as described in 13.6.5, "Coordinate systems for 3D".

#### 2.2: 8.3.2.1           General
Paths and positions shall be defined in terms of pairs of coordinates on the Cartesian plane. A
coordinate pair is a pair of real numbers x and y that locate a point horizontally and vertically within a
two-dimensional coordinate space. A coordinate space is determined by the following properties with
respect to the current page:
•    The location of the origin
•    The orientation of the x and y axes
•    The lengths of the units along each axis
PDF defines several coordinate spaces in which the coordinates specifying graphics objects shall be
interpreted. The following subclauses describe these spaces and the relationships among them.
Transformations among coordinate spaces shall be defined by transformation matrices, which can
specify any linear mapping of two-dimensional coordinates, including translation, scaling, rotation,
reflection, and skewing. Transformation matrices are discussed in 8.3.3, "Common transformations"
and 8.3.4, "Transformation matrices".

#### 2.3: 8.3.2.2        Device space
The contents of a page ultimately appear on a raster output device such as a display or a printer. Such
devices vary greatly in the built-in coordinate systems they use to address pixels within their
imageable areas. A particular device’s coordinate system is called its device space. The origin of the
device space on different devices can fall in different places on the output page; on displays, the origin
can vary depending on the window system. Because the paper or other output medium moves through
different printers and imagesetters in different directions, the axes of their device spaces may be
oriented differently. For instance, vertical (y) coordinates may increase from the top of the page to the
bottom on some devices and from bottom to top on others. Finally, different devices have different
resolutions; some even have resolutions that differ in the horizontal and vertical directions.
NOTE      If coordinates in a PDF file were specified in device space, the file would be device-dependent
and would appear differently on different devices.
EXAMPLE        Images specified in the typical device spaces of a 72-pixel-per-inch display and a 600-dot-per-inch printer
would differ in size by more than a factor of 8; an 8-inch line segment on the display would appear less than
1 inch long on the printer. "Figure 10 — Device space" shows how the same graphics object, specified in
device space, can appear drastically different when rendered on different output devices.
Figure 10 — Device space

#### 2.4: 8.3.2.3        User space
To avoid the device-dependent effects of specifying objects in device space, PDF defines a device-
independent coordinate system that always bears the same relationship to the current page, regardless
of the output device on which printing or displaying occurs. This device-independent coordinate
system is called user space.
The user space coordinate system shall be initialised to a default state for each page of a document. The
CropBox entry in the page dictionary shall specify the rectangle of user space corresponding to the
visible area of the intended output medium (display window or printed page). The positive x axis
extends horizontally to the right and the positive y axis vertically upward, as in standard mathematical
practice (subject to alteration by the Rotate entry in the page dictionary). The length of a unit along
both the x and y axes is set by the UserUnit entry (PDF 1.6) in the page dictionary (see "Table 31 —
Entries in a page object"). If that entry is not present or supported, the default value of 1 ⁄ 72 inch is
used. This coordinate system is called default user space.

NOTE 1      In the PostScript language, the origin of default user space always corresponds to the lower-left
corner of the output medium. While this convention is common in PDF documents as well, it is
not required; the page dictionary’s CropBox entry can specify any rectangle of default user space
to be made visible on the medium.
NOTE 2      The default for the size of the unit in default user space (1 ⁄ 72 inch) is approximately the same
as a point, a unit widely used in the printing industry. It is not exactly the same, however; there is
no universal definition of a point.
Conceptually, user space is an infinite plane. Only a small portion of this plane corresponds to the
imageable area of the output device: a rectangular region defined by the CropBox entry in the page
dictionary. The region of default user space that is viewed or printed can be different for each page and
is described in 14.11.2, "Page boundaries".
Coordinates in user space (as in any other coordinate space) may be specified as either integers or real
numbers, and the unit size in default user space does not constrain positions to any arbitrary grid. The
resolution of coordinates in user space is not related to the resolution of pixels in device space.
The transformation from user space to device space is defined by the current transformation matrix
(CTM), an element of the PDF graphics state (see 8.4, "Graphics state"). A PDF reader may adjust the
CTM for the native resolution of a particular output device, maintaining the device-independence of the
PDF page description. "Figure 11 — User space" shows how this allows an object specified in user
space to appear the same regardless of the device on which it is rendered.
The default user space provides a consistent, dependable starting place for PDF page descriptions
regardless of the output device used. If necessary, a PDF content stream may modify user space to be
more suitable to its needs by applying the coordinate transformation operator, cm (see 8.4.4, "Graphics
state operators"). Thus, what might appear to be absolute coordinates in a content stream are not
absolute with respect to the current page because they are expressed in a coordinate system that can
slide around and shrink or expand. Coordinate system transformation not only enhances device-
independence but is a useful tool in its own right.
EXAMPLE           A content stream originally composed to occupy an entire page can be incorporated without change as an
element of another page by shrinking the coordinate system in which it is drawn.
Figure 11 — User space

#### 2.5: 8.3.2.4         Other coordinate spaces
In addition to device space and user space, PDF uses a variety of other coordinate spaces for
specialised purposes:
•    The coordinates of text shall be specified in text space. The transformation from text space to user
space shall be defined by a text matrix in combination with several text-related parameters in the
graphics state (see 9.4.2, "Text-positioning operators").
•    Character glyphs in a font shall be defined in glyph space ("see 9.2.4, "Glyph positioning and
metrics"). The transformation from glyph space to text space shall be defined by the font matrix.
For most types of fonts, this matrix shall be predefined to map 1000 units of glyph space to 1 unit
of text space; for Type 3 fonts, the font matrix shall be given explicitly in the font dictionary ("see
9.6.4, "Type 3 fonts").
•    All sampled images shall be defined in image space. The transformation from image space to user
space shall be predefined and cannot be changed. All images shall be 1 unit wide by 1 unit high in
user space, regardless of the number of samples in the image. To be painted, an image shall be
mapped to a region of the page by temporarily altering the CTM.
•    A form XObject (discussed in 8.10, "Form XObjects") is a self-contained content stream that can be
treated as a graphical element within another content stream. The space in which it is defined is
called form space. The transformation from form space to user space shall be specified by a form
matrix contained in the form XObject.
•    PDF 1.2 defined a type of colour known as a pattern, discussed in 8.7, "Patterns". A pattern shall
be defined either by a content stream that shall be invoked repeatedly to tile an area or by a
shading whose colour is a function of position. The space in which a pattern is defined is called
pattern space. The transformation from pattern space to user space shall be specified by a pattern
matrix contained in the pattern.
•    PDF 1.6 embedded 3D artwork, which is described in three-dimensional coordinates (see 13.6.5,
"Coordinate systems for 3D") that are projected into an annotation’s target coordinate system
(see 13.6.2, "3D Annotations").

#### 2.6: 8.3.2.5         Relationships among coordinate spaces
"Figure 12 — Relationships among coordinate systems" shows the relationships among the coordinate
spaces described above. Each arrow in the figure represents a transformation from one coordinate
space to another. PDF allows modifications to many of these transformations.

Figure 12 — Relationships among coordinate systems
Because PDF coordinate spaces are defined relative to one another, changes made to one
transformation can affect the appearance of objects defined in several coordinate spaces.
EXAMPLE           A change in the CTM, which defines the transformation from user space to device space, affects forms, text,
images, and patterns, since they are all upstream from user space.

#### 2.7: 8.3.3 Common transformations
A transformation matrix specifies the relationship between two coordinate spaces. By modifying a
transformation matrix, objects can be scaled, rotated, translated, or transformed in other ways.
A transformation matrix in PDF shall be specified by six numbers, usually in the form of an array
containing six elements. In its most general form, this array is denoted [a b c d e f]; it can represent any
linear transformation from one coordinate system to another. This subclause lists the arrays that
specify the most common transformations; 8.3.4, "Transformation matrices", discusses more
mathematical details of transformations, including information on specifying transformations that are
combinations of those listed here:
•    Translations shall be specified as [ 1 0 0 1 𝑡𝑥 𝑡𝑦 ], where tx and ty shall be the distances to translate
the origin of the coordinate system in the horizontal and vertical dimensions, respectively.
•    Scaling shall be obtained by [ 𝑠𝑥 0 0 𝑠𝑦 0 0]. This scales the coordinates so that 1 unit in the
horizontal and vertical dimensions of the new coordinate system is the same size as sx and sy
units, respectively, in the previous coordinate system.
•    Rotations shall be produced by [rc rs -rs rc 0 0], where rc = cos(q) and rs = sin(q) which has the
effect of rotating the coordinate system axes by an angle q counter clockwise.
•    Skew shall be specified by [1 wx wy 1 0 0], where wx = tan(a) and wy = tan(b) which skews the x
axis by an angle a and the y axis by an angle b.
"Figure 13 — Effects of coordinate transformations" shows examples of each transformation. The
directions of translation, rotation, and skew shown in the figure correspond to positive values of the
array elements.
Figure 13 — Effects of coordinate transformations
NOTE 1    If several transformations are combined, the order in which they are applied is significant. For
example, first scaling and then translating the x axis is not the same as first translating and then
scaling it. In general, to obtain the expected results, transformations need to be done in the
following order: Translate, Rotate, Scale or skew.
"Figure 14 — Effect of transformation order" shows the effect of the order in which transformations
are applied. The figure shows two sequences of transformations applied to a coordinate system. After
each successive transformation, an outline of the letter n is drawn.
Figure 14 — Effect of transformation order
NOTE 2    The following transformations are shown in the figure: a translation of 10 units in the x direction
and 20 units in the y direction; a rotation of 30 degrees; a scaling by a factor of 3 in the x
direction
In the figure, the axes are shown with a dash pattern having a 2-unit dash and a 2-unit gap. In
addition, the original (untransformed) axes are shown in a lighter colour for reference. Notice
that the scale-rotate-translate ordering results in a distortion of the coordinate system, leaving

the x and y axes no longer perpendicular; the recommended translate-rotate-scale ordering
results in no distortion.

#### 2.8: 8.3.4 Transformation matrices
This subclause discusses the mathematics of transformation matrices.
To understand the mathematics of coordinate transformations in PDF, it is vital to remember two
points:
•    Transformations alter coordinate systems, not graphics objects. All objects painted before a
transformation is applied shall be unaffected by the transformation. Objects painted after the
transformation is applied shall be interpreted in the transformed coordinate system.
•    Transformation matrices specify the transformation from the new (transformed) coordinate system
to the original (untransformed) coordinate system. All coordinates used after the transformation
shall be expressed in the transformed coordinate system. PDF applies the transformation matrix
to find the equivalent coordinates in the untransformed coordinate system.
NOTE 1       Many computer graphics textbooks consider transformations of graphics objects rather than of
coordinate systems. Although either approach is correct and self-consistent, some details of the
calculations differ depending on which point of view is taken.
PDF represents coordinates in a two-dimensional space. The point (x, y) in such a space can be
expressed in vector form as [x y 1]. The constant third element of this vector (1) is needed so that the
vector can be used with 3-by-3 matrices in the calculations described below.
The transformation between two coordinate systems can be represented by a 3-by-3 transformation
matrix written as follows:
a b 0
[ c d 0]
e f 1
Because a transformation matrix has only six elements that can be changed, in most cases in PDF it
shall be specified as the six-element array [a b c d e f].
Coordinate transformations shall be expressed as matrix multiplications:
a b 0
[𝑥 ′   𝑦′   1] = [𝑥    𝑦      1] × [c d 0]
e f 1
Because PDF transformation matrices specify the conversion from the transformed coordinate system
to the original (untransformed) coordinate system, x′ and y′ in this equation shall be the coordinates in
the untransformed coordinate system, and x and y shall be the coordinates in the transformed system.
The multiplication is carried out as follows:
𝑥′ = a × 𝑥 + c × 𝑦 + e
𝑦′ = b × 𝑥 + d × 𝑦 + f
If a series of transformations is carried out, the matrices representing each of the individual
transformations can be multiplied together to produce a single equivalent matrix representing the
composite transformation.
NOTE 2      Matrix multiplication is not commutative — the order in which matrices are multiplied is
significant. Consider a sequence of two transformations: a scaling transformation applied to the
user space coordinate system, followed by a conversion from the resulting scaled user space to
device space. Let MS be the matrix specifying the scaling and MC the current transformation
matrix, which transforms user space to device space. Recalling that coordinates are always
specified in the transformed space, the correct order of transformations first converts the scaled
coordinates to default user space and then converts the default user space coordinates to device
space. This can be expressed as:
XD = XU × MC = (XS × MS ) × MC = XS × (MS × MC )
where:
XD denotes the coordinates in device space
XU denotes the coordinates in default user space
XS denotes the coordinates in scaled user space
This shows that when a new transformation is concatenated with an existing one, the matrix
representing it shall be multiplied before (premultiplied with) the existing transformation matrix.
This result is true in general for PDF: when a sequence of transformations is carried out, the matrix
representing the combined transformation (M′) is calculated by premultiplying the matrix
representing the additional transformation (MT) with the one representing all previously existing
transformations (M):
𝑀′ = 𝑀𝑇 × 𝑀
NOTE 3      When rendering graphics objects, it is sometimes necessary for a PDF reader to perform the
inverse of a transformation — that is, to find the user space coordinates that correspond to a
given pair of device space coordinates. Not all transformations are invertible, however. For
example, if a matrix contains a, b, c, and d elements that are all zero, all user coordinates map to
the same device coordinates and there is no unique inverse transformation. Such noninvertible
transformations are not very useful and generally arise from unintended operations, such as
scaling by 0. Use of a noninvertible matrix when painting graphics objects can result in
unpredictable behaviour.

### Requirement 3: 8.4      Graphics state
8.4.1 General

#### 3.1: 8.4.1 General
graphics control parameters. These parameters define the global framework within which the graphics
operators execute.
EXAMPLE 1       The f (fill) operator implicitly uses the current colour parameter, and the S (stroke) operator additionally
uses the current line width parameter from the graphics state.
A PDF processor shall initialise the graphics state at the beginning of each page with the values
specified in "Table 51 — Device-independent graphics state parameters" and "Table 52 — Device-
dependent graphics state parameters". "Table 51 — Device-independent graphics state parameters"
lists those graphics state parameters that are device-independent and are appropriate to specify in
page descriptions. The parameters listed in "Table 52 — Device-dependent graphics state parameters"
control details of the rendering (scan conversion) process and are device-dependent; a page

description that is intended to be device-independent should not be written to modify these
parameters.
Table 51 — Device-independent graphics state parameters
Parameter                    Type           Value
CTM                          array          The current transformation matrix, which maps positions from user
coordinates to device coordinates (see 8.3, "Coordinate systems"). This
matrix is modified by each application of the coordinate transformation
operator, cm. Initial value: a matrix that transforms default user coordinates
to device coordinates.
clipping path                (internal)     The current clipping path, which defines the boundary against which all
output shall be cropped (see 8.5.4, "Clipping path operators"). Initial value:
the size of the MediaBox.
color space                  name or        The current colour space in which colour values shall be interpreted (see 8.6,
array          "Colour spaces"). There are two separate colour space parameters: one for
stroking and one for all other painting operations. Initial value: DeviceGray.
color                        (various)      The current colour that shall be used during painting operations (see 8.6,
"Colour spaces"). The type and interpretation of this parameter depend on
the current colour space; for most colour spaces, a colour value consists of
one to four numbers. There are two separate colour parameters: one for
stroking and one for all other painting operations. Initial value: black.
text state                   (various)      A set of nine graphics state parameters that pertain only to the painting of
text. These include parameters that select the font, scale the glyphs to an
appropriate size, and accomplish other effects. The text state parameters are
described in 9.3, "Text state parameters and operators".
line width                   number         The thickness, in user space units, of paths to be stroked (see 8.4.3.2, "Line
width"). Initial value: 1.0.
line cap                     integer        A code specifying the shape of the start and endcaps for an open stroked
path or the caps at both ends of dashes in a stroked path (see 8.4.3.3, "Line
cap style"). Initial value: 0, for butt caps.
line join                    integer        A code specifying the shape of joints between connected segments of a
stroked path ("see 8.4.3.4, "Line join style"). Initial value: 0, for mitered joins.
miter limit                  number         The miter limit imposes a maximum on the ratio of the miter length to the
line width. When the limit is exceeded, the join is converted from a miter to a
bevel (see 8.4.3.5, "Miter limit"). This parameter limits the length of "spikes"
produced when line segments join at sharp angles. Initial value: 10.0, for a
miter cutoff below approximately 11.5 degrees.
dash pattern                 array and      A description of the dash pattern that shall be used when paths are stroked
number         (see 8.4.3.6, "Line dash pattern"). Initial value: [] 0, a solid line.
rendering intent             name           The rendering intent that shall be used when converting CIE-based colours
to device colours (see 8.6.5.8, "Rendering intents"). Initial value:
RelativeColorimetric.

Parameter           Type        Value
stroke adjustment   boolean     (PDF 1.2) A flag specifying whether to compensate for possible rasterization
effects when stroking a path with a line width that is small relative to the
pixel resolution of the output device (see 10.7.5, "Automatic stroke
adjustment").
NOTE     This is considered a device-independent parameter, even though the
details of its effects are device-dependent.
Initial value: false.
blend mode          name or     (PDF 1.4, array is deprecated in PDF 2.0) The current blend mode that shall
array       be used in the transparent imaging model (see 11.3.5, "Blend mode"). A PDF
(array is   reader shall implicitly reset this parameter to its initial value at the
deprecated beginning of execution of a transparency group XObject (see 11.6.6,
in PDF 2.0) "Transparency group XObjects").
The value shall be either a name object, designating one of the standard
blend modes listed in "Table 134 — Standard separable blend modes" and
"Table 135 — Standard non-separable blend modes" in 11.3.5, "Blend
mode", or an array of such names. In the latter case, the PDF reader shall use
the first blend mode in the array that it recognises (or Normal if it
recognises none of them).
Initial value: Normal.
soft mask           dictionary (PDF 1.4) A soft-mask dictionary (see 11.6.5.1, "Soft-mask dictionaries")
or name    specifying the mask shape or mask opacity values that shall be used in the
transparent imaging model (see 11.3.7.2, "Source shape and opacity" and
11.6.4.3, "Mask shape and opacity"), or the name None if no such mask is
specified. A PDF reader shall implicitly reset this parameter to its initial
value at the beginning of execution of a transparency group XObject (see
11.6.6, "Transparency group XObjects"). Initial value: None.
alpha constant      number      (PDF 1.4) The constant shape or constant opacity value that shall be used in
the transparent imaging model (see 11.3.7.2, "Source shape and opacity" and
11.6.4.4, "Constant shape and opacity"). There are two separate alpha
constant parameters: one for stroking and one for all other painting
operations. A PDF reader shall implicitly reset this parameter to its initial
value at the beginning of execution of a transparency group XObject (see
11.6.6, "Transparency group XObjects"). Initial value: 1.0.
alpha source        boolean     (PDF 1.4) A flag specifying whether the current soft mask and alpha constant
parameters shall be interpreted as shape values (true) or opacity values
(false). This flag also governs the interpretation of the SMask entry, if any, in
an image dictionary (see 8.9.5, "Image dictionaries"). Initial value: false.
black point         name        (PDF 2.0) The black point compensation algorithm that shall be used when
compensation                    converting CIE-based colours (see 8.6.5.9, "Use of black point
compensation"). Initial value: Default.

Table 52 — Device-dependent graphics state parameters
Parameter                 Type            Value
overprint                 boolean         (PDF 1.2) A flag specifying (on output devices that support the overprint
control feature) whether painting in one set of colourants should cause the
corresponding areas of other colourants to be erased (false) or left
unchanged (true); see 8.6.7, "Overprint control". PDF 1.3, introduced two
separate overprint parameters: one for stroking and one for all other painting
operations. Initial value: false.
overprint mode            number          (PDF 1.3) A code specifying whether a colour component value of 0 in a
DeviceCMYK colour space should erase that component (0) or leave it
unchanged (1) when overprinting (see 8.6.7, "Overprint control"). Initial
value: 0.
black generation          function or     (PDF 1.2) A function that calculates the level of the black colour component to
name            use when converting RGB colours to CMYK (see 10.4.2.4, "Conversion from
DeviceRGB to DeviceCMYK"). Initial value: a PDF reader shall initialise this to
a suitable device dependent value.
undercolor removal        function or     (PDF 1.2) A function that calculates the reduction in the levels of the cyan,
name            magenta, and yellow colour components to compensate for the amount of
black added by black generation (see 10.4.2.4, "Conversion from DeviceRGB
to DeviceCMYK"). Initial value: a PDF reader shall initialise this to a suitable
device dependent value.
transfer                  function,       (PDF 1.2, deprecated in PDF 2.0) A function that adjusts device gray or colour
name, or        component levels to compensate for nonlinear response in a particular
array           output device (see 10.5, "Transfer functions"). Initial value: a PDF reader
shall initialise this to a suitable device dependent value.
halftone                  dictionary,     (PDF 1.2) A halftone screen for gray and colour rendering, specified as a
stream, or      halftone dictionary or stream (see 10.6, "Halftones"). Initial value: a PDF
name            reader shall initialise this to a suitable device dependent value.
flatness                  number          The precision with which curves shall be rendered on the output device (see
10.7.2, "Flatness tolerance"). The value of this parameter (positive number)
gives the maximum error tolerance, measured in output device pixels;
smaller numbers give smoother curves at the expense of more computation
and memory use. Initial value: 1.0.
smoothness                number          (PDF 1.3) The precision with which colour gradients are to be rendered on
the output device (see 10.7.3, "Smoothness tolerance"). The value of this
parameter (0 to 1.0) gives the maximum error tolerance, expressed as a
fraction of the range of each colour component; smaller numbers give
smoother colour transitions at the expense of more computation and memory
use. Initial value: a PDF reader shall initialise this to a suitable device
dependent value.
NOTE 1       Some graphics state parameters are set with specific PDF operators, some are set by including a
particular entry in a graphics state parameter dictionary, and some can be specified either way.
EXAMPLE 2        The current line width can be set either with the w operator or (in PDF 1.3) with the LW entry in a graphics
state parameter dictionary, whereas the current colour is set only with specific operators, and the current

halftone is set only with a graphics state parameter dictionary.
In general, a PDF processor, when interpreting the operators that set graphics state parameters, shall
simply store them unchanged for later use when interpreting the painting operators. However, some
parameters have special properties or call for behaviour that a PDF processor shall handle:
•    Most parameters shall be of the correct type or have values that fall within a certain range.
•    Parameters that are numeric values, such as the current colour, line width, and miter limit, shall
be clipped into valid range, if necessary. However, they shall not be adjusted to reflect capabilities
of the raster output device, such as resolution or number of distinguishable colours. Painting
operators perform such adjustments, but the adjusted values shall not be stored back into the
graphics state.
•    Paths shall be internal objects that shall not be directly represented in PDF.
NOTE 2     As indicated in "Table 51 — Device-independent graphics state parameters" and "Table 52 —
Device-dependent graphics state parameters", some of the parameters — colour space, colour,
and overprint — have two values, one used for stroking (of paths and text objects) and one for
all other painting operations. The two parameter values can be set independently, allowing for
operations such as combined filling and stroking of the same path with different colours. Except
where noted, a term such as current colour is to be interpreted to refer to whichever colour
parameter applies to the operation being performed. When necessary, the individual colour
parameters are distinguished explicitly as the stroking colour and the nonstroking colour.

#### 3.2: 8.4.2 Graphics state stack
A PDF document typically contains many graphical elements that are independent of each other and
nested to multiple levels. The graphics state stack allows these elements to make local changes to the
graphics state without disturbing the graphics state of the surrounding environment. The stack is a
LIFO (last in, first out) data structure in which the contents of the graphics state may be saved and later
restored using the following operators:
•    The q operator shall push a copy of the entire graphics state onto the stack.
•    The Q operator shall restore the entire graphics state to its former value by popping it from the
stack.
NOTE       These operators can be used to encapsulate a graphical element so that it can modify parameters
of the graphics state and later restore them to their previous values.
Occurrences of the q and Q operators shall be balanced within a given content stream (or within the
sequence of streams specified in a page dictionary’s Contents array).

#### 3.3: 8.4.3.1         General
This subclause gives details of several of the device-independent graphics state parameters listed in
"Table 51 — Device-independent graphics state parameters".

#### 3.4: 8.4.3.2         Line width
The line width parameter specifies the thickness of the line used to stroke a path. It shall be a non-
negative number expressed in user space units; stroking a path shall entail painting all points whose
perpendicular distance from the path in user space is less than or equal to half the line width. The

effect produced in device space depends on the current transformation matrix (CTM) in effect at the
time the path is stroked. If the CTM specifies scaling by different factors in the horizontal and vertical
dimensions, the thickness of stroked lines in device space shall vary according to their orientation. The
actual line width achieved can differ from the requested width by as much as 2 device pixels,
depending on the positions of lines with respect to the pixel grid. Automatic stroke adjustment may be
used to ensure uniform line width; see 10.7.5, "Automatic stroke adjustment".
A line width of 0 shall denote the thinnest line that can be rendered at device resolution: 1 device pixel
wide. However, some devices cannot reproduce 1-pixel lines, and on high-resolution devices, they are
nearly invisible. Since the results of rendering such zero-width lines are device-dependent, they should
not be used.

#### 3.5: 8.4.3.3           Line cap style
The line cap style shall specify the shape that shall be used at both ends of open subpaths (and dashes
8.4.3.6, "Line dash pattern") when they are stroked. "Table 53 — Line cap styles" shows the allowed
values.
Table 53 — Line cap styles
Style         Appearance                Description
0                                       Butt cap. The stroke shall be squared off at the endpoint of the path. There
shall be no projection beyond the end of the path.
1                                       Round cap. A semicircular arc with a diameter equal to the line width shall
be drawn around the endpoint and shall be filled in.
2                                       Projecting square cap. The stroke shall continue beyond the endpoint of
the path for a distance equal to half the line width and shall be squared off.

#### 3.6: 8.4.3.4           Line join style
The line join style shall specify the shape to be used at the corners of paths that are stroked. "Table 54
— Line join styles" shows the allowed values. Join styles shall be significant only at points where
consecutive segments of a path connect at an angle; segments that meet or intersect fortuitously shall
receive no special treatment.
Table 54 — Line join styles
Style         Appearance              Description
0                                     Miter join. The outer edges of the strokes for the two segments shall be
extended until they meet at an angle, as in a picture frame. If the segments
meet at too sharp an angle (as defined by the miter limit parameter — see
8.4.3.5, "Miter limit"), a bevel join shall be used instead.
Style       Appearance             Description
1                                  Round join. An arc of a circle with a diameter equal to the line width shall
be drawn around the point where the two segments meet, connecting the
outer edges of the strokes for the two segments. This pie-slice-shaped
figure shall be filled in, producing a rounded corner.
2                                  Bevel join. The two segments shall be finished with butt caps (see 8.4.3.3,
"Line cap style") and the resulting notch beyond the ends of the segments
shall be filled with a triangle.
A zero length dash occurring at a zero length subpath segment does not have a determinable direction
and thus, if the line caps are non-round is rendered in an implementation-dependent manner.
In a closed subpath that is dashed, if the first segment starts with an on-dash and the last segment ends
within an on-dash, then they shall be joined.
NOTE      The definition of round join was changed in PDF 1.5. In rare cases, the implementation of the
previous specification could produce unexpected results.

#### 3.7: 8.4.3.5        Miter limit
When two line segments meet at a sharp angle and mitered joins have been specified as the line join
style, it is possible for the miter to extend far beyond the thickness of the line stroking the path. The
miter limit shall impose a maximum on the ratio of the miter length to the line width (see "Figure 15 —
Miter length"). When the limit is exceeded, the join is converted from a miter to a bevel.
The ratio of miter length to line width is directly related to the angle j between the segments in user
space by the following formula:
𝑚𝑖𝑡𝑒𝑟𝐿𝑒𝑛𝑔𝑡ℎ        1
=
𝑙𝑖𝑛𝑒𝑊𝑖𝑑𝑡ℎ            𝑗
sin 2
When the line width is zero, the miter length is zero.
NOTE      Very large miter lengths are allowed.
EXAMPLE        A miter limit of 1.414 converts miters to bevels for j less than 90 degrees, a limit of 2.0 converts them for j

less than 60 degrees, and a limit of 10.0 converts them for j less than approximately 11.5 degrees.
Figure 15 — Miter length
8.4.3.6              Line dash pattern

#### 3.8: 8.4.3.6              Line dash pattern
specified by a dash array and a dash phase. The dash array’s elements shall be numbers that specify the
lengths of alternating dashes and gaps; the numbers shall be nonnegative and not all zero. The dash
phase shall be a number that specifies the distance into the dash pattern at which to start the dash. If
the dash phase is negative, it shall be incremented by twice the sum of all lengths in the dash array
until it is positive. The elements of both the dash array and the dash phase shall be expressed in user
space units.
Before beginning to stroke a path, the dash array shall be cycled through, adding up the lengths of
dashes and gaps. When the accumulated length equals the value specified by the dash phase, stroking
of the path shall begin, and the dash array shall be used cyclically from that point onward. "Table 55 —
Examples of line dash patterns" shows examples of line dash patterns. If the dash array is empty, the
dash phase shall be zero and the path shall be stroked with a solid, unbroken line.
Table 55 — Examples of line dash patterns
Dash Array          Appearance                             Description
and Phase
[] 0                                                       No dash; solid, unbroken lines
[3] 0                                                      3 units on, 3 units off, …
[2] 1                                                      1 on, 2 off, 2 on, 2 off, …
[2 1] 0                                                    2 on, 1 off, 2 on, 1 off, …
[3 5] 6                                                    2 off, 3 on, 5 off, 3 on, 5 off, …
[2 3] 11                                                   1 on, 3 off, 2 on, 3 off, 2 on, …
[2 1 3] 0                                                  2 on, 1 off, 3 on, 2 off, 1 on, 3 off, 2 on, …
[2 1 3] -2                                                 2 off, 2 on, 1 off, 3 on, 2 off, 1 on, 3 off, …
Dashed lines shall wrap around curves and corners just as solid stroked lines do. The ends of each dash
shall be treated with the current line cap style, and corners within dashes shall be treated with the
current line join style. The treatment of overlapping line caps shall follow the rules given in 11.6.2,
"Specifying source and backdrop colours". A stroking operation shall take no measures to coordinate
the dash pattern with features of the path; it simply shall dispense dashes and gaps along the path in
the pattern defined by the dash array. If the end of a dashed segment coincides exactly with a join
point, then the end cap is painted before the corner.
When a path consisting of several subpaths is stroked, each subpath shall be treated independently —
that is, the dash pattern shall be restarted and the dash phase shall be reapplied to it at the beginning
of each subpath.
NOTE         As noted in 8.5.3.2, "Stroking" and in "Table 58 — Path construction operators", closed paths
have no end caps, but the individual dash segments of a path stroked using a non-empty line
dash pattern are individually open paths and therefore receive end cap processing as specified in
the graphics state. If any dash segment includes a corner then that corner is painted using the
current join style in the graphics state. If a corner is not contained within any dashed segment
the corner is not painted.
8.4.4 Graphics state operators

#### 3.9: 8.4.4 Graphics state operators
graphics state. (See also the colour operators listed in "Table 73 — Colour operators" and the text state
operators in "Table 103 — Text state operators".)
Table 56 — Graphics state operators
Operands            Operator    Description
—                   q           Save the current graphics state on the graphics state stack (see 8.4.2, "Graphics
state stack").
—                   Q           Restore the graphics state by removing the most recently saved state from the
stack and making it the current state (see 8.4.2, "Graphics state stack").
abcdef              cm          Modify the current transformation matrix (CTM) by concatenating the
specified matrix (see 8.3.2, "Coordinate spaces"). Although the operands
specify a matrix, they shall be written as six separate numbers, not as an array.
lineWidth           w           Set the line width in the graphics state (see 8.4.3.2, "Line width").
lineCap             J           Set the line cap style in the graphics state (see 8.4.3.3, "Line cap style").
lineJoin            j           Set the line join style in the graphics state (see 8.4.3.4, "Line join style").
miterLimit          M           Set the miter limit in the graphics state (see 8.4.3.5, "Miter limit").
dashArray           d           Set the line dash pattern in the graphics state (see 8.4.3.6, "Line dash pattern").
dashPhase
intent              ri          (PDF 1.1) Set the colour rendering intent in the graphics state (see 8.6.5.8,
"Rendering intents").

Operands             Operator       Description
flatness             i              Set the flatness tolerance in the graphics state (see 10.7.2, "Flatness
tolerance"). flatness is a number in the range 0 to 100; a value of 0 shall specify
the output device’s default flatness tolerance.
dictName             gs             (PDF 1.2) Set the specified parameters in the graphics state. dictName shall be
the name of a graphics state parameter dictionary in the ExtGState
subdictionary of the current resource dictionary (see the next subclause).

#### 3.10: 8.4.5 Graphics state parameter dictionaries
While some parameters in the graphics state may be set with individual operators, as shown in "Table
56 — Graphics state operators", others may not. The latter may only be set with the generic graphics
state operator gs (PDF 1.2). The operand supplied to this operator shall be the name of a graphics state
parameter dictionary whose contents specify the values of one or more graphics state parameters. This
name shall be looked up in the ExtGState subdictionary of the current resource dictionary.
The graphics state parameter dictionary is also used by Type 2 patterns, which do not have a content
stream in which the graphics state operators could be invoked (see 8.7.4, "Shading patterns").
Each entry in the parameter dictionary shall specify the value of an individual graphics state
parameter, as shown in "Table 57 — Entries in a graphics state parameter dictionary". All entries need
not be present for every invocation of the gs operator; the supplied parameter dictionary may include
any combination of parameter entries. The results of gs shall be cumulative; parameter values
established in previous invocations persist until explicitly overridden.
NOTE        Note that some parameters appear in both "Table 56 — Graphics state operators" and "Table 57
— Entries in a graphics state parameter dictionary"; these parameters can be set either with
individual graphics state operators or with gs. It is expected that any future extensions to the
graphics state will be implemented by adding new entries to the graphics state parameter
dictionary rather than by introducing new graphics state operators.
Table 57 — Entries in a graphics state parameter dictionary
Key                       Type         Value
Type                      name         (Optional) The type of PDF object that this dictionary describes; shall be
ExtGState for a graphics state parameter dictionary.
LW                        number       (Optional; PDF 1.3) The line width (see 8.4.3.2, "Line width").
LC                        integer      (Optional; PDF 1.3) The line cap style (see 8.4.3.3, "Line cap style").
LJ                        integer      (Optional; PDF 1.3) The line join style (see 8.4.3.4, "Line join style").
ML                        number       (Optional; PDF 1.3) The miter limit (see 8.4.3.5, "Miter limit").
D                         array        (Optional; PDF 1.3) The line dash pattern, expressed as an array of the form
[dashArray dashPhase], where dashArray shall be itself an array and
dashPhase shall be a number (see 8.4.3.6, "Line dash pattern").
Key            Type          Value
RI             name          (Optional; PDF 1.3) The name of the rendering intent (see 8.6.5.8, "Rendering
intents").
OP             boolean       (Optional) A flag specifying whether to apply overprint (see 8.6.7, "Overprint
control"). In PDF 1.2 and earlier, there is a single overprint parameter that
applies to all painting operations. Beginning with PDF 1.3, two separate
overprint parameters were defined: one for stroking and one for all other
painting operations. Specifying an OP entry shall set both parameters unless
there is also an op entry in the same graphics state parameter dictionary, in
which case the OP entry shall set only the overprint parameter for stroking.
op             boolean       (Optional; PDF 1.3) A flag specifying whether to apply overprint (see 8.6.7,
"Overprint control") for painting operations other than stroking. If this entry
is absent, the OP entry, if any, shall also set this parameter.
OPM            integer       (Optional; PDF 1.3) The overprint mode (see 8.6.7, "Overprint control").
Font           array         (Optional; PDF 1.3) An array of the form [font size], where font shall be an
indirect reference to a font dictionary and size shall be a number expressed in
text space units. These two objects correspond to the operands of the Tf
operator (see 9.3, "Text state parameters and operators"); however, the first
operand shall be an indirect object reference instead of a resource name.
BG             function      (Optional) The black-generation function, which maps the interval [0.0 1.0] to
the interval [0.0 1.0] (see 10.4.2.4, "Conversion from DeviceRGB to
DeviceCMYK").
BG2            function or (Optional; PDF 1.3) Same as BG except that the value may also be the name
name        Default, denoting the black-generation function that was in effect at the start
of the page. If both BG and BG2 are present in the same graphics state
parameter dictionary, BG2 shall take precedence.
UCR            function      (Optional) The undercolour-removal function, which maps the interval
[0.0 1.0] to the interval [−1.0 1.0] (see 10.4.2.4, "Conversion from DeviceRGB
to DeviceCMYK").
UCR2           function or (Optional; PDF 1.3) Same as UCR except that the value may also be the name
name        Default, denoting the undercolour-removal function that was in effect at the
start of the page. If both UCR and UCR2 are present in the same graphics
state parameter dictionary, UCR2 shall take precedence.
TR             function,     (Optional, deprecated in PDF 2.0) The transfer function, which maps the
name, or      interval [0.0 1.0] to the interval [0.0 1.0] (see 10.5, "Transfer functions"). The
array         value shall be either a single function (which applies to all process
colourants) or an array of four functions (which apply to the process
colourants individually). The name Identity may be used to represent the
Identity function.
TR2            function,     (Optional; PDF 1.3, deprecated in PDF 2.0) Same as TR except that the value
name, or      may also be the name Default, denoting the transfer function that was in
array         effect at the start of the page. If both TR and TR2 are present in the same
graphics state parameter dictionary, TR2 shall take precedence.
HT             dictionary,   (Optional) The halftone dictionary or stream (see 10.6, "Halftones") or the
stream, or    name Default, denoting the halftone that was in effect at the start of the page.
name

Key                    Type           Value
FL                     number         (Optional; PDF 1.3) The flatness tolerance (see 10.7.2, "Flatness tolerance").
SM                     number         (Optional; PDF 1.3) The smoothness tolerance (see 10.7.3, "Smoothness
tolerance").
SA                     boolean        (Optional) A flag specifying whether to apply automatic stroke adjustment
(see 10.7.5, "Automatic stroke adjustment").
BM                     name or     (Optional; PDF 1.4; array is deprecated in PDF 2.0) The current blend mode
array       that shall be used in the transparent imaging model (see 11.3.5, "Blend
(array is   mode").
deprecated
in PDF 2.0)
SMask                  dictionary     (Optional; PDF 1.4) The current soft mask, specifying the mask shape or mask
or name        opacity values that shall be used in the transparent imaging model (see
11.3.7.2, "Source shape and opacity" and 11.6.4.3, "Mask shape and opacity").
Although the current soft mask is sometimes referred to as a "soft clip",
altering it with the gs operator completely replaces the old value with the
new one, rather than intersecting the two as is done with the current clipping
path parameter (see 8.5.4, "Clipping path operators").
CA                     number         (Optional; PDF 1.4) The current stroking alpha constant, specifying the
constant shape or constant opacity value that shall be used for stroking
operations in the transparent imaging model (see 11.3.7.2, "Source shape and
opacity" and 11.6.4.4, "Constant shape and opacity").
ca                     number         (Optional; PDF 1.4) Same as CA, but for nonstroking operations.
AIS                    boolean        (Optional; PDF 1.4) The alpha source flag ("alpha is shape"), specifying
whether the current soft mask and alpha constant shall be interpreted as
shape values (true) or opacity values (false). This flag also governs the
interpretation of the SMask entry, if any, in an image dictionary (see 8.9.5,
"Image dictionaries").
TK                     boolean        (Optional; PDF 1.4) The text knockout flag, shall determine the behaviour of
overlapping glyphs within a text object in the transparent imaging model (see
9.3.8, "Text knockout"). This flag controls the behavior of glyphs obtained
from any font type, including Type 3.
UseBlackPtComp         name           (Optional; PDF 2.0) This graphics state parameter controls whether black
point compensation is performed while doing CIE-based colour conversions.
It shall be set to either OFF, ON or Default. The semantics of Default are up to
the PDF processor. See 8.6.5.9, "Use of black point compensation".
The default value is: Default.
Key                Type           Value
HTO                array          (Optional; PDF 2.0) Halftone origin, specified as an array of two numbers
specifying the X and Y location of the halftone origin in the current coordinate
system.
Although the numbers are specified in the current coordinate system,
changes to the current coordinate system (for example as a result of
invocation of a form XObject) do not move the halftone origin relative to the
underlying device coordinate system.
NOTE: The HTO key is very similar to the HTP key defined in PDF versions up to
PDF 1.3 (1st Edition), but differs in the coordinate system used.
EXAMPLE       The following shows two graphics state parameter dictionaries. In the first, automatic stroke adjustment is
turned on, and the dictionary includes a transfer function (deprecated in PDF 2.0) that inverts its value,
𝑓 (𝑥) = 1 − 𝑥. In the second, overprint is turned off, and the dictionary includes a parabolic transfer
function (deprecated in PDF 2.0), 𝑓 (𝑥) = (2𝑥 − 1)2, with a sample of 21 values. The domain of the transfer
function, [0.0 1.0], is mapped to [0 20], and the range of the sample values, [0 255], is mapped to the range
of the transfer function, [0.0 1.0].
10 0 obj                                                %Page object
<</Type /Page
/Parent 5 0 R
/Resources 20 0 R
/Contents 40 0 R
>>
endobj
20 0 obj                                                %Resource dictionary for page
<</Font <</F1 25 0 R>>
/ExtGState <</GS1 30 0 R
/GS2 35 0 R
>>
>>
endobj
30 0 obj                                                %First graphics state parameter dictionary
<</Type /ExtGState
/SA true
/TR 31 0 R
>>
endobj
31 0 obj                                                %First transfer function
<</FunctionType 0
/Domain [0.0 1.0]
/Range [0.0 1.0]
/Size 2
/BitsPerSample 8
/Length 7
/Filter /ASCIIHexDecode
>>
stream
01 00>
endstream
endobj
35 0 obj                                                %Second graphics state parameter dictionary
<</Type /ExtGState
/OP false
/TR 36 0 R
>>
endobj

36 0 obj                                      %Second transfer function
<</FunctionType 0
/Domain [0.0 1.0]
/Range [0.0 1.0]
/Size 21
/BitsPerSample 8
/Length 63
/Filter /ASCIIHexDecode
>>
stream
FF CE A3 7C 5B 3F 28 16 0A 02 00 02 0A 16 28 3F 5B 7C A3 CE FF>
endstream
endobj
8.5      Path construction and painting

#### 3.11: 8.5.1 General
shapes of filled areas, and specify boundaries for clipping other graphics. The graphics state shall
include a current clipping path that shall define the clipping boundary for the current page. At the
beginning of each page, the clipping path shall be initialised to the size of the MediaBox.
A path may contain any combination of zero or more line segments, which may be straight or curved.
Paths may connect to one another or may be disconnected. A pair of segments shall be said to connect
only if they are defined consecutively, with the second segment starting where the first one ends. Thus,
the order in which the segments of a path are defined shall be significant. Nonconsecutive segments
that meet or intersect fortuitously shall not be considered to connect.
NOTE        A path is made up of one or more disconnected subpaths, each comprising a sequence of
connected segments. The topology of the path is unrestricted: it can be concave or convex, can
contain multiple subpaths representing disjoint areas, and can intersect itself in arbitrary ways.
The h operator explicitly shall connect the end of a subpath back to its starting point; such a subpath is
said to be closed. A subpath that has not been explicitly closed is said to be open.
As discussed in 8.2, "Graphics objects", a path object is defined by a sequence of operators to construct
the path, followed by one or more operators to paint the path or to use it as a clipping boundary. PDF
path operators fall into three categories:
•    Path construction operators (8.5.2, "Path construction operators") define the geometry of a path. A
path is constructed by sequentially applying one or more of these operators.
•    Path-painting operators (8.5.3, "Path-painting operators") end a path object, usually causing the
object to be painted on the current page in any of a variety of ways.
•    Clipping path operators (8.5.4, "Clipping path operators"), invoked immediately before a path-
painting operator, cause the path object also to be used for clipping of subsequent graphics
objects.
8.5.2 Path construction operators

#### 3.12: 8.5.2.1            General
add segments to it. The path construction operators may be invoked in any sequence, but the first one
invoked shall be m or re to begin a new subpath. The path definition may conclude with the
application of a path-painting operator such as S, f, or b (see 8.5.3, "Path-painting operators"); this
operator may optionally be preceded by one of the clipping path operators W or W* (8.5.4, "Clipping
path operators").
NOTE        Note that the path construction operators do not place any marks on the page; only the painting
operators do that. A path definition is not complete until a path-painting operator has been
applied to it.
The path currently under construction is called the current path. In PDF (unlike PostScript), the
current path is not part of the graphics state and is not saved and restored along with the other
graphics state parameters. PDF paths shall be strictly internal objects with no explicit representation.
After the current path has been painted, it shall become no longer defined; there is then no current
path until a new one is begun with the m or re operator.
The trailing endpoint of the segment most recently added to the current path is referred to as the
current point. If the current path is empty, the current point shall be undefined. Most operators that
add a segment to the current path start at the current point; if the current point is undefined, an error
shall be generated.
"Table 58 — Path construction operators" shows the path construction operators. All operands shall be
numbers denoting coordinates in user space.
Table 58 — Path construction operators
Operands            Operator         Description
xy                  m                Begin a new subpath by moving the current point to coordinates (x, y),
omitting any connecting line segment. If the previous path construction
operator in the current path was also m, the new m overrides it; no
vestige of the previous m operation remains in the path.
xy                  l (lowercase L) Append a straight line segment from the current point to the point (x, y).
The new current point shall be (x, y).
x1 y1 x2 y2 x3 y3   c                Append a cubic Bézier curve to the current path. The curve shall extend
from the current point to the point (x3, y3), using (x1, y1 ) and (x2, y2 ) as
the Bézier control points (see 8.5.2.2, "Cubic Bézier curves"). The new
current point shall be (x3, y3 ).
x2 y2 x3 y3         v                Append a cubic Bézier curve to the current path. The curve shall extend
from the current point to the point (x3, y3 ), using the current point and
(x2, y2 ) as the Bézier control points (see 8.5.2.2, "Cubic Bézier curves").
The new current point shall be (x3, y3 ).

Operands         Operator            Description
x1 y1 x3 y3      y                   Append a cubic Bézier curve to the current path. The curve shall extend
from the current point to the point (x3, y3 ), using (x1, y1 ) and (x3, y3 ) as
the Bézier control points (see 8.5.2.2, "Cubic Bézier curves"). The new
current point shall be (x3, y3 ).
—                h                   Close the current subpath by appending a straight line segment from the
current point to the starting point of the subpath. If the current subpath
is already closed, h shall do nothing. This operator terminates the
current subpath. Appending another segment to the current path shall
begin a new subpath, even if the new segment begins at the endpoint
reached by the h operation.
x y width        re                  Append a rectangle to the current path as a complete subpath, with
height                               lower-left corner (x, y) and dimensions width and height in user space.
The operation:
x y width height re
is equivalent to:
𝑥𝑦m
( 𝑥 + 𝑤𝑖𝑑𝑡ℎ ) y 𝐥
( 𝑥 + 𝑤𝑖𝑑𝑡ℎ )( 𝑦 + ℎ𝑒𝑖𝑔ℎ𝑡 ) 𝐥
𝑥 ( 𝑦 + ℎ𝑒𝑖𝑔ℎ𝑡 ) 𝐥
h
8.5.2.2           Cubic Bézier curves

#### 3.13: 8.5.2.2           Cubic Bézier curves
points: the two endpoints (the current point P0 and the final point P3) and two control points P1 and
P2.Given the coordinates of the four points, the curve shall be generated by varying the parameter t
from 0.0 to 1.0 in the following equation:
𝑅(𝑡) = (1 − 𝑡)3 𝑃0 + 3𝑡(1 − 𝑡)2 𝑃1 + 3𝑡 2 (1 − 𝑡)𝑃2 + 𝑡 3 𝑃3
When t = 0.0, the value of the function R(t) coincides with the current point P0 ; when t = 1.0, R(t)
coincides with the final point P3. Intermediate values of t generate intermediate points along the curve.
The curve does not, in general, pass through the two control points P1 and P2.
NOTE 1       Cubic Bézier curves have two useful properties:
o   The curve can be very quickly split into smaller pieces for rapid rendering.
o   The curve is contained within the convex hull of the four points defining the curve,
most easily visualized as the polygon obtained by stretching a rubber band around
the outside of the four points. This property allows rapid testing of whether the
curve lies completely outside the visible region, and hence does not have to be
rendered.
NOTE 2       The Bibliography lists several books that describe cubic Bézier curves in more depth.
The most general PDF operator for constructing curved path segments is the c operator, which
specifies the coordinates of points P1, P2, and P3 explicitly, as shown in "Figure 16 — Cubic Bézier curve
generated by the c operator". (The starting point, P0, is defined implicitly by the current point.)
Figure 16 — Cubic Bézier curve generated by the c operator
Two more operators, v and y, each specify one of the two control points implicitly (see "Figure 17 —
Cubic Bézier curves generated by the v and y operators"). In both of these cases, one control point and
the final point of the curve shall be supplied as operands; the other control point shall be implied:
•    For the v operator, the first control point shall coincide with initial point of the curve.
•    For the y operator, the second control point shall coincide with final point of the curve.
Figure 17 — Cubic Bézier curves generated by the v and y operators
8.5.3 Path-painting operators
8.5.3.1         General

#### 3.14: 8.5.3.1         General
manner that the operator specifies. The principal path-painting operators shall be S (for stroking) and f
(for filling). Variants of these operators combine stroking and filling in a single operation or apply
different rules for determining the area to be filled. Attempting to execute a painting operator when
the current path is undefined (at the beginning of a new page or immediately after a painting operator
has been executed) shall generate an error. "Table 59 — Path-painting operators" lists all the path-

painting operators.
Table 59 — Path-painting operators
Operands Operator Description
—            S            Stroke the path.
—            s            Close and stroke the path. This operator shall have the same effect as the sequence h S.
—            f            Fill the path, using the non-zero winding number rule to determine the region to fill (see
8.5.3.3.2, "Non-zero winding number rule"). Any subpaths that are open shall be
implicitly closed before being filled.
—            F            Equivalent to f; deprecated in PDF 2.0 and included only for compatibility. Although PDF
readers shall be able to accept this operator, PDF writers should use f instead.
—            f*           Fill the path, using the even-odd rule to determine the region to fill (see 8.5.3.3.3, "Even-
odd rule").
—            B            Fill and then stroke the path, using the non-zero winding number rule to determine the
region to fill. This operator shall produce the same result as constructing two identical
path objects, painting the first with f and the second with S.
NOTE     The filling and stroking portions of the operation consult different values of several
graphics state parameters, such as the current colour. See also 11.7.4.4, "Special path-
painting considerations".
—            B*           Fill and then stroke the path, using the even-odd rule to determine the region to fill. This
operator shall produce the same result as B, except that the path is filled as if with f*
instead of f. See also 11.7.4.4, "Special path-painting considerations".
—            b            Close, fill, and then stroke the path, using the non-zero winding number rule to
determine the region to fill. This operator shall have the same effect as the sequence h B.
See also 11.7.4.4, "Special path-painting considerations".
—            b*           Close, fill, and then stroke the path, using the even-odd rule to determine the region to
fill. This operator shall have the same effect as the sequence h B*. See also 11.7.4.4,
"Special path-painting considerations".
—            n            End the path object without filling or stroking it. This operator shall be a path-painting
no-op, used primarily for the side effect of changing the current clipping path (see 8.5.4,
"Clipping path operators").
8.5.3.2           Stroking

#### 3.15: 8.5.3.2           Stroking
curved segment in the path, centred on the segment with sides parallel to it. Each of the path’s
subpaths shall be treated separately.
The results of the S operator shall depend on the current settings of various parameters in the graphics
state (see 8.4, "Graphics state", for further information on these parameters):
•    The width of the stroked line is defined by the current line width parameter (8.4.3.2, "Line
width").
•    The colour or pattern of the line is defined by the current colour and colour space for stroking
operations.
•    The line may be painted either solid or with a dash pattern, as specified by the current line dash
pattern (8.4.3.6, "Line dash pattern").
•    If a subpath is open, the unconnected ends shall be treated according to the current line cap style,
which may be butt, rounded, or square (see 8.4.3.3, "Line cap style").
•    Wherever two consecutive segments are connected, the joint between them shall be treated
according to the current line join style, which may be mitered, rounded, or beveled (see 8.4.3.4,
"Line join style"). Mitered joins shall be subject to the current miter limit (see 8.4.3.5, "Miter
limit").
Points at which unconnected segments happen to meet or intersect receive no special treatment. In
particular, using an explicit l operator to give the appearance of closing a subpath, rather than using h,
may result in a messy corner, because line caps are applied instead of a line join.
•    The stroke adjustment parameter (PDF 1.2) specifies that coordinates and line widths be adjusted
automatically to produce strokes of uniform thickness despite rasterization effects (see 10.7.5,
"Automatic stroke adjustment").
•    For transparency compositing purposes a path shall be treated as a single graphics object as
described in 11.6.2, "Specifying source and backdrop colours".
If a subpath is degenerate (consists of a single-point closed path or of two or more points at the same
coordinates), the S operator shall paint it only if round line caps have been specified, producing a filled
circle centred at the single point. If butt or projecting square line caps have been specified, S shall
produce no output, because the orientation of the caps would be indeterminate. This rule shall apply
only to zero-length subpaths of the path being stroked, and not to zero-length dashes in a dash pattern
of a non-degenerate subpath. In the latter case, the line caps shall always be painted, since their
orientation is determined by the direction of the underlying path except in the case of a degenerate
subpath. A single-point open subpath (specified by a trailing m operator) shall produce no output.
8.5.3.3         Filling
8.5.3.3.1       General

#### 3.16: 8.5.3.3.1       General
current path. If the path consists of several disconnected subpaths, f shall paint the insides of all
subpaths, considered together.
Any subpaths that are open shall be implicitly closed before being filled, except that if the last subpath
in the path is a single-point open subpath (specified by a trailing m operator), it shall be disregarded
and not considered to be part of the path. If a subpath is degenerate (consists entirely of one or more
points at the same coordinates), the subpath shall be considered to enclose the single device pixel lying
under that point; the result is device-dependent and not generally useful.
For a simple path, it is intuitively clear what region lies inside. However, for a more complex path, it is
not always obvious which points lie inside the path. For more detailed information, see 10.7.4, "Scan
conversion rules".

EXAMPLE           A path that intersects itself or has one subpath that encloses another.
The path machinery shall use one of two rules for determining which points lie inside a path: the non-
zero winding number rule and the even-odd rule, both discussed in detail below. The non-zero winding
number rule is more versatile than the even-odd rule and shall be the standard rule the f operator uses.
Similarly, the W operator shall use this rule to determine the inside of the current clipping path. The
even-odd rule is occasionally useful for special effects or for compatibility with other graphics systems;
the f* and W* operators invoke this rule.
8.5.3.3.2         Non-zero winding number rule

#### 3.17: 8.5.3.3.2         Non-zero winding number rule
drawing a ray from that point to infinity in any direction and then examining the places where a
segment of the path crosses the ray. Starting with a count of 0, the rule adds 1 each time a path
segment crosses the ray from left to right and subtracts 1 each time a segment crosses from right to
left. After counting all the crossings, if the result is 0, the point is outside the path; otherwise, it is
inside.
The method just described does not specify what to do if a path segment coincides with or is tangent to
the chosen ray. Since the direction of the ray is arbitrary, the rule simply chooses a ray that does not
encounter such problem intersections.
For simple convex paths, the non-zero winding number rule defines the inside and outside as one
would intuitively expect. The more interesting cases are those involving complex or self-intersecting
paths like the ones shown in "Figure 18 — Non-zero winding number rule". For a path consisting of a
five-pointed star, drawn with five connected straight line segments intersecting each other, the rule
considers the inside to be the entire area enclosed by the star, including the pentagon in the centre. For
a path composed of two concentric circles, the areas enclosed by both circles are considered to be
inside, provided that both are drawn in the same direction. If the circles are drawn in opposite
directions, only the doughnut shape between them is inside, according to the rule; the doughnut hole is
outside.
Figure 18 — Non-zero winding number rule
8.5.3.3.3         Even-odd rule

#### 3.18: 8.5.3.3.3         Even-odd rule
a point is inside a path by drawing a ray from that point in any direction and simply counting the
number of path segments that cross the ray, regardless of direction. If this number is odd, the point is
inside; if even, the point is outside. This yields the same results as the non-zero winding number rule
for paths with simple shapes, but produces different results for more complex shapes.
"Figure 19 — Even-odd rule" shows the effects of applying the even-odd rule to complex paths. For the
five-pointed star, the rule considers the triangular points to be inside the path, but not the pentagon in
the centre. For the two concentric circles, only the doughnut shape between the two circles is
considered inside, regardless of the directions in which the circles are drawn.
Figure 19 — Even-odd rule
8.5.4 Clipping path operators

#### 3.19: 8.5.4 Clipping path operators
painting operators. The closed subpaths of this path shall define the area that can be painted. Marks
falling inside this area shall be applied to the page; those falling outside it shall not be. Subclause
8.5.3.3, "Filling" defines what is inside a path as well as stating rules for closing paths and for
degenerate paths. For a given path definition, the same area that would be filled by the f operator is the
area that would be used for a clip.
In the context of the transparent imaging model (PDF 1.4), the current clipping path constrains an
object’s shape (see 11.2, "Overview of transparency"). The effective shape is the intersection of the
object’s intrinsic shape with the clipping path; the source shape value shall be 0.0 outside this
intersection. Similarly, the shape of a transparency group (defined as the union of the shapes of its
constituent objects) shall be influenced both by the clipping path in effect when each of the objects is
painted and by the one in effect at the time the group’s results are painted onto its backdrop.
The initial clipping path shall include the entire page. A clipping path operator (W or W*, shown in
"Table 60 — Clipping path operators") may appear after the last path construction operator and before
the path-painting operator that terminates a path object. Although the clipping path operator appears
before the painting operator, it shall not alter the clipping path at the point where it appears. Rather, it
shall modify the effect of the succeeding painting operator. After the path has been painted, the
clipping path in the graphics state shall be set to the intersection of the current clipping path and the
newly constructed path.

