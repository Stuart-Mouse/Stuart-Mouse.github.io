
Level_Script :: struct {
    using #as base: LS.Script;
    
    source:         string;
    random_state:   Random_State;
    random_seed:    u64;
    
    virtual_member_storage: Virtual_Member_Storage;
}

deinit_level_script :: (script: *Level_Script) {
    LS.deinit_script(*script.base);
    free(script.source);
    
    for script.virtual_member_storage.entries {
        free(it.name);
    }
    array_free(script.virtual_member_storage.entries);
    
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
    
    set_script_variables(*script, layout);
    script.my_evaluate_node(*script, init_block, flags = .EXPLICIT_CALL);
    if LS.has_error(script) {
        log("Error: failed to execute script init!");
        log(LS.format_error(*script));
    }
}

load_level_script :: (using level: *Level, source_path: string) -> bool {
    using LS;
    
    deinit_level_script(*script);
    for *level.layout.entities {
        if it.flags & .CREATED_BY_SCRIPT {
            remove;
        }
    }
    
    if !source_path  return true;
    
    source, ok := read_entire_file(join("data/scripts/", source_path,, temp));
    if !ok {
        log("Unable to load script source file: '%'!", source_path);
        return false;
    }
    script.source = source;
    
    init_script(script);
    
    script.get_virtual_member = xx get_virtual_member;
    script.declare_virtual_member = xx declare_virtual_member;
    
    register_type(script, "bool",    bool);
    register_type(script, "float",   float);
    register_type(script, "int",     int);
    register_type(script, "Vector2", Vector2);
    
    register_procedure(script, "entity_group", #procedure_of_call get_all_entities_in_group(0));
    register_procedure(script, "entity_group", #procedure_of_call get_all_entities_in_group(""));
    
    // TODO: may need #procedure_of_call later on to disambiguate with tilemap groups
    register_procedure(script, "members_of", members_of);
    
    register_procedure(script, "palette_id", get_color_animation_index);
    
    register_procedure(script, "add_to_group", #procedure_of_call add_to_group(null.(*Entity), ""));
    register_procedure(script, "add_to_group", #procedure_of_call add_to_group(null.(*Entity), null.(*Entity_Group)));
    
    register_procedure(script, "remove_from_group", #procedure_of_call remove_from_group(null.(*Entity), ""));
    register_procedure(script, "remove_from_group", #procedure_of_call remove_from_group(null.(*Entity), null.(*Entity_Group)));
    
    register_procedure(script, "make_entity", (template_id: Entity_Template_ID, flags := Entity.Flags.NONE) -> Entity_Handle {
        _flags := flags | .CREATED_BY_SCRIPT;
        return make_entity(template_id, _flags);
    });
    
    register_procedure(script, "set_next_offset", (entity: *Entity, offset: Vec2f) { 
        position := entity.init_position;
        
        if entity.attached_to.kind == {
          case .TILEMAP;
            position += get_tilemap_offset_from_root(context.current_level.tilemaps[entity.attached_to.index]);
            
          case .ENTITY;
            // TODO: this raises potential issues with order in which entities are updated
            parent := get(Entity_Handle.{ entity.attached_to.index, entity.attached_to.uuid });
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
    register_procedure(script, "pow",  pow);
    register_procedure(script, "sin",  sin);
    register_procedure(script, "cos",  cos);
    register_procedure(script, "sqrt", sqrt);
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
            lerp = 1 - lerp;
        }
        return lerp;
    });
    
    register_procedure(script, "circle", (lerp: float, phase: float) -> Vector2 { 
        return .{ cos(lerp * 2 * PI), sin((lerp + phase) * 2 * PI) }; 
    });
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
    
    #if EDITOR_ENABLED {
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
    }
    
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
    if !(script.flags & .TYPECHECKED) || LS.has_error(script)  return;
    
    defer_restore(*context.current_level);
    context.current_level = level;
    
    random_seed(*script.random_state, script.random_seed);
    defer_restore(*context.random_state);
    context.random_state = script.random_state;
    
    #if EDITOR_ENABLED {
        if show_imgui {
            ImGui.Begin("Level Script");
            Game.show_level_script_imgui = true;
        }
    }
    
    set_script_variables(*script, layout);
    if !LS.evaluate_script(*script) {
        ImGui.Text("Error: failed to execute script update!");
        ImGui.Text(LS.format_error(*script));
    }
    
    #if EDITOR_ENABLED {
        if show_imgui {
            ImGui.End();
            Game.show_level_script_imgui = false;
        }
    }
}

declare_script_variables :: (script: *Level_Script, level: *Level_Layout) {
    LS.declare_variable(script, "PI",  PI);
    LS.declare_variable(script, "TAU", TAU);
    
    LS.declare_variable(script, "Game",   Game,         .STATIC);
    LS.declare_variable(script, "player", Game.player,  .STATIC);
    
    LS.declare_variable(script, "time", float);
    LS.declare_variable(script, "time_ignoring_tempo", float);
    
    for *level.tilemaps {
        name := to_string(*it.name);
        if name {
            ok:, it.script_variable_index = LS.declare_variable(script, name, Tilemap);
        }
    }
    
    for *level.entities {
        name := to_string(*it.name);
        if name {
            ok:, it.script_variable_index = LS.declare_variable(script, name, Entity);
        }
    }
    
    for *level.entity_groups {
        name := to_string(*it.id);
        if name {
            ok:, it.script_variable_index = LS.declare_variable(script, name, Entity_Group);
        }
    }
}

set_script_variables :: (script: *Level_Script, level: *Level_Layout) {
    LS.reset_external_variables(script);
    
    LS.set_variable(script, "PI",  PI);
    LS.set_variable(script, "TAU", TAU);
    
    LS.set_variable(script, "time", level.time_since_start * level.tempo);
    LS.set_variable(script, "time_ignoring_tempo", level.time_since_start);
    
    for *level.tilemaps {
        if it.script_variable_index != -1 {
            LS.set_variable_by_index(script, it.script_variable_index, it.*);
            LS.set_variable_name(script, it.script_variable_index, to_string(*it.name));
        }
    }
    
    for *level.entities {
        if it.script_variable_index != -1 {
            LS.set_variable_by_index(script, it.script_variable_index, it.*);
            LS.set_variable_name(script, it.script_variable_index, to_string(*it.name));
        }
    }
    
    for *level.entity_groups {
        if it.script_variable_index != -1 {
            LS.set_variable_by_index(script, it.script_variable_index, it.*);
            LS.set_variable_name(script, it.script_variable_index, to_string(*it.id));
        }
    }
    
    LS.check_external_variables(script);
}



Virtual_Member_Storage :: struct {
    entries: [..] Entry;
    
    Entry :: struct {
        owner:  Actor.Handle;
        name:   string;
        
        // Cannot use an Any do to serialization complexities, so instead we use a tagged union.
        using tagged_union: Tagged_Union;
        Tagged_Union :: Enum_Tagged_Union( int, float, bool, Vec2i, Vec2f );
    }
}

get_virtual_member_owner_handle :: (script: *Level_Script, owner: Any) -> bool, Actor.Handle {
    // TODO: @Hack currently just implicitly dereferencing owner Any if it is a pointer 
    //       so that we can handle if the given type is a *Entity instead of Entity
    _owner := dereference_any_pointer(owner);
    
    if Compiler.is_subclass_of(_owner.type, "Actor") {
        handle := get_actor_handle(_owner.value_pointer.(*Actor));
        if handle.uuid == 0 {
            log("Error: Virtual members owner handle was invalid: %", handle);
        }
        return handle.uuid != 0, handle;
    }
    
    log("Error: Virtual members cannot be used on type: %", as_type(_owner.type));
    return false, .{};
}

// TODO: remove type parameter after reimplementing virtual member declarations as a separate thing
get_virtual_member :: (script: *Level_Script, owner: Any, member_name: string) -> bool, Any {
    ok, owner_handle := get_virtual_member_owner_handle(script, owner);
    if !ok  return false, NULL_ANY;
    
    for script.virtual_member_storage.entries {
        if it.owner == owner_handle && it.name == member_name {
            return true, get_as_any(*it.tagged_union);
        }
    }
    
    // TODO: once we reimplement virtual member declarations, we should not just declare by default here
    //       instead, we should return some error for attempt to get undeclared virtual member
    // ok=, value := declare_virtual_member(script, owner_handle, member_name, type);
    // return ok, value;
    
    // TODO: write proc for getting formatted name representing object of General_Handle
    log("Error: Attempt to get undeclared virtual member '%' on %", member_name, owner_handle);
    return false, NULL_ANY;
}

declare_virtual_member :: (script: *Level_Script, owner: Any, member_name: string, type: *Type_Info) -> bool, Any, bool {
    ok, owner_handle := get_virtual_member_owner_handle(script, owner);
    if !ok  return false, NULL_ANY, false;
    
    ok=, value, redeclared := declare_virtual_member(script, owner_handle, member_name, type);
    return ok, value, redeclared;
}

declare_virtual_member :: (script: *Level_Script, owner_handle: Actor.Handle, member_name: string, type: *Type_Info) -> bool, Any, bool {
    for script.virtual_member_storage.entries {
        if it.owner == owner_handle && it.name == member_name {
            value := get_as_any(*it.tagged_union);
            if value.type != type {
                log("Error: Attempt to redeclare virtual member '%' from type '%' to '%'", member_name, as_type(value.type), as_type(type));
                return false, NULL_ANY, true;
            }
            return true, value, true;
        }
    }
    
    ok, type_tag := Virtual_Member_Storage.Entry.get_tag_for_type(type);
    if !ok {
        log("Error: Unable to create new virtual member with unsupported type: %", as_type(type));
        return false, NULL_ANY, false;
    }
    
    new := array_add(*script.virtual_member_storage.entries);
    new.owner = owner_handle;
    new.name  = copy_string(member_name);
    new.tag   = type_tag;
    
    return true, get_as_any(*new.tagged_union), false;
}

get_virtual_members :: (script: *Level_Script, handle: Actor.Handle) -> [] *Virtual_Member_Storage.Entry {
    entries: [..] *Virtual_Member_Storage.Entry;
    for *script.virtual_member_storage.entries {
        if it.owner == handle {
            array_add(*entries, it);
        }
    }
    return entries;
}
