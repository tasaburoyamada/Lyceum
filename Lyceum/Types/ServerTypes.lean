import Lyceum.Types
import Lyceum.JsonRpc

namespace Lyceum

/-- サーバーのコンテキスト（不変な設定） -/
structure ServerConfig where
  apiKey : String
  modelName : String
deriving Repr, BEq

/-- サーバーの状態 -/
inductive ServerState where
  | Uninitialized
  | Initialized (config : ServerConfig)
  | Shutdown
deriving Repr, BEq

/-- 入力イベント -/
inductive Input where
  | Request (req : Lean.Json)
  | Notification (notif : Lean.Json)
deriving Repr, BEq

/-- 出力アクション -/
inductive Action where
  | Respond (res : Lean.Json)
  | Notify (notif : Lean.Json)
  | CallLlm (id : Lean.Json) (history : List Message)
  | None
deriving Repr, BEq

end Lyceum
