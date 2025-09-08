
// TODO: optionally pass *Context to callback?
InputTextDynamicCallbackUserData :: struct {
    buf:                    *[..] u8;
    ChainCallback:          InputTextCallback;
    ChainCallbackUserData:  *void;
}

InputTextDynamicCallback : InputTextCallback : (data: *InputTextCallbackData) -> s32 #c_call {
    new_context: #Context;
    push_context new_context {
        user_data := cast(*InputTextDynamicCallbackUserData) data.UserData;
        if data.EventFlag == .CallbackResize {
            new_len := cast(u32) data.BufTextLen;
            if new_len+1 >= user_data.buf.allocated {
                new_cap := max(8, user_data.buf.allocated, next_power_of_2(new_len+1));
                array_reserve(user_data.buf, new_cap);
                data.Buf = user_data.buf.data;
            }
            user_data.buf.count = new_len;
            return 0;
        }
        if user_data.ChainCallback != null {
            data.UserData = user_data.ChainCallbackUserData;
            return user_data.ChainCallback(data);
        }
    }
    return 0;
}

InputText :: inline (label: *u8, buf: []u8, flags: InputTextFlags = .None, callback: InputTextCallback = null, user_data: *void = null) -> bool {
    return InputText(label, buf.data, xx buf.count, flags, callback, user_data);
}

InputText :: inline (label: *u8, ss: *Static_String, flags: InputTextFlags = .None, callback: InputTextCallback = null, user_data: *void = null) -> bool {
    result := InputText(label, ss.data.data, xx capacity+1, flags, callback, user_data);
    if result  ss.count = strlen(ss.data.data);
    return result;
}

InputTextDynamic :: (
    label:      *u8, 
    buf:        *[..] u8, 
    flags:      InputTextFlags    = .None, 
    callback:   InputTextCallback = null, 
    user_data:  *void             = null
) -> bool {
    if !buf.data || !buf.count {
        array_reserve(buf, 8);
        buf.data[0] = 0;
    }
    cb_user_data: InputTextDynamicCallbackUserData = .{
        buf                   = buf,
        ChainCallback         = callback,
        ChainCallbackUserData = user_data,
    };
    return InputText(label, buf.data, buf.allocated.(u64), flags | .CallbackResize, InputTextDynamicCallback, *cb_user_data);
}

// InputTextWithHintDynamic :: (
//     label     : *u8, 
//     hint      : *u8, 
//     buf       : *[..] u8, 
//     flags     : InputTextFlags    = xx 0, 
//     callback  : InputTextCallback = null, 
//     user_data : *void                   = null
// ) -> bool {
//     cb_user_data : InputTextDynamicCallbackUserData = .{
//         buf                   = buf,
//         ChainCallback         = callback,
//         ChainCallbackUserData = user_data,
//     };
//     return InputTextWithHint(label, hint, *buf.*[0], buf.allocated, flags | .CallbackResize, InputTextDynamicCallback, *cb_user_data);
// }

// InputTextMultilineDynamic :: (
//     label     : *u8, 
//     buf       : *[..] u8, 
//     size      : Vector2                 = .{}, 
//     flags     : InputTextFlags    = xx 0, 
//     callback  : InputTextCallback = null, 
//     user_data : *void                   = null
// ) -> bool {
//     cb_user_data : InputTextDynamicCallbackUserData = .{
//         buf                   = buf,
//         ChainCallback         = callback,
//         ChainCallbackUserData = user_data,
//     };
//     return InputTextMultiline(label, *buf.*[0], buf.allocated, size, flags | .CallbackResize, InputTextDynamicCallback, *cb_user_data);
// }

ComboTypes :: (
    label:             *u8,
    value:             *Type,
    types:             [] Type, 
    combo_flags:       ComboFlags      = .None, 
    selectable_flags:  SelectableFlags = .None
) {
    if BeginCombo(label, tprint("%\0", value).data, combo_flags) {
        for types {
            if Selectable(
                label    = tprint("%\0", it).data, 
                selected = value.* == it, 
                flags    = selectable_flags
            ) {
                value.* = it;
            }
        }
        EndCombo();
    }
}

