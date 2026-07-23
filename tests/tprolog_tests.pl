:- use_module('../tprolog').

% =====================================================================
% tprolog.pl 本体の仕組み(共用型・カインドシステム・遅延検証)を
% 直接テストするためのファイル。
% docs/tprolog_union13.pl(単体で完結するスナップショット)に埋め込んで
% いた例・テストを、実際に use_module(tprolog) して検証する形に
% 移植したもの。
% =====================================================================

% --- 基本型・演算子定義 ---
'[|]'  ::= [A,list(A)]->list(A).
(+)    ::= [int_t,int_t]->int_t.
(*)    ::= [int_t,int_t]->int_t.
append ::= [list(X),list(X),list(X)].
integer::= [_].
is     ::= [int_t,int_t].
member ::= [A,list(A)].
atom   ::= [atom_t].
(!)    ::= [].
(:)    ::= [atom_t,V]->atom_t:V.
env    ::= list(atom_t:v).

expr   ::= int_t|atom_t|expr+expr|expr*expr|expr$expr|λ(atom_t,expr).
v      ::= int_t|clause(env,atom_t,expr).

eval   ::= [expr,int_t].
eval(I,I):-integer(I).
eval(E1+E2,I):-eval(E1,I1),eval(E2,I2),I is I1+I2.
eval(E1*E2,I):-eval(E1,I1),eval(E2,I2),I is I1*I2.

