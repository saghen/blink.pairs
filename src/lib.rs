use mlua::prelude::*;
use parser::matcher::TokenType;
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex, MutexGuard};

use buffer::ParsedBuffer;
use parser::{Match, MatchWithLine};

pub mod buffer;
pub mod parser;

static PARSED_BUFFERS: LazyLock<Mutex<HashMap<usize, ParsedBuffer>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn get_parsed_buffers<'a>() -> MutexGuard<'a, HashMap<usize, ParsedBuffer>> {
    // a poisoned lock only means a previous call panicked, the buffers are still usable
    PARSED_BUFFERS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Parses `text`, the lines `start_line..new_end_line` joined by newlines, replacing
/// `start_line..old_end_line`. Parses the whole buffer when the range is omitted. Returns whether
/// the filetype is supported and the range of lines whose matches may have changed.
fn parse_buffer(
    _lua: &Lua,
    (bufnr, tab_width, filetype, text, start_line, old_end_line, new_end_line): (
        usize,
        u8,
        String,
        LuaString,
        Option<usize>,
        Option<usize>,
        Option<usize>,
    ),
) -> LuaResult<(bool, usize, usize)> {
    let mut lines: Vec<Box<[u8]>> = text
        .as_bytes()
        .split(|&b| b == b'\n')
        .map(Box::from)
        .collect();
    // an empty string splits into one empty line, which is wrong when no lines were sent
    if let (Some(start), Some(end)) = (start_line, new_end_line) {
        lines.truncate(end.saturating_sub(start));
    }

    let mut parsed_buffers = get_parsed_buffers();
    let dirty = match (start_line, parsed_buffers.get_mut(&bufnr)) {
        (Some(start_line), Some(parsed_buffer)) => parsed_buffer.reparse_range(
            &filetype,
            tab_width,
            lines,
            start_line,
            old_end_line.unwrap_or(usize::MAX),
        ),
        _ => ParsedBuffer::parse(&filetype, tab_width, lines).map(|parsed_buffer| {
            let dirty = 0..parsed_buffer.lines.len();
            parsed_buffers.insert(bufnr, parsed_buffer);
            dirty
        }),
    };
    Ok(match dirty {
        Some(dirty) => (true, dirty.start, dirty.end),
        None => (false, 0, 0),
    })
}

fn remove_buffer(_lua: &Lua, (bufnr,): (usize,)) -> LuaResult<()> {
    get_parsed_buffers().remove(&bufnr);
    Ok(())
}

fn supports_filetype(_lua: &Lua, (filetype,): (String,)) -> LuaResult<bool> {
    Ok(ParsedBuffer::supports_filetype(&filetype))
}

fn get_line_matches(
    _lua: &Lua,
    (bufnr, line_number, token_type): (usize, usize, Option<u8>),
) -> LuaResult<Vec<Match>> {
    let parsed_buffers = get_parsed_buffers();
    let token_type = token_type
        // TODO: don't ignore the error
        .and_then(|token_type| token_type.try_into().ok())
        .unwrap_or(TokenType::Delimiter);

    Ok(parsed_buffers
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.matches_by_line.get(line_number))
        .map_or(Vec::new(), |matches| {
            matches
                .iter()
                .filter(|m| token_type.matches(m.token))
                .cloned()
                .collect()
        }))
}

fn get_span_at(_lua: &Lua, (bufnr, row, col): (usize, usize, usize)) -> LuaResult<Option<String>> {
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.span_at(row, col)))
}

fn get_match_at(_lua: &Lua, (bufnr, row, col): (usize, usize, usize)) -> LuaResult<Option<Match>> {
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.match_at(row, col)))
}

fn get_match_pair(
    _lua: &Lua,
    (bufnr, row, col): (usize, usize, usize),
) -> LuaResult<Option<Vec<MatchWithLine>>> {
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.match_pair(row, col))
        .map(|(open, close)| vec![open, close]))
}

