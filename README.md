This is an implementation of a forth language interpreter for Notch's [DCPU-16 processor](http://pastebin.com/raw.php?i=Q4JvQvnM).

This is based heavily on Richard W.M. Jones' forth implementation for i386 architecture machines. It is can be found here: [Jonesforth](http://git.annexia.org/?p=jonesforth.git;a=summary).

This is a work-in-progress so there may be some rough edges.  Not the least reason for which is the very dynamic nature of the DCPU-16 spec.
Because of this rapidly changing nature I have chosen (for the moment) to implement with a ruby pre-assembler that is run before the assembly step.

Please feel free to comment and/or contribute.

Much of this is what could be called a pre-assembler.  That is I have written my DCPU-16 assembly language in ruby.  This allows me to work through differences in assemblers that may handle macros and defines in different ways.  In looking at the RBS file you will see that it looks very much like DCPU-16 assembly language.

To make things easy when using [DevKit](http://0x10c-devkit.com/) I have created another script that, when run, will convert all the .rbs files in the current directory to .10c files in the destination directory. In addition it will convert any files listed in the `--disk-files` option into .10cdisk files.  All of these files are created in the devkit-dir (specified with the `--devkit-dir` option). Run the command

````
ruby -r ./dcpu devkit -- --devkit-dir=<dest-dir> --rbs-files dcpu.rbs --disk-files bootstrap.f
````

In addition to the `devkit` command there is also a `convert` command which will take an .rbs stdin and output devkit assembly on stdout.  A typical way to run this is:

````
ruby -r ./dcpu -e convert < dcpu.rb > main.10c
````

Finally there is a disk command which will make a devkit floppy out of any file.  it reads stdin and writes to stdout. A typical use is as follows:

````
ruby -r ./dcpu -e disk -- --disk-name bootstrap < bootstrap.f > bootstrap.10cdisk
````

You can get help by typing:

````
ruby -r ./dcpu -e help
````



