use std::{path::PathBuf, process::Command};

fn main() {
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rerun-if-changed=swift-library/Sources/swift-library");
        println!("cargo:rerun-if-changed=swift-library/Package.swift");

        let bridge_files = vec!["src/macos_bridge.rs"];
        swift_bridge_build::parse_bridges(bridge_files)
            .write_all_concatenated(swift_bridge_out_dir(), "rust-calls-swift");

        compile_swift();

        println!("cargo:rustc-link-lib=static=swift-library");
        println!(
            "cargo:rustc-link-search={}",
            swift_library_static_lib_dir().to_str().unwrap()
        );

        let xcode_path = if let Ok(output) = std::process::Command::new("xcode-select")
            .arg("--print-path")
            .output()
        {
            String::from_utf8(output.stdout.as_slice().into())
                .unwrap()
                .trim()
                .to_string()
        } else {
            "/Applications/Xcode.app/Contents/Developer".to_string()
        };
        println!(
            "cargo:rustc-link-search={}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/",
            &xcode_path
        );
        println!("cargo:rustc-link-search={}", "/usr/lib/swift");
        println!("cargo:rustc-link-arg=-Wl,-rpath,/usr/lib/swift");
        println!("cargo:rustc-link-arg=-Wl,-rpath,/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx");

        tauri_build::build()
    }
}

fn compile_swift() {
    let swift_package_dir = manifest_dir().join("swift-library");

    let mut cmd = Command::new("swift");
    cmd.current_dir(swift_package_dir).arg("build").args(&[
        "-Xswiftc",
        "-import-objc-header",
        "-Xswiftc",
        swift_source_dir()
            .join("bridging-header.h")
            .to_str()
            .unwrap(),
    ]);

    if is_release_build() {
        cmd.args(&["-c", "release"]);
    }

    match cmd.output() {
        Ok(output) => {
            if !output.status.success() {
                panic!(
                    "\n🛑 SWIFT COMPILATION FAILED! 🛑\n\nStdout:\n{}\n\nStderr:\n{}\n",
                    String::from_utf8_lossy(&output.stdout),
                    String::from_utf8_lossy(&output.stderr)
                );
            }
        }
        Err(e) => {
            panic!("Failed to execute 'swift build' command: {}", e);
        }
    }
}

fn swift_bridge_out_dir() -> PathBuf {
    generated_code_dir()
}

fn manifest_dir() -> PathBuf {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    PathBuf::from(manifest_dir)
}

fn is_release_build() -> bool {
    std::env::var("PROFILE").unwrap() == "release"
}

fn swift_source_dir() -> PathBuf {
    manifest_dir().join("swift-library/Sources/swift-library")
}

fn generated_code_dir() -> PathBuf {
    swift_source_dir().join("generated")
}

fn swift_library_static_lib_dir() -> PathBuf {
    let debug_or_release = if is_release_build() {
        "release"
    } else {
        "debug"
    };

    manifest_dir().join(format!("swift-library/.build/{}", debug_or_release))
}
