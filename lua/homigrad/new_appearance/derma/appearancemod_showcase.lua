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

        mdl:SetAnimated(false)
        mdl:SetAnimSpeed(0)

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
            ent:SetAngles(Angle(0,0,0))
            ent:SetSequence(ent:LookupSequence("idle_suitcase"))
            ent:SetCycle(0)
            ent:SetPlaybackRate(0)
            ent.AutomaticFrameAdvance = false

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
            Apply("hands", "models/humans/male/group01/normal")

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

            ent.__AppearanceFrozenShowcase = true

        end

        local label = vgui.Create("DLabel", pnl)
        label:Dock(BOTTOM)
        label:SetTall(20)
        label:SetText(clothesID)
        label:SetContentAlignment(5)
        label:SetTextColor(Color(255,255,255))

        function pnl:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            if not editTable then return end
            editTable.AClothes = editTable.AClothes or {}
            editTable.AClothes.main = clothesID
            editTable.AClothes.pants = clothesID
            editTable.AClothes.boots = clothesID
            surface.PlaySound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav")
            frame:Close()
        end

        grid:AddItem(pnl)

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
        mdl:SetAnimated(false)
        mdl:SetAnimSpeed(0)
        ApplyFacemapCameraBySex(mdl, modelData.sex and true or false)
        mdl:SetDirectionalLight(BOX_RIGHT, Color(255, 0, 0))
        mdl:SetDirectionalLight(BOX_LEFT, Color(125, 155, 255))
        mdl:SetDirectionalLight(BOX_FRONT, Color(160, 160, 160))
        mdl:SetDirectionalLight(BOX_BACK, Color(0, 0, 0))
        mdl:SetAmbientLight(Color(50, 50, 50))

        function mdl:LayoutEntity(ent)
            if not IsValid(ent) then return end
            ent:SetAngles(Angle(0, 0, 0))
            ent:SetSequence(ent:LookupSequence("idle_suitcase"))
            ent:SetCycle(0)
            ent:SetPlaybackRate(0)
            ent.AutomaticFrameAdvance = false

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

        function iconPanel:OnMousePressed(mouseCode)
            if mouseCode ~= MOUSE_LEFT then return end
            if not editTable then return end

            editTable.AModel = modelName
            editTable.AFacemap = varName
            EnsureValidClothesForModel(editTable, modelData)

            surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
            frame:Close()
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
