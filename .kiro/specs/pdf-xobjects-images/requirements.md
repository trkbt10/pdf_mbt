# SDD Draft

Generated from:
- `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt`

## Requirements

#### 0.1: 8.8.1 General
An external object (commonly called an XObject) is a graphics object whose contents are defined by a
self-contained stream, separate from the content stream in which it is used. There are two types of
external objects:
•    An image XObject (8.9.5, "Image dictionaries") represents a sampled visual image such as a
photograph.
•    A form XObject (8.10, "Form XObjects") is a self-contained description of an arbitrary sequence of
graphics objects.
Two further categories of external objects, group XObjects and reference XObjects (both PDF 1.4), are
actually specialised types of form XObjects with additional properties. See 8.10.3, "Group XObjects" and
8.10.4, "Reference XObjects" for additional information.
Any XObject can be painted as part of another content stream by means of the Do operator (see "Table
86 — XObject operator"). This operator applies to any type of XObject — image or form. The syntax is
the same in all cases, although details of the operator’s behaviour differ depending on the type.
Table 86 — XObject operator
Operands        Operator        Description
name            Do              Paint the specified XObject. The operand name shall appear as a
key in the XObject subdictionary of the current resource
dictionary (see 7.8.3, "Resource dictionaries"). The associated
value shall be a stream whose Type entry, if present, is XObject.
The effect of Do depends on the value of the XObject’s Subtype
entry, which may be Image (see 8.9.5, "Image dictionaries") or
Form (see 8.10, "Form XObjects").
Annex J, "XObject comparison", contains one method by which XObjects can be compared for
equivalency.

#### 0.2: 8.9.1 General
PDF’s painting operators include general facilities for dealing with sampled images. A sampled image
(or just image for short) is a rectangular array of sample values, each representing a colour. The image
may approximate the appearance of some natural scene obtained through an input scanner or a video
camera, or it may be generated synthetically. “Figure 48 — Typical sampled image” shows a typical
sampled image.
Figure 48 — Typical sampled image
An image is defined by a sequence of samples obtained by scanning the image array in row or column
order. Each sample in the array consists of as many colour components as are needed for the colour
space in which they are specified — for example, one component for DeviceGray, three for
DeviceRGB, four for DeviceCMYK, or whatever number is required by a particular DeviceN space.
Each component is a 1-, 2-, 4-, 8-, or (PDF 1.5) 16-bit integer, permitting the representation of 2, 4, 16,

256, or (PDF 1.5) 65536 distinct values for each component. Other component sizes can be
accommodated when a JPXDecode filter is used; see 7.4.9, "JPXDecode filter".
PDF provides two means for specifying images:
•    An image XObject (described in 8.9.5, "Image dictionaries") is a stream object whose dictionary
specifies attributes of the image and whose data contains the image samples. Like all external
objects, it is painted on the page by invoking the Do operator in a content stream (see 8.8,
"External objects"). Image XObjects have other uses as well, such as for alternate images (see
8.9.5.4, "Alternate images"), image masks (8.9.6, "Masked images"), and thumbnail images (12.3.4,
"Thumbnail images").
•    An inline image is a small image that is completely defined — both attributes and data — directly
inline within a content stream. The kinds of images that can be represented in this way are
limited; see 8.9.7, "Inline images" for details.

#### 0.3: 8.9.2 Image parameters
The properties of an image — resolution, orientation, scanning order, and so forth — are entirely
independent of the characteristics of the raster output device on which the image is to be rendered. A
PDF processor usually renders images by a sampling technique that attempts to approximate the
colour values of the source as accurately as possible. The actual accuracy achieved depends on the
resolution and other properties of the output device.
To paint an image, four interrelated items shall be specified:
•    The format of the image: number of columns (width), number of rows (height), number of colour
components per sample, and number of bits per colour component
•    The sample data constituting the image’s visual content
•    The correspondence between coordinates in user space and those in the image’s own internal
coordinate space, defining the region of user space that will receive the image
•    The mapping from colour component values in the image data to component values in the image’s
colour space
All of these items shall be specified explicitly or implicitly by an image XObject or an inline image.
NOTE        For convenience, the following subclauses refer consistently to the object defining an image as
an image dictionary. Although this term properly refers only to the dictionary portion of the
stream object representing an image XObject, it can be understood to apply equally to the
stream’s data portion or to the parameters and data of an inline image.

#### 0.4: 8.9.3 Sample representation
The source format for an image shall be described by four parameters:
•    The width of the image in samples
•    The height of the image in samples
•    The number of colour components per sample
•    The number of bits per colour component
The image dictionary shall specify the width, height, and number of bits per component explicitly. The
number of colour components shall be inferred from the colour space specified in the dictionary.
NOTE       For images using the JPXDecode filter (see 7.4.9, "JPXDecode filter"), the number of bits per
component is determined from the image data and is not specified in the image dictionary. The
colour space does not have to be specified in the image dictionary.
Sample data shall be represented as a stream of bytes, interpreted as 8-bit unsigned integers in the
range 0 to 255. The bytes constitute a continuous bit stream, with the high-order bit of each byte first.
This bit stream, in turn, is divided into units of n bits each, where n is the number of bits per
component. Each unit encodes a colour component value, given with high-order bit first; units of 16
bits shall be given with the most significant byte first. Byte boundaries shall be ignored, except that
each row of sample data shall begin on a byte boundary. If the number of data bits per row is not a
multiple of 8, the end of the row is padded with extra bits to fill out the last byte. A PDF processor shall
ignore these padding bits.
Each n-bit unit within the bit stream shall be interpreted as an unsigned integer in the range 0 to 2n- 1,
with the high-order bit first. The image dictionary’s Decode entry maps this integer to a colour
component value, equivalent to what could be used with colour operators such as sc or g. Colour
components shall be interleaved sample by sample; for example, in a three-component RGB image, the
red, green, and blue components for one sample are followed by the red, green, and blue components
for the next.
If the image dictionary's ImageMask entry is false or absent, the colour samples in an image shall be
interpreted according to the colour space specified in the image dictionary (see 8.6, "Colour spaces"),
without reference to the colour parameters in the graphics state. However, if the image dictionary’s
ImageMask entry is true, the sample data shall be interpreted as a stencil mask for applying the
graphics state’s nonstroking colour parameters (see 8.9.6.2, "Stencil masking").

#### 0.5: 8.9.4 Image coordinate system
Each image has its own internal coordinate system, or image space. The image occupies a rectangle in
image space w units wide and h units high, where w and h are the width and height of the image in
samples. Each sample occupies one square unit. The coordinate origin (0, 0) is at the upper-left corner
of the image, with coordinates ranging from 0 to w horizontally and 0 to h vertically.
The image’s sample data are ordered by row, with the horizontal coordinate varying most rapidly. This
is shown in "Figure 49 — Source image coordinate system", where the numbers inside the squares
indicate the order of the samples, counting from 0. The upper-left corner of the first sample is at
coordinates (0, 0), the second at (1, 0), and so on through the last sample of the first row, whose upper-
left corner is at (w - 1, 0) and whose upper-right corner is at (w, 0). The next samples after that are at
coordinates (0, 1), (1, 1), and so on to the final sample of the image, whose upper-left corner is at (w - 1,
h - 1) and whose lower-right corner is at (w, h).
NOTE       The image coordinate system and scanning order imposed by PDF do not preclude using
different conventions in the actual image. Coordinate transformations can be used to map from
other conventions to the PDF convention.
The correspondence between image space and user space is constant: the unit square of user space,
bounded by user coordinates (0, 0) and (1, 1), corresponds to the boundary of the image in image
space (see "Figure 50 — Mapping the source image"). Following the normal convention for user space,
the coordinate (0, 0) is at the lower-left corner of this square, corresponding to coordinates (0, h) in
image space. The implicit transformation from image space to user space, if specified explicitly, would

be described by the matrix [1⁄w 0 0 -1⁄h 0 1].
Figure 49 — Source image coordinate system
Figure 50 — Mapping the source image
An image can be placed on the output page in any position, orientation, and size by using the cm
operator to modify the current transformation matrix (CTM) so as to map the unit square of user space
to the rectangle or parallelogram in which the image shall be painted. Typically, this is done within a
pair of q and Q operators to isolate the effect of the transformation, which can include translation,
rotation, reflection, and skew (see 8.3, "Coordinate systems").
EXAMPLE           If the XObject subdictionary of the current resource dictionary defines the name Image1 to denote an image
XObject, the code shown in this example paints the image in a rectangle whose lower-left corner is at
coordinates (100, 200), that is rotated 45 degrees counter clockwise, and that is 150 units wide and 80 units
high.
q                                                                               %Save graphics state
1 0 0 1 100 200 cm                                                       %Translate
0. 7071 0.7071 -0.7071 0.7071 0 0 cm                                     %Rotate
150 0 0 80 0 0 cm                                                        %Scale
/Image1 Do                                                               %Paint image
Q                                                                               %Restore graphics state
As discussed in 8.3.4, "Transformation matrices", these three transformations could be combined into one.
Of course, if the aspect ratio (width to height) of the original image in this example is different from 150:80,
the result will be distorted.

#### 0.6: 8.9.5.1        General
An image dictionary — that is, the dictionary portion of a stream representing an image XObject —
may contain the entries listed in "Table 87 — Additional entries specific to an image dictionary" in
addition to the usual entries common to all streams (see "Table 5 — Entries common to all stream
dictionaries"). There are many relationships among these entries, and the current colour space may
limit the choices for some of them. Attempting to use an image dictionary whose entries are
inconsistent with each other or with the current colour space shall cause an error.
The entries described here are appropriate for a base image — one that is invoked directly with the Do
operator.
NOTE       Some of the entries are not defined for images used in other ways, such as for alternate images
(see 8.9.5.4, "Alternate images"), image masks (see 8.9.6, "Masked images"), or thumbnail images
(see 12.3.4, "Thumbnail images").
Table 87 — Additional entries specific to an image dictionary
Key                   Type            Value
Type                  name            (Optional) The type of PDF object that this dictionary describes; if present,
shall be XObject for an image XObject.
Subtype               name            (Optional when used only as a thumbnail image, required otherwise) The
type of XObject that this dictionary describes; shall be Image for an image
XObject.
NOTE     The conditions for when the Subtype key is required were clarified in
this document (2020).
Width                 integer         (Required) The width of the image, in samples.
Height                integer         (Required) The height of the image, in samples.
ColorSpace            name or         (Required for images, except those that use the JPXDecode filter; not
array           permitted for image masks) The colour space in which image samples shall
be specified; it can be any type of colour space except Pattern.
If the image uses the JPXDecode filter, this entry may be present:
•    If ColorSpace is present, any colour space specifications in the JPEG 2000
data shall be ignored.
•    If ColorSpace is absent, the colour space specifications in the JPEG 2000
data shall be used. The Decode array shall also be ignored unless
ImageMask is true.

Key                     Type            Value
BitsPerComponent integer                (Required except for image masks and images that use the JPXDecode filter)
The number of bits used to represent each colour component. Only a
single value shall be specified; the number of bits shall be the same for all
colour components. The value shall be 1, 2, 4, 8, or (from PDF 1.5) 16. If
ImageMask is true, this entry is optional, but if specified, its value shall be
1.
If the image stream uses a filter, the value of BitsPerComponent shall be
consistent with the size of the data samples that the filter delivers. In
particular, a CCITTFaxDecode or JBIG2Decode filter shall always deliver
1-bit samples, a RunLengthDecode or DCTDecode filter shall always
deliver 8-bit samples, and an LZWDecode or FlateDecode filter shall
deliver samples of a specified size if a predictor function is used.
If the image stream uses the JPXDecode filter, this entry is optional and
shall be ignored if present. The bit depth is determined by the PDF
processor in the process of decoding the JPEG 2000 image.
Intent                  name            (Optional; PDF 1.1) The name of a colour rendering intent that shall be
used in rendering any image that is not an image mask (see 8.6.5.8,
"Rendering intents"). This value is ignored if ImageMask is true. Default
value: the current rendering intent in the graphics state.
ImageMask               boolean         (Optional) A flag indicating whether the image shall be treated as an image
mask (see 8.9.6, "Masked images"). If this flag is true, the value of
BitsPerComponent, if present, shall be 1 and Mask and ColorSpace shall
not be specified; unmasked areas shall be painted using the current
nonstroking colour. Default value: false.
Mask                    stream or       (Optional; shall not be present for image masks; PDF 1.3) An image XObject
array           defining an image mask to be applied to this image (see 8.9.6.3, "Explicit
masking"), or an array specifying a range of colours to be applied to it as a
colour key mask (see 8.9.6.4, "Colour key masking"). If ImageMask is true,
this entry shall not be present.
Decode                  array           (Optional) An array of numbers describing how to map image samples into
the range of values appropriate for the image’s colour space (see 8.9.5.2,
"Decode arrays"). If ImageMask is true, the array shall be either [0 1] or
[1 0]; otherwise, its length shall be twice the number of colour
components required by ColorSpace. If the image uses the JPXDecode
filter and if ColorSpace is absent, the Decode array shall be ignored
unless ImageMask is true.
Default value: see "Table 88 — Default decode arrays".
Interpolate             boolean         (Optional) A flag indicating whether image interpolation should be
performed by a PDF processor (see 8.9.5.3, "Image interpolation"). Default
value: false.
Alternates              array           (Optional; PDF 1.3) An array of alternate image dictionaries for this image
(see 8.9.5.4, "Alternate images"). This entry shall not be present in an
image XObject that is itself an alternate image.
Key            Type          Value
SMask          stream        (Optional; PDF 1.4) A subsidiary image XObject defining a soft-mask image
(see 11.6.5.2, "Soft-mask images") that shall be used as a source of mask
shape or mask opacity values in the transparent imaging model. The alpha
source parameter in the graphics state determines whether the mask
values shall be interpreted as shape or opacity.
If present, this entry shall override the current soft mask in the graphics
state, as well as the image’s Mask entry, if any. However, the other
transparency-related graphics state parameters — blend mode and alpha
constant — shall remain in effect. If SMask is absent and SMaskInData
has value 0, the image shall have no associated soft mask (although the
current soft mask in the graphics state may still apply).
NOTE 1 Interactions between SMask, SMaskInData and the current soft mask in
the graphics state are set out in clause 11.6.4.3, "Mask shape and
opacity".
SMaskInData    integer       (Optional for images that use the JPXDecode filter, meaningless otherwise;
PDF 1.5) A code specifying how soft-mask information (see 11.6.5.2, "Soft-
mask images") encoded with image samples shall be used:
0     If present, encoded soft-mask image information shall be ignored.
1     The image’s data stream includes encoded soft-mask values. A PDF
processor shall create a soft-mask image from the information to be
used as a source of mask shape or mask opacity in the transparency
imaging model.
2     The image’s data stream includes colour channels that have been
premultiplied with an opacity channel; the image data also includes
the opacity channel. A PDF processor shall create a soft-mask image
from the opacity channel information to be used as a source of mask
shape or mask opacity in the transparency model.
If this entry has a non-zero value, SMask shall not be specified. See also
7.4.9, "JPXDecode filter".
NOTE 2 Interactions between SMask, SMaskInData and the current soft mask in
the graphics state are set out in clause 11.6.4.3, "Mask shape and
opacity".
Default value: 0.
Name           name          (Required in PDF 1.0; optional otherwise; deprecated in PDF 2.0) The name
by which this image XObject is referenced in the XObject subdictionary of
the current resource dictionary (see 7.8.3, "Resource dictionaries").
StructParent   integer       (Required if the image is a structural content item; PDF 1.3) The integer key
of the image’s entry in the structural parent tree (see 14.7.5.4, "Finding
structure elements from content items").
ID             byte string   (Optional; PDF 1.3; indirect reference preferred) The digital identifier of the
image’s parent Web Capture content set (see 14.10.6, "Object attributes
related to web capture").
OPI            dictionary    (Optional; PDF 1.2; deprecated in PDF 2.0) An OPI version dictionary for
the image; see 14.11.7, "Open prepress interface (OPI)". If ImageMask is
true, this entry shall be ignored.
Metadata       stream        (Optional; PDF 1.4) A metadata stream containing metadata for the image
(see 14.3.2, "Metadata streams").

Key                     Type            Value
OC                      dictionary      (Optional; PDF 1.5) An optional content group or optional content
membership dictionary (see 8.11, "Optional content"), specifying the
optional content properties for this image XObject. Before the image is
processed by a PDF processor, its visibility shall be determined based on
this entry. If it is determined to be invisible, the entire image shall be
skipped, as if there were no Do operator to invoke it.
AF                      array of     (Optional; PDF 2.0) An array of one or more file specification dictionaries
dictionaries (7.11.3, "File specification dictionaries") which denote the associated files
for this image XObject. See 14.13, "Associated files" and 14.13.7,
"Associated files linked to XObjects" for more details.
Measure                 dictionary      (Optional; PDF 2.0) A measure dictionary (see "Table 266 — Entries in a
measure dictionary") that specifies the scale and units which shall apply to
the image.
PtData                  dictionary      (Optional; PDF 2.0) A point data dictionary (see "Table 272 — Entries in a
point data dictionary") that specifies the extended geospatial data that
shall apply to the image.
EXAMPLE           This example defines an image 256 samples wide by 256 high, with 8 bits per sample in the DeviceGray
colour space. It paints the image on a page with its lower-left corner positioned at coordinates (45, 140) in
current user space and scaled to a width and height of 132 user space units.
20 0 obj                                                             %Page object
<</Type /Page
/Parent 1 0 R
/Resources 21 0 R
/MediaBox [0 0 612 792]
/Contents 23 0 R
>>
endobj
21 0 obj                                                             %Resource dictionary for page
<</XObject <</Im1 22 0 R>>
>>
endobj
22 0 obj                                              %Image XObject
<</Type /XObject
/Subtype /Image
/Width 256
/Height 256
/ColorSpace /DeviceGray
/BitsPerComponent 8
/Length 83183
/Filter /ASCII85Decode
>>
stream
9LhZI9h\GY9i+bb;,p:e;G9SP92/)X9MJ>^:f14d;,U(X8P;cO;G9e];c$=k9Mn\]
… Image data representing 65,536 samples …
8P;cO;G9e];c$=k9Mn\]~>
endstream
endobj
23 0 obj                                                             %Contents of page
<</Length 56>>
stream
q                                                              %Save graphics state
132 0 0 132 45 140 cm                                       %Translate to (45,140) and scale by 132
/Im1 Do                                                   %Paint image
Q                                                            %Restore graphics state
endstream
endobj

#### 0.7: 8.9.5.2          Decode arrays
Each image's colour component data is initially decomposed into integers in the domain 0 to 2n-1,
where n is the bit depth of the colour component. This bit depth is specified as the value of the image
dictionary's BitsPerComponent entry or, when the image uses the JPXDecode filter, is defined in the
JPEG 2000 data and can have different values per colour component. An image’s Decode array
specifies a linear mapping of each integer component value to a number that would be appropriate as a
component value in the image’s colour space.
Each pair of numbers in a Decode array specifies the lower and upper values to which the domain of
sample values in the image is mapped. A Decode array shall contain one pair of numbers for each
component in the colour space specified by the image’s ColorSpace entry. The mapping for each colour
component, by a PDF processor shall be a linear transformation; that is, it shall use the following
formula for linear interpolation:
𝑦 = Interpolate(𝑥, 𝑥min , 𝑥max , 𝑦min , 𝑦max )
𝑦max − 𝑦min
= 𝑦min + ((𝑥 − 𝑥min ) ×                  )
𝑥max − 𝑥min
This formula is used to convert a value x between xmin and xmax to a corresponding value y between ymin
and ymax, projecting along the line defined by the points (xmin, ymin ) and (xmax, ymax ).
NOTE 1     While this formula applies to values outside the domain xmin to xmax and does not require that xmin <
xmax, note that interpolation used for colour conversion, such as the Decode array, does require
that xmin < xmax and clips x values to this domain so that x = xmin for all x ≤ xmin, and x = xmax for all x ≥
xmax.
For a Decode array of the form [Dmin Dmax], this can be written as
𝑦 = Interpolate(𝑥, 0, 2𝑛 − 1, 𝐷min , 𝐷max )
𝐷max − 𝐷min
= 𝐷min + (𝑥 ×               )
2𝑛 − 1
where
n shall be the bit depth of the corresponding colour component
x shall be the input value, in the domain 0 to 2n - 1
Dmin and Dmax shall be the values specified in the Decode array
y is the output value, which shall be interpreted in the image’s colour space
Samples with a value of 0 shall be mapped to Dmin, those with a value of 2n - 1 shall be mapped to Dmax,
and those with intermediate values shall be mapped linearly between Dmin and Dmax. "Table 88 — Default
decode arrays" lists the default Decode arrays which shall be used with the various colour spaces by a
PDF processor.

NOTE 2      For most colour spaces, the Decode arrays listed in the table map into the full range of allowed
component values. For an Indexed colour space, the default Decode array ensures that
component values that index a colour table are passed through unchanged.
Table 88 — Default decode arrays
Colour Space        Decode Array
DeviceGray          [0.0 1.0]
DeviceRGB           [0.0 1.0 0.0 1.0 0.0 1.0]
DeviceCMYK          [0.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0]
CalGray             [0.0 1.0]
CalRGB              [0.0 1.0 0.0 1.0 0.0 1.0]
Lab                 [0 100 amin amax bmin bmax] where amin, amax, bmin, and bmax correspond to the values in
the Range array of the image’s colour space
ICCBased            Same as the value of Range in the ICC profile of the image’s colour space
Indexed             [0 N], where N = 2n – 1
Pattern             (Not permitted with images)
Separation          [0.0 1.0]
DeviceN             [0.0 1.0 0.0 1.0…0.0 1.0] (one pair of elements for each colour component)
NOTE 3      PDF supports mappings that invert sample colour intensities by specifying a Dmin value greater
than Dmax. For example, if the image’s colour space is DeviceGray and the Decode array is [1.0
0.0], an input value of 0 is mapped to 1.0 (white); an input value of 2n - 1 is mapped to 0.0
(black).
The Dmin and Dmax parameters for a colour component need not fall within the range of values allowed for
that component.
NOTE 4      For instance, if an application uses 6-bit numbers as its native image sample format, it can
represent those samples in PDF in 8-bit form, setting the two unused high-order bits of each
sample to 0. The image dictionary can then specify a Decode array of [0.00000 4.04762], which
maps input values from 0 to 63 into the range 0.0 to 1.0 (4.04762 being approximately equal to
255 ÷ 63).
If an output value is not permitted for a component, it shall be adjusted to the nearest allowed value.

#### 0.8: 8.9.5.3            Image interpolation
Image interpolation is an attempt to produce a smooth transition between adjacent sample values
when rendering an image whose resolution is significantly lower than that of the output device. Setting
the value of the Interpolate entry in an image dictionary to true, is a way for a PDF to declare to a PDF
processor that a specific image might render better if interpolation is used for this particular image.
However, this is only a hint, and a PDF processor may ignore it.

#### 0.9: 8.9.5.4         Alternate images
Alternate images (PDF 1.3) provide a straightforward and backward-compatible way to include
multiple versions of an image in a PDF file for different purposes. These variant representations of the
image may differ, for example, in resolution or in colour space. The primary goal is to reduce the need
to maintain separate versions of a PDF document for low-resolution on-screen viewing and high-
resolution printing.
A base image (that is, the image XObject referred to in a resource dictionary) may contain an
Alternates entry. The value of this entry shall be an array of alternate image dictionaries specifying
variant representations of the base image. Each alternate image dictionary shall contain an image
XObject for one variant and shall specify its properties. "Table 89 — Entries in an alternate image
dictionary" shows the contents of an alternate image dictionary.
Table 89 — Entries in an alternate image dictionary
Key                    Type        Value
Image                  stream      (Required) The image XObject for the alternate image.
DefaultForPrinting     boolean     (Optional) A flag indicating whether this alternate image is the default
version to be used for printing according to the algorithm described below.
At most one alternate for a given base image shall be so designated. Default
value: false.
OC                     dictionary (Optional; PDF 1.5) An optional content group (see 8.11.2, "Optional content
groups") or optional content membership dictionary (see 8.11.2.2, "Optional
content membership dictionaries") that facilitates the selection of which
alternate image to use.
In PDF 1.5, optional content (see 8.11, "Optional content") may be used to facilitate selection between
alternate images. The following algorithm shall be used to determine which image, if any, shall be
rendered:
NOTE       (2020) The following algorithm was changed in this document to reflect that OC processing has
precedence over DefaultForPrinting functionality, and situations where no image is to be
rendered.
a) If the base image contains an OC key then DefaultForPrinting shall be ignored on all Alternates entries.
b) If the base image contains an OC entry that specifies that the base image is visible, then the base image
shall be rendered.
c) If the base image contains an OC entry that specifies that the base image is not visible, then the list of
alternate image dictionaries specified by the base image Alternates entry shall be examined in order,
and the first entry not containing an OC key, or containing an OC entry specifying that the alternate
image should be visible, shall be selected. Further, if this selected alternate image has an OC entry, then
that OC entry shall also be processed to determine if the alternate image shall be rendered or not. If none
of the alternate image dictionaries have an OC key, or none of the alternate image dictionaries with an
OC entry specify that that alternate image is visible, then nothing shall be shown. DefaultForPrinting
shall be ignored on all Alternates entries.
d) If the base image does not contain an OC key and the PDF is being printed then the first entry in the
Alternates array of the base image that has DefaultForPrinting set to true shall be selected. Further, if

this selected alternate image has an OC entry, then that OC entry shall also be processed to determine if
the alternate image shall be printed or not. If no alternate image dictionary in the Alternates array has
DefaultForPrinting set to true, then the base image shall be printed.
NOTE        Alternate images cannot also have an Alternates key as described in "Table 87 — Additional
entries specific to an image dictionary".
EXAMPLE           The following shows an image with a single alternate. The base image is a grayscale image, and the alternate
is a high-resolution RGB image stored on a Web server.
10 0 obj                                                                       %Image XObject
<</Type /XObject
/Subtype /Image
/Width 100
/Height 200
/ColorSpace /DeviceGray
/BitsPerComponent 8
/Alternates 15 0 R
/Length 2167
/Filter /DCTDecode
>>
stream
… Image data …
endstream
endobj
15 0 obj                                                                       %Alternate images array
[<</Image 16 0 R
/DefaultForPrinting true
>>
]
endobj
16 0 obj                                                      %Alternate image
<</Type /XObject
/Subtype /Image
/Width 1000
/Height 2000
/ColorSpace /DeviceRGB
/BitsPerComponent 8
/Length 0                                            %This is an external stream
/F <</FS /URL
/F (http://www.myserver.mycorp.com/images/exttest.jpg)
>>
/FFilter /DCTDecode
>>
stream
endstream
endobj
8.9.6 Masked images

#### 0.10: 8.9.6.1           General
Ordinarily, in the opaque imaging model, images mark all areas they occupy on the page as if with
opaque paint. All portions of the image, whether black, white, gray, or colour, completely obscure any
marks that may previously have existed in the same place on the page. In the graphic arts industry and
page layout applications, however, it is common to crop or mask out the background of an image and
then place the masked image on a different background so that the existing background shows through
the masked areas. A number of PDF features are available for achieving such masking effects:
•    The ImageMask entry in the image dictionary, specifies that the image data shall be used as a
stencil mask for painting in the current colour.
•    The Mask entry in the image dictionary (PDF 1.3) specifies a separate image XObject which shall
be used as an explicit mask specifying which areas of the image to paint and which to mask out.
•    Alternatively, the Mask entry (PDF 1.3) specifies a range of colours which shall be masked out
wherever they occur within the image. This technique is known as colour key masking.
NOTE       Earlier versions of PDF commonly simulated masking by defining a clipping path enclosing only
those of an image’s samples that are to be painted. However, if the clipping path is very complex
(or if there is more than one clipping path) not all interactive PDF processors will render the
results in the same way. An alternative way to achieve the effect of an explicit mask is to define
the image being clipped as a pattern, make it the current colour, and then paint the explicit mask
as an image whose ImageMask entry is true.
In the transparent imaging model, a fourth type of masking effect, soft masking, is available through
the SMask entry (PDF 1.4) or the SMaskInData entry (PDF 1.5) in the image dictionary; see 11.6.5,
"Specifying soft masks", for further discussion.

#### 0.11: 8.9.6.2         Stencil masking
An image mask (an image XObject whose ImageMask entry is true) is a monochrome image in which
each sample is specified by a single bit. However, instead of being painted in opaque black and white,
the image mask is treated as a stencil mask that is partly opaque and partly transparent. Sample values
in the image do not represent black and white pixels; rather, they designate places on the page that
should either be marked with the current colour or masked out (not marked at all). Areas that are
masked out retain their former contents. The effect is like applying paint in the current colour through
a cut-out stencil, which lets the paint reach the page in some places and masks it out in others.
An image mask differs from an ordinary image in the following significant ways:
•    The image dictionary shall not contain a ColorSpace entry because sample values represent
masking properties (1 bit per sample) rather than colours.
•    The value of the BitsPerComponent entry shall be 1.
•    The Decode entry determines how the source samples shall be interpreted. If the Decode array is
[0 1] (the default for an image mask), a sample value of 0 shall mark the page with the current
colour, and a 1 shall leave the previous contents unchanged. If the Decode array is [1 0], these
meanings shall be reversed.
NOTE       One of the most important uses of stencil masking is for painting character glyphs represented as
bitmaps. Using such a glyph as a stencil mask transfers only its "black" bits to the page, leaving
the "white" bits (which are really just background) unchanged. For reasons discussed in 9.6.5.3,
"Encodings for Type 3 fonts", an image mask, rather than an image, need almost always be used
to paint glyph bitmaps.
If image interpolation (see 8.9.5.3, "Image interpolation") is requested during stencil masking, the
effect shall be to smooth the edges of the mask, not to interpolate the painted colour values. This effect
can minimise the jaggy appearance of a low-resolution stencil mask.

#### 0.12: 8.9.6.3         Explicit masking
In PDF 1.3, the Mask entry in an image dictionary may be an image mask, as described in subclause
8.9.6.2, "Stencil masking", which serves as an explicit mask for the primary (base) image. The base

image and the image mask need not have the same resolution (Width and Height values), but since all
images shall be defined on the unit square in user space, their boundaries on the page will coincide;
that is, they will overlay each other. The image mask indicates which places on the page shall be
painted and which shall be masked out (left unchanged). Unmasked areas shall be painted with the
corresponding portions of the base image; masked areas shall not be.

#### 0.13: 8.9.6.4           Colour key masking
In PDF 1.3, the Mask entry in an image dictionary may be an array specifying a range of colours to be
masked out. Samples in the image that fall within this range shall not be painted, allowing the existing
background to show through.
NOTE 1      The effect is similar to that of the video technique known as chroma-key.
For colour key masking, the value of the Mask entry shall be an array of 2 × 𝑛 integers,
[min1 max1 … min𝑛 max𝑛 ], where n is the number of colour components in the image’s colour space.
Each integer shall be in the range 0 to 2BitsPerComponent - 1, representing colour values before decoding
with the Decode array. An image sample shall be masked (not painted) if all of its colour components
before decoding, c1… cn, fall within the specified ranges (that is, if mini ≤ ci ≤ maxi for all 1 ≤ i ≤ n).
When colour key masking is specified, the use of a DCTDecode or lossy JPXDecode filter for the
stream can produce unexpected results.
NOTE 2      DCTDecode is always a lossy filter although JPXDecode has a lossy filter option. The use of a
lossy filter means that the output is only an approximation of the original input data. Therefore,
the use of this filter can lead to slight changes in the colour values of image samples, possibly
causing samples that were intended to be masked to be unexpectedly painted instead, in colours
slightly different from the mask colour.
8.9.7 Inline images

#### 0.14: 8.9.7 Inline images
be specified in the form of an inline image. This type of image shall be defined directly within the
content stream in which it will be painted rather than as a separate object. Because the inline format
gives the PDF processor less flexibility in managing the image data, it should be used only for small
images (4096 bytes or less).
An inline image object shall be delimited in the content stream by the operators BI (begin image), ID
(image data), and EI (end image). These operators are summarised in "Table 90 — Inline image
operators". BI and ID shall bracket a series of key-value pairs specifying the characteristics of the
image, such as its dimensions and colour space; the image data shall follow between the ID and EI
operators. The format is thus analogous to that of a stream object such as an image XObject:
BI
… Key-value pairs …
ID
… Image data …
EI
Table 90 — Inline image operators
Operands    Operator     Description
—           BI           Begin an inline image object.
—           ID           Begin the image data for an inline image object.
—           EI           End an inline image object.
Inline image objects shall not be nested; that is, two BI operators shall not appear without an
intervening EI to close the first object. Similarly, an ID operator shall only appear between a BI and its
balancing EI. Unless the image uses ASCIIHexDecode or ASCII85Decode as one of its filters, the ID
operator shall be followed by a single white-space character, and the next character shall be
interpreted as the first byte of image data.
The key-value pairs appearing between the BI and ID operators (as listed in "Table 91 — Entries in an
inline image object") are analogous to their respective key-value pairs in an image XObject dictionary
(see "Table 87 — Additional entries specific to an image dictionary") or a stream dictionary (see "Table
5 — Entries common to all stream dictionaries"). For convenience, the abbreviations shown in "Table
91 — Entries in an inline image object" and "Table 92 — Additional abbreviations in an inline image
object" may be used in place of the full names. Entries other than those listed shall be ignored.
The value of the Length (or L) key, which shall be present on all inline images, is the length of the data
between the ID and EI operators excluding the white-space delimiting those operators. The value of
the Length key should not exceed 4096 bytes.
NOTE 1     Because the Length (or L) key is new to PDF 2.0, PDF processors will not encounter this key in
older versions of PDF.
NOTE 2     The L key permits PDF processors to efficiently skip inline images if they do not need to display
them. To skip an image a processor can advance beyond the single white-space character
following the ID operator, then if the final or only filter is ASCIIHexDecode or ASCII85Decode
skip any further white-space. The number of characters expressed by the L key is then skipped,
and the EI operator is expected following optional white-space.
"Table 92 — Additional abbreviations in an inline image object" shows additional abbreviations that
can be used for the names of colour spaces and filters.
These abbreviations are valid only in inline images; they shall not be used in image XObjects.
JBIG2Decode, Crypt and JPXDecode are not listed in "Table 92 — Additional abbreviations in an
inline image object", because those filters shall not be used with inline images.
Table 91 — Entries in an inline image object
Full Name                                    Abbreviation
BitsPerComponent                             BPC
ColorSpace                                   CS
Decode                                       D

Full Name                                         Abbreviation
DecodeParms                                       DP
Filter                                            F
Height                                            H
ImageMask                                         IM
Intent (PDF 1.1)                                  No abbreviation
Interpolate                                       I (uppercase I)
Length (PDF 2.0)                                  L
Width                                             W
Table 92 — Additional abbreviations in an inline image object
Full Name                                 Abbreviation
DeviceGray                                G
DeviceRGB                                 RGB
DeviceCMYK                                CMYK
Indexed                                   I (uppercase i)
ASCIIHexDecode                            AHx
ASCII85Decode                             A85
LZWDecode                                 LZW
FlateDecode (PDF 1.2)                     Fl (uppercase F, lowercase L)
RunLengthDecode                           RL
CCITTFaxDecode                            CCF
DCTDecode                                 DCT
The colour space specified by the ColorSpace (or CS) entry shall be one of the standard device colour
spaces (DeviceGray, DeviceRGB, or DeviceCMYK) and shall be present unless ImageMask (IM) is
present and has the value of true. It shall not be a CIE-based colour space or a special colour space, with
the exception of a limited form of Indexed colour space whose base colour space is a device space and
whose colour table is specified by a byte string (see 8.6.6.3, "Indexed colour spaces"). Beginning with
PDF 1.2, the value of the ColorSpace entry may also be the name of a colour space in the ColorSpace
subdictionary of the current resource dictionary (see 7.8.3, "Resource dictionaries"). In this case, the
name may designate any colour space that can be used with an image XObject.
NOTE 3      The names DeviceGray, DeviceRGB, and DeviceCMYK (as well as their abbreviations G, RGB,
and CMYK) always identify the corresponding colour spaces directly; they never refer to
resources in the ColorSpace subdictionary.
The image data in an inline image may be encoded by using any of the standard PDF filters except
JPXDecode, Crypt and JBIG2Decode. The bytes between the ID operator and a white-space token, but
before the EI operator shall be treated the same as a stream object’s data (see 7.3.8, "Stream objects"),
even though they do not follow the standard stream syntax.
NOTE 4      This is an exception to the usual rule that the data in a content stream is interpreted according to
the standard PDF syntax for objects. Accordingly, this does not permit comments (see 7.2.4,
"Comments") within the image data.
EXAMPLE         This example shows an inline image 17 samples wide by 17 high with 8 bits per component in the
DeviceRGB colour space. The image has been encoded using LZW and ASCII base-85 encoding. The cm
operator is used to scale it to a width and height of 17 units in user space and position it at coordinates (298,
388). The q and Q operators encapsulate the cm operation to limit its effect to resizing the image.
q                                                                    %Save graphics state
17 0 0 17 298 388 cm                                                 %Scale and translate coordinate space
BI                                                                   %Begin inline image object
/W 17                                                           %Width in samples
/H 17                                                           %Height in samples
/CS /RGB                                                        %Colour space
/BPC 8                                                          %Bits per component
/L 763
/F [/A85 /LZW]                                                  %Filters
ID                                                                   %Begin image data
J1/gKA>.]AN&J?]-<HW]aRVcg*bb.\eKAdVV%/PcZ
… Image data representing 289 samples …
R.s(4KE3&d&7hb*7[%Ct2HCqC~>
EI                                                                   %End inline image object
Q                                                                    %Restore graphics state
8.10 Form XObjects

#### 0.15: 8.10.1           General
objects (including path objects, text objects, and sampled images). A form XObject may be painted
multiple times — either on several pages or at several locations on the same page — and produces the
same results each time, subject only to the graphics state at the time it is invoked. Not only is this
shared definition economical to represent in the PDF file, but under suitable circumstances the PDF
processor can optimise execution by caching the results of rendering the form XObject for repeated
reuse.
NOTE 1      The term form also refers to a completely different kind of object, an interactive form (sometimes
called an AcroForm), discussed in 12.7, "Forms". Whereas the form XObjects described in this
subclause correspond to the notion of forms in the PostScript language, interactive forms are the
PDF equivalent of the familiar paper instrument. Any unqualified use of the word form is
understood to refer to an interactive form; the type of form described here is always referred to
explicitly as a form XObject.
Form XObjects have various uses:

•    As its name suggests, a form XObject may serve as the template for an entire page.
EXAMPLE           A program that prints filled-in tax forms can first paint the fixed template as a form XObject and then paint
the variable information on top of it.
•    Any graphical element that is to be used repeatedly, such as a company logo or a standard
component in the output from a computer-aided design system, may be defined as a form XObject.
•    Certain document elements that are not part of a page’s contents, such as annotation appearances
(see 12.5.5, "Appearance streams"), shall be represented as form XObjects.
•    A specialised type of form XObject, called a group XObject (PDF 1.4), can be used to group
graphical elements together as a unit for various purposes (see 8.10.3, "Group XObjects"). In
particular, group XObjects shall be used to define transparency groups and soft masks for use in
the transparent imaging model (see 11.6.5.1, "Soft-mask dictionaries" and 11.6.6, "Transparency
group XObjects").
•    Another specialised type of form XObject, a reference XObject (PDF 1.4), may be used to import
content from one PDF document into another (see 8.10.4, "Reference XObjects").
A PDF writer shall perform the following two specific operations in order to use a form XObject:
a) Define the appearance of the form XObject. A form XObject is a PDF content stream. The dictionary
portion of the stream (called the form dictionary) shall contain descriptive information about the form
XObject; the body of the stream shall describe the graphics objects that produce its appearance. The
contents of the form dictionary are described in 8.10.2, "Form dictionaries".
b) Paint the form XObject. The Do operator (see 8.8, "External objects") shall paint a form XObject whose
name is supplied as an operand. The name shall be defined in the XObject subdictionary of the current
resource dictionary. Before invoking this operator, the content stream in which it appears should set
appropriate parameters in the graphics state. In particular, it should alter the current transformation
matrix to control the position, size, and orientation of the form XObject in user space.
Each form XObject is defined in its own coordinate system, called form space. The BBox entry in the
form dictionary shall be expressed in form space, as shall be any coordinates used in the form XObject’s
content stream, such as path coordinates. The Matrix entry in the form dictionary shall specify the
mapping from form space to the current user space. Each time the form XObject is painted by the Do
operator, this matrix shall be concatenated with the current transformation matrix to define the
mapping from form space to device space.
NOTE 2      This differs from the Matrix entry in a pattern dictionary, which maps pattern space to the initial
user space of the content stream in which the pattern is used.
When the Do operator is applied to a form XObject, a PDF processor shall perform the following tasks:
a) Saves the current graphics state, as if by invoking the q operator (see 8.4.4, "Graphics state operators")
b) Concatenates the matrix from the form dictionary’s Matrix entry with the current transformation matrix
(CTM)
c) Clips according to the form dictionary’s BBox entry
d) Paints the graphics objects specified in the form’s content stream
e) Restores the saved graphics state, as if by invoking the Q operator (see 8.4.4, "Graphics state operators")
Except as described above, the initial graphics state for the form shall be inherited from the graphics
state that is in effect at the time Do is invoked.

