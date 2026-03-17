--[[
    ZCity Appearance Mod
    Заменяет стандартные выпадающие меню выбора одежды на панели с иконками.
    Полностью совместим с оригинальным cl_appearance_editor.lua – не требует его замены.
]]

-- Убедимся, что основная таблица существует
hg.Appearance = hg.Appearance or {}

-----------------------------------------------------------------------
-- 1. Цвета и вспомогательные функции (из вашего файла)
-----------------------------------------------------------------------
local colors = {}
colors.secondary = Color(25,25,35,195)
colors.mainText = Color(255,255,255,255)
colors.secondaryText = Color(45,45,45,125)
colors.selectionBG = Color(20,130,25,225)
colors.highlightText = Color(120,35,35)
colors.presetBG = Color(35,35,45,220)
colors.presetBorder = Color(80,80,100,255)
colors.presetHover = Color(50,50,65,240)
colors.scrollbarBG = Color(20,20,30,200)
colors.scrollbarGrip = Color(70,70,90,255)
colors.scrollbarGripHover = Color(100,100,130,255)
colors.scrollbarBorder = Color(100,100,120,200)
colors.previewBorder = Color(255,200,50,255)

local clr_ico = Color(30, 30, 40, 255)
local clr_menu = Color(15, 15, 20, 250)

local MENU_PREVIEW_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.clothesCols) or 4
local FACEMAP_MENU_PREVIEW_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.facemapCols) or 3
local GLOVES_MENU_PREVIEW_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.glovesCols) or 3
local MODEL_MENU_PREVIEW_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.modelCols) or 4
local SEARCHABLE_CLOTHES_PARTS = {
    main = true,
    pants = true,
    boots = true
}

local scrollPositions = {}

local function RestoreScrollPositionDelayed(scroll, value)
    if not IsValid(scroll) or value == nil then return end

    local token = "ZCityAppearanceMod_RestoreScroll_" .. tostring(scroll)
    token = string.gsub(token, "[^%w]", "")

    local attempts = 0
    timer.Create(token, 0.05, 10, function()
        if not IsValid(scroll) then
            timer.Remove(token)
            return
        end

        local vbar = scroll:GetVBar()
        local canvas = scroll:GetCanvas()
        local max = (vbar and vbar.CanvasSize and vbar.BarSize) and math.max(vbar.CanvasSize - vbar.BarSize, 0) or 0
        if IsValid(canvas) and (canvas:GetTall() > scroll:GetTall() or max > 0 or attempts >= 2) then
            vbar:SetScroll(math.Clamp(value, 0, math.max(max, value)))
            timer.Remove(token)
            return
        end

        attempts = attempts + 1
    end)
end

local function ApplyBaseAppearanceButtonStyle(btn)
    if not IsValid(btn) then return end
    btn:SetFont("ZCity_Tiny")
    function btn:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

local function PaintSelectionIcon(panel, w, h, isSelected, isHovered)
    local bgColor = isSelected and colors.selectionBG or clr_ico
    draw.RoundedBox(4, 0, 0, w, h, bgColor)
    local borderCol = isHovered and Color(255,200,50,255) or colors.scrollbarBorder
    surface.SetDrawColor(borderCol)
    surface.DrawOutlinedRect(0, 0, w, h, isSelected and 2 or 1)
end

local function ApplyFacemapCamera(previewModel, isFemale)
    if not IsValid(previewModel) then return end

    -- FACEMAP_CAMERA_MALE_START
    local maleCamPos = Vector(45, 2, 66)
    local maleLookAt = Vector(7, 2, 64)
    local maleFOV = 20
    -- FACEMAP_CAMERA_MALE_END

    -- FACEMAP_CAMERA_FEMALE_START
    local femaleCamPos = Vector(45, 2, 63)
    local femaleLookAt = Vector(7, 2, 63)
    local femaleFOV = 20
    -- FACEMAP_CAMERA_FEMALE_END

    if isFemale then
        previewModel:SetCamPos(femaleCamPos)
        previewModel:SetLookAt(femaleLookAt)
        previewModel:SetFOV(femaleFOV)
    else
        previewModel:SetCamPos(maleCamPos)
        previewModel:SetLookAt(maleLookAt)
        previewModel:SetFOV(maleFOV)
    end
end


local PREVIEW_RENDER_BOUNDS_MIN = Vector(-10000, -10000, -10000)
local PREVIEW_RENDER_BOUNDS_MAX = Vector(10000, 10000, 10000)

local function FreezePreviewEntity(ent)
    if not IsValid(ent) then return end

    ent:SetRenderBounds(PREVIEW_RENDER_BOUNDS_MIN, PREVIEW_RENDER_BOUNDS_MAX)
    ent.__AppearanceRenderBoundsExpanded = true

    local idleSeq = ent:LookupSequence("idle_suitcase")
    if idleSeq and idleSeq >= 0 then
        ent:SetSequence(idleSeq)
    end

    ent:SetCycle(0)
    ent:SetPlaybackRate(0)
    ent.AutomaticFrameAdvance = false
    ent:SetAngles(Angle(0, 0, 0))

    if ent.SetIK then
        ent:SetIK(false)
    end

    if ent.SetLayerWeight then
        for layerID = 0, 31 do
            ent:SetLayerWeight(layerID, 0)
        end
    end

    if ent.SetLayerPlaybackRate then
        for layerID = 0, 31 do
            ent:SetLayerPlaybackRate(layerID, 0)
        end
    end

    if ent.GetFlexNum and ent.SetFlexWeight then
        local flexCount = ent:GetFlexNum() or 0
        for flexID = 0, math.max(flexCount - 1, 0) do
            ent:SetFlexWeight(flexID, 0)
        end
    end

    if ent.FrameAdvance then
        ent:FrameAdvance(0)
    end
end

local function EnsurePreviewPanelBounds(mdlPanel)
    if not IsValid(mdlPanel) then return end

    local function ApplyBounds()
        if not IsValid(mdlPanel) then return end
        local ent = mdlPanel.Entity
        if IsValid(ent) then
            ent:SetRenderBounds(PREVIEW_RENDER_BOUNDS_MIN, PREVIEW_RENDER_BOUNDS_MAX)
        end
    end

    ApplyBounds()
    timer.Simple(0, ApplyBounds)
end

local function ResolveCurrentModelData(appearanceTable)
    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    local currentModelName = (editTable and editTable.AModel) or "Male 01"
    local sexIndex = 1

    if hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][currentModelName] then
        sexIndex = 2
    end

    local modelData = hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[sexIndex] and hg.Appearance.PlayerModels[sexIndex][currentModelName]
    local currentModelPath = (modelData and modelData.mdl) or "models/player/group01/male_01.mdl"

    return editTable, currentModelName, currentModelPath, sexIndex, modelData
end

local function ApplyPreviewAppearance(ent, sexIndex, modelData, appearanceTable)
    if not IsValid(ent) or not modelData then return end

    local clothesTable = hg.Appearance.Clothes and hg.Appearance.Clothes[sexIndex]
    local appearanceClothes = appearanceTable and appearanceTable.AClothes or {}
    local materials = ent:GetMaterials()

    if modelData.submatSlots and clothesTable then
        for slot, matName in pairs(modelData.submatSlots) do
            if slot ~= "hands" then
                local selectedClothesId = appearanceClothes[slot] or "normal"
                local selectedTexture = clothesTable[selectedClothesId] or clothesTable["normal"]
                if selectedTexture then
                    for matIndex, modelMat in ipairs(materials) do
                        if modelMat == matName then
                            ent:SetSubMaterial(matIndex - 1, selectedTexture)
                            break
                        end
                    end
                end
            end
        end
    end

    if appearanceTable and appearanceTable.AFacemap and appearanceTable.AFacemap ~= "Default" then
        local facemapSlots = {}
        local modelKey = string.lower(modelData.mdl or "")
        local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]

        if multi and multi[appearanceTable.AFacemap] then
            facemapSlots = multi[appearanceTable.AFacemap]
        else
            local modelSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
            local slotVariants = modelSlot and hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[modelSlot]
            if slotVariants and slotVariants[appearanceTable.AFacemap] then
                facemapSlots = { [modelSlot] = slotVariants[appearanceTable.AFacemap] }
            end
        end

        for slotName, texturePath in pairs(facemapSlots) do
            for matIndex, modelMat in ipairs(materials) do
                if modelMat == slotName then
                    ent:SetSubMaterial(matIndex - 1, texturePath)
                    break
                end
            end
        end
    end
