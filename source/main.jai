
My_Site :: #insert #run generate_site(.{
    base_directory      = "C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io",
    templates_directory = "templates",
    pages_directory     = "content",
});

main :: () {
    my_site: My_Site;
    context.website = *my_site;
    
    config := load_runtime_config("config.gon");
    init(*my_site, config);
    
    // template_ids := collect_files_with_extension(*my_site.DIRECTORY, null, "tt");
    
    render_all_pages(*my_site);
}

load_runtime_config :: (path: string) -> Runtime_Config {
    using GON;
    
    config: Runtime_Config;
    
    file, ok := read_entire_file(path);
    if !ok { log("Error: failed to read_entire_file in load_runtime_config."); exit(1); }
    
    model: Data_Model;
    init_data_model(*model);
    defer deinit_data_model(*model);
    
    model.language = JSON_get_language(.{
        json_flags = .DEFAULT_GON_FLAGS, 
        skip_whitespace = GON.skip_whitespace_and_hashtag_comments
    });
    
    ok = parse_file(*model, file, path);
    if !ok { log("Error: failed to parse_file in load_runtime_config."); exit(1); }
    
    ok = add_data_binding(*model, config, "config");
    if !ok { log("Error: failed to add_data_binding in load_runtime_config."); exit(1); }
    
    ok = process_data_bindings(*model);
    if !ok { log("Error: failed to process_data_bindings in load_runtime_config."); exit(1); }
    
    config.working_directory = get_working_directory();
    
    return config;
}

// get_template :: (path: string) -> *Template {
    
// }

/*
    have to think about lifetimes in templates
    local variables / parameters
    local static data
        this is the trick one! not sure how to do this?
        maybe we wait until typechecked all we can with metaprogram, then look over all templates that want to have static data and just generate a big "Static_Data" struct.
        static data could be either a big global or we could put a pointer to it in context and init for each thread, kinda like temp storage
    constant data
        source path
        name?
    
    Could we put an init block in templates that will run or add code into context/static globals?
    
    Templates as Macros?
    Would allow calling some other template to insert variables into calling template's scope.
    Would require not using the indirection of call-template, so the template would have to be exported to some real procedure
        need to figure out scoping rules for that
    
    URL parameters can go into context so that they are easily available across template calls
        same goes for other request data
    
    
    TODO: WASM integration
            WASM content should probably get its own folder, separate from regular site content
                wasm stuff is more folder-based rather than file-based
                wasm stuff only needs to be rebuilt when individual wasm projects are changed (duh)
                    *some* wasm stuff could be generated from contents of website, or templates could potentially contain their own wasm functions that get built into a wasm binary.
                        or we just have a general wasm_utils module that contains al the wasm functions we want to be able to call site-wide.
        
    TODO: CSS generation in templates
            could have some way to generate styles such that they get appended to a global .css builder string in the same way that html gets built.
            On the other hand, maybe it's better just to inline the styles or put them directly on the generated content.
            Even if we are just putting the style in some inline <style> tag, we should have a mechanism to generate the style names in such a manner that they will not produce name conflicts.
        
    TODO: add option to PWA plugin to turn off the input event prevention 
            this is not really relevant to the templater but is relevant to the site so whatever
    
    
    TODO: think about whether we have any real practical use cases for precompiled headers atm, we may be able to actually remove this whole step...
            it is slightly nice that we can just use standard jai syntax to declare any data that needs to go into the header, but at the same time, it adds complication to compilation
            maybe static variables or thread-locals for pages will be a good test case for the utility of precompiled headers
    
    
    
    TODO:
    [ ] generate unique structs for each template
        [ ] store them in template/page arrays by pointer
        [ ] add thread locals to template structs
    [ ] create site struct based on directory structure
        [x] generate directory structure
        [ ] copy directory, insert template ids into directory entries
    
    
    
    
    
    
    this may be a better approach than generating a complex site struct
    
    render :: ($path: string, args: ..Code) {
        resolve template being referenced
        insert call to template.render(..args), basicalyy
        inserting args properly may prove problematic
    }
    
    get_template("templates/image_grid").render(..parameters);
    
*/


#scope_module

#import "Basic";
// #import "Math";
// #import "Random";
#import "File";
// #import "File_Utilities";
// #import "String";

using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";
using Compiler :: #import "Compiler";
// Program_Print :: #import "Program_Print";

#import "Utils";
GON :: #import "GON"()(string.["JSON"]);
// Convert :: #import "Convert";

#import "Site_Generator";

// HTTP_Server :: #import "Http_Server_caztanj";


/*
    TODO: need to think about what exactly we will want as an interface for navigating the site's directories and files.
    
    We should create a directory entry base type which maintains a handle to the parent directory (probably just offset in bytes from site struct base pointer)
    we should be able to move up or down the directory tree very easily
    we will also want some automated way to evalate relative paths between directory entries so that users can reference resources using standard file paths.
        insofar as it is possibel to do so, we should evaluate these links at compile time and validate them
    
    we will also want to introduce some means of handling dynamic resources.
    perhaps this will mean putting out a file watcher over the whole site public directory and maintaining file lists for each directory in the site struct.
    maybe we don't need this in all cases though, and it should probabyl be configurable how this sort of thing would behave
    
*/

// Walk_Site_Control_Code :: enum {
//     ERROR :: -1;
//     OK    ::  0;
//     SKIP_DIRECTORY :: 1;
// }

// entry_member_info:          *Type_Info_Struct_Member;
// entry_value_pointer:        *void;
// member_dereference_code:    *Code_Node;

// // TODO: should do a version that just fully expands at compile-time rather than walking the type info at runtime.
// walk_site :: (site: *$Site_Type, ) -> bool
// #modify {
//     return is_subclass_of(xx Site_Type, "Site_Base"), "Site_Type must contain `using #as Site_Base` as its first member.";
// } {
//     #insert -> Code {
//         code_template := #code {
            
//         };
        
//         builder: Code_Builder;
//         defer deinit(*buidler);
        
//         begin_block(*builder, .IMPERATIVE);
        
//         site_info :: type_info(Site_Type);
//         for site_info.members {
//             if it.flags & (.CONSTANT | .OVERLAY)  continue;
//             if it.name != site.BUILD_CONFIG.pages_directory  continue;
            
            
            
//             generate_code_for_member(*builder, it, it.offset_in_bytes);
//         }
        
//         block := end_block(*builder);
//         return block;
//     }
// }

// walk_site_directory :: (site: *$Directory_Type, ) -> bool
// #modify {
//     return is_subclass_of(xx Directory_Type, "Directory"), "Directory_Type must contain `using #as Directory` as its first member.";
// } {
//     #insert -> Code {
//         code_template := #code {
            
//         };
        
//         builder: Code_Builder;
//         defere deinit(*buidler);
        
//         begin_block(*builder, .IMPERATIVE);
        
//         site_info :: type_info(Site_Type);
//         for site_info.members {
//             if it.flags & (.CONSTANT | .OVERLAY)  continue;
//             if it.name != site.BUILD_CONFIG.pages_directory  continue;
//             generate_code_for_member(*builder, it, it.offset_in_bytes);
//         }
        
//         block := end_block(*builder);
//         return block;
//     }
// }




