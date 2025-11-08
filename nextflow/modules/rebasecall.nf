process REBASECALL {
    tag "$sample_id"
    publishDir "${params.outdir}/shared/basecalling/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(pod5)
    val model_path
    val dorado_opts

    output:
    tuple val(sample_id), path("${sample_id}.rbc.bam"), emit: bam

    script:
    // Pass through CUDA_VISIBLE_DEVICES if set
    def cuda_env = System.getenv('CUDA_VISIBLE_DEVICES') ? "export CUDA_VISIBLE_DEVICES=${System.getenv('CUDA_VISIBLE_DEVICES')}" : ''
    """
    ${cuda_env}

    dorado basecaller ${dorado_opts} ${model_path} ${pod5} > ${sample_id}.rbc.bam
    """

    stub:
    """
    touch ${sample_id}.rbc.bam
    """
}
