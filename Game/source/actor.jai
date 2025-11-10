/*
    Anything which needs a persistent uuid and name and may be used as an external variable in a script can be an Actor.
    
*/

Actor :: struct {
    kind:       Kind;
    uuid:       UUID;
    name:       Name;
    
    script_variable_index:  int = -1;
    
    
    Name :: Static_String(16);
    UUID :: u64;
    Kind :: enum {
        NONE;
        TILEMAP;
        ENTITY;
        ENTITY_GROUP;
    }
    Handle :: struct {
        kind:   Kind;
        index:  int;
        uuid:   u64;
    }
}

get_actor_uuid :: () -> Actor.UUID {
    return random_get();
}

get :: (handle: Actor.Handle) -> bool, Any {
    if #complete handle.kind == {
        case .NONE;
        case .TILEMAP;      
            value_pointer := get(Tilemap_Handle.{ handle.index, handle.uuid });
            return value_pointer != null, Any.{ xx Tilemap, value_pointer };
        case .ENTITY;       
            value_pointer := get(Entity_Handle.{ handle.index, handle.uuid });
            return value_pointer != null, Any.{ xx Entity, value_pointer };
        case .ENTITY_GROUP; 
            value_pointer := get(Entity_Group_Handle.{ handle.index, handle.uuid });
            return value_pointer != null, Any.{ xx Entity_Group, value_pointer };
    }
    return false, NULL_ANY;
}

get_actor_handle :: (actor: *Actor) -> Actor.Handle {
    if #complete actor.kind == {
        case .NONE;
        case .TILEMAP;      return to_actor_handle(get_handle(actor.(*Tilemap)));
        case .ENTITY;       return to_actor_handle(get_handle(actor.(*Entity)));
        case .ENTITY_GROUP; return to_actor_handle(get_handle(actor.(*Entity_Group)));
    }
    return .{};
}

operator == :: (h1: Actor.Handle, h2: Actor.Handle) -> bool {
    return memcmp(*h1, *h2, size_of(Actor.Handle)) == 0;
}

to_actor_handle :: (handle: Entity_Handle) -> Actor.Handle {
    return .{ kind = .ENTITY, index = handle.index, uuid = handle.uuid };
}

to_actor_handle :: (handle: Tilemap_Handle) -> Actor.Handle {
    return .{ kind = .TILEMAP, index = handle.index, uuid = handle.uuid };
}

to_actor_handle :: (handle: Entity_Group_Handle) -> Actor.Handle {
    return .{ kind = .ENTITY_GROUP, index = handle.index, uuid = handle.uuid };
}


// so we can just #type,distinct for specific handle types
Generic_Handle :: struct {
    index:  int;
    uuid:   u64;
}

operator == :: (a: Generic_Handle, b: Generic_Handle) -> bool {
    return a.index == b.index && a.uuid == b.uuid;
}
