///|
/// Type 2 CharString safety pre-flight.
///
/// `mizchi/font`'s CFF interpreter (`cff_glyph_outline`) panics with an
/// out-of-bounds `Array::at` whenever a glyph's CharString invokes a path
/// operator with fewer operands on the stack than the operator unconditionally
/// reads (e.g. `vmoveto` reading `stack[0]` from an empty stack). On wasm that
/// surfaces as `RuntimeError: unreachable` and aborts the whole `pageToSvg`
/// call; on native it's a `SIGABRT`. Real-world CIDFontType0C subsets
/// emitted by Adobe InDesign occasionally include glyphs whose CharString
/// starts with `4` (vmoveto) before pushing any operand, which trips this
/// case.
///
/// We can't catch the panic — `Array::at` traps via `guard`, not `raise` — and
/// `mizchi/font` lives under `.mooncakes/` (gitignored, so a local patch would
/// not survive `moon update`). So we run a stack-arity-only simulation of the
/// CharString (and its referenced subroutines, when statically resolvable) and
/// refuse to materialise the outline when an operator would panic. The
/// renderer then falls back to its `<text>` path for that glyph rather than
/// aborting the page.
///
/// We deliberately keep this simulation self-contained in the SVG package —
/// the only inputs we touch are `TTFont.data` and `TTFont.cff`, both exposed
/// as `pub(all)` in the upstream API.
pub fn cff_charstring_is_safe(font : @font.TTFont, gid : Int) -> Bool {
  match font.cff {
    Some(cff) => cff_charstring_is_safe_impl(font.data, cff, gid)
    None => true
  }
}

///|
priv struct CsSafetyState {
  data : Bytes
  cff : @font.CFFData
  // Operand-stack depth counter; tracked only as a length, never as values.
  mut stack_size : Int
  // The most recent constant pushed onto the operand stack, when known. We
  // only set this on the *literal* push immediately preceding the operator
  // that consumes it; any non-push operator clears it back to None. This lets
  // `callsubr` / `callgsubr` resolve their subroutine index.
  mut last_push : Int?
  mut safe : Bool
  mut ended : Bool
}

///|
fn cff_charstring_is_safe_impl(
  data : Bytes,
  cff : @font.CFFData,
  glyph_id : Int,
) -> Bool {
  if glyph_id < 0 || glyph_id >= cff_index_count(cff.charstrings) {
    return true
  }
  let (offset, length) = match cff_index_entry(cff.charstrings, glyph_id) {
    Some(value) => value
    None => return true
  }
  let state = CsSafetyState::{
    data,
    cff,
    stack_size: 0,
    last_push: None,
    safe: true,
    ended: false,
  }
  walk_cs(state, offset, length, 0)
  state.safe
}

///|
fn walk_cs(
  state : CsSafetyState,
  offset : Int,
  length : Int,
  depth : Int,
) -> Unit {
  if depth > 10 {
    state.safe = false
    return
  }
  let data_len = state.data.length()
  let end = offset + length
  if offset < 0 || length < 0 || end > data_len {
    state.safe = false
    return
  }
  let mut pos = offset
  while pos < end && state.safe && !state.ended {
    let b0 = byte_at(state, pos)
    if !state.safe {
      return
    }
    pos += 1
    if b0 == 28 {
      if pos + 2 > end {
        state.safe = false
        return
      }
      let hi = byte_at(state, pos)
      let lo = byte_at(state, pos + 1)
      pos += 2
      state.stack_size += 1
      let raw = (hi << 8) | lo
      let signed = if raw >= 32768 { raw - 65536 } else { raw }
      state.last_push = Some(signed)
    } else if b0 == 255 {
      if pos + 4 > end {
        state.safe = false
        return
      }
      pos += 4
      state.stack_size += 1
      // 16.16 fixed — its truncation back to int isn't useful for subr indices,
      // and conformant fonts don't use fixed for subr numbers anyway.
      state.last_push = None
    } else if b0 >= 32 && b0 <= 246 {
      state.stack_size += 1
      state.last_push = Some(b0 - 139)
    } else if b0 >= 247 && b0 <= 250 {
      if pos + 1 > end {
        state.safe = false
        return
      }
      let b1 = byte_at(state, pos)
      pos += 1
      state.stack_size += 1
      state.last_push = Some((b0 - 247) * 256 + b1 + 108)
    } else if b0 >= 251 && b0 <= 254 {
      if pos + 1 > end {
        state.safe = false
        return
      }
      let b1 = byte_at(state, pos)
      pos += 1
      state.stack_size += 1
      state.last_push = Some(-(b0 - 251) * 256 - b1 - 108)
    } else {
      let advanced_to = simulate_operator(state, b0, pos, end, depth)
      if !state.safe {
        return
      }
      pos = advanced_to
      if state.ended {
        return
      }
    }
  }
}

