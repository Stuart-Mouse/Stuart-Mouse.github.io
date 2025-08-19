// dear imgui: Renderer Backend for Vulkan
// 
// Straight ported from imgui-1.89.6/backends/imgui_impl_vulkan.cpp to start with, will likely evolve.
// 

// Implemented features:
//  [!] Renderer: User texture binding. Use 'VkDescriptorSet' as ImTextureID. Read the FAQ about ImTextureID! See https://github.com/ocornut/imgui/pull/914 for discussions.
//  [X] Renderer: Large meshes support (64k+ vertices) with 16-bit indices.

// Important note to the reader who wish to integrate imgui_impl_vulkan.cpp/.h in their own engine/app.
// - Common ImGui_ImplVulkan_XXX functions and structures are used to interface with imgui_impl_vulkan.cpp/.h.
//   You will use those if you want to use this rendering backend in your engine/app.
// - Helper ImGui_ImplVulkanH_XXX functions and structures are only used by this example (main.cpp) and by
//   the backend itself (imgui_impl_vulkan.cpp), but should PROBABLY NOT be used by your own engine/app code.
// Read comments in imgui_impl_vulkan.h.

//~
// imgui_impl_vulkan.h

// Vulkan includes

IMGUI_IMPL_VULKAN_NO_PROTOTYPES :: false;
VK_NO_PROTOTYPES :: IMGUI_IMPL_VULKAN_NO_PROTOTYPES;
#assert VK_NO_PROTOTYPES == false "Whatever Vulkan function loading imgui stuff is doing not supported for now!";

// Initialization data, for ImGui_ImplVulkan_Init()
// [Please zero-clear before use!]
ImGui_ImplVulkan_InitInfo :: struct {
    Instance: VkInstance;
    PhysicalDevice: VkPhysicalDevice;
    Device: VkDevice;
    QueueFamily: u32;
    Queue: VkQueue;
    PipelineCache: VkPipelineCache;
    DescriptorPool: VkDescriptorPool;
    Subpass: u32;
    MinImageCount: u32;            // >= 2
    ImageCount: u32;               // >= MinImageCount
    MSAASamples: VkSampleCountFlagBits; // >= ._1_BIT (0 -> default to ._1_BIT)
    Allocator: *VkAllocationCallbacks;
    CheckVkResultFn: #type (err: VkResult);
}


// ImGui_ImplVulkan_* are intended to be called from user code.
// ImGui_ImplVulkanH_* are helpers only intended to be internal to this code, or used in the imgui examples

// Helper structure to hold the data needed by one rendering frame
// (Used by example's main.cpp. Used by multi-viewport features. Probably NOT used by your own engine/app.)
// [Please zero-clear before use!]
ImGui_ImplVulkanH_Frame :: struct {
    CommandPool:    VkCommandPool;
    CommandBuffer:  VkCommandBuffer;
    Fence:          VkFence;
    Backbuffer:     VkImage;
    BackbufferView: VkImageView;
    Framebuffer:    VkFramebuffer;
}

ImGui_ImplVulkanH_FrameSemaphores :: struct {
    ImageAcquiredSemaphore:  VkSemaphore;
    RenderCompleteSemaphore: VkSemaphore;
}

// Helper structure to hold the data needed by one rendering context into one OS window
// (Used by example's main.cpp. Used by multi-viewport features. Probably NOT used by your own engine/app.)
ImGui_ImplVulkanH_Window :: struct {
    Width: s32;
    Height: s32;
    Swapchain: VkSwapchainKHR;
    Surface: VkSurfaceKHR;
    SurfaceFormat: VkSurfaceFormatKHR;
    PresentMode: VkPresentModeKHR = xx,no_check ~0; // Ensure we get an error if user doesn't set this.
    RenderPass: VkRenderPass;
    Pipeline: VkPipeline;               // The window pipeline may uses a different VkRenderPass than the one passed in ImGui_ImplVulkan_InitInfo
    ClearEnable := true;
    ClearValue: VkClearValue;

    FrameIndex: u32;             // Current frame being rendered to (0 <= FrameIndex < FrameInFlightCount)
    ImageCount: u32;             // Number of simultaneous in-flight frames (returned by vkGetSwapchainImagesKHR, usually derived from min_image_count)
    SemaphoreIndex: u32;         // Current set of swapchain wait semaphores we're using (needs to be distinct from per frame data)
    Frames:          [] ImGui_ImplVulkanH_Frame;
    FrameSemaphores: [] ImGui_ImplVulkanH_FrameSemaphores;
};

//~


// Reusable buffers used for rendering 1 current in-flight frame, for ImGui_ImplVulkan_RenderDrawData()
// [Please zero-clear before use!]
ImGui_ImplVulkanH_FrameRenderBuffers :: struct {
    Buffer :: struct {
        Memory: VkDeviceMemory;
        Size: VkDeviceSize;
        vk: VkBuffer; // Ooops capitalisation!
    }
    VertexBuffer: Buffer;
    IndexBuffer : Buffer;
};

// Each viewport will hold 1 ImGui_ImplVulkanH_WindowRenderBuffers
// [Please zero-clear before use!]
ImGui_ImplVulkanH_WindowRenderBuffers :: struct {
    Index: u32;
    FrameRenderBuffers: [] ImGui_ImplVulkanH_FrameRenderBuffers;
};

// Vulkan data
ImGui_ImplVulkan_Data :: struct {
    VulkanInitInfo:        ImGui_ImplVulkan_InitInfo;
    RenderPass:            VkRenderPass;
    BufferMemoryAlignment: VkDeviceSize = 256;
    PipelineCreateFlags:   VkPipelineCreateFlags;
    DescriptorSetLayout:   VkDescriptorSetLayout;
    PipelineLayout:        VkPipelineLayout;
    Pipeline:              VkPipeline;
    Subpass: u32;
    ShaderModuleVert: VkShaderModule;
    ShaderModuleFrag: VkShaderModule;

    // Font data
    FontSampler: VkSampler;
    FontMemory:  VkDeviceMemory;
    FontImage:   VkImage;
    FontView:    VkImageView;
    FontDescriptorSet:  VkDescriptorSet;
    UploadBufferMemory: VkDeviceMemory;
    UploadBuffer: VkBuffer;

    // Render buffers for main window
    MainWindowRenderBuffers: ImGui_ImplVulkanH_WindowRenderBuffers;
};

// Vulkan prototypes for use with custom loaders
// (see description of IMGUI_IMPL_VULKAN_NO_PROTOTYPES in imgui_impl_vulkan.h
#if VK_NO_PROTOTYPES {
    g_FunctionsLoaded := false;
} else {
    g_FunctionsLoaded := true;
}

#if VK_NO_PROTOTYPES {
    /*
#define IMGUI_VULKAN_FUNC_MAP(IMGUI_VULKAN_FUNC_MAP_MACRO) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkAllocateCommandBuffers) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkAllocateDescriptorSets) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkAllocateMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkBindBufferMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkBindImageMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdBindDescriptorSets) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdBindIndexBuffer) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdBindPipeline) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdBindVertexBuffers) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdCopyBufferToImage) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdDrawIndexed) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdPipelineBarrier) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdPushConstants) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdSetScissor) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCmdSetViewport) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateBuffer) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateCommandPool) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateDescriptorSetLayout) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateFence) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateFramebuffer) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateGraphicsPipelines) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateImage) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateImageView) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreatePipelineLayout) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateRenderPass) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateSampler) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateSemaphore) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateShaderModule) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkCreateSwapchainKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyBuffer) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyCommandPool) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyDescriptorSetLayout) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyFence) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyFramebuffer) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyImage) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyImageView) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyPipeline) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyPipelineLayout) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyRenderPass) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroySampler) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroySemaphore) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroyShaderModule) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroySurfaceKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDestroySwapchainKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkDeviceWaitIdle) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkFlushMappedMemoryRanges) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkFreeCommandBuffers) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkFreeDescriptorSets) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkFreeMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetBufferMemoryRequirements) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetImageMemoryRequirements) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetPhysicalDeviceMemoryProperties) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetPhysicalDeviceSurfaceCapabilitiesKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetPhysicalDeviceSurfaceFormatsKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetPhysicalDeviceSurfacePresentModesKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkGetSwapchainImagesKHR) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkMapMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkUnmapMemory) \
    IMGUI_VULKAN_FUNC_MAP_MACRO(vkUpdateDescriptorSets)

// Define function pointers
#define IMGUI_VULKAN_FUNC_DEF(func) static PFN_##func func;
IMGUI_VULKAN_FUNC_MAP(IMGUI_VULKAN_FUNC_DEF)
#undef IMGUI_VULKAN_FUNC_DEF
*/
}

//-----------------------------------------------------------------------------
// FUNCTIONS
//-----------------------------------------------------------------------------

