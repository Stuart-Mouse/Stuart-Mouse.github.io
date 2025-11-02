
/*
    Need coordinate system and camera movement functionality
    
    for now, will do the simplest thing just to get started
    coords will be 0-1 for a square with side length == smaller dimension of window (probably height)
    
*/



// a moving element within the visualization
// we will have an array of these whose properties will be evaluated for each frame by the main script
Viz_Point :: struct {
    name:         string;
    position:     Vector2;
    size:         Vector2;
    rotation:     float;
    color:        Color4;
    group_count:  int; // if this is >= 2 then we should declare and set_variable as an array 
}

Viz_Scene :: struct {
    viz_points:         [..] Viz_Point;
    script_source:      string;
    script:             LS.Script;
        
    init_time:          float;
    time_since_init:    float;
}

main_scene: Viz_Scene;

script_source_path :: "data/script.ls";

// callback directive for scripts to declare points by name
declare_viz_point :: (call: *LS.Directive_Call, scene: *Viz_Scene, name: string) -> bool {
    if call.phase == .PARSE {
        for scene.viz_points {
            if it.name == name {
                log("Error: cannot declare multiple viz points with the same name.");
                return false;
            }
        }
        
        new := array_add(*scene.viz_points);
        new.* = .{
            name     = name,
            size     = .{ 0.1, 0.1 },
            position = .{ 0.5, 0.5 },
            color    = .{ 1, 1, 1, 1 },
        };
        LS.declare_variable(*scene.script, name, Viz_Point);
    }
    return true;
}

declare_script_variables :: (scene: *Viz_Scene) {
    LS.declare_variable(*scene.script, "time", float);
}

set_script_variables :: (scene: *Viz_Scene) {
    LS.reset_external_variables(*scene.script);
    
    LS.set_variable(*scene.script, "time", scene.time_since_init);
    for scene.viz_points {
        LS.set_variable(*scene.script, it.name, it);
    }
}

load_script :: (scene: *Viz_Scene, source_path: string) {
    source, ok := read_entire_file(source_path);
    if !ok {
        log("Unable to load script source file: '%'!", source_path);
        return;
    }
    
    if !init_scene_script(scene, source)  return;
    
    #if OS == .WASM {
        js_set_script_source_text(scene.script_source.count, scene.script_source.data);
    }
}

init_scene_script :: (scene: *Viz_Scene, source: string) -> bool {
    array_reset_keeping_memory(*scene.viz_points);
    if scene.viz_points.allocator.proc == null {
        scene.viz_points.allocator = context.allocator;
    }
    
    LS.deinit_script(*scene.script);
    free(scene.script_source);
    
    scene.script_source = source;
    LS.init_script(*scene.script);
    
    scene.init_time = seconds_since_init().(float);
    declare_script_variables(scene);
    
    LS.register_directive(*scene.script, "declare", declare_viz_point, scene);
    
    LS.register_procedure(*scene.script, "fmod", #procedure_of_call fmod_cycling(1, 1));
    LS.register_procedure(*scene.script, "pow", pow);
    LS.register_procedure(*scene.script, "sin", sin);
    LS.register_procedure(*scene.script, "cos", cos);
    LS.register_procedure(*scene.script, "echo", (value: float) -> float { print("%\n", value); return value; });
    LS.register_procedure(*scene.script, "echo", (value: int) -> int { print("%\n", value); return value; });
    LS.register_procedure(*scene.script, "echo", (value: Vector2) -> Vector2 { print("%\n", value); return value; });
    LS.register_procedure(*scene.script, "circle", (lerp: float, phase: float) -> Vector2 { return .{ cos(lerp * 2 * PI), sin((lerp + phase) * 2 * PI) }; });
    LS.register_procedure(*scene.script, "ellipse", (lerp: float, x_timescale: float, y_timescale: float, phase: float) -> Vector2 { return .{ cos(lerp * x_timescale * 2 * PI), sin((lerp + phase) * y_timescale * 2 * PI) }; });
    LS.register_procedure(*scene.script, "rotate", #procedure_of_call rotate(Vector2.{}, 1.0));
    LS.register_procedure(*scene.script, "draw", #procedure_of_call draw(Viz_Point.{}));
    LS.register_procedure(*scene.script, "draw_square", draw_square);
    
    LS.register_type(*scene.script, "float",    float);
    LS.register_type(*scene.script, "int",      int);
    LS.register_type(*scene.script, "Vector2",  Vector2);
    
    if !LS.parse_source_file(*scene.script, scene.script_source) {
        report_script_error(scene);
        
        array_reset_keeping_memory(*scene.viz_points);
        LS.deinit_script(*scene.script);
        free(scene.script_source);
        scene.script = .{};
        return false;
    }
    
    #if OS == .WASM {
        js_set_script_source_text(scene.script_source.count, scene.script_source.data);
    }
    
    return true;
}

execute_script :: (scene: *Viz_Scene) {
    if !scene.script.flags & .TYPECHECKED  return;
    if LS.has_error(*scene.script)  return;
    
    set_script_variables(scene);
    if !LS.evaluate_script(*scene.script) {
        log("Error: Failed to execute script!");
        return;
    }
}


report_script_error :: (scene: Viz_Scene) {
    error_string := LS.format_error(*scene.script, false,, temp);
    log(error_string);
    #if OS == .WASM {
        js_set_script_error_message(error_string.count, error_string.data);
    }
}

#if OS == .WASM {
    js_set_script_error_message :: (count: s64, data: *void) #foreign;
    
    js_set_script_source_text :: (count: s64, data: *void) #foreign;
    js_get_script_source_text :: (data: *void) #foreign;
    
    #program_export
    compile_script :: () #c_call {
        push_context,defer_pop;
        source: string;
        js_get_script_source_text(*source);
        init_scene_script(*main_scene, source);
    }
}

