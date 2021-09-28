-- MIT License

-- Copyright (c) 2021 David Fletcher

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- grab the user preferences object that floats in from plugin.lua
local prefs = ...
if (prefs == nil) then
    prefs = {}
end
if (prefs.presets == nil) then
    prefs.presets = { { name="Create New...", layers={} } }
end

-- helper methods
-- table deep copy
local function deepcopy(orig)
    -- http://lua-users.org/wiki/CopyTable
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end

        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

-- create an error alert and exit the dialog
local function create_error(str, dialog, exit)
    app.alert(str)
    if (exit == 1) then dialog:close() end
end

-- create a confirmation dialog and wait for the user to confirm
local function create_confirm(str)
    local confirm = Dialog("Confirm?")

    confirm:label {
        id="text",
        text=str
    }

    confirm:button {
        id="cancel",
        text="Cancel",
        onclick=function()
            confirm:close()
        end
    }

    confirm:button {
        id="confirm",
        text="Confirm",
        onclick=function()
            confirm:close()
        end
    }

    -- show to grab centered coordinates
    confirm:show{ wait=true }

    return confirm.data.confirm
end

-- convert Color object to hex string
local function convertColorToHex(color)
    local result = "#"
    result = result..string.format("%02x", color.red)..string.format("%02x",color.green)..string.format("%02x",color.blue)..string.format("%02x",color.alpha)
    return result
end

-- convert mode string to BlendMode
local function convertStringToBlendMode(str)
    if     (str == "Normal")      then return BlendMode.NORMAL
    elseif (str == "Darken")      then return BlendMode.DARKEN
    elseif (str == "Multiply")    then return BlendMode.MULTIPLY
    elseif (str == "Color Burn")  then return BlendMode.COLOR_BURN
    elseif (str == "Lighten")     then return BlendMode.LIGHTEN
    elseif (str == "Screen")      then return BlendMode.SCREEN
    elseif (str == "Color Dodge") then return BlendMode.COLOR_DODGE
    elseif (str == "Addition")    then return BlendMode.ADDITION
    elseif (str == "Overlay")     then return BlendMode.OVERLAY
    elseif (str == "Soft Light")  then return BlendMode.SOFT_LIGHT
    elseif (str == "Hard Light")  then return BlendMode.HARD_LIGHT
    elseif (str == "Difference")  then return BlendMode.DIFFERENCE
    elseif (str == "Exclusion")   then return BlendMode.EXCLUSION
    elseif (str == "Subtract")    then return BlendMode.SUBTRACT
    elseif (str == "Divide")      then return BlendMode.DIVIDE
    elseif (str == "Hue")         then return BlendMode.HSL_HUE
    elseif (str == "Saturation")  then return BlendMode.HSL_SATURATION
    elseif (str == "Color")       then return BlendMode.HSL_COLOR
    elseif (str == "Luminosity")  then return BlendMode.HSL_LUMINOSITY
    else                               return BlendMode.NORMAL
    end
end

