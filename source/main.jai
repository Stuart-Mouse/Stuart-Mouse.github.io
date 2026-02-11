
TEMPLATE_FILE_EXTENSION :: "tt";

Template_Parameter :: struct {
    name:   string;
    value:  Any;
}

Template :: struct {
    using header:           *Template_Header;
    
    render_proc_pointer:    *void;
    render_proc_info:       *Procedure_Info;
    
    // thread_locals_type:     Type;
}

Template_Header :: struct {
    id:                         u64;
    source_path:                string;     // relative to working directory at comptime
    output_file_extension:      string;
    export_name:                string;
    notes:                      [] string;
    tags:                       [] string;
    
    procedure_header_code:      Code;
    
    directory_entry_id:         Directory.Entry.ID;
}

// Template_Call :: struct {
//     template:       *Template;
//     parameters:     [] Template_Parameter;
// }

/*
    Once we set up HTTP Server, this will be used to determine whether we just serve 
        a statically-generated page or generate the content on a per-request basis.
    We may also add some system later to just periodically or manually re-render static pages.
*/
// Page_Type :: enum {
//     STATIC;
//     DYNAMIC;
// }


// ===== STEP 1: Raw Templates =====

Template_Generation_Helpers :: struct {
    write_var  :: inline (var: $T) { 
        print(*context.website.__html_builder, "%", var); 
    }
    write_html :: inline (html: string) { 
        // TODO: prevent appending totally empty lines
        append(*context.website.__html_builder, remove_trailing_newline(html)); 
    }
    remove_trailing_newline :: inline (s: string) -> string { 
        return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; 
    }
}

Raw_Template :: struct {
    name:           string;
    source_path:    string;
    source_text:    string;
    
    directory_entry_id: Directory.Entry.ID;
    
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


process_templates :: (directory: *Directory) -> [] Raw_Template #compile_time {
    entries := collect_files_with_extension(directory, null, "tt");
    
    templates := NewArray(entries.count, Raw_Template); // @Leak?
    for entry: entries {
        log("processing template: %", entry.path);
        
        source, ok := read_entire_file(entry.path);
        assert(ok, "Unable to load file at path '%'. entry.name is %", entry.path, entry.name); 
        
        templates[it_index] = process_template(source, entry.path);
        templates[it_index].directory_entry_id = entry.id;
    }
    return templates;
}

#scope_module

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
templates.markdown_preamble.render();
__JAI;

default_markdown_postamble :: #string __JAI
templates.markdown_postamble.render();
__JAI;


#scope_export

process_template :: (source: string, path: string) -> Raw_Template #compile_time {
    template := Raw_Template.{ 
        name            = actual_basename(path),
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

// ===== STEP 2: Compile Headers =====

get_named_block :: (template: Raw_Template, name: string) -> text: string #compile_time {
    for template.named_blocks  if it.name == name  return it.text; 
    return "";
}

compile_headers :: ($templates: [] Raw_Template) -> [] Template_Header #compile_time {
    #insert -> string {
        builder: String_Builder;
        
        print(*builder, "headers: [%] Template_Header;\n", templates.count);
        for templates {
            header_text := get_named_block(it, "HEADER");
            path := copy_string(it.source_path,, temp);
            path_overwrite_separators(path, "/");
            
            parameters := get_named_block(it, "PARAMETERS");
            
            print(*builder, #string JAI
            headers[%1] = .{
                id = %2,
                source_path = "%3",
                output_file_extension = "%4",
                directory_entry_id = %6,
                procedure_header_code = (#code (%7) -> bool),
                %5
            };
            JAI, it_index, it_index, path, it.output_file_extension, header_text, it.directory_entry_id, parameters);
        }
        append(*builder, "return headers;");
        
        return builder_to_string(*builder);
    }
}

// ===== STEP 3: Generate Final Rendering Procedures =====

