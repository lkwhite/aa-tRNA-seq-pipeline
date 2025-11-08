process BWA_ALIGN {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/alignment/bam/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    path index_files
    val reference_fasta
    val bwa_opts

    output:
    tuple val(sample_id), path("${sample_id}.aln.bam"), path("${sample_id}.aln.bam.bai"), emit: bam

    script:
    """
    bwa mem -C -t ${task.cpus} ${bwa_opts} ${reference_fasta} ${fastq} \\
        | samtools view -F 4 -h \\
        | awk '(\$1 ~ /^@/ || \$4 <= 25)' \\
        | samtools view -Sb - \\
        | samtools sort -o ${sample_id}.aln.bam

    samtools index ${sample_id}.aln.bam
    """

    stub:
    """
    touch ${sample_id}.aln.bam
    touch ${sample_id}.aln.bam.bai
    """
}
