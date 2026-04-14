///|
test "rendering error model distinguishes foundation failure categories" {
  let invalid_device = PdfRenderingError::InvalidDevice("bad setup")
  match invalid_device {
    InvalidDevice(reason) => assert_eq(reason, "bad setup")
    _ => fail("expected invalid device")
  }

  let invalid_resource = PdfRenderingError::InvalidResource("bad halftone")
  match invalid_resource {
    InvalidResource(reason) => assert_eq(reason, "bad halftone")
    _ => fail("expected invalid resource")
  }

  let unsupported = PdfRenderingError::UnsupportedCapability("icc transform")
  match unsupported {
    UnsupportedCapability(reason) => assert_eq(reason, "icc transform")
    _ => fail("expected unsupported capability")
  }

  let provider = PdfRenderingError::ProviderFailure("function", "BG")
  match provider {
    ProviderFailure(category, resource) => {
      assert_eq(category, "function")
      assert_eq(resource, "BG")
    }
    _ => fail("expected provider failure")
  }

  let limit = PdfRenderingError::LimitExceeded("surface bytes", 12, 11)
  match limit {
    LimitExceeded(name, observed, configured) => {
      assert_eq(name, "surface bytes")
      assert_eq(observed, 12)
      assert_eq(configured, 11)
    }
    _ => fail("expected limit failure")
  }
}
