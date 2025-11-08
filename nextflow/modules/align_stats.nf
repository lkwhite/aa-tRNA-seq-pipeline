process ALIGN_STATS {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(unmapped_bam)
    tuple val(sample_id), path(aligned_bam), path(aligned_bai)
    tuple val(sample_id), path(classified_bam), path(classified_bai)

    output:
    tuple val(sample_id), path("${sample_id}.align_stats.tsv.gz"), emit: stats

    script:
    """
    python ${projectDir}/../workflow/scripts/get_align_stats.py \\
        -o ${sample_id}.align_stats.tsv.gz \\
        -a unmapped aligned classified \\
        -i ${sample_id} \\
        -b ${unmapped_bam} ${aligned_bam} ${classified_bam}
    """

    stub:
    """
    touch ${sample_id}.align_stats.tsv.gz
    """
}