/*
    TODO: generate these rendering procs as code nodes.
    this will require that we actually build the entire site struct as code nodes as well...
*/
generate_template_render_proc :: (builder: *String_Builder, raw_template: Raw_Template, header: Template_Header) #compile_time {
    parameters := get_named_block(raw_template, "PARAMETERS");
    // TODO: if parameters has a trailing comma, we should just remove it as a convenience to the user
    
    // sb: String_Builder;
    // PP.print_expression(*sb, Compiler.compiler_get_nodes(header.procedure_header_code));
    // log("parameters: %", builder_to_string(*sb));
    
    
    print (builder, "(%) -> bool {\n", parameters);
    
    append(builder, "using Template_Generation_Helpers;\n");
    append(builder, "using Template_Runtime_Helpers;\n");
    append(builder, "using context.website.(*__SITE_TYPE);\n");
    
    // if get_named_block(raw_template, "THREAD_LOCALS") {
    //     print(builder, "using context.site_thread_locals.__template_%;", header.id);
    // }
    
    append(builder, raw_template.preamble);
    
    for raw_template.tokens {
        if it.kind == {
          case .CODE;
            append(builder, slice(raw_template.source_text, it.start, it.count));
            
          case .CONTENT;
            raw_template.append_content(builder, slice(raw_template.source_text, it.start, it.count));
            
          case .VARIABLE;
            raw_template.append_variable(builder, slice(raw_template.source_text, it.start, it.count));
        }
    }
    
    append(builder, raw_template.postamble);
    
    append(builder, "return true;\n}");
}





// ===== Configuration =====


Build_Config :: struct {
    base_directory:     string;
    templates_directory := "templates";
    pages_directory     := "content";
}

Runtime_Config :: struct {
    working_directory:  string;
    output_directory:   string;
    navbar_items:       [] Navbar_Item;
    local_deployment:   bool;
}

Navbar_Item :: struct { name: string; path: string; };



// ===== Runtime Stuff =====

get_base_path :: () -> string {
    config := *context.website.__runtime_config;
    return ifx config.local_deployment then config.working_directory else config.output_directory;
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
    // for *get_templates(context.website) {
    //     if it.export_name == name {
    //         return it;
    //     }
    // }
    return null;
}

call_template :: (name: string, parameters: ..Template_Parameter) -> bool {
    template := get_template_by_name(name);
    if template == null { 
        log("Error: Unable to find template: %", name);  
        return false; 
    }
    return call_template(template, ..parameters);
}

call_template :: (template: *Template, parameters: ..Template_Parameter) -> bool {
    args := NewArray(parameters.count, Any,, temp);
    for parameters  args[it_index] = it.value;
    
    result := false;
    if !template.render_proc_info.call_wrapper(xx template.render_proc_pointer, args, .[ result ]) || !result {
        log("Error: Failed while trying to render template: %", template.source_path);
        return false;
    }
    return true;
}

