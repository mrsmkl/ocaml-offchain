
(* interpreter with merkle proofs *)

open Ast
open Source
(* perhaps we need to link the modules first *)

(* have a separate call stack? *)

(* perhaps the memory will include the stack? nope *)

type inst =
 | UNREACHABLE
 | NOP
 | JUMP of int
 | JUMPI of int
 | CALL of int
 | LABEL of int
 | PUSHBRK of int
 | L_JUMP of int
 | L_JUMPI of int
 | L_CALL of int
 | L_LABEL of int
 | L_PUSHBRK of int
 | POPBRK
 | BREAK
 | RETURN
 | LOAD
 | STORE
 | DROP
 | SELECT
 | DUP of int
 | SWAP of int
 | CURMEM
 | GROW
 | POPI of int
 | BREAKI
 | PUSH of literal                  (* constant *)
 | TEST of testop                    (* numeric test *)
 | CMP of relop                  (* numeric comparison *)
 | UNA of unop                     (* unary numeric operator *)
 | BIN of binop                   (* binary numeric operator *)
 | CONV of cvtop

type context = {
  ptr : int;
  label : int;
}

(* Push the break points to stack? they can have own stack, also returns will have the same *)

let rec compile ctx expr = compile' ctx expr.it
and compile' ctx = function
 | Unreachable -> ctx, [UNREACHABLE]
 | Nop -> ctx, [NOP]
 | Block (ty, lst) ->
   let end_label = ctx.label in
   let ctx = {ctx with label=ctx.label+1; ptr=ctx.ptr+1} in
   let ctx, body = compile_block ctx lst in
   {ctx with ptr=ctx.ptr-1}, [PUSHBRK end_label] @ body @ [LABEL end_label; POPBRK]
 | Const lit -> {ctx with ptr = ctx.ptr+1}, [PUSH lit]
 | Test t -> {ctx with ptr = ctx.ptr-1}, [TEST t]
 | Compare i -> {ctx with ptr = ctx.ptr-1}, [CMP i]
 | Unary i -> ctx, [UNA i]
 | Binary i -> {ctx with ptr = ctx.ptr-1}, [BIN i]
 | Convert i -> ctx, [CONV i]
 | Loop (_, lst) ->
   let start_label = ctx.label in
   let end_label = ctx.label+1 in
   let ctx = {ctx with label=ctx.label+2} in
   let ctx, body = compile_block ctx lst in
   {ctx with ptr=ctx.ptr-2}, [LABEL start_label; PUSHBRK end_label;  PUSHBRK start_label] @ body @ [JUMP ctx.label; LABEL end_label; POPBRK; POPBRK]
 | If (ty, texp, fexp) ->
   let else_label = ctx.label in
   let end_label = ctx.label+1 in
   let ctx = {ctx with ptr=ctx.ptr-1; label=ctx.label+2} in
   let ctx, tbody = compile' ctx (Block (ty, texp)) in
   let ctx, fbody = compile' ctx (Block (ty, fexp)) in
   ctx, [JUMPI else_label] @ tbody @ [JUMP end_label; LABEL else_label] @ fbody @ [LABEL end_label]
 | Br x -> compile_break ctx (Int32.to_int x.it)
 | BrIf x ->
   let continue_label = ctx.label in
   let ctx = {ctx with label=ctx.label+1; ptr = ctx.ptr-1} in
   let ctx, rest = compile_break ctx (Int32.to_int x.it) in
   ctx, [JUMPI continue_label] @ rest @ [LABEL continue_label]
 | BrTable (tab, def) ->
   (* push the list there, then use a special instruction *)
   let lst = List.map (fun x -> PUSH {at=no_region; it=I32 x.it}) (def::tab) in
   ctx, lst @ [DUP (List.length lst); POPI (List.length lst); BREAKI]
 | Return -> ctx, [RETURN]
 | Drop -> {ctx with ptr=ptr-1}, [DROP]
 | GrowMemory -> {ctx with ptr=ptr-1}, [GROW]
 | CurrentMemory -> {ctx with ptr=ptr+1}, [CURMEM]

and compile_break ctx = function
 | 0 -> ctx, [BREAK]
 | i ->
   let ctx, rest = compile_break ctx (i-1) in
   ctx, [POPBRK] @ rest

and compile_block ctx = function
 | [] -> ctx, []
 | a::tl ->
    let ctx, a = compile ctx a in
    let ctx, rest = compile_block ctx tl in
    ctx, a @ rest


