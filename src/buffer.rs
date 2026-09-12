use crate::parser::{
    Kind, Match, MatchWithLine, State, Token, TokenTypes, supports_filetype, tokenize_filetype,
};
use mlua::prelude::*;
use std::iter::repeat_n;
use std::ops::Range;

/// How often (in lines) to snapshot the delimiter stack, so that incremental updates can
/// resume from the nearest snapshot instead of the start of the buffer
const CHECKPOINT_INTERVAL: usize = 32;

/// Depths saturate at `u16::MAX`
fn to_depth(stack_len: usize) -> u16 {
    u16::try_from(stack_len).unwrap_or(u16::MAX)
}

/// Pairs whose nesting is counted separately from the rest, see `highlights.separate`
#[derive(Debug, Clone, Default, PartialEq)]
pub enum Separate {
    #[default]
    None,
    All,
    Openings(Vec<String>),
}

impl Separate {
    fn contains(&self, token: &Token) -> bool {
        let opening = token.opening();
        match self {
            Separate::None => false,
            Separate::All => true,
            // Most tokens don't match, so check the first byte before comparing the strings
            Separate::Openings(openings) => openings
                .iter()
                .any(|o| o.as_bytes().first() == opening.as_bytes().first() && o == opening),
        }
    }

    /// The pairs counted by a pair's `pair_depth`: only its own token when separate, otherwise
    /// every token that isn't
    fn group(&self, token: &'static Token) -> Option<&'static Token> {
        self.contains(token).then_some(token)
    }
}

/// A delimiter stack entry: the token, its group (see `Separate::group`) and pair depth
type StackEntry = (&'static Token, Option<&'static Token>, u16);

/// `nil` or `false` for none, `true` for all, otherwise an opening or a list of them
impl FromLua for Separate {
    fn from_lua(value: LuaValue, lua: &Lua) -> LuaResult<Self> {
        Ok(match value {
            LuaValue::Nil | LuaValue::Boolean(false) => Self::None,
            LuaValue::Boolean(true) => Self::All,
            LuaValue::String(opening) => Self::Openings(vec![opening.to_str()?.to_string()]),
            value => Self::Openings(lua.unpack(value)?),
        })
    }
}

#[derive(Default)]
pub struct ParsedBuffer {
    pub lines: Vec<Box<[u8]>>,
    pub matches_by_line: Vec<Vec<Match>>,
    pub indents_by_line: Vec<(u8, u8)>,
    pub state_by_line: Vec<State>,
    /// `(line, stack)`: the delimiter stack at the start of `line`, sorted by line
    checkpoints: Vec<(usize, Vec<StackEntry>)>,
    separate: Separate,
    /// Whether every delimiter is matched, in which case depths can be updated
    /// incrementally
    balanced: bool,
    /// Whether an edit deferred the depth calculation, see `ensure_depths`
    stale_depths: bool,
    tab_width: u8,
}

impl ParsedBuffer {
    pub fn supports_filetype(filetype: &str) -> bool {
        supports_filetype(filetype)
    }

    pub fn parse(
        filetype: &str,
        tab_width: u8,
        lines: Vec<Box<[u8]>>,
        separate: Separate,
    ) -> Option<Self> {
        let mut parsed = Self {
            separate,
            ..Self::default()
        };
        parsed.reparse_range(filetype, tab_width, lines, 0, 0)?;
        parsed.ensure_depths();
        Some(parsed)
    }

    /// Replaces `start_line..old_end_line` with `lines` and reparses. Returns the range of lines
    /// whose matches may have changed, or `None` if the filetype is unsupported.
    pub fn reparse_range(
        &mut self,
        filetype: &str,
        tab_width: u8,
        lines: Vec<Box<[u8]>>,
        start_line: usize,
        old_end_line: usize,
    ) -> Option<Range<usize>> {
        let start = start_line.min(self.lines.len());
        let old_end = old_end_line.clamp(start, self.lines.len());
        // Deleting every line leaves nvim with a single empty line, but it reports zero lines
        // Create one empty line so we don't desync when new lines are added
        let lines = if lines.is_empty() && start == 0 && old_end == self.lines.len() {
            vec![Box::default()]
        } else {
            lines
        };
        let new_end = start + lines.len();

        let state_before = |line: usize| match line.checked_sub(1) {
            Some(line) => self.state_by_line[line],
            None => State::Normal,
        };
        let initial_state = state_before(start);
        let old_end_state = state_before(old_end);

        let count = new_end - start;
        self.lines.splice(start..old_end, lines);
        self.matches_by_line
            .splice(start..old_end, repeat_n(Vec::new(), count));
        self.indents_by_line
            .splice(start..old_end, repeat_n((0, 0), count));
        self.state_by_line
            .splice(start..old_end, repeat_n(State::Normal, count));

        // Tokenize the new lines, continuing past them while the state at the end of the line
        // differs from before the edit (e.g. after opening a block comment)
        let tokenizer = tokenize_filetype(
            filetype,
            self.lines[start..].iter().map(|line| &**line),
            initial_state,
        )?;
        let mut end = start;
        for (line, (matches, indent, state)) in (start..).zip(tokenizer) {
            let old_state = if line < new_end {
                old_end_state
            } else {
                self.state_by_line[line]
            };
            self.matches_by_line[line] = matches;
            self.indents_by_line[line] = indent;
            self.state_by_line[line] = state;
            end = line + 1;
            if line + 1 >= new_end && state == old_state {
                break;
            }
        }

        let delta = new_end as isize - old_end as isize;
        if let Some(dirty) = self.incremental_depths(start..end, old_end, delta) {
            return Some(dirty);
        }

        // An unbalanced buffer needs the full depth pass, which is deferred until the next
        // query so that a burst of edits (e.g. undoing a `:substitute` sends one event per line)
        // only pays for it once. Any line's depth may change, so report them all
        self.balanced = false;
        self.stale_depths = true;
        self.tab_width = tab_width;
        Some(0..self.lines.len())
    }

