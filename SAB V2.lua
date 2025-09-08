-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LOCAL PLAYER & CHARACTER
local player = Players.LocalPlayer
local char, root, humanoid
local antiStunConnection = nil

local function updateCharacter()
    char = player.Character or player.CharacterAdded:Wait()
    root = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
end

updateCharacter()
player.CharacterAdded:Connect(function()
    task.wait(1)
    updateCharacter()
end)

-- SCRIPT-WIDE STATES & VARIABLES
local gui
local godConnection, aimConnection
local espEnabled = false
local espConnections = {}
local infinityJumpEnabled = false
local jumpBoostEnabled = false
local jumpBoostUsed = false

-- COLOR SCHEME
local colors = {
    background = Color3.fromRGB(30, 30, 40),
    header = Color3.fromRGB(25, 25, 35),
    accent = Color3.fromRGB(0, 150, 255),
    text = Color3.fromRGB(240, 240, 240),
    toggleOff = Color3.fromRGB(70, 70, 80),
    toggleOn = Color3.fromRGB(0, 200, 100),
    button = Color3.fromRGB(50, 50, 60),
    buttonHover = Color3.fromRGB(60, 60, 70),
    category = Color3.fromRGB(40, 40, 50)
}

-- ESP SETTINGS
_G.FriendColor = Color3.fromRGB(0, 0, 255)
_G.EnemyColor = Color3.fromRGB(255, 0, 0)
_G.UseTeamColor = true

---------------------------------------------------
--[[           FUNCTION DEFINITIONS            ]]--
---------------------------------------------------

-- JUMP FUNCTIONS
local function toggleInfinityJump(state)
    infinityJumpEnabled = state
end

local function toggleJumpBoost(state)
    jumpBoostEnabled = state
    jumpBoostUsed = false -- Reset when toggled
end

UserInputService.JumpRequest:Connect(function()
    if infinityJumpEnabled and humanoid and root then
        -- Infinity jump functionality
        root.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
        local gravityConn
        gravityConn = RunService.Stepped:Connect(function()
            if not char or not root or not humanoid or not infinityJumpEnabled then
                gravityConn:Disconnect()
                return
            end

            if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                root.Velocity = Vector3.new(root.Velocity.X, math.clamp(root.Velocity.Y, -20, 150), root.Velocity.Z)
            elseif humanoid.FloorMaterial ~= Enum.Material.Air then
                gravityConn:Disconnect()
            end
        end)
    elseif jumpBoostEnabled and humanoid and root and not jumpBoostUsed then
        -- Single jump boost functionality
        root.AssemblyLinearVelocity = Vector3.new(0, 120, 0) -- Higher jump than infinity
        jumpBoostUsed = true
        
        -- Reset when landing
        local landedConn
        landedConn = humanoid.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Landed then
                jumpBoostUsed = false
                if landedConn then
                    landedConn:Disconnect()
                end
            end
        end)
    end
end)

-- COMBAT / PLAYER STATE FUNCTIONS
function setGodMode(on)
    if not humanoid then updateCharacter() end
    if not humanoid then return end

    if on then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        if godConnection then godConnection:Disconnect() end
        godConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < math.huge then
                humanoid.Health = math.huge
            end
        end)
    else
        if godConnection then godConnection:Disconnect() end
        godConnection = nil
        pcall(function()
            humanoid.MaxHealth = 100
            humanoid.Health = 100
        end)
    end
end

local aimbotRange = 100

local function getClosestAimbotTarget()
    if not root then return nil end

    local closestPlayer, shortestDist = nil, aimbotRange
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character.Humanoid.Health > 0 then
            local targetHRP = p.Character.HumanoidRootPart
            local dist = (root.Position - targetHRP.Position).Magnitude
            
            if dist < shortestDist then
                closestPlayer = p
                shortestDist = dist
            end
        end
    end
    return closestPlayer
end

local function toggleAimbot(state)
    if state then
        aimConnection = RunService.Heartbeat:Connect(function()
            local target = getClosestAimbotTarget()
            if target and target.Character and char and root and humanoid then
                local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetHrp.Position.X, root.Position.Y, targetHrp.Position.Z))
                end
            end
        end)
    else
        if aimConnection then
            aimConnection:Disconnect()
            aimConnection = nil
        end
    end
end

