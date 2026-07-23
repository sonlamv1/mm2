if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Environment = type(getgenv) == "function" and getgenv() or _G

Environment.MM2UICleanerConfig = Environment.MM2UICleanerConfig or {
    -- Chờ MainGUI được game tạo xong trước khi dọn UI loading/menu.
    WaitForMainGUI = true,
    MainGUIWaitTimeout = 30,

    -- Destroy mọi game GUI không nằm trong danh sách code-critical bên dưới.
    RemoveUnusedGameUI = true,
    RemoveWorldUI = true,

    -- Tắt UI mặc định Roblox nhưng không đụng GUI executor lạ trong CoreGui.
    DisableRobloxCoreUI = true,
    CoreGuiRefreshRate = 1,

    -- Giữ code điều khiển vũ khí/phím bấm nhưng ẩn phần hiển thị của chúng.
    PreserveControlCode = true,

    -- Thêm tên GUI riêng cần giữ nguyên và vẫn cho hiển thị tại đây.
    -- Ví dụ: ["MyOverlay"] = true
    KeepGuiNames = {},

    -- Tùy chọn giảm lag ngoài UI.
    RemoveEffects = true,
    RemoveTextures = true,
    SimplifyParts = true,
    MuteSounds = true,
}

local Config = Environment.MM2UICleanerConfig

-- GUI được source game gọi trực tiếp hoặc clone làm template.
-- Không Destroy những tên này; chỉ khóa hiển thị để code vẫn hoạt động.
local CodeCriticalGuiNames = {
    -- UI chính. UISelector sẽ clone lại liên tục nếu bị xóa.
    MainGUI = "UISelector recreates this GUI when removed",

    -- Module gameplay gọi trực tiếp qua PlayerGui.
    TradeGUI = "TradeModule and Trading access this hierarchy directly",
    Scoreboard = "ScoreboardModule accesses this hierarchy directly",
    Scoreboard_Phone = "ScoreboardModule uses this on phone/tablet",
    SpawnFade = "FadeModule indexes SpawnFade.Fade directly",
    CameraFade = "FadeModule waits for CameraFade.Fade",
    Fade = "FadeService/FadeModule use this GUI",
    TouchInteractButtons = "InteractiveScript waits for this GUI",
    InteractGUI = "InteractiveScript waits for and updates this BillboardGui",

    -- GUI động được code chờ trực tiếp trong PlayerGui.
    Gifter = "Gifter LocalScript waits for this GUI",
    ESP = "MainGUI leaderboard code accesses PlayerGui.ESP",
    NewUI2025 = "UISelector/LoadingScript reference this GUI",

    -- Template nằm dưới gameplay scripts.
    DeathFade = "GameplayAnimations clones this template",
    Victory = "GameplayAnimations clones this template",
    TrapGUI = "TrapScriptClient clones this template",
    StatusEffectGui = "Status effect template kept for code safety",
    TrapBillboard = "TrapScriptClient clones this template",
    TrappedBillboard = "TrapScriptClient clones this template",
    TeamMate = "GameModes/Duel code clones this template",
    PetTag = "Pets script clones this template",
    NameTag = "Runtime name of the cloned PetTag",

    -- Box/opening animation templates referenced directly by modules.
    Unboxing = "BoxModule uses this template",
    Unboxing2 = "BoxModule uses this template",
    Hatching = "BoxModule uses this template",
    MysteryBoxOpen = "MysteryBoxService uses this template",
}

-- Các UI điều khiển có code liên quan đến equip/tool/input.
-- Chúng vẫn chạy nhưng hoàn toàn không render.
local ControlCodeGuiNames = {
    InputContext = true,
    BackpackUI = true,
    GameplayControlsUI = true,
}

-- Tên/prefix thường dùng bởi Roblox CoreGui.
-- Chỉ ẩn các root này trong CoreGui để tránh xóa nhầm UI executor.
local RobloxCoreGuiNames = {
    RobloxGui = true,
    RobloxPromptGui = true,
    RobloxLoadingGui = true,
    RobloxNetworkPauseNotification = true,
    PurchasePrompt = true,
    PurchasePromptApp = true,
    ExperienceChat = true,
    BubbleChat = true,
    Chat = true,
    PlayerList = true,
    Backpack = true,
    Health = true,
    EmotesMenu = true,
    VoiceChatPromptGui = true,
    DevConsoleMaster = true,
    TopBarApp = true,
    CaptureModeGui = true,
    ToastNotification = true,
    ScreenshotHud = true,
    SelfView = true,
    VRApp = true,
}

local Suppressed = setmetatable({}, { __mode = "k" })
local Deleted = setmetatable({}, { __mode = "k" })
local DeletedCount = 0
local HiddenCount = 0

local function isLayerCollector(Instance)
    return Instance and Instance:IsA("LayerCollector")
