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

unify(T1, T2) :- T1 == T2, !.
unify(T1, T2) :- var(T1), !, T1 = T2.
unify(T2, T1) :- var(T1), !, T1 = T2.
unify(T1, T2) :- (T1 ::: R1),!, unify(R1, T2).
unify(T1, T2) :- (T2 ::: R2),!, unify(T1, R2).
unify(arrow(A1, B1), arrow(A2, B2)) :- !, unify(A1, A2), unify(B1, B2).
unify(variant(Row1), variant(Row2)) :- !, unify_rows(Row1, Row2).
unify(T1,T2):-compound(T1), compound(T2), !, 
        T1 =.. [F1|As1], T2 =.. [F2|As2], F1 == F2,
        maplist(unify, As1, As2).

unify_rows(R1, R2) :- R1 == R2, !.
unify_rows(R1, R2) :- var(R1), !, R1 = R2.
unify_rows(R1, R2) :- var(R2), !, R2 = R1.
unify_rows([], []) :- !.
unify_rows([L:T | R1], R2) :- select_tag(L, T, R2, R2_Tail), unify_rows(R1, R2_Tail).

select_tag(L, T, R, R_Tail) :- var(R), !, R = [L:T | R_Tail].
select_tag(L, T, [L:T2 | R], R) :- !, unify(T, T2).
select_tag(L, T, [L2:T2 | R], [L2:T2 | R_Tail]) :- select_tag(L, T, R, R_Tail).

lookup_env(M, T, [M1:T1|_]) :- M == M1, !, unify(T, T1).
lookup_env(M, T, [E|_])     :- var(E), !, E = (M:T).
lookup_env(M, T, [_|R])     :- lookup_env(M, T, R).

tp(Γ, M, T) :- atom(M), \+ (M ::: _), !, lookup_env(M, T, Γ).
tp(_, N, int) :- integer(N), !.
tp(_, unit, unit) :- !.
tp(Γ, plus(E1, E2), int) :- !, tp(Γ, E1, int), tp(Γ, E2, int).
tp(Γ, match_list(L, E_nil, H, T, E_cons), Ret) :- !,
    tp(Γ, L, list(A)),tp(Γ, E_nil, Ret),
    tp([H:A, T:list(A) | Γ], E_cons, Ret).
tp(_, [], T) :- !, unify(T, list(_)).
tp(Γ, [H|Tail], T) :- !,unify(T, list(A)),tp(Γ, H, A),tp(Γ, Tail, list(A)).
tp(Γ, lam(X, Body), T) :- !,unify(T, arrow(A, B)),tp([X:A | Γ], Body, B).
tp(Γ, app(F, Arg), T) :- !, tp(Γ, F, Fun), unify(Fun, arrow(A, T)), tp(Γ, Arg, A).
tp(Γ, letrec(X, E1, E2), T) :- !, tp([X:Tx | Γ], E1, Tx), tp([X:Tx | Γ], E2, T).
tp(_, C, T) :- atom(C), (C ::: [] -> T), !.
tp(Γ, M, T) :- compound(M), !,M =.. [F|Args],(F ::: Sig -> Ret),unify(Ret, T),
    maplist(tp(Γ), Args, Sig).

:- begin_tests(rec_row_variant).
test(lambda) :-
    tp([], lam(x, x), T),writeln(T),T=arrow(T1, T2),T1==T2,var(T1).
test(letrec_id) :-
    tp([], letrec(id, lam(x, x), app(id, 42)), T),writeln(T),T=int.
test(list_rec) :-
    tp([], cons(1, cons(2, nil)), T),writeln(T),!,T=list(int).
test(tree_rec) :-
    tp([], node(leaf(10), 20, leaf(30)), T),writeln(T),!,T=tree(int).
test(sum) :-
    tp([], 
       letrec(sum, 
              lam(xs, 
                  match_list(xs, 
                             0,                          % nil枝
                             h, t,                       % consの束縛変数
                             plus(h, app(sum, t)))),     % cons枝
              app(sum, [1, 2, 3, 4])), 
       T),writeln(T),T=int.
:- end_tests(rec_row_variant).

:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.