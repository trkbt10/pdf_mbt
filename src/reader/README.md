# reader

## API

- **`PdfFDFDictionary`** (Struct) — FDF dictionary from ISO 32000-2 12.7.8.1 and 12.7.8.3.1 Table 246. It
- **`PdfFormFieldType`** (Enum) — ISO source: spec/extracted/12.7-12.11-forms-signatures.spec.txt.
- **`PdfFormField`** (Struct) — Interactive form field dictionary model for 12.7.1 through 12.7.5. A
- **`PdfDocument`** (Struct) — Public facade for ISO 32000-2 document-structure access backed by
- **`PdfAction`** (Struct) — ISO source: spec/extracted/12.6-actions.spec.txt.
- **`PdfSignatureDictionary`** (Struct) — Signature dictionary from ISO 32000-2 12.8.1 Table 255. It covers Sig and
- **`PdfAcroForm`** (Struct) — Interactive form dictionary (AcroForm) from ISO 32000-2 12.7.1 through
- **`PdfAnnotationSubtype`** (Enum) — Standard annotation types from ISO 32000-2 12.5.6.1 "General" and
- **`PdfSignatureValidationPlan`** (Struct) — Signature validation plan for 12.8.2 DocMDP and FieldMDP comparisons,
- **`PdfAnnotation`** (Struct) — Typed page annotation record for ISO 32000-2 12.5 "Annotations".
- **`PdfFormActionRaw`** (Struct) — Raw structural boundary for ISO 32000-2 12.7.6 and Tables 201, 239,
- **`PdfAnnotationCommon`** (Struct) — Entries common to all annotation dictionaries from ISO 32000-2 12.5.2
- **`PdfVariableTextDescriptor`** (Struct) — Variable text descriptor for ISO 32000-2 12.7.4.3 and Table 228. It keeps
- **`PdfAnnotationSpecific`** (Enum) — Subtype-specific annotation payloads for ISO 32000-2 12.5.6 annotation
- **`PdfFDFField`** (Struct) — FDF field dictionary from ISO 32000-2 12.7.8.3.2 and Table 249. It keeps
- **`PdfActionKind`** (Enum) — Standard action types from ISO 32000-2 12.6.4.1 Table 201: GoTo, GoToR,
- **`PdfCatalog`** (Struct) — Validated Catalog dictionary resolved from the trailer Root reference. The
- **`PdfLegalAttestation`** (Struct) — Legal attestation dictionary from 12.8.7 Table 264 and catalog Table 29.
- **`PdfActionSource`** (Enum) — Reader-layer provenance for an ISO 32000-2 12.6 Actions parse.
- **`PdfSignatureSubFilter`** (Enum) — Signature SubFilter names from 12.8.3.1 through 12.8.3.4. PKCS #1
- **`PdfDocumentSecurityStore`** (Struct) — Reader model for the document security store (DSS) from 12.8.4.1 through
- **`PdfSignatureField`** (Struct) — Signature field model from ISO 32000-2 12.7.5.5 Table 235. It ties a Sig
- **`PdfFDFDocument`** (Struct) — FDF document model for ISO 32000-2 12.7.8.2.1 through 12.7.8.2.4 and
- **`PdfAnnotationBorder`** (Struct) — Annotation border model for ISO 32000-2 12.5.4 "Border styles". It
- **`PdfFormWidgetRef`** (Struct) — Widget annotation association for interactive forms from 12.7.2,
- **`PdfSignatureReference`** (Struct) — Signature reference dictionary from Table 256 and transform method clauses
- **`PdfFreeTextAnnotation`** (Struct) — Free text annotation data from ISO 32000-2 12.5.6.6 and Table 177.
- **`annotations`** (Function) — Parses the page Annots array from ISO 32000-2 12.5.1 and 12.5.2 into
- **`PdfMarkupAnnotation`** (Struct) — Markup annotation common entries from ISO 32000-2 12.5.6.2 and
- **`PdfValidationRelatedInformation`** (Struct) — Validation-related information (VRI) dictionary from 12.8.4.4 Table 262
- **`PdfCatalogRequirement`** (Struct) — Catalog Requirements entry model from ISO 32000-2 12.11.1 Tables 273 and
- **`media_player_may_be_used`** (Function) — 13.2.7.2.2 Algorithm: Media Player. Applies content type, NU, MU, and A
- **`PdfRemoteGoToAction`** (Struct) — 12.6.4.3 Remote Go-To actions, Table 203. Represents S /GoToR with
- **`PdfRendition`** (Enum) — 13.2.3 rendition object: media rendition MR, selector rendition SR, or an
- **`PdfMediaPlayerInfo`** (Struct) — 13.2.7.3 Table 302 media player info dictionary with 4 entries. PID
- **`PdfNumberFormatDescriptor`** (Struct) — Number format dictionary from 12.9.1 Table 268 and the 12.9.2 algorithm
- **`PdfRichMediaExecuteAction`** (Struct) — 12.6.4.18 Rich-Media-Execute actions, Table 222. Represents PDF 2.0
- **`PdfMediaClip`** (Struct) — 13.2.4 media clip dictionary. It covers 13.2.4.1 common entries, 13.2.4.2
- **`PdfWidgetAnnotation`** (Struct) — Widget annotation data from ISO 32000-2 12.5.6.19 and Table 191. It keeps
- **`PdfAnnotationAppearance`** (Struct) — Appearance dictionary descriptor for ISO 32000-2 12.5.5 "Appearance
- **`find_latest_startxref`** (Function) — Finds the latest cross-reference byte offset by reverse parsing the file
- **`content_stream`** (Function) — Resolves absent, single-stream, and array-of-stream page Contents, decodes
- **`PdfPermissionsDictionary`** (Struct) — Permissions dictionary from 12.8.6 Table 263 and catalog Table 29. DocMDP
- **`extensions`** (Function) — Returns typed Catalog Extensions metadata when the Catalog has a direct
- **`PdfAnnotationTabOrder`** (Enum) — Page Tabs annotation navigation order from ISO 32000-2 12.5.1
- **`graphics_initial_state`** (Function) — Builds the initial graphics state inputs for a page. CropBox seeds the
- **`PdfUriAction`** (Struct) — 12.6.4.8 URI actions, Table 210 and Table 211. Represents S /URI with the
- **`PdfViewport`** (Struct) — Viewport dictionary from ISO 32000-2 12.9.1 Table 265. A viewport is a
- **`GraphicsPageOptions`** (Struct) — Page graphics interpretation options. The caller may supply the initial
- **`PdfRichMediaSettings`** (Struct) — 13.7.2.2.1 Table 334 RichMediaSettings dictionary. Activation and
- **`PdfFDFObjectRecord`** (Struct) — FDF body object record from ISO 32000-2 12.7.8.2.3. FDF bodies contain
- **`PdfRenditionAction`** (Struct) — 12.6.4.14 Rendition actions, Table 218. Represents S /Rendition with R
- **`PdfPointData`** (Struct) — Point data dictionary from ISO 32000-2 12.10.5 Table 272. PtData subtype
- **`PdfActionTriggerOrdering`** (Struct) — Structural ordering notes from 12.6.3 Trigger events. The arrays record
- **`annotation_tab_order`** (Function) — Parses the page Tabs entry described by ISO 32000-2 12.5.1 "General".
- **`PdfExtensionPrefixEntry`** (Struct) — One exact developer-prefix entry in a Catalog Extensions dictionary.
- **`PdfExtensions`** (Struct) — Typed Catalog Extensions aggregate from ISO 32000-2 clause 7.12. It
- **`PdfGeospatialMeasure`** (Struct) — Geospatial measure dictionary from 12.10.1 and 12.10.2 Table 269. It keeps
- **`PdfLineAnnotation`** (Struct) — Line annotation data from ISO 32000-2 12.5.6.7 and Table 178. It includes
- **`PdfWidgetAppearanceCharacteristics`** (Struct) — Appearance characteristics dictionary from ISO 32000-2 Table 192. Widget
- **`PdfMediaCriteria`** (Struct) — 13.2.3.1 Table 279 media criteria dictionary. Entries capture accessibility
- **`PdfLinkAnnotation`** (Struct) — Link annotation data from ISO 32000-2 12.5.6.5 and Table 176. Actions,
- **`PdfGoTo3DViewAction`** (Struct) — 12.6.4.16 Go-To-3D-View actions, Table 220. Represents S /GoTo3DView with
- **`PdfLaunchAction`** (Struct) — 12.6.4.6 Launch actions, Table 207. Represents S /Launch with F file
- **`PdfThreadAction`** (Struct) — 12.6.4.7 Thread actions, Table 209. Represents S /Thread with optional F
- **`PdfScreenAnnotation`** (Struct) — Screen annotation data from ISO 32000-2 12.5.6.18 and Table 190. T title,
- **`PdfRedactionAnnotation`** (Struct) — Redaction annotation data from ISO 32000-2 12.5.6.23 and Table 195.
- **`PdfPage`** (Struct) — Public Page object handle. It exposes page entries such as MediaBox,
- **`PdfPolygonAnnotation`** (Struct) — Polygon and polyline annotation data from ISO 32000-2 12.5.6.9 and
- **`PdfThreeDMeasurement`** (Struct) — 13.6.7.3 Tables 326 through 331 3D measurement/markup dictionary. It
- **`PdfRequirementHandler`** (Struct) — Requirement handler dictionary from ISO 32000-2 12.11.1 Table 273 and
- **`PdfMarkupExternalData`** (Struct) — External data dictionary carried by markup and projection annotations.
- **`PdfEmbeddedGoToAction`** (Struct) — 12.6.4.4 Embedded Go-To actions, Table 204. Represents S /GoToE for a
- **`PdfThreeDView`** (Struct) — 13.6.4.1 Table 315 3D view dictionary. It records external/internal names,
- **`PdfNamedAction`** (Struct) — 12.6.4.12 Named actions, Table 215 and Table 216. Represents S /Named and
- **`PdfMeasure`** (Struct) — Measure dictionary from ISO 32000-2 12.9.1 Table 266. Rectilinear
- **`PdfMovieAction`** (Struct) — 12.6.4.10 Movie actions, Table 213. Represents deprecated PDF 2.0
- **`media_box`** (Function) — Returns the inheritable MediaBox entry as a four-number page boundary from
- **`PdfTextAnnotation`** (Struct) — Text annotation data from ISO 32000-2 12.5.6.4 and Table 175. Text
- **`PdfThreeDProjection`** (Enum) — 13.6.4.2 projection dictionary, Table 316, plus adjacent Table 317 3D
- **`PdfSoundAction`** (Struct) — 12.6.4.9 Sound actions, Table 212. Represents deprecated PDF 2.0 S /Sound
- **`PdfTargetDictionary`** (Struct) — Target dictionary from 12.6.4.4 Table 205 for Embedded Go-To actions.
- **`PdfFDFFileSpecification`** (Struct) — FDF file specification wrapper from 12.7.8.3.1 Table 246. F and ID identify
- **`crop_box`** (Function) — Returns the inheritable CropBox entry as a four-number page boundary from
- **`PdfAnnotationFlags`** (Struct) — Annotation flags from ISO 32000-2 12.5.3 and Table 167. The F entry
- **`PdfJavaScriptAction`** (Struct) — 12.6.4.17 ECMAScript actions, Table 221. The PDF keyword remains
- **`PdfRawAnnotation`** (Struct) — Raw annotation hand-off for extensible or adjacent-clause subtypes,
- **`PdfSoundObject`** (Struct) — 13.3 Sound object, Table 305. Deprecated in PDF 2.0 and superseded by
- **`PdfMovieDictionary`** (Struct) — 13.4 movie dictionary, Table 306. Deprecated in PDF 2.0; it stores F file
- **`PdfSlideShow`** (Struct) — 13.5 Table 308 slideshow dictionary: Type SlideShow, Subtype Embedded,
- **`PdfHideAction`** (Struct) — 12.6.4.11 Hide actions, Table 214. Represents S /Hide with required T
- **`PdfFormFieldValue`** (Enum) — Field values from Table 226 V and DV, including name states for check
- **`PdfRichMediaActivation`** (Struct) — 13.7.2.2.2 Table 335 RichMediaActivation dictionary. It records activation
- **`PdfThreeDUnits`** (Struct) — 13.6.7.2 Table 325 3D units dictionary. Creation time, user override, and
- **`PdfGoToAction`** (Struct) — 12.6.4.2 Go-To actions, Table 202. Represents S /GoTo with required D
- **`PdfQuadPoints`** (Struct) — QuadPoints group from link, text markup, and redaction annotations.
- **`PdfWindowsLaunchParams`** (Struct) — Microsoft Windows launch parameter dictionary from 12.6.4.6 Table 208.
- **`PdfMonitorSpecifier`** (Enum) — 13.2.7.5 Table 304 monitor specifier values: document largest/smallest
- **`PdfMediaScreenParams`** (Struct) — 13.2.6.1 media screen parameters dictionary, Tables 293, 294, and 295.
- **`PdfActionTrigger`** (Enum) — Standard trigger event labels from 12.6.3 for Catalog OpenAction,
- **`PdfCatalogOpenAction`** (Enum) — Catalog OpenAction from 12.6.1 General and 7.7.2. It may be an existing
- **`PdfCatalogUri`** (Struct) — Catalog URI dictionary from 12.6.4.8 Table 211. Base is the optional base
- **`PdfSoftwareIdentifier`** (Struct) — 13.2.7.4.1 Table 303 software identifier dictionary. It preserves U URI
- **`PdfSoundAnnotation`** (Struct) — Sound annotation data from ISO 32000-2 12.5.6.16 and Table 188. The
- **`PdfRichMediaAnnotation`** (Struct) — 13.7.2.1 Table 333 RichMedia annotation. It connects required
- **`PdfTransitionAction`** (Struct) — 12.6.4.15 Transition actions, Table 219. Represents S /Trans and required
- **`content_resources`** (Function) — Returns the page content resource dictionary context by using the existing
- **`PdfCoordinateSystem`** (Struct) — Geographic or projected coordinate system dictionary from ISO 32000-2
- **`PdfFormFieldFlags`** (Struct) — Field dictionary Ff bitset from ISO 32000-2 Tables 227, 229, 231, and
- **`PdfTextMarkupAnnotation`** (Struct) — Text markup annotation data from ISO 32000-2 12.5.6.10 and Table 182.
- **`PdfGoToDPartAction`** (Struct) — 12.6.4.5 GoToDp action, Table 206. Represents S /GoToDp from PDF 2.0:
- **`PdfRichMediaPresentation`** (Struct) — 13.7.2.2.5 Table 338 RichMediaPresentation dictionary. It records Embedded
- **`PdfProjectionAnnotation`** (Struct) — Projection annotation data from ISO 32000-2 12.5.6.24. Projection is a
- **`PdfSetOCGStateAction`** (Struct) — 12.6.4.13 Set-OCG-state actions, Table 217. Represents S /SetOCGState with
- **`PdfDeveloperExtension`** (Struct) — One developer extension dictionary under a prefix. Optional URL and
- **`PdfRichMediaViewParams`** (Struct) — 13.7.2.3.6.1 Table 345 View Params dictionary. Instance links to a
- **`PdfNameTreeEntry`** (Struct) — Ordered entry returned by Catalog name-tree enumeration. Keys are preserved
- **`PdfMediaOffset`** (Enum) — 13.2.6.2 media offset dictionary, Tables 296, 297, 298, and 299. Time
- **`PdfShapeAnnotation`** (Struct) — Square and circle annotation data from ISO 32000-2 12.5.6.8 and
- **`PdfFileAttachmentAnnotation`** (Struct) — File attachment annotation data from ISO 32000-2 12.5.6.15 and
- **`PdfTrapNetworkAnnotation`** (Struct) — Trap network annotation data from ISO 32000-2 12.5.6.21. TrapNet is
- **`PdfNumberTreeEntry`** (Struct) — Entry returned by number-tree traversal. Number trees are used by
- **`PdfAnnotationAdditionalActions`** (Struct) — Annotation additional-actions dictionary from 12.6.3 Table 197. It models
- **`graphics_program`** (Function) — Parses this page's content stream and interprets graphics operators into a
- **`PdfCatalogAdditionalActions`** (Struct) — Document Catalog additional-actions dictionary from 12.6.3 Table 200. It
- **`PdfViewerPreferences`** (Struct) — Typed ViewerPreferences dictionary with ISO defaults for absent booleans
- **`PdfAppearanceEntry`** (Enum) — Appearance stream entry from ISO 32000-2 Table 170. An AP N, R, or D entry
- **`PdfFDFCatalog`** (Struct) — FDF catalog dictionary from 12.7.8.3.1 Table 245. The Version name may
- **`name_tree_entries`** (Function) — Enumerates all key/value pairs in a Catalog name tree in exact byte-key
- **`PdfFormFieldAdditionalActions`** (Struct) — Form field additional-actions dictionary from 12.6.3 Table 199. It models
- **`PdfAnnotationState`** (Enum) — Annotation states from ISO 32000-2 12.5.6.3 and Table 174. Marked,
- **`PdfMovieActivation`** (Struct) — 13.4 movie activation dictionary, Table 307. It keeps Start, Duration,
- **`PdfPopupAnnotation`** (Struct) — Popup annotation data from ISO 32000-2 12.5.6.14 and Table 186. Parent
- **`PdfSignatureByteRange`** (Struct) — ByteRange pair from ISO 32000-2 12.8.1 Table 255. Each pair contributes a
- **`rotate`** (Function) — Returns the inheritable Rotate entry from this Page or the nearest ancestor
- **`PdfRequirementSupportStatus`** (Enum) — Requirement evaluation status for ISO 32000-2 12.11.1. Requirements are
- **`PdfStampAnnotation`** (Struct) — Rubber stamp annotation data from ISO 32000-2 12.5.6.12 and Table 184.
- **`PdfBorderEffect`** (Struct) — Border effect dictionary from ISO 32000-2 Table 169. The style and
- **`PdfRichMediaContent`** (Struct) — 13.7.2.3.1 Table 341 RichMediaContent dictionary. Assets, Configurations,
- **`PdfRichMediaAsset`** (Struct) — 13.7.2.3.2 assets name tree entry. It preserves the file name and
- **`PdfCoordinateSystemDescriptor`** (Enum) — EPSG code or Well Known Text (WKT) descriptor for geographic and projected
- **`PdfOCGStateOperation`** (Struct) — One left-to-right State sequence from 12.6.4.13 Table 217: an ON, OFF, or
- **`open`** (Function) — Opens bytes as a PdfDocument and resolves the document structure layer.
- **`PdfWatermarkAnnotation`** (Struct) — Watermark annotation data from ISO 32000-2 12.5.6.22 and Table 193.
- **`PdfHideTarget`** (Enum) — Hide action target forms from 12.6.4.11 Table 214: annotation dictionary or
- **`PdfMeasureKind`** (Enum) — Measure dictionary subtype names from ISO 32000-2 12.9.1 Table 266:
- **`resources`** (Function) — Returns the inheritable Resources entry from this Page or the nearest
- **`PdfViabilityReport`** (Struct) — Side-effect-free viability report for renditions, media clips, media play
- **`PdfRichMediaAnimation`** (Struct) — 13.7.2.2.4 Table 337 RichMediaAnimation dictionary. It stores Subtype,
- **`NameTreeCategory`** (Enum) — Known Catalog name-tree categories required by the Names dictionary:
- **`PdfSoftwareIdentity`** (Struct) — Caller-supplied software identity for 13.2.7.4 matching and 13.2.7.2 media
- **`PdfOCGStateOperator`** (Enum) — Set-OCG-state operator names from 12.6.4.13 Table 217: ON, OFF, and Toggle.
- **`PdfPageMode`** (Enum) — Viewer presentation mode names shared by Catalog OpenAction and viewer
- **`name_tree_root`** (Function) — Returns the name-tree root for a Names dictionary category such as Dests,
- **`PdfFixedPrint`** (Struct) — Fixed print dictionary from ISO 32000-2 Table 194. Watermark annotations
- **`PdfMediaRendition`** (Struct) — 13.2.3.2 Media renditions, Table 282. It links C media clip, P media
- **`PdfThreeDAnnotation`** (Struct) — 13.6.1 and 13.6.2 3D annotation metadata, including Table 309 entries 3DD,
- **`PdfRichMediaView`** (Struct) — 13.7.2.3.5 Table 344 extended 3D view dictionary for RichMedia. Snapshot
- **`PdfMediaPlayParams`** (Struct) — 13.2.5 media play parameters dictionary, Table 290 and Table 291. Controls
- **`software_identifier_matches`** (Function) — 13.2.7.4.2 Algorithm: software identifier. It matches U software URI names,
- **`PdfRichMediaConfiguration`** (Struct) — 13.7.2.3.3 Table 342 RichMediaConfiguration dictionary. Subtype may be 3D,
- **`PdfMediaDuration`** (Enum) — 13.2.5 Table 292 media duration dictionary: intrinsic I, infinity F,
- **`PdfRawDictionaryPayload`** (Struct) — Raw dictionary payload retained for clause 13 dictionaries whose media,
- **`PdfMovieAnnotation`** (Struct) — Movie annotation data from ISO 32000-2 12.5.6.17 and Table 189. T title,
- **`permissions_entry`** (Function) — Returns the optional Perms entry from the Catalog dictionary for 12.8.6
- **`PdfLineEndingStyle`** (Enum) — Line ending styles from ISO 32000-2 Table 179: Square, Circle, Diamond,
- **`PdfSelectorRendition`** (Struct) — 13.2.3.3 selector rendition, Table 283. `renditions` preserves the ordered
- **`PdfAnnotationPath`** (Struct) — Annotation path made from coordinate pairs. It covers PDF 2.0 Path arrays
- **`PdfSoftwareNameUri`** (Struct) — 13.2.7.4.3 software URI. The defined scheme is vnd.adobe.swname, and the
- **`PdfTimespan`** (Struct) — 13.2.6.3 timespan dictionary, Table 300, and section offsets. `begin`
- **`PdfMovieTarget`** (Enum) — Movie action target from 12.6.4.10 Table 213. Exactly one of Annotation
- **`PdfMediaPermissions`** (Struct) — 13.2.4.2 media permissions dictionary, Table 286. It records TF temporary
- **`PdfRenditionCommon`** (Struct) — 13.2.3.1 Table 277 common rendition dictionary entries: Type Rendition,
- **`PdfCoordinateSystemKind`** (Enum) — Coordinate system kind names from ISO 32000-2 12.10.3 Table 270 and
- **`PdfPrinterMarkAnnotation`** (Struct) — Printer's mark annotation data from ISO 32000-2 12.5.6.20. PrinterMark
- **`PdfViabilityDecision`** (Enum) — Viability decision for clause 13 media objects: viable, non-viable, or
- **`lookup_name`** (Function) — Looks up a string key in a Catalog Names dictionary name tree and returns
- **`PdfRichMediaDeactivation`** (Struct) — 13.7.2.2.3 Table 336 RichMediaDeactivation dictionary. It keeps the
- **`PdfRichMediaPosition`** (Struct) — 13.7.2.2.6 Table 340 RichMediaPosition dictionary. HAlign and VAlign use
- **`PdfMultimediaObject`** (Enum) — Typed clause 13 object union for renditions, media clips, legacy media, 3D
- **`PdfMultimediaPayload`** (Enum) — Opaque multimedia payload carrier for object, byte-string, dictionary,
- **`PdfCaretAnnotation`** (Struct) — Caret annotation data from ISO 32000-2 12.5.6.11 and Table 183. RD
- **`PdfPageAdditionalActions`** (Struct) — Page object additional-actions dictionary from 12.6.3 Table 198. It models
- **`print_eligible`** (Function) — Structural print eligibility predicate for annotation flags from
- **`PdfPoint`** (Struct) — Point in default user space used by annotation geometry: Rect,
- **`screen_visible`** (Function) — Structural screen visibility predicate for annotation flags from
- **`PdfInkAnnotation`** (Struct) — Ink annotation data from ISO 32000-2 12.5.6.13 and Table 185. InkList
- **`PdfMediaClipKind`** (Enum) — 13.2.4.1 Table 284 media clip subtype: MCD media clip data, MCS media clip
- **`PdfHighlightMode`** (Enum) — Link and widget highlighting mode from ISO 32000-2 Tables 176 and 191:
- **`PdfJustification`** (Enum) — Quadding or justification code used by free text and redaction
- **`PdfMultimediaAnnotation`** (Enum) — Typed annotation-level clause 13 union for Sound, Movie, 3D, RichMedia, or
- **`document`** (Function) — Builds a PdfDocument from an already opened PdfFile, following the trailer
- **`PdfMediaPlayerPolicy`** (Struct) — 13.2.7.2 Table 301 media players dictionary. MU is `must_use`, A is
- **`PdfRawStreamPayload`** (Struct) — Raw stream payload retained for embedded files, Sound streams, 3D streams,
- **`PdfThreeDMarkupExternalData`** (Struct) — 13.6.6 Table 324 Markup3D ExData dictionary linking markup annotations to
- **`PageTreeRecord`** (Struct) — Internal page-tree record carrying the validated leaf page, its location,
- **`PdfMultimediaByteString`** (Struct) — Clause 13 multimedia byte string payload retained from
- **`PdfMultimediaUnknownName`** (Struct) — Forward-compatible unknown name with the dictionary context that made the
- **`PdfRichMediaInstance`** (Struct) — 13.7.2.3.4 Table 343 RichMediaInstance dictionary. It binds a required
- **`catalog`** (Function) — Returns the validated Catalog dictionary facade, including Type Catalog and
- **`requirements_entry`** (Function) — Returns the optional Requirements entry from the Catalog dictionary for
- **`PdfMultimediaObjectReference`** (Struct) — Clause 13 indirect object reference used by multimedia, 3D, and RichMedia
- **`PdfFloatingWindowParams`** (Struct) — 13.2.6.1 floating window parameters dictionary, Table 295, retained raw
- **`PdfAnnotationCallout`** (Struct) — Free text callout line from ISO 32000-2 Table 177 CL. Four numbers encode
- **`trailer`** (Function) — Returns trailer metadata from the latest cross-reference section, including
- **`PdfMhBePolicy`** (Struct) — 13.2.2 Viability MH and BE policy dictionaries. `must_honor` models MH
- **`read_startxref_offset`** (Function) — Parses the byte offset following the startxref keyword and validates that
- **`acro_form_entry`** (Function) — Returns the optional AcroForm entry as raw Catalog data. Typed form
- **`PdfBorderStyle`** (Enum) — Border style names from ISO 32000-2 Table 168: S solid, D dashed,
- **`PdfThreeDStream`** (Struct) — 13.6.3.1 Table 311 3D stream. Subtype identifies U3D or PRC; VA views are
- **`dss_entry`** (Function) — Returns the optional DSS entry from the Catalog dictionary for 12.8.4
- **`page_count`** (Function) — Reports the total page count by lazily traversing the Pages tree and
- **`compare_version_arrays`** (Function) — 13.2.7.4.4 Algorithm: Comparing version arrays. Empty arrays marked as
- **`PdfMovieOperation`** (Enum) — Movie Operation names from 12.6.4.10 Table 213: Play, Stop, Pause, and
- **`PdfVersionArray`** (Struct) — 13.2.7.4.4 version array with non-negative subversion components and an
- **`PdfTempFilePermission`** (Enum) — 13.2.4.2 Table 286 temporary file permission TF values: TEMPALWAYS,
- **`PdfThreeDMeasurementExternalData`** (Struct) — 13.6.7.4 Table 332 3DM ExData dictionary linking a projection annotation
- **`PdfMarkInfo`** (Struct) — Catalog MarkInfo flags with ISO defaults for absent entries. The raw
- **`PdfThreeDArtworkSource`** (Enum) — 13.6.2 Table 309 and 13.6.3.3 Table 314 artwork source: direct 3D stream,
- **`PdfThreeDReference`** (Struct) — 13.6.3.3 Table 314 3D reference dictionary that shares a run-time artwork
- **`pages`** (Function) — Enumerates all pages in document order by recursively traversing Kids from
- **`PdfMinimumScreenSize`** (Struct) — 13.2.3.1 Table 281 minimum screen size dictionary, including width, height,
- **`ByteSource`** (Struct) — Owns the raw PDF byte buffer and rebases PDF-relative offsets against the
- **`PdfAnnotationStateModel`** (Enum) — Annotation state model names from ISO 32000-2 12.5.6.3 and Table 174:
- **`PdfTextMarkupKind`** (Enum) — Text markup annotation kinds from ISO 32000-2 12.5.6.10 and Table 182:
- **`standard`** (Function) — Returns standard action-trigger ordering notes as structural metadata. No
- **`push_button`** (Function) — True when Table 229 bit 17 Pushbutton is set and no permanent V or DV
- **`compare_reference`** (Function) — Compares this file identifier against a caller-supplied reference by exact
- **`root_ref`** (Function) — Returns the trailer Root indirect reference that identifies the Catalog
- **`page`** (Function) — Returns the Page object for a zero-based page index and raises an error
- **`XrefSectionEntry`** (Struct) — Traditional or stream cross-reference entry data grouped with the object
- **`compare_file_id_reference`** (Function) — Compares an optional current identifier against a reference and reports
- **`PdfBorderEffectStyle`** (Enum) — Border effect style names from ISO 32000-2 Table 169: S no effect and
- **`PdfPointDataColumn`** (Enum) — Point data column names from 12.10.5 Table 272: LAT latitude, LON
- **`PdfLineCoordinates`** (Struct) — Line annotation L entry from ISO 32000-2 Table 178, holding start and end
- **`PdfHeader`** (Struct) — Parsed PDF header with the version, binary-indicator flag, and the
- **`PdfAlternatePresentation`** (Struct) — 13.5 Alternate presentations name-tree entry that pairs a name with a
- **`PdfThreeDMatrix`** (Struct) — 13.6.5 12-number 3D transformation matrix used for camera-to-world,
- **`legal_entry`** (Function) — Returns the optional Legal entry from Catalog Table 29 for 12.8.7 legal
- **`PdfMovieActivationMode`** (Enum) — 13.4 Table 307 movie activation Mode names: Once, Open, Repeat,
- **`PdfThreeDMeasurementKind`** (Enum) — 13.6.7.3 Table 326 measurement subtype names: LD3, PD3, AD3, RD3, 3DC,
- **`PdfPolygonKind`** (Enum) — Polygon family discriminator for ISO 32000-2 12.5.6.9 polygon and
- **`PdfUnknownRendition`** (Struct) — Unknown rendition subtype whose raw common dictionary is retained because
- **`PdfMinimumBitDepth`** (Struct) — 13.2.3.1 Table 280 minimum bit depth dictionary, including monitor
- **`parent_ref`** (Function) — Returns the Parent entry reference that links this Page to its ancestor
- **`PdfRichMediaWindow`** (Struct) — 13.7.2.2.6 Table 339 RichMediaWindow dictionary for non-printing
- **`PdfShapeKind`** (Enum) — Shape discriminator for ISO 32000-2 12.5.6.8 square and circle
- **`names_entry`** (Function) — Returns the optional Names entry from the Catalog dictionary for name
- **`slice_from_pdf_offset`** (Function) — Returns a raw byte slice from the PDF-relative offset through the end of
- **`names_dict`** (Function) — Resolves the optional Names entry in the Catalog dictionary as a name
- **`physical_offset`** (Function) — Converts a PDF-relative offset into a physical byte offset in the owned
- **`metadata_sources`** (Function) — Returns Catalog Metadata, trailer Info, and non-mutating source diagnostics.
- **`mark_info`** (Function) — Returns Catalog MarkInfo with ISO defaults when the dictionary is absent.
- **`slice_range`** (Function) — Returns a raw byte slice from a physical byte offset and explicit length.
- **`PdfRichMediaWindowDimension`** (Struct) — 13.7.2.2.6 Table 339 RichMediaWindow size interval in default user space.
- **`user_unit`** (Function) — Returns the optional UserUnit entry defined directly on the Page object.
- **`content_instructions`** (Function) — Returns only the parsed page content instructions from `content_stream`.
- **`PdfThreeDUnitSpec`** (Struct) — 13.6.7.2 Table 325 unit mapping "m model units = n real/display units".
- **`PdfRectangle`** (Struct) — Four-number page rectangle normalized from MediaBox or CropBox arrays.
- **`ObjectStreamTableCacheEntry`** (Struct) — Cached decoded object-stream member identity and parsed direct object.
- **`commit_on_sel_change`** (Function) — True when Table 233 bit 27 CommitOnSelChange is set for choice fields.
- **`PdfViabilityTraceEntry`** (Struct) — Entry-level trace for MH/BE and media criteria viability decisions.
- **`sort`** (Function) — True when Table 233 bit 20 Sort is set for choice option authoring.
- **`find_last_startxref_before`** (Function) — Searches backward for the startxref keyword during reverse parsing.
- **`comb`** (Function) — True when Table 231 bit 25 Comb is set for text fields with MaxLen.
- **`radios_in_unison`** (Function) — True when Table 229 bit 26 RadiosInUnison is set for radio buttons.
- **`TrailerInfo`** (Struct) — Trailer metadata extracted from the latest cross-reference section.
- **`PageTreeIndex`** (Struct) — Internal page-tree cache that stores the complete leaf-page order.
- **`no_toggle_to_off`** (Function) — True when Table 229 bit 15 NoToggleToOff is set for radio buttons.
- **`no_export`** (Function) — True when Table 227 bit 3 NoExport is set for submit-form actions.
- **`edit`** (Function) — True when Table 233 bit 19 Edit is set for an editable combo box.
- **`piece_info`** (Function) — Resolves and validates the optional Catalog PieceInfo dictionary.
- **`graphics_events`** (Function) — Convenience accessor returning only ordered page graphics events.
- **`multi_select`** (Function) — True when Table 233 bit 22 MultiSelect is set for choice fields.
- **`ObjectLocation`** (Enum) — Location of an indirect object after cross-reference resolution.
- **`radio`** (Function) — True when Table 229 bit 16 Radio is set and Pushbutton is clear.
- **`file_id`** (Function) — Returns the validated trailer file identifier pair when present.
- **`PdfFileId`** (Struct) — PDF file identifier pair from the trailer dictionary `ID` entry.
- **`PdfVersion`** (Struct) — PDF version pair used by reader metadata and header validation.
- **`do_not_spell_check`** (Function) — True when Table 231 or Table 233 bit 23 DoNotSpellCheck is set.
- **`do_not_scroll`** (Function) — True when Table 231 bit 24 DoNotScroll is set for text fields.
- **`XrefEntry`** (Enum) — Raw cross-reference entry shapes from table or stream parsing.
- **`locked_contents`** (Function) — True when ISO 32000-2 Table 167 bit 10 LockedContents is set.
- **`file_select`** (Function) — True when Table 231 bit 21 FileSelect is set for text fields.
- **`metadata_stream`** (Function) — Resolves and validates the optional Catalog Metadata stream.
- **`multiline`** (Function) — True when Table 231 bit 13 Multiline is set for text fields.
- **`document_info`** (Function) — Resolves and validates the optional trailer Info dictionary.
- **`ObjectStreamTableCache`** (Struct) — Cached decoded object-stream members and their parse offset.
- **`rich_text`** (Function) — True when Table 231 bit 26 RichText is set for text fields.
- **`password`** (Function) — True when Table 231 bit 14 Password is set for text fields.
- **`combo`** (Function) — True when Table 233 bit 18 Combo is set for a choice field.
- **`toggle_no_view`** (Function) — True when ISO 32000-2 Table 167 bit 9 ToggleNoView is set.
- **`PdfThreeDVector`** (Struct) — 13.6.5 3D vector in world, artwork, or camera coordinates.
- **`version`** (Function) — Returns the parsed PDF header version for the opened file.
- **`contents`** (Function) — Returns the optional Contents entry from the Page object.
- **`object_id`** (Function) — Returns the indirect object id of this leaf Page object.
- **`find_last_marker_before`** (Function) — Searches backward for a marker such as the %%EOF marker.
- **`annots`** (Function) — Returns the optional Annots entry from the Page object.
- **`invisible`** (Function) — True when ISO 32000-2 Table 167 bit 1 Invisible is set.
- **`read_only`** (Function) — True when ISO 32000-2 Table 167 bit 7 ReadOnly is set.
- **`no_rotate`** (Function) — True when ISO 32000-2 Table 167 bit 5 NoRotate is set.
- **`XrefSection`** (Struct) — One parsed cross-reference section and its provenance.
- **`new`** (Function) — Creates a byte source over the original input buffer.
- **`XrefIndex`** (Type) — Resolved active object-location map after xref merge.
- **`locked`** (Function) — True when ISO 32000-2 Table 167 bit 8 Locked is set.
- **`hidden`** (Function) — True when ISO 32000-2 Table 167 bit 2 Hidden is set.
- **`no_zoom`** (Function) — True when ISO 32000-2 Table 167 bit 4 NoZoom is set.
- **`no_view`** (Function) — True when ISO 32000-2 Table 167 bit 6 NoView is set.
- **`print`** (Function) — True when ISO 32000-2 Table 167 bit 3 Print is set.
- **`XrefSectionProvenance`** (Struct) — Provenance for one parsed cross-reference section.
- **`document_language`** (Function) — Returns the Catalog Lang text string, if present.
- **`PdfFile`** (Struct) — Opened-file state owned by the reader package.
- **`XrefSectionSource`** (Enum) — Origin of a parsed cross-reference section.
- **`required`** (Function) — True when Table 227 bit 2 Required is set.
- **`outline_item_action`** (Function) — 


