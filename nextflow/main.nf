#!/usr/bin/env nextflow

/*
 * aa-tRNA-seq Nextflow Pipeline
 *
 * Pipeline for processing Oxford Nanopore Technologies (ONT) aa-tRNA-seq data.
 * Distinguishes between charged (aminoacylated) and uncharged tRNA molecules
 * using Remora machine learning models trained on nanopore signal data.
 *
 * Migrated from Snakemake pipeline.
 */

nextflow.enable.dsl = 2

// Import modules
include { MERGE_PODS } from './modules/merge_pods'
include { REBASECALL } from './modules/rebasecall'
include { UBAM_TO_FASTQ } from './modules/ubam_to_fastq'
include { BWA_IDX } from './modules/bwa_idx'
include { BWA_ALIGN } from './modules/bwa_align'
include { CLASSIFY_CHARGING } from './modules/classify_charging'
include { TRANSFER_BAM_TAGS } from './modules/transfer_bam_tags'
include { GET_CCA_TRNA } from './modules/get_cca_trna'
include { GET_CCA_TRNA_CPM } from './modules/get_cca_trna_cpm'
include { BASE_CALLING_ERROR } from './modules/base_calling_error'
include { ALIGN_STATS } from './modules/align_stats'
include { BAM_TO_COVERAGE } from './modules/bam_to_coverage'
include { REMORA_SIGNAL_STATS } from './modules/remora_signal_stats'
include { MODKIT_PILEUP } from './modules/modkit_pileup'
include { MODKIT_EXTRACT_CALLS } from './modules/modkit_extract_calls'
include { MODKIT_EXTRACT_FULL } from './modules/modkit_extract_full'
include { SETUP_DORADO } from './modules/setup_dorado'
include { SETUP_MODKIT } from './modules/setup_modkit'
include { DOWNLOAD_DORADO_MODEL } from './modules/download_dorado_model'

/*
 * Print pipeline information
 */
log.info """\
    ═══════════════════════════════════════════════════════════
     A A - t R N A - s e q   P I P E L I N E
    ═══════════════════════════════════════════════════════════
     Analysis Profile : ${params.analysis_profile}
     Reference        : ${params.alignment.reference.name}
     Reference FASTA  : ${params.alignment.reference.fasta}
     ML Threshold     : ${params.ml_threshold}
     Filter Preset    : ${params.filtering.preset}
     Output Directory : ${params.outdir}

     Reuse Basecalling: ${params.reuse_basecalling_from ?: 'No (will basecall)'}
     Reuse Alignment  : ${params.reuse_alignment_from ?: 'No (will align)'}

     Enabled Analyses:
       - ModKit       : ${params.analyses.modkit}
       - Remora Signal: ${params.analyses.remora_signal}
       - Coverage     : ${params.analyses.coverage}
       - Base Error   : ${params.analyses.base_error}
    ═══════════════════════════════════════════════════════════
    """
    .stripIndent()

/*
 * Parse sample sheet
 * Expected format: 2-column TSV with sample_id and data_path
 */
def parse_samples(sample_file) {
    def samples = [:]

    file(sample_file).eachLine { line ->
        // Skip comments and empty lines
        if (line.startsWith('#') || line.trim().isEmpty()) {
            return
        }

        def parts = line.split(/\s+/)
        if (parts.size() != 2) {
            error "Invalid sample file format. Expected 2 columns (sample_id, data_path), got: $line"
        }

        def (sample_id, data_path) = parts

        if (samples.containsKey(sample_id)) {
            samples[sample_id] << data_path
        } else {
            samples[sample_id] = [data_path]
        }
    }

    return samples
}

/*
 * Find pod5 files for a sample
 */
def find_pod5_files(data_paths) {
    def pod5_dirs = ['pod5_pass', 'pod5_fail', 'pod5']
    def all_files = []

    data_paths.each { data_path ->
        pod5_dirs.each { subdir ->
            def search_path = "${data_path}/${subdir}/*.pod5"
            def files = file(search_path)
            if (files) {
                all_files.addAll(files)
            }
        }
    }

    return all_files
}

/*
 * Create input channel from samples file
 */
def create_sample_channel() {
    def samples = parse_samples(params.samples)

    Channel.from(samples.collect { sample_id, data_paths ->
        def pod5_files = find_pod5_files(data_paths)

        if (pod5_files.isEmpty()) {
            error "No pod5 files found for sample: $sample_id in paths: $data_paths"
        }

        tuple(sample_id, pod5_files)
    })
}

/*
 * Helper functions for output paths
 */
