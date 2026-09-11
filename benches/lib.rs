use blink_pairs_parser::buffer::ParsedBuffer;
use blink_pairs_parser::parser::{State, tokenize_filetype};
use criterion::{BatchSize, Criterion, criterion_group, criterion_main};
use std::hint::black_box;

fn criterion_benches(c: &mut Criterion) {
    let c_src = include_str!("./languages/c.c");
    // repeat the small rust sample to get a realistically sized file
    let rust_src = include_str!("./languages/rust.rs").repeat(10);

    for (name, src) in [("c", c_src), ("rust", rust_src.as_str())] {
        let lines = || {
            src.lines()
                .map(|l| l.as_bytes().into())
                .collect::<Vec<Box<[u8]>>>()
        };
        let mid = lines().len() / 2;

        c.bench_function(&format!("{name}/tokenize"), |b| {
            b.iter(|| {
                tokenize_filetype(
                    name,
                    black_box(src).lines().map(str::as_bytes),
                    State::Normal,
                )
                .unwrap()
                .count()
            })
        });

        c.bench_function(&format!("{name}/parse/full"), |b| {
            b.iter_batched(
                lines,
                |lines| ParsedBuffer::parse(name, 4, lines),
                BatchSize::LargeInput,
            )
        });

        let mut parsed = ParsedBuffer::parse(name, 4, lines()).unwrap();
        c.bench_function(&format!("{name}/parse/incremental_mid"), |b| {
            b.iter(|| {
                let line = parsed.lines[mid].clone();
                parsed.reparse_range(name, 4, vec![line], mid, mid + 1)
            })
        });

        c.bench_function(&format!("{name}/parse/insert_unmatched_{{"), |b| {
            b.iter(|| {
                parsed.reparse_range(name, 4, vec![b"{".to_vec().into()], mid, mid);
                parsed.ensure_stack_heights();
                parsed.reparse_range(name, 4, vec![], mid, mid + 1);
                parsed.ensure_stack_heights()
            })
        });

        c.bench_function(&format!("{name}/match_pair"), |b| {
            let (line, col) = (mid..)
                .find_map(|l| parsed.matches_by_line[l].first().map(|m| (l, m.col)))
                .unwrap();
            b.iter(|| parsed.match_pair(black_box(line), black_box(col)))
        });
    }
}

criterion_group!(benches, criterion_benches);
criterion_main!(benches);
