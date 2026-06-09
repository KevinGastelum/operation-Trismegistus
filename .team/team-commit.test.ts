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

import { mkdtempSync, rmSync, writeFileSync, mkdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

function sh(cmd: string[], cwd: string) {
  const p = Bun.spawnSync(cmd, { cwd });
  return { code: p.exitCode, out: p.stdout.toString(), err: p.stderr.toString() };
}

test("e2e: auto-split makes one authored commit per category in dependency order", () => {
  const dir = mkdtempSync(join(tmpdir(), "team-commit-"));
  try {
    sh(["git", "init", "-q", "-b", "main"], dir);
    sh(["git", "config", "user.name", "Tester"], dir);
    sh(["git", "config", "user.email", "tester@example.com"], dir);

    const here = fileURLToPath(new URL(".", import.meta.url));
    mkdirSync(join(dir, ".team"), { recursive: true });
    writeFileSync(join(dir, ".team", "roster.json"), readFileSync(join(here, "roster.json")));

    mkdirSync(join(dir, "src"), { recursive: true });
    mkdirSync(join(dir, "docs"), { recursive: true });
    writeFileSync(join(dir, "src", "a.ts"), "export const a = 1;\n");
    writeFileSync(join(dir, "src", "a.test.ts"), "// test\n");
    writeFileSync(join(dir, "docs", "g.md"), "# guide\n");
    writeFileSync(join(dir, "package.json"), "{}\n");

    const script = join(here, "team-commit.ts");
    const run = sh(["bun", script, "init team"], dir);
    expect(run.code).toBe(0);

    const subjects = sh(["git", "log", "--reverse", "--format=%s"], dir).out.trim().split("\n");
    expect(subjects).toEqual([
      "[Orchestrator] init team",
      "[Coder-A] init team",
      "[Auditor] init team",
      "[Captain] init team",
    ]);

    const authors = sh(["git", "log", "--format=%ae"], dir).out;
    expect(authors).toContain("97716634+KevinGastelum@users.noreply.github.com");
    expect(authors).toContain("290088768+K-Bot-T1@users.noreply.github.com");
    expect(authors).toContain("292116934+K-bot-T3@users.noreply.github.com");
    expect(authors).toContain("268125578+LucraTitan@users.noreply.github.com");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("e2e: --dry-run makes no commits (unborn HEAD stays unborn)", () => {
  const dir = mkdtempSync(join(tmpdir(), "team-commit-"));
  try {
    sh(["git", "init", "-q", "-b", "main"], dir);
    sh(["git", "config", "user.name", "Tester"], dir);
    sh(["git", "config", "user.email", "tester@example.com"], dir);
    const here = fileURLToPath(new URL(".", import.meta.url));
    mkdirSync(join(dir, ".team"), { recursive: true });
    writeFileSync(join(dir, ".team", "roster.json"), readFileSync(join(here, "roster.json")));
    mkdirSync(join(dir, "src"), { recursive: true });
    writeFileSync(join(dir, "src", "a.ts"), "export const a = 1;\n");

    const script = join(here, "team-commit.ts");
    const run = sh(["bun", script, "--dry-run"], dir);
    expect(run.code).toBe(0);
    expect(run.out).toContain("Coder-A");
    expect(sh(["git", "rev-parse", "--verify", "-q", "HEAD"], dir).code).not.toBe(0);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("e2e: pre-staged index aborts without --all, proceeds with it", () => {
  const dir = mkdtempSync(join(tmpdir(), "team-commit-"));
  try {
    sh(["git", "init", "-q", "-b", "main"], dir);
    sh(["git", "config", "user.name", "Tester"], dir);
    sh(["git", "config", "user.email", "tester@example.com"], dir);
    const here = fileURLToPath(new URL(".", import.meta.url));
    mkdirSync(join(dir, ".team"), { recursive: true });
    writeFileSync(join(dir, ".team", "roster.json"), readFileSync(join(here, "roster.json")));
    writeFileSync(join(dir, "README.md"), "# x\n");
    sh(["git", "add", "README.md"], dir);
    sh(["git", "commit", "-q", "-m", "init"], dir); // HEAD now exists
    mkdirSync(join(dir, "src"), { recursive: true });
    writeFileSync(join(dir, "src", "a.ts"), "export const a = 1;\n");
    sh(["git", "add", "src/a.ts"], dir); // curated staging

    const script = join(here, "team-commit.ts");
    const blocked = sh(["bun", script, "msg"], dir);
    expect(blocked.code).not.toBe(0);
    expect(blocked.err).toContain("--all");
    expect(sh(["git", "rev-list", "--count", "HEAD"], dir).out.trim()).toBe("1");

    const ok = sh(["bun", script, "msg", "--all"], dir);
    expect(ok.code).toBe(0);
    expect(Number(sh(["git", "rev-list", "--count", "HEAD"], dir).out.trim())).toBeGreaterThan(1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
