# SDD Draft

Generated from:
- `spec/extracted/10-rendering.spec.txt`

## Requirements

### Requirement 1: 10.1 General
The PDF imaging model separates the specification of graphics objects (defining shapes and colours)
from the process of rendering them on a raster output device.
NOTE 1     "Figure 20 — Colour specification" and "Figure 21 — Colour rendering" in clause 8.6.3, "Colour
space families" illustrate this division.
Clause 10 defines how the shape and colour of graphics objects are rendered on a raster output device.
Depending on the current colour space and on the characteristics of the raster output device, one or
more of the following steps may be necessary:
•    Convert colour that is not already in the native colour space of the raster output device, into that
colour space; see 10.3, "CIE-Based colour to device colour" and 10.4, "Conversions among device
colour spaces" for details.
•    For any object for which transfer functions are in effect, apply those transfer functions; see 10.5,
"Transfer functions" for details. Note that setting a transfer function in the graphic state using the
TR or TR2 keys in graphics state parameter dictionaries are deprecated in PDF 2.0.
•    Perform a scan conversion algorithm to mark the appropriate pixels of the raster output device;
see 10.7, "Scan conversion details" for details.
•    If the raster output device supports PDF-defined halftoning, apply halftoning according to 10.6,
"Halftones".
For the purpose of clause 10, it is irrelevant whether a raster output device physically exists and is
actually used for rendering, or is just assumed (for example to simulate the colour appearance of PDF
output on one raster output device by using some other raster output device).
NOTE 2     Any raster output device – printer or monitor – can in principle be used to simulate the colour
appearance produced by some other raster output device. In this case, the output colour values
in the colour space of the simulated raster output device become source colour values to be
rendered on the simulating raster output device. Usually the simulating raster output device will
have to be more capable regarding colour reproduction than the simulated device in order to be
useful.
NOTE 3     Managing colour from digital description all the way to creating a rendered reproduction on a
digital display or printed output is a complex topic. The International Color Consortium (ICC)
(http://www.color.org) is a good source of information. The publication "Color management:
understanding and using ICC profiles" provides a good introductory overview.
A PDF document may specify very little about the properties of the physical medium on which the
output will be produced; that information may be obtained from the following sources by a PDF
processor:
•    The media box and other entries in the page dictionary (see 14.11.2, "Page boundaries").
•    An interactive dialogue conducted when the user requests viewing or printing.
•    A job ticket, either embedded in the PDF document or provided separately, may specify detailed
instructions for placing (imposing) PDF pages onto media and for controlling special features of
the output device.
NOTE 4     A widely used standard for the format of vendor neutral job tickets is the JDF (Job Definition
Format) described in the CIP4 document JDF Specification.

### Requirement 2: 10.2 Raster output device native colour
Each raster output device has a native colour space, which often matches one of the following process
colour models: gray (monochrome), RGB (red-green-blue) or CMYK (cyan-magenta-yellow-black).
Process colours are ones that are produced by combinations of one or more process colourants. Colours
specified in any device or CIE-based colour space shall be rendered as process colours.
A device may also support additional spot colourants, which shall be painted only by means of
Separation or DeviceN colour spaces that define such spot colourants.

#### 2.1: 10.3.1            General
To render CIE-based colours on a raster output device, it is necessary to convert from the specified
CIE-based colour space to the device’s native colour space taking into account the known properties of
the raster output device.
For accurately rendering a CIE-based colour on a raster output device, a CIE-based destination colour
space that is suitable for representing the native colour space of the raster output device (for example,
by means of a monitor or printer ICC profile) needs to be established. The specific method by which the
CIE-based destination colour space is established is beyond the scope of this document, but may
include the use of Output Intents (see 14.11.5, "Output intents").
NOTE        Establishing a CIE-based destination colour space for a raster output device can happen based on
a user-driven configuration, by assumptions made by the PDF processor software, by a job ticket,
by settings in an output device, by built-in colour measurements, or by other mechanisms.
Conversion from a CIE-based source colour to a CIE-based destination colour shall be performed based
on ISO 15076-1:2010 (ICC.1:2010).

#### 2.2: 10.3.2            Establishing CIE-based colour space definitions
A PDF processor should establish CIE-based colour specifications for device colour spaces
(DeviceGray, DeviceRGB, or DeviceCMYK), and thus implicitly remap device colour spaces into CIE-
based colour spaces, when those device colour spaces do not match that of the raster output device. If
the native device colour space is CMYK, then converting colours in the DeviceGray colour space to that
CMYK should follow the method described in 10.4.2.3, “Conversion between DeviceGray and
DeviceCMYK".
NOTE        Establishing a CIE-based source colour space can happen based on a user-driven configuration,
by assumptions made by the PDF processor software, by analysis of the colour values and other
properties, or by other mechanisms.

#### 2.3: 10.4.1            General
This subclause describes the methods of classic colour conversion between DeviceGray and
DeviceRGB, DeviceGray and DeviceCMYK, and DeviceRGB and DeviceCMYK.

#### 2.4: 10.4.2.1        General
Although ICC enabled PDF processors should always follow the provisions and recommendations
provided in 10.3, "CIE-Based colour to device colour", a less-capable PDF processor may choose to use
the algorithms specified in the following subclauses 10.4.2.2 through 10.4.2.5. These algorithms are,
however, very simple and as perceived by a human viewer they produce only crude approximations of
the original colours.

#### 2.5: 10.4.2.2        Conversion between DeviceGray and DeviceRGB
Black, white, and intermediate shades of gray can be considered special cases of RGB colour. A
grayscale value shall be described by a single number: 0.0 corresponds to black, 1.0 to white, and
intermediate values to different gray levels.
A gray level shall be equivalent to an RGB value with all three components the same. In other words,
the RGB colour value equivalent to a specific gray value shall be:
𝑟𝑒𝑑 = 𝑔𝑟𝑒𝑦
𝑔𝑟𝑒𝑒𝑛 = 𝑔𝑟𝑒𝑦
𝑏𝑙𝑢𝑒 = 𝑔𝑟𝑒𝑦
The gray value for a given RGB value shall be computed according to the NTSC video standard, which
determines how a colour television signal is rendered on a black-and-white television set:
𝑔𝑟𝑎𝑦 = 0.3 × 𝑟𝑒𝑑 + 0.59 × 𝑔𝑟𝑒𝑒𝑛 + 0.11 × 𝑏𝑙𝑢𝑒

#### 2.6: 10.4.2.3        Conversion between DeviceGray and DeviceCMYK
Nominally, a gray level is the complement of the black component of CMYK. Therefore, the CMYK colour
value equivalent to a specific gray level shall be
𝑐𝑦𝑎𝑛 = 0.0
𝑚𝑎𝑔𝑒𝑛𝑡𝑎 = 0.0
𝑦𝑒𝑙𝑙𝑜𝑤 = 0.0
𝑏𝑙𝑎𝑐𝑘 = 1.0 − 𝑔𝑟𝑒𝑦
To obtain the equivalent gray level for a given CMYK value, the contributions of all components shall be
taken into account:
𝑔𝑟𝑎𝑦 = 1.0 − min(1.0, 0.3 × 𝑐𝑦𝑎𝑛 + 0.59 × 𝑚𝑎𝑔𝑒𝑛𝑡𝑎 + 0.11 × 𝑦𝑒𝑙𝑙𝑜𝑤 + 𝑏𝑙𝑎𝑐𝑘)
The interactions between the black component and the other three are elaborated in 10.4.2.4,
“Conversion from DeviceRGB to DeviceCMYK”.
10.4.2.4        Conversion from DeviceRGB to DeviceCMYK

#### 2.7: 10.4.2.4        Conversion from DeviceRGB to DeviceCMYK
the red-green-blue value to equivalent cyan, magenta, and yellow components. The second step shall

be to generate a black component and alter the other components to produce a better approximation
of the original colour.
NOTE 1      The subtractive colour primaries cyan, magenta, and yellow are the complements of the additive
primaries red, green, and blue.
EXAMPLE           A cyan ink subtracts the red component of white light. In theory, the conversion is very simple:
cyan = 1.0 − red
magenta = 1.0 − green
yellow = 1.0 − blue
A colour that is 0.2 red, 0.7 green, and 0.4 blue can also be expressed as 1.0 − 0.2 = 0.8 cyan, 1.0 − 0.7 =
0.3 magenta, and 1.0 − 0.4 = 0.6 yellow.
NOTE 2      Logically, only cyan, magenta, and yellow are needed to generate a printing colour. An equal level
of cyan, magenta, and yellow could be expected to create the equivalent level of black. In
practice, however, coloured printing inks do not mix perfectly; such combinations often form
dark brown shades instead of true black. To obtain a truer colour rendition on a printer, true
black ink is often substituted for the mixed-black portion of a colour. Most colour printers
support a black component (the K component of CMYK). Computing the quantity of this
component requires some additional steps:
o   Black generation calculates the amount of black to be used when trying to
reproduce a particular colour.
o   Undercolour removal reduces the amounts of the cyan, magenta, and yellow
components to compensate for the amount of black that was added by black
generation.
The complete conversion from RGB to CMYK shall be as follows, where BG (k) and UCR (k) are
invocations of the black-generation and undercolour-removal functions, respectively:
𝑐 = 1.0 − 𝑟𝑒𝑑
𝑚 = 1.0 − 𝑔𝑟𝑒𝑒𝑛
𝑦 = 1.0 − 𝑏𝑙𝑢𝑒
𝑘 = 𝑚𝑖𝑛 (𝑐, 𝑚, 𝑦)
𝑐𝑦𝑎𝑛 = 𝑚𝑖𝑛(1.0, 𝑚𝑎𝑥(0.0, 𝑐 − 𝑈𝐶𝑅(𝑘)))
𝑚𝑎𝑔𝑒𝑛𝑡𝑎 = 𝑚𝑖𝑛(1.0, 𝑚𝑎𝑥(0.0, 𝑚 − 𝑈𝐶𝑅(𝑘)))
𝑦𝑒𝑙𝑙𝑜𝑤 = 𝑚𝑖𝑛(1.0, 𝑚𝑎𝑥(0.0, 𝑦 − 𝑈𝐶𝑅(𝑘)))
𝑏𝑙𝑎𝑐𝑘 = 𝑚i𝑛(1.0, 𝑚𝑎𝑥(0.0, 𝐵𝐺(𝑘)))
The black-generation and undercolour-removal functions shall be defined as PDF function dictionaries
(see 7.10, "Functions") that are parameters in the graphics state. They shall be specified as the values
of the BG and UCR (or BG2 and UCR2) entries in a graphics state parameter dictionary (see "Table 57
— Entries in a graphics state parameter dictionary"). Each function shall be called with a single
numeric operand and shall return a single numeric result.
The input of both the black-generation and undercolour-removal functions shall be k, the minimum of
the intermediate c, m, and y values that have been computed by subtracting the original red, green, and
blue components from 1.0.
NOTE 3      Nominally, k is the amount of black that can be removed from the cyan, magenta, and yellow
components and substituted as a separate black component.
The black-generation function shall compute the black component as a function of the nominal k value.
It may simply return its k operand unchanged, or it may return a larger value for extra black, a smaller
value for less black, or 0.0 for no black at all.
The undercolour-removal function shall compute the amount to subtract from each of the intermediate
c, m, and y values to produce the final cyan, magenta, and yellow components. It may simply return its k
operand unchanged, or it may return 0.0 (so that no colour is removed), some fraction of the black
amount, or even a negative amount, thereby adding to the total amount of colourant.
The final component values that result after applying black generation and undercolour removal
should be in the range 0.0 to 1.0. If a value falls outside this range, the nearest valid value shall be
substituted automatically without error indication.
NOTE 4     This substitution is indicated explicitly by the min and max operations in the preceding formulas.
The correct choice of black-generation and undercolour-removal functions depends on the
characteristics of the output device. Each device shall be configured with default values that are
appropriate for that device.
NOTE 5     See 11.7.5, "Rendering parameters and transparency" and, in particular, 11.7.5.3, "Rendering
intent, black point compensation and colour conversions" for further discussion of the role of
black-generation and undercolour-removal functions in the transparent imaging model.
10.4.2.5        Conversion from DeviceCMYK to DeviceRGB
Conversion of a colour value from CMYK to RGB is a simple operation that does not involve black

#### 2.8: 10.4.2.5        Conversion from DeviceCMYK to DeviceRGB
𝑟𝑒𝑑 = 1.0 − 𝑚𝑖𝑛(1.0, 𝑐𝑦𝑎𝑛 + 𝑏𝑙𝑎𝑐𝑘)
𝑔𝑟𝑒𝑒𝑛 = 1.0 − 𝑚𝑖𝑛 (1.0, 𝑚𝑎𝑔𝑒𝑛𝑡𝑎 + 𝑏𝑙𝑎𝑐𝑘)
𝑏𝑙𝑢𝑒 = 1.0 − 𝑚𝑖𝑛(1.0, 𝑦𝑒𝑙𝑙𝑜𝑤 + 𝑏𝑙𝑎𝑐𝑘)
The black component shall be added to each of the other components, which shall then be converted to
their complementary colours by subtracting them each from 1.0.
10.5 Transfer functions
Starting with PDF 1.2, transfer functions shall be defined as PDF function objects (see 7.10,
"Functions"). There are two ways to specify transfer functions:

### Requirement 3: 10.5 Transfer functions
transfer function or an array of four separate transfer functions, one each for red, green, blue, and
gray or their complements cyan, magenta, yellow, and black. If only a single function is specified,
it shall apply to all components. An RGB device shall use the first three, a monochrome device
shall use the gray transfer function only, and a CMYK device shall use all four. The current transfer
function may be specified as the value of the TR or TR2 entry in a graphics state parameter
dictionary; see "Table 57 — Entries in a graphics state parameter dictionary" however this is
deprecated in PDF 2.0.
•    The current halftone parameter in the graphics state may specify transfer functions as optional
entries in halftone dictionaries (see 10.6.5, "Halftone dictionaries"). This is the only way to set
transfer functions for nonprimary colour components or for any component in devices whose
native colour space uses components other than the ones listed previously. A transfer function

specified in a halftone dictionary shall override the corresponding one specified by the current
transfer function parameter in the graphics state.
In the sequence of steps for processing colours, the PDF processor shall apply the transfer function
after performing any needed conversions between colour spaces. If the output is to be halftoned the
transfer function shall be applied before halftoning. Each colour component shall have its own separate
transfer function; there shall not be interaction between components.
NOTE 1      Starting with PDF 1.2, a transfer function can be used to adjust the values of colour components
to compensate for nonlinear response in an output device and in the human eye. Each
component of a device colour space — for example, the red component of the DeviceRGB space
— is intended to represent the perceived lightness or intensity of that colour component in
proportion to the component’s numeric value.
NOTE 2      Many devices do not actually behave this way, however; the purpose of a transfer function is to
compensate for the device’s actual behaviour. This operation is sometimes called gamma
correction (not to be confused with the CIE-based gamut mapping function performed as part of
CIE-based colour rendering).
Transfer functions shall always operate in the native colour space of the output device, regardless of
the colour space in which colours were originally specified. (For example, for a CMYK device, the
transfer functions apply to the device’s cyan, magenta, yellow, and black colour components, even if the
colours were originally specified in, for example, a DeviceRGB or CalRGB colour space.) The transfer
function shall be called with a numeric operand in the range 0.0 to 1.0 and shall return a number in the
same range. The input shall be the value of a colour component in the device’s native colour space,
either specified directly or produced by conversion from some other colour space. The output shall be
the transformed component value to be transmitted to the device (after halftoning, if necessary).
Both the input and the output of a transfer function shall always be interpreted as if the corresponding
colour component were additive (red, green, blue, or gray): the greater the numeric value, the lighter
the colour. If the component is subtractive (cyan, magenta, yellow, black, or a spot colour), it shall be
converted to additive form by subtracting it from 1.0 before it is passed to the transfer function. The
output of the function shall always be in additive form and shall be passed on to the halftone function
in that form.
Because transfer functions produce device-dependent effects, a page description that is intended to be
device-independent should not define a current transfer function in the graphics state, or define
TransferFunction in any halftone dictionaries.
When the current colour space is DeviceGray and the output device’s native colour space is
DeviceCMYK, a PDF processor shall use only the gray transfer function. The normal conversion from
DeviceGray to DeviceCMYK produces 0.0 for the cyan, magenta, and yellow components. These
components shall not be passed through their respective transfer functions but are rendered directly,
producing output containing no coloured inks. This special case exists for compatibility with existing
PDF processors that use a transfer function to obtain special effects on monochrome devices, and shall
apply only to colours specified in the DeviceGray colour space.
NOTE 3      See 11.7.5, "Rendering parameters and transparency" and, in particular, 11.7.5.2, "Halftone and
transfer function" for further discussion of the role of transfer functions in the transparent
imaging model.
10.6 Halftones
10.6.1          General
Halftoning is a process by which continuous-tone colours are approximated on an output device that

#### 3.1: 10.6.1          General
NOTE 1     Perhaps the most familiar example is the rendering of gray tones with black and white pixels, as
in a newspaper photograph.
Some output devices can reproduce continuous-tone colours directly. Halftoning is not required for
such devices; after gamma correction by the transfer functions, the colour components shall be
transmitted directly to the device. On devices that do require halftoning, it shall occur after all colour
components have been transformed by the applicable transfer functions. The input to the halftone
function shall consist of continuous-tone, gamma-corrected colour components in the device’s native
colour space. Its output shall consist of pixels in colours the device can reproduce.
PDF provides a high degree of control over details of the halftoning process.
NOTE 2     When rendering on low-resolution displays, fine control over halftone patterns is needed to
achieve the best approximations of gray levels or colours and to minimise visual artifacts.
NOTE 3     In colour printing, independent halftone screens can be specified for each of several colourants.
NOTE 4     Remember that everything pertaining to halftones is, by definition, device-dependent. In general,
when a PDF file provides its own halftone specifications, it sacrifices portability. Associated with
every output device is a default halftone definition that is appropriate for most purposes. Only
relatively sophisticated files need to define their own halftones to achieve special effects. For
correct results, a PDF file that defines a new halftone depends on certain assumptions about the
resolution and orientation of device space. The best choice of halftone parameters often depends
on specific physical properties of the output device, such as pixel shape, overlap between pixels,
and the effects of electronic or mechanical noise.
All halftones are defined in device space, and shall be unaffected by the current transformation matrix.
10.6.2          Halftone screens
In general, halftoning methods are based on the notion of a halftone screen, which divides the array of

#### 3.2: 10.6.2          Halftone screens
by conceptually laying a uniform rectangular grid over the device pixel array. Each pixel belongs to one
cell of the grid; a single cell typically contains many pixels. The screen grid shall be defined entirely in
device space and shall be unaffected by modifications to the current transformation matrix.
NOTE       This property is essential to ensure that adjacent areas coloured by halftones are properly
stitched together without visible seams.
On a bilevel (black-and-white) device, each cell of a screen may be made to approximate a shade of
gray by painting some of the cell’s pixels black and some white. Numerically, the gray level produced
within a cell shall be the ratio of white pixels to the total number of pixels in the cell. A cell containing n
pixels can render n + 1 different gray levels, ranging from all pixels black to all pixels white. A gray
value g in the range 0.0 to 1.0 shall be produced by making i pixels white, where 𝑖 = 𝑓𝑙𝑜𝑜𝑟 (𝑔 × 𝑛).

The foregoing description also applies to colour output devices whose pixels consist of primary colours
that are either completely on or completely off. Most colour printers, but not colour displays, work this
way. Halftoning shall be applied to each colour component independently, producing shades of that
colour.
Colour components shall be presented to the halftoning machinery in additive form, regardless of
whether they were originally specified additively (RGB or gray) or subtractively (CMYK or tint). Larger
values of a colour component represent lighter colours — greater intensity in an additive device such
as a display or less ink in a subtractive device such as a printer. Transfer functions produce colour
values in additive form; see 10.5, "Transfer functions".
10.6.3            Spot functions
A common way of defining a halftone screen is by specifying a frequency, angle, and spot function. The

#### 3.3: 10.6.3            Spot functions
lines relative to the device coordinate system. As a cell’s desired gray level varies from black to white,
individual pixels within the cell change from black to white in a well-defined sequence: if a particular
gray level includes certain white pixels, lighter grays will include the same white pixels along with
some additional ones. The order in which pixels change from black to white for increasing gray levels is
determined by a spot function, which specifies that order in an indirect way that minimises
interactions with the screen frequency and angle.
Consider a halftone cell to have its own coordinate system: the centre of the cell is the origin and the
corners are at coordinates ± 1.0 horizontally and vertically. Each pixel in the cell is centred at
horizontal and vertical coordinates that both lie in the range -1.0 to +1.0. For each pixel, the spot
function shall be invoked with the pixel’s coordinates as input and shall return a single number in the
range -1.0 to +1.0, defining the pixel’s position in the whitening order.
The specific values the spot function returns are not significant; all that matters are the relative values
returned for different pixels. As a cell’s gray level varies from black to white, the first pixel whitened
shall be the one for which the spot function returns the lowest value, the next pixel shall be the one
with the next higher spot function value, and so on. If two pixels have the same spot function value,
their relative order shall be chosen arbitrarily.
PDF provides built-in definitions for many of the most commonly used spot functions. A halftone may
simply specify any of these predefined spot functions by name instead of giving an explicit function
definition.
EXAMPLE           The name SimpleDot designates a spot function whose value is inversely related to a pixel’s distance from
the centre of the halftone cell. This produces a "dot screen" in which the black pixels are clustered within a
circle whose area is inversely proportional to the gray level. The name Line designates a spot function whose
value is the distance from a given pixel to a line through the centre of the cell, producing a "line screen" in
which the white pixels grow away from that line.
"Table 126 — Predefined spot functions" shows the predefined spot functions. The table gives the
mathematical definition of each function along with the corresponding PostScript language code as it
would be defined in a PostScript calculator function (see 7.10.5, "Type 4 (PostScript calculator)
functions"). The image accompanying each function shows how the relative values of the function are
distributed over the halftone cell, indicating the approximate order in which pixels are whitened. Pixels
corresponding to darker points in the image are whitened later than those corresponding to lighter
points.
Table 126 — Predefined spot functions
Name                   Appearance                Definition
SimpleDot                                        1 − (𝑥 2 + 𝑦 2 )
{ dup mul exch dup mul add 1 exch sub }
InvertedSimpleDot                                𝑥 2 + 𝑦2 − 1
{ dup mul exch dup mul add 1 sub }
DoubleDot                                        𝑠𝑖𝑛(360 × x) 𝑠𝑖𝑛(360 × 𝑦)
+
2                2
{ 360 mul sin 2 div exch 360 mul sin 2 div add }
InvertedDoubleDot                                     𝑠𝑖𝑛(360 × 𝑥) 𝑠𝑖𝑛(360 × 𝑦)
−(               +             )
2            2
{ 360 mul sin 2 div exch 360 mul sin 2 div add neg }
CosineDot                                        𝑐𝑜𝑠(180 × 𝑥) 𝑐𝑜𝑠(180 × 𝑦)
+
2              2
{ 180 mul cos exch 180 mul cos add 2 div }
Double                                                      𝑥
𝑠𝑖𝑛 (360 × ) 𝑠𝑖𝑛(360 × 𝑦)
2 +
2                2
{ 360 mul sin 2 div exch 2 div 360 mul sin 2 div add }
InvertedDouble                                                𝑥
𝑠𝑖𝑛 (360 × ) 𝑠𝑖𝑛(360 × 𝑦)
−(           2 +             )
2           2
{ 360 mul sin 2 div exch 2 div 360 mul sin 2 div add neg }

Name                        Appearance                   Definition
Line                                                     −|𝑦|
{ exch pop abs neg }
LineX                                                    𝑥
{ pop }
LineY                                                    𝑦
{ exch pop }
Round                                                    𝑖𝑓 |𝑥| + |𝑦| ≤ 1 𝑡ℎ𝑒𝑛 1 − (𝑥 2 + 𝑦 2 )
𝑒𝑙𝑠𝑒 (|𝑥| − 1)2 + (|𝑦| − 1)2 − 1
{ abs exch abs
2 copy add 1 le
{ dup mul exch dup mul add 1 exch sub }
{ 1 sub dup mul exch 1 sub dup mul add 1 sub }
ifelse }
Ellipse                                                  𝑙𝑒𝑡 𝑤 = (3 × |𝑥|) + (4 × |𝑦|) − 3
|𝑦| 2
𝑥2 + (     )
0.75
𝑖𝑓 𝑤 < 0 𝑡ℎ𝑒𝑛 1 −
|𝑦| 2
(1 − |𝑥|)2 + (1 −        )
0.75
𝑒𝑙𝑠𝑒 𝑖𝑓 𝑤 > 1 𝑡ℎ𝑒𝑛                                  −1
𝑒𝑙𝑠𝑒 0.5 − 𝑤
{ abs exch abs 2 copy 3 mul exch 4 mul add 3 sub dup 0 lt
{ pop dup mul exch 0.75 div dup mul add 4 div 1
exch sub }
{ dup 1 gt
{ pop 1 exch sub dup mul
exch 1 exch sub 0.75 div dup
mul add
4 div 1 sub }
{ 0.5 exch sub exch pop exch pop }
ifelse }
ifelse }
Name               Appearance                Definition
EllipseA                                     1 − (𝑥 2 + 0.9 × 𝑦 2 )
{ dup mul 0.9 mul exch dup mul add 1 exch sub }
InvertedEllipseA                             𝑥 2 + 0.9 × 𝑦 2 − 1
{ dup mul 0.9 mul exch dup mul add 1 sub }
EllipseB
1 − √𝑥 2 + × 𝑦 2
{ dup 5 mul 8 div mul exch dup mul exch add sqrt 1 exch sub
}
EllipseC                                     1 − (0.9 × 𝑥 2 + 𝑦 2 )
{ dup mul exch dup mul 0.9 mul add 1 exch sub }
InvertedEllipseC                             0.9 × 𝑥 2 + 𝑦 2 − 1
{ dup mul exch dup mul 0.9 mul add 1 sub }
Square                                       −𝑚𝑎𝑥 (|𝑥|, |𝑦|)
{ abs exch abs 2 copy lt
{ exch }
if
pop neg }
Cross                                        −𝑚𝑖𝑛 (|𝑥|, |𝑦|)
{ abs exch abs 2 copy gt
{ exch }
if
pop neg }

Name                        Appearance                   Definition
Rhomboid                                                 0.9 × |𝑥| + |𝑦|
{ abs exch abs 0.9 mul add 2 div }
Diamond                                                  𝑖𝑓 |𝑥| + |𝑦| ≤ 0.75 𝑡ℎ𝑒𝑛 1 − (𝑥 2 + 𝑦 2 )
𝑒𝑙𝑠𝑒 𝑖𝑓 |𝑥| + |𝑦| ≤ 1.23 𝑡ℎ𝑒𝑛 1 − (0.85 × |𝑥| + |𝑦|)
𝑒𝑙𝑠𝑒 (|𝑥| − 1)2 + (|𝑦| − 1)2 − 1
{ abs exch abs 2 copy add 0.75 le
{ dup mul exch dup mul add 1 exch sub }
{ 2 copy add 1.23 le
{ 0.85 mul add 1 exch sub }
{ 1 sub dup mul exch 1 sub du mul add 1 sub
}
ifelse }
ifelse }
"Figure 64 — Various halftoning effects" illustrates the effects of some of the predefined spot functions.
Figure 64 — Various halftoning effects
10.6.4            Threshold arrays
Another way to define a halftone screen is with a threshold array that directly controls individual
device pixels in a halftone cell. This technique provides a high degree of control over halftone
rendering. It also permits halftone cells to be arbitrary rectangles, whereas those controlled by a spot
function are always square.

#### 3.4: 10.6.4            Threshold arrays
defined entirely in device space. Depending on the halftone type, the threshold values occupy 8 or 16
bits each. Threshold values nominally represent gray levels in the usual way, from 0 for black up to the
maximum (255 or 65,535) for white. The threshold array shall be replicated to tile the entire device
space: each pixel in device space shall be mapped to a particular sample in the threshold array. On a
bilevel device, where each pixel is either black or white, halftoning with a threshold array shall proceed
as follows:
a) For each device pixel that is to be painted with some gray level, consult the corresponding threshold
value from the threshold array.
b) If the requested gray level is less than the threshold value, paint the device pixel black; otherwise, paint it
white. Gray levels in the range 0.0 to 1.0 correspond to threshold values from 0 to the maximum
available (255 or 65,535).
A threshold value of 0 shall be treated as if it were 1; therefore, a gray level of 0.0 paints all pixels
black, regardless of the values in the threshold array.
This scheme easily generalizes to monochrome devices with multiple bits per pixel, where each pixel
can directly represent intermediate gray levels in addition to black and white. For any device pixel that
is specified with some in-between gray level, the halftoning algorithm shall consult the corresponding
value in the threshold array to determine whether to use the next-lower or next-higher representable
gray level. In this situation, the threshold values do not represent absolute gray levels, but rather
gradations between any two adjacent representable gray levels.
EXAMPLE         If there are 2 bits per pixel, each pixel can directly represent one of four different gray levels: black, dark
gray, light gray, or white, encoded as 0, 1, 2, and 3, respectively.
NOTE       A halftone defined in this way can also be used with colour displays that have a limited number
of values for each colour component. The red, green, and blue components are simply treated
independently as gray levels, applying the appropriate threshold array to each. (This technique
also works for a screen defined as a spot function, since the spot function is used to compute a
threshold array internally.)
10.6.5          Halftone dictionaries
10.6.5.1        General
In PDF 1.2, the graphics state includes a current halftone parameter. A PDF processor may choose to
use this halftone to perform painting operations if required for the current output device. Alternatively
the PDF processor may choose to ignore some or all of the halftones specified in the PDF file and use

#### 3.5: 10.6.5.1        General
halftones").
The current halftone may be specified as the value of the HT entry in a graphics state parameter
dictionary; see "Table 57 — Entries in a graphics state parameter dictionary". It may be defined by
either a dictionary or a stream, depending on the type of halftone; the term halftone dictionary is used
generically throughout this clause to refer to either a dictionary object or the dictionary portion of a
stream object. (The halftones that are defined by streams are specifically identified as such in the
descriptions of particular halftone types; unless otherwise stated, they are understood to be defined by
simple dictionaries instead.)

Every halftone dictionary shall have a HalftoneType entry whose value shall be an integer specifying
the overall type of halftone definition. The remaining entries in the dictionary are interpreted
according to this type. PDF supports the halftone types listed in "Table 127 — PDF halftone types".
Table 127 — PDF halftone types
Type       Meaning
1          Defines a single halftone screen by a frequency, angle, and spot function.
5          Defines an arbitrary number of halftone screens, one for each colourant or
colour component (including both primary and spot colourants). The keys in
this dictionary are names of colourants; the values are halftone dictionaries
of other types, each defining the halftone screen for a single colourant.
6          Defines a single halftone screen by a threshold array containing 8-bit sample
values.
10         Defines a single halftone screen by a threshold array containing 8-bit sample
values, representing a halftone cell that may have a non-zero screen angle.
16         (PDF 1.3) Defines a single halftone screen by a threshold array containing 16-
bit sample values, representing a halftone cell that may have a non-zero
screen angle.
NOTE 1      The dictionaries representing these halftone types contain the same entries as the corresponding
PostScript language halftone dictionaries (as described in clause 7.4 of the PostScript Language
Reference, Third Edition), with the following exceptions:
The PDF dictionaries can contain a Type entry with the value Halftone, identifying the type of
PDF object that the dictionary describes.
Spot functions and transfer functions are represented by function objects instead of PostScript
language procedures. Threshold arrays are specified as streams instead of files.
In Type 5 halftone dictionaries, the keys for colourants shall be name objects; they cannot be strings as
is allowed in PostScript.
Halftone dictionaries have an optional entry, HalftoneName, that identifies the halftone by name. If
this entry is present, all other entries, including HalftoneType, are optional. At rendering time, if the
output device has a halftone with the specified name, that halftone may be used, overriding any other
halftone parameters specified in the dictionary.
NOTE 2      This provides a way for PDF files to select the proprietary halftones supplied by some device
manufacturers, which would not otherwise be accessible because they are not explicitly defined
in PDF.
If there is no HalftoneName entry, or if the requested halftone name does not exist on the device, the
halftone’s parameters may be defined by the other entries in the dictionary, if any. If no other entries
are present, the default halftone may be used.
NOTE 3      See 11.7.5, "Rendering parameters and transparency" and, in particular, 11.7.5.2, "Halftone and
transfer function" for further discussion of the role of halftones in the transparent imaging
model.
10.6.5.2       Type 1 halftones
"Table 128 — Entries in a Type 1 halftone dictionary" describes the contents of a halftone dictionary of
Type 1, which defines a halftone screen in terms of its frequency, angle, and spot function.
Table 128 — Entries in a Type 1 halftone dictionary
Key                Type             Value

#### 3.6: 10.6.5.2       Type 1 halftones
shall be Halftone for a halftone dictionary.
HalftoneType       integer          (Required) A code identifying the halftone type that this dictionary
describes; shall be 1 for this type of halftone.
HalftoneName       byte string      (Optional) The name of the halftone dictionary.
Frequency          number           (Required) The screen frequency, measured in halftone cells per inch in
device space.
Angle              number           (Required) The screen angle, in degrees of rotation counterclockwise with
respect to the device coordinate system.
NOTE     Most output devices have left-handed device spaces. On such devices, a
counterclockwise angle in device space corresponds to a clockwise
angle in default user space and on the physical medium.
SpotFunction       function, name   (Required) A function object defining the order in which device pixels
or array         within a screen cell shall be adjusted for different gray levels, or the name
of a spot function, or an array of names of spot functions (PDF 2.0). A
name should be one of the predefined spot functions (see "Table 126 —
Predefined spot functions"). If the value of SpotFunction is an array the
PDF processor shall use the first name within the array that it recognizes.
If a name is provided that is not defined in "Table 126 — Predefined spot
functions" and the PDF processor does not understand that name, or if
none of the names in an array are defined in "Table 126 — Predefined
spot functions" or are understood by the PDF processor, the processor
shall use the default halftone.
AccurateScreens    boolean          (Optional) A flag specifying whether to invoke a special halftone algorithm
that is extremely precise but computationally expensive; see Note 1 for
further discussion. Default value: false.
TransferFunction function or        (Optional) A transfer function, which overrides the current transfer
name               function in the graphics state for the same component. This entry shall be
present if the dictionary is a component of a Type 5 halftone (see 10.6.5.6,
"Type 5 halftones") and represents either a nonprimary or nonstandard
primary colour component (see 10.5, "Transfer functions"). The name
Identity may be used to specify the identity function. The
TransferFunction key should only be used to convey tone reproduction
compensation (sometimes called gamma curve correction); it should not
be used to specify artistic intent. If the key is required by some other
clause in this document but no compensation is necessary then the value
should be the name Identity.
If the AccurateScreens entry has a value of true, a highly precise halftoning algorithm shall be

substituted in place of the standard one. If AccurateScreens is false or not present, ordinary halftoning
shall be used.
NOTE 1      Accurate halftoning achieves the requested screen frequency and angle with very high accuracy,
whereas ordinary halftoning adjusts them so that a single screen cell is quantised to device
pixels. High accuracy is important mainly for making colour separations on high-resolution
devices. However, it ican be computationally expensive and therefore is ordinarily disabled.
NOTE 2      In principle, PDF permits the use of halftone screens with arbitrarily large cells — in other
words, arbitrarily low frequencies. However, cells that are very large relative to the device
resolution or that are oriented at unfavourable angles can exceed the capacity of available
memory. If this happens, an error occurs. The AccurateScreens feature often requires very large
amounts of memory to achieve the highest accuracy.
EXAMPLE           The following shows a halftone dictionary for a Type 1 halftone.
28 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 120
/Angle 30
/SpotFunction /CosineDot
/TransferFunction /Identity
>>
endobj
10.6.5.3          Type 6 halftones
A Type 6 halftone defines a halftone screen with a threshold array. The halftone shall be represented as
a stream containing the threshold values; the parameters defining the halftone shall be specified by
entries in the stream dictionary. This dictionary may contain the entries shown in "Table 129 —

#### 3.7: 10.6.5.3          Type 6 halftones
all streams (see "Table 5 — Entries common to all stream dictionaries"). The Width and Height entries
shall specify the dimensions of the threshold array in device pixels; the stream shall contain
𝑊𝑖𝑑𝑡ℎ × 𝐻𝑒𝑖𝑔ℎ𝑡 bytes, each representing a single threshold value. Threshold values are defined in
device space in the same order as image samples in image space (see "Figure 49 — Source image
coordinate system"), with the first value at device coordinates (0, 0) and horizontal coordinates
changing faster than vertical coordinates.
Table 129 — Additional entries specific to a Type 6 halftone dictionary
Key                    Type        Value
Type                   name        (Optional) The type of PDF object that this dictionary describes; if present,
shall be Halftone for a halftone dictionary.
HalftoneType           integer     (Required) A code identifying the halftone type that this dictionary
describes; shall be 6 for this type of halftone.
HalftoneName           byte        (Optional) The name of the halftone dictionary.
string
Width                  integer     (Required) The width of the threshold array, in device pixels.
Height                 integer     (Required) The height of the threshold array, in device pixels.
Key                 Type       Value
TransferFunction function (Optional) A transfer function, which overrides the current transfer function
or name in the graphics state for the same component. The name Identity may be
used to specify the identity function (see 10.5, "Transfer functions").
NOTE    PDF versions to 1.7 required that this entry be present if the dictionary is a
component of a Type 5 halftone (see 10.6.5.6, "Type 5 halftones") and
represents either a non-primary or non-standard primary colour
component.
10.6.5.4        Type 10 halftones
Type 6 halftones specify a threshold array with a zero screen angle; they make no provision for other
angles. The Type 10 halftone removes this restriction and allows the use of threshold arrays for
halftones with non-zero screen angles as well.
Halftone cells at non-zero angles can be difficult to specify because they may not line up well with scan

#### 3.8: 10.6.5.4        Type 10 halftones
halftone addresses these difficulties by dividing the halftone cell into a pair of squares that line up at
zero angles with the output device’s pixel grid. The squares contain the same information as the
original cell but are much easier to store and manipulate. In addition, they can be mapped easily into
the internal representation used for all rendering.
NOTE 1     "Figure 65 — Halftone cell with a non-zero angle" shows a halftone cell with a frequency of 38.4
cells per inch and an angle of 50.2 degrees, represented graphically in device space at a
resolution of 300 dots per inch. Each asterisk in the figure represents a location in device space
that is mapped to a specific location in the threshold array.
Figure 65 — Halftone cell with a non-zero angle
NOTE 2     "Figure 66 — Angled halftone cell divided into two squares" shows how the halftone cell can be
divided into two squares. If the squares and the original cell are tiled across device space, the
area to the right of the upper square maps exactly into the empty area of the lower square, and
vice versa (see "Figure 67 — Halftone cell and two squares tiled across device space"). The last
row in the first square is immediately adjacent to the first row in the second square and starts in
the same column.

Figure 66 — Angled halftone cell divided into two squares
Figure 67 — Halftone cell and two squares tiled across device space
NOTE 3      Any halftone cell can be divided in this way. The side of the upper square (X) is equal to the
horizontal displacement from a point in one halftone cell to the corresponding point in the
adjacent cell, such as those marked by asterisks in "Figure 67 — Halftone cell and two squares
tiled across device space". The side of the lower square (Y) is the vertical displacement between
the same two points. The frequency of a halftone screen constructed from squares with sides X
and Y is thus given by
resolution
frequency =
√𝑋 2 + 𝑌 2
and the angle by
𝑌
angle = 𝑎𝑡𝑎𝑛 ( )
𝑋
Like a type 6 halftone, a type 10 halftone shall be represented as a stream containing the threshold
values, with the parameters defining the halftone specified by entries in the stream dictionary. This
dictionary may contain the entries shown in "Table 130 — Additional entries specific to a Type 10
halftone dictionary" in addition to the usual entries common to all streams (see "Table 5 — Entries
common to all stream dictionaries"). The Xsquare and Ysquare entries replace the Type 6 halftone’s
Width and Height entries.
Table 130 — Additional entries specific to a Type 10 halftone dictionary
Key                 Type            Value
Type                name            (Optional) The type of PDF object that this dictionary describes; if
present, shall be Halftone for a halftone dictionary.
HalftoneType        integer         (Required) A code identifying the halftone type that this dictionary
describes; shall be 10 for this type of halftone.
HalftoneName        byte string     (Optional) The name of the halftone dictionary.
Xsquare             integer         (Required) The side of square X, in device pixels; see below.
Ysquare             integer         (Required) The side of square Y, in device pixels; see below.
TransferFunction function or        (Optional) A transfer function, which shall override the current
name               transfer function in the graphics state for the same component. This
entry shall be present if the dictionary is a component of a Type 5
halftone (see 10.6.5.6, "Type 5 halftones") and represents either a
nonprimary or nonstandard primary colour component (see 10.5,
"Transfer functions"). The name Identity may be used to specify the
identity function.
The Xsquare and Ysquare entries shall specify the dimensions of the two squares in device pixels. The
stream shall contain Xsquare2 + Ysquare2 bytes, each representing a single threshold value. The
contents of square X shall be specified first, followed by those of square Y. Threshold values within
each square shall be defined in device space in the same order as image samples in image space (see
"Figure 49 — Source image coordinate system"), with the first value at device coordinates (0, 0) and
horizontal coordinates changing faster than vertical coordinates.
10.6.5.5       Type 16 halftones
Like Type 10, a Type 16 halftone (PDF 1.3) defines a halftone screen with a threshold array and allows
non-zero screen angles. In Type 16, however, each element of the threshold array shall be 16 bits wide
instead of 8. This allows the threshold array to distinguish 65,536 levels of colour rather than only 256

#### 3.9: 10.6.5.5       Type 16 halftones
specified, they shall tile the device space as shown in "Figure 68 — Tiling of device space in a Type 16
halftone". The last row in the first rectangle shall be immediately adjacent to the first row in the second
and shall start in the same column.

Figure 68 — Tiling of device space in a Type 16 halftone
A Type 16 halftone, like Type 6 and Type 10, shall be represented as a stream containing the threshold
values, with the parameters defining the halftone specified by entries in the stream dictionary. This
dictionary may contain the entries shown in "Table 131 — Additional entries specific to a Type 16
halftone dictionary" in addition to the usual entries common to all streams (see "Table 5 — Entries
common to all stream dictionaries"). The dictionary’s Width and Height entries define the dimensions
of the first (or only) rectangle. The dimensions of the second, optional rectangle are defined by the
optional entries Width2 and Height2. Each threshold value shall be represented as 2 bytes, with the
high-order byte first. The stream shall contain 2 × Width × Height bytes if there is only one rectangle
or 2 × (Width × Height + Width2 × Height2) bytes if there are two rectangles. The contents of the first
rectangle are specified first, followed by those of the second rectangle. Threshold values within each
rectangle shall be defined in device space in the same order as image samples in image space (see
"Figure 49 — Source image coordinate system"), with the first value at device coordinates (0, 0) and
horizontal coordinates changing faster than vertical coordinates.
Table 131 — Additional entries specific to a Type 16 halftone dictionary
Key                    Type        Value
Type                   name        (Optional) The type of PDF object that this dictionary describes; if present, shall
be Halftone for a halftone dictionary.
HalftoneType           integer     (Required) A code identifying the halftone type that this dictionary describes;
shall be 16 for this type of halftone.
HalftoneName           byte        (Optional) The name of the halftone dictionary.
string
Width                  integer     (Required) The width of the first (or only) rectangle in the threshold array, in
device pixels.
Height                 integer     (Required) The height of the first (or only) rectangle in the threshold array, in
device pixels.
Width2                 integer     (Optional) The width of the optional second rectangle in the threshold array, in
device pixels. If this entry is present, the Height2 entry shall be present as well.
If this entry is absent, the Height2 entry shall also be absent, and the threshold
array has only one rectangle.
Height2                integer     (Optional) The height of the optional second rectangle in the threshold array, in
device pixels.
Key                   Type      Value
TransferFunction function (Optional) A transfer function, which shall override the current transfer function
or name in the graphics state for the same component. This entry shall be present if the
dictionary is a component of a Type 5 halftone (see 10.6.5.6, "Type 5 halftones")
and represents either a nonprimary or nonstandard primary colour component
(see 10.5, "Transfer functions"). The name Identity may be used to specify the
identity function.
10.6.5.6         Type 5 halftones
Some devices, particularly colour printers, require separate halftones for each individual colourant.
Also, devices that can produce named separations may require individual halftones for each
separation. Halftone dictionaries of Type 5 allow individual halftones to be specified for an arbitrary
number of colourants or colour components.

#### 3.10: 10.6.5.6         Type 5 halftones
dictionary containing independent halftone definitions for multiple colourants. Its keys shall be name
objects representing the names of individual colourants or colour components. The values associated
with these keys shall be other halftone dictionaries, each defining the halftone screen and transfer
function for a single colourant or colour component. The component halftone dictionaries shall not be
of halftone Type 5.
Table 132 — Entries in a Type 5 halftone dictionary
Key            Type            Value
Type           name            (Optional) The type of PDF object that this dictionary describes; if present,
shall be Halftone for a halftone dictionary.
HalftoneType integer           (Required) A code identifying the halftone type that this dictionary
describes; shall be 5 for this type of halftone.
HalftoneName byte string       (Optional) The name of the halftone dictionary.
any colourant dictionary or    (Required, one per colourant) The halftone corresponding to the colourant
name          stream           or colour component named by the key. The halftone may be of any Type
other than 5.
Default        dictionary or   (Required) A halftone that shall be used for any colourant or colour
stream          component that does not have an entry of its own. The value shall not be 5.
If there are any nonprimary colourants, the default halftone shall have a
transfer function.
The colourants or colour components represented in a Type 5 halftone dictionary (aside from the
Default entry) fall into two categories:
•     Primary colour components for the standard native device colour spaces (Gray for DeviceGray;
Red, Green, and Blue for DeviceRGB; Cyan, Magenta, Yellow, and Black for DeviceCMYK;).

•    Nonstandard colour components for use as spot colourants in Separation and DeviceN colour
spaces. Some of these may also be used as process colourants if the native colour space is
nonstandard.
When a halftone dictionary of some other Type appears as the value of an entry in a Type 5 halftone
dictionary, it shall apply only to the single colourant or colour component named by that entry’s key.
This is in contrast to such a dictionary’s being used as the current halftone parameter in the graphics
state, which shall apply to all colour components. If nonprimary colourants are requested when the
current halftone is defined by any means other than a Type 5 halftone dictionary, the gray halftone
screen and transfer function shall be used for all such colourants.
EXAMPLE           In this example, the halftone dictionaries for the colour components and for the default all use the same spot
function.
27 0 obj
<</Type /Halftone
/HalftoneType 5
/Cyan 31 0 R
/Magenta 32 0 R
/Yellow 33 0 R
/Black 34 0 R
/Default 35 0 R
>>
endobj
31 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 89.827
/Angle 15
/SpotFunction /Round
/AccurateScreens true
>>
endobj
32 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 89.827
/Angle 75
/SpotFunction /Round
/AccurateScreens true
>>
endobj
33 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 90.714
/Angle 0
/SpotFunction /Round
/AccurateScreens true
>>
endobj
34 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 89.803
/Angle 45
/SpotFunction /Round
/AccurateScreens true
>>
endobj
35 0 obj
<</Type /Halftone
/HalftoneType 1
/Frequency 90.0
/Angle 45
/SpotFunction /Round
/AccurateScreens true
>>
endobj
10.7 Scan conversion details
10.7.1          General
The final step of rendering shall be scan conversion. The PDF processor executes a scan conversion
algorithm to paint graphics, text, and images in the raster memory of the output device.
NOTE       The specifics of the scan conversion algorithm are not defined as part of PDF. Different

#### 3.11: 10.7.1          General
for one device could be inappropriate for another. Still, it is useful to have a general
understanding of how scan conversion works, particularly when creating PDF files intended for
viewing on a display. At the low resolutions typical of displays, variations of even one pixel’s
width can have a noticeable effect on the appearance of painted shapes.
Most scan conversion details are not under program control, but a few are; the parameters for
controlling them are described here.
10.7.2          Flatness tolerance
The flatness tolerance controls the maximum permitted distance in device pixels between the
mathematically correct path and an approximation constructed from straight line segments, as shown
in "Figure 69 — Flatness tolerance". Flatness may be specified as the operand of the i operator (see

#### 3.12: 10.7.2          Flatness tolerance
dictionary (see "Table 57 — Entries in a graphics state parameter dictionary"). It shall be a positive
number.
PDF processors may choose to ignore any flatness tolerance specified within a PDF file.
NOTE 1     Smaller values yield greater precision at the cost of more computation.
NOTE 2     Although the figure exaggerates the difference between the curved and flattened paths for the
sake of clarity, the purpose of the flatness tolerance is to control the precision of curve
rendering, not to draw inscribed polygons. If the parameter’s value is large enough to cause
visible straight line segments to appear, the result is unpredictable.

Figure 69 — Flatness tolerance
10.7.3            Smoothness tolerance
The smoothness tolerance (PDF 1.3) controls the quality of smooth shading (Type 2 patterns and the sh
operator) and thus indirectly controls the rendering performance. Smoothness is the allowable colour
error between a shading approximated by piecewise linear interpolation and the true value of a

#### 3.13: 10.7.3            Smoothness tolerance
maximum independent error shall be used. The allowable error (or tolerance) shall be expressed as a
fraction of the range of the colour component, from 0.0 to 1.0. Thus, a smoothness tolerance of 0.1
represents a tolerance of 10 percent in each colour component. Smoothness may be specified as the
value of the SM entry in a graphics state parameter dictionary (see "Table 57 — Entries in a graphics
state parameter dictionary").
Each output device may have internal limits on the maximum and minimum tolerances attainable.
Setting smoothness to 1.0 can result in an internal smoothness of 0.5 on a high-quality colour device,
although setting it to 0.0 on the same device can result in an internal smoothness of 0.01 if an error of
that magnitude is imperceptible on the device.
NOTE 1      The smoothness tolerance can also interact with the accuracy of colour conversion. In the case of
a colour conversion defined by a sampled function, the conversion function is unknown. Thus the
error can be sampled at too low a frequency, in which case the accuracy defined by the
smoothness tolerance cannot be guaranteed. In most cases, however, where the conversion
function is smooth and continuous, the accuracy will normally be within the specified tolerance.
NOTE 2      The effect of the smoothness tolerance is similar to that of the flatness tolerance. However, that
flatness is measured in device-dependent units of pixel width, whereas smoothness is measured
as a fraction of colour component range.
10.7.4            Scan conversion rules
The following rules determine which device pixels a painting operation affects. All references to
coordinates and pixels are in device space. A shape is a path to be painted with the current colour or
with an image. Its coordinates are mapped into device space but not rounded to device pixel

#### 3.14: 10.7.4            Scan conversion rules
computations have been performed.
Pixel boundaries always fall on integer coordinates in device space. A pixel is a square region identified
by the location of its corner with minimum horizontal and vertical coordinates. The region is half-open,
meaning that it includes its lower but not its upper boundaries. More precisely, for any point whose
real-number coordinates are (x, y), let i = floor(x) and j = floor(y). The pixel that contains this point is
the one identified as (i, j). The region belonging to that pixel is defined to be the set of points (x′, y′)
such that i ≤ x′ < i + 1 and j ≤ y′ < j + 1.
Like pixels, shapes to be painted by filling (8.5.3.3, "Filling") and stroking (8.5.3.2, "Stroking")
operations are also treated as half-open regions that include the boundaries along their "floor" sides,
but not along their "ceiling" sides.
A shape shall be scan-converted by painting any pixel whose half-open square region intersects the
shape, no matter how small the intersection is. This ensures that no shape ever disappears as a result
of unfavourable placement relative to the device pixel grid, as might happen with other possible scan
conversion rules. The area covered by painted pixels shall always be at least as large as the area of the
original shape. This rule applies both to fill operations and to strokes with non-zero width. Zero-width
strokes may be done in an implementation-defined manner that may include fewer pixels than the rule
implies.
NOTE 1     Normally, the intersection of two regions is defined as the intersection of their interiors.
However, for purposes of scan conversion, a filling region is considered to intersect every pixel
through which its boundary passes, even if the interior of the filling region is empty.
EXAMPLE         A zero-width or zero-height rectangle paints a line 1 pixel wide.
The region of device space to be painted by a sampled image is determined similarly to that of a filled
shape, though not identically. The PDF processor transforms the image’s source rectangle into device
space and defines a half-open region, just as for fill operations. However, only those pixels whose
centres lie within the region shall be painted. The position of the centre of such a pixel — in other
words, the point whose coordinate values have fractional parts of one-half — shall be mapped back
into source space to determine how to colour the pixel. There shall not be averaging over the pixel
area. If the resolution of the source image is higher than that of device space, some source samples
might not be used.
For clipping, the clipping region consists of the set of pixels that would be included by a fill operation.
Subsequent painting operations shall affect a region that is the intersection of the set of pixels defined
by the clipping region with the set of pixels for the region to be painted.
Scan conversion of character glyphs may be performed by a different algorithm from the preceding
one.
NOTE 2     Font rendering algorithms use hints in the glyph descriptions and techniques that are specialised
to glyph rasterization.
10.7.5          Automatic stroke adjustment
When a stroke is drawn along a path, the scan conversion algorithm may produce lines of nonuniform
thickness because of rasterization effects. In general, the line width and the coordinates of the
endpoints, transformed into device space, are arbitrary real numbers not quantised to device pixels. A

#### 3.15: 10.7.5          Automatic stroke adjustment
positioned. "Figure 70 — Rasterization without stroke adjustment" illustrates this effect.
For best results, it is important to compensate for the rasterization effects to produce strokes of
uniform thickness. This is especially important in low-resolution display applications. To meet this

need, PDF 1.2 provides an optional automatic stroke adjustment feature. When stroke adjustment is
enabled, the line width and the coordinates of a stroke shall automatically be adjusted as necessary to
produce lines of uniform thickness. The thickness shall be as near as possible to the requested line
width — no more than half a pixel different.
Figure 70 — Rasterization without stroke adjustment
If stroke adjustment is enabled and the requested line width, transformed into device space, is less
than half a pixel, the stroke shall be rendered as a single-pixel line.
NOTE        This is the thinnest line that can be rendered at device resolution. It is equivalent to the effect
produced by setting the line width to 0 (see 10.7.4, "Scan conversion rules").
Because automatic stroke adjustment can have a substantial effect on the appearance of lines, PDF
provides means to control whether the adjustment shall be performed. This may be specified with the
stroke adjustment parameter in the graphics state, set by means of the SA entry in a graphics state
parameter dictionary (see 8.4.5, "Graphics state parameter dictionaries").
10.8 Rendering for separations
10.8.1            General
A device onto which the PDF is being rendered has a set of colourants known by the renderer, the
knowledge of which is needed to produce the desired output. If those are subtractive colourants (see
8.6.4, "Device colour spaces") then the output for the device may take a form called separations where

#### 3.16: 10.8.1            General
are produced is up to the processing software.
10.8.2            Separations
Certain exceptions to the standard opaque and transparent imaging models are supported when
preparing device separations controlled by the overprint controls (see 8.6.7, "Overprint control"). For
example, using a Separation or DeviceN colour space, ink values may be introduced into one

#### 3.17: 10.8.2            Separations
be controlled very explicitly; thus providing detailed control when producing output that will be used
to control the colourant printing stations on a printing press.
Alternate colour spaces are supplied for DeviceN and Separation colour spaces so that files prepared
for generation of separations can be displayed on other devices and, in many cases, the overprint
controls are ignored. This can result in dramatically different colours in some cases. For example, if
two separate painting operations are performed on the same area of the page with the overprinting
controls turned on, one using a Cyan Separation colour space and the second using a Yellow
Separation colour space, then that area will appear green when produced using separations,
overprinting of the cyan and yellow inks, whereas displaying it on the screen, ignoring the overprint
controls, will generally produce yellow, the last colour painted.
10.8.3          Separation simulation
If it is important for the colours of the display for a PDF, on a device that normally would not be used to
produce separations, to more closely match those produced when using separations, then a simulation
of the separation process can be performed for the output to the non-separation device. Such a
simulation is defined here.

#### 3.18: 10.8.3          Separation simulation
a) Process the PDF as if separations were to be created for a simulated device that supports subtractive
process colourants and possibly spot colours. The PDF processor determines what process colours and
possible spot colours the simulated device is to have. A default DestOutputProfile, if available for a
subtractive device, or ColorantTable values, if available for a subtractive device, should be consulted to
determine the process colours to use (see 14.11.5, "Output intents").
b) Convert each separation into "flat XYZ" (no gamma) and using a background matte of all white.
c) Blend the resulting separations into a single result using a multiply blend (see "Table 133 — Variables
used in the basic compositing formula").
d) Convert the result to the actual device colour space and output it.

