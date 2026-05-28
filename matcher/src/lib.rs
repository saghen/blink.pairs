use proc_macro::TokenStream;
use quote::quote;
use syn::parse_macro_input;

mod config;
mod lookahead;
mod matcher;

use config::{collect_tokens, MatcherDef};
use lookahead::{calculate_max_lookahead, generate_lookahead_extractors};
use matcher::{create_match_header, MatchArm};

#[proc_macro]
pub fn define_matcher(input: TokenStream) -> TokenStream {
    let def = parse_macro_input!(input as MatcherDef);
    let max_lookahead = calculate_max_lookahead(&def);
    let all_tokens = collect_tokens(&def);
    let token_literals = all_tokens.iter().map(|&t| quote! { #t });
    let lookahead_extractors = generate_lookahead_extractors(max_lookahead);

    // Generate match arms for all patterns
    let mut match_arms = Vec::new();

    // Order matters, we want to prioritize:
    // - block strings and block comments
    // - line comments, strings, and chars
    // - finally, delimiters

    // 1. Block comment patterns
    for (open, close) in &def.block_comments {
        let open_arm = MatchArm::builder(open.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(
                Kind::Opening,
                Token::BlockComment(#open, #close),
                token.col,
            ));
            // Skip tokens based on length of pattern
            for _ in 1..#open.len() {
                tokens.next();
            }
            State::InBlockComment(#open)
        });
        match_arms.push(open_arm.build());

        let close_arm = MatchArm::builder(close.to_string(), max_lookahead)
            .input_state(quote! { State::InBlockComment(#open) })
            .body(quote! {
                matches.push(Match::new(
                    Kind::Closing,
                    Token::BlockComment(#open, #close),
                    token.col,
                ));
                // Skip tokens based on length of pattern
                for _ in 1..#close.len() {
                    tokens.next();
                }
                State::Normal
            });
        match_arms.push(close_arm.build());
    }

    // 2. Block string patterns
    for (open, close) in &def.block_strings {
        let open_arm = MatchArm::builder(open.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(
                Kind::Opening,
                Token::BlockString(#open, #close),
                token.col,
            ));
            // Skip tokens based on length of pattern
            for _ in 1..#open.len() {
                tokens.next();
            }
            State::InBlockString(#open)
        });
        match_arms.push(open_arm.build());

        let close_arm = MatchArm::builder(close.to_string(), max_lookahead)
            .ignore_escaped()
            .input_state(quote! { State::InBlockString(#open) })
            .body(quote! {
                matches.push(Match::new(
                    Kind::Closing,
                    Token::BlockString(#open, #close),
                    token.col,
                ));
                // Skip tokens based on length of pattern
                for _ in 1..#close.len() {
                    tokens.next();
                }
                State::Normal
            });
        match_arms.push(close_arm.build());
    }

    // 3. Block span patterns
    for (name, (open, close)) in &def.block_spans {
        let arm = MatchArm::builder(open.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(Kind::Opening, Token::BlockSpan(#name, #open, #close), token.col));
            // Skip tokens based on length of pattern
            for _ in 1..#open.len() {
                tokens.next();
            }
            State::InBlockSpan(#name)
        });
        match_arms.push(arm.build());

        let close_arm = MatchArm::builder(close.to_string(), max_lookahead)
            .input_state(quote! { State::InBlockSpan(#name) })
            .body(quote! {
                matches.push(Match::new(Kind::Closing, Token::BlockSpan(#name, #open, #close), token.col));
                // Skip tokens based on length of pattern
                for _ in 1..#close.len() {
                    tokens.next();
                }
                State::Normal
            });
        match_arms.push(close_arm.build());
    }

    // 4. Line comment patterns
    for comment in &def.line_comments {
        let arm = MatchArm::builder(comment.to_string(), max_lookahead)
            .ignore_escaped()
            .body(quote! {
                matches.push(Match::line_comment(#comment, token.col));
                // Skip tokens based on length of pattern
                for _ in 1..#comment.len() {
                    tokens.next();
                }
                State::InLineComment
            });
        // TODO: skip tokens based on length of pattern
        match_arms.push(arm.build());
    }

    // 5. String patterns
    for delim in &def.strings {
        // Opening string
        let open_arm = MatchArm::builder(delim.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(Kind::Opening, Token::String(#delim), token.col));
            // Skip tokens based on length of pattern
            for _ in 1..#delim.len() {
                tokens.next();
            }
            State::InString(#delim)
        });
        // TODO: skip tokens based on length of pattern
        match_arms.push(open_arm.build());

        // Closing string
        let close_arm = MatchArm::builder(delim.to_string(), max_lookahead)
            .ignore_escaped()
            .input_state(quote! { State::InString(#delim) })
            .body(quote! {
                matches.push(Match::new(Kind::Closing, Token::String(#delim), token.col));
                // Skip tokens based on length of pattern
                for _ in 1..#delim.len() {
                    tokens.next();
                }
                State::Normal
            });
        // TODO: skip tokens based on length of pattern
        match_arms.push(close_arm.build());
    }

    // 6. Character literal patterns
    for delim in &def.chars {
        // TODO: handle escaped
        let delim_byte = delim.as_bytes()[0];
        let arm = MatchArm::builder(delim.to_string(), max_lookahead)
            .non_adjacent()
            .if_condition(quote! { token_1_byte == #delim_byte && (token_1_distance == 1 || token_1_distance == 2) })
            .body(quote! {
                matches.push(Match::new(Kind::Opening, Token::String(#delim), token.col));
                matches.push(Match::new(Kind::Closing, Token::String(#delim), token.col + token_1_distance));
                tokens.next(); // Skip next token
                State::Normal
            });
        match_arms.push(arm.build());

        let arm = MatchArm::builder(delim.to_string(), max_lookahead)
            .non_adjacent()
            .if_condition(quote! { token_2_byte == #delim_byte && token_2_distance == 2 })
            .body(quote! {
                matches.push(Match::new(Kind::Opening, Token::String(#delim), token.col));
                matches.push(Match::new(Kind::Closing, Token::String(#delim), token.col + token_2_distance));
                tokens.next(); // Skip 2 tokens
                tokens.next();
                State::Normal
            });
        match_arms.push(arm.build());
    }

    // 7. Inline span patterns
    for (name, (open, close)) in &def.inline_spans {
        let arm = MatchArm::builder(open.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(Kind::Opening, Token::InlineSpan(#name, #open, #close), token.col));
            // Skip tokens based on length of pattern
            for _ in 1..#open.len() {
                tokens.next();
            }
            State::InInlineSpan(#name)
        });
        match_arms.push(arm.build());

        let close_arm = MatchArm::builder(close.to_string(), max_lookahead)
            .input_state(quote! { State::InInlineSpan(#name) })
            .body(quote! {
                matches.push(Match::new(Kind::Closing, Token::InlineSpan(#name, #open, #close), token.col));
                // Skip tokens based on length of pattern
                for _ in 1..#close.len() {
                    tokens.next();
                }
                State::Normal
            });
        match_arms.push(close_arm.build());
    }

    // 8. Delimiter patterns
    for (open, close) in &def.delimiters {
        // Opening delimiter
        let open_arm = MatchArm::builder(open.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(Kind::Opening, Token::Delimiter(#open, #close), token.col));
            State::Normal
        });
        match_arms.push(open_arm.build());

        // Closing delimiter
        let close_arm = MatchArm::builder(close.to_string(), max_lookahead).body(quote! {
            matches.push(Match::new(Kind::Closing, Token::Delimiter(#open, #close), token.col));
            State::Normal
        });
        match_arms.push(close_arm.build());
    }

    // Add fallback pattern
    let fallback_arm = quote! { _ => state };
    match_arms.push(fallback_arm);

    // Generate the match statement
    let match_header = create_match_header(max_lookahead);
    let match_stmt = quote! {
        match #match_header {
            #(#match_arms),*
        }
    };

    let name = &def.name;

    // Generate the full implementation
    let expanded = quote! {
        pub struct #name;

        impl Matcher for #name {
            const TOKENS: &[u8] = &[#(#token_literals),*];

            fn call<I>(
                &mut self,
                matches: &mut Vec<Match>,
                tokens: &mut MultiPeek<I>,
                state: State,
                token: CharPos,
                escaped: bool,
            ) -> State
            where
                I: Iterator<Item = CharPos>,
            {
                // Generate lookahead tokens based on the calculated max lookahead
                #lookahead_extractors

                #match_stmt
            }
        }
    };

    expanded.into()
}
