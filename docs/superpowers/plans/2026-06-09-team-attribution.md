# Team Attribution Convention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A portable `team-commit` tool that splits a working-tree change into one authored commit per owner (docs→Captain, src→Coder-A/B, tests→Auditor, rest→Orchestrator), so a 5-member team appears in any repo's commit log + GitHub avatars.

**Architecture:** Two Bun/TS modules under `.team/` — `routing.ts` (pure: roster types, path→role matching, commit planning; fully unit-tested) and `team-commit.ts` (CLI + git I/O via `Bun.spawn`). A `.team/roster.json` is the single source of truth. `scripts/team-init.sh` copies the `.team/` set + `just` recipes into any target repo.

**Tech Stack:** Bun 1.3.x, TypeScript, `Bun.Glob`, `Bun.spawnSync`, `bun test`, git, bash (installer), just (recipes).

Spec: `docs/superpowers/specs/2026-06-09-team-attribution-design.md`.

---

### Task 1: Roster data + routing core (types, author, loader)

**Files:**
- Create: `.team/roster.json`
- Create: `.team/routing.ts`
- Test: `.team/routing.test.ts`

- [ ] **Step 1: Create the roster data file**

Create `.team/roster.json`:

```json
{
  "version": 1,
  "roles": {
    "captain":      {"login": "LucraTitan",    "id": 268125578, "name": "LucraTitan",      "label": "Captain"},
    "coder-a":      {"login": "K-Bot-T1",      "id": 290088768, "name": "K-Bot-T1",        "label": "Coder-A"},
    "coder-b":      {"login": "K-bot-T2",      "id": 292117888, "name": "K-bot-T2",        "label": "Coder-B"},
    "auditor":      {"login": "K-bot-T3",      "id": 292116934, "name": "K-bot-T3",        "label": "Auditor"},
    "orchestrator": {"login": "KevinGastelum", "id": 97716634,  "name": "Kevin Gastelum", "label": "Orchestrator"}
  },
  "routes": [
    {"role": "auditor", "globs": ["**/*.test.*", "**/*.spec.*", "tests/**", "__tests__/**", "test/**", "**/__snapshots__/**"]},
    {"role": "captain", "globs": ["docs/**", "packages/*/docs/**", "agents/**"]},
    {"role": "coder",   "globs": ["src/**", "packages/*/src/**"], "rotate": ["coder-a", "coder-b"]},
    {"role": "orchestrator", "globs": ["**"]}
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `.team/routing.test.ts`:

```ts
import { test, expect } from "bun:test";
import { authorEmail, authorOf, normalize, type Roster } from "./routing.ts";

export const roster: Roster = {
  version: 1,
  roles: {
    captain: { login: "LucraTitan", id: 268125578, name: "LucraTitan", label: "Captain" },
    "coder-a": { login: "K-Bot-T1", id: 290088768, name: "K-Bot-T1", label: "Coder-A" },
    "coder-b": { login: "K-bot-T2", id: 292117888, name: "K-bot-T2", label: "Coder-B" },
    auditor: { login: "K-bot-T3", id: 292116934, name: "K-bot-T3", label: "Auditor" },
    orchestrator: { login: "KevinGastelum", id: 97716634, name: "Kevin Gastelum", label: "Orchestrator" },
  },
  routes: [
    { role: "auditor", globs: ["**/*.test.*", "**/*.spec.*", "tests/**", "__tests__/**", "test/**", "**/__snapshots__/**"] },
    { role: "captain", globs: ["docs/**", "packages/*/docs/**", "agents/**"] },
    { role: "coder", globs: ["src/**", "packages/*/src/**"], rotate: ["coder-a", "coder-b"] },
    { role: "orchestrator", globs: ["**"] },
  ],
};

test("authorEmail uses id+login noreply form", () => {
  expect(authorEmail(roster.roles.captain)).toBe("268125578+LucraTitan@users.noreply.github.com");
});

test("authorOf resolves name + email + label", () => {
  const a = authorOf("auditor", roster);
  expect(a).toEqual({ roleKey: "auditor", name: "K-bot-T3", email: "292116934+K-bot-T3@users.noreply.github.com", label: "Auditor" });
});

