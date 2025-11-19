
#module_parameters (
    TEMPLATES_DIRECTORY     := "templates",
    PAGES_DIRECTORY         := "content",
    CONTEXT_MEMBER_NAME     := "site_generator",
    TEMPLATE_FILE_EXTENSION := "tt"
);

// TODO: maybe we don't need to even put this in the context if we can just sneak it up as a first parameter to all render procs
// #insert #run tprint("#add_context %: *Site;", CONTEXT_MEMBER_NAME);
// #add_context site_generator: *Site;

Template_Parameter :: struct {
    name:   string;
    value:  Any;
}

Template_Nonpoly :: struct {
    using header:       *Template_Header;
    render:             *void;
    render_proc_type:   Type;
    // render_proc_info:   *Procedure_Info;
    statics:            Any;
}

Template :: struct(
    header:             Template_Header, 
    render:             $Render_Proc_Type, 
    // render_proc_info:   Procedure_Info, 
    Statics:            Type
) {
    statics: Statics;
}

get_nonpoly :: (template: *Template) -> Template_Nonpoly {
    return .{
        header           = *template.header,
        render           = xx template.render,
        render_proc_type = template.Render_Proc_Type,
        // render_proc_info = *template.render_proc_info,
        statics          = template.statics, // NOTE: implicit cast to Any
    };
}

// This is a bit silly, but this is the only practical way to insert the textual header stuff at the moment
compile_header :: ($raw_template: Raw_Template) -> Template_Header {
    #insert -> string {
        builder: String_Builder;
        
        append(*builder, "return .{");
        print (*builder, "source_path = \"%\",", raw_template.source_path);
        print (*builder, "output_file_extension = \"%\",", raw_template.output_file_extension);
        print (*builder, get_named_block(raw_template, "HEADER"));
        append(*builder, "};");
        
        return builder_to_string(*builder);
    }
}

generate_template_struct :: ($source_path: string) -> Type #compile_time {
    source_text, file_ok :: #run read_entire_file(source_path);
    #assert(file_ok);
    
    raw_template :: #run process_template_file(source_text, source_path);
    
    header :: #run compile_header(raw_template);
    
    render_proc_string :: #run generate_template_render_proc(raw_template, header);
    // render_proc_info   :: #run get_procedure_info(Compiler.compiler_get_nodes(render_proc_string));
    
    // this may not work if compiler typechecks render proc wrt this scope due to insert
    // my hope is that using the scope of the enclosing Site will allow the procedure to resolve properly
    render_proc        :: #insert render_proc_string; 
    
    Statics :: struct { #insert #run get_named_block(raw_template, "STATICS"); }
    
    return Template(header, render_proc, Statics);
}

Template_Header :: struct {
    source_path:                string;     // relative to working directory at comptime
    output_file_extension:      string;
    export_name:                string;
    notes:                      [] string;
    tags:                       [] string;
}

Template_Call :: struct {
    template:       *Template_Nonpoly;
    parameters:     [] Template_Parameter;
}

/*
    Once we set up HTTP Server, this will be used to determine whether we just serve 
        a statically-generated page or generate the content on a per-request basis.
    We may also add some system later to just periodically or manually re-render static pages.
*/
// Page_Type :: enum {
//     STATIC;
//     DYNAMIC;
// }



#scope_module

// ===== STEP 1: Raw Templates =====

Template_Generation_Helpers :: struct {
    write_var  :: inline (var: $T) { 
        // #insert #run tprint(#string JAI 
        // print(context.%.html_builder, "%%", var); 
        // JAI, CONTEXT_MEMBER_NAME);
        print(site.html_builder, "%", var); 
    }
    write_html :: inline (html: string) { 
        // TODO: prevent appending totally empty lines
        // #insert #run tprint(#string JAI 
        // append(context.%.html_builder, remove_trailing_newline(html)); 
        // JAI, CONTEXT_MEMBER_NAME);
        append(site.html_builder, remove_trailing_newline(html)); 
    }
    remove_trailing_newline :: inline (s: string) -> string { 
        return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; 
    }
}

// TODO: can probably slim this down or remove it altogether now that we arte just compiling templates one-by-one
Raw_Template :: struct {
    source_path:    string;
    source_text:    string;
    
    output_file_extension:        string;     // relative to working directory
    
    append_content  := default_append_content;
    append_variable := default_append_variable;
    
    preamble, postamble: string;
    
    tokens: [] Token;
    Token :: struct {
        Kind :: enum { CONTENT; CODE; VARIABLE; };
        
        kind: Kind;
        start, count: int;
    }
    
    named_blocks: [] Named_Block;
    Named_Block ::  struct { name: string; text: string; };
}

