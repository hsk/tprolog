:- use_module('../tprolog').

% =====================================================================
% let多相(let-polymorphism)を持つ型システムを tprolog 上に実装します。
%
% 型スキームは forall で量化した変数の集合を明示的に持たず、
% Prolog の論理変数をそのまま「未定の型変数」として保持し、
% let 束縛された変数を参照するたびに copy_term/2 で新しいインスタンス
% を作るだけの簡潔な実装にしています。
%
% ラムダ束縛の引数は単相(monomorphic)なので copy_term しては
% いけません(同じ型変数を使い回す必要があります)。そのため
% 環境の要素を mono(Ty)/poly(Ty) の2種類で区別しています。
% =====================================================================
:- op(650, yfx, [$]).

% --- 0. Prolog 組み込み述語のシグネチャ(節本体の型検査に必要) ---
'[|]'     ::= [A,list(A)]->list(A).
(+)       ::= [int_t, int_t] -> int_t.
integer   ::= [_].
is        ::= [int_t, int_t].
member    ::= [A, list(A)].
copy_term ::= [_, _].
atom      ::= [atom_t].
x         ::= atom_t.
(!)       ::= [].
(:)       ::= [x,V]->x:V.

% --- 1. 型 (t) ---
t ::= int | bool | (t->t).

% --- 2. 式 (term) ---
i     ::= int_t.
true  ::= [] -> b.
false ::= [] -> b.

e ::= i | b
    | e+e
    | if(e,e,e)
    | x
    | λ(x,e)
    | (e $ e)
    | let(x,e,e).

% --- 3. 型スキームと型付け環境 ---
% mono(T): ラムダ束縛。単相なので instantiate 時に copy_term しない。
% poly(T): let束縛。多相なので instantiate 時に copy_term して
%          参照のたびに独立した型変数のインスタンスを作る。
tscheme ::= mono(t) | poly(t).
tenv    ::= list(x:tscheme).

% --- 4. 型スキームのインスタンス化 (instantiate/2) ---
% infer/3 の X の節が本体で使うため、infer より先に
% シグネチャと節を宣言しておく必要がある
% (::= 宣言は登録した時点で述語シグネチャとして使えるようになるが、
%  節本体で呼ぶ述語は、その節が読み込まれる時点で既に
%  シグネチャが登録済みでなければメタ型検査を通らないため)。
instantiate ::= [tscheme, t].
% mono は copy_term せず、同じ型変数をそのまま返す
% (ラムダの引数が本体内の全ての出現で同じ型になるようにするため)。
instantiate(mono(T),T):- !.
% poly は copy_term して独立したインスタンスを返す
% (let束縛の変数を、出現ごとに違う型として使えるようにするため)。
instantiate(poly(T),T2):- copy_term(T,T2).

% --- 5. let多相の型推論 (infer/3) ---
infer ::= [tenv, e, t].
% X の節(裸のatomを変数として扱う)は、頭部だけを見ると
% どの節ともユニファイしてしまう(素の変数パターンのため)。
% Prolog の節インデックスではそれを区別できないので、各節で
% 自分自身がマッチしたと分かった時点で明示的にカットし、
% choicepoint が残らないようにしている。
infer(_,I,int):- integer(I), !.
infer(_,true,bool):- !.
infer(_,false,bool):- !.
infer(Γ,E1+E2,int):- !, infer(Γ,E1,int), infer(Γ,E2,int).
infer(Γ,if(E1,E2,E3),T):- !, infer(Γ,E1,bool), infer(Γ,E2,T), infer(Γ,E3,T).
infer(Γ,X,T):- atom(X),!,member(X:Scheme,Γ), instantiate(Scheme,T).
infer(Γ,λ(X,E),(T1->T2)):- !, infer([X:mono(T1)|Γ],E,T2).
infer(Γ,E1 $ E2,T1):- !, infer(Γ,E1,T2->T1), infer(Γ,E2,T2).
infer(Γ,let(X,E1,E2),T2):- !, infer(Γ,E1,T1), infer([X:poly(T1)|Γ],E2,T2).

% --- 6. ロード完了後のカインド一括検証 ---
:- check_all_kinds(Results),
   ( member(error(_,_,_,_,_,_), Results) ->
       writeln('Kind check failed!')
   ;   writeln('All kinds validated successfully!')
   ).

% --- 7. サンプルプログラム ---
% let id = λx.x in if (id true) then (id 1) else 0
% id を bool と int の両方に適用しており、let多相でなければ通らない。
sample_let_poly(
    let(id, λ(x,x),
    if(id $ true, id $ 1, 0))
).

% 同じことを let ではなく通常のラムダ適用でやろうとした版。
% id は単相にしかならないので、bool と int の両方には使えず失敗する。
sample_lambda_mono(λ(id,if(id $ true, id $ 1, 0)) $ λ(x,x)).

% --- 8. テスト ---
:- begin_tests(let_poly).

test(infer_int):- infer([],1,int).
test(infer_bool):- infer([],true,bool).
test(infer_plus):- infer([],1+2,int).
test(infer_ite):- infer([],if(true,1,2),int).
test(infer_lambda_and_app):- infer([], λ(x,x+1) $ 41,int).
% let多相: id を bool にも int にも適用できる。
test(let_polymorphism_ok):- sample_let_poly(Whole), infer([],Whole,int).
% 通常のラムダ(単相)では、同じことはできず型検査に失敗する。
test(lambda_is_monomorphic):- sample_lambda_mono(Whole), \+ infer([],Whole,_).
% 単相の確認: ラムダの引数を本体内で bool と int の両方に使うと失敗する。
test(monomorphic_lambda_rejects_mixed_use):-
    \+ infer([], λ(x, if(x,1,2)+ (x $ 1)), _).
% メタレベルの型検査: e に対して宣言していない (-)/2 を使う節は
% check/2 によってロード時に弾かれることの確認。
test(reject_undeclared_minus_clause):-
    \+ check(_, (infer(Γ,E1-E2,int):-infer(Γ,E1,int),infer(Γ,E2,int))).
% 存在しない変数の参照は失敗する。
test(reject_unbound_variable):- \+ infer([], nope, _).

:- end_tests(let_poly).

:- run_tests.
:- halt.
