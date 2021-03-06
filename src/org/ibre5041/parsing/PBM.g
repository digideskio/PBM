/*******************************************************************************
DESCRIPTION:
		Grammar for Sybase's PowerBuilder PowerScript						
		see: http://manuals.sybase.com/onlinebooks/group-pb/pbg0900e/psref/@Generic__BookTextView/222
				
AUTHOR:
		Ivan.Brezina (ibre5041@ibrezina.net)
DATE:
		DEC 2011
NOTES:
		target language Java
		antlr version 3.5
*******************************************************************************/

grammar PBM;


options {
  language = Java;
  output = AST;
}

tokens {
	DELIM = 'delim';
	
	ASTROOT = 'astroot';
	HEADER = 'header';
	BOODY = 'body';
	
	DATATYPEDECL               = 'datatypedecl';
	FORWARDDECL                = 'forwarddecl';
	TYPEVARIABLESDECL          = 'typevariablesdecl';
	GLOBALVARIABLESDECL        = 'globalvariablesdecl';
	VARIABLEDECL               = 'variabledecl';
	CONSTANTDECL               = 'constantdecl';
	FUNCTIONFORWARDDECL        = 'functionforwarddecl';
	FUNCTIONSFORWARDDECL       = 'functionsforwarddecl';
	FUNCTIONBODY               = 'functionbody';
	ONBODY                     = 'onbody';
	EVENTBODY                  = 'eventbody';
	
	STATEMENT                  = 'statement';
	SQLSTATEMENT               = 'sqlstatement';
	
	WINDOWPROP                 = 'windowprop';
	WINDOWPROPNAME             = 'windowpropname';
	WINDOWPROPVAL              = 'windowpropval';	
	WINDOWSUBPROP              = 'windowsubprop';
	WINDOWSUBPROPNAME          = 'windowsubpropname'; // windowsubpropname == "retreive" is what you're looking for
	WINDOWSUBPROPVAL           = 'windowsubpropval';
}

@header {
  package org.ibre5041.parsing;
}

@lexer::header {
  package org.ibre5041.parsing;
}

@lexer::members {
List tokens = new ArrayList();
public void emit(Token token) {
		state.token = token;
		tokens.add(token);
}
public Token nextToken() {
		super.nextToken();
		if ( tokens.size()==0 ) {
				return super.getEOFToken();
		}
		return (Token)tokens.remove(0);
}
}

@parser::members {

}

start_rule
	: header_rule	body_rule* EOF   
	 -> ^('astroot' ^('header' header_rule?) ^('body' body_rule*)) 
	;

// NOTE: this rule can match an empty string
header_rule
	: export_header* release_information? window_property_line*
	;

body_rule
	:
	  datatype_decl                -> ^('datatypedecl' datatype_decl)	  
	| access_modif!
	| forward_decl                 -> ^('forwarddecl' forward_decl)
	| type_variables_decl          -> ^('datatypedecl' type_variables_decl)
	| global_variables_decl        -> ^('datatypedecl' global_variables_decl)
	| variable_decl                -> ^('variabledecl' variable_decl)
	| constant_decl                -> ^('constantdecl' constant_decl)
	| functions_forward_decl       -> ^('functionsforwarddecl' functions_forward_decl)
	| function_body                -> ^('functionbody' function_body)
	| on_body                      -> ^('onbody' on_body)
	| event_body                   -> ^('eventbody' event_body)
	;
	
// Header fields
export_header
	:
	( 
		{ input.LT(1).getText().contains("PBExport") }? i=ID { $i.setType(EXPORT_HEADER); } swallow_to_newline
		| EXPORT_HEADER
		| PBSELECT 
	)
	(NEWLINE | EOF) 
	;
	
release_information
	:	'RELEASE' NUMBER SEMI // delim - ignored due to preceeding SEMI see lexer rule NEWLINE 
	;

window_property_line
	: window_property+ delim
	;
	
