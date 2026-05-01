import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { test } from "node:test";

// Surfaces lint failures inside `node --test` so CI catches the
// no-set-state-in-effect rule violations next to other tests.
test("eslint passes on src/", async () => {
  const code = await new Promise((resolve, reject) => {
    const child = spawn(
      process.execPath,
      ["node_modules/eslint/bin/eslint.js", "src", "--max-warnings=0"],
      {
        cwd: new URL("..", import.meta.url),
        stdio: "inherit",
      }
    );
    child.on("exit", resolve);
    child.on("error", reject);
  });
  assert.equal(code, 0, "eslint reported errors");
});

test("reader resource materialization lint passes", async () => {
  const code = await new Promise((resolve, reject) => {
    const child = spawn(
      "python3",
      ["scripts/lint_resource_materialization.py"],
      {
        cwd: new URL("../../..", import.meta.url),
        stdio: "inherit",
      }
    );
    child.on("exit", resolve);
    child.on("error", reject);
  });
  assert.equal(code, 0, "resource materialization lint reported errors");
});
