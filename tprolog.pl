:- module(tprolog, [
    % 演算子の再エクスポート
    op(1200, xfx, ::=),
    op(1200, xfx, :::),
    op(700,  xfx, ⊢),
    op(600,  xfy, $),
    op(600,  xfy, <:),

    % 主要述語
    type_check_all/0,
    type_check_all/1,
    check_all_kinds/1,
    check_all_clauses/1,
    try_check_clause/4,
    check_kind_decl/1,
    expand_bnf/1,
    check/2,
    tp/3,
    wf_kind/1,
    kind/1,
    is_kind/1,
    (:::)/2
]).

% 演算子宣言
:- op(1200, xfx, [::=, :::]).
:- op(700,  xfx, ⊢).
:- op(600,  xfy, [$, <:]).

:- dynamic (:::)/2.
:- discontiguous (:::)/2.
:- dynamic is_kind/1.
:- dynamic pending_kind_check/3.
:- dynamic pending_clause_check/3.

% --- サブタイピング (⊢) ---
_ ⊢ T <: T :- !.
Γ ⊢ T1 <: T2 :- member(Elm, Γ), Elm == (T1 <: T2), !.
_ ⊢ T1 <: T2 :- var(T1), !, T1 = T2.
Γ ⊢ T1 <: T2 :- (T1 ::: R1), R1 \= (_ -> _), !, [T1 <: T2 | Γ] ⊢ R1 <: T2.
Γ ⊢ T1 <: T2 :- (T2 ::: R2), R2 \= (_ -> _), !, [T1 <: T2 | Γ] ⊢ T1 <: R2.
Γ ⊢ T1 <: T2 :- is_list(T1), is_list(T2), !, forall(member(X, T1), ([T1 <: T2 | Γ] ⊢ [X] <: T2)).
Γ ⊢ T1 <: T2 :- is_list(T2), !, member(Y, T2), (T1 = Y ; [T1 <: T2 | Γ] ⊢ T1 <: Y), !.

% --- 項／カインド判定 (tp/3) ---
tp(Γ, M, T) :- var(M), !, lookup_env(M, T, Γ).
tp(_, M, T) :- integer(M), !, [] ⊢ int_t <: T.
tp(_, M, T) :- atom(M), (M ::: [] -> T1), !, [] ⊢ T1 <: T.
tp(_, M, T) :- atom(M), !, [] ⊢ atom_t <: T.
tp(_, [], T) :- !, [] ⊢ list(A) <: T, [] ⊢ T <: list(A).
tp(Γ, [H|Tail], list(A)) :- !, tp(Γ, H, A), tp(Γ, Tail, list(A)).
tp(Γ, M, T) :-
    compound(M), !,
    M =.. [C|Ms],
    findall(Ts-T1, (C ::: (Ts -> T1)), SigList),
    SigList \= [],
    match_sig(SigList, Γ, Ms, T).

match_sig(SigList, Γ, Ms, T) :-
    member(Ts-T1, SigList),
    [] ⊢ T1 <: T,
    maplist(tp(Γ), Ms, Ts), !.

% 修正：オープンリスト末尾（var）の判定を最優先で行う
lookup_env(M, T, Γ) :- var(Γ), !, Γ = [M:T|_].
lookup_env(M, T, [M1:T1|_]) :- M == M1, !, ([] ⊢ T <: T1 -> true ; [] ⊢ T1 <: T).
lookup_env(M, T, [_|Rest])  :- lookup_env(M, T, Rest).

% --- 述語シグネチャ取得 ---
pred_sig(P, Ts) :- (P ::: Ts), is_list(Ts), !.
pred_sig(P, Ts) :- (P ::: Target), !, Target \= (_ -> _), pred_sig(Target, Ts).

goal(Γ, G) :- G =.. [P|Ms], pred_sig(P, Ts), maplist(tp(Γ), Ms, Ts).

body(_, true) :- !.
body(Γ, (A, B)) :- !, body(Γ, A), body(Γ, B).
body(Γ, G) :- goal(Γ, G).

check(Γ, (Head :- Body)) :- !, goal(Γ, Head), body(Γ, Body).
check(Γ, Head) :- goal(Γ, Head).

% --- カインド管理および遅延検証 ---
kind(K) :- (is_kind(K) -> true ; assertz(is_kind(K))).
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
is_true_alias_rhs(T2) :- is_arg_list_form(T2), !.
is_true_alias_rhs(T2) :- atom(T2), ( is_kind(T2) ; (T2 ::: _) ), !.
is_true_alias_rhs(T2) :- compound(T2), functor(T2, list, 1), !.

expand_bnf(T ::= T2) :- T2 \= (_|_), is_true_alias_rhs(T2), !, assertz(T ::: T2).
expand_bnf(T ::= TE) :-
    flat(TE, Cs), alts(Cs, T, Ts), assertz(T ::: Ts),
    kind(T),
    ( source_location(File, Line) -> true ; File = unknown, Line = unknown ),
    assertz(pending_kind_check(T, File, Line)).

check_all_kinds(Results) :-
    findall(Result,
        ( pending_kind_check(K, File, Line),
          try_check_kind(K, File, Line, Result)
        ),
        Results).

try_check_kind(K, File, Line, Result) :-
    catch(check_kind_decl(K), error(kind_error(C, W, Wh), _), Caught = yes(C, W, Wh)),
    !,
    ( var(Caught) -> Result = ok(K) ; Result = error(K, File, Line, C, W, Wh) ).
try_check_kind(K, File, Line, error(K, File, Line, unknown, unknown, goal_failed)).

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
try_check_clause(Clause, File, Line, Result) :-
    catch(
        ( check(_, Clause) -> Result = ok(Clause)
        ; Result = error(Clause, File, Line, failed)
        ),
        Err,
        Result = error(Clause, File, Line, exception(Err))
    ), !.

