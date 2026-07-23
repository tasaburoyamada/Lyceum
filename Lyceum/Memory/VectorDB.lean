import Lean
import Lyceum.Types
import Lyceum.Inference
import Lyceum.Core.Environment

open Lyceum
open Lyceum.Core
open Lean hiding Message
open Lyceum.Core.Environment


namespace Lyceum.Memory

--TEMP_MARKER--

deriving instance Repr for Json

/-- ベクトル表現 -/
structure Vector where
  data : Array Float
deriving Repr, Inhabited, BEq, ToJson, FromJson

/-- 
ベクトルデータベースのエントリー。

ベクトルデータに加えて、元のテキストやメタデータを保持する。
-/
structure VectorEntry where
  id : String
  text : String
  vector : Vector
  metadata : Json := Json.null
deriving Repr, BEq, Inhabited, ToJson, FromJson

/--
インメモリーのベクトルデータベース。
-/
structure VectorDB where
  entries : Array VectorEntry := #[]
deriving Repr, BEq, Inhabited, ToJson, FromJson


instance : EmptyCollection VectorDB where
  emptyCollection := { entries := #[] }

/-- 
コサイン類似度の計算。
一時的な FloatArray アロケーションを完全に排除し、単一ループ走査で計算量を最適化。
-/
def cosineSimilarity (v1 v2 : Vector) : Float := Id.run do
  let d1 := v1.data
  let d2 := v2.data
  let size := d1.size
  if size != d2.size || size == 0 then return 0.0
  else
    let mut dot := 0.0
    let mut sumSq1 := 0.0
    let mut sumSq2 := 0.0
    for i in [0:size] do
      let x1 := d1[i]!
      let x2 := d2[i]!
      dot := dot + x1 * x2
      sumSq1 := sumSq1 + x1 * x1
      sumSq2 := sumSq2 + x2 * x2
    let n1 := Float.sqrt sumSq1
    let n2 := Float.sqrt sumSq2
    if n1 == 0.0 || n2 == 0.0 then return 0.0
    else return dot / (n1 * n2)

/--
ベクトル検索。
クエリベクトルに対して、類似度スコアが閾値以上のものを抽出し、
スコアの降順で上位K件を返す。
-/
def VectorDB.search (self : VectorDB) (query : Vector) (topK : Nat) (threshold : Float := 0.5) : Array (VectorEntry × Float) :=
  let scored := self.entries.filterMap (fun entry =>
    let score := cosineSimilarity query entry.vector
    if score >= threshold then some (entry, score) else none
  )
  -- Floatの比較用にソート
  let sorted := scored.qsort (fun a b => a.2 > b.2)
  sorted.extract 0 topK

/--
データベースへのエントリー追加。
-/
def VectorDB.insert (self : VectorDB) (entry : VectorEntry) : VectorDB :=
  { self with entries := self.entries.push entry }

/-- 永続化: ファイルへ保存 -/
def VectorDB.save (self : VectorDB) (path : String) [TerminalEnv IO] : IO Unit := do
  let json := Lean.toJson self
  TerminalEnv.writeFile (System.FilePath.mk path) json.pretty

/-- 永続化: ファイルから読込 -/
def VectorDB.load (path : String) [TerminalEnv IO] : IO (Except String VectorDB) := do
  if !(← TerminalEnv.pathExists path) then
    return .ok ∅
  let content ← TerminalEnv.readFile (System.FilePath.mk path)
  match Lean.Json.parse content with
  | .ok json => 
      match Lean.fromJson? json with
      | .ok db => return .ok db
      | .error e => return .error s!"JSON Decode error: {e}"
  | .error e => return .error s!"JSON Parse error: {e}"

end Lyceum.Memory
