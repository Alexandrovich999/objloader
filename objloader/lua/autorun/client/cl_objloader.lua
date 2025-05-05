




--OBJ LOADER UNFINISHED 4-5-2025 by Alexandrovich
--inverted normals is broken













if SERVER then return end

local spawnedModels = {} 

local function ParseOBJ(path)
    local vertices, uvs, normals, faces = {}, {}, {}, {}

    if not file.Exists(path, "DATA") then
        print("[OBJ Loader] File not found: " .. path)
        return nil
    end

    local lines = string.Explode("\n", file.Read(path, "DATA"))

    for _, line in ipairs(lines) do
        line = string.Trim(line)
        if line ~= "" then
            local parts = string.Explode(" ", line)
            local cmd = parts[1]

            if cmd == "v" then
                table.remove(parts, 1)
                table.insert(vertices, Vector(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])))
            elseif cmd == "vt" then
                table.remove(parts, 1)
                table.insert(uvs, {tonumber(parts[1]), 1 - tonumber(parts[2])})
            elseif cmd == "vn" then
                table.remove(parts, 1)
                table.insert(normals, Vector(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])))

            elseif cmd == "f" then
                table.remove(parts, 1)
                local tri = {}
                for _, part in ipairs(parts) do
                    local v, vt, vn = string.match(part, "(%d+)/?(%d*)/?(%d*)")
                    table.insert(tri, {
                        pos = vertices[tonumber(v)],
                        uv = uvs[tonumber(vt)] or {0, 0},
                        normal = normals[tonumber(vn)] or Vector(0, 0, 1)
                    })
                end
                if #tri == 3 then
                    table.insert(faces, tri)
                elseif #tri == 4 then
                    table.insert(faces, {tri[1], tri[2], tri[3]})
                    table.insert(faces, {tri[1], tri[3], tri[4]})
                end
            end
        end
    end

    return faces
end

local function CalculateMass(faces)
    local baseMass = 50 
    local massPerTriangle = 10 

    local totalMass = baseMass + (massPerTriangle * #faces)
    return totalMass
end

local function SpawnOBJProp(faces, modelID)
    if spawnedModels[modelID] then
        print("[OBJ Loader] Model ID already in use, skipping spawn.")
        return
    end

    local meshData = {}
    local physVerts = {}

    for _, face in ipairs(faces) do
        for i = 1, 3 do
            local vert = face[i]
            table.insert(meshData, {
                pos = vert.pos,
                normal = vert.normal,
                u = vert.uv[1],
                v = vert.uv[2]
            })
            table.insert(physVerts, vert.pos)
        end
    end

    customMaterial = CreateMaterial("objloader_mat_" .. modelID, "VertexLitGeneric", {
        ["$color"] = "1 1 1", 
        ["$model"] = "1",
        ["$vertexalpha"] = "1",
        ["$vertexcolor"] = "1"
    })

    customMesh = Mesh()
    customMesh:BuildFromTriangles(meshData)
    local ply = LocalPlayer()
    local forward = ply:GetForward()
    local eyePos = ply:GetShootPos()
    local eyeAngles = ply:EyeAngles()
    local traceLength = 200
    local traceEnd = eyePos + (eyeAngles:Forward() * traceLength)
    local traceResult = util.TraceLine({
        start = eyePos,
        endpos = traceEnd,
        filter = ply
    })

    local spawnPos = traceResult.HitPos + traceResult.HitNormal * 5

    local spawnedProp = ClientsideModel("models/props_c17/oildrum001.mdl")
    spawnedProp:SetNoDraw(true)
    spawnedProp:SetPos(spawnPos)
    spawnedProp:PhysicsInitConvex(physVerts)
    spawnedProp:SetSolid(SOLID_VPHYSICS)
    spawnedProp:SetMoveType(MOVETYPE_VPHYSICS)
    spawnedProp:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE) 
    spawnedProp:SetMaterial(customMaterial:GetName()) 
    spawnedProp:Spawn()

    local mass = CalculateMass(faces)
    local phys = spawnedProp:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(mass)
        phys:EnableMotion(true)
        phys:Wake()
    end

