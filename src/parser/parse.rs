use itertools::Itertools;

use crate::{
    buffer::ParsedBuffer,
    parser::{indent::indent_levels, tokenize::join_lines},
};

use super::{matcher::Matcher, tokenize::tokenize};

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
pub fn parse<M: Matcher>(
    tab_width: u8,
    lines: &[&str],
    initial_state: State,
    mut matcher: M,
) -> ParsedBuffer {
    // State
    let mut matches_by_line = Vec::with_capacity(lines.len());
    let mut line_matches = vec![];

    let mut state_by_line = Vec::with_capacity(lines.len());
    let mut state = initial_state;

    let mut escaped_col: Option<usize> = None;

    let text = join_lines(lines);
    let tokens = tokenize(&text, matcher.tokens());
    let indent_levels = indent_levels(lines, tab_width);

    let mut tokens = tokens.into_iter().multipeek();

    while let Some(token) = tokens.next() {
        // New line
        if matches!(token.byte, b'\n') {
            matches_by_line.push(line_matches);
            line_matches = vec![];
            escaped_col = None;

            if matches!(
                state,
                State::InString(_) | State::InLineComment | State::InInlineSpan(_)
            ) {
                state = State::Normal;
            }
            state_by_line.push(state);
            continue;
        }

        if matches!(token.byte, b'\\') {
            if let Some(col) = escaped_col {
                if col == token.col - 1 {
                    escaped_col = None;
                    continue;
                }
            }
            escaped_col = Some(token.col);
            continue;
        }

        state = matcher.call(
            &mut matches_by_line,
            &mut line_matches,
            &mut tokens,
            state,
            token,
            escaped_col.map(|col| col == token.col - 1).unwrap_or(false),
        );
    }
    matches_by_line.push(line_matches);
    state_by_line.push(state);

    ParsedBuffer {
        matches_by_line,
        state_by_line,
        indent_levels,
    }
}

// TODO: come up with a better way to do testing
#[cfg(test)]
mod tests {
    use crate::parser::{parse_filetype, Match, State};

    fn parse(filetype: &str, lines: &str) -> Vec<Vec<Match>> {
        parse_filetype(
            filetype,
            4,
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
                vec![Match::delimiter('{', 0, Some(0))],
                vec![Match::delimiter('}', 0, Some(0))]
            ]
        );

        assert_eq!(
            parse("c", "// comment {}\n}"),
            vec![
                vec![Match::line_comment("//", 0)],
                vec![Match::delimiter('}', 0, Some(0))],
            ]
        );

        assert_eq!(
            parse("c", "/* comment {} */\n}"),
            vec![
                vec![
                    Match::block_comment("/*", 0),
                    Match::block_comment("*/", 14)
                ],
                vec![Match::delimiter('}', 0, Some(0))]
            ]
        );
    }

    #[test]
    fn test_tex() {
        assert_eq!(
            parse("tex", "test 90\\% ( and b )\n%abc"),
            vec![
                vec![
                    Match::delimiter('(', 10, Some(0)),
                    Match::delimiter(')', 18, Some(0))
                ],
                vec![Match::line_comment("%", 0)]
            ]
        );
    }
}
