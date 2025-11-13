
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
          they are currently way too generic-sounding and could easily conflict later
    
    
    TODO: 
        can probably remove the active holding focus thing entirely and just use mouse state
            no reason for us to be be able to set a new hot item while the mouse is down, methinks
                only valid reason I can think of is to support some kind of drag and drop between nodes
                but then in that case we would already be holding some other active element anyhow
            this would simplify some logic and should make multi-selection logic easier to follow
        
        use a simple animator and enumerate the handle clips so that they are easier to reference
    
    
*/

#if EDITOR_ENABLED {

// declare clip rects for the various elements of ui
ui_texture_clip_position_2d            :: Rectf.{  0,  0, 32, 32 };
ui_texture_clip_position_1d_horizontal :: Rectf.{ 32,  0, 32, 32 };
ui_texture_clip_position_1d_vertical   :: Rectf.{ 64,  0, 32, 32 };
ui_texture_clip_rotation               :: Rectf.{ 96,  0, 32, 32 };
ui_texture_clip_circle                 :: Rectf.{ 64, 32, 32, 32 };

ui_texture_clip_bound_UL :: Rectf.{  0, 32, 32, 32 };
ui_texture_clip_bound_UR :: Rectf.{ 32, 32, 32, 32 };
ui_texture_clip_bound_DL :: Rectf.{  0, 64, 32, 32 };
ui_texture_clip_bound_DR :: Rectf.{ 32, 64, 32, 32 };

// TODO: use a simple animator for the ui texture clips so that we can apply offsets, and could also animate if desired.
//       one animator for all clips, using enum/string ident of animation for each clip. should make it possible to define all clips and animations in lsd file
//       NOTE: will not actually be able to use clip offset to influence offset of handle's actual interaction rect, unless we decide to use the texture clip to define the clickable rect


Handle_Focus_Type :: enum_flags {
    NONE :: 0; L :: 1; R :: 2;
}

base_color   := Color4.{ 0.8, 0.8, 0.8, 1 };
active_color := Color4.{ 1.0, 1.0, 1.0, 1 };
hot_color    := Color4.{ 0.0, 0.5, 0.0, 1 };

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
    
    
    NEWER NOTE:
        will probably only implement these after implementing some general window system in the ui
        since any popup menus will essentially just be little window into which we will render other ui elements
    
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
    palette:    Palette_ID;
    rect:       Rectf;
    flip:       Direction_Flip;
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
                    flip     = element.flip
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
}

}






/*
    UI Refactoring
    
    The new plan for this UI stuff will be to build an actual DOM that represents the current UI state.
    
    This should be more resiliant and easier to build out than the current mess that is the whole ID stack thing.
    
    I'm also not too concerned about performance characteristics at the moment since this is just Editor sutff, but using a flat pool for UI elements' nodes should help make things perform relatively well.
    
    
    One of the aspects of my editor UI which is seemingly unique compared to some other imgui uis I have encountered is that  
        I have to deal with more freely positioned elements, which may overlap with one another
        
        dear imgui still has to deal with this to some respect, but there's always a clear z-ordering of elements to be able to disambiguate what the user is interacting with
        and basically the only elements that may overlap are windows, not elements within the same window
        
        in my ui, this may not be as clear, or we may want a click to interact with multiple elements at once
            for example, if we have to overlapping entities, clicking on both should lead to some means of disambiguating which the player intends to interact with
            e.g.: a popup menu that shows both entity IDs, or clicking again to toggle which one is considered selected 
    
    I also need to deal with situations wher ethe user can select multiple ui elements at once and drag them all around as a group
        this may also include elements of heterogenous types
    
    multi-select and dragging will be intersting to implement
    
    
    interacting with handles/nodes
    
    nodes are the persistent state that we store for elements in the ui
    handles are for immediate-mode interactions that map onto some ui node
    
    handle will be given a ui node id 
    
    
    another aspect which may make my ui needs a bit more specialized is that I may have multiple separate parts in code that want to attach ui elements to the same 'top-level' item
    for example, we may have some ui handles that get attached to a tilemap by the edtor code itself, but then others may be added on by the level script
    so we need to be able to step back into a node that we already visited earlier in the frame...
        this will essentially just be so that we can then access the data on the parent node in the child handles we then append
    
    
    
    
    NOTE:
        maybe we can cycle through placing hot on multiple hovered elements by tapping CTRL or something...
        that way initial mouse click can still just be a click on the currently hot item
        OR could use scroll wheel?
    
*/