// returns true if value was changed
ComboEnum :: (
    label:              *u8,
    value:              *$T, 
    selectable_values:  ..T,
    combo_flags:        ComboFlags      = .None, 
    selectable_flags:   SelectableFlags = .None
) -> bool #modify {
    return T.(*Type_Info).type == .ENUM;
} {
    enum_ti := T.(*Type_Info_Enum);
    
    current_value_index := 0;
    for enum_ti.values {
        if value.* == it.(T) {
            current_value_index = it_index;
            break;
        }
    }
    current_value_name := enum_ti.names[current_value_index];
    
    new_value := value.*;
    if BeginCombo(label, current_value_name.data, combo_flags) {
        for name: enum_ti.names {
            if selectable_values && !array_find(selectable_values, enum_ti.values[it_index].(T)) then continue;
            if Selectable(
                label    = name.data, 
                selected = value.* == enum_ti.values[it_index].(T), 
                flags    = selectable_flags
            ) {
                new_value = enum_ti.values[it_index].(T);
            }
        }
        EndCombo();
    }
    
    // set value to new value after evaluating return value condition
    defer value.* = new_value;
    return value.* != new_value;
}


ComboEnumDynamic :: (
    label:              *u8,
    value:              Any, 
    combo_flags:        ComboFlags      = .None, 
    selectable_flags:   SelectableFlags = .None
) -> bool {
    if value.type.type != .ENUM  return false;
    ti_enum := value.type.(*Type_Info_Enum);
    
    s64_value: s64;
    dynamic_int_cast(s64_value, value);
    s64_value_before := s64_value;
    
    found, current_value_index := array_find(ti_enum.values, s64_value);
    if !found then current_value_index = 0;
    
    current_value_name  := ti_enum.names[current_value_index];
    
    if BeginCombo(label, current_value_name.data, combo_flags) {
        for name: ti_enum.names {
            if Selectable(
                label    = name.data, 
                selected = s64_value == ti_enum.values[it_index], 
                flags    = selectable_flags
            ) {
                s64_value = ti_enum.values[it_index];
            }
        }
        EndCombo();
    }
    
    dynamic_int_cast(value, s64_value);
    return s64_value == s64_value_before;
}

ComboArrayOfStructs :: (
    label:              *u8,
    array:              []$T, 
    selected_index:     *int,
    $name_member:       string,
    combo_flags:        ComboFlags      = .None, 
    selectable_flags:   SelectableFlags = .None
) -> bool #modify {
    if T.(*Type_Info).type != .STRUCT  return false, "T must be a struct!";
    if name_member == ""  return false, "Name member must be provided!";
    name_member_info := get_field(xx T, name_member);
    if !get_field(xx T, name_member)  return false, "No such member in struct!";
    
    if !(name_member_info.type.type == .STRING
     || (name_member_info.type.type == .ARRAY && name_member_info.type.(*Type_Info_Array).element_type.runtime_size == 1)
    ) return false, "Name member must be a string or a []u8!";
    
    return true;
} {
    get_name :: (foo: T) -> string { 
        #insert -> string {
            info := get_field(xx T, name_member);
            
            if info.type.type == {
              case .STRING;
                return tprint("return foo.%;", name_member);
              case .ARRAY;
                assert(info.type.(*Type_Info_Array).element_type.runtime_size == 1);
                return tprint("return to_string(foo.%.data);", name_member);
              case; 
                assert(false);
            }
            return "";
        }
    };
    
    if array.count == 0  return false;
    
    if selected_index.* < 0 || selected_index.* >= array.count {
        selected_index.* = 0;
    }
    selected_name := get_name(array[selected_index.*]);
    
    // log("%:%", selected_index.*, selected_name);
    
    new_value := selected_index.*;
    if ImGui.BeginCombo(label, tprintc("%###%", selected_name, selected_index.*), combo_flags) {
        for array {
            element_name := get_name(it);
            if ImGui.Selectable(
                label    = tprintc("%###%", element_name, it_index), 
                selected = selected_index.* == it_index,
                flags    = selectable_flags
            ) {
                new_value = xx it_index;
            }
        }
        ImGui.EndCombo();
    }
    
    // set value to new value after evaluating return value condition
    defer selected_index.* = new_value;
    return selected_index.* != new_value;
}

