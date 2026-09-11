use mlua::prelude::*;

use super::Token;

#[derive(Debug, Clone, Copy, PartialEq)]
#[repr(u8)]
pub enum TokenType {
    Delimiter = 0,
    String = 1,
    BlockString = 2,
    LineComment = 3,
    BlockComment = 4,
    InlineSpan = 5,
    BlockSpan = 6,
}

impl TokenType {
    pub fn matches(&self, token: &Token) -> bool {
        *self == TokenType::from(token)
    }
}

impl From<&Token> for TokenType {
    fn from(token: &Token) -> Self {
        match token {
            Token::Delimiter(_, _) => TokenType::Delimiter,
            Token::String(_) => TokenType::String,
            Token::BlockString(_, _) => TokenType::BlockString,
            Token::LineComment(_) => TokenType::LineComment,
            Token::BlockComment(_, _) => TokenType::BlockComment,
            Token::InlineSpan(_, _, _) => TokenType::InlineSpan,
            Token::BlockSpan(_, _, _) => TokenType::BlockSpan,
        }
    }
}

impl TryFrom<u8> for TokenType {
    type Error = ();

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(TokenType::Delimiter),
            1 => Ok(TokenType::String),
            2 => Ok(TokenType::BlockString),
            3 => Ok(TokenType::LineComment),
            4 => Ok(TokenType::BlockComment),
            5 => Ok(TokenType::InlineSpan),
            6 => Ok(TokenType::BlockSpan),
            _ => Err(()),
        }
    }
}

impl TryFrom<&str> for TokenType {
    type Error = ();

    fn try_from(name: &str) -> Result<Self, Self::Error> {
        match name {
            "delimiter" => Ok(TokenType::Delimiter),
            "string" => Ok(TokenType::String),
            "block_string" => Ok(TokenType::BlockString),
            "line_comment" => Ok(TokenType::LineComment),
            "block_comment" => Ok(TokenType::BlockComment),
            "inline_span" => Ok(TokenType::InlineSpan),
            "block_span" => Ok(TokenType::BlockSpan),
            _ => Err(()),
        }
    }
}

/// Set of token types, bit `n` is set for the type with discriminant `n`
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TokenTypes(pub u8);

impl TokenTypes {
    pub const ALL: Self = Self(u8::MAX);

    pub fn contains(&self, token: &Token) -> bool {
        self.0 & (1 << TokenType::from(token) as u8) != 0
    }
}

/// `nil` for every type, otherwise a type name or a list of them
impl FromLua for TokenTypes {
    fn from_lua(value: LuaValue, lua: &Lua) -> LuaResult<Self> {
        let names: Vec<String> = match value {
            LuaValue::Nil => return Ok(Self::ALL),
            LuaValue::String(name) => vec![name.to_str()?.to_string()],
            value => lua.unpack(value)?,
        };
        let mut types = 0;
        for name in names {
            let Ok(token_type) = TokenType::try_from(name.as_str()) else {
                return Err(LuaError::runtime(format!("unknown token type `{name}`")));
            };
            types |= 1 << token_type as u8;
        }
        Ok(Self(types))
    }
}