-- VISUALS FUNCTIONS
local function toggleESP(state)
    espEnabled = state
    if state then
        -- Create ESP holder
        local Holder = Instance.new("Folder", game.CoreGui)
        Holder.Name = "ServerV1ESP"
        
        local function LoadCharacter(v)
            repeat wait() until v.Character ~= nil
            v.Character:WaitForChild("Humanoid")
            
            local vHolder = Holder:FindFirstChild(v.Name)
            if not vHolder then
                vHolder = Instance.new("Folder", Holder)
                vHolder.Name = v.Name
            end
            vHolder:ClearAllChildren()
            
            -- Create highlight
            local highlight = Instance.new("Highlight")
            highlight.Name = v.Name .. "Highlight"
            highlight.Adornee = v.Character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = _G.UseTeamColor and v.TeamColor.Color or ((player.TeamColor == v.TeamColor) and _G.FriendColor or _G.EnemyColor)
            highlight.OutlineColor = Color3.new(1, 1, 1)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = vHolder
            
            -- Create name tag
            local head = v.Character:FindFirstChild("Head")
            if head then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = v.Name .. "NameTag"
                billboard.Adornee = head
                billboard.Size = UDim2.new(0, 100, 0, 40)
                billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 100
                billboard.Parent = vHolder
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, 0, 0, 20)
                nameLabel.Position = UDim2.new(0, 0, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = v.Name
                nameLabel.TextColor3 = _G.UseTeamColor and v.TeamColor.Color or ((player.TeamColor == v.TeamColor) and _G.FriendColor or _G.EnemyColor)
                nameLabel.TextStrokeTransparency = 0.5
                nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                nameLabel.Font = Enum.Font.GothamSemibold
                nameLabel.TextSize = 12
                nameLabel.Parent = billboard
                
                local distanceLabel = Instance.new("TextLabel")
                distanceLabel.Size = UDim2.new(1, 0, 0, 15)
                distanceLabel.Position = UDim2.new(0, 0, 0, 20)
                distanceLabel.BackgroundTransparency = 1
                distanceLabel.TextColor3 = _G.UseTeamColor and v.TeamColor.Color or ((player.TeamColor == v.TeamColor) and _G.FriendColor or _G.EnemyColor)
                distanceLabel.TextStrokeTransparency = 0.5
                distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                distanceLabel.Font = Enum.Font.Gotham
                distanceLabel.TextSize = 10
                distanceLabel.Parent = billboard
                
                -- Update distance periodically
                local distanceUpdate
                distanceUpdate = RunService.Heartbeat:Connect(function()
                    if not v.Character or not v.Character.Parent or not root then
                        distanceUpdate:Disconnect()
                        return
                    end
                    
                    local humanoidRootPart = v.Character:FindFirstChild("HumanoidRootPart")
                    if humanoidRootPart then
                        local distance = math.floor((humanoidRootPart.Position - root.Position).Magnitude)
                        distanceLabel.Text = tostring(distance) .. " studs"
                    end
                end)
                
                -- Clean up when ESP is disabled
                table.insert(espConnections, distanceUpdate)
            end
        end

        local function UnloadCharacter(v)
            local vHolder = Holder:FindFirstChild(v.Name)
            if vHolder then
                vHolder:Destroy()
            end
        end

        for _, v in pairs(Players:GetPlayers()) do
            if v ~= player then
                LoadCharacter(v)
            end
        end
        
        table.insert(espConnections, Players.PlayerAdded:Connect(function(newP)
            if newP ~= player then
                LoadCharacter(newP)
            end
        end))
        
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= player then
                table.insert(espConnections, v.CharacterAdded:Connect(function()
                    if espEnabled then LoadCharacter(v) end
                end))
            end
        end
    else
        for _, c in ipairs(espConnections) do c:Disconnect() end
        espConnections = {}
        local holder = game.CoreGui:FindFirstChild("ServerV1ESP")
        if holder then
            holder:Destroy()
        end
    end
end

-- WORLD / SERVER FUNCTIONS
local function serverHop()
    local placeId = game.PlaceId
    local servers = {}
    local success, response = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and response and response.data then
        for _, server in ipairs(response.data) do
            if server.playing and server.maxPlayers and server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(servers, server.id)
            end
        end
    end
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)])
    else
        StarterGui:SetCore("SendNotification", { Title = "Server Hop", Text = "No other servers found.", Duration = 3 })
    end
end

-- INSTANT STEAL FUNCTION
local function instantSteal()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/iw929wiwiw/New-Bypassed-/refs/heads/main/SAB"))()
end

---------------------------------------------------
--[[           GUI CREATION FUNCTIONS          ]]--
---------------------------------------------------

local function createButtonHoverEffect(button)
    local originalColor = button.BackgroundColor3
    local hoverColor = colors.buttonHover
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
    end)
end