end

-- Функция создания стилизованного скролла (если её нет в оригинале)
if not CreateStyledScrollPanel then
    function CreateStyledScrollPanel(parent)
        local scroll = vgui.Create("DScrollPanel", parent)
        local sbar = scroll:GetVBar()
        sbar:SetWide(ScreenScale(4))
        sbar:SetHideButtons(true)
        function sbar:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, colors.scrollbarBG)
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        function sbar.btnGrip:Paint(w, h)
            local col = self:IsHovered() and colors.scrollbarGripHover or colors.scrollbarGrip
            draw.RoundedBox(4, 2, 2, w - 4, h - 4, col)
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
        end
        return scroll
    end
end

-----------------------------------------------------------------------
-- 2. Функция создания меню с иконками (из вашего файла)
-----------------------------------------------------------------------
local function CreateClothesIconMenu(parent, title, clothesTable, sex, currentSelection, onSelect, showColorPicker, partName, currentModelName, currentModelPath, appearanceTable, onClose, scrollKey)
    local selectedName = string.NiceName(currentSelection or "normal")
    local baseTitle = title or "Select Clothing"

    local menu = vgui.Create("DFrame")
    menu:SetTitle(baseTitle .. " - " .. selectedName)
    menu:SetSize(ScreenScale(226), ScreenScale(220))

    -- Позиционирование
    local x, y
    if parent and IsValid(parent) then
        local parentX, parentY = parent:LocalToScreen(0, 0)
        local parentW, parentH = parent:GetSize()
        x = parentX + parentW + ScreenScale(5)
        y = parentY
        if x + menu:GetWide() > ScrW() then
            x = parentX - menu:GetWide() - ScreenScale(5)
        end
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    else
        local cx, cy = input.GetCursorPos()
        x, y = cx, cy
    end
    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(true)

    local function IsPanelInsideMenu(panel)
        while IsValid(panel) do
            if panel == menu then return true end
            panel = panel:GetParent()
        end
        return false
    end

    function menu:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local focusedPanel = vgui.GetKeyboardFocus()
            local hoveredPanel = vgui.GetHoveredPanel()

            if IsPanelInsideMenu(focusedPanel) or IsPanelInsideMenu(hoveredPanel) then return end
            self:Close()
        end)
    end

    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, clr_menu)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(10), colors.secondary, true, true, false, false)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawLine(0, ScreenScale(10), w, ScreenScale(10))
    end

    local searchValue = ""
    local searchPanel
    local searchEntry
    local searchButtonSize = 20

    if SEARCHABLE_CLOTHES_PARTS[partName] then
        searchPanel = vgui.Create("DPanel", menu)
        searchPanel:Dock(TOP)
        searchPanel:SetTall(math.max(ScreenScale(14), searchButtonSize + 4))
        searchPanel:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), 0)
        function searchPanel:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 25, 235))
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))


        -- Восстановление позиции скролла
    if scrollKey and scrollPositions[scrollKey] then
        timer.Simple(0.1, function()
            if IsValid(scroll) then
                local vbar = scroll:GetVBar()
                vbar:SetScroll(scrollPositions[scrollKey])
            end
        end)
    end



    -- Сетка 4x
    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(TOP)
    grid:SetCols(MENU_PREVIEW_COLS)
    grid:SetColWide(ScreenScale(53))
    grid:SetRowHeight(ScreenScale(56))

    local clothesEntries = {}
    local selectedIcon

    local function NormalizeSearchValue(value)
        local normalized = string.lower(value or "")
        normalized = string.gsub(normalized, "_", " ")
        normalized = string.gsub(normalized, "%s+", " ")
        return string.Trim(normalized)
    end

    local function MatchesSearch(clothesId)
        if searchValue == "" then return true end
        local normalizedId = NormalizeSearchValue(clothesId)
        local normalizedPretty = NormalizeSearchValue(string.NiceName(clothesId or ""))
        return string.find(normalizedId, searchValue, 1, true) ~= nil
            or string.find(normalizedPretty, searchValue, 1, true) ~= nil
    end

    local clothesEntries = {}
    local selectedIcon

    local function NormalizeSearchValue(value)
        local normalized = string.lower(value or "")
        normalized = string.gsub(normalized, "_", " ")
        normalized = string.gsub(normalized, "%s+", " ")
        return string.Trim(normalized)
    end

    local function MatchesSearch(clothesId)
        if searchValue == "" then return true end
        local normalizedId = NormalizeSearchValue(clothesId)
        local normalizedPretty = NormalizeSearchValue(string.NiceName(clothesId or ""))
        return string.find(normalizedId, searchValue, 1, true) ~= nil
            or string.find(normalizedPretty, searchValue, 1, true) ~= nil
    end

    -- Панель с текущим выбором
    local infoPanel = vgui.Create("DPanel", scroll)
    infoPanel:Dock(TOP)
    infoPanel:SetTall(ScreenScale(20))
    infoPanel:DockMargin(0, 0, 0, ScreenScale(4))
    function infoPanel:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 25, 240))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    local currentLabel = vgui.Create("DLabel", infoPanel)
    currentLabel:Dock(FILL)
    currentLabel:DockMargin(ScreenScale(4), 0, 0, 0)
    currentLabel:SetFont("ZCity_Tiny")
    currentLabel:SetText("Current: " .. selectedName)
    currentLabel:SetTextColor(colors.mainText)
    currentLabel:SetContentAlignment(4)

    -- Палитра цветов (только для main)
    if showColorPicker then
        local colorPanel = vgui.Create("DPanel", scroll)
        colorPanel:Dock(TOP)
        colorPanel:SetTall(ScreenScale(32))
        colorPanel:DockMargin(0, ScreenScale(4), 0, 0)
        function colorPanel:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 25, 240))
        end

        local colorLabel = vgui.Create("DLabel", colorPanel)
        colorLabel:SetPos(ScreenScale(4), ScreenScale(6))
        colorLabel:SetFont("ZCity_Tiny")
        colorLabel:SetText("Color:")
        colorLabel:SizeToContents()
        colorLabel:SetTextColor(colors.mainText)

        local colorPickerBtn = vgui.Create("DButton", colorPanel)
        colorPickerBtn:SetPos(ScreenScale(40), ScreenScale(4))
        colorPickerBtn:SetSize(ScreenScale(70), ScreenScale(28))
        colorPickerBtn:SetText("")

        local paletteHeaderBtn = vgui.Create("DImageButton", menu)
        paletteHeaderBtn:SetImage("icon16/palette.png")
        paletteHeaderBtn:SetSize(20, 20)
        paletteHeaderBtn:SetTooltip("Open color palette")
        function paletteHeaderBtn:Think()
            if not IsValid(menu) or not IsValid(menu.btnClose) then return end
            local closeX, closeY = menu.btnClose:GetPos()
            local closeH = menu.btnClose:GetTall()
            self:SetPos(closeX - self:GetWide() - 6, closeY + math.floor((closeH - self:GetTall()) * 0.5))
        end

        local currentColor = onSelect and onSelect.getCurrentColor and onSelect.getCurrentColor() or Color(255,255,255)

        function colorPickerBtn:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, currentColor)
            local borderCol = self:IsHovered() and Color(255,200,50,255) or colors.scrollbarBorder
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if self:IsHovered() then
                draw.SimpleText("Change", "ZCity_Tiny", w/2, h/2, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        function colorPickerBtn:DoClick()
            local colorMenu = vgui.Create("DFrame")
            colorMenu:SetTitle("Select Color")
            colorMenu:SetSize(ScreenScale(120), ScreenScale(140))
            local x, y = self:LocalToScreen(0, 0)
            x = x + self:GetWide() + ScreenScale(5)
            y = y
            if x + colorMenu:GetWide() > ScrW() then
                x = x - colorMenu:GetWide() - self:GetWide() - ScreenScale(10)
            end
            if y + colorMenu:GetTall() > ScrH() then
                y = ScrH() - colorMenu:GetTall() - ScreenScale(5)
            end
            colorMenu:SetPos(x, y)
            colorMenu:MakePopup()
            colorMenu:SetDraggable(false)

            function colorMenu:OnFocusChanged(gained)
                if not gained then self:Close() end
            end

            function colorMenu:Paint(w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 20, 250))
                surface.SetDrawColor(colors.scrollbarBorder)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end

            local colorMixer = vgui.Create("DColorMixer", colorMenu)
            colorMixer:Dock(FILL)
            colorMixer:DockMargin(ScreenScale(4), ScreenScale(4), ScreenScale(4), ScreenScale(4))
            colorMixer:SetColor(currentColor)

            function colorMixer:ValueChanged(clr)
                currentColor = clr
                if onSelect and onSelect.color then
                    onSelect.color(clr)
                end
                if IsValid(colorPickerBtn) then
                    colorPickerBtn.currentColor = clr
                end
            end

            local closeBtn = vgui.Create("DButton", colorMenu)
            closeBtn:Dock(BOTTOM)
            closeBtn:SetTall(ScreenScale(16))
            closeBtn:DockMargin(ScreenScale(4), 0, ScreenScale(4), ScreenScale(4))
            closeBtn:SetText("Close")
            closeBtn:SetFont("ZCity_Tiny")
            function closeBtn:Paint(w, h)
                draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
                surface.SetDrawColor(colors.scrollbarBorder)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            function closeBtn:DoClick() colorMenu:Close() end
        end

        function paletteHeaderBtn:DoClick()
            if IsValid(colorPickerBtn) then
                colorPickerBtn:DoClick()
            end
        end
    end

    -- Получаем текущие текстуры из appearanceTable
    local currentMaterials = {}
    if appearanceTable and appearanceTable.AClothes then
        for slot, key in pairs(appearanceTable.AClothes) do
            if hg.Appearance.Clothes[sex] and hg.Appearance.Clothes[sex][key] then
                currentMaterials[slot] = hg.Appearance.Clothes[sex][key]
            else
                currentMaterials[slot] = hg.Appearance.Clothes[sex]["normal"]
            end
        end
    else
        local normalPath = hg.Appearance.Clothes[sex] and hg.Appearance.Clothes[sex]["normal"] or ""
        currentMaterials = { main = normalPath, pants = normalPath, boots = normalPath }
    end

    -- Функция создания иконки
    local function CreateClothesIcon(clothesId, clothesPath, partName, modelPath, modelName)
        local ico = vgui.Create("DPanel")
        ico:SetSize(ScreenScale(52), ScreenScale(52))
        ico.ClothesId = clothesId
        ico.bIsHovered = false
        ico.IsSelected = (clothesId == currentSelection)

        local previewModel = vgui.Create("DModelPanel", ico)
        previewModel:Dock(FILL)
        previewModel:DockMargin(2, 2, 2, 2)
        previewModel:SetModel(modelPath)
        EnsurePreviewPanelBounds(previewModel)
        previewModel:SetAnimated(false)
        previewModel:SetAnimSpeed(0)
        function previewModel:RunAnimation() end

        -- Настройка камеры в зависимости от части тела
        local camPos, lookAt, fov
        if partName == "main" or partName == "jacket" then
            camPos = Vector(70, 0, 40)
            lookAt = Vector(0, 0, 45)
            fov = 25
        elseif partName == "pants" then
            camPos = Vector(70, 0, 20)
            lookAt = Vector(0, 0, 15)
            fov = 30
        elseif partName == "boots" then
            camPos = Vector(40, -50, 30) -- was 5
            lookAt = Vector(7, 0, 0)
            fov = 14
        --[[    
        elseif partName == "boots" then
            camPos = Vector(60, 0, 20) -- was 5
            lookAt = Vector(0, 8, 0)
            fov = 15
        ]]
        end

        previewModel:SetCamPos(camPos)
        previewModel:SetLookAt(lookAt)
        previewModel:SetFOV(fov)
        previewModel:SetDirectionalLight(BOX_RIGHT, Color(255, 0, 0))
        previewModel:SetDirectionalLight(BOX_LEFT, Color(125, 155, 255))
        previewModel:SetDirectionalLight(BOX_FRONT, Color(160, 160, 160))
        previewModel:SetDirectionalLight(BOX_BACK, Color(0, 0, 0))
        previewModel:SetAmbientLight(Color(50, 50, 50))

        function previewModel:PreDrawModel(ent)
            render.SetColorModulation(1, 1, 1)
        end
        function previewModel:PostDrawModel(ent)
            render.SetColorModulation(1, 1, 1)
        end

        function previewModel:LayoutEntity(ent)
            if not IsValid(ent) then return end
            FreezePreviewEntity(ent)

            if ent.__AppearanceFrozenClothes and ent.__AppearanceFrozenClothes == clothesId then return end

            local modelData = hg.Appearance.PlayerModels[sex] and hg.Appearance.PlayerModels[sex][modelName]
            if not modelData or not modelData.submatSlots then return end

            local mats = ent:GetMaterials()

            -- Применяем текстуру для текущего слота
            local currentSlotMaterialName = modelData.submatSlots[partName]
            if currentSlotMaterialName then
                local slotIndex
                for i, matName in ipairs(mats) do
                    if matName == currentSlotMaterialName then slotIndex = i - 1 break end
                end
                if slotIndex then ent:SetSubMaterial(slotIndex, clothesPath) end
            end

            -- Применяем остальные слоты из currentMaterials
            for slot, matName in pairs(modelData.submatSlots) do
                if slot ~= partName then
                    local slotIndex
                    for i, mName in ipairs(mats) do
                        if mName == matName then slotIndex = i - 1 break end
                    end
                    if slotIndex then
                        local texturePath = currentMaterials[slot] or hg.Appearance.Clothes[sex]["normal"]
                        ent:SetSubMaterial(slotIndex, texturePath)
                    end
                end
            end
            ent:SetColor(Color(255,255,255))
            ent.__AppearanceFrozenClothes = clothesId
        end

        local nameLabel = vgui.Create("DLabel", ico)
        nameLabel:SetPos(0, ScreenScale(42))
        nameLabel:SetSize(ScreenScale(52), ScreenScale(10))
        nameLabel:SetFont("ZCity_Tiny")
        nameLabel:SetText(string.NiceName(clothesId))
        nameLabel:SetTextColor(colors.mainText)
        nameLabel:SetContentAlignment(5)
        nameLabel:SetExpensiveShadow(1, Color(0,0,0,200))

        function previewModel:DoClick()
            if onSelect and onSelect.clothes then
                onSelect.clothes(clothesId)
            end
            surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
            menu:Close()
        end

        function ico:Paint(w, h)
            local bgColor = self.IsSelected and Color(40, 140, 45, 255) or clr_ico
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            local borderCol = self.bIsHovered and Color(255,200,50,255) or colors.scrollbarBorder
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        function ico:Think()
            self.bIsHovered = vgui.GetHoveredPanel() == self or vgui.GetHoveredPanel() == previewModel
            self.IsSelected = (clothesId == currentSelection)
            if self.IsSelected then
                selectedIcon = self
            end
        end

        return ico
    end

    local function RebuildClothesGrid()
        grid:Clear()
        selectedIcon = nil

        for _, entry in ipairs(clothesEntries) do
            if MatchesSearch(entry.id) then
                local icon = CreateClothesIcon(entry.id, entry.path, partName, currentModelPath, currentModelName)
                grid:AddItem(icon)
            end
        end

        grid:InvalidateLayout(true)
        scroll:InvalidateLayout(true)
    end

    -- Добавляем все предметы в сетку
    for clothesId, clothesPath in SortedPairs(clothesTable) do
        table.insert(clothesEntries, {
            id = clothesId,
            path = clothesPath
        })
    end

    RebuildClothesGrid()

    if IsValid(searchPanel) then
        local searchButton = vgui.Create("DImageButton", searchPanel)
        searchButton:Dock(RIGHT)
        searchButton:SetWide(searchButtonSize + 4)
        searchButton:SetImage("icon16/magnifier.png")
        searchButton:SetKeepAspect(true)
        searchButton:SetStretchToFit(false)
        searchButton:DockMargin(0, 2, 2, 2)
        searchButton:SetTooltip("Search")

        searchEntry = vgui.Create("DTextEntry", searchPanel)
        searchEntry:Dock(FILL)
        searchEntry:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))
        searchEntry:SetPlaceholderText("Search clothes...")
        searchEntry:SetUpdateOnType(true)

        function searchEntry:OnValueChange(value)
            searchValue = NormalizeSearchValue(value)
            RebuildClothesGrid()
        end

        function searchButton:DoClick()
            searchValue = NormalizeSearchValue(searchEntry:GetValue())
            RebuildClothesGrid()
        end
    end

    local vbar = scroll:GetVBar()
    function vbar:PaintOver(w, h)
        if not IsValid(selectedIcon) then return end

        local canvas = scroll:GetCanvas()
        if not IsValid(canvas) then return end

        local _, selectedY = selectedIcon:LocalToScreen(0, selectedIcon:GetTall() * 0.5)
        local _, canvasY = canvas:LocalToScreen(0, 0)
        local canvasTall = math.max(canvas:GetTall(), 1)
        local relativePos = math.Clamp((selectedY - canvasY) / canvasTall, 0, 1)
        local markerY = math.floor(relativePos * h)

        draw.RoundedBox(2, 0, math.Clamp(markerY - 2, 0, math.max(h - 4, 0)), w, 4, Color(50, 220, 80, 240))
    end

    -- Разделитель
    local separator = vgui.Create("DPanel", scroll)
    separator:Dock(TOP)
    separator:SetTall(ScreenScale(2))
    separator:DockMargin(0, ScreenScale(4), 0, ScreenScale(2))
    function separator:Paint(w, h)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawRect(0, 0, w, h)
    end

    -- Кнопка None
    local noneButton = vgui.Create("DButton", scroll)
    noneButton:Dock(TOP)
    noneButton:SetTall(ScreenScale(24))
    noneButton:SetText("")
    function noneButton:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 50, 240))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("None (Reset)", "ZCity_Tiny", w/2, h/2, colors.mainText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    function noneButton:DoClick()
        if onSelect and onSelect.clothes then
            onSelect.clothes("normal")
        end
        surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
        menu:Close()
    end



     -- Сохранение позиции при закрытии
    function menu:OnClose()
        if scrollKey and IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions[scrollKey] = vbar:GetScroll()
        end
        -- Если есть внешний onClose, вызываем его
        if onClose then onClose() end
    end





    return menu
end



-----------------------------------------------------------------------
-- Функция создания меню для Facemap
-----------------------------------------------------------------------
local function CreateFacemapIconMenu(parent, title, combinedVariants, sortedNames, sex, currentSelection, onSelect, partName, currentModelName, currentModelPath, appearanceTable, onClose, scrollKey)
    local selectedName = string.NiceName(currentSelection or "Default")
    local baseTitle = title or "Select Face"

    local menu = vgui.Create("DFrame")
    menu:SetTitle(baseTitle .. " - " .. selectedName)

    local defaultMenuHeight = ScreenScale(220)
    local rowsCount = math.max(1, math.ceil(#sortedNames / FACEMAP_MENU_PREVIEW_COLS))
    local contentHeight = ScreenScale(24) + (rowsCount * ScreenScale(56)) + ScreenScale(12) + ScreenScale(24)
    local dynamicMenuHeight = math.Clamp(contentHeight + ScreenScale(20), ScreenScale(130), defaultMenuHeight)

    menu:SetSize(ScreenScale(170), dynamicMenuHeight)

    -- Позиционирование как в ClothesIconMenu
    local x, y
    if parent and IsValid(parent) then
        local parentX, parentY = parent:LocalToScreen(0, 0)
        local parentW, parentH = parent:GetSize()
        x = parentX + parentW + ScreenScale(5)
        y = parentY
        if x + menu:GetWide() > ScrW() then
            x = parentX - menu:GetWide() - ScreenScale(5)
        end
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    else
        local cx, cy = input.GetCursorPos()
        x, y = cx, cy
    end
    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(true)

    function menu:OnFocusChanged(gained)
        if not gained then self:Close() end
    end

    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, clr_menu)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(10), colors.secondary, true, true, false, false)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawLine(0, ScreenScale(10), w, ScreenScale(10))
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))



    if scrollKey and scrollPositions[scrollKey] then
        timer.Simple(0.1, function()
            if IsValid(scroll) then
                local vbar = scroll:GetVBar()
                vbar:SetScroll(scrollPositions[scrollKey])
            end
        end)
    end





    -- Сетка 3x
    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(TOP)
    grid:SetCols(FACEMAP_MENU_PREVIEW_COLS)
    grid:SetColWide(ScreenScale(52))
    grid:SetRowHeight(ScreenScale(56))

    -- Панель с текущим выбором
    local infoPanel = vgui.Create("DPanel", scroll)
    infoPanel:Dock(TOP)
    infoPanel:SetTall(ScreenScale(20))
    infoPanel:DockMargin(0, 0, 0, ScreenScale(4))
    function infoPanel:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 25, 240))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    local currentLabel = vgui.Create("DLabel", infoPanel)
    currentLabel:Dock(FILL)
    currentLabel:DockMargin(ScreenScale(4), 0, 0, 0)
    currentLabel:SetFont("ZCity_Tiny")
    currentLabel:SetText("Current: " .. selectedName)
    currentLabel:SetTextColor(colors.mainText)
    currentLabel:SetContentAlignment(4)

    -- Функция создания иконки
    local function CreateFacemapIcon(varName, slotMap, modelPath, modelName, sex, currentSelection, onSelect)
        local ico = vgui.Create("DPanel")
        ico:SetSize(ScreenScale(52), ScreenScale(52))
        ico.VarName = varName
        ico.bIsHovered = false
        ico.IsSelected = (varName == currentSelection)

        local previewModel = vgui.Create("DModelPanel", ico)
        previewModel:Dock(FILL)
        previewModel:DockMargin(2, 2, 2, 2)
        previewModel:SetModel(modelPath)
        EnsurePreviewPanelBounds(previewModel)
        previewModel:SetAnimated(false)
        previewModel:SetAnimSpeed(0)
        function previewModel:RunAnimation() end
        ApplyFacemapCamera(previewModel, sex == 2)

        previewModel:SetDirectionalLight(BOX_RIGHT, Color(255, 0, 0))
        previewModel:SetDirectionalLight(BOX_LEFT, Color(125, 155, 255))
        previewModel:SetDirectionalLight(BOX_FRONT, Color(160, 160, 160))
        previewModel:SetDirectionalLight(BOX_BACK, Color(0, 0, 0))
        previewModel:SetAmbientLight(Color(50, 50, 50))

        function previewModel:PreDrawModel(ent)
            render.SetColorModulation(1, 1, 1)
        end
        function previewModel:PostDrawModel(ent)
            render.SetColorModulation(1, 1, 1)
        end

        function previewModel:LayoutEntity(ent)
            if not IsValid(ent) then return end
            FreezePreviewEntity(ent)

            if ent.__AppearanceFrozenFacemap and ent.__AppearanceFrozenFacemap == varName then return end

            local modelData = hg.Appearance.PlayerModels[sex] and hg.Appearance.PlayerModels[sex][modelName]
            if not modelData or not modelData.mdl then return end

            local mats = ent:GetMaterials()

            -- Применяем все текстуры из slotMap
            for slotMaterial, texturePath in pairs(slotMap) do
                -- Находим индекс этого материала в модели
                local slotIndex
                for i, matName in ipairs(mats) do
                    if matName == slotMaterial then
                        slotIndex = i - 1
                        break
                    end
                end
                if slotIndex then
                    ent:SetSubMaterial(slotIndex, texturePath)
                end
            end

            ent:SetColor(Color(255,255,255))
            ent.__AppearanceFrozenFacemap = varName
        end

        local nameLabel = vgui.Create("DLabel", ico)
        nameLabel:SetPos(0, ScreenScale(42))
        nameLabel:SetSize(ScreenScale(52), ScreenScale(10))
        nameLabel:SetFont("ZCity_Tiny")
        nameLabel:SetText(string.NiceName(varName))
        nameLabel:SetTextColor(colors.mainText)
        nameLabel:SetContentAlignment(5)
        nameLabel:SetExpensiveShadow(1, Color(0,0,0,200))

        function previewModel:DoClick()
            if onSelect then
                onSelect(varName)
            end
            surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
            menu:Close()
        end

        function ico:Paint(w, h)
            local bgColor = self.IsSelected and Color(40, 140, 45, 255) or clr_ico
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
            local borderCol = self.bIsHovered and Color(255,200,50,255) or colors.scrollbarBorder
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        function ico:Think()
            self.bIsHovered = vgui.GetHoveredPanel() == self or vgui.GetHoveredPanel() == previewModel
            self.IsSelected = (varName == currentSelection)
        end

        return ico
    end

    -- Добавляем все facemap в сетку
    for _, varName in ipairs(sortedNames) do
        local slotMap = combinedVariants[varName]  -- таблица слот -> путь
        local icon = CreateFacemapIcon(varName, slotMap, currentModelPath, currentModelName, sex, currentSelection, onSelect)
        grid:AddItem(icon)
    end

    -- Разделитель
    local separator = vgui.Create("DPanel", scroll)
    separator:Dock(TOP)
    separator:SetTall(ScreenScale(2))
    separator:DockMargin(0, ScreenScale(4), 0, ScreenScale(2))
    function separator:Paint(w, h)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawRect(0, 0, w, h)
    end

    -- Кнопка Default (сброс на стандартное лицо)
    local noneButton = vgui.Create("DButton", scroll)
    noneButton:Dock(TOP)
    noneButton:SetTall(ScreenScale(24))
    noneButton:SetText("")
    function noneButton:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 50, 240))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Default", "ZCity_Tiny", w/2, h/2, colors.mainText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    function noneButton:DoClick()
        if onSelect then
            onSelect("Default")
        end
        surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
        menu:Close()
    end



    function menu:OnClose()
        if scrollKey and IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions[scrollKey] = vbar:GetScroll()
        end
        if onClose then onClose() end
    end





    return menu
