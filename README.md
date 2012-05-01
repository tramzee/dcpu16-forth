This is an implementation of a forth language interpreter for Notch's [DCPU-16 processor](http://pastebin.com/raw.php?i=Q4JvQvnM).

This is based heavily on Richard W.M. Jones' forth implementation for i386 architecture machines. It is can be found here: [Jonesforth](http://git.annexia.org/?p=jonesforth.git;a=summary).

This is a work-in-progress so there may be some rough edges.  Not the least reason for which is the very dynamic nature of the DCPU-16 spec. 
Because of this rapidly changing nature I have chosen (for the moment) to implement with a ruby pre-assembler that is run before the assembly step.

Please feel free to comment and/or contribute.
