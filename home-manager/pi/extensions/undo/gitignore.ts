/**
 * Minimal .gitignore matcher (zero dependencies).
 *
 * Implements the common gitignore subset:
 * - blank lines and `#` comments
 * - `!` negation (last matching rule wins)
 * - trailing `/` -> directory-only pattern
 * - leading `/` -> anchored to the snapshot root
 * - patterns containing a slash are anchored to the root
 * - patterns without a slash match at any depth
 * - `*`, `?`, `**` wildcards and `[...]` character classes
 *
 * Documented limitations (v1):
 * - only the root-level .gitignore is read (no nested .gitignore files)
 * - no trailing-space unescaping
 * - git's "cannot re-include inside an ignored directory" rule is preserved
 *   implicitly because the walker never descends into ignored directories
 */

interface Rule {
  regex: RegExp;
  dirOnly: boolean;
  negated: boolean;
}

function escapeRegExpChar(c: string): string {
  return /[.*+?^${}()|[\]\\]/.test(c) ? `\\${c}` : c;
}

/** Find the index of the closing `]` for a character class starting at openIndex. */
function findClassEnd(pattern: string, openIndex: number): number {
  let i = openIndex + 1;
  while (i < pattern.length) {
    if (pattern[i] === "\\") {
      i += 2;
      continue;
    }
    if (pattern[i] === "]") return i;
    i += 1;
  }
  return -1;
}

/** Translate a gitignore glob into a regex source (without anchors). */
function translate(pattern: string): string {
  let out = "";
  let i = 0;
  while (i < pattern.length) {
    const c = pattern[i];
    if (c === undefined) break;
    if (c === "*") {
      if (pattern[i + 1] === "*") {
        if (pattern[i + 2] === "/") {
          out += "(?:.*/)?";
          i += 3;
        } else {
          out += ".*";
          i += 2;
        }
      } else {
        out += "[^/]*";
        i += 1;
      }
    } else if (c === "?") {
      out += "[^/]";
      i += 1;
    } else if (c === "[") {
      const end = findClassEnd(pattern, i);
      if (end === -1) {
        out += "\\[";
        i += 1;
      } else {
        let cls = pattern.slice(i + 1, end);
        if (cls.startsWith("!")) cls = `^${cls.slice(1)}`;
        cls = cls.replace(/\\/g, "\\\\").replace(/\]/g, "\\]");
        out += `[${cls}]`;
        i = end + 1;
      }
    } else {
      out += escapeRegExpChar(c);
      i += 1;
    }
  }
  return out;
}

export class Gitignore {
  private rules: Rule[] = [];

  /** @param patterns Lines from a .gitignore file (or equivalent). */
  constructor(patterns: readonly string[]) {
    for (const raw of patterns) {
      this.addPattern(raw);
    }
  }

  addPattern(raw: string): void {
    let pattern = raw.trim();
    if (!pattern || pattern.startsWith("#")) return;

    let negated = false;
    if (pattern.startsWith("!")) {
      negated = true;
      pattern = pattern.slice(1);
    }
    // Unescape a leading escaped # or !
    if (pattern.startsWith("\\#")) pattern = pattern.slice(1);
    if (pattern.startsWith("\\!")) pattern = pattern.slice(1);
    if (!pattern) return;

    let dirOnly = false;
    if (pattern.endsWith("/")) {
      dirOnly = true;
      pattern = pattern.slice(0, -1);
    }
    if (!pattern) return;

    const anchored = pattern.startsWith("/");
    if (anchored) pattern = pattern.slice(1);
    // A pattern that still contains a slash is implicitly anchored.
    const implicitAnchored = pattern.includes("/");

    const source = translate(pattern);
    const regex = new RegExp(
      anchored || implicitAnchored ? `^${source}$` : `^(?:.*/)?${source}$`,
    );

    this.rules.push({ regex, dirOnly, negated });
  }

  /**
   * Check whether a relative path (POSIX, forward slashes) is ignored.
   *
   * @param isDir true when the path refers to a directory
   */
  isIgnored(relPath: string, isDir: boolean): boolean {
    if (this.matchPath(relPath, isDir)) return true;
    // A file is also ignored when any ancestor directory is ignored
    // (git cannot re-include files inside an ignored directory).
    if (!isDir) {
      const segments = relPath.split("/");
      for (let i = segments.length - 1; i >= 1; i--) {
        if (this.matchPath(segments.slice(0, i).join("/"), true)) return true;
      }
    }
    return false;
  }

  /** Apply all rules to a single path (last matching rule wins). */
  private matchPath(relPath: string, isDir: boolean): boolean {
    let ignored = false;
    for (const rule of this.rules) {
      if (rule.dirOnly && !isDir) continue;
      if (rule.regex.test(relPath)) ignored = !rule.negated;
    }
    return ignored;
  }
}

/**
 * Patterns that are always excluded from snapshots regardless of config.
 * `.git` must never be snapshotted (it would contain the objects we write...,
 * actually it would just be wasteful and could include the refs/objects dir).
 */
export const HARD_EXCLUDES: readonly string[] = [
  ".git",
  ".hg",
  ".svn",
  ".DS_Store",
];
