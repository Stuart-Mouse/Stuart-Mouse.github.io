
TEMPLATE_FILE_EXTENSION :: "tt";

#add_context html_builder: *String_Builder;

Template_Render_Proc :: #type (parameters: ..Template_Parameter) -> bool;

Template_Parameter :: struct {
    name:   string;
    value:  Any;
}

Template_Parameter_Declaration :: struct {
    name:     string;
    type:     string;
    default:  string = "";
}

Template :: struct {
    using header:       Template_Header;
    render_proc:        Template_Render_Proc;
}


Page :: struct {
    using #as template: Template;
    // output_path:    string;
}

Template_Header :: struct {
    source_path:        string; // relative to working directory
    name:               string;
    notes:              [] string;  // TODO: should we transfer these onto call-template proc?
    parameters:         [] Template_Parameter_Declaration;
}

Template_Call :: struct {
    name: string;
    parameters: [] Template_Parameter;
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
    body_text:      string;
    insert_blocks:  [] Insert_Block;
}

Insert_Block ::  struct { name: string; text: string; };

process_templates :: (paths: [] string) -> [] Raw_Template #compile_time {
    templates := NewArray(paths.count, Raw_Template); // @Leak
    for path: paths {
        source, ok := read_entire_file(path);
        assert(ok, "Unable to load file at path '%'", path);
        
        log("processing template: %", path);
        append_proc := default_append_content;
        preamble, postamble: string;
        ifx path_extension(basename(path)) == "md" {
            append_proc = markdown_append_content;
            preamble    = default_markdown_preamble;
            postamble   = default_markdown_postamble;
        }
        templates[it_index] = process_template(source, path, append_proc, preamble, postamble);
    }
    return templates;
}

#scope_module

default_append_content :: (builder: *String_Builder, content: string) {
    print(builder, "write_html(#string __HTML\n%\n__HTML);\n", content);
}

markdown_append_content :: (builder: *String_Builder, content: string) {
    append(builder, "write_html(#string __HTML\n");
    
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
    result := md_html(content.data, xx content.count, process_output, *sb_and_ctx, 0, 0);
    assert(result == 0);
    
    append(builder, "\n__HTML);\n");
}
String_Builder_And_Context :: struct {
    builder: *String_Builder;
    ctx:     *#Context;
}

default_markdown_preamble :: #string __JAI
call("markdown_preamble");
__JAI;

default_markdown_postamble :: #string __JAI
call("markdown_postamble");
__JAI;


#scope_export

// TODO: rewrite to use some sort of scanner so that we can report proper error info.
// processes the template source to produce the body code for rendering procedure
// also returns the raw header code as text
process_template :: (source: string, path: string, append_content := default_append_content, preamble := "", postamble := "") -> Raw_Template #compile_time {
    insert_blocks: [..] Insert_Block;
    
    in_code := false;
    current_string: string = .{ 0, source.data };
    
    builder: String_Builder;
    append(*builder, preamble);
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<??") {
                if current_string.count > 0 {
                    append_content(*builder, current_string);
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
                array_add(*insert_blocks, .{ name, current_string });
                advance(*source, 2);
                
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "<?") {
                if current_string.count > 0 {
                    append_content(*builder, current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    append_content(*builder, current_string);
                }
                advance(*source, 2);
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "}}") {
                    advance(*source, 1);
                    current_string.count += 1;
                }
                advance(*source, 2);
                if current_string.count > 0 {
                    print(*builder, "write_var(%);\n", current_string);
                }
                current_string = .{ 0, source.data };
                continue loop;
            }
        }
        else if begins_with(source, "?>") {
            if current_string.count > 0 {
                append(*builder, current_string);
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
    if !in_code {
        if current_string.count > 0 {
            append_content(*builder, current_string);
        }
    } else {
        assert(false, "Unexpected EOF in code segment in template: %", path);
    }
    
    append(*builder, postamble);
    
    return .{ 
        name          = actual_basename(path),
        source_path   = path, 
        body_text     = builder_to_string(*builder), 
        insert_blocks = xx insert_blocks
    };
}

// ===== STEP 2: Compile Headers =====

get_insert_block :: (template: Raw_Template, name: string) -> text: string #compile_time {
    for template.insert_blocks  if it.name == name  return it.text; 
    return "";
}