ImGui_ImplVulkan_MemoryType :: (properties: VkMemoryPropertyFlags, type_bits: u32) -> u32 {
    bd := ImGui_ImplVulkan_GetBackendData();
    v  := *bd.VulkanInitInfo;
    prop: VkPhysicalDeviceMemoryProperties;
    vkGetPhysicalDeviceMemoryProperties(v.PhysicalDevice, *prop);
    for 0..prop.memoryTypeCount-1 {
        if (prop.memoryTypes[it].propertyFlags & properties) == properties && type_bits & (1 << it) {
            return it;
        }
    }

    return 0xFFFFFFFF; // Unable to find memoryType
}

// @TODO(Charles): Wrap these VKBuffer, VkDeviceMemory, VkDeviceSize in struct and pass pointer to that?!
CreateOrResizeBuffer :: (buffer: *ImGui_ImplVulkanH_FrameRenderBuffers.Buffer, new_size: u64, usage: VkBufferUsageFlagBits) {
    bd := ImGui_ImplVulkan_GetBackendData();
    v := *bd.VulkanInitInfo;
    err: VkResult;
    if buffer.vk     != VK_NULL_HANDLE  vkDestroyBuffer(v.Device, buffer.vk, v.Allocator);
    if buffer.Memory != VK_NULL_HANDLE  vkFreeMemory(v.Device, buffer.Memory, v.Allocator);

    vertex_buffer_size_aligned := cast(VkDeviceSize) (((new_size - 1) / bd.BufferMemoryAlignment + 1) * bd.BufferMemoryAlignment);
    buffer_info := VkBufferCreateInfo.{
        size = vertex_buffer_size_aligned,
        usage = usage,
        sharingMode = .EXCLUSIVE,
    };
    err = vkCreateBuffer(v.Device, *buffer_info, v.Allocator, *buffer.vk);
    check_vk_result(err);

    req: VkMemoryRequirements;
    vkGetBufferMemoryRequirements(v.Device, buffer.vk, *req);
    if bd.BufferMemoryAlignment > req.alignment {
        bd.BufferMemoryAlignment =  bd.BufferMemoryAlignment;
    } else {
        bd.BufferMemoryAlignment =  req.alignment;
    }
    alloc_info: VkMemoryAllocateInfo;
    alloc_info.allocationSize = req.size;
    alloc_info.memoryTypeIndex = ImGui_ImplVulkan_MemoryType(.HOST_VISIBLE_BIT, req.memoryTypeBits);
    err = vkAllocateMemory(v.Device, *alloc_info, v.Allocator, *buffer.Memory);
    check_vk_result(err);

    err = vkBindBufferMemory(v.Device, buffer.vk, buffer.Memory, 0);
    check_vk_result(err);
    buffer.Size = req.size;
}

ImGui_ImplVulkan_SetupRenderState :: (draw_data: *ImDrawData, pipeline: VkPipeline, command_buffer: VkCommandBuffer, rb: *ImGui_ImplVulkanH_FrameRenderBuffers, fb_width: s32, fb_height: s32) {
    bd := ImGui_ImplVulkan_GetBackendData();

    // Bind pipeline:
    {
        vkCmdBindPipeline(command_buffer, .GRAPHICS, pipeline);
    }

    // Bind Vertex And Index Buffer:
    if draw_data.TotalVtxCount > 0 {
        vertex_buffer := rb.VertexBuffer.vk;
        vertex_offset := cast(VkDeviceSize) 0;
        vkCmdBindVertexBuffers(command_buffer, 0, 1, *vertex_buffer, *vertex_offset);
        #assert size_of(ImDrawIdx) == 2 "ImDrawIdx should be u16 in jai bindings!";
        vkCmdBindIndexBuffer(command_buffer, rb.IndexBuffer.vk, 0, .UINT16);
    }

    // Setup viewport:
    {
        viewport: VkViewport;
        viewport.x = 0;
        viewport.y = 0;
        viewport.width = xx fb_width;
        viewport.height = xx fb_height;
        viewport.minDepth = 0.;
        viewport.maxDepth = 1.;
        vkCmdSetViewport(command_buffer, 0, 1, *viewport);
    }

    // Setup scale and translation:
    // Our visible imgui space lies from draw_data.DisplayPps (top left) to draw_data.DisplayPos+data_data.DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    {
        scale := float.[
            2. / draw_data.DisplaySize.x,
            2. / draw_data.DisplaySize.y,
        ];
        translate := float.[
            -1. - draw_data.DisplayPos.x * scale[0],
            -1. - draw_data.DisplayPos.y * scale[1],
        ];
        vkCmdPushConstants(command_buffer, bd.PipelineLayout, .VERTEX_BIT, size_of(float) * 0, size_of(float) * 2, scale.data);
        vkCmdPushConstants(command_buffer, bd.PipelineLayout, .VERTEX_BIT, size_of(float) * 2, size_of(float) * 2, translate.data);
    }
}

// Render function
ImGui_ImplVulkan_RenderDrawData :: (draw_data: *ImDrawData, command_buffer: VkCommandBuffer, pipeline: VkPipeline = VK_NULL_HANDLE) {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width  := cast(s32)(draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    fb_height := cast(s32)(draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if fb_width <= 0 || fb_height <= 0  return;

    bd := ImGui_ImplVulkan_GetBackendData();
    v := *bd.VulkanInitInfo;
    if pipeline == VK_NULL_HANDLE  pipeline = bd.Pipeline;

    // Allocate array to store enough vertex/index buffers
    wrb := *bd.MainWindowRenderBuffers;
    if wrb.FrameRenderBuffers.data == null {
        wrb.Index = 0;
        wrb.FrameRenderBuffers = NewArray(v.ImageCount, ImGui_ImplVulkanH_FrameRenderBuffers);
    }
    assert(wrb.FrameRenderBuffers.count == v.ImageCount);
    wrb.Index = xx ((wrb.Index + 1) % wrb.FrameRenderBuffers.count);
    rb := *wrb.FrameRenderBuffers[wrb.Index];

    if draw_data.TotalVtxCount > 0 {
        // Create or resize the vertex/index buffers
        vertex_size := cast(u64) draw_data.TotalVtxCount * size_of(ImDrawVert);
        index_size  := cast(u64) draw_data.TotalIdxCount * size_of(ImDrawIdx);
        if rb.VertexBuffer.vk == VK_NULL_HANDLE || rb.VertexBuffer.Size < vertex_size {
            CreateOrResizeBuffer(*rb.VertexBuffer, vertex_size, .VERTEX_BUFFER_BIT);
        }
        if rb.IndexBuffer.vk == VK_NULL_HANDLE || rb.IndexBuffer.Size < index_size {
            CreateOrResizeBuffer(*rb.IndexBuffer, index_size, .INDEX_BUFFER_BIT);
        }

        // Upload vertex/index data into a single contiguous GPU buffer
        vtx_dst: *ImDrawVert;
        idx_dst: *ImDrawIdx;
        err: VkResult;
        err = vkMapMemory(v.Device, rb.VertexBuffer.Memory, 0, rb.VertexBuffer.Size, 0, xx *vtx_dst);
        check_vk_result(err);
        err = vkMapMemory(v.Device, rb.IndexBuffer.Memory, 0, rb.IndexBuffer.Size, 0, xx *idx_dst);
        check_vk_result(err);
        for 0..draw_data.CmdListsCount-1 {
            cmd_list := draw_data.CmdLists[it];
            memcpy(vtx_dst, cmd_list.VtxBuffer.Data, cmd_list.VtxBuffer.Size * size_of(ImDrawVert));
            memcpy(idx_dst, cmd_list.IdxBuffer.Data, cmd_list.IdxBuffer.Size * size_of(ImDrawIdx));
            vtx_dst += cmd_list.VtxBuffer.Size;
            idx_dst += cmd_list.IdxBuffer.Size;
        }

        ranges: [2] VkMappedMemoryRange;
        ranges[0].memory = rb.VertexBuffer.Memory;
        ranges[0].size = VK_WHOLE_SIZE;
        ranges[1].memory = rb.IndexBuffer.Memory;
        ranges[1].size = VK_WHOLE_SIZE;
        err = vkFlushMappedMemoryRanges(v.Device, ranges.count, ranges.data);
        check_vk_result(err);

        vkUnmapMemory(v.Device, rb.VertexBuffer.Memory);
        vkUnmapMemory(v.Device, rb.IndexBuffer.Memory);
    }

    // Setup desired Vulkan state
    ImGui_ImplVulkan_SetupRenderState(draw_data, pipeline, command_buffer, rb, fb_width, fb_height);

    // Will project scissor/clipping rectangles into framebuffer space
    clip_off   := draw_data.DisplayPos;       // (0,0) unless using multi-viewports
    clip_scale := draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    // Render command lists
    // (Because we merged all buffers into a single one, we maintain our own offset into them)
    global_vtx_offset: u32;
    global_idx_offset: u32;
    for 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists[it];

        for cmd_index: 0..cmd_list.CmdBuffer.Size-1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_index]; // ImVector::operator[] has bounds checking in c++

            if pcmd.UserCallback {
                // User callback, registered via ImDrawList::AddCallback()
                // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                if pcmd.UserCallback == ImDrawCallback_ResetRenderState {
                    ImGui_ImplVulkan_SetupRenderState(draw_data, pipeline, command_buffer, rb, fb_width, fb_height);
                } else {
                    pcmd.UserCallback(cmd_list, pcmd);
                }

            } else {
                // Project scissor/clipping rectangles into framebuffer space
                clip_min := ImVec2.{(pcmd.ClipRect.x - clip_off.x) * clip_scale.x, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y};
                clip_max := ImVec2.{(pcmd.ClipRect.z - clip_off.x) * clip_scale.x, (pcmd.ClipRect.w - clip_off.y) * clip_scale.y};

                // Clamp to viewport as vkCmdSetScissor() won't accept values that are off bounds
                if clip_min.x < 0.  clip_min.x = 0.;
                if clip_min.y < 0.  clip_min.y = 0.;
                if clip_max.x > xx fb_width   clip_max.x = xx fb_width;
                if clip_max.y > xx fb_height  clip_max.y = xx fb_height;
                if clip_max.x <= clip_min.x || clip_max.y <= clip_min.y  continue;

                // Apply scissor/clipping rectangle
                scissor: VkRect2D;
                scissor.offset.x = xx clip_min.x;
                scissor.offset.y = xx clip_min.y;
                scissor.extent.width  = xx (clip_max.x - clip_min.x);
                scissor.extent.height = xx (clip_max.y - clip_min.y);
                vkCmdSetScissor(command_buffer, 0, 1, *scissor);

                // Bind DescriptorSet with font or user texture
                desc_set := cast(VkDescriptorSet) pcmd.TextureId;
                #assert size_of(ImTextureID) == size_of(ImU64) "Some crap about ImTextureID needing to be 64 bit. Which it always should be with jai bindings!";
                vkCmdBindDescriptorSets(command_buffer, .GRAPHICS, bd.PipelineLayout, 0, 1, *desc_set, 0, null);

                // Draw
                vkCmdDrawIndexed(command_buffer, pcmd.ElemCount, 1, pcmd.IdxOffset + global_idx_offset, xx(pcmd.VtxOffset + global_vtx_offset), 0);
            }
        }
        global_idx_offset += cast(u32) cmd_list.IdxBuffer.Size;
        global_vtx_offset += cast(u32) cmd_list.VtxBuffer.Size;
    }

    // Note: at this point both vkCmdSetViewport() and vkCmdSetScissor() have been called.
    // Our last values will leak into user/application rendering IF:
    // - Your app uses a pipeline with .VIEWPORT or .SCISSOR dynamic state
    // - And you forgot to call vkCmdSetViewport() and vkCmdSetScissor() yourself to explicitly set that state.
    // If you use .VIEWPORT or .SCISSOR you are responsible for setting the values before rendering.
    // In theory we should aim to backup/restore those values but I am not sure this is possible.
    // We perform a call to vkCmdSetScissor() to set back a full viewport which is likely to fix things for 99% users but technically this is not perfect. (See github #4644)
    scissor := VkRect2D.{
        extent = .{xx fb_width, xx fb_height},
    };
    vkCmdSetScissor(command_buffer, 0, 1, *scissor);
}

