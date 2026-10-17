use super::*;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::sync::atomic::{AtomicUsize, Ordering};

struct TestFile {
    path: PathBuf,
    file: File,
}

impl TestFile {
    fn new(bytes: &[u8]) -> Self {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "nono-elf-regions-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed),
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .unwrap();
        file.write_all(bytes).unwrap();
        Self { path, file }
    }
}

impl Drop for TestFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

#[derive(Debug, Default, PartialEq, Eq)]
struct Metadata {
    interpreter: Option<PathBuf>,
    needed: Vec<String>,
    search_dirs: Vec<String>,
}

fn put(bytes: &mut [u8], offset: usize, size: usize, value: u64) {
    bytes[offset..offset + size].copy_from_slice(&value.to_le_bytes()[..size]);
}

fn fixture(is64: bool) -> Vec<u8> {
    let mut bytes = vec![0; 8192];
    bytes[..4].copy_from_slice(b"\x7fELF");
    bytes[4] = if is64 { 2 } else { 1 };
    bytes[5] = 1;
    let stride = if is64 { 56 } else { 32 };
    put(
        &mut bytes,
        if is64 { 32 } else { 28 },
        if is64 { 8 } else { 4 },
        64,
    );
    put(&mut bytes, if is64 { 54 } else { 42 }, 2, stride as u64);
    put(&mut bytes, if is64 { 56 } else { 44 }, 2, 3);
    let strings = b"\0libone.so\0libtwo.so\0$ORIGIN/../lib:/opt/lib::\0/runtime\0";
    bytes[4096..4096 + strings.len()].copy_from_slice(strings);
    let position = |s: &[u8]| strings.windows(s.len()).position(|v| v == s).unwrap() as u64;
    let entries = [
        (1, position(b"libone")),
        (1, position(b"libtwo")),
        (5, 0x2000),
        (10, strings.len() as u64),
        (15, position(b"$ORIGIN")),
        (29, position(b"/runtime")),
        (0, 0),
    ];
    let word = if is64 { 8 } else { 4 };
    for (i, (tag, value)) in entries.iter().enumerate() {
        put(&mut bytes, 512 + i * word * 2, word, *tag);
        put(&mut bytes, 512 + i * word * 2 + word, word, *value);
    }
    let interpreter = std::env::current_exe().unwrap();
    let interpreter = interpreter.to_str().unwrap().as_bytes();
    bytes[7000..7000 + interpreter.len()].copy_from_slice(interpreter);
    for (index, kind, offset, vaddr, size) in [
        (0, 1, 0, 0x1000, 8192),
        (1, 2, 512, 0, entries.len() * word * 2),
        (2, 3, 7000, 0, interpreter.len() + 1),
    ] {
        let base = 64 + index * stride;
        put(&mut bytes, base, 4, kind);
        put(&mut bytes, base + if is64 { 8 } else { 4 }, word, offset);
        put(&mut bytes, base + if is64 { 16 } else { 8 }, word, vaddr);
        put(
            &mut bytes,
            base + if is64 { 32 } else { 16 },
            word,
            size as u64,
        );
    }
    bytes
}

fn read(bytes: Vec<u8>) -> Result<Metadata> {
    let file = TestFile::new(&bytes);
    let parsed = parse_elf(&file.path)?;
    Ok(Metadata {
        interpreter: parsed.interpreter,
        needed: parsed.needed,
        search_dirs: parsed.search_dirs,
    })
}

#[test]
fn parses_elf32_and_elf64_dependencies_paths_and_interpreter() {
    for is64 in [false, true] {
        let metadata = read(fixture(is64)).unwrap();
        assert_eq!(metadata.needed, ["libone.so", "libtwo.so"]);
        assert_eq!(
            metadata.search_dirs,
            [
                format!(
                    "{}/../lib",
                    std::env::temp_dir()
                        .join("tool")
                        .parent()
                        .unwrap()
                        .display()
                ),
                "/opt/lib".to_string(),
                "/runtime".to_string(),
            ]
        );
        assert_eq!(
            metadata.interpreter,
            Some(std::env::current_exe().unwrap().canonicalize().unwrap())
        );
    }
}

#[test]
fn empty_short_and_non_elf_files_are_empty() {
    for bytes in [vec![], vec![0; 63], vec![0; 8192]] {
        assert_eq!(read(bytes).unwrap(), Metadata::default());
    }
}

#[test]
fn static_elf_needs_no_dynamic_table() {
    for is64 in [false, true] {
        let mut bytes = fixture(is64);
        put(&mut bytes, if is64 { 56 } else { 44 }, 2, 0);
        assert_eq!(read(bytes).unwrap(), Metadata::default());
    }
}