// NOTE: ifdef-ing this all out for now, just jotting down some ideas, outlining data structures
Type_And_Index :: struct { type: Type; index: int; }

ui_state: UI_State;

UI_State :: struct {
    flags:                  Flags;
    draw_list:              [..] Render_Command;
    
    pool:                   Flat_Pool;
    root_node:              *UI_Node;
    current_node:           *UI_Node;
    
    hot, active:            *UI_Node;
    current_walk_index:     int;
    
    count_hovered:          int;
    prefer_nth_hovered:     int;
    
    // TODO: Some state for disambiguating between click on overlapping ui elements
    
    // TODO: will need some mouse state, track current action (clicking, dragging, selection rect, etc.)
    // also, avoid setting nodes/handles as hot when some active item is currently holding focus
    
    Flags :: enum_flags {
        MULTI_SELECTION_ACTIVE;
        // ACTIVE_HOLDING_FOCUS;
        ACTIVE_VISITED_THIS_FRAME;
        HOT_VISITED_THIS_FRAME;
    }
}

ui_begin_frame :: () {
    using ui_state;
    
    mouse := get_mouse();
    
    current_node = root_node;
    current_walk_index = 0;
    
    array_reset_keeping_memory(*draw_list);
    
    // NOTE: kind of a hack, or arbitrary choice, but holding CTRL will purposefully not reset active on mouse button down
    if (hot == null && mouse.left == .PRESSED && key_modifier_state == .NONE) 
    || (active && !(flags & .ACTIVE_VISITED_THIS_FRAME)) {
        ui_clear_active();
        editor_clear_grab_selection();
    }
    
    if !(flags & .HOT_VISITED_THIS_FRAME) {
        hot = null;
    }
    
    // reset transient flags
    flags &= ~(.HOT_VISITED_THIS_FRAME | .ACTIVE_VISITED_THIS_FRAME);
    
    /*
        Each frame we have to walk the entire DOM so that we can update 
        all node's frames_since_visited count and walk_index.
        
        TODO: we probably don't need to store walk index to solve the overlapping handles issue as I am anticipating it.
        My initial plan was that we could use this walk index to prioritize what node get hot state when multiple are hovered, using it like a sort of z-index.
        However, this solution does not solve the rendering issue, since we would still need to sort all render commands by some z index before rendering.
            Which we certainly *could* do, but maybe that's not ideal either?
        Maybe there's some better solution where we can simply note on some frame that we want to make hot the 'nth' overlapping element modulo however many elements we are currently hovering.
            Once that element is considered hot, that should be stable even if other elements are overlapping.
    */
    for root_node.children {
        walk_proc :: (n: *UI_Node) -> bool { 
            n.frames_since_pushed  += 1;
            n.frames_since_updated += 1; 
            n.walk_index = ui_next_walk_index();
            
            n.flags &= ~(.SHOULD_DO_CHILD_NODES);
            
            if (n.flags & (.ACTIVE | .CHILD_ACTIVE)) { 
                n.flags |= .SHOULD_DO_CHILD_NODES; 
            }
            
            return true; 
        };
        ui_walk_nodes(it, walk_proc);
    }
    
    
    if count_hovered == 0 {
        prefer_nth_hovered = 0;
    } else {
        if mouse.wheel.y > 0 then prefer_nth_hovered = modulo(prefer_nth_hovered + 1, count_hovered);
        if mouse.wheel.y < 0 then prefer_nth_hovered = modulo(prefer_nth_hovered - 1, count_hovered);
    }
    count_hovered = 0;
    
    // TODO: set up mouse state for ui for this frame
}

render_ui_state :: () {
    for ui_state.draw_list {
        exec_render_command(it);
    }
}

