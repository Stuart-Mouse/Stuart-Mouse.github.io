
#add_context html_builder: *String_Builder;

#no_reset templates: [..] Template;

Template_Render_Proc :: #type (args: ..Any);

Template_Parameter :: struct {
    key:    string;
    value:  string;
}

Template_Parameter_Declaration :: struct {
    key:    string;
    type:   Type;
}

Template :: struct {
    using header:       Template_Header;
    render_proc:        Template_Render_Proc;
    source_path:        string; // relative to working directory
}

Page :: struct {
    using #as template: Template;
}

Template_Header :: struct {
    name:               string;
    notes:              [] string;
    parameters:         [] Template_Parameter_Declaration;
}

/*
    How to attach a header to templates?
    Could figure out a way to store template data as constant structure inside the rendering procedure itself.
    Then add optional parameter to the procedure to ask it for a pointer to that structure.
    Or, we can separately return the header info and the body string.
    
    
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
    
    
    Templates VS Pages
    There definitely needs to be some sort of distinction here, but I'm not entirely sure yrt what this distinction should be!
        a page has a main template, using #as sort of relation
    Pages will have some actual url associated with them as well
    
    
    Template names
    should templates use short names at all? or just full path?
    
    
    Main pages should not be callable with call-template, probably
    for now, template names will be path of template relative to base templates directory
    
    template rendering proc should have statically-typed parameters so we can call it directly if so desired
        then we can automate the creation of a wrapper in the same way we do for lead sheets with dyncall disabled
            then call-template wraps calling into those! its wrappers all the way down...
    
    URL parameters can go into context so that tey are easily available across template calls
        same goes for other request data
    
    before we can really do anything cool, we need syntax to put header data in the template files!
    Directives will be ?? followed immediately by directive name
    If directive takes parameters, then we just scan for enclosing pair of () and return content for processing by the directive proc
    
    ??HEADER(
        
    );
    
    
    This is dumb because HTML is already a structured format! if we just actually parsed the html out then we could use custom tags for putting certian data in
    The only reason we would really need directives or custom syntax is for actually affecting parsing in some way
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


// macros to make code gen cleaner
write_var  :: inline (var: $T) { print(context.html_builder, "%", var); }
write_html :: inline (html: string) { append(context.html_builder, remove_trailing_newline(html)); }


remove_trailing_newline :: (s: string) -> string { return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; }

// also return any additional information that we pull out of template
// caller can then decide whether to 'export' template as a proc with static types, or whether to just put in templates array
process_template :: (builder: *String_Builder, source: string) -> bool, Template_Header #compile_time {

    // HEADER info is super hard-coded right now until I can figure out a better way to encode it in the templates
    // but I just need some kind of way to put this info in file so that I can build out other aspects
    
    header: Template_Header;
    
    HEADER_TAG :: "@HEADER")
    if begins_with(source, HEADER_TAG) {
        advance(*source, HEADER_TAG.count);
        if !begins_with(source, "(") {
            assert(false, "Expected ( after directive name.");
        }
        header_content := string.{ 0, source.data };
        while !begins_with(source, ")") {
            if !source  assert(false, "Unexpected EOF while parsing directive.");
            advance(*source, 1);
            header_content.count += 1;
        }
        advance(*source, 1);
        
        // for now will just parse out the header data as gon, since that's what I have on hand!
        // in the future it would probably be better to use another format or simply use that one file format that comes as part of Jai
        parser:, ok = parse_file(header_content);   assert(ok);
        add_data_binding(*parser, header, "");
        ok = process_data_bindings(*parser);   assert(ok);
    }
    
    in_code := false;
    current_string: string = .{ 0, source.data };
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<?") {
                if current_string.count > 0 {
                    print(builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    print(builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
                }
                advance(*source, 2);
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "}}") {
                    advance(*source, 1);
                    current_string.count += 1;
                }
                advance(*source, 2);
                if current_string.count > 0 {
                    print(builder, "write_var(%);\n", current_string);
                }
                current_string = .{ 0, source.data };
                continue loop;
            }
        }
        else {
            if begins_with(source, "?>") {
                if current_string.count > 0 {
                    append(builder, current_string);
                }
                in_code = false;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
        }
        
        advance(*source, 1);
        current_string.count += 1;
    }
    
    // write final string
    if !in_code {
        if current_string.count > 0 {
            print(builder, "write_html(#string __HTML\n%\n__HTML);\n", current_string);
        }
    } else {
        if current_string.count > 0 {
            append(builder, current_string);
        }
    }
    
    return true;
}

// generates the rendering code for a page and adds it to the templates table
// we have to also generate the code for adding the template to the table since simply adding the generated rendering functions to teh table at compile-time and using #no_reset does not actually work
// so unfortunately we gotta do all this weird business
generate_template_renderer :: (path: string) -> string, Template_Header #compile_time {
    source, ok := read_entire_file(path);
    assert(ok, "Unable to load file at path '%'", path);
    
    builder: String_Builder;
    append(*builder, "(parameters: ..Any) {\n");
    
    // TODO: template parameters
    
    ok, header := process_template(*builder, source);
    
    assert(ok, "Failed while trying to process template file: %", path);
    append(*builder, "}\n");
    
    
    
    return builder_to_string(*builder);
}

call_template :: (name: string, arguments: ..Template_Parameter) {
    template: *Template;
    for *templates  if it.name == name {
        template = it;  break;
    }
    assert(template != null, "Failed to find template '%'", name);
    template.render(..arguments);
}

config: struct {
    navbar_items:           [] struct { name: string; path: string; };
    
    local_deployment:       bool;
    working_directory:      string;
    
    templates_directory := "templates";     // input  path for supporting templates
    content\ _directory := "content";       // input  path for main page templates
    public\  _directory := "";              // output path for rendered pages
};

load_config :: () {
    file, ok := read_entire_file("config.gon");
    assert(ok);
    
    parser:, ok = parse_file(file);
    assert(ok);
    
    add_data_binding(*parser, config, "config");
    
    ok = process_data_bindings(*parser);
    assert(ok);
    
    config.working_directory = get_working_directory();
    
    // config.templates_directory = join(config.working_directory, config.templates_directory); // @Leak
    // config.content\ _directory = join(config.working_directory, config.content\ _directory); // @Leak
    // config.public\  _directory = join(config.working_directory, config.public\  _directory); // @Leak
}

get_base_path :: () -> string {
    return ifx config.local_deployment then config.working_directory else config.public_directory;
}

local_path :: inline (relative_path: string) -> string {
    // need to create some proc to get relative path from one page to another
    // or, we could use absolute paths within site
    
    // Frankly, we shouldn't have this issue in the first place except that we are using github pages to host all this crap instead of a real hosting service
    
    path := join(get_base_path(), relative_path, separator="/",, temp);
    return path;
}

collect_file_paths :: (base_path: string) -> [] string {
    paths: [..] string;
    visit_files(base_path, true, *paths, (info: *File_Visit_Info, paths: *[..] string) {
        array_add(paths, info.full_name);
    });
    return paths;
}

main :: () {
    // generate rendering procs
    #insert -> string {
        load_config();
        builder: String_Builder;
        
        template_paths := collect_file_paths(config.templates_directory);
        content\_paths := collect_file_paths(config.content_directory);
        
        append(*builder, "array_add(*templates, ");
        for template_paths {
            FORMAT :: #string JAI
            .{
                name        = "%1",
                source_path = "%2",
                render      = #insert #run generate_template_renderer("%2"),
            },
            JAI;
            
            print(*builder, FORMAT, basename(it), it);
        }
        
        for content_paths {
            FORMAT :: #string JAI
            .{
                name        = "%1",
                source_path = "%2",
                render      = #insert #run generate_template_renderer("%2"),
                flags       = .IS_CONTENT_PAGE,
            },
            JAI;
            
            print(*builder, FORMAT, basename(it), it);
        }
        append(*builder, ");");
        
        return builder_to_string(*builder);
    }
    
    // run all template rendering procs
    load_config();
    
    for templates  if it.flags & .IS_CONTENT_PAGE {
        relative_path := it.source_path;
        advance(*relative_path, config.content_directory.count);
        while relative_path && is_any(relative_path[0], "\\/") {
            advance(*relative_path);
        }
        
        output_path := relative_path;
        if config.public_directory {
            output_path = join(config.public_directory, output_path,, temp);
        }
        log("output_path: %", output_path);
        
        output_dir  := path_strip_filename(output_path);
        if output_dir {
            make_directory_if_it_does_not_exist(output_dir, recursive = true);
        }
        
        output_path  = join(path_strip_extension(output_path), ".html",, temp);
        log("Rendering page '%' to '%'", it.source_path, output_path);
        
        builder: String_Builder;
        call_template(it.name,, html_builder = *builder);
        write_entire_file(output_path, builder_to_string(*builder));
    }
}



/*
    TODO: 
        fix randomizer page
        remove some old content
        add new content for newer projects and Autumn Collage
        fix broken navbar links on devlog pages
            need to calculate paths relative to current file location
                probably put that info in context? but then how do we know when to push file path for template?
        
        
    how to organize site now
        main page
            projects
                game engines
                gon parsers
                lead sheets
                jai data packer
            gon parsers
                C, Jai, Odin
                write some post on parser paradigms
                    SAX vs DOM vs 'Immeditate-mode'
            game dev
                pong, mario, and zelda engines in Odin
            blog posts
            
    
    Improving jhtml stuff:
        add ability to put parameters on a template
            we want to be able to decalre the parameters within the template itself
                will require parsing out what those parameters are and using that to generate the template function signature, or at least some code to typecheck and unpack arguments passed as Anys
                even if function signature for page rendering functions is (parameters ..Any), we can probably write a metaprogam thing to check the types of arguments at compile-time in the same way that print does.
                either that, or we can just put the templating functions' names into some namespace instead of storing them in some dynamic array. This would remove the need for the call-template function
                    which is probably nicer for usablility overall, but having that renderer does technically give us an interface layer that could be useful?
                    page identifiers and template names need to be valid Jai identifiers if we want to use those names as the template-rendering renderer's names directly
                        which means we cannot use dashes anymore! maybe not a big deal?
                passing all parameters to page-rendering procs as strings may unfortunately be the best approach so that we can call these rendering functions with parameters provided in url
                in any case, it would be easier to move from using string parameters to strongly-type parameters in the future than to go the other direction
        add ability to use markdown files as base instead of html
        parse html lexically and construct a real DOM that we can introspect and modify
        
        Notes from Tsoding's version
            should we automatically walk project folders and generate site structure based on directory structure somehow?
                would need to separate non-public templates from public-facing pages to render

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
#import "File";
#import "File_Utilities";
#import "String";
#import "Hash_Table";
#import "GON";
