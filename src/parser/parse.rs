use super::matcher::{Match, Matcher};

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

/// The matches on a line, its indentation `(tabs, spaces)` and the parser state at its end
pub type TokenizedLine = (Vec<Match>, (u8, u8), State);

/// Tokenizes each line, tracking the parser state across lines
pub fn tokenize<'a, M: Matcher + 'a>(
    lines: impl Iterator<Item = &'a [u8]> + 'a,
    initial_state: State,
    mut matcher: M,
) -> impl Iterator<Item = TokenizedLine> + 'a {
    let mut mask = [false; 256];
    mask[b'\\' as usize] = true;
    for &token in M::TOKENS {
        mask[token as usize] = true;
    }

    let mut tokens = Vec::new();
    let mut state = initial_state;
    lines.map(move |line| {
        let indent = line
            .iter()
            .take_while(|&&b| b == b' ' || b == b'\t')
            .count();
        let tabs = line[..indent].iter().filter(|&&b| b == b'\t').count();
        let indent = (tabs.min(255) as u8, (indent - tabs).min(255) as u8);

        tokens.clear();
        for (col, &byte) in line.iter().enumerate() {
            if mask[byte as usize] {
                cold_path();
                tokens.push(CharPos { byte, col });
            }
        }

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
                line,
                &tokens,
                &mut idx,
                state,
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
        (line_matches, indent, state)
    })
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
    use crate::parser::{Kind, Match, State, Token, tokenize_filetype};

    fn parse(filetype: &str, lines: &str) -> Vec<Vec<Match>> {
        tokenize_filetype(
            filetype,
            lines.split('\n').map(str::as_bytes),
            State::Normal,
        )
        .unwrap()
        .map(|(matches, _, _)| matches)
        .collect()
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
                vec![Match::new(Kind::NonPair, &Token::LineComment("//"), 0)],
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

    /// Returns the columns of `<` and `>` matched as delimiters, as (col, is_opening)
    fn angle_brackets(lines: &str) -> Vec<Vec<(usize, bool)>> {
        angle_brackets_in("rust", lines)
    }

    fn angle_brackets_in(language: &str, lines: &str) -> Vec<Vec<(usize, bool)>> {
        parse(language, lines)
            .into_iter()
            .map(|matches| {
                matches
                    .into_iter()
                    .filter(|m| *m.token == Token::Delimiter("<", ">"))
                    .map(|m| (m.col, m.kind == Kind::Opening))
                    .collect()
            })
            .collect()
    }

    #[test]
    fn test_rust_angle_brackets() {
        // generics
        assert_eq!(angle_brackets("Vec<T>"), vec![vec![(3, true), (5, false)]]);
        assert_eq!(
            angle_brackets("Vec<Vec<T>>"),
            vec![vec![(3, true), (7, true), (9, false), (10, false)]]
        );
        assert_eq!(
            angle_brackets("Vec::<i32>::new()"),
            vec![vec![(5, true), (9, false)]]
        );
        assert_eq!(angle_brackets("Foo<'a>"), vec![vec![(3, true), (6, false)]]);
        assert_eq!(angle_brackets("Foo<>"), vec![vec![(3, true), (4, false)]]);
        assert_eq!(
            angle_brackets("Box<dyn Fn(i32) -> i32>"),
            vec![vec![(3, true), (22, false)]]
        );
        assert_eq!(
            angle_brackets("<T as Trait>::foo()"),
            vec![vec![(0, true), (11, false)]]
        );
        assert_eq!(
            angle_brackets("Vec<<T as Trait>::Item>"),
            vec![vec![(3, true), (4, true), (15, false), (22, false)]]
        );
        assert_eq!(
            angle_brackets("type X = <<T as A>::B as C>::D;"),
            vec![vec![(9, true), (10, true), (17, false), (26, false)]]
        );

        // operators
        assert_eq!(angle_brackets("a < b"), vec![vec![]]);
        assert_eq!(angle_brackets("a > b"), vec![vec![]]);
        assert_eq!(angle_brackets("a <= b"), vec![vec![]]);
        assert_eq!(angle_brackets("a >= b"), vec![vec![]]);
        assert_eq!(angle_brackets("a << b"), vec![vec![]]);
        assert_eq!(angle_brackets("a >> b"), vec![vec![]]);
        assert_eq!(angle_brackets("a <<= b"), vec![vec![]]);
        assert_eq!(angle_brackets("a >>= b"), vec![vec![]]);
        assert_eq!(angle_brackets("fn foo() -> T"), vec![vec![]]);
        assert_eq!(angle_brackets("Some(x) => x"), vec![vec![]]);
        assert_eq!(
            angle_brackets("Foo<{ N > 0 }>"),
            vec![vec![(3, true), (13, false)]]
        );

        // multi-line generics
        assert_eq!(
            angle_brackets(
                "fn foo<
    T: Into<String>,
>() {}"
            ),
            vec![
                vec![(6, true)],
                vec![(11, true), (18, false)],
                vec![(0, false)]
            ]
        );
        assert_eq!(
            angle_brackets(
                "    impl<
        T,
    > Foo<T> {}"
            ),
            vec![
                vec![(8, true)],
                vec![],
                vec![(4, false), (9, true), (11, false)]
            ]
        );

        // strings, chars and comments
        assert_eq!(angle_brackets("'<' '>' b'<'"), vec![vec![]]);
        assert_eq!(angle_brackets("\"<T>\""), vec![vec![]]);
        assert_eq!(angle_brackets("// Vec<T>"), vec![vec![]]);
        assert_eq!(
            angle_brackets("/* Vec<T> */ Vec<T>"),
            vec![vec![(16, true), (18, false)]]
        );
    }

    #[test]
    fn test_typescript_angle_brackets() {
        let ts = |lines| angle_brackets_in("typescript", lines);
        assert_eq!(
            ts("Map<string, Array<number>>"),
            vec![vec![(3, true), (17, true), (24, false), (25, false)]]
        );
        assert_eq!(
            ts("useState<string>(\"\")"),
            vec![vec![(8, true), (15, false)]]
        );
        assert_eq!(ts("<T,>(x: T) => x"), vec![vec![(0, true), (3, false)]]);
        assert_eq!(ts("<HTMLElement>el"), vec![vec![(0, true), (12, false)]]);
        assert_eq!(ts("a >>> b"), vec![vec![]]);
        assert_eq!(
            ts("const foo = <\n  T,\n>(x: T) => x"),
            vec![vec![(12, true)], vec![], vec![(0, false)]]
        );
        assert_eq!(
            ts("const foo = async <\n  T,\n>(x: T) => x"),
            vec![vec![(18, true)], vec![], vec![(0, false)]]
        );
        assert_eq!(ts("`${a}<${b}>`"), vec![vec![]]);

        let tsx = |lines| angle_brackets_in("typescriptreact", lines);
        assert_eq!(
            tsx("<div>{a < b}</div>"),
            vec![vec![(0, true), (4, false), (12, true), (17, false)]]
        );
        assert_eq!(
            tsx("<p>Loading...</p>"),
            vec![vec![(0, true), (2, false), (13, true), (16, false)]]
        );
        assert_eq!(
            tsx("<Foo\n  onClick={() => x}\n/>"),
            vec![vec![(0, true)], vec![], vec![(1, false)]]
        );
    }

    #[test]
    fn test_swift_angle_brackets() {
        let swift = |lines| angle_brackets_in("swift", lines);
        assert_eq!(swift("Array<Int>"), vec![vec![(5, true), (9, false)]]);
        assert_eq!(swift("for i in 0..<n {}"), vec![vec![]]);
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
                vec![Match::new(Kind::NonPair, &Token::LineComment("%"), 0)]
            ]
        );
    }
}
