import Lean
import Lyceum.Types

namespace Lyceum.JsonRpc

open Lean

structure Request where
  id : Json
  method : String
  params : Option Json := none
  jsonrpc : String := "2.0"
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure Response where
  id : Json
  result : Option Json := none
  error : Option Json := none
  jsonrpc : String := "2.0"
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure Notification where
  method : String
  params : Option Json := none
  jsonrpc : String := "2.0"
deriving Repr, ToJson, FromJson, BEq, Inhabited

end Lyceum.JsonRpc
