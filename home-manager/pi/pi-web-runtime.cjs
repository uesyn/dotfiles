const fs = require('node:fs');
const { homedir } = require('node:os');
const path = require('node:path');

function prepare(source) {
  const local = path.join(homedir(), '.local');
  const state = path.join(local, 'state');
  const appState = path.join(state, 'pi-web');
  const runtimeRoot = path.join(appState, 'runtime');
  for (const dir of [local, state, appState, runtimeRoot]) {
    try {
      fs.mkdirSync(dir, { mode: 0o700 });
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
    }
    const stat = fs.lstatSync(dir);
    const privateDir = dir === appState || dir === runtimeRoot;
    const mode = stat.mode & 0o777;
    if (!stat.isDirectory() || stat.uid !== process.getuid()
      || (privateDir ? mode !== 0o700 : (mode & 0o022) !== 0)) {
      const permission = privateDir ? 'with mode 0700' : 'not writable by other users';
      throw new Error(`Expected a user-owned directory ${permission}, not a symlink: ${dir}`);
    }
  }
  const runtime = fs.mkdtempSync(path.join(runtimeRoot, 'pi-web-'));
  process.once('exit', () => fs.rmSync(runtime, { recursive: true, force: true }));
  for (const entry of ['node_modules', 'package.json', 'next.config.ts', 'public']) {
    fs.symlinkSync(path.join(source, entry), path.join(runtime, entry));
  }
  const next = path.join(runtime, '.next');
  fs.mkdirSync(next);
  for (const entry of fs.readdirSync(path.join(source, '.next'))) {
    const from = path.join(source, '.next', entry);
    const to = path.join(next, entry);
    if (entry === 'prerender-manifest.json') fs.copyFileSync(from, to);
    else fs.symlinkSync(from, to);
  }
  return runtime;
}

module.exports = { prepare };
