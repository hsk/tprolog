:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(590,yfx, ::).
:- op(600,xfy, ⇩).
:- op(800,xfx, plus).
:- op(800,xfx, minus).
:- op(800,xfx, times).
:- op(800,xfx, lessThan).
:- op(800,xfx, matches).
:- op(800,xfx, doesntMatch).
:- op(900,xfx, when).
:- op(900,xfx, in).
:- op(900,xfx, with).
:- op(990,xfx, ⱶ).
% (->)/2 はカインド宣言の「Args->Result」構文の区切りとして使われて
% いるため、'->' 自身を構成子として使うと ::= 宣言と衝突する
% (EvalML3.pl/EvalML4.pl と同じ理由)。文字列 "->" 由来のトークン以外は
% すべて '=>' を使うことで、この衝突を避ける。with(900) より弱く
% 結合させる必要があるので 950 とする(EvalML4.pl と同じ)。
:- op(950,xfx, (=>)).

% --- tok/tokens/digit の型 (EvalML1〜4.pl と同じ) ---
bool_v ::= true | false.

% トークンの種類。記号・キーワードは int(_)/bool(_)/var(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める
% (EvalML1.pl と同じ理由: 個別登録すると tp/3 のカットで汎用の
%  atom_t として分類できなくなるため)。
tok_type ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | atom_t.

% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 と '[|]' のシグネチャ。
'[|]'     ::= [A,list(A)]->list(A).
(=)       ::= [X, X].
(!)       ::= [].

tok    ::= [tok_type, list(atom_t), list(atom_t)].
digits ::= [list(atom_t), list(atom_t), list(atom_t)].
digit  ::= [atom_t, list(atom_t), list(atom_t)].
tokens ::= [list(tok_type), list(atom_t), list(atom_t)].

alpha_alnums ::= [list(atom_t), list(atom_t), list(atom_t)].
alnums       ::= [list(atom_t), list(atom_t), list(atom_t)].
alpha        ::= [atom_t, list(atom_t), list(atom_t)].

code_type    ::= [atom_t, atom_t].
number_chars ::= [int_t, list(atom_t)].

% tokenize
tokens(Ts) --> " ", tokens(Ts).
tokens([T|Ts]) --> tok(T), !, tokens(Ts).
tokens([]) --> "".

tok(int(I)) --> digits(Cs), { number_chars(I, Cs) }.
tok(bool(true)) --> "true".
tok(bool(false)) --> "false".
tok(+) --> "+".
tok(=>) --> "->".
tok(-) --> "-".
tok(*) --> "*".
tok(<) --> "<".
tok('(') --> "(".
tok(')') --> ")".
tok('[') --> "[".
tok(']') --> "]".
tok('|') --> "|".
tok(=) --> "=".
tok(::) --> "::".
tok(_) --> "_".
tok(if) --> "if".
tok(then) --> "then".
tok(else) --> "else".
tok(let) --> "let".
tok(in) --> "in".
tok(fun) --> "fun".
tok(rec) --> "rec".
tok(match) --> "match".
tok(with) --> "with".
tok(var(Cs)) --> alpha_alnums(Cs).

digits([C|Cs]) --> digit(C), digits(Cs).
digits([C])    --> digit(C).

digit(C)   --> [C], { code_type(C, digit) }.

alpha_alnums([C|Cs]) --> alpha(C), alnums(Cs).
alpha_alnums([C]) --> alpha(C).

% 元々は (alpha(C)|digit(C)) というDCGの選言(;/2に変換される)で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、;/2 を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、節を分ける形に書き換えている(EvalML1〜4と同じ)。
alnums([C|Cs]) --> alpha(C), alnums(Cs).
alnums([C|Cs]) --> digit(C), alnums(Cs).
alnums([C])    --> alpha(C).
alnums([C])    --> digit(C).

alpha(C) --> [C], { code_type(C, alpha) }.

% --- トークナイザまでの型検査 ---
:- type_check_all.

% --- 式(AST)とパーサの型 ---
% let(X = E1 in E2) -> let(in(=(X,E1), E2))
% fun(X => E) -> fun(=>(X,E))  (EvalML3.pl/EvalML4.pl と同じ工夫)
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.

% fun_abs は '=>' という新しい演算子(-> とは別)を構成子に使うことで、
% ::= の「Args->Result」構文と衝突せず、普通の ::= 宣言(LHSは構成子
% '=>')として書ける(EvalML4.pl と同じ工夫)。[Args]->Result という
% 引数リスト形式のRHSは is_true_alias_rhs により「真の型エイリアス」
% とみなされ、裸の構成子名リスト(fun_abs:::[(=>)])は登録されない。
% ただしこの真エイリアス扱いのルートでは is_kind/1 が自動では立たない
% ため、fun_abs を is_kind として明示的に登録しておく。
(=>) ::= [list(atom_t), e]->fun_abs.
:- kind(fun_abs).

% パターン(match の枝の左辺)の型。DCG規則名 pat//1 とカインド名が
% 衝突しないよう、カインド名は pat_t とする(pred_sig(pat,_) と
% pat:::Alts が同じ名前を取り合わないようにするため)。
%
% 既知の制限: nil/(::) は e(式)側でも同じ裸のアトム/演算子として
% 構成子に使われている(元のOCaml風ソースが「空リスト式」と
% 「空リストパターン」に同じ nil を再利用しているため、実行時の値も
% 共有する必要があり、パターン側だけ別のアトムに変更することはできない)。
% tp/3 の「バインド済みアトムの型を引く」節(atom(M),(M:::[]->T1),!,...)
% は最初に見つかった構成子事実に即座にコミットする設計のため、nil の
% 場合は宣言順で e/pat_t のどちらかが「代表」になり、部分型判定
% (⊢/<:)の構成子名リスト同士の緩さ(EvalML4.plのarm_nil/arm_cons調査で
% 見つけたのと同じ)とあいまって、pat_t 専用の値(例: wildcard)が
% 誤って e としても型検査を通ってしまう抜け道が理論上存在する
% (実際に本ファイル中で使われている全節・全テストには影響しない、
%  意図的に壊した節でのみ顕在化する)。将来 tprolog.pl 側で
% callable型やもっと厳密な部分型付けを導入する際の課題として残す。
pat_t ::= var(list(atom_t)) | nil | wildcard | (pat_t :: pat_t).

% clause(P => E) --> pat(P), [=>], expr(E). の結果、P => E という
% 項になる(clause_t)。DCG規則名 clause//1 との衝突を避けるため
% カインド名は clause_t とする(builtin clause/2 との名前衝突も回避)。
clause_t ::= (pat_t => e).

% match(E with Cs) の Cs は clause_t のリスト。
match_body ::= (e with list(clause_t)).

% 式(構文解析で得られるAST)。
e ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | nil
    | e+e | e-e | e*e | (e<e) | (e :: e)
    | if(e,e,e) | let(let_body) | letrec(let_body)
    | fun(fun_abs) | app(e, e) | match(match_body).

expr    ::= [e, list(tok_type), list(tok_type)].
expr1   ::= [e, e, list(tok_type), list(tok_type)].
term    ::= [e, list(tok_type), list(tok_type)].
term1   ::= [e, e, list(tok_type), list(tok_type)].
factor  ::= [e, list(tok_type), list(tok_type)].
factor1 ::= [e, e, list(tok_type), list(tok_type)].
farg    ::= [e, list(tok_type), list(tok_type)].

clauses ::= [list(clause_t), list(tok_type), list(tok_type)].
clause  ::= [clause_t, list(tok_type), list(tok_type)].
pat     ::= [pat_t, list(tok_type), list(tok_type)].
pat1    ::= [pat_t, list(tok_type), list(tok_type)].

% parse
% expr ::= term | expr + term | expr - term | expr < term | term :: expr
expr(E)      --> term(T), expr1(T, E).
expr(T :: E) --> term(T), [::], expr(E).
expr1(E1, E) --> "<", term(T), expr1(E1 < T, E).
expr1(E1, E) --> "+", term(T), expr1(E1 + T, E).
expr1(E1, E) --> "-", term(T), expr1(E1 - T, E).
expr1(E, E)  --> [].

% term ::= factor | term * factor
term(T) --> factor(F), term1(F, T).
term1(E1, E) --> "*", term(T), expr1(E1 * T, E).
term1(E, E)  --> [].

% factor ::= farg         -- function body or argument
%          | factor farg  -- function application
factor(F) --> farg(A), factor1(A, F).
factor1(F1, F) --> farg(A), factor1(app(F1,A), F).
factor1(E, E) --> [].

% farg ::= int | bool | var | '(' expr ')' | '[' ']''
%        | 'if' expr 'then' expr 'else' expr
%        | 'let' var '=' expr 'in' expr
%        | 'letrec' var '=' fun var '->' expr 'in' expr
%        | 'fun' var '->' expr
%        | 'match' expr 'with' clauses
farg(int(I)) --> [int(I)].
farg(bool(B)) --> [bool(B)].
farg(var(X)) --> [var(X)].
farg(E) --> "(", expr(E), ")".
farg(nil) --> "[]".
% if e1 then e2 else e3
farg(if(E1, E2, E3)) -->
    [if], expr(E1), [then], expr(E2), [else], expr(E3).
% let x = e1 in e2
farg(let(X = E1 in E2)) -->
    [let, var(X), =], expr(E1), [in], expr(E2).
% let rec x = fun y -> e1 in e2
farg(letrec(X = fun(Y => E1) in E2)) -->
    [let, rec, var(X), =, fun, var(Y), =>], expr(E1), [in], expr(E2).
% fun x -> e
farg(fun(X => E)) -->
    [fun, var(X), =>], expr(E).
% match e with clauses
farg(match(E with Cs)) -->
    [match], expr(E), [with], clauses(Cs).

% clauses ::= pattern '->'' e ('|' clauses)
clauses([C|Cs]) --> clause(C), ['|'], clauses(Cs).
clauses([C]) --> clause(C).

clause(P => E) --> pat(P), [=>], expr(E).

% pattern ::= (var | '[]' | '_') ('::' pattern)
pat(P1 :: P2) --> pat1(P1), [::], pat(P2).
pat(P) --> pat1(P).

pat1(var(X)) --> [var(X)].
pat1(nil) --> "[]".
pat1(wildcard) --> "_".

% --- 評価の型 (EvalML4.pl + パターンマッチの束縛) ---
% 値: 整数・真偽値、クロージャ(通常/letrec)。
v ::= int_t | bool_v | cls(env, fun_abs) | cls(env, binding).

% match/nil/:: の評価結果や、x::y パターンの y は [] や [V1|V2] と
% いう素の Prolog リストで表現される(v のリスト)。v 自身の選択肢に
% list(v) を混ぜると型のエイリアス情報が失われるため、vlist という
% 別カインドを単一選択肢の「真の型エイリアス」として用意する
% (EvalML4.pl と同じ理由)。
vlist ::= list(v).

% 評価環境 C は (変数名 = 値) のペアのリスト。値は match の
% x :: y パターンで y がリスト全体(vlist)に束縛されることがあるので、
% v と vlist の2択にする(EvalML4.pl と同じ)。
env_binding ::= (list(atom_t) = v) | (list(atom_t) = vlist).
env ::= list(env_binding).

% 'C ⱶ E ⇩ V' は実際には ⱶ(C, ⇩(E,V)) という項になるので、
% ⇩(e,v) の形を eval_pair としてカインド登録しておく。V は
% スカラー(v)またはリスト(vlist)のどちらもありうるので2択にする。
eval_pair ::= (e ⇩ v) | (e ⇩ vlist).

% plus/minus/times/lessThan は 'I1 plus I2 is I3' という中置記法で
% 書かれているが、plus 等(800,xfx) は is(700,xfx) より優先順位の
% 数値が小さい(=強く結合する)ため、実際には
%   plus(I1, is(I2,I3))
% という項に展開される。結果型を汎用の _V で受け付ける。
result_is ::= is(int_t, _V).

(+)      ::= [int_t,int_t] -> int_t.
(-)      ::= [int_t,int_t] -> int_t.
(*)      ::= [int_t,int_t] -> int_t.
is       ::= [int_t,int_t].
(<)      ::= [int_t,int_t].
plus     ::= [int_t, result_is].
minus    ::= [int_t, result_is].
times    ::= [int_t, result_is].
lessThan ::= [int_t, result_is].
(ⱶ)      ::= [env, eval_pair].
(\==)    ::= [X, X].

% --- パターンマッチ(matches/doesntMatch)の型 ---
% 'P matches V when C' は when(900) が matches(800) より弱く結合する
% ため、実際には when(matches(P,V), C) という項になり、when/2 が
% 実体の述語になる(write_canonical で確認)。matches(P,V) の V は
% スカラー(v)またはリスト(vlist)のどちらもありうるので2択にする。
matches_pair ::= (pat_t matches v) | (pat_t matches vlist).
when ::= [matches_pair, env].

% doesntMatch(P,V) の V も v/vlist の2択が必要(nil doesntMatch [_|_]
% のようにリスト全体を受けたり、P1::_ doesntMatch [V1|_] :- P1
% doesntMatch V1. のように再帰でリストの要素(スカラー)を受けたりする
% ため)。tprolog の pred_sig/goal はこの2択を試して、body(実際には
% maplist(tp(Γ),...))が通る方を選べるようにオーバーロード対応済み
% (tprolog.pl の pred_sig/goal を修正: 複数の引数リスト形式シグネチャ
%  を登録できるようにし、最初の候補で本体の型検査が失敗したら次の
%  候補にバックトラックするようにした)。
doesntMatch ::= [pat_t, v].
doesntMatch ::= [pat_t, vlist].

% xunion/env_vars が使う append/intersection(いずれも library(lists)の
% 組み込み)のシグネチャ。C1/C2/C は環境(list(env_binding))、
% V1/V2 は変数名(list(atom_t))のリスト。
append       ::= [list(env_binding), list(env_binding), list(env_binding)].
intersection ::= [list(list(atom_t)), list(list(atom_t)), list(list(atom_t))].
env_vars     ::= [list(env_binding), list(list(atom_t))].
xunion       ::= [list(env_binding), list(env_binding), list(env_binding)].

% --- パーサ+eval型宣言までの型検査(カインド宣言自体の整合性確認) ---
:- type_check_all.

% eval

% --------- E-Int
% C ⱶ i ⇩ i
_ ⱶ int(I) ⇩ I.

% --------- E-Bool
% C ⱶ b ⇩ b
_ ⱶ bool(B) ⇩ B.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 plus i2 is i3
% -------------------------------------------- E-Plus
% C ⱶ e1 + e2 ⇩ i3
C ⱶ E1 + E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 plus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 minus i2 is i3
% --------------------------------------------- E-Minus
% C ⱶ e1 - e2 ⇩ i3
C ⱶ (E1 - E2) ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 minus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 times i2 is i3
% ------------------------------------------------- E-Times
% C ⱶ e1 * e2 ⇩ i3
C ⱶ E1 * E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 times I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 less than i2 is i3
% ----------------------------------------------------- E-LessThan
% C ⱶ e1 < e2 ⇩ i3
C ⱶ (E1 < E2) ⇩ B :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 lessThan I2 is B.

% C ⱶ e1 ⇩ true   C ⱶ e2 ⇩ v
% ----------------------------- E-IfT
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, E2, _) ⇩ V :-
    C ⱶ E1 ⇩ true, C ⱶ E2 ⇩ V.

