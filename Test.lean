import Lyceum.Test.ServerTest

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

  IO.println "All Nomos tests passed."