local mesh = Mesh()
mesh:BuildFromTriangles(meshData)

local material = CreateMaterial("objloader_mat_" .. modelID, "VertexLitGeneric", {
    ["$color"] = "1 1 1", 
    ["$model"] = "1",
    ["$vertexalpha"] = "1",
    ["$vertexcolor"] = "1"
})

local drawHookName = "OBJMeshRenderer_" .. modelID
hook.Add("PostDrawOpaqueRenderables", drawHookName, function()
    if not IsValid(spawnedProp) then return end

    render.SetMaterial(material)
    local m = Matrix()
    m:Translate(spawnedProp:GetPos())
    m:Rotate(spawnedProp:GetAngles())
    cam.PushModelMatrix(m)
    mesh:Draw()
    cam.PopModelMatrix()
end)








spawnedModels[modelID] = {
    entity = spawnedProp,
    mesh = mesh,
    material = material,
        drawHook = drawHookName,
        originalPos = spawnPos,
        originalAng = Angle(0, 0, 0),
        scale = 1
    }

    print("[OBJ Loader] Model spawned with ID: " .. modelID)
end


local function OpenFileBrowser()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("OBJ Files in /garrysmod/data/models")
    frame:SetSize(400, 300)
    frame:Center()
    frame:MakePopup()

    local modelList = vgui.Create("DListView", frame)
    modelList:SetPos(10, 30)
    modelList:SetSize(380, 220)
    modelList:AddColumn("OBJ Files")
    local files = file.Find("models/*.obj", "DATA")
    for _, file in ipairs(files) do
        modelList:AddLine(file)
    end
    modelList.OnRowSelected = function(_, index, line)
        local objFileName = line:GetValue(1)
        local objPath = "models/" .. objFileName
        local modelID = #spawnedModels + 1

        print("[OBJ Loader] Parsing OBJ: " .. objPath)
        local faces = ParseOBJ(objPath)
        if not faces then
            print("[OBJ Loader] Failed to parse OBJ file.")
            return
        end

        print("[OBJ Loader] Parsed " .. #faces .. " triangles.")
        SpawnOBJProp(faces, modelID)
        print("[OBJ Loader] Prop with physics spawned.")

        frame:Close()
    end
end

concommand.Add("load_obj", function()
    OpenFileBrowser()
end)

concommand.Add("clear_obj", function()
    for modelID, modelData in pairs(spawnedModels) do
        if IsValid(modelData.entity) then
            modelData.entity:Remove()
        end
        if modelData.drawHook then
            hook.Remove("PostDrawOpaqueRenderables", modelData.drawHook)
        end
    end

    spawnedModels = {}
    customMesh = nil
    customMaterial = nil
    print("[OBJ Loader] All models have been cleared.")
end)










































if SERVER then return end

local spawnedModels = {}
local modelCounter = 0
local selectedModel = nil
local uiPanel = nil
local scaleEntry = nil

local function ParseOBJ(path)
    local vertices, uvs, normals, faces = {}, {}, {}, {}

    if not file.Exists(path, "DATA") then
        print("[OBJ Loader] File not found: " .. path)
        return nil
    end

    local lines = string.Explode("\n", file.Read(path, "DATA"))

    for _, line in ipairs(lines) do
        line = string.Trim(line)
        if line ~= "" then
            local parts = string.Explode(" ", line)
            local cmd = parts[1]

            if cmd == "v" then
                table.remove(parts, 1)
                table.insert(vertices, Vector(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])))
            elseif cmd == "vt" then
                table.remove(parts, 1)
                table.insert(uvs, {tonumber(parts[1]), 1 - tonumber(parts[2])})
            elseif cmd == "vn" then
                table.remove(parts, 1)
                table.insert(normals, Vector(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])))
            elseif cmd == "f" then
                table.remove(parts, 1)
                local tri = {}
                for _, part in ipairs(parts) do
                    local v, vt, vn = string.match(part, "(%d+)/?(%d*)/?(%d*)")
                    table.insert(tri, {
                        pos = vertices[tonumber(v)],
                        uv = uvs[tonumber(vt)] or {0, 0},
                        normal = normals[tonumber(vn)] or Vector(0, 0, 1)
                    })
                end
                if #tri == 3 then
                    table.insert(faces, tri)
                elseif #tri == 4 then
                    table.insert(faces, {tri[1], tri[2], tri[3]})
                    table.insert(faces, {tri[1], tri[3], tri[4]})
                end
            end
        end
    end

    return faces
