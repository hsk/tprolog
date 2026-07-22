:- op(1100, xfx, :::).
tp(Γ, M, T) :- var(M), !, lookup_env(M, T, Γ).
tp(_, N, int) :- integer(N), !.
tp(_, unit, unit) :- !.
tp(_, [], T) :- unify_types(T, list(_)), !.
tp(Γ, [H|Tail], T) :- unify_types(T, list(A)),tp(Γ, H, A),tp(Γ, Tail, list(A)).
tp(_, C, T) :- atom(C), (C ::: [] -> T), !.
tp(Γ, M, T) :- compound(M), !,
    M =.. [F|Args],
    (F ::: Sig -> Ret),
    unify_types(Ret, T),
    maplist(tp(Γ), Args, Sig).

lookup_env(M, T, [M1:T1|_]) :- M == M1, !, unify_types(T, T1).
lookup_env(M, T, [E|_])     :- var(E), !, E = (M:T).
lookup_env(M, T, [_|R])     :- lookup_env(M, T, R).

unify_types(T, T) :- !.
unify_types(T1, T2) :- (T1 ::: R), !, unify_types(R, T2).
unify_types(T1, T2) :- (T2 ::: R), !, unify_types(T1, R).
unify_types(V1, V2) :- is_variant(V1, Row1), is_variant(V2, Row2), unify_rows(Row1, Row2).
unify_types(T1, T2) :- compound(T1), compound(T2), !, T1 =.. [F|As1], T2 =.. [F|As2],
    maplist(unify_types, As1, As2).

is_variant(variant(R), R) :- !.

unify_rows(R1, R2) :-
    normalize_row(R1, Tags1, Rest1),
    normalize_row(R2, Tags2, Rest2),
    unify_tags(Tags1, Tags2),
    unify_row_rest(Rest1, Rest2).

normalize_row(R, Tags, Rest) :-
    var(R)          -> Tags = [], Rest = R
    ; R = closed    -> Tags = [], Rest = closed
    ; R = (L:T | R0) -> Tags = [L-T|Ts], normalize_row(R0, Ts, Rest)
    ; Tags = [], Rest = R.

unify_tags([], _).
unify_tags([L:T|Ts], Row) :-
    (member(L:T2, Row) -> unify_types(T, T2); var_row(Row)),
    unify_tags(Ts, Row).

var_row(R) :- var(R).
var_row((_ | R)) :- var_row(R).

unify_row_rest(R, R) :- !.
unify_row_rest(R1, R2) :- var(R1),!, R1 = R2.
unify_row_rest(R1, R2) :- var(R2),!, R2 = R1.
unify_row_rest(closed, closed).

list(A) ::: variant([nil:unit, cons:(A * list(A)) | _P]).
option(A) ::: variant([none:unit, some:A | _P]).
either(A,B) ::: variant([left:A, right:B | _P]).
tree(A) ::: variant([leaf:A, node:(tree(A) * A * tree(A)) | _P]).
nil ::: [] -> list(_).
cons ::: [A, list(A)] -> list(A).
none ::: [] -> option(_).
some ::: [A] -> option(A).
leaf ::: [A] -> tree(A).
node ::: [tree(A), A, tree(A)] -> tree(A).

:- begin_tests(rec_row_variant).
test(list) :- tp([],cons(1, cons(2, nil)),T),!,writeln(T),T=list(int).
test(option) :- tp([],some(42),T),!,writeln(T),T=option(int).
test(tree) :- tp([],node(leaf(1), 10, leaf(2)),T),!,writeln(T).
test(polymorphic) :- tp([], cons(1, nil), T), writeln(T),!,T=list(int).
:- end_tests(rec_row_variant).

:-set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
