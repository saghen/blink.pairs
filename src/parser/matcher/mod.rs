use mlua::IntoLua;

mod angle_bracket;
mod token;
mod token_type;

pub use angle_bracket::*;
pub use token::*;
pub use token_type::*;

use crate::parser::{CharPos, State};

pub trait Matcher {
    const TOKENS: &[u8];

    fn call(
        &mut self,
        matches: &mut Vec<Match>,
        line: &[u8],
        tokens: &[CharPos],
        idx: &mut usize,
        state: State,
        escaped: bool,
    ) -> State;
}

#[derive(Debug, Clone, PartialEq)]
pub struct Match {
    pub kind: Kind,
    pub token: &'static Token,
    pub col: usize,
    pub depth: Option<u16>,
    /// Counts depth specific for this pair, ignoring the depth contributed by other pairs
    pub pair_depth: u16,
}

impl Match {
    pub fn new(kind: Kind, token: &'static Token, col: usize) -> Self {
        Self {
            kind,
            token,
            col,
            depth: None,
            pair_depth: 0,
        }
    }

    pub fn with_line(&self, line: usize) -> MatchWithLine {
        MatchWithLine {
            kind: self.kind,
            token: self.token,
            line,
            col: self.col,
            depth: self.depth,
            pair_depth: self.pair_depth,
        }
    }

    #[expect(clippy::len_without_is_empty)]
    pub fn len(&self) -> usize {
        match self.kind {
            Kind::Opening | Kind::NonPair => self.token.opening().len(),
            Kind::Closing => self
                .token
                .closing()
                .unwrap_or_else(|| self.token.opening())
                .len(),
        }
    }
}

#[cfg(test)]
impl Match {
    pub fn delimiter(char: char, col: usize, depth: Option<u16>) -> Self {
        let (kind, token) = match char {
            '{' => (Kind::Opening, &Token::Delimiter("{", "}")),
            '}' => (Kind::Closing, &Token::Delimiter("{", "}")),
            '[' => (Kind::Opening, &Token::Delimiter("[", "]")),
            ']' => (Kind::Closing, &Token::Delimiter("[", "]")),
            '(' => (Kind::Opening, &Token::Delimiter("(", ")")),
            ')' => (Kind::Closing, &Token::Delimiter("(", ")")),
            '<' => (Kind::Opening, &Token::Delimiter("<", ">")),
            '>' => (Kind::Closing, &Token::Delimiter("<", ">")),
            _ => panic!("Unknown token type"),
        };

        Self {
            kind,
            token,
            col,
            depth,
            // the tests nest a single token, so the pair depths match the depths
            pair_depth: depth.unwrap_or(0),
        }
    }

    pub fn block_comment(text: &'static str, col: usize) -> Self {
        let (kind, token) = match text {
            "/*" => (Kind::Opening, &Token::BlockComment("/*", "*/")),
            "*/" => (Kind::Closing, &Token::BlockComment("/*", "*/")),
            _ => panic!("Unknown token type"),
        };
        Self {
            kind,
            token,
            col,
            depth: None,
            pair_depth: 0,
        }
    }
}

impl IntoLua for Match {
    fn into_lua(self, lua: &mlua::Lua) -> mlua::Result<mlua::Value> {
        let table = lua.create_table()?;

        table.set(1, self.token.opening())?;
        if let Some(closing) = self.token.closing() {
            table.set(2, closing)?;
        }
        match self.token {
            Token::InlineSpan(span, _, _) | Token::BlockSpan(span, _, _) => {
                table.set("span", *span)?;
            }
            _ => {}
        }

        table.set("col", self.col)?;
        table.set("depth", self.depth)?;
        table.set("pair_depth", self.depth.map(|_| self.pair_depth))?;

        (&table).into_lua(lua)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct MatchWithLine {
    pub kind: Kind,
    pub token: &'static Token,
    pub line: usize,
    pub col: usize,
    pub depth: Option<u16>,
    pub pair_depth: u16,
}

impl IntoLua for MatchWithLine {
    fn into_lua(self, lua: &mlua::Lua) -> mlua::Result<mlua::Value> {
        let table = lua.create_table()?;

        table.set(1, self.token.opening())?;
        if let Some(closing) = self.token.closing() {
            table.set(2, closing)?;
        }
        match self.token {
            Token::InlineSpan(span, _, _) | Token::BlockSpan(span, _, _) => {
                table.set("span", *span)?;
            }
            _ => {}
        }

        table.set("line", self.line)?;
        table.set("col", self.col)?;
        table.set("depth", self.depth)?;
        table.set("pair_depth", self.depth.map(|_| self.pair_depth))?;

        (&table).into_lua(lua)
    }
}
