
#add_context html_builder: *String_Builder;

Template_Render_Proc :: #type (parameters: ..Template_Parameter) -> bool;

Template_Parameter :: struct {
    name:   string;
    value:  Any;
}

Template_Parameter_Declaration :: struct {
    name:   string;
    type:   string;
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
    notes:              [] string;  // TODO: chould we transfer these onto call-template proc?
    parameters:         [] Template_Parameter_Declaration;
}

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
    
    Main pages should not be callable with call-template, probably
    for now, template names will be path of template relative to base templates directory
    
    URL parameters can go into context so that they are easily available across template calls
        same goes for other request data
    
    
    TODO: report when short names of templates and pages conflict
        should not be using basename, should be using something like path relative to templates/ with extension stripped
        we still want to strip extensions, since really one should not have e.g. both an `template.html` and `template.md` file in that same directory
        
    Would be interesting to create a special type of parameter value that itself represents a template call.
        Not sure how we could actualyl go about implementing that atm though
*/

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

// raw template body text and header text
// TODO: maybe also include other specialized code blocks
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
        templates[it_index] = process_template(source, path);
    }
    return templates;
}

// TODO: rewrite to use some sort of scanner so that we can report proper error info.
// processes the template source to produce the body code for rendering procedure
// also returns the raw header code as text
process_template :: (source: string, path: string) -> Raw_Template #compile_time {
    insert_blocks: [..] Insert_Block;
    
    in_code := false;
    current_string: string = .{ 0, source.data };
    
    builder: String_Builder;
    while loop := source {
        if !in_code {
            if begins_with(source, "<??") {
                if current_string.count > 0 {
                    print(*builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
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
                    print(*builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    print(*builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
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
            print(*builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
        }
    } else {
        assert(false, "Unexpected EOF in code segment in template: %", path);
    }
    
    return .{ 
        name          = basename(path),
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

// template header is just kind of passed through right now
generate_template_proc :: (body_text: string, header: Template_Header) -> string #compile_time {
    builder: String_Builder;
    
    append(*builder, "(__parameters__: ..Template_Parameter) -> bool {\n");
    append(*builder, "using Template_Generation_Helpers;\n");
    append(*builder, "using Template_Runtime_Helpers;\n");
    
    // generate code to typecheck and unpack parameters as local variables
    for header.parameters {
        print(*builder, "%1 := get_parameter(\"%1\", %2);\n", it.name, it.type);
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
    get_parameter :: ($name: string, $T: Type) -> T #expand {
        for `__parameters__ {
            if it.name == name {
                value: T;
                // TODO: use Convert.any_to_any for my builds...
                if it.value.type.type == .STRING {
                    string_value := it.value.value_pointer.(*string).*;
                    if !set_value_from_string(value, string_value) {
                        log("Error: Unable to set value of parameter '%' from string '%'", name, string_value);
                        `return false;
                    }
                } else {
                    info :: type_info(T);
                    
                    // TODO: we will also want to have auto conversions for integers to prevent pain
                    
                    if it.value.type != info {
                        // need to have some basic automatic conversions for arrays in order to reduce suffering
                        #if info.type == .ARRAY {
                            if info.array_type == .VIEW {
                                if it.value.type.type {
                                    src_array_info := it.value.type.(*Type_Info_Array);
                                    dst_array_info := info.(*Type_Info_Array);
                                    if src_array_info.element_type == dst_array_info.element_type {
                                        value.count, value.data = get_array_count_and_data(it.value.value_pointer, xx it.value.type);
                                        return value;
                                    }
                                }
                            }
                        }
                    
                        log("Error: Incorrect type passed for parameter: %\n\tExpected: %, got: %", name, T, (*it.value.type).(*Type).*);
                        `return false;
                    }
                    memcpy(*value, it.value.value_pointer, size_of(T));
                }
                return value;
            }
        }
        
        log("Error: No value provided for parameter: %", name);
        `return false;
    }
    
    // shorthand for call_template to make life easier, also uses backticked return to invisibly propogate errors
    call :: (name: string, parameters: ..Template_Parameter) #expand {
        if !call_template(name, ..parameters) `return false;
    }

    #if 0 {
    
    // to be used only within template/page rendering procs. should namespace with other such procedures kind of like Template_Generation_Helpers
    get_url_parameter :: ($name: string, $T: Type) -> T #expand {
        for context.url_parameters {
            if it.name == name {
                value: T;
                if !set_value_from_string(value, it.value)  `return false;
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
        array_add(paths, info.full_name);
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
    
    template_headers :: #run,stallable compile_headers(raw_templates);
    page_headers     :: #run,stallable compile_headers(raw_pages);
    
    // generate final arrays for templates and pages
    // would be nice if we did not need to re-serialize the final headers, but it is what it is...
    // in order to make the job a bit easier we jsut override the print style so that they can just be passed to print as is
    
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
}


get_page_output_path :: (source_path: string) -> string {
    relative_path := source_path;
    advance(*relative_path, config.build.pages_directory.count);
    while relative_path && is_any(relative_path[0], "\\/") {
        advance(*relative_path);
    }
    
    output_path := relative_path;
    if config.output_directory {
        output_path = join(config.output_directory, output_path,, temp);
    }
    
    return join(path_strip_extension(output_path), ".html",, temp);
}


/*
    TODO: 
        fix randomizer page
        remove some old content
        add new content for newer projects and Autumn Collage
        fix broken navbar links on devlog pages
            need to calculate paths relative to current file location
                probably put that info in context? but then how do we know when to push file path for template?
    
    
    Improving jhtml stuff:
        add ability to put parameters on a template
            we want to be able to decalre the parameters within the template itself
                will require parsing out what those parameters are and using that to generate the template function signature, or at least some code to typecheck and unpack parameters passed as Anys
                even if function signature for page rendering functions is (parameters ..Any), we can probably write a metaprogam thing to check the types of parameters at compile-time in the same way that print does.
                either that, or we can just put the templating functions' names into some namespace instead of storing them in some dynamic array. This would remove the need for the call-template function
                    which is probably nicer for usablility overall, but having that renderer does technically give us an interface layer that could be useful?
                    page identifiers and template names need to be valid Jai identifiers if we want to use those names as the template-rendering renderer's names directly
                        which means we cannot use dashes anymore! maybe not a big deal?
                passing all parameters to page-rendering procs as strings may unfortunately be the best approach so that we can call these rendering functions with parameters provided in url
                in any case, it would be easier to move from using string parameters to strongly-typed parameters in the future than to go the other direction
        add ability to use markdown files as base instead of html
        parse html lexically and construct a real DOM that we can introspect and modify
        
        Notes from Tsoding's version
            maybe copy his RSS thing, as that would also be a cool feature to have.
            watch video again and see if he finished the markdown stuff?
                use html.t and md.t file extensions to signify templates, so we just have to strip off the .t and can handle many file template types
                jai preprocessor can probably just be the same for any textual template files, we will just need additional post-processing for certain other file types, e.g. MD needs conversion to HTML after we do the templating step
                    well, not really after, but we can do the conversion at comp-time and store the resulting html strings for the md sections we are going to insert
                    can we find a simple md -> html converter binary that we can just call at comptime?
        
        Syntax notes:
            If we were to fully parse out HTML or other templated file formats, I am somewhat interested in potentially using something like the razor `@` syntax for code blocks and expressions
            It's not only that it's a nice shorthand syntax, but it could allow for actually doing things with the templated content that would not otherwise be possible.
            
            
    in template header, need some way to denote a template as private so that it does not get deployed when doing a public build
    
    
    Long-Term
        figure out how to integrate this kind of stuff with an http/web server module in order to get more complete functionality, not just static site generation
        figure out how to nicely integrate WASM stuff into sites
            If we use a somewhat similar structure to existing wasm toolchain demo, 
                then perhaps we can collect wasm content to compile as part of main build program
            If eventually there is a sufficiently well-supported way to manipulate the DOM with Jai wasm,
                then maybe we can really get cooking by putting Jai WASM code directly into our html templates
    
    
    Project structure
        /project
            /templates              --- templates that can be called by other templates or in page renderers
            /content                --- templated content that generates actual public pages
                index.html.t
                /devlogs
                    ...
            /style
            /script
            /data
                /images
                /audio
                /text
            /public                 --- generated public content. totally static content gets indexed and served directly. pages which require some rendering on a per-request basis will be generated dynamically
                index.html
                /data
                /style
                /script
                
    
    use 'navbar(label/sublabel)' note in template header to automatically collect pages we want to link on navbar
        label/sublabel structure could be used for generating dropdown menus
    
    I was starting to think, "why not just embed nested templates directly into the source of the calling template at comptime?"
    But one benefit of calling templates dynamically is that we switch which template we are choosing to call in certain situations by simply passing a different identifier to call_template
        This could be very usful when we get to the point of dynamically rendering pages on a server, since we can load different templates in response to the request data
    OR, potentially, we could even do dll shenanigans to replace/update templates without taking down the main http server program
        This is really less of a concern though
    
*/


#scope_module

#import "Basic";
#import "Reflection"; // for set_value_from_string
#import "Math";
#import "File";
#import "File_Utilities";
#import "String";
#import "Hash_Table";
#import "GON";