#[test]
fn rejects_bad_class_and_byte_order() {
    for (offset, value) in [(4, 3), (5, 2)] {
        let mut bytes = fixture(true);
        bytes[offset] = value;
        assert!(matches!(read(bytes), Err(NonoError::SandboxInit(_))));
    }
}

#[test]
fn rejects_overflowing_or_out_of_file_header_ranges() {
    for (offset, size, value) in [(32, 8, u64::MAX), (54, 2, 55), (56, 2, u16::MAX as u64)] {
        let mut bytes = fixture(true);
        put(&mut bytes, offset, size, value);
        assert!(read(bytes).is_err());
    }
}

#[test]
fn rejects_segment_ranges_and_address_overflow() {
    for (offset, value) in [
        (64 + 16, u64::MAX),
        (64 + 56 + 8, 8192),
        (64 + 56 + 32, u64::MAX),
    ] {
        let mut bytes = fixture(true);
        put(&mut bytes, offset, 8, value);
        assert!(read(bytes).is_err());
    }
}

#[test]
fn rejects_missing_unbacked_or_oversized_string_table() {
    for (offset, value) in [(512 + 32, 0), (512 + 40, u64::MAX), (512 + 56, 8193)] {
        let mut bytes = fixture(true);
        put(&mut bytes, offset, 8, value);
        assert!(read(bytes).is_err());
    }
}

#[test]
fn rejects_out_of_range_unterminated_and_non_utf8_strings() {
    for (offset, size, value) in [(520, 8, 8192), (512 + 56, 8, 4), (4097, 1, 255)] {
        let mut bytes = fixture(true);
        put(&mut bytes, offset, size, value);
        assert!(read(bytes).is_err());
    }
}

#[test]
fn interpreter_cannot_read_past_declared_segment() {
    let mut bytes = fixture(true);
    put(&mut bytes, 64 + 56 * 2 + 32, 8, 1);
    assert!(read(bytes).is_err());
}

#[test]
fn string_table_without_strsz_uses_file_backed_load_boundary() {
    let mut bytes = fixture(true);
    put(&mut bytes, 512 + 48, 8, 99); // ignore DT_STRSZ
    assert_eq!(read(bytes).unwrap().needed, ["libone.so", "libtwo.so"]);
}

#[test]
fn truncation_after_metadata_returns_unexpected_eof() {
    let file = TestFile::new(&fixture(true));
    let reader = ElfReader::open(&file.path).unwrap();
    file.file.set_len(0).unwrap();
    assert!(matches!(
        reader.region(0, 64),
        Err(NonoError::ConfigRead { source, .. }) if source.kind() == std::io::ErrorKind::UnexpectedEof
    ));
}

#[test]
fn huge_unused_file_body_is_not_read() {
    let file = TestFile::new(&fixture(true));
    file.file.set_len(1 << 40).unwrap(); // sparse 1 TiB file; metadata still small
    let reader = ElfReader::open(&file.path).unwrap();
    let header = reader.region(0, 64).unwrap();
    assert_eq!(
        parse_elf64(&file.path, &header, &reader)
            .unwrap()
            .needed
            .len(),
        2
    );
    assert!(reader.bytes_read() < 2048);
}

#[test]
fn reads_long_strings_from_one_table_buffer() {
    let mut bytes = fixture(true);
    bytes[4097..4397].fill(b'a');
    bytes[4397] = 0;
    put(&mut bytes, 512 + 56, 8, 512);
    let metadata = read(bytes).unwrap();
    assert_eq!(metadata.needed[0], "a".repeat(300));
}

#[test]
fn oversized_metadata_is_rejected_before_read_or_allocation() {
    let file = TestFile::new(&[]);
    file.file.set_len(128 * 1024 * 1024).unwrap();
    let reader = ElfReader::open(&file.path).unwrap();
    assert!(reader.region(0, 64 * 1024 * 1024 + 1).is_err());
    assert_eq!(reader.bytes_read(), 0);
}

#[test]
fn oversized_dynamic_or_string_table_never_falls_back_to_full_read() {
    for dynamic in [true, false] {
        let mut bytes = fixture(true);
        if dynamic {
            put(&mut bytes, 64 + 56 + 32, 8, 64 * 1024 * 1024 + 1);
        } else {
            put(&mut bytes, 64 + 32, 8, 128 * 1024 * 1024);
            put(&mut bytes, 512 + 56, 8, 64 * 1024 * 1024 + 1);
        }
        let file = TestFile::new(&bytes);
        file.file.set_len(128 * 1024 * 1024).unwrap();
        let reader = ElfReader::open(&file.path).unwrap();
        let header = reader.region(0, 64).unwrap();
        assert!(parse_elf64(&file.path, &header, &reader).is_err());
        assert!(reader.bytes_read() < 2048);
    }
}
