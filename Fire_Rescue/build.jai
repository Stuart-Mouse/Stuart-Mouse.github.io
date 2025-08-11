

#run,stallable build();

build :: () {
    set_working_directory(#filepath);
    
    set_build_options_dc(.{do_output=false});
    build_options := get_build_options();

    // Create a workspace for the target program.
    w_target := compiler_create_workspace("Target Program");
    if !w_target {
        print("Workspace creation failed.\n");
        return;
    }
    
    target_options := get_build_options(w_target);
    target_options.output_executable_name = "game";
    
    build_dir := "build_debug";
    set_optimization(*target_options, .DEBUG);
    
    args := build_options.compile_time_command_line;
    for arg: args {
        if arg == {
          case "release";
            build_dir = "build_release";
            set_optimization(*target_options, .VERY_OPTIMIZED);
            target_options.array_bounds_check = .ON;
            target_options.null_pointer_check = .ON;
            target_options.arithmetic_overflow_check = .OFF;
            print("release build\n");
            
          case;
            compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug', 'release'.\n", it_index+1, arg));
        }
    }
    
    make_directory_if_it_does_not_exist(build_dir);
    target_options.output_path = build_dir;
    
    set_build_options(target_options, w_target);

    USING_IPROF :: false;
    #if USING_IPROF {
        iprof_plugin: *Iprof.My_Plugin;
        iprof_plugin = cast(*Iprof.My_Plugin) Iprof.get_plugin();
        iprof_plugin.workspace = w_target;
        
        // Set options
        // iprof_plugin.instrument_modules = true;
        // iprof_plugin.min_size = 100; // Hitting MAX_PROFILING_ZONES with the default of 30, so bumped up. What is the correct thing to do?
        // iprof_plugin.csv_output_filename = "iprof_report.csv"; // Disable this if we don't want to output the report.
        
        iprof_plugin.before_intercept(iprof_plugin, null);
    }

    compiler_begin_intercept(w_target);
    
    add_build_string(tprint("USING_IPROF :: %;", USING_IPROF), w_target);
    #if USING_IPROF  iprof_plugin.add_source(iprof_plugin);
    
    add_build_file("source/main.jai", w_target);
    
    while true {
        message := compiler_wait_for_message();

        #if USING_IPROF  iprof_plugin.message(iprof_plugin, message);

        if message.kind == {
            case .ERROR;
                print("\n"); // Seems to be some issue with exit() not flushing output, we miss errors!
                exit(1);

            case .COMPLETE;
                break;
        }
    }
    compiler_end_intercept(w_target);
    
    #if USING_IPROF {
        iprof_plugin.finish(iprof_plugin);
        iprof_plugin.shutdown(iprof_plugin);
    }
}

Iprof :: #import "Iprof"(IMPORT_MODE = .METAPROGRAM);

#import "Compiler";
#import "Basic";
#import "File";