end









-- Публичная функция открытия меню одежды
function hg.Appearance.OpenClothesMenu(parent, partName, currentSelection, onSelectCallback, appearanceTable, onClose)
    local ply = LocalPlayer()
    if not ply then return end

    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    local currentModelName = "Male 01"
    local currentModelPath = "models/player/group01/male_01.mdl"
    if editTable and editTable.AModel then
        currentModelName = editTable.AModel
    end

    local isFemale = false
    if hg.Appearance.PlayerModels then
        if hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][currentModelName] then
            isFemale = true
        end
    end
    local sexIndex = isFemale and 2 or 1

    if hg.Appearance.PlayerModels then
        local sexModels = hg.Appearance.PlayerModels[sexIndex]
        if sexModels and sexModels[currentModelName] and sexModels[currentModelName].mdl then
            currentModelPath = sexModels[currentModelName].mdl
        end
    end

    local clothesTable = hg.Appearance.Clothes[sexIndex] or {}
    local titles = { main = "Select Jacket", pants = "Select Pants", boots = "Select Boots" }
    local showColorPicker = (partName == "main")

    local currentColor = Color(255,255,255)
    if editTable and editTable.AColor then
        currentColor = editTable.AColor
    end

    local menu = CreateClothesIconMenu(
        parent,
        titles[partName] or "Select Clothing",
        clothesTable,
        sexIndex,
        currentSelection,
        {
            clothes = function(id) if onSelectCallback then onSelectCallback(id) end end,
            color = function(clr) if editTable then editTable.AColor = clr end end,
            getCurrentColor = function() return currentColor end
        },
        showColorPicker,
        partName,
        currentModelName,
        currentModelPath,
        editTable,
        onClose,
        "clothes_" .. partName   -- scrollKey
    )
    return menu
