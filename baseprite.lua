-- Baseprite by Creamy! v1.0

local function createColorIndices(sprite, cel, palette)
    local colorToIndex = {}
    local img = cel.image
  
    -- Build a map of colors from the provided palette
    for i, colorInfo in ipairs(palette) do
      local colorValue = app.pixelColor.rgba(
        colorInfo.color.red,
        colorInfo.color.green,
        colorInfo.color.blue,
        colorInfo.color.alpha
      )
      colorToIndex[colorValue] = i - 1 -- 0-based index
    end
  
    local pixelData = {}
    for pixel in img:pixels() do
      local colorValue = pixel()
      if app.pixelColor.rgbaA(colorValue) > 0 then
        local index = colorToIndex[colorValue]
        if index ~= nil then -- Only include pixels matching palette colors
          table.insert(pixelData, {
            x = pixel.x + cel.position.x, -- Offset by cel position
            y = pixel.y + cel.position.y, -- Offset by cel position
            color = index
          })
        end
      end
    end
  
    return pixelData
  end
  
  local function getUniqueColors()
    local sprite = app.activeSprite
    if not sprite then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- Default blue if no sprite
    local cel = sprite.cels[1]
    if not cel then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- Default blue if no cel
  
    local colorToIndex = {}
    local colorList = {}
    local nextIndex = 0
    local img = cel.image
  
    for pixel in img:pixels() do
      local colorValue = pixel()
      if app.pixelColor.rgbaA(colorValue) > 0 then
        if not colorToIndex[colorValue] then
          colorToIndex[colorValue] = nextIndex
          table.insert(colorList, {
            color = Color{
              r = app.pixelColor.rgbaR(colorValue),
              g = app.pixelColor.rgbaG(colorValue),
              b = app.pixelColor.rgbaB(colorValue),
              a = app.pixelColor.rgbaA(colorValue)
            }
          })
          nextIndex = nextIndex + 1
        end
      end
    end
  
    return #colorList > 0 and colorList or {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} -- Default blue if empty
  end
  
  local function generateJSON(palette, selectedLayerIndex)
    local sprite = app.activeSprite
    if not sprite then
      app.alert("No sprite is active!")
      return nil
    end
  
    local layer = sprite.layers[selectedLayerIndex]
    if not layer then
      app.alert("Selected layer not found!")
      return nil
    end
  
    local cel = layer:cel(sprite.frames[1]) -- First frame
    if not cel then
      app.alert("No cel found in selected layer!")
      return nil
    end
  
    local pixelData = createColorIndices(sprite, cel, palette)
    local json_lines = {}
  
    for i, pixel in ipairs(pixelData) do
      table.insert(json_lines, string.format(
        '{"point":{"x":%d,"y":%d},"color":%d}%s',
        pixel.x, pixel.y, pixel.color,
        i < #pixelData and "," or ""
      ))
    end
  
    return "[\n" .. table.concat(json_lines, "\n") .. "\n]"
  end
  
  local function saveToFileWithPrompt(json_string)
    local dlg = Dialog{ title = "Save Pixel Data As" }
    dlg:file{
      id = "filepath",
      label = "File:",
      save = true,
      filename = "output.txt"
    }
    dlg:button{
      text = "Save",
      onclick = function()
        local filepath = dlg.data.filepath
        if filepath and filepath ~= "" then
          local file = io.open(filepath, "w")
          if file then
            file:write(json_string)
            file:close()
            os.execute("open \"" .. filepath .. "\"")
            app.alert("Saved and opened: " .. filepath)
          else
            app.alert("Failed to save file!")
          end
        else
          app.alert("No file path provided.")
        end
      end
    }
    dlg:button{ text = "Cancel" }
    dlg:show()
  end
  
  local function copyToClipboard(json_string)
    if not json_string then return end
  
    local osName = os.getenv("OS") or "unknown"
    if osName:lower():find("windows") then
      os.execute("echo|set /p=\"" .. json_string:gsub('"', '""') .. "\"|clip")
    elseif package.config:sub(1,1) == "/" then
      local success = os.execute("printf %s \"" .. json_string:gsub('"', '\\"') .. "\" | pbcopy 2>/dev/null")
      if not success then
        success = os.execute("printf %s \"" .. json_string:gsub('"', '\\"') .. "\" | xclip -selection clipboard 2>/dev/null")
      end
      if success then
        app.alert("Copied to clipboard!")
      else
        app.alert("Clipboard copy failed. Ensure 'pbcopy' (macOS) or 'xclip' (Linux) is installed.")
      end
    else
      app.alert("Unsupported OS for clipboard copy.")
      return
    end
    app.alert("Copied to clipboard!")
  end

  local function getLayerNames() -- Refresh layers function
    local names = {}
    local sprite = app.activeSprite
    if not sprite then return names end
    for _, layer in ipairs(sprite.layers) do
      if layer.name and layer.name ~= "" then
        table.insert(names, layer.name)
      end
    end
    return names
  end
  
  
  local dlg = nil
  local palette = getUniqueColors() -- Initialize with sprite colors
  local selectedLayerIndex = 2 -- Default to Layer 2
  
  local function pickColor(index)
    app.useTool{
      tool = "eyedropper",
      color = palette[index].color,
      button = MouseButton.LEFT,
      callback = function(color)
        palette[index].color = color
        createDialog()
      end
    }
  end
  
  local function createDialog()
    if dlg then dlg:close() end
  
    dlg = Dialog{ title = "Baseprite by Creamy" }
  
    dlg:button{
      text = "Extract Colors",
      onclick = function()
        palette = getUniqueColors()
        createDialog()
      end
    }
  
    dlg:button{
      text = "+ Add Color",
      onclick = function()
        table.insert(palette, { color = Color{ r = 0, g = 0, b = 0, a = 255 } })
        createDialog()
      end
    }
  
    local layerNames = getLayerNames()

    dlg:combobox{
        id = "layer",
        options = layerNames,
        option = layerNames[1]
      }
      
  
    dlg:newrow()
    dlg:button{
        text = "Refresh Layers",
        onclick = function()
          createDialog() -- re-renders with updated layer list
        end
      }
      
    dlg:newrow()
    dlg:separator()
  
    for i, colorInfo in ipairs(palette) do
      dlg:newrow()
      dlg:color{
        id = "color_" .. i,
        color = colorInfo.color,
        onclick = function() pickColor(i) end,
        onchange = function(ev)
          palette[i].color = ev.color
        end
      }
      
    end
  
    dlg:newrow()
    dlg:separator()
  
    dlg:button{
      text = "Save to File",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local sprite = app.activeSprite
        local selectedIndex = 1
        
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedIndex = i
            break
          end
        end
        
        local json_string = generateJSON(palette, selectedIndex)
        
        if json_string then
          saveToFileWithPrompt(json_string)
        end
      end
    }
  
    dlg:button{
      text = "Copy to Clipboard",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local sprite = app.activeSprite
        local selectedIndex = 1
        
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedIndex = i
            break
          end
        end
        
        local json_string = generateJSON(palette, selectedIndex)
        
        if json_string then
          copyToClipboard(json_string)
        end
      end
    }
      
    dlg:label{
        text = "Tip: Press Enter to approve popups!"
      }
      dlg:newrow()
      dlg:label{
          text = "(Sometimes the OK button is hidden)"
        }
  
    dlg:show{ wait = false }
  end
  
  createDialog()