#!/usr/bin/env nextflow

// Simple test to verify LSF integration works
// Tests: basic job submission, GPU queue, memory allocation

params.test_data = "test.txt"

process TEST_BASIC {
    tag "basic"

    output:
    path("basic_output.txt")

    script:
    """
    echo "Testing basic LSF submission" > basic_output.txt
    hostname >> basic_output.txt
    date >> basic_output.txt
    """
}

process TEST_GPU_QUEUE {
    tag "gpu"
    queue 'gpu'

    output:
    path("gpu_output.txt")

    script:
    """
    echo "Testing GPU queue submission" > gpu_output.txt
    hostname >> gpu_output.txt
    nvidia-smi --query-gpu=name --format=csv,noheader >> gpu_output.txt || echo "No GPU detected" >> gpu_output.txt
    """
}

process TEST_MEMORY {
    tag "memory"
    memory '24 GB'

    output:
    path("memory_output.txt")

    script:
    """
    echo "Testing memory allocation (24GB requested)" > memory_output.txt
    free -h >> memory_output.txt
    """
}

workflow {
    TEST_BASIC()
    TEST_GPU_QUEUE()
    TEST_MEMORY()
}