#### 0.16: 8.10.2          Form dictionaries
Every form XObject shall have a form type, which determines the format and meaning of the entries in
its form dictionary. This specification only defines one form type, Type 1. Form XObject dictionaries
may contain the entries shown in "Table 93 — Additional entries specific to a Type 1 form dictionary",
in addition to the usual entries common to all streams (see "Table 5 — Entries common to all stream
dictionaries").
Table 93 — Additional entries specific to a Type 1 form dictionary
Key             Type         Value
Type            name         (Optional) The type of PDF object that this dictionary describes; if
present, shall be XObject for a form XObject.
Subtype         name         (Required) The type of XObject that this dictionary describes; shall be
Form for a form XObject.
FormType        integer      (Optional) A code identifying the type of form XObject that this
dictionary describes. The only valid value is 1. Default value: 1.
BBox            rectangle    (Required) An array of four numbers in the form coordinate system
(see above), giving the coordinates of the left, bottom, right, and top
edges, respectively, of the form XObject’s bounding box. These
boundaries shall be used to clip the form XObject and to determine its
size for caching.
Matrix          array        (Optional) An array of six numbers specifying the form matrix, which
maps form space into user space (see 8.3.4, "Transformation
matrices"). Default value: the identity matrix [1 0 0 1 0 0].
Resources       dictionary   (Optional but strongly recommended; PDF 1.2) A dictionary specifying
any resources (such as fonts and images) required by the form
XObject (see 7.8, "Content streams and resources").
In a PDF whose version is 1.1 and earlier, all named resources used in
the form XObject shall be included in the resource dictionary of each
page object on which the form XObject appears, regardless of whether
they also appear in the resource dictionary of the form XObject. These
resources should also be specified in the form XObject’s resource
dictionary as well, to determine which resources are used inside the
form XObject. If a resource is included in both dictionaries, it shall
have the same name in both locations.
In PDF 1.2 and later versions, form XObjects may be independent of
the content streams in which they appear, and this is strongly
recommended although not required. In an independent form XObject,
the resource dictionary of the form XObject is required and shall
contain all named resources used by the form XObject. These
resources shall not be promoted to the outer content stream’s
resource dictionary, although that stream’s resource dictionary refers
to the form XObject.

Key               Type           Value
Group             dictionary     (Optional; PDF 1.4) A group attributes dictionary indicating that the
contents of the form XObject shall be treated as a group and specifying
the attributes of that group (see 8.10.3, "Group XObjects").
If a Ref entry (see below) is present, the group attributes shall also
apply to the external page imported by that entry, which allows such
an imported page to be treated as a group without further
modification.
Ref               dictionary     (Optional; PDF 1.4) A reference dictionary identifying a page to be
imported from another PDF file, and for which the form XObject
serves as a proxy (see 8.10.4, "Reference XObjects").
Metadata          stream         (Optional; PDF 1.4) A metadata stream containing metadata for the
form XObject (see 14.3.2, "Metadata streams").
PieceInfo         dictionary     (Optional; PDF 1.3) A page-piece dictionary associated with the form
XObject (see 14.5, "Page-piece dictionaries").
LastModified      date           (Required if PieceInfo is present; optional otherwise; PDF 1.3) The date
and time (see 7.9.4, "Dates") when the form XObject’s contents were
most recently modified. If a page-piece dictionary (PieceInfo) is
present, the modification date shall be used to ascertain which of the
application data dictionaries it contains correspond to the current
content of the form (see 14.5, "Page-piece dictionaries").
StructParent      integer        (Required if the form XObject is a structural content item; PDF 1.3) The
integer key of the form XObject’s entry in the structural parent tree
(see 14.7.5.4, "Finding structure elements from content items").
StructParents integer            (Required if the form XObject contains marked-content sequences that
are structural content items; PDF 1.3) The integer key of the form
XObject’s entry in the structural parent tree (see 14.7.5.4, "Finding
structure elements from content items").
At most one of the entries StructParent or StructParents shall be
present. A form XObject shall be either a content item in its entirety or
a container for marked-content sequences that are content items, but
not both.
OPI               dictionary     (Optional; PDF 1.2; deprecated in PDF 2.0) An OPI version dictionary
for the form XObject (see 14.11.7, "Open prepress interface (OPI)").
OC                dictionary     (Optional; PDF 1.5) An optional content group or optional content
membership dictionary (see 8.11, "Optional content") specifying the
optional content properties for the form XObject. Before the form is
processed, its visibility shall be determined based on this entry. If it is
determined to be invisible, the entire form shall be skipped, as if there
were no Do operator to invoke it.
Name              name           (Required in PDF 1.0; optional otherwise; deprecated in PDF 2.0) The
name by which this form XObject is referenced in the XObject
subdictionary of the current resource dictionary (see 7.8.3, "Resource
dictionaries").
Key              Type           Value
AF               array of     (Optional; PDF 2.0) An array of one or more file specification
dictionaries dictionaries (7.11.3, "File specification dictionaries") which denote the
associated files for this form XObject. See 14.13, "Associated files" and
14.13.7, "Associated files linked to XObjects" for more details.
Measure          dictionary     (Optional; PDF 2.0) A measure dictionary (see "Table 266 — Entries in
a measure dictionary") that specifies the scale and units which shall
apply to the form.
PtData           dictionary     (Optional; PDF 2.0) A point data dictionary (see "Table 272 — Entries
in a point data dictionary") that specifies the extended geospatial data
that shall apply to the form.
EXAMPLE         The following shows a simple form XObject that paints a filled square 1000 units on each side.
6 0 obj                                                            %Form XObject
<</Type /XObject
/Subtype /Form
/FormType 1
/BBox [0 0 1000 1000]
/Matrix [1 0 0 1 0 0]
/Length 58
>>
stream
0 0 m
0 1000 l
1000 1000 l
1000 0 l f
endstream
endobj

#### 0.17: 8.10.3          Group XObjects
A group XObject (PDF 1.4) is a special type of form XObject that can be used to group graphical
elements together as a unit for various purposes. It shall be distinguished by the presence of the
optional Group entry in the form dictionary (see 8.10.2, "Form dictionaries"). The value of this entry
shall be a subsidiary group attributes dictionary describing the properties of the group.
As shown in "Table 94 — Entries common to all group attributes dictionaries", every group XObject
shall have a group subtype (specified by the S entry in the group attributes dictionary) that determines
the format and meaning of the dictionary’s remaining entries. This specification only defines one
subtype, a transparency group XObject (subtype Transparency) representing a transparency group for
use in the transparent imaging model (see 11.4, "Transparency groups"). The remaining contents of
this type of dictionary are described in 11.6.6, "Transparency group XObjects".
Table 94 — Entries common to all group attributes dictionaries
Key          Type       Value
Type         name       (Optional) The type of PDF object that this dictionary describes; if present,
shall be Group for a group attributes dictionary.

Key           Type          Value
S             name          (Required) The group subtype, which identifies the type of group whose
attributes this dictionary describes and determines the format and meaning
of the dictionary’s remaining entries. The only group subtype defined is
Transparency; see 11.6.6, "Transparency group XObjects", for the remaining
contents of this type of dictionary.

#### 0.18: 8.10.4            Reference XObjects
8.10.4.1          General

#### 0.19: 8.10.4.1          General
in which the reference occurs is called the containing document; the one whose content is being
imported is the target document. The target document may reside in a file external to the containing
document or may be included within it as an embedded file stream (see 7.11.4, "Embedded file
streams").
The reference XObject in the containing document shall be a form XObject containing the Ref entry in
its form dictionary, as described below. This form XObject shall serve as a proxy that should be
processed by a PDF processor when the referenced content is not available.
NOTE         The proxy can consist of a low-resolution image of the imported content, a piece of descriptive
text referring to it, a gray box to be displayed in its place, or any other similar placeholder.
PDF processors that do not recognise the Ref entry shall simply display or print the proxy as an
ordinary form XObject. Those PDF processors that do implement reference XObjects shall use the
proxy in place of the imported content if the latter is unavailable. An interactive PDF processor may
also provide a user interface to allow editing and updating of imported content links.
The imported content shall consist of a single, complete PDF page in the target document. It shall be
designated by a reference dictionary, which in turn shall be the value of the Ref entry in the reference
XObject’s form dictionary (see 8.10.2, "Form dictionaries"). The presence of the Ref entry shall
distinguish reference XObjects from other types of form XObjects. "Table 95 — Entries in a reference
dictionary" shows the contents of the reference dictionary.
Table 95 — Entries in a reference dictionary
Key      Type                 Value
F        file                 (Required) The PDF file containing the target document.
specification
Page     integer or text      (Required) A page index or page label (see 12.4.2, "Page labels")
string               identifying the page of the target document containing the content to be
imported. This reference is a weak one and may be inadvertently
invalidated if the referenced page is changed or replaced in the target
document after the reference is created.
Key     Type            Value
ID      array           (Optional) An array of two byte strings constituting a PDF file identifier
(14.4, "File identifiers") for the PDF file containing the target document.
The use of this entry improves a PDF processor’s chances of finding the
intended PDF file and allows it to warn the user if the PDF file has changed
since the reference was created.
When the imported content replaces the proxy, it shall be transformed according to the proxy object’s
transformation matrix and clipped to the boundaries of its bounding box, as specified by the Matrix
and BBox entries in the proxy’s form dictionary (see 8.10.2, "Form dictionaries"). The combination of
the proxy object’s matrix and bounding box thus implicitly defines the bounding box of the imported
page. This bounding box typically coincides with the imported page’s crop box or art box (see 14.11.2,
"Page boundaries"), but may not correspond to any of the defined page boundaries. If the proxy
object’s form dictionary contains a Group entry, the specified group attributes shall apply to the
imported page as well, which allows the imported page to be treated as a group without further
modification.

#### 0.20: 8.10.4.2        Printing reference XObjects
When printing a page containing reference XObjects, a PDF processor may emit any of the following
items, depending on its capabilities, the user’s preferences, and the nature of the print job:
•   The imported content designated by the reference XObject
•   The reference XObject as a proxy for the imported content

#### 0.21: 8.10.4.3        Special considerations
Certain special considerations arise when reference XObjects interact with other PDF features:
•   When the page imported by a reference XObject contains annotations (see 12.5, "Annotations"),
all annotations that contain a printable, unhidden, visible appearance stream (12.5.5,
"Appearance streams") shall be included in the rendering of the imported page. If the proxy is a
snapshot image of the imported page, it shall also include the annotation appearances. These
appearances shall therefore be converted into part of the proxy’s content stream, either as
subsidiary form XObjects or by flattening them directly into the content stream.
•   Logical structure information associated with a page (see 14.7, "Logical structure") may be
ignored when importing that page into another document with a reference XObject. In a target
document with multiple pages, structure elements occurring on the imported page are typically
part of a larger structure pertaining to the document as a whole; such elements cannot
meaningfully be incorporated into the structure of the containing document. In a one-page target
document or one made up of independent, structurally unrelated pages, the logical structure for
the imported page may be wholly self-contained; in this case, it may be possible to incorporate
this structure information into that of the containing document.
8.11 Optional content

#### 0.22: 8.11.1          General
viewed or hidden by document authors or consumers. This capability is useful in items such as CAD

drawings, layered artwork, maps, and multi-language documents.
The following subclauses describe the PDF structures used to implement optional content:
•    8.11.2, "Optional content groups" describes the primary structures used to control the visibility of
the document.
•    8.11.3, "Making graphical content optional", describes how individual pieces of content in a
document can declare themselves as belonging to one or more optional content groups.
•    8.11.4, "Configuring optional content", describes how the states of optional content groups are set.

#### 0.23: 8.11.2            Optional content groups
8.11.2.1          General

#### 0.24: 8.11.2.1          General
or invisible dynamically by PDF processors. The graphics belonging to such a group may reside
anywhere in the document: they need not be consecutive in drawing order, nor even belong to the
same content stream. "Table 96 — Entries in an optional content group dictionary" shows the entries
in an optional content group dictionary.
Table 96 — Entries in an optional content group dictionary
Key           Type               Value
Type          name               (Required) The type of PDF object that this dictionary describes; shall
be OCG for an optional content group dictionary.
Name          text string        (Required) The name of the optional content group, suitable for
presentation in an interactive PDF processor’s user interface.
Intent        name or array      (Optional) A single name or an array of names that represent the
intended use of the graphics in the group. The values View and Design,
or any second-class name may be used (see Annex E, "Extending
PDF"). A PDF processor may choose to use only groups that have a
specific intent and ignore others.
Default value: View. See 8.11.2.3, "Intent" for more information.
Usage         dictionary         (Optional) A usage dictionary describing the nature of the content
controlled by the group. It may be used by features that automatically
control the state of the group based on outside factors. See 8.11.4.4,
"Usage and usage application dictionaries" for more information.
In its simplest form, each dictionary shall contain a Type entry and a Name for presentation in a user
interface. It may have an Intent entry that describes its intended use (see 8.11.2.3, "Intent"), and a
Usage entry that describes the nature of its content (see 8.11.4.4, "Usage and usage application
dictionaries").
Individual content elements in a document may specify the optional content group or groups that
affect their visibility (see 8.11.3, "Making graphical content optional"). Any content whose visibility is
affected by a given optional content group belongs to that group.
A group shall be assigned a state, which is either ON or OFF. States themselves are not part of the PDF
document but may be set programmatically or through the interactive PDF processor’s user interface
to change the visibility of content. When a document is first opened by a PDF processor, the groups’
states shall be initialised based on the document’s default configuration dictionary (see 8.11.4.3,
"Optional content configuration dictionaries").
Content belonging to a single group shall be visible when the group is ON and invisible when it is OFF.
Content may, however, belong to multiple groups, when its group is nested inside of another (parent)
group. In such a case, the content shall only be visible if this group and all its parent groups indicate
visibility. In other words, if the visibility state of an outer level indicates that the content needs to be
hidden, all inner levels shall be hidden regardless of their individual visibility states.

#### 0.25: 8.11.2.2         Optional content membership dictionaries
To express more complex visibility policies, content shall not declare itself to belong directly to an
optional content group but rather to an optional content membership dictionary, whose entries are
shown in "Table 97 — Entries in an optional content membership dictionary".
NOTE 1       8.11.3, "Making graphical content optional" describes how content declares its membership in a
group or membership dictionary.
Table 97 — Entries in an optional content membership dictionary
Key       Type         Value
Type      name         (Required) The type of PDF object that this dictionary describes; shall be OCMD
for an optional content membership dictionary.
OCGs      dictionary   (Optional) A dictionary or array of dictionaries specifying the optional content
or array     groups whose states shall determine the visibility of content controlled by this
membership dictionary.
Null values or references to deleted objects shall be ignored.
If this entry is not present, is an empty array, or contains references only to
null or deleted objects, the P entry shall have no effect on the visibility of any
content.
P         name         (Optional) A name specifying the visibility policy for content belonging to this
membership dictionary. Valid values shall be:
AllOn            visible only if all of the entries in OCGs are ON
AnyOn            visible if any of the entries in OCGs are ON
AnyOff           visible if any of the entries in OCGs are OFF
AllOff           visible only if all of the entries in OCGs are OFF
Default value: AnyOn
VE        array        (Optional; PDF 1.6) An array specifying a visibility expression, used to compute
visibility of content based on a set of optional content groups; see discussion
below.
An optional content membership dictionary may express its visibility policy in two ways:

•    The P entry may specify a simple boolean expression indicating how the optional content groups
specified by the OCGs entry determine the visibility of content controlled by the membership
dictionary.
•    PDF 1.6 introduced the VE entry, which is a visibility expression that may be used to specify an
arbitrary boolean expression for computing the visibility of content from the states of optional
content groups.
If the VE key is present it shall be used in preference to the OCGs and P keys. For compatibility
purposes PDF writers should provide OCGs and P entries where possible, and especially in cases
where the use of VE is necessary to express the intended behaviour.
A visibility expression is an array with the following characteristics:
•    Its first element shall be a name representing a boolean operator (And, Or, or Not).
•    Subsequent elements shall be either optional content groups or other visibility expressions.
•    If the first element is Not, it shall have only one subsequent element. If the first element is And or
Or, it shall have one or more subsequent elements.
•    In evaluating a visibility expression, the ON state of an optional content group shall be equated to
the boolean value true; OFF shall be equated to false.
Membership dictionaries are useful in cases such as these:
•    Some content may choose to be invisible when a group is ON and visible when it is OFF. In this
case, the content would belong to a membership dictionary whose OCGs entry consists of a single
optional content group and whose P entry is AnyOff or AllOff.
NOTE 2       It is valid to have an OCGs entry consisting of a single group and a P entry that is AnyOn or AllOn.
However, in this case it is preferable to use an optional content group directly because it uses
fewer objects.
•    Some content may belong to more than one group and needs to specify its policy when the groups
are in conflicting states. In this case, the content would belong to a membership dictionary whose
OCGs entry consists of an array of optional content groups and whose P entry specifies the
visibility policy, as illustrated in Example 1 in this subclause. Example 2 in this subclause shows
the equivalent policy using visibility expressions.
EXAMPLE 1         This example shows content belonging to a membership dictionary whose OCGs entry consists of an array
of optional content groups and whose P entry specifies the visibility policy.
<</Type /OCMD                                     %Content belonging to this optional content
%membership dictionary is controlled by the states
/OCGs [12 0 R 13 0 R 14 0 R]                 %of three optional content groups.
/P /AllOn                                    %Content is visible only if the state of all three
>>                                                %groups is ON; otherwise it’s hidden.
EXAMPLE 2         This example shows a visibility expression equivalent to Example 1 in this subclause
<</Type /OCMD
/VE [/And 12 0 R 13 0 R 14 0 R]                %Visibility expression equivalent to Example 1.
>>
EXAMPLE 3         This example shows a more complicated visibility expression based on five optional content groups,
represented by objects 1 through 5. It is equivalent to
"OCG 1" OR (NOT "OCG 2") OR ("OCG 3" AND "OCG 4" AND "OCG 5")
<</Type /OCMD
/VE [/Or                                                 %Visibility expression: OR
1 0 R                                              %OCG 1
[/Not 2 0 R]                                       %NOT OCG 2
[/And 3 0 R 4 0 R 5 0 R]                           %OCG 3 AND OCG 4 AND OCG 5
]
>>
8.11.2.3         Intent

#### 0.26: 8.11.2.3         Intent
structural organisation of artwork, and View, which may be used for interactive PDF processors.
NOTE        The Intent entry in "Table 96 — Entries in an optional content group dictionary" provides a way
to distinguish between different intended uses of optional content. For example, many document
design applications, such as CAD packages, offer layering features for collecting groups of
graphics together and selectively hiding or viewing them for the convenience of the author.
However, this layering can be different (at a finer granularity, for example) than would be useful
to consumers of the document. Therefore, a single document can specify different intents for
different optional content groups. A PDF processor can decide to use only groups that are of a
specific intent.
Configuration dictionaries (see 8.11.4.3, "Optional content configuration dictionaries") may also
contain an Intent entry. If one or more of a group’s intents is contained in the current configuration’s
set of intents, the group shall be used in determining visibility. If there is no match, the group shall
have no effect on visibility.
If the configuration’s Intent is an empty array, no groups shall be used in determining visibility;
therefore, all content shall be considered visible.

#### 0.27: 8.11.3           Making graphical content optional
8.11.3.1         General

#### 0.28: 8.11.3.1         General
group or optional content membership dictionary. Two primary mechanisms exist for defining
membership:
•    Sections of content streams delimited by marked-content operators may be made optional, as
described in 8.11.3.2, "Optional content in content streams".
•    Form and image XObjects and annotations may be made optional in their entirety by means of a
dictionary entry, as described in 8.11.3.3, "Optional content in XObjects and annotations".
When it is determined that a piece of optional content in a PDF file is to be hidden, the following shall
occur:
•    The content shall not be drawn.
•    Graphics state operations, such as setting the colour, transformation matrix, and clipping, shall
still be applied. In addition, graphics state side effects that arise from drawing operators shall be
applied; in particular, the current text position shall be updated even for text wrapped in optional
content. In other words, graphics state parameters that persist past the end of a marked-content
section shall be the same whether the optional content is visible or not.
NOTE 1      Hiding a section of optional content does not change the colour of objects that do not belong to
the same optional content group.

•    This rule shall also apply to operators that set state that is not strictly graphics state; for example,
BX and EX.
•    Objects such as form XObjects and annotations that have been made optional may be skipped
entirely, because their contents are encapsulated such that no changes to the graphics state (or
other state) persist beyond the processing of their content stream.
Other features in interactive PDF processors, such as searching and editing, may be affected by the
ability to selectively show or hide content. An interactive PDF processor may choose whether to use
the document’s current state of optional content groups (and, correspondingly, the document’s visible
graphics) or to supply their own states of optional content groups to control the graphics they process.
NOTE 2      Tools to select and move annotations need to honour the current on-screen visibility of
annotations when performing cursor tracking and mouse-click processing. A full text search
engine, however, is likely to need to process all content in a document, regardless of its current
visibility on-screen. Export filters could choose the current on-screen visibility, the full content,
or present the user with a selection of optional content groups to control visibility.
NOTE 3      A PDF processor that does not support optional content, such as one that only supports PDF 1.4
functionality, will draw and process all content in a document.

#### 0.29: 8.11.3.2          Optional content in content streams
Sections of content in a content stream (including a page's content stream, a form or pattern’s content
stream, glyph descriptions of a Type 3 font as specified by its CharProcs entry, or an annotation’s
appearance) may be made optional by enclosing them between the marked-content operators BDC and
EMC (see 14.6, "Marked content") with a marked-content tag of OC. In addition, a DP marked-content
operator may be placed in a page’s content stream to force a reference to an optional content group or
groups on the page, even when the page has no current content in that layer.
The property list associated with the marked-content shall specify either an optional content group or
optional content membership dictionary to which the content belongs. Because a group shall be an
indirect object and a membership dictionary contains references to indirect objects, the property list
shall be a named resource listed in the Properties subdictionary of the current resource dictionary
(see 14.6.2, "Property lists"), as shown in Example 1 and Example 2 in this subclause.
Although the marked-content tag shall be OC, other applications of marked-content are not precluded
from using OC as a tag. The marked-content is optional content only if the tag is OC and the dictionary
operand is a valid optional content group that is included in the OCGs array of the optional content
properties dictionary (see "Table 98 — Entries in the optional content properties dictionary"), or a
valid optional content membership dictionary.
To avoid conflict with other features that used marked-content (such as logical structure; see 14.7,
"Logical structure"), the following strategy is recommended:
•    Where content is to be tagged with optional content markers as well as other markers, the
optional content markers should be nested inside the other marked-content.
•    Where optional content and the other markers would overlap but there is not strict containment,
the optional content should be broken up into two or more BDC/EMC sections, nesting the
optional content sections inside the others as necessary.
NOTE        Breaking up optional content spans does not damage the nature of the visibility of the content,
whereas the same guarantee cannot be made for all other uses of marked-content.
In the following example, the state of the Show Greeting optional content group directly controls the
visibility of the text string "Hello" on the page. When the group is ON, the text is visible; when the
group is OFF, the text is hidden.
EXAMPLE 1
%Within a content stream
…
/OC /oc1 BDC                                %Optional content follows
BT
/F1 1 Tf
12 0 0 12 100 600 Tm
(Hello) Tj
ET
EMC                                         %End of optional content
…
<<                                          %In the resources dictionary
/Properties <</oc1 5 0 R>>            %This dictionary maps the name oc1 to an
…                                           %optional content group (object 5)
>>
5 0 obj                                     %The OCG controlling the visibility
<<                                          %of the text.
/Type /OCG
/Name (Show Greeting)
>>
endobj
The example above shows one piece of content associated with one optional content group. There are
other possibilities:
•    More than one section of content may refer to the same group or membership dictionary, in which
case the visibility of both sections is always the same.
•    Equivalently, although less space-efficient, different sections may have separate membership
dictionaries with the same OCGs and P entries. The sections shall have identical visibility
behaviour.
•    Two sections of content may belong to membership dictionaries that refer to the same group(s)
but with different P settings. For example, if one section has no P entry, and the other has a P
entry of AllOff, the visibility of the two sections of content shall be opposite. That is, the first
section shall be visible when the second is hidden, and vice versa.
The following example demonstrates both the direct use of optional content groups and the indirect
use of groups through a membership dictionary. The content (a black rectangle frame) is drawn if
either of the images controlled by the groups named Image A or Image B is shown. If both groups are
hidden, the rectangle frame is hidden.
EXAMPLE 2
%Within a content stream
…
/OC /OC2 BDC                                                   %Draws a black rectangle frame
0 g
4 w
100 100 412 592 re s
EMC
/OC /OC3 BDC                                                   %Draws an image XObject
q
412 0 0 592 100 100 cm

/Im3 Do
Q
EMC
/OC /OC4 BDC                                          %Draws an image XObject
q
412 0 0 592 100 100 cm
/Im4 Do
Q
EMC
…
<<                                                    %The resource dictionary
/Properties <</OC2 20 0 R /OC3 30 0 R /OC4 40 0 R>>
/XObject <</lm3 50 0 R /lm4 /60 0 R>>
>>
20 0 obj
<<                                                                   %Optional content membership dictionary
/Type /OCMD
/OCGs [30 0 R 40 0 R]
/P /AnyOn
>>
endobj
30 0 obj                                                             %Optional content group "Image A"
<<
/Type /OCG
/Name (Image A)
>>
endobj
40 0 obj                                                             %Optional content group "Image B"
<<
/Type /OCG
/Name (Image B)
>>
endobj

#### 0.30: 8.11.3.3          Optional content in XObjects and annotations
In addition to marked-content within content streams, form XObjects and image XObjects (see 8.8,
"External objects") and annotations (see 12.5, "Annotations") may contain an OC entry, which shall be
an optional content group or an optional content membership dictionary.
A form XObject or image XObject's visibility shall be determined by the state of the group or those of
the groups referenced by the membership dictionary in conjunction with its P (or VE) entry, along with
the current visibility state in the context in which the XObject is invoked (that is, whether objects are
visible in the content stream at the place where the Do operation occurred).
Annotations have various flags controlling on-screen and print visibility (see 12.5.3, "Annotation
flags"). If an annotation contains an OC entry, it shall be visible for screen or print only if the flags have
the appropriate settings and the group or membership dictionary indicates it shall be visible.

#### 0.31: 8.11.4            Configuring optional content
8.11.4.1          General

#### 0.32: 8.11.4.1          General
groups in the document and indicate which external factors shall be used to alter the states. The
following subclauses describe the PDF structures that are used to specify this information.
8.11.4.2, "Optional content properties dictionary" describes the structure that lists all the optional
content groups in the document and their possible configurations.
8.11.4.3, "Optional content configuration dictionaries" describes the structures that specify initial state
settings and other information about the groups in the document.
8.11.4.4, "Usage and usage application dictionaries" and 8.11.4.5, "Determining the state of optional
content groups" describe how the states of groups can be affected based on external factors.

#### 0.33: 8.11.4.2        Optional content properties dictionary
The optional OCProperties entry in the document catalog dictionary (see 7.7.2, "Document catalog
dictionary") shall contain, when present, the optional content properties dictionary, which contains a
list of all the optional content groups in the document, as well as information about the default and
alternate configurations for optional content. This dictionary shall be present if the PDF file contains
any optional content; if it is missing, a PDF processor shall ignore any optional content structures in
the document. This dictionary contains the following entries:
Table 98 — Entries in the optional content properties dictionary
Key      Type       Value
OCGs     array      (Required) An array of indirect references to all the optional content groups in
the document (see 8.11.2, "Optional content groups"), in any order. Every
optional content group shall be included in this array.
D        dictionary (Required) The default viewing optional content configuration dictionary (see
8.11.4.3, "Optional content configuration dictionaries").
Configs array       (Optional) An array of alternate optional content configuration dictionaries
(see 8.11.4.3, "Optional content configuration dictionaries").

#### 0.34: 8.11.4.3         Optional content configuration dictionaries
The D and Configs entries in "Table 98 — Entries in the optional content properties dictionary" are
configuration dictionaries, which represent different presentations of a document’s optional content
groups for use by PDF processors. The D configuration dictionary shall be used to specify the initial
state of the optional content groups when a document is opened. Configs lists other configurations that
may be used under particular circumstances. The entries in a configuration dictionary are shown in
"Table 99 — Entries in an optional content configuration dictionary".
Table 99 — Entries in an optional content configuration dictionary
Key          Type      Value
Name         text      (Optional) A name for the configuration, suitable for presentation in a user interface.
string
Creator      text      (Optional) Name of the application or feature that created this configuration dictionary.
string

Key           Type        Value
BaseState name            (Optional) Used to initialise the states of all the optional content groups in a document
when this configuration is applied. The value of this entry shall be one of the following
names:
ON                     The states of all groups shall be turned ON.
OFF                    The states of all groups shall be turned OFF.
Unchanged              The states of all groups shall be left unchanged.
After this initialization, the contents of the ON and OFF arrays shall be processed,
overriding the state of the groups included in the arrays.
Default value: ON.
If BaseState is present in the document’s default configuration dictionary, its value
shall be ON.
ON            array       (Optional) An array of optional content groups whose state shall be set to ON when this
configuration is applied.
If the BaseState entry is ON, this entry is redundant.
OFF           array       (Optional) An array of optional content groups whose state shall be set to OFF when
this configuration is applied. Any OCG group included in the ON array shall not also be
included in the OFF array.
If the BaseState entry is OFF, this entry is redundant.
Intent        name or (Optional) A single name or an array of names used by a PDF processor to determine
array   which optional content groups’ states to consider and which to ignore in calculating the
visibility of content (see 8.11.2.3, "Intent").
Since this value may contain any name that could appear as the value of the Intent key
in an optional content group dictionary, a special name, All, is used to indicate the set of
all intents.
Default value: View. (If Intent is present in the document’s default configuration
dictionary, its value shall be View.)
AS            array       (Optional) An array of usage application dictionaries (see "Table 101 — Entries in a
usage application dictionary") specifying which usage dictionary categories (see "Table
100 — Entries in an optional content usage dictionary") shall be consulted by PDF
processors, when automatically setting the states of optional content groups based on
external factors, such as the current system language or viewing magnification, and
when they shall be applied.
Key        Type    Value
Order      array   (Optional) An array specifying the order for presentation of optional content groups in
an interactive PDF processor’s user interface. The array elements may include the
following objects:
•   Optional content group dictionaries, whose Name entry shall be displayed in the user
interface by the interactive PDF processor.
•   Arrays of optional content groups which may be displayed by an interactive PDF processor
in a tree or outline structure. Each nested array may optionally have as its first element a
text string to be used as a non-selectable label in an interactive PDF processor’s user
interface.
Text labels in nested arrays shall be used to present collections of related optional
content groups, and not to communicate actual nesting of content inside multiple
layers of groups (see Example 1 in 8.11.4.3, "Optional content configuration
dictionaries"). To reflect actual nesting of groups in the content, such as for layers with
sublayers, nested arrays of groups without a text label shall be used (see Example 2 in
8.11.4.3, "Optional content configuration dictionaries").
An empty array [] explicitly specifies that no groups shall be presented.
In the default configuration dictionary, the default value shall be an empty array; in
other configuration dictionaries, the default shall be the Order value from the default
configuration dictionary.
Any groups not listed in this array shall not be presented in any user interface that uses
the configuration.
ListMode   name    (Optional) A name specifying which optional content groups in the Order array shall
be displayed to the user. Valid values shall be:
AllPages          Display all groups in the Order array.
VisiblePages      Display only those groups in the Order array that are referenced by
one or more visible pages.
Default value: AllPages.
RBGroups array     (Optional) An array consisting of one or more arrays, each of which represents a
collection of optional content groups whose states shall be intended to follow a radio
button paradigm. That is, the state of at most one optional content group in each array
shall be ON at a time. If one group is turned ON, all others shall be turned OFF.
However, turning a group from ON to OFF does not force any other group to be turned
ON.
An empty array [] explicitly indicates that no such collections exist.
In the default configuration dictionary, the default value shall be an empty array; in
other configuration dictionaries, the default is the RBGroups value from the default
configuration dictionary.
Locked     array   (Optional; PDF 1.6) An array of optional content groups that shall be locked when this
configuration is applied. The state of a locked group cannot be changed through the
user interface of an interactive PDF processor. PDF writers can use this entry to
prevent the visibility of content that depends on these groups from being changed by
users.
Default value: an empty array.
An interactive PDF processor may allow the states of optional content groups to be
changed by means other than the user interface, such as ECMAScript or items in the AS
entry of a configuration dictionary.

NOTE          Example 1 and Example 2 in this subclause illustrate the use of the Order entry to control the
display of groups in a user interface.
EXAMPLE 1         Given the following PDF objects:
1 0 obj <</Type /OCG /Name (Skin)>> endobj                    %Optional content groups
2 0 obj <</Type /OCG /Name (Bones)>> endobj
3 0 obj <</Type /OCG /Name (Bark)>> endobj
4 0 obj <</Type /OCG /Name (Wood)>> endobj
5 0 obj                                                       %Configuration dictionary
<</Order [[(Frog Anatomy) 1 0 R 2 0 R] [(Tree Anatomy) 3 0 R 4 0 R]]>>
An interactive PDF processor needs to display the optional content groups as follows:
Frog Anatomy
Skin
Bones
Tree Anatomy
Bark
Wood
EXAMPLE 2         Given the following PDF objects:
%Page contents
/OC /L1 BDC                                                               %Layer 1
/OC /L1a BDC                                                           %Sublayer A of layer 1
0 0 100 100 re f
EMC
/OC /L1b BDC                                                           %Sublayer B of layer 1
0 100 100 100 re f
EMC
EMC
…
<</L1 1 0 R                                                              %Resource names
/L1a 2 0 R
/L1b 3 0 R
>>
…                                                                           %Optional content groups
1 0 obj <</Type /OCG /Name (Layer 1)>> endobj
2 0 obj <</Type /OCG /Name (Sublayer A)>> endobj
3 0 obj <</Type /OCG /Name (Sublayer B)>> endobj
…
4 0 obj                                                                     %Configuration dictionary
<</Order [1 0 R [2 0 R 3 0 R]]>>
An interactive PDF processor needs to display the optional content groups as follows:
Layer 1
Sublayer A
Sublayer B
The AS entry is an auto state array consisting of one or more usage application dictionaries that specify
how interactive PDF processors shall, and non-interactive PDF processors should, automatically set the
state of optional content groups based on external factors, as discussed in 8.11.4.4, “Usage and usage
application dictionaries”.

#### 0.35: 8.11.4.4       Usage and usage application dictionaries
Optional content groups are typically constructed to control the visibility of graphics objects that are
related in some way. Objects can be related in several ways; for example, a group may contain content
in a particular language or content suitable for viewing at a particular magnification.
An optional content group’s usage dictionary (the value of the Usage entry in an optional content group
dictionary; see "Table 96 — Entries in an optional content group dictionary") shall contain information
describing the nature of the content controlled by the group. This dictionary can contain any
combination of the entries shown in "Table 100 — Entries in an optional content usage dictionary".
Table 100 — Entries in an optional content usage dictionary
Key           Type       Value
CreatorInfo   dictionary (Optional) A dictionary used by the creating application to store application-
specific data associated with this optional content group. It shall contain two
required entries:
Creator      A text string specifying the application that created the group.
Subtype      A name defining the type of content controlled by the group.
Suggested values include but shall not be limited to Artwork, for
graphic-design or publishing applications, and Technical, for technical
designs such as building plans or schematics.
Additional entries may be included to present information relevant to the creating
application or related applications.
If an Optional Content Group Dictionary (see "Table 96 — Entries in an optional
content group dictionary") Intent entry contains Design then a CreatorInfo entry
should be included.
Language      dictionary (Optional) A dictionary specifying the language of the content controlled by this
optional content group. It shall contain the following entry:
Lang         (required) A text string that specifies a language and possibly a locale
(see 14.9.2, "Natural language specification"). For example, es-MX
represents Mexican Spanish.
Additionally, it may contain the following entry:
Preferred (optional) A name whose values shall be either ON or OFF. Default
value: OFF. It shall be used by PDF processors when there is a partial
match but no exact match between the system language and the
language strings in all usage dictionaries. See 8.11.4.4, "Usage and
usage application dictionaries" for more information.
Export        dictionary (Optional) A dictionary containing one entry, ExportState, a name whose value
shall be either ON or OFF. This value indicates the recommended state for content
in this group when the document (or part of it) is saved by a PDF processor to a
format that does not support optional content (for example, a raster image
format).

Key              Type         Value
Zoom             dictionary (Optional) A dictionary specifying a range of magnifications at which the content in
this optional content group is best viewed. It shall contain one or both of the
following entries:
min      A number representing the minimum recommended magnification factor
at which the group shall be ON. Default value: 0.
max      A number representing the magnification factor below which the group
shall be ON. Default value: infinity.
Print            dictionary (Optional) A dictionary specifying that the content to be used when printing. It may
contain the following optional entries:
Subtype        A name object specifying the kind of content controlled by the group;
for example, Trapping, PrintersMarks or Watermark.
PrintState A name that shall be either ON or OFF, indicating that the group shall
be set to that state when the document is printed.
View             dictionary (Optional) A dictionary that shall have a single entry, ViewState, a name that shall
have a value of either ON or OFF, indicating the state of the group when the
document is first opened by a PDF processor.
User             dictionary (Optional) A dictionary specifying one or more users for whom this optional
content group is primarily intended. This dictionary shall have two required
entries:
Type A name object that shall be either Ind (individual), Ttl (title or position), or
Org (organisation).
Name A text string or array of text strings representing the name(s) of the
individual, position or organisation.
PageElement dictionary (Optional) A dictionary declaring that the group contains a pagination artifact. It
shall contain one entry, Subtype, whose value shall be a name that is either HF
(header/footer), FG (foreground image or graphics), BG (background image or
graphics), or L (logo).
While the data in the usage dictionary serves as information for a document user to examine, it may
also be used by PDF processors to automatically manipulate the state of optional content groups based
on external factors such as current system language settings or zoom level. Document authors may use
usage application dictionaries to specify which entries in the usage dictionary shall be consulted to
automatically set the state of optional content groups based on such factors. Usage application
dictionaries shall be listed in the AS entry in an optional content configuration dictionary (see "Table
99 — Entries in an optional content configuration dictionary"). If no AS entry is present, states shall
not be automatically adjusted based on usage information.
A usage application dictionary specifies the rules by which usage entries shall be used by interactive
PDF processors, and should be used by non-interactive PDF processors, to automatically manipulate
the state of optional content groups, which groups shall be affected, and under which circumstances.
"Table 101 — Entries in a usage application dictionary" shows the entries in a usage application
dictionary.
Table 101 — Entries in a usage application dictionary
Key        Type     Value
Event      name     (Required) A name defining the situation in which this usage application dictionary
should be used. Shall be one of View, Print, or Export.
OCGs       array    (Optional) An array listing the optional content groups that shall have their states
automatically managed based on information in their usage dictionary (see 8.11.4.4,
"Usage and usage application dictionaries"). Default value: an empty array, indicating
that no groups shall be affected.
Category array      (Required) An array of names, each of which corresponds to a usage dictionary entry (see
"Table 100 — Entries in an optional content usage dictionary"). When managing the
states of the optional content groups in the OCGs array, each of the corresponding
categories in the group’s usage dictionary shall be considered.
The Event entry specifies whether the usage settings shall be applied during viewing, printing, or
exporting the document. The OCGs entry specifies the set of optional content groups to which usage
settings shall be applied. For each of the groups in OCGs, the entries in its usage dictionary (see "Table
100 — Entries in an optional content usage dictionary") specified by Category shall be examined to
yield a recommended state for the group. If all the entries yield a recommended state of ON, the group’s
state shall be set to ON; otherwise, its state shall be set to OFF.
The entries in the usage dictionary shall be used as follows:
•    View: The state shall be the value of the ViewState entry. This entry allows a document to contain
content that is relevant only when the document is viewed interactively, such as instructions for
how to interact with the document.
•    Print: The state shall be the value of the PrintState entry. If PrintState is not present, the state of
the optional content group shall be left unchanged.
•    Export: The state shall be the value of the ExportState entry.
•    Zoom: If the current magnification level of the document is greater than or equal to min and less
than max, the ON state shall be used; otherwise, OFF shall be used.
•    User: The Name entry shall specify a name or names to match with the user’s identification. The
Type entry determines how the Name entry shall be interpreted (name, title, or organisation). If
there is an exact match, the ON state shall be used; otherwise OFF shall be used.
•    Language: This category shall allow the selection of content based on the language and locale of
the application. If an exact match to the language and locale is found among the Lang entries of
the optional content groups in the usage application dictionary’s OCGs list, all groups that have
exact matches shall receive an ON recommendation. If no exact match is found, but a partial
match is found (that is, the language matches but not the locale), all partially matching groups
that have Preferred entries with a value of ON shall receive an ON recommendation. All other
groups shall receive an OFF recommendation.
There shall be no restriction on multiple entries with the same value of Event, in order to allow
documents with incompatible usage application dictionaries to be combined into larger documents and
have their behaviour preserved. If a given optional content group appears in more than one OCGs
array, its state shall be ON only if all categories in all the usage application dictionaries it appears in
have a state of ON.

EXAMPLE           This example shows the use of an auto state array with usage application dictionaries. The AS entry in the
default configuration dictionary is an array of three usage application dictionaries, one for each of the Event
values View, Print, and Export.
/OCProperties                           %OCProperties dictionary in document catalog dictionary
<</OCGs [1 0 R 2 0 R 3 0 R 4 0 R]
/D <</BaseState /OFF           %The default configuration
/ON [1 0 R]
/AS [                    %Auto state array of usage application dictionaries
<</Event /View /Category [/Zoom] /OCGs [1 0 R 2 0 R 3 0 R 4 0 R]>>
<</Event /Print /Category [/Print] /OCGs [4 0 R]>>
<</Event /Export /Category [/Export] /OCGs [3 0 R 4 0 R]>>
]
>>
>>
…
1 0 obj
<</Type /OCG
/Name (20000 foot view)
/Usage <</Zoom <</max 1.0>>>>
<<
endobj
2 0 obj
<</Type /OCG
/Name (10000 foot view)
/Usage <</Zoom <</min 1.0 /max 2.0>>>>
>>
endobj
3 0 obj
<</Type /OCG
/Name (1000 foot view)
/Usage <</Zoom <</min 2.0 /max 20.0>>
/Export <</ExportState /OFF>>>>
<<
endobj
4 0 obj
<</Type /OCG
/Name (Copyright notice)
/Usage <</Print <</PrintState /ON>>
/Export <</ExportState /ON>>>>
>>
endobj
In the example, the usage application dictionary with event type View specifies that all optional
content groups have their states managed based on zoom level when viewing. Three groups (objects 1,
2, and 3) contain Zoom usage information. Object 4 has none; therefore, it is not affected by zoom level
changes. Object 3 receives an OFF recommendation when exporting. When printing or exporting,
object 4 receives an ON recommendation.

#### 0.36: 8.11.4.5          Determining the state of optional content groups
This subclause summarises the rules by which PDF processors make use of the configuration and usage
application dictionaries to set the state of optional content groups. For purposes of this discussion, it is
useful to distinguish the following types of PDF processors:
•    Viewer applications which allow users to interact with the document in various ways.
•    Design applications, which offer layering features for collecting groups of graphics together and
selectively hiding or viewing them.
NOTE 1     The following rules are not meant to apply to design applications; they can manage their states
in an entirely different manner if they choose.
•    Aggregating applications, which import PDF files as graphics.
•    Printing applications, which print PDF files.
When a document is opened, its optional content groups shall be assigned a state based on the D
(default) configuration dictionary in the OCProperties dictionary:
a) The value of BaseState shall be applied to all the groups.
b) The groups listed in either the ON or OFF array (depending on which one is opposite to BaseState) shall
have their states adjusted.
This state shall be the initial state used by all PDF processors.
NOTE 2     Viewer applications can also provide users with an option to view documents in this state (that
is, to disable the automatic adjustments discussed below). This option permits an accurate
preview of the content as it will appear in an aggregating application or a stand-alone printing
system.
The remaining discussion in this subclause applies only to interactive PDF processors. Such
applications shall examine the AS array for usage application dictionaries that have an Event of type
View. For each one found, the groups listed in its OCGs array shall be adjusted as described in 8.11.4.4,
"Usage and usage application dictionaries".
Subsequently, the document is ready for interactive viewing by a user. Whenever there is a change to a
factor that the usage application dictionaries with event type View depend on (such as zoom level), the
corresponding dictionaries shall be reapplied.
The user may manipulate optional content group states manually or by triggering set-OCG-state
actions (see 12.6.4.13, "Set-OCG-state actions") by, for example, clicking links or document outline
items. Manual changes shall override the states that were set automatically. The states of these groups
remain overridden and shall not be readjusted based on usage application dictionaries with event type
View as long as the document is open (or until the user reverts the document to its original state).
When a document is printed by an interactive PDF processor, usage application dictionaries with an
event type Print shall be applied over the current states of optional content groups. These changes
shall persist only for the duration of the print operation; then all groups shall revert to their prior
states.
Similarly, when a document is exported to a format that does not support optional content, usage
application dictionaries with an event type Export shall be applied over the current states of optional
content groups. Changes shall persist only for the duration of the export operation; then all groups
shall revert to their prior states.
NOTE 3     Although the event types Print and Export have identically named counterparts that are usage
categories, the corresponding usage application dictionaries are permitted to specify that other
categories can be applied.