ImGui_ImplVulkan_CreateFontsTexture :: (command_buffer: VkCommandBuffer) -> bool {
    io := ImGui.GetIO();
    bd := ImGui_ImplVulkan_GetBackendData();
    v  := *bd.VulkanInitInfo;

    pixels: *u8;
    width, height: s32;
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
    upload_size := cast(u64) (width * height * 4 * size_of(u8));

    err: VkResult;

    // Create the Image:
    {
        info: VkImageCreateInfo;
        info.imageType = ._2D;
        info.format = .R8G8B8A8_UNORM;
        info.extent.width  = xx width;
        info.extent.height = xx height;
        info.extent.depth = 1;
        info.mipLevels = 1;
        info.arrayLayers = 1;
        info.samples = ._1_BIT;
        info.tiling = .OPTIMAL;
        info.usage = .SAMPLED_BIT | .TRANSFER_DST_BIT;
        info.sharingMode = .EXCLUSIVE;
        info.initialLayout = .UNDEFINED;
        err = vkCreateImage(v.Device, *info, v.Allocator, *bd.FontImage);
        check_vk_result(err);

        req: VkMemoryRequirements;
        vkGetImageMemoryRequirements(v.Device, bd.FontImage, *req);
        
        alloc_info: VkMemoryAllocateInfo;
        alloc_info.allocationSize = req.size;
        alloc_info.memoryTypeIndex = ImGui_ImplVulkan_MemoryType(.DEVICE_LOCAL_BIT, req.memoryTypeBits);
        err = vkAllocateMemory(v.Device, * alloc_info, v.Allocator, *bd.FontMemory);
        check_vk_result(err);

        err = vkBindImageMemory(v.Device, bd.FontImage, bd.FontMemory, 0);
        check_vk_result(err);
    }

    // Create the Image View:
    {
        info: VkImageViewCreateInfo;
        info.image = bd.FontImage;
        info.viewType = ._2D;
        info.format = .R8G8B8A8_UNORM;
        info.subresourceRange.aspectMask = .COLOR_BIT;
        info.subresourceRange.levelCount = 1;
        info.subresourceRange.layerCount = 1;
        err = vkCreateImageView(v.Device, *info, v.Allocator, *bd.FontView);
        check_vk_result(err);
    }

    // Create the Descriptor Set:
    bd.FontDescriptorSet = ImGui_ImplVulkan_AddTexture(bd.FontSampler, bd.FontView, .SHADER_READ_ONLY_OPTIMAL);

    // Create the Upload Buffer:
    {
        buffer_info: VkBufferCreateInfo;
        buffer_info.size = upload_size;
        buffer_info.usage = .TRANSFER_SRC_BIT;
        buffer_info.sharingMode = .EXCLUSIVE;
        err = vkCreateBuffer(v.Device, *buffer_info, v.Allocator, *bd.UploadBuffer);
        check_vk_result(err);

        req: VkMemoryRequirements;
        vkGetBufferMemoryRequirements(v.Device, bd.UploadBuffer, *req);

        if (bd.BufferMemoryAlignment > req.alignment) {
            bd.BufferMemoryAlignment = bd.BufferMemoryAlignment;
        } else {
            bd.BufferMemoryAlignment = req.alignment;
        }

        alloc_info: VkMemoryAllocateInfo;
        alloc_info.allocationSize = req.size;
        alloc_info.memoryTypeIndex = ImGui_ImplVulkan_MemoryType(.HOST_VISIBLE_BIT, req.memoryTypeBits);
        err = vkAllocateMemory(v.Device, *alloc_info, v.Allocator, *bd.UploadBufferMemory);
        check_vk_result(err);

        err = vkBindBufferMemory(v.Device, bd.UploadBuffer, bd.UploadBufferMemory, 0);
        check_vk_result(err);
    }

    // Upload to Buffer:
    {
        map: *u8;
        err = vkMapMemory(v.Device, bd.UploadBufferMemory, 0, upload_size, 0, xx *map);
        check_vk_result(err);

        memcpy(map, pixels, xx upload_size);

        range := VkMappedMemoryRange.{
            memory = bd.UploadBufferMemory,
            size = upload_size,
        };
        err = vkFlushMappedMemoryRanges(v.Device, 1, *range);
        check_vk_result(err);

        vkUnmapMemory(v.Device, bd.UploadBufferMemory);
    }

    // Copy to Image:
    {
        copy_barrier: VkImageMemoryBarrier;
        copy_barrier.dstAccessMask = .TRANSFER_WRITE_BIT;
        copy_barrier.oldLayout = .UNDEFINED;
        copy_barrier.newLayout = .TRANSFER_DST_OPTIMAL;
        copy_barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        copy_barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        copy_barrier.image = bd.FontImage;
        copy_barrier.subresourceRange.aspectMask = .COLOR_BIT;
        copy_barrier.subresourceRange.levelCount = 1;
        copy_barrier.subresourceRange.layerCount = 1;
        vkCmdPipelineBarrier(command_buffer, .HOST_BIT, .TRANSFER_BIT, 0, 0, null, 0, null, 1, *copy_barrier);

        region: VkBufferImageCopy;
        region.imageSubresource.aspectMask = .COLOR_BIT;
        region.imageSubresource.layerCount = 1;
        region.imageExtent.width  = xx width;
        region.imageExtent.height = xx height;
        region.imageExtent.depth = 1;
        vkCmdCopyBufferToImage(command_buffer, bd.UploadBuffer, bd.FontImage, .TRANSFER_DST_OPTIMAL, 1, *region);

        use_barrier: VkImageMemoryBarrier;
        use_barrier.srcAccessMask = .TRANSFER_WRITE_BIT;
        use_barrier.dstAccessMask = .SHADER_READ_BIT;
        use_barrier.oldLayout = .TRANSFER_DST_OPTIMAL;
        use_barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL;
        use_barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        use_barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        use_barrier.image = bd.FontImage;
        use_barrier.subresourceRange.aspectMask = .COLOR_BIT;
        use_barrier.subresourceRange.levelCount = 1;
        use_barrier.subresourceRange.layerCount = 1;
        vkCmdPipelineBarrier(command_buffer, .TRANSFER_BIT, .FRAGMENT_SHADER_BIT, 0, 0, null, 0, null, 1, *use_barrier);
    }

    // Store our identifier
    io.Fonts.TexID = cast(ImTextureID) bd.FontDescriptorSet;

    return true;
}

