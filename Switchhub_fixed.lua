--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║         Switch Hub - Bounty Hunting Ultimate V6           ║
    ║                    By: tbobiito                           ║
    ╚═══════════════════════════════════════════════════════════╝
    V6 FIX:
    ✅ Kill TẤT CẢ player trong server - không giới hạn level
    ✅ Fix chọn target - luôn có target nếu server có người
    ✅ Hop server ưu tiên 9-16 người để kill nhiều hơn
    ✅ Bay BodyVelocity mượt - không bị rơi
    ✅ Tự chuyển target khi kill xong hoặc hết 60s
    ✅ Sau respawn tự tìm target mới ngay
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
    On           = true,
    Target       = nil,
    HuntStart    = tick(),
    Flying       = false,
    InSafe       = false,
    Arrived      = false,
    WeaponPhase  = "Melee",
    PhaseTimer   = tick(),
    CurrentTween = nil,
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
SubLbl.Text = "Kill ALL  •  350 Speed  •  Hop 9-16 Players Server"
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
-- SPAM SKILL
-- ══════════════════════════════════════════════
local lastSkillTime = {}
local function SpamSkill()
    local keys = ST.WeaponPhase == "Melee" and CFG.SkillKeys.Melee or CFG.SkillKeys.Sword
    for _, k in pairs(keys) do
        local id = tostring(k.Value)
        if not lastSkillTime[id] or tick() - lastSkillTime[id] > 0.2 then
            lastSkillTime[id] = tick()
            VIM:SendKeyEvent(true, k, false, game)
            task.wait(0.02)
            VIM:SendKeyEvent(false, k, false, game)
        end
    end
end

-- ══════════════════════════════════════════════
-- EQUIP
-- ══════════════════════════════════════════════
local function EquipAny()
    if not Char then return end
    for _, tool in pairs(lp.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() Hum:EquipTool(tool) end)
            return tool
        end
    end
    for _, tool in pairs(Char:GetChildren()) do
        if tool:IsA("Tool") then return tool end
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
-- FLY SYSTEM - BODYVELOCITY 350 SPEED
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
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
            end
        end
    end)
    pcall(function()
        if Hum then Hum.PlatformStand = false end
    end)
end

local function FlyToTarget()
    if not ST.Target or not ST.Target.Character then StopFly(); return end
    if not HRP then StopFly(); return end
    if ST.Flying then return end
    ST.Flying = true

    task.spawn(function()
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity  = Vector3.zero
        bv.Parent    = HRP

        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.D = 100; bg.P = 1e4
        bg.Parent = HRP

        pcall(function() if Hum then Hum.PlatformStand = true end end)

        while ST.Flying and ST.Target and ST.Target.Character do
            local ok = pcall(function()
                local tc2   = ST.Target.Character
                if not tc2 then StopFly(); return end
                local tRoot = tc2:FindFirstChild("HumanoidRootPart")
                if not tRoot or not HRP then StopFly(); return end

                local targetPos  = tRoot.Position + Vector3.new(0, 3, 0)
                local currentPos = HRP.Position
                local dist       = (targetPos - currentPos).Magnitude

                if dist <= CFG.AttackDist + 2 then
                    bv.Velocity = Vector3.zero
                    StopFly()
                    ST.Arrived = true
                    return
                end

                local dir   = (targetPos - currentPos).Unit
                bv.Velocity = dir * CFG.FlySpeed
                bg.CFrame   = CFrame.lookAt(currentPos, targetPos)
            end)
            if not ok then break end
            task.wait(0.05)
        end

        pcall(function() bv:Destroy() end)
        pcall(function() bg:Destroy() end)
        pcall(function() if Hum then Hum.PlatformStand = false end end)
    end)
end

-- ══════════════════════════════════════════════
-- ATTACK LOOP
-- ══════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.05) do
        if not ST.On or not ST.Arrived or not ST.Target then continue end
        pcall(function()
            if not HRP or not ST.Target.Character then return end
            local tRoot = ST.Target.Character:FindFirstChild("HumanoidRootPart")
            if not tRoot then return end
            local dist = (tRoot.Position - HRP.Position).Magnitude
            if dist <= CFG.AttackDist + 5 then
                FireAttack(GetAttackTargets())
                SpamSkill()
            end
        end)
    end
end)

