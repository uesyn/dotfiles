import assert from "node:assert/strict";
import { test } from "node:test";
import { access, chmod, mkdir, mkdtemp, readFile, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { createLocalBashOperations } from "@earendil-works/pi-coding-agent";
import { createState, initialize, sandboxShell } from "../state.ts";

test("initialize requires an executable wrapper and fails closed otherwise", async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-endpoint-test-"));
  try {
    const state = createState();
    await initialize(state, join(dir, "missing"));
    assert.equal(state.shell, null);
    assert.throws(() => sandboxShell(state), /missing or not executable/);

    const notExecutable = join(dir, "nono-bash");
    await writeFile(notExecutable, "#!/bin/sh\n");
    await initialize(state, notExecutable);
    assert.equal(state.shell, null);

    await chmod(notExecutable, 0o755);
    await initialize(state, notExecutable);
    assert.equal(state.shell, notExecutable);
    assert.equal(sandboxShell(state), notExecutable);

    // Home Manager substitutes the endpoint; the unsubstituted placeholder must
    // never resolve to a shell.
    await initialize(state, "@sandboxShell@");
    assert.equal(state.shell, null);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

// Mirrors the Nix-generated wrapper: the only thing the extension swaps is
// shellPath, so Pi's local operations own spawn, timeout and process-tree kill.
async function wrapper(dir: string, nono: string, shell: string, profile: string, stateHome: string): Promise<string> {
  const file = join(dir, "nono-bash");
  await writeFile(file, `#!/bin/bash
set +u
for name in \${!NONO_@}; do unset "$name"; done
unset NODE_OPTIONS NODE_PATH BASH_ENV ENV
export XDG_STATE_HOME='${stateHome}'
exec '${nono}' run -s --profile '${profile}' --allow-cwd --workdir "$PWD" --no-rollback --no-audit --no-diagnostics -- '${shell}' "$@"
`);
  await chmod(file, 0o755);
  return file;
}

// Opt-in: real installed nono and kernel enforcement. Temporary profiles only.
test("real nono enforces the selected profile through the wrapper shell", {
  skip: process.env.PI_NONO_INTEGRATION !== "1", timeout: 60_000,
}, async () => {
  const dir = await mkdtemp(join(tmpdir(), "pi-nono-integration-"));
  try {
    const workspace = join(dir, "workspace");
    const outside = join(dir, "outside");
    await mkdir(workspace);
    await mkdir(outside);
    await symlink(outside, join(workspace, "escape"));
    await writeFile(join(dir, "strict.json"), JSON.stringify({
      extends: "default",
      // Defaults allow /tmp writes; exclude that group so the fixture is real.
      groups: { include: ["nix_runtime"], exclude: ["system_write_linux", "system_write_macos"] },
      workdir: { access: "readwrite" },
      filesystem: { read: [outside], allow_file: ["/dev/null"] },
      network: { block: true },
    }));
    const nono = await realpath(process.env.PI_NONO_BINARY ?? join(homedir(), ".nix-profile/bin/nono"));
    const bash = await realpath("/bin/bash");
    const shell = await wrapper(workspace, nono, bash, join(dir, "strict.json"), dir);
    const ops = createLocalBashOperations({ shellPath: shell });
    const run = (command: string, extra: { signal?: AbortSignal; timeout?: number } = {}) =>
      ops.exec(command, workspace, { onData() {}, env: process.env, ...extra });

    assert.equal((await run("printf x > inside && cat inside")).exitCode, 0);
    await writeFile(join(outside, "caller-can-write"), "yes");
    assert.notEqual((await run(`printf no > '${outside}/denied'`)).exitCode, 0);
    assert.notEqual((await run("printf no > escape/symlink-denied")).exitCode, 0);
    // Reserved TEST-NET-3 peer, never a third party. A routing failure would
    // also exit 3, so require the kernel denial itself in the output.
    let network = "";
    const net = await ops.exec("if exec 3<>/dev/tcp/203.0.113.1/443; then exit 0; else exit 3; fi", workspace, {
      onData: (data) => { network += data.toString(); }, env: process.env, timeout: 10,
    });
    assert.equal(net.exitCode, 3);
    assert.match(network, /denied|not permitted/i);

    const controller = new AbortController();
    const aborted = run("sleep 1; touch aborted-marker", { signal: controller.signal });
    const rejected = assert.rejects(aborted, /aborted|Command aborted/i);
    setTimeout(() => controller.abort(), 200);
    await rejected;
    await assert.rejects(run("sleep 1; touch timeout-marker", { timeout: 0.2 }), /timeout:0\.2/);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    for (const name of ["aborted-marker", "timeout-marker"]) await assert.rejects(access(join(workspace, name)));

    // Profile selection is a config choice, not new policy code.
    const permissive = join(dir, "permissive.json");
    const strict = JSON.parse(await readFile(join(dir, "strict.json"), "utf8"));
    await writeFile(permissive, JSON.stringify({ ...strict, filesystem: { ...strict.filesystem, allow: [outside] }, network: undefined }));
    const permissiveShell = await wrapper(workspace, nono, bash, permissive, dir);
    const result = await createLocalBashOperations({ shellPath: permissiveShell })
      .exec(`printf ok > '${outside}/allowed'`, workspace, { onData() {}, env: process.env });
    assert.equal(result.exitCode, 0);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
