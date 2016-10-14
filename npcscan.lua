npcscan = CreateFrame'Frame'
npcscan:SetScript('OnUpdate', function() npcscan.UPDATE() end)
npcscan:SetScript('OnEvent', function() npcscan.LOAD() end)
npcscan:RegisterEvent'VARIABLES_LOADED'

local BROWN = {.7, .15, .05}
local YELLOW = {1, 1, .15}
local CHECK_INTERVAL = .1

npcscan_targets = {}

do 
	local nop = function() end
	function npcscan.without_errors(f)
	    local orig = UIErrorsFrame.AddMessage
	    UIErrorsFrame.AddMessage = nop
	    f()
	    UIErrorsFrame.AddMessage = orig
	end
end

do
	local last_played
	
	function npcscan.play_sound()
		if not last_played or GetTime() - last_played > 10 then -- 8
			SetCVar('MasterSoundEffects', 0)
			SetCVar('MasterSoundEffects', 1)
			PlaySoundFile[[Interface\AddOns\npcscan\Event_wardrum_ogre.ogg]]
			PlaySoundFile[[Interface\AddOns\npcscan\scourge_horn.ogg]]
			last_played = GetTime()
		end
	end
end

function npcscan.check_for_targets()
	for name, _ in npcscan_targets do
		if npcscan.target(name) then
			npcscan.toggle_target(name)
			npcscan.play_sound()
			if npcscan.flash.animation:playing() then
				npcscan.flash.animation:stop_after(3)
			else
				npcscan.flash:reset()
				npcscan.flash.animation:play()			
			end
			npcscan.button:set_target()
		end
	end
end

function npcscan.target(name)
	TargetByName(name, true)
	local target = UnitName'target'
	return target and strupper(target) == name
end