local function createV1Menu()
    if gui then gui:Destroy() end

    gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    gui.Name = "ServerV1Menu"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame", gui)
    local originalSize = UDim2.new(0, 200, 0, 300) -- Increased height for new button
    mainFrame.Size = originalSize
    mainFrame.Position = UDim2.new(0.05, 0, 0.5, -150) -- Adjusted position
    mainFrame.BackgroundColor3 = colors.background
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 8)
    
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = colors.accent
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.5

    local titleBar = Instance.new("TextLabel", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = colors.header
    titleBar.BackgroundTransparency = 0
    titleBar.Text = "ZenoVa HUB | SAB"
    titleBar.Font = Enum.Font.GothamBold
    titleBar.TextSize = 16
    titleBar.TextColor3 = colors.text
    titleBar.TextXAlignment = Enum.TextXAlignment.Center
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 8)

    local contentFrame = Instance.new("ScrollingFrame", mainFrame)
    contentFrame.Size = UDim2.new(1, -10, 1, -40)
    contentFrame.Position = UDim2.new(0, 5, 0, 35)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 4
    contentFrame.ScrollBarImageColor3 = colors.accent
    contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local listLayout = Instance.new("UIListLayout", contentFrame)
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- MINIMIZE BUTTON
    local minimized = false
    local minimizeButton = Instance.new("TextButton", titleBar)
    minimizeButton.Size = UDim2.new(0, 25, 0, 25)
    minimizeButton.Position = UDim2.new(1, -30, 0.5, -12.5)
    minimizeButton.BackgroundColor3 = colors.button
    minimizeButton.Text = "–"
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextSize = 16
    minimizeButton.TextColor3 = colors.text
    local minimizeCorner = Instance.new("UICorner", minimizeButton)
    minimizeCorner.CornerRadius = UDim.new(0, 4)
    
    createButtonHoverEffect(minimizeButton)
    
    minimizeButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        contentFrame.Visible = not minimized
        minimizeButton.Text = minimized and "+" or "–"
        
        local targetSize = minimized and UDim2.new(0, 200, 0, 35) or originalSize
        TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
    end)

    local currentLayoutOrder = 1
    local function createCategory(title)
        local categoryFrame = Instance.new("Frame", contentFrame)
        categoryFrame.Size = UDim2.new(1, 0, 0, 25)
        categoryFrame.BackgroundColor3 = colors.category
        categoryFrame.BackgroundTransparency = 0.5
        categoryFrame.LayoutOrder = currentLayoutOrder
        currentLayoutOrder = currentLayoutOrder + 1
        
        local categoryCorner = Instance.new("UICorner", categoryFrame)
        categoryCorner.CornerRadius = UDim.new(0, 4)
        
        local categoryLabel = Instance.new("TextLabel", categoryFrame)
        categoryLabel.Size = UDim2.new(1, 0, 1, 0)
        categoryLabel.Text = title
        categoryLabel.Font = Enum.Font.GothamBold
        categoryLabel.TextSize = 14
        categoryLabel.TextColor3 = colors.text
        categoryLabel.BackgroundTransparency = 1
        categoryLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        return categoryFrame
    end

    local function createToggleButton(name, parent, callback)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(1, 0, 0, 30)
        container.BackgroundTransparency = 1
        container.LayoutOrder = currentLayoutOrder
        currentLayoutOrder = currentLayoutOrder + 1

        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Text = name
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 14
        label.TextColor3 = colors.text
        label.BackgroundTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left

        local switch = Instance.new("TextButton", container)
        switch.Size = UDim2.new(0, 45, 0, 22)
        switch.Position = UDim2.new(1, -50, 0.5, -11)
        switch.BackgroundColor3 = colors.toggleOff
        switch.Text = ""
        local switchCorner = Instance.new("UICorner", switch)
        switchCorner.CornerRadius = UDim.new(0.5, 0)
        
        local switchStroke = Instance.new("UIStroke", switch)
        switchStroke.Color = colors.accent
        switchStroke.Thickness = 1
        switchStroke.Transparency = 0.7

        local nub = Instance.new("Frame", switch)
        nub.Size = UDim2.new(0, 18, 0, 18)
        nub.Position = UDim2.new(0, 2, 0.5, -9)
        nub.BackgroundColor3 = colors.text
        local nubCorner = Instance.new("UICorner", nub)
        nubCorner.CornerRadius = UDim.new(0.5, 0)

        local state = false
        switch.MouseButton1Click:Connect(function()
            state = not state
            callback(state)
            local nubPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            local switchColor = state and colors.toggleOn or colors.toggleOff
            TweenService:Create(nub, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = nubPos }):Play()
            TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundColor3 = switchColor }):Play()
        end)
        
        createButtonHoverEffect(switch)
    end
    
    local function createOneShotButton(name, parent, callback)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = colors.button
        btn.TextColor3 = colors.text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.Text = name
        btn.LayoutOrder = currentLayoutOrder
        currentLayoutOrder = currentLayoutOrder + 1
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 4)
        
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = colors.accent
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.7
        
        createButtonHoverEffect(btn)

        btn.MouseButton1Click:Connect(callback)
    end
    
    -- CREATE UI ELEMENTS
    -- Player Settings
    createCategory("PLAYER SETTINGS")
    createToggleButton("Godmode", contentFrame, setGodMode)
    createToggleButton("Aimbot", contentFrame, toggleAimbot)
    createToggleButton("Infinity Jump", contentFrame, toggleInfinityJump)
    createToggleButton("Jump Boost", contentFrame, toggleJumpBoost)

    -- Visual Settings
    createCategory("VISUALS")
    createToggleButton("ESP", contentFrame, toggleESP)
    
    -- Server Settings
    createCategory("SERVER")
    createOneShotButton("Server Hop", contentFrame, serverHop)
    
    -- New Instant Steal button
    createCategory("FEATURES")
    createOneShotButton("Instant Steal", contentFrame, instantSteal)
    
    -- Initial animation
    mainFrame.Position = UDim2.new(0.05, 0, 0, -400)
    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.05, 0, 0.5, -150)}):Play()
end

-- Initialize Menu
createV1Menu()