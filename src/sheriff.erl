%% Copyright (c) 2011, William Dang <malliwi@hotmail.com>,
%%                     Hamza Mahmood <zar_roc@hotmail.fr>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-module(sheriff).
-export([parse_transform/2,check/2]).

% This function is not supposed to be called.
% It is just for dialyzer's code testing
-spec check(any(),any())-> true | false.
check("Sheriff_$_test : Hello","World")->true;
check(_,_)->false.

-type form() :: any().
-type forms() :: [form()].
-type options() :: [{atom(), any()}].

-spec parse_transform(Forms, options()) -> Forms when Forms :: forms().
parse_transform(Forms, _Options) ->
    %start an ets table for global variables
    sheriff_string_generator:database(),
    %get the module name
    [_Module]=lists:foldl(
            fun({attribute,_,module,Name},Name_list) -> [Name|Name_list];
	       (_,Name_list)                         -> Name_list end,
                        [],Forms),
    %and save it in ets table
    sheriff_string_generator:name_module(_Module),
    %replaces sheriff:check calls
    New_forms=type_checking_f(Forms),
    %builf type testing functions
    sheriff_check_call:main(New_forms,_Options).

%% @doc This function genrate the AST code for static (and dynamic) type
%% @doc testing code.
-spec type_checking_f(forms())->forms().
type_checking_f(Forms)->
    %find all type definitions
    Type_fun=lists:filter( fun(X)->case X of
            {attribute,_,type,Type}->
	        sheriff_string_generator:register_type(Type),true;
	    _->false end end,
                        Forms),
    %generate a checking function for each type
    New_fun=lists:map(
        fun(X)->sheriff_static_generator:build_f(X) end, Type_fun),
    %build the new forms
    New_forms=lists:append(Forms,New_fun),
    Final_forms=export_type_definition(Type_fun,New_forms),
    %io:format("after : ~p~n", [Final_forms]),
    Final_forms.

%% @doc function for exporting types definitions
%% @doc it just export the created functions for each type to export
-spec export_type_definition(forms(),forms())->forms().
export_type_definition(Type_fun,List)->
    %change the type list in {fun,arrity}
    Fun_to_export=lists:map(
        fun({attribute,_,type,{Type_name,_,List_of_type_arg}})-> 
                {sheriff_string_generator:name_function(Type_name),
                    length(List_of_type_arg)+2} 
        end,
        Type_fun),
    %add this list to the list of function to be export
    case lists:any(fun({attribute,_L,export,_List_fun})->true;
		      (_)->false end,
                    List) of
        false->[L1,L2|TlList]=List,
	        Final_form=[L1,L2,{attribute,1,export,Fun_to_export}|TlList];
        %when 
        true->Final_form=lists:map(
		fun({attribute,_L,export,List_fun})->
		     {attribute,_L,export,lists:append(List_fun,Fun_to_export)};
		   (All)->All end,
                List)
    end,
    Final_form.