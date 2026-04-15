#include <stdio.h>

#include "moonbit.h"

/* Native stderr bridge for the pdf CLI subcommand architecture. It is used by
 * text, images, and check subcommands to print diagnostic capability reporting,
 * unsupported feature warnings, and summary statistics to stderr. */
MOONBIT_FFI_EXPORT void trkbt10_pdf_cli_stderr_write(moonbit_bytes_t message) {
  fputs((const char *)message, stderr);
  fputc('\n', stderr);
  fflush(stderr);
}