function npcscan.LOAD()
	do
		local flash = CreateFrame'Frame'
		npcscan.flash = flash
		flash:Show()
		flash:SetAllPoints()
		flash:SetAlpha(0)
		flash:SetFrameStrata'FULLSCREEN_DIALOG'
		
		local texture = flash:CreateTexture()
		texture:SetBlendMode'ADD'
		texture:SetAllPoints()
		texture:SetTexture[[Interface\FullScreenTextures\LowHealth]]
		
		function flash:reset()
			self:SetAlpha(0)
		end
		
		local screen_flash_in = npcscan.alpha_animation(flash, 1, .5)
		local screen_flash_out = npcscan.alpha_animation(flash, -1, .5)
		local screen_flash_delay = npcscan.delay(.5)
		
		flash.animation = (screen_flash_in..screen_flash_delay..screen_flash_out) * 3
	end
	
	local button = CreateFrame('Button', 'npcscan_button', UIParent)
	button:Hide()
	npcscan.button = button
	button:SetPoint('BOTTOM', UIParent, 0, 128)
	button:SetWidth(150)
	button:SetHeight(42)
	button:SetScale(1.25)
	button:SetFrameStrata'FULLSCREEN_DIALOG'
	button:SetNormalTexture[[Interface\AddOns\npcscan\UI-Achievement-Parchment-Horizontal]]
	button:SetBackdrop{
		tile = true,
		edgeSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	}
	button:SetBackdropBorderColor(unpack(BROWN))
	button:SetScript('OnEnter', function()
		this:SetBackdropBorderColor(unpack(YELLOW))
	end)
	button:SetScript('OnLeave', function()
		this:SetBackdropBorderColor(unpack(BROWN))
	end)
	button:SetScript('OnClick', function()
		TargetByName(this:GetText(), true)
	end)
	function button:set_target()
		self:SetText(UnitName'target')

		self.model:reset()
		self.model:SetUnit'target'

		self:Show()
		self.glow.animation:stop()
		self.shine.animation:stop()
		self.glow:reset()
		self.shine:reset()
		self.glow.animation:play()
		self.shine.animation:play()
	end
	
	do
		local background = button:GetNormalTexture()
		background:SetDrawLayer'BACKGROUND'
		background:ClearAllPoints()
		background:SetPoint('BOTTOMLEFT', 3, 3)
		background:SetPoint('TOPRIGHT', -3, -3)
		background:SetTexCoord(0, 1, 0, .25)
	end
	
	do
		local title_background = button:CreateTexture(nil, 'BORDER')
		title_background:SetTexture[[Interface\AddOns\npcscan\UI-Achievement-Title]]
		title_background:SetPoint('TOPRIGHT', -5, -5)
		title_background:SetPoint('LEFT', 5, 0)
		title_background:SetHeight(18)
		title_background:SetTexCoord(0, .9765625, 0, .3125)
		title_background:SetAlpha(.8)

		local title = button:CreateFontString(nil, 'OVERLAY')
		title:SetFont([[Fonts\FRIZQT__.TTF]], 14)
		title:SetShadowOffset(1, -1)
		title:SetPoint('TOPLEFT', title_background, 0, 0)
		title:SetPoint('RIGHT', title_background)
		button:SetFontString(title)

		local subtitle = button:CreateFontString(nil, 'OVERLAY')
		subtitle:SetFont([[Fonts\FRIZQT__.TTF]], 9)
		subtitle:SetTextColor(0, 0, 0)
		subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
		subtitle:SetPoint('RIGHT', title )
		subtitle:SetText'NPC Found!'
	end
	
	do
		local model = CreateFrame('PlayerModel', nil, button)
		button.model = model
		model:SetPoint('BOTTOMLEFT', button, 'TOPLEFT', 0, -4)
		model:SetPoint('RIGHT', 0, 0)
		model:SetHeight(button:GetWidth() * .6)
		
		do
			local last_update, delay
			function model:on_update()
				this:SetFacing(this:GetFacing() + (GetTime() - last_update) * math.pi / 4)
				last_update = GetTime()
			end
			
			function model:on_update_model()
				if delay > 0 then
					delay = delay - 1
					return
				end
				
				this:SetScript('OnUpdateModel', nil)
				this:SetScript('OnUpdate', this.on_update)
				this:SetModelScale(.75)
				this:SetAlpha(1)	
				last_update = GetTime()
			end
			
			function model:reset()
				self:SetAlpha(0)
				self:SetFacing(0)
				self:SetModelScale(1)
				self:ClearModel()
				self:SetScript('OnUpdate', nil)
				self:SetScript("OnUpdateModel", self.on_update_model)
				delay = 10 -- to prevent scaling bugs
			end
		end
	end
	
	do
		local close = CreateFrame('Button', nil, button, 'UIPanelCloseButton')
		close:SetPoint('TOPRIGHT', 0, 0)
		close:SetWidth(32)
		close:SetHeight(32)
		close:SetScale(.8)
		close:SetHitRectInsets(8, 8, 8, 8)
	end
	
	do
		local glow = button.model:CreateTexture(nil, 'OVERLAY')
		button.glow = glow
		glow:SetPoint('CENTER', button, 'CENTER')
		glow:SetWidth(400 / 300 * button:GetWidth())
		glow:SetHeight(171 / 70 * button:GetHeight())
		glow:SetTexture[[Interface\AddOns\npcscan\UI-Achievement-Alert-Glow]]
		glow:SetBlendMode'ADD'
		glow:SetTexCoord(0, .78125, 0, .66796875)
		glow:SetAlpha(0)
		
		function glow:reset()
			self:SetAlpha(0)
		end
		
		local glow_in = npcscan.alpha_animation(glow, 1, .2)
		local glow_out = npcscan.alpha_animation(glow, -1, .5)
		
		glow.animation = glow_in .. glow_out
	end

	do
		local shine = button:CreateTexture(nil, 'ARTWORK')
		button.shine = shine
		shine:SetPoint('TOPLEFT', button, 0, 8)
		shine:SetWidth(67 / 300 * button:GetWidth())
		shine:SetHeight(1.28 * button:GetHeight())
		shine:SetTexture[[Interface\AddOns\npcscan\UI-Achievement-Alert-Glow]]
		shine:SetBlendMode'ADD'
		shine:SetTexCoord(.78125, .912109375, 0, .28125)
		shine:SetAlpha(0)
		
		function shine:reset()
			self:SetAlpha(0)
			self:SetPoint('TOPLEFT', button, 0, 8)
		end
		
		local shine_delay1 = npcscan.delay(.3)
		local shine_in = npcscan.alpha_animation(shine, 1, 0)
		local shine_delay2 = npcscan.delay(.2)
		local shine_move = npcscan.translation_animation(shine, button:GetWidth() - shine:GetWidth() + 8, 0, .4)
		local shine_out = npcscan.alpha_animation(shine, -1, .2)
		
		shine.animation = (shine_delay1 .. shine_in) .. (shine_move + (shine_delay2 .. shine_out))
	end
end

do
	npcscan.last_check = GetTime()
	function npcscan.UPDATE()
		if GetTime() - npcscan.last_check >= CHECK_INTERVAL then
			npcscan.last_check = GetTime()
			npcscan.without_errors(npcscan.check_for_targets)
		end
	end
end

function npcscan.log(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '[npcscan] ' .. msg)
	end
end

-- Slash commands

function npcscan.sorted_targets()
	local sorted_targets = {}
	for key, _ in pairs(npcscan_targets) do
		tinsert(sorted_targets, key)
	end
	sort(sorted_targets, function(key1, key2) return key1 < key2 end)
	return sorted_targets
end

function npcscan.toggle_target(name)
	local key = strupper(name)
	if npcscan_targets[key] then
		npcscan_targets[key] = nil
		npcscan.log('- ' .. key)
	elseif key ~= '' then
		npcscan_targets[key] = true
		npcscan.log('+ ' .. key)
	end
end
	
SLASH_NPCSCAN1 = '/npcscan'
function SlashCmdList.NPCSCAN(parameter)
	local _, _, name = strfind(parameter, '^%s*(.-)%s*$')
	
	if name == '' then
		for _, key in ipairs(npcscan.sorted_targets()) do
			npcscan.log(key)
		end
	else
		npcscan.toggle_target(name)
	end
