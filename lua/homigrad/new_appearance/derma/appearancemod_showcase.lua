if SERVER then return end


hg.Appearance = hg.Appearance or {}

local SHOWCASE_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.showcaseCols) or 15
local FACEMAP_COLS = (hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.allFacemapsCols) or 15

-- увеличенные иконки
local ICON_W = 150
local ICON_H = 310
local FACEMAP_ICON_SIZE = 128
local FACEMAP_ICON_SPACING = 6
local FACEMAP_SECTION_HEADER_PAD = math.floor(FACEMAP_ICON_SIZE * (((hg.Appearance.MenuPerf and hg.Appearance.MenuPerf.allFacemapsHeaderGapFactor) or 0.43)))
local scrollPositions = hg.Appearance.MenuScrollPositions or {}
hg.Appearance.MenuScrollPositions = scrollPositions
local WHITE_PLAYER_COLOR = Vector(1, 1, 1)
local uiColors = {
    panel = Color(15, 15, 20, 250),
    header = Color(25, 25, 35, 195),
    border = Color(100, 100, 120, 200),
    sliderBg = Color(18, 18, 24, 235)
}

local function CreateStyledScrollPanel(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    local sbar = scroll:GetVBar()
    sbar:SetWide(ScreenScale(4))
    sbar:SetHideButtons(true)

    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 30, 200))
        surface.SetDrawColor(uiColors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    function sbar.btnGrip:Paint(w, h)
        local col = self:IsHovered() and Color(100, 100, 130, 255) or Color(70, 70, 90, 255)
        draw.RoundedBox(4, 2, 2, w - 4, h - 4, col)
        surface.SetDrawColor(uiColors.border)
        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
    end

    return scroll
end

local function ForcePreviewPlayerColor(ent)
    if not IsValid(ent) then return end

    if ent.SetPlayerColor then
        ent:SetPlayerColor(WHITE_PLAYER_COLOR)
    end

    if ent.SetNWVector then
        ent:SetNWVector("PlayerColor", WHITE_PLAYER_COLOR)
    end

    ent.GetPlayerColor = ent.GetPlayerColor or function()
        return WHITE_PLAYER_COLOR
    end
end

local function RestoreScrollPositionDelayed(scroll, value)
    if not IsValid(scroll) or value == nil then return end

    local token = "ZCityAppearanceMod_ShowcaseRestore_" .. tostring(scroll)
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
    ent:SetAngles(Angle(0,0,0))

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

local function InstallPreviewFreezeGuard(mdlPanel)
    if not IsValid(mdlPanel) or mdlPanel.__AppearanceFreezeGuardInstalled then return end
    mdlPanel.__AppearanceFreezeGuardInstalled = true

    function mdlPanel:Think()
        local ent = self.Entity
        if not IsValid(ent) then return end
        FreezePreviewEntity(ent)
        ForcePreviewPlayerColor(ent)
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
    InstallPreviewFreezeGuard(mdlPanel)
end

local function ResolveModelDataByName(modelName)
    if not modelName then return nil, nil end
    local male = hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[1] and hg.Appearance.PlayerModels[1][modelName]
    if male then return male, 1 end
    local female = hg.Appearance.PlayerModels and hg.Appearance.PlayerModels[2] and hg.Appearance.PlayerModels[2][modelName]
    if female then return female, 2 end
    return nil, nil
end

local function EnsureValidClothesForModel(appearanceTable, modelData)
    if not appearanceTable or not modelData then return end
    local sexIndex = modelData.sex and 2 or 1
    local clothesBySex = hg.Appearance.Clothes and hg.Appearance.Clothes[sexIndex]
    if not clothesBySex then return end

    appearanceTable.AClothes = appearanceTable.AClothes or {}
    for _, slot in ipairs({"main", "pants", "boots"}) do
        local selected = appearanceTable.AClothes[slot]
        if not selected or not clothesBySex[selected] then
            appearanceTable.AClothes[slot] = clothesBySex.normal and "normal" or next(clothesBySex)
        end
    end
end

local function ResolveBodygroupDefinition(bodygroupName, sexIndex)
    if not bodygroupName then return nil, nil end

    local bodygroups = hg.Appearance.Bodygroups or {}
    local variants = {
        bodygroupName,
        string.lower(bodygroupName),
        string.upper(bodygroupName)
    }

    for _, key in ipairs(variants) do
        local bySex = bodygroups[key] and bodygroups[key][sexIndex]
        if bySex and not table.IsEmpty(bySex) then
            return bySex, key
        end
    end
end

local function ApplySelectedBodygroups(ent, sexIndex, appearanceTable)
    if not IsValid(ent) or not appearanceTable then return end

    local selected = appearanceTable.ABodygroups or {}
    if table.IsEmpty(selected) then return end

    for _, bg in ipairs(ent:GetBodyGroups() or {}) do
        local selectedName = selected[bg.name] or selected[string.lower(bg.name)] or selected[string.upper(bg.name)]
        if not selectedName then continue end

        local bySex = ResolveBodygroupDefinition(bg.name, sexIndex)
        local bgData = bySex and bySex[selectedName]
        if not bgData then continue end

        local pointItem = bgData.ID and hg.PointShop and hg.PointShop.Items and hg.PointShop.Items[bgData.ID]
        local pointData = pointItem and pointItem.DATA
        if pointData then
            for subMatIndex, subMatPath in pairs(pointData) do
                local matIndex = tonumber(subMatIndex)
                if matIndex ~= nil and isstring(subMatPath) and subMatPath ~= "" then
                    ent:SetSubMaterial(matIndex, subMatPath)
                end
            end
        end

        local bgValue = bgData[1]
        if not bgValue then continue end

        local submodels = bg.submodels or {}
        for subIndex = 0, #submodels do
            local subModel = submodels[subIndex]
            if subModel == bgValue then
                ent:SetBodygroup(bg.id, subIndex)
                break
            end
        end
    end
end

local function GetDefaultHandsMaterialBySex(sexIndex)
    return (sexIndex == 2) and "models/humans/female/group01/normal" or "models/humans/male/group01/normal"
end

--[[
local ICON_W = 150
local ICON_H = 260
]]





function hg.Appearance.OpenShowcaseMenu(appearanceTable)

    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetTitle("")
    frame:MakePopup()
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(true)

    -- ЧЁРНЫЙ ФОН
    function frame:Paint(w,h)
        surface.SetDrawColor(0,0,0,255)
        surface.DrawRect(0,0,w,h)
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)

    if scrollPositions.showcase then
        RestoreScrollPositionDelayed(scroll, scrollPositions.showcase)
    end

    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(TOP)
    grid:SetCols(SHOWCASE_COLS)
    grid:SetColWide(ICON_W + 8)
    grid:SetRowHeight(ICON_H + 8) -- было +26

    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    if not editTable then return end

    local modelName = editTable.AModel

    local modelData =
        hg.Appearance.PlayerModels[1][modelName] or
        hg.Appearance.PlayerModels[2][modelName]

    if not modelData then return end

    local modelPath = modelData.mdl
    local sexIndex = modelData.sex and 2 or 1

    local clothes = hg.Appearance.Clothes[sexIndex]
    local facemap = editTable.AFacemap or "Default"

    for clothesID, clothesMat in SortedPairs(clothes) do

        local pnl = vgui.Create("DPanel")
        pnl:SetSize(ICON_W, ICON_H)

        function pnl:Paint(w,h)
            draw.RoundedBox(6,0,0,w,h,Color(20,20,20))
        end

        local mdl = vgui.Create("DModelPanel", pnl)

        mdl:Dock(FILL)
        mdl:SetModel(modelPath)
        EnsurePreviewPanelBounds(mdl)

        mdl:SetAnimated(false)
        mdl:SetAnimSpeed(0)
        function mdl:RunAnimation() end

        ----------------------------------------------------------------
        --                КАМЕРА ИКОНКИ (РЕДАКТИРУЙ ЗДЕСЬ)
        ----------------------------------------------------------------

        -- Если модель слишком маленькая / большая — меняй значения
        -- CamPos = расстояние камеры
        -- LookAt = точка куда камера смотрит
        -- FOV = масштаб
        ----------------------------------------------------------------


        mdl:SetFOV(16)                      -- масштаб модели
        mdl:SetCamPos(Vector(120,0,38))      -- позиция камеры
        mdl:SetLookAt(Vector(0,0,30))       -- центр взгляда


        --[[
        mdl:SetFOV(28)                      -- масштаб модели
        mdl:SetCamPos(Vector(75,0,60))      -- позиция камеры
        mdl:SetLookAt(Vector(0,0,55))       -- центр взгляда
        ]]
        ----------------------------------------------------------------
        --   ЭТИ 3 ПАРАМЕТРА ТЫ БУДЕШЬ ПОДГОНЯТЬ ПОД СВОИ МОДЕЛИ
        ----------------------------------------------------------------

        function mdl:LayoutEntity(ent)
            if not IsValid(ent) then return end
            FreezePreviewEntity(ent)
            ForcePreviewPlayerColor(ent)

            if ent.__AppearanceFrozenShowcase then return end

            local mats = ent:GetMaterials()

            local slots = modelData.submatSlots

            local function Apply(slot, texture)

                local matName = slots[slot]
                if not matName then return end

                for i,mat in ipairs(mats) do
                    if mat == matName then
                        ent:SetSubMaterial(i-1, texture)
                        break
                    end
                end

            end

            Apply("main", clothesMat)
            Apply("pants", clothesMat)
            Apply("boots", clothesMat)
            Apply("hands", GetDefaultHandsMaterialBySex(sexIndex))

            if facemap ~= "Default" then

                for i = 1,#mats do
                    local mat = mats[i]

                    if hg.Appearance.FacemapsSlots[mat]
                    and hg.Appearance.FacemapsSlots[mat][facemap] then

                        ent:SetSubMaterial(
                            i-1,
                            hg.Appearance.FacemapsSlots[mat][facemap]
                        )

                    end
                end

            end

            ApplySelectedBodygroups(ent, sexIndex, editTable)
            ent.__AppearanceFrozenShowcase = true

        end

        local label = vgui.Create("DLabel", pnl)
        label:Dock(BOTTOM)
        label:SetTall(20)
        label:SetText(clothesID)
        label:SetContentAlignment(5)
        label:SetTextColor(Color(255,255,255))

        local function ApplyShowcaseChoice()
            if not editTable then return end
            editTable.AClothes = editTable.AClothes or {}
            editTable.AClothes.main = clothesID
            editTable.AClothes.pants = clothesID
            editTable.AClothes.boots = clothesID
            surface.PlaySound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav")
            frame:Close()
        end

        function pnl:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            ApplyShowcaseChoice()
        end

        function mdl:DoClick()
            ApplyShowcaseChoice()
        end

        label:SetMouseInputEnabled(true)
        function label:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            ApplyShowcaseChoice()
        end

        grid:AddItem(pnl)

    end

    function frame:OnClose()
        if IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions.showcase = vbar and vbar:GetScroll() or 0
        end
    end

