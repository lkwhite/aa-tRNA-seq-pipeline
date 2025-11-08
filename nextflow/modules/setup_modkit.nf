process SETUP_MODKIT {
    tag "modkit-${modkit_version}"
    storeDir "${params.outdir}/../resources/tools/modkit/${modkit_version}"

    input:
    val modkit_version

    output:
    path "bin/modkit", emit: modkit_bin

    script:
    def modkit_repo = "https://github.com/nanoporetech/modkit"
    """
    # Check if Rust is installed
    if ! command -v rustc &> /dev/null; then
        echo "Rust not found, installing..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "\$HOME/.cargo/env"
    fi

    export PATH="\$HOME/.cargo/bin:\$PATH"
    export CARGO_NET_GIT_FETCH_WITH_CLI=true

    # Install modkit from source
    cargo install --git ${modkit_repo} \\
                 --tag v${modkit_version} \\
                 --root . \\
                 --jobs ${task.cpus}

    # Verify installation
    if [ ! -f "bin/modkit" ]; then
        echo "Error: modkit binary not created"
        exit 1
    fi

    chmod +x bin/modkit
    """

    stub:
    """
    mkdir -p bin
    touch bin/modkit
    chmod +x bin/modkit
    """
}