TreeNodeAny :: (
    label: *u8,
    value: Any,
    flags: TreeNodeFlags = .None
) {
    if value.type.type == {
      case .STRUCT;
        if TreeNodeEx(label, flags) {
            ti_struct := value.type.(*Type_Info_Struct);
            last_member_offset := -1;
            for ti_struct.members {
                if it.flags & .CONSTANT  continue;
                if it.offset_in_bytes <= last_member_offset  continue; // skips #place members
                last_member_offset = it.offset_in_bytes;
                TreeNodeAny(it.name.data, Any.{ it.type, value.value_pointer + it.offset_in_bytes }, flags);
            }
            TreePop();
        }
        
      case .ARRAY;
        count, data := get_array_count_and_data(value.value_pointer, xx value.type);
        is_open := TreeNodeEx(label, flags);
        SameLine();
        TextDisabled("% elements", count);
        if is_open {
            ti_array := value.type.(*Type_Info_Array);
            member_any := Any.{ ti_array.element_type, data };
            for 0..count-1 {
                TreeNodeAny(tprint("[%]\0", it).data, member_any, flags);
                member_any.value_pointer += ti_array.element_type.runtime_size;
            }
            TreePop();
        }
        
      case .ENUM;
        ComboEnumDynamic(label, value);
        
      case .INTEGER; #through;
      case .FLOAT;
        InputAnyScalar(label, value);
        
      case .BOOL;
        Checkbox(label, xx value.value_pointer);
        
      case;
        BulletText("%: \"%\"", label, value);
    }
}

// NOTE: assumes we are already in a table 3 columns: Name, Value, Type
TableTreeNodeAny :: (
    label: string,
    value: Any,
    flags: TreeNodeFlags = .None
) {
    name_column :: inline (label: string, flags: TreeNodeFlags) {  
        TreeNodeEx(temp_c_string(label), flags);
    }
    type_column :: inline (value: Any) {  
        TableNextColumn();
        Text("%", (*value.type).(*Type).*);
    }
    
    TableNextRow(); TableNextColumn();
    if value.type.type == {
      case .STRUCT;
        is_open := TreeNodeEx(temp_c_string(label), flags | .SpanFullWidth);
        TableNextColumn();
        if !is_open  Text("%", value);
        type_column(value);
        if is_open {
            ti_struct := value.type.(*Type_Info_Struct);
            last_member_offset := -1;
            for ti_struct.members {
                if it.flags & .CONSTANT  continue;
                if it.offset_in_bytes <= last_member_offset  continue;
                last_member_offset = it.offset_in_bytes;
                TableTreeNodeAny(it.name, Any.{ it.type, value.value_pointer + it.offset_in_bytes }, flags);
            }
            TreePop();
        }
        
      case .ARRAY;
        count, data := get_array_count_and_data(value.value_pointer, xx value.type);
        is_open := TreeNodeEx(temp_c_string(label), flags | .SpanFullWidth);
        TableNextColumn();
        if !is_open  TextDisabled("% elements", count);
        type_column(value);
        if is_open {
            ti_array := value.type.(*Type_Info_Array);
            member_any := Any.{ ti_array.element_type, data };
            for 0..count-1 {
                TableTreeNodeAny(tprint("[%]\0", it), member_any, flags);
                member_any.value_pointer += ti_array.element_type.runtime_size;
            }
            TreePop();
        }
        
      case .ENUM;
        name_column(label, flags | .Leaf | .Bullet | .NoTreePushOnOpen | .SpanFullWidth);
        TableNextColumn();
        SetNextItemWidth(-FLOAT32_MIN);
        // NOTE: we append '_value' to the end of the id here so that it doesn't conflict with the name column
        ComboEnumDynamic(tprint("%_value\0", label).data, value);
        type_column(value);
        
      case .INTEGER; #through;
      case .FLOAT;
        name_column(label, flags | .Leaf | .Bullet | .NoTreePushOnOpen | .SpanFullWidth);
        TableNextColumn();
        SetNextItemWidth(-FLOAT32_MIN);
        InputAnyScalar(tprint("%_value\0", label).data, value);
        type_column(value);
        
      case .BOOL;
        name_column(label, flags | .Leaf | .Bullet | .NoTreePushOnOpen | .SpanFullWidth);
        TableNextColumn();
        RadioButton(tprint("%_value\0", label).data, xx value.value_pointer);
        type_column(value);
        
      case;
        name_column(label, flags | .Leaf | .Bullet | .NoTreePushOnOpen | .SpanFullWidth);
        TableNextColumn();
        Text("%", value);
        type_column(value);
    }
}

