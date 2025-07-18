
#add_context html_builder: *String_Builder;

// Template :: struct { type: *Type_Info_Procedure; ptr: *void; };
Template :: #type ();

#no_reset templates: Table(string, Template);



// macros to make code gen cleaner
write_var  :: inline (var: $T) { print_to_builder(context.html_builder, "%", var); }
write_html :: inline (html: string) { append(context.html_builder, remove_trailing_newline(html)); }


remove_trailing_newline :: (s: string) -> string { return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; }

// restores the value of a variable at this time upon scope exit
defer_restore :: (value: $T) #expand {
    value_before := value;
    `defer value = value_before;
}

// generates the rendering code for a page and adds it to the templates table
generate_page_renderer :: (name: string, path: string) -> string #compile_time {
    // TODO: check if we have already created a rendering function for this file
    found := table_find_new(*templates, name);
    if found  {
        log("Tried to generate duplicate render proc for page '%'", path);
        return "";
    }
    
    source, ok := read_entire_file(path);
    assert(ok, "Unable to load file at path '%'", path);
    
    // TODO: parameters?
    sb: String_Builder;
    print_to_builder(*sb, "table_add(*templates, \"%\", () {\n", name);
    
    in_code := false;
    current_string: string = .{ 0, source.data };    
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<%") {
                if current_string.count > 0 {
                    print_to_builder(*sb, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    print_to_builder(*sb, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
                }
                advance(*source, 2);
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "}}") {
                    advance(*source, 1);
                    current_string.count += 1;
                }
                advance(*source, 2);
                if current_string.count > 0 {
                    print_to_builder(*sb, "write_var(%);\n", current_string);
                }
                current_string = .{ 0, source.data };
                continue loop;
            }
        }
        else {
            if begins_with(source, "%>") {
                if current_string.count > 0 {
                    append(*sb, current_string);
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
            print_to_builder(*sb, "write_html(#string _inserted_html_\n%\n_inserted_html_);\n", current_string);
        }
    } else {
        if current_string.count > 0 {
            append(*sb, current_string);
        }
    }
    
    append(*sb, "});\n");
    
    return builder_to_string(*sb);
}

call_template :: (name: string) {
    ok, renderer := table_find_new(*templates, name);
    assert(ok, "Failed to find template '%'", name);
    renderer();
}

settings: struct {
    templates:          [..] struct { name: string; input_path: string; output_path: string; };
    navbar_items:       [..] struct { name: string; path: string; };
    base_url:           string;
    local_deployment:   bool;
};

working_directory:  string;

load_settings :: () {
    file, ok := read_entire_file("settings.gon");
    assert(ok);
    
    parser:, ok = parse_file(file);
    assert(ok);
    
    add_data_binding(*parser, settings, "settings");
    
    ok = process_data_bindings(*parser);
    assert(ok);
    
    working_directory = get_working_directory();
}

get_base_path :: () -> string {
    return ifx settings.local_deployment 
        then working_directory 
        else settings.base_url;
}

make_path_absolute :: inline (relative_path: string) -> string {
    return join(get_base_path(), relative_path, separator="/",, temp);
}

main :: () {
    // generate rendering procs
    #insert -> string {
        load_settings();
        sb: String_Builder;
        for settings.templates {
            print_to_builder(*sb, "#insert #run generate_page_renderer(\"%\", \"%\");\n", it.name, it.input_path);
            log("Generated rendering proc for page '%'", it.input_path);
        }
        return builder_to_string(*sb);
    }
    
    // run all template rendering procs
    // should probably not change the settings between compile time and runtime, but putting #no_reset on settings did not work (program crashed)
    load_settings();
    for settings.templates {
        if !it.output_path  continue;
        log("Rendering page '%' to '%'", it.input_path, it.output_path);
        
        sb: String_Builder;
        call_template(it.name,, html_builder = *sb);
        write_entire_file(it.output_path, builder_to_string(*sb));
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
            game dev
                pong, mario, and zelda engines in Odin
            blog posts
            
    
    Improving jhtml stuff:
        add ability to put parameters on a template
        add ability to use markdown files as base instead of html
        parse html lexically and construct a real DOM that we can introspect and modify
*/


#scope_module

#import "Basic";
#import "File";
#import "String";
#import "Hash_Table";
#import "GON";
