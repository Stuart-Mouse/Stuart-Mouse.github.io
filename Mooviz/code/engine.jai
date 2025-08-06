
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
        LS.set_variable(*scene.script, name, new.*);
    }
    return true;
}

set_script_variables :: (scene: *Viz_Scene) {
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
    
    // js_set_script_source_text(scene.script_source.count, scene.script_source.data);
}

init_scene_script :: (scene: *Viz_Scene, source: string) -> bool {
    log("init scene script");
    
    array_reset_keeping_memory(*scene.viz_points);
    if scene.viz_points.allocator.proc == null {
        scene.viz_points.allocator = context.allocator;
    }
    
    LS.free_script(*scene.script);
    free(scene.script_source);
    
    scene.script_source = source;
    LS.init_script(*scene.script);
    
    scene.init_time = seconds_since_init().(float);
    set_script_variables(scene);
    
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
    
    LS.register_type(*scene.script, "float", type_info(float));
    LS.register_type(*scene.script, "int",   type_info(int));
    LS.register_type(*scene.script, "Vector2",   type_info(Vector2));
    
    if !LS.parse_source_file(*scene.script, scene.script_source) {
        report_script_error(scene);
        
        array_reset_keeping_memory(*scene.viz_points);
        LS.free_script(*scene.script);
        free(scene.script_source);
        return false;
    }
    
    js_set_script_source_text(scene.script_source.count, scene.script_source.data);
    
    return true;
}

execute_script :: (scene: *Viz_Scene) {
    if !scene.script.flags & .TYPECHECKED  return;

    set_script_variables(scene);
    if !LS.execute_script(*scene.script) {
        log("Error: Failed to execute script!");
        return;
    }
}