- **`lower_ascii`** (Function) — 


- **`PdfCollectionView`** (Enum) — 


- **`PdfCollectionSchemaField`** (Struct) — 


- **`PdfCollectionSort`** (Struct) — 


- **`PdfCollectionFile`** (Struct) — 


- **`PdfCollectionFolder`** (Struct) — 


- **`PdfNavigator`** (Struct) — 


- **`PdfCollection`** (Struct) — 


- **`PdfPageLabelStyle`** (Enum) — 


- **`PdfPageLabelRange`** (Struct) — 


- **`PdfPageLabel`** (Struct) — 


- **`PdfArticleThread`** (Struct) — 


- **`PdfArticleBead`** (Struct) — 


- **`PdfTransitionStyle`** (Enum) — 


- **`PdfTransition`** (Struct) — 


- **`PdfPresentation`** (Struct) — 


- **`PdfNavigationNode`** (Struct) — 


- **`InheritedPageEntry`** (Struct) — 


- **`PdfEmbeddedFileParams`** (Struct) — 


- **`PdfRelatedFile`** (Struct) — 


- **`navigation_nodes`** (Function) — 


- **`PdfCollectionItem`** (Struct) — 


- **`named_destinations`** (Function) — 


- **`standard_structure_report`** (Function) — 


- **`parse_xref_subsection_header`** (Function) — 


