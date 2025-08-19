AT_COMPILE_TIME :: true;

// We don’t ship the Dear ImGui source with the compiler. Download a Dear ImGui release and update this path if you want to re-generate the bindings.
IMGUI_PATH    :: "src/imgui-1.89.6";
LIB_BASE_NAME :: "ImGui";

// Q: Is there anything to be gained by configuring imconfig.h in some way when compiling the library? Eg overriding what happens on assert.

DECLARATIONS_TO_OMIT :: string.[
    // We have custom declarations for these in module.jai:
    "ImVec2",
    "ImVec4",
    "ImColor",
    "ImVector",
    "ImDrawCallback",

    // Jai has its own, better "String_Builder"
    "ImGuiTextBuffer",
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        root_options := get_build_options();
        args := root_options.compile_time_command_line;
        if !generate_bindings(args) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        args := get_command_line_arguments();
        if !generate_bindings(args) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string) -> bool {
    target_android := array_find(args, "-android");
    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;
    if target_android  os_target  = .ANDROID;
    if target_x64      cpu_target = .X64;
    if target_arm      cpu_target = .ARM64;

    print("Generating bindings for % %\n", os_target, cpu_target);

    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        case .LINUX;
            lib_directory = "linux";
        case .MACOS;
            lib_directory = "macos";
        case .ANDROID;
            lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
        case;
            assert(false);
    }

    if compile {
        imgui_src_files: [..] string;
        array_add(*imgui_src_files, tprint("%/imgui.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_widgets.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_draw.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_tables.cpp", IMGUI_PATH));
        // @ToDo: Maybe add an option to exclude imgui_demo?
        array_add(*imgui_src_files, tprint("%/imgui_demo.cpp", IMGUI_PATH));

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;
        if os_target == .WINDOWS {
            success &&= build_cpp_dynamic_lib(lib_path, ..imgui_src_files, extra = .["/DIMGUI_API=__declspec(dllexport)"], debug=compile_debug);
            // We set IMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS. Otherwise all users of the ImGui module have to link against "imm32".
            success &&= build_cpp_static_lib(lib_path, ..imgui_src_files, extra = .["/DIMGUI_API=__declspec(dllexport)", "/DIMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS"], debug=compile_debug);

        } else if os_target == .LINUX {
            success &&= build_cpp_dynamic_lib(lib_path, ..imgui_src_files, debug=compile_debug);
            // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
            // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
            success &&= build_cpp_static_lib(lib_path, ..imgui_src_files, extra = .["-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics"], debug=compile_debug);

        } else if os_target == .MACOS {
            lib_path_x64   := tprint("%_x64"  , lib_path);
            lib_path_arm64 := tprint("%_arm64", lib_path);
            macos_x64_version_arg   := "-mmacos-version-min=10.13"; // Our current x64 min version
            macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64

            // x64 variant
            success &&= build_cpp_dynamic_lib(lib_path_x64,   ..imgui_src_files, extra = .["-arch", "x86_64", "-std=c++20", macos_x64_version_arg], debug=compile_debug);
            // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
            // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
            success &&= build_cpp_static_lib( lib_path_x64,   ..imgui_src_files, extra = .["-arch", "x86_64", "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", macos_x64_version_arg], debug=compile_debug);
            // arm64 variant
            success &&= build_cpp_dynamic_lib(lib_path_arm64, ..imgui_src_files, extra = .["-arch", "arm64",  "-std=c++20", macos_arm64_version_arg], debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_arm64, ..imgui_src_files, extra = .["-arch", "arm64",  "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", macos_arm64_version_arg], debug=compile_debug);
            
            // Create universal binaries
            #import "Process";
            run_result := run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path));
            success &&= (run_result.exit_code == 0);
            run_result =  run_command("lipo", "-create", tprint("%.a"    , lib_path_x64), tprint("%.a"    , lib_path_arm64), "-output", tprint("%.a"    , lib_path));
            success &&= (run_result.exit_code == 0);

        } else if os_target == .ANDROID {
            // @CopyPasta and tweaked from linux. Combine?

            extra: [] string;
            _, target_triple_with_sdk := get_android_target_triple(cpu_target);
            extra = .["-target", target_triple_with_sdk];

            success &&= build_cpp_dynamic_lib(lib_path, ..imgui_src_files, target = os_target, extra = extra, debug=compile_debug);
            
            // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
            // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link against libc++ or something. But do we really want to enforce that?
            extra = .["-target", target_triple_with_sdk, "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics",
                // NOTE(Charles): BuildCpp adds this automatically for dynamic lib. I was getting relocation errors when
                // linking imgui without this, seems weird I need to add here though?
                // Eg: ld.lld: error: relocation R_X86_64_PC32 cannot be used against symbol 'GImGui'; recompile with -fPIC
                "-fpic" 
            ];
            success &&= build_cpp_static_lib(lib_path, ..imgui_src_files, target = os_target, extra = extra, debug=compile_debug);

        } else {
            assert(false);
        }

        if !success  return false;
    }

    defer array_reset(*begin_end_string_args);

    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        os  = os_target;
        cpu = cpu_target;

        array_add(*libpaths, lib_directory);
        if os_target == .WINDOWS {
            output_filename = "windows.jai";

        } else {
            output_filename = "unix.jai";
            generate_library_declarations = false;
            footer = FOOTER_UNIX;
        }

        array_add(*libnames,      LIB_BASE_NAME);
        array_add(*include_paths, IMGUI_PATH);
        array_add(*source_files,  tprint("%/imgui.h", IMGUI_PATH));
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");
        array_add(*flatten_namespaces, "ImGui");
        array_add(*strip_prefixes, "ImGui");
        auto_detect_enum_prefixes = false;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
        strip_flags |= .INLINED_FUNCTIONS; // "inline" functions are not present in the static library.

        visitor   = imgui_visitor;
        get_func_args_for_printing = imgui_get_function_arg_for_printing;
    }

    return generate_bindings(opts, output_filename);
}

