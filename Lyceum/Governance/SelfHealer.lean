import Lean
import Lyceum.Types
import Lyceum.Inference

namespace Lyceum.Governance

open Lyceum

/-- LLM 応答エラーやフォーマット不備を修復する補修用構造体 -/
structure SelfHealer where
  maxRetries : Nat := 3
  currentCount : Nat := 0
deriving Repr, Inhabited, BEq

/-- パース失敗時にプロンプト補修アドバイスを挿入する -/
def healPrompt (healer : SelfHealer) (rawErr : String) : SelfHealer × Message :=
  let advice := s!"[Self-Healing Prompt Recovery]: Previous response caused error '{rawErr}'. Please format your output strictly."
  let updatedHealer := { healer with currentCount := healer.currentCount + 1 }
  (updatedHealer, Message.mkText .user advice)

end Lyceum.Governance
