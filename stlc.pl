:- use_module(tprolog_core).

% =====================================================================
% STLC (Simply Typed Lambda Calculus) を tprolog_core 上に実装する。
% ::= で宣言した型・述語シグネチャは、tprolog_core の term_expansion
% フックによって自動的にカインド登録され、各節は check/2 で
% (メタレベルの)型検査を受けた上でロードされる。
% =====================================================================

% --- 0. Prolog 組み込み述語のシグネチャ(節本体の型検査に必要) ---
% リストのコンスセル '[|]'(H,T) 自体のシグネチャ。これがないと
% [X:ArgTy|Γ] のようなリスト値を tenv/env 等のエイリアス越しに
% 型検査する際、tp/3 が '[|]' の署名を見つけられず失敗する。
'[|]'  ::= [A,list(A)]->list(A).
(+)    ::= [int_t, int_t] -> int_t.
(*)    ::= [int_t, int_t] -> int_t.
integer::= [_].
is     ::= [int_t, int_t].
member ::= [A, list(A)].
(!)    ::= [].
% 環境の要素 X:Ty / X:V の ':' 演算子のシグネチャ(tenv, env は list(atom_t:_) で
% これを使うため、節本体での ':' 項のメタ型検査に必要)。
(:)    ::= [atom_t,V]->atom_t:V.

% --- 1. STLC の型 (ty) ---
% | があるので tprolog_core により自動的に kind 登録される。
ty ::= tint | tbool | (ty->ty).

% --- 2. STLC の式 (term) ---
term ::= int_t | bool_t
       | term+term
       | ite(term,term,term)
       | var(atom_t)
       | lam(atom_t,ty,term)
       | app(term,term).

true  ::= [] -> bool_t.
false ::= [] -> bool_t.

% --- 3. 型付け環境・評価環境・値 ---
tenv ::= list(atom_t:ty).
env  ::= list(atom_t:v).
% v は closure(env,atom_t,ty,term) で env を、env は list(atom_t:v) で v を
% 参照し合う相互再帰的な定義だが、tprolog_core の遅延カインド検証
% (check_all_kinds) により、全宣言が出揃った後にまとめて解決される。
v    ::= int_t | bool_t | closure(env,atom_t,ty,term).

% --- 4. STLC の型検査 (typeof/3) ---
typeof ::= [term, tenv, ty].
typeof(I,_,tint):-integer(I).
typeof(true,_,tbool).
typeof(false,_,tbool).
typeof(E1+E2,Γ,tint):-typeof(E1,Γ,tint),typeof(E2,Γ,tint).
typeof(ite(C,Th,El),Γ,Ty):-typeof(C,Γ,tbool),typeof(Th,Γ,Ty),typeof(El,Γ,Ty).
typeof(var(X),Γ,Ty):-member(X:Ty,Γ).
typeof(lam(X,ArgTy,Body),Γ,(ArgTy->ResTy)):-typeof(Body,[X:ArgTy|Γ],ResTy).
typeof(app(F,A),Γ,ResTy):-typeof(F,Γ,(ArgTy->ResTy)),typeof(A,Γ,ArgTy).

% --- 5. STLC の評価 (eval/3, 大ステップ意味論) ---
eval ::= [env, term, v].
eval(_,I,I):-integer(I).
eval(_,true,true).
eval(_,false,false).
eval(Γ,E1+E2,I):-eval(Γ,E1,I1),eval(Γ,E2,I2),I is I1+I2.
eval(Γ,ite(C,Th,_),V):-eval(Γ,C,true),!,eval(Γ,Th,V).
eval(Γ,ite(C,_,El),V):-eval(Γ,C,false),!,eval(Γ,El,V).
eval(Γ,var(X),V):-member(X:V,Γ).
eval(Γ,lam(X,Ty,Body),closure(Γ,X,Ty,Body)).
eval(Γ,app(F,A),V):-
    eval(Γ,F,closure(Γ2,X,_,Body)),
    eval(Γ,A,Av),
    eval([X:Av|Γ2],Body,V).

% --- 6. ロード完了後のカインド一括検証 ---
:- check_all_kinds(Results),
   ( member(error(_,_,_,_,_,_), Results) ->
       writeln('Kind check failed!')
   ;   writeln('All kinds validated successfully!')
   ).

% --- 7. サンプルプログラム ---
% ite(true, (λx:tint. x+1) 41, 0)
sample_program(ite(true, app(lam(x,tint,var(x)+1), 41), 0)).

% --- 8. テスト ---
:- begin_tests(stlc).

test(typeof_whole):-
    sample_program(Whole),
    typeof(Whole,[],Ty),
    Ty == tint.

test(eval_whole):-
    sample_program(Whole),
    eval([],Whole,V),
    V == 42.

test(wf_kind_arrow_ok):-
    wf_kind((tint->tbool)).

test(wf_kind_arrow_rejects_unknown_ty):-
    \+ wf_kind((tint->foo)).

% -/2 は term に対して一切宣言していないので、
% typeof にこの節を足すと check/2 が「弾く」ことを確認する。
test(reject_undeclared_minus_clause):-
    \+ check(_, (typeof(E1-E2,Γ,tint):-typeof(E1,Γ,tint),typeof(E2,Γ,tint))).

test(reject_ill_typed_application):-
    \+ typeof(app(lam(x,tint,var(x)), true), [], _).

:- end_tests(stlc).

:- run_tests.
:- halt.
