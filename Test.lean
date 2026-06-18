import Lyceum.Test.ServerTest
import Lyceum.Test.LocalLlmTest -- New import

def main : IO Unit := do
  IO.println "Running Lyceum Nomos Tests..."
  
  if Lyceum.Test.checkNormalTrace then
    IO.println "  [PASS] Normal Initialization Trace"
  else
    IO.eprintln "  [FAIL] Normal Initialization Trace"
    IO.Process.exit 1

  if Lyceum.Test.checkInvalidInitTrace then
    IO.println "  [PASS] Invalid Initialization Rejection Trace"
  else
    IO.eprintln "  [FAIL] Invalid Initialization Rejection Trace"
    IO.Process.exit 1

  -- Run Local LLM tests
  let localLlmTestResult ← Lyceum.Test.runLocalLlmTests
  if localLlmTestResult != 0 then
    IO.eprintln "  [FAIL] Local LLM tests failed."
    IO.Process.exit 1
  else
    IO.println "  [PASS] Local LLM tests passed."

  IO.println "All Lyceum tests passed."
