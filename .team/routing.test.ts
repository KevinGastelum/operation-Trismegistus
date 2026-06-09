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
