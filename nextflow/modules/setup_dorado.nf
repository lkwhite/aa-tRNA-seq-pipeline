process SETUP_DORADO {
    tag "dorado-${dorado_version}"
    storeDir "${params.outdir}/../resources/tools/dorado/${dorado_version}"

    input:
    val dorado_version

    output:
    path "bin/dorado", emit: dorado_bin

    script:
    // Detect OS and architecture
    def system = System.getProperty("os.name").toLowerCase()
    def arch = System.getProperty("os.arch").toLowerCase()

    // Determine architecture
    def arch_name = ""
    if (arch.contains("aarch64") || arch.contains("arm64")) {
        arch_name = "arm64"
    } else if (arch.contains("amd64") || arch.contains("x86_64")) {
        arch_name = "x64"
    } else {
        error "Unsupported architecture: ${arch}"
    }

    // Determine OS suffix and file extension
    def os_suffix = ""
    def file_ext = ""
    if (system.contains("linux")) {
        os_suffix = "linux-${arch_name}"
        file_ext = "tar.gz"
    } else if (system.contains("mac") || system.contains("darwin")) {
        os_suffix = "osx-${arch_name}"
        file_ext = "zip"
    } else {
        error "Unsupported operating system: ${system}"
    }

    def dorado_url = "https://cdn.oxfordnanoportal.com/software/analysis/dorado-${dorado_version}-${os_suffix}.${file_ext}"

    """
    # Download Dorado
    curl -L -o dorado.${file_ext} ${dorado_url}

    # Extract based on file type
    if [ "${file_ext}" = "tar.gz" ]; then
        tar -xzf dorado.${file_ext} --strip-components=1
    elif [ "${file_ext}" = "zip" ]; then
        unzip -o dorado.${file_ext}
        # Find the extracted directory and move its contents
        mv dorado-*/* ./
    fi

    # Remove the archive
    rm dorado.${file_ext}

    # Make the binary executable
    chmod +x bin/dorado
    """

    stub:
    """
    mkdir -p bin
    touch bin/dorado
    chmod +x bin/dorado
    """
}
