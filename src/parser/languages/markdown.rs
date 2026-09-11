use crate::parser::*;
use matcher_macros::define_matcher;

define_matcher!(Markdown {
    inline_span: {
        math: "$" => "$",
        italic: "_" => "_",
        bold: "*" => "*",
        bold: "**" => "**",
        strikethrough: "~~" => "~~"
    },
    block_span: {
        math: "$$" => "$$",
        code: "```" => "```"
    },
});
