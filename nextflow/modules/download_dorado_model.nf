process DOWNLOAD_DORADO_MODEL {
    tag "$model_name"
    storeDir "${params.outdir}/../resources/models"

    input:
    val model_name

    output:
    path model_name, emit: model_dir

    script:
    """
    # Download the model using dorado
    dorado download --model ${model_name} --models-directory .

    # Verify the download
    if [ ! -d "${model_name}" ]; then
        echo "Error: Model directory not created: ${model_name}"
        exit 1
    fi

    # Create a marker file to ensure directory is not empty
    touch ${model_name}/.downloaded

    # List contents for verification
    echo "Downloaded model contents:"
    ls -la ${model_name}
    """

    stub:
    """
    mkdir -p ${model_name}
    touch ${model_name}/.downloaded
    """
}
