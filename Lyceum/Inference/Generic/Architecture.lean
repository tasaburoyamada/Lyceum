import Lean
import Std.Data.HashMap

deriving instance Repr for ByteArray

namespace Lyceum.Inference.Generic

/--
モデルの構造を記述する、アーキテクチャに依存しない汎用的なレコード。
GGUFファイルのメタデータから動的に構築される。
--/
structure ModelArchitecture where
  name : String
  vocabSize : Nat
  hiddenSize : Nat
  numLayers : Nat
  numHeads : Nat
  headDim : Nat
deriving Inhabited, Repr

/-- 
GGUFテンソルの量子化タイプ。
ggml_type enumに対応する。
--/
inductive QuantizationType where
  | F32
  | Q8_0
  | Q4_0
  | Q2_K
  | Q1_K -- This is our target
deriving Inhabited, Repr, BEq

/--
量子化済みテンソル（生データ）。
ディスクからロードされたままの、デコードされていないByteArrayを保持する。
--/
structure RawQuantizedTensor where
  name : String
  qType : QuantizationType
  dims : List Nat
  data : ByteArray
deriving Inhabited, Repr

/-- 
任意のLLMアーキテクチャを表現する生モデル構造。
テンソルは名前をキーとするHashMapで管理される。
--/
structure RawGenericModel where
  arch : ModelArchitecture
  tensors : Std.HashMap String RawQuantizedTensor
deriving Inhabited, Repr

end Lyceum.Inference.Generic