    /// Runs the depth calculation deferred by `reparse_range`
    pub fn ensure_depths(&mut self) {
        if self.stale_depths {
            self.stale_depths = false;
            self.calculate_depths(self.tab_width);
        }
    }

    /// Fast path for balanced buffers: replays the stack from the nearest checkpoint before the
    /// edit, and stops at the first checkpoint after it whose stack is unchanged. Returns the
    /// lines whose depths changed, or `None` if the buffer is unbalanced.
    fn incremental_depths(
        &mut self,
        retokenized: Range<usize>,
        old_end: usize,
        delta: isize,
    ) -> Option<Range<usize>> {
        if !self.balanced {
            return None;
        }

        // Checkpoints inside the edited region are stale, those after it shift with the edit
        let cp = self
            .checkpoints
            .partition_point(|(line, _)| *line <= retokenized.start)
            - 1;
        let stale_end = self.checkpoints.partition_point(|&(line, _)| {
            line <= retokenized.start
                || line < old_end
                || (line as isize + delta) < retokenized.end as isize
        });
        for checkpoint in &mut self.checkpoints[stale_end..] {
            checkpoint.0 = (checkpoint.0 as isize + delta) as usize;
        }

        let (cp_line, mut stack) = self.checkpoints[cp].clone();
        let mut new_checkpoints = vec![];
        let mut next = stale_end;
        // Depths are only written once we know the buffer is still balanced
        let mut updates = vec![];
        for line in cp_line.. {
            if line < retokenized.end {
                if line > cp_line && line % CHECKPOINT_INTERVAL == 0 {
                    new_checkpoints.push((line, stack.clone()));
                }
            } else if let Some((_, old_stack)) =
                self.checkpoints.get_mut(next).filter(|(l, _)| *l == line)
            {
                if *old_stack == stack {
                    break;
                }
                // A different depth almost always means an unmatched delimiter was added or
                // removed, which we'd otherwise only find out at the end of the buffer
                if old_stack.len() != stack.len() {
                    return None;
                }
                *old_stack = stack.clone();
                next += 1;
            }

            let Some(matches) = self.matches_by_line.get(line) else {
                // Reached the end of the buffer, every delimiter must be closed
                if stack.is_empty() {
                    break;
                }
                return None;
            };
            for (i, match_) in matches.iter().enumerate() {
                let (depth, pair_depth) = match match_.kind {
                    Kind::Opening => {
                        let group = self.separate.group(match_.token);
                        // One deeper than the nearest enclosing pair of the same group
                        let pair_depth = stack
                            .iter()
                            .rev()
                            .find(|(_, other, _)| *other == group)
                            .map_or(0, |(_, _, pair_depth)| pair_depth.saturating_add(1));
                        stack.push((match_.token, group, pair_depth));
                        (to_depth(stack.len() - 1), pair_depth)
                    }
                    Kind::Closing => match stack.pop() {
                        Some((token, _, pair_depth)) if token == match_.token => {
                            (to_depth(stack.len()), pair_depth)
                        }
                        _ => return None,
                    },
                    Kind::NonPair => continue,
                };
                if (match_.depth, match_.pair_depth) != (Some(depth), pair_depth) {
                    updates.push((line, i, depth, pair_depth));
                }
            }
        }

        self.checkpoints.splice(cp + 1..stale_end, new_checkpoints);
        let mut dirty = retokenized;
        for &(line, i, depth, pair_depth) in &updates {
            let match_ = &mut self.matches_by_line[line][i];
            match_.depth = Some(depth);
            match_.pair_depth = pair_depth;
            dirty.start = dirty.start.min(line);
            dirty.end = dirty.end.max(line + 1);
        }
        Some(dirty)
    }

