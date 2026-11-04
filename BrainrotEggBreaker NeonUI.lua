--[[
    Brainrot Egg Breaker - Zone 1 Automation (v3 - Neon Red UI)
    - Giao diện Cyberpunk đen/đỏ neon, sidebar + nội dung
    - Nút tròn nổi 👑 để BẬT/TẮT menu (kéo thả được) + phím tắt RightShift
    - Tab: Main / Hop / Settings / Info / About
    CÁCH DÙNG:
      1) Đứng ở 1 góc bãi trứng -> "Đặt góc 1"
      2) Đi tới góc đối diện -> "Đặt góc 2"
      3) (Tuỳ chọn) "Hiện viền vùng" để kiểm tra khung
      4) Bật Bay sát đất + Tự động đập trứng
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
    HammerKeywords = { "hammer", "mallet", "bua", "búa", "smash" },
    HammerExactName = nil,

    FlightHeight = 4,
    FlightSpeed = 45,
    RowSpacing = 14,
    Margin = 6,

    SmashDelay = 0.08,
    SmashRemote = nil,
    SmashRemoteArgs = {},

    EggKeywords = { "egg", "trung", "trứng" },  -- tên (một phần) của trứng để bỏ qua khi dò mặt đất

    WalkSpeed = 32,        -- tốc độ chạy khi bật "Tăng tốc chạy" (game thường là 16). Cao quá dễ bị server kéo lại
    FastAttackRate = 12,   -- Fast Attack: số lần đánh mỗi GIÂY (cao quá server sẽ lag, nên 8-15)

    ToggleKey = Enum.KeyCode.RightShift,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = { Equip = false, Flight = false, Smash = false, Speed = false, FastAttack = false, Noclip = true }
local cornerA, cornerB
local bounds
local bodyVel
local outlineParts = {}
local conns = {}

local function getChar() return player.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function recomputeBounds()
    if not (cornerA and cornerB) then bounds = nil return end
    local m = CONFIG.Margin
    local minX = math.min(cornerA.X, cornerB.X) + m
    local maxX = math.max(cornerA.X, cornerB.X) - m
    local minZ = math.min(cornerA.Z, cornerB.Z) + m
    local maxZ = math.max(cornerA.Z, cornerB.Z) - m
    if minX >= maxX or minZ >= maxZ then bounds = nil return end
    bounds = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

----------------------------------------------------------------
-- CLEANUP CŨ (chạy lại script không bị trùng)
----------------------------------------------------------------
local env = (getgenv and getgenv()) or _G
if env.__BrainrotCleanup then pcall(env.__BrainrotCleanup) end

local parentGui
pcall(function() parentGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not parentGui then parentGui = player:WaitForChild("PlayerGui") end
local oldGui = parentGui:FindFirstChild("BrainrotEggBreakerUI")
if oldGui then oldGui:Destroy() end

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------
local RED = Color3.fromRGB(255, 38, 38)
local RED_DARK = Color3.fromRGB(190, 12, 20)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(110, 235, 120)
local YELLOW = Color3.fromRGB(255, 205, 60)
local GRAY = Color3.fromRGB(170, 170, 180)

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function stroke(o, col, th, tr)
    return new("UIStroke", {
        Color = col or RED, Thickness = th or 1.5, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local function tw(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function text(parent, props)
    local p = {
        BackgroundTransparency = 1, TextColor3 = WHITE, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
    }
    for k, v in pairs(props) do p[k] = v end
    return new("TextLabel", p, parent)
end

local function neonButton(parent, label, pos, size, kind)
    local base, hover, strokeCol
    if kind == "dark" then
        base, hover, strokeCol = Color3.fromRGB(20, 20, 25), Color3.fromRGB(40, 20, 24), Color3.fromRGB(130, 30, 36)
    else
        base, hover, strokeCol = Color3.fromRGB(150, 10, 18), Color3.fromRGB(215, 20, 28), RED
    end
    local b = new("TextButton", {
        Position = pos, Size = size, Text = label, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = WHITE, AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = base,
    }, parent)
    corner(b, 8)
    stroke(b, strokeCol, 1.5)
    b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = hover }) end)
    b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = base }) end)
    return b
end

local function panel(parent, pos, size, title)
    local f = new("Frame", {
        Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(8, 8, 10),
        BackgroundTransparency = 0.25, BorderSizePixel = 0,
    }, parent)
    corner(f, 10)
    stroke(f, Color3.fromRGB(95, 20, 26), 1.2, 0.15)
    if title then
        new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(3, 16),
            BackgroundColor3 = RED, BorderSizePixel = 0 }, f)
        text(f, { Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -24, 0, 20), Text = title, TextSize = 14 })
    end
    return f
end

local function makeDraggable(handle, target, onClick)
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onClick and not moved then onClick() end
                end
            end)
        end
    end)
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
local gui = new("ScreenGui", { Name = "BrainrotEggBreakerUI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parentGui)

local WIN_W, WIN_H = 680, 560
local PAGE_W, PAGE_H = WIN_W - 140, WIN_H - 66 - 40

local baseScale = 1
pcall(function()
    local vp = workspace.CurrentCamera.ViewportSize
    baseScale = math.clamp(math.min((vp.X - 20) / WIN_W, (vp.Y - 20) / WIN_H), 0.45, 1)
end)

local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = Color3.fromRGB(10, 10, 13),
    BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true,
}, gui)
corner(main, 14)
local mainStroke = stroke(main, RED, 2)
new("UIGradient", {
    Color = ColorSequence.new(RED, Color3.fromRGB(110, 10, 16)), Rotation = 45,
}, mainStroke)
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(34, 8, 10), Color3.fromRGB(8, 8, 11)), Rotation = 90,
}, main)
local uiScale = new("UIScale", { Scale = baseScale }, main)