% C ⱶ e1 ⇩ false    C ⱶ e3 ⇩ v
% ----------------------------- E-IfF
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, _, E3) ⇩ V :-
    C ⱶ E1 ⇩ false, C ⱶ E3 ⇩ V.

% C ⱶ e1 ⇩ v1   C, x = v1 ⱶ e2 ⇩ v
% -------------------------------- E-Let
% C ⱶ let x = e1 in e2 ⇩ v
C ⱶ let(X = E1 in E2) ⇩ V :-
    C ⱶ E1 ⇩ V1, [X = V1 | C] ⱶ E2 ⇩ V. 

% C, x = (ε)[rec x = fun y -> e1] ⱶ e2 ⇩ v 
% ---------------------------------------- E-LetRec
% C ⱶ let rec x = fun y -> e1 in e2 ⇩ v
C ⱶ letrec(X = fun(Y => E1) in E2) ⇩ V :-
    [X = cls(C, X = fun(Y => E1)) | C] ⱶ E2 ⇩ V.

% ---------------- E-Var1
% C, x = v ⱶ x ⇩ v
[X = V | _] ⱶ var(X) ⇩ V.

% (y != x)   C ⱶ x ⇩ v2
% --------------------- E-Var2
% C, y = v1 ⱶ x ⇩ v2
[Y = _ | C] ⱶ var(X) ⇩ V :-
    Y \== X, C ⱶ var(X) ⇩ V.