def shared_dir(path) {
    // Outputs that are profile-independent (expensive, reusable)
    return "${params.outdir}/shared/${path}"
}

def analysis_dir(path) {
    // Outputs that are profile-specific
    return "${params.outdir}/analyses/${params.analysis_profile}/${path}"
}

/*
 * Main workflow
 */
workflow {
    // Setup tools (if not already installed)
    SETUP_DORADO(params.dorado_version)
    SETUP_MODKIT(params.modkit_version)
    DOWNLOAD_DORADO_MODEL(params.dorado_model)

    // Create sample input channel
    samples_ch = create_sample_channel()

    // Step 1: Merge pod5 files per sample (shared across all analyses)
    MERGE_PODS(samples_ch)

    // Step 2: Basecall with dorado (shared across all analyses)
    // Can be reused from another profile if reuse_basecalling_from is set
    if (params.reuse_basecalling_from) {
        // Reuse existing basecalling
        basecalled_ch = samples_ch.map { sample_id, pod5_files ->
            def bam = file("${shared_dir('basecalling')}/${sample_id}/${sample_id}.rbc.bam")
            tuple(sample_id, bam)
        }
    } else {
        // Perform new basecalling
        REBASECALL(
            MERGE_PODS.out.pod5,
            params.base_calling_model,
            params.dorado_opts
        )
        basecalled_ch = REBASECALL.out.bam
    }

    // Step 3: Convert BAM to FASTQ
    UBAM_TO_FASTQ(basecalled_ch)

    // Step 4: Index reference (only once per reference)
    reference_ch = Channel.fromPath(params.alignment.reference.fasta)
    BWA_IDX(reference_ch)

    // Step 5: Align reads with BWA
    // Can be reused from another profile if reuse_alignment_from is set
    if (params.reuse_alignment_from) {
        // Reuse existing alignment
        aligned_ch = samples_ch.map { sample_id, pod5_files ->
            def bam = file("${params.outdir}/analyses/${params.reuse_alignment_from}/alignment/bam/${sample_id}/${sample_id}.aln.bam")
            def bai = file("${params.outdir}/analyses/${params.reuse_alignment_from}/alignment/bam/${sample_id}/${sample_id}.aln.bam.bai")
            tuple(sample_id, bam, bai)
        }
    } else {
        // Perform new alignment
        BWA_ALIGN(
            UBAM_TO_FASTQ.out.fastq,
            BWA_IDX.out.index.collect(),
            params.alignment.reference.fasta,
            params.alignment.bwa_opts
        )
        aligned_ch = BWA_ALIGN.out.bam
    }

    // Step 6: Classify charging status with Remora
    CLASSIFY_CHARGING(
        MERGE_PODS.out.pod5,
        aligned_ch,
        params.remora_cca_classifier
    )

    // Step 7: Transfer tags from charging BAM to aligned BAM
    TRANSFER_BAM_TAGS(
        CLASSIFY_CHARGING.out.bam,
        aligned_ch
    )

    // Summary and Analysis Steps

    // Get charging probability per read
    GET_CCA_TRNA(TRANSFER_BAM_TAGS.out.bam)

    // Calculate CPM for charged vs uncharged
    GET_CCA_TRNA_CPM(
        GET_CCA_TRNA.out.charging_table,
        params.ml_threshold
    )

    // Optional analyses based on config
    if (params.analyses.base_error) {
        BASE_CALLING_ERROR(
            TRANSFER_BAM_TAGS.out.bam,
            params.alignment.reference.fasta
        )
    }

    // Alignment statistics
    ALIGN_STATS(
        basecalled_ch,
        aligned_ch,
        TRANSFER_BAM_TAGS.out.bam
    )

    if (params.analyses.coverage) {
        BAM_TO_COVERAGE(
            TRANSFER_BAM_TAGS.out.bam,
            params.coverage_opts
        )
    }

    if (params.analyses.remora_signal && params.remora_kmer_table) {
        REMORA_SIGNAL_STATS(
            TRANSFER_BAM_TAGS.out.bam,
            MERGE_PODS.out.pod5,
            params.remora_kmer_table,
            params.remora_opts
        )
    }

    if (params.analyses.modkit) {
        MODKIT_PILEUP(
            TRANSFER_BAM_TAGS.out.bam,
            params.alignment.reference.fasta
        )

        MODKIT_EXTRACT_CALLS(
            TRANSFER_BAM_TAGS.out.bam,
            params.alignment.reference.fasta
        )

        MODKIT_EXTRACT_FULL(
            TRANSFER_BAM_TAGS.out.bam,
            params.alignment.reference.fasta
        )
    }
}
