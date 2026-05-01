import { useState } from "react";
import { PdfViewer } from "./components/viewer/PdfViewer";
import { readDebugFlag } from "./hooks/use-debug-flag";
import { bootstrapWasm } from "./store/wasm-bootstrap";

bootstrapWasm();

export default function App() {
  const [debugEnabled] = useState<boolean>(() => readDebugFlag());
  return <PdfViewer debugEnabled={debugEnabled} />;
}