-- Top bar
local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Active = true }, main)
text(topbar, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(44, 42), Text = "👑",
    TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = RED })
text(topbar, { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -190, 0, 30), RichText = true,
    Font = Enum.Font.GothamBlack, TextSize = 24,
    Text = '<i>Brainrot <font color="#ff2a2a">Egg Breaker</font></i>' })
text(topbar, { Position = UDim2.fromOffset(70, 34), Size = UDim2.new(1, -190, 0, 20), RichText = true,
    Font = Enum.Font.GothamMedium, TextSize = 14, Text = '<i>Zone 1 Automation</i>' })
new("Frame", { Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = RED, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, main)

local minBtn = neonButton(topbar, "–", UDim2.new(1, -84, 0, 14), UDim2.fromOffset(34, 30), "dark")
local closeBtn = neonButton(topbar, "✕", UDim2.new(1, -44, 0, 14), UDim2.fromOffset(34, 30), "dark")
minBtn.TextSize = 18
closeBtn.TextColor3 = RED
makeDraggable(topbar, main)

-- Footer
text(main, { Position = UDim2.new(0, 16, 1, -32), Size = UDim2.new(0.5, 0, 0, 24), RichText = true,
    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = WHITE,
    Text = '<font color="#ff2a2a">⚡</font> <i>Auto • Fast • Smooth</i>' })
text(main, { Position = UDim2.new(0.5, 0, 1, -32), Size = UDim2.new(0.5, -16, 0, 24), RichText = true,
    Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
    Text = '<font color="#ff2a2a">👑</font> <i>Made for Brainrot</i>' })

-- Sidebar
local sidebar = panel(main, UDim2.fromOffset(10, 66), UDim2.fromOffset(112, WIN_H - 66 - 40))
local pages = new("Frame", { Position = UDim2.fromOffset(130, 66), Size = UDim2.fromOffset(PAGE_W, PAGE_H),
    BackgroundTransparency = 1 }, main)

local tabDefs = {
    { "Main", "🏠" }, { "Hop", "🔁" }, { "Settings", "⚙" }, { "Info", "ℹ" }, { "About", "★" },
}
local tabButtons, pageFrames = {}, {}

local function selectTab(name)
    for n, b in pairs(tabButtons) do
        local on = (n == name)
        tw(b.btn, 0.15, { BackgroundTransparency = on and 0.55 or 1 })
        b.stroke.Transparency = on and 0 or 1
        b.icon.TextColor3 = on and RED or GRAY
        b.lbl.TextColor3 = on and RED or GRAY
        pageFrames[n].Visible = on
    end
end

for i, def in ipairs(tabDefs) do
    local name, icon = def[1], def[2]
    local btn = new("TextButton", {
        Position = UDim2.fromOffset(6, 8 + (i - 1) * 62), Size = UDim2.new(1, -12, 0, 56),
        BackgroundColor3 = RED_DARK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0,
    }, sidebar)
    corner(btn, 8)
    local st = stroke(btn, RED, 1.6, 1)
    local ic = text(btn, { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 28), Text = icon,
        TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = GRAY })
    local lb = text(btn, { Position = UDim2.fromOffset(0, 33), Size = UDim2.new(1, 0, 0, 18), Text = name,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = GRAY })
    tabButtons[name] = { btn = btn, stroke = st, icon = ic, lbl = lb }
    btn.MouseButton1Click:Connect(function() selectTab(name) end)

    local pg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, pages)
    pageFrames[name] = pg
end

----------------------------------------------------------------
-- PAGE: MAIN
----------------------------------------------------------------
local mainPage = pageFrames.Main
local leftW = 0.58

local funcPanel = panel(mainPage, UDim2.fromOffset(0, 0), UDim2.new(leftW, -4, 0, 276), "Chức Năng Chính")

local inputRange = { WalkSpeed = { 16, 500 }, FastAttackRate = { 1, 30 } }

