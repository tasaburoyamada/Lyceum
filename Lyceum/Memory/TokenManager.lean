import Lean
import Lyceum.Types
import Lyceum.Inference -- For AppError (implicitly used)

open Lyceum

open Lean hiding Message

namespace Lyceum.Memory.TokenManager

/--
リストの安全な切り詰め処理。
先頭から指定された要素数だけを残す。
-/
def truncateList (n : Nat) (l : List α) : List α :=
  l.take n

/--
切り詰められたリストの長さが、元のリストの長さ以下であることの証明。
-/
theorem truncateList_length_le (n : Nat) (l : List α) : (truncateList n l).length ≤ l.length := by
  simp [truncateList]
  omega

/--
切り詰められたリストの長さが、指定した長さ n 以下であることの証明。
-/
theorem truncateList_length_le_n (n : Nat) (l : List α) : (truncateList n l).length ≤ n := by
  simp [truncateList]
  omega

/-- トークン数の概算見積もり -/
def estimateTokens (s : String) : Nat :=
  let rec loop (chars : List Char) (acc : Nat) : Nat :=
    match chars with
    | [] => acc
    | c :: rest =>
        -- 日本語や特殊文字は1文字1トークン、半角英数は4文字1トークン程度
        let val := c.toNat
        let weight := if val > 128 then 4 else 1 -- 簡易的な重み付け
        loop rest (acc + weight)
  (loop s.toList 0) / 4

/-- メッセージ履歴全体のトークン数を概算する -/
def countMessageTokens (m : Lyceum.Message) : Nat :=
  m.parts.foldl (fun acc p => acc + match p with
    | .text t => estimateTokens t
    | .image _ d => (d.size / 1024) * 10 -- 1KB あたり 10トークン
    | _ => 10
  ) 0

end Lyceum.Memory.TokenManager