fn get_surrounding_match_pair(
    _lua: &Lua,
    (bufnr, row, col, between): (usize, usize, usize, Option<bool>),
) -> LuaResult<Option<Vec<MatchWithLine>>> {
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| {
            parsed_buffer.surrounding_match_pair(row, col, between.unwrap_or(false))
        })
        .map(|(open, close)| vec![open, close]))
}

fn get_unmatched_opening_before(
    _lua: &Lua,
    (bufnr, opening, closing, row, col): (usize, LuaString, LuaString, usize, usize),
) -> LuaResult<Option<MatchWithLine>> {
    let (Ok(opening), Ok(closing)) = (opening.to_str(), closing.to_str()) else {
        return Ok(None);
    };
    Ok(get_parsed_buffers().get(&bufnr).and_then(|parsed_buffer| {
        parsed_buffer.unmatched_opening_before(&opening, &closing, row, col)
    }))
}

fn get_unmatched_closing_after(
    _lua: &Lua,
    (bufnr, opening, closing, row, col): (usize, LuaString, LuaString, usize, usize),
) -> LuaResult<Option<MatchWithLine>> {
    let (Ok(opening), Ok(closing)) = (opening.to_str(), closing.to_str()) else {
        return Ok(None);
    };
    Ok(get_parsed_buffers().get(&bufnr).and_then(|parsed_buffer| {
        parsed_buffer.unmatched_closing_after(&opening, &closing, row, col)
    }))
}

fn get_unterminated_opening_before(
    _lua: &Lua,
    (bufnr, opening, row, col): (usize, LuaString, usize, usize),
) -> LuaResult<Option<MatchWithLine>> {
    let Ok(opening) = opening.to_str() else {
        return Ok(None);
    };
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.unterminated_opening_before(&opening, row, col)))
}

fn get_unterminated_opening_after(
    _lua: &Lua,
    (bufnr, opening, row, col): (usize, LuaString, usize, usize),
) -> LuaResult<Option<MatchWithLine>> {
    let Ok(opening) = opening.to_str() else {
        return Ok(None);
    };
    Ok(get_parsed_buffers()
        .get(&bufnr)
        .and_then(|parsed_buffer| parsed_buffer.unterminated_opening_after(&opening, row, col)))
}

// NOTE: skip_memory_check greatly improves performance
// https://github.com/mlua-rs/mlua/issues/318
#[mlua::lua_module(skip_memory_check)]
fn blink_pairs_parser(lua: &Lua) -> LuaResult<LuaTable> {
    // panics throw a lua error, add a hook so we don't also println them
    std::panic::set_hook(Box::new(|_| {}));

    let exports = lua.create_table()?;
    exports.set("parse_buffer", lua.create_function(parse_buffer)?)?;
    exports.set("remove_buffer", lua.create_function(remove_buffer)?)?;
    exports.set("supports_filetype", lua.create_function(supports_filetype)?)?;
    exports.set("get_line_matches", lua.create_function(get_line_matches)?)?;
    exports.set("get_span_at", lua.create_function(get_span_at)?)?;
    exports.set("get_match_at", lua.create_function(get_match_at)?)?;
    exports.set("get_match_pair", lua.create_function(get_match_pair)?)?;
    exports.set(
        "get_surrounding_match_pair",
        lua.create_function(get_surrounding_match_pair)?,
    )?;
    exports.set(
        "get_unmatched_opening_before",
        lua.create_function(get_unmatched_opening_before)?,
    )?;
    exports.set(
        "get_unmatched_closing_after",
        lua.create_function(get_unmatched_closing_after)?,
    )?;
    exports.set(
        "get_unterminated_opening_before",
        lua.create_function(get_unterminated_opening_before)?,
    )?;
    exports.set(
        "get_unterminated_opening_after",
        lua.create_function(get_unterminated_opening_after)?,
    )?;
    Ok(exports)
}
