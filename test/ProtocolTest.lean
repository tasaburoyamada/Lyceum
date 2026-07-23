import Lyceum.Protocol.Types
import Lyceum.Protocol.Parser
import Lyceum.Governance.Vlog
import Lyceum.Governance.SelfHealer

namespace Lyceum.Test.ProtocolTest

def testProtocolAndGovernance : IO UInt32 := do
  IO.println "[Lyceum Test] Testing Protocol Parser & Governance Vlog..."
  
  -- 1. Parser Test
  let action := Lyceum.Protocol.parseActionFromText "/quit"
  if action != some .Quit then
    IO.eprintln "  [FAIL] Protocol Parser Mismatch"
    return 1

  -- 2. SelfHealer Test
  let healer : Lyceum.Governance.SelfHealer := default
  let (h2, msg) := healer.healPrompt "Test Error"
  if h2.currentCount != 1 then
    IO.eprintln "  [FAIL] SelfHealer Count Mismatch"
    return 1

  IO.println "  [PASS] Protocol & Governance Test Passed."
  return 0

end Lyceum.Test.ProtocolTest