end



-- Публичная функция открытия меню Facemap
function hg.Appearance.OpenFacemapMenu(parent, currentSelection, onSelectCallback, appearanceTable, onClose)
    local ply = LocalPlayer()
    if not ply then return end

    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    local currentModelName = "Male 01"
    local currentModelPath = "models/player/group01/male_01.mdl"
    if editTable and editTable.AModel then
        currentModelName = editTable.AModel
    end

    local isFemale = false
    if hg.Appearance.PlayerModels then
        if hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][currentModelName] then
            isFemale = true
        end
    end
    local sexIndex = isFemale and 2 or 1

    if hg.Appearance.PlayerModels then
        local sexModels = hg.Appearance.PlayerModels[sexIndex]
        if sexModels and sexModels[currentModelName] and sexModels[currentModelName].mdl then
            currentModelPath = sexModels[currentModelName].mdl
        end
    end


    -- =====================================================
    -- НОВАЯ СИСТЕМА MULTI-FACEMAPS (если есть)
    -- =====================================================

    local combinedVariants = {}

    local modelKey = string.lower(currentModelPath)
    local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]

    if multi then
        -- Используем новую систему
        combinedVariants = multi

    else

        -- =====================================================
        -- СТАРАЯ СИСТЕМА ZCITY (fallback)
        -- =====================================================

        local modelSlots = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]

        if not modelSlots then
            notification.AddLegacy("This model does not support face changing", NOTIFY_ERROR, 3)
            return
        end

        local slotVariants = hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[modelSlots]

        if slotVariants then
            for varName, texturePath in pairs(slotVariants) do
                combinedVariants[varName] = {
                    [modelSlots] = texturePath
                }
            end
        end

    end




    --[[
    -- Получаем все слоты, связанные с этой моделью
    local modelSlots = hg.Appearance.ModelFaceSlots and hg.Appearance.ModelFaceSlots[currentModelPath]
    if not modelSlots or table.IsEmpty(modelSlots) then
        -- Если нет специальных слотов, пробуем старый способ (один слот)
        local faceSlotMaterial = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[currentModelPath]
        if faceSlotMaterial then
            modelSlots = { [faceSlotMaterial] = true }
        else
            notification.AddLegacy("This model does not support face changing", NOTIFY_ERROR, 3)
            return
        end
    end

    -- Собираем все варианты лица, объединяя по имени
    local combinedVariants = {}  -- ключ: имя варианта, значение: таблица { [slot] = texturePath }
    for slot, _ in pairs(modelSlots) do
        local slotVariants = hg.Appearance.FacemapsSlots[slot]
        if slotVariants then
            for varName, texturePath in pairs(slotVariants) do
                combinedVariants[varName] = combinedVariants[varName] or {}
                combinedVariants[varName][slot] = texturePath
            end
        end
    end
    ]]


    if table.IsEmpty(combinedVariants) then
        notification.AddLegacy("No facemaps available", NOTIFY_ERROR, 3)
        return
    end

    -- Сортируем имена вариантов (например, по алфавиту)
    local sortedNames = table.GetKeys(combinedVariants)
    table.sort(sortedNames)

    -- Создаём меню, передавая собранные варианты
    local menu = CreateFacemapIconMenu(
        parent,
        "Select Face",
        combinedVariants,        -- теперь это таблица имя -> { slot = texture }
        sortedNames,             -- отсортированный список имён
        sexIndex,
        currentSelection,
        function(varName)        -- onSelect
            if onSelectCallback then
                onSelectCallback(varName)
            end
            -- Если нужно обновить несколько полей в AppearanceTable, сделай это здесь,
            -- но для совместимости оставляем пока только одно поле.
            -- Например, если у модели есть отдельные поля для волос, их можно установить:
            -- if editTable then
            --     editTable.AFacemap = varName  -- основное поле
            --     -- для волос можно использовать editTable.AHair = varName, но нужно знать, как они хранятся
            -- end
        end,
        "face",
        currentModelName,
        currentModelPath,
        editTable,
        onClose,
        "facemap"   -- scrollKey
    )
    return menu
