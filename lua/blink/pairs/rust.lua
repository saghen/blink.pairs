--- @class blink.pairs.Parser
--- @field parse_buffer fun(bufnr: number, tab_width: number, filetype: string, text: string, start_line: number?, old_end_line: number?, new_end_line: number?, separate: boolean | string | string[] | nil): boolean, number, number Pairs whose nesting depth is counted separately (see `highlights.separate`), used on the initial parse
--- @field remove_buffer fun(bufnr: number)
--- @field supports_filetype fun(filetype: string): boolean
--- @field get_line_matches fun(bufnr: number, line_number: number, token_type: number?): blink.pairs.Match[]
--- @field get_span_at fun(bufnr: number, row: number, col: number): string?
--- @field get_match_at fun(bufnr: number, row: number, col: number): blink.pairs.Match?
--- @field get_match_pair fun(bufnr: number, row: number, col: number, token_types?: blink.pairs.TokenType | blink.pairs.TokenType[]): blink.pairs.MatchWithLine[]? Pair of the delimiter at the position, only of the `token_types` (default all)
--- @field get_surrounding_match_pair fun(bufnr: number, row: number, col: number, between?: boolean, token_types?: blink.pairs.TokenType | blink.pairs.TokenType[], surrounding_token_types?: blink.pairs.TokenType | blink.pairs.TokenType[]): blink.pairs.MatchWithLine[]? Innermost pair surrounding the position, including a delimiter at the position. With `between`, the position is treated as being between characters (insert mode cursor), so a closing delimiter at `col` surrounds it but an opening one does not. Only pairs of the `token_types` (default all) are considered
--- @field get_unmatched_opening_before fun(bufnr: number, opening: string, closing: string, row: number, col: number): blink.pairs.MatchWithLine?
--- @field get_unmatched_closing_after fun(bufnr: number, opening: string, closing: string, row: number, col: number): blink.pairs.MatchWithLine?
--- @field get_unterminated_opening_before fun(bufnr: number, opening: string, row: number, col: number): blink.pairs.MatchWithLine?
--- @field get_unterminated_opening_after fun(bufnr: number, opening: string, row: number, col: number): blink.pairs.MatchWithLine?

--- @alias blink.pairs.TokenType 'delimiter' | 'string' | 'block_string' | 'line_comment' | 'block_comment' | 'inline_span' | 'block_span'

--- @class blink.pairs.Match
--- @field [1] string
--- @field [2] string?
--- @field span string?
--- @field col number
--- @field depth number?
--- @field pair_depth number? Nesting depth counting only pairs it nests with, see `highlights.separate`

--- @class blink.pairs.MatchWithLine : blink.pairs.Match
--- @field line number

local project_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h:h')
local native = require('blink.lib.native')
--- @type blink.pairs.Parser
local rust = native.load('blink_pairs_parser', native.try_git_commit(project_root))
return rust
