
/*
    Immediate-mode UI components for the level editor.
    
    Handles
        partially implemented
        draggable, hierarchical
    
    Popup Menus
        not yet started
        easiest type to implement first will be menu that works on a known number of elements
        that way we can compute layout ahead of time
        selectable options will be a []T with parallel array for icon textures
        easy to make the menu either a straight bar or a radial menu
        
    
    TODO: rename all of the functions to be a little more namespaced
          they are currently way too generic-sounding an dcould easily conflict later
    
*/

ui_elements_texture: Texture;

// declare clip rects for the various elements of ui
ui_texture_clip_position_2d :: Rectf.{ 128,  0, 64, 64 };
// ui_texture_clip_position_1d :: Rectf.{ 32,  0, 32, 32 };
ui_texture_clip_rotation    :: Rectf.{ 192,  0, 64, 64 };


Handle_Focus_Type :: enum_flags {
    NONE :: 0; L :: 1; R; L_SHIFT; R_SHIFT; L_CTRL; R_CTRL; L_ALT; R_ALT;
}

// top-level id. This is a handle to a top-level element in the level data, for example a tilemap or entity
Top_Level_ID :: struct { type: Type; index: s64; };

operator == :: (a: Top_Level_ID, b: Top_Level_ID) -> bool {
    return a.type == b.type && a.index == b.index;
}

// dynamic id, like a typical imgui id, can be put on any element
Dynamic_ID :: string;

MAX_ID_STACK_COUNT :: 16;

// For now, assume that id stack will never be greater than 16 deep
// our ui components will likely never get that complicated
// because of how our ui handles are structured, we need the entire path to the hot and active elements, not just their terminal id or a hash
ID_Stack :: struct {
    top:        Top_Level_ID;
    dyn_stack:  [MAX_ID_STACK_COUNT] Dynamic_ID;
    dyn_count:  int;
}

ui_state: struct {
    current, hot, active: ID_Stack;
    
    element_offsets: [MAX_ID_STACK_COUNT+1] Vector2; // +1 for the top-level element's offset
    
    active_holding_focus:           Handle_Focus_Type;  // prevents setting hot item. using Directions so we can differentiate focus held by left and right clicks
    did_visit_active_this_frame:    bool;  // if we didn't visist the active element this frame, we need to release its hold on focus
    
    draw_list: [..] Render_Command; // for now we will only do quads
}

render_ui_state :: () {
    mouse := get_mouse();
    for ui_state.draw_list {
        exec_render_command(it);
    }
    array_reset_keeping_memory(*ui_state.draw_list);
    
    // TODO: move this to some begin_frame proc
    if ui_state.hot.dyn_count == 0 {
        if mouse.left == .DOWN {
            clear_active_id();
        }
    }
}

try_set_hot :: (id_stack: ID_Stack) {
    if !ui_state.active_holding_focus && ui_state.current.dyn_count >= ui_state.hot.dyn_count {
        ui_state.hot = id_stack;
    }
}

set_active :: (id_stack: ID_Stack, hold_focus := Handle_Focus_Type.NONE) {
    ui_state.active = id_stack;
    if hold_focus == {
      case .L; ui_state.active_holding_focus = .L;
      case .R; ui_state.active_holding_focus = .R;
    }
}

clear_active_id :: () {
    ui_state.active = .{};
    ui_state.active_holding_focus = .NONE;
}

begin_id :: (id_stack: *ID_Stack, tlid: Top_Level_ID) {
    id_stack.* = .{ top = tlid };
}

end_id :: (id_stack: *ID_Stack) { id_stack.* = .{}; }

push_id :: (id_stack: *ID_Stack, dyn_id: Dynamic_ID) {
    assert(id_stack.dyn_count < type_info(type_of(ID_Stack.dyn_stack)).array_count);
    id_stack.dyn_stack[id_stack.dyn_count] = dyn_id;
    id_stack.dyn_count += 1;
}

pop_id :: (id_stack: *ID_Stack) {
    id_stack.dyn_count -= 1;
    assert(id_stack.dyn_count >= 0);
}

// returns how far the stacks match
compare_id_stacks :: (a: ID_Stack, b: ID_Stack) -> int {
    if a.top != b.top  return -1;
    min_count := min(a.dyn_count, b.dyn_count);
    for 0..min_count {
        if a.dyn_stack[it] != b.dyn_stack[it]  return it;
    }
    return min_count;
}

