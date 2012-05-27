: / /MOD SWAP DROP ;

: MOD /MOD DROP ;

: '\n' 17 ;
: BL 32 ;
: CR '\n' EMIT ;
: SPACE BL EMIT ;
: NEGATE 0 SWAP - ;
: TRUE  1 ;
: FALSE 0 ;
: NOT   0= ;

: LITERAL IMMEDIATE
    ' LIT ,                \ compile LIT
    ,                      \ compile the literal itself from the stack
;

: ':'
        [               \ go into immediate mode (temporarily)
        CHAR :          \ push the number 58 (ASCII code of colon) on the parameter stack
        ]               \ go back to compile mode
        LITERAL         \ compile LIT 58 as the definition of ':' word
;

: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

: [COMPILE] IMMEDIATE
    WORD                                \ get the next word
    FIND                                \ find it in the dictionary
    >CFA                                \ get its codeword
    ,                                   \ and compile that
;

: RECURSE IMMEDIATE
    LATEST @  \ LATEST points to the word being compiled at the moment
    >CFA      \ get the codeword
    ,         \ compile it
;

: IF IMMEDIATE
    ' 0BRANCH ,             \ compile 0BRANCH
    HERE @                  \ save location of the offset on the stack
    0 ,                     \ compile a dummy offset
;

: THEN IMMEDIATE
    DUP
    HERE @ SWAP - \ calculate the offset from the address saved on the stack
    SWAP !        \ store the offset in the back-filled location
;

: ELSE IMMEDIATE
    ' BRANCH ,           \ definite branch to just over the false-part
    HERE @               \ save location of the offset on the stack
    0 ,                  \ compile a dummy offset
    SWAP                 \ now back-fill the original (IF) offset
    DUP                  \ same as for THEN word above
    HERE @ SWAP -
    SWAP !
;

: BEGIN IMMEDIATE
    HERE @                              \ save location on the stack
;

: UNTIL IMMEDIATE
    ' 0BRANCH ,                         \ compile 0BRANCH
    HERE @ - \ calculate the offset from the address saved on the stack
    ,        \ compile the offset here
;

: AGAIN IMMEDIATE
    ' BRANCH ,                          \ compile BRANCH
    HERE @ -                            \ calculate the offset back
    ,                                   \ compile the offset here
;

: WHILE IMMEDIATE
    ' 0BRANCH ,            \ compile 0BRANCH
    HERE @                 \ save location of the offset2 on the stack
    0 ,                    \ compile a dummy offset2
;

: REPEAT IMMEDIATE
    ' BRANCH ,                  \ compile BRANCH
    SWAP                        \ get the original offset (from BEGIN)
    HERE @ - ,                  \ and compile it after BRANCH
    DUP
    HERE @ SWAP -          \ calculate the offset2
    SWAP !                 \ and back-fill it in the original location
;

: UNLESS IMMEDIATE
    ' NOT ,                        \ compile NOT (to reverse the test)
    [COMPILE] IF                   \ continue by calling the normal IF
;