///|
/// Simulates the operand-stack and reader-position effects of the CharString
/// operator with leading byte `b0`. Returns the new reader position. Marks
/// `state.safe = false` when the operator would underflow the stack or when
/// recursive subroutines fall outside `state.data`.
fn simulate_operator(
  state : CsSafetyState,
  b0 : Int,
  pos_in : Int,
  end : Int,
  depth : Int,
) -> Int {
  let mut pos = pos_in
  match b0 {
    1 | 3 | 18 | 23 => {
      // hstem / vstem / hstemhm / vstemhm — clear stack, no operand indexing
      state.stack_size = 0
      state.last_push = None
    }
    4 => {
      // vmoveto — reads stack[0]
      if state.stack_size < 1 {
        state.safe = false
        return pos
      }
      state.stack_size = 0
      state.last_push = None
    }
    5 | 6 | 7 => {
      // rlineto / hlineto / vlineto — guarded loops on stack length
      state.stack_size = 0
      state.last_push = None
    }
    8 => {
      // rrcurveto — guarded loop on i+5<n
      state.stack_size = 0
      state.last_push = None
    }
    10 => {
      // callsubr — pop 1 (subr index), then recurse
      if state.stack_size < 1 {
        state.safe = false
        return pos
      }
      state.stack_size -= 1
      let resolved = state.last_push
      state.last_push = None
      simulate_subr(state, state.cff.local_subrs, resolved, depth)
      if !state.safe {
        return pos
      }
    }
    11 => {
      // return — terminates current invocation level
      return pos
    }
    12 => {
      // escape — second byte selects sub-operator
      if pos >= end {
        state.safe = false
        return pos
      }
      let b1 = byte_at(state, pos)
      pos += 1
      simulate_escape(state, b1)
      if !state.safe {
        return pos
      }
    }
    14 => {
      // endchar
      state.stack_size = 0
      state.last_push = None
      state.ended = true
      return pos
    }
    15 => {
      // CFF2 vsindex — pop 1 if non-empty
      if state.stack_size > 0 {
        state.stack_size -= 1
      }
      state.last_push = None
    }
    16 => {
      // CFF2 blend — upstream guards on stack size>0 and clears blend deltas
      if state.stack_size > 0 {
        state.stack_size -= 1
      }
      state.last_push = None
    }
    19 | 20 => {
      // hintmask / cntrmask — clear stack and skip mask bytes
      let stems = state.stack_size / 2
      let mask_bytes = (stems + 7) / 8
      state.stack_size = 0
      state.last_push = None
      if pos + mask_bytes > end {
        state.safe = false
        return pos
      }
      pos += mask_bytes
    }
    21 => {
      // rmoveto — reads stack[0], stack[1]
      if state.stack_size < 2 {
        state.safe = false
        return pos
      }
      state.stack_size = 0
      state.last_push = None
    }
    22 => {
      // hmoveto — reads stack[0]
      if state.stack_size < 1 {
        state.safe = false
        return pos
      }
      state.stack_size = 0
      state.last_push = None
    }
    24 => {
      // rcurveline — reads stack[n-2], stack[n-1]
      if state.stack_size < 2 {
        state.safe = false
        return pos
      }
      state.stack_size = 0
      state.last_push = None
    }
    25 => {
      // rlinecurve — reads stack[n-6 .. n-1]
      if state.stack_size < 6 {
        state.safe = false
        return pos
      }
      state.stack_size = 0
      state.last_push = None
    }
    26 | 27 | 30 | 31 => {
      // vvcurveto / hhcurveto / vhcurveto / hvcurveto — guarded loops
      state.stack_size = 0
      state.last_push = None
    }
    29 => {
      // callgsubr — pop 1, recurse into global subrs
      if state.stack_size < 1 {
        state.safe = false
        return pos
      }
      state.stack_size -= 1
      let resolved = state.last_push
      state.last_push = None
      simulate_subr(state, state.cff.global_subrs, resolved, depth)
      if !state.safe {
        return pos
      }
    }
    _ => {
      // Reserved / unknown operator. Upstream's `_ => stack.clear()` matches
      // this branch, so we mirror it.
      state.stack_size = 0
      state.last_push = None
    }
  }
  pos
}

