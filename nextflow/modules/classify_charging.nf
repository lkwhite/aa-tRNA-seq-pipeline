process CLASSIFY_CHARGING {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/classification/bam", mode: 'copy'

    input:
    tuple val(sample_id), path(pod5)
    tuple val(sample_id), path(bam), path(bai)
    val model_path

    output:
    tuple val(sample_id), path("${sample_id}.charging.bam"), path("${sample_id}.charging.bam.bai"), emit: bam

    script:
    // Pass through CUDA_VISIBLE_DEVICES if set
    def cuda_env = System.getenv('CUDA_VISIBLE_DEVICES') ? "export CUDA_VISIBLE_DEVICES=${System.getenv('CUDA_VISIBLE_DEVICES')}" : ''
    """
    ${cuda_env}

    remora infer from_pod5_and_bam ${pod5} ${bam} \\
        --model ${model_path} \\
        --out-bam ${sample_id}.charging.bam \\
        --reference-anchored \\
        --device 0

    # Sort the result
    samtools sort ${sample_id}.charging.bam > ${sample_id}.charging.sorted.bam
    mv ${sample_id}.charging.sorted.bam ${sample_id}.charging.bam

    samtools index ${sample_id}.charging.bam
    """

    stub:
    """
    touch ${sample_id}.charging.bam
    touch ${sample_id}.charging.bam.bai
    """
}
