//! I/O only: the ELF parsing remains in platform/linux.rs.
use std::fs::File;
use std::os::unix::fs::FileExt;
use std::path::{Path, PathBuf};

use super::{NonoError, Result};

// Bound each metadata allocation independently of untrusted ELF sizes. No
// fallback to whole-file reads or mmap is used if a region exceeds this limit.
const MAX_METADATA_BYTES: u64 = 64 * 1024 * 1024;

pub(super) struct ElfReader {
    file: File,
    path: PathBuf,
    len: u64,
    #[cfg(test)]
    read_bytes: std::cell::Cell<usize>,
}

impl ElfReader {
    pub(super) fn open(path: &Path) -> Result<Self> {
        let error = |source| NonoError::ConfigRead {
            path: path.to_path_buf(),
            source,
        };
        let file = File::open(path).map_err(error)?;
        let len = file.metadata().map_err(error)?.len();
        Ok(Self {
            file,
            path: path.to_path_buf(),
            len,
            #[cfg(test)]
            read_bytes: std::cell::Cell::new(0),
        })
    }

    pub(super) fn len(&self) -> u64 {
        self.len
    }

    pub(super) fn check_range(&self, offset: u64, size: u64) -> Result<()> {
        match offset.checked_add(size) {
            Some(end) if end <= self.len => Ok(()),
            _ => Err(NonoError::SandboxInit("ELF range outside file".into())),
        }
    }

    fn read_into(&self, offset: u64, bytes: &mut [u8]) -> Result<()> {
        self.check_range(offset, bytes.len() as u64)?;
        self.file
            .read_exact_at(bytes, offset)
            .map_err(|source| NonoError::ConfigRead {
                path: self.path.clone(),
                source,
            })?;
        #[cfg(test)]
        self.read_bytes.set(self.read_bytes.get() + bytes.len());
        Ok(())
    }

    pub(super) fn program_header<const N: usize>(
        &self,
        start: u64,
        index: usize,
        stride: usize,
    ) -> Result<[u8; N]> {
        if stride < N {
            return Err(NonoError::SandboxInit(
                "ELF program header entry too small".into(),
            ));
        }
        let offset = (index as u64)
            .checked_mul(stride as u64)
            .and_then(|relative| start.checked_add(relative))
            .ok_or_else(|| NonoError::SandboxInit("ELF program header offset overflow".into()))?;
        let mut bytes = [0u8; N];
        self.read_into(offset, &mut bytes)?;
        Ok(bytes)
    }

    pub(super) fn region(&self, offset: u64, size: u64) -> Result<Vec<u8>> {
        self.check_range(offset, size)?;
        if size > MAX_METADATA_BYTES {
            return Err(NonoError::SandboxInit(
                "ELF metadata region exceeds 64 MiB limit".into(),
            ));
        }
        let size = usize::try_from(size)
            .map_err(|_| NonoError::SandboxInit("ELF metadata size overflow".into()))?;
        let mut bytes = Vec::new();
        bytes
            .try_reserve_exact(size)
            .map_err(|_| NonoError::SandboxInit("ELF metadata allocation failed".into()))?;
        bytes.resize(size, 0);
        self.read_into(offset, &mut bytes)?;
        Ok(bytes)
    }

    #[cfg(test)]
    pub(super) fn bytes_read(&self) -> usize {
        self.read_bytes.get()
    }
}
