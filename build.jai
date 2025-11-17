
#load "source/main.jai";

#run {
    Compiler :: #import "Compiler";
    Compiler.set_build_options_dc(.{output_executable_name = "render"});
};

/*
    Compilation Stages:
        1. Scanning template and content folders
            - currently uses visit_files to collect file names within template and content directories
        2. Generate template body text and header text
        3. Insert headers as jai code
            - In theory we could just use some other format (e.g. json, gon) for the header info.
                - Or even just parse the html properly
                - However, using actual jai code means we can write expressions or refer to things in the comptime site config
                - It also allows us to potentially add page-specific header info by generating unique header structs for each page
            - In the future, we may also put other types of special code blocks in, which can be inserted or run by the metaprogram at this stage.
        4. User code gets access to headers and other special code blocks
        5. final rendering procedures are generated and templates are stored in contant array
    
    What things do we need at runtime?
        Ideally, all templates get stored into a constant array
            maybe in the future they can go in a dynamic array so we can have some main server accept dll's for additional pages without restarting
                but that is a very future concern

    Future: 
        any way we can figure out to make this entire thing a 
        
        
    
    My biggest difficulties with finding a suitable build process are twofold:
        1. needing to pre-compile headers 
            - so that we can use and modify them at compile-time
                - to generate "static data" structures
            - then storing for runtime use
        2. preserving data from compiletime to runtime
            - don't want to repeat work if possible
            - don't want to re-serialize data from structured format back into text if possible
            - certain data is just intermediate stuff that we actually don't want at runtime
            
    The ouptut of each stage of compilation gets inserted as constants so that the next stage can use the data in #insert and #run directives
    
    
*/