end

-- Animation framework

function npcscan.translation_animation(target, x_change, y_change, duration)
	return npcscan.animation(
		{x_change, y_change},
		duration,
		function()
			local _, _, _, original_x, original_y = target:GetPoint()
			return original_x, original_y
		end,
		function(x, y)
			local point, relative_to, relative_point = target:GetPoint()
			target:SetPoint(
				point,
				relative_to,
				relative_point,
				x,
				y
			)
		end
	)
end

function npcscan.alpha_animation(target, change, duration)
	return npcscan.animation(
		{change},
		duration,
		function()
			return target:GetAlpha()
		end,
		function(alpha)
			target:SetAlpha(alpha)
		end
	)
end

function npcscan.delay(t)
	return npcscan.animation({}, t, function() end, function() end)
end

do
	local animation_metamethods = {}
	
	local mul_mt = { __index={} }
	local add_mt = { __index={} }
	local concat_mt = { __index={} }
	local animation_mt = { __index={} }
	
	
	function animation_metamethods.__mul(animation, repetitions)
		local self = {
			_frame = CreateFrame'Frame',
			_repetitions_left = 0,
			_repetitions = repetitions,
			_animation = animation,
		}
		setmetatable(self, mul_mt)
		
		self._frame:SetScript('OnUpdate', function()
			self:_on_update()
		end)
		
		return self
	end
	function animation_metamethods.__add(lhs, rhs)
		local self = {}
		setmetatable(self, add_mt)
		
		self._animations = {lhs, rhs}
	
		return self
	end
	function animation_metamethods.__concat(lhs, rhs)
		local self = { _frame=CreateFrame'Frame' }
		setmetatable(self, concat_mt)
		
		self._animations = {lhs, rhs}
		
		self._frame:SetScript('OnUpdate', function()
			self:_on_update()
		end)
			
		return self
	end
	
	
	for _, mt in ipairs({mul_mt, add_mt, concat_mt, animation_mt}) do
		for key, metamethod in pairs(animation_metamethods) do
			mt[key] = metamethod
		end
	end
	
	
	function mul_mt.__index:play()
		self._repetitions_left = self._repetitions
	end	
	function mul_mt.__index:playing()
		return self._repetitions_left > 0
	end
	function mul_mt.__index:stop()
		self._repetitions_left = 0
	end
	function mul_mt.__index:stop_after(repetitions)
		self._repetitions_left = self._repetitions
	end
	function mul_mt.__index:_on_update()
		if self._repetitions_left > 0 then
			if not self._animation_started then
				self._animation:play()
				self._animation_started = true
			elseif not self._animation:playing() then
				self._repetitions_left = self._repetitions_left - 1
				self._animation_started = false
			end
		end
	end

	
	function add_mt.__index:play()
		for _, animation in ipairs(self._animations) do
			animation:play()
		end
	end
	function add_mt.__index:playing()
		for _, animation in ipairs(self._animations) do
			if animation:playing() then
				return true
			end
		end
	end
	function add_mt.__index:stop()
		for _, animation in ipairs(self._animations) do
			animation:stop()
		end
	end
	
	
	function concat_mt.__index:play()
		self._index = 1
	end	
	function concat_mt.__index:playing()
		return self._index ~= nil
	end
	function concat_mt.__index:stop()
		if self._index and self._animations[self._index] then
			self._animations[self._index]:stop()
		end
		self._index = nil
	end
	function concat_mt.__index:_on_update()
		if self._index then
			if not self._animations[self._index] then
				self._index = nil
			elseif not self._animation_started then
				self._animations[self._index]:play()
				self._animation_started = true
			elseif not self._animations[self._index]:playing() then
				self._index = self._index + 1
				self._animation_started = false
			end
		end
	end
	
	
	function animation_mt.__index:play()
		self._t0 = GetTime()
		self._original_values = {self._getter()}
	end
	function animation_mt.__index:stop()
		self._t0 = nil
	end
	function animation_mt.__index:playing()
		return self._t0 ~= nil
	end
	function animation_mt.__index:_current_changes(factor)
		local values = {}
		for i, change in ipairs(self._changes) do
			tinsert(values, self._original_values[i] + change * factor)
		end
		return unpack(values)
	end
	function animation_mt.__index:_on_update(factor)
		if self._t0 then
			local progress = GetTime() - self._t0
			if progress >= self._duration then
				self._callback(self:_current_changes(1))
				self._t0 = nil
			else
				self._callback(self:_current_changes(progress / self._duration))
			end
		end
	end
	
	
	function npcscan.animation(changes, duration, getter, callback)
		
		local self = { 
			_frame = CreateFrame'Frame',
			_changes = changes,
			_duration = duration,
			_getter = getter,
			_callback = callback,
		}
		setmetatable(self, animation_mt)
		
		self._frame:SetScript('OnUpdate', function()
			self:_on_update()
		end)
		
		return self
	end
end