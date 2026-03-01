--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║         Switch Hub - Bounty Hunting Ultimate V10          ║
    ║                    By: tbobiito                           ║
    ╚═══════════════════════════════════════════════════════════╝
    V10 FIX:
    ✅ Spam skill KHÔNG bị rớt - tách riêng luồng skill khỏi bay
    ✅ Tự equip Melee và Sword đúng loại, chuyển qua lại 3s/lần
    ✅ Bám sát target liên tục trong khi spam skill
    ✅ Timer 60s chỉ bắt đầu đếm KHI ĐÃ ĐẾN GẦN target
    ✅ Chuyển target ngay khi safe zone / kill xong
    ✅ Noclip bật tự động khi load
    ✅ SPAM HOP liên tục khi hết player
]]

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer
repeat task.wait() until game.Players.LocalPlayer.Character

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportSvc = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RS          = game:GetService("ReplicatedStorage")
local VIM         = game:GetService("VirtualInputManager")

local lp   = Players.LocalPlayer
local pGui = lp:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════
local CFG = {
    AttackDist    = 10,
    FlySpeed      = 350,
    MaxHuntTime   = 60,
    SkillKeys     = {
        Melee = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V},
        Sword = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C},
    },
    SkipList      = {},
    JoinedServers = {},
    SafeHP        = 500,
    MaxHP         = 2000,
    -- Hop server ưu tiên server có số người này
    MinHopPlayers = 9,
    MaxHopPlayers = 16,
}

-- ══════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════
local ST = {
    On            = true,
    Noclip        = true,
    Target        = nil,
    HuntStart     = nil,   -- nil = chưa bắt đầu, chỉ set khi Arrived lần đầu
    Flying        = false,
    InSafe        = false,
    Arrived       = false,
    WeaponPhase   = "Melee",
    PhaseTimer    = tick(),
    CurrentTween  = nil,
}

-- ══════════════════════════════════════════════
-- CHARACTER
-- ══════════════════════════════════════════════
local Char, Hum, HRP

local function RefreshChar()
    Char = lp.Character
    if not Char then return end
    Hum  = Char:FindFirstChildOfClass("Humanoid")
    HRP  = Char:FindFirstChild("HumanoidRootPart")
end
RefreshChar()

-- Forward declare các hàm dùng trước khi define
local FindTarget, SetTarget, StopFly

lp.CharacterAdded:Connect(function(c)
    Char = c
    Hum  = c:WaitForChild("Humanoid")
    HRP  = c:WaitForChild("HumanoidRootPart")
    ST.Target  = nil
    ST.Flying  = false
    ST.Arrived = false
    ST.InSafe  = false
    task.wait(2)
    if ST.On then
        local t = FindTarget()
        if t then SetTarget(t) end
    end
end)

-- ══════════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════════
pcall(function()
    local o = game:GetService("CoreGui"):FindFirstChild("SwitchHubUI")
    if o then o:Destroy() end
end)
pcall(function()
    local o = pGui:FindFirstChild("SwitchHubUI")
    if o then o:Destroy() end
end)

local SG = Instance.new("ScreenGui")
SG.Name = "SwitchHubUI"; SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 999; SG.IgnoreGuiInset = true
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent or SG.Parent == game then SG.Parent = pGui end

local BgImg = Instance.new("ImageLabel", SG)
BgImg.Size = UDim2.fromScale(1,1); BgImg.Position = UDim2.fromScale(0,0)
BgImg.BackgroundTransparency = 1; BgImg.Image = "rbxassetid://16060333448"
BgImg.ImageTransparency = 0.5; BgImg.ScaleType = Enum.ScaleType.Stretch; BgImg.ZIndex = 1

local TitleLbl = Instance.new("TextLabel", SG)
TitleLbl.Size = UDim2.new(1,0,0,180)
TitleLbl.Position = UDim2.new(0,0,0.5,-220)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "Switch Hub"
TitleLbl.TextColor3 = Color3.fromRGB(80,200,255)
TitleLbl.TextScaled = true
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextStrokeTransparency = 0
TitleLbl.TextStrokeColor3 = Color3.fromRGB(255,255,255)
TitleLbl.ZIndex = 5

