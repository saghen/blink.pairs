fn main() {
    // delete existing version file created by blink.download
    let _ = std::fs::remove_file("target/release/version");

    println!("cargo:rustc-check-cfg=cfg(have_cold_path)");
    if std::process::Command::new("rustc")
        .arg("--version")
        .output()
        .ok()
        .is_some_and(|out| {
            let out = String::from_utf8_lossy(&out.stdout);

            if let Some(version) = out.split(" ").nth(1) // extract version component from `rustc 1.98.0-nightly (<commit_hash>)`
                && let Some(version) = version.split("-").next() // remove any trailing tags like `-nightly`
                && let &[major, minor, patch] = version
                    .split(".")
                    .filter_map(|n| str::parse::<u32>(n).ok())
                    .collect::<Vec<_>>()
                    .as_slice()
            {
                // Only enable cold_path if we know for sure that rust >= 1.95.0
                (major, minor, patch) >= (1, 95, 0)
            } else {
                false
            }
        })
    {
        println!("cargo:rustc-cfg=have_cold_path");
    }
}
