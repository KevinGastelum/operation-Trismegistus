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
