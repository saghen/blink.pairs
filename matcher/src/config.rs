use syn::parse::{Parse, ParseStream};
use syn::token::{Colon, Comma, FatArrow};
use syn::{Ident, LitStr};
use syn::{Result, braced, bracketed};

use std::collections::{HashMap, HashSet};

pub struct MatcherDef {
    pub name: Ident,
    pub delimiters: Vec<(String, String)>,
    pub angle_brackets: Vec<(String, String)>,
    pub line_comments: Vec<String>,
    pub block_comments: Vec<(String, String)>,
    pub strings: Vec<String>,
    pub chars: Vec<String>,
    pub block_strings: Vec<(String, String)>,
    pub inline_spans: HashMap<String, (String, String)>,
    pub block_spans: HashMap<String, (String, String)>,
}

// Parse the incoming macro definition into a MatcherDef struct
impl Parse for MatcherDef {
    fn parse(input: ParseStream) -> Result<Self> {
        let name = input.parse::<Ident>()?;
        let content;
        braced!(content in input);

        let mut delimiters = Vec::new();
        let mut angle_brackets = Vec::new();
        let mut line_comments = Vec::new();
        let mut block_comments = Vec::new();
        let mut strings = Vec::new();
        let mut chars = Vec::new();
        let mut block_strings = Vec::new();
        let mut inline_spans = HashMap::new();
        let mut block_spans = HashMap::new();

        fn get_single_char(token: LitStr) -> Result<String> {
            let value = token.value();
            if value.len() != 1 {
                Err(syn::Error::new(
                    token.span(),
                    "Delimiter must be a single character",
                ))
            } else {
                Ok(value)
            }
        }

        // Parse each section
        while !content.is_empty() {
            let section_name = content.parse::<Ident>()?;
            content.parse::<Colon>()?;

            let section_content;
            match section_name.to_string().as_str() {
                "delimiters" | "angle_brackets" | "line_comment" | "block_comment" | "string"
                | "char" | "block_string" => {
                    bracketed!(section_content in content);
                }
                "inline_span" | "block_span" => {
                    braced!(section_content in content);
                }
                _ => return Err(syn::Error::new(section_name.span(), "Unknown section name")),
            }

            match section_name.to_string().as_str() {
                "delimiters" | "angle_brackets" => {
                    let target = if section_name == "delimiters" {
                        &mut delimiters
                    } else {
                        &mut angle_brackets
                    };
                    while !section_content.is_empty() {
                        let open = get_single_char(section_content.parse::<LitStr>()?)?;
                        section_content.parse::<FatArrow>()?;
                        let close = get_single_char(section_content.parse::<LitStr>()?)?;
                        target.push((open, close));

                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "line_comment" => {
                    while !section_content.is_empty() {
                        line_comments.push(section_content.parse::<LitStr>()?.value());
                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "block_comment" => {
                    while !section_content.is_empty() {
                        let open = section_content.parse::<LitStr>()?.value();
                        section_content.parse::<FatArrow>()?;
                        let close = section_content.parse::<LitStr>()?.value();
                        block_comments.push((open, close));

                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "string" => {
                    while !section_content.is_empty() {
                        strings.push(section_content.parse::<LitStr>()?.value());
                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "char" => {
                    while !section_content.is_empty() {
                        let delim = get_single_char(section_content.parse::<LitStr>()?)?;
                        chars.push(delim);
                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "block_string" => {
                    while !section_content.is_empty() {
                        let open = section_content.parse::<LitStr>()?.value();
                        section_content.parse::<FatArrow>()?;
                        let close = section_content.parse::<LitStr>()?.value();
                        block_strings.push((open, close));

                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "inline_span" => {
                    while !section_content.is_empty() {
                        let name = section_content.parse::<Ident>()?.to_string();
                        section_content.parse::<Colon>()?;
                        let open = section_content.parse::<LitStr>()?.value();
                        section_content.parse::<FatArrow>()?;
                        let close = section_content.parse::<LitStr>()?.value();
                        inline_spans.insert(name, (open, close));

                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                "block_span" => {
                    while !section_content.is_empty() {
                        let name = section_content.parse::<Ident>()?.to_string();
                        section_content.parse::<Colon>()?;
                        let open = section_content.parse::<LitStr>()?.value();
                        section_content.parse::<FatArrow>()?;
                        let close = section_content.parse::<LitStr>()?.value();
                        block_spans.insert(name, (open, close));

                        if !section_content.is_empty() {
                            section_content.parse::<Comma>()?;
                        }
                    }
                }
                _ => return Err(syn::Error::new(section_name.span(), "Unknown section name")),
            }

            if !content.is_empty() {
                content.parse::<Comma>()?;
            }
        }

        Ok(MatcherDef {
            name,
            delimiters,
            angle_brackets,
            line_comments,
            block_comments,
            strings,
            chars,
            block_strings,
            inline_spans,
            block_spans,
        })
    }
}

// Helper function to collect all unique tokens
pub fn collect_tokens(def: &MatcherDef) -> Vec<u8> {
    let mut all_tokens = HashSet::new();

    // Add all token bytes
    for (open, close) in def.delimiters.iter().chain(&def.angle_brackets) {
        for c in open.bytes() {
            all_tokens.insert(c);
        }
        for c in close.bytes() {
            all_tokens.insert(c);
        }
    }

    for comment in &def.line_comments {
        for c in comment.bytes() {
            all_tokens.insert(c);
        }
    }

    for (open, close) in &def.block_comments {
        for c in open.bytes() {
            all_tokens.insert(c);
        }
        for c in close.bytes() {
            all_tokens.insert(c);
        }
    }

    for (open, close) in &def.block_strings {
        for c in open.bytes() {
            all_tokens.insert(c);
        }
        for c in close.bytes() {
            all_tokens.insert(c);
        }
    }

    for s in &def.strings {
        for c in s.bytes() {
            all_tokens.insert(c);
        }
    }

    for s in &def.chars {
        for c in s.bytes() {
            all_tokens.insert(c);
        }
    }

    for (open, close) in def.inline_spans.values() {
        for c in open.bytes() {
            all_tokens.insert(c);
        }
        for c in close.bytes() {
            all_tokens.insert(c);
        }
    }

    for (open, close) in def.block_spans.values() {
        for c in open.bytes() {
            all_tokens.insert(c);
        }
        for c in close.bytes() {
            all_tokens.insert(c);
        }
    }

    // Convert to sorted vector
    let mut tokens_vec: Vec<u8> = all_tokens.into_iter().collect();
    tokens_vec.sort();
    tokens_vec
}