Template_Runtime_Helpers :: struct {
    // shorthand for call_template to make life easier, also uses backticked return to invisibly propogate errors
    call :: (name: string, parameters: ..Template_Parameter) #expand {
        if !call_template(name, ..parameters) `return false;
    }
    
    // primarily intended for use in nesting templates
    // a Template_Call can be passed to a template as a sort of callback proc
    // so that one can have some broad structural templates and then embed content within that
    // call :: (using template_call: Template_Call) #expand {
    //     // by default, just don't try to call if name is empty
    //     if name && !call_template(name, ..parameters) `return false;
    // }
    
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

collect_file_paths :: (base_path: string) -> [] string {
    paths: [..] string;
    visit_files(base_path, true, *paths, (info: *File_Visit_Info, paths: *[..] string) {
        if path_extension(info.full_name) == TEMPLATE_FILE_EXTENSION {
            array_add(paths, info.full_name);
        }
    });
    return paths;
}

get_page_output_path :: (site: *Site, page: Template) -> string {
    content_base_path := site.__build_config.pages_directory;
    
    relative_path := page.source_path;
    assert(begins_with(relative_path, content_base_path));
    advance(*relative_path, content_base_path.count);
    while relative_path && is_any(relative_path[0], "\\/") {
        advance(*relative_path);
    }
    
    output_path := relative_path;
    assert(ends_with(output_path, TEMPLATE_FILE_EXTENSION));
    output_path = path_strip_extension(output_path); // strip template extension
    output_path = path_strip_extension(output_path); // then strip normal file extension
    
    if site.__runtime_config.output_directory {
        output_path = path_join(site.__runtime_config.output_directory, output_path, separator="/",, temp);
    }
    
    return join(output_path, page.output_file_extension, separator = ".",, temp);;
}

generate_site :: ($build_config: Build_Config) -> (
    site_insert_string: string, 
    directory:          Directory,
    template_headers:   [] Template_Header
) #compile_time {
    DIRECTORY        :: #run,stallable build_directory(build_config.base_directory, .[ build_config.pages_directory, build_config.templates_directory ]);
    
    // log(format_directory(*DIRECTORY,, temp));
    
    RAW_TEMPLATES    :: #run,stallable process_templates(*DIRECTORY);
    TEMPLATE_HEADERS :: #run,stallable compile_headers(RAW_TEMPLATES);
    
    // TODO: Just a thought, but could we do some kind of crazy dynamic specialize stuff to generate the Template structs? 
    //       That could potentially allow us to much more easily write the template generation loop and then we can just return all the types as an array from some #run.
    
    builder: String_Builder;
    
    format_directory_entry :: (builder: *String_Builder, directory: *Directory, entry: *Directory.Entry, indent := 0) {
        if entry.kind == .FOLDER {
            for 1..indent append(builder, "  ");
            append(builder, entry.name);
            append(builder, ": struct {\n");
            for *child: entry.entries { 
                format_directory_entry(builder, directory, child, indent + 1);
            }
            for 1..indent append(builder, "  ");
            append(builder, "}\n");
        } else {
            ext, found := path_extension(entry.name);
            if found {
                if ext == { 
                  case "tt";
                    // TODO: optimize template lookup
                    for raw_template, template_index: RAW_TEMPLATES {
                        if raw_template.directory_entry_id == entry.id {
                            name := actual_basename(entry.name);
                            assert(is_legal_identifier(name), "Invalid template filename: %", entry.name);
                            
                            for 1..indent append(builder, "  ");
                            print(builder, "%: struct {\n", name);
                            indent += 1; 
                            
                            for 1..indent append(builder, "  ");
                            append(builder, "using #as base: Template;\n");
                            
                            for 1..indent append(builder, "  ");
                            append(builder, "render :: ");
                            generate_template_render_proc(builder, raw_template, TEMPLATE_HEADERS[template_index]);
                            append(builder, "\n");
                            
                            for 1..indent append(builder, "  ");
                            append(builder, "RENDER_PROC_INFO :: #run get_procedure_info(render);\n");
                            
                            indent -= 1;
                            for 1..indent append(builder, "  ");
                            append(builder, "}\n");
                            
                            break raw_template;
                        }
                    }
                }
            }
            // TODO: else no extension?
            
            // TODO: some default case for file handle of some sort?
            
            append(builder, "\n");
        }
    }
    
    // TODO: actually modify directory so it contains info about file contents
    directory := clone_directory(*DIRECTORY);
    
    for *child: directory.root.entries { 
        format_directory_entry(*builder, *directory, child);
    }
    
    // TODO: walk new directory and place template type and id onto corresponding file entries
    //       may have to put this in a different #run so that we actually can access the generated struct members
    //       or figure out some other way to get_template_from_directory_entry
    
    // TODO: for templates with an export name defined, we could use #overlay (this will be necessary once templates have state and unique types)
    
    // if header.export_name {
    //     print(builder, "#overlay(__template_%1) %2 : type_of(__template_%1);\n", template_index, header.export_name);
    // }
    
    append(*builder, "__SITE_TYPE :: #this;");
    
    return builder_to_string(*builder), DIRECTORY, TEMPLATE_HEADERS;
}

