import Lean

namespace Lyceum

/-- 物理メモリ空間を模したコンテキストバッファ -/
structure MemoryMappedContext where
  buffer : ByteArray
  offset : Nat -- 読み込み開始位置
  size   : Nat -- 最大メモリ容量
deriving Inhabited

/-- コンテキストバッファの生成 -/
def MemoryMappedContext.create (size : Nat) : MemoryMappedContext :=
  { buffer := ByteArray.mk (Array.mk (List.replicate size 0)), offset := 0, size := size }

/-- 指定した範囲のデータをフェッチする -/
def MemoryMappedContext.fetchSegment (ctx : MemoryMappedContext) (start : Nat) (len : Nat) : Except String ByteArray :=
  if start + len > ctx.size then
    Except.error "Segment out of bounds"
  else
    Except.ok (ctx.buffer.extract start (start + len))

/-- バッファにデータを書き込む -/
def MemoryMappedContext.write (ctx : MemoryMappedContext) (start : Nat) (data : ByteArray) : MemoryMappedContext :=
  let newBuffer := ctx.buffer.extract 0 start
  let newBuffer := newBuffer ++ data
  let newBuffer := newBuffer ++ ctx.buffer.extract (start + data.size) ctx.size
  { ctx with buffer := newBuffer }

end Lyceum