local SubLbl = Instance.new("TextLabel", SG)
SubLbl.Size = UDim2.new(1,0,0,44); SubLbl.Position = UDim2.new(0,0,0.5,-38)
SubLbl.BackgroundTransparency = 1
SubLbl.Text = "Kill ALL  •  350 Speed  •  Spam Hop  •  Noclip AUTO"
SubLbl.TextColor3 = Color3.fromRGB(220,220,220); SubLbl.TextScaled = true
SubLbl.Font = Enum.Font.Gotham; SubLbl.TextStrokeTransparency = 0.3
SubLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); SubLbl.ZIndex = 5

local TargetLbl = Instance.new("TextLabel", SG)
TargetLbl.Size = UDim2.new(1,0,0,40); TargetLbl.Position = UDim2.new(0,0,0.5,14)
TargetLbl.BackgroundTransparency = 1; TargetLbl.Text = "🎯  Searching..."
TargetLbl.TextColor3 = Color3.fromRGB(255,255,255); TargetLbl.TextScaled = true
TargetLbl.Font = Enum.Font.Gotham; TargetLbl.TextStrokeTransparency = 0.3
TargetLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); TargetLbl.ZIndex = 5

local StatusLbl = Instance.new("TextLabel", SG)
StatusLbl.Size = UDim2.new(1,0,0,36); StatusLbl.Position = UDim2.new(0,0,0.5,60)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Text = "⚡  Starting..."
StatusLbl.TextColor3 = Color3.fromRGB(100,255,100); StatusLbl.TextScaled = true
StatusLbl.Font = Enum.Font.Gotham; StatusLbl.TextStrokeTransparency = 0.3
StatusLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); StatusLbl.ZIndex = 5

local TimerLbl = Instance.new("TextLabel", SG)
TimerLbl.Size = UDim2.new(1,0,0,30); TimerLbl.Position = UDim2.new(0,0,0.5,100)
TimerLbl.BackgroundTransparency = 1; TimerLbl.Text = ""
TimerLbl.TextColor3 = Color3.fromRGB(255,200,50); TimerLbl.TextScaled = true
TimerLbl.Font = Enum.Font.Gotham; TimerLbl.TextStrokeTransparency = 0.3
TimerLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0); TimerLbl.ZIndex = 5

local SkipBtn = Instance.new("TextButton", SG)
SkipBtn.Size = UDim2.fromOffset(150,55); SkipBtn.Position = UDim2.new(1,-160,0,15)
SkipBtn.BackgroundColor3 = Color3.fromRGB(255,255,255); SkipBtn.BorderSizePixel = 0
SkipBtn.Text = "⏭  Skip"; SkipBtn.TextColor3 = Color3.fromRGB(0,0,0)
SkipBtn.TextSize = 22; SkipBtn.Font = Enum.Font.GothamBold; SkipBtn.ZIndex = 10
Instance.new("UICorner", SkipBtn).CornerRadius = UDim.new(0,14)

local ToggleBtn = Instance.new("TextButton", SG)
ToggleBtn.Size = UDim2.fromOffset(150,55); ToggleBtn.Position = UDim2.new(1,-160,0,80)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40,200,90); ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "✅  ON"; ToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
ToggleBtn.TextSize = 22; ToggleBtn.Font = Enum.Font.GothamBold; ToggleBtn.ZIndex = 10
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0,14)

-- Noclip button (bên trái màn hình)
local NoclipBtn = Instance.new("TextButton", SG)
NoclipBtn.Size = UDim2.fromOffset(150,55); NoclipBtn.Position = UDim2.new(0,10,0,15)
NoclipBtn.BackgroundColor3 = Color3.fromRGB(80,80,80); NoclipBtn.BorderSizePixel = 0
NoclipBtn.Text = "🧱  Noclip OFF"; NoclipBtn.TextColor3 = Color3.fromRGB(255,255,255)
NoclipBtn.TextSize = 18; NoclipBtn.Font = Enum.Font.GothamBold; NoclipBtn.ZIndex = 10
Instance.new("UICorner", NoclipBtn).CornerRadius = UDim.new(0,14)