% --------------------------------- E-Fun
% C ⱶ fun x -> e ⇩ (C) [fun x -> e]
C ⱶ fun(X => E) ⇩ cls(C, fun(X => E)).

% C ⱶ e1 ⇩ (C2) [fun x -> e0]
% C ⱶ e2 ⇩ v2   C2, x = v2 ⱶ e0 ⇩ v
% --------------------------------- E-App
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, fun(X => E0)),
    C ⱶ E2 ⇩ V2,
    [X = V2 | C2] ⱶ E0 ⇩ V.

% C ⱶ e1 ⇩ (C2) [rec x = fun y -> e0]   C ⱶ e2 ⇩ v2
% C2, x = (C2) [rec x = fun y -> e0], y = v2 ⱶ e0 ⇩ v
% --------------------------------------------------- E-AppRec
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, X = fun(Y => E0)),
    C ⱶ E2 ⇩ V2,
    [Y = V2, X = cls(C2, X = fun(Y => E0)) | C2] ⱶ E0 ⇩ V.

% ----------- E-Nil
% C ⱶ [] ⇩ []
_ ⱶ nil ⇩ [].

% C ⱶ e1 ⇩ v1   C ⱶ e2 ⇩ v2
% ------------------------ E-Cons
% C ⱶ e1 :: e2 ⇩ v1 :: v2
C ⱶ E1 :: E2 ⇩ [V1 | V2] :-
    C ⱶ E1 ⇩ V1, C ⱶ E2 ⇩ V2.