local function makeToggle(parent, icon, label, y, key, inputKey)
    local row = new("Frame", { Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(1, -16, 0, 38),
        BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0 }, parent)
    corner(row, 8)
    stroke(row, Color3.fromRGB(50, 50, 58), 1)
    text(row, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(32, 38), Text = icon, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Center })
    text(row, { Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, inputKey and -190 or -130, 1, 0),
        Text = label, TextSize = inputKey and 13 or 14 })
    if inputKey then
        local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -88, 0.5, 0),
            Size = UDim2.fromOffset(50, 24), BackgroundColor3 = Color3.fromRGB(8, 8, 10),
            Text = tostring(CONFIG[inputKey]), TextColor3 = YELLOW, Font = Enum.Font.GothamBold, TextSize = 13,
            ClearTextOnFocus = false, BorderSizePixel = 0 }, row)
        corner(box, 6)
        stroke(box, Color3.fromRGB(130, 30, 36), 1.2)
        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            local r = inputRange[inputKey]
            if v then CONFIG[inputKey] = math.clamp(v, r[1], r[2]) end
            box.Text = tostring(CONFIG[inputKey])
        end)
    end

    local sw = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(72, 28), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(45, 45, 52) }, row)
    corner(sw, 14)
    local swStroke = stroke(sw, RED, 1.4, 1)
    local lbl = text(sw, { Size = UDim2.new(1, -26, 1, 0), Font = Enum.Font.GothamBlack, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center })
    local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = WHITE, BorderSizePixel = 0 }, sw)
    corner(knob, 11)

    local function refresh()
        local on = State[key]
        lbl.Text = on and "BẬT" or "TẮT"
        lbl.TextColor3 = on and WHITE or GRAY
        lbl.Position = on and UDim2.fromOffset(0, 0) or UDim2.fromOffset(26, 0)
        tw(knob, 0.15, { Position = on and UDim2.new(1, -25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        tw(sw, 0.15, { BackgroundColor3 = on and RED_DARK or Color3.fromRGB(45, 45, 52) })
        swStroke.Transparency = on and 0 or 1
    end
    sw.MouseButton1Click:Connect(function() State[key] = not State[key]; refresh() end)
    refresh()
end

makeToggle(funcPanel, "🔨", "Tự động cầm búa", 30, "Equip")
makeToggle(funcPanel, "🕊", "Bay sát đất Zone 1", 70, "Flight")
makeToggle(funcPanel, "💥", "Tự động đập trứng", 110, "Smash")
makeToggle(funcPanel, "🏃", "Tăng tốc chạy", 150, "Speed", "WalkSpeed")
makeToggle(funcPanel, "⚡", "Fast Attack /s", 190, "FastAttack", "FastAttackRate")
makeToggle(funcPanel, "👻", "Bay xuyên trứng", 230, "Noclip")

local zonePanel = panel(mainPage, UDim2.fromOffset(0, 284), UDim2.new(leftW, -4, 0, PAGE_H - 284), "Đặt Vùng Bay")
local btnA = neonButton(zonePanel, "📍 Đặt góc 1", UDim2.fromOffset(8, 32), UDim2.new(0.5, -12, 0, 34), "red")
local btnB = neonButton(zonePanel, "📍 Đặt góc 2", UDim2.new(0.5, 4, 0, 32), UDim2.new(0.5, -12, 0, 34), "red")
local btnShow = neonButton(zonePanel, "👁 Hiện viền vùng", UDim2.fromOffset(8, 74), UDim2.new(1, -16, 0, 34), "dark")
local btnReset = neonButton(zonePanel, "🗑 Xóa vùng", UDim2.fromOffset(8, 116), UDim2.new(1, -16, 0, 34), "red")

-- Right: zone info
local infoPanel = panel(mainPage, UDim2.new(leftW, 4, 0, 0), UDim2.new(1 - leftW, -4, 0, 236), "Thông Tin Vùng")
text(infoPanel, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 18), Text = "Kích thước vùng:",
    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = GRAY })
local sizeLabel = text(infoPanel, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 30),
    Text = "XXX x XXX studs", TextSize = 20, TextColor3 = RED, Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Center })
local checkLabel = text(infoPanel, { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 20),
    Text = "✗ Chưa đặt vùng", TextSize = 13, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Center })

local preview = new("Frame", { Position = UDim2.fromOffset(12, 110), Size = UDim2.new(1, -24, 0, 116),
    BackgroundColor3 = Color3.fromRGB(40, 6, 8), BorderSizePixel = 0 }, infoPanel)
corner(preview, 6)
local previewStroke = stroke(preview, Color3.fromRGB(110, 25, 30), 1.6)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 8, 12), Color3.fromRGB(14, 6, 8)), Rotation = 90 }, preview)
local cornerSquares = {}
for _, a in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local sq = new("Frame", { AnchorPoint = Vector2.new(a[1], a[2]), Position = UDim2.fromScale(a[1], a[2]),
        Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(110, 25, 30), BorderSizePixel = 0 }, preview)
    table.insert(cornerSquares, sq)
end

local statusPanel = panel(mainPage, UDim2.new(leftW, 4, 0, 244), UDim2.new(1 - leftW, -4, 0, PAGE_H - 244), nil)
text(statusPanel, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), Text = "〰 Trạng Thái:", TextSize = 14 })
local statusValue = text(statusPanel, { Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -40),
    Text = "Đang đứng yên", TextSize = 19, TextColor3 = GREEN, Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })

local function clearOutline()
    for _, p in ipairs(outlineParts) do p:Destroy() end
    outlineParts = {}
end

local function drawOutline()
    clearOutline()
    if not bounds then return end
    local hrp = getHRP()
    local y = hrp and hrp.Position.Y or 5
    local pts = {
        Vector3.new(bounds.minX, y, bounds.minZ), Vector3.new(bounds.maxX, y, bounds.minZ),
        Vector3.new(bounds.maxX, y, bounds.maxZ), Vector3.new(bounds.minX, y, bounds.maxZ),
    }
    for i = 1, 4 do
        local a, b = pts[i], pts[i % 4 + 1]
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(255, 60, 60)
        p.Transparency = 0.3
        p.Size = Vector3.new(0.5, 0.5, (b - a).Magnitude)
        p.CFrame = CFrame.lookAt((a + b) / 2, b)
        p.Parent = workspace
        table.insert(outlineParts, p)
    end
end

