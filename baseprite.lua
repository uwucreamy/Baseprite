--      ___         ___          ___          ___          ___          ___               ___          ___     
--     /\  \       /\  \        /\  \        /\  \        /\  \        /\  \        ___  /\  \        /\  \    
--    /::\  \     /::\  \      /::\  \      /::\  \      /::\  \      /::\  \      /\  \ \:\  \      /::\  \   
--   /:/\:\  \   /:/\:\  \    /:/\ \  \    /:/\:\  \    /:/\:\  \    /:/\:\  \     \:\  \ \:\  \    /:/\:\  \  
--  /::\~\:\__\ /::\~\:\  \  _\:\~\ \  \  /::\~\:\  \  /::\~\:\  \  /::\~\:\  \    /::\__\/::\  \  /::\~\:\  \ 
-- /:/\:\ \:|__/:/\:\ \:\__\/\ \:\ \ \__\/:/\:\ \:\__\/:/\:\ \:\__\/:/\:\ \:\__\__/:/\/__/:/\:\__\/:/\:\ \:\__\
-- \:\~\:\/:/  |/__\:\/:/  /\:\ \:\ \/__/\:\~\:\ \/__/\/__\:\/:/  /\/_|::\/:/  /\/:/  / /:/  \/__/\:\~\:\ \/__/
--  \:\ \::/  /     \::/  /  \:\ \:\__\   \:\ \:\__\       \::/  /    |:|::/  /\::/__/ /:/  /      \:\ \:\__\  
--   \:\/:/  /      /:/  /    \:\/:/  /    \:\ \/__/        \/__/     |:|\/__/  \:\__\ \/__/        \:\ \/__/  
--    \::/__/      /:/  /      \::/  /      \:\__\                    |:|  |     \/__/               \:\__\    
--     ~~          \/__/        \/__/        \/__/                     \|__|                          \/__/    
--                                      Baseprite by Creamy! v2.0

-- fetch palette from "basepaint.xyz/api/theme/day#"
local function fetchBasepaintPalette(day)
  local scriptPath = debug.getinfo(1, "S").source:match("@(.*/)")
  local tmpPath = scriptPath .. "basepaint_theme_data.json"
  local url = "https://basepaint.xyz/api/theme/" .. day
  local curl = 'curl -s "' .. url .. '" -o "' .. tmpPath .. '"'
  os.execute(curl)

  local f = io.open(tmpPath, "r")
  if not f then
    app.alert("Download failed.")
    return nil
  end

  local contents = f:read("*a")
  f:close()

  local hexes = {}
  for hex in contents:gmatch('"#(%x%x%x%x%x%x)"') do
    table.insert(hexes, "#" .. hex:upper())
  end
  if #hexes == 0 then
    app.alert("No valid hex codes found.")
    return nil
  end

  local colorList = {}
  for _, hex in ipairs(hexes) do
    local r = tonumber(hex:sub(2,3), 16)
    local g = tonumber(hex:sub(4,5), 16)
    local b = tonumber(hex:sub(6,7), 16)
    table.insert(colorList, { color = Color{ r=r, g=g, b=b, a=255 } })
  end

  return colorList
end

-- calculate current Basepaint canvas date
local function getCurrentBasepaintDay()
  local baseStart = os.time{year=2023, month=8, day=8, hour=16, min=41, sec=5} -- Birthday!
  local nowUTC = os.time(os.date("!*t"))
  local secondsPerDay = 60 * 60 * 24
  local diff = nowUTC - baseStart
  return math.floor(diff / secondsPerDay)
end

