
init: {
    platform_count := random_int(3, 6);
    for 1..platform_count {
        entity := make_entity(template_id);
        add_to_group(entity, "wheel_platforms");
    }
}





{
    // TODO: create marker entity to use which does not inherently move
    center := wheel.position;
    
    wheel_radius :: 5.0?
    
    // TODO: need to be able to do immediate-mode platform entities, or else just set up the entities in the init block
    cycle_offset := random_float(0, 1);
    
    platforms := entity_group("wheel_platforms");
    for platform: platforms {
        it_cycle_offset := (offset + it_index.(float)/platforms.count.(float)) * TAU;
        unit := unit_vector_given_angle(it_cycle_offset);
        
        offset := center + unit * wheel_radius;
        set_next_offset(platform, offset);
    }
    
    
}