local refreshZone
function refreshZone()
    recomputeBounds()
    btnA.Text = cornerA and "✓ Góc 1 đã đặt" or "📍 Đặt góc 1"
    btnB.Text = cornerB and "✓ Góc 2 đã đặt" or "📍 Đặt góc 2"
    local ok = bounds ~= nil
    if ok then
        sizeLabel.Text = string.format("%d x %d studs", math.floor(bounds.maxX - bounds.minX), math.floor(bounds.maxZ - bounds.minZ))
        checkLabel.Text = "✓ Đã đặt vùng"
    elseif cornerA and cornerB then
        sizeLabel.Text = string.format("%d x %d studs", math.floor(math.abs(cornerA.X - cornerB.X)), math.floor(math.abs(cornerA.Z - cornerB.Z)))
        checkLabel.Text = "! Vùng quá nhỏ (giảm Margin)"
    elseif cornerA or cornerB then
        sizeLabel.Text = "XXX x XXX studs"
        checkLabel.Text = "! Cần đặt đủ 2 góc"
    else
        sizeLabel.Text = "XXX x XXX studs"
        checkLabel.Text = "✗ Chưa đặt vùng"
    end
    local col = ok and GREEN or ((cornerA or cornerB) and YELLOW or RED)
    sizeLabel.TextColor3 = ok and WHITE or RED
    checkLabel.TextColor3 = col
    previewStroke.Color = ok and RED or Color3.fromRGB(110, 25, 30)
    for _, sq in ipairs(cornerSquares) do sq.BackgroundColor3 = ok and RED or Color3.fromRGB(110, 25, 30) end
end

btnA.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then cornerA = hrp.Position; refreshZone(); if #outlineParts > 0 then drawOutline() end end
end)
btnB.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then cornerB = hrp.Position; refreshZone(); if #outlineParts > 0 then drawOutline() end end
end)
btnShow.MouseButton1Click:Connect(function()
    if #outlineParts > 0 then clearOutline() else drawOutline() end
end)
btnReset.MouseButton1Click:Connect(function()
    cornerA, cornerB, bounds = nil, nil, nil
    clearOutline()
    refreshZone()
end)
refreshZone()

----------------------------------------------------------------
-- PAGE: HOP (server hop)
----------------------------------------------------------------
local hopPage = pageFrames.Hop
text(hopPage, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(40, 40), Text = "🔁", TextSize = 28,
    TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = RED })
text(hopPage, { Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -170, 0, 26), Text = "Server Hop",
    Font = Enum.Font.GothamBlack, TextSize = 22 })
text(hopPage, { Position = UDim2.fromOffset(48, 26), Size = UDim2.new(1, -170, 0, 18),
    Text = "Tìm server phù hợp và dịch chuyển ngay!", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = GRAY })
local refreshBtn = neonButton(hopPage, "⟳ Làm mới", UDim2.new(1, -112, 0, 4), UDim2.fromOffset(108, 34), "dark")

local banner = new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Color3.fromRGB(30, 5, 8), BackgroundTransparency = 0.2, BorderSizePixel = 0 }, hopPage)
corner(banner, 8)
stroke(banner, RED, 1.6)
text(banner, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), RichText = true, TextWrapped = true,
    Font = Enum.Font.GothamMedium, TextSize = 12,
    Text = '<font color="#ff2a2a">⚠ LƯU Ý:</font> Script không đọc được trứng của server khác. Danh sách xếp theo <font color="#ffcd3c">ping thấp nhất</font> (còn chỗ trống).' })

local headY = 112
local colX = { 0.02, 0.45, 0.65, 0.80 }
local heads = { "Tên Server / ID", "Người chơi", "Ping", "Hành động" }
for i, h in ipairs(heads) do
    text(hopPage, { Position = UDim2.new(colX[i], 0, 0, headY), Size = UDim2.new(0.3, 0, 0, 20), Text = h,
        TextSize = 12, TextColor3 = GRAY })
end

local listFrame = new("ScrollingFrame", {
    Position = UDim2.fromOffset(0, headY + 24), Size = UDim2.new(1, 0, 0, PAGE_H - headY - 24 - 34),
    BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.25, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = RED, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, hopPage)
corner(listFrame, 8)
stroke(listFrame, Color3.fromRGB(95, 20, 26), 1.2, 0.15)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, listFrame)

local hopFooter = new("Frame", { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1 }, hopPage)
local scanLabel = text(hopFooter, { Size = UDim2.new(0.55, 0, 1, 0), Text = "Chưa quét", TextSize = 12, TextColor3 = GRAY })
local marqClip = new("Frame", { Position = UDim2.fromScale(0.55, 0), Size = UDim2.fromScale(0.45, 1),
    BackgroundTransparency = 1, ClipsDescendants = true }, hopFooter)
local marq = text(marqClip, { Size = UDim2.fromOffset(260, 28), Text = ">>> Hop ngay để không bỏ lỡ! <<<",
    TextSize = 12, TextColor3 = RED })

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then return res end
    local req = (syn and syn.request) or http_request or request
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and r and r.Body then return r.Body end
    end
end

local scanning = false
local function clearRows()
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
end