UI_Node :: struct {
    id:         ID;
    flags:      Flags;
    
    parent, next, prev:     *UI_Node;
    children:               UI_Node_List;
    
    // used to store positioning information the almost all handles will need
    offset:             Vec2f;
    
    // transient, gets updated each frame
    // this is used to determine which element should be considered hot when mouse is hovering over mutliple overlapping elements
    walk_index:         int;
    
    // if 0, then the element was shown this frame
    // we may use this to cull old nodes if we run into the issue of exhausting our node pool
    // separate counters for pushed and updated, since a node may be pushed for child nodes to be updated without actually updating parent
    frames_since_pushed:    int;
    frames_since_updated:   int;
    
    Flags :: enum_flags {
        // state flags
        HOVERED;
        HOT;
        ACTIVE;
        REMOVED;
        
        CHILD_HOT;
        CHILD_ACTIVE;
        
        SHOULD_DO_CHILD_NODES;
        
        // behaviour flags
        // SHOW_CHILDREN_WHEN_HOT;
        // SHOW_CHILDREN_WHEN_ACTIVE;
    }
    
    // NOTE: ID is more of an interface so that we can add different types of IDs that work better for specific use cases
    ID :: struct {
        kind: Kind;
        
        union {
            _string:            string;
            _type_and_index:    Type_And_Index;
            _actor_handle:      Actor.Handle;
        }
        
        Kind :: enum {
            STRING;
            // TYPE_AND_INDEX;
            ACTOR_HANDLE;
        };
    }
}

// helper procs for making ui ids of various sorts
// this first one just exists as a passthrough so we don't have to duplicate other procedures
ui_id :: inline (id: UI_Node.ID) -> UI_Node.ID { return id; };
ui_id :: inline (s: string) -> UI_Node.ID { return .{ kind = .STRING, _string = copy_string(s,, get_pool_allocator(*ui_state.pool)) }; };
// ui_id :: inline (t: Type, i: int) -> UI_Node.ID { return .{ kind = .TYPE_AND_INDEX, _type_and_index = .{ t, i } }; };
ui_id :: inline (a: Actor.Handle) -> UI_Node.ID { return .{ kind = .ACTOR_HANDLE, _actor_handle = a }; };
ui_id :: inline (a: *Actor) -> UI_Node.ID { return ui_id(get_actor_handle(a)); };

// NOTE: this will return a null type if ID kind is not .TYPE_AND_INDEX
// get_id_type_and_index :: (node: *UI_Node) -> Type, int {
//     type: Type;
//     if node == null || node.id.kind != .TYPE_AND_INDEX return type, 0;
//     return node.id._type_and_index.type, node.id._type_and_index.index;
// }

ui_get_child_by_id :: (parent: *UI_Node, id: UI_Node.ID) -> *UI_Node {
    for parent.children  if it.id == id  return it;
    return null;
}

// TODO: right now I am assuming that actor nodes are always at root level
//       but I don't actually do anything to guarantee this as of yet
ui_get_node_for_actor :: (a: *Actor) -> *UI_Node { 
    return ui_get_child_by_id(ui_state.root_node, ui_id(get_actor_handle(a))); 
};

get_actor_handle :: (node: *UI_Node) -> Actor.Handle {
    return ifx node && node.id.kind == .ACTOR_HANDLE then node.id._actor_handle;
}

operator == :: (a: UI_Node.ID, b: UI_Node.ID) -> bool {
    if a.kind != b.kind  return false;
    
    if #complete a.kind == {
      case .STRING;
        return a._string == b._string;
        
      // case .TYPE_AND_INDEX;
      //   return a._type_and_index.type == b._type_and_index.type && a._type_and_index.index == b._type_and_index.index;
        
      case .ACTOR_HANDLE;
        return a._actor_handle == b._actor_handle;
    }
    
    return false;
}

ui_walk_nodes :: (node: *UI_Node, proc: (*UI_Node, T) -> bool, user_data: $T) {
    if proc(node, user_data) {
        for node.children {
            ui_walk_nodes(it, proc, user_data);
        }
    }
}

ui_walk_nodes :: (node: *UI_Node, proc: (*UI_Node) -> bool) {
    if proc(node) {
        for node.children {
            ui_walk_nodes(it, proc);
        }
    }
}

get_or_add_child_node :: (parent: *UI_Node, id: UI_Node.ID) -> *UI_Node {
    for parent.children {
        if it.id == id {
            return it;
        }
    }
    
    node := New(UI_Node,, get_pool_allocator(*ui_state.pool));
    node.parent = parent;
    node.id = id;
    
    if parent.children.last != null {
        parent.children.last.next = node;
        node.prev = parent.children.last;
    }
    parent.children.last = node;
    
    if parent.children.first == null {
        parent.children.first = node;
    }
    
    parent.children.count += 1;
    
    return node;
}

UI_Node_List :: struct { 
    first:  *UI_Node;
    last:   *UI_Node;
    count:  int;
};