get_named_block :: (template: Raw_Template, name: string) -> text: string #compile_time {
    for template.named_blocks  if it.name == name  return it.text; 
    return "";
}

process_templates :: (paths: [] string) -> [] Raw_Template #compile_time {
    templates := NewArray(paths.count, Raw_Template); // @Leak
    for path: paths {
        source, ok := read_entire_file(path);
        assert(ok, "Unable to load file at path '%'", path);
        
        log("processing template: %", path);
        templates[it_index] = process_template(source, path);
    }
    return templates;
}


default_append_content :: (builder: *String_Builder, content: string) {
    if !trim(content)  return;
    print(builder, "write_html(#string __HTML\n%\n__HTML);\n", content);
}

default_append_variable :: (builder: *String_Builder, content: string) {
    if !trim(content)  return;
    print(builder, "write_var(%);\n", content);
}

process_markdown :: (builder: *String_Builder, content: string) -> int {
    process_output :: (
        chunk: *MD_CHAR,
        chunk_size: MD_SIZE,
        userdata: *void
    ) #c_call {
        using data := userdata.(*String_Builder_And_Context);
        push_context ctx {
            append(builder, string.{ chunk_size, chunk });
        }
    }
    
    sb_and_ctx := String_Builder_And_Context.{ builder, *context };
    return md_html(content.data, xx content.count, process_output, *sb_and_ctx, 0, 0);
}

markdown_append_content :: (builder: *String_Builder, content: string) {
    append(builder, "write_html(#string __HTML\n");
    assert(process_markdown(builder, content) == 0, "Error: failed while trying to process markdown.");
    append(builder, "\n__HTML);\n");
}

String_Builder_And_Context :: struct {
    builder: *String_Builder;
    ctx:     *#Context;
}

default_markdown_preamble :: #string __JAI
markdown_preamble();
__JAI;

default_markdown_postamble :: #string __JAI
markdown_postamble();
__JAI;



process_template_file :: (source: string, path: string) -> Raw_Template #compile_time {
    template := Raw_Template.{ 
        source_path     = path, 
        source_text     = source, 
        append_content  = default_append_content,
        append_variable = default_append_variable,
        output_file_extension = "html",
    };
    
    if path_extension(basename(path)) == "md" {
        template.append_content = markdown_append_content;
        template.preamble       = default_markdown_preamble;
        template.postamble      = default_markdown_postamble;
    }
    
    named_blocks: [..] Raw_Template.Named_Block;
    tokens:       [..] Raw_Template.Token;
    
    in_code := false;
    current_string := string.{ 0, source.data };
    
    // make a copy so we have the original data pointer
    // I use this to determine the start offset for tokens, since I don't want to track index manually
    source_begin := source.data;
    
    record_token :: (kind: Raw_Template.Token.Kind, s: string) #expand {
        array_add(*tokens, .{ kind = kind, start = s.data - source_begin, count = s.count });
    }
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<??") {
                if current_string.count > 0 {
                    record_token(.CONTENT, current_string);
                }
                advance(*source, 3);
                source = eat_spaces(source);
                
                // TODO: better criteria on what is a valid identifier?
                current_string = .{ 0, source.data };
                while source && (is_alnum(source[0]) || source[0] == "_") {
                    advance(*source);
                    current_string.count += 1;
                }
                name := current_string;
                if !name  assert(false, "Invalid name for insert block in template: %", path);
                
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "?>") {
                    if !source  assert(false, "Unexpected EOF in insert block in template: %", path);
                    current_string.count += 1;
                    advance(*source, 1);
                }
                array_add(*named_blocks, .{ name, current_string });
                advance(*source, 2);
                
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "<?") {
                if current_string.count > 0 {
                    record_token(.CONTENT, current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    record_token(.CONTENT, current_string);
                }
                advance(*source, 2);
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "}}") {
                    advance(*source, 1);
                    current_string.count += 1;
                }
                advance(*source, 2);
                if current_string.count > 0 {
                    record_token(.VARIABLE, current_string);
                }
                current_string = .{ 0, source.data };
                continue loop;
            }
        }
        else if begins_with(source, "?>") {
            if current_string.count > 0 {
                record_token(.CODE, current_string);
            }
            in_code = false;
            advance(*source, 2);
            current_string = .{ 0, source.data };
            continue loop;
        }
        
        advance(*source, 1);
        current_string.count += 1;
    }
    
    // write final string
    if in_code  assert(false, "Unexpected EOF in code segment in template: %", path);
    if current_string.count > 0 {
        record_token(.CONTENT, current_string);
    }
    
    template.named_blocks = xx named_blocks;
    template.tokens       = xx tokens;
    return template;
}