-- parse Frame # Input Field
local function parseFrameInput(input, sprite)
  local str = tostring(input):lower():gsub("frame", ""):gsub("%s+", "")
  local index = tonumber(str) or 1

  if index > #sprite.frames then
    app.alert("Frame " .. index .. " not found. Using last available frame: " .. #sprite.frames)
    return #sprite.frames
  elseif index < 1 then
    app.alert("Frame number must be 1 or higher. Defaulting to Frame 1.")
    return 1
  end

  return index
end

-- function to magically convert pixel data into number salad
local function createColorIndices(sprite, cel, palette)
    local colorToIndex = {}
    local img = cel.image    
  
    -- build a map of colors from the provided palette
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
        if index ~= nil then -- only include pixels matching palette colors
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
  
  -- sniff sprite for colors on open
  local function getUniqueColors()
    local sprite = app.activeSprite
    if not sprite then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- default basepaint blue if no sprite
    local cel = sprite.cels[1]
    if not cel then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- default basepaint blue if no cel
  
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
  
    return #colorList > 0 and colorList or {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} -- default basepaint blue if empty
  end
  
  -- function to grab pixels on export
  local function generateJSON(palette, selectedLayerIndex, frameIndex)
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
  
    local cel = layer:cel(sprite.frames[frameIndex]) -- first frame
    if not cel then
      app.alert("No pixel data found in selected layer/frame!")
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
  
  -- save to file
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
  
  -- copy to clipboard
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

  -- refresh layers
  local function getLayerNames()
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
  local palette = getUniqueColors() -- initialize with sprite colors
  local selectedLayerIndex = 2 -- default to Layer 2
  local currentDayInput = "Day #" -- set default day input text here
  
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
  
  -- plugin window
  local function createDialog()
    if dlg then dlg:close() end
  
    dlg = Dialog{ title = "Baseprite by Creamy" }
  
    -- day input
    dlg:entry{
      id = "dayInput",
      text = currentDayInput
    }

    -- load palette button
    dlg:button{
      text = "Load Palette",
      onclick = function()
        local rawDay = dlg.data and dlg.data.dayInput or "1"
        local maxDay = getCurrentBasepaintDay() + 1
        local day

        if tostring(rawDay):lower():find("random") then
          math.randomseed(os.time())
          day = tostring(math.random(1, maxDay))
          currentDayInput = day
          app.alert("Random palette: Day " .. day)
        else
          local numeric = tonumber(rawDay:match("%d+")) or -1
          if numeric < 1 or numeric > maxDay then
            app.alert("Invalid day! Please enter a number between 1 and " .. maxDay .. ", or type 'random'.")
            return
          end
          day = tostring(numeric)
          currentDayInput = rawDay
        end

        local fetched = fetchBasepaintPalette(day)
        if fetched then
          palette = fetched

          local sprite = app.activeSprite
          if sprite then
            local newPal = Palette(#fetched)
            for i, c in ipairs(fetched) do
              newPal:setColor(i-1, c.color)
            end
            sprite:setPalette(newPal)
          end

          createDialog()
        end
      end
    }

    -- palette hex
    dlg:button{
      text = "Enter Hex",
      onclick = function()
        local hexDlg = Dialog("Import Hex Colors")
        hexDlg
          :entry{ id="hexes", text="", focus=true }
          :button{
            text = "Import",
            onclick = function()
              local input = hexDlg.data.hexes or ""
              local hexList = {}
              for hex in input:gmatch("#?%x%x%x%x%x%x") do
                hex = hex:gsub("#", "")
                local r = tonumber(hex:sub(1,2), 16)
                local g = tonumber(hex:sub(3,4), 16)
                local b = tonumber(hex:sub(5,6), 16)
                table.insert(hexList, { color = Color{ r=r, g=g, b=b, a=255 } })
              end

              if #hexList == 0 then
                app.alert("No valid hex codes found.")
                return
              end

              -- update global palette
              palette = hexList

              -- apply to active sprite
              local sprite = app.activeSprite
              if sprite then
                local newPal = Palette(#hexList)
                for i, c in ipairs(hexList) do
                  newPal:setColor(i-1, c.color)
                end
                sprite:setPalette(newPal)
                app.refresh()
              end

              hexDlg:close()
              createDialog()
            end
          }
          :button{ text="Cancel", onclick=function() hexDlg:close() end }
          :show()
      end
    }

    dlg:newrow()
    dlg:separator()
  
    local layerNames = getLayerNames()

    -- layer menu
    dlg:combobox{
        id = "layer",
        options = layerNames,
        option = layerNames[1]
      }

    -- frame input
    dlg:entry{
      id = "frame",
      text = "Frame 1"
    }      
  
    dlg:newrow()

    -- refresh button
    dlg:button{
        text = "Refresh Layers List",
        onclick = function()
          createDialog() -- re-renders with updated layer list
        end
      }
      
    dlg:newrow()
    dlg:separator()
      
      -- palette
      for i, colorInfo in ipairs(palette) do
        dlg:color{
          id = "color_" .. i,
          color = colorInfo.color,
          label = "",
          onchange = function(ev)
            palette[i].color = ev.color
          end
        }
      
        dlg:newrow()
      end      
  
    dlg:newrow()
    dlg:separator()
  
    -- save button
    dlg:button{
      text = "Save to File",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local frameInput = dlg.data and dlg.data.frame or "1"
        local sprite = app.activeSprite
        local selectedLayerIndex = 1
        local frameIndex = parseFrameInput(frameInput, sprite)

        -- get selected layer index
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedLayerIndex = i
            break
          end
        end

        local json_string = generateJSON(palette, selectedLayerIndex, frameIndex)
        
        if json_string then
          saveToFileWithPrompt(json_string)
        end
      end
    }
  
    -- copy button
    dlg:button{
      text = "Copy to Clipboard",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local frameInput = dlg.data and dlg.data.frame or "1"
        local sprite = app.activeSprite
        local selectedLayerIndex = 1
        local frameIndex = parseFrameInput(frameInput, sprite)

        -- get selected layer index
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedLayerIndex = i
            break
          end
        end

        local json_string = generateJSON(palette, selectedLayerIndex, frameIndex)
        
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