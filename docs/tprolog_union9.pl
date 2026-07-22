:-op(1200,xfx,[::=,:::]).
:-op(700,xfx,⊢).
:-op(600,xfy,[$,<:,#]).
_⊢T<:T:-!.
Γ⊢T1<:T2:-member(Elm,Γ),Elm==(T1<:T2),!.
_⊢T1<:T2:-var(T1),!,T1=T2.
Γ⊢T1<:T2:-(T1:::R1),R1\=(_->_),!,[T1<:T2|Γ]⊢R1<:T2.
Γ⊢T1<:T2:-(T2:::R2),R2\=(_->_),!,[T1<:T2|Γ]⊢T1<:R2.
Γ⊢T1<:T2:-is_list(T1),is_list(T2),!,forall(member(X,T1),([T1<:T2|Γ]⊢[X]<:T2)).
Γ⊢T1<:T2:-is_list(T2),!,member(Y,T2),(T1=Y;[T1<:T2|Γ]⊢T1<:Y),!.
tp(Γ,M,T):-var(M),!,lookup_env(M,T,Γ).
tp(_,M,T):-integer(M),!,[]⊢int_t<:T.
tp(_,M,T):-atom(M),(M:::[]->T1),!,[]⊢T1<:T.
tp(_,M,T):-atom(M),!,[]⊢atom_t<:T.
tp(_,[],T):-!,[]⊢list(A)<:T,[]⊢T<:list(A).
tp(Γ,[H|Tail],list(A)):-!,tp(Γ,H,A),tp(Γ,Tail,list(A)).
tp(Γ,M,T):-compound(M),!,M=..[C|Ms],(C:::Ts->T1),[]⊢T1<:T,maplist(tp(Γ),Ms,Ts).
lookup_env(M,T,[M1:T1|_]):-M==M1,!,([]⊢T<:T1;[]⊢T1<:T).
lookup_env(M,T,[Elm|_]):-var(Elm),!,Elm=(M:T).
lookup_env(M,T,[_|Rest]):-lookup_env(M,T,Rest).
goal(Γ,G):-G=..[P|Ms],(P:::Ts),maplist(tp(Γ),Ms,Ts).
body(_,true):-!.
body(Γ,(A,B)):-!,body(Γ,A),body(Γ,B).
body(Γ,G):-goal(Γ,G).
check(Γ,Head:-Body):-goal(Γ,Head),body(Γ,Body).
check(Γ,Head):-goal(Γ,Head).
expand_bnf(T::=T2):-T2\=(_|_),assertz(T:::T2).
expand_bnf(T::=TE):-
    flat(TE,Cs),alts(Cs,T,Ts),assertz(T:::Ts),
    ( is_kind(T) -> true ; kind(T) ),
    check_kind_decl(T).
flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
alts([],_,[]).
alts([Op->T|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->G),alts(Ts,G,Cs).
typed_clause(Head):-compound(Head),Head =.. [Name|_],(Name ::: _).
:- dynamic (:::)/2. :- discontiguous (:::)/2.
:- dynamic is_kind/1.
kind(K):-assertz(is_kind(K)).
:- kind(int_t).
:- kind(atom_t).
check_kind_decl(K):-
    (K:::Names),
    forall(member(C,Names), check_kind_con(C,K)).
check_kind_con(C,K):-
    findall(As-R,(C:::As->R),Pairs),
    Pairs\=[],!,
    ( member(ArgSorts-K,Pairs) -> true
    ; throw(error(kind_error(C,result(_),expected(K)),_)) ),
    forall(member(A,ArgSorts),
           ( kind_compatible(A) -> true
           ; throw(error(kind_error(C,arg(A),not_a_kind),_)) )).
check_kind_con(_,_).
kind_compatible(A):-is_kind(A),!.
kind_compatible(A):-var(A),!.
kind_compatible(A):-
    atom(A),(A:::Body),\+ is_arg_list_form(Body),!,
    kind_compatible_body(Body), kind(A).
kind_compatible(A):-compound(A),!,A=..[_|Args],forall(member(X,Args),kind_compatible(X)).
is_arg_list_form(L):-is_list(L),!.
is_arg_list_form(L->_):-is_list(L),!.
kind_compatible_body(Body):-compound(Body),!,Body=..[_|Args],forall(member(X,Args),kind_compatible(X)).
kind_compatible_body(Body):-atom(Body),!,kind_compatible(Body).

:- multifile prolog:error_message/1.
prolog:error_message(type_error(Culprit)) --> ['Type error in ~p'-[Culprit]].
prolog:error_message(kind_error(Con,Where,What)) --> ['Kind error in constructor ~p: ~p ~p'-[Con,Where,What]].
term_expansion(A::=B,[]):-expand_bnf(A::=B).
term_expansion((Head :- Body), (Head :- Body)):-
    typed_clause(Head),!,(check(_,(Head :- Body))->true
    ; throw(error(type_error(Head), _))).
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
%eval(E1-E2,I):-eval(E1,I1),eval(E2,I2),I is I1-I2. % ERROR:    Type error in eval(_18168-_18170,_18164)
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
tc(Γ,E1-E2,i):-tc(Γ,E1,i),tc(Γ,E2,i). % error
tc(Γ,X,T):-atom(X),!,member(X:T,Γ).
tc(Γ,E1$E2,T):-tc(Γ,E1,T2->T),tc(Γ,E2,T2).
tc(Γ,λ(X,E),T1->T2):-tc([X:T1|Γ],E,T2).
:-begin_tests(t).
test(1):-check(_,(append([1],[2],[1,2]):-true)),!.
test(2):-[]⊢int_t<:expr,!.
test(3):-eval(1*2+3*4,R),R=14.
test(4):-ev([],λ(x,x+1)$(2*3),R),R=7,!.
test(5):-tc([],2,T),writeln(T),!,T=i.
test(6):-tc([],λ(x,x+1),T),writeln(T),!,T=(i->i).
:-end_tests(t).

s1_ty   ::= tint | tbool | arrow(s1_ty,s1_ty) | list_ty(s1_ty).
wf_kind(T):-is_kind(K),tp([],T,K),!.

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

test(kind_decl_time_check_rejects_bad_arg):-
    catch(
        ( expand_bnf(demo_bad_ty::=(demo_ok|demo_mk(demo_bad_ty,unregistered_sort))),
          throw(error(unexpected_success,_)) ),
        error(kind_error(_,_,_),_),
        true
    ).
test(kind_decl_time_check_accepts_good_arg):-
    expand_bnf(demo_good_ty::=(demo_leaf|demo_pair(demo_good_ty,demo_good_ty))).

test(auto_kind_registered_for_sum_type):-
    is_kind(expr), is_kind(s1_expr), is_kind(v), is_kind(t), is_kind(s1_ty).
test(pred_signature_not_auto_kind_registered):-
    \+ is_kind(eval), \+ is_kind(append), \+ is_kind(ev).
test(alias_promoted_to_kind_when_body_is_kind_compatible):-
    is_kind(v),is_kind(env).
:-end_tests(s1).

:-run_tests.
:-halt.