end

local function SpawnOBJProp(faces, textureName)
    modelCounter = modelCounter + 1
    local modelID = modelCounter

    local meshData = {}

    for _, face in ipairs(faces) do
        for i = 1, 3 do
            local vert = face[i]
            table.insert(meshData, {
                pos = vert.pos,
                normal = vert.normal,
                u = vert.uv[1],
                v = vert.uv[2]
            })
        end
    end

    local customMaterial = CreateMaterial("objloader_mat_" .. CurTime(), "VertexlitGeneric", {
        ["$basetexture"] = textureName,
        ["$model"] = "1",
        ["$vertexalpha"] = "1",
        ["$vertexcolor"] = "1"
    })

    local customMesh = Mesh()
    customMesh:BuildFromTriangles(meshData)

    local ply = LocalPlayer()
    local forward = ply:GetForward()
    local eyePos = ply:GetShootPos()
    local eyeAngles = ply:EyeAngles()
    local traceLength = 200
    local traceEnd = eyePos + (eyeAngles:Forward() * traceLength)

    local traceResult = util.TraceLine({
        start = eyePos,
        endpos = traceEnd,
        filter = ply
    })

    local spawnPos = traceResult.HitPos + traceResult.HitNormal * 5

    local dummyEnt = ClientsideModel("models/props_c17/oildrum001.mdl")
    dummyEnt:SetNoDraw(true)
    dummyEnt:SetPos(spawnPos)
    dummyEnt:SetAngles(Angle(0, 0, 0))

    local drawHookName = "OBJMeshRenderer_" .. modelID
    hook.Add("PostDrawOpaqueRenderables", drawHookName, function()
        if not IsValid(dummyEnt) or not customMesh then return end

        render.SetMaterial(customMaterial)
        local m = Matrix()
        m:Translate(dummyEnt:GetPos())
        m:Rotate(dummyEnt:GetAngles())
        local scale = spawnedModels[modelID].scale or 1
        m:Scale(Vector(scale, scale, scale))
        cam.PushModelMatrix(m)
        customMesh:Draw()
        cam.PopModelMatrix()
    end)

    spawnedModels[modelID] = {
        id = modelID,
        entity = dummyEnt,
        mesh = customMesh,
        material = customMaterial,
        drawHook = drawHookName,
        originalPos = spawnPos,
        originalAng = Angle(0, 0, 0),
        scale = 1,
        meshData = meshData,
    }

    print("[OBJ Loader] Model spawned with ID: " .. modelID)
end

local function OpenOBJLoaderUI()
    if IsValid(uiPanel) then
        uiPanel:Remove()
    end

    uiPanel = vgui.Create("DFrame")
    uiPanel:SetTitle("OBJ Loader")
    uiPanel:SetSize(700, 438)
    local screenW, screenH = ScrW(), ScrH()
    local panelW, panelH = 700, 438
    uiPanel:SetPos((screenW - panelW) / 2, screenH - panelH - 5)
    uiPanel:MakePopup()
    uiPanel:SetSizable(true)
    uiPanel:SetDraggable(true)

    local modelList = vgui.Create("DListView", uiPanel)
    modelList:SetPos(10, 30)
    modelList:SetSize(200, 400)
    modelList:AddColumn("Model ID")

    for id, modelData in pairs(spawnedModels) do
        modelList:AddLine(id)
    end

    local scaleEntry = vgui.Create("DTextEntry", uiPanel)
    scaleEntry:SetPos(410, 270)
    scaleEntry:SetSize(100, 25)
    scaleEntry:SetText("1")
    scaleEntry.Name = "scaleEntry"
    modelList.OnRowSelected = function(lst, index, pnl)
        local id = tonumber(pnl:GetValue(1))
        selectedModel = spawnedModels[id]
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local ang = selectedModel.entity:GetAngles()
            posX:SetValue(pos.x)
            posY:SetValue(pos.y)
            posZ:SetValue(pos.z)
            angP:SetValue(ang.p)
            angY:SetValue(ang.y)
            angR:SetValue(ang.r)

            scaleEntry:SetValue(tostring(selectedModel.scale or 1))
            print("[OBJ Loader] Model with ID " .. id .. " selected.")
        end
    end