// ===== STEP 3: Generate Final Rendering Procedures =====

generate_template_render_proc :: (raw_template: Raw_Template, header: Template_Header) -> string #compile_time {
    builder: String_Builder;
    
    parameters := get_named_block(raw_template, "PARAMETERS");
    print (*builder, "(%) -> bool {\n", parameters);
    
    // append(*builder, "using context.%;\n", CONTEXT_MEMBER_NAME);
    append(*builder, "using site;\n");
    append(*builder, "using Template_Generation_Helpers;\n");
    append(*builder, "using Template_Runtime_Helpers;\n");
    
    append(*builder, raw_template.preamble);
    
    for raw_template.tokens {
        if it.kind == {
          case .CODE;
            append(*builder, slice(raw_template.source_text, it.start, it.count));
            
          case .CONTENT;
            raw_template.append_content(*builder, slice(raw_template.source_text, it.start, it.count));
            
          case .VARIABLE;
            raw_template.append_variable(*builder, slice(raw_template.source_text, it.start, it.count));
        }
    }
    
    append(*builder, raw_template.postamble);
    
    append(*builder, "return true;\n}");
    
    return builder_to_string(*builder);
}





// ===== Runtime Helpers =====


get_base_path :: () -> string {
    using site;
    return ifx runtime_config.local_deployment then runtime_config.working_directory else runtime_config.output_directory;
}

// to be called form within template rendering procs, to adjust links for local deployment if need be
local_path :: (relative_path: string) -> string {
    // need to create some proc to get relative path from one page to another
    // or, we could use absolute paths within site
    // Frankly, we shouldn't have this issue in the first place except that we are using github pages to host all this crap instead of a real hosting service
    
    path := join(get_base_path(), relative_path, separator="/",, temp);
    return path;
}

get_template_by_name :: (name: string) -> *Template {
    for *get_templates(*site) {
        if it.export_name == name {
            return it;
        }
    }
    return null;
}

call_template :: (name: string, parameters: ..Template_Parameter) -> bool {
    template := get_template_by_name(name);
    if template == null { 
        log("Error: Unable to find template: %", name);  
        return false; 
    }
    return call_template(.{ template, parameters });
}

call_template :: (using template_call: Template_Call) -> bool {
    args := NewArray(parameters.count, Any,, temp);
    for parameters  args[it_index] = it.value;
    
    result := false;
    if !try_calling_procedure_with_wrapper(xx template.render_proc_type, xx template.render, args, .[ result ]) || !result {
        log("Error: Failed while trying to render template: %", template.source_path);
        return false;
    }
    return true;
}

// TODO: make_template_call :: (code: Code) -> Template_Call 
//       takes the code for the procedure call and automatically generates a Template_Call using the current values for each thing passed

// make_template_call :: (code: Code) -> Template_Call {
//     #insert -> string {
//         root := Compiler.compiler_get_nodes(code).(*Code_Procedure_Call);
//         assert(root.kind == .PROCEDURE_CALL);
        
//         // determine exaclty which procedure overload would be called in this procedure call
//         // collect 
//     }
    
// }

Template_Runtime_Helpers :: struct {
    // shorthand for call_template to make life easier, also uses backticked return to invisibly propogate errors
    call :: (name: string, parameters: ..Template_Parameter) #expand {
        if !call_template(name, ..parameters) `return false;
    }
    
    // primarily intended for use in nesting templates
    // a Template_Call can be passed to a template as a sort of callback proc
    // so that one can have some broad structural templates and then embed content within that
    call :: (using template_call: Template_Call) #expand {
        // by default, just don't try to call if name is empty
        if name && !call_template(name, ..parameters) `return false;
    }
    
    #if 0 {
    
    // to be used only within template/page rendering procs. should namespace with other such procedures kind of like Template_Generation_Helpers
    get_url_parameter :: ($name: string, $T: Type) -> T #expand {
        for context.url_parameters {
            if it.name == name {
                value: T;
                if !Convert.set_value_from_string(value, src)  `return false;
                return value;
            }
        }
        `return false;
    }
    
    }
}