end


local function CreateGlovesIconMenu(parent, currentSelection, onSelectCallback, appearanceTable, onClose)
    local editTable, currentModelName, currentModelPath, sexIndex, modelData = ResolveCurrentModelData(appearanceTable)
    if not modelData then return end

    local bodygroupsBySex = hg.Appearance.Bodygroups and hg.Appearance.Bodygroups["HANDS"] and hg.Appearance.Bodygroups["HANDS"][sexIndex]
    if not bodygroupsBySex then
        notification.AddLegacy("No gloves available", NOTIFY_ERROR, 3)
        return
    end

    local menu = vgui.Create("DFrame")
    menu:SetTitle("Select Gloves - " .. string.NiceName(currentSelection or "None"))
    menu:SetSize(ScreenScale(210), ScreenScale(165))

    local x, y
    if parent and IsValid(parent) then
        local parentX, parentY = parent:LocalToScreen(0, 0)
        local parentW = parent:GetWide()
        x = parentX + parentW + ScreenScale(5)
        y = parentY
        if x + menu:GetWide() > ScrW() then
            x = parentX - menu:GetWide() - ScreenScale(5)
        end
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    else
        x, y = input.GetCursorPos()
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    end
    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(true)

    local function IsPanelInsideMenu(panelToCheck)
        while IsValid(panelToCheck) do
            if panelToCheck == menu then return true end
            panelToCheck = panelToCheck:GetParent()
        end
        return false
    end

    function menu:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local focusedPanel = vgui.GetKeyboardFocus()
            local hoveredPanel = vgui.GetHoveredPanel()

            if IsPanelInsideMenu(focusedPanel) or IsPanelInsideMenu(hoveredPanel) then return end
            self:Close()
        end)
    end

    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, clr_menu)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))

    if scrollPositions.gloves then
        timer.Simple(0, function()
            if not IsValid(scroll) then return end
            scroll:GetVBar():SetScroll(scrollPositions.gloves)
        end)
    end

    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(TOP)
    grid:SetCols(GLOVES_MENU_PREVIEW_COLS)
    grid:SetColWide(ScreenScale(68))
    grid:SetRowHeight(ScreenScale(66))

    local lply = LocalPlayer()
    local selectedIcon

    for gloveName, gloveData in SortedPairs(bodygroupsBySex) do
        local hasAccess = hg.Appearance.GetAccessToAll and hg.Appearance.GetAccessToAll(lply)
        local hasItem = lply and lply.PS_HasItem and gloveData and gloveData.ID and lply:PS_HasItem(gloveData.ID)
        if gloveData and gloveData[2] and not hasAccess and not hasItem then continue end
        local icon = vgui.Create("DButton")
        icon:SetText("")
        icon:SetSize(ScreenScale(66), ScreenScale(62))

        local mdl = vgui.Create("DModelPanel", icon)
        mdl:Dock(FILL)
        mdl:DockMargin(2, 2, 2, 10)
        mdl:SetModel(currentModelPath)
        EnsurePreviewPanelBounds(mdl)
        mdl:SetAnimated(false)
        function mdl:RunAnimation() end

        -- GLOVES_CAMERA_START
        mdl:SetCamPos(Vector(9, -24, 34))
        mdl:SetLookAt(Vector(3, -10, 31))
        mdl:SetFOV(25)
        -- GLOVES_CAMERA_END

        function mdl:LayoutEntity(ent)
            if not IsValid(ent) then return end
            FreezePreviewEntity(ent)

            ApplyPreviewAppearance(ent, sexIndex, modelData, editTable)

            local defaultHandsMaterial = (sexIndex == 2) and "models/humans/female/group01/normal" or "models/humans/male/group01/normal"
            if modelData.submatSlots and modelData.submatSlots.hands then
                local handsSlot = modelData.submatSlots.hands
                for matIndex, modelMatName in ipairs(ent:GetMaterials()) do
                    if modelMatName == handsSlot then
                        ent:SetSubMaterial(matIndex - 1, defaultHandsMaterial)
                        break
                    end
                end
            end

            local pointItem = gloveData and gloveData.ID and hg.PointShop and hg.PointShop.Items and hg.PointShop.Items[gloveData.ID]
            local pointData = pointItem and pointItem.DATA
            if pointData then
                for subMatIndex, subMatPath in pairs(pointData) do
                    local matIndex = tonumber(subMatIndex)
                    if matIndex ~= nil and isstring(subMatPath) and subMatPath ~= "" then
                        ent:SetSubMaterial(matIndex, subMatPath)
                    end
                end
            end

            local bgValue = gloveData and gloveData[1]
            if bgValue then
                for _, bg in ipairs(ent:GetBodyGroups() or {}) do
                    if string.lower(bg.name or "") == "hands" then
                        for subIndex, subModel in ipairs(bg.submodels or {}) do
                            if subModel == bgValue then
                                ent:SetBodygroup(bg.id, subIndex)
                                break
                            end
                        end
                        break
                    end
                end
            end
        end

        function icon:DoClick()
            if onSelectCallback then onSelectCallback(gloveName) end
            menu:Close()
            surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
        end

        function mdl:DoClick()
            icon:DoClick()
        end

        local lbl = vgui.Create("DLabel", icon)
        lbl:SetPos(0, ScreenScale(50))
        lbl:SetSize(ScreenScale(66), ScreenScale(10))
        lbl:SetFont("ZCity_Tiny")
        lbl:SetText(string.NiceName(gloveName))
        lbl:SetTextColor(colors.mainText)
        lbl:SetContentAlignment(8)
        lbl:SetMouseInputEnabled(false)

        function icon:Think()
            self.bIsHovered = vgui.GetHoveredPanel() == self or vgui.GetHoveredPanel() == mdl
        end

        function icon:Paint(w, h)
            local selected = gloveName == currentSelection
            if selected then selectedIcon = self end
            PaintSelectionIcon(self, w, h, selected, self.bIsHovered)
        end

        grid:AddItem(icon)
    end

    local vbar = scroll:GetVBar()
    function vbar:PaintOver(w, h)
        if not IsValid(selectedIcon) then return end

        local canvas = scroll:GetCanvas()
        if not IsValid(canvas) then return end

        local _, selectedY = selectedIcon:LocalToScreen(0, selectedIcon:GetTall() * 0.5)
        local _, canvasY = canvas:LocalToScreen(0, 0)
        local canvasTall = math.max(canvas:GetTall(), 1)
        local relativePos = math.Clamp((selectedY - canvasY) / canvasTall, 0, 1)
        local markerY = math.floor(relativePos * h)

        draw.RoundedBox(2, 0, math.Clamp(markerY - 2, 0, math.max(h - 4, 0)), w, 4, Color(50, 220, 80, 240))
    end

    function menu:OnClose()
        if IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions.gloves = vbar and vbar:GetScroll() or 0
        end
        if onClose then onClose() end
    end

    return menu