check_all_clauses(Results) :-
    findall(Result,
        ( pending_clause_check(Clause, File, Line),
          try_check_clause(Clause, File, Line, Result)
        ),
        Results).

% ロード完了後にまとめてカインド・節の型整合性を検証する。
% Results は kinds(KindResults)-clauses(ClauseResults) の形。
type_check_all(kinds(KindResults)-clauses(ClauseResults)) :-
    check_all_kinds(KindResults),
    check_all_clauses(ClauseResults).

% 上記をまとめて実行し、結果を1行で報告するだけの簡易版。
% 利用側のファイルで毎回同じ定型文を書かずに済むようにするための
% ユーティリティ。
type_check_all :-
    type_check_all(kinds(KindResults)-clauses(ClauseResults)),
    forall(member(error(K, File, Line, C, W, Wh), KindResults),
           format(user_error,
                  "~w:~w: kind error in ~w -- constructor ~w: ~w ~w~n",
                  [File, Line, K, C, W, Wh])),
    forall(member(error(Clause, File, Line, Reason), ClauseResults),
           format(user_error,
                  "~w:~w: type error in clause ~p (~w)~n",
                  [File, Line, Clause, Reason])),
    ( ( member(error(_,_,_,_,_,_), KindResults)
      ; member(error(_,_,_,_), ClauseResults) ) ->
        writeln('Type check failed!')
    ;   writeln('All kinds and clauses validated successfully!')
    ).

wf_kind(T) :- is_kind(K), tp([], T, K), !.

flat(T|T2, [T|Ts]) :- !, flat(T2, Ts).
flat(T, [T]).

alts([], _, []).
alts([Op->T|Ts], G, [C|Cs]) :- Op =.. [C|As], G \= C, assertz(C ::: As->T), alts(Ts, G, Cs).
alts([Op|Ts], G, [C|Cs])    :- Op =.. [C|As], G \= C, assertz(C ::: As->G), alts(Ts, G, Cs).

check_kind_decl(K) :-
    (K ::: Names),
    forall(member(C, Names), check_kind_con(C, K)).

check_kind_con(C, K) :-
    findall(As-R, (C ::: As->R), Pairs),
    Pairs \= [], !,
    ( member(ArgSorts-K, Pairs) -> true
    ; throw(error(kind_error(C, result(_), expected(K)), _)) ),
    forall(member(A, ArgSorts),
           ( kind_compatible(A) -> true
           ; throw(error(kind_error(C, arg(A), not_a_kind), _)) )).
check_kind_con(_, _).

kind_compatible(A) :- is_kind(A), !.
kind_compatible(A) :- var(A), !.
kind_compatible(A) :-
    atom(A), (A ::: Body), \+ is_arg_list_form(Body), !,
    kind_compatible_body(Body), kind(A).
kind_compatible(A) :- compound(A), !, A =.. [_|Args], forall(member(X, Args), kind_compatible(X)).

is_arg_list_form(L) :- is_list(L), !.
is_arg_list_form(L->_) :- is_list(L), !.

kind_compatible_body(Body) :- compound(Body), !, Body =.. [_|Args], forall(member(X, Args), kind_compatible(X)).
kind_compatible_body(Body) :- atom(Body), !, kind_compatible(Body).

typed_clause(Head) :- compound(Head), Head =.. [Name|_], pred_sig(Name, _).

% カスタムエラーメッセージ
:- multifile prolog:error_message/1.
prolog:error_message(type_error(Culprit)) --> ['Type error in ~p'-[Culprit]].
prolog:error_message(kind_error(Con, Where, What)) --> ['Kind error in constructor ~p: ~p ~p'-[Con, Where, What]].

% --- ユーザー空間の項展開 (term_expansion) フック ---
:- multifile user:term_expansion/2.
user:term_expansion(A ::= B, []) :-
    expand_bnf(A ::= B).

% 規則節 (Head :- Body) は、ロードはそのまま通し、型検査は
% pending_clause_check に登録するだけにとどめる。実際の検証は
% type_check_all/0,1 でロード完了後にまとめて行う。
user:term_expansion((Head :- Body), (Head :- Body)) :-
    typed_clause(Head), !,
    ( source_location(File, Line) -> true ; File = unknown, Line = unknown ),
    assertz(pending_clause_check((Head :- Body), File, Line)).

% 単一項 (Head.) も同様。
user:term_expansion(Head, Head) :-
    typed_clause(Head), !,
    ( source_location(File, Line) -> true ; File = unknown, Line = unknown ),
    assertz(pending_clause_check(Head, File, Line)).

% DCG規則 (Head --> Body) は、そのままでは差分リストの隠れた引数が
% 2つ増えるため typed_clause の対象外だが、非終端記号名にシグネチャが
% 宣言されている(= 型を付けたい)場合だけ、自前で dcg_translate_rule/2 に
% よる変換を行い、変換後の通常節を pending_clause_check に登録する。
% シグネチャが無い(型付けしていない)DCG規則は従来通り素通りし、
% SWI 標準のDCG変換に任せる。
user:term_expansion((Head --> Body), Translated) :-
    nonvar(Head), Head \= (_,_),
    ( Head = (H2,_) -> functor(H2, Name, _) ; functor(Head, Name, _) ),
    pred_sig(Name, _), !,
    dcg_translate_rule((Head --> Body), Translated),
    ( source_location(File, Line) -> true ; File = unknown, Line = unknown ),
    assertz(pending_clause_check(Translated, File, Line)).
