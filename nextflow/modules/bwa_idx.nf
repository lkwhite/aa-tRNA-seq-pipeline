process BWA_IDX {
    tag "$fasta.baseName"
    publishDir "${params.outdir}/shared/indices/${params.alignment.reference.name}", mode: 'copy'

    input:
    path fasta

    output:
    path "${fasta}*", emit: index

    script:
    """
    bwa index ${fasta}
    """

    stub:
    """
    touch ${fasta}.amb
    touch ${fasta}.ann
    touch ${fasta}.bwt
    touch ${fasta}.pac
    touch ${fasta}.sa
    """
}