window_property
	:
	(
	 attribute_name array_decl_sub?
	 LPAREN
	 window_property_attributes_sub?
	 RPAREN
	)
	-> ^('windowprop' ^('windowpropname' attribute_name array_decl_sub?) ^('windowpropval' LPAREN window_property_attributes_sub? RPAREN))
	;

window_property_attributes_sub
	: window_property_attribute_sub+
	;
	
window_property_attribute_sub
	:		(('NULL' | numeric_atom | DQUOTED_STRING | DATE | TIME) NEWLINE? COMMA?)
			|
			(
				attribute_name eq='=' 
				(
					attribute_value array_decl_sub?
					| LPAREN window_property_attributes_sub RPAREN
				) 
			) 
			NEWLINE? COMMA?
			-> ^('windowsubprop' ^('windowsubpropname' attribute_name) ^('windowsubpropval' attribute_value? array_decl_sub? LPAREN? window_property_attributes_sub? RPAREN?))			
	;

attribute_name
	: (identifier_name | 'TYPE' | 'UPDATE') NUMBER?
	( DOT ( identifier_name | 'CASE' | 'TYPE' | 'ON' | 'DYNAMIC') )*
	;

fragment
attribute_sub_call
    : identifier_name LPAREN expression_list? RPAREN
    ;
fragment    
attribute_sub_member    
    :  identifier_name
    ;

attribute_value
    : (attribute_sub_call) => attribute_sub_call
    | (attribute_sub_member) => attribute_sub_member    
    | ('-')? numeric_atom
    | boolean_atom
    | ENUM
    | DQUOTED_STRING
    | QUOTED_STRING
    | DATE
    | TIME
    | 'TYPE' | 'TO' | 'FROM' | 'REF' | 'NULL' | T_OPEN | 'EVENT'
    | LPAREN 
					LPAREN (expression | data_type_sub ) (COMMA (expression| data_type_sub))? RPAREN
					(COMMA LPAREN (expression | data_type_sub ) (COMMA (expression | data_type_sub))? RPAREN)* 
			RPAREN
		| data_type_sub (LPAREN NUMBER RPAREN)?    
    ;
	
// Forward declaration
forward_decl
	: 
		'FORWARD' delim
		(datatype_decl | variable_decl)+
		'END' 'FORWARD' delim
	;

// Type declaration
datatype_decl
	:
		scope_modif? 'TYPE' identifier_name 'FROM' (identifier_name '`')? data_type_name ('WITHIN' identifier_name)? ('AUTOINSTANTIATE')?
		('DESCRIPTOR' DQUOTED_STRING '=' DQUOTED_STRING)? delim  
		(variable_decl | event_forward_decl)*
		'END' 'TYPE' delim
	;

type_variables_decl
	:
	'TYPE' 'VARIABLES' delim
	(access_modif | variable_decl | constant_decl)* 
	'END' 'VARIABLES' delim
	;

global_variables_decl
	:
	('GLOBAL'|'SHARED') 'VARIABLES' delim
	(variable_decl | constant_decl)*
	'END' 'VARIABLES' delim
	;

// Variable declaration
variable_decl_sub
    :
    ('INDIRECT')?
    access_modif_part?
    scope_modif?
    //indirect string y[] {  " ", "  a", "  1", "  ", "  2"  }
    (
   			  data_type_name decimal_decl_sub? identifier_name_ex array_decl_sub ( ('=')? '{' expression_list '}')?
   			|	data_type_name decimal_decl_sub? identifier_name_ex ('=' expression)?
   	)
    (
      	COMMA 
      	(
      				identifier_name_ex array_decl_sub ( ('=')? '{' expression_list '}')?
      			|	identifier_name_ex ('=' expression)?
    	  )
    )*
    ('DESCRIPTOR' DQUOTED_STRING '=' DQUOTED_STRING)?
    ;

variable_decl
		: variable_decl_sub delim
		;
		
decimal_decl_sub
    :   '{' NUMBER '}'
    ;

