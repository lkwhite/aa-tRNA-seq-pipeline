# Nextflow LSF Integration Test

This is a simple test to verify Nextflow works with your LSF cluster setup.

## Prerequisites

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash
# Or if already installed via conda: which nextflow
```

## Run Tests

### Test locally (no LSF):
```bash
cd test-nextflow
nextflow run main.nf -profile local
```

### Test with LSF:
```bash
cd test-nextflow
nextflow run main.nf -profile lsf
```

### Test with LSF and get reports:
```bash
cd test-nextflow
nextflow run main.nf -profile lsf -with-report -with-timeline -with-dag
```

## What to Check

After running, check:

1. **Jobs submitted to LSF correctly:**
   ```bash
   bjobs  # Should show nextflow jobs
   ```

2. **Execution reports generated:**
   - `test-results/report.html` - Runtime statistics
   - `test-results/timeline.html` - Timeline view
   - `test-results/dag.html` - DAG visualization
   - `test-results/trace.txt` - Detailed execution trace

3. **GPU queue works:**
   - Check `gpu_output.txt` confirms GPU access or expected queue

4. **Memory allocation respected:**
   - Check LSF job submission used correct memory flags

## Resume Test

```bash
# Kill the pipeline mid-run (Ctrl+C)
# Then resume:
nextflow run main.nf -profile lsf -resume

# Should skip completed tasks and only run what's needed
```

## Expected Output

```
N E X T F L O W  ~  version 23.10.0
Launching `main.nf` [somename] DSL2 - revision: abc123

executor >  lsf (3)
[xx/yyyyyy] process > TEST_BASIC        [100%] 1 of 1 ✔
[xx/yyyyyy] process > TEST_GPU_QUEUE    [100%] 1 of 1 ✔
[xx/yyyyyy] process > TEST_MEMORY       [100%] 1 of 1 ✔

Completed at: 01-Jan-2025 12:00:00
Duration    : 2m 30s
CPU hours   : 0.1
Succeeded   : 3
```

## Troubleshooting

If jobs don't submit:
- Check LSF queue names match your cluster: `bqueues`
- Check project tag is valid: `-P aatrnaseq`
- Look at `.nextflow.log` for submission commands
