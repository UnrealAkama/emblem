module R = Rresult.R

module type IdBase = sig
  val tag_len : int
  val tag : Z.t
end

module Id (B : IdBase) : sig
  type t = private Z.t
  val gen : unit -> t
  val get_time : t -> float
  val get_random : t -> Z.t
  val get_tag : t -> Z.t
  val to_raw_string : t -> string
  val to_hex_string : t -> string
  val to_uuid_string : t -> string
  val to_z : t -> Z.t
  val of_raw_string : string -> (t, [> R.msg ]) result
  val of_z : Z.t -> (t, [> R.msg ]) result
  val eq : t -> t -> bool
  val compare : t -> t -> int
  val pp : Format.formatter -> t -> unit
end = struct
  type t = Z.t
  let random_len = (20 - B.tag_len) * 4
  let tag_len = B.tag_len * 4
  let max_random = Z.(pow (add one one) random_len - one)
  let max_total = Z.(pow (add one one) 128 - one)
  let max_tag = Z.(pow (add one one) tag_len - one)
  let to_raw_string = Z.to_bits
  let to_hex_string = Z.format "%032x"
  let to_z t = t
  let to_uuid_string t =
    let front = Z.((t asr 96)) |> Z.format "%08x" in
    let qlen = Z.(pow (add one one) 15 - one) in
    let qone = Z.((t asr 80) land qlen) |> Z.format "%04x" in
    let qtwo = Z.((t asr 64) land qlen) |> Z.format "%04x" in
    let qthree = Z.((t asr 48) land qlen) |> Z.format "%04x" in
    let blen = Z.(pow (add one one) 47 - one) in
    let back = Z.(t land blen) |> Z.format "%012x" in
    Fmt.str "%s-%s-%s-%s-%s" front qone qtwo qthree back
  let eq = Z.equal
  let compare = Z.compare
  let get_time t =
    let c = random_len + tag_len in
    Z.(t asr c) |> Z.to_float
  let get_random t =
    Z.((t asr tag_len) land max_random)
  let get_tag t =
    Z.(t land max_tag)
  let verify t =
    let tag = get_tag t in
    if (Z.equal tag B.tag) then
      if (Z.compare t max_total < 0) then
        R.ok t
      else
        R.error_msg "Value is too large to fit inside a emblem id."
    else
      R.error_msgf "Tag (%a) doesn't match emblem tag (%a)." Z.pp_print tag Z.pp_print B.tag
  let of_raw_string s =
    let t = Z.of_bits s in
    verify t
  let of_z t =
    verify t
  let pp m t = Fmt.string m (to_uuid_string t)
  let gen () =
    let back = String.init 16 (fun _ -> Char.chr (Random.int 256)) |> Z.of_bits in
    let safe_back = Z.(back land max_random) in
    let backend = Z.((safe_back lsl tag_len) + B.tag) in
    let time = Unix.gettimeofday() *. 1000. |> Z.of_float in
    let front = Z.(time lsl 80) in
    Z.add front backend
end