///|
/// Simulates the escape (12) sub-operator opcodes that act on the operand
/// stack via `unsafe_pop`. The geometry-only operators (34, 35, 36, 37 — the
/// flex variants) clear the stack regardless and don't underflow upstream
/// because of `if length >= N` guards, so we just clear the stack.
fn simulate_escape(state : CsSafetyState, b1 : Int) -> Unit {
  state.last_push = None
  match b1 {
    3 | 4 | 10 | 11 | 12 | 15 | 24 => {
      // and / or / add / sub / div / eq / mul — pop 2, push 1
      if state.stack_size < 2 {
        state.safe = false
        return
      }
      state.stack_size -= 1
    }
    5 | 9 | 14 | 26 => {
      // not / abs / neg / sqrt — pop 1, push 1
      if state.stack_size < 1 {
        state.safe = false
        return
      }
    }
    18 => {
      // drop — pop 1
      if state.stack_size < 1 {
        state.safe = false
        return
      }
      state.stack_size -= 1
    }
    20 => {
      // put — pop 2 (val, idx)
      if state.stack_size < 2 {
        state.safe = false
        return
      }
      state.stack_size -= 2
    }
    21 => {
      // get — pop 1 (idx), push 1
      if state.stack_size < 1 {
        state.safe = false
        return
      }
    }
    22 => {
      // ifelse — pop 4, push 1
      if state.stack_size < 4 {
        state.safe = false
        return
      }
      state.stack_size -= 3
    }
    23 => {
      // random — push 1
      state.stack_size += 1
    }
    27 => {
      // dup — pop 1, push 2
      if state.stack_size < 1 {
        state.safe = false
        return
      }
      state.stack_size += 1
    }
    28 =>
      // exch — pop 2, push 2 (net 0)
      if state.stack_size < 2 {
        state.safe = false
        return
      }
    29 => {
      // index — pop 1, push 1
      if state.stack_size < 1 {
        state.safe = false
        return
      }
    }
    30 => {
      // roll — pop 2 (n, j), rotate top n
      if state.stack_size < 2 {
        state.safe = false
        return
      }
      state.stack_size -= 2
    }
    34 | 35 | 36 | 37 => {
      // hflex / flex / hflex1 / flex1 — guarded `if length >= N` upstream
      state.stack_size = 0
    }
    _ =>
      // Unknown / reserved sub-operator — be conservative and clear
      state.stack_size = 0
  }
}

///|
/// Walks a referenced subroutine when its index is statically resolvable
/// (i.e. came from a literal push immediately preceding the call). When the
/// index can't be resolved — for instance because it was produced by a
/// computation — we conservatively assume the subroutine clears the stack and
/// returns safely, matching the most common subroutine shape and avoiding
/// false-positive rejections of well-formed glyphs that exercise dynamic
/// subroutine selection.
fn simulate_subr(
  state : CsSafetyState,
  subrs : @font.CFFIndex,
  index_value : Int?,
  depth : Int,
) -> Unit {
  let count = cff_index_count(subrs)
  if count <= 0 {
    state.stack_size = 0
    return
  }
  match index_value {
    Some(raw) => {
      let bias = if state.cff.is_cff2 { 0 } else { calc_subr_bias(count) }
      let idx = raw + bias
      match cff_index_entry(subrs, idx) {
        Some((off, len)) => walk_cs(state, off, len, depth + 1)
        None => state.stack_size = 0
      }
    }
    None => state.stack_size = 0
  }
}

///|
/// Replicates upstream `CFFIndex::count`. Upstream keeps the helper private,
/// but the struct itself is `pub(all)`, so we mirror the algorithm: an empty
/// index has at most one offset, otherwise the count is `len(offsets) - 1`.
fn cff_index_count(index : @font.CFFIndex) -> Int {
  if index.offsets.length() <= 1 {
    0
  } else {
    index.offsets.length() - 1
  }
}

///|
/// Replicates upstream `CFFIndex::entry` with explicit bounds checks. Upstream
/// uses raw `offsets[i]` indexing which would panic for out-of-range entries;
/// since the whole point of this module is preventing panics, we hand back
/// `None` instead.
fn cff_index_entry(index : @font.CFFIndex, i : Int) -> (Int, Int)? {
  if i < 0 || i + 1 >= index.offsets.length() {
    return None
  }
  let start = index.data_offset + index.offsets[i]
  let len = index.offsets[i + 1] - index.offsets[i]
  Some((start, len))
}

///|
fn calc_subr_bias(count : Int) -> Int {
  if count < 1240 {
    107
  } else if count < 33900 {
    1131
  } else {
    32768
  }
}

///|
fn byte_at(state : CsSafetyState, pos : Int) -> Int {
  if pos < 0 || pos >= state.data.length() {
    state.safe = false
    return 0
  }
  state.data[pos].to_int()
}
