
// This is like a crappy low tech version of the bucket array that I had been using in Odin mario, should probably just use bucket array instead
// TODO: we can improve at least somewhat by using a bitfield for the occupied flags.
//       this will make it faster to find the first unoccupied slot, and will make the actual array elements packed properly
//       easier to compact down elements, track the count of currently occupied slots

Slot_Array :: struct(T: Type, capacity: int) {
    next:           int;
    occupancy_mask: [capacity >> 6] s64;
    slots:          [capacity] T;
}

// TODO: decide if we want the slot getter procs to automatically set the returned slot as occupied

get_first_empty_slot :: (using array: *Slot_Array, set_occupied := false) -> *array.T, int {
    for 0..capacity-1  if !index_is_occupied(array, it)  { 
        if set_occupied then set_index_occupied(array, it, true);
        return *slots[it], it; 
    }
    return null, -1;
}

// TODO: optimize
get_next_empty_slot :: (using array: *Slot_Array, set_occupied := false) -> *array.T, int {
    for next..capacity-1  if !index_is_occupied(array, it) { 
        if set_occupied then set_index_occupied(array, it, true);
        array.next = it + 1;
        return *slots[it], it; 
    }
    for 0..next-1  if !index_is_occupied(array, it) { 
        if set_occupied then set_index_occupied(array, it, true);
        array.next = it + 1;
        return *slots[it], it; 
    }
    return null, -1;
}

get_next_slot :: (array: *Slot_Array, set_occupied := false) -> *array.T, int {
    if set_occupied then set_index_occupied(array, array.next, true);
    index := array.next;
    slot  := *array.slots[array.next];
    array.next = (array.next + 1) % array.capacity;
    return slot, index;
}

get_element_index :: (array: *Slot_Array, element: *array.T) -> int {
    assert(element >= array.slots.data && element < array.slots.data + array.capacity);
    return (element.(s64) - array.slots.data.(s64)) / size_of(array.T);
}

is_valid_index :: (array: Slot_Array, index: int) -> bool {
    return index >= 0 && index < array.capacity;
}

index_is_occupied :: (array: Slot_Array, index: int) -> bool {
    if !is_valid_index(array, index)  return false;
    return array.occupancy_mask[index >> 6] & (1 << (index & 63)) != 0;
}

// TODO: optimize so that we do the occupancy checking manually
// for_expansion :: (array: *Slot_Array, body: Code, flags: For_Flags) #expand {
//     REVERSE    :: cast(bool) flags & .REVERSE;
//     DO_POINTER :: cast(bool) flags & .POINTER;
//     for <=REVERSE *=DO_POINTER  `it, `it_index: array.slots {
//         if !index_is_occupied(array, it_index) continue;
//         #insert (remove={set_index_occupied(array, it_index, false);}) body;
//     }
// }

for_expansion :: (array: *Slot_Array, body: Code, flags: For_Flags) #expand {
    REVERSE    :: cast(bool) flags & .REVERSE;
    DO_POINTER :: cast(bool) flags & .POINTER;
    
    // TODO: implement reverse
    #assert(!REVERSE);
    
    // #if REVERSE {
        
    // }
    
    mask_ptr := array.occupancy_mask.data.(*u8);
    mask_bit: u8 = 1;
    
    it_ptr := array.slots.data;
    
    `it_index := 0;
    while it_index < array.capacity {
        // skip by 8 if byte is zero
        if it_index >> 3 == 0 && mask_ptr.* == 0 {
            mask_bit  = 1; // NOTE: may not be required?
            mask_ptr += 1;
            it_index += 8;
            it_ptr   += 8;
            continue;
        }
        
        if mask_ptr.* & mask_bit {
            #if DO_POINTER 
                then `it := it_ptr;
                else `it := it_ptr.*;
            #insert (remove={mask_ptr.* &= ~mask_bit;}) body;
        }
        
        it_index   += 1;
        it_ptr     += 1;
        
        mask_bit <<<= 1;
        mask_ptr += (mask_bit == 1).(u8);
    }
}

set_index_occupied :: (array: *Slot_Array, index: int, $$occupied: bool) {
    assert(is_valid_index(array, index));
    if occupied {
        array.occupancy_mask[index >> 6] |= (1 << (index & 63));
    } else {
        array.occupancy_mask[index >> 6] &= ~(1 << (index & 63));
    }
}

set_index_occupied :: (array: *Slot_Array, element: *array.T, $$occupied: bool) {
    index := get_element_index(array, element);
    if occupied {
        array.occupancy_mask[index >> 6] |= (1 << (index & 63));
    } else {
        array.occupancy_mask[index >> 6] &= ~(1 << (index & 63));
    }
}

// pairs :: (slot_array: *Slot_Array, body: Code, flags: For_Flags) #expand {
//     assert(flags & .REVERSE == 0, "cannot iterate slot array pairs in reverse");
//     DO_POINTER :: true;
//     for *=DO_POINTER  `it_a, `it_a_index: slot_array.slots {
//         if !it_a.occupied continue;
//         for *=DO_POINTER  `it_b, `it_b_index: slot_array.slots {
//             if !it_b.occupied || it_a == it_b continue;
//             #insert (remove={assert(false, "cannot remove when iterating pairs in slot array");}) body;
//         }
//     }
// }


operator[] :: (array: *Slot_Array, index: int) -> array.T {
    return array.slots[index];
}

operator*[] :: (array: *Slot_Array, index: int) -> *array.T {
    return *array.slots[index];
}

clone_to_view :: (array: Slot_Array) -> [] array.T {
    // TODO: make this more efficient
    occupied_count := 0;
    for array  occupied_count += 1; // iteration skips unoccipied slots automatically
    
    view  := NewArray(occupied_count, array.T, initialized = false); 
    index := 0;
    for array {
        view[index] = it;
        index += 1;
    }
    return view;
}

clone_from_view :: (array: *Slot_Array, view: [] array.T, assert_size := false) {
    if assert_size  assert(array.capacity >= view.count);
    for view  get_next_slot(array, true).* = it;
}