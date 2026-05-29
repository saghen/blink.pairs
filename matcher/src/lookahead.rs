use proc_macro2::TokenStream as TokenStream2;
use quote::{format_ident, quote};

use crate::config::MatcherDef;

/// Calculate the maximum number of characters we need to look ahead
/// based on the longest string we need to match
pub fn calculate_max_lookahead(def: &MatcherDef) -> usize {
    let mut max_len = 0;

    for (open, close) in &def.delimiters {
        max_len = max_len.max(open.len());
        max_len = max_len.max(close.len());
    }

    for comment in &def.line_comments {
        max_len = max_len.max(comment.len());
    }

    for (open, close) in &def.block_comments {
        max_len = max_len.max(open.len());
        max_len = max_len.max(close.len());
    }

    for s in &def.strings {
        max_len = max_len.max(s.len());
    }

    for s in &def.chars {
        // Always need to lookahead 2 extra bytes ahead for single-char strings
        // So we can check for the second `'` in `'{'`
        max_len = max_len.max(s.len() + 2);
    }

    for (open, close) in &def.block_strings {
        max_len = max_len.max(open.len());
        max_len = max_len.max(close.len());
    }

    for (open, close) in def.inline_spans.values() {
        max_len = max_len.max(open.len());
        max_len = max_len.max(close.len());
    }

    for (open, close) in def.block_spans.values() {
        max_len = max_len.max(open.len());
        max_len = max_len.max(close.len());
    }

    // Already have the first byte, so subtract 1
    max_len.saturating_sub(1)
}

/// Helper function to generate lookahead token extractors
pub fn generate_lookahead_extractors(max_lookahead: usize) -> TokenStream2 {
    let mut extractors = TokenStream2::new();

    for i in 0..max_lookahead {
        let lookahead = i + 1;
        let token_name = format_ident!("token_{}_byte", lookahead);
        let distance_name = format_ident!("token_{}_distance", lookahead);

        let extractor = quote! {
            let (#token_name, #distance_name) = {
                let next_token = tokens.get(*idx + #lookahead);
                (
                    next_token.map(|t| t.byte).unwrap_or(0),
                    next_token.map(|t| t.col).unwrap_or(usize::MAX) - token.col,
                )
            };
        };

        extractors.extend(extractor);
    }

    extractors
}