begin_end_string_args: [..]*Declaration;

enums_for_typedefs: Table(string, *Enum);

imgui_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    // ImGui has "typedef ints" for each enum. but we want to just use the enums directly,
    // so we get nice type safety, and .unary dots, etc.
    //
    // Look for declarations inside functions (i.e., arguments) or structs (i.e., fields)
    get_associated_enum_name :: (name: string) -> string {
        if name.count > 1 && name[name.count - 1] != #char "_" {
            return tprint("%_", name);
        }
        return name;
    }

    if !parent_decl {
        if array_find(DECLARATIONS_TO_OMIT, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
        if decl.name == "ImGuiContext" {
            decl.output_name = decl.name; // Don’t shorten ImGuiContext to Context as this would conflict
        }

        if decl.kind == .TYPEDEF {
            old_name := decl.name;
            if old_name {
                new_name := get_associated_enum_name(old_name);
                for context.generator.global_scope.members {
                    if it.kind != .ENUM  || it.name != new_name     continue;

                    en := cast(*Enum)it;

                    // Don't output the integer typedef
                    decl.decl_flags |= .OMIT_FROM_OUTPUT;

                    // Make sure the enums like "FocusFlags_" get outputted as "FocusFlags"
                    if en.output_name.count > 2 && en.output_name[en.output_name.count - 1] == #char "_" {
                        en.output_name.count -= 1;
                    }

                    // Keep the comment, if there is one:
                    if decl.comment.text && !en.comment.text {
                        en.comment = decl.comment;
                    }

                    table_add(*enums_for_typedefs, old_name, en);
                    break;
                }
            }
        }
    }

    // Look for function arguments with "typedef" types.
    if parent_decl &&
        (parent_decl.kind == .FUNCTION || parent_decl.kind == .STRUCT) &&
        decl.kind == .DECLARATION && decl.type.type_of_typedef != null
    {
        old_name := decl.type.type_of_typedef.name;
        if old_name {
            en, found := table_find(*enums_for_typedefs, old_name);
            if found {
                change_type_to_enum(decl, en);
            }
        }
    }

    if decl.kind == .ENUM {
        // ImGui has lots of enums that should be enum flags. Luckily, they all end in "…Flags_".
        if ends_with(decl.name, "Flags_") {
            en := cast(*Enum)decl;
            en.flags |= .IS_ENUM_FLAGS;
            en.flags |= .VALUES_IN_HEX;
        }
    }

    if decl.kind == .FUNCTION {
        func := cast(*Function)decl;
        type := func.type.type_of_function;
        // ImGui also has functions with pairs of arguments like "text_begin" and "text_end"
        // for the pointers to the beginning and end of a string. We'll generate wrappers for
        // those function which take a jai string.
        //
        // Here we collect pointers to "_begin" arguments, and use them in
        // get_func_args_for_printing below.
        for type.arguments {
            if it_index == 0 || !ends_with(it.name, "_end")     continue;
            arg_type := find_underlying_type(it.type);
            if !arg_type.pointer_to || !(arg_type.pointer_to.number_flags & ._8BIT) continue; // Only convert *u8 ranges to string

            name_part := slice(it.name, 0, it.name.count - "_end".count);
            if !name_part   continue;

            // the first arg may appear as "text_begin" or just "text"
            name_part_with_begin := tprint("%_begin", name_part);
            prev_arg := type.arguments[it_index - 1];
            if prev_arg.name == name_part || prev_arg.name == name_part_with_begin {
                array_add(*begin_end_string_args, prev_arg);
                func.decl_flags |= .NEEDS_ARGUMENT_WRAPPER;
            }
        }
    }

    return .RECURSE;
}