- **`lookup_named_destination_value`** (Function) — 


- **`lookup_legacy_destination`** (Function) — 


- **`append_legacy_destinations`** (Function) — 


- **`resolve_structure_type`** (Function) — 


- **`PdfAssociatedFileRelationship`** (Enum) — 


- **`default`** (Function) — 


- **`require_xref_subsection_object_number_range`** (Function) — 


- **`first_page_object_id`** (Function) — 


- **`elements`** (Function) — 


- **`PdfFileSpecStream`** (Struct) — 


- **`ensure_page_index`** (Function) — 


- **`element_by_id`** (Function) — 


- **`media_player_info_matches`** (Function) — 


- **`action_source_object_id`** (Function) — 


- **`parent_for_object`** (Function) — 


- **`parent_for_mcid`** (Function) — 


- **`structure_number_tree_entry`** (Function) — 


- **`reject_duplicate_name_tree_entries`** (Function) — 


- **`file_spec_append_bytes`** (Function) — 


- **`bytes_compare`** (Function) — 


- **`file_spec_join_components`** (Function) — 


- **`name_tree_category_key`** (Function) — 


- **`structural_key`** (Function) — 


- **`catalog_optional_content_state`** (Function) — 


- **`effective_language`** (Function) — 


- **`inherited_structure_language`** (Function) — 