ImGui_ImplVulkan_CreateShaderModules :: (device: VkDevice, allocator: *VkAllocationCallbacks) {
    // Create the shader modules
    bd := ImGui_ImplVulkan_GetBackendData();
    if bd.ShaderModuleVert == VK_NULL_HANDLE {
        vert_info: VkShaderModuleCreateInfo;
        vert_info.codeSize = size_of(type_of(__glsl_shader_vert_spv));
        vert_info.pCode = __glsl_shader_vert_spv.data;
        err := vkCreateShaderModule(device, *vert_info, allocator, *bd.ShaderModuleVert);
        check_vk_result(err);
    }

    if bd.ShaderModuleFrag == VK_NULL_HANDLE {
        frag_info: VkShaderModuleCreateInfo;
        frag_info.codeSize = size_of(type_of(__glsl_shader_frag_spv));
        frag_info.pCode = __glsl_shader_frag_spv.data;
        err := vkCreateShaderModule(device, *frag_info, allocator, *bd.ShaderModuleFrag);
        check_vk_result(err);
    }
}

ImGui_ImplVulkan_CreatePipeline :: (device: VkDevice, allocator: *VkAllocationCallbacks, pipelineCache: VkPipelineCache, renderPass: VkRenderPass, MSAASamples: VkSampleCountFlagBits, pipeline: *VkPipeline, subpass: u32) {
    bd := ImGui_ImplVulkan_GetBackendData();
    ImGui_ImplVulkan_CreateShaderModules(device, allocator);

    stage := VkPipelineShaderStageCreateInfo.[
        .{
            stage = .VERTEX_BIT,
            module = bd.ShaderModuleVert,
            pName = "main",
        },
        .{
            stage = .FRAGMENT_BIT,
            module = bd.ShaderModuleFrag,
            pName = "main",
        },
    ];

    binding_desc: VkVertexInputBindingDescription;
    binding_desc.stride = size_of(ImDrawVert);
    binding_desc.inputRate = .VERTEX;

    offset_of: *ImDrawVert;

    attribute_desc := VkVertexInputAttributeDescription.[
        .{
            location = 0,
            binding = binding_desc.binding,
            format = .R32G32_SFLOAT,
            offset = xx *offset_of.pos,
        },
        .{
            location = 1,
            binding = binding_desc.binding,
            format = .R32G32_SFLOAT,
            offset = xx *offset_of.uv,
        },
        .{
            location = 2,
            binding = binding_desc.binding,
            format = .R8G8B8A8_UNORM,
            offset = xx *offset_of.col,
        },
    ];

    vertex_info: VkPipelineVertexInputStateCreateInfo;
    vertex_info.vertexBindingDescriptionCount = 1;
    vertex_info.pVertexBindingDescriptions = *binding_desc;
    vertex_info.vertexAttributeDescriptionCount = 3;
    vertex_info.pVertexAttributeDescriptions = attribute_desc.data;

    ia_info: VkPipelineInputAssemblyStateCreateInfo;
    ia_info.topology = .TRIANGLE_LIST;

    viewport_info: VkPipelineViewportStateCreateInfo;
    viewport_info.viewportCount = 1;
    viewport_info.scissorCount = 1;

    raster_info: VkPipelineRasterizationStateCreateInfo;
    raster_info.polygonMode = .FILL;
    raster_info.cullMode = .NONE;
    raster_info.frontFace = .COUNTER_CLOCKWISE;
    raster_info.lineWidth = 1.;

    ms_info: VkPipelineMultisampleStateCreateInfo;
    ms_info.rasterizationSamples = ifx MSAASamples != 0  MSAASamples else ._1_BIT;

    color_attachment: VkPipelineColorBlendAttachmentState;
    color_attachment.blendEnable = VK_TRUE;
    color_attachment.srcColorBlendFactor = .SRC_ALPHA;
    color_attachment.dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA;
    color_attachment.colorBlendOp = .ADD;
    color_attachment.srcAlphaBlendFactor = .ONE;
    color_attachment.dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA;
    color_attachment.alphaBlendOp = .ADD;
    color_attachment.colorWriteMask = .R_BIT | .G_BIT | .B_BIT | .A_BIT;

    depth_info: VkPipelineDepthStencilStateCreateInfo;

    blend_info: VkPipelineColorBlendStateCreateInfo;
    blend_info.attachmentCount = 1;
    blend_info.pAttachments = *color_attachment;

    dynamic_states := VkDynamicState.[.VIEWPORT, .SCISSOR];
    dynamic_state: VkPipelineDynamicStateCreateInfo;
    dynamic_state.dynamicStateCount = dynamic_states.count;
    dynamic_state.pDynamicStates = dynamic_states.data;

    info: VkGraphicsPipelineCreateInfo;
    info.flags = bd.PipelineCreateFlags;
    info.stageCount = stage.count;
    info.pStages    = stage.data;
    info.pVertexInputState   = *vertex_info;
    info.pInputAssemblyState = *ia_info;
    info.pViewportState      = *viewport_info;
    info.pRasterizationState = *raster_info;
    info.pMultisampleState   = *ms_info;
    info.pDepthStencilState  = *depth_info;
    info.pColorBlendState    = *blend_info;
    info.pDynamicState       = *dynamic_state;
    info.layout = bd.PipelineLayout;
    info.renderPass = renderPass;
    info.subpass = subpass;
    err := vkCreateGraphicsPipelines(device, pipelineCache, 1, *info, allocator, pipeline);
    check_vk_result(err);
}

ImGui_ImplVulkan_CreateDeviceObjects :: () -> bool
{
    bd := ImGui_ImplVulkan_GetBackendData();
    v := *bd.VulkanInitInfo;
    err: VkResult;

    if !bd.FontSampler {
        // Bilinear sampling is required by default. Set 'io.Fonts.Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling.
        info: VkSamplerCreateInfo;
        info.magFilter = .LINEAR;
        info.minFilter = .LINEAR;
        info.mipmapMode = .LINEAR;
        info.addressModeU = .REPEAT;
        info.addressModeV = .REPEAT;
        info.addressModeW = .REPEAT;
        info.minLod = -1000;
        info.maxLod = 1000;
        info.maxAnisotropy = 1.;
        err = vkCreateSampler(v.Device, *info, v.Allocator, *bd.FontSampler);
        check_vk_result(err);
    }

    if !bd.DescriptorSetLayout {
        binding: VkDescriptorSetLayoutBinding;
        binding.descriptorType = .COMBINED_IMAGE_SAMPLER;
        binding.descriptorCount = 1;
        binding.stageFlags = .FRAGMENT_BIT;

        info: VkDescriptorSetLayoutCreateInfo;
        info.bindingCount = 1;
        info.pBindings = *binding;
        err = vkCreateDescriptorSetLayout(v.Device, *info, v.Allocator, *bd.DescriptorSetLayout);
        check_vk_result(err);
    }

    if !bd.PipelineLayout {
        // Constants: we are using 'vec2 offset' and 'vec2 scale' instead of a full 3d projection matrix
        push_constants: VkPushConstantRange;
        push_constants.stageFlags = .VERTEX_BIT;
        push_constants.offset = size_of(float) * 0;
        push_constants.size   = size_of(float) * 4;

        layout_info: VkPipelineLayoutCreateInfo;
        layout_info.setLayoutCount = 1;
        layout_info.pSetLayouts = *bd.DescriptorSetLayout;
        layout_info.pushConstantRangeCount = 1;
        layout_info.pPushConstantRanges = *push_constants;
        err = vkCreatePipelineLayout(v.Device, *layout_info, v.Allocator, *bd.PipelineLayout);
        check_vk_result(err);
    }

    if bd.Pipeline == VK_NULL_HANDLE {
        ImGui_ImplVulkan_CreatePipeline(v.Device, v.Allocator, v.PipelineCache, bd.RenderPass, v.MSAASamples, *bd.Pipeline, bd.Subpass);
    }

    return true;
}


ImGui_ImplVulkan_DestroyFontUploadObjects :: () {
    bd := ImGui_ImplVulkan_GetBackendData();
    v  := *bd.VulkanInitInfo;

    if bd.UploadBuffer {
        vkDestroyBuffer(v.Device, bd.UploadBuffer, v.Allocator);
        bd.UploadBuffer = VK_NULL_HANDLE;
    }

    if bd.UploadBufferMemory {
        vkFreeMemory(v.Device, bd.UploadBufferMemory, v.Allocator);
        bd.UploadBufferMemory = VK_NULL_HANDLE;
    }
}

