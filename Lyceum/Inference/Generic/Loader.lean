import Lean
import Lyceum.Inference.Generic.Architecture
import Lyceum.Types
import Lyceum.Core.Environment
import Lyceum.Core.IO
import Std.Data.HashMap

import LeanTensor.Math.Gguf.Types
import LeanTensor.Math.Gguf.Reader
import LeanTensor.Math.Gguf.Parser

open Lib.Gguf
open Std

namespace Lyceum.Inference.Generic.Loader

def ggmlTypeToQuantizationType (ggmlType : UInt32) : Except String QuantizationType :=
  match ggmlType.toNat with
  | 0 => Except.ok QuantizationType.F32
  | 2 => Except.ok QuantizationType.Q4_0
  | 9 => Except.ok QuantizationType.Q1_K
  | _ => Except.error s!"Unsupported GGUF quantization type: {ggmlType}"

def calcTensorSize (prod : Nat) (qType : QuantizationType) : Nat :=
  match qType with
  | .F32  => prod * 4
  | .Q4_0 => (prod / 32) * 18
  | .Q1_K => (prod + 7) / 8
  | _     => 0

/-- GGUFメタデータ値の物理サイズを正確に計算する --/
def getMetadataDataSize (v : MetadataValue) : Nat :=
  match v with
  | .uint8 _ | .int8 _ | .bool _ => 1
  | .uint16 _ | .int16 _ => 2
  | .uint32 _ | .int32 _ | .float32 _ => 4
  | .uint64 _ | .int64 _ | .float64 _ => 8
  | .string s => 8 + s.toUTF8.size
  | .array _ el => 4 + 8 + el.foldl (fun acc e => acc + getMetadataDataSize e) 0

/--
GGUFファイルをロードし、汎用的な `RawGenericModel` を構築する。
メタデータサイズからテンソル情報テーブルの開始オフセットを数学的に特定し、物理ロードを完遂する。
--/
def loadRawGenericModel (modelPath : String) [Lyceum.Core.TerminalEnv IO] : IO (Except AppError RawGenericModel) := do
  let metaRes ← Lib.Gguf.parseGgufMetadata modelPath
  match metaRes with
  | Except.error e => return Except.error (AppError.ModelError s!"GGUF metadata error: {e}")
  | Except.ok (header, metadataList) =>
      let mut metaMap : Std.HashMap String MetadataValue := {}
      let mut totalMetaSize : Nat := 0
      for (k, v) in metadataList do
        metaMap := metaMap.insert k v
        totalMetaSize := totalMetaSize + 8 + k.toUTF8.size + 4 + getMetadataDataSize v
      
      let archResult : Except String ModelArchitecture := do
        let getVal (key : String) : Option MetadataValue := metaMap.get? key
        let name := getVal "general.name" >>= fun v => match v with | .string s => some s | _ => none
        let vocabSize := getVal "llama.vocab_size" >>= fun v => match v with | .uint32 v => some v.toNat | .uint64 v => some v.toNat | _ => none
        let hiddenSize := getVal "llama.embedding_length" >>= fun v => match v with | .uint32 v => some v.toNat | .uint64 v => some v.toNat | _ => none
        let numLayers := getVal "llama.block_count" >>= fun v => match v with | .uint32 v => some v.toNat | .uint64 v => some v.toNat | _ => none
        let numHeads := getVal "llama.attention.head_count" >>= fun v => match v with | .uint32 v => some v.toNat | .uint64 v => some v.toNat | _ => none
        let headDim := getVal "llama.attention.head_count_kv" >>= fun v => match v with | .uint32 v => some v.toNat | .uint64 v => some v.toNat | _ => none
        return {
          name := name.getD "unknown", vocabSize := vocabSize.getD 0, hiddenSize := hiddenSize.getD 0,
          numLayers := numLayers.getD 0, numHeads := numHeads.getD 0, headDim := headDim.getD 0
        }

      match archResult with
      | Except.error e => return Except.error (AppError.ModelError s!"Metadata extraction failed: {e}")
      | Except.ok arch =>
          let handle ← IO.FS.Handle.mk modelPath .read
          let infoStartOff := 24 + totalMetaSize
          Lyceum.Core.IO.seek handle infoStartOff.toUInt64
          let infoBuf ← handle.read (1024 * 1024 * 5)
          let (tensorInfos, _) := Lib.Gguf.parseGgufTensorInfos infoBuf 0 header.tensorCount.toNat
          
          let mut tensors : Std.HashMap String RawQuantizedTensor := {}
          for tInfo in tensorInfos do
            match ggmlTypeToQuantizationType tInfo.type with
            | Except.ok qType =>
                let prod := tInfo.dimensions.foldl (· * ·) 1
                let byteSize := calcTensorSize prod qType
                Lyceum.Core.IO.seek handle tInfo.offset
                let tensorData ← handle.read byteSize.toUSize
                tensors := tensors.insert tInfo.name { name := tInfo.name, qType := qType, dims := tInfo.dimensions, data := tensorData }
            | Except.error _ => continue

          return Except.ok ({ arch := arch, tensors := tensors } : RawGenericModel)


end Lyceum.Inference.Generic.Loader
