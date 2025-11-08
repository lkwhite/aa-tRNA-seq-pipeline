process GET_CCA_TRNA {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.charging_prob.tsv.gz"), emit: charging_table

    script:
    """
    python ${projectDir}/../workflow/scripts/get_charging_table.py \\
        --tag CL \\
        ${bam} \\
        ${sample_id}.charging_prob.tsv.gz
    """

    stub:
    """
    touch ${sample_id}.charging_prob.tsv.gz
    """
}