C ⱶ match(E0 with [P => E]) ⇩ V1 :-
    C ⱶ E0 ⇩ V,
    P matches V when C1,
    append(C1, C, C2),    % (E2 = E ; E1) , 左が先頭なので E と E1 は逆順になる
    C2 ⱶ E ⇩ V1.          % E2 |- e ⇩ v'
C ⱶ match(E0 with [(P => E) | _]) ⇩ V1 :-
    C ⱶ E0 ⇩ V,
    P matches V when C1,
    append(C1, C, C2),    % (E2 = E ; E1) , 左が先頭なので E と E1 は逆順になる
    C2 ⱶ E ⇩ V1.          % E2 |- e ⇩ v'
C ⱶ match(E0 with [(P => _) | Cs]) ⇩ V1 :-
    C ⱶ E0 ⇩ V,
    P doesntMatch V,
    C ⱶ match(E0 with Cs) ⇩ V1.

var(X) matches V when [X = V]. % X matches V when [X = V]
nil matches [] when [].        % [] matches [] when []
wildcard matches _ when [].    % _ matches v when []
P1 :: P2 matches [V1 | V2] when C :-
    P1 matches V1 when C1, P2 matches V2 when C2,
    xunion(C1, C2, C).

nil doesntMatch [_|_]. % [] doesn't match V1 :: V2
_ :: _ doesntMatch []. % P1 :: P2 doesn't match []
P1 :: _ doesntMatch [V1 | _] :- P1 doesntMatch V1.
_ :: P2 doesntMatch [_ | V2] :- P2 doesntMatch V2.