end


local function SyncModelSelectorCombo(panel, modelName)
    if not IsValid(panel) then return end
    if not modelName or modelName == "" then return end

    local function FindCombo(parent)
        if not IsValid(parent) or not parent.GetChildren then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            local className = child.GetClassName and child:GetClassName() or ""
            if className == "DComboBox" then
                return child
            end
            local nested = FindCombo(child)
            if IsValid(nested) then return nested end
        end
    end

    local combo = FindCombo(panel)
    if not IsValid(combo) then return end

    if combo.ChooseOption then
        combo:ChooseOption(modelName)
    end

    if combo.SetValue then
        combo:SetValue(modelName)
    elseif combo.SetText then
        combo:SetText(modelName)
    end
end

local function ModelHasFacemapVariants(modelPath)
    if not modelPath then return false end
    local modelKey = string.lower(modelPath)
    if hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey] then return true end

    local slot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
    if not slot then return false end

    local slotVariants = hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[slot]
    return slotVariants and not table.IsEmpty(slotVariants) or false
end

local function ModelHasFacemapName(modelPath, facemapName)
    if not modelPath or not facemapName or facemapName == "" then return false end
    if facemapName == "Default" then return true end

    local modelKey = string.lower(modelPath)
    local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]
    if multi and multi[facemapName] then return true end

    local slot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
    if not slot then return false end

    local slotVariants = hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[slot]
    return slotVariants and slotVariants[facemapName] ~= nil or false
end

