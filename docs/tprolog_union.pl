:- op(1100, xfx, :::).
:- op(700,  xfx, ⊢).
:- op(600,  xfy, [$, <:, #]).

% --- 2. 項の型検査エンジン ---
tp(Γ, M, T)   :- var(M), !, lookup_env(M, T, Γ).
tp(_, M, T) :- integer(M), !, [] ⊢ int <: T.
tp(_, M, T) :- atom(M), (M ::: [] -> T1), !,[] ⊢ T1 <: T.
tp(_, M, T) :- atom(M), !, [] ⊢ atom <: T.

% エイリアス/部分型に対応したリストの型チェック
tp(_, [], T) :-
    !,
    ([] ⊢ list(_A) <: T ; [] ⊢ T <: list(_A)).
tp(Γ, [H|Tail], T) :-
    !,
    ([] ⊢ list(A) <: T ; [] ⊢ T <: list(A)),
    tp(Γ, H, A),
    tp(Γ, Tail, list(A)).

tp(Γ, M, T) :-
    compound(M), !,
    M =.. [C|Ms],
    (C ::: Ts -> T1),
    [] ⊢ T1 <: T,
    maplist(tp(Γ), Ms, Ts).

% 安全な型環境管理
lookup_env(M, T, [M1:T1|_]) :- M == M1, !, ([] ⊢ T <: T1 ; [] ⊢ T1 <: T).
lookup_env(M, T, [Elem|_])  :- var(Elem), !, Elem = (M:T). 
lookup_env(M, T, [_|Rest])  :- lookup_env(M, T, Rest).

goal(Γ, G) :- 
    G =.. [P|Ms], 
    (P ::: Ts), 
    length(Ms, L), length(Ts, L),
    maplist(tp(Γ), Ms, Ts).

body(_Γ, true) :- !.
body(Γ, (A,B)) :- !, body(Γ, A), body(Γ, B).
body(Γ, G)     :- goal(Γ, G).

check(Γ, (Head:-Body)) :- goal(Γ, Head), body(Γ, Body).
check(Γ, Head)         :- goal(Γ, Head).

% --- 核心：部分型関係（Subtyping Solver） ---
_ ⊢ T <: T :- !.
Γ ⊢ T1 <: T2 :- member(T1 <: T2, Γ), !. 

% 【完全修正】型変数（var）の厳密な部分型・伝播処理
% シングルトン警告を100%全消去し、型変数のポインタの寿命と代入を完璧に制御します。
_ ⊢ T1 <: T2 :- var(T1), var(T2), !, T1 = T2.
Γ ⊢ T1 <: T2 :- var(T1), !, (is_list(T2) -> member(Y, T2), (T1 = Y ; [T1 <: T2|Γ] ⊢ T1 <: Y) ; T1 = T2), !.
Γ ⊢ T1 <: T2 :- var(T2), !, (is_list(T1) -> member(X, T1), (X = T2 ; [T1 <: T2|Γ] ⊢ X <: T2) ; T2 = T1), !.

% 型別名（:::）の遅延展開ルール
Γ ⊢ T1 <: T2 :- (T1 ::: R1), R1 \= (_->_), !, [T1 <: T2|Γ] ⊢ R1 <: T2.
Γ ⊢ T1 <: T2 :- (T2 ::: R2), R2 \= (_->_), !, [T1 <: T2|Γ] ⊢ T1 <: R2.

% レコード/多相ヴァリアント（列多相）の包含関係
Γ ⊢ r(P1) <: r(P2) :- !, forall(member(L:X2, P2), (member(L:X1, P1), [r(P1) <: r(P2)|Γ] ⊢ X1 <: X2)).

% Union型（リスト表現）の分配・包含ルール
Γ ⊢ T1 <: T2 :- is_list(T1), is_list(T2), !, forall(member(X, T1), ([T1 <: T2|Γ] ⊢ [X] <: T2)).
Γ ⊢ [r(P1)] <: [r(P2)] :- !, [[r(P1)] <: [r(P2)]|Γ] ⊢ r(P1) <: r(P2).
Γ ⊢ [X] <: T2 :- is_list(T2), !, member(Y, T2), (X = Y; [X <: T2|Γ] ⊢ X <: Y), !.
Γ ⊢ X <: T2 :- is_list(T2), !, member(Y, T2), (X = Y; [X <: T2|Γ] ⊢ X <: Y), !.

% 関数型（->）の反変・共変ルール
Γ ⊢ (A1 -> B1) <: (A2 -> B2) :- !, 
    [(A1 -> B1) <: (A2 -> B2)|Γ] ⊢ A2 <: A1, 
    [(A1 -> B1) <: (A2 -> B2)|Γ] ⊢ B1 <: B2.

% 複合構造体の再帰的部分型
Γ ⊢ T1 <: T2 :-
    compound(T1), compound(T2), !,
    T1 =.. [F|Args1], T2 =.. [F|Args2],
    length(Args1, L), length(Args2, L),
    maplist(check_sub(Γ), Args1, Args2).

check_sub(Γ, X, Y) :- Γ ⊢ X <: Y.

% --- 1. 型定義のブロック ---
'[|]'  ::: [A, list(A)] -> list(A).
append ::: [list(X), list(X), list(X)].

% expr 型は、[int, add, mul] のいずれの構造も許容する「Union型」として定義
expr  ::: [int, add, mul,var,abs,app].

int   ::: [int] -> expr.
add   ::: [expr, expr] -> expr.
mul   ::: [expr, expr] -> expr.
eval  ::: [expr, int].
integer::: [_].
is    ::: [int, int].
(+)   ::: [int, int] -> int.
(*)   ::: [int, int] -> int.

int   ::: [int] -> v.
env   ::: list(atom:v).

clause::: [env, atom, expr] -> v.
ev    ::: [env, expr, v]. 
ev    ::: [expr, v]. 

var   ::: [atom] -> expr.
abs   ::: [atom, expr] -> expr. 
app   ::: [expr, expr] -> expr.

(:)   ::: [atom, V] -> atom:V.
member ::: [A, list(A)].
iii:::[]->t.
et:::[expr,t].

% --- 3. テスト実行（PLUnit） ---
:- begin_tests(check_union).
% 【完全復元】構文エラーを起こさない正しい形式の append のリスト引数定義
test(test1)  :-check(_,(append([1],[2],[1,2]):-true)), !.
test(test2)  :-check(_,(eval(int(I),I):-integer(I))), !.
test(test3)  :-check(_,(eval(add(E1,E2),I):-eval(E1,I1),eval(E2,I2),I is I1+I2)), !.
test(test4)  :-check(_,(eval(mul(E1,E2),I):-eval(E1,I1),eval(E2,I2),I is I1*I2)), !.
test(test5)  :-check(_,(ev(int(I), int(I)))), !.
test(test6)  :-check(_,(ev(_, int(I), int(I)))), !.
test(test7)  :-check(_,(ev(Γ,add(E1,E2),int(I)):-ev(Γ,E1,int(I1)),ev(Γ,E2,int(I2)),I is I1+I2)), !.
test(test8)  :-check(_,(ev(Γ,mul(E1,E2),int(I)):-ev(Γ,E1,int(I1)),ev(Γ,E2,int(I2)),I is I1*I2)), !.
test(test9)  :-check(_,(ev(Γ,var(X),V):-member(X:V,Γ))), !.
test(test10) :-check(_,(ev(Γ,app(E1,E2),I):-ev(Γ,E1,clause(Γ2,X,E)),ev(Γ,E2,V2),ev([X:V2|Γ2],E,I))), !.
test(test11) :-check(_,(ev(Γ,abs(X,E),clause(Γ,X,E)))), !.
test(test12):-check(_,(et(int(_),iii))),!.
test(union_test) :- [] ⊢ int <: expr, !.
:- end_tests(check_union).

:- run_tests.
:- halt.
