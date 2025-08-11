
// This name is so generic... maybe we should change it to Collectable?
Item :: struct {
    using #as base: Entity;
    
    item_type: Item_Type;
    
    COIN_SIZE :: Vec2f.{ 0.5, 1 };
}

Item_Type :: enum {
    COIN;
}

init_item :: (item: *Item, item_type: Item_Type) {
    if item.item_type == {
      case .COIN;
        item.palette = get_palette_index("coins");
        item.size = Item.COIN_SIZE;
    }
}

update_item :: (using item: *Item) {
    player      := *get_active_level().player;
    player_rect := get_collision_rect(player);
    item_rect   := get_collision_rect(item);
    
    if item_type == {
      case .COIN;
        velocity.y = min(default_enemy_physics.max_fall_speed, velocity.y + default_enemy_physics.jump_gravity);
        if player.state == .STANDARD && aabb_frect(player_rect, item_rect) {
            award_coins(player, 1);
        }
    }
}

render_item :: (using item: *Item, render_unit: float, offset: Vec2f, alpha_mod: float) {
    if item_type == {
      case .COIN;
        
    }
}