- **`embedded_files`** (Function) — 


- **`open_action`** (Function) — 


- **`catalog_additional_actions`** (Function) — 


- **`catalog_uri`** (Function) — 


- **`additional_actions`** (Function) — 


- **`annotation_action`** (Function) — 


- **`annotation_previous_uri_action`** (Function) — 


- **`annotation_additional_actions`** (Function) — 


- **`ObjectStreamMember`** (Struct) — 


- **`navigation_node_forward_action`** (Function) — 


- **`ObjectStreamTable`** (Struct) — 


- **`entry_at`** (Function) — 


- **`PdfStructureParent`** (Enum) — 


- **`PdfStructureDiagnostic`** (Struct) — 


- **`PdfMarkedContentIdentifier`** (Struct) — 


- **`PdfMarkedContentReference`** (Struct) — 


- **`PdfObjectReferenceContent`** (Struct) — 


- **`PdfStructureContentItem`** (Enum) — 


- **`PdfStructureChild`** (Enum) — 


- **`PdfStructureAttributeSourceKind`** (Enum) — 


- **`PdfUserProperty`** (Struct) — 


- **`PdfStructureAttributeObject`** (Struct) — 


- **`PdfStructureClassReference`** (Struct) — 


- **`PdfStructureClassMapEntry`** (Struct) — 


