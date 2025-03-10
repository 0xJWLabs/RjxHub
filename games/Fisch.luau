local PreloadedConstants = {
	IsDev = false,
	Version = "0.1.0",
	Is_Debugging = false
}

local function clone<Original>(ToClone: any & Original): Original
	if cloneref or clonereference then
		return ToClone
	end
	
	return ToClone
end

local StarterPlayer = clone(game:GetService("StarterPlayer"))
local Players = clone(game:GetService("Players"))
local RunService = clone(game:GetService("RunService"))
local UserInputService = clone(game:GetService("UserInputService"))
local ReplicatedStorage = clone(game:GetService("ReplicatedStorage"))
local GuiService = clone(game:GetService("GuiService"))
local VirtualInputManager = clone(game:GetService("VirtualInputManager"))

local Player = Players.LocalPlayer
local DEFAULT_WALKSPEED = StarterPlayer.CharacterWalkSpeed

if not Player.Character then
	repeat
		task.wait()
	until Player.Character
end

local Unloaded = false
local CurrentTool: Tool?

if not (hookfunction and hookmetamethod) then
	hookfunction = function(...) end
	hookmetamethod = function(...) end
	NO_HOOKING = true
end

if not getconnections then
	getconnections = function(...) end
end

if not setthreadidentity then
	setthreadidentity = function(...) end -- i hate you solara
end

-- Modules
if getgenv and getgenv().sasware_fisch_unload then
	pcall(getgenv().sasware_fisch_unload)
end

local Library = loadstring(game:HttpGet("https://github.com/0xJWLabs/FluentRenewed/releases/download/0.1.0/Fluent.luau"))()

local Connections: { [string]: RBXScriptConnection | thread } = {}
local State = {
	LastToolReset = os.clock(),
	ToolResetCooldown = 5,
	ClipParts = {},
	InfiniteJumpDebounce = false,
	Walkspeed = DEFAULT_WALKSPEED
}

local Remotes = {
	ReelFinished = ReplicatedStorage:WaitForChild("events"):WaitForChild("reelfinished"),
}

local function disconnect(name: string)
	if Connections[name] then
		local item = Connections[name]
		local success, err = pcall(function()
			if typeof(item) == "thread" then
				-- Check if the thread is still running before closing it
				if coroutine.status(item) ~= "dead" then
					coroutine.close(item)
				end
			else
				item:Disconnect()
			end
		end)

		if not success then
			warn(`Failed to disconnect {name}: {err}`)
		end

		Connections[name] = nil
	end
end

local function connect(name: string, item: RBXScriptConnection | thread)
	-- Disconnect any existing connection or thread with the same name
	disconnect(name)

	-- Validate the item before adding it to the Connections table
	if typeof(item) ~= "RBXScriptConnection" and typeof(item) ~= "thread" then
		error(`Invalid item type for connection {name}: expected RBXScriptConnection or thread, got {typeof(item)}`)
	end

	Connections[name] = item

	if typeof(item) == "thread" then
		coroutine.resume(item)
	end

	-- Optional: Debugging log
	if PreloadedConstants.Is_Debugging then
		print(`Connected {name} (Type: {typeof(item)})`)
	end
end

local function disconnect_all()
	for connection_name, _ in Connections do
		disconnect(connection_name)
	end
end

local function Unload()
	RunService:Set3dRenderingEnabled(true)
	disconnect_all()
	
	Library = nil
	
	if getgenv then
		getgenv().sasware_fisch_unload = nil
	end
	Unloaded = true
end

if getgenv then
	getgenv().sasware_fisch_unload = Unload
end

if not PreloadedConstants.IsDev then
	do
		if game.PlaceVersion >= 3744 then
			print("Bypassing")
			local URL = "https://raw.githubusercontent.com/centerepic/sasware-fisch/refs/heads/main/bypasses/V3.luau"
			local Success, Error = pcall(function()
				return loadstring(game:HttpGet(URL))()
			end)

			print("Bypassed")

			if not Success then
				print(Error)
				-- Player:Kick("Failed to load RjxGuard! " .. Error)
			end
		end
	end
end

local function EnsureInstance(Instance: Instance?): boolean
	return (Instance and Instance:IsDescendantOf(game))
end

local function GetToggleValue(name: string): boolean?
	local Toggle = Library.Options[name]
	
	if not Toggle then
		return nil
	end
	
	return Toggle.Value
end

