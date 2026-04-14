///|
pub fn PdfDocument::tagged_pdf_report(
  self : PdfDocument,
) -> PdfTaggedPdfReport raise PdfDocumentError {
  let mark_info = self.mark_info()
  let tree = self.structure_tree()
  match tree {
    Some(structure) => structure.tagged_pdf_report()
    None => {
      let errors : Array[PdfTaggedPdfReportItem] = []
      let warnings : Array[PdfTaggedPdfReportItem] = []
      let unchecked : Array[PdfTaggedPdfReportItem] = []
      if !mark_info.marked {
        errors.push(
          structure_report_item(
            b"MissingMarkedFlag",
            PdfTaggedPdfSeverity::Error,
            "Tagged PDF requires MarkInfo /Marked true",
            None,
            Some(self.catalog.object_id),
            None,
          ),
        )
      } else {
        errors.push(
          structure_report_item(
            b"MissingStructureTree",
            PdfTaggedPdfSeverity::Error,
            "marked document has no StructTreeRoot",
            None,
            Some(self.catalog.object_id),
            None,
          ),
        )
      }
      PdfTaggedPdfReport::{
        errors,
        warnings,
        unchecked,
        is_marked: mark_info.marked,
        has_structure_tree: false,
      }
    }
  }
}

///|
pub fn PdfStructureTree::tagged_pdf_report(
  self : PdfStructureTree,
) -> PdfTaggedPdfReport raise PdfDocumentError {
  let errors : Array[PdfTaggedPdfReportItem] = []
  let warnings : Array[PdfTaggedPdfReportItem] = []
  let unchecked : Array[PdfTaggedPdfReportItem] = []
  if !self.mark_info.marked {
    errors.push(
      structure_report_item(
        b"MissingMarkedFlag",
        PdfTaggedPdfSeverity::Error,
        "Tagged PDF requires MarkInfo /Marked true",
        None,
        self.root_object_id,
        None,
      ),
    )
  }
  for diagnostic in self.standard_structure_report() {
    append_standard_diagnostic(errors, warnings, unchecked, diagnostic)
  }
  append_structure_tree_report_items(self, errors, warnings, unchecked)
  let content_report = self.structure_content_report()
  for item in content_report.unchecked {
    unchecked.push(item)
  }
  PdfTaggedPdfReport::{
    errors,
    warnings,
    unchecked,
    is_marked: self.mark_info.marked,
    has_structure_tree: true,
  }
}

///|
fn append_standard_diagnostic(
  errors : Array[PdfTaggedPdfReportItem],
  warnings : Array[PdfTaggedPdfReportItem],
  unchecked : Array[PdfTaggedPdfReportItem],
  diagnostic : PdfStandardNestingDiagnostic,
) -> Unit {
  let item = structure_report_item(
    diagnostic.code.bytes,
    diagnostic.severity,
    diagnostic.message,
    diagnostic.element_index,
    None,
    None,
  )
  match diagnostic.severity {
    PdfTaggedPdfSeverity::Error => errors.push(item)
    PdfTaggedPdfSeverity::Warning => warnings.push(item)
    PdfTaggedPdfSeverity::Unchecked => unchecked.push(item)
  }
}

///|
fn append_structure_tree_report_items(
  tree : PdfStructureTree,
  errors : Array[PdfTaggedPdfReportItem],
  warnings : Array[PdfTaggedPdfReportItem],
  unchecked : Array[PdfTaggedPdfReportItem],
) -> Unit raise PdfDocumentError {
  for element in tree.elements {
    append_parent_report_item(tree, element, errors)
    append_namespace_report_item(tree, element, warnings)
    append_user_properties_report_item(tree, element, warnings)
    append_accessibility_report_items(tree, element, warnings, unchecked)
  }
}

