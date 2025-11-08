## Migration Guide: Snakemake → Nextflow

This guide helps you transition from the Snakemake version to the Nextflow version of the aa-tRNA-seq pipeline.

## Key Differences

| Aspect | Snakemake | Nextflow |
|--------|-----------|----------|
| **Resume** | `snakemake --rerun-incomplete` | `nextflow run -resume` |
| **Reports** | `snakemake --report report.html` | Automatic (always generated) |
| **Config** | YAML files | Groovy config + CLI params |
| **Cluster** | Profile files in cluster/ | Built-in executor system |
| **Dry run** | `snakemake -n` | `nextflow run -preview` (limited) |
| **DAG** | `snakemake --dag` | Automatic DAG in reports |

## Command Comparison

### Running the Pipeline

**Snakemake:**
```bash
snakemake --cores 12 --configfile config/config-test.yml

# On LSF
snakemake --profile cluster/lsf --configfile config/config-test.yml
```

**Nextflow:**
```bash
nextflow run main.nf

# On LSF
nextflow run main.nf -profile lsf
```

### Resume After Failure

**Snakemake:**
```bash
snakemake --cores 12 --configfile config/config-test.yml --rerun-incomplete
```

**Nextflow:**
```bash
nextflow run main.nf -profile lsf -resume
```

### Generate Reports

**Snakemake:**
```bash
snakemake --report report.html
```

**Nextflow:**
```bash
# Reports are automatic! Just look in:
results/reports/{profile}/report.html
results/reports/{profile}/timeline.html
results/reports/{profile}/trace.txt
```

### Force Re-run

**Snakemake:**
```bash
snakemake --forcerun <rule_name>
```

**Nextflow:**
```bash
# Delete work directory for specific process
rm -rf work/*/*/{process_hash}

# Or clean everything and re-run
nextflow clean -f
nextflow run main.nf -profile lsf
```

## Configuration Migration

### Sample Sheet

**No change** - same format:

```tsv
sample1    /path/to/data1
sample2    /path/to/data2
```

### Pipeline Parameters

**Snakemake (config/config-base.yml):**
```yaml
fasta: "resources/ref/sacCer3-mature-tRNAs.fa"
base_calling_model: "resources/models/rna004_130bps_sup@v5.1.0"

opts:
  bwa: "-W 13 -k 6 -T 20 -x ont2d"
  dorado: "--modified-bases pseU m5C inosine_m6A --emit-moves"
```

**Nextflow (nextflow.config or CLI):**
```groovy
params {
    alignment {
        reference {
            fasta = "resources/ref/sacCer3-mature-tRNAs.fa"
        }
        bwa_opts = "-W 13 -k 6 -T 20 -x ont2d"
    }
    base_calling_model = "resources/models/rna004_130bps_sup@v5.1.0"
    dorado_opts = "--modified-bases pseU m5C inosine_m6A --emit-moves"
}
```

Or via command line:
```bash
nextflow run main.nf \\
    --alignment.reference.fasta "resources/ref/sacCer3-mature-tRNAs.fa" \\
    --alignment.bwa_opts "-W 13 -k 6 -T 20 -x ont2d"
```

### LSF Configuration

**Snakemake (cluster/lsf/config.yaml):**
```yaml
executor: lsf
jobs: 300

set-resources:
  - rebasecall:lsf_queue="gpu"
  - rebasecall:lsf_extra="-gpu num=1:j_exclusive=yes"
  - rebasecall:mem_mb=24
```

**Nextflow (conf/lsf.config):**
```groovy
executor {
    name = 'lsf'
    queueSize = 300
}

process {
    withName: 'REBASECALL' {
        queue = 'gpu'
        clusterOptions = '-P aatrnaseq -gpu "num=1:j_exclusive=yes"'
        memory = 24.GB
    }
}
```

## Workflow Concepts

### Rules → Processes

