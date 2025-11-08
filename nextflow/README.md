# aa-tRNA-seq Nextflow Pipeline

Nextflow pipeline for processing Oxford Nanopore Technologies (ONT) aa-tRNA-seq data to distinguish between charged (aminoacylated) and uncharged tRNA molecules using Remora machine learning models.

## Features

- **Robust Resume**: Native `-resume` support for seamless pipeline continuation after failures
- **Automatic Reports**: HTML reports, timelines, and execution traces generated for every run
- **Branching Workflows**: Run multiple analyses with different parameters (references, filters) while reusing expensive computations
- **LSF Cluster Ready**: First-class LSF executor support with GPU queue integration
- **Modular Design**: Clean process-based architecture for easy extension and maintenance

## Quick Start

```bash
# Navigate to nextflow directory
cd nextflow

# Run with default configuration (local execution)
nextflow run main.nf

# Run on LSF cluster
nextflow run main.nf -profile lsf

# Resume after failure
nextflow run main.nf -profile lsf -resume
```

## Installation

### Prerequisites

- Nextflow >= 23.04.0
- Conda (optional, for environment management)
- Access to LSF cluster (for cluster execution)

### Install Nextflow

```bash
# Method 1: Direct download
curl -s https://get.nextflow.io | bash

# Method 2: Via conda
conda install -c bioconda nextflow
```

### Setup Pipeline

```bash
# Clone repository (if not already done)
git clone https://github.com/lkwhite/aa-tRNA-seq-pipeline.git
cd aa-tRNA-seq-pipeline/nextflow

# Test LSF integration (optional)
cd ../test-nextflow
nextflow run main.nf -profile lsf
```

## Configuration

### Input Files

Create a sample sheet at `config/samples.tsv`:

```tsv
sample1    /path/to/sequencing/run1
sample2    /path/to/sequencing/run2
sample3    /path/to/sequencing/run3
```

Format: 2-column TSV (no header)
- Column 1: Unique sample ID
- Column 2: Path to sequencing run folder (containing pod5_pass/pod5_fail/pod5 subdirectories)

### Main Configuration

Edit `nextflow.config` to customize:

```groovy
params {
    // Input/Output
    samples = "config/samples.tsv"
    outdir = "results"

    // Analysis profile (for branching workflows)
    analysis_profile = "default"

    // Reference
    alignment {
        reference {
            name = "sacCer3-mature"
            fasta = "resources/ref/sacCer3-mature-tRNAs-dual-adapt-v2.fa"
        }
        bwa_opts = "-W 13 -k 6 -T 20 -x ont2d"
    }

    // Classification threshold
    ml_threshold = 200

    // Optional: Reuse computations from another profile
    reuse_basecalling_from = null
    reuse_alignment_from = null
}
```

## Usage Examples

### Basic Execution

```bash
# Local execution
nextflow run main.nf --samples config/samples.tsv --outdir results

# LSF cluster execution
nextflow run main.nf -profile lsf --samples config/samples.tsv
```

### Branching Workflows

Run multiple analyses with different parameters while reusing expensive computations:

```bash
# 1. Run with default reference (creates basecalling in shared/)
nextflow run main.nf -profile lsf \\
    --analysis_profile "sacCer3-mature" \\
    --outdir results

# 2. Run with alternative reference (reuses basecalling)
nextflow run main.nf -profile lsf \\
    --analysis_profile "sacCer3-precursor" \\
    --alignment.reference.name "sacCer3-precursor" \\
    --alignment.reference.fasta "resources/ref/sacCer3-precursor-tRNAs.fa" \\
    --reuse_basecalling_from "sacCer3-mature" \\
    --outdir results

# 3. Run with different filter settings (reuses basecalling AND alignment)
nextflow run main.nf -profile lsf \\
    --analysis_profile "sacCer3-mature-relaxed" \\
    --filtering.preset "v2-relaxed" \\
    --filtering.bam_filter "-5 20 -3 20 -s" \\
    --reuse_basecalling_from "sacCer3-mature" \\
    --reuse_alignment_from "sacCer3-mature" \\
    --outdir results
```

### Resume After Failure

```bash
# Pipeline fails mid-run - just add -resume
nextflow run main.nf -profile lsf -resume

# Nextflow automatically:
# - Skips completed tasks
# - Reuses cached results
# - Only runs what's needed
```

### Conditional Analyses

```bash
# Disable optional analyses to save time
nextflow run main.nf -profile lsf \\
    --analyses.modkit false \\
    --analyses.remora_signal false \\
    --analyses.coverage false
```

## Output Structure

