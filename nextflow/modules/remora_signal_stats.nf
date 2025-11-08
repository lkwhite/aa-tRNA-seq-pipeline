process REMORA_SIGNAL_STATS {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    tuple val(sample_id), path(pod5)
    val kmer_table
    val remora_opts

    output:
    tuple val(sample_id), path("${sample_id}.remora.tsv.gz"), emit: remora_stats

    script:
    """
    python ${projectDir}/../workflow/scripts/extract_signal_metrics.py \\
        --pod5_dir ${pod5} \\
        --bam ${bam} \\
        --kmer ${kmer_table} \\
        --sample_name ${sample_id} \\
        ${remora_opts} \\
        | gzip -c \\
        > ${sample_id}.remora.tsv.gz
    """

    stub:
    """
    touch ${sample_id}.remora.tsv.gz
    """
}
