process TRANSFER_BAM_TAGS {
    tag "$sample_id"
    publishDir "${params.outdir}/analyses/${params.analysis_profile}/final/bam", mode: 'copy'

    input:
    tuple val(sample_id), path(charging_bam), path(charging_bai)
    tuple val(sample_id), path(target_bam), path(target_bai)

    output:
    tuple val(sample_id), path("${sample_id}.bam"), path("${sample_id}.bam.bai"), emit: bam

    script:
    """
    python ${projectDir}/../workflow/scripts/transfer_tags.py \\
        --tags ML MM \\
        --rename ML=CL MM=CM \\
        --source ${charging_bam} \\
        --target ${target_bam} \\
        --output ${sample_id}.bam

    samtools index ${sample_id}.bam
    """

    stub:
    """
    touch ${sample_id}.bam
    touch ${sample_id}.bam.bai
    """
}