- **`PdfResolvedAttribute`** (Struct) — 


- **`PdfAccessibilityProperties`** (Struct) — 


- **`PdfEffectiveLanguageSource`** (Enum) — 


- **`PdfEffectiveLanguage`** (Struct) — 


- **`PdfStructureElement`** (Struct) — 


- **`PdfNamespaceRoleMapEntry`** (Struct) — 


- **`PdfStructureNamespace`** (Struct) — 


- **`PdfStandardStructureCategory`** (Enum) — 


- **`PdfStandardStructureType`** (Struct) — 


- **`PdfResolvedStructureType`** (Struct) — 


- **`PdfStructureParentLookup`** (Struct) — 


- **`PdfStructureContentReport`** (Struct) — 


- **`PdfTaggedPdfSeverity`** (Enum) — 


- **`PdfTaggedPdfReportItem`** (Struct) — 


- **`PdfStandardNestingDiagnostic`** (Struct) — 


- **`PdfTaggedPdfReport`** (Struct) — 


- **`PdfStructureTree`** (Struct) — 


- **`entries`** (Function) — 


- **`require_object_stream_int`** (Function) — 


- **`read_object_stream_header_pairs`** (Function) — 


- **`read_object_stream_members`** (Function) — 


- **`parse_object_stream_member`** (Function) — 