// Modify function with _begin and _end string arguments as they get printed.
// See the note above about "text_begin".
imgui_get_function_arg_for_printing :: (func: *Function, type: *Function_Type, mode: Arg_Print_Mode) -> []*Declaration {
    args: [..]*Declaration;
    for type.arguments {
        if array_find(begin_end_string_args, it) {
            if mode == {
                case .OUTER_WRAPPER;
                    // For the outer wrapper, remove any "_begin" part of the argument, and
                    // change its type to a jai string
                    arg_copy := New(Declaration);
                    (<<arg_copy) = <<it;
                    arg_copy.type = context.generator.type_def_jai_string;
                    if ends_with(it.name, "_begin") {
                        arg_copy.output_name = slice(it.name, 0, it.name.count - "_begin".count);
                    }
                    array_add(*args, arg_copy);

                    it_index += 1; // skip the next argument-we collpase the _begin and _end args into one string arg

                    continue;
                case .INNER_WRAPPER_CALL;
                    // For the inner wrapper function call, we pass the incoming arg
                    // as two arguments: "jai_string.data, jai_string.data + jai_string.count" -- corresponding
                    // to the _begin and _end parts.
                    base_arg_name := it.name;
                    if ends_with(it.name, "_begin") {
                        base_arg_name = slice(it.name, 0, it.name.count - "_begin".count);
                    }

                    arg_copy := New(Declaration);
                    (<<arg_copy) = <<it;
                    arg_copy.output_name = tprint("%.data", base_arg_name);
                    array_add(*args, arg_copy);

                    arg_copy_2 := New(Declaration);
                    (<<arg_copy_2) = <<it;
                    arg_copy_2.output_name = tprint("%.data + %.count", base_arg_name, base_arg_name);
                    array_add(*args, arg_copy_2);

                    it_index += 1; // skip the next arg, since we already added a second one above
                    continue;
            }
        }

        array_add(*args, it);
    }

    return args;
}

#import "Basic";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";
#import "Toolchains/Android";

FOOTER_UNIX :: #string END

#if OS == .MACOS {
    imgui :: #library "macos/ImGui";
} else #if OS == .LINUX {
    imgui :: #library "linux/ImGui";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        imgui :: #library "android/x64/ImGui";
    } else #if CPU == .ARM64 {
        imgui :: #library "android/arm64/ImGui";
    }
} else {
    #assert false "Unsupported platform!";
}

END