test("normalize converts backslashes to forward slashes", () => {
  expect(normalize("src\\a\\b.ts")).toBe("src/a/b.ts");
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd .team && bun test routing.test.ts`
Expected: FAIL — `Cannot find module './routing.ts'` / undefined exports.

- [ ] **Step 4: Create the implementation (types + helpers)**

Create `.team/routing.ts`:

```ts
// Pure routing logic for team-commit. No git, no process side effects.
// Runs under Bun (uses Bun.Glob). Imported by team-commit.ts and tests.

export type RoleKey = "captain" | "coder-a" | "coder-b" | "auditor" | "orchestrator";
export type RouteRole = "captain" | "coder" | "auditor" | "orchestrator";

export interface RoleDef {
  login: string;
  id: number;
  name: string;
  label: string;
}

export interface Route {
  role: RouteRole;
  globs: string[];
  rotate?: RoleKey[];
}

export interface Roster {
  version: number;
  roles: Record<RoleKey, RoleDef>;
  routes: Route[];
}

export interface ChangedFile {
  path: string; // new/current path, /-normalized
  oldPath?: string; // rename source, /-normalized
}

export interface Author {
  roleKey: RoleKey;
  name: string;
  email: string;
  label: string;
}

export function normalize(p: string): string {
  return p.replace(/\\/g, "/");
}

export function authorEmail(role: RoleDef): string {
  return `${role.id}+${role.login}@users.noreply.github.com`;
}

export function authorOf(roleKey: RoleKey, roster: Roster): Author {
  const r = roster.roles[roleKey];
  if (!r) throw new Error(`roster.roles missing "${roleKey}"`);
  return { roleKey, name: r.name, email: authorEmail(r), label: r.label };
}

export async function loadRoster(path: string): Promise<Roster> {
  const file = Bun.file(path);
  if (!(await file.exists())) {
    throw new Error(`no roster at ${path} — run team-init in this repo`);
  }
  return (await file.json()) as Roster;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd .team && bun test routing.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add .team/roster.json .team/routing.ts .team/routing.test.ts
git commit -m "feat: team roster data + routing core (types, author, loader)"
```

---

### Task 2: Path → role matching (`routeFile`)

**Files:**
- Modify: `.team/routing.ts`
- Test: `.team/routing.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `.team/routing.test.ts`:

```ts
import { routeFile } from "./routing.ts";

test("routeFile: tests beat src (auditor precedence over coder)", () => {
  expect(routeFile("src/app.test.ts", roster.routes)).toBe("auditor");
  expect(routeFile("src/app.spec.tsx", roster.routes)).toBe("auditor");
  expect(routeFile("src/__snapshots__/a.snap", roster.routes)).toBe("auditor");
});

test("routeFile: src, docs, agents, catch-all", () => {
  expect(routeFile("src/app.ts", roster.routes)).toBe("coder");
  expect(routeFile("packages/ui/src/x.ts", roster.routes)).toBe("coder");
  expect(routeFile("docs/guide.md", roster.routes)).toBe("captain");
  expect(routeFile("packages/ui/docs/x.md", roster.routes)).toBe("captain");
  expect(routeFile("agents/LucraTitan.md", roster.routes)).toBe("captain");
  expect(routeFile("README.md", roster.routes)).toBe("orchestrator");
  expect(routeFile("package.json", roster.routes)).toBe("orchestrator");
  expect(routeFile("justfile", roster.routes)).toBe("orchestrator");
});

test("routeFile normalizes backslash paths", () => {
  expect(routeFile("src\\a.ts", roster.routes)).toBe("coder");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd .team && bun test routing.test.ts`
Expected: FAIL — `routeFile is not a function`.

- [ ] **Step 3: Implement `routeFile`**

Append to `.team/routing.ts`:

```ts
// First-match-wins route resolution on a /-normalized path.
export function routeFile(path: string, routes: Route[]): RouteRole {
  const p = normalize(path);
  for (const route of routes) {
    for (const g of route.globs) {
      if (new Bun.Glob(g).match(p)) return route.role;
    }
  }
  return "orchestrator"; // defensive; routes always end with a ** catch-all
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd .team && bun test routing.test.ts`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add .team/routing.ts .team/routing.test.ts
git commit -m "feat: routeFile path-to-role matching with first-match precedence"
```

---

### Task 3: Commit planning (`planCommits`, `dominantBucket`)

**Files:**
- Modify: `.team/routing.ts`
- Test: `.team/routing.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `.team/routing.test.ts`:

```ts
import { planCommits, dominantBucket } from "./routing.ts";

test("planCommits: buckets in dependency order; rename old+new together", () => {
  const files = [
    { path: "docs/a.md" },
    { path: "src/b.ts" },
    { path: "src/b.test.ts" },
    { path: "package.json" },
    { path: "src/new.ts", oldPath: "src/old.ts" },
  ];
  const plan = planCommits(files, roster);
  expect(plan.buckets.map((b) => b.routeRole)).toEqual(["orchestrator", "coder", "auditor", "captain"]);
  const coder = plan.buckets.find((b) => b.routeRole === "coder")!;
  expect(coder.paths).toContain("src/new.ts");
  expect(coder.paths).toContain("src/old.ts");
  expect(coder.author.label).toBe("Coder-A");
});

test("planCommits: coder alternates from lastCoder; pin overrides", () => {
  const f = [{ path: "src/a.ts" }];
  expect(planCommits(f, roster, { lastCoder: "coder-a" }).buckets[0].author.label).toBe("Coder-B");
  expect(planCommits(f, roster, { lastCoder: "coder-b" }).buckets[0].author.label).toBe("Coder-A");
  expect(planCommits(f, roster, {}).buckets[0].author.label).toBe("Coder-A");
  expect(planCommits(f, roster, { coderPin: "b", lastCoder: "coder-b" }).buckets[0].author.label).toBe("Coder-B");
  expect(planCommits(f, roster, { lastCoder: "coder-a" }).nextLastCoder).toBe("coder-b");
});

test("dominantBucket: most files wins", () => {
  const plan = planCommits([{ path: "src/a.ts" }, { path: "src/b.ts" }, { path: "docs/c.md" }], roster);
  expect(dominantBucket(plan.buckets).routeRole).toBe("coder");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd .team && bun test routing.test.ts`
Expected: FAIL — `planCommits is not a function`.

- [ ] **Step 3: Implement planning**

Append to `.team/routing.ts`:

```ts
export interface Bucket {
  routeRole: RouteRole;
  author: Author;
  paths: string[]; // includes rename oldPath entries
}

export interface CommitPlan {
  buckets: Bucket[]; // in commit (dependency) order
  nextLastCoder?: RoleKey;
}

export interface PlanOpts {
  coderPin?: "a" | "b";
  lastCoder?: RoleKey;
}

// Commit (dependency) order — decoupled from match precedence so an
// intermediate commit is more likely to build.
const COMMIT_ORDER: RouteRole[] = ["orchestrator", "coder", "auditor", "captain"];

// Tie-break order for --solo dominant selection (match precedence).
const PRECEDENCE: RouteRole[] = ["auditor", "captain", "coder", "orchestrator"];

function resolveCoder(rotate: RoleKey[], pin: "a" | "b" | undefined, lastCoder: RoleKey | undefined): RoleKey {
  if (pin === "a") return "coder-a";
  if (pin === "b") return "coder-b";
  if (lastCoder && rotate.includes(lastCoder)) {
    return rotate[(rotate.indexOf(lastCoder) + 1) % rotate.length];
  }
  return rotate[0];
}

export function planCommits(files: ChangedFile[], roster: Roster, opts: PlanOpts = {}): CommitPlan {
  const groups = new Map<RouteRole, string[]>();
  for (const f of files) {
    const role = routeFile(f.path, roster.routes);
    const arr = groups.get(role) ?? [];
    arr.push(f.path);
    if (f.oldPath) arr.push(f.oldPath);
    groups.set(role, arr);
  }

  const coderRoute = roster.routes.find((r) => r.role === "coder");
  const rotate = coderRoute?.rotate ?? ["coder-a", "coder-b"];

  let nextLastCoder: RoleKey | undefined;
  const buckets: Bucket[] = [];
  for (const routeRole of COMMIT_ORDER) {
    const paths = groups.get(routeRole);
    if (!paths || paths.length === 0) continue;
    let author: Author;
    if (routeRole === "coder") {
      const coderKey = resolveCoder(rotate, opts.coderPin, opts.lastCoder);
      author = authorOf(coderKey, roster);
      nextLastCoder = coderKey;
    } else {
      author = authorOf(routeRole as RoleKey, roster);
    }
    buckets.push({ routeRole, author, paths });
  }
  return { buckets, nextLastCoder };
}

export function dominantBucket(buckets: Bucket[]): Bucket {
  if (buckets.length === 0) throw new Error("no buckets");
  return [...buckets].sort((a, b) => {
    if (b.paths.length !== a.paths.length) return b.paths.length - a.paths.length;
    return PRECEDENCE.indexOf(a.routeRole) - PRECEDENCE.indexOf(b.routeRole);
  })[0];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd .team && bun test routing.test.ts`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add .team/routing.ts .team/routing.test.ts
git commit -m "feat: planCommits bucketing + dependency order + coder rotation"
```

---

### Task 4: git layer — status parser + arg parser

**Files:**
- Create: `.team/team-commit.ts`
- Test: `.team/team-commit.test.ts`

- [ ] **Step 1: Write the failing test**

Create `.team/team-commit.test.ts`:

```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd .team && bun test team-commit.test.ts`
Expected: FAIL — `Cannot find module './team-commit.ts'`.

- [ ] **Step 3: Implement the git layer + parsers**

Create `.team/team-commit.ts`:

```ts
#!/usr/bin/env bun
import { existsSync } from "node:fs";
import {
  loadRoster,
  planCommits,
  dominantBucket,
  normalize,
  type Author,
  type ChangedFile,
  type RoleKey,
} from "./routing.ts";

interface GitResult { code: number; out: string; err: string; }

function git(args: string[], input?: Uint8Array): GitResult {
  const p = Bun.spawnSync(["git", ...args], input ? { stdin: input } : {});
  return { code: p.exitCode, out: p.stdout.toString(), err: p.stderr.toString() };
}

export function parseStatus(z: string): ChangedFile[] {
  const tokens = z.split("\0");
  const files: ChangedFile[] = [];
  for (let i = 0; i < tokens.length; i++) {
    const entry = tokens[i];
    if (!entry) continue;
    const xy = entry.slice(0, 2);
    const path = normalize(entry.slice(3));
    let oldPath: string | undefined;
    if (xy[0] === "R" || xy[0] === "C") {
      const next = tokens[++i];
      oldPath = next ? normalize(next) : undefined;
    }
    files.push({ path, oldPath });
  }
  return files;
}

export interface Args {
  msg?: string;
  solo: boolean;
  coder?: "a" | "b";
  push: boolean;
  dryRun: boolean;
  all: boolean;
}

export function parseArgs(argv: string[]): Args {
  const a: Args = { solo: false, push: false, dryRun: false, all: false };
  for (let i = 0; i < argv.length; i++) {
    const t = argv[i];
    if (t === "--solo") a.solo = true;
    else if (t === "--push") a.push = true;
    else if (t === "--dry-run" || t === "--status") a.dryRun = true;
    else if (t === "--all") a.all = true;
    else if (t === "--coder") a.coder = argv[++i] as "a" | "b";
    else if (!t.startsWith("--") && a.msg === undefined) a.msg = t;
  }
  return a;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd .team && bun test team-commit.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add .team/team-commit.ts .team/team-commit.test.ts
git commit -m "feat: team-commit git layer — porcelain -z status + arg parsers"
```

---

### Task 5: Orchestration (`main`) + end-to-end integration test

**Files:**
- Modify: `.team/team-commit.ts`
- Test: `.team/team-commit.test.ts`

- [ ] **Step 1: Write the failing end-to-end test**

Append to `.team/team-commit.test.ts`:

```ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd .team && bun test team-commit.test.ts`
Expected: FAIL — script has no orchestration; e2e gets 0 commits, assertions fail.

- [ ] **Step 3: Implement the orchestration**

Append to `.team/team-commit.ts`:

```ts
function hasHead(): boolean {
  return git(["rev-parse", "--verify", "-q", "HEAD"]).code === 0;
}

function hasStagedChanges(): boolean {
  return git(["diff", "--cached", "--quiet"]).code !== 0;
}

function assertNoDirtySubmodules(): void {
  if (!existsSync(".gitmodules")) return;
  const r = git(["submodule", "status", "--recursive"]);
  const dirty = r.out.split("\n").filter((l) => /^[+U-]/.test(l));
  if (dirty.length) {
    throw new Error(`unsynced submodule(s):\n${dirty.join("\n")}\ncommit/sync submodule content first`);
  }
}

function changedFiles(): ChangedFile[] {
  const r = git(["status", "--porcelain=v1", "-z", "--untracked-files=all", "--renames"]);
  if (r.code !== 0) throw new Error(`git status failed: ${r.err}`);
  return parseStatus(r.out);
}

function emptyIndex(): void {
  if (hasHead()) git(["reset", "-q"]);
  else git(["read-tree", "--empty"]);
}

function stage(paths: string[]): void {
  const input = new TextEncoder().encode(paths.join("\0"));
  const r = git(["--literal-pathspecs", "add", "-A", "--pathspec-from-file=-", "--pathspec-file-nul"], input);
  if (r.code !== 0) throw new Error(`git add failed: ${r.err}`);
}

function commit(author: Author, msg: string): void {
  const r = git(["commit", "-q", `--author=${author.name} <${author.email}>`, "-m", `[${author.label}] ${msg}`]);
  if (r.code !== 0) throw new Error(`git commit failed: ${r.err}`);
}

async function main(): Promise<void> {
  const args = parseArgs(Bun.argv.slice(2));
  const roster = await loadRoster(".team/roster.json");
  const files = changedFiles();
  if (files.length === 0) {
    console.log("team-commit: nothing to commit");
    return;
  }

  const lastCoder = (git(["config", "--local", "--get", "team.last-coder"]).out.trim() || undefined) as RoleKey | undefined;
  const plan = planCommits(files, roster, { coderPin: args.coder, lastCoder });

  if (args.dryRun) {
    console.log("team-commit plan (no changes made):");
    for (const b of plan.buckets) {
      console.log(`  [${b.author.label}] ${b.author.name} <${b.author.email}>`);
      for (const p of b.paths) console.log(`      ${p}`);
    }
    return;
  }

  if (args.msg === undefined) throw new Error('commit message required, e.g. team-commit "msg"');
  if (hasHead() && hasStagedChanges() && !args.all) {
    throw new Error("index has staged changes; rerun with --all to commit the whole working tree");
  }
  assertNoDirtySubmodules();

  if (args.solo) {
    const dom = dominantBucket(plan.buckets);
    const all = plan.buckets.flatMap((b) => b.paths);
    emptyIndex();
    stage(all);
    commit(dom.author, args.msg);
  } else {
    emptyIndex();
    for (const b of plan.buckets) {
      stage(b.paths);
      commit(b.author, args.msg);
    }
    if (plan.nextLastCoder) git(["config", "--local", "team.last-coder", plan.nextLastCoder]);
  }

  if (args.push) {
    const r = git(["push"]);
    if (r.code !== 0) throw new Error(`git push failed: ${r.err}`);
  }
  console.log("team-commit: done");
}

if (import.meta.main) {
  main().catch((e: Error) => {
    console.error(`team-commit: ${e.message}`);
    process.exit(1);
  });
}
```

- [ ] **Step 4: Run the full suite to verify it passes**

Run: `cd .team && bun test`
Expected: PASS (all routing + team-commit tests, including both e2e cases).

- [ ] **Step 5: Commit**

```bash
git add .team/team-commit.ts .team/team-commit.test.ts
git commit -m "feat: team-commit orchestration — gate, split, solo, push, dry-run"
```

---

### Task 6: `just` recipes + portable installer

**Files:**
- Create: `justfile` (operation-Trismegistus root)
- Create: `scripts/team-init.sh`

- [ ] **Step 1: Create the justfile recipes**

Create `justfile` at the repo root:

```just
# Team commit-attribution — route commits by changed path → role.
commit MSG:
    bun .team/team-commit.ts "{{MSG}}"

commit-push MSG:
    bun .team/team-commit.ts "{{MSG}}" --push

commit-solo MSG:
    bun .team/team-commit.ts "{{MSG}}" --solo

team-status:
    bun .team/team-commit.ts --dry-run
```

- [ ] **Step 2: Verify the recipe previews routing (no commit)**

```bash
mkdir -p docs && echo "tmp" >> docs/_scratch.md
just team-status
rm -f docs/_scratch.md
```
Expected: output lists `[Captain] LucraTitan …` owning `docs/_scratch.md`; no new commit (the recipe runs `--dry-run`).

- [ ] **Step 3: Create the installer**

Create `scripts/team-init.sh`:

```bash
#!/usr/bin/env bash
# Install the team-commit convention into a target repo.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

mkdir -p "$TARGET/.team"
cp "$SRC/.team/roster.json"    "$TARGET/.team/roster.json"
cp "$SRC/.team/routing.ts"     "$TARGET/.team/routing.ts"
cp "$SRC/.team/team-commit.ts" "$TARGET/.team/team-commit.ts"

JF="$TARGET/justfile"
if [ ! -f "$JF" ] || ! grep -q "team-commit.ts" "$JF"; then
  cat >> "$JF" <<'EOF'

# Team commit-attribution — route commits by changed path → role.
commit MSG:
    bun .team/team-commit.ts "{{MSG}}"

commit-push MSG:
    bun .team/team-commit.ts "{{MSG}}" --push

commit-solo MSG:
    bun .team/team-commit.ts "{{MSG}}" --solo

team-status:
    bun .team/team-commit.ts --dry-run
EOF
fi

# Warn-only verification of roster accounts against GitHub.
if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  while read -r login id; do
    real="$(gh api "users/$login" --jq .id 2>/dev/null || echo "")"
    if [ -n "$real" ] && [ "$real" != "$id" ]; then
      echo "warn: roster $login id=$id but GitHub reports $real"
    fi
  done < <(jq -r '.roles[] | "\(.login) \(.id)"' "$TARGET/.team/roster.json")
fi

echo "team-init: installed into $TARGET"
echo "  preview:  just team-status   (or: bun .team/team-commit.ts --dry-run)"
echo "  commit:   just commit \"message\""
```

- [ ] **Step 4: Verify the installer against a throwaway repo**

```bash
chmod +x scripts/team-init.sh
TMP="$(mktemp -d)"; git -C "$TMP" init -q
bash scripts/team-init.sh "$TMP"
ls "$TMP/.team" && grep -q team-commit.ts "$TMP/justfile" && echo OK
rm -rf "$TMP"
```
Expected: `roster.json routing.ts team-commit.ts` listed, `OK` printed.

- [ ] **Step 5: Commit**

```bash
git add justfile scripts/team-init.sh
git commit -m "feat: just recipes + portable team-init installer"
```

---

### Task 7: Refresh the role cards (dogfood the tool)

**Files:**
- Modify: `agents/LucraTitan.md`, `agents/K-bot-T1.md`, `agents/K-bot-T2.md`, `agents/K-bot-T3.md`

Note: `agents/**` routes to Captain (added to the captain route in Task 1), so committing these via `team-commit` produces a single `[Captain]` commit — the first real dogfood.

- [ ] **Step 1: Overwrite each card**

`agents/LucraTitan.md`:

```markdown
# LucraTitan — Captain / Coordinator

- Role: **Captain / Coordinator**
- Owns: `docs/**`, `agents/**` (documentation, coordination)
- GitHub: LucraTitan (id 268125578)
- Warren agent: claude-code

Authorship is routed by [`.team/roster.json`](../.team/roster.json) via
`team-commit`. Design: `docs/superpowers/specs/2026-06-09-team-attribution-design.md`.

## Action Log
- 2026-06-09 — renamed to Captain/Coordinator; wired into the team-commit convention.
```

`agents/K-bot-T1.md`:

```markdown
# K-Bot-T1 — Coder-A

- Role: **Coder-A**
- Owns: `src/**` (shared with Coder-B, alternating)
- GitHub: K-Bot-T1 (id 290088768)
- Warren agent: claude-code

Authorship is routed by [`.team/roster.json`](../.team/roster.json) via
`team-commit`. Design: `docs/superpowers/specs/2026-06-09-team-attribution-design.md`.

## Action Log
- 2026-06-09 — renamed to Coder-A; wired into the team-commit convention.
```

`agents/K-bot-T2.md`:

```markdown
# K-bot-T2 — Coder-B

- Role: **Coder-B**
- Owns: `src/**` (shared with Coder-A, alternating)
- GitHub: K-bot-T2 (id 292117888)
- Warren agent: claude-code

Authorship is routed by [`.team/roster.json`](../.team/roster.json) via
`team-commit`. Design: `docs/superpowers/specs/2026-06-09-team-attribution-design.md`.

## Action Log
- 2026-06-09 — renamed to Coder-B; wired into the team-commit convention.
```

`agents/K-bot-T3.md`:

```markdown
# K-bot-T3 — Auditor

- Role: **Auditor**
- Owns: tests (`**/*.test.*`, `**/*.spec.*`, `tests/`, `__tests__/`, `__snapshots__/`)
- GitHub: K-bot-T3 (id 292116934)
- Warren agent: claude-code

Authorship is routed by [`.team/roster.json`](../.team/roster.json) via
`team-commit`. Design: `docs/superpowers/specs/2026-06-09-team-attribution-design.md`.

## Action Log
- 2026-06-09 — renamed to Auditor; wired into the team-commit convention.
```

- [ ] **Step 2: Commit via team-commit (expect a single `[Captain]` commit)**

```bash
bun .team/team-commit.ts "agents: refresh role cards to Captain/Coder-A/Coder-B/Auditor"
git log --format='%an <%ae> %s' -1
```
Expected: `LucraTitan <268125578+LucraTitan@users.noreply.github.com> [Captain] agents: refresh role cards …`

---

### Task 8: Install into Trismegistus-Dashboard (CHECKPOINT)

**Files:** (in target repo) `Trismegistus-Dashboard/.team/*`, justfile recipes

- [ ] **Step 1: Run the installer against the dashboard**

```bash
bash scripts/team-init.sh /c/Users/Ivonne/Documents/Coding/Trismegistus-Dashboard
```
Expected: `.team/` populated; justfile recipes appended (dashboard already has a justfile); `team-init: installed` printed.

- [ ] **Step 2: Preview routing on the dashboard's working tree**

```bash
cd /c/Users/Ivonne/Documents/Coding/Trismegistus-Dashboard
bun .team/team-commit.ts --dry-run
```
Expected: a routing table showing how the dashboard's `src/**`, `index.html`, configs would split. **No commits made.**

- [ ] **Step 3: CHECKPOINT — do not auto-commit in the operator's active project**

Report the dry-run output and pause. The operator decides whether the first real split commit happens now (`just commit "..."`). The dashboard has **no remote yet**, so nothing pushes regardless.

---

## Notes / preconditions

- **Committer identity must be configured** (`git config user.name`/`user.email`) or `git commit` fails; `--author` only sets the author. team-init does not set the human's git identity.
- **Bun on PATH** in every target repo; the script only shells out to git, so the target need not be a Bun project.
- **`.team/` is committed** (not ignored) so the convention travels with the repo.
- Rename path order in `git status -z` is pinned by the `parseStatus` unit test (Task 4); if a future git changes it, that test fails loudly.
- **Coder rotation persists** via `git config --local team.last-coder` (per-repo, uncommitted).
```