end

local function hasLayerCollectorAncestor(Instance)
    local Parent = Instance.Parent

    while Parent do
        if Parent:IsA("LayerCollector") then
            return true
        end

        Parent = Parent.Parent
    end

    return false
end

local function isKeptByUser(Instance)
    return Config.KeepGuiNames
        and Config.KeepGuiNames[Instance.Name] == true
end

local function isRobloxCoreRoot(Instance)
    if RobloxCoreGuiNames[Instance.Name] then
        return true
    end

    local LowerName = string.lower(Instance.Name)

    -- CoreGui chính thức thường bắt đầu bằng Roblox.
    if string.sub(LowerName, 1, 6) == "roblox" then
        return true
    end

    return LowerName == "touchgui"
        or LowerName == "controlgui"
        or string.find(LowerName, "playerlist", 1, true) ~= nil
        or string.find(LowerName, "bubblechat", 1, true) ~= nil
        or string.find(LowerName, "experiencechat", 1, true) ~= nil
end

local function getCodeProtectionReason(Instance)
    if isKeptByUser(Instance) then
        return "kept by user configuration"
    end

    local Reason = CodeCriticalGuiNames[Instance.Name]
    if Reason then
        return Reason
    end

    if Config.PreserveControlCode and ControlCodeGuiNames[Instance.Name] then
        return "input/tool control code uses this GUI"
    end

    -- MainXbox chỉ cần giữ nếu người chơi thực sự đang ở giao diện console.
    if Instance.Name == "MainXbox" and GuiService:IsTenFootInterface() then
        return "console UI selected by UISelector"
    end

    return nil
end

local function forceDisableLayerCollector(Instance)
    if not Instance or not Instance.Parent then
        return
    end

    pcall(function()
        if Instance.Enabled then
            Instance.Enabled = false
        end
    end)
end

local function suppressLayerCollector(Instance, Reason)
    if Suppressed[Instance] then
        forceDisableLayerCollector(Instance)
        return
    end

    Suppressed[Instance] = Reason or true
    HiddenCount = HiddenCount + 1
    forceDisableLayerCollector(Instance)

    -- Game thường bật lại TradeGUI, Scoreboard, InteractGUI... nên khóa liên tục.
    pcall(function()
        Instance:GetPropertyChangedSignal("Enabled"):Connect(function()
            if Instance.Parent and Instance.Enabled then
                task.defer(forceDisableLayerCollector, Instance)
            end
        end)
    end)

    Instance.AncestryChanged:Connect(function(_, Parent)
        if Parent then
            task.defer(forceDisableLayerCollector, Instance)
        end
    end)
end

local function disableScriptsInside(Instance)
    for _, Descendant in ipairs(Instance:GetDescendants()) do
        if Descendant:IsA("LocalScript") or Descendant:IsA("Script") then
            pcall(function()
                Descendant.Disabled = true
            end)
        elseif Descendant:IsA("VideoFrame") then
            pcall(function()
                Descendant.Playing = false
            end)
        end
    end
end

local function destroyLayerCollector(Instance)
    if Deleted[Instance] or not Instance.Parent then
        return
    end

    Deleted[Instance] = true
    disableScriptsInside(Instance)

    local Success = pcall(function()
        Instance:Destroy()
    end)

    if Success then
        DeletedCount = DeletedCount + 1
    end
end

local function processLayerCollector(Instance)
    if not isLayerCollector(Instance) or hasLayerCollectorAncestor(Instance) then
        return
    end

    -- CoreGui: chỉ ẩn UI chính thức của Roblox, không Destroy GUI executor lạ.
    if Instance:IsDescendantOf(CoreGui) then
        if Config.DisableRobloxCoreUI and isRobloxCoreRoot(Instance) then
            suppressLayerCollector(Instance, "Roblox default CoreGui")
        end

        return
    end

    local ProtectionReason = getCodeProtectionReason(Instance)

    if ProtectionReason then
        -- GUI do người dùng tự keep sẽ không bị ẩn.
        if not isKeptByUser(Instance) then
            suppressLayerCollector(Instance, ProtectionReason)
        end

        return
    end

    if Instance:IsDescendantOf(Workspace) and not Config.RemoveWorldUI then
        return
    end

    if Config.RemoveUnusedGameUI then
        destroyLayerCollector(Instance)
    end
end

local function scanGuiContainer(Container)
    for _, Descendant in ipairs(Container:GetDescendants()) do
        if isLayerCollector(Descendant) then
            processLayerCollector(Descendant)
        end
    end
end

