
/*
    Some custom extensions for the Enum_Tagged_Union type.
    Would also be nice to have some defined type coersions on the tagged union (e.g. float32 to float64)
    get_or_default(*u, float32, 5) ? can't do bc get returns a pointer 
    
    This tagged union implementation uses an enum for the tag instead of a Type, which makes it serializable.
    Although of course, if you change the order of the elements of value_types, then it will affect the underlying enum values assigned to each type tag.
*/

Enum_Tagged_Union :: struct (value_types: ..Type) {
    tag:            Tag;
    using value:    Value;
    
    Value :: union {
        #insert -> string {
            sb: String_Builder;
            for value_types  print_to_builder(*sb, "as_%1: %1;\n", it);
            return builder_to_string(*sb);
        }
    }
    
    // NOTE: Tag values are just the type names with an underscore prepended
    //       void is always included so that we can express an uninitialized union
    Tag :: enum {
        #insert -> string {
            sb: String_Builder;
            append(*sb, "_void :: 0;\n");
            for value_types  print_to_builder(*sb, "_%1;\n", it);
            return builder_to_string(*sb);
        }
    }
    
    tag_types :: #insert -> string {
        sb: String_Builder;
        append(*sb, "Enumerated_Array(Tag, Type).{\n");
        append(*sb, "_void = void,\n");
        for value_types  print_to_builder(*sb, "_%1 = %1,\n", it);
        append(*sb, "};");
        return builder_to_string(*sb);
    }
    
    // placed inside the struct namespace so that this gets overloaded per instantiation
    is_valid_type :: (t: Type) -> bool {
        return array_find(value_types, t);
    }
    
    // TODO: better handling for invalid type
    get_tag_for_type :: (t: Type) -> Tag { return get_tag_for_type(t.(*Type_Info)); };
    get_tag_for_type :: (t: *Type_Info) -> Tag {
        for tag_types  if xx it == t return it_index;
        return ._void;
    }
}

// statically typed set
set :: inline (u: *Enum_Tagged_Union, value: $T) {
    u.tag = #insert -> u.Tag {
        for u.tag_types  if it == T  return it_index;
        assert(false, "Type % is not a member of %", T, type_of(u.*));
    }
    memcpy(*u.value, *value, size_of(T));
}

// set from an Any
set_any :: (u: *Enum_Tagged_Union, value: Any) -> bool {
    for u.tag_types  if it == T {
        u.tag = it_index;
        memcpy(*u.value, value.value_pointer, value.type.runtime_size);
        return true;
    }
    return false;
}

// get the value of the tagged union as a certain type
get_as :: (u: Enum_Tagged_Union, $T: Type) -> *T {
    TAG :: #insert -> u.Tag {
        for u.tag_types  if it == T  return it_index;
        assert(false, "Type % is not a member of %", T, type_of(u.*));
    }
    if u.tag == TAG  return (*u.value).(*T);
    return null;
}

// get the value of the tagged union as an Any
// useful for printing the tagged union's value
get_as_any :: (using u: *Enum_Tagged_Union) -> Any {
    for u.tag_types  if it_index == u.tag {
        return Any.{ 
            type = it.(*Type_Info),
            value_pointer = *u.value,
        };
    }
    unreachable();
    return Any.{};
}

#scope_file

// get_biggest_size is used at compile-time by the #run in Enum_Tagged_Union.
get_biggest_size :: (types: [] Type) -> s64 {
    biggest: s64;

    // This cast to *Type_Info requires runtime_storageless_type_info to be disabled,
    // or for us to be running at compile-time. We know for sure in this case that we are
    // calling this routine at compile-time, but in runtime use, this kind of cast
    // presumes that Type_Info has been exported for all runtime types.
    for types  biggest = max(biggest, (cast(*Type_Info)(it)).runtime_size); 

    return biggest;
}

