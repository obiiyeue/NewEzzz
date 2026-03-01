--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║         Switch Hub - Bounty Hunting Ultimate V5           ║
    ║                    By: tbobiito                           ║
    ╚═══════════════════════════════════════════════════════════╝
    V5 NÂNG CẤP:
    ✅ Bay TWEEN mượt mà 350 studs/giây - KHÔNG GIẬT LAG
    ✅ Chỉ tìm player level 2300-2800 để kill
    ✅ Tự động hop server khi ≥9 players
    ✅ Chỉ spam skill & attack KHI ĐÃ ĐẾN GẦN (dist <= 10)
    ✅ Chữ "Switch Hub" cực to giữa màn hình + VIỀN TRẮNG DÀY
    ✅ Skip = đổi player NGAY, không delay
    ✅ Hết player → bay lên trời → đổi server
    ✅ Bám target 60s → tự chuyển player mới
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
    FlySpeed      = 350,  -- Tốc độ bay 350 studs/giây
    MaxHuntTime   = 60,
    MinLevel      = 2300, -- Level tối thiểu
    MaxLevel      = 2800, -- Level tối đa
    SkillKeys     = {
        Melee = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V},
        Sword = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C},
    },
    SkipList      = {},
    JoinedServers = {},
    SafeHP        = 500,
    MaxHP         = 2000,
}

-- ══════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════
local ST = {
    On          = true,
    Target      = nil,
    HuntStart   = tick(),
    Flying      = false,
    InSafe      = false,
    Arrived     = false,
    WeaponPhase = "Melee",
    PhaseTimer  = tick(),
    CurrentTween = nil,
}

-- ══════════════════════════════════════════════
-- CHARACTER
-- ══════════════════════════════════════════════
local Char, Hum, HRP

local function RefreshChar()
    Char=lp.Character; if not Char then return end
    Hum=Char:FindFirstChildOfClass("Humanoid")
    HRP=Char:FindFirstChild("HumanoidRootPart")
end
RefreshChar()

lp.CharacterAdded:Connect(function(c)
    Char=c; Hum=c:WaitForChild("Humanoid"); HRP=c:WaitForChild("HumanoidRootPart")
    ST.Target=nil; ST.Flying=false; ST.Arrived=false; ST.InSafe=false
    -- Sau khi respawn, tìm target mới và bay lại
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
    local o=game:GetService("CoreGui"):FindFirstChild("SwitchHubUI"); if o then o:Destroy() end
end)
pcall(function()
    local o=pGui:FindFirstChild("SwitchHubUI"); if o then o:Destroy() end
end)

local SG=Instance.new("ScreenGui")
SG.Name="SwitchHubUI"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.DisplayOrder=999; SG.IgnoreGuiInset=true
pcall(function() SG.Parent=game:GetService("CoreGui") end)
if not SG.Parent or SG.Parent==game then SG.Parent=pGui end

-- Background avatar toàn màn hình 50% trong suốt
local BgImg=Instance.new("ImageLabel",SG)
BgImg.Size=UDim2.fromScale(1,1); BgImg.Position=UDim2.fromScale(0,0)
BgImg.BackgroundTransparency=1; BgImg.Image="rbxassetid://16060333448"
BgImg.ImageTransparency=0.5; BgImg.ScaleType=Enum.ScaleType.Stretch; BgImg.ZIndex=1

-- ★★★ TITLE SIÊU TO GIỮA MÀN HÌNH + VIỀN TRẮNG DÀY ★★★
local TitleLbl=Instance.new("TextLabel",SG)
TitleLbl.Size=UDim2.new(1,0,0,180)
TitleLbl.Position=UDim2.new(0,0,0.5,-220)
TitleLbl.BackgroundTransparency=1
TitleLbl.Text="Switch Hub"
TitleLbl.TextColor3=Color3.fromRGB(80,200,255)
TitleLbl.TextScaled=true
TitleLbl.Font=Enum.Font.GothamBold
TitleLbl.TextStrokeTransparency=0        -- Viền đậm tối đa
TitleLbl.TextStrokeColor3=Color3.fromRGB(255,255,255)  -- VIỀN TRẮNG
TitleLbl.ZIndex=5

