# SDD Draft

Generated from:
- `spec/extracted/8.6-colour-spaces.spec.txt`

## Requirements

#### 0.1: 8.6.1 General
PDF includes facilities for specifying the colours of graphics objects. The colour facilities are divided
into two parts:
•    Colour specification. A PDF file may specify abstract colours in a device-independent way. Colours
may be described in any of a variety of colour systems, or colour spaces. Some colour spaces are
related to device colour representation (grayscale, RGB, CMYK), others to human visual
perception (CIE-based). Certain special features are also modelled as colour spaces: patterns,
colour mapping, separations, and high-fidelity and multitone colour.
•    Colour rendering. A PDF processor shall reproduce colours on the raster output device by a
multiple-step process that includes some combination of colour conversion, gamma correction,
halftoning, and scan conversion. Some aspects of this process use information that is specified in
PDF. However, unlike the facilities for colour specification, the colour-rendering facilities are
device-dependent and should not be included in a page description.
When the device is a subtractive colour device, "rendering for separations" may be implemented (see
10.8.2, "Separations"). In addition, a PDF reader may optionally support "separation simulation" for
any device (see 10.8.3, "Separation simulation"). In both cases overprinting (see 8.6.7, "Overprint
control") may be enabled. "Figure 20 — Colour specification" and "Figure 21 — Colour rendering"
illustrate the division between PDF’s (device-independent) colour specification and (device-
dependent) colour-rendering facilities. This subclause describes the colour specification features,
covering everything that PDF documents need to specify colours. The facilities for controlling colour
rendering are described in clause 10, "Rendering"; a PDF processor should use these facilities only to
configure or calibrate an output device or to achieve special device-dependent effects.

#### 0.2: 8.6.2 Colour values
As described in 8.5.3, "Path-painting operators", marks placed on the page by operators such as f and S
shall have a colour that is determined by the current colour parameter of the graphics state. A colour
value consists of one or more colour components, which are usually numbers. A gray level shall be
specified by a single number ranging from 0.0 (black) to 1.0 (white). Full colour values may be
specified in any of several ways; a common method uses three numeric values to specify red, green,
and blue components.
Colour values shall be interpreted according to the current colour space, another parameter of the
graphics state. A PDF content stream first selects a colour space by invoking the CS operator (for the
stroking colour) or the cs operator (for the nonstroking colour). It then selects colour values within
that colour space with the SC operator (stroking) or the sc operator (nonstroking). There are also
convenience operators — G, g, RG, rg, K, and k — that select both a colour space and a colour value
within it in a single step. "Table 73 — Colour operators" lists all the colour-setting operators.
Sampled images (see 8.9, "Images") specify the colour values of individual samples with respect to a
colour space designated by the image object itself. While these values are independent of the current
colour space and colour parameters in the graphics state, all later stages of colour processing shall
treat them in exactly the same way as colour values specified with the SC or sc operator.

#### 0.3: 8.6.3 Colour space families
Colour spaces are classified into colour space families. Spaces within a family share the same general
characteristics; they shall be distinguished by parameter values supplied at the time the space is
specified. The families fall into three broad categories:
•    Device colour spaces directly specify colours or shades of gray that the output device shall
produce. They provide a variety of colour specification methods, including grayscale, RGB (red-
green-blue), and CMYK (cyan-magenta-yellow-black), corresponding to the colour space families
DeviceGray, DeviceRGB, and DeviceCMYK. Since each of these families consists of just a single
colour space with no parameters, they may be referred to as the DeviceGray, DeviceRGB, and
DeviceCMYK colour spaces.
•    CIE-based colour spaces shall be based on an international standard for colour specification
created by the Commission Internationale de l’Éclairage (International Commission on
Illumination). These spaces specify colours in a way that is independent of the characteristics of
any particular output device. Colour space families in this category include CalGray, CalRGB, Lab,
and ICCBased. Individual colour spaces within these families shall be specified by means of
dictionaries containing the parameter values needed to define the space.
•    Special colour spaces add features or properties to an underlying colour space. They include
facilities for patterns, colour mapping, separations, and high-fidelity and multitone colour. The
corresponding colour space families are Pattern, Indexed, Separation, and DeviceN. Individual
colour spaces within these families shall be specified by means of additional parameters.

Figure 20 — Colour specification
Figure 21 — Colour rendering

"Table 61 — Colour space families" summarises the colour space families in PDF.
Table 61 — Colour space families
Device                           CIE-based                        Special
DeviceGray (PDF 1.1)             CalGray (PDF 1.1)                Indexed (PDF 1.1)
DeviceRGB (PDF 1.1)              CalRGB (PDF 1.1)                 Pattern (PDF 1.2)
DeviceCMYK (PDF 1.1)             Lab (PDF 1.1)                    Separation (PDF 1.2)
ICCBased (PDF 1.3)               DeviceN (PDF 1.3)
A colour space shall be defined by an array object whose first element is a name object identifying the
colour space family. The remaining array elements, if any, are parameters that further characterise the
colour space; their number and types vary according to the particular family. For families that do not
require parameters, the colour space may be specified simply by the family name itself instead of an
array.
A colour space shall be specified in one of two ways:
•    Within a content stream, the CS or cs operator establishes the current colour space parameter in
the graphics state. The operand shall always be name object, which either identifies one of the
colour spaces that need no additional parameters (DeviceGray, DeviceRGB, DeviceCMYK, or
some cases of Pattern) or shall be used as a key in the ColorSpace subdictionary of the current
resource dictionary (see 7.8.3, "Resource dictionaries"). In the latter case, the value of the
dictionary entry in turn shall be a colour space array or name. A colour space array shall never be
inline within a content stream.
•    Outside a content stream, certain objects, such as image XObjects, shall specify a colour space as
an explicit parameter, often associated with the key ColorSpace. In this case, the colour space
array or name shall always be defined directly as a PDF object, not by an entry in the ColorSpace
resource subdictionary. This convention also applies when colour spaces are defined in terms of
other colour spaces.
The following operators shall set the current colour space and current colour parameters in the
graphics state:
•    CS shall set the stroking colour space; cs shall set the nonstroking colour space.
•    SC and SCN shall set the stroking colour; sc and scn shall set the nonstroking colour. Depending
on the colour space, these operators shall have one or more operands, each specifying one
component of the colour value.
•    G, RG, and K shall set the stroking colour space implicitly and the stroking colour as specified by
the operands; g, rg, and k do the same for the nonstroking colour space and colour.

#### 0.4: 8.6.4.1           General
The device colour spaces enable a page description to specify colour values that are directly related to
their representation on an output device. Colour values in these spaces map directly (or by simple
conversions) to the application of device colourants, such as quantities of ink or intensities of display
phosphors. This enables a PDF writer to control colours precisely for a particular device, but the
results might not be consistent from one device to another.
Output devices form colours either by adding light sources together or by subtracting light from an
illuminating source. Computer displays and film recorders typically add colours; printing inks typically
subtract them. These two ways of forming colours give rise to two complementary methods of colour
specification, called additive and subtractive colour (see "Figure 22 — Additive and subtractive
colour"). The most widely used forms of these two types of colour specification are known as RGB and
CMYK, respectively, for the names of the primary colours on which they are based. They correspond to
the following device colour spaces:
•    DeviceGray controls the intensity of achromatic light, on a scale from black to white.
•    DeviceRGB controls the intensities of red, green, and blue light, the three additive primary
colours used in displays.
•    DeviceCMYK controls the concentrations of cyan, magenta, yellow, and black inks, the four
subtractive process colours used in printing.
NOTE       Although the notion of explicit colour spaces is a PDF 1.1 feature, the operators for specifying
colours in the device colour spaces — G, g, RG, rg, K, and k — are available in all versions of PDF.
Beginning with PDF 1.2, colours specified in device colour spaces can optionally be remapped
systematically into other colour spaces; see 8.6.5.6, "Default colour spaces".
Figure 22 — Additive and subtractive colour
In the transparent imaging model (PDF 1.4), the use of device colour spaces is subject to special
treatment within a transparency group whose group colour space is CIE-based (see 11.4,
"Transparency groups" and 11.6.6, "Transparency group XObjects"). In particular, the device colour
space operators should be used only if device colour spaces have been remapped to CIE-based spaces
by means of the default colour space mechanism. Otherwise, the colour results are implementation-
dependent and unpredictable.

#### 0.5: 8.6.4.2         DeviceGray colour space
Black, white, and intermediate shades of gray are special cases of full colour. A grayscale value shall be
represented by a single number in the range 0.0 to 1.0, where 0.0 corresponds to black, 1.0 to white,
and intermediate values to different gray levels.
EXAMPLE         This example shows alternative ways to select the DeviceGray colour space and a specific gray level within
that space for stroking operations.
/DeviceGray CS                            %Set DeviceGray colour space

gray SC                                       %Set gray level
gray G                                        %Set both in one operation
The CS and SC operators shall select the current stroking colour space and current stroking colour
separately; G shall set them in combination. (The cs, sc, and g operators shall perform the same
functions for nonstroking operations.) Setting either current colour space to DeviceGray shall
initialise the corresponding current colour to 0.0.

#### 0.6: 8.6.4.3           DeviceRGB colour space
Colours in the DeviceRGB colour space shall be specified according to the additive RGB (red-green-
blue) colour model, in which colour values shall be defined by three components representing the
intensities of the additive primary colourants red, green, and blue. Each component shall be specified
by a number in the range 0.0 to 1.0, where 0.0 shall denote the complete absence of a primary
component and 1.0 shall denote maximum intensity.
EXAMPLE           This example shows alternative ways to select the DeviceRGB colour space and a specific colour within that
space for stroking operations.
/DeviceRGB CS                             %Set DeviceRGB colour space
red green blue SC                         %Set colour
red green blue RG                         %Set both in one operation
1 0 0 RG                                  %Set a pure red colour for stroking operations
The CS and SC operators shall select the current stroking colour space and current stroking colour
separately; RG shall set them in combination. The cs, sc, and rg operators shall perform the same
functions for nonstroking operations. Setting either current colour space to DeviceRGB shall initialise
the red, green, and blue components of the corresponding current colour to 0.0.

#### 0.7: 8.6.4.4           DeviceCMYK colour space
The DeviceCMYK colour space allows colours to be specified according to the subtractive CMYK (cyan-
magenta-yellow-black) model typical of printers and other paper-based output devices. The four
components in a DeviceCMYK colour value shall represent the concentrations of these process
colourants. Each component shall be a number in the range 0.0 to 1.0, where 0.0 shall denote the
complete absence of a process colourant and 1.0 shall denote maximum concentration (absorbs as
much as possible of the additive primary).
NOTE        As much as the reflective colours (CMYK) decrease reflection with increased ink values and
radiant colours (RGB) increases the intensity of colours with increased values the values work in
an opposite manner.
EXAMPLE           The following shows alternative ways to select the DeviceCMYK colour space and a specific colour within
that space for stroking operations.
/DeviceCMYK CS                                %Set DeviceCMYK colour space
cyan magenta yellow black SC                  %Set colour
cyan magenta yellow black K                   %Set both in one operation
The CS and SC operators shall select the current stroking colour space and current stroking colour
separately; K shall set them in combination. The cs, sc, and k operators shall perform the same
functions for nonstroking operations. Setting either current colour space to DeviceCMYK shall
initialise the cyan, magenta, and yellow components of the corresponding current colour to 0.0 and the
black component to 1.0.

#### 0.8: 8.6.5.1        General
Calibrated colour in PDF shall be defined in terms of an international standard used in the graphic arts,
television, and printing industries. CIE-based colour spaces enable a page description to specify colour
values in a way that is related to human visual perception. The goal is for the same colour specification
to produce consistent results on different output devices, within the limitations of each device; "Figure
23 — Uncalibrated colour" illustrates the kind of variation in colour reproduction that can result from
the use of uncalibrated colour on different devices. PDF 1.1 supports three CIE-based colour space
families, named CalGray, CalRGB, and Lab; PDF 1.3 added a fourth, named ICCBased.
Figure 23 — Uncalibrated colour
A PDF reader shall ignore CalCMYK colour space attributes and render colours specified in this family
as if they had been specified using DeviceCMYK.
NOTE 1    In PDF 1.1, a colour space family named CalCMYK was partially defined, with the expectation
that its definition would be completed in a future version. However, this feature has been
completely removed. PDF 1.3 and later versions support calibrated four-component colour
spaces by means of ICC profiles (see 8.6.5.5, "ICCBased colour spaces").
NOTE 2    The details of the CIE colorimetric system and the theory on which it is based are beyond the
scope of this specification; see the Bibliography for sources of further information. The
semantics of CIE-based colour spaces are defined in terms of the relationship between the

space’s components and the tristimulus values X, Y, and Z of the CIE 1931 XYZ space. The CalRGB
and Lab colour spaces (PDF 1.1) are special cases of three-component CIE-based colour spaces,
known as CIE-based ABC colour spaces. These spaces are defined in terms of a two-stage,
nonlinear transformation of the CIE 1931 XYZ space. The formulation of such colour spaces
models a simple zone theory of colour vision, consisting of a nonlinear trichromatic first stage
combined with a nonlinear opponent-colour second stage. This formulation allows colours to be
digitised with minimum loss of fidelity, an important consideration in sampled images.
Colour values in a CIE-based ABC colour space shall have three components, arbitrarily named A, B, and
C. The first stage shall transform these components by first forcing their values to a specified range,
then applying decoding functions, and then multiplying the results by a 3-by-3 matrix, producing three
intermediate components arbitrarily named L, M, and N. The second stage shall transform these
intermediate components in a similar fashion, producing the final X, Y, and Z components of the CIE
1931 XYZ space (see "Figure 24 — Component transformations in a CIE-based ABC colour space").
Figure 24 — Component transformations in a CIE-based ABC colour space
Colour spaces in the CIE-based families shall be defined by an array
[name dictionary]
where name is the name of the family and dictionary is a dictionary containing parameters that further
characterise the space. The entries in this dictionary have specific interpretations that depend on the
colour space; some entries are required and some are optional. See the subclauses on specific colour
space families for details.
Setting the current stroking or nonstroking colour space to any CIE-based colour space shall initialise
all components of the corresponding current colour to 0.0 (unless the range of valid values for a given
component does not include 0.0, in which case the nearest valid value shall be substituted.)
NOTE 3      The model and terminology used here — CIE-based ABC (above) and CIE-based A (below) — are
derived from the PostScript language, which supports these colour space families in their full
generality. PDF supports specific useful cases of CIE-based ABC and CIE-based A spaces; most
others can be represented as ICCBased spaces.

#### 0.9: 8.6.5.2           CalGray colour spaces
A CalGray colour space (PDF 1.1) is a special case of a single-component CIE-based colour space,
known as a CIE-based A colour space. This type of space is the one-dimensional (and usually
achromatic) analog of CIE-based ABC spaces. Colour values in a CIE-based A space shall have a single
component, arbitrarily named A. "Figure 25 — Component transformations in a CIE-based A colour
space" illustrates the transformations of the A component to X, Y, and Z components of the CIE 1931
XYZ space.
Figure 25 — Component transformations in a CIE-based A colour space
A CalGray colour space shall be a CIE-based A colour space with only one transformation stage instead
of two. In this type of space, A represents the gray component of a calibrated gray space. This
component shall be in the range 0.0 to 1.0; component values falling outside that range shall be
adjusted to the nearest valid value without error indication. The decoding function (denoted by
"Decode A" in "Figure 25 — Component transformations in a CIE-based A colour space") is a gamma
function whose coefficient shall be specified by the Gamma entry in the colour space dictionary (see
"Table 62 — Entries in a CalGray colour space dictionary"). The transformation matrix denoted by
"Matrix A" in the figure is derived from the dictionary’s WhitePoint entry, as described below. Since
there is no second transformation stage, "Decode LMN" and "Matrix LMN" shall be implicitly taken to
be identity transformations.
Table 62 — Entries in a CalGray colour space dictionary
Key         Type     Value
WhitePoint array     (Required) An array of three numbers [XW YW ZW] specifying the tristimulus
value, in the CIE 1931 XYZ space, of the diffuse white point; see 8.6.5.3,
"CalRGB colour spaces", for further discussion. The numbers XW and ZW shall
be positive, and YW shall be equal to 1.0.
BlackPoint array     (Optional) An array of three numbers [XB YB ZB] specifying the tristimulus
value, in the CIE 1931 XYZ space, of the diffuse black point; see 8.6.5.3,
"CalRGB colour spaces", for further discussion. All three of these numbers
shall be non-negative. Default value: [0.0 0.0 0.0].
Gamma       number (Optional) A number G defining the gamma for the gray (A) component. G
shall be positive and is generally greater than or equal to 1. Default value: 1.
The transformation defined by the Gamma and WhitePoint entries is
𝑋 = 𝐿 = 𝑋𝑊 × 𝐴𝐺
𝑌 = 𝑀 = 𝑌𝑊 × 𝐴𝐺
𝑍 = 𝑁 = 𝑍𝑊 × 𝐴𝐺
In other words, the A component shall be first decoded by the gamma function, and the result shall be
multiplied by the components of the white point to obtain the L, M, and N components of the
intermediate representation. Since there is no second stage, the L, M, and N components shall also be

the X, Y, and Z components of the final representation.
EXAMPLE 1         The examples in this subclause illustrate interesting and useful special cases of CalGray spaces. This
example establishes a space consisting of the Y dimension of the CIE 1931 XYZ space with the CCIR XA/11–
recommended D65 white point.
[/CalGray
<</WhitePoint [0.9505 1.00 1.0890]>>
]
EXAMPLE 2         This example establishes a calibrated gray space with the CCIR XA/11–recommended D65 white point and
opto-electronic transfer function.
[/CalGray
<</WhitePoint [0.9505 1.00 1.0890]
/Gamma 2.222
>>
]

#### 0.10: 8.6.5.3           CalRGB colour spaces
A CalRGB colour space is a CIE-based ABC colour space with only one transformation stage instead of
two. In this type of space, A, B, and C represent calibrated red, green, and blue colour values. These
three colour components shall be in the range 0.0 to 1.0; component values falling outside that range
shall be adjusted to the nearest valid value without error indication. The decoding functions (denoted
by "Decode ABC" in "Figure 24 — Component transformations in a CIE-based ABC colour space") are
gamma functions whose coefficients shall be specified by the Gamma entry in the colour space
dictionary (see "Table 63 — Entries in a CalRGB colour space dictionary"). The transformation matrix
denoted by "Matrix ABC" in "Figure 24 — Component transformations in a CIE-based ABC colour
space" shall be defined by the dictionary’s Matrix entry. Since there is no second transformation stage,
"Decode LMN" and "Matrix LMN" shall be implicitly taken to be identity transformations.
Table 63 — Entries in a CalRGB colour space dictionary
Key            Type Value
WhitePoint array (Required) An array of three numbers [XW YW ZW] specifying the tristimulus value, in the
CIE 1931 XYZ space, of the diffuse white point; see below for further discussion. The
numbers XW and ZW shall be positive, and YW shall be equal to 1.0.
BlackPoint array (Optional) An array of three numbers [XK YK ZK] specifying the tristimulus value, in the
CIE 1931 XYZ space, of the diffuse black point; see below for further discussion. All three
of these numbers shall be non-negative. Default value: [0.0 0.0 0.0].
Gamma          array (Optional) An array of three numbers [GR GG GB] specifying the gamma for the red, green,
and blue (A, B, and C) components of the colour space. Default value: [1.0 1.0 1.0].
Matrix         array (Optional) An array of nine numbers [XA YA ZA XB YB ZB XC YC ZC] specifying the linear
interpretation of the decoded A, B, and C components of the colour space with respect to
the final XYZ representation. Default value: the identity matrix [1 0 0 0 1 0 0 0 1].
The WhitePoint and BlackPoint entries in the colour space dictionary shall control the overall effect
of the CIE-based gamut mapping function described in subclause 10.3, "CIE-Based colour to device
colour". Typically, the colours specified by WhitePoint and BlackPoint shall be mapped to the nearly
lightest and nearly darkest achromatic colours that the output device is capable of rendering in a way
that preserves colour appearance and visual contrast.
WhitePoint represents the diffuse achromatic highlight, not a specular highlight. Specular highlights,
achromatic or otherwise, are often reproduced lighter than the diffuse highlight. BlackPoint
represents the diffuse achromatic shadow; its value is limited by the dynamic range of the input device.
In images produced by a photographic system, the values of WhitePoint and BlackPoint vary with
exposure, system response, and artistic intent; hence, their values are image-dependent.
The transformation defined by the Gamma and Matrix entries in the CalRGB colour space dictionary
shall be
𝑋 = 𝐿 = 𝑋𝐴 × 𝐴𝐺𝑅 + 𝑋𝐵 × 𝐵𝐺𝐺 + 𝑋𝐶 × 𝐶 𝐺𝐵
𝑌 = 𝑀 = 𝑌𝐴 × 𝐴𝐺𝑅 + 𝑌𝐵 × 𝐵𝐺𝐺 + 𝑌𝐶 × 𝐶 𝐺𝐵
𝑍 = 𝑁 = 𝑍𝐴 × 𝐴𝐺𝑅 + 𝑍𝐵 × 𝐵𝐺𝐺 + 𝑍𝐶 × 𝐶 𝐺𝐵
The A, B, and C components shall first be decoded individually by the gamma functions. The results
shall be treated as a three-element vector and multiplied by Matrix (a 3-by-3 matrix) to obtain the L, M,
and N components of the intermediate representation. Since there is no second stage, these shall also
be the X, Y, and Z components of the final representation.
EXAMPLE          The following shows an example of a CalRGB colour space for the CCIR XA/11–recommended D65 white
point with 1.8 gammas and Sony Trinitron phosphor chromaticities.
[/CalRGB
<</WhitePoint [0.9505 1.00 1.0890]
/Gamma [1.8000 1.8000 1.8000]
/Matrix [0.4497 0.2446 0.0252
0.3163 0.6720 0.1412
0.1845 0.0833 0.9227
]
>>
]
The parameters of a CalRGB colour space may be specified in terms of the CIE 1931 chromaticity
coordinates (xR, yR ), (xG, yG ), (xB, yB ) of the red, green, and blue phosphors, respectively, and the
chromaticity (xW, yW ) of the diffuse white point corresponding to a linear RGB value (R, G, B), where R,
G, and B should all equal 1.0. The standard CIE notation uses lowercase letters to specify chromaticity
coordinates and uppercase letters to specify tristimulus values. Given this information, Matrix and
WhitePoint shall be calculated as follows:
𝑧 = 𝑦𝑊 × ((𝑥𝐺 − 𝑥𝐵 ) × 𝑦𝑅 − (𝑥𝑅 − 𝑥𝐵 ) × 𝑦𝐺 + (𝑥𝑅 − 𝑥𝐺 ) × 𝑦𝐵 )
𝑦𝑅 (𝑥𝐺 − 𝑥𝐵 ) × 𝑦𝑊 − (𝑥𝑊 − 𝑥𝐵 ) × 𝑦𝐺 + (𝑥𝑊 − 𝑥𝐺 ) × 𝑦𝐵
𝑌𝐴 =     ×
𝑅                           𝑧
𝑥                       1−𝑥R
𝑋𝐴 = 𝑌𝐴 × R           ZA = YA × (       − 1)
𝑦R                       𝑦R
𝑦G (𝑥R − 𝑥B ) × 𝑦W − (𝑥W − 𝑥B ) × 𝑦R + (𝑥W − 𝑥R ) × 𝑦B
YB =     ×
G                          𝑧

𝑥                        1−𝑥
X B = YB × 𝑦G          ZB = YB × ( 𝑦 G − 1)
G                       G
𝑦B (𝑥R − 𝑥G ) × 𝑦W − (𝑥W − 𝑥G ) × 𝑦R + (𝑥W − 𝑥R ) × 𝑦G
YC =     ×
B                          𝑧
𝑥                        1−𝑥B
X C = YC × B           ZC = YC × (         − 1)
𝑦B                        𝑦B
XW = XA × R + XB × G + XC × B
YW = YA × R + YB × G + YC × B
ZW = ZA × R + ZB × G + ZC × B
8.6.5.4           Lab colour spaces
A Lab colour space is a CIE-based ABC colour space with two transformation stages (see "Figure 24 —

#### 0.11: 8.6.5.4           Lab colour spaces
represent the L*, a*, and b* components of a CIE 1976 L*a*b* space. The range of the first (L*)
component shall be 0 to 100; the ranges of the second and third (a* and b*) components shall be
defined by the Range entry in the colour space dictionary (see "Table 64 — Entries in a Lab colour
space dictionary"). Component values falling outside the specified range shall be adjusted to the
nearest valid value without error indication.
Table 64 — Entries in a Lab colour space dictionary
Key            Type          Value
WhitePoint array             (Required) An array of three numbers [XW YW ZW] that shall specify the tristimulus
value, in the CIE 1931 XYZ space, of the diffuse white point; see 8.6.5.3, "CalRGB
colour spaces" for further discussion. The numbers XW and ZW shall be positive, and
YW shall be 1.0.
BlackPoint array             (Optional) An array of three numbers [XB YB ZB] that shall specify the tristimulus
value, in the CIE 1931 XYZ space, of the diffuse black point; see 8.6.5.3, "CalRGB
colour spaces" for further discussion. All three of these numbers shall be non-
negative. Default value: [0.0 0.0 0.0].
Range          array         (Optional) An array of four numbers [amin amax bmin bmax] that shall specify the range of
valid values for the a* and b* (B and C) components of the colour space — that is,
𝑎𝑚𝑖𝑛 ≤ 𝑎 ∗≤ 𝑎𝑚𝑎𝑥
and
𝑏𝑚𝑖𝑛 ≤ 𝑏 ∗≤ 𝑏𝑚𝑎𝑥
Component values falling outside the specified range shall be adjusted to the nearest
valid value without error indication.
Default value: [-100 100 -100 100]
"Figure 26 — Lab colour space" illustrates the coordinates of a typical Lab colour space; "Figure 27 —
Colour gamuts" compares the gamuts (ranges of representable colours) for L*a*b*, RGB, and CMYK
spaces.
Figure 26 — Lab colour space
Figure 27 — Colour gamuts
A Lab colour space shall not specify explicit decoding functions or matrix coefficients for either stage of
the transformation from L*a*b* space to XYZ space (denoted by "Decode ABC", "Matrix ABC", "Decode
LMN", and "Matrix LMN" in "Figure 24 — Component transformations in a CIE-based ABC colour
space"). Instead, these parameters shall have constant implicit values. The first transformation stage
shall be defined by the equations
𝐿∗ + 16     𝑎∗
𝐿=           +
116      500
𝐿∗ + 16
𝑀=
𝐿∗ + 16     𝑏∗
𝑁=            −
116      200
The second transformation stage shall be
𝑋 = 𝑋𝑊 × 𝑔(𝐿)
𝑌 = 𝑌𝑊 × 𝑔(𝑀)
𝑍 = 𝑍𝑊 × 𝑔(𝑁)
where the function g(x) shall be defined as
𝑔(𝑥) = 𝑥 3                  if 𝑥 ≥ 29

108       4
𝑔(𝑥) =       × (𝑥 − )        otherwise
841       29
EXAMPLE         The following defines the CIE 1976 L*a*b* space with the CCIR XA/11–recommended D65 white point (see
ITU Recommendation BT.709). The a* and b* components, although theoretically unbounded, are defined
to lie in the useful range -128 to +127.
[/Lab
<</WhitePoint [0.9505 1.00 1.0890]
/Range [-128 127 -128 127]
>>
]
8.6.5.5          ICCBased colour spaces
ICCBased colour spaces (PDF 1.3) shall be based on a cross-platform colour profile as defined by the

#### 0.12: 8.6.5.5          ICCBased colour spaces
characterised by entries in the colour space dictionary, an ICCBased colour space shall be
characterised by a sequence of bytes in a standard format. Details of the profile format can be found in
the ICC specification.
An ICCBased colour space shall be an array: [/ICCBased stream]
The stream shall contain the ICC profile. Besides the usual entries common to all streams (see "Table 5
— Entries common to all stream dictionaries"), the profile stream shall have the additional entries
listed in "Table 65 — Additional entries specific to an ICC profile stream dictionary".
Table 65 — Additional entries specific to an ICC profile stream dictionary
Key           Type      Value
N            integer   (Required) The number of colour components in the colour space described by the ICC
profile data. This number shall match the number of components actually in the ICC
profile. Valid values for N: 1, 3, or 4.
Alternate    name or    (Optional) An alternate colour space that shall be used in case the one specified in the
array     stream data is not supported. PDF readers should not use this colour space. The
alternate space may be any valid colour space (except a Pattern colour space) that has
the number of components specified by N. If this entry is omitted and the PDF reader
does not understand the ICC profile data, the colour space that shall be used is
DeviceGray, DeviceRGB, or DeviceCMYK, depending on whether the value of N is 1, 3,
or 4, respectively. There shall not be conversion of source colour values, such as a tint
transformation, when using the alternate colour space. Colour values within the range
of the ICCBased colour space might not be within the range of the alternate colour
space. In this case and after constraining to the ICCBased range, the nearest values
within the range of the alternate space shall be substituted without error indication.
Range        array     (Optional) An array of 2 × N numbers [𝑚𝑖𝑛0 𝑚𝑎𝑥0 𝑚𝑖𝑛1 𝑚𝑎𝑥1 … ] that shall specify the
minimum and maximum valid values of the corresponding colour components. These
values shall match the information in the ICC profile. Default value: [0.0 1.0 0.0 1.0 … ].
Metadata     stream    (Optional; PDF 1.4) A metadata stream that shall contain metadata for the colour space
("see 14.3.2, "Metadata streams").
"Table 66 — ICC Specification versions supported by ICC based colour spaces" shows the versions of
the ICC specification on which the ICCBased colour spaces that PDF versions 1.3 and later shall use.
(Earlier versions of the ICC specification shall also be supported.)
Table 66 — ICC Specification versions supported by ICC based colour spaces
PDF Version ICC Specification Version
1.3           3.3
1.4           ICC.1:1998-09 and its addendum ICC.1A:1999-04
1.5           ICC.1:2001-12
1.6           ICC.1:2003-09
1.7           ICC.1:2010 (ISO 15076-1:2010)
2.0           ICC.1:2010 (ISO 15076-1:2010)

#### 0.13: 2.0           ICC.1:2010 (ISO 15076-1:2010)
render all embedded ICC profiles regardless of the PDF version.
•    A PDF reader shall always process an embedded ICC profile according to the corresponding
version of the PDF being processed as shown in "Table 66 — ICC Specification versions supported
by ICC based colour spaces" above; it shall not substitute the alternate colour space in these cases.
•    A PDF writer should use ICC 1:2010 profiles. It may embed profiles conforming to an earlier or
later ICC version.
•    A PDF processor shall substitute the alternate colour space for embedded profiles conforming to
later ICC versions, if the PDF processor is not capable of properly processing the embedded ICC
profile.
•    PDF writers shall only use the profile types shown in "Table 67 — ICC profile types" for specifying
calibrated colour spaces for colouring graphics objects. Each of the indicated fields shall have one
of the values listed for that field in the second column of the table. Profiles shall satisfy both the
criteria shown in the table. The terminology is taken from the ICC specifications.
•    Profiles shall conform to the specification version indicated by the Profile version number in its
header.
NOTE 1     XYZ and 16-bit L*a*b* profiles are not listed.
Table 67 — ICC profile types
Header Field            Required Value
deviceClass             icSigInputClass ('scnr')
icSigDisplayClass ('mntr')
icSigOutputClass ('prtr')
icSigColorSpaceClass ('spac')
colorSpace              icSigGrayData ('GRAY')
icSigRgbData ('RGB ')
icSigCmykData ('CMYK')
icSigLabData ('Lab ')

The terminology used in PDF colour spaces and ICC colour profiles is similar, but sometimes the same
terms are used with different meanings. The default value for each component in an ICCBased colour
space is 0. The range of each colour component is a function of the colour space specified by the profile
and is indicated in the ICC specification. The ranges for several ICC colour spaces are shown in "Table
68 — Ranges for typical ICC colour spaces".
Table 68 — Ranges for typical ICC colour spaces
ICC Colour Space             Component Ranges
Gray                         [0.0 1.0]
RGB                          [0.0 1.0]
CMYK                         [0.0 1.0]
L*a*b*                       𝐿∗ : [0 100]; a∗ and 𝑏 ∗ : [−128 127]
Since the ICCBased colour space is being used as a source colour space, only the "to CIE" profile
information (AToB in ICC terminology) shall be used; the "from CIE" (BToA) information shall be
ignored when present. An ICC profile may also specify a rendering intent, but a PDF reader shall ignore
this information; the rendering intent shall be specified in PDF by a separate parameter (see 8.6.5.8,
"Rendering intents").
The requirements stated above apply to an ICCBased colour space that is used to specify the source
colours of graphics objects. When such a space is used as the blending colour space for a transparency
group in the transparent imaging model (see 11.3.4, "Blending colour space"; 11.4, "Transparency
groups"; and 11.6.6, "Transparency group XObjects"), it shall have both "to CIE" (AToB) and "from CIE"
(BToA) information. This is because the group colour space shall be used as both the destination for
objects being painted within the group and the source for the group’s results. ICC profiles shall also be
used in specifying output intents for matching the colour characteristics of a PDF document with those
of a target output device or production environment. When used in this context, they shall be subject to
still other constraints on the "to CIE" and "from CIE" information; 14.11.5, "Output intents", for details.
The representations of ICCBased colour spaces are less compact than CalGray, CalRGB, and Lab, but
can represent a wider range of colour spaces.
NOTE 2      One particular colour space is the "standard RGB" or sRGB, defined in IEC 61966-2-1 ed1.0
(1999-10) Multimedia systems and equipment - Colour measurement and management - Part 2-
1: Colour management - Default RGB colour space - sRGB (with Amendment 1 IEC 61966-2-1-
am1 ed1.0 (2003-01)). In PDF, the sRGB colour space can only be expressed as an ICCBased
space, although it can be approximated by a CalRGB space.
EXAMPLE           The following shows an ICCBased colour space for a typical three-component RGB space. The profile’s data
has been encoded in hexadecimal representation for readability; in actual practice, a lossless decompression
filter such as FlateDecode can be used.
10 0 obj                                                   %Colour space
[/ICCBased 15 0 R]
endobj
15 0 obj                                                   %ICC profile stream
<</N 3
/Alternate /DeviceRGB
/Length 1605
/Filter /ASCIIHexDecode
>>
stream
00 00 02 0C 61 70 70 6C 02 00 00 00 6D 6E 74 72
52 47 42 20 58 59 5A 20 07 CB 00 02 00 16 00 0E
00 22 00 2C 61 63 73 70 41 50 50 4C 00 00 00 00
61 70 70 6C 00 00 04 01 00 00 00 00 00 00 00 02
00 00 00 00 00 00 F6 D4 00 01 00 00 00 00 D3 2B
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 09 64 65 73 63 00 00 00 F0 00 00 00 71
72 58 59 5A 00 00 01 64 00 00 00 14 67 58 59 5A
00 00 01 78 00 00 00 14 62 58 59 5A 00 00 01 8C
00 00 00 14 72 54 52 43 00 00 01 A0 00 00 00 0E
67 54 52 43 00 00 01 B0 00 00 00 0E 62 54 52 43
00 00 01 C0 00 00 00 0E 77 74 70 74 00 00 01 D0
00 00 00 14 63 70 72 74 00 00 01 E4 00 00 00 27
64 65 73 63 00 00 00 00 00 00 00 17 41 70 70 6C
65 20 31 33 22 20 52 47 42 20 53 74 61 6E 64 61
72 64 00 00 00 00 00 00 00 00 00 00 00 17 41 70
70 6C 65 20 31 33 22 20 52 47 42 20 53 74 61 6E
64 61 72 64 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 58 59 5A 58 59 5A 20 00 00 00 00 00 00 63 0A
00 00 35 0F 00 00 03 30 58 59 5A 20 00 00 00 00
00 00 53 3D 00 00 AE 37 00 00 15 76 58 59 5A 20
00 00 00 00 00 00 40 89 00 00 1C AF 00 00 BA 82
63 75 72 76 00 00 00 00 00 00 00 01 01 CC 63 75
63 75 72 76 00 00 00 00 00 00 00 01 01 CC 63 75
63 75 72 76 00 00 00 00 00 00 00 01 01 CC 58 59
58 59 5A 20 00 00 00 00 00 00 F3 1B 00 01 00 00
00 01 67 E7 74 65 78 74 00 00 00 00 20 43 6F 70
79 72 69 67 68 74 20 41 70 70 6C 65 20 43 6F 6D
70 75 74 65 72 73 20 31 39 39 34 00>
endstream
endobj
8.6.5.6         Default colour spaces
Colours that are specified in a device colour space (DeviceGray, DeviceRGB, or DeviceCMYK) are

#### 0.14: 8.6.5.6         Default colour spaces
colours shall be systematically transformed (remapped) into device-independent CIE-based colour
spaces. This capability can be useful in a variety of circumstances:
•    A document originally intended for one output device is redirected to a different device.
•    A document is intended to be compatible with older PDF readers that do not support CIE-based
colours.
•    Colour corrections or rendering intents need to be applied to device colours (see 8.6.5.8,
"Rendering intents").
A colour space is selected for painting each graphics object. This is either the current colour space
parameter in the graphics state or a colour space given as an entry in an image XObject, inline image, or
shading dictionary. Regardless of how the colour space is specified, it shall be subject to remapping as
described below.

When a device colour space is selected, the ColorSpace subdictionary of the current resource
dictionary (see 7.8.3, "Resource dictionaries") is checked for the presence of an entry designating a
corresponding default colour space (DefaultGray, DefaultRGB, or DefaultCMYK, corresponding to
DeviceGray, DeviceRGB, or DeviceCMYK, respectively). If such an entry is present, its value shall be
used as the colour space for the operation currently being performed.
NOTE        (2020) This remapping means that the current colour space is defined by the default colour
space rather than DeviceGray, DeviceRGB or DeviceCMYK. Provisions in this standard that
apply specifically to device colour spaces are then not applicable to graphic objects painted when
the default colour space is not one of DeviceGray, DeviceRGB or DeviceCMYK.
Colour values in the original device colour space shall be passed unchanged to the default colour space,
which shall have the same number of components as the original space. The default colour space
should be chosen to be compatible with the original, taking into account the components’ ranges and
whether the components are additive or subtractive. If a colour value lies outside the range of the
default colour space, it shall be adjusted to the nearest valid value.
Any colour space other than a Lab, Indexed, or Pattern colour space may be used as a default colour
space and it should be compatible with the original device colour space as described above.
If the selected space is a special colour space based on an underlying device colour space, the default
colour space shall be used in place of the underlying space. This shall apply to the following colour
spaces:
•    The underlying colour space of a Pattern colour space
•    The base colour space of an Indexed colour space
•    The alternate colour space of a Separation or DeviceN colour space (but only if the alternate
colour space is actually selected)
•    See 8.6.6, "Special colour spaces", for details on these colour spaces.
There is no conversion of colour values, such as a tint transformation, when using the default colour
space. Colour values that are within the range of the device colour space might not be within the range
of the default colour space (particularly if the default is an ICCBased colour space). In this case, the
nearest values within the range of the default space are used. For this reason, a Lab colour space shall
not be used as the DefaultRGB colour space.
8.6.5.7           Implicit conversion of CIE-Based colour spaces
In cases where a source colour space accurately represents the particular output device being used, a

#### 0.15: 8.6.5.7           Implicit conversion of CIE-Based colour spaces
as output values. This avoids any unwanted computational error and in the case of 4 component colour
spaces avoids the conversion from 4 components to 3 and back to 4, a process that loses critical colour
information.
NOTE 1      In workflows in which PDF documents are intended for rendering on a specific target output
device (such as a printing press with particular inks and media), it is often useful to specify the
source colours for some or all of a document’s objects in a CIE-based colour space that matches
the calibration of the intended device. The resulting document, although tailored to the specific
characteristics of the target device, remains device-independent and will produce reasonable
results if retargeted to a different output device. However, the expectation is that if the
document is printed on the intended target device, source colours that have been specified in a
colour space matching the calibration of the device will pass through unchanged, without
conversion to and from the intermediate CIE 1931 XYZ space as depicted in "Figure 24 —
Component transformations in a CIE-based ABC colour space".
NOTE 2     In particular, when colours intended for a CMYK output device are specified in an ICCBased
colour space using a matching CMYK printing profile, converting such colours from four
components to three components and back is unnecessary, and results in a loss of fidelity in the
black component. In such cases, a PDF processor could provide the ability for the user to specify
a particular calibration to use for printing, proofing, or previewing. This calibration is then
considered to be that of the native colour space of the intended output device (typically
DeviceCMYK), and colours expressed in a CIE-based source colour space matching it can be
treated as if they were specified directly in the device’s native colour space.
NOTE 3     The conditions under which such implicit conversion is done cannot be specified in PDF, since
nothing in PDF describes the calibration of the output device (although an output intent
dictionary, if present, can suggest such a calibration; "see 14.11.5, "Output intents"). The
conversion is completely hidden by the PDF processor and plays no part in the interpretation of
PDF colour spaces.
When this type of implicit conversion is done, all of the semantics of the device colour space shall also
apply, even though they do not apply to CIE-based spaces in general. In particular:
•    The non-zero overprint mode (see 8.6.7, "Overprint control") shall determine the interpretation
of colour component values in the space.
•    If the space is used as the blending colour space for a transparency group in the transparent
imaging model (see 11.3.4, "Blending colour space"; 11.4, "Transparency groups"; and 11.6.6,
"Transparency group XObjects"), components of the space, such as Cyan, may be selected in a
Separation or DeviceN colour space used within the group (see 8.6.6.4, "Separation colour
spaces" and 8.6.6.5, "DeviceN colour spaces").
•    Likewise, any uses of device colour spaces for objects within such a transparency group have
well-defined conversions to the group colour space.
NOTE 4     A source colour space can be specified directly (for example, with an ICCBased colour space) or
indirectly using the default colour space mechanism (for example, DefaultCMYK; see 8.6.5.6,
"Default colour spaces"). The implicit conversion of a CIE-based colour space to a device space
need not depend on whether the CIE-based space is specified directly or indirectly.
8.6.5.8         Rendering intents
Although CIE-based colour specifications are theoretically device-independent, they are subject to

#### 0.16: 8.6.5.8         Rendering intents
sometimes require compromises to be made among various properties of a colour specification when
rendering colours for a given device. Specifying a rendering intent (PDF 1.1) allows a PDF writer to set
priorities regarding which of these properties to preserve and which to sacrifice.
EXAMPLE        The PDF writer might request that colours falling within the output device’s gamut (the range of colours it
can reproduce) be rendered exactly while sacrificing the accuracy of out-of-gamut colours, or that a scanned
image such as a photograph be rendered in a perceptually pleasing manner at the cost of strict colorimetric
accuracy.
Rendering intents shall be specified with the ri operator (see 8.4.4, "Graphics state operators"), the RI
entry in a graphics state parameter dictionary (see 8.4.5, "Graphics state parameter dictionaries"), or
with the Intent entry in image dictionaries (see 8.9.5, "Image dictionaries"). The value shall be a name
identifying the rendering intent. "Table 69 — Rendering intents" lists the standard rendering intents
that shall be recognised.

Table 69 — Rendering intents
Name                       Description
AbsoluteColorimetri        Colours shall be represented solely with respect to the light source; no correction shall
c                          be made for the output medium’s white point (such as the colour of unprinted paper).
Thus, for example, a monitor’s white point, which is bluish compared to that of a
printer’s paper, would be reproduced with a blue cast. In-gamut colours shall be
reproduced exactly; out-of-gamut colours shall be mapped to the nearest value within
the reproducible gamut
NOTE 1 This style of reproduction has the advantage of providing exact colour matches from
one output medium to another. It has the disadvantage of causing colours with Y
values between the medium’s white point and 1.0 to be out of gamut. Logos and solid
colours are typical cases requiring exact reproduction across different media.
RelativeColorimetric Colours shall be represented with respect to the combination of the light source and
the output medium’s white point (such as the colour of unprinted paper). Thus, a
monitor’s white point can be reproduced on a printer by simply leaving the paper
unmarked, ignoring colour differences between the two media. In-gamut colours shall
be reproduced exactly; out-of-gamut colours shall be mapped to the nearest value
within the reproducible gamut.
NOTE 2 This style of reproduction has the advantage of adapting for the varying white points
of different output media. It has the disadvantage of not providing exact colour
matches from one medium to another. Vector graphics are a typical use case.
Saturation                 Colours shall be represented in a manner that preserves or emphasizes saturation.
Reproduction of in-gamut colours may or may not be colorimetrically accurate.
NOTE 3 Business graphics are a typical use case where saturation is the most important
attribute of the colour.
Perceptual                 Colours shall be represented in a manner that provides a pleasing perceptual
appearance. To preserve colour relationships, both in-gamut and out-of-gamut colours
shall be generally modified from their precise colorimetric values.
NOTE 4 Scanned images are a typical use case.
"Figure 28 — Rendering intents" illustrates the effects of the standard rendering intents. These intents
have been chosen to correspond to those defined by the International Color Consortium (ICC), an
industry organisation that has developed standards for device-independent colour. If a PDF processor
does not recognise the specified name, it shall use the RelativeColorimetric intent by default.
NOTE        The exact set of rendering intents supported can vary from one output device to another; a
particular device does not have to support all PDF rendering intents and can support additional
ones beyond those listed in the table above.
Figure 28 — Rendering intents
See 11.7.5, "Rendering parameters and transparency", and in particular 11.7.5.3, "Rendering intent,
black point compensation and colour conversions", for further discussion of the role of rendering
intents in the transparent imaging model.
8.6.5.9        Use of black point compensation
Black point compensation applies to CIE-based colour conversion and extends the concept of the use of

#### 0.17: 8.6.5.9        Use of black point compensation
The use of black point compensation can be controlled through the UseBlackPtComp entry in the
ExtGState dictionary. If the value for UseBlackPtComp is ON, colour conversion shall be carried out
according to the provisions in ISO 18619. If it is set to OFF no black point compensation shall be carried
out. If the value is not given or set to Default, then the behaviour is left to the PDF processor to
determine. If the current render intent of an object is AbsColorimetric then the value of
UseBlackPtComp shall be treated as OFF.

8.6.6 Special colour spaces
8.6.6.1           General
Special colour spaces add features or properties to an underlying colour space. There are four special

#### 0.18: 8.6.6.1           General
A Pattern colour space (PDF 1.2) specifies that an area is to be painted with a pattern rather than a

#### 0.19: 8.6.6.2           Pattern colour spaces
"Patterns", discusses patterns in detail.
8.6.6.3           Indexed colour spaces
An Indexed colour space specifies a colour map or colour table of arbitrary colours in some other

#### 0.20: 8.6.6.3           Indexed colour spaces
colour value it finds there. This technique can considerably reduce the amount of data required to
represent a sampled image.
An Indexed colour space shall be defined by a four-element array:
[/Indexed base hival lookup]
The first element shall be the colour space family name Indexed. The remaining elements shall be
parameters that an Indexed colour space requires; their meanings are discussed below. Setting the
current stroking or nonstroking colour space to an Indexed colour space shall initialise the
corresponding current colour to 0.
The base parameter shall be an array or name that identifies the base colour space in which the values
in the colour table are to be interpreted. It shall be any device or CIE-based colour space or (PDF 1.3) a
Separation or DeviceN space, but shall not be a Pattern space or another Indexed space. If the base
colour space is DeviceRGB, the values in the colour table shall be interpreted as red, green, and blue
components; if the base colour space is a CIE-based ABC space such as a CalRGB or Lab space, the
values shall be interpreted as A, B, and C components.
The hival parameter shall be an integer that specifies the maximum valid index value. The colour table
shall be indexed by integers in the range 0 to hival. hival shall be no greater than 255, which is the
integer required to index a table with 8-bit index values.
The colour table shall be defined by the lookup parameter, which may be either a stream or (PDF 1.2) a
byte string. It shall provide the mapping between index values and the corresponding colours in the
base colour space.
The colour table data shall be 𝑚 × (ℎ𝑖𝑣𝑎𝑙 + 1) bytes long, where m is the number of colour
components in the base colour space. Each byte shall be an unsigned integer in the range 0 to 255 that
shall be scaled to the range of the corresponding colour component in the base colour space; that is, 0
corresponds to the minimum value in the range for that component, and 255 corresponds to the
maximum.
The colour components for each entry in the table shall appear consecutively in the string or stream.
EXAMPLE 1       If the base colour space is DeviceRGB and the indexed colour space contains two colours, the order of bytes
in the string or stream is R0 G0 B0 R1 G1 B1, where letters denote the colour component and numeric
subscripts denote the table entry.
EXAMPLE 2       The following illustrates the specification of an Indexed colour space that maps 8-bit index values to three-
component colour values in the DeviceRGB colour space.
[/Indexed
/DeviceRGB
<000000 FF0000 00FF00 0000FF B57342 …>
]
The example shows only the first five colour values in the lookup string; in all, there will be 256 colour
values and the string will be 768 bytes long. Having established this colour space, the PDF file can now
specify colours as single-component values in the range 0 to 255. For example, a colour value of 4
selects an RGB colour whose components are coded as the hexadecimal integers B5, 73, and 42.
Dividing these by 255 and scaling the results to the range 0.0 to 1.0 yields a colour with red, green, and
blue components of 0.710, 0.451, and 0.259, respectively.
Although an Indexed colour space is useful mainly for images, index values can also be used with the
colour selection operators SC, SCN, sc, and scn.
EXAMPLE 3       The following selects the same colour as does an image sample value of 123.
123 sc
The index value should be an integer in the range 0 to hival. If the value is a real number, it shall be
rounded to the nearest integer (0.5 values shall be rounded up); if it is outside the range 0 to hival, it
shall be adjusted to the nearest value within that range.
8.6.6.4         Separation colour spaces
A Separation colour space (PDF 1.2) provides a means for specifying the use of additional colourants

#### 0.21: 8.6.6.4         Separation colour spaces
device. When such a space is the current colour space, the current colour shall be a single-component
value, called a tint, that controls the application of the given colourant or colour components only.
NOTE 1      Colour output devices produce full colour by combining primary or process colourants in varying
amounts. On an additive colour device such as a display, the primary colourants consist of red,
green, and blue phosphors; on a subtractive device such as a printer, they typically consist of
cyan, magenta, yellow, and sometimes black inks. In addition, some devices can apply special
colourants, often called spot colourants, to produce effects that cannot be achieved with the
standard process colourants alone. Examples include metallic and fluorescent colours and
special textures.
NOTE 2      When printing a page, most devices produce a single composite page on which all process
colourants (and spot colourants, if any) are combined. However, some devices, such as
imagesetters, produce a separate, monochromatic rendition of the page, called a separation, for
each colourant. When the separations are later combined — on a printing press, for example —
and the proper inks or other colourants are applied to them, the result is a full-colour page.
NOTE 3      The term separation is often misused as a synonym for an individual device colourant. In the
context of this discussion, a printing system that produces separations generates a separate
piece of physical medium (generally film) for each colourant. It is these pieces of physical

medium that are correctly referred to as separations. A particular colourant properly constitutes
a separation only if the device is generating physical separations, one of which corresponds to
the given colourant. The Separation colour space is so named for historical reasons, but it has
evolved to the broader purpose of controlling the application of individual colourants in general,
regardless of whether they are actually realised as physical separations.
NOTE 4      The operation of a Separation colour space itself is independent of the characteristics of any
particular output device. Depending on the device, the colour space does not have to correspond
to a true, physical separation or to an actual colourant. For example, a Separation colour space
could be used to control the application of a single process colourant (such as cyan) on a
composite device that does not produce physical separations, or could represent a colour (such
as orange) for which no specific colourant exists on the device. A Separation colour space
provides consistent, predictable behaviour, even on devices that cannot directly generate the
requested colour.
A Separation colour space is defined as follows:
[/Separation name alternateSpace tintTransform]
It shall be a four-element array whose first element shall be the colour space family name Separation.
The remaining elements are parameters that a Separation colour space requires; their meanings are
discussed below.
A colour value in a Separation colour space shall consist of a single tint component in the range 0.0 to
1.0. The value 0.0 shall represent the minimum amount of colourant that can be applied; 1.0 shall
represent the maximum. Tints shall always be treated as subtractive colours, even if the device

#### 0.22: 1.0. The value 0.0 shall represent the minimum amount of colourant that can be applied; 1.0 shall
the lightest colour that can be achieved with the given colourant, and 1.0 is the darkest. The initial
value for both the stroking and nonstroking colour in the graphics state shall be 1.0. The SCN and scn
operators respectively shall set the current stroking and nonstroking colour to a tint value. A sampled
image with single-component samples may also be used as a source of tint values.
NOTE 5      This convention is the same as for DeviceCMYK colour components but opposite to the one for
DeviceGray and DeviceRGB.
The name parameter is a name object that shall specify the name of the colourant that this Separation
colour space is intended to represent (or one of the special names All or None; see below). With the
exception of the names Cyan, Magenta, Yellow and Black which are reserved to name the process
colourants of a CMYK device, such colourant names are arbitrary, and there may be any number of
them, subject to implementation limits.
The special colourant name All shall refer collectively to all colourants available on an output device,
including those for the standard process colourants. When a Separation space with this colourant
name is the current colour space, painting operators shall apply tint values to all available colourants
at once. When outputting to an additive device, such as a computer monitor, the subtractive tint values
of the All colourant shall be complemented by subtracting from 1 before applying to all available
colourants.
NOTE 6      This is useful for purposes such as painting registration targets in the same place on every
separation. Such marks are typically painted as the last step in composing a page to ensure that
they are not overwritten by subsequent painting operations.
The special colourant name None shall not produce any visible output. Painting operations in a
Separation space with this colourant name shall have no effect on the current page.
A PDF processor shall support Separation colour spaces with the colourant names All and None on all
devices, even if the devices are not capable of supporting any others. When processing Separation
spaces with either of these colourant names PDF processors shall ignore the alternateSpace and
tintTransform parameters (discussed below), although valid values shall still be provided.
At the moment the colour space is set to a Separation space, the PDF reader shall determine whether
the device has an available colourant corresponding to the name of the requested space. If so, the PDF
processor shall ignore the alternateSpace and tintTransform parameters; subsequent painting
operations within the space shall apply the designated colourant directly, according to the tint values
supplied.
The preceding paragraph applies only to subtractive output devices such as printers and imagesetters.
For an additive device such as a computer display, a Separation colour space never applies a process
colourant directly; it always reverts to the alternate colour space as described below. This is because
the model of applying process colourants independently does not work as intended on an additive
device.
EXAMPLE 1       In an R, G, B colour space, painting tints of the Red component on a white background (1,1,1) produces a
result that varies from white to cyan (0,1,1) which is not as might be otherwise expected for a red
component.
This exception applies only to colourants for additive devices, not to any specific names, e.g., Red,
Green, and Blue. In contrast, a printer might have a (subtractive) ink named Red, which should work
as a Separation colour space just the same as any other supported colourant.
If the colourant name associated with a Separation colour space does not correspond to a colourant
available on the device, the PDF processor shall arrange for subsequent painting operations to be
performed in an alternate colour space. The intended colours may be approximated by colours in a
device or CIE-based colour space, which shall then be rendered using the usual primary or process
colourants:
•    The alternateSpace parameter shall be an array or name object that identifies the alternate colour
space, which may be any device or CIE-based colour space but may not be another special colour
space (Pattern, Indexed, Separation, or DeviceN).
•    The tintTransform parameter shall be a function (see 7.10, "Functions"). During subsequent
painting operations, a PDF processor calls this function to transform a tint value into colour
component values in the alternate colour space. The function shall be called with the tint value
and shall return the corresponding colour component values. That is, the number of components
and the interpretation of their values shall depend on the alternate colour space.
NOTE 7      In some cases where colourants are unavailable on the output device, painting in the alternate
colour space can produce a good approximation of the intended colour when only opaque
objects are painted. However, it does not necessarily reflect the interactions between an object
and its backdrop when overprinting (see 8.6.7, "Overprint control") is enabled. Separation
simulation (see 10.8.3) can be used as an alternative method to yield better results when
overprinting is involved. When transparency is involved, the use of the alternate space can
produce incorrect output regardless of what method is used.
EXAMPLE 2       The following illustrates the specification of a Separation colour space (object 5) that is intended to produce
a colour named LogoGreen. If the output device has no colourant corresponding to this colour, DeviceCMYK
is used as the alternate colour space, and the tint transformation function (object 12) maps tint values

linearly into shades of a CMYK colour value approximating the LogoGreen colour.
5 0 obj                                           %Colour space
[/Separation
/LogoGreen
/DeviceCMYK
12 0 R
]
endobj
12 0 obj                               %Tint transformation function
<</FunctionType 4
/Domain [0.0 1.0]
/Range [0.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0]
/Length 62
>>
stream
{dup 0.84 mul
exch 0.00 exch dup 0.44 mul exch 0.21 mul
}
endstream
endobj
See 11.7.3, "Spot colours and transparency", for further discussion of the role of Separation colour
spaces in the transparent imaging model.
8.6.6.5           DeviceN colour spaces
DeviceN colour spaces (PDF 1.3) may contain an arbitrary number of colour components.

#### 0.23: 8.6.6.5           DeviceN colour spaces
DeviceCMYK or with individual Separation colour spaces.
EXAMPLE 1         It is possible to create a DeviceN colour space consisting of only the cyan, magenta, and yellow colour
components, with the black component excluded.
NOTE 2      DeviceN colour spaces are used in applications such as these:
High-fidelity colour is the use of more than the standard CMYK process colourants to produce an
extended gamut, or range of colours. A popular example is the PANTONE Hexachrome system,
which uses six colourants: the usual cyan, magenta, yellow, and black, plus orange and green.
Multitone colour systems use a single-component image to specify multiple colour components.
In a duotone, for example, a single-component image can be used to specify both the black
component and a spot colour component. The tone reproduction is generally different for the
different components. For example, the black component can be painted with the exact sample
data from the single-component image; the spot colour component can be generated as a
nonlinear function of the image data in a manner that emphasizes the shadows. "Figure 29 —
Duotone image" shows an example that uses black and magenta colour components. In "Figure
30 — Quadtone image" a single-component grayscale image is used to generate a quadtone
result that uses four colourants: black and three PANTONE spot colours. See Example 4 in this
subclause for the code used to generate this image.
Figure 29 — Duotone image
Figure 30 — Quadtone image
DeviceN shall be used to represent colour spaces containing multiple components that correspond to
colourants of some target device. As with Separation colour spaces, PDF processors shall be able to
approximate the colourants if they are not available on the current output device, such as a display. To
accomplish this, the colour space definition provides a tint transformation function that shall be used
to convert all the components to an alternate colour space.
PDF 1.6 extended the meaning of DeviceN to include colour spaces that are referred to as NChannel
colour spaces. Such colour spaces may contain an arbitrary number of spot and process components,
which may or may not correspond to specific device colourants (the process components shall be from
a single process colour space). They provide information about each component that allows PDF
processors more flexibility in converting colours. These colour spaces shall be identified by a value of
NChannel for the Subtype entry of the attributes dictionary (see "Table 70 — Entries in a DeviceN
colour space attributes dictionary"). A value of DeviceN for the Subtype entry, or no value, shall mean
that only the previous features shall be supported. PDF processors that do not support PDF 1.6 shall

treat these colour spaces as normal DeviceN colour spaces and shall use the tint transformation
function as appropriate. PDF writers using the NChannel features should follow certain guidelines, as
noted throughout this subclause, to achieve good backward compatibility.
NOTE 3      PDF processors can use their own blending algorithms for on-screen viewing and composite
printing, rather than being required to use a specified tint transformation function. See also
clause 10.8, "Rendering for separations".
DeviceN colour spaces shall be defined in a similar way to Separation colour spaces — in fact, a
Separation colour space can be defined as a DeviceN colour space with only one component. A
DeviceN colour space shall be specified as follows:
[/DeviceN names alternateSpace tintTransform]
or
[/DeviceN names alternateSpace tintTransform attributes]
It is a four- or five-element array whose first element shall be the colour space family name DeviceN.
The remaining elements shall be parameters that a DeviceN colour space requires.
The names parameter shall be an array of name objects specifying the individual colour components.
The maximum number of entries in the names array in the computer on which the PDF processor is
running may be subject to implementation limits; see Annex C, "Advice on maximising portability".
The component names shall all be different from one another, except for the name None, which may be
repeated as described later in this subclause. The special name All, used by Separation colour spaces,
shall not be used. The names Cyan, Magenta, Yellow and Black are reserved to name the subtractive
process colourants of a CMYK device.
Colour values shall be tint components in the range 0.0 to 1.0:
•    For DeviceN colour spaces that do not have a subtype of NChannel, 0.0 shall represent the
minimum amount of colourant; 1.0 shall represent the maximum. Tints shall always be treated as
subtractive colours, even if the device produces output for the designated component by an
additive method. Thus, a tint value of 0.0 shall denote the lightest colour that can be achieved with
the given colourant, and 1.0 the darkest.
NOTE 4      This convention is the same one as for DeviceCMYK colour components but opposite to the one
for DeviceGray and DeviceRGB.
•    For NChannel colour spaces, values for additive process colours (such as RGB) shall be specified
in their natural form, where 1.0 shall represent maximum intensity of colour.
When this space is set to the current colour space (using the CS or cs operators), each component shall
be given an initial value of 1.0. The SCN and scn operators respectively shall set the current stroking
and nonstroking colour. Operand values supplied to SCN or scn shall be interpreted as colour
component values in the order in which the colours are given in the names array, as are the values in a
sampled image that uses a DeviceN colour space.
The alternateSpace parameter shall be an array or name object that can be any device or CIE-based
colour space but shall not be another special colour space (Pattern, Indexed, Separation, or
DeviceN). When the colour space is set to a DeviceN space, if any of the component names in the
colour space do not correspond to a colourant available on the device, the PDF processor should
perform subsequent painting operations in the alternate colour space specified by this parameter.
NOTE 5     In some cases PDF processors have more information about colourants and their interaction
than is provided through the alternateSpace parameter, and are free to use such information
instead of the alternateSpace parameter. In addition, where a DeviceN space contains an
attributes dictionary, PDF processors are free to use the information provided in the attributes
dictionary instead of the alternateSpace parameter.
For NChannel colour spaces, the components shall be evaluated individually; that is, only the ones not
present on the output device shall use the alternate colour space of that component.
The tintTransform parameter shall specify a function (see 7.10, "Functions") that is used to transform
the tint values into the alternate colour space. It shall be called with n tint values and returns m colour
component values, where n is the number of components needed to specify a colour in the DeviceN
colour space and m is the number required by the alternate colour space.
NOTE 6     Painting in the alternate colour space can produce a good approximation of the intended colour
when only opaque objects are painted. However, it does not correctly represent the interactions
between an object and its backdrop when the object is painted with transparency or when
overprinting (see 8.6.7, "Overprint control") is enabled.
The colour component name None, which may be present only for DeviceN colour spaces that do not
have the NChannel subtype, indicates that the corresponding colour component shall never be painted
on the page, as in a Separation colour space for the None colourant. When a DeviceN colour space is
painting the named device colourants directly, colour components corresponding to None colourants
shall be discarded. However, when the DeviceN colour space reverts to its alternate colour space,
those components shall be passed to the tint transformation function, which may use them as desired.
A DeviceN colour space whose component colourant names are all None shall always discard its
output, just the same as a Separation colour space for None; it shall never revert to the alternate
colour space. Reversion shall occur only if at least one colour component (other than None) is specified
and is not available on the device.
The optional attributes parameter shall be a dictionary (see "Table 70 — Entries in a DeviceN colour
space attributes dictionary") containing additional information about the components of this colour
space that PDF processors may use. PDF processors need not use the alternateSpace and tintTransform
parameters, and may instead use custom blending algorithms, along with other information provided
in the attributes dictionary if present. (If the value of the Subtype entry in the attributes dictionary is
NChannel, such information shall be present.) However, alternateSpace and tintTransform shall always
be provided for PDF processors that want to use them or do not support PDF 1.6.
Table 70 — Entries in a DeviceN colour space attributes dictionary
Key           Type        Value
Subtype       name        (Optional; PDF 1.6) A name specifying the preferred treatment for the colour space.
Values shall be DeviceN or NChannel. Default value: DeviceN.

Key             Type          Value
Colorants       dictionary    (Required if Subtype is NChannel and the colour space includes spot colourants;
otherwise optional; PDF 1.6) A dictionary describing the individual colourants used
in the DeviceN colour space. For each entry in this dictionary, the key shall be a
colourant name and the value shall be an array defining a Separation colour space
for that colourant (see 8.6.6.4, "Separation colour spaces"). The key shall match the
colourant name given in that colour space.
This dictionary provides information about the individual colourants that may be
useful to some PDF processors. In particular, the alternate colour space and tint
transformation function of a Separation colour space describe the appearance of
that colourant alone, whereas those of a DeviceN colour space describe only the
appearance of its colourants in combination.
Process         dictionary    (Required if Subtype is NChannel and the colour space includes components of a
process colour space, otherwise optional; PDF 1.6) A dictionary (see "Table 71 —
Entries in a DeviceN process dictionary") that describes the process colour space
whose components are included in this colour space.
MixingHints dictionary        (Optional; PDF 1.6) A dictionary (see "Table 72 — Entries in a DeviceN mixing hints
dictionary") that specifies optional attributes of the inks that shall be used in
blending calculations when used as an alternative to the tint transformation
function.
This dictionary provides information about the individual colourants that may be useful to some PDF
processors. In particular, the alternate colour space and tint transformation function of a Separation
colour space describe the appearance of that colourant alone, whereas those of a DeviceN colour space
describe only the appearance of its colourants in combination.
If Subtype is NChannel, the Colorants dictionary shall have entries for all spot colourants in this
colour space. The Colorants dictionary may also include additional colourants not used by this colour
space.
A value of NChannel for the Subtype entry indicates that some of the other entries in the Colorants
dictionary are required rather than optional. The Colorants entry specifies a Colorants dictionary that
contains entries for all the spot colourants in the colour space; they shall be defined using individual
Separation colour spaces. The Process entry specifies a process dictionary (see "Table 71 — Entries
in a DeviceN process dictionary") that identifies the process colour space that is used by this colour
space and the names of its components. It shall be present if Subtype is NChannel and the colour
space has process colour components. An NChannel colour space shall contain components from at
most one process colour space.
For colour spaces that have a value of NChannel for the Subtype entry in the attributes dictionary the
following restrictions apply to process colours:
•    There may be colour components from at most one process colour space, which may be any
device or CIE-based colour space.
•    For a non-CMYK colour space, the names of the process components shall appear sequentially in
the names array, in the normal colour space order (for example, Red, Green, and Blue). However,
the names in the names array need not match the actual colour space names (for example, a Red
component need not be named Red). The mapping of names is specified in the process dictionary
(see "Table 71 — Entries in a DeviceN process dictionary" and discussion below), which shall be
present.
•    Definitions for process colourants should not appear in the Colorants dictionary. Any such
definition shall be ignored if the colourant is also present in the process dictionary. Any
component not specified in the process dictionary shall be considered to be a spot colourant.
•    For a CMYK colour space, a subset of the components may be present, and they may appear in any
order in the names array. The reserved names Cyan, Magenta, Yellow, and Black shall always be
considered to be process colours, which do not necessarily correspond to the colourants of a
specific device; they need not have entries in the process dictionary.
•    The values associated with the process components shall be stored in their natural form (that is,
subtractive colour values for CMYK and additive colour values for RGB), since they shall be
interpreted directly as process values by consumers making use of the process dictionary. (For
additive colour spaces, this is the reverse of how colour values are specified for DeviceN, as
described above in the discussion of the names parameter.)
The MixingHints entry in the attributes dictionary specifies a mixing hints dictionary (see "Table 72 —
Entries in a DeviceN mixing hints dictionary") that provides information about the characteristics of
colourants that may be used in blending calculations when the actual colourants are not available on
the target device. PDF processors need not use this information.
Table 71 — Entries in a DeviceN process dictionary
Key            Type         Value
ColorSpace     name or      (Required) A name or array identifying the process colour space,
array        which may be any device or CIE-based colour space except Lab. If an
ICCBased colour space is specified, it shall provide calibration
information appropriate for the process colour components specified
in the names array of the DeviceN colour space.
Components     array        (Required) An array of component names that correspond, in order, to
the components of the process colour space specified in ColorSpace.
For example, an RGB colour space shall have three names
corresponding to red, green, and blue. The names may be arbitrary
(that is, not the same as the standard names for the colour space
components) and shall match those specified in the names array of the
DeviceN colour space, even if all components are not present in the
names array.

Table 72 — Entries in a DeviceN mixing hints dictionary
Key               Type       Value
Solidities        dictionary (Optional) A dictionary specifying the solidity of inks that shall be used in blending
calculations when used as an alternative to the tint transformation function. For
each entry, the key shall be a colourant name, and the value shall be a number
between 0.0 and 1.0. This dictionary need not contain entries for all colourants
used in this colour space; it may also include additional colourants not used by this
colour space.
A value of 1.0 simulates an ink that completely covers the inks beneath; a value of
0.0 simulates a transparent ink that completely reveals the inks beneath. An entry
with a key of Default specifies a value that shall be used by all components in the
associated DeviceN colour space for which a solidity value is not explicitly
provided. If Default is not present, the default value for unspecified colourants
shall be 0.0; interactive PDF processors may choose to use other values.
If this entry is present, PrintingOrder shall also be present.
PrintingOrder array          (Required if Solidities is present) An array of colourant names, specifying the order
in which inks shall be laid down. Each component in the names array of the
DeviceN colour space shall appear in this array (although the order is unrelated to
the order specified in the names array). This entry may also list colourants unused
by this specific DeviceN instance.
NOTE    (2020) PrintingOrder precisely matches the optional ICC profile
colorantOrderTag (ISO 15076-1, 9.2.17), which specifies physical colourant
laydown relative to the substrate. It does not define viewing direction.
DotGain           dictionary (Optional) A dictionary specifying the dot gain of inks that shall be used in blending
calculations when used as an alternative to the tint transformation function. Dot
gain (or loss) represents the amount by which a printer’s halftone dots change as
the ink spreads and is absorbed by paper.
For each entry, the key shall be a colourant name, and the value shall be a function
that maps values in the range 0 to 1 to values in the range 0 to 1. The dictionary
may list colourants unused by this specific DeviceN instance and need not list all
colourants. An entry with a key of Default shall specify a function that shall be used
by all colourants for which a dot gain function is not explicitly specified.
PDF processors may ignore values in this dictionary when other sources of dot gain
information are available, such as ICC profiles associated with the process colour
space or tint transformation functions associated with individual colourants.
Each entry in the mixing hints dictionary refers to colourant names, which include spot colourants
referenced by the Colorants dictionary. Under some circumstances, they may also refer to one or more
individual process components called Cyan, Magenta, Yellow, or Black when DeviceCMYK is
specified as the process colour space in the process dictionary. However, applications shall ignore
these process component entries if they can obtain the information from an ICC profile.
NOTE 7       The mixing hints subdictionaries (as well as the Colorants dictionary) can specify colourants
that are not used in any given instance of a DeviceN colour space. This allows them to be
referenced from multiple DeviceN colour spaces, which can produce smaller file sizes as well as
consistent colour definitions across instances.
For consistency of colour, the following guidelines apply:
•   The PDF processor should apply either the specified tint transformation function or invoke the
same alternative blending algorithm for all DeviceN instances in the document.
NOTE 8      When the tint transformation function is used, the burden is on the PDF writer to guarantee that
the individual function definitions chosen for all DeviceN instances produce similar colour
appearances throughout the document.
•    Blending algorithms should produce a similar appearance for colours when they are used as
separation colours or as a component of a DeviceN colour space.
EXAMPLE 2       This example shows a DeviceN colour space consisting of three colour components named Orange, Green,
and None. In this example, the DeviceN colour space, object 30, has an attributes dictionary whose
Colorants entry is an indirect reference to object 45 (which might also be referenced by attributes
dictionaries of other DeviceN colour spaces). tintTransform1, whose definition is not shown, maps three
colour components (tints of the colourants Orange, Green, and None) to four colour components in the
alternate colour space, DeviceCMYK. tintTransform2 maps a single colour component (an orange tint) to
four components in DeviceCMYK. Likewise, tintTransform3 maps a green tint to DeviceCMYK, and
tintTransform4 maps a tint of PANTONE 131 to DeviceCMYK.
30 0 obj                                                         %Colour space
[/DeviceN
[/Orange /Green /None]
/DeviceCMYK
tintTransform1
<</Colorants 45 0 R>>
]
endobj
45 0 obj                                                         %Colorants dictionary
<</Orange [/Separation
/Orange
/DeviceCMYK
tintTransform2
]
/Green [/Separation
/Green
/DeviceCMYK
tintTransform3
]
/PANTONE#20131 [/Separation
/PANTONE#20131
/DeviceCMYK
tintTransform4
]
>>
endobj
NOTE 9      Example 3, Example 4 and Example 5 show the use of NChannel colour spaces.
EXAMPLE 3       This example shows the use of calibrated CMYK process components.
10 0 obj                                              %Colour space
[/DeviceN
[/Magenta /Spot1 /Yellow /Spot2]
alternateSpace
tintTransform1
<<                                        %Attributes dictionary
/Subtype /NChannel
/Process
<</ColorSpace [/ICCBased CMYK_ICC profile]
/Components [/Cyan /Magenta /Yellow /Black]
>>
/Colorants
<</Spot1 [/Separation /Spot1 alternateSpace tintTransform2]
/Spot2 [/Separation /Spot2 alternateSpace tintTransform3]
>>
>>
]
endobj

EXAMPLE 4         This example shows the recommended convention for dealing with situations where a spot colourant and a
process colour component have the same name. Since the names array cannot have duplicate names, the
process colours will need to be given different names, which are mapped to process components in the
Components entry of the process dictionary. In this case, Red refers to a spot colourant; ProcessRed,
ProcessGreen, and ProcessBlue are mapped to the components of an RGB colour space.
10 0 obj                                               %Colour space
[/DeviceN
[/ProcessRed /ProcessGreen /ProcessBlue /Red]
alternateSpace
tintTransform1
<<                                            %Attributes dictionary
/Subtype /NChannel
/Process
<</ColorSpace [/ICCBased RGB_ICC profile]
/Components [/ProcessRed /ProcessGreen /ProcessBlue]
>>
/Colorants
<</Red [/Separation /Red alternateSpace tintTransform2]>>
>>
]
endobj
EXAMPLE 5         This example shows the use of a mixing hints dictionary.
10 0 obj                                              %Colour space
[/DeviceN
[/Magenta /Spot1 /Yellow /Spot2]
alternateSpace
tintTransform1
<<
/Subtype /NChannel
/Process
<</ColorSpace [/ICCBased CMYK_ICC profile]
/Components [/Cyan /Magenta /Yellow /Black]
>>
/Colorants
<</Spot1 [/Separation /Spot1 alternateSpace tintTransform2]
/Spot2 [/Separation /Spot2 alternateSpace tintTransform2]
>>
/MixingHints
<<
/Solidities
<</Spot1 1.0
/Spot2 0.0
>>
/DotGain
<</Spot1 function1
/Spot2 function2
/Magenta function3
/Yellow function4
>>
/PrintingOrder [/Magenta /Yellow /Spot1 /Spot2]
>>
>>
]
endobj
See 11.7.3, "Spot colours and transparency", for further discussion of the role of DeviceN colour spaces
in the transparent imaging model.
8.6.6.6          Multitone examples
NOTE 1      The following examples illustrate various interesting and useful special cases of the use of

#### 0.24: 8.6.7 Overprint control
separations, but it is available on some composite devices as well. Although the operation of this
parameter is device-dependent, it is described here rather than in the subclause on colour rendering,
because it pertains to an aspect of painting in device colour spaces that is important to many
applications.
Any painting operation marks some specific set of device colourants, depending on the colour space in
which the painting takes place. In a Separation or DeviceN colour space, the colourants to be marked
shall be specified explicitly; in a device or CIE-based colour space, they shall be implied by the process
colour model of the output device (see clause 10, "Rendering"). The overprint parameter is a boolean
flag that determines how painting operations affect colourants other than those explicitly or implicitly
specified by the current colour space.
If the overprint parameter is false (the default value), painting a colour in any colour space shall cause
the corresponding areas of unspecified colourants to be erased (painted with a tint value of 0.0). The
effect is that the colour at any position on the page is whatever was painted there last, which is
consistent with the normal painting behaviour of the opaque imaging model.
If the overprint parameter is true and the output device supports overprinting, erasing actions shall
not be performed; anything previously painted in other colourants is left undisturbed. Consequently,
the colour at a given position on the page may be a combined result of several painting operations in
different colourants. The effect produced by such overprinting is device-dependent and is not defined
here.
NOTE 1      Not all devices support overprinting. Furthermore, many PostScript language compatible
printers support it only when separations are being produced, and not for composite output.
If overprinting is not supported, the value of the overprint parameter shall be ignored.
An additional graphics state parameter, the overprint mode (PDF 1.3), shall affect the interpretation of a
tint value of 0.0 for a colour component in a DeviceCMYK colour space when overprinting is enabled.
This parameter is controlled by the OPM entry in a graphics state parameter dictionary; it shall have
an effect only when the overprint parameter is true, as described above. Determination of whether a
tint value is zero or non-zero shall be made on the tint value defined within the PDF file, before
quantisation into a device tint value for the output device.
When colours are specified in a DeviceCMYK colour space and the native colour space of the output
device is also DeviceCMYK, each of the source colour components controls the corresponding device
colourant directly. Ordinarily, each source colour component value replaces the value previously
painted for the corresponding device colourant, no matter what the new value is; this is the default
behaviour, specified by overprint mode 0.
When the overprint mode is 1 (also called non-zero overprint mode), a tint value of 0.0 for a source
colour component shall leave the corresponding component of the previously painted colour
unchanged. The effect is equivalent to painting in a DeviceN colour space that includes only those
components whose values are non-zero.
EXAMPLE          If the overprint parameter is true and the overprint mode is 1, the operation
0.2 0.3 0.0 1.0 k
is equivalent to
0.2 0.3 1.0 scn
in the colour space shown in this example.
10 0 obj                                           %Colour space
[/DeviceN
[/Cyan /Magenta /Black]
/DeviceCMYK
15 0 R
]
endobj
15 0 obj                                        %Tint transformation function
<</FunctionType 4
/Domain [0.0    1.0   0.0 1.0     0.0     1.0]
/Range [0.0 1.0    0.0 1.0 0.0 1.0 0.0    1.0]
/Length 13
>>
stream
{ 0      exch }
endstream
endobj
Non-zero overprint mode shall apply only to painting operations that use the current colour in the
graphics state when the current colour space is DeviceCMYK (or is implicitly converted to
DeviceCMYK; see (8.6.5.7, "Implicit conversion of CIE-Based colour spaces"). It shall not, however,
apply to the painting of images or shadings (8.7.4, "Shading patterns"). It also shall not apply if the
native colour space of the output device does not include CMYK device colourants; in that case, source
colours shall be converted to the device’s native colour space, and all components participate in the
conversion, whatever their values.
NOTE 2    This is shown explicitly in the alternate colour space and tint transformation function of the
DeviceN colour space (see Example 3 in 8.6.6.5, "DeviceN colour spaces").
See 11.7.4, "Overprinting and transparency", for further discussion of the role of overprinting in the
transparent imaging model.
8.6.8 Colour operators
"Table 73 — Colour operators" lists the PDF operators that control colour spaces and colour values.

#### 0.25: 8.6.8 Colour operators
and discussed under 8.6.5.8, "Rendering intents". Colour operators may appear at the page description
level or inside text objects (see "Figure 9 — Graphics objects").

Table 73 — Colour operators
Operands         Operator Description
name             CS             (PDF 1.1) Set the current colour space to use for stroking operations. The
operand name shall be a name object. If the colour space is one that can be
specified by a name and no additional parameters (DeviceGray, DeviceRGB,
DeviceCMYK, and certain cases of Pattern), the name may be specified
directly. Otherwise, it shall be a name defined in the ColorSpace subdictionary
of the current resource dictionary (see 7.8.3, "Resource dictionaries"); the
associated value shall be an array describing the colour space (see 8.6.3,
"Colour space families").
The names DeviceGray, DeviceRGB, DeviceCMYK, and Pattern always identify
the corresponding colour spaces directly; they never refer to resources in the
ColorSpace subdictionary.
The CS operator shall also set the current stroking colour to its initial value,
which depends on the colour space:
In a DeviceGray, DeviceRGB, CalGray, or CalRGB colour space, the initial
colour shall have all components equal to 0.0.
In a DeviceCMYK colour space, the initial colour shall be [0.0 0.0 0.0 1.0].
In a Lab or ICCBased colour space, the initial colour shall have all components
equal to 0.0 unless that falls outside the intervals specified by the space’s
Range entry, in which case the nearest valid value shall be substituted.
In an Indexed colour space, the initial colour value shall be 0.
In a Separation or DeviceN colour space, the initial tint value shall be 1.0 for
all colourants.
In a Pattern colour space, the initial colour shall be a pattern object that causes
nothing to be painted.
name             cs             (PDF 1.1) Same as CS but used for nonstroking operations.
c1 … c n         SC             (PDF 1.1) Set the colour to use for stroking operations in a device, CIE-based
(other than ICCBased), or Indexed colour space. The number of operands
required and their interpretation depends on the current stroking colour space:
For DeviceGray, CalGray, and Indexed colour spaces, one operand shall be
required (n = 1).
For DeviceRGB, CalRGB, and Lab colour spaces, three operands shall be
required (n = 3).
For DeviceCMYK, four operands shall be required (n = 4).
c1 … c n         SCN            (PDF 1.2) Same as SC but also supports Pattern, Separation, DeviceN and
c1… cn name      SCN            ICCBased colour spaces.
If the current stroking colour space is a Separation, DeviceN, or ICCBased
colour space, the operands c1… cn shall be numbers. The number of operands
and their interpretation depends on the colour space.
If the current stroking colour space is a Pattern colour space, name shall be the
name of an entry in the Pattern subdictionary of the current resource
dictionary (see 7.8.3, "Resource dictionaries"). For an uncoloured tiling pattern
(PatternType = 1 and PaintType = 2), c1… cn shall be component values
specifying a colour in the pattern’s underlying colour space. For other types of
patterns, these operands shall not be specified.
c1 … c n         sc             (PDF 1.1) Same as SC but used for nonstroking operations.
Operands      Operator Description
c1 … c n      scn         (PDF 1.2) Same as SCN but used for nonstroking operations.
c1… cn name   scn
gray          G           Set the stroking colour space to DeviceGray (or the DefaultGray colour space;
see 8.6.5.6, "Default colour spaces") and set the gray level to use for stroking
operations. gray shall be a number between 0.0 (black) and 1.0 (white).
gray          g           Same as G but used for nonstroking operations.
rgb           RG          Set the stroking colour space to DeviceRGB (or the DefaultRGB colour space;
see 8.6.5.6, "Default colour spaces") and set the colour to use for stroking
operations. Each operand shall be a number between 0.0 (minimum intensity)
and 1.0 (maximum intensity).
rgb           rg          Same as RG but used for nonstroking operations.
cmyk          K           Set the stroking colour space to DeviceCMYK (or the DefaultCMYK colour
space; see 8.6.5.6, "Default colour spaces") and set the colour to use for stroking
operations. Each operand shall be a number between 0.0 (zero concentration)
and 1.0 (maximum concentration). The behaviour of this operator is affected by
the overprint mode (see 8.6.7, "Overprint control").
cmyk          k           Same as K but used for nonstroking operations.
Invoking operators that specify colours or other colour-related parameters in the graphics state is
restricted in certain circumstances. This restriction occurs when defining graphical figures whose
colours shall be specified separately each time they are used. Specifically, the restriction applies in
these circumstances:
•    In any glyph description that uses the d1 operator (see 9.6.4, "Type 3 fonts") and to all other
content streams invoked from within the same glyph description.
•    In the content stream of an uncoloured tiling pattern (see 8.7.3.3, "Uncoloured tiling patterns")
and to all other content streams invoked from within the uncoloured tiling pattern stream.
In these circumstances:
•    All of the following operators shall be ignored:
CS                  scn                 K
cs                  G                   k
SC                  g                   ri
SCN                 RG                  sh
sc                  rg
•    All of the following entries, if present in the graphics state parameter dictionary of a gs operator
shall be ignored:

