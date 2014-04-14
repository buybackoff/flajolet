open Core.Std

type t

val create : int -> t
val offer : t -> float -> t
val quantile : t -> float -> float option
val median : t -> float option
val cdf : t -> float -> float
val mean : t -> float
val describe : t -> float * float * float

