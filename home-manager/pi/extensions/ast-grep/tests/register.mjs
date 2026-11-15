import { registerHooks } from "node:module";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const dir = process.env.PI_TEST_PACKAGE_DIR;
if (!dir) throw new Error("Set PI_TEST_PACKAGE_DIR to the installed Pi package directory");
const entry = pathToFileURL(resolve(dir, "dist/index.js")).href;

// Match the peer-module aliases Pi itself supplies to extensions.
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "@earendil-works/pi-coding-agent") {
      return { url: entry, shortCircuit: true };
    }
    if (/^@earendil-works\/pi-(ai|agent-core|tui)(\/|$)/.test(specifier) ||
      /^typebox(\/|$)/.test(specifier)) {
      return nextResolve(specifier, { ...context, parentURL: entry });
    }
    return nextResolve(specifier, context);
  },
});
