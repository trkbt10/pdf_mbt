#include <stdio.h>

#include "moonbit.h"

MOONBIT_FFI_EXPORT void trkbt10_pdf_cli_stderr_write(moonbit_bytes_t message) {
  fputs((const char *)message, stderr);
  fputc('\n', stderr);
  fflush(stderr);
}