-- ══════════════════════════════════════════════
-- ATTACK REMOTE
-- ══════════════════════════════════════════════
local u4, u5 = nil, nil
local function FindBypassRemote()
    local folders = {}
    for _,name in ipairs({"Util","Common","Remotes","Assets","FX"}) do
        local f = RS:FindFirstChild(name)
        if f then table.insert(folders, f) end
    end
    for _, folder in pairs(folders) do
        for _, child in pairs(folder:GetChildren()) do
            if child and child:IsA("RemoteEvent") and child:GetAttribute("Id") then
                u5 = child:GetAttribute("Id"); u4 = child
            end
        end
        pcall(function()
            folder.ChildAdded:Connect(function(c)
                if c:IsA("RemoteEvent") and c:GetAttribute("Id") then
                    u5 = c:GetAttribute("Id"); u4 = c
                end
            end)
        end)
    end
end
FindBypassRemote()

local function GetAttackTargets()
    if not HRP then return {} end
    local list = {}
    local function scan(folder)
        if not folder then return end
        for _, char in pairs(folder:GetChildren()) do
            local root  = char:FindFirstChild("HumanoidRootPart")
            local human = char:FindFirstChild("Humanoid")
            if root and human and human.Health > 0 and char ~= Char then
                if (root.Position - HRP.Position).Magnitude <= 60 then
                    for _, part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            table.insert(list, {char, part})
                        end
                    end
                end
            end
        end
    end
    scan(workspace:FindFirstChild("Characters"))
    scan(workspace:FindFirstChild("Enemies"))
    return list
end

local function FireAttack(targets)
    if #targets == 0 then return end
    pcall(function()
        local Net  = RS.Modules.Net
        local head = targets[1][1]:FindFirstChild("Head") or targets[1][2]
        require(Net):RemoteEvent("RegisterHit", true)
        Net["RE/RegisterAttack"]:FireServer()
        Net["RE/RegisterHit"]:FireServer(head, targets, {},
            {Id=u5, Distance=60, EffectId="", Duration=1.5,
             Increment=0.08, Priority=0, OriginData={}, InCombo=false})
        if u4 then u4:FireServer(head, targets, {}) end
    end)
end