end





local function GetFacemapVariantsForModel(modelPath)
    local combinedVariants = {}
    if not modelPath then return combinedVariants end

    local modelKey = string.lower(modelPath)
    local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]

    if multi then
        return table.Copy(multi)
    end

    local modelSlots = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
    if not modelSlots then
        return combinedVariants
    end

    local slotVariants = hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[modelSlots]
    if not slotVariants then
        return combinedVariants
    end

    for varName, texturePath in pairs(slotVariants) do
        combinedVariants[varName] = {
            [modelSlots] = texturePath
        }
    end

    return combinedVariants
end

local function ApplyFacemapCameraBySex(mdl, isFemale)
    if not IsValid(mdl) then return end

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
        mdl:SetCamPos(femaleCamPos)
        mdl:SetLookAt(femaleLookAt)
        mdl:SetFOV(femaleFOV)
    else
        mdl:SetCamPos(maleCamPos)
        mdl:SetLookAt(maleLookAt)
        mdl:SetFOV(maleFOV)
    end
end

function hg.Appearance.OpenAllFacemapsMenu(appearanceTable)
    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    if not editTable then return end

    local currentModelData = ResolveModelDataByName(editTable.AModel)
    EnsureValidClothesForModel(editTable, currentModelData)

    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetTitle("")
    frame:MakePopup()
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(true)

    function frame:Paint(w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)

    if scrollPositions.allFacemaps then
        RestoreScrollPositionDelayed(scroll, scrollPositions.allFacemaps)
    end

    local content = vgui.Create("DIconLayout", scroll)
    content:Dock(TOP)
    content:SetSpaceY(8)

    local iconSize = FACEMAP_ICON_SIZE
    local iconSpacing = FACEMAP_ICON_SPACING
    local clothesSelection = editTable.AClothes or {}

    local function CreateFacemapPreviewIcon(parent, modelData, variants, varName, modelName)
        local iconPanel = vgui.Create("DPanel", parent)
        iconPanel:SetSize(iconSize, iconSize + 18)

        function iconPanel:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 20, 20, 245))
            surface.SetDrawColor(70, 70, 90, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local mdl = vgui.Create("DModelPanel", iconPanel)
        mdl:SetPos(2, 2)
        mdl:SetSize(iconSize - 4, iconSize - 4)
        mdl:SetModel(modelData.mdl)
        EnsurePreviewPanelBounds(mdl)
        mdl:SetAnimated(false)
        mdl:SetAnimSpeed(0)
        function mdl:RunAnimation() end
        ApplyFacemapCameraBySex(mdl, modelData.sex and true or false)
        mdl:SetDirectionalLight(BOX_RIGHT, Color(255, 0, 0))
        mdl:SetDirectionalLight(BOX_LEFT, Color(125, 155, 255))
        mdl:SetDirectionalLight(BOX_FRONT, Color(160, 160, 160))
        mdl:SetDirectionalLight(BOX_BACK, Color(0, 0, 0))
        mdl:SetAmbientLight(Color(50, 50, 50))

        function mdl:LayoutEntity(ent)
            if not IsValid(ent) then return end
            FreezePreviewEntity(ent)
            ForcePreviewPlayerColor(ent)

            if ent.__AppearanceFrozenFacemapAll and ent.__AppearanceFrozenFacemapAll == varName then return end

            local mats = ent:GetMaterials()
            local slots = modelData.submatSlots or {}
            local clothesTable = hg.Appearance.Clothes[modelData.sex and 2 or 1] or {}

            local function ApplyBySlot(slotName, clothesId)
                local matName = slots[slotName]
                if not matName then return end

                local texturePath = clothesTable[clothesId or ""] or clothesTable.normal or ""
                for i, mat in ipairs(mats) do
                    if mat == matName then
                        ent:SetSubMaterial(i - 1, texturePath)
                        break
                    end
                end
            end

            ApplyBySlot("main", clothesSelection.main)
            ApplyBySlot("pants", clothesSelection.pants)
            ApplyBySlot("boots", clothesSelection.boots)

            local slotMap = variants[varName] or {}
            for slotMaterial, texturePath in pairs(slotMap) do
                for i, matName in ipairs(mats) do
                    if matName == slotMaterial then
                        ent:SetSubMaterial(i - 1, texturePath)
                        break
                    end
                end
            end

            ent:SetColor(Color(255, 255, 255))
            ent.__AppearanceFrozenFacemapAll = varName
        end

        function iconPanel:OnMouseWheeled(delta)
            if IsValid(scroll) then
                scroll:OnMouseWheeled(delta)
                return true
            end
        end

        function mdl:OnMouseWheeled(delta)
            if IsValid(scroll) then
                scroll:OnMouseWheeled(delta)
                return true
            end
        end

        local label = vgui.Create("DLabel", iconPanel)
        label:Dock(BOTTOM)
        label:SetTall(16)
        label:SetText(varName)
        label:SetFont("ZCity_Tiny")
        label:SetContentAlignment(5)
        label:SetTextColor(Color(255, 255, 255))

        local function ApplyFacemapChoice()
            if not editTable then return end

            editTable.AModel = modelName
            editTable.AFacemap = varName
            if hg.Appearance.QueueDelayedFacemapApply then
                hg.Appearance.QueueDelayedFacemapApply(editTable, modelName, varName)
            else
                timer.Simple(0.05, function()
                    if not editTable then return end
                    if editTable.AModel ~= modelName then return end
                    editTable.AFacemap = varName
                end)
            end
            EnsureValidClothesForModel(editTable, modelData)

            surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
            frame:Close()
        end

        function iconPanel:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            ApplyFacemapChoice()
        end

        function mdl:DoClick()
            ApplyFacemapChoice()
        end

        label:SetMouseInputEnabled(true)
        function label:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            ApplyFacemapChoice()
        end

        return iconPanel
    end

    local function BuildModelSection(modelName, modelData)
        if not modelData or not modelData.mdl then return end

        local variants = GetFacemapVariantsForModel(modelData.mdl)
        if table.IsEmpty(variants) then return end

        local sortedNames = table.GetKeys(variants)
        table.sort(sortedNames)

        local section = vgui.Create("DPanel")
        local rowsCount = math.max(math.ceil(#sortedNames / FACEMAP_COLS), 1)
        local rowHeight = iconSize + 18 + iconSpacing
        section:SetSize(math.max(ScrW() - 24, 300), FACEMAP_SECTION_HEADER_PAD + (rowsCount * rowHeight) + 12)

        function section:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(12, 12, 16, 235))
            surface.SetDrawColor(70, 70, 90, 200)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(modelName, "ZCity_Small", 8, 7, Color(230, 230, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local row = vgui.Create("DGrid", section)
        row:SetPos(6, FACEMAP_SECTION_HEADER_PAD)
        row:SetCols(FACEMAP_COLS)
        row:SetColWide(iconSize + iconSpacing)
        row:SetRowHeight(iconSize + 18 + iconSpacing)

        function section:Think()
            if not IsValid(scroll) then return end
            local targetW = math.max(scroll:GetWide() - 10, 300)
            if self:GetWide() ~= targetW then
                self:SetWide(targetW)
            end
        end

        for _, varName in ipairs(sortedNames) do
            local icon = CreateFacemapPreviewIcon(section, modelData, variants, varName, modelName)
            row:AddItem(icon)
        end

        content:Add(section)
    end

    for _, sex in ipairs({1, 2}) do
        for modelName, modelData in SortedPairs(hg.Appearance.PlayerModels[sex] or {}) do
            BuildModelSection(modelName, modelData)
        end
    end

    function frame:OnClose()
        if IsValid(scroll) then
            local vbar = scroll:GetVBar()
            scrollPositions.allFacemaps = vbar and vbar:GetScroll() or 0
        end
    end
end

function hg.Appearance.OpenBodygroupsShowcaseMenu(appearanceTable)
    local editTable = appearanceTable or hg.Appearance.CurrentEditTable
    if not editTable then return end

    local modelData = ResolveModelDataByName(editTable.AModel)
    if not modelData then return end

    EnsureValidClothesForModel(editTable, modelData)
    editTable.ABodygroups = editTable.ABodygroups or {}

    local sexIndex = modelData.sex and 2 or 1

    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(ScrW() - 40, 1080), math.min(ScrH() - 40, 680))
    frame:SetTitle("Bodygroups")
    frame:MakePopup()
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(true)

    function frame:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, uiColors.panel)
        surface.SetDrawColor(uiColors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(10), uiColors.header, true, true, false, false)
        surface.SetDrawColor(uiColors.border)
        surface.DrawLine(0, ScreenScale(10), w, ScreenScale(10))
    end

    local viewport = vgui.Create("DPanel", frame)
    viewport:Dock(LEFT)
    viewport:DockMargin(8, 28, 6, 8)
    viewport:SetWide(math.floor(frame:GetWide() * 0.56))
    function viewport:Paint(w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(10, 10, 14, 255))
        surface.SetDrawColor(uiColors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local modelPreview = vgui.Create("DModelPanel", viewport)
    modelPreview:Dock(FILL)
    modelPreview:DockMargin(8, 8, 8, 8)
    modelPreview:SetModel(modelData.mdl)
    modelPreview:SetCamPos(Vector(220, -45, 60))
    modelPreview:SetLookAt(Vector(0, 0, 38))
    modelPreview:SetFOV(24)
    modelPreview:SetAnimated(false)
    EnsurePreviewPanelBounds(modelPreview)
    function modelPreview:RunAnimation() end

    function modelPreview:LayoutEntity(ent)
        if not IsValid(ent) then return end
        FreezePreviewEntity(ent)
        ForcePreviewPlayerColor(ent)

        local mats = ent:GetMaterials()
        local clothes = hg.Appearance.Clothes[sexIndex] or {}
        local selectedClothes = editTable.AClothes or {}
        for slot, matName in pairs(modelData.submatSlots or {}) do
            local texturePath
            if slot == "hands" then
                texturePath = (sexIndex == 2) and "models/humans/female/group01/normal" or "models/humans/male/group01/normal"
            else
                local selectedClothesId = selectedClothes[slot] or "normal"
                texturePath = clothes[selectedClothesId] or clothes.normal
            end

            if texturePath then
                for i, mat in ipairs(mats) do
                    if mat == matName then
                        ent:SetSubMaterial(i - 1, texturePath)
                        break
                    end
                end
            end
        end

        local facemap = editTable.AFacemap
        if facemap and facemap ~= "Default" then
            local modelKey = string.lower(modelData.mdl or "")
            local facemapSlots = {}
            local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]
            if multi and multi[facemap] then
                facemapSlots = multi[facemap]
            else
                local slot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
                local slotVariants = slot and hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[slot]
                if slotVariants and slotVariants[facemap] then
                    facemapSlots[slot] = slotVariants[facemap]
                end
            end

            for slotName, texturePath in pairs(facemapSlots) do
                for i, matName in ipairs(mats) do
                    if matName == slotName then
                        ent:SetSubMaterial(i - 1, texturePath)
                        break
                    end
                end
            end
        end

        ApplySelectedBodygroups(ent, sexIndex, editTable)
    end

    local function IsPanelInsideFrame(panelToCheck)
        while IsValid(panelToCheck) do
            if panelToCheck == frame then return true end
            panelToCheck = panelToCheck:GetParent()
        end
        return false
    end

    function frame:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end
            local focusedPanel = vgui.GetKeyboardFocus()
            local hoveredPanel = vgui.GetHoveredPanel()
            if IsPanelInsideFrame(focusedPanel) or IsPanelInsideFrame(hoveredPanel) then return end
            self:Close()
        end)
    end

    local controlsScroll = CreateStyledScrollPanel(frame)
    controlsScroll:Dock(FILL)
    controlsScroll:DockMargin(6, 28, 8, 8)

    local controlsList = vgui.Create("DListLayout", controlsScroll)
    controlsList:Dock(TOP)

    local header = vgui.Create("DLabel", controlsList)
    header:SetFont("ZCity_Small")
    header:SetText("BODYGROUPS")
    header:SetTextColor(color_white)
    header:SetTall(24)
    header:DockMargin(2, 0, 2, 4)
    controlsList:Add(header)

    local previewEntity
    timer.Simple(0, function()
        if IsValid(modelPreview) then
            previewEntity = modelPreview.Entity
        end
    end)

    local function AddBodygroupSlider(bgData)
        local bgName = bgData and bgData.name
        if not bgName then return end
        local slider = vgui.Create("DNumSlider")
        slider:Dock(TOP)
        slider:DockMargin(0, 0, 0, 4)
        slider:SetText(string.NiceName(bgName))
        slider:SetMin(0)
        slider:SetMax(math.max((bgData.num or 1) - 1, 0))
        slider:SetDecimals(0)
        slider:SetDark(true)
        if IsValid(slider.Label) then
            slider.Label:SetTextColor(color_white)
        end
        if IsValid(slider.TextArea) then
            slider.TextArea:SetTextColor(color_white)
        end

        slider.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, uiColors.sliderBg)
            surface.SetDrawColor(uiColors.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local selectedVariant = editTable.ABodygroups[bgName] or editTable.ABodygroups[string.lower(bgName)] or editTable.ABodygroups[string.upper(bgName)]
        local bodygroupOptions = ResolveBodygroupDefinition(bgName, sexIndex)
        if bodygroupOptions and selectedVariant and bodygroupOptions[selectedVariant] then
            local selectedSubmodel = bodygroupOptions[selectedVariant][1]
            local submodels = bgData.submodels or {}
            for idx = 0, #submodels do
                local submodelName = submodels[idx]
                if submodelName == selectedSubmodel then
                    slider:SetValue(idx)
                    break
                end
            end
        else
            slider:SetValue(0)
        end

        function slider:OnValueChanged(value)
            if not IsValid(previewEntity) then
                previewEntity = IsValid(modelPreview) and modelPreview.Entity or nil
            end

            local newValue = math.Round(value)
            if IsValid(previewEntity) then
                previewEntity:SetBodygroup(bgData.id, newValue)
            end

            local subModelName = bgData.submodels and bgData.submodels[newValue]
            if not subModelName then return end

            local optionsByName, resolvedKey = ResolveBodygroupDefinition(bgName, sexIndex)
            if not optionsByName then return end

            for variantName, variantData in pairs(optionsByName) do
                if variantData and variantData[1] == subModelName then
                    local key = resolvedKey or bgName
                    editTable.ABodygroups[key] = variantName
                    if key ~= bgName then
                        editTable.ABodygroups[bgName] = variantName
                    end
                    break
                end
            end
        end

        controlsList:Add(slider)
    end

    timer.Simple(0, function()
        if not IsValid(modelPreview) then return end
        local ent = modelPreview.Entity
        if not IsValid(ent) then return end

        for _, bg in ipairs(ent:GetBodyGroups() or {}) do
            AddBodygroupSlider(bg)
        end
    end)
end

hook.Add("Think","Appearance_ShowcaseHook",function()

    if hg.Appearance.ShowcaseHooked then return end

    if not vgui or not vgui.GetWorldPanel then return end

    for _,panel in ipairs(vgui.GetWorldPanel():GetChildren()) do

        if panel:GetClassName() == "DFrame" then

            for _,child in ipairs(panel:GetChildren()) do

                if child:GetClassName() == "DButton"
                and child:GetText() == "Facemap" then

                    hg.Appearance.ShowcaseHooked = true

                    local oldClick = child.DoClick

                    function child:DoClick()

                        if input.IsKeyDown(KEY_LSHIFT) then
                            hg.Appearance.OpenShowcaseMenu()
                            return
                        end

                        if oldClick then
                            oldClick(self)
                        end

                    end

                end

            end

        end

    end

end)