local function QueueDelayedFacemapApply(editTable, modelName, facemapName)
    if not editTable or not modelName or not facemapName then return end

    local timerId = "ZCityAppearanceMod_FacemapApply_" .. string.gsub(tostring(editTable), "[^%w]", "")
    local retries = 10

    timer.Create(timerId, 0.05, retries, function()
        if not editTable then
            timer.Remove(timerId)
            return
        end

        if editTable.AModel ~= modelName then return end

        local modelData = (hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[1] and hg.Appearance.PlayerModels[1][modelName])
            or (hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][modelName])
        local modelPath = modelData and modelData.mdl

        if not ModelHasFacemapName(modelPath, facemapName) then
            timer.Remove(timerId)
            return
        end

        editTable.AFacemap = facemapName
        if editTable.AFacemap == facemapName then
            timer.Remove(timerId)
        end
    end)
end

hg.Appearance.QueueDelayedFacemapApply = QueueDelayedFacemapApply

local function CreateModelIcon(parent, modelName, modelData, appearanceTable, onSelectCallback)
    local pnl = vgui.Create("DButton", parent)
    pnl:SetText("")
    pnl:SetSize(ScreenScale(80), ScreenScale(76))

    local mdl = vgui.Create("DModelPanel", pnl)
    mdl:Dock(FILL)
    mdl:DockMargin(2, 2, 2, 10)
    mdl:SetModel(modelData.mdl)
    EnsurePreviewPanelBounds(mdl)
    mdl:SetAnimated(false)
    function mdl:RunAnimation() end

    local isFemale = modelData.sex == true
    ApplyFacemapCamera(mdl, isFemale)

    local previewAppearance = {
        AClothes = appearanceTable and appearanceTable.AClothes or {},
        AFacemap = "Default"
    }

    function mdl:LayoutEntity(ent)
        if not IsValid(ent) then return end
        FreezePreviewEntity(ent)

        ApplyPreviewAppearance(ent, isFemale and 2 or 1, modelData, previewAppearance)
    end

    function pnl:DoClick()
        if onSelectCallback then onSelectCallback(modelName) end
    end

    function mdl:DoClick()
        pnl:DoClick()
    end

    local lbl = vgui.Create("DLabel", pnl)
    lbl:SetPos(0, ScreenScale(62))
    lbl:SetSize(ScreenScale(80), ScreenScale(10))
    lbl:SetFont("ZCity_Tiny")
    lbl:SetText(modelName)
    lbl:SetTextColor(colors.mainText)
    lbl:SetContentAlignment(8)
    lbl:SetMouseInputEnabled(false)

    function pnl:Think()
        self.bIsHovered = vgui.GetHoveredPanel() == self or vgui.GetHoveredPanel() == mdl
    end

    function pnl:Paint(w, h)
        local selectedModel = appearanceTable and appearanceTable.AModel
        local selected = selectedModel == modelName
        PaintSelectionIcon(self, w, h, selected, self.bIsHovered)
    end

    return pnl
end

function hg.Appearance.OpenModelMenu(parent, currentSelection, onSelectCallback, appearanceTable, onClose)
    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    if not editTable then return end

    local menu = vgui.Create("DFrame")
    menu:SetTitle("Select Model")
    menu:SetSize(ScreenScale(340), ScreenScale(250))

    local x, y
    if parent and IsValid(parent) then
        local parentX, parentY = parent:LocalToScreen(0, 0)
        local parentW = parent:GetWide()
        x = parentX + parentW + ScreenScale(5)
        y = parentY + ScreenScale(24)
        if x + menu:GetWide() > ScrW() then
            x = parentX - menu:GetWide() - ScreenScale(5)
        end
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    else
        x, y = input.GetCursorPos()
        y = y + ScreenScale(24)
        if y + menu:GetTall() > ScrH() then
            y = ScrH() - menu:GetTall() - ScreenScale(5)
        end
    end

    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(true)

    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, clr_menu)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(10), colors.secondary, true, true, false, false)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawLine(0, ScreenScale(10), w, ScreenScale(10))
    end

    local function IsPanelInsideMenu(panelToCheck)
        while IsValid(panelToCheck) do
            if panelToCheck == menu then return true end
            panelToCheck = panelToCheck:GetParent()
        end
        return false
    end

    function menu:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local focusedPanel = vgui.GetKeyboardFocus()
            local hoveredPanel = vgui.GetHoveredPanel()

            if IsPanelInsideMenu(focusedPanel) or IsPanelInsideMenu(hoveredPanel) then return end
            self:Close()
        end)
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))

    if scrollPositions.modelSelector then
        RestoreScrollPositionDelayed(scroll, scrollPositions.modelSelector)
    end

    local content = vgui.Create("DIconLayout", scroll)
    content:Dock(TOP)
    content:SetSpaceX(0)
    content:SetSpaceY(ScreenScale(3))

    local selectedIcon

    local function addSection(title, sexIndex)
        local header = vgui.Create("DLabel", content)
        header:SetSize(menu:GetWide() - ScreenScale(14), ScreenScale(18))
        header:SetFont("ZCity_Small")
        header:SetText(title)
        header:SetTextColor(colors.mainText)

        local grid = vgui.Create("DGrid", content)
        grid:SetCols(MODEL_MENU_PREVIEW_COLS)
        local availableWidth = menu:GetWide() - ScreenScale(14)
        local colWide = math.max(ScreenScale(80), math.floor(availableWidth / MODEL_MENU_PREVIEW_COLS))
        grid:SetColWide(colWide)
        grid:SetRowHeight(ScreenScale(78))
        grid:SetSize(colWide * MODEL_MENU_PREVIEW_COLS, ScreenScale(4))

        local shownCount = 0
        for modelName, modelData in SortedPairs(hg.Appearance.PlayerModels[sexIndex] or {}) do
            if not ModelHasFacemapVariants(modelData and modelData.mdl) then continue end

            local icon = CreateModelIcon(grid, modelName, modelData, editTable, function(selectedModel)
                if onSelectCallback then onSelectCallback(selectedModel) end
                menu:Close()
                surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
            end)
            grid:AddItem(icon)
            if editTable.AModel == modelName then
                selectedIcon = icon
            end
            shownCount = shownCount + 1
        end

        local rows = math.max(1, math.ceil(shownCount / MODEL_MENU_PREVIEW_COLS))
        grid:SetTall(rows * ScreenScale(78))
    end

    addSection("Male", 1)
    addSection("Female", 2)

    local vbar = scroll:GetVBar()
    function vbar:PaintOver(w, h)
        if not IsValid(selectedIcon) then return end

        local canvas = scroll:GetCanvas()
        if not IsValid(canvas) then return end

        local _, selectedY = selectedIcon:LocalToScreen(0, selectedIcon:GetTall() * 0.5)
        local _, canvasY = canvas:LocalToScreen(0, 0)
        local canvasTall = math.max(canvas:GetTall(), 1)
        local relativePos = math.Clamp((selectedY - canvasY) / canvasTall, 0, 1)
        local markerY = math.floor(relativePos * h)

        draw.RoundedBox(2, 0, math.Clamp(markerY - 2, 0, math.max(h - 4, 0)), w, 4, Color(50, 220, 80, 240))
    end

    function menu:OnClose()
        if IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions.modelSelector = vbar and vbar:GetScroll() or 0
        end
        if onClose then onClose() end
    end

    return menu
end

hook.Add("Think", "ZCityAppearanceMod_KeepChosenFacemap", function()
    local editTable = hg.Appearance and hg.Appearance.CurrentEditTable
    if not editTable then return end

    local pending = editTable.__AppearancePendingFacemap
    if not pending or not pending.model or not pending.facemap then return end

    if pending.applyAt and CurTime() < pending.applyAt then return end

    if editTable.AModel ~= pending.model then return end

    local modelData = (hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[1] and hg.Appearance.PlayerModels[1][pending.model])
        or (hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][pending.model])
    local modelPath = modelData and modelData.mdl

    if ModelHasFacemapName(modelPath, pending.facemap) then
        if editTable.AFacemap ~= pending.facemap then
            editTable.AFacemap = pending.facemap
        end
        if editTable.AFacemap == pending.facemap then
            editTable.__AppearancePendingFacemap = nil
            return
        end
    end

    pending.retries = (pending.retries or 1) - 1
    pending.applyAt = CurTime() + 0.05
    if pending.retries <= 0 then
        editTable.__AppearancePendingFacemap = nil
    end