xunion(E1, E2, E3) :-
    append(E1, E2, E3),
    env_vars(E1, V1), env_vars(E2, V2), intersection(V1, V2, []).

env_vars([], []).
env_vars([X = _|E], [X | Vars]) :- env_vars(E, Vars).

% (i3 = i1 + i2)
% ---------------- B-Plus
% i1 plus i2 is i3
I1 plus I2 is I3 :-
    I3 is I1 + I2.

% (i3 = i1 - i2)
% ---------------- B-Minus
% i1 minus i2 is i3
I1 minus I2 is I3 :-
     I3 is I1 - I2.

% (i3 = i1 * i2)
% ---------------- B-Times
% i1 times i2 is i3
I1 times I2 is I3 :-
     I3 is I1 * I2.

% (b3 = i1 < i2)
% ---------------- B-LessThan
% i1 less than i2 is b3
% 元々は 'I1 < I2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :- I1 < I2, !.
_I1 lessThan _I2 is false.

% --- eval までの型検査 ---
:- type_check_all.

% --- UI (code_result/2 等) の型 ---
% string_chars/2 の第1引数はSWIのstringオブジェクトで、tp/3 に対応する
% 節が無い(atomでもリストでもcompoundでもない)ため、汎用にする。
string_chars ::= [_, list(atom_t)].
code_result  ::= [list(atom_t), v].
code_expr    ::= [list(atom_t), e].
code_tokens  ::= [list(atom_t), list(tok_type)].
% test/check_and_report は writef/2 に list(atom_t) と v が混在する
% 引数リストを渡すため、tprolog の list(A)(同種要素のみ)では
% 型付けできない(EvalML2.pl参照)。そのためシグネチャを与えず、
% 型検査の対象外(untyped)のままにする。