for_expansion :: (list: *UI_Node_List, body: Code, flags: For_Flags) #expand {
    #if flags & .REVERSE {
        `it_index := list.count;
        `it := list.last;
        while it {
            prev := it.prev;
            defer { it = prev; it_index -= 1; }
            #insert(remove={remove_node(it);}) body;
        }
    } else {
        `it_index := 0;
        `it := list.first;
        while it {
            next := it.next;
            defer { it = next; it_index += 1; }
            #insert(remove={remove_node(it);}) body;
        }
    }
}

// NOTE: does not deallocate node, since we use a flat pool for node allocation
remove_node :: (node: *UI_Node) {
    node.parent.children.count -= 1;
    if node.next != null  node.next.prev = node.prev;
    if node.prev != null  node.prev.next = node.next;
    if node.parent.children.first == node  node.parent.children.first = node.next;
    if node.parent.children.last  == node  node.parent.children.last  = node.prev;
    
    node.flags |= .REMOVED;
}

ui_next_walk_index :: () -> int {
    ui_state.current_walk_index += 1;
    return ui_state.current_walk_index;
}

update_node :: (node: *UI_Node, offset: Vec2f) { 
    node.frames_since_updated = 0; 
    node.offset = offset;
}

ui_try_set_hot :: (node: *UI_Node) {
    node.flags |= .HOVERED;
    
    if ui_state.hot == null || (ui_state.prefer_nth_hovered == ui_state.count_hovered) {
        ui_state.hot = node;
        node.flags |= .HOT;
        ui_state.flags |= .HOT_VISITED_THIS_FRAME;
    }
}

ui_set_active :: (node: *UI_Node) {
    if !key_modifier_state & .CTRL {
        editor_clear_grab_selection();
    }
    ui_state.active = node;
    node.flags |= .ACTIVE;
}

ui_clear_active :: () {
    ui_state.active = null;
}