array_decl_sub
    :   '[]'
    |		'[' ( ( '+' | '-' )? NUMBER ('TO' ( '+' | '-' )? NUMBER)? (COMMA ( '+' | '-' )? NUMBER ('TO' ( '+' | '-' )? NUMBER)? )* )? ']'
    ;

constant_decl_sub
    : // TODO '=' is mandatory for constants
    		access_modif_part? 'CONSTANT' variable_decl_sub
    ;   

constant_decl
		: constant_decl_sub delim
		;
		
function_forward_decl
	:
	access_modif_part?
	scope_modif?
	('FUNCTION' data_type_name | 'SUBROUTINE')	
	identifier_name
	LPAREN
	parameters_list_sub?
	RPAREN
	('LIBRARY' (DQUOTED_STRING|QUOTED_STRING) ('ALIAS' 'FOR' (DQUOTED_STRING|QUOTED_STRING) )? )?
	('RPCFUNC' ('ALIAS' 'FOR' (DQUOTED_STRING|QUOTED_STRING))? )?
	('THROWS' identifier_name)?
	delim
	;

parameter_sub
	:
		('READONLY')? ('REF')? data_type_name decimal_decl_sub? identifier_name_ex array_decl_sub?
	;

parameters_list_sub
	:
		parameter_sub (COMMA parameter_sub)*
	;

functions_forward_decl
	:
		('FORWARD'|'TYPE') 'PROTOTYPES' delim
		(access_modif | function_forward_decl)*
		'END' 'PROTOTYPES' delim
	;
	
function_body
	:
	('PUBLIC' | 'PRIVATE' | 'PROTECTED')?
	scope_modif?
	('FUNCTION' data_type_name | 'SUBROUTINE')	
	identifier_name
	LPAREN
	parameters_list_sub?
	RPAREN 	('THROWS' identifier_name)?
	delim
	(statement)*
	'END' ('FUNCTION'|'SUBROUTINE') delim
	;

fragment
event_name_sub
	: T_OPEN | T_CLOSE | 'DESTROY' | 'CREATE'
	;
event_name
	: event_name_sub | identifier_name
	;
on_body
	: 'ON' event_name ( (DOT|FOUR_DOTS) event_name)?
	// Ugly hack:
	// on ue_postopen;setpointer(Hourglass!)
	// on itemfocuschanged;IF ib_import THEN return
	delim
	(statement)*
	'END' 'ON' delim
	;

event_forward_decl_sub
	: 'EVENT' (identifier_name | 'CREATE' | 'DESTROY') identifier_name? (LPAREN parameters_list_sub? RPAREN)? 
	| 'EVENT' 'TYPE' data_type_name identifier_name (LPAREN parameters_list_sub? RPAREN) 
	;
	
event_forward_decl
	: event_forward_decl_sub delim
	;
	
event_body
	// Ugly hack on event dw_summary::doubleclicked;call super::doubleclicked;long ll_row
	: 'EVENT' NEWLINE? ('TYPE' data_type_name)? (identifier_name '::')? (identifier_name | T_OPEN | T_CLOSE)
	(LPAREN parameters_list_sub? RPAREN)?
	SEMI
	(statement)*	
	'END' 'EVENT' delim
	;
	
// Member access modifiers
access_modif
    :
    (
        'PUBLIC:' | 'PUBLIC' ':'
    |   'PRIVATE:' | 'PRIVATE' ':'
    |   'PROTECTED:' | 'PROTECTED' ':'
    )
    delim
    ;

access_modif_part
		: 'PUBLIC' | 'PRIVATE' | 'PRIVATEREAD' | 'PRIVATEWRITE' | 'PROTECTED' | 'PROTECTEDREAD' | 'PROTECTEDWRITE'
		;
		
scope_modif
    : 'GLOBAL' | 'LOCAL'
    ;
    
// value expressions
expression
    : ('{') => '{' expression_list '}'
		| ('CREATE') => create_call_sub
		| boolean_expression
    ;