local loadButton = vgui.Create("DButton", uiPanel)
loadButton:SetText("Load OBJ")
loadButton:SetPos(220, 30)
loadButton:SetSize(100, 30)
loadButton.DoClick = function()
    local browserFrame = vgui.Create("DFrame")
    browserFrame:SetTitle("OBJ Files in /garrysmod/data/models")
    browserFrame:SetSize(500, 400)
    browserFrame:Center()
    browserFrame:MakePopup()

    local fileList = vgui.Create("DListView", browserFrame)
    fileList:SetPos(10, 30)
    fileList:SetSize(480, 300)
    fileList:AddColumn("OBJ Files")

    local files = file.Find("models/*.obj", "DATA")
    for _, fileName in ipairs(files) do
        fileList:AddLine(fileName)
    end

    fileList.OnRowSelected = function(lst, index, pnl)
        local fileName = pnl:GetValue(1)
        local objPath = "models/" .. fileName
        local mtlPath = string.sub(objPath, 1, string.len(objPath) - 3) .. "mtl"
        local texture = "models/debug/debugwhite"
        local faces = ParseOBJ(objPath)
        if faces then
            SpawnOBJProp(faces, texture or "models/debug/debugwhite")
            modelList:AddLine(modelCounter)
            browserFrame:Close()
        else
            print("[OBJ Loader] Failed to load selected OBJ file.")
        end
    end