ImGui_ImplVulkan_DestroyDeviceObjects :: () {
    bd := ImGui_ImplVulkan_GetBackendData();
    v  := *bd.VulkanInitInfo;

    ImGui_ImplVulkanH_DestroyWindowRenderBuffers(v.Device, *bd.MainWindowRenderBuffers, v.Allocator);
    ImGui_ImplVulkan_DestroyFontUploadObjects();

    if bd.ShaderModuleVert     { vkDestroyShaderModule(v.Device, bd.ShaderModuleVert, v.Allocator)          ; bd.ShaderModuleVert = VK_NULL_HANDLE; }
    if bd.ShaderModuleFrag     { vkDestroyShaderModule(v.Device, bd.ShaderModuleFrag, v.Allocator)          ; bd.ShaderModuleFrag = VK_NULL_HANDLE; }
    if bd.FontView             { vkDestroyImageView(v.Device, bd.FontView, v.Allocator)                     ; bd.FontView    = VK_NULL_HANDLE; }
    if bd.FontImage            { vkDestroyImage(v.Device, bd.FontImage, v.Allocator)                        ; bd.FontImage   = VK_NULL_HANDLE; }
    if bd.FontMemory           { vkFreeMemory(v.Device, bd.FontMemory, v.Allocator)                         ; bd.FontMemory  = VK_NULL_HANDLE; }
    if bd.FontSampler          { vkDestroySampler(v.Device, bd.FontSampler, v.Allocator)                    ; bd.FontSampler = VK_NULL_HANDLE; }
    if bd.DescriptorSetLayout  { vkDestroyDescriptorSetLayout(v.Device, bd.DescriptorSetLayout, v.Allocator); bd.DescriptorSetLayout = VK_NULL_HANDLE; }
    if bd.PipelineLayout       { vkDestroyPipelineLayout(v.Device, bd.PipelineLayout, v.Allocator)          ; bd.PipelineLayout = VK_NULL_HANDLE; }
    if bd.Pipeline             { vkDestroyPipeline(v.Device, bd.Pipeline, v.Allocator)                      ; bd.Pipeline = VK_NULL_HANDLE; }
}

/*
// Optional: load Vulkan functions with a custom function loader
// This is only useful with IMGUI_IMPL_VULKAN_NO_PROTOTYPES / VK_NO_PROTOTYPES
ImGui_ImplVulkan_LoadFunctions :: (PFN_vkVoidFunction(*loader_func)(const char* function_name, void* user_data), user_data: *void) -> bool
{
    // Load function pointers
    // You can use the default Vulkan loader using:
    //      ImGui_ImplVulkan_LoadFunctions([](const char* function_name, void*) { return vkGetInstanceProcAddr(your_vk_isntance, function_name); });
    // But this would be equivalent to not setting VK_NO_PROTOTYPES.
#ifdef VK_NO_PROTOTYPES
#define IMGUI_VULKAN_FUNC_LOAD(func) \
    func = reinterpret_cast<decltype(func)>(loader_func(#func, user_data)); \
    if (func == null)   \
        return false;
    IMGUI_VULKAN_FUNC_MAP(IMGUI_VULKAN_FUNC_LOAD)
#undef IMGUI_VULKAN_FUNC_LOAD
#else
    IM_UNUSED(loader_func);
    IM_UNUSED(user_data);
#endif
    g_FunctionsLoaded = true;
    return true;
}
*/

ImGui_ImplVulkan_Init :: (info: *ImGui_ImplVulkan_InitInfo, render_pass: VkRenderPass) -> bool {
    assert(g_FunctionsLoaded, "Need to call ImGui_ImplVulkan_LoadFunctions() if IMGUI_IMPL_VULKAN_NO_PROTOTYPES or VK_NO_PROTOTYPES are set!");

    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == null, "Already initialized a renderer backend!");

    // Setup backend capabilities flags
    // bd := NEW(ImGui_ImplVulkan_Data); // :TheOneImGuiVulkan
    bd := *imgui_vulkan_backend_data;

    io.BackendRendererUserData = xx bd;
    io.BackendRendererName = "imgui_impl_vulkan".data;
    io.BackendFlags_ |= .RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.

    assert(info.Instance != VK_NULL_HANDLE);
    assert(info.PhysicalDevice != VK_NULL_HANDLE);
    assert(info.Device != VK_NULL_HANDLE);
    assert(info.Queue != VK_NULL_HANDLE);
    assert(info.DescriptorPool != VK_NULL_HANDLE);
    assert(info.MinImageCount >= 2);
    assert(info.ImageCount >= info.MinImageCount);
    assert(render_pass != VK_NULL_HANDLE);

    bd.VulkanInitInfo = info.*;
    bd.RenderPass = render_pass;
    bd.Subpass = info.Subpass;

    ImGui_ImplVulkan_CreateDeviceObjects();

    return true;
}

// For having multiple imgui contexts sharing one vulkan render backend.
ImGui_ImplVulkan_InitAdditionalView :: () -> bool {

    io := ImGui.GetIO();
    assert(io.BackendRendererUserData == null, "Already initialized a renderer backend!");

    bd := ImGui_ImplVulkan_GetBackendData();

    io.BackendRendererUserData = xx bd;
    io.BackendRendererName = "imgui_impl_vulkan".data;
    io.BackendFlags_ |= .RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.

    return true;    
}

ImGui_ImplVulkan_Shutdown :: () {
    bd := ImGui_ImplVulkan_GetBackendData();
    assert(bd != null, "No renderer backend to shutdown, or already shutdown?");
    io := ImGui.GetIO();

    ImGui_ImplVulkan_DestroyDeviceObjects();
    io.BackendRendererName = null;
    io.BackendRendererUserData = null;
    io.BackendFlags_ &= ~.RendererHasVtxOffset;
    // IM_DELETE(bd); // :TheOneImGuiVulkan
}

ImGui_ImplVulkan_NewFrame :: () {
    bd := ImGui_ImplVulkan_GetBackendData();
    assert(bd != null, "Did you call ImGui_ImplVulkan_Init()?");
}

ImGui_ImplVulkan_SetMinImageCount :: (min_image_count: u32) {
    bd := ImGui_ImplVulkan_GetBackendData();
    assert(min_image_count >= 2);
    if bd.VulkanInitInfo.MinImageCount == min_image_count  return;

    v := *bd.VulkanInitInfo;
    err := vkDeviceWaitIdle(v.Device);
    check_vk_result(err);

    ImGui_ImplVulkanH_DestroyWindowRenderBuffers(v.Device, *bd.MainWindowRenderBuffers, v.Allocator);
    bd.VulkanInitInfo.MinImageCount = min_image_count;
}

// Register a texture
// FIXME: This is experimental in the sense that we are unsure how to best design/tackle this problem, please post to https://github.com/ocornut/imgui/pull/914 if you have suggestions.
ImGui_ImplVulkan_AddTexture :: (sampler: VkSampler, image_view: VkImageView, image_layout: VkImageLayout) -> VkDescriptorSet {
    bd := ImGui_ImplVulkan_GetBackendData();
    v  := *bd.VulkanInitInfo;

    // Create Descriptor Set:
    descriptor_set: VkDescriptorSet;
    {
        alloc_info: VkDescriptorSetAllocateInfo;
        alloc_info.descriptorPool = v.DescriptorPool;
        alloc_info.descriptorSetCount = 1;
        alloc_info.pSetLayouts = *bd.DescriptorSetLayout;
        err := vkAllocateDescriptorSets(v.Device, *alloc_info, *descriptor_set);
        check_vk_result(err);
    }

    // Update the Descriptor Set:
    {
        desc_image: VkDescriptorImageInfo;
        desc_image.sampler = sampler;
        desc_image.imageView = image_view;
        desc_image.imageLayout = image_layout;

        write_desc: VkWriteDescriptorSet;
        write_desc.dstSet = descriptor_set;
        write_desc.descriptorCount = 1;
        write_desc.descriptorType = .COMBINED_IMAGE_SAMPLER;
        write_desc.pImageInfo = *desc_image;
        vkUpdateDescriptorSets(v.Device, 1, *write_desc, 0, null);
    }

    return descriptor_set;
}

ImGui_ImplVulkan_RemoveTexture :: (descriptor_set: VkDescriptorSet) {
    bd := ImGui_ImplVulkan_GetBackendData();
    v := *bd.VulkanInitInfo;

    vkFreeDescriptorSets(v.Device, v.DescriptorPool, 1, *descriptor_set);
}

//-------------------------------------------------------------------------
// Internal / Miscellaneous Vulkan Helpers
// (Used by example's main.cpp. Used by multi-viewport features. PROBABLY NOT used by your own app.)
//-------------------------------------------------------------------------
// You probably do NOT need to use or care about those functions.
// Those functions only exist because:
//   1) they facilitate the readability and maintenance of the multiple main.cpp examples files.
//   2) the upcoming multi-viewport feature will need them internally.
// Generally we avoid exposing any kind of superfluous high-level helpers in the backends,
// but it is too much code to duplicate everywhere so we exceptionally expose them.
//
// Your engine/app will likely _already_ have code to setup all that stuff (swap chain, render pass, frame buffers, etc.).
// You may read this code to learn about Vulkan, but it is recommended you use you own custom tailored code to do equivalent work.
// (The ImGui_ImplVulkanH_XXX functions do not interact with any of the state used by the regular ImGui_ImplVulkan_XXX functions)
//-------------------------------------------------------------------------


