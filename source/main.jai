
#add_context html_builder: *String_Builder;

// Template :: struct { type: *Type_Info_Procedure; ptr: *void; };
Template :: #type ();

#no_reset templates: Table(string, Template);



echo :: inline (t: $T) { print_to_builder(context.html_builder, "%", t); }

remove_trailing_newline :: (s: string) -> string { return ifx s[s.count-1] == #char "\n" then string.{ s.count-1, s.data } else s; }

// restores the value of a variable at this time upon scope exit
defer_restore :: (value: $T) #expand {
    value_before := value;
    `defer value = value_before;
}

// generates the rendering code for a page and adds it to the templates table
generate_page_renderer :: (name: string, path: string) -> string #compile_time {
    // TODO: check if we have already created a rendering function for this file
    _, found := table_find(*templates, name);
    if found  {
        log("Tried to generate duplicate render proc for page '%'", path);
        return "";
    }
    
    source, ok := read_entire_file(path);
    assert(ok, "Unable to load file at path '%'", path);
    
    // TODO: parameters?
    sb: String_Builder;
    print_to_builder(*sb, "table_add(*templates, \"%\", () {\n", name);
    append(*sb, "sb := context.html_builder;\n");
    
    in_code := false;
    current_string: string = .{ 0, source.data };    
    
    while loop := source {
        if !in_code {
            if begins_with(source, "<%") {
                if current_string.count > 0 {
                    print_to_builder(*sb, "append(sb, remove_trailing_newline(#string __inserted_html__\n%\n__inserted_html__));\n", current_string);
                }
                in_code = true;
                advance(*source, 2);
                current_string = .{ 0, source.data };
                continue loop;
            }
            
            if begins_with(source, "{{") {
                if current_string.count > 0 {
                    print_to_builder(*sb, "append(sb, remove_trailing_newline(#string __inserted_html__\n%\n__inserted_html__));\n", current_string);
                }
                advance(*source, 2);
                current_string = .{ 0, source.data };
                while source && !begins_with(source, "}}") {
                    advance(*source, 1);
                    current_string.count += 1;
                }
                advance(*source, 2);
                if current_string.count > 0 {
                    print_to_builder(*sb, "print_to_builder(sb, \"%%\", %);\n", current_string);
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
            print_to_builder(*sb, "append(sb, remove_trailing_newline(#string __inserted_html__\n%\n__inserted_html__));\n", current_string);
        }
    } else {
        if current_string.count > 0 {
            print_to_builder(*sb, "print_to_builder(sb, \"%%\", %);\n", current_string);
        }
    }
    
    append(*sb, "});\n");
    
    return builder_to_string(*sb);
}

call_template :: (name: string) {
    renderer, ok := table_find(*templates, name);
    assert(ok, "Failed to find template '%'", name);
    renderer();
}

settings: struct {
    templates:      [..] struct { name: string; input_path: string; output_path: string; };
    navbar_items:   [..] struct { name: string; path: string; };
};

load_settings :: () {
    file, ok := read_entire_file("settings.gon");
    assert(ok);
    
    parser:, ok = parse_file_to_dom(file);
    assert(ok);
    
    add_data_binding_to_dom(*parser, settings, "settings");
    
    ok = process_data_bindings(*parser);
    assert(ok);
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


#scope_module

#import "Basic";
#import "File";
#import "String";
#import "Hash_Table";
#import "GON";