local function addRow(idx, s)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = idx,
        BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0 }, listFrame)
    corner(row, 6)
    text(row, { Position = UDim2.new(colX[1], 0, 0, 2), Size = UDim2.new(0.4, 0, 0, 18),
        Text = "🥚 Server #" .. idx, TextSize = 13 })
    text(row, { Position = UDim2.new(colX[1], 0, 0, 19), Size = UDim2.new(0.4, 0, 0, 16),
        Text = string.sub(s.id, 1, 13) .. "…", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = GRAY })
    text(row, { Position = UDim2.new(colX[2], 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0),
        Text = string.format("%d/%d", s.playing or 0, s.maxPlayers or 0), TextSize = 13, TextColor3 = YELLOW })
    text(row, { Position = UDim2.new(colX[3], 0, 0, 0), Size = UDim2.new(0.15, 0, 1, 0),
        Text = s.ping and (tostring(math.floor(s.ping)) .. " ms") or "?", TextSize = 13, TextColor3 = GREEN })
    local hop = neonButton(row, "Hop Ngay >", UDim2.new(colX[4], 0, 0.5, -14), UDim2.new(0.19, 0, 0, 28), "red")
    hop.TextSize = 12
    hop.MouseButton1Click:Connect(function()
        hop.Text = "Đang hop…"
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
        end)
        if not ok then
            hop.Text = "Lỗi!"
            warn("[Hop] " .. tostring(err))
            task.delay(1.5, function() if hop.Parent then hop.Text = "Hop Ngay >" end end)
        end
    end)
end

local function scanServers()
    if scanning then return end
    scanning = true
    scanLabel.Text = "Đang quét server…"
    clearRows()
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local body = httpGet(url)
    local list = {}
    if body then
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
                    table.insert(list, s)
                end
            end
        end
    end
    table.sort(list, function(a, b) return (a.ping or 9e9) < (b.ping or 9e9) end)
    for i, s in ipairs(list) do
        if i > 40 then break end
        addRow(i, s)
    end
    scanLabel.Text = string.format("Đã quét %d server  •  Cập nhật: %s", #list, os.date("%H:%M:%S"))
    if #list == 0 then scanLabel.Text = "Không lấy được danh sách (kiểm tra executor/HttpGet)" end
    scanning = false
end

refreshBtn.MouseButton1Click:Connect(function() task.spawn(scanServers) end)

task.spawn(function()
    while gui.Parent do
        marq.Position = UDim2.new(1, 0, 0, 0)
        local t = TweenService:Create(marq, TweenInfo.new(7, Enum.EasingStyle.Linear),
            { Position = UDim2.new(0, -260, 0, 0) })
        t:Play()
        t.Completed:Wait()
    end
end)

----------------------------------------------------------------
-- PAGE: SETTINGS
----------------------------------------------------------------
local setPage = pageFrames.Settings
local setPanel = panel(setPage, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 300), "Cài đặt nâng cao")

local function numRow(label, y, key, min, max)
    local row = new("Frame", { Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(1, -16, 0, 36),
        BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0 }, setPanel)
    corner(row, 8)
    text(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 1, 0), Text = label, TextSize = 13 })
    local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(86, 26), BackgroundColor3 = Color3.fromRGB(8, 8, 10), Text = tostring(CONFIG[key]),
        TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 13, ClearTextOnFocus = false,
        BorderSizePixel = 0 }, row)
    corner(box, 6)
    stroke(box, Color3.fromRGB(130, 30, 36), 1.2)
    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v then CONFIG[key] = math.clamp(v, min, max) end
        box.Text = tostring(CONFIG[key])
        if key == "Margin" then
            refreshZone()
            if #outlineParts > 0 then drawOutline() end
        end
    end)
end

numRow("Độ cao bay (studs)", 32, "FlightHeight", 1, 30)
numRow("Tốc độ bay", 74, "FlightSpeed", 10, 120)
numRow("Khoảng cách hàng quét", 116, "RowSpacing", 4, 40)
numRow("Đệm an toàn Margin", 158, "Margin", 0, 30)
numRow("Delay đập (giây)", 200, "SmashDelay", 0.02, 1)

local hammerRow = new("Frame", { Position = UDim2.new(0, 8, 0, 242), Size = UDim2.new(1, -16, 0, 36),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0 }, setPanel)
corner(hammerRow, 8)
text(hammerRow, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -180, 1, 0), Text = "Tên búa chính xác", TextSize = 13 })
local hammerBox = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(150, 26), BackgroundColor3 = Color3.fromRGB(8, 8, 10), Text = "",
    PlaceholderText = "(để trống = tự dò)", PlaceholderColor3 = GRAY, TextColor3 = WHITE,
    Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false, BorderSizePixel = 0 }, hammerRow)
corner(hammerBox, 6)
stroke(hammerBox, Color3.fromRGB(130, 30, 36), 1.2)
hammerBox.FocusLost:Connect(function()
    CONFIG.HammerExactName = (hammerBox.Text ~= "") and hammerBox.Text or nil
end)

----------------------------------------------------------------
-- PAGE: INFO / ABOUT
----------------------------------------------------------------
local infoPage = panel(pageFrames.Info, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), "Hướng dẫn")
text(infoPage, { Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 1, -44), RichText = true,
    TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextSize = 14,
    Text = '<font color="#ff2a2a">1.</font> Đứng ở 1 góc bãi trứng (sát lằng trắng, phía trong) → <b>Đặt góc 1</b>.\n\n'
        .. '<font color="#ff2a2a">2.</font> Đi tới góc đối diện (chéo) → <b>Đặt góc 2</b>.\n\n'
        .. '<font color="#ff2a2a">3.</font> Bấm <b>Hiện viền vùng</b> để kiểm tra khung.\n\n'
        .. '<font color="#ff2a2a">4.</font> Bật <b>Bay sát đất</b> + <b>Tự động đập trứng</b>.\n\n'
        .. 'Nhân vật bị khóa cứng trong khung (có đệm Margin).\n\n'
        .. '<font color="#ffcd3c">Bay xuyên trứng:</font> tắt va chạm khi bay, không bị vướng trứng (mặc định BẬT).\n'
        .. '<font color="#ffcd3c">Tăng tốc chạy:</font> nhập số vào ô cạnh công tắc (16-500).\n'
        .. '<font color="#ffcd3c">Fast Attack:</font> nhập số lần đánh mỗi giây (1-30, nên 8-15). Cao quá server sẽ lag và trứng vỡ trễ.\n\n'
        .. '<font color="#ffcd3c">Phím tắt:</font> RightShift hoặc nút 👑 để ẩn/hiện menu.' })

