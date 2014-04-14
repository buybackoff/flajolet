open Core.Std
open Printf
module B = Core_extended.Std.Bitarray

type t = {
    nmax:       int;
    error:      float;
    error2:     float;
    m:          float;
    v:          B.t;
    mutable l:  float;
    c:          int;
    d:          int;
    r:          float;
    tt:         float;
    seed:       int
}

let log2 x = (log x) /. (log 2.0)

let create nmax error seed =
    let error2 = error ** 2.0 in

    (*let mx = (1. +. 2.0 *. (Float.of_int nmax) *. error2) in*)
    let m_num = log(1. +. 2.0 *. (Float.of_int nmax) *. error2) in

    let m_denom = log(1.0 +. 2.0 *. error2 *. (1.0 -. error2)**(-1.0)) in
    let m = m_num /. m_denom in
    let c = Int.of_float (log2 m) in
    let r = (1.0 -. 2.0 *. error2 *. (1.0 +. error2) ** (-1.0)) in
    (*printf "M: %f Md: %f Mn: %f R: %f C: %d\n" m m_denom m_num r c;*)
    {
        nmax;
        error;
        error2 = error ** 2.0;
        m;
        v = B.create (Float.to_int m);
        l = 0.0;
        c;
        d = (64 - c);
        r;
        tt = 0.0;
        seed
    }

let get_rightmost_bits x nbits = 
    let y = Int64.((shift_left 1L nbits) - 1L) in
    Int64.(bit_and x y)

let get_pk t k =
    let pk = t.m *. (t.m +. 1.0 -. k) ** -1.0 *. (1.0 +. t.error2) *. t.r ** k in
    pk

let add t item =
    let (h, h2) = Hashing.murmurHash3_x64_128 item t.seed in
    let j = Int64.shift_right_logical h t.d |> Int64.to_int in
    match j with
    | Some j' ->
        if not (B.get t.v j') then begin
            let u = get_rightmost_bits h t.d in
            let uf = Int64.to_float u in
            let plnext = get_pk t (t.l +. 1.0) in
            let mdf = Float.of_int (-t.d) in
            let dude = uf *. 2.0 ** mdf in
            (*printf "%s H: %Ld U: %Ld PLNEXT: %f Dude: %f L %7.f\n" item h u plnext dude t.l;*)
            if dude < plnext then begin
                B.set t.v j' true;
                t.l <- t.l +. 1.0
            end
            else ()
        end
        else ()
    | None -> ()

let get_q t l pl =
    t.m ** (-1.0) *. (t.m -. l +. 1.0) *. pl

let total t l =
    let tl = ref 0.0 in
    let i = ref 1.0 in
    while !i <= l do
        let pk = get_pk t !i in
        let q = (get_q t !i pk) ** (-1.0) in
        tl := !tl +. q;
        i := !i +. 1.0
    done;
    !tl

let estimate t =
    let t1 = total t t.l in
    let t2 = total t (t.l +. 1.0) in
    if (t.m > t.l) && (t2 -. t1 > 1.5) then begin
        2.0 *. t1 *. t2 /. (t1 +. t2)
    end
    else t1

let merge t1 t2 =
    if t1.m <> t2.m then None
    else
        let mi = Float.to_int t1.m in
        let merged = B.create mi in
        let popcount = ref 0 in
        for i = 0 to (mi - 1) do
            if (B.get t1.v i) || (B.get t2.v i) then begin
                B.set merged i true;
                incr popcount
            end
            else ()
        done;
        Some ({t1 with v = merged; l = (Float.of_int !popcount)})

