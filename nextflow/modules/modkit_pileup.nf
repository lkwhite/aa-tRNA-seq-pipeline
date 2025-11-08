process MODKIT_PILEUP {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/modkit/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    val reference_fasta

    output:
    tuple val(sample_id), path("${sample_id}.pileup.bed.gz"), emit: pileup

    script:
    """
    modkit pileup \\
        --ref ${reference_fasta} \\
        ${bam} - \\
        | gzip -9 -c > ${sample_id}.pileup.bed.gz
    """

    stub:
    """
    touch ${sample_id}.pileup.bed.gz
    """
}
