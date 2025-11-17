
TEMPLATE_FILE_EXTENSION :: "tt";

#add_context html_builder: *String_Builder;

Template_Parameter :: struct {
    name:   string;
    value:  Any;
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
    thread_locals_type:         Type;
    
    flags:  Flags;
    Flags :: enum_flags {
        NONE :: 0;
        HAS_THREAD_LOCALS :: 1;
    }
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


// ===== STEP 1: Raw Templates =====

Template_Generation_Helpers :: struct {
    write_var  :: inline (var: $T) { 
        print(context.html_builder, "%", var); 
    }
    write_html :: inline (html: string) { 
        // TODO: prevent appending totally empty lines
        append(context.html_builder, remove_trailing_newline(html)); 
    }
    remove_trailing_newline :: inline (s: string) -> string { 
        return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; 
    }
}

Raw_Template :: struct {
    name:           string;
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
markdown_preamble();
__JAI;

default_markdown_postamble :: #string __JAI
markdown_postamble();
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





// ===== Configuration =====

config: struct {
    build: struct {
        templates_directory :: "templates";
        pages_directory     :: "content";
    }
    
    // shared config
    working_directory:  string;
    
    // runtime config
    output_directory:   string; // TODO
    navbar_items:       [] Navbar_Item;
    local_deployment:   bool;
};

Navbar_Item :: struct { name: string; path: string; };


load_config :: () {
    file, ok := read_entire_file("config.gon");     assert(ok);
    parser:, ok = parse_file(file);                 assert(ok);
    
    add_data_binding(*parser, config, "config");
    
    ok = process_data_bindings(*parser);            assert(ok);
    
    config.working_directory = get_working_directory();
}



// ===== Runtime Stuff =====

get_base_path :: () -> string {
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
    for *Site.templates {
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

collect_file_paths :: (base_path: string) -> [] string {
    paths: [..] string;
    visit_files(base_path, true, *paths, (info: *File_Visit_Info, paths: *[..] string) {
        if path_extension(info.full_name) == TEMPLATE_FILE_EXTENSION {
            array_add(paths, info.full_name);
        }
    });
    return paths;
}

get_page_output_path :: (page: Template) -> string {
    relative_path := page.source_path;
    assert(begins_with(relative_path, config.build.pages_directory));
    advance(*relative_path, config.build.pages_directory.count);
    while relative_path && is_any(relative_path[0], "\\/") {
        advance(*relative_path);
    }
    
    output_path := relative_path;
    assert(ends_with(output_path, TEMPLATE_FILE_EXTENSION));
    output_path = path_strip_extension(output_path); // strip template extension
    output_path = path_strip_extension(output_path); // then strip normal file extension
    
    if config.output_directory {
        output_path = join(config.output_directory, output_path, separator="/",, temp);
    }
    
    return join(output_path, page.output_file_extension, separator = ".",, temp);;
}


// this is basically the entire metaprogram, i guess
// TODO: probably take in some config here as parameter
generate_site :: () -> string {
    // don't bother to load any other config atm. build config can just be put directly in the source
    config.working_directory = get_working_directory();
    
    // // setup these print settings so some code generation is easier
    // ps := context.print_style;
    // defer context.print_style = ps;
    
    // fs := *context.print_style.default_format_struct;
    // fs.begin_string = ".{";
    // fs.use_long_form_if_more_than_this_many_members = S64_MAX;
    
    // fa := *context.print_style.default_format_array;
    // fa.begin_string = ".[";
    // fa.stop_printing_after_this_many_elements = -1;
    
    template_paths   :: #run collect_file_paths(config.build.templates_directory);
    page_paths       :: #run collect_file_paths(config.build.pages_directory);
    
    raw_templates    :: #run process_templates(template_paths);
    raw_pages        :: #run process_templates(page_paths);
    
    template_headers :: #run compile_headers(raw_templates, 0);
    page_headers     :: #run compile_headers(raw_pages, 1 << 31);
    
    builder: String_Builder;
    
    append(*builder, #string END
    Site: struct {
        templates: [] Template;
        pages:     [] Template;
    END);
    
    
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
    
    // init sets up all initial global data, and creates the Template instances for all page and template rendering procs
    // we do this at runtime because we have to be able to cast the render proc pointers to *void
    // (and in the future there will probably be other data we need to load for each template on startup anyhow)
    
    print(*builder, "init :: () {\n");
    
    print (*builder, "Site.templates = array_copy(Template.[\n", template_headers.count);
    for raw_templates {
        header := template_headers[it_index];
        append_template_data(*builder, header);
    }
    append(*builder, "]);\n");
    
    append(*builder, "Site.pages = array_copy(Template.[\n");
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
    
    append(*builder, "init_thread_locals();\n");
    
    append(*builder, "}\n");
    
    
    append(*builder, "Thread_Locals :: struct {\n");
    for raw_templates {
        header := template_headers[it_index];
        thread_locals_text := get_named_block(it, "THREAD_LOCALS");
        if thread_locals_text {
            print (*builder, "__template_%: struct {\n", header.uuid);
            append(*builder, thread_locals_text);
            append(*builder, "};\n");
        }
    }
    for raw_pages {
        header := page_headers[it_index];
        thread_locals_text := get_named_block(it, "THREAD_LOCALS");
        if thread_locals_text {
            print (*builder, "__template_%: struct {\n", header.uuid);
            append(*builder, thread_locals_text);
            append(*builder, "};\n");
        }
    }
    append(*builder, "}\n");
    
    
    append(*builder, "get_thread_locals :: (template_render_proc: *void) -> Any {\n");
    for raw_templates {
        header := template_headers[it_index];
        if get_named_block(it, "THREAD_LOCALS") {
            print(*builder, "if template_render_proc == xx __render_template_%1  return context.thread_locals.__template_%1;\n", header.uuid);
        }
    }
    for raw_pages {
        header := page_headers[it_index];
        if get_named_block(it, "THREAD_LOCALS") {
            print(*builder, "if template_render_proc == xx __render_template_%1  return context.thread_locals.__template_%1;\n", header.uuid);
        }
    }
    append(*builder, "return Any.{};\n}\n");
    
    
    append(*builder, #string JAI
    get_template_header :: (template_render_proc: *void) -> *Template {
        for *Site.templates  if it.render == template_render_proc  return it;
        for *Site.pages      if it.render == template_render_proc  return it;
        return null;
    }
    JAI);
    
    append(*builder, "init_thread_locals :: () { context.thread_locals = New(Thread_Locals); }\n");
    
    append(*builder, "}\n"); // close Site struct
    
    append(*builder, "#add_context thread_locals: *Site.Thread_Locals;");
    
    return builder_to_string(*builder);
}

#insert #run generate_site();

main :: () {
    Site.init();
    
    load_config();
    
    for *page: Site.pages {
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
    
    
    fs := *context.print_style.default_format_struct;
    fs.begin_string = ".{";
    fs.use_long_form_if_more_than_this_many_members = 0;
    
    log("thread locals for image_grid: %", Site.get_thread_locals(xx Site.image_grid));
    
    // using HTTP_Server;
    
    // mylog :: (args: ..Any) {for args print("% ", it); print("\n"); }
    
    // http_listen(port=80);
    
    // any("*", (request: *Request) { mylog(request.method, request.path); });
    
    // get("/hello/:name", (request: *Request) {
    //   send_html(request, tprint("Hello %!", Request.get_param(request, "name")));
    // });
    
    // static("Game");
    
    // do_server();
}

// do_server :: () {
// server: Http_Server;

//     error := init(*server, 3000);
//     if error return;

//     router: Http_Router;
//     init(*router);

//     get(*router, "/", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/");
//     });

//     get(*router, "/hello", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/hello");
//     });

//     get(*router, "/a/b/c", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/a/b/c");
//     });

//     get(*router, "/a/d", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/a/d");
//     });

//     get(*router, "/hello/*", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/hello/*");
//     });

//     get(*router, "/hello/*/abc", (server: *Http_Server, request: *Http_Request, response: *Http_Response) {
//         html(server, response, "/hello/*/abc");
//     });

//     static(*router, "/public", "public");

//     quit := false;
//     while !quit {
//         error, events := http_server_update(*server);
//         if error quit = true;

//         for events {
//             if it.type != .Http_Request continue;

//             handled := http_router_handle_request(*server, *router, it);
//             if !handled {
//                 response := make_response(it,, temp);
//                 not_found(*server, response);
//                 send_response(*server, response);
//             }
//         }

//         reset_temporary_storage();
//     }

//     fini(*router);
//     shutdown(*server);
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
            set standard base uuid for pages, use that so we can convert a uuid back into an index to either the templates or pages array
            
            
    OK, so the new plan in order to really clean things up is to make the site generator generate a Site struct that houses all the wacky generated stuff
        see Site_Generator.jai
    There's a few ideas I need to test out first though, or this may not work out
    
    I really want to figure out a way to make Templates be the thing that gets exposed under the export name rather than the rendering proc itself
    this would be helpful for various reasons, but perhaps it would also allow us to store statics on the Template itself rather than on the Site
    then the templates can just be non-constant members of some generate Template subtype
    and of course they will all use some Template_Base 
    
    
    and some things to consider
        the site was really designed to just be a single global instance, and making it instantiable makes a lot of new problems
        one option is to use the context so that we can still access site data implicitly, but then still, there are problems
        may drop the nomenclature of using thread-locals and instead just go back to calling them statics
            main reason being that it will be more reasonable to put the statics on the Site struct itself
            and then if we have thread-local instances of the Site then the statics are also implicitly thread-local anyhow
    
    consider building out some kind of tree structure that represents the site in terms of file structure
        this will be helpful when we decide to do request routing stuff, and we can generate the tree as a constant later on if we want to optimize
    
    ok, wild new idea
        what if we change the first step of collecting file paths to instead generate a [] File_Tree_Node
            these nodes use indices to refer to one another (duh) and together they form a file tree (duh)
            but then we use the file tree to build the structure of the site itself
            so folders become struct members
            and we get to say like, templates.image_grid to pick out a particular template
            this will prevent any kind of name conflicts and allows for use to represent our actual projects structure in the Site struct itself
        this structure should also make it easier to make each page its own Template polymorph
        and should make it easier to generate each template separately
        but we will have to make a restriction on file names, to make sure they are valid Jai identifiers
            for templates this is not a big deal, since we want to be able to refer to templates directly in this way anyhow
            but for pages, it's not ideal. maybe we can work around this though
    
    
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
#import "GON";
Convert :: #import "Convert";
#import "md4c";

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