expression_list
	: ('REF'? expression) (COMMA 'REF'? expression)*    
	;
	
// LOGICAL expression  
boolean_expression
    :   condition_or
    ;

condition_or
    :   condition_and ( 'OR' condition_and )*
    ;

condition_and
    :   condition_not ( 'AND' condition_not )*
    ;

condition_not
    :   ('NOT')? condition_comparison
    ;

// RELATIONAL
condition_comparison
    :
        add_expr (( '=' | '>' | '<' | '<>' | '>=' | '<=' ) add_expr)?
    ;
    
// ARITHMETICAL
add_expr
    :   mul_expr ( ('-' | '+') mul_expr )*
    ;

mul_expr
    :   unary_sign_expr ( ( '*' | '/' | '^' ) unary_sign_expr )*
    ;

unary_sign_expr
    : (LPAREN expression RPAREN) => (LPAREN expression RPAREN)
    | ('-' | '+')? atom
    ;
    

// Statements
statement
		:
		(if_simple_statement) => if_simple_statement                 -> ^('statement' if_simple_statement)
		| (assignment_statement) => assignment_statement             -> ^('statement' assignment_statement)
		| (if_statement) => if_statement                             -> ^('statement' if_statement)
		| ('TRY') => try_catch_block                                 -> ^('statement' try_catch_block)
		| (constant_decl) => constant_decl                           -> ^('statement' constant_decl)
		| (variable_decl) => variable_decl                           -> ^('statement' variable_decl)
		| (super_call_statement) => super_call_statement             -> ^('statement' super_call_statement)
		| (do_loop_while_statement) => do_loop_while_statement       -> ^('statement' do_loop_while_statement)
		| (do_while_loop_statement)	=> do_while_loop_statement       -> ^('statement' do_while_loop_statement)
		| (create_call_statement) => (create_call_statement)         -> ^('statement' create_call_statement)
		| (destroy_call_statement) => (destroy_call_statement)       -> ^('statement' destroy_call_statement)
		| (label_stat) => label_stat                                 -> ^('statement' label_stat)
		| {(input.LA(1)==T_OPEN||input.LA(1)== T_CLOSE||input.LA(1)== T_UPDATE|input.LA(1)== T_DESCRIBE)&& input.LA(2)==LPAREN}?
				atom delim                                                 -> ^('statement' atom)
		|	{   
				input.LA(1)==T_CLOSE      ||
				input.LA(1)==T_COMMIT     ||
				input.LA(1)==T_CONNECT    ||
				input.LA(1)==T_DECLARE    ||
				input.LA(1)==T_DELETE     ||
				input.LA(1)==T_DESCRIBE   ||
				input.LA(1)==T_DISCONNECT ||
				input.LA(1)==T_EXECUTE    ||
				input.LA(1)==T_FETCH      ||
				input.LA(1)==T_IMMEDIATE  ||
				input.LA(1)==T_INSERT     ||
				input.LA(1)==T_MERGE      ||
				input.LA(1)==T_OPEN       ||
				input.LA(1)==T_PREPARE    ||
				input.LA(1)==T_ROLLBACK   ||
				input.LA(1)==T_SELECT     ||
				input.LA(1)==T_SELECTBLOB ||
				input.LA(1)==T_UPDATE     ||
				input.LA(1)==T_UPDATEBLOB
			}?
			sql_statement                                              -> ^('sqlstatement' sql_statement)
		| throw_stat                                                 -> ^('statement' throw_stat)
		| goto_stat                                                  -> ^('statement' goto_stat) 
		| choose_statement                                           -> ^('statement' choose_statement)
		| return_statement                                           -> ^('statement' return_statement)
		| for_loop_statement                                         -> ^('statement' for_loop_statement)
		| continue_statement                                         -> ^('statement' continue_statement)
		| exit_statement                                             -> ^('statement' exit_statement)
		| halt_statement_sub delim		                               -> ^('statement' halt_statement_sub)
		| atom delim                                                 -> ^('statement' atom)
		;