- **`buffer_length`** (Function) — 


- **`navigation_node_backward_action`** (Function) — 


- **`checked_object_stream_add`** (Function) — 


- **`has_startxref_prefix_boundary`** (Function) — 


- **`checked_object_stream_pdf_offset`** (Function) — 


- **`has_startxref_whitespace_after_keyword`** (Function) — 


- **`skip_tail_whitespace`** (Function) — 


- **`is_tail_whitespace`** (Function) — 


- **`media_player_info_array_matches`** (Function) — 


- **`bytes_match_at`** (Function) — 


- **`article_beads`** (Function) — 


- **`annotation_action_value`** (Function) — 


- **`annotation_additional_action_value`** (Function) — 


- **`multimedia_bytes_equal_ascii_case_insensitive`** (Function) — 


- **`multimedia_key`** (Function) — 


- **`pattern_resources`** (Function) — 


- **`page_direct_resource_dictionary`** (Function) — 


- **`page_label`** (Function) — 


- **`format_page_label`** (Function) — 


- **`int_to_bytes`** (Function) — 


- **`roman_bytes`** (Function) — 


- **`alpha_bytes`** (Function) — 


- **`reverse_bytes`** (Function) — 


- **`PdfThumbnailColorSpace`** (Enum) — 


- **`PdfResolvedFileSpecObject`** (Struct) — 


