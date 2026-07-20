# I/O Monad Boundary Test Plan (Lyceum)

This document outlines the boundary test cases for the I/O-centric components of the Lyceum project, focusing on the `IO` monad boundaries, FFI interactions, and state persistence.

## 1. TerminalEnv (Environment Interface)
- [ ] **File System Robustness:**
    - Read/Write to non-existent files.
    - Read/Write with insufficient permissions (EACCES).
    - Handling very large files (memory pressure).
    - File system locking/concurrency during file operations.
- [ ] **Process Execution:**
    - Spawning processes with invalid paths.
    - Process termination/timeout handling (SIGTERM, SIGKILL).
    - Handling empty or malformed stdout/stderr streams.
- [ ] **Raw Mode Handling:**
    - Enabling/disabling raw mode with terminal size errors.

## 2. JsonRpc (Communication Boundary)
- [ ] **Request Parsing:**
    - Empty JSON string.
    - Malformed JSON structure.
    - Unexpected field types.
    - Extremely large payloads exceeding buffer limits.
- [ ] **Method Handling:**
    - Unknown method calls.
    - Missing required parameters for known methods.
    - Method calls with incorrect parameter types.

## 3. Inference (Local LLM & Model Loading)
- [ ] **Model Loading:**
    - Loading non-existent `.gguf` files.
    - Loading corrupted GGUF files (invalid magic numbers, incomplete headers).
    - Out-of-bounds access in tensor offset calculation.
    - Tensor size mismatches (logic vs. physical file size).
- [ ] **Generative Loop:**
    - Empty prompt input.
    - KV-cache overflow (exceeding pre-allocated capacity).
    - Numerical instability (NaN/Inf) in softmax or FFN layers.

## 4. Memory (VectorDB & Persistence)
- [ ] **Vector Operations:**
    - Search with empty DB.
    - Search with zero-length query vectors.
    - Threshold-edge cases (exactly at threshold).
## 5. System Robustness & Concurrency
- [ ] **Race Conditions:**
    - Concurrent requests modifying `ServerState`.
    - Simultaneous read/write access to the same file path/resource.
- [ ] **Timing & Timeout:**
    - I/O operations blocking indefinitely (verify timeout implementation).
    - Handling system interrupts during sensitive I/O phases.
- [ ] **Security:**
    - Sensitive data (e.g., API Keys) leaked into log files/stderr.
    - Potential command injection in `ExecutionAction` (Bash, Docker).
- [ ] **FFI / Native Boundaries:**
    - Memory leaks in `FloatArray` or native tensor buffers.
    - Invalid data passed between Lean and native C/FFI layers.
- [ ] **Resource Exhaustion:**
    - Disk full during log/file write operations.
    - Log buffer saturation.
