process MODKIT_EXTRACT_CALLS {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/modkit/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    val reference_fasta

    output:
    tuple val(sample_id), path("${sample_id}.mod_calls.tsv.gz"), emit: mod_calls

    script:
    """
    modkit extract calls \\
        --bgzf \\
        --reference ${reference_fasta} \\
        --edge-filter 10 \\
        --mapped --pass \\
        ${bam} ${sample_id}.mod_calls.tsv.gz
    """

    stub:
    """
    touch ${sample_id}.mod_calls.tsv.gz
    """
}