**Snakemake rule:**
```python
rule bwa_align:
    input:
        reads=rules.ubam_to_fastq.output,
        idx=rules.bwa_idx.output,
    output:
        bam=os.path.join(outdir, "bam", "aln", "{sample}.aln.bam"),
    params:
        index=config["fasta"],
        bwa_opts=config["opts"]["bwa"],
    threads: 12
    shell:
        """
        bwa mem -t {threads} {params.bwa_opts} {params.index} {input.reads} \\
            | samtools sort -o {output.bam}
        """
```

**Nextflow process:**
```groovy
process BWA_ALIGN {
    tag "$sample_id"

    input:
    tuple val(sample_id), path(fastq)
    path index_files
    val reference_fasta
    val bwa_opts

    output:
    tuple val(sample_id), path("${sample_id}.aln.bam"), emit: bam

    script:
    """
    bwa mem -t ${task.cpus} ${bwa_opts} ${reference_fasta} ${fastq} \\
        | samtools sort -o ${sample_id}.aln.bam
    """
}
```

### Wildcards → Channels

**Snakemake:**
```python
# Wildcards automatically propagate through rules
expand("{sample}.bam", sample=samples.keys())
```

**Nextflow:**
```groovy
// Explicit channel creation
Channel
    .from(samples.keySet())
    .map { sample -> tuple(sample, file("data/${sample}.pod5")) }
    .set { samples_ch }
```

### Config Variables → Params

**Snakemake:**
```python
config["fasta"]
config["opts"]["bwa"]
```

**Nextflow:**
```groovy
params.alignment.reference.fasta
params.alignment.bwa_opts
```

## Feature Mapping

### Branching Workflows

**Snakemake (proposed):**
```bash
# Would require custom implementation
analysis_profile: "sacCer3-mature"
```

**Nextflow (built-in):**
```bash
nextflow run main.nf --analysis_profile "sacCer3-mature"
nextflow run main.nf --analysis_profile "sacCer3-precursor" \\
    --reuse_basecalling_from "sacCer3-mature"
```

### Conditional Execution

**Snakemake:**
```python
# In pipeline_outputs()
if "remora_kmer_table" in config and config["remora_kmer_table"]:
    outs += expand("summary/{sample}.remora.tsv.gz", sample=samples)
```

**Nextflow:**
```groovy
// In workflow block
if (params.analyses.remora_signal && params.remora_kmer_table) {
    REMORA_SIGNAL_STATS(bam_ch, pod5_ch, params.remora_kmer_table)
}
```

### Protected Files

**Snakemake:**
```python
output:
    protected(os.path.join(outdir, "bam", "{sample}.bam"))
```

**Nextflow:**
```groovy
// Use publishDir with mode 'copy' and chmod
publishDir path, mode: 'copy', fileMode: '0444'
```

## Output Directory Structure

### Snakemake (current)

```
results/
├── pod5/
├── bam/
│   ├── rebasecall/
│   ├── aln/
│   └── final/
├── fq/
└── summary/
```

### Nextflow (new)

```
results/
├── shared/              # Reusable across profiles
│   ├── pod5/
│   ├── basecalling/
│   └── fastq/
├── analyses/           # Profile-specific
│   └── {profile}/
│       ├── alignment/
│       ├── classification/
│       ├── final/
│       └── summary/
└── reports/           # Execution reports
    └── {profile}/
```

**Why the change?**
- Enables branching workflows (multiple analyses from same basecalling)
- Clear separation of expensive vs. cheap operations
- Better organization for comparison studies

## Common Workflows

### 1. Basic Run (Same as Before)

**Snakemake:**
```bash
snakemake --profile cluster/lsf --configfile config/config-test.yml
```

**Nextflow:**
```bash
cd nextflow
nextflow run main.nf -profile lsf --samples ../config/samples.tsv
```

### 2. Resume After Crash

**Snakemake:**
```bash
# Same command, Snakemake checks timestamps
snakemake --profile cluster/lsf --configfile config/config-test.yml --rerun-incomplete
```

