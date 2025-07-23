
#add_context html_builder: *String_Builder;

templates: Table(string, Template);

Template_Renderer :: #type (parameters: ..Template_Parameter);

Template_Parameter :: struct {
    key:    string;
    value:  string;
}

Template_Parameter_Declaration :: struct {
    key:    string;
    type:   Type;
}

Template :: struct {
    source_path:        string; // relative to working directory
    
    name:               string;
    // notes:              [] string;
    // parameters:         [] Template_Parameter_Declaration;
    renderer:           Template_Renderer;
    
    // page_type:      Page_Type;
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


// macros to make code gen cleaner
write_var  :: inline (var: $T) { print(context.html_builder, "%", var); }
write_html :: inline (html: string) { append(context.html_builder, remove_trailing_newline(html)); }


remove_trailing_newline :: (s: string) -> string { return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; }

// generates the rendering code for a page and adds it to the templates table
// we have to also generate the code for adding the template to the table since simply adding the generated rendering functions to teh table at compile-time and using #no_reset does not actually work
// so unfortunately we gotta do all this weird business
generate_page_renderer :: (builder: *String_Builder, name: string, path: string) -> bool #compile_time {
    // TODO: check if we have already created a rendering function for this file
    // found := table_find_new(*templates, name);
    // if found  {
    //     log("Tried to generate duplicate render proc for page '%'", path);
    //     return "";
    // }
    
    source, ok := read_entire_file(path);
    assert(ok, "Unable to load file at path '%'", path);
    
    append(builder, "{\n");
    
    append(builder, "template := Template.{");
    print (builder, "name = \"%\",", name);
    print (builder, "source_path = \"%\",", path);
    append(builder, "};");
    
    print(builder, "template.renderer = (parameters: ..Template_Parameter) {\n", name);
    
    in_code := false;
    current_string: string = .{ 0, source.data };    
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<%") {
                if current_string.count > 0 {
                    print(builder, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    print(builder, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
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
            if begins_with(source, "%>") {
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
            print(builder, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
        }
    } else {
        if current_string.count > 0 {
            append(builder, current_string);
        }
    }
    
    append(builder, "}\n");
    
    print(builder, "table_add(*templates, template.name, template);\n");
    append(builder, "}\n");
    
    return true;
}

call_template :: (name: string, arguments: ..Template_Parameter) {
    ok, template := table_find_new(*templates, name);
    assert(ok, "Failed to find template '%'", name);
    template.renderer(..arguments);
}

config: struct {
    navbar_items:           [..] struct { name: string; path: string; };
    
    local_deployment:       bool;
    working_directory:      string;
    base_url:               string;
    
    templates_directory := "templates/";    // input  path for supporting templates
    content\ _directory := "content/";      // input  path for main page templates
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
    
    log("config: %", config);
    
    // config.templates_directory = join(config.working_directory, config.templates_directory); // @Leak
    // config.content\ _directory = join(config.working_directory, config.content\ _directory); // @Leak
    // config.public\  _directory = join(config.working_directory, config.public\  _directory); // @Leak
}

get_base_path :: () -> string {
    return ifx config.local_deployment 
        then config.working_directory 
        else config.base_url;
}

make_path_absolute :: inline (relative_path: string) -> string {
    path := join(get_base_path(), relative_path, separator="/",, temp);
    log("base_path: %", get_base_path());
    log("config.working_directory: %", config.working_directory);
    log("config.base_url: %", config.base_url);
    log("config.local_deployment: %", config.local_deployment);
    log("absolutized path: %", path);
    return path;
}

main :: () {
    // generate rendering procs
    // TODO: this should probably go into build.jai, but need to figure out how to allow both build program and main program to see the array of page rendering functions
    #insert -> string {
        load_config();
        builder: String_Builder;
        
        visit_proc :: (info: *File_Visit_Info, builder: *String_Builder) {
            // For some reason, full name here is already just path relative to current directory, so we just use that as input path.
            relative_path := info.full_name;
            advance(*relative_path, config.content_directory.count);
            // log("relative_path: %", relative_path);
            
            generate_page_renderer(builder, path_strip_extension(info.short_name), info.full_name);
            log("Generated rendering proc for page '%'", relative_path);
        }
        visit_files("content", true, *builder, visit_proc);
        
        return builder_to_string(*builder);
    }
    
    // run all template rendering procs
    // should probably not change the config between compile time and runtime, but putting #no_reset on config did not work (program crashed)
    load_config();
    
    for templates  log("%", it);
    
    for templates {
        // TODO: separate templates from actual content pages so we don't render them here.
        relative_path := it.source_path;
        advance(*relative_path, config.content_directory.count);
        
        output_path := join(config.public_directory, relative_path,, temp);
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
*/


#scope_module

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "Hash_Table";
#import "GON";
