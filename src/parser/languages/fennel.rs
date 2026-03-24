use crate::parser::*;
use matcher_macros::define_matcher;

define_matcher!(Fennel {
    delimiters: [
        "(" => ")",
        "[" => "]",
        "{" => "}"
    ],
    line_comment: [";"],
    block_comment: [],
    string: ["\""]
});
