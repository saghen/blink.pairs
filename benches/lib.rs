use blink_pairs_parser::parser::{parse_filetype, State};
use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

fn criterion_benches(c: &mut Criterion) {
    let c_lines = include_str!("./languages/c.c")
        .lines()
        .collect::<Box<[_]>>();
    let rust_lines = include_str!("./languages/rust.rs")
        .lines()
        .collect::<Box<[_]>>();

    c.bench_function("parse simd - c", |b| {
        b.iter(|| parse_filetype("c", black_box(&c_lines), State::Normal))
    });

    c.bench_function("parse simd - rust", |b| {
        b.iter(|| parse_filetype("rust", black_box(&rust_lines), State::Normal))
    });
}

criterion_group!(benches, criterion_benches);
criterion_main!(benches);
