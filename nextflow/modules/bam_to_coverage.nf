process BAM_TO_COVERAGE {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)
    val coverage_opts

    output:
    tuple val(sample_id), path("${sample_id}.counts.bg.gz"), path("${sample_id}.cpm.bg.gz"), emit: coverage

    script:
    """
    # Generate CPM coverage
    bamCoverage \\
        -b ${bam} \\
        -o ${sample_id}.cpm.bg \\
        --normalizeUsing CPM \\
        --outFileFormat bedgraph \\
        -bs 1 \\
        -p ${task.cpus} \\
        ${coverage_opts}

    # Generate counts coverage
    bamCoverage \\
        -b ${bam} \\
        -o ${sample_id}.counts.bg \\
        --outFileFormat bedgraph \\
        -bs 1 \\
        -p ${task.cpus} \\
        ${coverage_opts}

    # Compress outputs
    gzip -c ${sample_id}.counts.bg > ${sample_id}.counts.bg.gz
    gzip -c ${sample_id}.cpm.bg > ${sample_id}.cpm.bg.gz
    """

    stub:
    """
    touch ${sample_id}.counts.bg.gz
    touch ${sample_id}.cpm.bg.gz
    """
}