Focus_State :: enum {
    UNFOCUSED;
    PARENT_OF_FOCUSED;  // or grandparent
    FOCUSED;
}

get_hot_state :: (id_stack: ID_Stack) -> Focus_State {
    match_count := compare_id_stacks(id_stack, ui_state.hot);
    if match_count >= ui_state.hot.dyn_count
    && match_count >= id_stack.dyn_count  return .FOCUSED; // should it really ever be greater than...?
    if match_count >= id_stack.dyn_count  return .PARENT_OF_FOCUSED;
    return .UNFOCUSED;
}

get_active_state :: (id_stack: ID_Stack) -> Focus_State {
    match_count := compare_id_stacks(id_stack, ui_state.active);
    if match_count >= ui_state.active.dyn_count
    && match_count >= id_stack.dyn_count  return .FOCUSED; // should it really ever be greater than...?
    if match_count >= id_stack.dyn_count  return .PARENT_OF_FOCUSED;
    return .UNFOCUSED;
}

get_parent_handle_offset :: () -> Vector2 {
    total := Vector2.{};
    for 0..ui_state.current.dyn_count-1 {
        total += ui_state.element_offsets[it];
    }
    return total;
}

update_focus_state :: (using handle: *UI_Handle) {
    hot_state, active_state, focus_held, hovered = update_active_hot_state(rect, want_focus_held);
}

// want_focus_held should only be either .L or .R, or .L | .R
update_active_hot_state :: (rect: Rectf, want_focus_held := Handle_Focus_Type.NONE) -> (hot: Focus_State, active: Focus_State, focus_held: Handle_Focus_Type, hovered: bool) {
    mouse := get_mouse();
    hot_state    := get_hot_state(ui_state.current);
    active_state := get_active_state(ui_state.current);
    
    hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
    if hovered {
        if !ui_state.active_holding_focus && hot_state == .FOCUSED {
            if mouse.left == .PRESSED {
                set_active(ui_state.current, want_focus_held & .L);
            }
            if mouse.right == .PRESSED {
                set_active(ui_state.current, want_focus_held & .R);
            }
        }
        try_set_hot(ui_state.current);
    } else {
        if !ui_state.active_holding_focus && hot_state == .FOCUSED {
            ui_state.hot = .{};
        }
    }
    
    focus_held := Handle_Focus_Type.NONE;
    if active_state == .FOCUSED {
        if ((mouse.left  & .DOWN | .RELEASED) && (ui_state.active_holding_focus == .L))
        || ((mouse.right & .DOWN | .RELEASED) && (ui_state.active_holding_focus == .R)) {
            focus_held = ui_state.active_holding_focus;
        }
        // use .UP here instead of .RELEASED, since we still want to hold focus on the frame mouse button is released
        if ((mouse.left  == .UP) && (ui_state.active_holding_focus == .L))
        || ((mouse.right == .UP) && (ui_state.active_holding_focus == .R)) {
            ui_state.active_holding_focus = .NONE;
        }
    }
    
    return hot_state, active_state, focus_held, hovered;
}

// TODO: maybe params should be color3 since we basically want all alpha to be determined by focus state
get_render_color :: (hot_state: Focus_State, active_state: Focus_State, base_color: Color4, hot_color: Color4, active_color: Color4) -> Color4 {
    color := base_color;
    
    if hot_state == {
      case .FOCUSED;
        color.r += hot_color.r;
        color.g += hot_color.g;
        color.b += hot_color.b;
    }
    
    if active_state == {
      case .PARENT_OF_FOCUSED;
        color = lerp(base_color, active_color, 0.75);
        color.a *= 0.8;
        
      case .FOCUSED;
        if ui_state.active_holding_focus {
            color = active_color;
        } else {
            color = lerp(base_color, active_color, 0.85);
        }
        color.a *= 1.0;
        
      case xx 0; // if handle is not at all active
        if hot_state == .FOCUSED 
            then color.a *= 0.8;
            else color.a *= 0.6;
    }
    
    return color;
}