///|
fn append_parent_report_item(
  tree : PdfStructureTree,
  element : PdfStructureElement,
  errors : Array[PdfTaggedPdfReportItem],
) -> Unit {
  match element.parent {
    PdfStructureParent::Root => ()
    PdfStructureParent::Element(Some(parent_ref)) =>
      if tree.root_object_id != Some(parent_ref) &&
        structure_element_by_ref(tree.elements, parent_ref) is None {
        errors.push(
          structure_report_item(
            b"ParentNotParsed",
            PdfTaggedPdfSeverity::Error,
            "structure element parent does not reference the parsed tree",
            Some(element.index),
            element.object_id,
            None,
          ),
        )
      }
    PdfStructureParent::Element(None) | PdfStructureParent::Raw(_) =>
      errors.push(
        structure_report_item(
          b"InvalidParentReference",
          PdfTaggedPdfSeverity::Error,
          "structure element parent must be an indirect reference",
          Some(element.index),
          element.object_id,
          None,
        ),
      )
  }
}

///|
fn append_namespace_report_item(
  tree : PdfStructureTree,
  element : PdfStructureElement,
  warnings : Array[PdfTaggedPdfReportItem],
) -> Unit {
  match element.namespace_ref {
    Some(namespace_ref) =>
      if !structure_namespace_declared(tree.namespaces, namespace_ref) {
        warnings.push(
          structure_report_item(
            b"NamespaceNotDeclared",
            PdfTaggedPdfSeverity::Warning,
            "structure element namespace is not declared by the structure tree root",
            Some(element.index),
            element.object_id,
            None,
          ),
        )
      }
    None => ()
  }
}

///|
fn append_user_properties_report_item(
  tree : PdfStructureTree,
  element : PdfStructureElement,
  warnings : Array[PdfTaggedPdfReportItem],
) -> Unit {
  if !tree.mark_info.user_properties &&
    structure_user_property_count(element) > 0 {
    warnings.push(
      structure_report_item(
        b"UserPropertiesFlagMissing",
        PdfTaggedPdfSeverity::Warning,
        "user properties are present but MarkInfo /UserProperties is false",
        Some(element.index),
        element.object_id,
        None,
      ),
    )
  }
}

///|
fn structure_user_property_count(element : PdfStructureElement) -> Int {
  let mut count = 0
  for attribute in element.attributes {
    count += attribute.user_properties.length()
  }
  count
}

///|
fn append_accessibility_report_items(
  tree : PdfStructureTree,
  element : PdfStructureElement,
  warnings : Array[PdfTaggedPdfReportItem],
  unchecked : Array[PdfTaggedPdfReportItem],
) -> Unit raise PdfDocumentError {
  let resolved = tree.resolve_structure_type(element)
  match resolved.standard_target {
    Some(standard) =>
      if standard.category == PdfStandardStructureCategory::Figure ||
        standard.category == PdfStandardStructureCategory::Formula {
        if element.accessibility.alternate_description is None &&
          element.accessibility.replacement_text is None {
          warnings.push(
            structure_report_item(
              b"MissingAlternateDescription",
              PdfTaggedPdfSeverity::Warning,
              "Figure and Formula elements should provide Alt or ActualText",
              Some(element.index),
              element.object_id,
              None,
            ),
          )
        }
        unchecked.push(
          structure_report_item(
            b"VisualGeometryNotChecked",
            PdfTaggedPdfSeverity::Unchecked,
            "visual BBox and text-object placement checks require rendering context",
            Some(element.index),
            element.object_id,
            None,
          ),
        )
      }
    None => ()
  }
  if element.accessibility.replacement_text is None {
    unchecked.push(
      structure_report_item(
        b"UnicodeMappingNotChecked",
        PdfTaggedPdfSeverity::Unchecked,
        "Unicode mapping and word-break checks require font and content context",
        Some(element.index),
        element.object_id,
        None,
      ),
    )
  }
}

///|
fn structure_namespace_declared(
  namespaces : Array[PdfStructureNamespace],
  namespace_ref : @objects.ObjectId,
) -> Bool {
  for ns in namespaces {
    if ns.object_id == Some(namespace_ref) {
      return true
    }
  }
  false
}