ImGui_ImplVulkanH_SelectSurfaceFormat :: (physical_device: VkPhysicalDevice, surface: VkSurfaceKHR, request_formats: [] VkFormat, request_color_space: VkColorSpaceKHR) -> VkSurfaceFormatKHR {
    assert(g_FunctionsLoaded, "Need to call ImGui_ImplVulkan_LoadFunctions() if IMGUI_IMPL_VULKAN_NO_PROTOTYPES or VK_NO_PROTOTYPES are set!");
    assert(request_formats.data != null);
    assert(request_formats.count > 0);

    // Per Spec Format and View Format are expected to be the same unless VK_IMAGE_CREATE_MUTABLE_BIT was set at image creation
    // Assuming that the default behavior is without setting this bit, there is no need for separate Swapchain image and image view format
    // Additionally several new color spaces were introduced with Vulkan Spec v1.0.40,
    // hence we must make sure that a format with the mostly available color space, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR, is found and used.
    available_formats, result := vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface,, temp);
    assert(result == .SUCCESS);

    // First check if only one format, .UNDEFINED, is available, which would imply that any format is available
    if available_formats.count == 1 {
        if available_formats[0].format == .UNDEFINED {
            ret: VkSurfaceFormatKHR;
            ret.format = request_formats[0];
            ret.colorSpace = request_color_space;
            return ret;
        }

        // No point in searching another format
        return available_formats[0];
    }

    // Request several formats, the first found will be used
    for requested_format: request_formats {
        for available_format: available_formats {
            if available_format.format == requested_format && available_format.colorSpace == request_color_space {
                return available_format;
            } 
        }
    }

    // If none of the requested image formats could be found, use the first available
    return available_formats[0];
}


ImGui_ImplVulkanH_SelectPresentMode :: (physical_device: VkPhysicalDevice, surface: VkSurfaceKHR, request_modes: [] VkPresentModeKHR) -> VkPresentModeKHR {
    assert(g_FunctionsLoaded, "Need to call ImGui_ImplVulkan_LoadFunctions() if IMGUI_IMPL_VULKAN_NO_PROTOTYPES or VK_NO_PROTOTYPES are set!");
    assert(request_modes.data != null);
    assert(request_modes.count > 0);

    // Request a certain mode and confirm that it is available. If not use .FIFO_KHR which is mandatory
    available_modes, result := vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface,, temp);
    assert(result == .SUCCESS);

    for requested_mode: request_modes {
        for available_mode: available_modes {
            if requested_mode == available_mode  return requested_mode;
        }
    }

    return .FIFO_KHR; // Always available
}

ImGui_ImplVulkanH_CreateWindowCommandBuffers :: (physical_device: VkPhysicalDevice, device: VkDevice, wd: *ImGui_ImplVulkanH_Window, queue_family: u32 , allocator: *VkAllocationCallbacks) {
    assert(physical_device != VK_NULL_HANDLE && device != VK_NULL_HANDLE);

    assert(wd.Frames.count == wd.ImageCount);
    assert(wd.Frames.count == wd.FrameSemaphores.count);

    // Create Command Buffers
    err: VkResult;
    for * wd.Frames {
        {
            info: VkCommandPoolCreateInfo;
            info.flags = .RESET_COMMAND_BUFFER_BIT;
            info.queueFamilyIndex = queue_family;
            err = vkCreateCommandPool(device, *info, allocator, *it.CommandPool);
            check_vk_result(err);
        }
        {
            info: VkCommandBufferAllocateInfo;
            info.commandPool = it.CommandPool;
            info.level = .PRIMARY;
            info.commandBufferCount = 1;
            err = vkAllocateCommandBuffers(device, *info, *it.CommandBuffer);
            check_vk_result(err);
        }
        {
            info: VkFenceCreateInfo;
            info.flags = .SIGNALED_BIT;
            err = vkCreateFence(device, *info, allocator, *it.Fence);
            check_vk_result(err);
        }

        fsd := *wd.FrameSemaphores[it_index];
        {
            info: VkSemaphoreCreateInfo;
            err = vkCreateSemaphore(device, *info, allocator, *fsd.ImageAcquiredSemaphore);
            check_vk_result(err);

            err = vkCreateSemaphore(device, *info, allocator, *fsd.RenderCompleteSemaphore);
            check_vk_result(err);
        }
    }
}

ImGui_ImplVulkanH_GetMinImageCountFromPresentMode :: (present_mode: VkPresentModeKHR) -> s32 {
    if present_mode == {
        case .MAILBOX_KHR;
        return 3;

        case .FIFO_KHR; #through;
        case .FIFO_RELAXED_KHR;
        return 2;

        case .IMMEDIATE_KHR;
        return 1;
    }

    assert(false);
    return 1;
}

// Also destroy old swap chain and in-flight frames data, if any.
ImGui_ImplVulkanH_CreateWindowSwapChain :: (physical_device: VkPhysicalDevice, device: VkDevice, wd: *ImGui_ImplVulkanH_Window, allocator: *VkAllocationCallbacks, w: s32, h: s32, min_image_count: u32) {
    err: VkResult;
    old_swapchain := wd.Swapchain;
    wd.Swapchain = VK_NULL_HANDLE;
    err = vkDeviceWaitIdle(device);
    check_vk_result(err);

    // We don't use ImGui_ImplVulkanH_DestroyWindow() because we want to preserve the old swapchain to create the new one.
    // Destroy old Framebuffer
    for 0..wd.ImageCount-1 {
        ImGui_ImplVulkanH_DestroyFrame(device, *wd.Frames[it], allocator);
        ImGui_ImplVulkanH_DestroyFrameSemaphores(device, *wd.FrameSemaphores[it], allocator);
    }
    // Q: Can't we just reuse the memory?
    array_reset(*wd.Frames);
    array_reset(*wd.FrameSemaphores);
    wd.ImageCount = 0;

    if wd.RenderPass  vkDestroyRenderPass(device, wd.RenderPass, allocator);
    if wd.Pipeline    vkDestroyPipeline(device, wd.Pipeline, allocator);

    // If min image count was not specified, request different count of images dependent on selected present mode
    min_image_count_ := min_image_count;
    if min_image_count == 0  min_image_count = xx ImGui_ImplVulkanH_GetMinImageCountFromPresentMode(wd.PresentMode);

    // Create Swapchain
    {
        info: VkSwapchainCreateInfoKHR;
        info.surface = wd.Surface;
        info.minImageCount = min_image_count;
        info.imageFormat = wd.SurfaceFormat.format;
        info.imageColorSpace = wd.SurfaceFormat.colorSpace;
        info.imageArrayLayers = 1;
        info.imageUsage = .COLOR_ATTACHMENT_BIT;
        info.imageSharingMode = .EXCLUSIVE;           // Assume that graphics family == present family
        info.preTransform = .IDENTITY_BIT_KHR;
        info.compositeAlpha = .OPAQUE_BIT_KHR;
        info.presentMode = wd.PresentMode;
        info.clipped = VK_TRUE;
        info.oldSwapchain = old_swapchain;

        cap: VkSurfaceCapabilitiesKHR;
        err = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, wd.Surface, *cap);
        check_vk_result(err);

        if info.minImageCount < cap.minImageCount {
            info.minImageCount = cap.minImageCount;
        } else if cap.maxImageCount != 0 && info.minImageCount > cap.maxImageCount {
            info.minImageCount = cap.maxImageCount;
        }

        if cap.currentExtent.width == 0xffffffff {
            info.imageExtent.width  = xx w;
            info.imageExtent.height = xx h;
            wd.Width  = xx w;
            wd.Height = xx h;
        } else {
            info.imageExtent.width  = xx w;
            info.imageExtent.height = xx h;
            wd.Width  = xx cap.currentExtent.width;
            wd.Height = xx cap.currentExtent.height;
        }

        err = vkCreateSwapchainKHR(device, *info, allocator, *wd.Swapchain);
        check_vk_result(err);

        images:, err = vkGetSwapchainImagesKHR(device, wd.Swapchain,, temp);
        check_vk_result(err);

        wd.ImageCount = xx images.count;
        wd.Frames          = NewArray(wd.ImageCount, ImGui_ImplVulkanH_Frame);
        wd.FrameSemaphores = NewArray(wd.ImageCount, ImGui_ImplVulkanH_FrameSemaphores);
        for * wd.Frames  it.Backbuffer = images[it_index];
    }

    if old_swapchain  vkDestroySwapchainKHR(device, old_swapchain, allocator);

    // Create the Render Pass
    {
        attachment: VkAttachmentDescription;
        attachment.format = wd.SurfaceFormat.format;
        attachment.samples = ._1_BIT;
        attachment.loadOp = ifx wd.ClearEnable then .CLEAR else .DONT_CARE;
        attachment.storeOp = .STORE;
        attachment.stencilLoadOp = .DONT_CARE;
        attachment.stencilStoreOp = .DONT_CARE;
        attachment.initialLayout = .UNDEFINED;
        attachment.finalLayout = .PRESENT_SRC_KHR;

        color_attachment: VkAttachmentReference;
        color_attachment.attachment = 0;
        color_attachment.layout = .COLOR_ATTACHMENT_OPTIMAL;

        subpass: VkSubpassDescription;
        subpass.pipelineBindPoint = .GRAPHICS;
        subpass.colorAttachmentCount = 1;
        subpass.pColorAttachments = *color_attachment;

        dependency: VkSubpassDependency;
        dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
        dependency.dstSubpass = 0;
        dependency.srcStageMask = .COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.dstStageMask = .COLOR_ATTACHMENT_OUTPUT_BIT;
        dependency.srcAccessMask = 0;
        dependency.dstAccessMask = .COLOR_ATTACHMENT_WRITE_BIT;

        info: VkRenderPassCreateInfo;
        info.attachmentCount = 1;
        info.pAttachments = *attachment;
        info.subpassCount = 1;
        info.pSubpasses = *subpass;
        info.dependencyCount = 1;
        info.pDependencies = *dependency;
        err = vkCreateRenderPass(device, *info, allocator, *wd.RenderPass);
        check_vk_result(err);

        // We do not create a pipeline by default as this is also used by examples' main.cpp,
        // but secondary viewport in multi-viewport mode may want to create one with:
        //ImGui_ImplVulkan_CreatePipeline(device, allocator, VK_NULL_HANDLE, wd.RenderPass, ._1_BIT, &wd.Pipeline, bd.Subpass);
    }

    // Create The Image Views
    {
        info: VkImageViewCreateInfo;
        info.viewType = ._2D;
        info.format = wd.SurfaceFormat.format;
        info.components.r = .R;
        info.components.g = .G;
        info.components.b = .B;
        info.components.a = .A;
        info.subresourceRange = VkImageSubresourceRange.{ .COLOR_BIT, 0, 1, 0, 1 };

        for * wd.Frames {
            info.image = it.Backbuffer;
            err = vkCreateImageView(device, *info, allocator, *it.BackbufferView);
            check_vk_result(err);
        }
    }

    // Create Framebuffer
    {
        attachment: VkImageView;

        info: VkFramebufferCreateInfo;
        info.renderPass = wd.RenderPass;
        info.attachmentCount = 1;
        info.pAttachments = *attachment;
        info.width  = xx wd.Width;
        info.height = xx wd.Height;
        info.layers = 1;
        for * wd.Frames {
            attachment = it.BackbufferView;
            err = vkCreateFramebuffer(device, *info, allocator, *it.Framebuffer);
            check_vk_result(err);
        }
    }
}


