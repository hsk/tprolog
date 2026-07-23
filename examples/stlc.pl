:- use_module('../tprolog').

% =====================================================================
% STLC (Simply Typed Lambda Calculus) を tprolog 上に実装する。
% ::= で宣言した型・述語シグネチャは、tprolog の term_expansion
% フックによって自動的にカインド登録され、各節は check/2 で
% (メタレベルの)型検査を受けた上でロードされる。
% =====================================================================

% --- 関数適用演算子 $ の定義 ---
:- op(650, yfx, [$]).

% --- 0. Prolog 組み込み述語のシグネチャ(節本体の型検査に必要) ---
'[|]'  ::= [A,list(A)]->list(A).
(+)    ::= [int_t, int_t] -> int_t.
(*)    ::= [int_t, int_t] -> int_t.
integer::= [_].
is     ::= [int_t, int_t].
member ::= [A, list(A)].
atom   ::= [atom_t].
(!)    ::= [].
x      ::= atom_t.
(:)    ::= [x,V]->x:V.

% --- 1. STLC の型 (t) ---
t ::= int | bool | (t->t).
i ::= int_t.
% --- 2. STLC の式 (e) ---
e ::= i | b
       | e+e
       | if(e,e,e)
       | x               % 変数
       | λ(x:t,e)
       | e $ e.         % 関数適用 ($)

true  ::= [] -> b.
false ::= [] -> b.

% --- 3. 型付け環境・評価環境・値 ---
tenv ::= list(x:t).
env  ::= list(x:v).
v    ::= i | b | closure(env,x:t,e).

% --- 4. STLC の型検査 (typeof/3) ---
typeof ::= [e, tenv, t].
typeof(I,_,int):-integer(I), !.
typeof(true,_,bool):- !.
typeof(false,_,bool):- !.
typeof(E1+E2,Γ,int):- !, typeof(E1,Γ,int), typeof(E2,Γ,int).
typeof(if(E1,E2,E3),Γ,T):- !, typeof(E1,Γ,bool), typeof(E2,Γ,T), typeof(E3,Γ,T).
typeof(λ(X:T1,E1),Γ,(T1->T2)):- !, typeof(E1,[X:T1|Γ],T2).
typeof(E1 $ E2,Γ,T1):- !, typeof(E1,Γ,(T2->T1)), typeof(E2,Γ,T2).
typeof(X,Γ,T):-atom(X), !, member(X:T,Γ), !.

% --- 5. STLC の評価 (eval/3, 大ステップ意味論) ---
eval ::= [env, e, v].
eval(_,I,I):-integer(I), !.
eval(_,true,true):- !.
eval(_,false,false):- !.
eval(Γ,E1+E2,I):- !, eval(Γ,E1,I1), eval(Γ,E2,I2), I is I1+I2.
eval(Γ,if(E1,E2,_),V):-eval(Γ,E1,true), !, eval(Γ,E2,V).
eval(Γ,if(E1,_,E3),V):-eval(Γ,E1,false), !, eval(Γ,E3,V).
eval(Γ,λ(X:T,E),closure(Γ,X:T,E)):- !.
eval(Γ,E1 $ E2,V):- !,
    eval(Γ,E1,closure(Γ2,X:_,E3)),
    eval(Γ,E2,V2),
    eval([X:V2|Γ2],E3,V).
eval(Γ,X,V):-atom(X), !, member(X:V,Γ), !.

% --- 6. ロード完了後のカインド一括検証 ---
:- type_check_all.

% --- 7. サンプルプログラム ---
% if(true, (λx:int. x+1) $ 41, 0)
sample_program(if(true, λ(x:int,x+1) $ 41, 0)).

% --- 8. テスト ---
:- begin_tests(stlc).

test(typeof_whole):-
    sample_program(Whole),
    typeof(Whole,[],T),
    T == int.

test(eval_whole):-
    sample_program(Whole),
    eval([],Whole,V),
    V == 42.

test(wf_kind_arrow_ok):-
    wf_kind((int->bool)).

test(wf_kind_arrow_rejects_unknown_ty):-
    \+ wf_kind((int->foo)).

test(reject_undeclared_minus_clause):-
    \+ check(_, (typeof(E1-E2,Γ,int):-typeof(E1,Γ,int),typeof(E2,Γ,int))).

test(reject_ill_typed_application):-
    \+ typeof(λ(x:int,x) $ true, [], _).

:- end_tests(stlc).

:- run_tests.
:- halt.