ui_push_defer_pop :: (t: $T) -> *UI_Node #expand {
    `defer ui_pop();
    return ui_push(t);
}

ui_push :: (t: $T) -> *UI_Node {
    if !context.in_editor  return null;
    assert(ui_state.current_node != null);
    ui_state.current_node = get_or_add_child_node(ui_state.current_node, ui_id(t));
    ui_state.current_node.frames_since_pushed = 0;
    return ui_state.current_node;
}

ui_pop :: () {
    if !context.in_editor  return;
    assert(ui_state.current_node != ui_state.root_node, "Called pop_id on the root ui node!");
    
    parent := ui_state.current_node.parent;
    if ui_state.current_node.flags & .HOT {
        parent.flags |= .CHILD_HOT;
    }
    if ui_state.current_node.flags & .ACTIVE {
        parent.flags |= .CHILD_ACTIVE;
    }
    ui_state.current_node = parent;
    
    assert(ui_state.current_node != null, "Current ui node was null after pop_id!");
}

// TODO: put ui state (on editor?) on context so that we can just do `node := context.ui_state.current_node` as argument
ui_should_do_child_nodes :: (node: *UI_Node = null) -> bool {
    _node := ifx node else ui_state.current_node;
    return _node.frames_since_updated == 0 && (_node.flags & (.ACTIVE | .SHOULD_DO_CHILD_NODES));
}

// only need to pop if it returns true
ui_append_to :: ui_push_for_children;
ui_push_for_children :: (t: $T) -> bool {
    if !context.in_editor  return false;
    node := ui_push(t);
    result := ui_should_do_child_nodes(node);
    if !result ui_pop();
    return result;
}

notify_parent_of_active_hot_state :: (node: *UI_Node) {
    if node.flags & .HOT    then node.parent.flags |= .CHILD_HOT;
    if node.flags & .ACTIVE then node.parent.flags |= .CHILD_ACTIVE;
}

update_active_hot_state :: (node: *UI_Node, hovered: bool) {
    mouse := get_mouse();
    
    node.flags &= ~(.HOVERED | .HOT | .ACTIVE | .CHILD_HOT | .CHILD_ACTIVE);
    
    if node == ui_state.hot {
        if hovered {
            node.flags |= .HOT;
            ui_state.flags |= .HOT_VISITED_THIS_FRAME;
            if mouse.left == .PRESSED || mouse.right == .PRESSED {
                ui_set_active(node);
            }
        } else {
            ui_state.hot == null;
        }
    } else if hovered {
        ui_try_set_hot(node);
    }
    
    ui_state.count_hovered += hovered.(int);
    
    if node == ui_state.active {
        node.flags |= .ACTIVE;
        ui_state.flags |= .ACTIVE_VISITED_THIS_FRAME;
    }
    
    notify_parent_of_active_hot_state(node);
}


get_render_color :: (node: *UI_Node, base_color: Color4, hot_color: Color4, active_color: Color4) -> Color4 {
    color := base_color;
    
    mouse := get_mouse();
    
    if node.flags & .HOT {
        color.r += hot_color.r;
        color.g += hot_color.g;
        color.b += hot_color.b;
    }
    
    if node.flags & .CHILD_ACTIVE {
        color = lerp(base_color, active_color, 0.75);
        color.a *= 0.8;
    } else if node.flags & .ACTIVE {
        if mouse && (mouse.left || mouse.right) {
            color = active_color;
        } else {
            color = lerp(base_color, active_color, 0.85);
        }
        color.a *= 1.0;
        
    } else {
        if node.flags & .HOT
            then color.a *= 0.8;
            else color.a *= 0.6;
    }
    
    return color;
}



ui_tilemap_handle :: (tilemap: *Tilemap, index: int) {
    node := ui_push_defer_pop(tilemap);
    
    mouse := get_mouse();
    
    offset := tilemap.root_offset;
    size   := Vec2f.{ 1, 1 };
    
    rect := Rectf.{ position = offset - size / 2, size = size };
    
    hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
    update_active_hot_state(node, hovered);
    
    if node.flags & .ACTIVE {
        if mouse.left == {
          case .DOWN;
            tilemap.root_offset += to_Vec2f(mouse.velocity) / Editor.tile_unit;
            // Editor.should_recalculate_timeline_points = true;
            
          case .RELEASED;
            tilemap.root_offset = snap_to_nearest_unit(tilemap.root_offset, 0.5);
            // Editor.should_recalculate_timeline_points = true;
        }
        
        if !mouse.left {
            if mouse.right == {
              case .DOWN;
                move := to_Vec2f(mouse.velocity) / Editor.tile_unit;
                tilemap.anchor_point += move;
                tilemap.root_offset  += move;
                
              case .RELEASED;
                tilemap.anchor_point = snap_to_nearest_unit(tilemap.anchor_point, 0.5);
                tilemap.root_offset  = snap_to_nearest_unit(tilemap.root_offset,  0.5);
            }
        }
    }
    if hovered {
        // TODO: set hovered in editor flag, update rendering to auto hide the other tilemaps like we do when editting a tilemap
        tilemap.flags |= .HOVERED_IN_EDITOR;
    }
    if node.flags & (.ACTIVE | .CHILD_ACTIVE) {
        tilemap.flags |= .SELECTED_IN_EDITOR;
        Editor.selected_tilemap = index;
    }
    
    update_node(node, offset);
    
    color := get_render_color(node, base_color, hot_color, active_color);
    
    append_render_command_quad(*ui_state.draw_list,
        texture  = *textures.UI_ELEMENTS,
        clip     = *ui_texture_clip_position_2d,
        color    = color,
        position = (rect.position - Editor.level.camera) * Editor.tile_unit,
        size     = rect.size * Editor.tile_unit,
    );
}

ui_entity_handle :: (entity: *Entity, index: int) {
    node := ui_push_defer_pop(entity);
    
    mouse := get_mouse();
    
    rect := get_collision_rect(entity);
    
    hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
    is_selected := (entity.flags & .SELECTED_IN_EDITOR).(bool);
    
    update_active_hot_state(node, hovered);
    
    if Editor.selection.active {
        if Editor.selection.first != Editor.selection.second {
            if aabb_frect(get_editor_selection_rect(), rect) {
                node.flags |= .HOT; // NOTE: only for visual effect
            }
        }
    } else {
        if is_selected || (node.flags & .ACTIVE) {
            if mouse.left == {
              case .PRESSED;
                if hovered {
                    if key_modifier_state & .CTRL {
                        editor_toggle_grab_selection(entity);
                        if !(entity.flags & .SELECTED_IN_EDITOR) && node == ui_state.active then ui_clear_active();
                    } else {
                        if !(entity.flags & .SELECTED_IN_EDITOR) {
                            editor_set_grab_selection(entity);
                            Editor.details_panel_subject = entity.*;
                        }
                    }
                }
                
              case .DOWN;
                entity.init_position += to_Vec2f(mouse.velocity) / Editor.tile_unit;
                
              case .RELEASED;
                entity.init_position = snap_to_nearest_unit(entity.init_position, 0.5);
            }
        }
    }
    
    update_node(node, entity.position);
    
    // NOTE: this will only affect visuals, not ui function
    if is_selected {
        node.flags |= .ACTIVE;
    }
    
    color := get_render_color(node, base_color, hot_color, active_color);
    
    render_rect := rect;
    render_rect.position -= Editor.level.camera;
    render_rect *= Editor.tile_unit;
    
    append_render_command_rect(*ui_state.draw_list,
        rect        = render_rect,
        color       = color,
        thickness   = 2,
    );
}

// NOTE: just playing with this right now, seeing if I like this way of doing nodes which may or may not auto-pop
ui_rotation_handle :: (id: UI_Node.ID, angle: *float, radius := 1.0, snap := 1.0, size := Vec2f.{ 1, 1 }, pop := true) -> bool {
    node := ui_push(id);
    defer if pop  ui_pop();
    
    mouse := get_mouse();
    
    parent_offset := node.parent.offset;
    
    unit   := unit_vector_given_angle_degrees(angle.*);
    offset := parent_offset + unit * radius;
    rect   := Rectf.{ position = offset - size/2, size = size };
    
    hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
    update_active_hot_state(node, hovered);
    
    if node.flags & .ACTIVE {
        if mouse.left == {
          case .DOWN;
            angle.* = angle_between_points(parent_offset, Editor.mouse_tile_position) * 180 / PI;
            
          case .RELEASED;
            if snap then angle.* = snap_to_nearest_unit(angle.*, snap);
        }
    }
    
    update_node(node, offset);
    
    color := get_render_color(node, base_color, hot_color, active_color);
    
    append_render_command_quad(*ui_state.draw_list,
        texture  = *textures.UI_ELEMENTS,
        clip     = *ui_texture_clip_rotation,
        color    = color,
        position = (rect.position - Editor.level.camera) * Editor.tile_unit,
        size     = rect.size * Editor.tile_unit,
    );
    
    return !pop && ui_should_do_child_nodes(node);
}


ui_range_handle :: (
    id:     UI_Node.ID, 
    range:  *Vec2f,
    // align   := Vec2f.{ .5, .5 }, 
    // snap    := 1.0, 
    // size    := Vec2f.{ 1, 1 }, 
    pop     := true
) -> bool {
    node := ui_push(id);
    defer if pop  ui_pop();
    
    mouse := get_mouse();
    
    parent_offset := node.parent.offset;
    parent_actor := get(get_actor_handle(node.parent));
    if parent_actor {
        if parent_actor.kind == {
          case .ENTITY;
            parent_offset = get_attachment_offset(parent_actor.(*Entity));
        }
    }
    
    size   := Vec2f.{ 1, 1 };
    
    offset := parent_offset + range.*;
    rect   := Rectf.{ position = offset - size/2, size = size };
    
    hovered := is_point_within_frect(Editor.mouse_tile_position, rect);
    update_active_hot_state(node, hovered);
    
    if node.flags & .ACTIVE {
        if mouse.left == {
          case .DOWN;
            offset += to_Vec2f(mouse.velocity) / Editor.tile_unit;
            
          case .RELEASED;
            offset = snap_to_nearest_unit(offset, 0.5);
        }
    }
    
    update_node(node, offset);
    range.* = (offset - parent_offset);
    
    color := get_render_color(node, base_color, hot_color, active_color);
    
    bound := Rectf.{ position = parent_offset - range.*, size = range.* * 2 };
    append_render_command_rect(*ui_state.draw_list,
        color    = color,
        rect = .{
            position = (bound.position - Editor.level.camera) * Editor.tile_unit,
            size     = bound.size * Editor.tile_unit,
        }
    );
    
    append_render_command_quad(*ui_state.draw_list,
        texture  = *textures.UI_ELEMENTS,
        clip     = *ui_texture_clip_circle,
        color    = color,
        position = (rect.position - Editor.level.camera) * Editor.tile_unit,
        size     = rect.size * Editor.tile_unit,
    );
    
    return !pop && ui_should_do_child_nodes(node);
}