push_site_to_context :: (site: *Site_Base) #expand {
    // site_generator_before := context.site_generator;
    // context.site_generator = site;
    // `defer context.site_generator = site_generator_before;
}


/*
    Site Directory
    
    I would like to build a site directory at compile-time which is a sort of constant file-tree that represents the site's contents
    we will already be mirroring the file structure in the struct layout itself, 
    but I would prefer to have a separate user-navigable structure apart from type info
    
    In theory we could also use some sort of dynamic directory structure to allow for site pages to be loaded from some dll and inserted into the site at runtime
*/

// Directory_Builder :: struct {
//     entry: [..] Entry;
//     current_folder: int;
// }

// Directory :: {
//     entries: [] Directory_Entry;
// }

// Directory_Entry :: struct {
//     Kind :: enum { FILE; FOLDER; };
//     kind: Kind;
//     name: string;
    
//     folder: struct {
//         contents_index: int;
//         contents_count: int;
//     }
    
//     // template: *Template_Nonpoly;
// }

// build_directory :: (base_path: string) -> Directory {
//     builder: Directory_Builder;
//     directory.entries.allocator = temp;
//     array_add(directory.nodes)
    
//     // TODO: will need to manually get all file descriptors in each directory, append nodes for all files/folders at the level,
//     // and then iterate over each element and recurse for it if it is also a folder
//     // this way, all folder contents should be contiguous in memory, meaning we can just use an index and count
    
    
//     return Directory.{ entries = array_copy() };
// }


collect_file_paths :: (base_path: string) -> [] string {
    paths: [..] string;
    visit_files(base_path, true, *paths, (info: *File_Visit_Info, paths: *[..] string) {
        if path_extension(info.full_name) == TEMPLATE_FILE_EXTENSION {
            array_add(paths, info.full_name);
        }
    });
    return paths;
}

get_page_output_path :: (site: *Site_Base, page: Template_Nonpoly) -> string {
    build_config := get_build_config(site);
    
    relative_path := page.header.source_path;
    assert(begins_with(relative_path, build_config.PAGES_DIRECTORY));
    advance(*relative_path, build_config.PAGES_DIRECTORY.count);
    while relative_path && is_any(relative_path[0], "\\/") {
        advance(*relative_path);
    }
    
    output_path := relative_path;
    assert(ends_with(output_path, TEMPLATE_FILE_EXTENSION));
    output_path = path_strip_extension(output_path); // strip template extension
    output_path = path_strip_extension(output_path); // then strip normal file extension
    
    if site.runtime_config.output_directory {
        output_path = join(site.runtime_config.output_directory, output_path, separator="/",, temp);
    }
    
    return join(output_path, page.header.output_file_extension, separator = ".",, temp);;
}


#scope_export



// ===== Configuration =====

// Build_Config :: struct {
//     TEMPLATES_DIRECTORY     := "templates";
//     PAGES_DIRECTORY         := "content";
//     CONTEXT_MEMBER_NAME     := "site_generator";
//     TEMPLATE_FILE_EXTENSION := "tt";
// }

Runtime_Config :: struct {
    working_directory:  string;
    output_directory:   string;
    navbar_items:       [] Navbar_Item;
    local_deployment:   bool;
}

Navbar_Item :: struct { name: string; path: string; };


// TODO: we need to make site base contain some header containing info about the Site that was generated.
Site_Base :: struct {
    // type:               Type;           // Site.init will set this to #this of generated Site
    runtime_config:     Runtime_Config;
    // __build_config:     *Build_Config;  // NOTE: do not ever write over this! points into constant storage
    html_builder:       *String_Builder;
}

// get_build_config :: (site: *Site_Base) -> *Build_Config {
//     return site.__build_config;
// }

// NOTE: getter procs are because I am actually quite likely to change how sites or templates are stored internally
get_templates :: (site: *Site) -> [] Template_Nonpoly {
    templates_info :: type_info(Templates);
    templates: [#run templates_info.members.count] Template_Nonpoly;
    #insert -> string {
        templates_info :: type_info(Templates);
        builder: String_Builder;
        for templates_info.members {
            print(*builder, "templates[%] = get_nonpoly(*site.templates.%);\n", it_index, it.name);
        }
        return builder_to_string(*builder);
    }
    return array_copy(templates); // TODO
}