is_legal_identifier :: (str: string) -> bool {
    begins_identifier :: (char: u8) -> bool { return is_alpha(char) || char == #char "_"; }
    continues_identifier :: is_alnum;
    
    if !str return false;
    if !begins_identifier(str[0])  return false;
    for str  if !continues_identifier(it)  return false;
    return true;
}

render_all_pages :: (site: *Site) {
    render_page :: (site: *Site, page: *Template) {
        output_path := get_page_output_path(site, page);
        output_dir  := path_strip_filename(output_path);
        if output_dir {
            make_directory_if_it_does_not_exist(output_dir, recursive = true);
        }
        
        log("Rendering page '%' to '%'", page.source_path, output_path);
        
        if !call_template(page) {
            log("Failed while trying to render page: %", output_path);
            exit(1);
        }
        write_entire_file(output_path, builder_to_string(*site.__html_builder));
    }
    
    // TODO: instead of walking the directory, we should probably just walk the site's type info, and check if the member is using Template
    #insert -> string {
        builder: String_Builder;
        
        format_directory_entry :: (builder: *String_Builder, directory: *Directory, entry: *Directory.Entry, indent := 0) {
            if entry.kind == .FOLDER {
                for *child: entry.entries { 
                    format_directory_entry(builder, directory, child, indent + 1);
                }
            } else {
                ext, found := path_extension(entry.name);
                if found {
                    if ext == { 
                      case "tt";
                        // TODO: optimize template lookup
                        for header, template_index: site.TEMPLATE_HEADERS {
                            if header.directory_entry_id == entry.id {
                                name := copy_string(entry.path,, temp);
                                _, name = split_from_left(name, "."); // TODO: more rigorous solution
                                path_overwrite_separators(name, ".");
                                
                                for 1..indent append(builder, "  ");
                                print(builder, "render_page(site, *site.%);\n", name);
                                
                                break header;
                            }
                        }
                    }
                }
            }
        }
        
        for *child: site.DIRECTORY.root.entries { 
            if child.name == "content" {
                format_directory_entry(*builder, *site.DIRECTORY, child);
            }
        }
        
        return builder_to_string(*builder);
    }
}

// TODO: remove need for using by making get_procedure_header more robust, able to access through struct namespace
init :: (using site: *Site, runtime_config: Runtime_Config) {
    #insert -> string {
        builder: String_Builder;
        
        append(*builder, "site.__type = site.__SITE_TYPE;\n");
        append(*builder, "site.__build_config = *site.BUILD_CONFIG;\n");
        print (*builder, "site.__runtime_config = runtime_config;\n");
        
        format_directory_entry :: (builder: *String_Builder, directory: *Directory, entry: *Directory.Entry, indent := 0) {
            if entry.kind == .FOLDER {
                for *child: entry.entries { 
                    format_directory_entry(builder, directory, child, indent + 1);
                }
            } else {
                ext, found := path_extension(entry.name);
                if found {
                    if ext == { 
                      case "tt";
                        // TODO: optimize template lookup
                        for header, template_index: site.TEMPLATE_HEADERS {
                            if header.directory_entry_id == entry.id {
                                name := copy_string(entry.path,, temp);
                                _, name = split_from_left(name, "."); // TODO: more rigorous solution
                                path_overwrite_separators(name, ".");
                                
                                print(builder, "site.%.header = *site.TEMPLATE_HEADERS[%];\n", name, template_index);
                                print(builder, "site.%1.render_proc_pointer = xx site.%1.render;\n", name);
                                print(builder, "site.%1.render_proc_info = *site.%1.RENDER_PROC_INFO;\n", name);
                                
                                break header;
                            }
                        }
                    }
                }
            }
        }
        
        for *child: site.DIRECTORY.root.entries { 
            format_directory_entry(*builder, *site.DIRECTORY, child);
        }
        
        return builder_to_string(*builder);
    }
}

