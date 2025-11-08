process BASE_CALLING_ERROR {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    val reference_fasta

    output:
    tuple val(sample_id), path("${sample_id}.bcerror.tsv.gz"), emit: bcerror

    script:
    """
    python ${projectDir}/../workflow/scripts/get_bcerror_freqs.py \\
        ${bam} \\
        ${reference_fasta} \\
        ${sample_id}.bcerror.tsv.gz
    """

    stub:
    """
    touch ${sample_id}.bcerror.tsv.gz
    """
}
