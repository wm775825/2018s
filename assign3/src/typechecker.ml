open Core
open Ast.IR

exception TypeError of string
(* exception Unimplemented *)

(* Checks that a type is legal. *)
let rec typecheck_type (tenv : String.Set.t) (tau : Type.t) : Type.t =
  match tau with
   | Type.Var x ->
     if Set.mem tenv x then tau
     else raise (TypeError (Printf.sprintf "Unbound type variable %s" x))
   | Type.Product (t1, t2) -> Type.Product (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Sum (t1, t2) -> Type.Sum (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Fn (t1, t2) -> Type.Fn (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.ForAll(s, t1) -> Type.ForAll(s, typecheck_type (String.Set.add tenv s) t1)
   | Type.Exists(s, t1) -> Type.Exists(s, typecheck_type (String.Set.add tenv s) t1)
   | Type.Int -> tau

(* You need to implement the statics for the remaining cases below.
 * We have provided you with implementations of the other cases that you may
 * refer to.
 *
 * Note that you'll have to use OCaml sets to do this assignment. The semantics
 * for sets will be similar to maps. Like Maps, Sets are also immutable, so
 * any result from a set function will be different from the source. You may
 * find the functions Set.add and Set.find to be useful, in addition to others.
 *)
let rec typecheck_term (tenv : String.Set.t) (env : Type.t String.Map.t) (t : Term.t) : Type.t =
  match t with
  | Term.Int _ -> Type.Int

  | Term.Var x -> (
      match (String.Map.find env x) with
      | Some _type -> (typecheck_type tenv _type) 
      | None -> raise (TypeError "Does not typecheck 01")
    )

  | Term.Lam (x, tau, t) -> (
      let tau1 = typecheck_type tenv tau in
      let new_map = String.Map.add env ~key:x ~data:tau1 in
      let tau2 = typecheck_term tenv new_map t in
      Type.Fn(tau1, tau2)
    )

  | Term.App (fn, arg) -> (
      let tau1 = typecheck_term tenv env fn in
      let tau2 = typecheck_term tenv env arg in
      match (tau1, tau2) with
      | (Type.Fn (type_a, type_b), type_c) -> (
          if Type.aequiv type_a type_c then type_b
          else raise (TypeError "Does not typecheck 03")
        )
      | _ -> raise (TypeError "Does not typecheck 05")
    )

  | Term.Binop (_, t1, t2) -> (
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
      match (Type.aequiv tau1 tau2) with
      | true -> tau1
      | false -> raise (TypeError "Binop: types of lhs and rhs different!")
    )

  | Term.Tuple (t1, t2) -> (
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
      Type.Product (tau1, tau2)
    )

  | Term.Project (t, dir) -> (
      let tau = typecheck_term tenv env t in
      match tau with
      | Type.Product (l, r) -> (
          match dir with
          | Left -> l
          | Right -> r
       )
      | _ -> raise (TypeError "Project: not a product type!")
    )

  | Term.Inject (arg, dir, sum_tau) -> (
      let tau = typecheck_term tenv env arg in
      let _sum_tau = typecheck_type tenv sum_tau in
      match _sum_tau with
      | Type.Sum(tau1, tau2) -> (
          match dir with
          | Left -> (
              match Type.aequiv tau tau1 with
              | true -> _sum_tau
              | false -> raise (TypeError "Inject: tau is different from tau1!")
            )
          | Right -> (
              match Type.aequiv tau tau2 with
              | true -> _sum_tau
              | false -> raise (TypeError "Inject: tau is different from tau2!")
              )
        )
      | _ -> raise (TypeError "Inject: not a sum type!")
    )

  | Term.Case (t, (x1, t1), (x2, t2)) -> (
      let sum_tau = typecheck_term tenv env t in
      match sum_tau with
      | Type.Sum (tau_x1, tau_x2) -> (
          let new_map = String.Map.add (String.Map.add env ~key:x1 ~data:tau_x1) ~key:x2 ~data:tau_x2 in
          let tau_t1 = typecheck_term tenv new_map t1 in
          let tau_t2 = typecheck_term tenv new_map t2 in
          match Type.aequiv tau_t1 tau_t2 with
          | true -> tau_t1
          | false -> raise (TypeError "Case: different types for two cases!")
        )
      | _ -> raise (TypeError "Case: t is not a sum type!")
    )

  | Term.TLam (x, t) -> (
      let new_set = String.Set.add tenv x in
      let tau = typecheck_term new_set env t in
      Type.ForAll (x, tau)
    )

  | Term.TApp (t, arg_tau) -> (
      let tau = typecheck_term tenv env t in
      let tau2 = typecheck_type tenv arg_tau in
      match tau with
      | Type.ForAll (x, tau1) -> (Type.substitute x tau2 tau1)
      | _ -> raise (TypeError "TApp: t is not a forall type!") 
    )

  | Term.TPack (abstracted_tau, t, existential_type) -> (
      let tau1 = typecheck_type tenv abstracted_tau in
      let tau = typecheck_term tenv env t in
      let x_tau2 = typecheck_type tenv existential_type in
      match x_tau2 with
      | Type.Exists (x, tau2) -> (
          match (Type.aequiv tau (Type.substitute x tau1 tau2)) with
          | true -> x_tau2
          | false -> raise (TypeError "TPack: existential type and tau not match!")
        )
      | _ -> raise (TypeError "TPack: not a existential_type!")
    )

  | Term.TUnpack (xty, xterm, arg, body) -> (
      let tau_t1 = typecheck_term tenv env arg in
      match tau_t1 with
      | Type.Exists (_x, tau1) -> (
          let new_set = String.Set.add tenv xty in
          let new_map = String.Map.add env ~key:xterm ~data:tau1 in
          typecheck_term new_set new_map body
        )
      | _ -> raise (TypeError "TUnpack: type of t1 is not a exists type!")
    )

let typecheck t =
  try Ok (typecheck_term String.Set.empty String.Map.empty t)
  with TypeError s -> Error s

let inline_tests () =
  (* Typechecks Pack and Unpack*)
  let exist =
    Type.Exists("Y", Type.Int)
  in
  let pack =
    Term.TPack(Type.Int, Term.Int 5, exist)
  in
  let unpack =
    Term.TUnpack("Y", "y", pack, Term.Var "y")
  in
  assert(typecheck unpack = Ok(Type.Int));

  (* Typecheck Inject *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Int))
  in
  assert (typecheck inj = Ok(Type.Sum(Type.Int, Type.Int)));

  (* Typechecks Tuple *)
  let tuple =
    Term.Tuple(((Int 3), (Int 4)))
  in
  assert (typecheck tuple = Ok(Type.Product(Type.Int, Type.Int)));

  (* Typechecks Case *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Product(Type.Int, Type.Int)))
  in
  let case1 = ("case1", Term.Int 8)
  in
  let case2 = ("case2", Term.Int 0)
  in
  let switch = Term.Case(inj, case1, case2)
  in
  assert (typecheck switch = Ok(Type.Int));

  (* Inline Tests from Assignment 3 *)
  let t1 = Term.Lam ("x", Type.Int, Term.Var "x") in
  assert (typecheck t1 = Ok(Type.Fn(Type.Int, Type.Int)));

  let t2 = Term.Lam ("x", Type.Int, Term.Var "y") in
  assert (Result.is_error (typecheck t2));

  let t3 = Term.App (t1, Term.Int 3) in
  assert (typecheck t3 = Ok(Type.Int));

  let t4 = Term.App (t3, Term.Int 3) in
  assert (Result.is_error (typecheck t4));

  let t5 = Term.Binop (Ast.Add, Term.Int 0, t1) in
  assert (Result.is_error (typecheck t5))

let () = inline_tests ()