```
results/
├── shared/                          # Profile-independent (reusable)
│   ├── pod5/                        # Merged pod5 files
│   │   └── sample1/
│   │       └── sample1.pod5
│   ├── basecalling/                 # Basecalled BAMs (GPU-intensive)
│   │   └── sample1/
│   │       └── sample1.rbc.bam
│   └── fastq/                       # Extracted reads
│       └── sample1.fq.gz
│
├── analyses/                        # Profile-specific analyses
│   ├── default/                     # Default analysis profile
│   │   ├── alignment/
│   │   │   └── bam/
│   │   │       └── sample1/
│   │   │           ├── sample1.aln.bam
│   │   │           └── sample1.aln.bam.bai
│   │   ├── classification/
│   │   │   └── bam/
│   │   │       ├── sample1.charging.bam
│   │   │       └── sample1.charging.bam.bai
│   │   ├── final/
│   │   │   └── bam/
│   │   │       ├── sample1.bam
│   │   │       └── sample1.bam.bai
│   │   └── summary/
│   │       ├── tables/
│   │       │   └── sample1/
│   │       │       ├── sample1.charging_prob.tsv.gz
│   │       │       ├── sample1.charging.cpm.tsv.gz
│   │       │       ├── sample1.bcerror.tsv.gz
│   │       │       ├── sample1.align_stats.tsv.gz
│   │       │       ├── sample1.counts.bg.gz
│   │       │       └── sample1.cpm.bg.gz
│   │       └── modkit/
│   │           └── sample1/
│   │               ├── sample1.pileup.bed.gz
│   │               ├── sample1.mod_calls.tsv.gz
│   │               └── sample1.mod_full.tsv.gz
│   │
│   └── sacCer3-precursor/           # Alternative reference profile
│       └── ... (same structure)
│
└── reports/                         # Execution reports
    ├── default/
    │   ├── report.html              # Comprehensive execution report
    │   ├── timeline.html            # Visual timeline
    │   ├── trace.txt                # Detailed task metrics
    │   └── dag.html                 # Workflow DAG
    └── sacCer3-precursor/
        └── ... (reports for each profile)
```

## Pipeline Stages

1. **merge_pods**: Merge pod5 files per sample
2. **rebasecall**: Basecall with dorado (GPU-accelerated)
3. **ubam_to_fastq**: Extract reads to FASTQ
4. **bwa_idx**: Index reference genome
5. **bwa_align**: Align reads with BWA MEM
6. **classify_charging**: Classify charged vs uncharged with Remora (GPU-accelerated)
7. **transfer_bam_tags**: Transfer classification tags to aligned BAM
8. **Summary analyses**: Generate statistics, coverage, modifications

## Execution Profiles

### `standard` (default)
Local execution on single machine

### `lsf`
LSF cluster execution with GPU support

Configuration in `conf/lsf.config`:
- GPU queues for `rebasecall` and `classify_charging`
- Memory scaling on retry
- Resource limits per process

### `conda`
Use conda environment for dependencies

### `docker` (future)
Containerized execution

## Reports

Every run automatically generates reports in `results/reports/{profile}/`:

- **report.html**: Comprehensive execution report with runtime statistics
- **timeline.html**: Visual timeline showing when each task ran
- **trace.txt**: Detailed metrics (CPU, memory, time) for each task
- **dag.html**: Workflow DAG visualization

## Troubleshooting

### Pipeline Fails Mid-Run

```bash
# Always try resume first
nextflow run main.nf -profile lsf -resume
```

### Check What Failed

```bash
# Look at the execution report
open results/reports/default/report.html

# Check the timeline
open results/reports/default/timeline.html

# Look at detailed trace
less results/reports/default/trace.txt
```

### LSF Queue Issues

```bash
# Check available queues
bqueues

# Verify GPU queue exists
bqueues gpu

# Check job status
bjobs
```

### Work Directory

Nextflow stores intermediate files in `work/`:

```bash
# Clean up work directory after successful run
nextflow clean -f

# Keep work directory for debugging
# (it's automatically used by -resume)
```

## Advanced Topics

### Custom Resource Allocation

Edit `conf/lsf.config`:

```groovy
process {
    withName: 'BWA_ALIGN' {
        cpus = 24              // Increase CPUs
        memory = 48.GB         // Increase memory
        time = 8.h             // Increase time limit
    }
}
```

### Add New Processes

1. Create process module in `modules/my_process.nf`
2. Add include statement in `main.nf`
3. Add process call in workflow block
4. Update LSF config if needed

### Multiple References Simultaneously

```bash
# Run in parallel in different directories
nextflow run main.nf -profile lsf --analysis_profile "ref1" --outdir results1 &
nextflow run main.nf -profile lsf --analysis_profile "ref2" --outdir results2 &
```

## Migration from Snakemake

See [MIGRATION.md](MIGRATION.md) for detailed migration guide.

## Citation

If you use this pipeline, please cite:
- Nextflow: https://www.nextflow.io/
- Dorado: https://github.com/nanoporetech/dorado
- Remora: https://github.com/nanoporetech/remora

## Support

For issues or questions:
1. Check execution reports in `results/reports/`
2. Review `.nextflow.log` for detailed logs
3. Open an issue on GitHub

## License

See LICENSE file in repository root.