-- Weapon phase switch
task.spawn(function()
    while task.wait(1) do
        if ST.Arrived and ST.Target then
            if tick() - ST.PhaseTimer >= 8 then
                ST.PhaseTimer = tick()
                ST.WeaponPhase = (ST.WeaponPhase == "Melee" and "Sword" or "Melee")
                EquipAny()
            end
        end
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
-- SERVER HOP — ưu tiên server 9-16 người
-- ══════════════════════════════════════════════
local isHopping = false
local function HopServer()
    if isHopping then return end
    isHopping = true
    StatusLbl.Text = "🌐  Hopping server..."
    TargetLbl.Text = "🔄  Finding server with more players..."
    if HRP then HRP.CFrame = HRP.CFrame * CFrame.new(0, 9999, 0) end
    task.wait(1.5)

    local hopOk = pcall(function()
        -- sortOrder=Desc = server nhiều người nhất lên đầu
        local url  = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100"
        local raw  = game:HttpGet(url)
        local data = HttpService:JSONDecode(raw)

        local preferred = {} -- 9-16 người
        local fallback  = {} -- bất kỳ server có người

        for _, s in pairs(data.data or {}) do
            if s.id == game.JobId then continue end
            if table.find(CFG.JoinedServers, s.id) then continue end

            local playing    = tonumber(s.playing) or 0
            local maxPlayers = tonumber(s.maxPlayers) or 20

            if playing >= CFG.MinHopPlayers and playing <= CFG.MaxHopPlayers then
                table.insert(preferred, {id=s.id, playing=playing})
            elseif playing >= 3 then
                -- Fallback: ít nhất 3 người
                table.insert(fallback, {id=s.id, playing=playing})
            end
        end

        -- Sắp xếp: nhiều người nhất lên đầu
        table.sort(preferred, function(a,b) return a.playing > b.playing end)
        table.sort(fallback,  function(a,b) return a.playing > b.playing end)

        local list = #preferred > 0 and preferred or fallback

        if #list > 0 then
            -- Chọn random trong top 3 nhiều người nhất
            local topN   = math.min(3, #list)
            local chosen = list[math.random(1, topN)]
            table.insert(CFG.JoinedServers, chosen.id)
            print("🌐 Hopping → "..chosen.playing.." players | "..chosen.id)
            StatusLbl.Text = "🌐  Joining ("..chosen.playing.." players)..."
            task.wait(0.5)
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId, chosen.id, lp)
        else
            print("⚠️ No servers found — reset list")
            CFG.JoinedServers = {}
            isHopping = false
        end
    end)

    if not hopOk then
        isHopping = false
    end
end

-- ══════════════════════════════════════════════
-- SET TARGET
-- ══════════════════════════════════════════════
SetTarget = function(p)
    StopFly()
    ST.Target    = p
    ST.Arrived   = false
    ST.HuntStart = tick()
    ST.PhaseTimer = tick()

    if p then
        local bounty = p:GetAttribute("Bounty") or 0
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TARGET: "..p.Name.." | Bounty: "..bounty)
        TargetLbl.Text = "🎯  "..p.Name.." | 💰"..bounty
        StatusLbl.Text = "🚀  Flying to "..p.Name.."..."
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
    print("🔍 SWITCH HUB V6 — KILL ALL MODE")
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

local noTargetTime = 0

task.spawn(function()
    while task.wait(0.05) do
        if not ST.On then continue end
        pcall(function()
            if not HRP then RefreshChar(); return end
            if CheckHP() then GoSafe(); return end
            if ST.InSafe then return end

            -- Không có target → tìm ngay
            if not ST.Target or not ST.Target.Character then
                StopFly(); ST.Arrived = false
                local t = FindTarget()
                if t then
                    noTargetTime = 0
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

            -- Target chết → chọn ngay target mới
            if not tRoot or not tHum or tHum.Health <= 0 then
                SetTarget(FindTarget())
                return
            end

            -- 60s → đổi target
            local elapsed   = tick() - ST.HuntStart
            local remaining = math.max(0, CFG.MaxHuntTime - elapsed)
            TimerLbl.Text = "⏱ "..math.floor(remaining).."s | "..ST.Target.Name

            if elapsed >= CFG.MaxHuntTime then
                table.insert(CFG.SkipList, ST.Target.Name)
                task.delay(180, function()
                    local idx = table.find(CFG.SkipList, ST.Target and ST.Target.Name or "")
                    if idx then table.remove(CFG.SkipList, idx) end
                end)
                local nxt = FindTarget()
                if nxt then SetTarget(nxt) else HopServer() end
                return
            end

            -- Update UI
            local dist   = (tRoot.Position - HRP.Position).Magnitude
            local bounty = ST.Target:GetAttribute("Bounty") or 0
            TargetLbl.Text = "🎯  "..ST.Target.Name.." | "..math.floor(dist).."m | ❤"..math.floor(tHum.Health).." | 💰"..bounty

            -- Bay hoặc đánh
            if dist > CFG.AttackDist + 2 then
                ST.Arrived = false
                if not ST.Flying then
                    StatusLbl.Text = "🚀  Flying → "..ST.Target.Name
                    FlyToTarget()
                end
            elseif dist <= CFG.AttackDist then
                ST.Arrived = true
                StatusLbl.Text = "⚔  Attacking "..ST.Target.Name.." | "..ST.WeaponPhase
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
        Title="Switch Hub V6",
        Text="✅ Kill ALL | 350 Speed | Hop 9-16 Players",
        Duration=5
    })
end)
print("✅ Switch Hub V6 — Kill ALL | 350 Speed Ready!")
