import Lyceum.Inference.Generic.KVCache
import Lyceum.Types
import Std.Data.HashMap

namespace Lyceum.Test.KVCacheTest

open Lyceum.Inference.Generic

def testInvalidCacheUpdate : IO Unit := do
  let cache : GenericKVCache := { keys := #[], values := #[] }
  -- Attempt update on empty cache
  match updateCacheLayer cache 0 #[1.0] #[1.0] with
  | Except.error _ => IO.println "[PASS] InvalidCacheUpdate caught"
  | Except.ok _ => throw (IO.userError "[FAIL] InvalidCacheUpdate should have been returned")

def runKVCacheTests : IO Int := do
  try
    testInvalidCacheUpdate
    return 0
  catch _ => return 1