: ( IMMEDIATE
    1                \ allowed nested parens by keeping track of depth
    BEGIN
        KEY                             \ read next character
        DUP '(' = IF                    \ open paren?
            DROP                        \ drop the open paren
            1+                          \ depth increases
        ELSE
            ')' = IF                    \ close paren?
                1-                      \ depth decreases
            THEN
        THEN
    DUP 0= UNTIL \ continue until we reach matching close paren, depth 0
    DROP         \ drop the depth counter
;

: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;
: PICK ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
        1+              ( add one because of 'u' on the stack )
        DSP@ +          ( add to the stack pointer )
        @               ( and fetch )
;

: SPACES        ( n -- )
    BEGIN
        DUP 0>          ( while n > 0 )
    WHILE
            SPACE       ( print a space )
            1-          ( until we count down to 0 )
    REPEAT
    DROP
;

: DECIMAL ( -- ) 10 BASE ! ;
: HEX ( -- ) 16 BASE ! ;

: U.            ( u -- )
    BASE @ /MOD     ( width rem quot )
    ?DUP IF                 ( if quotient <> 0 then )
        RECURSE         ( print the quotient )
    THEN

        ( print the remainder )
    DUP 10 < IF
        '0'             ( decimal digits 0..9 )
    ELSE
        10 -            ( hex and beyond digits A..Z )
        'A'
    THEN
    +
    EMIT
;

: .S            ( -- )
    DSP@            ( get current stack pointer )
    BEGIN
        DUP S0 @ <
    WHILE
            DUP @ U.        ( print the stack element )
            SPACE
            1+              ( move up )
    REPEAT
    DROP
;

: UWIDTH        ( u -- width )
    BASE @ /        ( rem quot )
    ?DUP IF         ( if quotient <> 0 then )
        RECURSE 1+      ( return 1+recursive call )
    ELSE
        1               ( return 1 )
    THEN
;

: U.R           ( u width -- )
    SWAP            ( width u )
    DUP             ( width u u )
    UWIDTH          ( width u uwidth )
    ROT             ( u uwidth width )
    SWAP -          ( u width-uwidth )
    ( At this point if the requested width is narrower, we will have a negative number on the stack.
    Otherwise the number on the stack is the number of spaces to print.  But SPACES will not print
    a negative number of spaces anyway, so it is now safe to call SPACES ... )
    SPACES
    ( ... and then call the underlying implementation of U. )
    U.
;

: .R            ( n width -- )
    SWAP            ( width n )
    DUP 0< IF
        NEGATE          ( width u )
        1               ( save a flag to remember that it was negative | width n 1 )
        SWAP            ( width 1 u )
        ROT             ( 1 u width )
        1-              ( 1 u width-1 )
    ELSE
        0               ( width u 0 )
        SWAP            ( width 0 u )
        ROT             ( 0 u width )
    THEN
    SWAP            ( flag width u )
    DUP             ( flag width u u )
    UWIDTH          ( flag width u uwidth )
    ROT             ( flag u uwidth width )
    SWAP -          ( flag u width-uwidth )

    SPACES          ( flag u )
    SWAP            ( u flag )

    IF                      ( was it negative? print the - character )
        '-' EMIT
    THEN

    U.
;

: . 0 .R SPACE ;
: U. U. SPACE ;

( ? fetches the integer at an address and prints it. )
: ? ( addr -- ) @ . ;

: DEPTH         ( -- n )
    S0 @ DSP@ -
    1-                      ( adjust because S0 was on the stack when we pushed DSP )
;

: ? ( addr -- ) @ . ;

: WITHIN
    -ROT            ( b c a )
    OVER            ( b c a c )
    <= IF
        > IF            ( b c -- )
            TRUE
        ELSE
            FALSE
        THEN
    ELSE
        2DROP           ( b c -- )
        FALSE
    THEN
;

: S" IMMEDIATE         ( -- addr len )
    STATE @ IF      ( compiling? )
        ' LITSTRING ,  ( compile LITSTRING )
        HERE @          ( save the address of the length word on the stack )
        0 ,             ( dummy length - we dont know what it is yet )
        BEGIN
            KEY             ( get next character of the string )
            DUP '"' <>
        WHILE
                ,               ( copy character )
        REPEAT
        DROP            ( drop the double quote character at the end )
        DUP             ( get the saved address of the length word )
        HERE @ SWAP -   ( calculate the length )
        1-              ( subtract 4 (because we measured from the start of the length word) )
        SWAP !          ( and back-fill the length location )
    ELSE                    ( immediate mode )
        HERE @          ( get the start address of the temporary space )
        BEGIN
            KEY
            DUP '"' <>
        WHILE
                OVER !          ( save next character )
                1+              ( increment address )
        REPEAT
        DROP            ( drop the final " character )
        HERE @ -        ( calculate the length )
        HERE @          ( push the start address )
        SWAP            ( addr len )
    THEN
;

: ." IMMEDIATE          ( -- )
    STATE @ IF      ( compiling? )
        [COMPILE] S"   ( read the string, and compile LITSTRING, etc. )
        ' TELL ,       ( compile the final TELL )
    ELSE
        ( In immediate mode, just read characters and print them until we get
        to the ending double quote. )
        BEGIN
            KEY
            DUP '"' = IF
                DROP    ( drop the double quote character )
                EXIT    ( return from this function )
            THEN
            EMIT
        AGAIN
    THEN
;

: CONSTANT
    WORD
    CREATE
    DOCOL ,
    ' LIT ,
    ,
    ' EXIT ,
;

: VAR
    WORD CREATE DOCOL ,
    ' LIT ,
    ,
    ' EXIT ,
;

: SETQ
    WORD FIND >DFA 1+

    STATE @ IF              ( compiling? )
        ' LIT ,         ( compile LIT )
        ,               ( compile the address of the value )
        ' ! ,           ( compile +! )
    ELSE                    ( immediate mode )
        !               ( update it straightaway )
    THEN
;

: INCQ
    WORD FIND >DFA 1+

    STATE @ IF              ( compiling? )
        ' LIT ,         ( compile LIT )
        ,               ( compile the address of the value )
        ' +! ,          ( compile +! )
    ELSE                    ( immediate mode )
        +!              ( update it straightaway )
    THEN
;


: ID.
    1+              ( skip over the link pointer )
    DUP @           ( get the flags/length byte )
    F_LENMASK AND   ( mask out the flags - just want the length )

    BEGIN
        DUP 0>          ( length > 0? )
    WHILE
            SWAP 1+         ( addr len -- len addr+1 )
            DUP @           ( len addr -- len addr char | get the next character)
            EMIT            ( len addr char -- len addr | and print it)
            SWAP 1-         ( len addr -- addr len-1    | subtract one from length )
    REPEAT
    2DROP           ( len addr -- )
;

: ?HIDDEN
    1+              ( skip over the link pointer )
    @               ( get the flags/length word )
    F_HIDDEN AND    ( mask the F_HIDDEN flag and return it (as a truth value) )
;
: ?IMMEDIATE
    1+              ( skip over the link pointer )
    @               ( get the flags/length byte )
    F_IMMED AND     ( mask the F_IMMED flag and return it (as a truth value) )
;

: :NONAME
    0 0 CREATE      ( create a word with no name - we need a dictionary header because ; expects it )
    HERE @          ( current HERE value is the address of the codeword, ie. the xt )
    DOCOL ,         ( compile DOCOL (the codeword) )
    ]               ( go into compile mode )
;

: ['] IMMEDIATE
    ' LIT ,                ( compile LIT )
;

: CFA>
    LATEST @        ( start at LATEST dictionary entry )
    BEGIN
        ?DUP            ( while link pointer is not null )
    WHILE
            2DUP SWAP       ( cfa curr curr cfa )
            < IF            ( current dictionary entry < cfa? )
                NIP             ( leave curr dictionary entry on the stack )
                EXIT
            THEN
            @               ( follow link pointer back )
    REPEAT
    DROP            ( restore stack )
    0               ( sorry, nothing found )
;

: FORGET
    WORD FIND       ( find the word, gets the dictionary entry address )
    DUP @ LATEST !  ( set LATEST to point to the previous word )
    HERE !          ( and store HERE with the dictionary address )
;

: CASE IMMEDIATE
    0               ( push 0 to mark the bottom of the stack )
;

: OF IMMEDIATE
    ' OVER ,            ( compile OVER )
    ' = ,               ( compile = )
    [COMPILE] IF        ( compile IF )
    ' DROP ,            ( compile DROP )
;

: ENDOF IMMEDIATE
    [COMPILE] ELSE      ( ENDOF is the same as ELSE )
;

: ENDCASE IMMEDIATE
    ' DROP ,            ( compile DROP )

    ( keep compiling THEN until we get to our zero marker )
    BEGIN
        ?DUP
    WHILE
            [COMPILE] THEN
    REPEAT
;

: EXCEPTION-MARKER
    RDROP               ( drop the original parameter stack pointer )
    0                   ( there was no exception, this is the normal return path )
;

: CATCH    ( xt -- exn? )
    DSP@ 1+ >R          ( save parameter stack pointer, +1 because of xt, on the return stack )
    ' EXCEPTION-MARKER 1+       ( push the address of the RDROP inside EXCEPTION-MARKER ... )
    >R                          ( ... on to the return stack so it acts like a return address )
    EXECUTE                     ( execute the nested function )
;

: THROW         ( n -- )
    ?DUP IF                     ( only act if the exception code <> 0 )
        RSP@                    ( get return stack pointer )
        BEGIN
            DUP R0 1- <         ( RSP < R0 )
        WHILE
                DUP @                   ( get the return stack entry )
                ' EXCEPTION-MARKER 1+ =
                IF                      ( found the EXCEPTION-MARKER on the return stack )
                    1+                  ( skip the EXCEPTION-MARKER on the return stack )
                    RSP!                ( restore the return stack pointer )

                    ( Restore the parameter stack. )
                    DUP DUP DUP         ( reserve some working space so the stack for this word
                                          doesn't coincide with the part of the stack being restored )
                    R>                  ( get the saved parameter stack pointer | n dsp )
                    1-                  ( reserve space on the stack to store n )
                    SWAP OVER           ( dsp n dsp )
                    !                   ( write n on the stack )
                    DSP! EXIT           ( restore the parameter stack pointer, immediately exit )
                THEN
                1+
        REPEAT

        ( No matching catch - print a message and restart the INTERPRETer. )
        DROP

        CASE
            0 1- OF     ( ABORT )
                ." ABORTED" CR
            ENDOF
            ( default case )
            ." UNCAUGHT THROW "
            DUP . CR
        ENDCASE
        QUIT
    THEN
;

: ABORT   ( -- )
    0 1- THROW
;


( Print a stack trace by walking up the return stack. )
: PRINT-STACK-TRACE
    RSP@                        ( start at caller of this function )
    BEGIN
        DUP R0 1- <             ( RSP < R0 )
    WHILE
            DUP @                   ( get the return stack entry )
            CASE
                ' EXCEPTION-MARKER 1+ OF        ( is it the exception stack frame? )
                    ." CATCH ( DSP="
                    1+ DUP @
                    BASE @ SWAP HEX U.     ( print saved stack pointer )
                    BASE !
                    ." ) "
                ENDOF
                ( default case )
                DUP
                CFA>                    ( look up the codeword to get the dictionary entry )
                ?DUP IF                 ( and print it )
                    2DUP                    ( dea addr dea )
                    ID.                     ( print word from dictionary entry )
                    [ CHAR + ] LITERAL EMIT
                    SWAP >DFA 1+ - .        ( print offset )
                THEN
            ENDCASE
            1+                      ( move up the stack )
    REPEAT
    DROP
    CR
;

." Loaded" CR