end












    local clearAllButton = vgui.Create("DButton", uiPanel)
    clearAllButton:SetText("Clear All")
    clearAllButton:SetPos(220, 70)
    clearAllButton:SetSize(100, 30)
    clearAllButton.DoClick = function()
        for id, modelData in pairs(spawnedModels) do
            if IsValid(modelData.entity) then
                modelData.entity:Remove()
            end
            if modelData.drawHook then
                hook.Remove("PostDrawOpaqueRenderables", modelData.drawHook)
            end
            spawnedModels[id] = nil
        end
        modelList:Clear()
        print("[OBJ Loader] All models cleared.")
    end

    local removeButton = vgui.Create("DButton", uiPanel)
    removeButton:SetText("Remove Selected")
    removeButton:SetPos(220, 110)
    removeButton:SetSize(100, 30)
    removeButton.DoClick = function()
        local selected = modelList:GetSelectedLine()
        if selected then
            local line = modelList:GetLine(selected)
            local id = tonumber(line:GetValue(1))
            local modelData = spawnedModels[id]
            if modelData then
                if IsValid(modelData.entity) then
                    modelData.entity:Remove()
                end
                if modelData.drawHook then
                    hook.Remove("PostDrawOpaqueRenderables", modelData.drawHook)
                end
                spawnedModels[id] = nil
                modelList:RemoveLine(selected)
                print("[OBJ Loader] Model with ID " .. id .. " removed.")
            end
        end
    end

    local lblX = vgui.Create("DLabel", uiPanel)
    lblX:SetText("X Position:")
    lblX:SetPos(330, 30)
    lblX:SetSize(80, 20)

    local posX = vgui.Create("DTextEntry", uiPanel)
    posX:SetPos(410, 30)
    posX:SetSize(100, 25)
    posX:SetValue("0")
    posX.Name = "posX"

    local btnXPlus = vgui.Create("DButton", uiPanel)
    btnXPlus:SetText("+")
    btnXPlus:SetPos(520, 30)
    btnXPlus:SetSize(20, 25)
    btnXPlus.Name = "btnXPlus"
    local btnXMinus = vgui.Create("DButton", uiPanel)
    btnXMinus:SetText("-")
    btnXMinus:SetPos(380, 30)
    btnXMinus:SetSize(20, 25)
    btnXMinus.Name = "btnXMinus"

    local lblY = vgui.Create("DLabel", uiPanel)
    lblY:SetText("Y Position:")
    lblY:SetPos(330, 70)
    lblY:SetSize(80, 20)

    local posY = vgui.Create("DTextEntry", uiPanel)
    posY:SetPos(410, 70)
    posY:SetSize(100, 25)
    posY:SetValue("0")
    posY.Name = "posY"

    local btnYPlus = vgui.Create("DButton", uiPanel)
    btnYPlus:SetText("+")
    btnYPlus:SetPos(520, 70)
    btnYPlus:SetSize(20, 25)
    btnYPlus.Name = "btnYPlus"
    local btnYMinus = vgui.Create("DButton", uiPanel)
    btnYMinus:SetText("-")
    btnYMinus:SetPos(380, 70)
    btnYMinus:SetSize(20, 25)
    btnYMinus.Name = "btnYMinus"

    local lblZ = vgui.Create("DLabel", uiPanel)
    lblZ:SetText("Z Position:")
    lblZ:SetPos(330, 110)
    lblZ:SetSize(80, 20)

    local posZ = vgui.Create("DTextEntry", uiPanel)
    posZ:SetPos(410, 110)
    posZ:SetSize(100, 25)
    posZ:SetValue("0")
    posZ.Name = "posZ"

    local btnZPlus = vgui.Create("DButton", uiPanel)
    btnZPlus:SetText("+")
    btnZPlus:SetPos(520, 110)
    btnZPlus:SetSize(20, 25)
    btnZPlus.Name = "btnZPlus"
    local btnZMinus = vgui.Create("DButton", uiPanel)
    btnZMinus:SetText("-")
    btnZMinus:SetPos(380, 110)
    btnZMinus:SetSize(20, 25)
    btnZMinus.Name = "btnZMinus"

    local angP = vgui.Create("DNumSlider", uiPanel)
    angP:SetPos(330, 150)
    angP:SetSize(250, 30)
    angP:SetText("Pitch")
    angP:SetMin(-180)
    angP:SetMax(180)
    angP:SetDecimals(2)
    angP.Name = "angP"
    angP.OnValueChanged = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local ang = selectedModel.entity:GetAngles()
            selectedModel.entity:SetAngles(Angle(value, ang.y, ang.r))
        end
    end

    local angY = vgui.Create("DNumSlider", uiPanel)
    angY:SetPos(330, 190)
    angY:SetSize(250, 30)
    angY:SetText("Yaw")
    angY:SetMin(-180)
    angY:SetMax(180)
    angY:SetDecimals(2)
    angY.Name = "angY"
    angY.OnValueChanged = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local ang = selectedModel.entity:GetAngles()
            selectedModel.entity:SetAngles(Angle(ang.p, value, ang.r))
        end
    end

    local angR = vgui.Create("DNumSlider", uiPanel)
    angR:SetPos(330, 230)
    angR:SetSize(250, 30)
    angR:SetText("Roll")
    angR:SetMin(-180)
    angR:SetMax(180)
    angR:SetDecimals(2)
    angR.Name = "angR"
    angR.OnValueChanged = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local ang = selectedModel.entity:GetAngles()
            selectedModel.entity:SetAngles(Angle(ang.p, ang.y, value))
        end
    end

    local resetButton = vgui.Create("DButton", uiPanel)
    resetButton:SetText("Reset Position")
    resetButton:SetPos(220, 150)
    resetButton:SetSize(100, 30)
    resetButton.DoClick = function()
        if selectedModel and IsValid(selectedModel.entity) then
            selectedModel.entity:SetPos(selectedModel.originalPos)
            selectedModel.entity:SetAngles(selectedModel.originalAng)
            posX:SetValue(selectedModel.originalPos.x)
            posY:SetValue(selectedModel.originalPos.y)
            posZ:SetValue(selectedModel.originalPos.z)
            angP:SetValue(selectedModel.originalAng.p)
            angY:SetValue(selectedModel.originalAng.y)
            angR:SetValue(selectedModel.originalAng.r)
            scaleEntry:SetValue(tostring(selectedModel.scale or 1))
            print("[OBJ Loader] Model position and rotation reset.")
        end
    end

    local posChangeValue = 10

    local function updatePosition(axis, delta)
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local newPos = pos
            if axis == "x" then
                newPos = Vector(pos.x + delta, pos.y, pos.z)
                posX:SetValue(newPos.x)
            elseif axis == "y" then
                newPos = Vector(pos.x, pos.y + delta, pos.z)
                posY:SetValue(newPos.y)
            elseif axis == "z" then
                newPos = Vector(pos.x, pos.y, pos.z + delta)
                posZ:SetValue(newPos.z)
            end
            selectedModel.entity:SetPos(newPos)

        end
    end

    local xPlusHeld = false
    local xMinusHeld = false
    local yPlusHeld = false
    local yMinusHeld = false
    local zPlusHeld = false
    local zMinusHeld = false

    local function positionChangeLoop()
        if xPlusHeld then
            updatePosition("x", posChangeValue)
        end
        if xMinusHeld then
            updatePosition("x", -posChangeValue)
        end
        if yPlusHeld then
            updatePosition("y", posChangeValue)
        end
        if yMinusHeld then
            updatePosition("y", -posChangeValue)
        end
        if zPlusHeld then
            updatePosition("z", posChangeValue)
        end
        if zMinusHeld then
            updatePosition("z", -posChangeValue)
        end
    end

    timer.Create("positionChangeLoop", 0.1, 0, positionChangeLoop)

    btnXPlus.OnMousePressed = function()
        xPlusHeld = true
    end
    btnXPlus.OnMouseReleased = function()
        xPlusHeld = false
    end

    btnXMinus.OnMousePressed = function()
        xMinusHeld = true
    end
    btnXMinus.OnMouseReleased = function()
        xMinusHeld = false
    end

    btnYPlus.OnMousePressed = function()
        yPlusHeld = true
    end
    btnYPlus.OnMouseReleased = function()
        yPlusHeld = false
    end

    btnYMinus.OnMousePressed = function()
        yMinusHeld = true
    end
    btnYMinus.OnMouseReleased = function()
        yMinusHeld = false
    end

    btnZPlus.OnMousePressed = function()
        zPlusHeld = true
    end
    btnZPlus.OnMouseReleased = function()
        zPlusHeld = false
    end

    btnZMinus.OnMousePressed = function()
        zMinusHeld = true
    end
    btnZMinus.OnMouseReleased = function()
        zMinusHeld = false
    end

    posX.OnValueChange = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local numValue = tonumber(value)
            if numValue then
                selectedModel.entity:SetPos(Vector(numValue, pos.y, pos.z))
            end
        end
    end

    posY.OnValueChange = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local numValue = tonumber(value)
            if numValue then
                selectedModel.entity:SetPos(Vector(pos.x, numValue, pos.z))
            end
        end
    end

    posZ.OnValueChange = function(self, value)
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local numValue = tonumber(value)
            if numValue then
                selectedModel.entity:SetPos(Vector(pos.x, pos.y, numValue))
            end
        end
    end

    modelList.OnRowSelected = function(lst, index, pnl)
        local id = tonumber(pnl:GetValue(1))
        selectedModel = spawnedModels[id]
        if selectedModel and IsValid(selectedModel.entity) then
            local pos = selectedModel.entity:GetPos()
            local ang = selectedModel.entity:GetAngles()
            posX:SetValue(pos.x)
            posY:SetValue(pos.y)
            posZ:SetValue(pos.z)
            angP:SetValue(ang.p)
            angY:SetValue(ang.y)
            angR:SetValue(ang.r)
            scaleEntry:SetValue(tostring(selectedModel.scale or 1))
            print("[OBJ Loader] Model with ID " .. id .. " selected.")
        end
    end

    local scaleLabel = vgui.Create("DLabel", uiPanel)
    scaleLabel:SetText("Model Scale:")
    scaleLabel:SetPos(330, 270)
    scaleLabel:SetSize(150, 20)

    local scaleEntry = vgui.Create("DTextEntry", uiPanel)
    scaleEntry:SetPos(410, 270)
    scaleEntry:SetSize(100, 25)
    scaleEntry:SetText("1")
    scaleEntry.Name = "scaleEntry"

    scaleEntry.OnEnter = function(self)
        local newScale = tonumber(self:GetValue())
        if selectedModel and IsValid(selectedModel.entity) and newScale then
            selectedModel.scale = newScale
            selectedModel.entity:SetModelScale(Vector(newScale, newScale, newScale))
            print("[OBJ Loader] Scale updated to: " .. newScale)
        end
    end

    local spawnPhysButton = vgui.Create("DButton", uiPanel)
    spawnPhysButton:SetText("Load OBJ - Physics")
    spawnPhysButton:SetPos(330, 310)
    spawnPhysButton:SetSize(150, 30)
    spawnPhysButton.DoClick = function()
        RunConsoleCommand("load_obj")
        print("[OBJ Loader] Triggered 'load_obj' command.")
    end

    local clearPhysButton = vgui.Create("DButton", uiPanel)
    clearPhysButton:SetText("Clear All - Physics")
    clearPhysButton:SetPos(330, 350)
    clearPhysButton:SetSize(150, 30)
    clearPhysButton.DoClick = function()
        RunConsoleCommand("clear_obj")
        print("[OBJ Loader] Triggered 'clear_obj' command.")
    end

    local invertNormalsButton = vgui.Create("DButton", uiPanel)
    invertNormalsButton:SetText("Invert Normals")
    invertNormalsButton:SetPos(220, 190)
    invertNormalsButton:SetSize(100, 30)
    invertNormalsButton.DoClick = function()
        if selectedModel and IsValid(selectedModel.entity) then
            InvertNormals(selectedModel)
        end
    end
