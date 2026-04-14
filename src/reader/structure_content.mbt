///|
pub fn PdfDocument::structure_content_report(
  self : PdfDocument,
) -> PdfStructureContentReport raise PdfDocumentError {
  match self.structure_tree() {
    Some(tree) => tree.structure_content_report()
    None => PdfStructureContentReport::{ diagnostics: [], unchecked: [] }
  }
}

///|
fn PdfStructureTree::structure_content_report(
  self : PdfStructureTree,
) -> PdfStructureContentReport {
  let diagnostics : Array[PdfStructureDiagnostic] = []
  let unchecked : Array[PdfTaggedPdfReportItem] = []
  for element in self.elements {
    collect_structure_content_child_report(
      element.children,
      Some(element.index),
      diagnostics,
      unchecked,
    )
  }
  PdfStructureContentReport::{ diagnostics, unchecked }
}

///|
fn collect_structure_content_child_report(
  children : Array[PdfStructureChild],
  element_index : Int?,
  diagnostics : Array[PdfStructureDiagnostic],
  unchecked : Array[PdfTaggedPdfReportItem],
) -> Unit {
  for child in children {
    match child {
      PdfStructureChild::Diagnostic(diagnostic) => diagnostics.push(diagnostic)
      PdfStructureChild::Content(item) =>
        unchecked.push(content_item_unchecked_report(item, element_index))
      PdfStructureChild::Element(_, _) | PdfStructureChild::Raw(_) => ()
    }
  }
}

///|
fn content_item_unchecked_report(
  item : PdfStructureContentItem,
  element_index : Int?,
) -> PdfTaggedPdfReportItem {
  match item {
    PdfStructureContentItem::MCID(mcid) =>
      structure_report_item(
        b"MarkedContentNotScanned",
        PdfTaggedPdfSeverity::Unchecked,
        "MCID existence requires decoded content-stream context",
        element_index,
        None,
        Some(mcid.raw_object),
      )
    PdfStructureContentItem::MCR(reference) =>
      structure_report_item(
        b"MarkedContentReferenceNotScanned",
        PdfTaggedPdfSeverity::Unchecked,
        "marked-content reference requires decoded stream context",
        element_index,
        None,
        Some(@objects.PdfObject::Dictionary(reference.raw_dict)),
      )
    PdfStructureContentItem::OBJR(reference) =>
      structure_report_item(
        b"ObjectReferenceNotClassified",
        PdfTaggedPdfSeverity::Unchecked,
        "object reference subtype checks require object-specific context",
        element_index,
        Some(reference.object_ref),
        Some(@objects.PdfObject::Dictionary(reference.raw_dict)),
      )
  }
}
