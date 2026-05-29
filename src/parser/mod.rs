pub mod languages;
pub mod matcher;
pub mod parse;

pub use matcher::{Kind, Match, MatchWithLine, Matcher, Token};
pub use parse::{CharPos, State, parse};

use crate::buffer::ParsedBuffer;

#[rustfmt::skip]
const FILETYPES: &[&str] = &[
    "c", "clojure", "cpp", "csharp", "dart", "elixir", "erlang", "fennel", "fsharp", "go", "haskell",
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
    lines: &[&str],
    initial_state: State,
) -> Option<ParsedBuffer> {
    match filetype {
        "c" => Some(parse(lines, initial_state, languages::C {})),
        "clojure" => Some(parse(lines, initial_state, languages::Clojure {})),
        "cpp" => Some(parse(lines, initial_state, languages::Cpp {})),
        "csharp" => Some(parse(lines, initial_state, languages::CSharp {})),
        "dart" => Some(parse(lines, initial_state, languages::Dart {})),
        "elixir" => Some(parse(lines, initial_state, languages::Elixir {})),
        "erlang" => Some(parse(lines, initial_state, languages::Erlang {})),
        "fennel" => Some(parse(lines, initial_state, languages::Fennel {})),
        "fsharp" => Some(parse(lines, initial_state, languages::FSharp {})),
        "go" => Some(parse(lines, initial_state, languages::Go {})),
        "haskell" => Some(parse(lines, initial_state, languages::Haskell {})),
        "haxe" => Some(parse(lines, initial_state, languages::Haxe {})),
        "java" => Some(parse(lines, initial_state, languages::Java {})),
        "typescript" | "javascript" | "typescriptreact" | "javascriptreact" =>
            Some(parse(lines, initial_state, languages::JavaScript {})),
        "json" => Some(parse(lines, initial_state, languages::Json {})),
        "kotlin" => Some(parse(lines, initial_state, languages::Kotlin {})),
        "latex" | "tex" | "bib" => Some(parse(lines, initial_state, languages::Latex {})),
        "lean" => Some(parse(lines, initial_state, languages::Lean {})),
        "lua" => Some(parse(lines, initial_state, languages::Lua {})),
        "markdown" => Some(parse(lines, initial_state, languages::Markdown {})),
        "nix" => Some(parse(lines, initial_state, languages::Nix {})),
        "objc" => Some(parse(lines, initial_state, languages::ObjC {})),
        "ocaml" => Some(parse(lines, initial_state, languages::OCaml {})),
        "perl" => Some(parse(lines, initial_state, languages::Perl {})),
        "php" => Some(parse(lines, initial_state, languages::Php {})),
        "python" => Some(parse(lines, initial_state, languages::Python {})),
        "r" => Some(parse(lines, initial_state, languages::R {})),
        "ruby" => Some(parse(lines, initial_state, languages::Ruby {})),
        "rust" => Some(parse(lines, initial_state, languages::Rust {})),
        "scala" => Some(parse(lines, initial_state, languages::Scala {})),
        "scheme" => Some(parse(lines, initial_state, languages::Scheme {})),
        "shell" => Some(parse(lines, initial_state, languages::Shell {})),
        "sql" => Some(parse(lines, initial_state, languages::Sql {})),
        "swift" => Some(parse(lines, initial_state, languages::Swift {})),
        "toml" => Some(parse(lines, initial_state, languages::Toml {})),
        "typst" => Some(parse(lines, initial_state, languages::Typst {})),
        "vim" => Some(parse(lines, initial_state, languages::Vim {})),
        "zig" => Some(parse(lines, initial_state, languages::Zig {})),

        _ => None,
    }
}