/*
    We will need to have a #init section of script that will do the initial setup
    or some kind of mechanism for the initial creation of the points and giving them names.
    
    Ideally, we could declare all of the points that will be used in the scene in the header of the script
    this would just be a simple function call like "create_point(name)" or somthing
    but then this would require us to have strings as a concept in the scripts
    
    then after this block executes, we would actually need to come back out of the script to set more variables in the script context?
    maybe not, we could set the variables in the create_point procedure
    but we don't want to have to pass the scene explicitly
    so maybe need a set_context proc for script that lets us pass a single *void context pointer for user?
    
    ok, so say we have strings and context ptr 
    now when we construct the script, we need to fully construct and run the #init block
    then proceed with constructing the rest of the script
    this is also basically just a #run block i guess
    
    
    couple new ideas
    
    lexer directives
    
    #declare(ident1, ident2, ...)
        caller gets nodes, or just tokens and can handle them individually
        [] *Node    
    
    direct insertion of new statements at runtime
    
    we could put an identifier on a block and then use that ident to look up the block later
    then we could dynamically compile and append new statements to the block
    done in a mamanged way, this could allow us to dynamically add and remove new viz points with their own expressions
    
    the less ideal part here is that we still want to be able to write new subexpressions
        there's no reason we couldn't have a general block though for just declaring subexpressions and then a separate block for the update loop
        but managing when/where these blocks run could get confusing
        also, there is a problem to solve in regards to how we allocate new intermediates once stack base has already been set
        we would need a sub-allocator that gets blocks from variables/constants/intermediates section and divvys those out at runtime
        and then if we run out of space and need to move the stack, that's another added complexity...
    
    ***
    so, for now probably just want to add subexpressions, some lexer callback for declaring viz points, and 
    but we will also want to export variables declared in script so that we can edit them visually, or at least in imgui menu
    ***
    
    as far is the user is concerned, there's probably not much difference to the experience if we got he route of just 
    fully recompiling script on edit vs appending statements to blocks dynamically
    the main benefit of individually appending statements is that we can have a compile error on just that one statement while the rest continues running
    
    we could have some kind of 'try' keyword that would allow a statement to fail and then just continue with execution
    but then a statement should never fail to execute
        though it could certainly fail to evaluate
    #try to try compiling a statement, but if that statement fails to compile, just ignore it 
        well report the error, but remove the node from AST so taht it does not kill next stage of compilation or execution
    
    maybe it would be much easier to implement some of these higher-level features if we re-implement the evaluate procs
        then user can be much more maleable about how they run statements within a script
        maybe we could be more liberal about using remap_data as well, at least between numeric types
            though that could make a mess... 
    
    it would be nice to be able to have some setup where statements within a script are each their own strings which are lexed an typechecked individually
    statements within a script are still all run in a linked-list fashion, so this would be no different
    its just that we would attempt to recompile each statement each time it is changed
    and if the statement fails to compile then we will skip it during evaluation
    
    definitely some kinks to work out there though
    
    probably not worthwhile at the moment
    putting individual statements in their own text entry boxes e.g. imgui input text woiuld suck
    but then we can't really just put everything in one file/string either
        we could technically try to recover after even a lexer error by just going to the next semicolon and trying again
        but if we have a lexer error we will basically certainly have another type of error
    
    even if we do a full recompile on scripts, we can still get relatively seamless behavior on success by just not resetting the start_time value
    
    
    could even create imgui-esque elements dynamically in the script that get exported
    for example, 
    in script:
        width := slide_handle_x(vp_oval.position, -5, 5);
        
        vp_oval.offset = Vec2(width * cos(oval_cycle_time), sin(oval_cycle_time));
    
    in code:
        slide_handle_x :: (base_position: Vector2, min_offset: float, max_offset: float) -> float { 
            // renders a handle on the screen that user can drag left/right
            // it is rendered relative to the base_position provided and returns x offset from that position
            // and of course this is all done in world coords
            
            // would actually be better if we passed this the viz point instead of position
            // that way we could check for some flag on point to know whether we should render its associated handles
        }
    
    
    this would make lead sheets an incredibly powerful way to edit levels, since we can essentially write new funcitonality into the editor dynamically
    but then all of this is only for the purposes of building the level. once it comes time to actually run the levels ingame, we don't have all the extra overhead
    
    the more dynamic source versions of script which include things like adjustable handles could then be further compiled down into AST's that remove the handles and instead replace them with the final literal values
    and then of course that optimized ast could be lowered all the way down to bytecode or even assembly
    
    
    change declare function to accept count parameter, which will optionally declare an array of points instead of a single point
    this will make it trivial to implement spreading points along path and no need for some kind of macro system or anything like that
        tried this and it didnt really work, because we need some extra state to manage the groupings of elements
        not that it couldn't be made to work, but it would require some more work
    
    parametric expressions
    will be simpler to implement than function calls since it will just copy the ast nodes and replace the parameterized values
    
    $<identifier> refers to a parametric expression
    $<number> refers to a parameter of a parametric expression, a lot like %<number> in Jai's print
    
    $circle := Vec2(cos($1 * TAU), sin(($1 + $2) * TAU)) * $3;
    
    planet.position = $circle(time, phase, radius);
    
    but maybe it would be useful to name the parameter values in a parametric expression
    more powerful version would be to just do proper macros
    may actually steal rust ! syntax for this as its very simple, but also clear that we're calling a macro
    macros are sort of like in C, except not purely textual so they just insert whatever nodes they are given at the call site into the invocation
    
    circle!(lerp, phase, radius) :: Vec2(cos(lerp * TAU), sin((lerp + phase) * TAU)) * radius;
    
    This macro is an exression, but macro could be a statement as well maybe
    the ! is included as part of the identifier, probably?
    
    planet.position = circle!(time, phase, radius);
    
    
*/

report_script_error :: (scene: Viz_Scene) {
    error_string := LS.format_error(scene.script.error, false,, temp);
    log(error_string);
    js_set_script_error_message(error_string.count, error_string.data);
}

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
