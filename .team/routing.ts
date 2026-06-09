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