compile_headers :: ($templates: [] Raw_Template) -> [] Template_Header #compile_time {
    #insert -> string {
        builder: String_Builder;
        
        print(*builder, "headers: [%] Template_Header;\n", templates.count);
        for templates {
            header_text := get_insert_block(it, "HEADER");
            
            print(*builder, #string JAI
            headers[%] = .{
                name = "%",
                source_path = "%",
                %
            };
            JAI, it_index, it.name, it.source_path, header_text);
            
            // TODO: we would like to be able to use `arg1: T1, arg2: T2, ...` syntax for parameters, 
            //       but we can't just trivially insert that here, we would actually need to parse it out
            //       and to be frank, I don't really feel like bringing in the Jai lexer to make that robust
            //       Although, perhaps we could consider using Jai lexer to get more razor-like syntax, e.g. `@identifier.member` and such
            // NOTE: maybe we can just generate the sample procedure type signature and then store the type info for that, as well as a parallel array of parameter names
            // params_text := get_insert_block(it, "");
            // if params_text {
            //     print(*builder, "headers[%].parameters = .[\n", it_index);
            //     for 
                
            //     append(*builder, "];");
            // }
        }
        append(*builder, " return headers;");
        
        return builder_to_string(*builder);
    }
}

// ===== STEP 3: Generate Final Rendering Procedures =====

generate_template_proc :: (body_text: string, header: Template_Header) -> string #compile_time {
    builder: String_Builder;
    
    append(*builder, "(__parameters__: ..Template_Parameter) -> bool {\n");
    append(*builder, "using Template_Generation_Helpers;\n");
    append(*builder, "using Template_Runtime_Helpers;\n");
    
    // generate code to typecheck and unpack parameters as local variables
    for header.parameters {
        print(*builder, "%1 := get_parameter(\"%1\", %2, \"%3\");\n", it.name, it.type, it.default);
    }
    
    append(*builder, body_text);
    append(*builder, "return true;\n}\n");
    
    return builder_to_string(*builder);
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

call_template :: (name: string, parameters: ..Template_Parameter) -> bool {
    template: *Template;
    for *templates  if it.name == name {
        template = it;  break;
    }
    if template == null { 
        log("Error: Unable to find template: %", name);  
        return false; 
    }
    if !template.render_proc(..parameters) {
        log("Error: Failed while trying to render template: %", template.name);
        return false;
    }
    return true;
}

