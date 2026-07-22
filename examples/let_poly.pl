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

% --- 0. Prolog 組み込み述語のシグネチャ(節本体の型検査に必要) ---
'[|]'     ::= [A,list(A)]->list(A).
(+)       ::= [int_t, int_t] -> int_t.
integer   ::= [_].
is        ::= [int_t, int_t].
member    ::= [A, list(A)].
copy_term ::= [_, _].
(!)       ::= [].
(:)       ::= [atom_t,V]->atom_t:V.

% --- 1. 型 (ty) ---
ty ::= tint | tbool | (ty->ty).

% --- 2. 式 (term) ---
term ::= int_t | bool_t
       | term+term
       | ite(term,term,term)
       | var(atom_t)
       | lam(atom_t,term)
       | app(term,term)
       | let(atom_t,term,term).

true  ::= [] -> bool_t.
false ::= [] -> bool_t.

% --- 3. 型スキームと型付け環境 ---
% mono(T): ラムダ束縛。単相なので instantiate 時に copy_term しない。
% poly(T): let束縛。多相なので instantiate 時に copy_term して
%          参照のたびに独立した型変数のインスタンスを作る。
tscheme ::= mono(ty) | poly(ty).
tenv    ::= list(atom_t:tscheme).

% --- 4. 型スキームのインスタンス化 (instantiate/2) ---
% infer/3 の var(X) の節が本体で使うため、infer より先に
% シグネチャと節を宣言しておく必要がある
% (::= 宣言は登録した時点で述語シグネチャとして使えるようになるが、
%  節本体で呼ぶ述語は、その節が読み込まれる時点で既に
%  シグネチャが登録済みでなければメタ型検査を通らないため)。
instantiate ::= [tscheme, ty].
% mono は copy_term せず、同じ型変数をそのまま返す
% (ラムダの引数が本体内の全ての出現で同じ型になるようにするため)。
instantiate(mono(T),T):- !.
% poly は copy_term して独立したインスタンスを返す
% (let束縛の変数を、出現ごとに違う型として使えるようにするため)。
instantiate(poly(T),T2):- copy_term(T,T2).

% --- 5. let多相の型推論 (infer/3) ---
infer ::= [tenv, term, ty].
infer(_,I,tint):- integer(I).
infer(_,true,tbool).
infer(_,false,tbool).
infer(Γ,E1+E2,tint):- infer(Γ,E1,tint), infer(Γ,E2,tint).
infer(Γ,ite(C,Th,El),Ty):- infer(Γ,C,tbool), infer(Γ,Th,Ty), infer(Γ,El,Ty).
infer(Γ,var(X),Ty):- member(X:Scheme,Γ), instantiate(Scheme,Ty).
infer(Γ,lam(X,Body),(ArgTy->ResTy)):- infer([X:mono(ArgTy)|Γ],Body,ResTy).
infer(Γ,app(F,A),ResTy):- infer(Γ,F,(ArgTy->ResTy)), infer(Γ,A,ArgTy).
infer(Γ,let(X,E1,Body),Ty):- infer(Γ,E1,T1), infer([X:poly(T1)|Γ],Body,Ty).

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
    let(id, lam(x,var(x)),
        ite(app(var(id),true), app(var(id),1), 0))
).

% 同じことを let ではなく通常のラムダ適用でやろうとした版。
% id は単相にしかならないので、bool と int の両方には使えず失敗する。
sample_lambda_mono(
    app(lam(id,
             ite(app(var(id),true), app(var(id),1), 0)),
        lam(x,var(x)))
).

% --- 8. テスト ---
:- begin_tests(let_poly).

test(infer_int):-
    infer([],1,tint).

test(infer_bool):-
    infer([],true,tbool).

test(infer_plus):-
    infer([],1+2,tint).

test(infer_ite):-
    infer([],ite(true,1,2),tint).

test(infer_lambda_and_app):-
    infer([],app(lam(x,var(x)+1),41),tint).

% let多相: id を bool にも int にも適用できる。
test(let_polymorphism_ok):-
    sample_let_poly(Whole),
    infer([],Whole,tint).

% 通常のラムダ(単相)では、同じことはできず型検査に失敗する。
test(lambda_is_monomorphic):-
    sample_lambda_mono(Whole),
    \+ infer([],Whole,_).

% 単相の確認: ラムダの引数を本体内で bool と int の両方に使うと失敗する。
test(monomorphic_lambda_rejects_mixed_use):-
    \+ infer([], lam(x, ite(var(x),1,2)+app(var(x),1)), _).

% メタレベルの型検査: term に対して宣言していない (-)/2 を使う節は
% check/2 によってロード時に弾かれることの確認。
test(reject_undeclared_minus_clause):-
    \+ check(_, (infer(Γ,E1-E2,tint):-infer(Γ,E1,tint),infer(Γ,E2,tint))).

% 存在しない変数の参照は失敗する。
test(reject_unbound_variable):-
    \+ infer([], var(nope), _).

:- end_tests(let_poly).

:- run_tests.
:- halt.