-- ══════════════════════════════════════════════
-- SPAM SKILL — dùng task.spawn để không yield loop bay
-- ══════════════════════════════════════════════
local lastSkillTime = {}
local function SpamSkill()
    -- Chạy trong task.spawn riêng để không block/yield FlyToTarget loop
    task.spawn(function()
        local keys = ST.WeaponPhase == "Melee" and CFG.SkillKeys.Melee or CFG.SkillKeys.Sword
        for _, k in pairs(keys) do
            local id = tostring(k.Value)
            if not lastSkillTime[id] or tick() - lastSkillTime[id] > 0.15 then
                lastSkillTime[id] = tick()
                pcall(function()
                    VIM:SendKeyEvent(true,  k, false, game)
                    task.wait(0.02)
                    VIM:SendKeyEvent(false, k, false, game)
                end)
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- EQUIP — phân biệt Melee và Sword
-- ══════════════════════════════════════════════
local function GetAllTools()
    local tools = {}
    for _, t in pairs(lp.Backpack:GetChildren()) do
        if t:IsA("Tool") then table.insert(tools, t) end
    end
    for _, t in pairs(Char and Char:GetChildren() or {}) do
        if t:IsA("Tool") then table.insert(tools, t) end
    end
    return tools
end

local function EquipMelee()
    -- Melee = tool không có "sword","katana","blade","gun","pistol" trong tên
    if not Char or not Hum then return end
    local tools = GetAllTools()
    for _, tool in pairs(tools) do
        local name = tool.Name:lower()
        local isSword = name:find("sword") or name:find("katana") or name:find("blade")
                     or name:find("gun")   or name:find("pistol") or name:find("rifle")
                     or name:find("knife") or name:find("dagger")
        if not isSword then
            pcall(function() Hum:EquipTool(tool) end)
            return tool
        end
    end
    -- Nếu không tìm được melee đặc trưng, equip tool đầu tiên
    if #tools > 0 then
        pcall(function() Hum:EquipTool(tools[1]) end)
        return tools[1]
    end
end

local function EquipSword()
    -- Sword = tool có "sword","katana","blade","saber","cutlass" trong tên
    if not Char or not Hum then return end
    local tools = GetAllTools()
    for _, tool in pairs(tools) do
        local name = tool.Name:lower()
        local isSword = name:find("sword") or name:find("katana") or name:find("blade")
                     or name:find("saber") or name:find("cutlass") or name:find("rapier")
        if isSword then
            pcall(function() Hum:EquipTool(tool) end)
            return tool
        end
    end
    -- Nếu không tìm được sword đặc trưng, equip tool thứ 2 (nếu có)
    local tools2 = GetAllTools()
    if #tools2 >= 2 then
        pcall(function() Hum:EquipTool(tools2[2]) end)
        return tools2[2]
    elseif #tools2 == 1 then
        pcall(function() Hum:EquipTool(tools2[1]) end)
        return tools2[1]
    end
end

local function EquipAny()
    if ST.WeaponPhase == "Melee" then
        return EquipMelee()
    else
        return EquipSword()
    end
end

-- ══════════════════════════════════════════════
-- HITBOX
-- ══════════════════════════════════════════════
local function MakeHitbox(p)
    pcall(function()
        local c = p.Character; if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        local head = c:FindFirstChild("Head")
        if root then root.Size = Vector3.new(35,35,35); root.Transparency = 0.8; root.CanCollide = false end
        if head then head.Size = Vector3.new(35,35,35); head.Transparency = 0.8; head.CanCollide = false end
    end)
end

-- ══════════════════════════════════════════════
-- FLY + CHASE — BodyVelocity, không dùng PlatformStand
-- Spam skill chạy riêng task.spawn để không block loop bay
-- ══════════════════════════════════════════════
StopFly = function()
    ST.Flying = false
    if ST.CurrentTween then
        ST.CurrentTween:Cancel()
        ST.CurrentTween = nil
    end
    pcall(function()
        if HRP then
            for _, v in pairs(HRP:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
                    v:Destroy()
                end
            end
        end
    end)
    -- KHÔNG đặt PlatformStand ở đây — để humanoid tự xử lý đứng/ngồi
end

local function FlyToTarget()
    if not ST.Target or not ST.Target.Character then StopFly(); return end
    if not HRP then StopFly(); return end
    if ST.Flying then return end
    ST.Flying = true

    task.spawn(function()
        -- BodyVelocity: điều khiển hướng bay
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.zero
        bv.Parent   = HRP

        -- BodyGyro: giữ hướng mặt (không lăn)
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(0, 1e9, 0)  -- chỉ xoay trục Y, không lật người
        bg.D  = 200
        bg.P  = 3000
        bg.Parent = HRP

        while ST.Flying and ST.Target do
            -- Kiểm tra target còn hợp lệ không
            local tc2 = ST.Target and ST.Target.Character
            if not tc2 or not HRP then break end
            local tRoot = tc2:FindFirstChild("HumanoidRootPart")
            if not tRoot then break end

            local targetPos  = tRoot.Position + Vector3.new(0, 2, 0)
            local currentPos = HRP.Position
            local dist       = (targetPos - currentPos).Magnitude

            -- Luôn hướng mặt về target (chỉ trục Y)
            bg.CFrame = CFrame.new(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))

            if dist <= CFG.AttackDist then
                -- ĐÃ SÁT TARGET: đứng yên, đánh
                bv.Velocity = Vector3.zero
                if not ST.Arrived then
                    ST.Arrived = true
                    -- Bắt đầu đếm thời gian 60s từ khi arrived
                    if not ST.HuntStart then
                        ST.HuntStart = tick()
                        print("⏱ Timer started — arrived at "..ST.Target.Name)
                    end
                end
                -- Attack trong task.spawn riêng — KHÔNG yield loop này
                task.spawn(function()
                    FireAttack(GetAttackTargets())
                end)
                SpamSkill()

            elseif dist <= CFG.AttackDist + 8 then
                -- VÙNG ĐỆM: tiến chậm vào và đánh
                local dir = (targetPos - currentPos).Unit
                bv.Velocity = dir * 60
                ST.Arrived = true
                if not ST.HuntStart then
                    ST.HuntStart = tick()
                end
                task.spawn(function()
                    FireAttack(GetAttackTargets())
                end)
                SpamSkill()

            else
                -- CÒN XA: bay nhanh
                ST.Arrived = false
                local dir = (targetPos - currentPos).Unit
                bv.Velocity = dir * CFG.FlySpeed
            end

            task.wait(0.05)
        end

        -- Dọn dẹp
        pcall(function() bv:Destroy() end)
        pcall(function() bg:Destroy() end)
        ST.Flying = false
    end)
end

-- ══════════════════════════════════════════════
-- WEAPON PHASE SWITCH: Melee ↔ Sword mỗi 3s
-- ══════════════════════════════════════════════
task.spawn(function()
    while task.wait(3) do
        if not ST.On or not ST.Target or not ST.Arrived then continue end
        pcall(function()
            -- Chuyển phase
            ST.WeaponPhase = (ST.WeaponPhase == "Melee" and "Sword" or "Melee")
            ST.PhaseTimer  = tick()
            -- Equip đúng loại vũ khí
            if ST.WeaponPhase == "Melee" then
                EquipMelee()
            else
                EquipSword()
            end
            print("🔄 Phase → "..ST.WeaponPhase)
        end)
    end
end)

-- ══════════════════════════════════════════════
-- FIND TARGET — Kill ALL, không filter level
-- Chọn người có bounty cao nhất
-- ══════════════════════════════════════════════
FindTarget = function()
    if not HRP then return nil end

    local best       = nil
    local bestBounty = -1
    local count      = 0

    for _, p in pairs(Players:GetPlayers()) do
        if p == lp then continue end
        if table.find(CFG.SkipList, p.Name) then continue end

        local c = p.Character
        if not c then continue end

        local root = c:FindFirstChild("HumanoidRootPart")
        local h    = c:FindFirstChild("Humanoid")
        if not root or not h or h.Health <= 0 then continue end

        -- Không cần check team — kill tất cả
        count = count + 1
        local bounty = p:GetAttribute("Bounty") or 0

        if bounty > bestBounty then
            bestBounty = bounty
            best       = p
        end
    end

    if count > 0 then
        print("✅ "..count.." target(s) | Best: "..(best and best.Name or "?").." | Bounty: "..bestBounty)
    end

    return best
end

-- ══════════════════════════════════════════════
-- SAFE ZONE
-- ══════════════════════════════════════════════
local function CheckHP()
    if not Hum then return false end
    return Hum.Health < CFG.SafeHP
end

local function GoSafe()
    if ST.InSafe then return end
    ST.InSafe = true; StopFly(); ST.Target = nil; ST.Arrived = false
    if HRP then HRP.CFrame = HRP.CFrame * CFrame.new(0, 500, 0) end
    task.spawn(function()
        while ST.InSafe do
            if Hum and Hum.Health >= CFG.MaxHP then ST.InSafe = false end
            task.wait(1)
        end
        if ST.On then
            local t = FindTarget()
            if t then SetTarget(t) end
        end
    end)
end

-- ══════════════════════════════════════════════
-- SERVER HOP — SPAM HOP liên tục đến khi vào được
-- ══════════════════════════════════════════════
local isHopping   = false
local hopAttempt  = 0

-- Cache server list để không spam API
local cachedServers = {}
local lastFetch     = 0

local function FetchServers()
    -- Chỉ fetch lại sau 15s
    if tick() - lastFetch < 15 and #cachedServers > 0 then
        return cachedServers
    end
    lastFetch   = tick()
    cachedServers = {}

    pcall(function()
        local url  = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100"
        local raw  = game:HttpGet(url)
        local data = HttpService:JSONDecode(raw)

        local preferred = {}
        local fallback  = {}

        for _, s in pairs(data.data or {}) do
            if s.id == game.JobId then continue end
            local playing = tonumber(s.playing) or 0
            if playing >= CFG.MinHopPlayers and playing <= CFG.MaxHopPlayers then
                table.insert(preferred, {id=s.id, playing=playing})
            elseif playing >= 3 then
                table.insert(fallback, {id=s.id, playing=playing})
            end
        end

        table.sort(preferred, function(a,b) return a.playing > b.playing end)
        table.sort(fallback,  function(a,b) return a.playing > b.playing end)

        for _, s in pairs(preferred) do table.insert(cachedServers, s) end
        for _, s in pairs(fallback)  do table.insert(cachedServers, s) end
    end)

    return cachedServers
end

local function HopServer()
    if isHopping then return end
    isHopping  = true
    hopAttempt = 0

    StatusLbl.Text = "🌐  Spam Hopping..."
    TargetLbl.Text = "🔄  Scanning servers 9-16 players..."
    if HRP then HRP.CFrame = HRP.CFrame * CFrame.new(0, 9999, 0) end
    task.wait(0.3)

    task.spawn(function()
        while isHopping do
            hopAttempt = hopAttempt + 1

            local servers = FetchServers()

            -- Lọc server chưa thử
            local candidates = {}
            for _, s in pairs(servers) do
                if not table.find(CFG.JoinedServers, s.id) then
                    table.insert(candidates, s)
                end
            end

            -- Hết tất cả server → xóa cache + list rồi thử lại ngay
            if #candidates == 0 then
                print("♻️ Attempt "..hopAttempt.." — No more servers, resetting...")
                CFG.JoinedServers = {}
                cachedServers     = {}
                lastFetch         = 0
                StatusLbl.Text = "♻️  Reset list, re-fetching... (#"..hopAttempt..")"
                task.wait(1.5)
                continue
            end

            -- Lấy server nhiều người nhất chưa thử
            local chosen = candidates[1]
            table.insert(CFG.JoinedServers, chosen.id)

            print("🌐 Hop #"..hopAttempt.." → "..chosen.playing.." players | "..chosen.id)
            StatusLbl.Text = "🌐  #"..hopAttempt.." → "..chosen.playing.." players"
            TargetLbl.Text = "🚀  Teleporting now..."

            -- Fire teleport
            local teleOk = pcall(function()
                TeleportSvc:TeleportToPlaceInstance(game.PlaceId, chosen.id, lp)
            end)

            if teleOk then
                -- Chờ 6s xem có load vào server không
                -- Nếu vẫn còn đây nghĩa là teleport thất bại → thử tiếp ngay
                task.wait(6)
                if isHopping then
                    print("⚠️ Hop #"..hopAttempt.." failed (still here), next server...")
                    StatusLbl.Text = "⚠️  Hop #"..hopAttempt.." failed, trying next..."
                end
            else
                print("❌ Hop #"..hopAttempt.." pcall error, next server...")
                StatusLbl.Text = "❌  Error #"..hopAttempt..", retrying..."
                task.wait(0.5)
            end
        end
    end)
end

-- ══════════════════════════════════════════════
-- SET TARGET
-- ══════════════════════════════════════════════
SetTarget = function(p)
    StopFly()
    ST.Target     = p
    ST.Arrived    = false
    ST.HuntStart  = nil    -- Timer chỉ bắt đầu khi đã đến gần target
    ST.PhaseTimer = tick()

    if p then
        local bounty = p:GetAttribute("Bounty") or 0
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TARGET: "..p.Name.." | Bounty: "..bounty)
        TargetLbl.Text = "🎯  "..p.Name.." | 💰"..bounty
        StatusLbl.Text = "🚀  Flying to "..p.Name.."..."
        TimerLbl.Text  = "⏱ Chưa đến..."
        MakeHitbox(p)
        EquipAny()
        FlyToTarget()
    else
        TargetLbl.Text = "🎯  Searching..."
        StatusLbl.Text = "🔍  No target found"
        TimerLbl.Text  = ""
    end
end

-- ══════════════════════════════════════════════
-- AUTO JOIN PIRATES
-- ══════════════════════════════════════════════
task.spawn(function()
    task.wait(2)
    pcall(function() RS.Remotes.CommF_:InvokeServer("JoinTeam","Pirates") end)
    pcall(function() RS.Remotes.CommF_:InvokeServer("ChooseTeam","Pirates") end)
    pcall(function()
        for _, sg in pairs(pGui:GetChildren()) do
            for _, v in pairs(sg:GetDescendants()) do
                if v:IsA("TextButton") then
                    local t = v.Text:lower()
                    if t:find("pirate") or t:find("hải tặc") then
                        v.MouseButton1Click:Fire()
                    end
                end
            end
        end
    end)
end)

-- ══════════════════════════════════════════════
-- MAIN LOOP
-- ══════════════════════════════════════════════
task.spawn(function()
    task.wait(1)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 SWITCH HUB V7 — KILL ALL + SPAM HOP")
    print("👥 Players: "..#Players:GetPlayers())
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            local bounty = p:GetAttribute("Bounty") or 0
            local team   = p.Team and p.Team.Name or "None"
            print("→ "..p.Name.." | 💰"..bounty.." | "..team)
        end
    end
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    if ST.On then
        SetTarget(FindTarget())
    end
end)

local noTargetTime  = 0
local lastTargetHP  = 0
local stuckHPTimer  = 0

task.spawn(function()
    while task.wait(0.05) do
        if not ST.On then continue end
        pcall(function()
            if not HRP then RefreshChar(); return end
            if CheckHP() then GoSafe(); return end
            if ST.InSafe then return end

            -- Không có target → tìm ngay
            if not ST.Target or not ST.Target.Character then
                if ST.Flying then StopFly() end
                ST.Arrived = false
                local t = FindTarget()
                if t then
                    noTargetTime = 0
                    isHopping    = false
                    SetTarget(t)
                else
                    noTargetTime = noTargetTime + 0.05
                    TargetLbl.Text = "🎯  No players... ("..math.floor(noTargetTime).."s)"
                    StatusLbl.Text = "🔍  Waiting for players..."
                    TimerLbl.Text  = ""
                    if noTargetTime >= 8 then
                        noTargetTime = 0
                        HopServer()
                    end
                end
                return
            end

            noTargetTime = 0

            local tc    = ST.Target.Character
            local tRoot = tc and tc:FindFirstChild("HumanoidRootPart")
            local tHum  = tc and tc:FindFirstChild("Humanoid")

            -- Target chết / mất → chuyển ngay
            if not tRoot or not tHum or tHum.Health <= 0 then
                isHopping = false
                stuckHPTimer = 0
                SetTarget(FindTarget())
                return
            end

            -- ★ DETECT SAFE ZONE: HP không giảm trong 5s khi đang đánh → safe zone → skip
            if ST.Arrived then
                local currentHP = tHum.Health
                if currentHP >= lastTargetHP - 0.5 then
                    stuckHPTimer = stuckHPTimer + 0.05
                    if stuckHPTimer >= 5 then
                        stuckHPTimer = 0
                        print("⚠️ Safe zone detected! Switching from "..ST.Target.Name)
                        table.insert(CFG.SkipList, ST.Target.Name)
                        task.delay(60, function()
                            local idx = table.find(CFG.SkipList, ST.Target and ST.Target.Name or "")
                            if idx then table.remove(CFG.SkipList, idx) end
                        end)
                        local nxt = FindTarget()
                        if nxt then SetTarget(nxt) else HopServer() end
                        return
                    end
                else
                    stuckHPTimer = 0  -- HP đang giảm, reset
                end
                lastTargetHP = currentHP
            else
                stuckHPTimer = 0
                lastTargetHP = tHum.Health
            end

            -- Timer 60s — chỉ tính khi đã arrived
            if ST.HuntStart then
                local elapsed   = tick() - ST.HuntStart
                local remaining = math.max(0, CFG.MaxHuntTime - elapsed)
                TimerLbl.Text   = "⏱ "..math.floor(remaining).."s | "..ST.Target.Name

                if elapsed >= CFG.MaxHuntTime then
                    print("⏰ 60s up — switching from "..ST.Target.Name)
                    table.insert(CFG.SkipList, ST.Target.Name)
                    task.delay(180, function()
                        local idx = table.find(CFG.SkipList, ST.Target and ST.Target.Name or "")
                        if idx then table.remove(CFG.SkipList, idx) end
                    end)
                    local nxt = FindTarget()
                    if nxt then SetTarget(nxt) else HopServer() end
                    return
                end
            else
                TimerLbl.Text = "⏱ Bay đến target..."
            end

            -- Update UI
            local dist   = (tRoot.Position - HRP.Position).Magnitude
            local bounty = ST.Target:GetAttribute("Bounty") or 0
            TargetLbl.Text = "🎯  "..ST.Target.Name.." | "..math.floor(dist).."m | ❤"..math.floor(tHum.Health).." | 💰"..bounty

            -- Luôn bay/bám — nếu không flying thì khởi động lại
            if not ST.Flying then
                StatusLbl.Text = (dist <= CFG.AttackDist)
                    and "⚔  Attacking "..ST.Target.Name.." | "..ST.WeaponPhase
                    or  "🚀  Re-flying → "..ST.Target.Name
                FlyToTarget()
            else
                StatusLbl.Text = (ST.Arrived)
                    and "⚔  Attacking + Chasing | "..ST.WeaponPhase
                    or  "🚀  Flying → "..ST.Target.Name.." ("..math.floor(dist).."m)"
            end
        end)
    end
end)

-- ══════════════════════════════════════════════
-- SKIP
-- ══════════════════════════════════════════════
SkipBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if ST.Target then
            local name = ST.Target.Name
            table.insert(CFG.SkipList, name)
            task.delay(180, function()
                local idx = table.find(CFG.SkipList, name)
                if idx then table.remove(CFG.SkipList, idx) end
            end)
        end
        StopFly(); ST.Arrived = false; ST.Target = nil
        local t = FindTarget()
        if t then SetTarget(t) else HopServer() end
    end)
end)