// Create or resize window
ImGui_ImplVulkanH_CreateOrResizeWindow :: (instance: VkInstance, physical_device: VkPhysicalDevice, device: VkDevice, wd: *ImGui_ImplVulkanH_Window, queue_family: u32, allocator: *VkAllocationCallbacks, width: s32, height: s32, min_image_count: u32) {
    assert(g_FunctionsLoaded, "Need to call ImGui_ImplVulkan_LoadFunctions() if IMGUI_IMPL_VULKAN_NO_PROTOTYPES or VK_NO_PROTOTYPES are set!");
    ImGui_ImplVulkanH_CreateWindowSwapChain(physical_device, device, wd, allocator, width, height, min_image_count);
    ImGui_ImplVulkanH_CreateWindowCommandBuffers(physical_device, device, wd, queue_family, allocator);
}

ImGui_ImplVulkanH_DestroyWindow :: (instance: VkInstance, device: VkDevice, wd: *ImGui_ImplVulkanH_Window, allocator: *VkAllocationCallbacks) {
    vkDeviceWaitIdle(device); // FIXME: We could wait on the Queue if we had the queue in wd. (otherwise VulkanH functions can't use globals)
    //vkQueueWaitIdle(bd.Queue);

    for 0..wd.ImageCount-1 {
        ImGui_ImplVulkanH_DestroyFrame(device, *wd.Frames[it], allocator);
        ImGui_ImplVulkanH_DestroyFrameSemaphores(device, *wd.FrameSemaphores[it], allocator);
    }
    array_reset(*wd.Frames);
    array_reset(*wd.FrameSemaphores);

    vkDestroyPipeline(device, wd.Pipeline, allocator);
    vkDestroyRenderPass(device, wd.RenderPass, allocator);
    vkDestroySwapchainKHR(device, wd.Swapchain, allocator);
    vkDestroySurfaceKHR(instance, wd.Surface, allocator);

    wd.* = .{};
}

ImGui_ImplVulkanH_DestroyFrame :: (device: VkDevice, fd: *ImGui_ImplVulkanH_Frame, allocator: *VkAllocationCallbacks) {
    vkDestroyFence(device, fd.Fence, allocator);
    vkFreeCommandBuffers(device, fd.CommandPool, 1, *fd.CommandBuffer);
    vkDestroyCommandPool(device, fd.CommandPool, allocator);
    fd.Fence = VK_NULL_HANDLE;
    fd.CommandBuffer = VK_NULL_HANDLE;
    fd.CommandPool = VK_NULL_HANDLE;

    vkDestroyImageView(device, fd.BackbufferView, allocator);
    vkDestroyFramebuffer(device, fd.Framebuffer, allocator);
}

ImGui_ImplVulkanH_DestroyFrameSemaphores :: (device: VkDevice, fsd: *ImGui_ImplVulkanH_FrameSemaphores, allocator: *VkAllocationCallbacks) {
    vkDestroySemaphore(device, fsd.ImageAcquiredSemaphore, allocator);
    vkDestroySemaphore(device, fsd.RenderCompleteSemaphore, allocator);
    fsd.ImageAcquiredSemaphore = VK_NULL_HANDLE;
    fsd.RenderCompleteSemaphore = VK_NULL_HANDLE;
}

ImGui_ImplVulkanH_DestroyFrameRenderBuffers :: (device: VkDevice, buffers: *ImGui_ImplVulkanH_FrameRenderBuffers, allocator: *VkAllocationCallbacks)
{
    if buffers.VertexBuffer.vk      { vkDestroyBuffer(device, buffers.VertexBuffer.vk, allocator) ; buffers.VertexBuffer.vk = VK_NULL_HANDLE; }
    if buffers.VertexBuffer.Memory  { vkFreeMemory(device, buffers.VertexBuffer.Memory, allocator); buffers.VertexBuffer.Memory = VK_NULL_HANDLE; }
    if buffers.IndexBuffer.vk      { vkDestroyBuffer(device, buffers.IndexBuffer.vk, allocator) ; buffers.IndexBuffer.vk = VK_NULL_HANDLE; }
    if buffers.IndexBuffer.Memory  { vkFreeMemory(device, buffers.IndexBuffer.Memory, allocator); buffers.IndexBuffer.Memory = VK_NULL_HANDLE; }
    buffers.VertexBuffer.Size = 0;
    buffers.IndexBuffer.Size = 0;
}

ImGui_ImplVulkanH_DestroyWindowRenderBuffers :: (device: VkDevice, buffers: *ImGui_ImplVulkanH_WindowRenderBuffers, allocator: *VkAllocationCallbacks) {
    for * buffers.FrameRenderBuffers {
        ImGui_ImplVulkanH_DestroyFrameRenderBuffers(device, it, allocator);
    }
    array_reset(*buffers.FrameRenderBuffers);
    buffers.Index = 0;
}

#scope_file

// :ImGuiBackends

#import "Basic";
#import "Vulkan";
using ImGui :: #import "ImGui";

// Backend data stored in io.BackendRendererUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
// FIXME: multi-context support is not tested and probably dysfunctional in this backend.
ImGui_ImplVulkan_GetBackendData :: () -> *ImGui_ImplVulkan_Data {
    // return ImGui.GetCurrentContext() ? (ImGui_ImplVulkan_Data*)ImGui.GetIO().BackendRendererUserData : null;
    return *imgui_vulkan_backend_data;
}

imgui_vulkan_backend_data: ImGui_ImplVulkan_Data; // Just one global one for now! :TheOneImGuiVulkan
check_vk_result :: (err: VkResult) {
    bd := ImGui_ImplVulkan_GetBackendData();
    if bd == null  return;

    v := *bd.VulkanInitInfo;
    if v.CheckVkResultFn  v.CheckVkResultFn(err);
}

//-----------------------------------------------------------------------------
// SHADERS
//-----------------------------------------------------------------------------