% UI
% phrase/2 は使わず、DCG変換後の3引数の述語として直接呼ぶ
% (tokens(Tokens,Code,[]) は phrase(tokens(Tokens),Code) と同じ意味。
%  phrase/2 は非終端記号を reified call として渡す高階述語で、
%  tprolog はcallableという概念を持たないため型付けできない)。
code_result(Code, Result) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []),
    [] ⱶ Expr ⇩ Result, !.

code_expr(Code, Expr) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []).

code_tokens(Code, Tokens) :-
    tokens(Tokens, Code, []).

% code_result/code_expr/code_tokens は type_check_all の後で
% 定義したので、ここでもう一度呼んでまとめて検証する。
:- type_check_all.

% test
% test内(:-begin_tests/:-end_testsの中)ではdouble_quotes=charsが
% 効かず、文字列リテラルがSWIのstringオブジェクトのままになるため、
% string_chars/2で明示的にcharsのリストへ変換してからcode_result/2に
% 渡す(EvalML2.plのtest/2と同じパターン)。
test(String, Expected) :-
    string_chars(String, Code),
    code_result(Code, Actual),
    check_and_report(Code, Expected, Actual).

check_and_report(Code, Expected, Expected) :- !, writef('%s => %w\n', [Code, Expected]).
check_and_report(Code, Expected, Actual) :-
    writef('%s => %w expected, but got %w\n', [Code, Expected, Actual]), fail.

:- begin_tests(eval_ml5).
test(1):- test("42", 42).
test(2):- test("1 + 2", 3).
test(3):- test("3 + 4 - 2", 5).
test(4):- test("10 - 1 - 2", 7).
test(5):- test("1 + 2 * 3", 7).
test(6):- test("(1 + 2) * 3", 9).
test(7):- test("1 < 2", true).
test(8):- test("2 < 1", false).
test(9):- test("if 1 < 2 then 3 else 4", 3).
test(10):- test("if 2 < 1 then 3 else 4", 4).
test(11):- test("if true then 1 else 2", 1).
test(12):- test("if false then 1 else 2", 2).
test(13):- test("let x = 1 in x + 2", 3).
test(14):- test("let x = 1 in let y = 2 in x + y", 3).
test(15):- test("let x = 1 in let x = 2 in x + x", 4).
test(16):- test("let double = fun x -> x + x in double 1", 2).
test(17):- test("(fun x -> fun y -> x + y) 1 2", 3).
test(18):- test("let rec fact = fun n -> if n < 2 then 1 else n * fact (n - 1) in fact 5", 120).
test(19):- test("let rec fib = fun n -> if n < 2 then n else fib (n - 1) + fib (n - 2) in fib 10", 55).
test(20):- test("match [] with [] -> 1 | a :: b -> a", 1).
test(21):- test("let x = [] in match x with [] -> 1 | a :: b -> a", 1).
test(22):- test("match 1 :: 2 :: 3 :: [] with [] -> 4 | a :: b -> a", 1).
test(23):- test("match 1 :: 2 :: 3 :: [] with [] -> 4 | a :: b -> b", [2, 3]).
test(24):- test("let rec length = fun x -> match x with [] -> 0 | a :: b -> 1 + length b in length (10 :: 20 :: 30 :: [])", 3).
test(25):- test("let rec length = fun x -> match x with [] -> 0 | _ :: b -> 1 + length b in length (1 :: 2 :: [])", 2).
test(26):- test("let rec max = fun l -> match l with [] -> 0 | x :: [] -> x | x :: y :: z -> if x < y then max (y :: z) else max (x :: z) in max (1 :: 2 :: 3 :: [])", 3).
test(27):- test("1", 1).
:- end_tests(eval_ml5).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.