-- ══════════════════════════════════════════════
-- NOCLIP — BẬT NGAY KHI LOAD, không cần bấm nút
-- ══════════════════════════════════════════════
local noclipConn = nil

local function SetNoclip(enabled)
    ST.Noclip = enabled

    if enabled then
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(0,180,80)
        NoclipBtn.Text = "👻  Noclip ON"
        if not noclipConn then
            noclipConn = RunService.Stepped:Connect(function()
                pcall(function()
                    if not ST.Noclip then return end
                    if not Char then return end
                    for _, part in pairs(Char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end)
            end)
        end
    else
        NoclipBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
        NoclipBtn.Text = "🧱  Noclip OFF"
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        pcall(function()
            if not Char then return end
            for _, part in pairs(Char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end)
    end
end

-- Bật noclip ngay khi load
SetNoclip(true)

-- Toggle khi bấm nút
NoclipBtn.MouseButton1Click:Connect(function()
    SetNoclip(not ST.Noclip)
end)

-- Re-apply noclip sau khi respawn
lp.CharacterAdded:Connect(function(c)
    if ST.Noclip then
        task.wait(0.5)
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        SetNoclip(true)
    end
end)

-- ══════════════════════════════════════════════
-- TOGGLE
-- ══════════════════════════════════════════════
ToggleBtn.MouseButton1Click:Connect(function()
    ST.On = not ST.On
    if ST.On then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40,200,90)
        ToggleBtn.Text = "✅  ON"
        SetTarget(FindTarget())
    else
        StopFly(); ST.Target = nil; ST.Arrived = false
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        ToggleBtn.Text = "❌  OFF"
        StatusLbl.Text = "⏸  Paused"; TimerLbl.Text = ""
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title="Switch Hub V10",
        Text="✅ No-Fall Skill | Auto Equip | Timer Fix!",
        Duration=5
    })
end)
print("✅ Switch Hub V10 — No-Fall Skill | Auto Equip Melee/Sword | Timer on Arrive!")