Template_Runtime_Helpers :: struct {
    get_parameter :: ($name: string, $T: Type, $default: string) -> T #expand {
        src: Any;
        found := false;
        for `__parameters__ {
            if it.name == name { src = it.value; found = true; break; }
        }
        
        if !found {
            #if default {
                #insert #run tprint("return %;", default);
                // return #insert default;  // why does this not work?
            }
            
            log("Error: No value provided for parameter: %", name);
            `return false;
        }
        
        // TODO: In the future, instead of using temp here, maybe we would use some other context.request_allocator or similar.
        //       In any case, we definitely don't want these parameter values to get allocator with some long-lived allocator.
        value: T;
        if src.type.type == .STRING {
            src_string := src.value_pointer.(*string).*;
            if !Convert.set_value_from_string(value, src_string, should_copy_strings = false) {
                log("Error: failed while trying to set value of type % from string: %", T, src_string);
                `return false;
            }
        } else if !Convert.any_to_any(value, src,, temp) {
            log("Error: failed while trying to set value of type % from value of type %", T, (*src.type).(*Type).*);
            `return false; 
        }
        return value;
    }
    
    // shorthand for call_template to make life easier, also uses backticked return to invisibly propogate errors
    call :: (name: string, parameters: ..Template_Parameter) #expand {
        if !call_template(name, ..parameters) `return false;
    }
    
    // primarily intended for use in nesting templates
    // a Template_Call can be passed to a template as a sort of callback proc
    // so that one can have some broad structural templates and then embed content within that
    call :: (using callable: Template_Call) #expand {
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


// this is basically the entire metaprogram, i guess
#insert -> string {
    // don't bother to load any other config atm. build config can just be put directly in the source
    config.working_directory = get_working_directory();
    
    // setup these print settings so some code generation is easier
    ps := context.print_style;
    defer context.print_style = ps;
    
    fs := *context.print_style.default_format_struct;
    fs.begin_string = ".{";
    fs.use_long_form_if_more_than_this_many_members = S64_MAX;
    
    fa := *context.print_style.default_format_array;
    fa.begin_string = ".[";
    fa.stop_printing_after_this_many_elements = -1;
    
    template_paths   :: #run collect_file_paths(config.build.templates_directory);
    pages_paths      :: #run collect_file_paths(config.build.pages_directory);
    
    raw_templates    :: #run process_templates(template_paths);
    raw_pages        :: #run process_templates(pages_paths);
    
    template_headers :: #run compile_headers(raw_templates);
    page_headers     :: #run compile_headers(raw_pages);
    
    // generate final arrays for templates and pages
    // would be nice if we did not need to re-serialize the final headers, but it is what it is...
    // in order to make the job a bit easier we just override the print style so that they can just be passed to print as is
    
    // TODO: I don't necessarily like that we are putting the generated render_proc in its entirety directly into the output string here...
    //       but maybe later we will come up with a better way
    
    builder: String_Builder;
    
    append(*builder, "templates :: Template.[\n");
    for raw_templates {
        header := template_headers[it_index];
        FORMAT :: #string JAI
        .{
            header      = %1,
            render_proc = %2,
        },
        JAI;
        print(*builder, FORMAT, header, generate_template_proc(it.body_text, header));
    }
    append(*builder, "];\n");
    
    append(*builder, "pages :: Page.[");
    for raw_pages {
        header := page_headers[it_index];
        FORMAT :: #string JAI
        .{
            header      = %1,
            render_proc = %2,
        },
        JAI;
        print(*builder, FORMAT, header, generate_template_proc(it.body_text, header));
    }
    append(*builder, "];\n");
    
    return builder_to_string(*builder);
}


main :: () {
    load_config();
    
    for pages {
        output_path := get_page_output_path(it.source_path);
        output_dir  := path_strip_filename(output_path);
        if output_dir {
            make_directory_if_it_does_not_exist(output_dir, recursive = true);
        }
        
        log("Rendering page '%' to '%'", it.source_path, output_path);
        builder: String_Builder;
        
        if !it.render_proc(,, html_builder = *builder) {
            log("Failed while trying to render page: %", output_path);
            exit(1);
        }
        write_entire_file(output_path, builder_to_string(*builder));
    }
    
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


get_page_output_path :: (source_path: string) -> string {
    relative_path := source_path;
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
    
    // TODO: robustly determine output file extension. for now it will always be html
    return join(output_path, ".html",, temp);;
}


/*
    Improving jhtml stuff:
        parse html lexically and construct a real DOM that we can introspect and modify
        
        Syntax notes:
            If we were to fully parse out HTML or other templated file formats, I am somewhat interested in potentially using something like the razor `@` syntax for code blocks and expressions
            It's not only that it's a nice shorthand syntax, but it could allow for actually doing things with the templated content that would not otherwise be possible.
            
    Long-Term
        figure out how to integrate this kind of stuff with an http/web server module in order to get more complete functionality, not just static site generation
        figure out how to nicely integrate WASM stuff into sites
            If we use a somewhat similar structure to existing wasm toolchain demo, 
                then perhaps we can collect wasm content to compile as part of main build program
            If eventually there is a sufficiently well-supported way to manipulate the DOM with Jai wasm,
                then maybe we can really get cooking by putting Jai WASM code directly into our html templates
    
    
    use 'navbar(label/sublabel)' note in template header to automatically collect pages we want to link on navbar
        label/sublabel structure could be used for generating dropdown menus
    
    I was starting to think, "why not just embed nested templates directly into the source of the calling template at comptime?"
    But one benefit of calling templates dynamically is that we switch which template we are choosing to call in certain situations by simply passing a different identifier to call_template
        This could be very usful when we get to the point of dynamically rendering pages on a server, since we can load different templates in response to the request data
    OR, potentially, we could even do dll shenanigans to replace/update templates without taking down the main http server program
        This is really less of a concern though
    
*/


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
    
    
    TODO: report when short names of templates and pages conflict
        should not be using basename, should be using something like path relative to templates/ with extension stripped
        we still want to strip extensions, since really one should not have e.g. both an `template.html` and `template.md` file in that same directory
        
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
        
    TODO: improve parameter passing
        it's pretty ok now on the caller's side, and having default value expressions is pretty cool
        it would still be nicer to have totally normal syntax and static typechecking, but we just need to implement 'exported' template procedures for that
        
    TODO: improve parameter declarations
        These are now more clunky to define since we have to either use a key/value type struct intializer or provide the empty string for .default
        Ideally we could use `name: Type = value,` syntax for each element, but the problem is we then need to parse this crap
            In theory, we could probably insert the declarations as code and then introspect them and modify as needed
            but that is a lot more work than what we are currently doing!
            step 1: try getting code nodes for argument list in the first place
                done
            step 2: create a helper function to generate a procedure as code nodes given its constituent parts
            step 3: insert that procedure into the program
            step 4: add export name to header so that we can just call templates by name
        
        
    TODO: add option to PWA plugin to turn off the input event prevention 
        this is not really relevant to the templater but is relevant to the site so whatever
        
    
*/


#scope_module

#import "Basic";
// #import "Reflection"; // for set_value_from_string
#import "Math";
#import "File";
#import "File_Utilities";
#import "String";
#import "Hash_Table";

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

