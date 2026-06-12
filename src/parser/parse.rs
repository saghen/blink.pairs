use crate::buffer::ParsedBuffer;

use super::matcher::Matcher;

#[derive(Debug, Clone, Copy)]
pub struct CharPos {
    pub byte: u8,
    pub col: usize,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum State {
    Normal,
    InString(&'static str),
    InBlockString(&'static str),
    InLineComment,
    InBlockComment(&'static str),
    InInlineSpan(&'static str),
    InBlockSpan(&'static str),
}

/// Given a matcher, runs the tokenizer on the lines and keeps track
/// of the state and matches for each line
pub fn parse<M: Matcher>(lines: &[&str], initial_state: State, mut matcher: M) -> ParsedBuffer {
    let mut matches_by_line = Vec::with_capacity(lines.len());
    let mut indents_by_line = Vec::with_capacity(lines.len());
    let mut state_by_line = Vec::with_capacity(lines.len());

    let mut mask = [false; 256];
    mask[b'\\' as usize] = true;
    for &token in M::TOKENS {
        mask[token as usize] = true;
    }

    let mut tokens = Vec::new();
    let mut last_indent = None;
    let mut state = initial_state;
    for line in lines {
        let mut tabs: u8 = 0;
        let mut spaces: u8 = 0;

        tokens.clear();
        let mut found_non_whitespace = false;
        for (col, &byte) in line.as_bytes().iter().enumerate() {
            if !found_non_whitespace {
                cold_path();
                match byte {
                    b'\t' => tabs = tabs.saturating_add(1),
                    b' ' => spaces = spaces.saturating_add(1),
                    _ => found_non_whitespace = true,
                }
            }
            if mask[byte as usize] {
                cold_path();
                tokens.push(CharPos { byte, col });
            }
        }
        if !found_non_whitespace {
            cold_path();
            // this line is entirely whitespace, so use the previous line's indentation.
            indents_by_line.push(last_indent.unwrap_or((tabs, spaces)));
        } else {
            indents_by_line.push((tabs, spaces));
        }
        last_indent = Some((tabs, spaces));

        let mut line_matches = Vec::new();
        let mut escaped_col = None;
        let mut idx = 0;
        while idx < tokens.len() {
            let token = tokens[idx];
            if token.byte == b'\\' {
                if let Some(col) = escaped_col
                    && col == token.col - 1
                {
                    escaped_col = None;
                } else {
                    escaped_col = Some(token.col);
                }
                idx += 1;
                continue;
            }

            state = matcher.call(
                &mut line_matches,
                &tokens,
                &mut idx,
                state,
                token,
                escaped_col.map(|col| col == token.col - 1).unwrap_or(false),
            );
            idx += 1;

            // Once we're in a line comment, nothing else on this line can match.
            if state == State::InLineComment {
                break;
            }
        }

        if matches!(
            state,
            State::InString(_) | State::InLineComment | State::InInlineSpan(_)
        ) {
            state = State::Normal;
        }
        matches_by_line.push(line_matches);
        state_by_line.push(state);
    }

    ParsedBuffer {
        matches_by_line,
        indents_by_line,
        state_by_line,
    }
}

/// [`std::hint::cold_path`] intrinsic, when it is available (i.e., rust is at
/// least 1.95.0).
///
/// NOTE: remove this and use [`std::hint::cold_path`] once rust 1.95.0 is
/// sufficiently old (for instance, once it's available in debian)
#[inline(always)]
fn cold_path() {
    // See build.rs for the definition of have_cold_path.
    #[cfg(have_cold_path)]
    std::hint::cold_path();
}

// TODO: come up with a better way to do testing
#[cfg(test)]
mod tests {
    use crate::parser::{Match, State, parse_filetype};

    fn parse(filetype: &str, lines: &str) -> Vec<Vec<Match>> {
        parse_filetype(
            filetype,
            &lines.split('\n').collect::<Vec<_>>(),
            State::Normal,
        )
        .unwrap()
        .matches_by_line
    }

    #[test]
    fn test_parse() {
        assert_eq!(
            parse("c", "{\n}"),
            vec![
                vec![Match::delimiter('{', 0, None)],
                vec![Match::delimiter('}', 0, None)]
            ]
        );

        assert_eq!(
            parse("c", "// comment {}\n}"),
            vec![
                vec![Match::line_comment("//", 0)],
                vec![Match::delimiter('}', 0, None)],
            ]
        );

        assert_eq!(
            parse("c", "/* comment {} */\n}"),
            vec![
                vec![
                    Match::block_comment("/*", 0),
                    Match::block_comment("*/", 14)
                ],
                vec![Match::delimiter('}', 0, None)]
            ]
        );
    }

    #[test]
    fn test_tex() {
        assert_eq!(
            parse("tex", "test 90\\% ( and b )\n%abc"),
            vec![
                vec![
                    Match::delimiter('(', 10, None),
                    Match::delimiter(')', 18, None)
                ],
                vec![Match::line_comment("%", 0)]
            ]
        );
    }
}