-- Sub title
local SubLbl=Instance.new("TextLabel",SG)
SubLbl.Size=UDim2.new(1,0,0,44); SubLbl.Position=UDim2.new(0,0,0.5,-38)
SubLbl.BackgroundTransparency=1; SubLbl.Text="Lv.2300-2800  •  350 Speed  •  Hop to 9-12 Players Server"
SubLbl.TextColor3=Color3.fromRGB(220,220,220); SubLbl.TextScaled=true
SubLbl.Font=Enum.Font.Gotham; SubLbl.TextStrokeTransparency=0.3
SubLbl.TextStrokeColor3=Color3.fromRGB(0,0,0); SubLbl.ZIndex=5

-- Target label
local TargetLbl=Instance.new("TextLabel",SG)
TargetLbl.Size=UDim2.new(1,0,0,40); TargetLbl.Position=UDim2.new(0,0,0.5,14)
TargetLbl.BackgroundTransparency=1; TargetLbl.Text="🎯  Searching..."
TargetLbl.TextColor3=Color3.fromRGB(255,255,255); TargetLbl.TextScaled=true
TargetLbl.Font=Enum.Font.Gotham; TargetLbl.TextStrokeTransparency=0.3
TargetLbl.TextStrokeColor3=Color3.fromRGB(0,0,0); TargetLbl.ZIndex=5

-- Status label
local StatusLbl=Instance.new("TextLabel",SG)
StatusLbl.Size=UDim2.new(1,0,0,36); StatusLbl.Position=UDim2.new(0,0,0.5,60)
StatusLbl.BackgroundTransparency=1; StatusLbl.Text="⚡  Starting..."
StatusLbl.TextColor3=Color3.fromRGB(100,255,100); StatusLbl.TextScaled=true
StatusLbl.Font=Enum.Font.Gotham; StatusLbl.TextStrokeTransparency=0.3
StatusLbl.TextStrokeColor3=Color3.fromRGB(0,0,0); StatusLbl.ZIndex=5

-- Timer label
local TimerLbl=Instance.new("TextLabel",SG)
TimerLbl.Size=UDim2.new(1,0,0,30); TimerLbl.Position=UDim2.new(0,0,0.5,100)
TimerLbl.BackgroundTransparency=1; TimerLbl.Text=""
TimerLbl.TextColor3=Color3.fromRGB(255,200,50); TimerLbl.TextScaled=true
TimerLbl.Font=Enum.Font.Gotham; TimerLbl.TextStrokeTransparency=0.3
TimerLbl.TextStrokeColor3=Color3.fromRGB(0,0,0); TimerLbl.ZIndex=5

-- Skip button
local SkipBtn=Instance.new("TextButton",SG)
SkipBtn.Size=UDim2.fromOffset(150,55); SkipBtn.Position=UDim2.new(1,-160,0,15)
SkipBtn.BackgroundColor3=Color3.fromRGB(255,255,255); SkipBtn.BorderSizePixel=0
SkipBtn.Text="⏭  Skip"; SkipBtn.TextColor3=Color3.fromRGB(0,0,0)
SkipBtn.TextSize=22; SkipBtn.Font=Enum.Font.GothamBold; SkipBtn.ZIndex=10
Instance.new("UICorner",SkipBtn).CornerRadius=UDim.new(0,14)

-- Toggle button
local ToggleBtn=Instance.new("TextButton",SG)
ToggleBtn.Size=UDim2.fromOffset(150,55); ToggleBtn.Position=UDim2.new(1,-160,0,80)
ToggleBtn.BackgroundColor3=Color3.fromRGB(40,200,90); ToggleBtn.BorderSizePixel=0
ToggleBtn.Text="✅  ON"; ToggleBtn.TextColor3=Color3.fromRGB(255,255,255)
ToggleBtn.TextSize=22; ToggleBtn.Font=Enum.Font.GothamBold; ToggleBtn.ZIndex=10
Instance.new("UICorner",ToggleBtn).CornerRadius=UDim.new(0,14)

