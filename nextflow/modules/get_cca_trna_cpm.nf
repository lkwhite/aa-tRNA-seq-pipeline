process GET_CCA_TRNA_CPM {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/summary/tables/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(charging_table)
    val ml_threshold

    output:
    tuple val(sample_id), path("${sample_id}.charging.cpm.tsv.gz"), emit: cpm

    script:
    """
    python ${projectDir}/../workflow/scripts/get_trna_charging_cpm.py \\
        --input ${charging_table} \\
        --output ${sample_id}.charging.cpm.tsv.gz \\
        --ml-threshold ${ml_threshold}
    """

    stub:
    """
    touch ${sample_id}.charging.cpm.tsv.gz
    """
}
