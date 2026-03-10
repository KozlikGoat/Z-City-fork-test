if SERVER then return end


hg.Appearance = hg.Appearance or {}

local SHOWCASE_COLS = 15

-- увеличенные иконки
local ICON_W = 150
local ICON_H = 310

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

    -- ЧЁРНЫЙ ФОН (как ты хотел)
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

            ent:SetAngles(Angle(0,0,0))
            ent:SetSequence(ent:LookupSequence("idle_suitcase"))

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

        end

        local label = vgui.Create("DLabel", pnl)
        label:Dock(BOTTOM)
        label:SetTall(20)
        label:SetText(clothesID)
        label:SetContentAlignment(5)
        label:SetTextColor(Color(255,255,255))

        grid:AddItem(pnl)

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