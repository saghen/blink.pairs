use crate::parser::*;
use matcher_macros::define_matcher;

define_matcher!(Shell {
    delimiters: [
        "(" => ")",
        "[" => "]",
        "{" => "}"
    ],
    line_comment: ["#"],
    block_string: ["\"" => "\"", "'" => "'"],
});
