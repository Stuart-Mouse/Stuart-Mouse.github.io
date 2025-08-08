
/*
    Menu code for menus I would prefer not to build in dear imgui.
    Eventually maybe I'll build this out more into a bit more general purpose as time goes on.
    
    I'll probably replace the tile selector view with something more like the tilemap editor, 
        but using a tilemap that can't be editted.
        
        
    Because of the paletted rendering that I'm using in my game, I'm not quite sure how to display my textures in imgui menus
    there's probably some way I could do it through render callbacks, but I'm sure it would be slow and hacky.
    So I'm just writing my own cruddy menu code for some highly visual menus
    
    these aren't really immediate mode in the same way as imgui, since these are mostly quite stateful menus and I don't see much benefit to giving them an immediate-mode interface beyond what is strictly useful
    
    
    I may end up making my ui code a bit more useful over time, but I'd still like to avoid most of the complication that comes from jsut having free-floating windows.
    so maybe I will keep everything to anchored, non-overlapping panels. sort of like a tiling window manager
*/

/*
    Grid view usage currently
    disclaimer: it sucks because I'm building a single ui widget without any real framework

    begin_grid_view();
    
    add_element();
    add_element();
    add_element();
    
    end_grid_view();
    
    each element passes render data and callback + data, that will get executed as onclick event for that element
    this interface is somehow  better than the clusterfuck I had before
    
    I think the biggest drawback is that we arent' handling the onlick immediately, but I can't do that without rewriting the window size calculations atm.
    so any user_data pointer we pass to the callback needs to be valid until at least the end_grid_view call
*/

Old_Grid_View_Element :: struct {
    texture:    *Texture;
    clip:       Rectf;
    palette:    int;
    selected:   bool;
    on_click:   (*void, int, u64) -> ();
    user_data:  *void;
    user_id:    u64;
}

Old_Grid_View :: struct {
    tile_render_size:   Vector2;
    tile_padding:       Vector2;
    grid_size:          Vec2i;
    flags:              Old_Grid_View_Flags; // factor out later
    attachement:        Directions;      // factor out later
    
    hovered_tile:       int;
    // scroll:          Vector2;
    grid_size_current:  Vec2i;
    
    elements:           [..] Old_Grid_View_Element;
}

Old_Grid_View_Flags :: enum {
    FIT_WIDTH;
    FIT_HEIGHT;
    ALLOW_MULTI_SELECT;
}

update_grid_view :: (grid_view: *Old_Grid_View) {
    using grid_view;
    
    element_count := elements.count;
    
    max_grid_size := to_Vec2i(Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } / (tile_render_size + tile_padding));
    
    grid_size_current = grid_size;
    
    if flags & .FIT_WIDTH {
        print("max grid width %\n", max_grid_size.x);
        grid_size_current.x = min(grid_size_current.x, max_grid_size.x);
    }
    
    rows_required := element_count / grid_size_current.x;
    grid_size_current.y = xx (rows_required + (element_count % grid_size.x != 0).(int));
    
    total_render_size := to_Vec2f(grid_size_current) * (tile_render_size + tile_padding);
    
    margin: Vector2;
    if attachement == {
      case .L;
      case .R;
        margin = (Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } - total_render_size);
      case; // centered
        margin = (Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } - total_render_size) / 2;
    }
    
    hovered_tile_new := get_grid_index_checked(
        position  = to_Vec2f(mouse.position), 
        tile_size = tile_render_size, 
        grid_size = grid_size_current,
        margin    = tile_padding,
        offset    = margin
    );
    
    // TODO: don't really want to have another callback to get max index, but also don't want to move hovered tile to an invalid index
    // may just pass the old and new value to on click callback
    hovered_tile = ifx hovered_tile_new < element_count then hovered_tile_new else -1;
    
    if hovered_tile >= 0 
    && mouse.left == .PRESSED 
    && elements[hovered_tile].on_click {
        elements[hovered_tile].on_click(elements[hovered_tile].user_data, hovered_tile, elements[hovered_tile].user_id);
    }
}