-- ══════════════════════════════════════════════
-- ATTACK REMOTE — REDZ HUB METHOD
-- ══════════════════════════════════════════════
local u4,u5=nil,nil
local function FindBypassRemote()
    local folders={}
    for _,name in ipairs({"Util","Common","Remotes","Assets","FX"}) do
        local f=RS:FindFirstChild(name); if f then table.insert(folders,f) end
    end
    local v1=next; local v3=nil
    while true do
        local v6; v3,v6=v1(folders,v3); if v3==nil then break end
        local v7=next; local v8=v6:GetChildren(); local v9=nil
        while true do
            local v10; v9,v10=v7(v8,v9); if v9==nil then break end
            if v10 and v10:IsA("RemoteEvent") and v10:GetAttribute("Id") then
                u5=v10:GetAttribute("Id"); u4=v10
            end
        end
        pcall(function()
            v6.ChildAdded:Connect(function(c)
                if c:IsA("RemoteEvent") and c:GetAttribute("Id") then
                    u5=c:GetAttribute("Id"); u4=c
                end
            end)
        end)
    end
end
FindBypassRemote()

local function GetAttackTargets()
    if not HRP then return {} end
    local list={}
    local function scan(folder)
        if not folder then return end
        for _,char in pairs(folder:GetChildren()) do
            local root=char:FindFirstChild("HumanoidRootPart")
            local human=char:FindFirstChild("Humanoid")
            if root and human and human.Health>0 and char~=Char then
                if (root.Position-HRP.Position).Magnitude<=60 then
                    for _,part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") then table.insert(list,{char,part}) end
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
    if #targets==0 then return end
    pcall(function()
        local Net=RS.Modules.Net
        local head=targets[1][1]:FindFirstChild("Head") or targets[1][2]
        require(Net):RemoteEvent("RegisterHit",true)
        Net["RE/RegisterAttack"]:FireServer()
        Net["RE/RegisterHit"]:FireServer(head,targets,{},
            {Id=u5,Distance=60,EffectId="",Duration=1.5,
             Increment=0.08,Priority=0,OriginData={},InCombo=false})
        if u4 then u4:FireServer(head,targets,{}) end
    end)
end

-- ══════════════════════════════════════════════
-- SPAM SKILL
-- ══════════════════════════════════════════════
local lastSkillTime={}
local function SpamSkill()
    local keys=ST.WeaponPhase=="Melee" and CFG.SkillKeys.Melee or CFG.SkillKeys.Sword
    for _,k in pairs(keys) do
        local id=tostring(k.Value)
        if not lastSkillTime[id] or tick()-lastSkillTime[id]>0.2 then
            lastSkillTime[id]=tick()
            VIM:SendKeyEvent(true,k,false,game)
            task.wait(0.02)
            VIM:SendKeyEvent(false,k,false,game)
        end
    end
end

-- ══════════════════════════════════════════════
-- EQUIP
-- ══════════════════════════════════════════════
local function EquipAny()
    if not Char then return end
    for _,tool in pairs(lp.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() Hum:EquipTool(tool) end)
            return tool
        end
    end
    for _,tool in pairs(Char:GetChildren()) do
        if tool:IsA("Tool") then return tool end
    end
end

-- ══════════════════════════════════════════════
-- HITBOX
-- ══════════════════════════════════════════════
local function MakeHitbox(p)
    pcall(function()
        local c=p.Character; if not c then return end
        local root=c:FindFirstChild("HumanoidRootPart")
        local head=c:FindFirstChild("Head")
        if root then root.Size=Vector3.new(35,35,35); root.Transparency=0.8; root.CanCollide=false end
        if head then head.Size=Vector3.new(35,35,35); head.Transparency=0.8; head.CanCollide=false end
    end)
end

