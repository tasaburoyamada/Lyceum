import Lyceum.Test.ServerTest
import Lyceum.Test.LocalLlmTest
import Lyceum.Test.PhysicalIOTest
import Lyceum.Test.KVCacheTest

def main : IO Unit := do
  IO.println "Running Lyceum Nomos Tests..."
  
  if Lyceum.Test.checkNormalTrace && Lyceum.Test.checkMalformedTrace then
    IO.println "  [PASS] Server Traces (Normal/Malformed)"
  else
    IO.eprintln "  [FAIL] Server Traces"
    IO.Process.exit 1

  -- ... existing tests ...

  -- Run KV Cache tests
  let kvTestResult ← Lyceum.Test.KVCacheTest.runKVCacheTests
  if kvTestResult != 0 then
    IO.eprintln "  [FAIL] KV Cache tests failed."
    IO.Process.exit 1
  else
    IO.println "  [PASS] KV Cache tests passed."

  -- Run Physical I/O tests
  -- ... (rest)