render_grid_view :: (grid_view: *Old_Grid_View) {
    using grid_view;
    
    total_render_size := to_Vec2f(grid_size_current) * (tile_render_size + tile_padding);
    
    margin: Vector2;
    if attachement == {
      case .L;
      case .R;
        margin = (Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } - total_render_size);
      case; // centered
        margin = (Vector2.{ cast(float) WINDOW_WIDTH, cast(float) WINDOW_HEIGHT } - total_render_size) / 2;
    }
    
    // TODO: we should probably not be starting/ending render batch in this procedure...
    render_begin_batch();
    
    // TODO: setting or param for bg color
    bg_rect_position := margin - tile_padding / 2;
    render_draw_quad(
        position = bg_rect_position, 
        size     = total_render_size, 
        color    = .{ 0, 0, 0, 0.5 }, 
    );
    
    index := 0;
    for y: 0..cast(int)grid_size_current.y-1 {
        for x: 0..cast(int)grid_size_current.x-1 {
            if index >= elements.count  break;
            defer index += 1;
            
            if elements[index].selected {
                selected_tile_bg_rect := get_grid_tile_rect(
                    index        = index, 
                    tile_size    = tile_render_size, 
                    grid_size    = grid_size_current,
                    pixel_offset = margin,
                    margin       = tile_padding
                );
                
                render_draw_quad(
                    texture       = null,
                    color         = .{ 1, 1, 1, 0.75 },
                    position      = selected_tile_bg_rect.position,
                    size          = selected_tile_bg_rect.size,
                );
            }
            
            dst_rect := Rectf.{
                x = margin.x + cast(float) x * (tile_render_size.x + tile_padding.x),
                y = margin.y + cast(float) y * (tile_render_size.y + tile_padding.y),
                w = tile_render_size.x,
                h = tile_render_size.y,
            };
            
            render_draw_quad(
                texture       = elements[index].texture,
                clip          = *elements[index].clip,
                palette       = elements[index].palette,
                position      = dst_rect.position,
                size          = dst_rect.size,
            );
        }
    }
    
    mouse_tile_rect := get_grid_tile_rect(
        index        = hovered_tile, 
        tile_size    = tile_render_size, 
        grid_size    = grid_size_current,
        pixel_offset = margin,
        margin       = tile_padding
    );
    
    // TODO: setting for color of hovered tile
    render_draw_quad(
        texture       = null,
        color         = .{ 1, 1, 1, 0.25 },
        position      = mouse_tile_rect.position,
        size          = mouse_tile_rect.size,
    );
    
    render_end_batch();
    render_flush();
}

/*
    current interface for grid view sucks
    passing procedure for grid view to pull data
    what we want is to push data and icon to grid view through proc call and then get selected item back
    ideal interface would acutally be like
    
    if grid_view_element(...) {
        // do stuff on click
    }
    
    for each element, we want to 
        tell immediately whether it was clicked this frame
        save the given quad to render later
            cannot just render immediately because we may render menus with transparency over the main view (game/editor)
            
    we already know just based off of position of grid view and number of elements which element is hovered
    so in order to determine selected element, all we need to do is get that element by index
    
*/

// init state for this frame
// begin_grid_view :: (using grid_view: *Old_Grid_View) {
//     array_reset_keeping_memory(render_list);
// }

// add_element(grid_view: *Old_Grid_View, element: Old_Grid_View_Element) {
//     array_add(*grid_view.elements, element);
// }


// Menu_Global_State


// Window :: struct {
//     using rect : Rect; // when not fullscreen
//     flags : Window_Flags;
//     id    : u64;
// }

// Window_Flags :: enum {
//     SHOWN;
//     FULLSCREEN;
// }

// WINDOW_GRAB_MARGIN :: 2;
// WINDOW_BAR_HEIGHT  :: 16;
// WINDOW_BORDER_WDITH :: 1;

// update_window :: (win: *Window) {
//     if !(win.flags & .SHOWN)  return;
    
//     active_rect := rect;
//     if win.flags & .FULLSCREEN {
//         active_rect = { WINDOW_WIDTH, WINDOW_HEIGHT };
//     }
    
//     relative_mouse_position := mouse.position - active_rect.position;
//     mouse_position_in_window = mouse_position_in_rect - .{ 0, WINDOW_BAR_HEIGHT };
    
//     if is_point_within_rect(mouse_position_in_rect, )
    
// }

// render_window :: (win: *Window) {
//     if !(win.flags & .SHOWN)  return;
    
//     // render body bg rect
//     // render top bar bg rect
//     // render top bar title text
        
//     render_draw_quad(
//         position = win.position,
//         size     = win.size,
//     );
// }


// Menu_Element :: struct {
//     shown      : bool;
// }

// Sidebar :: struct {
//     attachment : Directions = .R;
//     content    : 
// }



// NOTE TO SELF: use gl viewport or gl scissor in order to only render to subsections of the window







