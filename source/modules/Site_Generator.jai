
TEMPLATE_FILE_EXTENSION :: "tt";

// TODO: maybe we don't need to even put this in the context if we can just sneak it up as a first parameter to all render procs
#add_context site_generator: *Site_Base;

Template_Parameter :: struct {
    name:   string;
    value:  Any;
}

Template_Base :: struct {
    type:   Type;
    
}

Template :: struct {
    using header:   Template_Header;
    render:         *void;
}

Template_Header :: struct {
    uuid:                       u64;
    source_path:                string;     // relative to working directory at comptime
    output_file_extension:      string;
    export_name:                string;
    notes:                      [] string;
    tags:                       [] string;
    
    render_proc_type:           Type;
}

Template_Call :: struct {
    template:       *Template;
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
        print(context.site_generator.html_builder, "%", var); 
    }
    write_html :: inline (html: string) { 
        // TODO: prevent appending totally empty lines
        append(context.site_generator.html_builder, remove_trailing_newline(html)); 
    }
    remove_trailing_newline :: inline (s: string) -> string { 
        return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; 
    }
}

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



process_template :: (source: string, path: string) -> Raw_Template #compile_time {
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

// ===== STEP 2: Compile Headers =====

get_named_block :: (template: Raw_Template, name: string) -> text: string #compile_time {
    for template.named_blocks  if it.name == name  return it.text; 
    return "";
}

compile_headers :: ($templates: [] Raw_Template, $uuid_start: int) -> [] Template_Header #compile_time {
    #insert -> string {
        builder: String_Builder;
        uuid := uuid_start;
        
        print(*builder, "headers: [%] Template_Header;\n", templates.count);
        for templates {
            defer uuid += 1;
            header_text := get_named_block(it, "HEADER");
            
            print(*builder, #string JAI
            headers[%1] = .{
                uuid = %2,
                source_path = "%3",
                output_file_extension = "%4",
                %5
            };
            JAI, it_index, uuid, it.source_path, it.output_file_extension, header_text);
            
            if get_named_block(it, "THREAD_LOCALS") {
                print(*builder, "headers[%1].flags |= .HAS_THREAD_LOCALS;\n", it_index);
            }
        }
        append(*builder, "return headers;");
        
        return builder_to_string(*builder);
    }
}

// ===== STEP 3: Generate Final Rendering Procedures =====

generate_template_render_proc :: (builder: *String_Builder, raw_template: Raw_Template, header: Template_Header) #compile_time {
    parameters := get_named_block(raw_template, "PARAMETERS");
    print (builder, "(%) -> bool {\n", parameters);
    
    append(builder, "using Template_Generation_Helpers;\n");
    append(builder, "using Template_Runtime_Helpers;\n");
    
    if header.flags & .HAS_THREAD_LOCALS {
        print(builder, "using context.thread_locals.__template_%;", header.uuid);
    }
    
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





// ===== Runtime Helpers =====


