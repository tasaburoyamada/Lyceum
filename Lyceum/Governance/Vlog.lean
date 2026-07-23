import Lean.Data.Json
import Lyceum.Types
import Lyceum.Inference
import Lyceum.Core.Environment

open Lyceum
open Lean hiding Message

namespace Lyceum.Governance

/-- 
HV-CAD Vector-State Log (.vlog) の構成要素。
参考: HV-CAD-Framework/specs/vlog_format_spec.md
-/
inductive VlogNode where
  | Ctx (domain sub goal : String)
  | Bias (p m s d c : Float)
  | Delta (winner loser : String)
  | ShiftPlus (token : String)
  | ShiftMinus (token : String)
  | ShiftMandatory (token : String)
  | Concept (tokens : List String)
deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- VlogNode を .vlog フォーマットのトークン列に変換する -/
def vlogNodeToTokens (node : VlogNode) : String :=
  match node with
  | .Ctx dom sub goal => s!"@CTX:[DOM:{dom}|SUB:{sub}|GOAL:{goal}]\n"
  | .Bias p m s d c => s!"@BIAS:{"{"}P:{p}, M:{m}, S:{s}, D:{d}, C:{c}{"}"}\n"
  | .Delta w l => s!"@DELTA({w} > {l})\n"
  | .ShiftPlus t => s!"+ [{t}]\n"
  | .ShiftMinus t => s!"- [{t}]\n"
  | .ShiftMandatory t => s!"! [{t}]\n"
  | .Concept ts => s!"@CONCEPT\n{String.intercalate " " (ts.map (fun t => s!"[[{t}]]"))}\n"

/-- VLOG 全体をファイルへ書き込む -/
def writeVlog (path : System.FilePath) (nodes : List VlogNode) : IO Unit := do
  let content := nodes.foldl (fun acc n => acc ++ vlogNodeToTokens n) ""
  IO.FS.writeFile path (content ++ "@EOF\n")

end Lyceum.Governance