#add_context website: *Site_Base;

Site_Base :: struct {
    __type:             Type;               // Site.init will set this to #this of generated Site
    __runtime_config:   Runtime_Config;
    __build_config:     *Build_Config;      // NOTE: points into constant storage
    __html_builder:     String_Builder;
}

Site :: struct(BUILD_CONFIG := Build_Config.{}) {
    using #as __base: Site_Base;
    
    SITE_INSERT_STRING, DIRECTORY, TEMPLATE_HEADERS :: #run,stallable generate_site(BUILD_CONFIG);
    
    #insert SITE_INSERT_STRING;
}

My_Site :: Site(.{
    base_directory      = "C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io",
    templates_directory = "templates",
    pages_directory     = "content",
});

main :: () {
    my_site: My_Site;
    context.website = *my_site;
    
    config := load_runtime_config("config.gon");
    init(*my_site, config);
    
    template_ids := collect_files_with_extension(*my_site.DIRECTORY, null, "tt");
    
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
    
    
    TODO: check if program print has a better proc for printing types so we don't have to do silly things in append_template_data
            right now it's kinda fine since we just insert the parameters string as text
            maybe at some point we will find out that we want to go back to using code for the parameters so that we can introspect them, but for now that was just not necessary
    
    TODO: think about whether we have any real practical use cases for precompiled headers atm, we may be able to actually remove this whole step...
            it is slightly nice that we can just use standard jai syntax to declare any data that needs to go into the header, but at the same time, it adds complication to compilation
            maybe static variables or thread-locals for pages will be a good test case for the utility of precompiled headers
            
    
    TODO: when implementing make_template_call, we will need to look up the header for our template so that we can get info about parameters
            and we will need some way to do this lookup at comptime...?
            
    TODO: think about how to implement globals. this may actually be more problematic that thread-locals, because we will have to consider locking/unlocking of mutexes and the sort
            also need to consider how thread-locals and globals may need to be synchronized with a database
            
    TODO: need a better method for setting uuids on templates
            set standard base id for pages, use that so we can convert a id back into an index to either the templates or pages array
            
            
    OK, so the new plan in order to really clean things up is to make the site generator generate a Site struct that houses all the wacky generated stuff
        see Site_Generator.jai
    There's a few ideas I need to test out first though, or this may not work out
    
    I really want to figure out a way to make Templates be the thing that gets exposed under the export name rather than the rendering proc itself
    this would be helpful for various reasons, but perhaps it would also allow us to store statics on the Template itself rather than on the Site
    then the templates can just be non-constant members of some generate Template subtype
    and of course they will all use some Template_Base 
    
    
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
#import "Math";
#import "Random";
#import "File";
#import "File_Utilities";
#import "String";
using,except(next_power_of_two) Hash_Table :: #import "Hash_Table";
Compiler :: #import "Compiler";
PP :: #import "Program_Print";

#import "Utils";
GON :: #import "GON"()(string.["JSON"]);
Convert :: #import "Convert";
#import "md4c";

#import "Site_Generator";

// HTTP_Server :: #import "Http_Server_caztanj";

// regular basename should do this, but doesn't
actual_basename :: (path: string) -> string {
    _path := path_filename(path);
    while 1 {
        extension, found := path_extension(_path);
        if !found  break;
        _path.count -= extension.count + 1;
    }
    return _path;
}



/*

Site_Builder :: struct {
    // The directory structure is built out throughout the compilation process. 
    // It relates particular sub-structures in the site_struct to the source files that generated them.
    directory: Directory_Builder;
    
    // This struct code is built out throughout the compilation process as well. 
    // Whenever we we need to 
    site_struct: *Code_Struct;
}















*/
