process UBAM_TO_FASTQ {
    tag "$sample_id"
    publishDir "${params.outdir}/shared/fastq", mode: 'copy'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.fq.gz"), emit: fastq

    script:
    """
    samtools fastq -T "*" ${bam} | gzip > ${sample_id}.fq.gz
    """

    stub:
    """
    touch ${sample_id}.fq.gz
    """
}
