
--[[
	 _______                           _                       ______                  _____  _____ __  _    
	|_   __ \                         (_)                     |_   _ \                |_   _||_   _[  |/ |_  
	  | |__) _ .--. .---. _ .--..--.  __ __   _  _ .--..--.     | |_) | ,--.  .--. .---.| |    | |  | `| |-' 
	  |  ___[ `/'`\/ /__\[ `.-. .-. |[  [  | | |[ `.-. .-. |    |  __'.`'_\ :( (`\/ /__\| '    ' |  | || |   
	 _| |_   | |   | \__.,| | | | | | | || \_/ |,| | | | | |   _| |__) // | |,`'.'| \__.,\ \__/ /   | || |,  
	|_____| [___]   '.__.[___||__||__[___'.__.'_[___||__||__] |_______/\'-;__[\__) '.__.' `.__.'   [___\__/  

--]]

local DrawColor, DrawLine, DrawRect, DrawText, GameCanUseSpell, GameHero, GameObject, GameObjectCount, GameTimer =
	Draw.Color, Draw.Line, Draw.Rect, Draw.Text, Game.CanUseSpell, Game.Hero, Game.Object, Game.ObjectCount, Game.Timer
local MathCeil, MathFloor, MathMax, MathSqrt = math.ceil, math.floor, math.max, math.sqrt

local function GameHeroCount()
	local c = Game.HeroCount()
	return (not c or c < 0 or c > 12) and 0 or c
end

local SpellData = {
	["Ashe"] = {
		speed = 1600, delay = 0.25, radius = 130, collision = true,
		type = 1, damage = function(lvl) return 200 * lvl + myHero.ap end
	},
	["Draven"] = {
		speed = 2000, delay = 0.4, radius = 160, collision = false,
		type = 2, damage = function(lvl) return 150 + 200 * lvl +
		(1.8 + 0.4 * lvl) * myHero.bonusDamage end
	},
	["Ezreal"] = {
		speed = 2000, delay = 1, radius = 160, collision = false,
		type = 2, damage = function(lvl) return 100 + 75 * lvl +
		0.5 * myHero.bonusDamage + 0.45 * myHero.ap end
	},
	["Jinx"] = {
		speed = 1700, delay = 0.6, radius = 140, collision = true,
		type = 2, damage = function(lvl) return 150 + 100 * lvl +
		1.5 * myHero.bonusDamage end
	}
}

function OnLoad()
	print("Loading PremiumBaseUlt...")
	if not SpellData[myHero.charName] then
		print("PremiumBaseUlt: Champion not supported!")
		return end
	DelayAction(function()
		BaseUlt:__init()
		print("PremiumBaseUlt successfully loaded!")
	end, MathMax(0.07, 30 - GameTimer()))
end

class "BaseUlt"

function BaseUlt:CalcMagicalDamage(source, target, amount)
	local mr = target.magicResist * source.magicPenPercent - source.magicPen
	return MathMax(0, MathFloor((mr < 0 and 2 - 100 / (100 - mr) or 100 / (100 + mr)) * amount))
end

function BaseUlt:CalcPhysicalDamage(source, target, amount)
	local ar = target.armor * source.armorPenPercent - (target.bonusArmor * (1 -
		source.bonusArmorPenPercent)) - (source.armorPen * (0.6 + (0.4 * (target.levelData.lvl / 18))))
	return MathMax(0, MathFloor((ar < 0 and 2 - 100 / (100 - ar) or 100 / (100 + ar)) * amount))
end

function BaseUlt:CalcTimeToHit(dist)
	local data = SpellData[self.CharName]
	local speed = data.speed
	if self.CharName == "Jinx" and dist > 1350 then
		local diff = MathMin(dist - 1350, 150)
		speed = (diff ^ 2 * 0.3 + (diff + 1350) *
			speed + 2200 * (dist - 1500)) / dist
	end
	return data.delay + dist / speed
end

function BaseUlt:Distance(p1, p2)
	local dx, dy = p2.x - p1.x, p2.z - p1.z
	return MathSqrt(dx * dx + dy * dy)
end

function BaseUlt:ForceUlt()
	self.Action = true
	local mm = Vector(self.Base):ToMM()
	Control.SetCursorPos(mm.x, mm.y)
	Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
	if cursorPos.x == mm.x then
		Control.CastSpell(HK_R, mm.x, mm.y)
		self.Action = false
	end
	Control.mouse_event(MOUSEEVENTF_LEFTUP)
end

function BaseUlt:IsUltReady()
	return GameCanUseSpell(_R) == READY
end

function BaseUlt:__init()
	self.Window = {x = Game.Resolution().x * 0.5, y = Game.Resolution().y * 0.5}
	self.Action, self.Allow, self.Done, self.Base, self.CharName, self.Mia,
		self.Recalls = false, nil, false, nil, myHero.charName, {}, {}
	for i = 1, GameObjectCount() do
		local obj = GameObject(i)
		if obj.isEnemy and obj.type == Obj_AI_SpawnPoint then
			self.Base = Vector(obj.pos); break
		end
	end
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPreMovement(function(...) self:OnPreMovement(...) end)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
		_G.PremiumOrbwalker:OnPreMovement(function(...) self:OnPreMovement(...) end)
	end
	Callback.Add("ProcessRecall", function(unit, recall)
		self:OnProcessRecall(unit, recall) end)
	Callback.Add("WndMsg", function(...) self:OnWndMsg(...) end)
	Callback.Add("Draw", function() self:OnDraw() end)
	Callback.Add("Tick", function() self:OnTick() end)