local aboutPage = panel(pageFrames.About, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), "Giới thiệu")
text(aboutPage, { Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 1, -44), RichText = true,
    TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextSize = 14,
    Text = '<font color="#ff2a2a"><b>Brainrot Egg Breaker</b></font> - Zone 1 Automation\nPhiên bản: v3 (Neon Red UI)\n\n'
        .. 'Tự cầm búa • Bay quét kín vùng • Tự đập trứng • Server Hop.' })

----------------------------------------------------------------
-- TOGGLE UI (nút nổi + phím tắt)
----------------------------------------------------------------
local uiVisible = true
local function setVisible(v)
    uiVisible = v
    if v then
        uiScale.Scale = baseScale * 0.9
        main.Visible = true
        TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = baseScale }):Play()
    else
        main.Visible = false
    end
end

local floatBtn = new("TextButton", {
    Name = "ToggleUI", Position = UDim2.new(0, 16, 0.5, -24), Size = UDim2.fromOffset(48, 48),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18), Text = "👑", TextSize = 24, Font = Enum.Font.GothamBold,
    TextColor3 = RED, AutoButtonColor = false, BorderSizePixel = 0, Active = true,
}, gui)
corner(floatBtn, 24)
local fbStroke = stroke(floatBtn, RED, 2)
new("UIGradient", { Color = ColorSequence.new(RED, Color3.fromRGB(100, 8, 14)), Rotation = 45 }, fbStroke)
makeDraggable(floatBtn, floatBtn, function() setVisible(not uiVisible) end)

minBtn.MouseButton1Click:Connect(function() setVisible(false) end)

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == CONFIG.ToggleKey then setVisible(not uiVisible) end
end))

selectTab("Main")

----------------------------------------------------------------
-- A. AUTO EQUIP HAMMER
----------------------------------------------------------------
local function isHammer(tool)
    if not tool:IsA("Tool") then return false end
    if CONFIG.HammerExactName then return tool.Name == CONFIG.HammerExactName end
    local n = string.lower(tool.Name)
    for _, k in ipairs(CONFIG.HammerKeywords) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

local function findHammer()
    local char = getChar()
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if isHammer(t) then return t, true end
        end
    end
    for _, t in ipairs(player.Backpack:GetChildren()) do
        if isHammer(t) then return t, false end
    end
end

task.spawn(function()
    while gui.Parent do
        if State.Equip then
            pcall(function()
                local tool, equipped = findHammer()
                local hum = getChar() and getChar():FindFirstChildOfClass("Humanoid")
                if tool and not equipped and hum then hum:EquipTool(tool) end
            end)
        end
        task.wait(0.5)
    end
end)

