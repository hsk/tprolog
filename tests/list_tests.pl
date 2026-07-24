:- use_module('../tprolog').

% =====================================================================
% リスト値(list(A)というエイリアス)と、それに伴う述語シグネチャの
% オーバーロード(pred_sig/goal)をテストするファイル。
%
% あるカインド K の選択肢に list(K) を直接混ぜる(K ::= ... | list(K).)
% と、alts/3 が list(K) を単に「list という名前の構成子」として登録
% してしまい、tp/3 の空リスト/consリスト専用節(tp(_,[],T) や
% tp(Γ,[H|Tail],list(A)))が反応できなくなる(list(A) というエイリアス
% 情報が失われるため)。そのため、値がスカラー(K)またはリスト
% (list(K))のどちらにもなりうる場合は、
%   KList ::= list(K).            % 単一選択肢の「真の型エイリアス」
%   pair  ::= (... K) | (... KList).  % 呼び出し側は2択のデータ型
% という形にする(examples/copl/EvalML4.pl/EvalML5.pl で確立したパターン)。
%
% さらに、述語(データ構成子ではなくゴールとして呼ぶもの)がスカラーと
% リストの両方を引数に取りうる場合(EvalML5.pl の doesntMatch/2 が
% 典型)は、同じ述語名に複数の引数リスト形式シグネチャを登録できる
% 必要がある。以前の pred_sig/goal は最初に見つかったシグネチャに
% 即座にコミットしてしまい、2つ目以降の候補を試せなかった
% (match_sig がデータ構成子に対してはバックトラックできるのと非対称
%  だった)。この修正(pred_sig を全候補列挙可能にし、goal/2 側で
% maplistが成功するまでバックトラックしてからカットする)を直接検証する。
% =====================================================================

% --- リスト値のスカラー/リスト2択パターン ---
'[|]' ::= [A,list(A)]->list(A).
v     ::= int_t | bool_v.
bool_v ::= true | false.
vlist ::= list(v).

% eval_pair のように「値はvかvlistのどちらか」という2択のデータ型。
holds ::= [v] | [vlist].

% --- オーバーロードされた述語シグネチャ ---
% empty/1 は「スカラーが0であること」と「リストが空であること」の
% 両方の意味で使う、意図的にオーバーロードした述語。
empty ::= [v].
empty ::= [vlist].

empty(0).
empty([]).

% shrink/2 は再帰的にスカラー/リストを行き来する述語
% (EvalML5.pl の doesntMatch/2 と同じ構造)。
shrink ::= [v].
shrink ::= [vlist].

shrink([_|T]) :- shrink(T).
shrink([]).
shrink(0).

% --- ロード完了後のカインド・節の一括検証 ---
:- dynamic program_clause_check_results/1.
:- type_check_all(kinds(_)-clauses(ClauseResults)),
   assertz(program_clause_check_results(ClauseResults)).

:- begin_tests(list_and_overload).

% 型検査自体がエラー無く完走していること
% (empty/1, shrink/1 の複数シグネチャがどちらも正しく検査されている)。
test(no_type_errors_in_program_clauses):-
    program_clause_check_results(Results),
    \+ member(error(_,_,_,_), Results).

% empty/1 が実際にスカラー版・リスト版の両方で動くこと。
test(empty_scalar):- empty(0).
test(empty_list):- empty([]).
test(empty_scalar_rejects_nonzero):- \+ empty(1).

% shrink/1 が再帰的にリスト全体を辿って最後にスカラーへ落ちること。
test(shrink_runs):- shrink([1,2,3]).

% pred_sig が実際に empty/1 の2つのシグネチャを両方列挙できること
% (以前は最初の1つにカットしてしまい、2つ目が見えなかった)。
% pred_sig/2 はモジュール外にエクスポートされていないため tprolog:
% で修飾して呼ぶ。
test(pred_sig_enumerates_all_overloads):-
    findall(Ts, tprolog:pred_sig(empty, Ts), All),
    sort(All, Sorted),
    Sorted == [[v],[vlist]].

% 型の合わない使い方は、オーバーロードを許すようになった後でも
% 依然として正しく検出されることの確認(健全性の後退が無いこと)。
% empty/1 の2つのシグネチャ([v]と[vlist])は、どちらもatom_t
% (アトム 'hello')を受け付けないはずなので、empty(hello) という
% ファクトそのものを try_check_clause/4 で直接検証する。
test(bad_empty_usage_is_still_detected):-
    try_check_clause(empty(hello), demo_file, 1, Result),
    Result = error(empty(hello), demo_file, 1, failed).

:- end_tests(list_and_overload).

:- run_tests.
:- halt.