local function ResetTool()
	if CurrentTool then
		local ToolCache = Player.Character:FindFirstChildOfClass("Tool")
		if CurrentTool then
			if State.LastToolReset + State.ToolResetCooldown < os.clock() then
				State.LastToolReset = os.clock()
				Player.Character.Humanoid:UnequipTools()
				task.wait()
				ToolCache.Parent = Player.Character
			end
		end
	end
end

local Utilities = {}

do
	function Utilities.CountInstances(Parent: Instance, Name: string): number
		local Count = 0
		for _, instance in Parent:GetChildren() do
			if instance.Name == Name then
				Count += 1
			end
		end
		return Count
	end
	
	function Utilities.CharacterChildAdded(Child: Instance)
		if Child:IsA("Tool") then
			CurrentTool = Child
		end
	end
	
	function Utilities.CharacterChildRemoved(Child: Instance)
		if Child:IsA("Tool") then
			CurrentTool = nil
		end
	end
	
	function Utilities.CharacterAdded(Character: Model)
		for _, child in Character:GetChildren() do
			Utilities.CharacterChildAdded(child)
		end
		
		connect("ChildAdded", Character.ChildAdded:Connect(Utilities.CharacterChildAdded))
		connect("ChildRemoved", Character.ChildRemoved:Connect(Utilities.CharacterChildRemoved))
	end
end

local function WaitForTable(Root: Instance, InstancePath: { string }, Timeout: number?)
	local Instance = Root
	for i, v in InstancePath do
		Instance = Instance:WaitForChild(v, Timeout)
	end
	return Instance
end

local Window = Library:Window{
	Title = `RjwHub v{PreloadedConstants.Version}`,
	SubTitle = "by robloxjw02",
	TabWidth = 160,
	Size = UDim2.fromOffset(830, 525),
	Resize = true,
	Acrylic = false,
	Theme = "Catppuccin Mocha",
	MinimizeKey = Enum.KeyCode.RightShift
}

local Tabs = {
	LocalPlayer = Window:Tab{
		Title = "Local Player",
		Icon = "phosphor-users-bold"
	},
	["Game"] = Window:Tab{
		Title = "In-Game",
		Icon = "fish"
	}
}

local Input = Tabs.LocalPlayer:Input("Walkspeed", {
	Title = "Walkspeed",
	Default = State.Walkspeed,
	Numeric = true,
	Finished = false,
	Placeholder = "WalkSpeed",
})

Input:OnChanged(function(Value)
	State.Walkspeed = Value
end)

local WalkspeedToggle = Tabs.LocalPlayer:Toggle("WalkspeedToggle", {
	Title = "Enabled Walkspeed",
	Default = false,
	Callback = function(Value: boolean)
		local Character = Player.Character
		local PlayerSpeed = Value and Input.Value or DEFAULT_WALKSPEED
		local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
		State.Walkspeed = PlayerSpeed
		Humanoid.WalkSpeed = State.Walkspeed
		if Value then
			connect("Walkspeed", coroutine.create(function()
				while true do
					local Character = Player.Character
					if not Character then
						return
					end

					local Humanoid: Humanoid = Character:FindFirstChildOfClass("Humanoid")

					if Humanoid and Humanoid.WalkSpeed ~= State.Walkspeed then
						Humanoid.WalkSpeed = State.Walkspeed
					end
					task.wait()
				end
			end))
		else
			disconnect("Walkspeed")
		end
	end,
})


local NoClipToggle = Tabs.LocalPlayer:Toggle("NoClip", {
	Title = "NoClip",
	Default = false,
	Callback = function(value)
		if value then
			State.ClipParts = {}
			connect("NoClipping", RunService.Stepped:Connect(function()
				if not Player.Character then
					return
				end

				local parts = Player.Character:GetDescendants()

				for _, child in parts do
					if child:IsA("BasePart") and child.CanCollide == true then
						if not table.find(State.ClipParts, child) then
							table.insert(State.ClipParts, child)
						end

						child.CanCollide = false
					end
				end
			end))
		else
			disconnect("NoClipping")

			for i, part in State.ClipParts do
				part.CanCollide = true
			end

			State.ClipParts = {}
		end
	end,
})

local InfiniteJumpToggle = Tabs.LocalPlayer:Toggle("InfiniteJump", {
	Title = "Infinite Jump",
	Default = false,
	Callback = function(value)
		if value then
			connect("InfiniteJump", UserInputService.JumpRequest:Connect(function()
				if not Player.Character then
					return
				end
				
				if not State.InfiniteJumpDebounce then
					local Character = Player.Character
					local Humanoid = Character:FindFirstChildOfClass("Humanoid")

					if Humanoid then
						Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					State.InfiniteJumpDebounce = true
					task.wait()
					State.InfiniteJumpDebounce = false
				end
			end))
		else
			disconnect("InfiniteJump")
			State.InfiniteJumpDebounce = false
		end
	end,
})