    fn calculate_depths(&mut self, tab_width: u8) {
        let mut unmatched_openings: Vec<(usize, usize)> = vec![];
        let mut stack: Vec<(usize, Option<&'static Token>, &mut Match)> = vec![];
        let mut balanced = true;
        self.checkpoints.clear();

        // Get depths for all openings using a traditional stack
        // This results in matching on the closest pairs when there are mismatched
        // openings/closings
        // [ ( ( [] (  ) ]
        // 0     11 1  1 0
        for (line, matches) in self.matches_by_line.iter_mut().enumerate() {
            if line % CHECKPOINT_INTERVAL == 0 {
                self.checkpoints.push((
                    line,
                    stack
                        .iter()
                        .map(|(_, g, m)| (m.token, *g, m.pair_depth))
                        .collect(),
                ));
            }

            'outer: for match_ in matches.iter_mut() {
                // Opening delimiter
                if match_.kind == Kind::Opening {
                    let group = self.separate.group(match_.token);
                    // One deeper than the nearest enclosing pair of the same group
                    match_.pair_depth = stack
                        .iter()
                        .rev()
                        .find(|(_, other, _)| *other == group)
                        .map_or(0, |(_, _, opening)| opening.pair_depth.saturating_add(1));
                    stack.push((line, group, match_));
                }
                // Closing delimiter
                else if match_.kind == Kind::Closing {
                    for (i, (_, _, opening)) in stack.iter().enumerate().rev() {
                        if opening.token == match_.token {
                            // Mark all skipped matches as unmatched
                            for (unmatched_line, _, unmatched_opening) in
                                stack.splice((i + 1).., vec![])
                            {
                                unmatched_openings.push((unmatched_line, unmatched_opening.col));
                            }

                            // Update depth
                            let (_, _, opening) = stack.pop().unwrap();
                            opening.depth = Some(to_depth(stack.len()));
                            match_.depth = Some(to_depth(stack.len()));
                            match_.pair_depth = opening.pair_depth;
                            continue 'outer;
                        }
                    }

                    // No match found, mark as unmatched
                    match_.depth = None;
                    match_.pair_depth = 0;
                    balanced = false;
                }
            }
        }

        // Remaining items in stack must be unmatched
        for (line, _, match_) in stack.into_iter() {
            unmatched_openings.push((line, match_.col));
        }
        unmatched_openings.sort();
        self.balanced = balanced && unmatched_openings.is_empty();

        // Remove depths for unmatched openings
        for (line, col) in unmatched_openings.iter() {
            let match_ = self.match_at_mut(*line, *col).unwrap();
            match_.depth = None;
        }

        // Prefer matching on the furthest pair for mismatched openings
        // As is, we have matched like so:
        // [ ( ( [] (  ) ]
        // 0     11 1  1 0
        // but we want to match like:
        // [ ( ( [] (  ) ]
        // 0 1   22    1 0
        for (line, col) in unmatched_openings.into_iter().rev() {
            self.rematch_by_indent_recursive(line, col, tab_width);
        }
    }

    /// Gets the indent level of the line, rounded down to the nearest tab width
    pub fn rounded_indent_level(&self, line: usize, tab_width: u8) -> u8 {
        let line_indents = self.indents_by_line[line];
        line_indents.0 * tab_width + (line_indents.1 / tab_width) * tab_width
    }

    /// Given an unmatched opening's position, attempts to find a matching opening/closing pair
    /// where the closing ident level matches the unmatched opening.
    /// Performed recursively until the match cannot be moved further down the stack.
    ///
    /// ```text
    /// if some_example {
    ///     //          ^ unmatched
    ///     if no_closing_on_this {
    ///         //       matched  ^
    /// }
    /// ```
    /// becomes
    /// ```text
    /// if some_example {
    ///     //  matched ^
    ///     if no_closing_on_this {
    ///         //      unmatched ^
    ///     }
    /// }
    /// ```
    pub fn rematch_by_indent_recursive(&mut self, line: usize, col: usize, tab_width: u8) {
        let indent_level = self.rounded_indent_level(line, tab_width);
        let token = self.match_at(line, col).unwrap().token;
        let group = self.separate.group(token);
        let depth = self.depth_at(line, col);

        // Find the first matched opening that has the same depth and token
        let matched_pair = self
            .iter_from(line, col + 1)
            .take_while(|match_| {
                match_
                    .depth
                    .map(|match_depth| match_depth >= depth.saturating_add(1))
                    .unwrap_or(true)
            })
            .filter(|match_| match_.token == token)
            .flat_map(|match_| self.match_pair(match_.line, match_.col))
            .find(|(open, close)| {
                self.rounded_indent_level(close.line, tab_width) == indent_level
                    && self.rounded_indent_level(close.line, tab_width)
                        != self.rounded_indent_level(open.line, tab_width)
            });

        if let Some((matched_opening_with_line, matched_closing_with_line)) = matched_pair {
            // Mark matched opening as unmatched
            let matched_opening = self
                .match_at_mut(
                    matched_opening_with_line.line,
                    matched_opening_with_line.col,
                )
                .unwrap();
            matched_opening.depth = None;

            // Mark unmatched opening as matched, using the depth - 1 as unmatched
            // openings lead to incorrect depths for the matches after them
            // For example:
            // [ ( ( ) ]
            // 0   2 2 0
            // When it should be:
            // [ ( ( ) ]
            // 0   1 1 0
            // But since we're now matching on the unmatched opening, we end up with:
            // [ ( ( ) ]
            // 0 1   1 0
            let unmatched_opening = self.match_at_mut(line, col).unwrap();
            unmatched_opening.depth = Some(depth);
            let pair_depth = unmatched_opening.pair_depth;

            let matched_closing = self
                .match_at_mut(
                    matched_closing_with_line.line,
                    matched_closing_with_line.col,
                )
                .unwrap();
            matched_closing.depth = Some(depth);
            matched_closing.pair_depth = pair_depth;

            // All matches after the closing match are now 1 depth shallower,
            // For example, starting with:
            // [ ( ( ) { } ]
            // 0   2 2 2 2 0
            // After the previous step, we have:
            // [ ( ( ) { } ]
            // 0 1   1 2 2 0
            // So we update the "{ }" depth by 1
            // [ ( ( ) { } ]
            // 0 1   1 1 1 0
            for match_ in self.matches_by_line[matched_closing_with_line.line..]
                .iter_mut()
                .enumerate()
                .flat_map(|(line_idx, matches)| {
                    matches.iter_mut().filter(move |match_| {
                        line_idx != 0 || match_.col > matched_closing_with_line.col
                    })
                })
            {
                if match_.depth == Some(depth) && match_.kind == Kind::Closing {
                    break;
                }
                match_.depth = match_.depth.map(|depth| depth.saturating_sub(1));
                if self.separate.group(match_.token) == group {
                    match_.pair_depth = match_.pair_depth.saturating_sub(1);
                }
            }

            self.rematch_by_indent_recursive(
                matched_opening_with_line.line,
                matched_opening_with_line.col,
                tab_width,
            );
        } else {
            // Stays unmatched, so its pair depth from the stack is no longer needed
            self.match_at_mut(line, col).unwrap().pair_depth = 0;
        }
    }