get_base_path :: () -> string {
    using context.site_generator;
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
    for *context.site_generator.templates {
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

push_site_to_context :: (site: *Site) #expand {
    site_generator_before := context.site_generator;
    context.site_generator = *site.site_base;
    `defer context.site_generator = site_generator_before;
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

get_page_output_path :: (site: *Site_Base, page: Template) -> string {
    build_config := get_build_config(site);
    
    relative_path := page.source_path;
    assert(begins_with(relative_path, build_config.pages_directory));
    advance(*relative_path, build_config.pages_directory.count);
    while relative_path && is_any(relative_path[0], "\\/") {
        advance(*relative_path);
    }
    
    output_path := relative_path;
    assert(ends_with(output_path, TEMPLATE_FILE_EXTENSION));
    output_path = path_strip_extension(output_path); // strip template extension
    output_path = path_strip_extension(output_path); // then strip normal file extension
    
    if build_config.output_directory {
        output_path = join(build_config.output_directory, output_path, separator="/",, temp);
    }
    
    return join(output_path, page.output_file_extension, separator = ".",, temp);;
}


#scope_export



// ===== Configuration =====

Build_Config :: struct {
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

load_runtime_config :: (site: *Site, path: string) {
    file, ok := read_entire_file(path);     assert(ok);
    parser:, ok = parse_file(file);         assert(ok);
    
    add_data_binding(*parser, site.runtime_config, "config");
    
    ok = process_data_bindings(*parser);            assert(ok);
    
    site.runtime_config.working_directory = get_working_directory();
}


// TODO: we need to make site base contain some header containing info about the Site that was generated.
Site_Base :: struct {
    type:               Type;           // Site.init will set this to #this of generated Site
    runtime_config:     Runtime_Config;
    __build_config:     *Build_Config;  // NOTE: do not ever write over this! points into constant storage
    html_builder:       *String_Builder;
    
    templates:          [] Template;
    pages:              [] Template;
}

get_build_config :: (site: *Site_Base) -> *Build_Config {
    return site.__build_config;
}

// NOTE: getter procs are because I am actually quite likely to change how sites or templates are stored internally
get_templates :: (site: *Site_Base) -> [] Template {
    return site.templates;
}

get_pages :: (site: *Site_Base) -> [] Template {
    return site.templates;
}

render_all_pages :: (site: *Site_Base) -> {
    push_site_to_context();
    
    for *page: get_pages(site) {
        output_path := get_page_output_path(page);
        output_dir  := path_strip_filename(output_path);
        if output_dir {
            make_directory_if_it_does_not_exist(output_dir, recursive = true);
        }
        
        log("Rendering page '%' to '%'", page.source_path, output_path);
        builder: String_Builder;
        
        if !call_template(.{ template = page },, html_builder = *builder) {
            log("Failed while trying to render page: %", output_path);
            exit(1);
        }
        write_entire_file(output_path, builder_to_string(*builder));
    }
}


Site :: struct(BUILD_CONFIG := Build_Config) {
    using #as site_base: Site_Base;
    
    
    #insert -> string {
        // I wish I could just do some of this outside of the #run and just link to the constant data like paths and headers from the runtime unstance
        // but there's just too much stuff (especially in the Raw_Template) that I don't think will really be usable at runtime
        // maybe in the future I'll figure out how to factor some of this in a better way
        
        template_paths   :: #run collect_file_paths(page.BUILD_CONFIG.templates_directory);
        page_paths       :: #run collect_file_paths(page.BUILD_CONFIG.pages_directory);
        
        raw_templates    :: #run process_templates(template_paths);
        raw_pages        :: #run process_templates(page_paths);
        
        template_headers :: #run compile_headers(raw_templates, 0);
        page_headers     :: #run compile_headers(raw_pages, 1 << 31);
        
        builder: String_Builder;
        
        for raw_templates {
            header := template_headers[it_index];
            print(*builder, "__render_template_% :: ", header.uuid);
            generate_template_render_proc(*builder, it, header);
            append(*builder, "\n");
        }
        for raw_pages {
            header := page_headers[it_index];
            print(*builder, "__render_template_% :: ", header.uuid);
            generate_template_render_proc(*builder, it, header);
            append(*builder, "\n");
        }
        
        
        append(*builder, "// exported templates\n");
        for raw_templates {
            header := template_headers[it_index];
            if header.export_name {
                print(*builder, "% :: __render_template_%;\n", header.export_name, header.uuid);
            }
        }
        append(*builder, "// exported pages\n");
        for raw_pages {
            header := page_headers[it_index];
            if header.export_name {
                print(*builder, "% :: __render_template_%;\n", header.export_name, header.uuid);
            }
        }
        
        append_template_data :: (builder: *String_Builder, header: Template_Header) {
            print (builder, "    .{\n");
            append(builder, "        header = .{\n");
            print (builder, "            export_name = \"%\",\n", header.export_name);
            print (builder, "            source_path = \"%\",\n", header.source_path);
            print (builder, "            output_file_extension = \"%\",\n", header.output_file_extension);
            if header.notes         print (builder, "            notes = %,\n", header.notes);
            if header.tags          print (builder, "            tags = %,\n", header.tags);
            if header.export_name   print (builder, "            export_name = \"%\",\n", header.export_name);
            print (builder, "            render_proc_type = type_of(__render_template_%),\n", header.uuid);
            
            if header.flags & .HAS_THREAD_LOCALS
            print (builder, "            thread_locals_type = type_of(Thread_Locals.__template_%),\n", header.uuid);
            append(builder, "        },\n");
            
            // TODO: should put a get_thread_locals proc directly on here like we do for the render proc?
            print (builder, "        render = xx __render_template_%,\n", header.uuid);
            append(builder, "    },\n");
        }
        
        
        // TODO: try to factor out init somehow
        // init sets up all initial global data, and creates the Template instances for all page and template rendering procs
        // we do this at runtime because we have to be able to cast the render proc pointers to *void
        // (and in the future there will probably be other data we need to load for each template on startup anyhow)
        
        append(*builder, #string JAI
        init :: (using site: *Site) {
            __build_config = *BUILD_CONFIG;
            type = #this;
        JAI);
        
        print (*builder, "templates = array_copy(Template.[\n", template_headers.count);
        for raw_templates {
            header := template_headers[it_index];
            append_template_data(*builder, header);
        }
        append(*builder, "]);\n");
        
        append(*builder, "pages = array_copy(Template.[\n");
        for raw_pages {
            header := page_headers[it_index];
            append_template_data(*builder, header);
        }
        append(*builder, "]);\n");
        
        // TODO: should probably deduplicate calls here so that we only call once per unique proc type
        for template_headers {
            print(*builder, "register_procedure_type_for_dynamic_call(type_of(__render_template_%));\n", it.uuid);
        }
        for page_headers {
            print(*builder, "register_procedure_type_for_dynamic_call(type_of(__render_template_%));\n", it.uuid);
        }
        
        append(*builder, "}\n"); // end init
        
        
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
#import "GON";
Convert :: #import "Convert";
#import "md4c";


/*

#import "Site_Generator";

My_Site: Site(.{
    templates_directory = "../templates",
    pages_directory     = "../content",
});

main :: () {
    using My_Site
    
    init(*My_Site);
    
    load_config(*My_Site, "config.gon");
    
    render_all_pages(*My_Site);
    
    fs := *context.print_style.default_format_struct;
    fs.begin_string = ".{";
    fs.use_long_form_if_more_than_this_many_members = 0;
    
    log("thread locals for image_grid: %", get_thread_locals(xx My_Site.image_grid));
    
    // do_server();
}

*/