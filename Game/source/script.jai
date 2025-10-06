
Level_Script :: struct {
    using #as base: LS.Script;
    
    source:         string;
    random_state:   Random_State;
    random_seed:    u64;
}

deinit_level_script :: (script: *Level_Script) {
    LS.deinit_script(*script.base);
    free(script.source);
    script.* = .{};
}

execute_level_script_init_block :: (using level: *Level) {
    if !(script.flags & .TYPECHECKED)  return;
    
    init_block := LS.get_named_block(*script, "init");
    if !init_block  return;
    
    defer_restore(*context.current_level);
    context.current_level = level;
    
    random_seed(*script.random_state, script.random_seed);
    defer_restore(*context.random_state);
    context.random_state = script.random_state;
    
    script.stack_ptr = script.stack_base;
    if !LS.execute_node(*script, init_block, explicit_call = true) {
        log("Error: failed to execute script update!");
        log(LS.format_error(*script));
    }
}

load_level_script :: (using level: *Level, source_path: string) -> bool {
    using LS;
    
    deinit_level_script(*script);
    
    if !source_path  return true;
    
    source, ok := read_entire_file(join("data/scripts/", source_path,, temp));
    if !ok {
        log("Unable to load script source file: '%'!", source_path);
        return false;
    }
    script.source = source;
    
    init_script(script);
    
    register_type(script, "bool",    bool);
    register_type(script, "float",   float);
    register_type(script, "int",     int);
    register_type(script, "Vector2", Vector2);
    
    register_procedure(script, "entity_group", #procedure_of_call get_all_entities_in_group(0));
    register_procedure(script, "entity_group", #procedure_of_call get_all_entities_in_group(""));
    
    register_procedure(script, "set_next_offset", (entity: *Entity, offset: Vec2f) { 
        position := entity.init_position;
        
        if entity.attached_to.kind == {
          case .TILEMAP;
            position += get_tilemap_offset_from_root(context.current_level.tilemaps[entity.attached_to.index]);
            
          case .ENTITY;
            // TODO: this raises potential issues with order in which entities are updated
            parent := get(entity.attached_to.entity);
            if parent then position += get_position(parent);
        }
        
        entity.flags |= .POSITIONED_BY_SCRIPT;
        entity.offset_next = position + offset;
    });
    
    register_procedure(script, "set_position", (entity: *Entity, position: Vec2f) { 
        entity.flags |= .POSITIONED_BY_SCRIPT;
        entity.position = position;
    });
    
    register_procedure(script, "set_next_offset", (tilemap: *Tilemap, offset: Vec2f) { 
        tilemap.flags |= .POSITIONED_BY_SCRIPT;
        tilemap.offset_next = tilemap.root_offset + offset;
    });
    
    register_procedure(script, "immediate_fireball", immediate_fireball);
    register_procedure(script, "find_entity_template_index_by_name", find_entity_template_index_by_name);
    // register_procedure(script, "find_entity_template_index_by_uuid", find_entity_template_index_by_uuid);
    
    register_procedure(script, "offset_from_root", get_tilemap_offset_from_root);
    
    register_procedure(script, "degrees_to_radians", (d: float) -> float { return d / 180 * PI; });
    register_procedure(script, "fmod", #procedure_of_call fmod_cycling(1, 1));
    register_procedure(script, "pow", pow);
    register_procedure(script, "sin", sin);
    register_procedure(script, "cos", cos);
    register_procedure(script, "random_bool", () -> bool { return (random_get() & 1).(bool); });
    register_procedure(script, "random_int", (min: int, max: int) -> int { return min + (random_get() % (max-min+1).(u64)).(s64); });
    register_procedure(script, "random_float", #procedure_of_call random_get_within_range(.0, .0));
    
    // TODO: support passing Any in scripts
    echo :: (t: $T) -> T { print("%\n", t); return t; };
    register_procedure(script, "echo", #procedure_of_call echo(1.0));
    register_procedure(script, "echo", #procedure_of_call echo(1));
    register_procedure(script, "echo", #procedure_of_call echo(Vector2.{}));
    
    register_procedure(script, "cycle_over", (value: float, divisor: float) -> float { return fmod_cycling(value, divisor) / divisor; });
    register_procedure(script, "cycle_over_random", (value: float, min: float, max: float, randomize_offset: bool, randomize_direction: bool) -> float { 
        divisor := random_get_within_range(min, max);
        if randomize_offset {
            value += random_get_within_range(0, divisor);
        }
        lerp := fmod_cycling(value, divisor) / divisor;
        if randomize_direction && (random_get() & 1) {
            lerp = -lerp;
        }
        return lerp;
    });
    
    register_procedure(script, "circle", (lerp: float, phase: float) -> Vector2 { return .{ cos(lerp * 2 * PI), sin((lerp + phase) * 2 * PI) }; });
    register_procedure(script, "ellipse", (lerp: float, x_timescale: float, y_timescale: float, phase: float) -> Vector2 { 
        return .{ cos(lerp * x_timescale * 2 * PI), sin((lerp + phase) * y_timescale * 2 * PI) }; 
    });
    
    register_procedure(script, "distance", #procedure_of_call distance(Vector2.{}, Vector2.{}));
    
    register_procedure(script, "ellipse", (lerp: float, p1: Vec2f, p2: Vec2f, x_scale: float, y_scale: float, x_timescale: float, y_timescale: float, phase: float) -> Vector2 { 
        center   := (p1 + p2) / 2;
        dist     := distance(p1, p2);
        angle    := angle_between_points(p1, p2);
        
        position := Vec2f.{ dist * x_scale * cos(lerp * x_timescale * 2 * PI), y_scale * sin((lerp + phase) * y_timescale * 2 * PI) };
        position  = rotate(position, angle) + center;
        return position;
    });
    
    register_procedure(script, "rotate", #procedure_of_call rotate(Vector2.{}, 1.0));
    
    register_procedure(script, "pendulum", (lerp: float, dist: float, angle: float) -> Vector2 { 
        __lerp := 0.5 + (sin(lerp * 2 * PI) / 2) * angle;
        return .{ 
            dist * sin(2 * PI *  __lerp), 
            dist * sin(2 * PI * (__lerp - 0.25)) 
        }; 
    });
    
    
    // TODO: add more procedures and directives for imgui stuff
    
    register_procedure(script, "input_float", (id: string, v: *float) { 
        if Game.show_level_script_imgui {
            ImGui.InputFloat(temp_c_string(id), v);
        }
    });
    
    register_procedure(script, "input_vec2", (id: string, v: *Vec2f) { 
        if Game.show_level_script_imgui {
            ImGui.InputFloat2(temp_c_string(id), xx v);
        }
    });
    
    
    declare_script_variables(*script, layout);
    
    if !parse_source_file(*script, script.source, source_path) {
        log("Error: Failed to construct script from source!\n");
        log(format_error(*script));
        deinit_level_script(*script);
        return false;
    }
    
    return true;
}

// if null is passed for level, then we use context.current_level
execute_level_script :: (using level: *Level, show_imgui := false) {
    if !(script.flags & .TYPECHECKED)  return;
    
    defer_restore(*context.current_level);
    context.current_level = level;
    
    random_seed(*script.random_state, script.random_seed);
    defer_restore(*context.random_state);
    context.random_state = script.random_state;
    
    if show_imgui {
        ImGui.Begin("Level Script");
        Game.show_level_script_imgui = true;
    }
    
    set_script_variables(*script, layout);
    if !LS.execute_script(*script) {
        log("Error: failed to execute script update!");
        log(LS.format_error(*script));
    }
    
    if show_imgui {
        ImGui.End();
        Game.show_level_script_imgui = false;
    }
}

declare_script_variables :: (script: *Level_Script, level: *Level_Layout) {
    LS.declare_variable(script, "PI",  PI,  .CONSTANT);
    LS.declare_variable(script, "TAU", TAU, .CONSTANT);
    
    LS.declare_variable(script, "Game",   Game,         .STATIC);
    LS.declare_variable(script, "player", Game.player,  .STATIC);
    
    LS.declare_variable(script, "time", float);
    
    for level.tilemaps {
        name := to_string(it.name.data);
        if name  LS.declare_variable(script, name, Tilemap);
    }
    
    for *level.entities {
        name := to_string(it.name.data);
        if name  LS.declare_variable(script, name, Entity);
    }
}

set_script_variables :: (script: *Level_Script, level: *Level_Layout) {
    LS.reset_external_variables(script);
    
    LS.set_variable(script, "time", level.time_since_start);
    
    for *level.tilemaps {
        name := to_string(it.name.data);
        LS.set_variable(script, name, it.*);
    }
    
    for *level.entities {
        name := to_string(it.name.data);
        if name  LS.set_variable(script, name, it.*);
    }
    
    LS.check_external_variables(script);
}