end)











-----------------------------------------------------------------------
-- 3. Перехват создания панели и замена кнопок
-----------------------------------------------------------------------

-- Сохраняем оригинальную функцию
local oldCreateApperanceMenu = hg.CreateApperanceMenu

-- Функция модификации панели: ищем кнопки по тексту и подменяем DoClick
local function ModifyAppearanceMenu(panel)
    if not IsValid(panel) then return end

    -- Таблица соответствия: текст кнопки -> часть тела
    local buttonMap = {
        ["Jacket"]  = "main",
        ["Pants"]   = "pants",
        ["Boots"]   = "boots",
        ["Gloves"]  = "gloves",
        ["Facemap"] = "facemap"
    }

    if not IsValid(panel.ShowcaseBtn) then
        local showcaseBtn = vgui.Create("DButton", panel)
        showcaseBtn:SetText("SHOWCASE")
        showcaseBtn:SetSize(math.floor(ScreenScale(70)), math.floor(ScreenScale(11)))
        ApplyBaseAppearanceButtonStyle(showcaseBtn)
        function showcaseBtn:Think()
            if not IsValid(panel) then return end
            local margin = ScreenScale(6)
            self:SetPos(panel:GetWide() - self:GetWide() - margin, panel:GetTall() - self:GetTall() - margin)
        end
        function showcaseBtn:DoClick()
            hg.Appearance.OpenShowcaseMenu(panel.AppearanceTable)
        end
        panel.ShowcaseBtn = showcaseBtn
    end

    if not IsValid(panel.AllFacemapsBtn) then
        local allFacemapsBtn = vgui.Create("DButton", panel)
        allFacemapsBtn:SetText("ALL FACEMAPS")
        allFacemapsBtn:SetSize(math.floor(ScreenScale(70)), math.floor(ScreenScale(11)))
        ApplyBaseAppearanceButtonStyle(allFacemapsBtn)
        function allFacemapsBtn:Think()
            if not IsValid(panel) then return end
            local spacing = ScreenScale(4)
            local rightButton = panel.ShowcaseBtn
            if not IsValid(rightButton) then return end
            self:SetPos(rightButton:GetX(), rightButton:GetY() - self:GetTall() - spacing)
        end
        function allFacemapsBtn:DoClick()
            if hg.Appearance.OpenAllFacemapsMenu then
                hg.Appearance.OpenAllFacemapsMenu(panel.AppearanceTable)
            end
        end
        panel.AllFacemapsBtn = allFacemapsBtn
    end

    ------------------------------------------------------
    ------------------------------------------------------





    local function FindModelComboBox(parent)
        if not IsValid(parent) or not parent.GetChildren then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            local className = child.GetClassName and child:GetClassName() or ""
            if className == "DComboBox" then
                return child
            end
            local nested = FindModelComboBox(child)
            if IsValid(nested) then return nested end
        end
    end

    if not IsValid(panel.ModelSelectorBtn) then
        local modelBtn = vgui.Create("DButton", panel)
        modelBtn:SetText("MODEL SELECTOR")
        modelBtn:SetSize(math.floor(ScreenScale(85)), math.floor(ScreenScale(15)))
        ApplyBaseAppearanceButtonStyle(modelBtn)

        function modelBtn:Think()
            if not IsValid(panel) then return end

            local modelCombo = FindModelComboBox(panel)
            if IsValid(modelCombo) then
                local comboX, comboY = modelCombo:GetPos()
                self:SetPos(comboX + modelCombo:GetWide() + ScreenScale(4), comboY + ScreenScale(3))
                self:SetTall(modelCombo:GetTall())
            else
                self:SetPos(panel:GetWide() - self:GetWide() - ScreenScale(10), ScreenScale(10))
                self:SetTall(math.floor(ScreenScale(15)))
            end
        end

        function modelBtn:DoClick()
            panel.modelPosID = "All"
            hg.Appearance.OpenModelMenu(self, panel.AppearanceTable and panel.AppearanceTable.AModel, function(modelName)
                if not panel.AppearanceTable then return end
                panel.AppearanceTable.AModel = modelName

                SyncModelSelectorCombo(panel, modelName)
            end, panel.AppearanceTable, function()
                panel.modelPosID = "All"
            end)
        end

        panel.ModelSelectorBtn = modelBtn
    end

    -- Рекурсивно ищем все кнопки внутри панели
    local function FindButtons(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:GetName() == "DButton" or child:GetClassName() == "DButton" then
                local text = child:GetText() or ""
                if buttonMap[text] then
                    -- Запоминаем оригинальный DoClick (на всякий случай)
                    local oldDoClick = child.DoClick
                    local part = buttonMap[text]

                    -- Подменяем метод
                    child.DoClick = function(btn)
                        -- Устанавливаем позицию камеры (как в оригинале)
                        if part == "main" then
                            panel.modelPosID = "Torso"
                        elseif part == "pants" then
                            panel.modelPosID = "Legs"
                        elseif part == "boots" then
                            panel.modelPosID = "Boots"
                        elseif part == "gloves" then
                            panel.modelPosID = "Hands"
                        elseif part == "facemap" then
                            panel.modelPosID = "Face"
                        end

                        -- Определяем текущее значение для этой части
                        local current
                        if part == "main" then
                            current = panel.AppearanceTable.AClothes.main
                        elseif part == "pants" then
                            current = panel.AppearanceTable.AClothes.pants
                        elseif part == "boots" then
                            current = panel.AppearanceTable.AClothes.boots
                        elseif part == "gloves" then
                            -- для gloves нужно брать из ABodygroups
                            current = panel.AppearanceTable.ABodygroups and panel.AppearanceTable.ABodygroups["HANDS"] or "Default"
                        elseif part == "facemap" then
                            current = panel.AppearanceTable.AFacemap or "Default"
                        end

                        -- Колбэк обновления таблицы
                        local function onSelect(id)
                            if part == "main" then
                                panel.AppearanceTable.AClothes.main = id
                            elseif part == "pants" then
                                panel.AppearanceTable.AClothes.pants = id
                            elseif part == "boots" then
                                panel.AppearanceTable.AClothes.boots = id
                            elseif part == "gloves" then
                                if not panel.AppearanceTable.ABodygroups then panel.AppearanceTable.ABodygroups = {} end
                                panel.AppearanceTable.ABodygroups["HANDS"] = id
                            elseif part == "facemap" then
                                panel.AppearanceTable.AFacemap = id
                            end
                        end

                        -- Открываем соответствующее меню
                        if part == "facemap" then
                            hg.Appearance.OpenFacemapMenu(btn, current, onSelect, panel.AppearanceTable, function()
                                panel.modelPosID = "All"
                            end)
                        elseif part == "gloves" then
                            CreateGlovesIconMenu(btn, current, onSelect, panel.AppearanceTable, function()
                                panel.modelPosID = "All"
                            end)
                        else
                            hg.Appearance.OpenClothesMenu(btn, part, current, onSelect, panel.AppearanceTable, function()
                                panel.modelPosID = "All"
                            end)
                        end


                        -- Открываем наше меню
                        --hg.Appearance.OpenClothesMenu(btn, part, current, onSelect, panel.AppearanceTable, function()
                            -- При закрытии меню возвращаем камеру в положение "All"
                            --panel.modelPosID = "All"
                        --end)
                    end
                end
            end
            -- Рекурсивно обходим дочерние панели
            if child.GetChildren then
                FindButtons(child)
            end
        end
    end

    FindButtons(panel)
end

-- Переопределяем функцию создания меню
function hg.CreateApperanceMenu(ParentPanel)
    -- Вызываем оригинал
    oldCreateApperanceMenu(ParentPanel)

    -- Ждём, пока панель появится и отрисуется
    timer.Simple(0.1, function()
        if IsValid(zpan) then
            ModifyAppearanceMenu(zpan)
        end
    end)
end

print("[ZCityAppearanceMod] Is loaded")
