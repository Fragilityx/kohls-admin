local BaseClass = require(script.Parent.BaseClass)
local UI = require(script.Parent.Parent)

local Tooltip = {}
Tooltip.__index = Tooltip
setmetatable(Tooltip, BaseClass)

local layerSizeState = UI.state(UI.LayerTop, "AbsoluteSize")

function Tooltip.new(definition)
	local new = UI.makeStatefulDefaults({
		Enabled = true,
		Visible = false,
	}, definition)

	local hoverStart
	local hovering = UI.state(false)
	local positionState = UI.state(Vector2.zero)
	local sizeState = UI.state(Vector2.zero)
	local tipSizeState = UI.state(Vector2.zero)

	local function hover(value)
		if value then
			local start = tick()
			hoverStart = start
			task.delay(0.4, function()
				if hoverStart == start and hovering._value then
					new.Visible:set(true)
				end
			end)
		else
			new.Visible:set(false)
		end
	end

	new._instance = UI.new "TextLabel" {
		AutoLocalize = false,
		Parent = UI.LayerTop,
		Name = "Tooltip",
		Visible = function(use)
			return use(new.Enabled) and use(new.Visible)
		end,
		ZIndex = 100,
		BackgroundColor3 = UI.Theme.Primary,
		Font = UI.Theme.Font,
		TextSize = UI.Theme.FontSize,
		Text = "Example tooltip text.",
		TextColor3 = UI.Theme.PrimaryText,
		TextStrokeColor3 = UI.Theme.Primary,
		TextStrokeTransparency = UI.Theme.TextStrokeTransparency,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = function(use)
			local tipSize = use(tipSizeState)
			local max = use(layerSizeState)
			local position, size = use(positionState), use(sizeState)
			local yOffset = position.Y + size.Y + use(UI.TopbarInset).Height + use(UI.Theme.PaddingHalf).Offset

			return UDim2.fromOffset(
				math.clamp(position.X, 0, math.max(0, max.X - tipSize.X)),
				math.clamp(yOffset, 0, math.max(0, max.Y - tipSize.Y))
			)
		end,

		UI.new "UICorner" {
			CornerRadius = UI.Theme.CornerRadius,
		},
		UI.new "UIPadding" {
			PaddingLeft = UI.Theme.Padding,
			PaddingRight = UI.Theme.Padding,
			PaddingTop = UI.Theme.Padding,
			PaddingBottom = UI.Theme.Padding,
		},
		UI.new "UISizeConstraint" {
			MinSize = Vector2.new(8, 8),
			MaxSize = Vector2.new(256, math.huge),
		},
		UI.new "UIStroke" {
			Enabled = UI.Theme.StrokeEnabled,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = UI.Theme.TransparencyClamped,
			Color = UI.Theme.Border,
		},
	}

	local parent
	local hoverConnections = {}
	local function hoverEnter()
		UI.activateState(hovering, "hover")
	end
	local function hoverLeave()
		UI.deactivateState(hovering, "hover")
	end

	local function inputChanged(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if UI.sinkInput(input.Position.X, input.Position.Y, parent) then
				hoverLeave()
				return
			end
			hoverEnter()
		end
	end

	local function inputEnded(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			hoverLeave()
		end
	end

	UI.edit(new._instance, {
		[UI.Clean] = {
			UI.UserInputService.TouchMoved:Connect(function()
				hovering:set(false)
			end),
			hovering:hook(hover),
			new._instance:GetPropertyChangedSignal("Parent"):Connect(function()
				local newParent = new._instance.Parent
				if newParent and newParent ~= UI.LayerTop then
					if parent then
						for _, v in hoverConnections do
							v:Disconnect()
						end
					end

					parent = newParent
					table.insert(hoverConnections, parent.InputChanged:Connect(inputChanged))
					table.insert(hoverConnections, parent.InputEnded:Connect(inputEnded))
					table.insert(hoverConnections, parent.SelectionGained:Connect(hoverEnter))
					table.insert(hoverConnections, parent.SelectionLost:Connect(hoverLeave))
					positionState:bindToProperty(parent, "AbsolutePosition")
					sizeState:bindToProperty(parent, "AbsoluteSize")
					task.wait()
					new._instance.Parent = UI.LayerTop
				end
			end),
			positionState,
			sizeState,
			hovering,
		},
	})

	tipSizeState:bindToProperty(new._instance, "AbsoluteSize")

	return setmetatable(new, Tooltip)
end

return Tooltip
