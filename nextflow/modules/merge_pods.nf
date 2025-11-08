process MERGE_PODS {
    tag "$sample_id"
    publishDir "${params.outdir}/shared/pod5/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(pod5_files)

    output:
    tuple val(sample_id), path("${sample_id}.pod5"), emit: pod5

    script:
    """
    pod5 merge -t ${task.cpus} -f -o ${sample_id}.pod5 ${pod5_files}
    """
}
