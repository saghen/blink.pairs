use crate::parser::*;
use matcher_macros::define_matcher;

define_matcher!(Julia {
    delimiters: [
        "(" => ")",
        "[" => "]",
        "{" => "}"
    ],
    line_comment: ["#"],
    block_comment: ["#=" => "=#"],
    string: ["\"", "`"],
    // `'` is also the transpose operator (`A'`), so only match it as a char literal
    char: ["'"],
    block_string: ["\"\"\"" => "\"\"\"", "```" => "```"]
});
