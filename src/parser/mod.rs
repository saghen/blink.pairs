pub mod languages;
pub mod matcher;
pub mod parse;

pub use matcher::{
    Kind, Match, MatchWithLine, Matcher, Token, is_angle_bracket_closing, is_angle_bracket_opening,
};
pub use parse::{CharPos, State, TokenizedLine, tokenize};

#[rustfmt::skip]
const FILETYPES: &[&str] = &[
    "bash", "c", "clojure", "cmake", "cpp", "csharp", "dart", "elixir", "erlang", "fennel", "fish", "fsharp", "go", "haskell",
    "haxe", "java", "javascript", "typescript", "typescriptreact", "javascriptreact", "json", "julia",
    "kotlin", "latex", "tex", "bib", "lean", "lua", "markdown", "nix", "objc", "ocaml", "perl",
    "php", "python", "r", "ruby", "rust", "scala", "scheme", "sh", "shell", "sql", "swift", "systemverilog",
    "toml", "typst", "verilog", "vim", "zig", "zsh"
];

pub fn supports_filetype(filetype: &str) -> bool {
    FILETYPES.contains(&filetype)
}

#[rustfmt::skip]
pub fn tokenize_filetype<'a>(
    filetype: &str,
    lines: impl Iterator<Item = &'a [u8]> + 'a,
    initial_state: State,
) -> Option<Box<dyn Iterator<Item = TokenizedLine> + 'a>> {
    match filetype {
        "c" => Some(Box::new(tokenize(lines, initial_state, languages::C {}))),
        "clojure" => Some(Box::new(tokenize(lines, initial_state, languages::Clojure {}))),
        "cmake" => Some(Box::new(tokenize(lines, initial_state, languages::CMake {}))),
        "cpp" => Some(Box::new(tokenize(lines, initial_state, languages::Cpp {}))),
        "csharp" => Some(Box::new(tokenize(lines, initial_state, languages::CSharp {}))),
        "dart" => Some(Box::new(tokenize(lines, initial_state, languages::Dart {}))),
        "elixir" => Some(Box::new(tokenize(lines, initial_state, languages::Elixir {}))),
        "erlang" => Some(Box::new(tokenize(lines, initial_state, languages::Erlang {}))),
        "fennel" => Some(Box::new(tokenize(lines, initial_state, languages::Fennel {}))),
        "fsharp" => Some(Box::new(tokenize(lines, initial_state, languages::FSharp {}))),
        "go" => Some(Box::new(tokenize(lines, initial_state, languages::Go {}))),
        "haskell" => Some(Box::new(tokenize(lines, initial_state, languages::Haskell {}))),
        "haxe" => Some(Box::new(tokenize(lines, initial_state, languages::Haxe {}))),
        "java" => Some(Box::new(tokenize(lines, initial_state, languages::Java {}))),
        "typescript" | "javascript" | "typescriptreact" | "javascriptreact" =>
            Some(Box::new(tokenize(lines, initial_state, languages::JavaScript {}))),
        "json" => Some(Box::new(tokenize(lines, initial_state, languages::Json {}))),
        "julia" => Some(Box::new(tokenize(lines, initial_state, languages::Julia {}))),
        "kotlin" => Some(Box::new(tokenize(lines, initial_state, languages::Kotlin {}))),
        "latex" | "tex" | "bib" => Some(Box::new(tokenize(lines, initial_state, languages::Latex {}))),
        "lean" => Some(Box::new(tokenize(lines, initial_state, languages::Lean {}))),
        "lua" => Some(Box::new(tokenize(lines, initial_state, languages::Lua {}))),
        "markdown" => Some(Box::new(tokenize(lines, initial_state, languages::Markdown {}))),
        "nix" => Some(Box::new(tokenize(lines, initial_state, languages::Nix {}))),
        "objc" => Some(Box::new(tokenize(lines, initial_state, languages::ObjC {}))),
        "ocaml" => Some(Box::new(tokenize(lines, initial_state, languages::OCaml {}))),
        "perl" => Some(Box::new(tokenize(lines, initial_state, languages::Perl {}))),
        "php" => Some(Box::new(tokenize(lines, initial_state, languages::Php {}))),
        "python" => Some(Box::new(tokenize(lines, initial_state, languages::Python {}))),
        "r" => Some(Box::new(tokenize(lines, initial_state, languages::R {}))),
        "ruby" => Some(Box::new(tokenize(lines, initial_state, languages::Ruby {}))),
        "rust" => Some(Box::new(tokenize(lines, initial_state, languages::Rust {}))),
        "scala" => Some(Box::new(tokenize(lines, initial_state, languages::Scala {}))),
        "scheme" => Some(Box::new(tokenize(lines, initial_state, languages::Scheme {}))),
        "bash" | "fish" | "sh" | "zsh" => Some(Box::new(tokenize(lines, initial_state, languages::Shell {}))),
        "sql" => Some(Box::new(tokenize(lines, initial_state, languages::Sql {}))),
        "swift" => Some(Box::new(tokenize(lines, initial_state, languages::Swift {}))),
        "systemverilog" | "verilog" => Some(Box::new(tokenize(lines, initial_state, languages::SystemVerilog {}))),
        "toml" => Some(Box::new(tokenize(lines, initial_state, languages::Toml {}))),
        "typst" => Some(Box::new(tokenize(lines, initial_state, languages::Typst {}))),
        "vim" => Some(Box::new(tokenize(lines, initial_state, languages::Vim {}))),
        "zig" => Some(Box::new(tokenize(lines, initial_state, languages::Zig {}))),

        _ => None,
    }
}