**Nextflow:**
```bash
# Just add -resume
nextflow run main.nf -profile lsf -resume
```

### 3. Test Different Reference (NEW!)

**Snakemake:**
```bash
# Would need to manually edit config and manage outputs
# Risk of overwriting previous results
```

**Nextflow:**
```bash
# Original run
nextflow run main.nf -profile lsf \\
    --analysis_profile "sacCer3-mature"

# Alternative reference (reuses basecalling!)
nextflow run main.nf -profile lsf \\
    --analysis_profile "hg38-mature" \\
    --alignment.reference.fasta "resources/ref/hg38-mature.fa" \\
    --reuse_basecalling_from "sacCer3-mature"
```

## Troubleshooting Migration Issues

### "Process not found" Error

**Problem:** Missing module import

**Solution:**
```groovy
// Add to main.nf
include { MY_PROCESS } from './modules/my_process'
```

### "File not found" in LSF Jobs

**Problem:** Working directory not accessible on compute nodes

**Solution:** Ensure `work/` is on shared filesystem, or use:
```groovy
// In nextflow.config
process.scratch = true
```

### Different Results from Snakemake Version

**Problem:** Slight differences in process execution

**Solution:**
1. Check all parameters match between configs
2. Verify same tool versions in PATH
3. Compare shell commands in `.command.sh` files in `work/` directory
4. Check Snakemake log vs Nextflow trace

### Memory/Time Limits

**Problem:** Jobs killed for exceeding resources

**Solution:** Edit `conf/lsf.config`:
```groovy
process {
    withName: 'PROBLEMATIC_PROCESS' {
        memory = { 64.GB * task.attempt }  // Doubles on retry
        time = { 12.h * task.attempt }
    }
}
```

## Validation Checklist

After migrating, verify:

- [ ] Sample sheet parses correctly
- [ ] Pod5 files found for all samples
- [ ] Reference genome indexed correctly
- [ ] GPU queues accessible for rebasecall/classify_charging
- [ ] Output files match Snakemake version
- [ ] Reports generated successfully
- [ ] Resume works after interruption
- [ ] Branching workflows create separate outputs

## Getting Help

1. **Check execution reports**: `results/reports/{profile}/report.html`
2. **Review logs**: `.nextflow.log` in run directory
3. **Inspect work directory**: `work/*/*/.command.sh` and `.command.log`
4. **Compare configs**: Ensure parameters match Snakemake version
5. **Test locally first**: Run `nextflow run main.nf` before LSF submission

## Rollback Plan

If you need to return to Snakemake:

1. Nextflow outputs are in `nextflow/results/`
2. Snakemake outputs remain in original `results/`
3. Both can coexist for validation
4. Keep both versions until confident in migration

## Why Migrate?

**Resume capability:**
- Snakemake: Requires checking timestamps, can miss failures
- Nextflow: Content-based caching, robust to any interruption

**Reports:**
- Snakemake: Manual generation, limited info
- Nextflow: Automatic, comprehensive timeline/resource usage

**Branching workflows:**
- Snakemake: Would require custom implementation
- Nextflow: Built-in with profile system

**Cluster integration:**
- Snakemake: Profile-based, varies by scheduler
- Nextflow: Native executor system, same interface everywhere

**Learning curve:**
- Initial: ~1-2 weeks to learn Nextflow concepts
- Long-term: More intuitive for complex workflows, better debugging

## Next Steps

1. Test LSF integration: `cd test-nextflow && nextflow run main.nf -profile lsf`
2. Run small sample: Use 1-2 samples to validate results match Snakemake
3. Compare outputs: Verify BAM files, tables, and statistics are identical
4. Run full dataset: Once validated, migrate production runs
5. Deprecate Snakemake: After 3-6 months of successful Nextflow use

Good luck with the migration! The investment in learning Nextflow pays off quickly with better resume, reporting, and workflow flexibility.
