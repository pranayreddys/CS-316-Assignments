%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	extern "C" void yyerror(char *s);
	extern int yylex(void);
	extern int yylineno;
	Symbol_Table* global_sym_table = new Symbol_Table();
	Symbol_Table* local_sym_table = new Symbol_Table();
%}

%union {
	int integer_value;
	double double_value;
	std::string * string_value;
	list<Ast *> * ast_list;
	Ast * ast;
	Symbol_Table * symbol_table;
	Symbol_Table_Entry * symbol_entry;
	Basic_Block * basic_block;
	Procedure * procedure;
	list<Symbol_Table_Entry *> * symbol_entry_list;
}

%token <integer_value> INTEGER_NUMBER
%token <double_value> DOUBLE_NUMBER
%token <string_value> NAME
%token BBNUM  RETURN  INTEGER  FLOAT  ASSIGN  VOID  UMINUS

%type <symbol_entry_list> variable_list	declaration	variable_declaration variable_declaration_list optional_variable_declaration_list
%type <procedure> procedure_definition
%type <ast>	assignment_statement expression
%type <ast_list> statement_list

%left '+' '-'
%left '*' '/'
%right UMINUS

%start program

%%

program					:	global_variable_declaration_list procedure_definition
							{
								program_object.set_global_table(*global_sym_table);
								program_object.set_procedure($2, yylineno);
							}
							; 

procedure_definition	:	VOID NAME '(' ')'
                  	   		'{'
									local_variable_declaration_list statement_list
        	           		'}' 
							{	
								$$ = new Procedure(void_data_type,*$2, yylineno);
								(*$$).set_local_list((*local_sym_table));
								(*$$).set_ast_list(*($7));
							}
        	           		;


global_variable_declaration_list	: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(global);
												(*global_sym_table).push_symbol(*it);
											}
										}
										;

local_variable_declaration_list		: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(local);
												(*local_sym_table).push_symbol(*it);
											}
										}
										;
								
optional_variable_declaration_list	:	/* empty */ 
										{
											$$ = new list<Symbol_Table_Entry *>();
										}
										|	variable_declaration_list
										{
											$$ = $1;
										}
										;

variable_declaration_list			:	variable_declaration
										{
											$$ = $1;
										}
										|	variable_declaration_list variable_declaration
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*($1)).push_back(*it);
											}
											$$ = $1;
										}
										;

variable_declaration				:	declaration ';'
										{
											$$ = $1;
										}
										;

declaration							:	INTEGER variable_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(int_data_type);
											}
											$$ = $2;
										}
										| FLOAT variable_list 
										{	
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(double_data_type);
											}
											$$ = $2;
										}
                                        ;

variable_list                       :	NAME	
										{
											$$ = new list<Symbol_Table_Entry *>();
											Symbol_Table_Entry* x = new Symbol_Table_Entry(*$1,int_data_type,yylineno);
											(*$$).push_back(x);
										}
										| variable_list ',' NAME
										{
											Symbol_Table_Entry* x = new Symbol_Table_Entry(*$3,int_data_type,yylineno);
											(*$1).push_back(x);
											$$ = $1;
										}
										;


statement_list	        :	/* empty */ 
							{
								$$ = new list<Ast *>();
							}
							|	statement_list assignment_statement
							{
								(*$1).push_back($2);
								$$ = $1;
							}
							;

assignment_statement	:	NAME ASSIGN expression ';'
							{
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*$1)){
									Ast* lhs = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs,$3,yylineno);
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									Ast* lhs = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs,$3,yylineno);
								}
								else{
									exit(1);
								}
							}
							;

expression				: 	INTEGER_NUMBER	
							{
								$$ = new Number_Ast<int>($1, int_data_type, yylineno);
							}
							| DOUBLE_NUMBER 
							{
								$$ = new Number_Ast<double>($1, double_data_type, yylineno);
							}
							| NAME
							{
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*($1))){
									$$ = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									$$ = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else{
									exit(1);
								}
							}
							| expression '+' expression 
							{
								$$ = new Plus_Ast($1, $3, yylineno);
							}
							| expression '*' expression 
							{
								$$ = new Mult_Ast($1, $3, yylineno);
							}
							| expression '-' expression 
							{
								$$ = new Minus_Ast($1, $3, yylineno);
							}
							| expression '/' expression 
							{
								$$ = new Divide_Ast($1, $3, yylineno);
							}
							| '('expression')'
							{
								$$ = $2;
							}
							;
%%