local AutoCastToggle = Tabs.Game:Toggle("AutoCast", {
	Title = "Auto Cast",
	Default = false,
	Callback = function(value)
		if value then
			connect("AutoCast", coroutine.create(function()
				local lastCastAttempt = 0
				
				while task.wait(0.3) do
					pcall(function()
						if not CurrentTool then
							return
						end
						
						local Values = CurrentTool:FindFirstChild("values")
						if CurrentTool and Values then
							local Events = CurrentTool:FindFirstChild("events")

							-- sometimes the game freaks out and gets stuck after reeling in with blatant autoreel and we need to fix it
							if
								Values:FindFirstChild("bite")
								and Values.bite.Value == true
								and Values.casted.Value == true
							then
								if (not Player.PlayerGui:FindFirstChild("reel")) and tick() - lastCastAttempt > 5 then
									ResetTool()
								end
							end

							-- another fix
							if Utilities.CountInstances(Player.PlayerGui, "reel") > 1 then
								-- reeling is broken, reset tool and delete the glitched reel UI
								ResetTool()
								for _, child in Player.PlayerGui:GetChildren() do
									if child.Name == "reel" then
										child:Destroy()
									end
								end
							end

							if Values.casted.Value == false then
								lastCastAttempt = tick()

								local AnimationFolder = ReplicatedStorage:WaitForChild("resources")
									:WaitForChild("animations")

								local CastAnimation: AnimationTrack = Player.Character
									:FindFirstChild("Humanoid")
									:LoadAnimation(AnimationFolder.fishing.throw)
								CastAnimation.Priority = Enum.AnimationPriority.Action3
								CastAnimation:Play()
								Events.cast:FireServer(100, 1)

								CastAnimation.Stopped:Once(function()
									CastAnimation:Destroy()

									local WaitingAnimation: AnimationTrack = Player.Character
										:FindFirstChild("Humanoid")
										:LoadAnimation(AnimationFolder.fishing.waiting)
									WaitingAnimation.Priority = Enum.AnimationPriority.Action3
									WaitingAnimation:Play()

									local UnequippedLoop, CastConnection

									CastConnection = Values.casted.Changed:Once(function()
										WaitingAnimation:Stop()
										WaitingAnimation:Destroy()
										coroutine.close(UnequippedLoop)
									end)

									UnequippedLoop = coroutine.create(function()
										repeat
											task.wait()
										until not CurrentTool
										WaitingAnimation:Stop()
										WaitingAnimation:Destroy()
										CastConnection:Disconnect()
									end)

									coroutine.resume(UnequippedLoop)
								end)
							end
						end
					end)
				end
			end))
		else
			disconnect("AutoCast")
		end
	end,
})

local AutoShakeToggle = Tabs.Game:Toggle("AutoShake", {
	Title = "Auto Shake",
	Default = false,
	Callback = function(value)
		if value then
			connect("AutoShake", coroutine.create(function()
				function Utilities.MountShakeUI(ShakeUI: ScreenGui)
					local SafeZone: Frame? = ShakeUI:WaitForChild("safezone", 5) :: Frame?

					local function HandleButton(Button: ImageButton)
						Button.Selectable = true -- For some reason this is false for the first 0.2 seconds.

						if EnsureInstance(Button) then
							GuiService.SelectedObject = Button
						end
					end
					
					if not SafeZone then
						print("Unable to mount shake UI")
						return
					end
					
					if GetToggleValue("CenterShake") then
						local Connect = SafeZone:WaitForChild("connect", 1)

						if Connect then
							Connect.Enabled = false -- this script locks the size of the safezone, so we disable it.
						end

						SafeZone.Size = UDim2.fromOffset(0, 0)
						SafeZone.Position = UDim2.fromScale(0.5, 0.5)
						SafeZone.AnchorPoint = Vector2.new(0.5, 0.5)
					end
					
					connect("SafeZoneShake", SafeZone.ChildAdded:Connect(function(Child)
						if Child:IsA("ImageButton") then
							local Done = false

							task.spawn(function()
								repeat
									RunService.RenderStepped:Wait()
									HandleButton(Child)
								until Done
							end)

							task.spawn(function()
								repeat
									RunService.RenderStepped:Wait()
								until (not Child) or (not Child:IsDescendantOf(SafeZone))
								Done = true
							end)
						end
					end))

					repeat
						RunService.RenderStepped:Wait()
						if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(SafeZone) then
							VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
							VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
						end
						RunService.RenderStepped:Wait()
					until not SafeZone:IsDescendantOf(Player.PlayerGui)
					disconnect("SafeZoneShake")
					GuiService.SelectedObject = nil
				end
				
				connect("ChildAddedShake", Player.PlayerGui.ChildAdded:Connect(function(child: Instance)
					if child.Name == "shakeui" and child:IsA("ScreenGui") then
						Utilities.MountShakeUI(child)
					end
				end))
			end))
		else
			disconnect("ChildAddedShake")
			disconnect("AutoShake")
		end
	end,
})