UI_Handle :: struct {
    // must be set by user
    id:         string;
    offset:     Vector2;    // positioning relative to parent handle
    
    // optionally set by user
    size:       Vector2     = .{ 1, 1 };
    thickness:  float       = 1.0;
    snap:       float       = 0.5;
    flags:      Flags;
    
    // only valid flags are .L and .R, used to indicate which mouse buttons should lock active state while held
    // TODO: later probably use some new enum that adds options for ctrl/alt/shift + mouse buttons as distinct interactions
    want_focus_held:    Handle_Focus_Type; 
    
    // set by for_expansion
    parent_offset:  Vector2;
    focus_held:     Handle_Focus_Type;
    hot_state, 
    active_state:   Focus_State;
    hovered:        bool;
    rect:           Rectf; // used for collision and rendering, based on offset and size
    
    texture: *Texture;
    clip:    *Rectf;
    
    Flags :: enum_flags { POSITION_ABSOLUTE; };
}

/*
    Maybe if we get rid of for expansion, we can do something like the following, supplying 2 code blocks
    because we will want to commit the final parent offset for the element and render before doing the children
    
    do_handle(handle, #code {
        // self code
    }, #code {
        // child code
    });
*/

update_offset :: (handle: *UI_Handle, offset: Vector2) {
    handle.offset = offset;
    ui_state.element_offsets[ui_state.current.dyn_count] = offset;
    calculate_rect(handle);
}

calculate_rect :: inline (using handle: *UI_Handle) {
    rect.position = (parent_offset + offset) - size / 2;
    rect.size     = size;
}

// slowly getting rid of the need for this as we factor things out...
for_expansion :: (handle: *UI_Handle, body: Code, for_flags: For_Flags) #expand {
    using `it := handle;
    `it_index := 0; // meaningless placeholder
    
    push_id(*ui_state.current, it.id);
    ui_state.element_offsets[ui_state.current.dyn_count] = offset;
    
    parent_offset = .{};
    if !(flags & .POSITION_ABSOLUTE)  
        parent_offset = get_parent_handle_offset();
    
    calculate_rect(handle);
    
    update_focus_state(handle);
    
    #insert body;
    
    render_ui_handle(handle);
    
    end_handle();
}

render_ui_handle :: (using handle: *UI_Handle) {
    color := get_render_color(hot_state, active_state, base_color, hot_color, active_color);
    
    if texture {
        draw_data := Render_Command.{
            type = .QUAD,
            quad_params = .{
                texture  = texture,
                clip     = clip,
                palette  = get_color_animation_index("white"), // TODO: we should just save the index elsewhere
                color    = color,
                position = (rect.position - Editor.level.camera) * EDITOR_TILE_UNIT,
                size     = rect.size * EDITOR_TILE_UNIT,
            }
        };
        array_add(*ui_state.draw_list, draw_data);
    } else {
        render_rect := rect;
        render_rect.position -= Editor.level.camera;
        render_rect *= EDITOR_TILE_UNIT;
        draw_data := Render_Command.{
            type = .RECT,
            rect_params = .{
                rect      = render_rect,
                color     = color,
                thickness = thickness,
            }
        };
        array_add(*ui_state.draw_list, draw_data);
    }
}

base_color   := Color4.{ 0.8, 0.8, 0.8, 1 };
active_color := Color4.{ 1.0, 1.0, 1.0, 1 };
hot_color    := Color4.{ 0.0, 0.5, 0.0, 1 };

rotation_handle :: (id: string, angle: *float, radius := 3.0, snap := 1.0, size := Vector2.{ 1, 1 }) -> bool {
    mouse := get_mouse();
    push_id(*ui_state.current, id);
    parent_offset := get_parent_handle_offset();
    
    unit     := unit_vector_given_angle_degrees(angle.*);
    position := parent_offset + unit * radius;
    rect     := Rectf.{ position = position - size/2, size = size };
    
    ui_state.element_offsets[ui_state.current.dyn_count] = position;
    
    hot_state, active_state, focus_held := update_active_hot_state(rect, .L);
    
    if focus_held && mouse.velocity != .{ 0, 0 } {
        angle.* = angle_between_points(parent_offset, Editor.mouse_tile_position) * 180 / PI;
        if mouse.left == .RELEASED {
            if snap then angle.* = snap_to_nearest_unit(angle.*, snap);
        }
    }
    
    color := get_render_color(hot_state, active_state, base_color, hot_color, active_color);
    
    draw_data := Render_Command.{
        type = .QUAD,
        quad_params = .{
            texture  = *ui_elements_texture,
            clip     = *ui_texture_clip_rotation,
            palette  = get_color_animation_index("white"), // TODO: we should just save the index elsewhere
            color    = color,
            position = (rect.position - Editor.level.camera) * EDITOR_TILE_UNIT,
            size     = rect.size * EDITOR_TILE_UNIT,
        }
    };
    array_add(*ui_state.draw_list, draw_data);
    
    return active_state != .UNFOCUSED;
}