end

function BaseUlt:IsInsideTheBox(pt)
	local x, y = self.Window.x, self.Window.y
	return pt.x >= x and pt.x <= x + 375
		and pt.y >= y and pt.y <= y + 83
end

function BaseUlt:IsOnButton(pt)
	local x, y = self.Window.x, self.Window.y
	return pt.x >= x + 141 and pt.x <= x + 221
		and pt.y >= y + 46 and pt.y <= y + 74
end

function BaseUlt:OnPreAttack(args)
	if self.Action then args.Process = false end
end

function BaseUlt:OnPreMovement(args)
	if self.Action then args.Process = false end
end

function BaseUlt:OnProcessRecall(unit, recall)
	if unit.team == myHero.team then return end
	self.Recalls[unit.networkID] = recall.isStart and not
		recall.isFinish and {endTime = (GameTimer() + recall.totalTime * 0.001),
			duration = recall.totalTime * 0.001, process = false} or nil
end

function BaseUlt:OnWndMsg(msg, wParam)
	if self.Done then return end
	if self:IsOnButton(cursorPos) then
		self.Window.y = self.Window.y + 63
		self.Done = true; return end
	self.Allow = msg == 513 and wParam == 0 and self:IsInsideTheBox(cursorPos)
		and {x = self.Window.x - cursorPos.x, y = self.Window.y - cursorPos.y} or nil
end

function BaseUlt:DrawOutlineRect(x, y, w, h, t, c)
	DrawLine(x, y, x + w, y, t, c); DrawLine(x + w, y, x + w, y + h, t, c)
	DrawLine(x + w, y + h, x, y + h, t, c); DrawLine(x, y + h, x, y, t, c)
end

function BaseUlt:OnDraw()
	if not self.Done then
		if self.Allow then self.Window = {x = cursorPos.x +
			self.Allow.x, y = cursorPos.y + self.Allow.y} end
		DrawRect(self.Window.x, self.Window.y, 375, 83, DrawColor(224, 23, 23, 23))
		DrawText("Premium Base Ult", 14, self.Window.x + 136,
			self.Window.y + 7, DrawColor(192, 255, 255, 255))
		DrawText("Please move the window box to your favourite spot and click OK", 14,
			self.Window.x + 10, self.Window.y + 23, DrawColor(192, 255, 255, 255))
		DrawRect(self.Window.x + 141, self.Window.y + 46, 80, 28, DrawColor(224, 0, 128, 127))
		DrawText("OK", 14, self.Window.x + 173, self.Window.y + 53, DrawColor(192, 255, 255, 255))
		return
	end
	if not self:IsUltReady() or
		myHero.dead then return end
	local swap = 0
	for i = 1, GameHeroCount() do
		local hero = GameHero(i)
		if hero.valid and hero.isEnemy then
			local id = hero.networkID
			if self.Recalls[id] then
				local dur, timer = self.Recalls[id].duration,
					MathMax(0, self.Recalls[id].endTime - GameTimer())
				local pos = {x = self.Window.x, y = self.Window.y - swap * 60}
				DrawRect(pos.x, pos.y, timer / dur * 375, 16, DrawColor(192, 220, 220, 220))
				self:DrawOutlineRect(pos.x, pos.y, 375, 16, 3, DrawColor(224, 25, 25, 25))
				DrawText(hero.charName, 15, pos.x + 2, pos.y - 18, DrawColor(192, 255, 255, 255))
				local t = self:CalcTimeToHit(self:Distance(myHero.pos, self.Base))
				if t <= dur and self.Recalls[id].process then DrawRect(pos.x + t /
					dur * 375 - 2, pos.y, 5, 16, DrawColor(224, 220, 10, 30)) end
				swap = swap + 1
			end
		end
	end
end

function BaseUlt:OnTick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
		or Game.IsChatOpen() or myHero.dead or not self:IsUltReady() then return end
	for i = 1, GameHeroCount() do
		local hero = GameHero(i)
		if hero.valid and hero.isEnemy then
			local id, visible = hero.networkID, hero.visible
			if not visible and not self.Mia[id] then
				self.Mia[id] = GameTimer()
			elseif visible and self.Mia[id] then
				self.Mia[id] = nil
			end
			if self.Recalls[id] then
				local lvl = myHero:GetSpellData(_R).level
				local dmg = SpellData[self.CharName].damage(lvl)
				local dist = self:Distance(myHero.pos, self.Base)
				if self.CharName == "Jinx" then
					dmg = dmg * (0.1 + 0.0006 * MathMax(1500, dist)) +
						(0.2 + 0.05 * lvl) * (unit.maxHealth - unit.health)
				end
				local timeToHit, recallTime = self:CalcTimeToHit(dist),
					self.Recalls[id].endTime - GameTimer()
				if timeToHit <= self.Recalls[id].duration then
					local delta = timeToHit + recallTime + (self.Mia[id]
						and GameTimer() - self.Mia[id] or 0)
					dmg = dmg - MathCeil(delta) * hero.hpRegen
					dmg = SpellData[self.CharName].type == 2 and
						self:CalcPhysicalDamage(myHero, hero, dmg)
						or self:CalcMagicalDamage(myHero, hero, dmg)
					if dmg >= hero.health then
						self.Recalls[id].process = true
						if recallTime <= timeToHit + 0.1 and recallTime >
							timeToHit - 0.5 then self:ForceUlt() end
					end
				end
			end
		end
	end
end