// glsl_shader.vert, compiled with:
// # glslangValidator -V -x -o glsl_shader.vert.u32 glsl_shader.vert
/*
#version 450 core
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aUV;
layout(location = 2) in vec4 aColor;
layout(push_constant) uniform uPushConstant { vec2 uScale; vec2 uTranslate; } pc;

out gl_PerVertex { vec4 gl_Position; };
layout(location = 0) out struct { vec4 Color; vec2 UV; } Out;

void main()
{
    Out.Color = aColor;
    Out.UV = aUV;
    gl_Position = vec4(aPos * pc.uScale + pc.uTranslate, 0, 1);
}
*/
__glsl_shader_vert_spv :: u32.[
    0x07230203,0x00010000,0x00080001,0x0000002e,0x00000000,0x00020011,0x00000001,0x0006000b,
    0x00000001,0x4c534c47,0x6474732e,0x3035342e,0x00000000,0x0003000e,0x00000000,0x00000001,
    0x000a000f,0x00000000,0x00000004,0x6e69616d,0x00000000,0x0000000b,0x0000000f,0x00000015,
    0x0000001b,0x0000001c,0x00030003,0x00000002,0x000001c2,0x00040005,0x00000004,0x6e69616d,
    0x00000000,0x00030005,0x00000009,0x00000000,0x00050006,0x00000009,0x00000000,0x6f6c6f43,
    0x00000072,0x00040006,0x00000009,0x00000001,0x00005655,0x00030005,0x0000000b,0x0074754f,
    0x00040005,0x0000000f,0x6c6f4361,0x0000726f,0x00030005,0x00000015,0x00565561,0x00060005,
    0x00000019,0x505f6c67,0x65567265,0x78657472,0x00000000,0x00060006,0x00000019,0x00000000,
    0x505f6c67,0x7469736f,0x006e6f69,0x00030005,0x0000001b,0x00000000,0x00040005,0x0000001c,
    0x736f5061,0x00000000,0x00060005,0x0000001e,0x73755075,0x6e6f4368,0x6e617473,0x00000074,
    0x00050006,0x0000001e,0x00000000,0x61635375,0x0000656c,0x00060006,0x0000001e,0x00000001,
    0x61725475,0x616c736e,0x00006574,0x00030005,0x00000020,0x00006370,0x00040047,0x0000000b,
    0x0000001e,0x00000000,0x00040047,0x0000000f,0x0000001e,0x00000002,0x00040047,0x00000015,
    0x0000001e,0x00000001,0x00050048,0x00000019,0x00000000,0x0000000b,0x00000000,0x00030047,
    0x00000019,0x00000002,0x00040047,0x0000001c,0x0000001e,0x00000000,0x00050048,0x0000001e,
    0x00000000,0x00000023,0x00000000,0x00050048,0x0000001e,0x00000001,0x00000023,0x00000008,
    0x00030047,0x0000001e,0x00000002,0x00020013,0x00000002,0x00030021,0x00000003,0x00000002,
    0x00030016,0x00000006,0x00000020,0x00040017,0x00000007,0x00000006,0x00000004,0x00040017,
    0x00000008,0x00000006,0x00000002,0x0004001e,0x00000009,0x00000007,0x00000008,0x00040020,
    0x0000000a,0x00000003,0x00000009,0x0004003b,0x0000000a,0x0000000b,0x00000003,0x00040015,
    0x0000000c,0x00000020,0x00000001,0x0004002b,0x0000000c,0x0000000d,0x00000000,0x00040020,
    0x0000000e,0x00000001,0x00000007,0x0004003b,0x0000000e,0x0000000f,0x00000001,0x00040020,
    0x00000011,0x00000003,0x00000007,0x0004002b,0x0000000c,0x00000013,0x00000001,0x00040020,
    0x00000014,0x00000001,0x00000008,0x0004003b,0x00000014,0x00000015,0x00000001,0x00040020,
    0x00000017,0x00000003,0x00000008,0x0003001e,0x00000019,0x00000007,0x00040020,0x0000001a,
    0x00000003,0x00000019,0x0004003b,0x0000001a,0x0000001b,0x00000003,0x0004003b,0x00000014,
    0x0000001c,0x00000001,0x0004001e,0x0000001e,0x00000008,0x00000008,0x00040020,0x0000001f,
    0x00000009,0x0000001e,0x0004003b,0x0000001f,0x00000020,0x00000009,0x00040020,0x00000021,
    0x00000009,0x00000008,0x0004002b,0x00000006,0x00000028,0x00000000,0x0004002b,0x00000006,
    0x00000029,0x3f800000,0x00050036,0x00000002,0x00000004,0x00000000,0x00000003,0x000200f8,
    0x00000005,0x0004003d,0x00000007,0x00000010,0x0000000f,0x00050041,0x00000011,0x00000012,
    0x0000000b,0x0000000d,0x0003003e,0x00000012,0x00000010,0x0004003d,0x00000008,0x00000016,
    0x00000015,0x00050041,0x00000017,0x00000018,0x0000000b,0x00000013,0x0003003e,0x00000018,
    0x00000016,0x0004003d,0x00000008,0x0000001d,0x0000001c,0x00050041,0x00000021,0x00000022,
    0x00000020,0x0000000d,0x0004003d,0x00000008,0x00000023,0x00000022,0x00050085,0x00000008,
    0x00000024,0x0000001d,0x00000023,0x00050041,0x00000021,0x00000025,0x00000020,0x00000013,
    0x0004003d,0x00000008,0x00000026,0x00000025,0x00050081,0x00000008,0x00000027,0x00000024,
    0x00000026,0x00050051,0x00000006,0x0000002a,0x00000027,0x00000000,0x00050051,0x00000006,
    0x0000002b,0x00000027,0x00000001,0x00070050,0x00000007,0x0000002c,0x0000002a,0x0000002b,
    0x00000028,0x00000029,0x00050041,0x00000011,0x0000002d,0x0000001b,0x0000000d,0x0003003e,
    0x0000002d,0x0000002c,0x000100fd,0x00010038,
];

// glsl_shader.frag, compiled with:
// # glslangValidator -V -x -o glsl_shader.frag.u32 glsl_shader.frag
/*
#version 450 core
layout(location = 0) out vec4 fColor;
layout(set=0, binding=0) uniform sampler2D sTexture;
layout(location = 0) in struct { vec4 Color; vec2 UV; } In;
void main()
{
    fColor = In.Color * texture(sTexture, In.UV.st);
}
*/
__glsl_shader_frag_spv :: u32.[
    0x07230203,0x00010000,0x00080001,0x0000001e,0x00000000,0x00020011,0x00000001,0x0006000b,
    0x00000001,0x4c534c47,0x6474732e,0x3035342e,0x00000000,0x0003000e,0x00000000,0x00000001,
    0x0007000f,0x00000004,0x00000004,0x6e69616d,0x00000000,0x00000009,0x0000000d,0x00030010,
    0x00000004,0x00000007,0x00030003,0x00000002,0x000001c2,0x00040005,0x00000004,0x6e69616d,
    0x00000000,0x00040005,0x00000009,0x6c6f4366,0x0000726f,0x00030005,0x0000000b,0x00000000,
    0x00050006,0x0000000b,0x00000000,0x6f6c6f43,0x00000072,0x00040006,0x0000000b,0x00000001,
    0x00005655,0x00030005,0x0000000d,0x00006e49,0x00050005,0x00000016,0x78655473,0x65727574,
    0x00000000,0x00040047,0x00000009,0x0000001e,0x00000000,0x00040047,0x0000000d,0x0000001e,
    0x00000000,0x00040047,0x00000016,0x00000022,0x00000000,0x00040047,0x00000016,0x00000021,
    0x00000000,0x00020013,0x00000002,0x00030021,0x00000003,0x00000002,0x00030016,0x00000006,
    0x00000020,0x00040017,0x00000007,0x00000006,0x00000004,0x00040020,0x00000008,0x00000003,
    0x00000007,0x0004003b,0x00000008,0x00000009,0x00000003,0x00040017,0x0000000a,0x00000006,
    0x00000002,0x0004001e,0x0000000b,0x00000007,0x0000000a,0x00040020,0x0000000c,0x00000001,
    0x0000000b,0x0004003b,0x0000000c,0x0000000d,0x00000001,0x00040015,0x0000000e,0x00000020,
    0x00000001,0x0004002b,0x0000000e,0x0000000f,0x00000000,0x00040020,0x00000010,0x00000001,
    0x00000007,0x00090019,0x00000013,0x00000006,0x00000001,0x00000000,0x00000000,0x00000000,
    0x00000001,0x00000000,0x0003001b,0x00000014,0x00000013,0x00040020,0x00000015,0x00000000,
    0x00000014,0x0004003b,0x00000015,0x00000016,0x00000000,0x0004002b,0x0000000e,0x00000018,
    0x00000001,0x00040020,0x00000019,0x00000001,0x0000000a,0x00050036,0x00000002,0x00000004,
    0x00000000,0x00000003,0x000200f8,0x00000005,0x00050041,0x00000010,0x00000011,0x0000000d,
    0x0000000f,0x0004003d,0x00000007,0x00000012,0x00000011,0x0004003d,0x00000014,0x00000017,
    0x00000016,0x00050041,0x00000019,0x0000001a,0x0000000d,0x00000018,0x0004003d,0x0000000a,
    0x0000001b,0x0000001a,0x00050057,0x00000007,0x0000001c,0x00000017,0x0000001b,0x00050085,
    0x00000007,0x0000001d,0x00000012,0x0000001c,0x0003003e,0x00000009,0x0000001d,0x000100fd,
    0x00010038,
];