-- main window helper logic
local function getListOfPresets(presets)
    local p = {}
    local map = {}
    for key, val in pairs(presets) do
        p[#p+1] = val.name
        map[val.name] = key
    end

    return p, map
end

-- helper method to prevent name collisions
local function doesPresetNameExist(check, presets_list)
    for _, p in pairs(presets_list) do
        if (check == p) then
            return true
        end
    end

    return false
end

-- main logic
local function insertPreset(preset, above)
    -- if they select the "default" selection, don't do anything.
    if (preset.name == "Create New...") then return end

    -- create a transaction so it's an easy undo
    app.transaction(function ()
        local sprite = app.activeSprite
        
        if (above) then
            -- newLayer adds new layers to the TOP of the layer stack
            -- so we loop through backwards to preserve the user-set order
            for idx=#preset.layers, 1, -1 do
                -- get necessary locals
                local preset_layer = preset.layers[idx]
                local layer = sprite:newLayer()

                -- configure the layer information
                layer.name = preset_layer.name
                layer.blendMode = convertStringToBlendMode(preset_layer.mode)
                layer.opacity = preset_layer.opacity
                layer.color = Color{ red=preset_layer.color.red, green=preset_layer.color.green, blue=preset_layer.color.blue, alpha=preset_layer.color.alpha }
            end
        else
            -- loop through the layers forwards, and set their stackLevel to 1 every time (forcing them to the bottom of the stack list)
            for idx=1, #preset.layers, 1 do
                -- get necessary locals
                local preset_layer = preset.layers[idx]
                local layer = sprite:newLayer()

                -- make sure the layer gets added to the bottom
                layer.stackIndex = 1

                -- configure the layer information
                layer.name = preset_layer.name
                layer.blendMode = convertStringToBlendMode(preset_layer.mode)
                layer.opacity = preset_layer.opacity
                layer.color = Color{ red=preset_layer.color.red, green=preset_layer.color.green, blue=preset_layer.color.blue, alpha=preset_layer.color.alpha }
            end
        end
    end)
end

-- edit window helper logic
local function editLayerWindow(cur_layer)
    local dlg = Dialog("Editing Layer")

    dlg:entry {
        id="layer_name",
        label="Layer Name:",
        text=cur_layer.name
    }

    dlg:combobox {
        id="layer_mode",
        label="Layer Mode:",
        option=cur_layer.mode,
        options={ 
                    "Normal", 
                    "Darken", "Multiply", "Color Burn", 
                    "Lighten", "Screen", "Color Dodge", "Addition",
                    "Overlay", "Soft Light", "Hard Light",
                    "Difference", "Exclusion", "Subtract", "Divide",
                    "Hue", "Saturation", "Color", "Luminosity"
                }
    }

    dlg:slider {
        id="layer_opacity",
        label="Layer Opacity:",
        value=cur_layer.opacity,
        min=0,
        max=255
    }

    dlg:color {
        id="layer_color",
        label="Layer Color:",
        color=Color{ red=cur_layer.color.red, green=cur_layer.color.green, blue=cur_layer.color.blue, alpha=cur_layer.color.alpha }
    }

    dlg:separator {
        id="footer",
        text="Finalize"
    }

    dlg:button {
        id="save",
        text="Save",
        onclick=function()
            dlg:close()
        end
    }

    return dlg
end

-- build and execute logic for the edit window
local function editPresetWindow(preset, exit_action, presets_list)
    local dlg = Dialog("Edit Layer Preset")

    -- save current state and refresh window
    local function refresh(dlg)
        preset.name = dlg.data.preset_name
        dlg:close()
        editPresetWindow(preset, exit_action, presets_list):show{ wait=true }
    end

    dlg:entry {
        id="preset_name",
        text=preset.name
    }

    for idx, layer in pairs(preset.layers) do
        dlg:button {
            id=idx.."_layer",
            text=layer.name.." | "..layer.mode.." | "..layer.opacity.." | "..convertColorToHex(layer.color),
            onclick=function ()
                local edit = editLayerWindow(layer):show{ wait=true }
                -- save the layer data
                if (edit.data.save) then
                    preset.layers[idx].name = edit.data.layer_name
                    preset.layers[idx].mode = edit.data.layer_mode
                    preset.layers[idx].opacity = edit.data.layer_opacity
                    preset.layers[idx].color = {
                        red = edit.data.layer_color.red,
                        green = edit.data.layer_color.green,
                        blue = edit.data.layer_color.blue,
                        alpha = edit.data.layer_color.alpha
                    }
                end

                -- refresh the dialog
                refresh(dlg)
            end -- onclick
        }

        dlg:button {
            id=idx.."delete",
            text="Delete Layer",
            onclick=function ()
                local confirm = create_confirm("Are you sure that you'd like to delete this layer?")
                if (confirm) then
                    table.remove(preset.layers, idx)
                    refresh(dlg)
                end
            end
        }

        dlg:newrow()
    end

    dlg:button {
        id="add_row",
        text="Add Layer to Preset",
        onclick=function()
            -- insert and refresh the dialog
            table.insert(preset.layers, { name = "NEW LAYER", mode = "Normal", opacity = 255, color = { red = 0, green = 0, blue = 0, alpha = 0 } })
            refresh(dlg)
        end -- onclick
    }

    dlg:separator {
        id="footer",
        text="Finalize"
    }

    dlg:button {
        id="confirm",
        text="Confirm",
        onclick=function()
            preset.name = dlg.data.preset_name
            if (doesPresetNameExist(preset.name, presets_list)) then
                create_error("That preset name is already in use. Please use a different preset name.", dlg, 0)
                return
            end
            exit_action.action = "confirm"
            dlg:close()
        end
    }

    return dlg
end

-- build the main window
local function mainWindow(presets)
    local dlg = Dialog("Open Layer Presets")

    -- refresh the window
    local function refresh(dlg)
        dlg:close()
        mainWindow(presets):show{ wait=true }
    end

    -- get preset information
    local presets_list, map = getListOfPresets(presets)

    -- layer preset selection
    dlg:combobox {
        id="sel_preset",
        options=presets_list,
        onchange=function()
            if (dlg.data.sel_preset == "Create New...") then
                dlg:modify {
                    id="edit_preset",
                    text="Add New Preset"
                }
            else
                dlg:modify {
                    id="edit_preset",
                    text="Edit Preset"
                }
            end
        end
    }

    dlg:newrow()

    -- preset actions
    dlg:button {
        id="edit_preset",
        text="Add New Preset",
        onclick=function()
            local exit_action = { action = nil }
            if (dlg.data.sel_preset == "Create New...") then
                -- create a new blank preset so the dialog is populated
                local new_preset = {name = "NEW PRESET", layers = {}}
                editPresetWindow(new_preset, exit_action, presets_list):show{ wait=true }
                if (exit_action.action == "confirm") then
                    -- add to the preset list
                    table.insert(presets, new_preset)
                    refresh(dlg)
                end
            else
                -- load from memory
                local presets_copy = deepcopy(presets)
                editPresetWindow(presets_copy[map[dlg.data.sel_preset]], exit_action, presets_list):show{ wait=true }
                if (exit_action.action == "confirm") then
                    local idx = map[dlg.data.sel_preset]
                    -- out with the old, in with the new
                    table.remove(presets, idx)
                    table.insert(presets, idx, deepcopy(presets_copy[idx]))
                    refresh(dlg)
                end
            end
        end
    }

    dlg:button {
        id="delete_preset",
        text="Delete Selected Preset",
        onclick=function()
            if (dlg.data.sel_preset ~= "Create New...") then
                -- delete the preset and reload the window
                table.remove(presets, map[dlg.data.sel_preset])
                refresh(dlg)
            end
        end
    }

    -- footer
    dlg:separator {
        id="footer",
        text="Add to Current Sprite"
    }

    dlg:button {
        id="add_below",
        text="Below All Layers",
        onclick=function ()
            if (presets[map[dlg.data.sel_preset]].name == "Create New...") then return end

            insertPreset(presets[map[dlg.data.sel_preset]], false)
            dlg:close()
        end
    }

    dlg:button {
        id="add_above",
        text="Above All Layers",
        onclick=function ()
            if (presets[map[dlg.data.sel_preset]].name == "Create New...") then return end

            insertPreset(presets[map[dlg.data.sel_preset]], true)
            dlg:close()
        end
    }

    return dlg
end

mainWindow(prefs.presets):show{ wait=true }
