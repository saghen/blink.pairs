use mlua::IntoLua;

mod token;
mod token_type;

pub use token::*;
pub use token_type::*;

use crate::parser::{CharPos, State};

pub trait Matcher {
    const TOKENS: &[u8];
    #[inline(always)]
    fn tokens(&self) -> &'static [u8] {
        Self::TOKENS
    }

    fn call(
        &mut self,
        matches: &mut Vec<Match>,
        tokens: &[CharPos],
        idx: &mut usize,
        state: State,
        token: CharPos,
        escaped: bool,
    ) -> State;
}

#[derive(Debug, Clone, PartialEq)]
pub struct Match {
    pub kind: Kind,
    pub token: Token,
    pub col: usize,
    pub stack_height: Option<usize>,
}

impl Match {
    pub fn new(kind: Kind, token: Token, col: usize) -> Self {
        Self {
            kind,
            token,
            col,
            stack_height: None,
        }
    }

    pub fn new_with_stack(kind: Kind, token: Token, col: usize, stack_height: usize) -> Self {
        Self {
            kind,
            token,
            col,
            stack_height: Some(stack_height),
        }
    }

    pub fn with_line(&self, line: usize) -> MatchWithLine {
        MatchWithLine {
            kind: self.kind,
            token: self.token.clone(),
            line,
            col: self.col,
            stack_height: self.stack_height,
        }
    }

    pub fn line_comment(text: &'static str, col: usize) -> Self {
        Self {
            kind: Kind::NonPair,
            token: Token::LineComment(text),
            col,
            stack_height: None,
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
    pub fn delimiter(char: char, col: usize, stack_height: Option<usize>) -> Self {
        let (kind, token) = match char {
            '{' => (Kind::Opening, Token::Delimiter("{", "}")),
            '}' => (Kind::Closing, Token::Delimiter("{", "}")),
            '[' => (Kind::Opening, Token::Delimiter("[", "]")),
            ']' => (Kind::Closing, Token::Delimiter("[", "]")),
            '(' => (Kind::Opening, Token::Delimiter("(", ")")),
            ')' => (Kind::Closing, Token::Delimiter("(", ")")),
            _ => panic!("Unknown token type"),
        };

        Self {
            kind,
            token,
            col,
            stack_height,
        }
    }

    pub fn block_comment(text: &'static str, col: usize) -> Self {
        let (kind, token) = match text {
            "/*" => (Kind::Opening, Token::BlockComment("/*", "*/")),
            "*/" => (Kind::Closing, Token::BlockComment("/*", "*/")),
            _ => panic!("Unknown token type"),
        };
        Self {
            kind,
            token,
            col,
            stack_height: None,
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
                table.set("span", span)?;
            }
            _ => {}
        }

        table.set("col", self.col)?;
        table.set("stack_height", self.stack_height)?;

        (&table).into_lua(lua)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct MatchWithLine {
    pub kind: Kind,
    pub token: Token,
    pub line: usize,
    pub col: usize,
    pub stack_height: Option<usize>,
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
                table.set("span", span)?;
            }
            _ => {}
        }

        table.set("line", self.line)?;
        table.set("col", self.col)?;
        table.set("stack_height", self.stack_height)?;

        (&table).into_lua(lua)
    }
}