ev     ::= [env,expr,v].
ev(_,I,I):-integer(I),!.
ev(Γ,E1+E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1+I2.
ev(Γ,E1*E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1*I2.
ev(Γ,X,V):-atom(X),!,member(X:V,Γ).
ev(Γ,E1$E2,I):-ev(Γ,E1,clause(Γ2,X,E)),ev(Γ,E2,V2),ev([X:V2|Γ2],E,I).
ev(Γ,λ(X,E),clause(Γ,X,E)).

t      ::= i | (t->t).
tenv   ::= list(atom_t:t).
tc     ::= [tenv,expr,t].
tc(_,I,i):-integer(I).
tc(Γ,E1+E2,i):-tc(Γ,E1,i),tc(Γ,E2,i).
tc(Γ,E1*E2,i):-tc(Γ,E1,i),tc(Γ,E2,i).
tc(Γ,X,T):-atom(X),!,member(X:T,Γ).
tc(Γ,E1$E2,T):-tc(Γ,E1,T2->T),tc(Γ,E2,T2).
tc(Γ,λ(X,E),T1->T2):-tc([X:T1|Γ],E,T2).

% --- System 1 (s1) の定義 ---
s1_ty   ::= tint | tbool | arrow(s1_ty,s1_ty) | list_ty(s1_ty).

s1_expr ::= int_t | bool_t | s1_expr+s1_expr | ite(s1_expr,s1_expr,s1_expr)
          | var(atom_t) | lam(atom_t,s1_ty,s1_expr) | app(s1_expr,s1_expr)
          | enil | econs(s1_expr,s1_expr).
true  ::= [] -> bool_t.
false ::= [] -> bool_t.

s1_tenv ::= list(atom_t:s1_ty).
s1_env  ::= list(atom_t:s1_v).
s1_v    ::= int_t | bool_t | closure(s1_env,atom_t,s1_ty,s1_expr) | vnil | vcons(s1_v,s1_v).

s1_eval ::= [s1_expr, s1_env, s1_v].
s1_eval(I,_,I):-integer(I).
s1_eval(true,_,true).
s1_eval(false,_,false).
s1_eval(E1+E2,Γ,I):-s1_eval(E1,Γ,I1),s1_eval(E2,Γ,I2),I is I1+I2.
s1_eval(ite(C,Th,_),Γ,V):-s1_eval(C,Γ,true),!,s1_eval(Th,Γ,V).
s1_eval(ite(C,_,El),Γ,V):-s1_eval(C,Γ,false),!,s1_eval(El,Γ,V).
s1_eval(var(X),Γ,V):-member(X:V,Γ).
s1_eval(lam(X,Ty,Body),Γ,closure(Γ,X,Ty,Body)).
s1_eval(app(F,A),Γ,V):-
    s1_eval(F,Γ,closure(Γ2,X,_,Body)),
    s1_eval(A,Γ,Av),
    s1_eval(Body,[X:Av|Γ2],V).
s1_eval(enil,_,vnil).
s1_eval(econs(H,T),Γ,vcons(Hv,Tv)):-s1_eval(H,Γ,Hv),s1_eval(T,Γ,Tv).

s1_type ::= [s1_expr, s1_tenv, s1_ty].
s1_type(I,_,tint):-integer(I).
s1_type(true,_,tbool).
s1_type(false,_,tbool).
s1_type(E1+E2,Γ,tint):-s1_type(E1,Γ,tint),s1_type(E2,Γ,tint).
s1_type(ite(C,Th,El),Γ,Ty):-s1_type(C,Γ,tbool),s1_type(Th,Γ,Ty),s1_type(El,Γ,Ty).
s1_type(var(X),Γ,Ty):-member(X:Ty,Γ).
s1_type(lam(X,ArgTy,Body),Γ,arrow(ArgTy,ResTy)):-s1_type(Body,[X:ArgTy|Γ],ResTy).
s1_type(app(F,A),Γ,ResTy):-s1_type(F,Γ,arrow(ArgTy,ResTy)),s1_type(A,Γ,ArgTy).
s1_type(enil,_,list_ty(_)).
s1_type(econs(H,T),Γ,list_ty(A)):-s1_type(H,Γ,A),s1_type(T,Γ,list_ty(A)).

% --- 相互再帰的な型(カインド)と述語の例 ---
% nat_even は構成子 odd_succ/1 の引数に nat_odd を、
% nat_odd は構成子 even_succ/1 の引数に nat_even を取り、互いに参照し合う。
% 宣言時には即座にチェックしないため、この定義順でも問題なく登録できる。
nat_even ::= zero | odd_succ(nat_odd).
nat_odd  ::= even_succ(nat_even).

even ::= [nat_even].
odd  ::= [nat_odd].

even(zero).
even(odd_succ(O)) :- odd(O).

odd(even_succ(E)) :- even(E).

% --- 単一構成子(newtype)の例 ---
% single_ty は tok_only という1つの(引数なしの)構成子しか持たない型。
single_ty ::= tok_only.

% --- エイリアスの定義 ---
my_expr    ::= expr.
eval_alias ::= eval.

% ここまでの ::= 宣言・節が出揃ったところで、まとめてカインドと節の
% 型整合性を検証する。相互再帰的な型/述語があっても、両方が登録済みに
% なったこの時点でチェックすれば解決できる。
% 結果はテストから参照できるよう記憶しておく(この後テスト内で追加される
% demo_bad_ty 等の宣言と混ざらないようにするため)。
:- dynamic program_kind_check_results/1.
:- dynamic program_clause_check_results/1.
:- check_all_kinds(Results0),
   assertz(program_kind_check_results(Results0)),
   forall(member(error(K,File,Line,C,W,Wh),Results0),
          format(user_error,
                 "~w:~w: kind error in ~w -- constructor ~w: ~w ~w~n",
                 [File,Line,K,C,W,Wh])).
:- check_all_clauses(Results1),
   assertz(program_clause_check_results(Results1)),
   forall(member(error(Clause,File,Line,Reason),Results1),
          format(user_error,
                 "~w:~w: type error in clause ~p (~w)~n",
                 [File,Line,Clause,Reason])).

% --- テスト ---
:-begin_tests(t).
test(1):-check(_,(append([1],[2],[1,2]):-true)),!.
test(2):-tp([],1,expr),!.
test(3):-eval(1*2+3*4,R),R=14.
test(4):-ev([],λ(x,x+1)$(2*3),R),R=7,!.
test(5):-tc([],2,T),!,T=i.
test(6):-tc([],λ(x,x+1),T),!,T=(i->i).
:-end_tests(t).

:-begin_tests(s1).
test(eval):-
    s1_eval(ite(true, app(lam(x,tint,var(x)+1), 41), 0),[],V), V=42.
test(type):-
    s1_type(ite(true, app(lam(x,tint,var(x)+1), 41), 0),[],T), T=tint.
test(reject_undeclared_minus):-
    \+ check(_, (s1_eval(E1-E2,Γ,I):-s1_eval(E1,Γ,I1),s1_eval(E2,Γ,I2),I is I1-I2)).
test(reject_undeclared_minus_type):-
    \+ check(_, (s1_type(E1-E2,Γ,int):-s1_type(E1,Γ,tint),s1_type(E2,Γ,tint))).
test(list_eval):-
    s1_eval(econs(1,econs(2,econs(3,enil))),[],vcons(1,vcons(2,vcons(3,vnil)))).
test(list_type):-
    s1_type(econs(1,econs(2,econs(3,enil))),[],list_ty(tint)).
test(kind_ok_list_int):-wf_kind(list_ty(tint)).
test(kind_ok_fun_to_list):-wf_kind(arrow(tint,list_ty(tbool))).
test(kind_error_arity):- \+ wf_kind(list_ty(tint,tbool)).
test(kind_error_self_application):- \+ wf_kind(list_ty(list_ty)).
test(kind_error_bad_arg):- \+ wf_kind(list_ty(foo)).

test(overloaded_operator_non_int_expr):-
    tp([], λ(x,x) + λ(y,y), expr).

% expand_bnf 自体はもう即座に検証しない(登録するだけ)ので、
% check_kind_decl/1 を明示的に呼んで同期的な検証を行う。
test(kind_decl_time_check_rejects_bad_arg):-
    expand_bnf(demo_bad_ty::=(demo_ok|demo_mk(demo_bad_ty,unregistered_sort))),
    catch(
        ( check_kind_decl(demo_bad_ty),
          throw(error(unexpected_success,_)) ),
        error(kind_error(_,_,_),_),
        true
    ).

test(kind_decl_time_check_accepts_good_arg):-
    expand_bnf(demo_good_ty::=(demo_leaf|demo_pair(demo_good_ty,demo_good_ty))),
    check_kind_decl(demo_good_ty).

% ファイル中の全ての ::= 宣言(相互参照するものも含む)が、
% check_all_kinds でまとめて検証してエラーゼロだったことを確認する
% (demo_bad_ty 等テスト内で追加される宣言と混ざらないよう、
%  ロード完了時点で記憶しておいた結果を見る)。
test(check_all_kinds_reports_no_errors_for_program_types):-
    program_kind_check_results(Results),
    \+ member(error(_,_,_,_,_,_),Results).

test(auto_kind_registered_for_sum_type):-
    is_kind(expr), is_kind(s1_expr), is_kind(v), is_kind(t), is_kind(s1_ty).
test(pred_signature_not_auto_kind_registered):-
    \+ is_kind(eval), \+ is_kind(append), \+ is_kind(ev).
test(alias_promoted_to_kind_when_body_is_kind_compatible):-
    is_kind(v), is_kind(env).
:-end_tests(s1).

:-begin_tests(kind_alias).
test(expr_as_kind):-
    tp([], 1 + 2 * 3, expr).
test(alias_as_kind):-
    tp([], 1 + 2 * 3, my_expr).
test(predicate_alias):-
    check(_, (eval_alias(1 + 2, 3) :- true)).
:-end_tests(kind_alias).

:-begin_tests(mutual_recursion).
% nat_even/nat_odd が check_all_kinds で正しくカインド登録・検証されていることの確認。
test(mutual_kinds_registered):-
    is_kind(nat_even), is_kind(nat_odd).
test(mutual_kinds_no_error_in_batch_check):-
    program_kind_check_results(Results),
    \+ member(error(nat_even,_,_,_,_,_),Results),
    \+ member(error(nat_odd,_,_,_,_,_),Results).
% even/odd は相互再帰述語として正しく動作する。
test(even_zero):- even(zero).
test(even_two):- even(odd_succ(even_succ(zero))).
test(odd_one):- odd(even_succ(zero)).
test(odd_three):- odd(even_succ(odd_succ(even_succ(zero)))).
test(reject_non_nat_arg):-
    \+ check(_, (even(odd_succ(foo)):-true)).
:-end_tests(mutual_recursion).

:-begin_tests(single_ctor_newtype).
% single_ty(::= tok_only.)が「他の型へのエイリアス」ではなく、
% ちゃんと kind として登録され、tok_only がその構成子になっていることの確認。
test(single_ty_registered_as_kind):-
    is_kind(single_ty).
test(single_ty_not_registered_as_plain_alias):-
    tp([], tok_only, single_ty).
test(single_ty_rejects_unknown_atom):-
    \+ tp([], not_tok_only, single_ty).
% 既に定義済みの型への参照(my_expr ::= expr.)は、従来通りエイリアスとして
% 扱われ、新たな kind としては登録されないことも合わせて確認する。
test(alias_to_existing_kind_not_double_registered):-
    (my_expr ::: expr),
    \+ ( (my_expr ::: Body), Body \== expr ).
:-end_tests(single_ctor_newtype).

:-begin_tests(deferred_clause_check).
% 節の型検査も、宣言と同じく「その場でチェック」ではなく
% pending_clause_check に登録するだけになり、type_check_all/0,1 で
% まとめて検証できるようになったことの確認。

% ファイル中の全ての typed_clause(even/odd/eval/ev/tc/s1_eval/...等)が、
% ロード完了時点で check_all_clauses によりエラーゼロだったことを確認する。
test(check_all_clauses_reports_no_errors_for_program_clauses):-
    program_clause_check_results(Results),
    \+ member(error(_,_,_,_),Results).

% 型の合わない節を試しに1つ検証してみる。even の引数は nat_even
% でなければならないので、even(foo) は本来型エラーになるはずの節。
% try_check_clause/4 (check_all_clauses が内部で使う判定ロジック)を
% 直接呼んで、正しくエラーとして検出できることを確認する
% (pending_clause_check への assertz は PLUnit のテスト本体が
%  別モジュールで実行されるため、そこで assertz するとグローバルな
%  動的述語ではなく別モジュール内のローカルな述語を作ってしまい
%  check_all_clauses からは見えなくなる。そのため判定ロジックを
%  直接呼ぶ形にしている)。
test(deferred_bad_clause_is_detected_by_check_all_clauses):-
    try_check_clause(even(foo), demo_file, 12345, Result),
    Result == error(even(foo), demo_file, 12345, failed).

% type_check_all/1 は kinds(...)-clauses(...) の形でまとめて返す。
test(type_check_all_1_returns_kinds_and_clauses):-
    type_check_all(kinds(KindResults)-clauses(ClauseResults)),
    is_list(KindResults), is_list(ClauseResults).
:-end_tests(deferred_clause_check).

:-run_tests.
:-halt.
