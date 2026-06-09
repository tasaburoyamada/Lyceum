import Lean
import Lyceum.Types

namespace Lyceum.JsonRpc

open Lean

structure Request where
  jsonrpc : String := "2.0"
  id : Json
  method : String
  params : Json := Json.null
deriving Repr, ToJson, FromJson, BEq

structure Response where
  jsonrpc : String := "2.0"
  id : Json
  result : Option Json := none
  error : Option Json := none
deriving Repr, ToJson, FromJson, BEq

structure Notification where
  jsonrpc : String := "2.0"
  method : String
  params : Json := Json.null
deriving Repr, ToJson, FromJson, BEq

end Lyceum.JsonRpc
