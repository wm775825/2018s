open Core
open Ast.IR

exception RuntimeError of string
(* exception Unimplemented *)

type outcome =
  | Step of Term.t
  | Val
  | Err of string

(* You will implement the cases below. See the dynamics section
   for a specification on how the small step semantics should work. *)
let rec trystep (t : Term.t) : outcome =
  match t with
  | Term.Var _ -> raise (RuntimeError "Unreachable")

  | (Term.Lam _ | Term.Int _) -> Val

  | Term.TLam (_, t) -> Step t

  | Term.TApp (t, _) -> Step t

  | Term.TPack (_, t, _) -> Step t

  | Term.TUnpack (_, x, t1, t2) -> Step (Term.substitute x t1 t2)

  | Term.App (fn, arg) -> (
      match trystep fn with
      | Step t1' -> Step (Term.App (t1', arg))
      | Val -> (
          match trystep arg with
          | Step t2' -> Step (Term.App (fn, t2'))
          | Val -> (
              match fn with
              | Term.Lam (x, _, t) -> Step (Term.substitute x arg t)
              | _ -> raise (RuntimeError "RuntimeError 0")
            )
          | Err str -> raise (RuntimeError str)
        )
      | Err str -> raise (RuntimeError str)
    )

  | Term.Binop (b, t1, t2) -> (
      match trystep t1 with
      | Step t1' -> Step (Term.Binop (b, t1', t2))
      | Val -> (
          match trystep t2 with
          | Step t2' -> Step (Term.Binop (b, t1, t2'))
          | Val -> (
              match (b, t1, t2) with
              | (Div, _, Term.Int 0) -> Err "divided by zero!"
              | (Add, (Term.Int n1), (Term.Int n2)) -> Step (Term.Int (n1 + n2))
              | (Sub, (Term.Int n1), (Term.Int n2)) -> Step (Term.Int (n1 - n2))
              | (Mul, (Term.Int n1), (Term.Int n2)) -> Step (Term.Int (n1 * n2))
              | (Div, (Term.Int n1), (Term.Int n2)) -> Step (Term.Int (n1 / n2))
              | _ -> raise (RuntimeError "RuntimeError 1")
           )
          | Err str -> raise (RuntimeError str)
        )
      | Err str -> raise (RuntimeError str)
    )

  | Term.Tuple (t1, t2) -> (
      match trystep t1 with
      | Step t1' -> Step (Term.Tuple(t1', t2))
      | Val -> (
          match trystep t2 with
          | Step t2' -> Step (Term.Tuple(t1, t2'))
          | Val -> Val
          | Err str -> raise (RuntimeError str)
        )
      | Err str -> raise (RuntimeError str)
    )

  | Term.Project (t, dir) -> (
      match trystep t with
      | Step t' -> Step(Term.Project (t', dir))
      | Val -> (
          match t with
          | Term.Tuple (t1, t2) -> (
              match dir with
              | Left -> Step t1
              | Right -> Step t2
            )
          | _ -> raise (RuntimeError "RuntimeError 2")
        )
      | Err str -> raise (RuntimeError str)
    )
  | Term.Inject (t, dir, tau) -> (
      match trystep t with
      | Step t' -> Step (Term.Inject (t', dir, tau))
      | Val -> Val
      | Err str -> raise (RuntimeError str)
    )

  | Term.Case (t, (x1, t1), (x2, t2)) -> (
      match trystep t with
      | Step t' -> Step (Term.Case (t', (x1, t1), (x2, t2)))
      | Val -> (
          match t with
          | Term.Inject (t', dir, _) -> (
              match dir with
              | Left -> Step (Term.substitute x1 t' t1)
              | Right -> Step (Term.substitute x2 t' t2)
            )
          | _ -> raise (RuntimeError "RuntimeError 3")
        )
      | Err str -> raise (RuntimeError str)
    )

let rec eval e =
  match trystep e with
  | Step e' -> eval e'
  | Val -> Ok e
  | Err s -> Error s

let inline_tests () =
  (* Typecheck Inject *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Int))
  in
  assert (trystep inj = Val);

  (* Typechecks Tuple *)
  let tuple =
    Term.Tuple(((Int 3), (Int 4)))
  in
  assert (trystep tuple = Val);

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
  assert (trystep switch = Step(Term.Int 8));

  (* Inline Tests from Assignment 3 *)
  let t1 = Term.Binop(Ast.Add, Term.Int 2, Term.Int 3) in
  assert (trystep t1 = Step(Term.Int 5));

  let t2 = Term.App(Term.Lam("x", Type.Int, Term.Var "x"), Term.Int 3) in
  assert (trystep t2 = Step(Term.Int 3));

  let t3 = Term.Binop(Ast.Div, Term.Int 3, Term.Int 0) in
  assert (match trystep t3 with Err _ -> true | _ -> false)

let () = inline_tests ()