-- ══════════════════════════════════════════════
-- SMOOTH TWEEN FLIGHT SYSTEM - 350 SPEED
-- ══════════════════════════════════════════════
local function StopFly()
    ST.Flying = false
    if ST.CurrentTween then
        ST.CurrentTween:Cancel()
        ST.CurrentTween = nil
    end

    -- Xóa BodyVelocity/BodyGyro nếu có
    pcall(function()
        if HRP then
            for _, v in pairs(HRP:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
            end
        end
    end)

    -- Tắt PlatformStand
    pcall(function()
        if Hum then Hum.PlatformStand = false end
    end)
end

local function FlyToTarget()
    if not ST.Target or not ST.Target.Character then
        StopFly()
        return
    end

    local tc = ST.Target.Character
    local tRoot = tc:FindFirstChild("HumanoidRootPart")
    if not tRoot or not HRP then
        StopFly()
        return
    end

    -- Nếu đang bay rồi thì không tạo thêm
    if ST.Flying then return end
    ST.Flying = true

    task.spawn(function()
        -- Tạo BodyVelocity và BodyGyro để bay không bị trọng lực kéo
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity = Vector3.zero
        bv.Parent = HRP

        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.D = 100
        bg.P = 1e4
        bg.Parent = HRP

        -- Vô hiệu hóa humanoid để không bị animation can thiệp
        pcall(function()
            if Hum then
                Hum.PlatformStand = true
            end
        end)

        while ST.Flying and ST.Target and ST.Target.Character do
            pcall(function()
                -- Refresh target root mỗi frame vì target có thể di chuyển
                local tc2 = ST.Target.Character
                if not tc2 then StopFly(); return end
                local tRoot2 = tc2:FindFirstChild("HumanoidRootPart")
                if not tRoot2 or not HRP then StopFly(); return end

                local targetPos = tRoot2.Position + Vector3.new(0, 4, 0)
                local currentPos = HRP.Position
                local distance = (targetPos - currentPos).Magnitude

                if distance <= CFG.AttackDist + 2 then
                    bv.Velocity = Vector3.zero
                    StopFly()
                    ST.Arrived = true
                    return
                end

                -- Tính hướng và đặt velocity thẳng về target
                local direction = (targetPos - currentPos).Unit
                bv.Velocity = direction * CFG.FlySpeed
                bg.CFrame = CFrame.lookAt(currentPos, targetPos)
            end)
            task.wait(0.05)
        end

        -- Dọn dẹp khi kết thúc
        pcall(function() bv:Destroy() end)
        pcall(function() bg:Destroy() end)
        pcall(function()
            if Hum then Hum.PlatformStand = false end
        end)
    end)
end

-- ══════════════════════════════════════════════
-- ATTACK LOOP — CHỈ KHI ARRIVED
-- ══════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.05) do
        if not ST.On or not ST.Arrived or not ST.Target then continue end
        pcall(function()
            if not HRP or not ST.Target.Character then return end
            local tRoot=ST.Target.Character:FindFirstChild("HumanoidRootPart")
            if not tRoot then return end
            local dist=(tRoot.Position-HRP.Position).Magnitude
            if dist<=CFG.AttackDist+5 then
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
            if tick()-ST.PhaseTimer>=8 then
                ST.PhaseTimer=tick()
                ST.WeaponPhase=(ST.WeaponPhase=="Melee" and "Sword" or "Melee")
                EquipAny()
            end
        end
    end
end)

-- ══════════════════════════════════════════════
-- GET PLAYER LEVEL
-- ══════════════════════════════════════════════
local function GetPlayerLevel(player)
    local level = 0
    
    -- Method 1: Check player attributes
    level = player:GetAttribute("Level") or player:GetAttribute("Lv")
    if level and level > 0 then return tonumber(level) end
    
    -- Method 2: Check leaderstats
    pcall(function()
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local lvl = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("Lv") or leaderstats:FindFirstChild("level")
            if lvl then
                if lvl:IsA("IntValue") or lvl:IsA("NumberValue") then
                    level = tonumber(lvl.Value)
                elseif lvl:IsA("StringValue") then
                    level = tonumber(lvl.Value)
                end
            end
        end
    end)
    if level and level > 0 then return level end
    
    -- Method 3: Check Data folder
    pcall(function()
        local data = player:FindFirstChild("Data")
        if data then
            local lvl = data:FindFirstChild("Level") or data:FindFirstChild("Lv") or data:FindFirstChild("level")
            if lvl then
                if lvl:IsA("IntValue") or lvl:IsA("NumberValue") then
                    level = tonumber(lvl.Value)
                elseif lvl:IsA("StringValue") then
                    level = tonumber(lvl.Value)
                end
            end
        end
    end)
    if level and level > 0 then return level end
    
    -- Method 4: Check PlayerGui for level display
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in pairs(playerGui:GetDescendants()) do
                if gui:IsA("TextLabel") and gui.Name:lower():find("level") then
                    local text = gui.Text
                    local num = text:match("%d+")
                    if num then
                        level = tonumber(num)
                    end
                end
            end
        end
    end)
    if level and level > 0 then return level end
    
    -- Method 5: Use RemoteFunction (Blox Fruits specific)
    pcall(function()
        local result = RS.Remotes.CommF_:InvokeServer("GetPlayerLevel", player)
        if result then
            level = tonumber(result)
        end
    end)
    
    return level or 0
