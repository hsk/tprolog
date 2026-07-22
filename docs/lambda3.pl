:- op(1100, xfx, :::).

list(A)   ::: variant([nil:unit, cons:(A * list(A)) | _]).
option(A) ::: variant([none:unit, some:A | _]).
tree(A)   ::: variant([leaf:A, node:(tree(A)*A*tree(A)) | _]).

nil   ::: [] -> list(_).
cons  ::: [A, list(A)] -> list(A).
none  ::: [] -> option(_).
some  ::: [A] -> option(A).
leaf  ::: [A] -> tree(A).
node  ::: [tree(A), A, tree(A)] -> tree(A).

in_history(Hist, T1, T2) :-
    member(A-B, Hist),
    ((T1 == A, T2 == B) ; (T1 == B, T2 == A)), !.

unify(T1, T2) :- unify([], T1, T2).
unify(Hist, T1, T2) :- in_history(Hist, T1, T2),!.
unify(Hist, T1, T2) :- unify_core([T1-T2 | Hist], T1, T2).

unify_core(_, T1, T2) :- T1 == T2, !.
unify_core(_, T1, T2) :- var(T1), !, T1 = T2.
unify_core(_, T2, T1) :- var(T1), !, T1 = T2.
unify_core(Hist, T1, T2) :- (T1 ::: R1), !, unify(Hist, R1, T2).
unify_core(Hist, T1, T2) :- (T2 ::: R2), !, unify(Hist, T1, R2).
unify_core(Hist, arrow(A1, B1), arrow(A2, B2)) :- !, unify(Hist, A1, A2), unify(Hist, B1, B2).
unify_core(Hist, variant(Row1), variant(Row2)) :- !, unify_rows(Hist, Row1, Row2).
unify_core(Hist, T1, T2) :- compound(T1), compound(T2), !, 
    T1 =.. [F1|As1], T2 =.. [F2|As2], F1 == F2,
    maplist(unify(Hist), As1, As2).

unify_rows(_, R1, R2) :- R1 == R2, !.
unify_rows(_, R1, R2) :- var(R1), !, R1 = R2.
unify_rows(_, R1, R2) :- var(R2), !, R2 = R1.
unify_rows(_, [], []) :- !.
unify_rows(Hist, [L:T | R1], R2) :- select_tag(Hist, L, T, R2, R2_Tail), unify_rows(Hist, R1, R2_Tail).

select_tag(_, L, T, R, R_Tail) :- var(R), !, R = [L:T | R_Tail].
select_tag(Hist, L, T, [L:T2 | R], R) :- !, unify(Hist, T, T2).
select_tag(Hist, L, T, [L2:T2 | R], [L2:T2 | R_Tail]) :- select_tag(Hist, L, T, R, R_Tail).

lookup_env(M, T, [M1:T1|_]) :- M == M1, !, unify(T, T1).
lookup_env(M, T, [E|_])     :- var(E), !, E = (M:T).
lookup_env(M, T, [_|R])     :- lookup_env(M, T, R).

args_to_tuple_type([], unit) :- !.
args_to_tuple_type([T|Ts], Type) :- build_tuple_type(Ts, T, Type).

build_tuple_type([], Current, Current).
build_tuple_type([T|Ts], Current, Expected) :- 
    build_tuple_type(Ts, Current * T, Expected).

make_env([], [], []).
make_env([X|Xs], [T|Ts], [X:T | Rest]) :- make_env(Xs, Ts, Rest).

tp_branch(Γ, Row, RetType, Pattern-> Body) :-
    (atom(Pattern) -> F = Pattern, Args = [] ; Pattern =.. [F|Args]),
    length(Args, N), length(ArgTypes, N),
    args_to_tuple_type(ArgTypes, PatternType),
    select_tag([], F, PatternType, Row, _), % ここは新規探索なので空Historyで開始
    make_env(Args, ArgTypes, EnvPart),
    append(EnvPart, Γ, NewΓ),
    tp(NewΓ, Body, RetType).

tp(Γ, M, T) :- atom(M), \+ (M ::: _), !, lookup_env(M, T, Γ).
tp(_, N, int) :- integer(N), !.
tp(_, unit, unit) :- !.
tp(Γ, E1+ E2, int) :- !, tp(Γ, E1, int), tp(Γ, E2, int).
tp(Γ, match(L, Branches), Ret) :- !,
    tp(Γ, L, variant(Row)),
    maplist(tp_branch(Γ, Row, Ret), Branches).
tp(_, [], T) :- !, unify(T, list(_)).
tp(Γ, [H|Tail], T) :- !, unify(T, list(A)), tp(Γ, H, A), tp(Γ, Tail, list(A)).
tp(Γ, λ(X, Body), T) :- !, unify(T, arrow(A, B)), tp([X:A | Γ], Body, B).
tp(Γ, app(F, Arg), T) :- !, tp(Γ, F, Fun), unify(Fun, arrow(A, T)), tp(Γ, Arg, A).
tp(Γ, letrec(X=E1, E2), T) :- !, tp([X:Tx | Γ], E1, Tx), tp([X:Tx | Γ], E2, T).
tp(_, C, T) :- atom(C), (C ::: [] -> T), !.
tp(Γ, M, T) :- compound(M), !, M =.. [F|Args], (F ::: Sig -> Ret), unify(Ret, T),
    maplist(tp(Γ), Args, Sig).

:- begin_tests(rec_row_variant).

test(lambda) :-
    tp([], λ(x, x), T), writeln(T), T=arrow(T1, T2), T1==T2, var(T1).
test(letrec_id) :-
    tp([], letrec(id=λ(x, x), app(id, 42)), T), writeln(T), T=int.
test(list_rec) :-
    tp([], cons(1, cons(2, nil)), T), writeln(T), !, T=list(int).
test(tree_rec) :-
    tp([], node(leaf(10), 20, leaf(30)), T), writeln(T), !, T=tree(int).
test(list_sum) :-
    tp([], 
       letrec(sum=λ(xs, match(xs, [
            nil-> 0,
            cons(h, t)-> h + app(sum, t)
       ])), 
       app(sum, [1, 2, 3, 4])), 
       T), writeln(T), T=int.
test(tree_sum) :-
    tp([], 
       letrec(tsum=λ(tr, match(tr, [
         leaf(v)-> v,
         node(l, v, r)-> v + app(tsum, l)+ app(tsum, r)
       ])), 
       app(tsum, node(leaf(10), 20, leaf(30)))), 
       T), writeln(T),!, T=int.

:- end_tests(rec_row_variant).

:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
