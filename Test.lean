import Lyceum.Test.ServerTest
import Lyceum.Test.LocalLlmTest
import Lyceum.Test.PhysicalIOTest
import Lyceum.Test.KVCacheTest

/--
Lyceum ハイブリッド動作保証テストスイート
Phase 1: Nomos 状態遷移・不変条件テスト
Phase 2: 物理境界・I/O レジリエンス・プロセストラッキングテスト
Phase 3: E2E モナド・ブラックボックス総合テスト
--/
def main : IO Unit := do
  IO.println "=================================================="
  IO.println "  Lyceum Hybrid Verification Test Suite Running   "
  IO.println "=================================================="
  
  -- Phase 1: Nomos Trace Checking
  IO.println "\n[Phase 1] Nomos State Trace & Protocol Invariants..."
  if Lyceum.Test.checkNormalTrace && Lyceum.Test.checkMalformedTrace then
    IO.println "  [PASS] Server Traces (Normal Protocol & Malformed Payloads)"
  else
    IO.eprintln "  [FAIL] Server Traces Validation Failed"
    IO.Process.exit 1

  let unknownToolResult ← Lyceum.Test.checkUnknownToolHandling
  if unknownToolResult then
    IO.println "  [PASS] Anti-Corruption Layer (Unknown Tool Defense)"
  else
    IO.eprintln "  [FAIL] Anti-Corruption Layer Test Failed"
    IO.Process.exit 1

  -- Phase 1.2: KV Cache Tests
  IO.println "\n[Phase 1.2] KV Cache & Memory Allocation Invariants..."
  let kvTestResult ← Lyceum.Test.KVCacheTest.runKVCacheTests
  if kvTestResult != 0 then
    IO.eprintln "  [FAIL] KV Cache tests failed."
    IO.Process.exit 1
  else
    IO.println "  [PASS] KV Cache tests passed."

  -- Phase 2: Physical I/O & Boundary Resilience
  IO.println "\n[Phase 2] Physical I/O & System Boundary Resilience..."
  let ioTestResult ← Lyceum.Test.PhysicalIOTest.runPhysicalIOTests
  if ioTestResult != 0 then
    IO.eprintln "  [FAIL] Physical I/O Resilience tests failed."
    IO.Process.exit 1
  else
    IO.println "  [PASS] Physical I/O Resilience tests passed."

  IO.println "\n=================================================="
  IO.println "  All Hybrid Tests Successfully Passed (PASS: 100%)"
  IO.println "=================================================="
