pub type SimdVec = std::simd::Simd<u8, 16>;

pub mod indent;
pub mod languages;
pub mod matcher;
pub mod parse;
pub mod tokenize;

pub use itertools::MultiPeek;
pub use matcher::{Kind, Match, MatchWithLine, Matcher, Token};
pub use parse::{parse, State};
pub use tokenize::{tokenize, CharPos};

use crate::buffer::ParsedBuffer;

#[rustfmt::skip]
const FILETYPES: &[&str] = &[
    "c", "clojure", "cpp", "csharp", "dart", "elixir", "erlang", "fsharp", "go", "haskell",
    "haxe", "java", "javascript", "typescript", "typescriptreact", "javascriptreact", "json",
    "kotlin", "latex", "tex", "bib", "lean", "lua", "markdown", "nix", "objc", "ocaml", "perl",
    "php", "python", "r", "ruby", "rust", "scala", "scheme", "shell", "sql", "swift", "toml", "typst", "vim",
    "zig"
];

pub fn supports_filetype(filetype: &str) -> bool {
    FILETYPES.contains(&filetype)
}

#[rustfmt::skip]
pub fn parse_filetype(
    filetype: &str,
    tab_width: u8,
    lines: &[&str],
    initial_state: State,
) -> Option<ParsedBuffer> {
    match filetype {
        "c" => Some(parse(tab_width, lines, initial_state, languages::C {})),
        "clojure" => Some(parse(tab_width, lines, initial_state, languages::Clojure {})),
        "cpp" => Some(parse(tab_width, lines, initial_state, languages::Cpp {})),
        "csharp" => Some(parse(tab_width, lines, initial_state, languages::CSharp {})),
        "dart" => Some(parse(tab_width, lines, initial_state, languages::Dart {})),
        "elixir" => Some(parse(tab_width, lines, initial_state, languages::Elixir {})),
        "erlang" => Some(parse(tab_width, lines, initial_state, languages::Erlang {})),
        "fsharp" => Some(parse(tab_width, lines, initial_state, languages::FSharp {})),
        "go" => Some(parse(tab_width, lines, initial_state, languages::Go {})),
        "haskell" => Some(parse(tab_width, lines, initial_state, languages::Haskell {})),
        "haxe" => Some(parse(tab_width, lines, initial_state, languages::Haxe {})),
        "java" => Some(parse(tab_width, lines, initial_state, languages::Java {})),
        "typescript" | "javascript" | "typescriptreact" | "javascriptreact" =>
            Some(parse(tab_width, lines, initial_state, languages::JavaScript {})),
        "json" => Some(parse(tab_width, lines, initial_state, languages::Json {})),
        "kotlin" => Some(parse(tab_width, lines, initial_state, languages::Kotlin {})),
        "latex" | "tex" | "bib" => Some(parse(tab_width, lines, initial_state, languages::Latex {})),
        "lean" => Some(parse(tab_width, lines, initial_state, languages::Lean {})),
        "lua" => Some(parse(tab_width, lines, initial_state, languages::Lua {})),
        "markdown" => Some(parse(tab_width, lines, initial_state, languages::Markdown {})),
        "nix" => Some(parse(tab_width, lines, initial_state, languages::Nix {})),
        "objc" => Some(parse(tab_width, lines, initial_state, languages::ObjC {})),
        "ocaml" => Some(parse(tab_width, lines, initial_state, languages::OCaml {})),
        "perl" => Some(parse(tab_width, lines, initial_state, languages::Perl {})),
        "php" => Some(parse(tab_width, lines, initial_state, languages::Php {})),
        "python" => Some(parse(tab_width, lines, initial_state, languages::Python {})),
        "r" => Some(parse(tab_width, lines, initial_state, languages::R {})),
        "ruby" => Some(parse(tab_width, lines, initial_state, languages::Ruby {})),
        "rust" => Some(parse(tab_width, lines, initial_state, languages::Rust {})),
        "scala" => Some(parse(tab_width, lines, initial_state, languages::Scala {})),
        "scheme" => Some(parse(tab_width, lines, initial_state, languages::Scheme {})),
        "shell" => Some(parse(tab_width, lines, initial_state, languages::Shell {})),
        "sql" => Some(parse(tab_width, lines, initial_state, languages::Sql {})),
        "swift" => Some(parse(tab_width, lines, initial_state, languages::Swift {})),
        "toml" => Some(parse(tab_width, lines, initial_state, languages::Toml {})),
        "typst" => Some(parse(tab_width, lines, initial_state, languages::Typst {})),
        "vim" => Some(parse(tab_width, lines, initial_state, languages::Vim {})),
        "zig" => Some(parse(tab_width, lines, initial_state, languages::Zig {})),

        _ => None,
    }
}