- **`PdfFileSpecPath`** (Struct) — 


- **`PdfSimpleFileSpecification`** (Struct) — 


- **`PdfFileSpecNameEntry`** (Struct) — 


- **`PdfFileSpecFileSystem`** (Enum) — 


- **`PdfFileSpecIdentifier`** (Struct) — 


- **`PdfFileSpecificationDictionary`** (Struct) — 


- **`PdfEmbeddedFile`** (Struct) — 


- **`PdfThumbnail`** (Struct) — 


- **`PdfOutlineItem`** (Struct) — 


- **`PdfEncryptedPayload`** (Struct) — 


- **`PdfEmbeddedFileEntry`** (Struct) — 


- **`normalize_file_spec_path`** (Function) — 


- **`resolve_file_spec_path`** (Function) — 


- **`resolve_file_spec_url_path`** (Function) — 


- **`reject_url_relative_path`** (Function) — 


- **`encode_url_path`** (Function) — 


- **`url_encode_byte`** (Function) — 


- **`is_url_path_safe`** (Function) — 


- **`hex_digit`** (Function) — 


- **`resolve_encoded_url_path`** (Function) — 


- **`url_base_directory`** (Function) — 


- **`trim_url_base_for_relative_components`** (Function) — 


- **`url_parent_directory`** (Function) — 