end

function InvertNormals(modelData)
    if not modelData or not modelData.meshData then
        print("[OBJ Loader] No model or mesh data to invert normals.")
        return
    end

    for i = 1, #modelData.meshData do
        if modelData.meshData[i] and modelData.meshData[i].normal then
            modelData.meshData[i].normal = -modelData.meshData[i].normal
        end
    end


    local newMesh = Mesh()
    newMesh:BuildFromTriangles(modelData.meshData)
    modelData.mesh = newMesh

    if modelData.drawHook then
        hook.Remove("PostDrawOpaqueRenderables", modelData.drawHook)
    end

    local drawHookName = "OBJMeshRenderer_" .. modelData.id
    modelData.drawHook = drawHookName;
    hook.Add("PostDrawOpaqueRenderables", drawHookName, function()
        if not IsValid(modelData.entity) or not modelData.mesh then return end

        render.SetMaterial(modelData.material)
        local m = Matrix()
        m:Translate(modelData.entity:GetPos())
        m:Rotate(modelData.entity:GetAngles())
        local scale = modelData.scale or 1
        m:Scale(Vector(scale, scale, scale))
        cam.PushModelMatrix(m)
        modelData.mesh:Draw()
        cam.PopModelMatrix()
    end)
    print("[OBJ Loader] Normals inverted and model redrawn for model ID: " .. modelData.id)
end

concommand.Add("open_objloader_ui", OpenOBJLoaderUI)
