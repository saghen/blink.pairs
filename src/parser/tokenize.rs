use fearless_simd::{dispatch, Level, Select, Simd, SimdBase, SimdInt};

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CharPos {
    pub byte: u8,
    pub col: usize,
}

impl CharPos {
    pub fn new(byte: u8, col: usize) -> Self {
        Self { byte, col }
    }
}

/// Prepare lines for tokenization by joining them with newlines and padding the
/// result to the next multiple of the simd width
pub fn join_lines(lines: &[&str]) -> Vec<u8> {
    let len = lines.iter().map(|l| l.len()).sum::<usize>() + lines.len().saturating_sub(1);
    // pad to 64, which is an upper bound on the SIMD width
    let len = len.next_multiple_of(64);
    let mut lines = lines.iter();
    if let Some(line) = lines.next() {
        let mut text = Vec::<u8>::with_capacity(len);
        text.extend_from_slice(line.as_bytes());
        for line in lines {
            text.push(b'\n');
            text.extend_from_slice(line.as_bytes());
        }
        text.extend(std::iter::repeat_n(0, len - text.len()));
        text
    } else {
        Vec::new()
    }
}

/// Takes input text and uses SIMD to find the provided list of tokens in the text
/// returning the byte and column position of each token. You can get the row by counting
/// every incoming `\n` token
pub fn tokenize(text: &[u8], tokens: &'static [u8]) -> Vec<CharPos> {
    let level = Level::new();
    dispatch!(level, simd => tokenize_impl(simd, text, tokens))
}

#[inline(always)]
fn tokenize_impl<S: Simd>(simd: S, text: &[u8], tokens: &'static [u8]) -> Vec<CharPos> {
    assert!(text.len().is_multiple_of(S::u8s::N));
    let new_line = S::u8s::splat(simd, b'\n');
    let escape = S::u8s::splat(simd, b'\\');

    let tokens_to_find = tokens
        .iter()
        .flat_map(|&c| {
            match c {
                // Enabled by default, ignore
                0 | b'\n' | b'\\' => None,

                _ => Some(S::u8s::splat(simd, c)),
            }
        })
        .collect::<Vec<_>>();

    let mut result = Vec::with_capacity(text.len() / 64);
    let mut col_offset = 0usize;

    for (chunk_idx, chunk_bytes) in text.chunks_exact(S::u8s::N).enumerate() {
        let chunk = S::u8s::from_slice(simd, chunk_bytes);
        let mut mask = new_line.simd_eq(chunk);
        mask |= escape.simd_eq(chunk);
        for &char in tokens_to_find.iter() {
            mask |= char.simd_eq(chunk);
        }
        let tokens = mask.select(chunk, S::u8s::splat(simd, 0));

        let chunk_col = chunk_idx * S::u8s::N;
        for (idx_in_chunk, &byte) in tokens.as_slice().iter().enumerate() {
            match byte {
                0 => {}
                b'\n' => {
                    col_offset = chunk_col + idx_in_chunk + 1;
                    result.push(CharPos {
                        byte: b'\n',
                        col: 0,
                    });
                }
                byte => {
                    result.push(CharPos {
                        byte,
                        col: chunk_col + idx_in_chunk - col_offset,
                    });
                }
            }
        }
    }

    result
}

// TODO: come up with a better way to do testing
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenize() {
        let text = join_lines(&[
            "use crate::r#const::*;",
            "use std::ops::Not;",
            "use std::simd::cmp::*;",
            "use std::simd::num::SimdUint;",
            "use std::simd::{Mask, Simd};",
        ]);

        assert_eq!(
            tokenize(&text, b"(){}"),
            vec![
                CharPos::new(b'\n', 0),
                CharPos::new(b'\n', 0),
                CharPos::new(b'\n', 0),
                CharPos::new(b'\n', 0),
                CharPos::new(b'{', 15),
                CharPos::new(b'}', 26),
            ]
        );
    }
}