- **`url_authority_end`** (Function) — 


- **`require_object_stream_cache_entry`** (Function) — 


- **`default_viewer_preferences`** (Function) — 


- **`decoded_content_bytes`** (Function) — 


- **`content_stream_objects`** (Function) — 


- **`XrefStreamIndexRange`** (Struct) — 


- **`parse_xref_stream_section`** (Function) — 


- **`require_xref_stream_index_range`** (Function) — 


- **`parse_header`** (Function) — 


- **`find_header_offset`** (Function) — 


- **`header_marker_at`** (Function) — 


- **`parse_header_version`** (Function) — 


- **`validate_supported_version`** (Function) — 


- **`parse_version_digit`** (Function) — 


- **`require_header_byte`** (Function) — 


- **`consume_header_eol`** (Function) — 


- **`detect_binary_indicator`** (Function) — 


- **`scan_binary_indicator_comment`** (Function) — 


- **`read_section_chain_from_offset`** (Function) — 


- **`read_xref_section_at_offset`** (Function) — 


- **`parse_xref_stream_entries`** (Function) — 


- **`parse_xref_stream_entry`** (Function) — 


- **`read_xref_stream_unsigned`** (Function) — 


- **`require_xref_stream_entry_width`** (Function) — 


- **`checked_xref_stream_add`** (Function) — 


- **`require_xref_stream_int`** (Function) — 


- **`user_properties`** (Function) — 


- **`resolved_attributes`** (Function) — 


- **`append_resolved_attribute_objects`** (Function) — 


- **`is_markup_subtype`** (Function) — 


- **`parse_xref_table_body`** (Function) — 


- **`require_xref_keyword`** (Function) — 


- **`parse_xref_entry`** (Function) — 


- **`parse_xref_trailer`** (Function) — 


- **`require_xref_int`** (Function) — 


- **`parse_xref_decimal`** (Function) — 


- **`parse_xref_fixed_width_decimal`** (Function) — 


- **`require_xref_ascii_space`** (Function) — 


- **`require_xref_entry_eol`** (Function) — 


- **`matches_keyword_at`** (Function) — 


- **`has_keyword_boundary`** (Function) — 


- **`skip_all_xref_whitespace`** (Function) — 


- **`skip_inline_xref_whitespace`** (Function) — 


- **`consume_xref_line_ending`** (Function) — 


- **`parse_collection_files`** (Function) — 


- **`collection_folder_id_from_name`** (Function) — 


- **`collect_structure_content_child_report`** (Function) — 


- **`content_item_unchecked_report`** (Function) — 


- **`multimedia_software_uri_matches`** (Function) — 


- **`multimedia_version_component`** (Function) — 


- **`multimedia_ascii_lower`** (Function) — 


- **`multimedia_version_is_non_negative`** (Function) — 


- **`multimedia_version_after_lower_bound`** (Function) — 


- **`text_resources`** (Function) — 


- **`text_program`** (Function) — 


- **`extracted_text`** (Function) — 


- **`materialized_text_content_resources`** (Function) — 


- **`multimedia_version_before_upper_bound`** (Function) — 


- **`extension_key`** (Function) — 


- **`parse_catalog_extension_version`** (Function) — 


- **`compare_pdf_versions`** (Function) — 


- **`pdf20_extension_syntax_allowed`** (Function) — 


- **`append_namespace_report_item`** (Function) — 


- **`append_user_properties_report_item`** (Function) — 


- **`structure_user_property_count`** (Function) — 


- **`append_accessibility_report_items`** (Function) — 


- **`PdfReadingDirection`** (Enum) — 


- **`PdfPageBoundary`** (Enum) — 


- **`PdfPrintScaling`** (Enum) — 


- **`PdfDuplex`** (Enum) — 


- **`sort_name_tree_entries`** (Function) — 


- **`PdfViewerPreferenceEnforceName`** (Enum) — 


- **`PdfPageRange`** (Struct) — 


- **`append_standard_diagnostic`** (Function) — 


- **`append_structure_tree_report_items`** (Function) — 


- **`append_parent_report_item`** (Function) — 


- **`sort_number_tree_entries`** (Function) — 


- **`PdfDestinationTarget`** (Enum) — 


- **`PdfDestinationView`** (Enum) — 


- **`PdfDestination`** (Struct) — 


- **`PdfNamedDestination`** (Struct) — 


- **`materialized_content_stream`** (Function) — 


- **`PdfOutline`** (Struct) — 


- **`requires_file_id`** (Function) — 


- **`structure_tree`** (Function) — 
- **`parse_file_spec_path`** (Function) — 
- **`reader_boundary_probe`** (Function) — 
- **`parse_xref_table_section`** (Function) — 
- **`StructuralStreamPurpose`** (Enum) — 
- **`ExtensionParseContext`** (Struct) — 
- **`HeaderScanResult`** (Struct) — 
- **`structure_key`** (Function) — 
- **`outline`** (Function) — 
- **`presentation`** (Function) — 
- **`accessibility_properties`** (Function) — 
- **`action_key`** (Function) — 
- **`page_label_ranges`** (Function) — 
- **`merge_sections`** (Function) — 
- **`load_catalog`** (Function) — 
- **`StructuralDomain`** (Enum) — 
- **`file_spec_key`** (Function) — 
- **`threads`** (Function) — 
- **`ObjectStreamHeaderPair`** (Struct) — 
- **`multimedia_bytes_array_contains`** (Function) — 
- **`named_destination`** (Function) — 
- **`read_section_chain`** (Function) — 
- **`tagged_pdf_report`** (Function) — 
- **`parse_file_spec_dictionary`** (Function) — 
- **`thumbnail`** (Function) — 
- **`collection`** (Function) — 
- **`namespaces`** (Function) — 
- **`viewer_preferences`** (Function) — 
- **`annotation_key`** (Function) — 
- **`structure_content_report`** (Function) — 
- **`optional_content_state`** (Function) — 
- **`PdfFileSpecification`** (Enum) — 
- **`materialized_content_resources`** (Function) — 
- **`attributes`** (Function) — 
- **`build_page_tree_index`** (Function) — 
- **`XrefStreamWidths`** (Struct) — 
- **`navigation_key`** (Function) — 
- **`TextPageOptions`** (Struct) —