local function disableRobloxCoreUI()
    if not Config.DisableRobloxCoreUI then
        return
    end

    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    end)

    pcall(function()
        StarterGui:SetCore("TopbarEnabled", false)
    end)

    pcall(function()
        StarterGui:SetCore("ChatActive", false)
    end)

    pcall(function()
        StarterGui:SetCore("PointsNotificationsActive", false)
    end)

    pcall(function()
        StarterGui:SetCore("BadgesNotificationsActive", false)
    end)

    pcall(function()
        ReplicatedFirst:RemoveDefaultLoadingScreen()
    end)

    pcall(function()
        TextChatService.ChatWindowConfiguration.Enabled = false
    end)

    pcall(function()
        TextChatService.ChatInputBarConfiguration.Enabled = false
    end)

    pcall(function()
        TextChatService.BubbleChatConfiguration.Enabled = false
    end)
end

-- Tắt CoreGui ngay và tiếp tục khóa vì Loading script của game bật All = true lại.
disableRobloxCoreUI()
scanGuiContainer(CoreGui)

task.spawn(function()
    while task.wait(math.max(0.25, tonumber(Config.CoreGuiRefreshRate) or 1)) do
        disableRobloxCoreUI()
        scanGuiContainer(CoreGui)
    end
end)

-- Đợi game hoàn tất bước GiveGameGUI để không làm hỏng chuỗi loading/data.
if Config.WaitForMainGUI and not PlayerGui:FindFirstChild("MainGUI") then
    local Deadline = os.clock() + (tonumber(Config.MainGUIWaitTimeout) or 30)

    repeat
        task.wait(0.1)
    until PlayerGui:FindFirstChild("MainGUI") or os.clock() >= Deadline
end

-- Dọn cả GUI đang hiển thị và template GUI trong file game.
local GuiContainers = {
    PlayerGui,
    StarterGui,
    ReplicatedFirst,
    ReplicatedStorage,
    StarterPlayer,
    Workspace,
}

for _, Container in ipairs(GuiContainers) do
    scanGuiContainer(Container)

    Container.DescendantAdded:Connect(function(Instance)
        if isLayerCollector(Instance) then
            task.defer(processLayerCollector, Instance)
        end
    end)
end

-- Phần giảm lag hình ảnh ngoài UI, giữ từ bản trước.
local function processVisual(Instance)
    if not Instance or not Instance.Parent then
        return
    end

    -- LayerCollector đã được xử lý riêng theo mức độ liên quan tới code.
    if isLayerCollector(Instance) then
        return
    end

    if Config.RemoveEffects then
        if Instance:IsA("ParticleEmitter")
            or Instance:IsA("Trail")
            or Instance:IsA("Beam")
            or Instance:IsA("Smoke")
            or Instance:IsA("Fire")
            or Instance:IsA("Sparkles")
            or Instance:IsA("Highlight")
            or Instance:IsA("PostEffect")
            or Instance:IsA("Atmosphere")
            or Instance:IsA("Clouds") then
            pcall(function()
                Instance:Destroy()
            end)
            return
        end
    end

    if Config.RemoveTextures then
        if Instance:IsA("Decal")
            or Instance:IsA("Texture")
            or Instance:IsA("SurfaceAppearance") then
            pcall(function()
                Instance:Destroy()
            end)
            return
        end

        if Instance:IsA("MeshPart") then
            pcall(function()
                Instance.TextureID = ""
                Instance.RenderFidelity = Enum.RenderFidelity.Performance
            end)
        elseif Instance:IsA("SpecialMesh") then
            pcall(function()
                Instance.TextureId = ""
            end)
        end
    end

    if Config.SimplifyParts and Instance:IsA("BasePart") then
        pcall(function()
            Instance.CastShadow = false
            Instance.Reflectance = 0
            Instance.Material = Enum.Material.Plastic
        end)
    end

    if Config.MuteSounds and Instance:IsA("Sound") then
        pcall(function()
            Instance:Stop()
            Instance.Volume = 0
        end)
    end
end

pcall(function()
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
end)

pcall(function()
    Lighting.GlobalShadows = false
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.FogEnd = 1000000000
end)

local Terrain = Workspace:FindFirstChildOfClass("Terrain")
if Terrain then
    pcall(function()
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
        Terrain.Decoration = false
    end)
end

for _, Instance in ipairs(Workspace:GetDescendants()) do
    processVisual(Instance)
end

for _, Instance in ipairs(Lighting:GetDescendants()) do
    processVisual(Instance)
end

for _, Instance in ipairs(SoundService:GetDescendants()) do
    processVisual(Instance)
end

Workspace.DescendantAdded:Connect(function(Instance)
    task.defer(processVisual, Instance)
end)

Lighting.DescendantAdded:Connect(function(Instance)
    task.defer(processVisual, Instance)
end)

SoundService.DescendantAdded:Connect(function(Instance)
    task.defer(processVisual, Instance)
end)

print(string.format(
    "[MM2 UI Cleaner] Hidden code-critical/Core GUI: %d | Destroyed unused GUI roots: %d",
    HiddenCount,
    DeletedCount
))