----------------------------------------------------------------
-- B. AUTO FLIGHT (quét kín vùng, khóa cứng trong ranh giới)
----------------------------------------------------------------
local function buildWaypoints(b)
    local pts = {}
    local z = b.minZ
    local dir = 1
    while z <= b.maxZ do
        local xa, xb = b.minX, b.maxX
        if dir == -1 then xa, xb = xb, xa end
        table.insert(pts, Vector3.new(xa, 0, z))
        table.insert(pts, Vector3.new(xb, 0, z))
        z = z + CONFIG.RowSpacing
        dir = -dir
    end
    if pts[#pts].Z < b.maxZ - 0.1 then
        local last = pts[#pts]
        table.insert(pts, Vector3.new(last.X, 0, b.maxZ))
        table.insert(pts, Vector3.new(last.X == b.minX and b.maxX or b.minX, 0, b.maxZ))
    end
    for i = #pts - 1, 1, -1 do table.insert(pts, pts[i]) end
    return pts
end

local function isEggPart(inst)
    local cur = inst
    for _ = 1, 6 do
        if not cur or cur == workspace then break end
        local n = string.lower(cur.Name)
        for _, k in ipairs(CONFIG.EggKeywords) do
            if string.find(n, k, 1, true) then return true end
        end
        cur = cur.Parent
    end
    return false
end

-- Dò mặt đất: bỏ qua trứng, người chơi khác và part không va chạm để không bị nâng lên khi bay qua trứng
local function groundY(pos, char)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    local ex = { char }
    for _, p in ipairs(outlineParts) do table.insert(ex, p) end
    params.FilterDescendantsInstances = ex
    local origin = Vector3.new(pos.X, pos.Y + 50, pos.Z)
    for _ = 1, 8 do
        local res = workspace:Raycast(origin, Vector3.new(0, -250, 0), params)
        if not res then return nil end
        local hit = res.Instance
        local model = hit:FindFirstAncestorOfClass("Model")
        local skip = (State.Noclip and isEggPart(hit))
            or (model and model:FindFirstChildOfClass("Humanoid") ~= nil)
        if not skip then return res.Position.Y end
        table.insert(ex, hit)
        params.FilterDescendantsInstances = ex
    end
    return nil
end

-- NOCLIP: tắt va chạm nhân vật khi đang bay, trả lại như cũ khi dừng
local savedCollide = {}
local function setNoclip(on)
    if on then
        local char = getChar()
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                savedCollide[d] = true
                d.CanCollide = false
            end
        end
    else
        for part in pairs(savedCollide) do
            if part.Parent then part.CanCollide = true end
            savedCollide[part] = nil
        end
    end
end

table.insert(conns, RunService.Stepped:Connect(function()
    if State.Flight and State.Noclip and bounds then
        setNoclip(true)
    elseif next(savedCollide) then
        setNoclip(false)
    end
end))

local waypoints, wpIndex, lastY, lastBoundsKey

local function stopFlight()
    if bodyVel then bodyVel:Destroy() bodyVel = nil end
    local hum = getChar() and getChar():FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    waypoints = nil
    setNoclip(false)
end

local function flightStep(dt)
    if not State.Flight or not bounds then
        if bodyVel then stopFlight() end
        return
    end
    local char, hrp = getChar(), getHRP()
    if not char or not hrp then return end

    -- (đã sửa: dùng %.1f vì %d lỗi khi toạ độ có phần thập phân)
    local key = string.format("%.1f_%.1f_%.1f_%.1f", bounds.minX, bounds.maxX, bounds.minZ, bounds.maxZ)
    if key ~= lastBoundsKey then waypoints = nil lastBoundsKey = key end

    local p = hrp.Position
    local cx = math.clamp(p.X, bounds.minX, bounds.maxX)
    local cz = math.clamp(p.Z, bounds.minZ, bounds.maxZ)

    if not waypoints then
        waypoints = buildWaypoints(bounds)
        local best, bd = 1, math.huge
        for i, w in ipairs(waypoints) do
            local d = (Vector2.new(w.X, w.Z) - Vector2.new(cx, cz)).Magnitude
            if d < bd then best, bd = i, d end
        end
        wpIndex = best
        lastY = p.Y
    end

    if not bodyVel or bodyVel.Parent ~= hrp then
        if bodyVel then bodyVel:Destroy() end
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVel.Velocity = Vector3.zero
        bodyVel.Parent = hrp
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    local gy = groundY(p, char)
    local targetY = (gy and gy + CONFIG.FlightHeight) or lastY
    lastY = targetY
    local vy = math.clamp((targetY - p.Y) * 8, -60, 60)

    -- Chỉ điều khiển bằng vận tốc (BodyVelocity), KHÔNG ghi CFrame mỗi khung hình -> hết giật
    local vx, vz = 0, 0
    local outside = (p.X ~= cx) or (p.Z ~= cz)
    if outside then
        local toIn = Vector3.new(cx - p.X, 0, cz - p.Z)
        local d = toIn.Magnitude
        if d > 80 then
            -- lệch quá xa (lag/bị đẩy): đưa về ngay, giữ nguyên hướng xoay
            hrp.CFrame = CFrame.new(cx, p.Y, cz) * (hrp.CFrame - hrp.CFrame.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
        elseif d > 0 then
            -- bay mượt về lại điểm gần nhất trong vùng
            local spd = math.min(CONFIG.FlightSpeed, d / math.max(dt, 1 / 120))
            local u = toIn.Unit
            vx, vz = u.X * spd, u.Z * spd
        end
    else
        local wp = waypoints[wpIndex]
        local flat = Vector3.new(wp.X - p.X, 0, wp.Z - p.Z)
        if flat.Magnitude < 3 then
            wpIndex = wpIndex % #waypoints + 1
        end
        if flat.Magnitude > 0.1 then
            local u = flat.Unit
            vx, vz = u.X * CONFIG.FlightSpeed, u.Z * CONFIG.FlightSpeed
        end
        -- khóa cứng: bước kế tiếp mà vượt biên thì triệt tiêu thành phần đó
        local nx, nz = p.X + vx * dt * 2, p.Z + vz * dt * 2
        if nx < bounds.minX or nx > bounds.maxX then vx = 0 end
        if nz < bounds.minZ or nz > bounds.maxZ then vz = 0 end
    end
    bodyVel.Velocity = Vector3.new(vx, vy, vz)
end

local lastFlightErr
table.insert(conns, RunService.Heartbeat:Connect(function(dt)
    local ok, err = pcall(flightStep, dt)
    if not ok and err ~= lastFlightErr then
        lastFlightErr = err
        warn("[Flight] " .. tostring(err))
    end
end))

----------------------------------------------------------------
-- C. AUTO SMASH
----------------------------------------------------------------
local function swingOnce()
    if CONFIG.SmashRemote then
        CONFIG.SmashRemote:FireServer(table.unpack(CONFIG.SmashRemoteArgs))
    end
    local char = getChar()
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
    VirtualUser:CaptureController()
    VirtualUser:Button1Down(Vector2.new(0, 0))
    VirtualUser:Button1Up(Vector2.new(0, 0))
end

-- Đánh theo NHỊP CỐ ĐỊNH (lần/giây), không dồn lệnh -> server không bị tồn hàng đợi, không lag.
-- Nếu bị chậm khung hình thì bỏ lượt thừa thay vì đánh bù một loạt.
local swingAcc = 0
table.insert(conns, RunService.Heartbeat:Connect(function(dt)
    if not State.Smash then swingAcc = 0 return end
    local rate = State.FastAttack and CONFIG.FastAttackRate or (1 / math.max(CONFIG.SmashDelay, 0.02))
    local interval = 1 / rate
    swingAcc = swingAcc + math.min(dt, 0.1)
    local n = 0
    while swingAcc >= interval and n < 2 do
        swingAcc = swingAcc - interval
        n = n + 1
        pcall(swingOnce)
    end
    if swingAcc > interval * 2 then swingAcc = 0 end
end))

-- Fast Attack: tăng tốc animation vung búa cho khớp nhịp đánh (bỏ qua animation đi/đứng)
table.insert(conns, RunService.Heartbeat:Connect(function()
    if not State.FastAttack then return end
    local animSpeed = math.clamp(CONFIG.FastAttackRate / 3, 1, 6)
    local char = getChar()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local pr = track.Priority
        if pr ~= Enum.AnimationPriority.Core and pr ~= Enum.AnimationPriority.Idle
            and pr ~= Enum.AnimationPriority.Movement then
            if track.Speed ~= animSpeed then track:AdjustSpeed(animSpeed) end
        end
    end
end))

----------------------------------------------------------------
-- D. SPEED BOOST (tăng tốc chạy)
----------------------------------------------------------------
-- Không đụng vào WalkSpeed và không ghi đè vận tốc (humanoid sẽ giành lại -> giật).
-- Humanoid vẫn chạy với tốc độ gốc của game; script chỉ cộng thêm phần "chênh lệch" bằng cách
-- dịch nhân vật theo từng khung hình (RenderStepped, theo dt) nên hình ảnh mượt.
-- Có tăng dần trong 0.25s (không bật vọt gây server kéo lại) và kiểm tra tường phía trước.
local speedBlend = 0
local speedCap = 1        -- hệ số an toàn: tự giảm khi bị server kéo lại, hồi rất chậm
local lastPos            -- vị trí cuối khung hình trước (để phát hiện bị kéo lùi)
local normalWS           -- WalkSpeed "bình thường" của game (giá trị cao nhất đã thấy)
local speedRay = RaycastParams.new()
speedRay.FilterType = Enum.RaycastFilterType.Exclude
speedRay.RespectCanCollide = true

table.insert(conns, player.CharacterAdded:Connect(function()
    normalWS, lastPos, speedBlend, speedCap = nil, nil, 0, 1
end))

table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    dt = math.min(dt, 1 / 20)
    local char = getChar()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = getHRP()
    local active = State.Speed and hum and hrp and hum.Health > 0 and not hum.Sit
        and not (State.Flight and bounds) -- đang bay thì chế độ bay tự điều khiển
    local dir = active and hum.MoveDirection or Vector3.zero
    if not active or dir.Magnitude < 0.05 then speedBlend = 0 lastPos = nil return end
    dir = Vector3.new(dir.X, 0, dir.Z).Unit

    -- Phát hiện bị server kéo lùi (rubber-band): vị trí lùi > 1.5 studs so với hướng đang đi
    if lastPos then
        local moved = hrp.Position - lastPos
        local back = -(moved.X * dir.X + moved.Z * dir.Z)
        if back > 1.5 then
            speedCap = speedCap * 0.6   -- giảm ngay, tự dò ra mức server chấp nhận
            if speedCap < 0.05 then speedCap = 0 end
        end
    end
    speedCap = math.min(1, speedCap + dt * 0.003)

    -- Tỉ lệ theo WalkSpeed hiện tại: ôm pet/bị làm chậm thì phần cộng thêm cũng nhỏ lại tương ứng
    local ws = hum.WalkSpeed
    if not normalWS or ws > normalWS then normalWS = ws end
    local target = CONFIG.WalkSpeed * (ws / math.max(normalWS, 1))

    speedBlend = math.min(1, speedBlend + dt / 0.25)
    local extra = math.max(0, target - ws) * speedBlend * speedCap
    if extra <= 0 then lastPos = hrp.Position return end

    local step = dir * extra * dt
    speedRay.FilterDescendantsInstances = { char }
    if workspace:Raycast(hrp.Position, dir * (step.Magnitude + 2), speedRay) then
        lastPos = hrp.Position
        return -- có tường
    end

    hrp.CFrame = hrp.CFrame + step
    lastPos = hrp.Position
end))

----------------------------------------------------------------
-- STATUS
----------------------------------------------------------------
task.spawn(function()
    while gui.Parent do
        local txt, col = "Đang đứng yên", GREEN
        if State.Flight and not bounds then
            txt, col = "Chưa đặt vùng bay!", YELLOW
        elseif State.Flight and State.Smash then
            txt = "Bay sát đất + đập trứng"
        elseif State.Smash then
            txt = "Đang đập trứng"
        elseif State.Flight then
            txt = "Đang bay sát mặt đất"
        end
        local extra = {}
        if State.Speed then table.insert(extra, "⚡ Speed " .. CONFIG.WalkSpeed) end
        if State.FastAttack then table.insert(extra, "🔥 Fast " .. CONFIG.FastAttackRate .. "/s") end
        if #extra > 0 then txt = txt .. "\n" .. table.concat(extra, "  ") end
        statusValue.Text = txt
        statusValue.TextColor3 = col
        task.wait(0.3)
    end
end)

table.insert(conns, player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

----------------------------------------------------------------
-- CLOSE / CLEANUP
----------------------------------------------------------------
local function destroyAll()
    State.Equip, State.Flight, State.Smash = false, false, false
    pcall(stopFlight)
    clearOutline()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if gui then gui:Destroy() end
end
env.__BrainrotCleanup = destroyAll
closeBtn.MouseButton1Click:Connect(destroyAll)

task.spawn(scanServers)
