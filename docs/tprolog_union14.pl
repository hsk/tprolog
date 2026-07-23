:-op(1200,xfx,[::=,::: ]).
:-op(700,xfx,⊢).
:-op(600,xfy,[$,<:,#]).

% --- サブタイピング・エイリアス展開ルール ---
_⊢T<:T:-!.
Γ⊢T1<:T2:-member(Elm,Γ),Elm==(T1<:T2),!.
_⊢T1<:T2:-var(T1),!,T1=T2.
Γ⊢T1<:T2:-(T1:::R1),R1\=(_->_),!,[T1<:T2|Γ]⊢R1<:T2.
Γ⊢T1<:T2:-(T2:::R2),R2\=(_->_),!,[T1<:T2|Γ]⊢T1<:R2.
Γ⊢T1<:T2:-is_list(T1),is_list(T2),!,forall(member(X,T1),([T1<:T2|Γ]⊢[X]<:T2)).
Γ⊢T1<:T2:-is_list(T2),!,member(Y,T2),(T1=Y;[T1<:T2|Γ]⊢T1<:Y),!.

% --- 項／カインド判定 (tp/3) ---
tp(Γ,M,T):-var(M),!,lookup_env(M,T,Γ).
tp(_,M,T):-integer(M),!,[]⊢int_t<:T.
tp(_,M,T):-atom(M),(M:::[]->T1),!,[]⊢T1<:T.
tp(_,M,T):-atom(M),!,[]⊢atom_t<:T.
tp(_,[],T):-!,[]⊢list(A)<:T,[]⊢T<:list(A).
tp(Γ,[H|Tail],list(A)):-!,tp(Γ,H,A),tp(Γ,Tail,list(A)).
tp(Γ,M,T):-
    compound(M),!,M=..[C|Ms],
    findall(Ts-T1, (C ::: (Ts->T1)), SigList),
    SigList \= [],match_sig(SigList, Γ, Ms, T).

match_sig(SigList, Γ, Ms, T):-
    member(Ts-T1, SigList),[] ⊢ T1 <: T,maplist(tp(Γ), Ms, Ts), !.

lookup_env(M,T,[M1:T1|_]):-M==M1,!, ([]⊢T<:T1 -> true ; []⊢T1<:T).
lookup_env(M,T,[Elm|_]):-var(Elm),!,Elm=(M:T).
lookup_env(M,T,[_|Rest]):-lookup_env(M,T,Rest).

% --- 述語シグネチャ取得 ---
pred_sig(P,Ts):- (P ::: Ts), is_list(Ts), !.
pred_sig(P,Ts):- (P ::: Target), !, Target \= (_->_), pred_sig(Target, Ts).

goal(Γ,G):-G=..[P|Ms],pred_sig(P,Ts),maplist(tp(Γ),Ms,Ts).
body(_,true):-!.
body(Γ,(A,B)):-!,body(Γ,A),body(Γ,B).
body(Γ,G):-goal(Γ,G).

check(Γ,(Head :- Body)):- !, goal(Γ,Head), body(Γ,Body).
check(Γ,Head):- goal(Γ,Head).

% --- カインド管理および遅延検証 (check_all_kinds) ---
:- dynamic (:::)/2. :- discontiguous (:::)/2.
:- dynamic is_kind/1.
% 相互再帰的な型定義に対応するため、宣言時にはカインドの整合性チェックを
% 行わず、型をそのまま登録するだけにとどめる。チェックは後で
% check_all_kinds/0 がまとめて行えるよう、宣言位置(ファイル・行番号)を
% pending_kind_check/3 に記録しておく。
:- dynamic pending_kind_check/3.

kind(K):- (is_kind(K) -> true ; assertz(is_kind(K))).
:- kind(int_t).
:- kind(atom_t).

% T2 が「述語シグネチャ([Args]/[Args]->T)」「既に定義済みの型そのものへの
% 参照(裸のatomで、かつ既に is_kind/::: が存在する)」「組み込みコンテナ
% list/1 による構造的な別名」のいずれかであれば、本当の型エイリアスとして
% 扱い、カインド登録はしない。
% それ以外(まだ誰も定義していない裸のatom、または even_succ(nat_even) の
% ような複合項)は、| がなくても単一構成子の直和型(newtype)とみなし、
% alts 経由でカインド登録する(そうしないと、その構成子が alts に一切
% 登録されず、相互再帰する単一構成子の型(例: nat_odd)や、tint のような
% 単一構成子しか持たない型が定義できなくなるため)。
% 「裸のatomなら常にエイリアス」だと、ty ::= tint. のように tint が
% 未定義の新しい型トークンである場合まで誤ってエイリアス扱いしてしまい、
% tint が構成子として登録されず typeof(_,tint) 等が失敗するので、
% "既に定義済みかどうか" を見て判定する。
is_true_alias_rhs(T2):- is_arg_list_form(T2), !.
is_true_alias_rhs(T2):- atom(T2), ( is_kind(T2) ; (T2:::_) ), !.
is_true_alias_rhs(T2):- compound(T2), functor(T2,list,1), !.

expand_bnf(T::=T2):- T2\=(_|_), is_true_alias_rhs(T2), !, assertz(T:::T2).
expand_bnf(T::=TE):-
    flat(TE,Cs), alts(Cs,T,Ts), assertz(T:::Ts),
    kind(T),
    ( source_location(File,Line) -> true ; File=unknown, Line=unknown ),
    assertz(pending_kind_check(T,File,Line)).

% 記録しておいた宣言を全てまとめて検証する。
% 個々の失敗を Results に集約するので、1つの kind_error で
% 他の宣言の検証が止まることはない(相互参照する型も、全て登録し
% 終わった後にまとめて検証すれば解決できる)。
check_all_kinds(Results):-
    findall(Result,
        ( pending_kind_check(K,File,Line),
          try_check_kind(K,File,Line,Result)
        ),
        Results).

try_check_kind(K,File,Line,Result):-
    catch(check_kind_decl(K), error(kind_error(C,W,Wh),_), Caught=yes(C,W,Wh)),
    !,
    ( var(Caught) -> Result = ok(K) ; Result = error(K,File,Line,C,W,Wh) ).
try_check_kind(K,File,Line,error(K,File,Line,unknown,unknown,goal_failed)).

flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
alts([],_,[]).
alts([Op->T|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->G),alts(Ts,G,Cs).

% 宣言時に構成子の引数型が有効な Kind かどうか判定
check_kind_decl(K):-
    (K ::: Names),
    forall(member(C, Names), check_kind_con(C, K)).

check_kind_con(C, K):-
    findall(As-R, (C ::: As->R), Pairs),
    Pairs \= [], !,
    ( member(ArgSorts-K, Pairs) -> true
    ; throw(error(kind_error(C, result(_), expected(K)), _)) ),
    forall(member(A, ArgSorts),
           ( kind_compatible(A) -> true
           ; throw(error(kind_error(C, arg(A), not_a_kind), _)) )).
check_kind_con(_, _).

kind_compatible(A):- is_kind(A), !.
kind_compatible(A):- var(A), !.
kind_compatible(A):-
    atom(A), (A ::: Body), \+ is_arg_list_form(Body), !,
    kind_compatible_body(Body), kind(A).
kind_compatible(A):- compound(A), !, A=..[_|Args], forall(member(X, Args), kind_compatible(X)).

is_arg_list_form(L):- is_list(L), !.
is_arg_list_form(L->_):- is_list(L), !.

kind_compatible_body(Body):- compound(Body), !, Body=..[_|Args], forall(member(X, Args), kind_compatible(X)).
kind_compatible_body(Body):- atom(Body), !, kind_compatible(Body).

typed_clause(Head):- compound(Head), Head =.. [Name|_], pred_sig(Name, _).

% --- 節(clause)の遅延型検証 ---
% 以前は term_expansion の中で各節をその場(ロード時)に型検査し、
% 型が合わなければ throw して(その節だけを)ロードから除外していた。
% しかし相互再帰する述語同士だと、片方の述語シグネチャがまだ
% 登録されていない時点でもう片方の節がチェックされ、誤って
% 弾かれることがある(カインドで check_all_kinds を導入したのと
% 同じ理由)。そこで節のチェックも pending_clause_check に記録するに
% とどめ、実際の検証は type_check_all/0,1 でまとめて行うようにした。
% この結果、型が合わない節も(検出はできるが)ロード時には
% 削除されずデータベースに残る点に注意。
:- dynamic pending_clause_check/3.

try_check_clause(Clause,File,Line,Result):-
    catch(
        ( check(_, Clause) -> Result = ok(Clause)
        ; Result = error(Clause,File,Line,failed)
        ),
        Err,
        Result = error(Clause,File,Line,exception(Err))
    ), !.

check_all_clauses(Results):-
    findall(Result,
        ( pending_clause_check(Clause,File,Line),
          try_check_clause(Clause,File,Line,Result)
        ),
        Results).

% ロード完了後にまとめてカインド・節の型整合性を検証する。
% Results は kinds(KindResults)-clauses(ClauseResults) の形。
type_check_all(kinds(KindResults)-clauses(ClauseResults)):-
    check_all_kinds(KindResults),
    check_all_clauses(ClauseResults).

% 上記をまとめて実行し、結果を1行で報告するだけの簡易版。
% 利用側のファイルで毎回同じ定型文を書かずに済むようにするための
% ユーティリティ。
type_check_all :-
    type_check_all(kinds(KindResults)-clauses(ClauseResults)),
    forall(member(error(K,File,Line,C,W,Wh), KindResults),
           format(user_error,
                  "~w:~w: kind error in ~w -- constructor ~w: ~w ~w~n",
                  [File,Line,K,C,W,Wh])),
    forall(member(error(Clause,File,Line,Reason), ClauseResults),
           format(user_error,
                  "~w:~w: type error in clause ~p (~w)~n",
                  [File,Line,Clause,Reason])),
    ( ( member(error(_,_,_,_,_,_), KindResults)
      ; member(error(_,_,_,_), ClauseResults) ) ->
        writeln('Type check failed!')
    ;   writeln('All kinds and clauses validated successfully!')
    ).

:- multifile prolog:error_message/1.
prolog:error_message(type_error(Culprit)) --> ['Type error in ~p'-[Culprit]].
prolog:error_message(kind_error(Con,Where,What)) --> ['Kind error in constructor ~p: ~p ~p'-[Con,Where,What]].

term_expansion(A::=B,[]):- expand_bnf(A::=B).
% 規則節 (Head :- Body) は、ロードはそのまま通し、型検査は
% pending_clause_check に登録するだけにとどめる。実際の検証は
% type_check_all/0,1 でロード完了後にまとめて行う。
term_expansion((Head :- Body), (Head :- Body)):-
    typed_clause(Head),!,
    ( source_location(File,Line) -> true ; File=unknown, Line=unknown ),
    assertz(pending_clause_check((Head:-Body),File,Line)).
% 単一項 (Head.) も同様。
term_expansion(Head, Head):-
    typed_clause(Head),!,
    ( source_location(File,Line) -> true ; File=unknown, Line=unknown ),
    assertz(pending_clause_check(Head,File,Line)).

% DCG規則 (Head --> Body) は、そのままでは差分リストの隠れた引数が
% 2つ増えるため typed_clause の対象外だが、非終端記号名にシグネチャが
% 宣言されている(= 型を付けたい)場合だけ、自前で dcg_translate_rule/2 に
% よる変換を行い、変換後の通常節を pending_clause_check に登録する。
% シグネチャが無い(型付けしていない)DCG規則は従来通り素通しし、
% SWI 標準のDCG変換に任せる。
term_expansion((Head --> Body), Translated):-
    nonvar(Head), Head \= (_,_),
    ( Head = (H2,_) -> functor(H2,Name,_) ; functor(Head,Name,_) ),
    pred_sig(Name,_),!,
    dcg_translate_rule((Head --> Body), Translated),
    ( source_location(File,Line) -> true ; File=unknown, Line=unknown ),
    assertz(pending_clause_check(Translated,File,Line)).

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

wf_kind(T):- is_kind(K), tp([], T, K), !.

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

% 節の型検査(check/2)は各節のコンパイル時に行われるが、
% even/odd の述語シグネチャは既に登録済みなので問題ない。
even(zero).
even(odd_succ(O)) :- odd(O).

odd(even_succ(E)) :- even(E).

% --- 単一構成子(newtype)の例 ---
% single_ty は tok_only という1つの(引数なしの)構成子しか持たない型。
% | が無い上に右辺が裸の atom なので、以前は「他の型への参照(エイリアス)」
% と誤判定されて tok_only が構成子として登録されず、
% tp(_,tok_only,single_ty) のような型検査が失敗する不具合があった。
% is_true_alias_rhs が「その atom が既に定義済みか」で判定するようになった
% ことで、tok_only は(まだ誰も定義していない新しい記号なので)
% 正しく single_ty の構成子として登録される。
single_ty ::= tok_only.

% --- エイリアスの定義 ---
% my_expr は「既に定義済みの expr への参照」なので、is_true_alias_rhs が
% atom(T2), (is_kind(T2);T2:::_) を満たし、正しくエイリアスと判定される。
my_expr    ::= expr.
eval_alias ::= eval.

% --- DCG規則への型付けの例 ---
% digit_tok//1 は1文字の数字を読んで整数に変換するDCG規則。
% 非終端記号名 digit_tok にシグネチャが宣言されているので、
% term_expansion が自前で dcg_translate_rule/2 により変換し、
% 変換後の通常節(差分リスト引数が2つ増える)を型検査する。
:- set_prolog_flag(double_quotes, chars).
digit_tok   ::= [int_t, list(atom_t), list(atom_t)].
code_type   ::= [atom_t, atom_t].
atom_number ::= [atom_t, int_t].
% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 のシグネチャ
% (これが無いと dcg_translate_rule で生成される S0=[C|S] のような
%  ゴールが型検査できず、digit_tok 全体が型エラーになってしまう)。
(=)         ::= [_, _].

digit_tok(I) --> [C], { code_type(C, digit), atom_number(C, I) }.

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
test(2):-[]⊢int_t<:expr,!.
test(3):-eval(1*2+3*4,R),R=14.
test(4):-ev([],λ(x,x+1)$(2*3),R),R=7,!.
test(5):-tc([],2,T),writeln(T),!,T=i.
test(6):-tc([],λ(x,x+1),T),writeln(T),!,T=(i->i).
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
    % もし誤ってエイリアス扱いされていたら single_ty ::: tok_only という
    % 「aliasとしての」事実になり、tok_only 自体は構成子としては
    % 登録されない。ここでは tok_only が nullary constructor として
    % 正しく tp/3 で型付けできることを確認する。
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
% ロード完了時点で check_all_clauses によりエラーゼロだったことを確認する
% (テスト内で追加する下記の意図的な悪い節と混ざらないよう、ロード完了
%  時点で記憶しておいた結果を見る)。
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
% 実際にこの節を通常の Head. として書いてしまっても、以前のように
% ロード時に弾かれるのではなく、そのままロードされる点に注意。
% 検出は type_check_all/check_all_clauses を呼んで初めて行われる。
test(deferred_bad_clause_is_detected_by_check_all_clauses):-
    try_check_clause(even(foo), demo_file, 12345, Result),
    Result == error(even(foo), demo_file, 12345, failed).

% type_check_all/1 は kinds(...)-clauses(...) の形でまとめて返す。
test(type_check_all_1_returns_kinds_and_clauses):-
    type_check_all(kinds(KindResults)-clauses(ClauseResults)),
    is_list(KindResults), is_list(ClauseResults).
:-end_tests(deferred_clause_check).

:-begin_tests(dcg_clause_check).
% digit_tok//1(DCG規則)が実際に動作すること。
test(digit_tok_runs):-
    phrase(digit_tok(I), ['5'], []), I == 5.
% digit_tok//1 が typed_clause として型検査され、program_clause_check_results
% に(エラー無く)含まれていることの確認
% (dcg_translate_rule で変換された3引数の節として登録されているはず)。
test(digit_tok_is_type_checked):-
    program_clause_check_results(Results),
    member(ok((digit_tok(_,_,_):-_)), Results).
% 型の合わないDCG節を試しに検証してみる。digit_tok の結果は int_t
% でなければならないので、digit_tok(foo) は本来型エラーになるはずの節。
test(deferred_bad_dcg_clause_is_detected):-
    dcg_translate_rule((digit_tok(foo) --> [_]), Translated),
    try_check_clause(Translated, demo_file, 1, Result),
    Result = error(Translated, demo_file, 1, failed).
:-end_tests(dcg_clause_check).

:-run_tests.
:-halt.