local CenterShakeToggle = Tabs.Game:Toggle("CenterShake", {
	Title = "Center Shake",
	Default = false,
})

local AutoReelToggle, InstantReelToggle

AutoReelToggle = Tabs.Game:Toggle("AutoReel", {
	Title = "Auto Reel",
	Default = false,
	Callback = function(value)
		if value then
			if GetToggleValue("InstantReel") then
				InstantReelToggle:SetValue(false)
			end
			connect("AutoReel", coroutine.create(function()
				while true do
					RunService.RenderStepped:Wait()

					local ReelUI: ScreenGui = Player.PlayerGui:FindFirstChild("reel")

					if not ReelUI then
						continue
					end

					local Bar = ReelUI:FindFirstChild("bar")
					if not Bar then
						continue
					end
					
					local PlayerBar: Frame = Bar:FindFirstChild("playerbar")
					local TargetBar: Frame = Bar:FindFirstChild("fish")

					while Bar and ReelUI:IsDescendantOf(Player.PlayerGui) do
						RunService.RenderStepped:Wait()
						local UnfilteredTargetPosition = PlayerBar.Position:Lerp(TargetBar.Position, 0.7)
						local TargetPosition = UDim2.fromScale(
							math.clamp(UnfilteredTargetPosition.X.Scale, 0.15, 0.85),
							UnfilteredTargetPosition.Y.Scale
						)

						PlayerBar.Position = TargetPosition
					end
				end
			end))
		else
			disconnect("AutoReel")
		end
	end,
})

InstantReelToggle = Tabs.Game:Toggle("Instant Reel", {
	Title = "Instant Reel",
	Default = false,
	Callback = function(value)
		if value then
			if GetToggleValue("AutoReel") then
				AutoReelToggle:SetValue(false)
			end
			connect("InstantReel", coroutine.create(function()
				while true do
					RunService.RenderStepped:Wait()

					local ReelUI: ScreenGui = Player.PlayerGui:FindFirstChild("reel")

					if not ReelUI then
						continue
					end
					
					local Bar = ReelUI:FindFirstChild("bar")
					
					if not Bar then
						continue
					end
					
					local ReelScript = Bar:FindFirstChild("reel")
					if ReelScript and ReelScript.Enabled == true then
						Remotes.ReelFinished:FireServer(100, GetToggleValue("PerfectReel"))
					end
				end
			end))
		else
			disconnect("InstantReel")
		end
	end,
})

local PerfectReelToggle = Tabs.Game:Toggle("PerfectReel", {
	Title = "Perfect Reel",
	Default = false,
})

if NO_HOOKING and not PreloadedConstants.IsDev then
	local oldnamecall
	oldnamecall = hookmetamethod(game, "__namecall", function(...)
		if not Unloaded then
			if not checkcaller() then
				local Method = getnamecallmethod()

				local Args = { ... }
				local self = table.remove(Args, 1)

				if Method == "FireServer" then
					if self == Remotes.ReelFinished then
						if GetToggleValue("PerfectReel") then
							Args[1] = 100 -- Reel percentage
							Args[2] = true -- If the reel was perfect
						end
					elseif tostring(self) == "cast" then -- ultra detectable but i dont care because im sigma.
						if GetToggleValue("PerfectCast") then
							Args[1] = 100 -- Cast percentage
						end
					end

					return oldnamecall(self, unpack(Args))
				end
			end
		end

		return oldnamecall(...)
	end)
end

Library.MinimizeKeybind = Library.Options.MenuKeybind
Window:SelectTab(1)

Library:Notify({
	Title = "RjwHub",
	Content = "The script has been loaded.",
	Duration = 5
})

connect("CharacterAdded", Player.CharacterAdded:Connect(Utilities.CharacterAdded))
Utilities.CharacterAdded(Player.Character)