// polymorphic version so you can freely update you data types and not worry about modifying all your imgui menus
InputScalar :: (label: *u8, value: *$T) -> bool #modify {
    return is_numeric_type(T);
} {
    DATA_TYPE :: #run get_imgui_data_type(T.(*Type_Info));
    return InputScalar(label, DATA_TYPE, value);
}

InputAnyScalar :: (label: *u8, value: Any) -> bool {
    assert(is_numeric_type(value.type));
    data_type := get_imgui_data_type(value.type);
    return InputScalar(label, data_type, value.value_pointer);
}

// will just return .S8 by default. I don't care enough to prevent that, so just be aware
get_imgui_data_type :: (type: *Type_Info) -> DataType {
    data_type: DataType;
    if type.type == {
      case .INTEGER;
        if type.(*Type_Info_Integer).signed {
            if type.runtime_size == {
                case 1; data_type = .S8;
                case 2; data_type = .S16;
                case 4; data_type = .S32;
                case 8; data_type = .S64;
            }
        } else {
            if type.runtime_size == {
                case 1; data_type = .U8;
                case 2; data_type = .U16;
                case 4; data_type = .U32;
                case 8; data_type = .U64;
            }
        }
        
      case .FLOAT;
        if type.runtime_size == {
            case 4; data_type = .Float;
            case 8; data_type = .Double;
        }
    }
    return data_type;
}


#scope_file

using ImGui;

is_numeric_type :: inline (T: Type) -> bool {
    return is_numeric_type(T.(*Type_Info));
}

is_numeric_type :: inline (ti: *Type_Info) -> bool {
    return ti && (ti.type == .INTEGER || ti.type == .FLOAT);
}

next_power_of_2 :: (num: u32) -> u32 {
    if num != 0 {
        num -= 1;
        num |= (num >> 1);  // OR first 2 bits
        num |= (num >> 2);  // OR next  2 bits
        num |= (num >> 4);  // OR next  4 bits
        num |= (num >> 8);  // OR next  8 bits
        num |= (num >> 16); // OR next 16 bits
        num += 1;
    }
    return num;
}

dynamic_int_cast :: (dst: Any, src: Any, enforce_size: bool = false) -> bool {
    if enforce_size && src.type.runtime_size > dst.type.runtime_size {
        return false;
    }
    
    if src.type.type == {
        case .INTEGER;
        case .ENUM;
        case .BOOL;
        
        case; return false;
    }
    if dst.type.type == {
        case .INTEGER;
        case .ENUM;
        case .BOOL;
        
        case; return false;
    }
    
    s64_value: s64;
    
    if src.type.runtime_size == {
        case 1; s64_value = src.value_pointer.(*s8 ).*;
        case 2; s64_value = src.value_pointer.(*s16).*;
        case 4; s64_value = src.value_pointer.(*s32).*;
        case 8; s64_value = src.value_pointer.(*s64).*;
    }
    
    if dst.type.runtime_size == {
        case 1; dst.value_pointer.(*s8 ).* = s64_value.(s8 );
        case 2; dst.value_pointer.(*s16).* = s64_value.(s16);
        case 4; dst.value_pointer.(*s32).* = s64_value.(s32);
        case 8; dst.value_pointer.(*s64).* = s64_value.(s64);
    }
    
    return true;
}

#import "Reflection";