    pub fn iter_from(
        &self,
        line_number: usize,
        col: usize,
    ) -> impl Iterator<Item = MatchWithLine> + '_ {
        self.matches_by_line[line_number..]
            .iter()
            .enumerate()
            .flat_map(move |(offset, matches)| {
                let current_line = line_number + offset;
                matches
                    .iter()
                    .filter(move |match_| current_line != line_number || match_.col >= col)
                    .map(move |match_| match_.with_line(current_line))
            })
    }

    pub fn iter_to(
        &self,
        line_number: usize,
        col: usize,
    ) -> impl Iterator<Item = MatchWithLine> + '_ {
        self.matches_by_line[0..(line_number + 1).min(self.matches_by_line.len())]
            .iter()
            .enumerate()
            .rev()
            .flat_map(move |(current_line, matches)| {
                matches
                    .iter()
                    .rev()
                    .filter(move |match_| current_line != line_number || match_.col < col)
                    .map(move |match_| match_.with_line(current_line))
            })
    }

    pub fn span_at(&self, line_number: usize, col: usize) -> Option<String> {
        let line_matches = self.matches_by_line.get(line_number)?;
        let line_state = self.state_by_line.get(line_number)?;

        // Look for spans starting in the current line before the desired column

        let matching_span = line_matches
            .iter()
            .rev()
            // Get all opening matches before the cursor on the current line
            .filter(|match_| match_.kind == Kind::Opening && match_.col <= col)
            // Find closing match on the same line or no match (overflows to next line)
            .find_map(|opening| {
                match opening.token {
                    Token::InlineSpan(span, _, _) | Token::BlockSpan(span, _, _) => {
                        let closing = line_matches.iter().find(|closing| {
                            closing.kind == Kind::Closing
                                && closing.col > opening.col
                                && closing.token == opening.token
                                && closing.depth == opening.depth
                        });

                        match closing {
                            // Ends before desired column
                            Some(closing) if closing.col < col => None,
                            // Extends to end of line or found closing after desired column
                            _ => Some(span),
                        }
                    }
                    _ => None,
                }
            });

        if let Some(span) = matching_span {
            return Some(span.to_string());
        }

        // Look for spans that started before the current line
        match line_state {
            // TODO: check that the span doesn't end before the cursor
            State::InInlineSpan(span) | State::InBlockSpan(span) => Some(span.to_string()),
            _ => None,
        }
    }

    pub fn match_at(&self, line_number: usize, col: usize) -> Option<Match> {
        self.matches_by_line
            .get(line_number)?
            .iter()
            .find(|match_| (match_.col..(match_.col + match_.len())).contains(&col))
            .cloned()
    }

    pub fn match_at_mut(&mut self, line_number: usize, col: usize) -> Option<&mut Match> {
        self.matches_by_line
            .get_mut(line_number)?
            .iter_mut()
            .find(|match_| (match_.col..(match_.col + match_.len())).contains(&col))
    }

    pub fn match_pair(
        &self,
        line_number: usize,
        col: usize,
    ) -> Option<(MatchWithLine, MatchWithLine)> {
        let match_at_pos = self.match_at(line_number, col)?.with_line(line_number);

        // Ignore unmatched delimiter
        if matches!(match_at_pos.token, Token::Delimiter(_, _)) && match_at_pos.depth.is_none() {
            return None;
        }

        // Opening match
        if match_at_pos.kind == Kind::Opening {
            let closing_match = self.matches_by_line[line_number..]
                .iter()
                .enumerate()
                .map(|(matches_line_number, matches)| (matches_line_number + line_number, matches))
                .find_map(|(matches_line_number, matches)| {
                    matches
                        .iter()
                        .find(|match_| {
                            (line_number != matches_line_number || match_.col > match_at_pos.col)
                                && match_at_pos.token == match_.token
                                && match_at_pos.depth == match_.depth
                        })
                        .map(|match_| match_.with_line(matches_line_number))
                })?;

            Some((match_at_pos, closing_match))
        }
        // Closing match
        else if match_at_pos.kind == Kind::Closing {
            let opening_match = self.matches_by_line[0..=line_number]
                .iter()
                .enumerate()
                .rev()
                .find_map(|(matches_line_number, matches)| {
                    matches
                        .iter()
                        .rev()
                        .find(|match_| {
                            (line_number != matches_line_number || match_.col < match_at_pos.col)
                                && match_at_pos.token == match_.token
                                && match_at_pos.depth == match_.depth
                        })
                        .map(|match_| match_.with_line(matches_line_number))
                })?;

            Some((opening_match, match_at_pos))
        } else {
            None
        }
    }

    /// Innermost pair surrounding the position, including a delimiter at the position itself.
    /// With `between`, the position is treated as being between characters (as with the cursor in
    /// insert mode), so a closing delimiter starting at `col` surrounds it but an opening one does not.
    /// Only pairs of the given `token_types` are considered.
    pub fn surrounding_match_pair(
        &self,
        line_number: usize,
        col: usize,
        between: bool,
        token_types: TokenTypes,
    ) -> Option<(MatchWithLine, MatchWithLine)> {
        let match_before = self
            .match_at(line_number, col)
            .filter(|match_| token_types.contains(match_.token))
            .filter(|match_| !between || (match_.kind == Kind::Closing && match_.col == col))
            .map(|m| m.with_line(line_number))
            // Find match before cursor, where the ending comes after the cursor
            .or_else(|| {
                self.iter_to(line_number, col).find(|match_before| {
                    match_before.kind == Kind::Opening
                        && token_types.contains(match_before.token)
                        && self
                            .match_pair(match_before.line, match_before.col)
                            .map(|(_, match_after)| {
                                match_after.line > line_number
                                    || (match_after.line == line_number && match_after.col > col)
                            })
                            .unwrap_or(false)
                })
            })?;

        self.match_pair(match_before.line, match_before.col)
    }

    pub fn depth_at_forward(&self, line_number: usize, col: usize) -> Option<u16> {
        let mut unmatched_opening_count: u16 = 0;
        self.iter_from(line_number, col)
            .find_map(|match_| match match_.depth {
                Some(depth) => Some(
                    depth
                        .saturating_add(if match_.kind == Kind::Closing { 1 } else { 0 })
                        .saturating_sub(unmatched_opening_count),
                ),
                None => {
                    if matches!(match_.token, Token::Delimiter(_, _)) {
                        match match_.kind {
                            Kind::Opening => {
                                unmatched_opening_count = unmatched_opening_count.saturating_add(1)
                            }
                            Kind::Closing => {
                                unmatched_opening_count = unmatched_opening_count.saturating_sub(1)
                            }
                            Kind::NonPair => {}
                        };
                    }
                    None
                }
            })
    }

    pub fn depth_at_backward(&self, line_number: usize, col: usize) -> Option<u16> {
        let mut unmatched_opening_count: u16 = 0;
        self.iter_to(line_number, col)
            .find_map(|match_| match match_.depth {
                Some(depth) => Some(
                    depth
                        .saturating_add(if match_.kind == Kind::Opening { 1 } else { 0 })
                        .saturating_sub(unmatched_opening_count),
                ),
                None => {
                    if matches!(match_.token, Token::Delimiter(_, _)) {
                        match match_.kind {
                            Kind::Opening => {
                                unmatched_opening_count = unmatched_opening_count.saturating_add(1)
                            }
                            Kind::Closing => {
                                unmatched_opening_count = unmatched_opening_count.saturating_sub(1)
                            }
                            Kind::NonPair => {}
                        };
                    }
                    None
                }
            })
    }

    pub fn depth_at(&self, line_number: usize, col: usize) -> u16 {
        self.depth_at_forward(line_number, col)
            .or_else(|| self.depth_at_backward(line_number, col))
            .unwrap_or(0)
    }

    pub fn unmatched_opening_before(
        &self,
        opening: &str,
        closing: &str,
        line_number: usize,
        col: usize,
    ) -> Option<MatchWithLine> {
        let cursor_depth = self.depth_at(line_number, col);
        let mut lowest_depth = cursor_depth;
        let mut current_depth = cursor_depth;

        for match_ in self
            .iter_to(line_number, col)
            .filter(|match_| matches!(match_.token, Token::Delimiter(_, _)))
        {
            if let Some(depth) = match_.depth {
                // Depth greater than the cursor
                if depth < lowest_depth {
                    // For example: ( [] ( | )
                    // Stack:            ^   ^
                    // Cursor depth: 1
                    // We can close the outer pair by adding a closing pair at the cursor
                    if match_.kind == Kind::Opening
                        && match_.token.closing() == Some(closing)
                        && match_.token.opening() == opening
                    {
                        lowest_depth = depth;
                    }
                    // In this example: ( [ ( | ) ] )
                    // Stack:             ^ ^   ^ ^
                    // Cursor depth: 2
                    // Inserting a closing pair would not close the outer pair, so we exit
                    else {
                        return None;
                    }
                }

                current_depth = depth.saturating_add((match_.kind == Kind::Closing) as u16);
            }

            // Unmatched opening with the same depth
            if match_.kind == Kind::Opening
                && match_.token.opening() == opening
                && match_.token.closing() == Some(closing)
                && match_.depth.is_none()
                && current_depth == lowest_depth
            {
                return Some(match_);
            }
        }

        None
    }

    pub fn unmatched_closing_after(
        &self,
        opening: &str,
        closing: &str,
        line_number: usize,
        col: usize,
    ) -> Option<MatchWithLine> {
        let cursor_depth = self.depth_at(line_number, col);
        let mut lowest_depth = cursor_depth;
        let mut current_depth = cursor_depth;

        for match_ in self
            .iter_from(line_number, col)
            .filter(|match_| matches!(match_.token, Token::Delimiter(_, _)))
        {
            if let Some(depth) = match_.depth {
                // Depth greater than the cursor
                if depth < lowest_depth {
                    // For example: ( | ) )
                    // Stack:       ^   ^
                    // Cursor depth: 1
                    // We can close the outer pair by adding a closing pair at the cursor
                    if match_.kind == Kind::Closing
                        && match_.token.closing() == Some(closing)
                        && match_.token.opening() == opening
                    {
                        lowest_depth = depth;
                    }
                    // In this example: [ ( | ) ] )
                    // Stack:           ^ ^   ^ ^
                    // Cursor depth: 2
                    // Inserting a closing pair would not close the outer pair, so we exit
                    else {
                        return None;
                    }
                }

                current_depth = depth.saturating_add((match_.kind == Kind::Opening) as u16);
            }

            // Unmatched closing with the same depth
            if match_.kind == Kind::Closing
                && match_.token.opening() == opening
                && match_.token.closing() == Some(closing)
                && match_.depth.is_none()
                && current_depth == lowest_depth
            {
                return Some(match_);
            }
        }

        None
    }

    /// Finds the string, block string or block comment opening that the cursor is inside of,
    /// if the parser couldn't find a closing for it. Typing the closing should then insert
    /// only the closing, instead of a new pair.
    ///
    /// ```text
    /// "foo|      -> Some, "foo"|
    /// "foo|bar"  -> None, "foo"|"bar"
    /// // foo "|  -> None, inside a line comment
    /// ```
    pub fn unterminated_opening_before(
        &self,
        opening: &str,
        line_number: usize,
        col: usize,
    ) -> Option<MatchWithLine> {
        let line_matches = self.matches_by_line.get(line_number)?;

        // Strings reset at the end of the line, so the last non-delimiter match
        // before the cursor tells us the state
        let match_before = line_matches.iter().rev().find(|match_| {
            !matches!(match_.token, Token::Delimiter(_, _)) && match_.col + match_.len() <= col
        });
        if let Some(match_) = match_before {
            return (match_.kind == Kind::Opening
                && match_.token.opening() == opening
                && match_.depth.is_none())
            .then(|| match_.with_line(line_number));
        }

        // Nothing before the cursor on this line, check if we're in a block string/comment
        // from a previous line
        let previous_state = line_number
            .checked_sub(1)
            .and_then(|line_number| self.state_by_line.get(line_number))?;
        match previous_state {
            State::InBlockString(open) | State::InBlockComment(open) if *open == opening => self
                .iter_to(line_number, 0)
                .find(|match_| match_.kind == Kind::Opening && match_.token.opening() == opening)
                .filter(|match_| match_.depth.is_none()),
            _ => None,
        }
    }

    /// Finds an unterminated opening after the cursor, for tokens where the opening and closing
    /// are the same (i.e. `"`). The parser marks it as an opening since it's the first one it
    /// sees, but typing the opening at the cursor would turn it into the closing.
    ///
    /// ```text
    /// |foo"       -> Some, "|foo"
    /// |foo"bar"   -> None, "|"foo"bar"
    /// ```
    pub fn unterminated_opening_after(
        &self,
        opening: &str,
        line_number: usize,
        col: usize,
    ) -> Option<MatchWithLine> {
        self.matches_by_line
            .get(line_number)?
            .iter()
            .filter(|match_| match_.col >= col && match_.token.opening() == opening)
            .filter(|match_| {
                match_
                    .token
                    .closing()
                    .is_none_or(|closing| closing == opening)
            })
            .next_back()
            .filter(|match_| match_.kind == Kind::Opening && match_.depth.is_none())
            .map(|match_| match_.with_line(line_number))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq;

    fn parse(filetype: &str, lines: &[&str]) -> ParsedBuffer {
        parse_separate(Separate::None, filetype, lines)
    }

    fn parse_separate(separate: Separate, filetype: &str, lines: &[&str]) -> ParsedBuffer {
        let lines = lines.iter().map(|l| l.as_bytes().into()).collect();
        ParsedBuffer::parse(filetype, 4, lines, separate).unwrap()
    }

    #[test]
    fn test_angle_brackets() {
        let buffer = parse("rust", &["let x: Vec<Vec<T>> = if a < b { c } else { d };"]);
        assert_eq!(
            buffer.matches_by_line[0],
            vec![
                Match::delimiter('<', 10, Some(0)),
                Match::delimiter('<', 14, Some(1)),
                Match::delimiter('>', 16, Some(1)),
                Match::delimiter('>', 17, Some(0)),
                Match::delimiter('{', 30, Some(0)),
                Match::delimiter('}', 34, Some(0)),
                Match::delimiter('{', 41, Some(0)),
                Match::delimiter('}', 45, Some(0)),
            ]
        );

        // matching and typing helpers see angle brackets like any other delimiter
        assert_eq!(
            buffer
                .match_pair(0, 10)
                .map(|(open, close)| (open.col, close.col)),
            Some((10, 17))
        );
        let buffer = parse("rust", &["Vec<T", "foo::<"]);
        assert_eq!(
            buffer.unmatched_opening_before("<", ">", 0, 5),
            Some(Match::delimiter('<', 3, None).with_line(0))
        );
        assert_eq!(
            buffer.unmatched_opening_before("<", ">", 1, 6),
            Some(Match::delimiter('<', 5, None).with_line(1))
        );
        let buffer = parse("rust", &["Vec>"]);
        assert_eq!(
            buffer.unmatched_closing_after("<", ">", 0, 3),
            Some(Match::delimiter('>', 3, None).with_line(0))
        );
    }

    #[test]
    fn test_pair_depth() {
        let pair_depths = |separate| {
            let buffer = parse_separate(separate, "rust", &["{ Vec<(T)> } ]"]);
            let matches = &buffer.matches_by_line[0];
            assert_eq!(matches[6].depth, None);
            matches.iter().map(|m| m.pair_depth).collect::<Vec<_>>()
        };
        assert_eq!(pair_depths(Separate::None), [0, 1, 2, 2, 1, 0, 0]);
        assert_eq!(pair_depths(Separate::All), [0, 0, 0, 0, 0, 0, 0]);
        let angle = Separate::Openings(vec!["<".into()]);
        assert_eq!(pair_depths(angle), [0, 0, 1, 1, 0, 0, 0]);
    }

    #[test]
    fn test_depth_saturates() {
        let line = "(".repeat(70_000) + &")".repeat(70_000);
        let buffer = parse("rust", &[&line]);
        let deepest = &buffer.matches_by_line[0][69_999];
        assert_eq!(
            (deepest.depth, deepest.pair_depth),
            (Some(u16::MAX), u16::MAX)
        );
        assert_eq!(std::mem::size_of::<Match>(), 24);
    }

    #[test]
    fn test_unmatched_opening_before() {
        let buffer = parse("rust", &["("]);
        assert_eq!(buffer.unmatched_opening_before("(", ")", 0, 0), None);
        assert_eq!(
            buffer.unmatched_opening_before("(", ")", 0, 1),
            Some(Match::delimiter('(', 0, None).with_line(0))
        );

        let buffer = parse("rust", &["( ( )"]);
        assert_eq!(
            buffer.unmatched_opening_before("(", ")", 0, 4),
            Some(Match::delimiter('(', 0, None).with_line(0))
        );
    }

    #[test]
    fn test_get_unmatched_closing_at() {
        let buffer = parse("rust", &[")"]);
        assert_eq!(
            buffer.unmatched_closing_after("(", ")", 0, 0),
            Some(Match::delimiter(')', 0, None).with_line(0))
        );
        assert_eq!(buffer.unmatched_closing_after("(", ")", 0, 1), None);
        assert_eq!(buffer.unmatched_closing_after("(", ")", 1, 1), None);

        let buffer = parse("rust", &[" )"]);
        assert_eq!(
            buffer.unmatched_closing_after("(", ")", 0, 0),
            Some(Match::delimiter(')', 1, None).with_line(0))
        );
        assert_eq!(
            buffer.unmatched_closing_after("(", ")", 0, 1),
            Some(Match::delimiter(')', 1, None).with_line(0))
        );
        assert_eq!(buffer.unmatched_closing_after("(", ")", 0, 2), None);
        assert_eq!(buffer.unmatched_closing_after("(", ")", 1, 0), None);

        let buffer = parse("rust", &["( ] )"]);
        assert_eq!(buffer.unmatched_closing_after("[", "]", 0, 0), None);
        assert_eq!(
            buffer.unmatched_closing_after("[", "]", 0, 1),
            Some(Match::delimiter(']', 2, None).with_line(0))
        );
    }

    #[test]
    fn test_unterminated_opening_before() {
        // "foo|
        let buffer = parse("lua", &["\"foo"]);
        assert_eq!(buffer.unterminated_opening_before("\"", 0, 0), None);
        assert_eq!(
            buffer.unterminated_opening_before("\"", 0, 4),
            Some(Match::new(Kind::Opening, &Token::String("\""), 0).with_line(0))
        );
        // Different string type
        assert_eq!(buffer.unterminated_opening_before("'", 0, 4), None);
        // Strings reset at the end of the line
        let buffer = parse("lua", &["\"foo", ""]);
        assert_eq!(buffer.unterminated_opening_before("\"", 1, 0), None);

        // "foo|bar"
        let buffer = parse("lua", &["\"foo bar\""]);
        assert_eq!(buffer.unterminated_opening_before("\"", 0, 4), None);
        assert_eq!(buffer.unterminated_opening_before("\"", 0, 9), None);

        // "foo" ("bar|
        let buffer = parse("lua", &["\"foo\" (\"bar"]);
        assert_eq!(buffer.unterminated_opening_before("\"", 0, 6), None);
        assert_eq!(
            buffer.unterminated_opening_before("\"", 0, 11),
            Some(Match::new(Kind::Opening, &Token::String("\""), 7).with_line(0))
        );

        // -- "foo|
        let buffer = parse("lua", &["-- \"foo"]);
        assert_eq!(buffer.unterminated_opening_before("\"", 0, 7), None);

        // Block string from a previous line
        let buffer = parse("lua", &["[[foo", "bar"]);
        assert_eq!(
            buffer.unterminated_opening_before("[[", 1, 3),
            Some(Match::new(Kind::Opening, &Token::BlockString("[[", "]]"), 0).with_line(0))
        );
        assert_eq!(buffer.unterminated_opening_before("\"", 1, 3), None);
        let buffer = parse("lua", &["[[foo", "bar", "]]"]);
        assert_eq!(buffer.unterminated_opening_before("[[", 1, 3), None);

        // Block comment from a previous line
        let buffer = parse("c", &["/* foo", "bar"]);
        assert_eq!(
            buffer.unterminated_opening_before("/*", 1, 3),
            Some(Match::block_comment("/*", 0).with_line(0))
        );
    }

    #[test]
    fn test_unterminated_opening_after() {
        // |foo"
        let buffer = parse("lua", &["foo\""]);
        assert_eq!(
            buffer.unterminated_opening_after("\"", 0, 0),
            Some(Match::new(Kind::Opening, &Token::String("\""), 3).with_line(0))
        );
        assert_eq!(buffer.unterminated_opening_after("\"", 0, 4), None);
        assert_eq!(buffer.unterminated_opening_after("'", 0, 0), None);

        // |foo"bar"
        let buffer = parse("lua", &["foo\"bar\""]);
        assert_eq!(buffer.unterminated_opening_after("\"", 0, 0), None);

        // |foo"bar"baz"
        let buffer = parse("lua", &["foo\"bar\"baz\""]);
        assert_eq!(
            buffer.unterminated_opening_after("\"", 0, 0),
            Some(Match::new(Kind::Opening, &Token::String("\""), 11).with_line(0))
        );

        // Only for tokens with the same opening and closing
        let buffer = parse("lua", &["foo[["]);
        assert_eq!(buffer.unterminated_opening_after("[[", 0, 0), None);
    }

    /// Applies random edits (and undoes them) incrementally, checking the result against a
    /// fresh full parse each time
    #[test]
    fn test_incremental_matches_full_parse() {
        let sources = [
            ("c", include_str!("../benches/languages/c.c")),
            ("rust", include_str!("../benches/languages/rust.rs")),
        ];
        #[rustfmt::skip]
        let snippets: &[&[u8]] = &[
            b"", b"x", b"foo(bar[1]) {}", b"\"str\" 'c'", b"/* {} */", b"// (", b"Vec<T>", b"a < b",
            b"{", b"}", b"(", b")", b"\"", b"/*", b"*/", b"'\"'",
        ];
        let mut seed = 0x2545F4914F6CDD1Du64;
        let mut rand = |n: usize| {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            (seed % n.max(1) as u64) as usize
        };

        let separates = [
            Separate::None,
            Separate::All,
            Separate::Openings(vec!["<".into()]),
        ];
        let cases = sources
            .iter()
            .flat_map(|src| separates.iter().map(move |sep| (src, sep)));
        for (&(filetype, src), separate) in cases {
            let mut lines: Vec<Box<[u8]>> = src.lines().map(|l| l.as_bytes().into()).collect();
            let mut incremental =
                ParsedBuffer::parse(filetype, 4, lines.clone(), separate.clone()).unwrap();
            let mut undo = None;
            let mut balanced_edits = 0;
            for _ in 0..600 {
                balanced_edits += incremental.balanced as usize;
                // undo the previous edit, unless the buffer is still balanced and we want to
                // keep accumulating edits
                let (start, old_end, new_lines) = match undo.take() {
                    Some(edit) if !incremental.balanced || rand(3) == 0 => edit,
                    _ => {
                        let start = rand(lines.len() + 1);
                        let old_end = (start + rand(3)).min(lines.len());
                        let new_lines: Vec<Box<[u8]>> = (0..rand(4))
                            .map(|_| snippets[rand(snippets.len())].into())
                            .collect();
                        undo = Some((
                            start,
                            start + new_lines.len(),
                            lines[start..old_end].to_vec(),
                        ));
                        (start, old_end, new_lines)
                    }
                };
                lines.splice(start..old_end, new_lines.clone());
                let mut rendered = incremental.matches_by_line.clone();
                rendered.splice(start..old_end, new_lines.iter().map(|_| vec![]));
                let dirty = incremental
                    .reparse_range(filetype, 4, new_lines, start, old_end)
                    .unwrap();
                incremental.ensure_depths();
                let full =
                    ParsedBuffer::parse(filetype, 4, lines.clone(), separate.clone()).unwrap();

                // Everything outside the dirty range must be unchanged
                for line in (0..lines.len()).filter(|line| !dirty.contains(line)) {
                    assert_eq!(
                        rendered[line], incremental.matches_by_line[line],
                        "line {line} changed outside of dirty range {dirty:?} (edit {start}..{old_end})"
                    );
                }

                assert_eq!(incremental.lines, lines);
                assert_eq!(incremental.state_by_line, full.state_by_line);
                assert_eq!(incremental.indents_by_line, full.indents_by_line);
                for line in 0..lines.len() {
                    assert_eq!(
                        incremental.matches_by_line[line], full.matches_by_line[line],
                        "line {line} (edit {start}..{old_end}, dirty {dirty:?})"
                    );
                }
                assert_eq!(incremental.balanced, full.balanced);
            }
            assert!(
                balanced_edits > 200,
                "{filetype}: only {balanced_edits} edits on a balanced buffer"
            );
        }
    }

    #[test]
    fn test_rebalanced_matching() {
        let buffer = parse("rust", &["{", "\t{", "\t", "}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, Some(0))],
                vec![Match::delimiter('{', 1, None)],
                vec![],
                vec![Match::delimiter('}', 0, Some(0))],
            ]
        );

        let buffer = parse("rust", &["{", "\t{", "\t}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, None)],
                vec![Match::delimiter('{', 1, Some(1))],
                vec![Match::delimiter('}', 1, Some(1))],
            ]
        );

        let buffer = parse("rust", &["{", "\t{", "\t}", "}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, Some(0))],
                vec![Match::delimiter('{', 1, Some(1))],
                vec![Match::delimiter('}', 1, Some(1))],
                vec![Match::delimiter('}', 0, Some(0))],
            ]
        );

        let buffer = parse("rust", &["{", "\t{", "\t\t{", "\t\t}", "}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, Some(0))],
                vec![Match::delimiter('{', 1, None)],
                vec![Match::delimiter('{', 2, Some(2))],
                vec![Match::delimiter('}', 2, Some(2))],
                vec![Match::delimiter('}', 0, Some(0))],
            ]
        );

        let buffer = parse("rust", &["{", "\t{", "\t\t{", "\t\t}", "\t}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, None)],
                vec![Match::delimiter('{', 1, Some(1))],
                vec![Match::delimiter('{', 2, Some(2))],
                vec![Match::delimiter('}', 2, Some(2))],
                vec![Match::delimiter('}', 1, Some(1))],
            ]
        );

        let buffer = parse("rust", &["{", "\t{", "\t\t{", "\t\t}", "\t{", "}"]);
        assert_eq!(
            buffer.matches_by_line,
            vec![
                vec![Match::delimiter('{', 0, Some(0))],
                vec![Match::delimiter('{', 1, None)],
                vec![Match::delimiter('{', 2, Some(2))],
                vec![Match::delimiter('}', 2, Some(2))],
                vec![Match::delimiter('{', 1, None)],
                vec![Match::delimiter('}', 0, Some(0))],
            ]
        );
    }
}
