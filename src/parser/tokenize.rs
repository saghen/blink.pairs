use std::{cell::Cell, rc::Rc, sync::LazyLock};

use fearless_simd::{Level, Select as _, Simd, SimdBase, SimdInt as _};

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
#[inline]
pub fn tokenize<'s>(
    text: &'s [u8],
    tokens: &'static [u8],
) -> Box<dyn Iterator<Item = CharPos> + 's> {
    static LEVEL: LazyLock<Level> = LazyLock::new(Level::new);
    let level = *LEVEL;
    fearless_simd::dispatch!(level, simd => tokenize_impl(simd, text, tokens))
}

#[inline(always)]
fn tokenize_impl<'s, S: Simd>(
    simd: S,
    text: &'s [u8],
    tokens: &'static [u8],
) -> Box<dyn Iterator<Item = CharPos> + 's> {
    assert!(text.len().is_multiple_of(S::u8s::N));
    let none = S::u8s::splat(simd, 0);
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

    // TODO: must use Rc and Cell here since we need to mutate the value inside a closure
    // which uses `move`, so otherwise we would copy, and the value would be reset on every
    // chunk
    let col_offset = Rc::new(Cell::new(0));
    let iter = text
        .chunks_exact(S::u8s::N)
        .map(move |c| S::u8s::from_slice(simd, c))
        .enumerate()
        .flat_map(move |(chunk_idx, chunk)| {
            let mut tokens = none;
            tokens |= new_line.simd_eq(chunk).select(new_line, none);
            tokens |= escape.simd_eq(chunk).select(escape, none);

            for &char in tokens_to_find.iter() {
                tokens |= char.simd_eq(chunk).select(char, none);
            }

            // Apply parsed tokens
            let chunk_col = chunk_idx * S::u8s::N;
            let col_offset = col_offset.clone();
            (0..S::u8s::N)
                .map(move |i| (i, tokens[i]))
                .flat_map(move |(idx_in_chunk, byte)| match byte {
                    0 => None,
                    b'\n' => {
                        col_offset.set(chunk_col + idx_in_chunk + 1);

                        Some(CharPos {
                            byte: b'\n',
                            col: 0,
                        })
                    }
                    byte => Some(CharPos {
                        byte,
                        col: chunk_col + idx_in_chunk - col_offset.get(),
                    }),
                })
        });
    Box::new(iter)
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
            tokenize(&text, b"(){}").collect::<Vec<_>>(),
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
