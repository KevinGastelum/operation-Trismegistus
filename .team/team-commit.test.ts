import { test, expect } from "bun:test";
import { parseStatus, parseArgs } from "./team-commit.ts";

test("parseStatus: rename gives new path + oldPath; others have no oldPath", () => {
  // porcelain v1 -z: "R  <new>\0<old>\0", then a modified, then an untracked
  const z = "R  src/new.ts\0src/old.ts\0 M docs/a.md\0?? README.md\0";
  const files = parseStatus(z);
  expect(files).toContainEqual({ path: "src/new.ts", oldPath: "src/old.ts" });
  expect(files).toContainEqual({ path: "docs/a.md", oldPath: undefined });
  expect(files).toContainEqual({ path: "README.md", oldPath: undefined });
  expect(files.length).toBe(3);
});

test("parseArgs: message + flags", () => {
  const a = parseArgs(["my message", "--coder", "b", "--push", "--all"]);
  expect(a.msg).toBe("my message");
  expect(a.coder).toBe("b");
  expect(a.push).toBe(true);
  expect(a.all).toBe(true);
  expect(a.solo).toBe(false);
  expect(a.dryRun).toBe(false);
});

test("parseArgs: --dry-run and --solo", () => {
  expect(parseArgs(["--dry-run"]).dryRun).toBe(true);
  expect(parseArgs(["msg", "--solo"]).solo).toBe(true);
});