get_pages :: (site: *Site) -> [] Template_Nonpoly {
    templates_info :: type_info(Pages);
    templates: [#run templates_info.members.count] Template_Nonpoly;
    #insert -> string {
        templates_info :: type_info(Pages);
        builder: String_Builder;
        for templates_info.members {
            print(*builder, "templates[%] = get_nonpoly(*site.pages.%);\n", it_index, it.name);
        }
        return builder_to_string(*builder);
    }
    return array_copy(templates); // TODO
}

render_all_pages :: (site: *Site) {
    // push_site_to_context(site);
    
    for *page: get_pages(site) {
        output_path := get_page_output_path(site, page);
        output_dir  := path_strip_filename(output_path);
        if output_dir {
            make_directory_if_it_does_not_exist(output_dir, recursive = true);
        }
        
        log("Rendering page '%' to '%'", page.source_path, output_path);
        builder: String_Builder;
        
        if !call_template(.{ template = page }) {
            log("Failed while trying to render page: %", output_path);
            exit(1);
        }
        write_entire_file(output_path, builder_to_string(*builder));
    }
}


#insert #run generate_templates("Templates", TEMPLATES_DIRECTORY);
#insert #run generate_templates("Pages",     PAGES_DIRECTORY);

generate_templates :: (name: string, path: string, _using := false) -> string #compile_time {
    template_paths := collect_file_paths(path);
    
    builder: String_Builder;
    
    print(*builder, "% :: struct {\n", name);
    for template_paths {
        print(*builder, "    _%1: #run,stallable generate_template_struct(\"%2\");\n", it_index, it);
    }
    append(*builder, "}");
    
    return builder_to_string(*builder);
}

site: Site;

Site :: struct {
    using #as site_base: Site_Base;
    
    templates:  Templates;
    pages:      Pages;
    
    #insert -> string {
        log("generating export aliases for template render procs");
        
        builder: String_Builder;
        for type_info(Templates).members {
            template_info := it.type.(*Type_Info_Struct);
            
            // TODO: create helpers in utils for get_parameter and get_specified_parameter, and variant where we can assert then type and get concrete result 
            // we have to locate the headers manually through reflection here, this is really dumb
            header: *Template_Header;
            for param: template_info.specified_parameters {
                if param.name == "header" {
                    header = (*template_info.constant_storage[param.offset_into_constant_storage]).(*Template_Header);
                }
            }
            if !header {continue; log("no export_name defined for template %", it_index);}
            
            if header.export_name {
                print(*builder, "% :: Templates._%.render;\n", header.export_name, it_index);
                log("% :: Templates._%.render));", header.export_name, it_index);
            }
        }
        return builder_to_string(*builder);
    };
}

init :: (site: *Site, runtime_config: Runtime_Config) {
    site.__build_config = *site.BUILD_CONFIG;
    site.type = type_of(site);
    
    site.runtime_config = runtime_config;
    
    #insert -> string {
        builder: String_Builder;
        // TODO: should probably deduplicate calls here so that we only call once per unique proc type
        for type_info(Templates).members {
            print(*builder, "register_procedure_type_for_dynamic_call(type_of(Templates.%.render));\n", it.name);
        }
        for type_info(Pages).members {
            print(*builder, "register_procedure_type_for_dynamic_call(type_of(Pages.%.render));\n", it.name);
        }
        return builder_to_string(*builder);
    }
}

#scope_module

#import "Basic";
#import "Math";
#import "Random";
#import "File";
#import "File_Utilities";
#import "String";
using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";
Compiler :: #import "Compiler";

#import "Utils";
Convert :: #import "Convert";
#import "md4c";


/*

#import "Basic";
#import "File";
#import "GON";

#import "Site_Generator"(
    TEMPLATES_DIRECTORY = "../templates",
    PAGES_DIRECTORY     = "../content",
);

main :: () {
    config := load_runtime_config("config.gon");
    
    init(*site, config);
    render_all_pages(*site);
}


load_runtime_config :: (path: string) -> Runtime_Config {
    config: Runtime_Config;
    
    file, ok := read_entire_file(path);     assert(ok);
    parser:, ok = parse_file(file);         assert(ok);
    
    add_data_binding(*parser, config, "config");
    
    ok = process_data_bindings(*parser);            assert(ok);
    
    config.working_directory = get_working_directory();
    
    return config;
}

*/