// TODO: we should use some flags instead of passing positio_absolute parameter
begin_handle :: (id: string, offset: *Vector2, offset_2: *Vector2 = null, snap := 0.5, position_absolute := true) -> bool {
    mouse := get_mouse();
    push_id(*ui_state.current, id);
    parent_offset := get_parent_handle_offset();
    if position_absolute then parent_offset = .{};
    
    size := Vector2.{ 1, 1 };
    rect := Rectf.{ position = (parent_offset + offset.*) - size/2, size = size };
    
    hot_state, active_state, focus_held := update_active_hot_state(rect, .L | (ifx offset_2 then .R));
    
    if focus_held && mouse.velocity != .{ 0, 0 } {
        if focus_held == .L {
            offset.* = Editor.mouse_tile_position - parent_offset;
            // if mouse.left == .RELEASED {
                if snap then offset.* = snap_to_nearest_unit(offset.*, snap);
            // }
        }
        else if focus_held == .R && offset_2 {
            offset_2.* -= to_Vec2f(mouse.velocity) / EDITOR_TILE_UNIT;
            // if mouse.right == .RELEASED {
            //     if snap then offset_2.* = snap_to_nearest_unit(offset_2.*, snap);
            // }
        }
    }
    
    color := get_render_color(hot_state, active_state, base_color, hot_color, active_color);
    
    draw_data := Render_Command.{
        type = .QUAD,
        quad_params = .{
            texture  = *ui_elements_texture,
            clip     = *ui_texture_clip_position_2d,
            palette  = get_color_animation_index("white"), // TODO: we should just save the index elsewhere
            color    = color,
            position = (rect.position - Editor.level.camera) * EDITOR_TILE_UNIT,
            size     = rect.size * EDITOR_TILE_UNIT,
        }
    };
    array_add(*ui_state.draw_list, draw_data);
    
    // set element at the end so that if offset was modified (handle was dragged) then we are not one frame behind.
    ui_state.element_offsets[ui_state.current.dyn_count] = parent_offset + offset.*;
    
    return active_state != .UNFOCUSED;
}

end_handle :: () { 
    pop_id(*ui_state.current); 
}

do_handle :: (id: string, offset: *Vector2, offset_2: *Vector2 = null, snap := 0.5, position_absolute := true) {
    begin_handle(id, offset, offset_2, snap, position_absolute);
    end_handle();
}







/*
    Popup menus
    
    these are the other main ui component that I want to implement
    I may still decide just to use imgui for these, since I've done so in the past an it works fine
    it also works just as well to simply open entity/tilemap details in the side panel
    
    but perhaps this will still be nice for certain small, very visual menus
        e.g. entity subtype picker or something
    
    
    Other editor interactivity we need:
    
    being able to drag entities over tiles or other entities and get contextual interactions e.g. mario maker
        like being able to put an entity in a pipe or something
    
    
*/




/*
    Because it is such a basic primitive, the grid view will be implemented as both a standalone thing and a ui handle
    
    for the basic version, just take a given rectangle and render into that
        no need to compute sizing
    
    for the ui handle, we want the following functionality
        center the ui element over a given point
        requires knowing how many elements to render...
            we can probbaly hint this to parent call before doing immediate-mode elements within
        ability to scroll within element?
            pass this as another Vec2 ptr
            or maybe at least add buttons and int ptr for min index
            will require capturing mouse events with ui element
                our existing elements should actualyl do this already but dont
                
    
    
    TODO: 
        get working in place of existing tile selector
        get working in context of imgui window
        get working as an editor context menu (ui handle)

*/