statement_sub
		: (return_sub) => return_sub
		| (variable_decl_sub) => variable_decl_sub		
		| (super_call_sub) => super_call_sub
		| (create_call_sub) => create_call_sub
		| (destroy_call_sub) => destroy_call_sub
		| (continue_sub) => continue_sub
		| (goto_stat_sub) => goto_stat_sub				
		| (assignment_sub) => assignment_sub
		| exit_statement_sub
		| halt_statement_sub
		| atom
		;
		
assignment_sub
    :
        lvalue_sub ( ('[]')? '=' | '+=' | '-=' | '*=' | '/=' )
        (
        ('NOT') => boolean_expression
        | ('{') => '{' expression_list '}' // NOTE: this is an array assignment TOO
        | (boolean_expression) => boolean_expression
        | expression
        )
    ;
assignment_statement
		: assignment_sub delim
		;
		
lvalue_sub
		: identifier_name (atom_array_access_suffix|atom_call_suffix)?
		(
			DOT identifier_name_ex (atom_array_access_suffix|atom_call_suffix)?
		)*		
		;
		
return_sub
		: 'RETURN' expression?
		;
		
return_statement
		: return_sub delim
		;		
		
open_call_sub
		: T_OPEN LPAREN expression_list? RPAREN
		;

update_call_sub
		: 'UPDATE' LPAREN expression_list? RPAREN
		;
		
close_call_sub
		:	T_CLOSE LPAREN expression_list? RPAREN
		;

describe_call_sub
		:	T_DESCRIBE LPAREN expression_list? RPAREN
		;
		
halt_statement_sub
		: 'HALT' T_CLOSE
		;

super_call_sub
		: 'CALL' identifier_name ('`' identifier_name)? FOUR_DOTS event_name 
		;

super_call_statement
		: super_call_sub delim
		;

create_call_sub
		: 'CREATE' ('USING')? (identifier_name DOT)? data_type_name	(LPAREN expression_list? RPAREN)?
		;
		
create_call_statement
		: 	create_call_sub delim
		;	

destroy_call_sub
		: 'DESTROY' atom	
		;
		
destroy_call_statement
		: 	destroy_call_sub delim
		;	
								
for_loop_statement
		:
			'FOR' lvalue_sub '=' expression 'TO' expression ('STEP' expression)? delim
			statement*
			( 'NEXT' delim | 'END' 'FOR' delim)
		;

do_while_loop_statement
		: 'DO' ('WHILE' | 'UNTIL') boolean_expression delim
			statement*
			'LOOP' delim			
		;

do_loop_while_statement
		: 'DO' delim
			statement*
			'LOOP' ('WHILE' | 'UNTIL') boolean_expression delim			
		;
		
if_statement
		:	'IF' boolean_expression 'THEN' delim
			statement*
			(
				'ELSEIF' boolean_expression 'THEN' delim
				statement* 
			)*			
			(
				'ELSE' delim
				statement* 
			)?
			'END' 'IF' delim
		;

// NOTE this one is single liner (all statements end with delim)
if_simple_statement
		: 'IF' boolean_expression 'THEN' statement_sub ('ELSE' statement_sub)? delim
		;

continue_sub
		: 'CONTINUE'
		;

continue_statement
		: continue_sub delim
		;

exit_statement_sub
		: 'EXIT'		
		;
		
exit_statement
		: exit_statement_sub delim
		;
		
choose_statement
		: 'CHOOSE' 'CASE' expression delim
			( 
			(choose_case_range_sub) => choose_case_range_sub
			| (choose_case_cond_sub) => choose_case_cond_sub
			| (choose_case_else_sub) => choose_case_else_sub
			| choose_case_value_sub  
			)+
			'END' 'CHOOSE' delim
		;

choose_case_value_sub
		: 'CASE' expression (COMMA expression)* delim
			statement*
		;