end

-- ══════════════════════════════════════════════
-- FIND TARGET
-- ══════════════════════════════════════════════
local function FindTarget()
    if not HRP then return nil end
    local best = nil
    local bestV = 0
    local validPlayers = {}
    
    -- Tìm tất cả players hợp lệ
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp and not table.find(CFG.SkipList, p.Name) then
            local c = p.Character
            if c then
                local root = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChild("Humanoid")
                
                if root and h and h.Health > 0 then
                    -- Kiểm tra team khác nhau (nếu có team)
                    local isDifferentTeam = true
                    if lp.Team and p.Team then
                        isDifferentTeam = (p.Team ~= lp.Team)
                    end
                    
                    if isDifferentTeam then
                        -- Kiểm tra level CHÍNH XÁC trong khoảng 2300-2800
                        local playerLevel = GetPlayerLevel(p)
                        
                        -- Chỉ chọn player có level CHÍNH XÁC từ 2300 đến 2800
                        if playerLevel >= CFG.MinLevel and playerLevel <= CFG.MaxLevel then
                            local bounty = p:GetAttribute("Bounty") or 0
                            table.insert(validPlayers, {player = p, level = playerLevel, bounty = bounty})
                            
                            if bounty > bestV then
                                bestV = bounty
                                best = p
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Debug: In ra số lượng players hợp lệ
    if #validPlayers > 0 then
        print("✅ Found "..#validPlayers.." valid player(s) in level range "..CFG.MinLevel.."-"..CFG.MaxLevel)
        for _, data in pairs(validPlayers) do
            print("   → "..data.player.Name.." | Lv."..data.level.." | Bounty: "..data.bounty)
        end
    end
    
    return best
end

-- ══════════════════════════════════════════════
-- SAFE ZONE
-- ══════════════════════════════════════════════
local function CheckHP()
    if not Hum then return false end
    return Hum.Health<CFG.SafeHP
end
local function GoSafe()
    if ST.InSafe then return end
    ST.InSafe=true; StopFly(); ST.Target=nil; ST.Arrived=false
    if HRP then HRP.CFrame=HRP.CFrame*CFrame.new(0,500,0) end
    task.spawn(function()
        while ST.InSafe do
            if Hum and Hum.Health>=CFG.MaxHP then ST.InSafe=false end
            task.wait(1)
        end
    end)
end

-- ══════════════════════════════════════════════
-- SERVER HOP — bay lên trời trước
-- ══════════════════════════════════════════════
local isHopping=false
local function HopServer()
    if isHopping then return end; isHopping=true
    StatusLbl.Text="🌐  No targets — Hopping..."
    TargetLbl.Text="🎯  Switching server..."
    -- Bay lên trời
    if HRP then HRP.CFrame=HRP.CFrame*CFrame.new(0,9999,0) end
    task.wait(1.5)
    pcall(function()
        local data=HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
        
        -- Ưu tiên server 9-12 người để kill được nhiều target
        local preferred={}  -- 9-12 người
        local fallback={}   -- server khác còn slot

        for _,s in pairs(data.data or {}) do
            if s.id~=game.JobId and not table.find(CFG.JoinedServers,s.id) then
                local playing = s.playing or 0
                local maxPlayers = s.maxPlayers or 12
                if playing >= 9 and playing <= 12 then
                    table.insert(preferred, s)
                elseif playing > 0 and playing < maxPlayers then
                    table.insert(fallback, s)
                end
            end
        end

        -- Chọn server ưu tiên 9-12 người trước
        local list = #preferred > 0 and preferred or fallback

        if #list>0 then
            local s=list[math.random(1,#list)]
            table.insert(CFG.JoinedServers,s.id)
            local playerCount = s.playing or 0
            print("🌐 Hopping to server with "..playerCount.." players (ID: "..s.id..")")
            StatusLbl.Text="🌐  Joining server with "..playerCount.." players..."
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId,s.id,lp)
        else
            -- Reset joined servers nếu đã đi hết
            CFG.JoinedServers={}
            isHopping=false
        end
    end)
end

-- ══════════════════════════════════════════════
-- SET TARGET
-- ══════════════════════════════════════════════
local function SetTarget(p)
    StopFly()
    ST.Target=p; ST.Arrived=false
    ST.HuntStart=tick(); ST.PhaseTimer=tick()
    if p then
        local playerLevel = GetPlayerLevel(p)
        local bounty = p:GetAttribute("Bounty") or 0
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ TARGET LOCKED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("👤 Name: "..p.Name)
        print("⚔️  Level: "..playerLevel.." (Range: "..CFG.MinLevel.."-"..CFG.MaxLevel..")")
        print("💰 Bounty: "..bounty)
        print("🎯 Status: Flying to target at 350 speed...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        TargetLbl.Text="🎯  "..p.Name.." (Lv."..playerLevel..")"
        StatusLbl.Text="🚀  Flying to "..p.Name.." (350 speed)..."
        MakeHitbox(p); EquipAny()
        FlyToTarget()  -- Bay ngay lập tức
    else
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⚠️ NO TARGET FOUND")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎯 Level range: "..CFG.MinLevel.."-"..CFG.MaxLevel)
        print("🔍 Searching for valid targets...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        TargetLbl.Text="🎯  Searching Lv."..CFG.MinLevel.."-"..CFG.MaxLevel.."..."
        StatusLbl.Text="🔍  No target in level range"; TimerLbl.Text=""
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
        for _,sg in pairs(pGui:GetChildren()) do
            for _,v in pairs(sg:GetDescendants()) do
                if v:IsA("TextButton") then
                    local t=v.Text:lower()
                    if t:find("pirate") or t:find("hải tặc") then v.MouseButton1Click:Fire() end
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
    print("🔍 SWITCH HUB V5 - STARTING TARGET SEARCH")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("👥 Players in server: "..#Players:GetPlayers())
    print("🏴‍☠️ Your team: "..(lp.Team and lp.Team.Name or "None"))
    print("🎯 Target level range: "..CFG.MinLevel.."-"..CFG.MaxLevel.." (Exact match)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    local validCount = 0
    local invalidCount = 0
    
    -- List all players with detailed info
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            local bounty = p:GetAttribute("Bounty") or 0
            local team = p.Team and p.Team.Name or "None"
            local level = GetPlayerLevel(p)
            
            -- Check if in valid range
            local inRange = (level >= CFG.MinLevel and level <= CFG.MaxLevel)
            local icon = inRange and "✅" or "❌"
            
            if inRange then
                validCount = validCount + 1
                print(icon.." "..p.Name.." | Lv."..level.." | Team: "..team.." | Bounty: "..bounty)
            else
                invalidCount = invalidCount + 1
                print(icon.." "..p.Name.." | Lv."..level.." (OUT OF RANGE) | Team: "..team)
            end
        end
    end
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 Valid targets: "..validCount.." | Invalid: "..invalidCount)
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if ST.On then 
        local target = FindTarget()
        if target then
            local targetLevel = GetPlayerLevel(target)
            print("✅ Initial target selected: "..target.Name.." (Lv."..targetLevel..")")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        else
            print("⚠️ No valid target found in level range "..CFG.MinLevel.."-"..CFG.MaxLevel.."!")
            print("💡 Searching for valid targets...")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        end
        SetTarget(target)
    end
end)

local noTargetTime=0

task.spawn(function()
    while task.wait(0.05) do
        if not ST.On then continue end
        pcall(function()
            if not HRP then RefreshChar(); return end
            if CheckHP() then GoSafe(); return end
            if ST.InSafe then return end
            
            -- Kiểm tra số người trong server
            local playerCount = #Players:GetPlayers()
            if playerCount >= 9 then
                StatusLbl.Text="👥 Server có "..playerCount.." người - Hopping..."
                TargetLbl.Text="🔄 Tìm server ít người hơn..."
                task.wait(1)
                HopServer()
                return
            end

            -- Không có target
            if not ST.Target or not ST.Target.Character then
                StopFly(); ST.Arrived=false
                local t=FindTarget()
                if t then
                    noTargetTime=0; SetTarget(t)
                else
                    noTargetTime+=0.05
                    TargetLbl.Text="🎯  Searching Lv."..CFG.MinLevel.."-"..CFG.MaxLevel.."... ("..math.floor(noTargetTime).."s)"
                    StatusLbl.Text="🔍  No valid target in level range"
                    TimerLbl.Text=""
                    if noTargetTime>=10 then
                        print("⏰ 10s timeout - No targets found. Hopping server...")
                        noTargetTime=0; HopServer()
                    end
                end
                return
            end

            noTargetTime=0

            local tc=ST.Target.Character
            local tRoot=tc and tc:FindFirstChild("HumanoidRootPart")
            local tHum=tc and tc:FindFirstChild("Humanoid")

            -- Target chết
            if not tRoot or not tHum or tHum.Health<=0 then
                SetTarget(FindTarget()); return
            end

            -- Timer 60s → skip
            local elapsed=tick()-ST.HuntStart
            local remaining=math.max(0,CFG.MaxHuntTime-elapsed)
            TimerLbl.Text="⏱  "..math.floor(remaining).."s left on "..ST.Target.Name

            if elapsed>=CFG.MaxHuntTime then
                -- Hết 60s → chuyển player khác NGAY
                table.insert(CFG.SkipList,ST.Target.Name)
                task.delay(300,function()
                    local idx=table.find(CFG.SkipList,ST.Target and ST.Target.Name or "")
                    if idx then table.remove(CFG.SkipList,idx) end
                end)
                local next=FindTarget()
                if next then SetTarget(next)
                else HopServer() end
                return
            end

            -- Update UI
            local dist=(tRoot.Position-HRP.Position).Magnitude
            local targetLevel = GetPlayerLevel(ST.Target)
            TargetLbl.Text="🎯  "..ST.Target.Name.." (Lv."..targetLevel..") | "..math.floor(dist).."m | HP:"..math.floor(tHum.Health)

            -- Bay đến / Đánh
            if dist>CFG.AttackDist+2 then
                ST.Arrived = false
                if not ST.Flying then
                    StatusLbl.Text="🚀  Flying → "..ST.Target.Name.." (350 speed)"
                    FlyToTarget()
                end
            elseif dist<=CFG.AttackDist then
                ST.Arrived=true
                StatusLbl.Text="⚔  "..ST.Target.Name.." | "..ST.WeaponPhase.." | "..math.floor(elapsed).."s"
            end
        end)
    end
end)

-- ══════════════════════════════════════════════
-- SKIP — NGAY LẬP TỨC
-- ══════════════════════════════════════════════
SkipBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if ST.Target then
            local name=ST.Target.Name
            table.insert(CFG.SkipList,name)
            task.delay(180,function()  -- Reset skip sau 3 phút
                local idx=table.find(CFG.SkipList,name)
                if idx then table.remove(CFG.SkipList,idx) end
            end)
        end
        StopFly(); ST.Arrived=false; ST.Target=nil
        local t=FindTarget()
        if t then
            SetTarget(t)  -- Đổi ngay
        else
            TargetLbl.Text="🎯  No targets!"
            HopServer()   -- Hết player → hop server
        end
    end)
end)

-- ══════════════════════════════════════════════
-- TOGGLE
-- ══════════════════════════════════════════════
ToggleBtn.MouseButton1Click:Connect(function()
    ST.On=not ST.On
    if ST.On then
        ToggleBtn.BackgroundColor3=Color3.fromRGB(40,200,90)
        ToggleBtn.Text="✅  ON"
        SetTarget(FindTarget())
    else
        StopFly(); ST.Target=nil; ST.Arrived=false
        ToggleBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
        ToggleBtn.Text="❌  OFF"
        StatusLbl.Text="⏸  Paused"; TimerLbl.Text=""
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="Switch Hub V5",Text="✅ Hunting Lv.2300-2800 | 350 Speed",Duration=5
    })
end)
print("✅ Switch Hub V5 — Targeting Lv.2300-2800 | Smooth 350 Speed Ready!")
