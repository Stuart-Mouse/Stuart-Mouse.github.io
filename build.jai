
#load "source/main.jai";

#run {
  Compiler :: #import "Compiler";
  Compiler.set_build_options_dc(.{output_executable_name = "render"});
};

/*

    When we compile, we will want to scan the input directory and iterate over all template files.
    For each file, open and produce a render function for that page.
    
    then i guess we need some way to actually run those rendering functions?
    
    For now I will probably just maintain a static site, so I will probably not have much need to run the render program more than once
    
    
*/