choose_case_cond_sub
		: 'CASE' 'IS' ( '=' | '>' | '<' | '<>' | '>=' | '<=' ) expression delim
			statement*
		;

choose_case_range_sub
		: 'CASE' atom 'TO' atom delim
					statement*
		;
		
choose_case_else_sub
		: 'CASE' 'ELSE' delim
			statement*
		;		

goto_stat_sub
		: 'GOTO' identifier_name
		;
		
goto_stat
		: goto_stat_sub delim
		;
		
label_stat
		: identifier_name COLON delim
		;

try_catch_block
		: 'TRY' delim
		statement*
		(
			'CATCH' LPAREN variable_decl_sub RPAREN delim
			statement*	
		)*
		(
			'FINALLY' delim
			statement*
		)?
		'END' 'TRY' delim	
		;

throw_stat_sub
		:	'THROW' expression
		;

throw_stat
		: throw_stat_sub delim
		;		

sql_statement
		: // NOTE: since the SQL statement ends with SEMI, a newline(delim) is on the HIDDEN channel
		(T_OPEN|T_CLOSE|'UPDATE') swallow_to_semi SEMI		
		| // Long ones
		(  
			('SELECT' | 'SELECTBLOB' | 'UPDATEBLOB' | 'INSERT' | 'MERGE' | 'DELETE' | 'PREPARE' |
			'EXECUTE' 'IMMEDIATE' |
			'DECLARE' | 'FETCH' |
			'COMMIT'| 'ROLLBACK' | 'CONNECT' | 'DISCONNECT' ) 
			swallow_to_semi SEMI // delim
		)
		| // Short ones
		( 'COMMIT' | 'CONNECT' | 'ROLLBACK' | 'DISCONNECT' ) SEMI // delim
		| // Strange ones (NOTE: Here we handle presence of the function describe(String s)) 
		( T_DESCRIBE identifier_name identifier_name identifier_name ) SEMI // delim
		|
		( 'EXECUTE' identifier_name) SEMI
		;

identifier_name
    : ID
    ;

// this one can be used in expressions like:
// excel_object.Application.Sheets("Sheet1").Select()
// identifier_name_ex is never the first part in the identifier
identifier_name_ex
    : identifier_name
    | 'SELECT' | 'TYPE' | 'UPDATE' | 'DELETE' | T_OPEN | T_CLOSE 
    | 'GOTO' | 'INSERT' | T_DESCRIBE | 'TIME' | 'READONLY' | 'CREATE'
    | 'APPLICATION'
    ;

fragment
atom_call_suffix
    : LPAREN expression_list? RPAREN
    ;

fragment
atom_array_access_suffix
    : '[' expression_list? ']'
    | '[]'
    ;


atom :
		(
			identifier_name (atom_call_suffix | atom_array_access_suffix)?
			(
				DOT 
				( ('FUNCTION'|'EVENT') ('STATIC'|'DYNAMIC')? ('POST' | 'TRIGGER')? identifier_name_ex atom_call_suffix
				| ('STATIC'|'DYNAMIC') ('POST' | 'TRIGGER')? ('FUNCTION'|'EVENT')? identifier_name_ex atom_call_suffix
				| ('POST' | 'TRIGGER') ('FUNCTION'|'EVENT')? identifier_name_ex atom_call_suffix				
				|	identifier_name_ex (atom_call_suffix | atom_array_access_suffix)?
				)
			)*
			(			  
				FOUR_DOTS
				('FUNCTION'|'EVENT')?	('POST' | 'TRIGGER')? identifier_name_ex atom_call_suffix
			)?
			('++' | '--')?
		)
		|
		(
			('FUNCTION'|'EVENT') ('STATIC'|'DYNAMIC')? ('POST' | 'TRIGGER')? identifier_name atom_call_suffix
		)
		|
		(
			('POST' | 'TRIGGER') ('FUNCTION'|'EVENT')? event_name atom_call_suffix
		)
		|		
		(
			(event_name_sub | data_type_sub | 'DESCRIBE' | 'UPDATE' ) atom_call_suffix
		)
    | numeric_atom
    | boolean_atom
    | ENUM
    | DQUOTED_STRING
    | QUOTED_STRING
    | DATE
    | TIME 		
     ;

