process MODKIT_EXTRACT_FULL {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/modkit/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    val reference_fasta

    output:
    tuple val(sample_id), path("${sample_id}.mod_full.tsv.gz"), emit: mod_full

    script:
    """
    modkit extract full \\
        --bgzf \\
        --threads ${task.cpus} \\
        --reference ${reference_fasta} \\
        --edge-filter 10 \\
        --mapped \\
        ${bam} ${sample_id}.mod_full.tsv.gz
    """

    stub:
    """
    touch ${sample_id}.mod_full.tsv.gz
    """
}
