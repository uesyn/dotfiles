#!/usr/bin/env python3
"""Test the actual patched parser against the unmodified upstream parser."""

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, required=True, help="unpatched platform/linux.rs")
parser.add_argument("--reader", type=Path, default=Path(__file__).with_name("elf-reader.rs"))
parser.add_argument("--patch", type=Path, default=Path(__file__).with_name("elf-reader.patch"))
parser.add_argument("--rustc", default="rustc")
parser.add_argument("--corpus", type=Path, action="append", default=[])
args = parser.parse_args()


def extract(source):
    start = source.rindex("#[derive(Clone, Copy)]", 0, source.index("struct LoadSegment {"))
    end = source.index("/// Resolves the `NEEDED`", start)
    functions = source[start:end].replace("fn parse_elf(", "pub fn parse_elf(", 1)
    start = source.index("fn vaddr_to_offset(")
    end = source.index("#[cfg(test)]", start)
    return functions + source[start:end]


support = r'''
use std::{fs, path::{Path, PathBuf}};
type Result<T> = std::result::Result<T, NonoError>;
#[derive(Debug)]
pub enum NonoError {
    ConfigRead { path: PathBuf, source: std::io::Error },
    PathCanonicalization { path: PathBuf, source: std::io::Error },
    SandboxInit(String),
}
#[derive(Debug)]
pub struct ParsedElf {
    pub interpreter: Option<PathBuf>,
    pub needed: Vec<String>,
    pub search_dirs: Vec<String>,
}
'''
checks = r'''
#[test]
fn reference_parser_agrees_on_actual_files() {
    let mut paths = vec![std::env::current_exe().unwrap()];
    paths.extend(std::env::split_paths(&std::env::var_os("ELF_READER_CORPUS").unwrap_or_default()));
    let mut accepted = 0;
    for path in paths {
        let expected = reference::parse_elf(&path);
        let actual = patched::parse_elf(&path);
        match (expected, actual) {
            (Ok(expected), Ok(actual)) => {
                assert_eq!(actual.interpreter, expected.interpreter, "{}", path.display());
                assert_eq!(actual.needed, expected.needed, "{}", path.display());
                assert_eq!(actual.search_dirs, expected.search_dirs, "{}", path.display());
                accepted += 1;
            }
            (Err(_), Err(_)) => (),
            (expected, actual) => panic!("parser disagreement on {}: {expected:?} vs {actual:?}", path.display()),
        }
    }
    eprintln!("reference parity: {accepted} accepted files");
}
'''
# Validate paths so a typo cannot silently turn a corpus into matching I/O errors.
corpus = set()
for path in args.corpus:
    if not path.exists():
        parser.error(f"corpus path does not exist: {path}")
    if path.is_dir():
        corpus.update(
            p.resolve() for p in path.iterdir()
            if p.is_file() and (os.access(p, os.X_OK) or p.name.endswith(".so") or ".so." in p.name)
        )
    else:
        corpus.add(path.resolve())
env = os.environ.copy()
env["ELF_READER_CORPUS"] = os.pathsep.join(map(str, sorted(corpus)))
with tempfile.TemporaryDirectory(prefix="nono-elf-reader-tests-") as directory:
    directory = Path(directory)
    patched = directory / "linux-patched.rs"
    subprocess.run(
        ["patch", "--silent", "--output", str(patched), str(args.source.resolve()), str(args.patch.resolve())],
        check=True,
    )
    functions = extract(patched.read_text()).replace(
        '#[path = "elf-reader-tests.rs"]',
        '#[path = ' + json.dumps(str(args.reader.resolve().with_name("elf-reader-tests.rs"))) + ']',
    )
    helper = '#[path = ' + json.dumps(str(args.reader.resolve())) + ']\nmod elf_reader;\nuse elf_reader::ElfReader;\n'
    harness = directory / "tests.rs"
    harness.write_text(
        "#[allow(dead_code, unused_imports)]\nmod reference {\n"
        + support + extract(args.source.read_text()) + "\n}\n"
        + "#[allow(dead_code, unused_imports)]\nmod patched {\n"
        + support + helper + functions + "\n}\n" + checks
    )
    binary = directory / "tests"
    subprocess.run([args.rustc, "--edition", "2024", "--test", str(harness), "-o", str(binary)], check=True)
    subprocess.run([str(binary), "--nocapture"], env=env, check=True)