Grid_View_Element :: struct {
    texture:    *Texture;
    clip:       Rectf;
    palette:    int;
    rect:       Rectf;
}

Grid_View :: struct {
    // NOTE: all units are in screen-space (pixels)
    position:       Vec2f;
    size:           Vec2f;
    tile_size:      Vec2f; 
    tile_padding:   Vec2f; 
    
    bg_color:       Color4;
    outline_color:  Color4;
    
    render_offset:  Vec2f;
    
    render_commands: [..] Render_Command;
    render_immediate := true; // bit of a hack
    
    // current_selection:  int; // maybe use a *void so user can do their own data there?
    
    // TODO: set anchor/alignment. currently just doing top-left
    // TODO: later do multiple type of click, or do focus state thing like handles do
    //       but before doing that, refactor how interaction events are communicated generally
    // TODO: replace position/size with Rect for screenspace viewport
    //       then use separate Vec2f for internal scrolling offset
}

for_expansion :: (grid_view: *Grid_View, body: Code, for_flags: For_Flags) #expand {
    using `it := grid_view;
    `it_index := 0; // meaningless placeholder
    
    tile_size_with_padding := tile_size + tile_padding;
    max_grid_size := size / tile_size_with_padding;
    
    x_wrap_cutoff := position.x + size.x - tile_size.x - tile_padding.x / 2;
    
    element_rect := Rectf.{
        position = position + tile_padding / 2,
        size     = tile_size,
    };
    
    // TODO: track element index, provide a way for user to signify the currently selected element
    // element_index := 
    
    // create temp array for render commands so that we can later insert the bg rectangle before the commands for drawing the elements of grid view.
    array_reset(*render_commands);
    render_commands.allocator = temp;
    
    // push one empty render command for bg rect before doing elements
    // we will overwrite this later with the proper rect
    array_add(*render_commands, .{});
    array_add(*render_commands, .{});
    
    // This macro for doing elements is exported to the user.
    // We need a macro here so that we can hide how render comands are added to the above array.
    `do_element :: (element: Grid_View_Element) -> (clicked: bool, hovered: bool) #expand {
        helper :: (element: Grid_View_Element, grid_view: *Grid_View) -> (clicked: bool, hovered: bool) {
            mouse := get_mouse();
            
            hovered := mouse && is_point_within_frect(to_Vec2f(mouse.position), element.rect);
            clicked := hovered && (mouse.left == .PRESSED);
            
            array_add(*grid_view.render_commands, Render_Command.{
                type = .QUAD,
                quad_params = .{
                    texture  = element.texture,
                    clip     = element.clip,
                    palette  = element.palette,
                    position = element.rect.position + grid_view.render_offset,
                    size     = element.rect.size,
                }
            });
            
            // TODO: render an additonal rect around currently selected element.
            
            if hovered {
                outline_rect := element.rect;
                outline_rect.position += grid_view.render_offset - grid_view.tile_padding / 2;
                outline_rect.size += grid_view.tile_padding;
                array_add(*grid_view.render_commands, Render_Command.{
                    type = .RECT,
                    rect_params = .{
                        rect = outline_rect,
                    }
                });
            }
            
            return clicked, hovered;
        }
        
        element.rect = element_rect;
        clicked, hovered := helper(element, grid_view);
        
        element_rect.x += tile_size_with_padding.x;
        if element_rect.x > x_wrap_cutoff {
            element_rect.x = grid_view.position.x + grid_view.tile_padding.x / 2;
            element_rect.y += tile_size_with_padding.y;
        }
        
        return clicked, hovered;
    }
    
    #insert body;
    
    // bg rect
    render_commands[0] = .{
        type = .QUAD,
        quad_params = .{
            position = position + render_offset,
            size     = .{ size.x, element_rect.y + element_rect.h + tile_padding.y / 2 - position.y },
            color    = bg_color,
        }
    };
    render_commands[1] = .{
        type = .RECT,
        rect_params = .{
            rect = .{
                position = position + render_offset,
                size     = .{ size.x, element_rect.y + element_rect.h + tile_padding.y / 2 - position.y },
            },
            color    = outline_color,
        }
    };
    
    if render_immediate {
        render_begin_batch();
        for render_commands  exec_render_command(it);
        render_end_batch();
        render_flush();
    }
}