swallow_to_semi :
        ~( SEMI )+
    ;
    
swallow_to_newline :
       ~( NEWLINE )+
    ;   
	
numeric_atom
    : NUMBER
    ;

boolean_atom
    : 'TRUE'
    | 'FALSE'
    ;

cast_expression
		: data_type_sub LPAREN expression (COMMA expression)* RPAREN
		;
		
data_type_sub
    :   'APPLICATION'
    |   'ANY'
    |   'BLOB'
    |   'BOOLEAN'
    |   'BYTE'
    |   'CHARACTER'
    |   'CHAR'
    |   'DATE'
    |   'DATETIME'
    |   'DECIMAL'
    |   'DEC'
    |   'DOUBLE'
    |   'INTEGER'
    |   'INT'
    |   'LONG'
    |   'LONGLONG'
    |   'REAL'
    |   'STRING'
    |   'TIME'
    |   'UNSIGNEDINTEGER'
    |   'UINT'
    |   'UNSIGNEDLONG'
    |   'ULONG'
    |		'WINDOW'
    ;

data_type_name
		: data_type_sub
		| identifier_name
		;
    
delim
    : NEWLINE
    | DELIM
    | EOF
    | SEMI
    ;

T_CLOSE:        'CLOSE';
T_COMMIT:       'COMMIT';
T_CONNECT:      'CONNECT';
T_DECLARE:      'DECLARE';
T_DELETE:       'DELETE';
T_DESCRIBE:     'DESCRIBE';
T_DISCONNECT:   'DISCONNECT';
T_EXECUTE:      'EXECUTE';
T_FETCH:        'FETCH';
T_IMMEDIATE:    'IMMEDIATE';
T_INSERT:       'INSERT';
T_MERGE:        'MERGE';
T_OPEN:         'OPEN';
T_PREPARE:      'PREPARE';
T_ROLLBACK:     'ROLLBACK';
T_SELECT:       'SELECT';
T_SELECTBLOB:   'SELECTBLOB';
T_UPDATE:       'UPDATE';			
T_UPDATEBLOB:   'UPDATEBLOB';
    
DQUOTED_STRING
    :   '"' (E_TILDE | ~('"') | E_DOUBLE_QUOTE )* '"'
    ;
    
QUOTED_STRING
    :   '\'' ( ~('\'') | E_QUOTE )* '\''
    ;    

fragment
ID_PARTS
		: ('A' .. 'Z' | '#') ( 'A' .. 'Z' | DIGIT | '-' | '$' | '#' | '%' | '_' )*
		;

ENUM
    :
        ID_PARTS '!'
    ;

COMMA : ',';


ID  :
        ID_PARTS
    ;

SEMI :
    ';'
// NOTE: this breaks SQL statements     
//    WS* n='\r\n'?
//    {
//    	if( $n != null)
//    	$type = DELIM;
//    }
		;

LPAREN : '(';

RPAREN : ')';

COLON : ':';

NUMBER
    :
        (   ( NUM POINT NUM ) => NUM POINT NUM
        |   POINT NUM
        |   NUM
        )
        ( 'E' ( '+' | '-' )? NUM )?
        ( 'D' | 'F')?
    ;

fragment
NUM : DIGIT ( DIGIT )*;

DOT : POINT;

FOUR_DOTS : '::';

fragment
POINT : '.';

DQUOTE : '"';

