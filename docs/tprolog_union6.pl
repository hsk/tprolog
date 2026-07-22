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
expand_bnf(T::=TE):-flat(TE,Cs),alts(Cs,T,Ts),assertz(T:::Ts).
flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
alts([],_,[]).
alts([Op->T|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->G),alts(Ts,G,Cs).
typed_clause(Head):-compound(Head),Head =.. [Name|_],(Name ::: _).
:- dynamic (:::)/2. :- discontiguous (:::)/2.
:- multifile prolog:error_message/1.
prolog:error_message(type_error(Culprit)) --> ['Type error in ~p'-[Culprit]].
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
:-run_tests.
:-halt.