SL_COMMENT
	:	'//' ~('\n'|'\r')* d='\r\n'
	{
			int pos = state.tokenStartCharIndex;
			boolean textFound = false;
			while(pos-- != 0)
			{
				String c = input.substring(pos, pos);	
				if(c.equals("\n"))
					break;
				if(c.equals(";"))
					break;					
				if(c.equals("*"))
					break;					
				if(!c.equals(" ") && !c.equals("\t") && !c.equals("/"))
				{
					textFound = true;
					break;
				}
			}
			if(textFound)
			{
				$d.setType(DELIM);
				emit($d);
			}
			$channel=HIDDEN;
	}
	;

ML_COMMENT
	:	'/*' ( options {greedy=false;} : . )* '*/' //'/'* WS* //d='\r\n' 
	{
		$channel=HIDDEN;
	}
	;

WS
	: (' '|'\t') {$channel=HIDDEN;}
	;

// PB specific tokens
fragment TAB : '~t';
fragment CR  : '~r';
fragment LF  : '~n';
fragment E_DOUBLE_QUOTE : '~"';
fragment E_QUOTE : '~\''    ;
fragment E_TILDE : '~~'    ;
//TILDE : '~';

fragment DIGIT : '0' .. '9';

NEWLINE
	: '\r\n'
	// PB woodoo some newlines are hidden while others are not
	// each statement ends with a newline but we do not want empty lines to parsed
	{		
		if ( state.tokenStartCharIndex == 0)
		{
			$channel = HIDDEN;
		} else if ( input.substring(state.tokenStartCharIndex - 1,state.tokenStartCharIndex-1).equals("\n")) {			
			$channel = HIDDEN;
		} else {
			int pos = state.tokenStartCharIndex;
			boolean textFound = false;
			// Loop from the rigth to the left
			// Set $channel to HIDDEN unless you find something usefull (non-space, non-comment, non-SEMICOLON
			while(pos-- != 0)
			{
				String c = input.substring(pos, pos);
				String p = input.substring(pos-1, pos-1);	
				if(c.equals("\n"))
					break;
				if(c.equals(";"))
					break;					
				if(p.equals("*") && c.equals("/") && pos >= 4)
				{
				  pos--;
					while(pos-- >= 1)
					{
						c = input.substring(pos, pos);
						p = input.substring(pos-1, pos-1);
						if(p.equals("/") && c.equals("*"))
						{
						  pos--;
						  break;
						}											
					}
					continue;
				}					
				if(!c.equals(" ") && !c.equals("\t"))
				{
					textFound = true;
					break;
				}
			}
			if(!textFound)
			{
				$channel = HIDDEN;
			}			
		}
//			if($channel == HIDDEN)
//			{
//				System.out.println("Empty line at: " + input.getLine());			
//			}					
	}		
	;
	
LINE_CONTINUATION
	: '&' w1=WS*  eol1='\r\n' w2=WS* eol2=('\r\n')?
	{
		if( $eol2 == null)		
			$channel = HIDDEN;
		else
			$type = DELIM;
	//System.out.println("Line continuation at: " + input.getLine()); 
	}
	;
	
EXPORT_HEADER
	:
	'$' 'A' .. 'Z' 
	( options {greedy=false;} : ( 'A' .. 'Z' | DIGIT | '-' | '#' | '%' | '_' ) )* 
	'$' ~('\n'|'\r')* //d='\r\n'
	;

PBSELECT
	: ('PBSELECT' ~('\n'|'\r')*)
	;
	
DATE // 1996-09-26
	: DIGIT DIGIT DIGIT DIGIT '-' DIGIT DIGIT '-' DIGIT DIGIT
	;

TIME // 00:00:00:000000
	: DIGIT DIGIT ':' DIGIT DIGIT ':' DIGIT DIGIT 
	(':'	DIGIT DIGIT DIGIT DIGIT DIGIT DIGIT)?
	;
	
BINDPAR
	: ':' ID_PARTS
	; 
		
TQ : '???';

DOUBLE_PIPE
 	 : '||' // used in Oracle SQL statements (see swallow_to_semi)
 	 ;

AT
   : '@'  // used in Oracle SQL statements (see swallow_to_semi)
   ;
