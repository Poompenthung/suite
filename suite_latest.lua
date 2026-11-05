--==[ Sailueat Suite — build มือถือ/คอม (Delta, Potassium, ฯลฯ) ]==--
-- หัวไฟล์: เติมเฉพาะฟังก์ชันที่ตัวรัน "ไม่มีจริง" (เช็กตัวแปรตรง ๆ ของจริงไม่ถูกแตะ) + กล่อง ERROR บนจอ เพราะ console ของตัวรันมือถือมักว่าง
if getgenv == nil then
	local _store = {}
	getgenv = function() return _store end
end
do
	local _fs = {}
	if isfile == nil then isfile = function(p) return _fs[p] ~= nil end end
	if readfile == nil then readfile = function(p) return _fs[p] or error("file does not exist") end end
	if writefile == nil then writefile = function(p, c) _fs[p] = c end end
	if isfolder == nil then isfolder = function() return true end end
	if makefolder == nil then makefolder = function() end end
	if setreadonly == nil then setreadonly = function() end end
	if getgc == nil then getgc = function() return {} end end
	if getupvalue == nil then getupvalue = function() return nil end end
	if getconnections == nil then getconnections = function() return {} end end
	if fireproximityprompt == nil then fireproximityprompt = function(p) pcall(function() p:InputHoldBegin() task.wait(0.05) p:InputHoldEnd() end) end end
	if queue_on_teleport == nil then queue_on_teleport = function() end end
	if setfpscap == nil then setfpscap = function() end end
end

-- กล่องสถานะ/ERROR บนจอ (ตัวรันมือถือกลืน error เงียบ ๆ) หายเองใน 8 วิถ้าไม่พัง
local _task_spawn = task.spawn
do
	local host = select(2, pcall(function() return gethui and gethui() end))
	if not host then host = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
	local sg = Instance.new("ScreenGui")
	sg.Name, sg.ResetOnSpawn, sg.IgnoreGuiInset, sg.DisplayOrder = "SailueatBoot", false, true, 999
	sg.Parent = host
	local lb = Instance.new("TextLabel", sg)
	lb.Size, lb.Position = UDim2.new(1, -20, 0, 70), UDim2.fromOffset(10, 60)
	lb.BackgroundColor3, lb.BackgroundTransparency, lb.TextColor3 = Color3.new(0, 0, 0), 0.3, Color3.new(1, 1, 1)
	lb.TextWrapped, lb.TextSize, lb.Font, lb.TextXAlignment = true, 14, Enum.Font.Code, Enum.TextXAlignment.Left
	lb.Text = "Sailueat: กำลังโหลด (รอตัวละครเข้าแมพ)..."
	local bad = false
	task = setmetatable({
		spawn = function(f, ...)
			local a = { ... }
			return _task_spawn(function()
				local ok, e = xpcall(f, function(m) return m .. "\n" .. debug.traceback("", 2) end, table.unpack(a))
				if not ok then
					bad = true
					lb.TextColor3, lb.Size = Color3.fromRGB(255, 120, 120), UDim2.new(1, -20, 0, 150)
					lb.Text = "ERROR: " .. tostring(e):sub(1, 400)
				end
			end)
		end,
	}, { __index = task })
	task.delay(8, function() if not bad and sg.Parent then sg:Destroy() end end)
end

--==[ Sailueat Suite v3 — Rayfield ]==--
-- SilentAim(หัว) / ESP ผู้เล่น / ESP จุดขายยา+ร้านพเนจร / นับถอยหลังอีเวนต์ / Stamina / ปืน / AutoTrash / FPS
-- rejoin แล้วรันตัวนี้ตัวเดียวพอ มันรอโหลดเกมเสร็จเอง

--========================= รองรับตัวรันมือถือ (Delta/iOS) =========================
-- อยู่นอก task.spawn ตั้งใจ: ฟังก์ชันหลักข้างล่างชน "เพดาน 200 local ของ Luau" แล้ว เพิ่ม local ในนั้นอีกตัวเดียวก็คอมไพล์ไม่ผ่าน
do
	local UISd = game:GetService("UserInputService")
	local mobile = UISd.TouchEnabled and not UISd.KeyboardEnabled

	-- mouse1click: มือถือไม่มีเมาส์ ตัวรันหลายตัวไม่มีฟังก์ชันนี้ → ยิงด้วย VirtualInputManager ที่กลางจอ (triggerbot ถึงจะทำงาน)
	if mouse1click == nil then
		mouse1click = function()
			local vp = workspace.CurrentCamera.ViewportSize
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 1)
			task.wait(0.03)
			vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 1)
		end
	end

	-- Drawing แบบ native: Drawing ของตัวรันมือถือ "มีฟังก์ชันแต่ไม่วาดจริง" (เจอกับ Delta: Drawing=true แต่จอว่าง)
	-- สร้างทับด้วย Frame/TextLabel จริง ทุกที่ที่เรียก Drawing.new ได้ของเหมือนเดิม (ESP ผู้เล่น/จุดสำคัญ/วง FOV/จุดแดง)
	-- บังคับเองได้: getgenv().SuiteNativeDraw = true/false ก่อนรัน
	local force = getgenv().SuiteNativeDraw
	if force == true or (force == nil and (mobile or Drawing == nil)) then
		local host = select(2, pcall(function() return gethui and gethui() end))
		if not host then host = select(2, pcall(function() local c = game:GetService("CoreGui") c:GetFullName() return c end)) end
		if not host then host = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
		local prev = host:FindFirstChild("SuiteDraw")
		if prev then pcall(function() prev:Destroy() end) end
		local scr = Instance.new("ScreenGui")
		scr.Name, scr.IgnoreGuiInset, scr.ResetOnSpawn, scr.DisplayOrder = "SuiteDraw", true, false, 5
		scr.Parent = host
		getgenv().SuiteDrawGui = scr

		-- Drawing: Transparency 1 = ทึบ (กลับทางกับ Roblox) | Circle.Position = จุดกึ่งกลาง, Square.Position = มุมบนซ้าย
		local function apply(d)
			local g, tr = d._g, 1 - (tonumber(d.Transparency) or 1)
			g.Visible = d.Visible == true
			if not g.Visible then return end
			local col = d.Color or Color3.new(1, 1, 1)
			if d._t == "Text" then
				g.Text, g.TextColor3, g.TextTransparency = tostring(d.Text or ""), col, tr
				g.TextSize = tonumber(d.Size) or 13
				g.TextStrokeTransparency = d.Outline and tr or 1
				g.TextStrokeColor3 = d.OutlineColor or Color3.new()
				g.TextXAlignment = d.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
				local p = d.Position or Vector2.zero
				g.Size = UDim2.fromOffset(320, g.TextSize + 4)
				g.Position = UDim2.fromOffset(p.X - (d.Center and 160 or 0), p.Y)
			elseif d._t == "Line" then
				local a, b = d.From or Vector2.zero, d.To or Vector2.zero
				g.BackgroundColor3, g.BackgroundTransparency = col, tr
				g.Size = UDim2.fromOffset(math.max((b - a).Magnitude, 1), math.max(tonumber(d.Thickness) or 1, 1))
				g.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
				g.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
			else
				if d._t == "Circle" then
					local r = tonumber(d.Radius) or 0
					local p = d.Position or Vector2.zero
					g.Position, g.Size = UDim2.fromOffset(p.X - r, p.Y - r), UDim2.fromOffset(r * 2, r * 2)
				else
					local p, s = d.Position or Vector2.zero, d.Size or Vector2.zero
					g.Position, g.Size = UDim2.fromOffset(p.X, p.Y), UDim2.fromOffset(s.X, s.Y)
				end
				if d.Filled then
					g.BackgroundColor3, g.BackgroundTransparency, d._s.Transparency = col, tr, 1
				else
					g.BackgroundTransparency = 1
					d._s.Color, d._s.Transparency, d._s.Thickness = col, tr, math.max(tonumber(d.Thickness) or 1, 1)
				end
			end
		end

		-- เขียนค่าลง Instance รอบเดียวต่อเฟรม: ESP เขียนพรอพ ~25 ครั้ง/คน/เฟรม ถ้า apply ทุกครั้งที่เขียน = หลายพันครั้ง/เฟรม มือถือเฟรมตก
		-- ต้องผูกที่ Last+1 ไม่ใช่ RenderStepped: RenderStepped ทำงาน "ก่อน" กล้องอัปเดตและก่อน SuiteLoop (Last=2000) ที่คำนวณตำแหน่ง
		-- → ภาพที่ได้คือพิกัดของเฟรมที่แล้ว ช้ากว่ากล้อง 1 เฟรม = กรอบ ESP ว่ายไปมา/กระพริบตอนหันจอ (อาการที่เจอบนมือถือ)
		local dirty = {}
		pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SuiteDrawFlush") end)
		game:GetService("RunService"):BindToRenderStep("SuiteDrawFlush", Enum.RenderPriority.Last.Value + 1, function()
			if not next(dirty) then return end
			for d in pairs(dirty) do
				dirty[d] = nil
				if d._g.Parent then pcall(apply, d) end
			end
		end)

		Drawing = { Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 } }
		function Drawing.new(kind)
			local g
			if kind == "Text" then
				g = Instance.new("TextLabel")
				g.BackgroundTransparency, g.Font, g.TextScaled = 1, Enum.Font.GothamBold, false
			else
				g = Instance.new("Frame")
				g.BorderSizePixel, g.BackgroundTransparency = 0, 1
				if kind == "Line" then g.AnchorPoint = Vector2.new(0.5, 0.5) end
			end
			g.Visible, g.ZIndex, g.Parent = false, 10, scr
			local d = { _t = kind, _g = g, Visible = false, Transparency = 1, Thickness = 1, Filled = false, Color = Color3.new(1, 1, 1) }
			if kind ~= "Text" then
				d._s = Instance.new("UIStroke", g)
				d._s.Transparency = 1
				if kind == "Circle" then Instance.new("UICorner", g).CornerRadius = UDim.new(1, 0) end
			end
			return setmetatable({}, {
				__index = function(_, k)
					if k == "Remove" or k == "Destroy" then return function() pcall(function() g:Destroy() end) end end
					return d[k]
				end,
				__newindex = function(_, k, v) d[k] = v dirty[d] = true end,
			})
		end
	end
end

task.spawn(function()

--========================= รอเข้าเกม =========================
local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local CoreGui = (function() local ok,c=pcall(function() local x=game:GetService("CoreGui"); x:FindFirstChild("x"); return x end) return ok and c or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end)()
while not Players.LocalPlayer do task.wait(0.5) end
local lp = Players.LocalPlayer
while not lp.Character do task.wait(0.5) end
task.wait(2)
local cam = workspace.CurrentCamera

-- ลบ UI เก่าก่อนเสมอ ไม่งั้นหน้าต่างซ้อนกันแล้วดูเหมือนค้าง
for _, n in ipairs({ "Rayfield", "Sirius", "SiriusNotification", "SailueatUI" }) do
	local old = CoreGui:FindFirstChild(n)
	if old then pcall(function() old:Destroy() end) end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local old2 = pg and pg:FindFirstChild(n)
	if old2 then pcall(function() old2:Destroy() end) end
end

--========================= CONFIG =========================
local S = {
	-- aim
	AimOn = true, FovPx = 110, StickFovPx = 140, MaxDist = 600,
	TeamCheck = true, ShowFov = true, AimNPC = false,  -- เล็ง NPC ด้วย (ตำรวจ/ประชาชน ฯลฯ ไม่ใช่แค่ผู้เล่น)
	-- esp ผู้เล่น
	EspOn = true, EspBox = true, EspTeam = true, EspDist = 1200, EspTextSize = 17, EspHz = 30,
	-- esp จุด
	PointOn = true, PointDrug = true, PointShop = true, PointTextSize = 18, EdgePad = 40,   -- PointDrug = จุดขายยา, PointShop = ร้านค้ามืด
	ItemDist = 350,    -- ระยะที่เห็นรูปอาวุธใต้ตัวแต่ละคน
	-- ปืน
	NoSpread = true, FireMul = 1, ReloadMul = 0.4, EquipMul = 0.1,   -- 0.45 ค้างต่อเนื่อง 20 วิ = ถูกเตะ (Anti System 49) | 0.6 ใช้เป็นช่วง ๆ (burst) ตัวคุมด้านล่างถอยเป็น x1.0 ถ้ายิงค้าง
	Trigger = false, TrigSpray = true, HoldSpray = true, CrouchKeep = true, TriggerDist = 300, TriggerAngle = 6, MaxCPS = 40, TrigOnly = false, FovFollow = true, WantedEsp = true, AimAngle = 4,
	GunRange = {},   -- ระยะที่เชื่อถือได้ของปืนแต่ละกระบอก (ชื่อปืน = studs) ตั้งจากสไลเดอร์ในแท็บปืน 0/ไม่มี = อัตโนมัติจากค่าปืน 
	ItemPanel = true, ItemHideTeam = false, HoldMax = 1.5, CfgVer = 0,   -- ItemPanel = แผงของในตัวเป้า (เดิมหลุดไปอยู่ในคอมเมนต์ = ไม่เคยจำค่า) | CfgVer = เวอร์ชันค่าที่จำไว้ ไว้รีเซ็ตค่าพื้นฐานครั้งเดียว
	MeleeFast = true, MeleeMul = 0.75, MeleePct = 40, AutoRate = true, BulletMul = 1, LatComp = 0, Jitter = true, JitterAmp = 15, JitterWalk = 15, Dodge = false, DodgeAmp = 20, DodgeRadius = 15, DodgeWalk = 4, DownedDodge = true, DownedAmp = 1.2, LagStyle = false, LagStyleAmp = 1.5, Lag = false, LagTime = 0.05, AtkSuspend = true, AtkWin = 0.35, AtkJitter = 3,   -- ฟันเร็ว (มีด) MeleePct = % เร็วขึ้นจากดีเลย์เดิมของแต่ละอาวุธ (0-50)
	FireFloor = 0.15,   -- ช่วงเวลายิงต่ำสุด (วิ) ระหว่างนัด ทุกปืนไม่ให้เร็วกว่านี้
	NoHeat = true, NoRecoil = true, MuteReload = true, InstantPrompt = true,
	-- ตัวละคร
	StaminaOn = true, SpeedBonus = 0,
	-- auto
	DigMult = 1.3,     -- 1.4+ เซิร์ฟตีตก (เส้นแบ่ง 24-25 วิ/กอง)
	TrashSearch = 80,
	AutoSell = true, SellEvery = 4,   -- ฟาร์มครบกี่กองแล้วเดินไปขายให้ NPC
	AutoTrash = false, AutoCandy = false, LowGfx = false, FpsUnlock = false,   -- จำข้ามรอบรัน | LowGfx/FpsUnlock เปิดอัตโนมัติตอนรัน
	SellPick = {},     -- ไอเท็มที่จะขาย (ติก) ว่างหรือไม่มีเลย = ขายหมด; มีบางตัว = ขายเฉพาะที่ติก
}
--========================= จำค่า (CONFIG PERSISTENCE) =========================
-- รันใหม่ไม่ต้องตั้งค่าใหม่ จำค่าล่าสุดไว้ในไฟล์ (executor ต้องมี writefile/readfile)
local CFG_DIR, CFG_FILE = "SailueatSuite", "SailueatSuite/config.json"
local HS = game:GetService("HttpService")
local function loadCfg()
	if not (readfile and isfile) then return end
	local okf, has = pcall(isfile, CFG_FILE)
	if not (okf and has) then return end
	local ok, data = pcall(function() return HS:JSONDecode(readfile(CFG_FILE)) end)
	if not ok or type(data) ~= "table" then return end
	for k, v in pairs(data) do
		if k == "SellPick" and type(v) == "table" then S.SellPick = v
		elseif S[k] ~= nil and type(S[k]) == type(v) then S[k] = v end
	end
	print("[CFG] โหลดค่าที่จำไว้แล้ว")
end
loadCfg()
-- ค่าที่จำไว้ในไฟล์อาจเร็วกว่าขีดปลอดภัย (ตั้งไว้รอบก่อน ๆ) บังคับกลับมาที่ขีดทุกครั้งที่โหลด
-- FireMul ล็อก 0.4: ทดสอบจริง 31/10 ยิงชุดละ 12 นัดที่ 0.30/0.25/0.20/0.17/0.14/0.11 วิ ผ่านหมดไม่โดนเตะ (ที่โดนเตะคือรัวค้าง ~75 นัด/20 วิ)
-- ทดสอบจริง: โดนเตะ Anti System 49 เพราะ "เร่งรีโหลด" (ReloadMul 0.2) ไม่ใช่ยิงรัว | รีโหลด/ชักปืนล็อกที่ x1.0 | ยิงรัวแบบปืนกล FireMul 0.1 (ผ่าน ~9 นัด/วิ ต่อแม็ก)
-- ทดสอบจริง 31/10: ชักปืน x0.1 ชัก-เก็บ 8 รอบ ผ่าน (ไม่โดนเตะ) | รีโหลด x0.2 ยิงนัดเดียวแล้วรีโหลด 5 รอบ ผ่าน แต่รอบยิงเต็มแม็ก+รีโหลดเร็วติดกันเคยโดนเตะ จึงยังล็อกรีโหลดที่ 1.0 ไว้ก่อน
-- ค่าพื้นฐาน (ทดสอบผ่าน): ชักปืน 0.1 | รีโหลด 0.4 (โหลดนัดเดียว 5 รอบผ่าน ที่ 0.2 ก็ผ่านแบบนัดเดียว แต่เต็มแม็กรัวติดกันยังไม่ยืนยัน) | ปรับเองได้ที่สไลเดอร์ ค่าที่ปรับจะถูกจำ
-- ไฟล์ config เก่าที่จำค่าไว้ก่อนเวอร์ชันนี้ (CfgVer < 2) จะถูกตั้งกลับเป็นค่าพื้นฐานครั้งเดียว หลังจากนั้นค่าที่ปรับเองจะอยู่ถาวร
if S.CfgVer < 2 then S.CfgVer, S.ReloadMul, S.EquipMul = 2, 0.4, 0.1 end
-- CfgVer 3: ดัน EspHz จาก 30 เป็น 60 ครั้งเดียว — 30 ครั้ง/วิ บนจอ 60fps = กรอบขยับเฟรมเว้นเฟรม เห็นเป็นกรอบว่ายตามตัวตอนหันจอ (ชัดมากบนมือถือที่ปัดนิ้วหันเร็ว)
-- ถ้า fps ตก ลดเองได้ที่สไลเดอร์ "อัตราวาด" แล้วค่าที่ลดจะถูกจำ ไม่ถูกดันขึ้นอีก
if S.CfgVer < 3 then S.CfgVer, S.EspHz = 3, 60 end
-- CfgVer 4: กราฟิกต่ำ/ปลดล็อก FPS ไม่เปิดเองตอนรันแล้ว (ค่าเก่าในเซฟถูกบังคับให้เปิดมาตลอด) รีเซ็ตเป็นปิดครั้งเดียว หลังจากนี้ใครเปิดไว้ก็จำค่านั้นข้ามรอบ
if S.CfgVer < 4 then S.CfgVer, S.LowGfx, S.FpsUnlock = 4, false, false end
S.ReloadMul, S.EquipMul = math.clamp(S.ReloadMul, 0.2, 1), math.clamp(S.EquipMul, 0.1, 1)
S.FireMul = math.clamp(S.FireMul, 0.1, 1)   -- ปรับได้จากสไลเดอร์ "ความรัวปืน" ในแท็บปืน
S.MaxCPS = math.max(S.MaxCPS, 40)   -- 0.4 → 0.6: ปืนช้า (Double Barrel 0.43) เคยถูกเร่งเป็น 0.17 = 2.5 เท่าของปืนจริง
S.FireFloor = 0.03
-- ตรึงค่าที่ซ่อนจากเมนู (ไม่มีสวิตช์แล้ว ค่าเก่าในไฟล์เซฟต้องไม่ค้างมาแทน): เล็ง NPC ปิด | Triggerbot รัวเป็นชุด เปิด | ปิดคลิกเอง ปิด | ล็อกค้างถึง 200
-- (ค่าพื้นฐานเดิมของสคริปต์ทั้งหมด ตัวทำงานไม่ได้ถูกแตะ) | อยากเปลี่ยนค่าไหนแก้ตรงนี้ที่เดียว
S.AimNPC, S.TrigSpray, S.TrigOnly, S.StickFovPx = false, true, false, 200
-- ซ่อนเพิ่ม: ตำรวจ ★ ผู้ต้องหา เปิด | กระสุนเกาะกลุ่ม เปิด | ไม่ร้อน เปิด | ไม่มีรีคอยล์ เปิด | ตัดเสียงรีโหลด เปิด (ค่าพื้นฐานเดิมทั้งหมด)
S.WantedEsp, S.NoSpread, S.NoHeat, S.NoRecoil, S.MuteReload = true, true, true, true, true
-- ซ่อนแท็บปืนเพิ่ม: ระยะเชื่อถือได้ = อัตโนมัติ (ล้างค่าที่เคยตั้งเองในเซฟ) | ฟันมีดเร็วขึ้น เปิด 40% | ปรับความรัวอัตโนมัติ เปิด | ท่าแลคกระตุกตอนปกติ ปิด (ลบออก)
S.GunRange, S.MeleeFast, S.MeleePct, S.AutoRate, S.LagStyle = {}, true, 40, true, false
-- เดินปกติ = 8, วิ่ง (sprint) ของเกม = 18 (วัดจริง) | ทดสอบ 31/10: ความเร็วตายตัวผ่านถึง 26, โดนเตะที่ 30 (Anti System 25)
-- SpeedCap = ความเร็วรวมสูงสุดไม่ว่าเดิน/วิ่ง (เผื่อขอบ 2 จาก 26) | SpeedMax = ค่าบวกสูงสุดของสไลเดอร์ (ฐานเดิน 8 + 16 = 24)
local SpeedCap, SpeedMax = 24, 16
S.SpeedBonus = math.min(S.SpeedBonus, SpeedMax)
local lastSaved
local function saveCfg()
	if not writefile or getgenv().SuiteNoSave then return end   -- SuiteNoSave: ตอนชุดทดสอบสลับค่า ไม่เขียนค่าชั่วคราวทับ config.json
	local ok, enc = pcall(function() return HS:JSONEncode(S) end)
	if ok and enc ~= lastSaved then
		if makefolder and isfolder and not isfolder(CFG_DIR) then pcall(makefolder, CFG_DIR) end
		if pcall(writefile, CFG_FILE, enc) then lastSaved = enc end
	end
end
getgenv().SuiteSaveCfg = saveCfg

getgenv().SuiteCfg = S
local gen = (getgenv().SuiteGen or 0) + 1
getgenv().SuiteGen = gen
local function live() return getgenv().SuiteGen == gen end

--========================= LOG เหตุการณ์ (ไว้ไล่สาเหตุตอนโดนเตะ) =========================
-- เขียนลง SailueatSuite/log.txt ทุกเหตุการณ์ทันที เก็บ 120 บรรทัดล่าสุด | หลังโดนเตะ เปิดไฟล์ดูนัดสุดท้ายก่อนหลุดได้
local LOG_FILE = "SailueatSuite/log.txt"
local logLines, lastClick, clicks = {}, 0, {}
local function log(msg)
	logLines[#logLines + 1] = string.format("%s %.2f %s", os.date("%H:%M:%S"), os.clock(), msg)
	if #logLines > 120 then table.remove(logLines, 1) end
	if writefile then
		if makefolder and isfolder and not isfolder("SailueatSuite") then pcall(makefolder, "SailueatSuite") end
		pcall(writefile, LOG_FILE, table.concat(logLines, "\n"))
	end
end
getgenv().SuiteLog = log
UIS.InputBegan:Connect(function(i)
	-- มือถือยิงด้วยนิ้ว = UserInputType.Touch ไม่ใช่ MouseButton1 (เช็กแค่เมาส์ = ทุกอย่างที่นับคลิกตายหมดบนมือถือ)
	if not live() or (i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch) then return end
	local t = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
	if not t then return end
	local now = os.clock()
	log(string.format("click tool=%s gap=%.3f lock=%s", t.Name, now - lastClick, tostring(getgenv().SuiteLock)))
	lastClick = now
	-- นับเฉพาะ "นัดที่ปืนยอมให้ยิงจริง" (ห่างจากนัดก่อน >= ~อัตรายิงปัจจุบัน) คลิกรัวที่ปืนปัดทิ้งเพราะคูลดาวน์ไม่นับ
	if t:FindFirstChild("Setting") then
		local ok, cfg = pcall(require, t.Setting)
		local fr = (ok and type(cfg) == "table" and tonumber(cfg.FireRate)) or 0.25
		if now - (getgenv().SuiteLastShot or 0) >= fr * 0.9 then
			getgenv().SuiteLastShot = now
			clicks[#clicks + 1] = now
			-- วัดความแม่นจริง: นัดที่ยิงตอนมีล็อกเป้า ดูว่าเลือดเป้าลดภายใน 1.2 วิไหม (บันทึก RES ... HIT/miss ใน log.txt)
			local lc = getgenv().SuiteLockChar
			local th = lc and lc:FindFirstChildOfClass("Humanoid")
			if th then
				local h0, nm = th.Health, lc.Name
				task.delay(1.2, function() log(string.format("RES %s %s hp %d->%d", nm, th.Health < h0 and "HIT" or "miss", h0, th.Health)) end)
			end
		end
	end
end)
-- ตัวจำกัดคลิก: กิน MouseButton1 ที่เกิน S.MaxCPS ครั้ง/วินาที ไม่ให้ไปถึงปืน/เซิร์ฟเวอร์ (ทดสอบแล้ว: ContextActionService Sink กันปืนยิงได้จริง)
-- รอบกดรัว 14 คลิก/วิ นาน 20 วิ โดนเตะ → จำกัดเพดานที่ MaxCPS (ค่าเริ่มต้น 6) | S.TrigOnly = ห้ามคลิกเอง ให้เฉพาะคลิกของ Triggerbot ผ่าน
do
	local CASg = game:GetService("ContextActionService")
	pcall(function() CASg:UnbindAction("SuiteClickGuard") end)
	local times, sunk = {}, false
	CASg:BindActionAtPriority("SuiteClickGuard", function(_, state)
		if not live() then return Enum.ContextActionResult.Pass end
		if state ~= Enum.UserInputState.Begin then
			local r = sunk and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
			if state == Enum.UserInputState.End then sunk = false end
			return r
		end
		local now = os.clock()
		for i = #times, 1, -1 do if now - times[i] > 1 then table.remove(times, i) end end
		local isTrig = now - (getgenv().SuiteTrigClickAt or -1) < 0.15
		if (S.TrigOnly and not isTrig) or #times >= S.MaxCPS then
			sunk = true
			return Enum.ContextActionResult.Sink
		end
		sunk = false
		times[#times + 1] = now
		return Enum.ContextActionResult.Pass
	end, false, 9000, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
end

-- ตัวคุมจังหวะ: ยิงรัวได้เป็นช่วง ๆ (burst) แล้วถอยกลับอัตรายิงเดิมของปืนถ้ากดต่อเนื่อง กันโดน "ยิงรัวค้าง" (Anti System 49)
-- คลิกใน 4 วิล่าสุด < BURST_MAX = ใช้ค่าเร่ง (FireMul) | เกิน = ใช้ x1.0 จนกว่าจะหยุดยิงสักพัก
-- ชุดละ BURST_SHOTS นัด: ยิงรัวเร่งเต็ม (FireMul) ได้ BURST_SHOTS นัดภายใน BURST_WIN วิ แล้วติดคูลดาวน์ CD_TIME วิ
-- (ช่วงคูลดาวน์อัตรายิงปืนถูกดันเป็น >= CD_TIME ต่อนัด) หมดคูลดาวน์แล้วเริ่มชุดใหม่ | เฉลี่ย 3 นัด/1.5 วิ = 2 นัด/วิ ต่ำกว่าปืนจริง (Beretta 3.3 นัด/วิ)
local BURST_SHOTS, BURST_WIN, CD_TIME = 1e9, 2.0, 2.0   -- ปิดตัวคูลดาวน์: ทดสอบแล้วอัตรายิงไม่ใช่สาเหตุเตะ   -- 6 นัดรัว + คูลดาวน์ 2 วิ ≈ 2.2 นัด/วิ เฉลี่ย (ที่โดนเตะ ~3.7 นัด/วิ ค้าง 20 วิ)
local cdUntil = 0
task.spawn(function()
	while live() do
		local now, n = os.clock(), 0
		for i = #clicks, 1, -1 do if now - clicks[i] > BURST_WIN then table.remove(clicks, i) else n += 1 end end
		local cd = now < cdUntil
		if not cd and n >= BURST_SHOTS then   -- ครบ 3 นัดไว ๆ → ติดคูลดาวน์
			cdUntil, cd = now + CD_TIME, true
			table.clear(clicks)
			log("cooldown " .. CD_TIME .. "s")
		end
		if cd ~= (getgenv().SuiteCd == true) then
			getgenv().SuiteCd = cd
			getgenv().SuiteMulNow = S.FireMul
			if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end   -- ปรับ FireRate ทันที ไม่รอรอบ 0.25 วิ
		end
		task.wait(0.1)
	end
end)
task.spawn(function()
	task.wait(1)
	log(string.format("start aim=%s trig=%s fireMul=%.2f floor=%.2f melee=%s/%.2f free=%s", tostring(S.AimOn), tostring(S.Trigger),
		S.FireMul, S.FireFloor, tostring(S.MeleeFast), S.MeleeMul, tostring(getgenv().SuiteFree)))
	while live() do
		task.wait(5)
		local t = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
		-- + ข้อมูลการเคลื่อนที่ (noclip / ความเร็วจริง / WalkSpeed) ไว้ไล่สาเหตุเตะแบบ Anti System 25
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		local rt = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local v = rt and rt.AssemblyLinearVelocity or Vector3.zero
		log(string.format("hb tool=%s lock=%s trig=%s free=%s noclip=%s ws=%.1f vel=%.1f", t and t.Name or "-", tostring(getgenv().SuiteLock),
			tostring(S.Trigger), tostring(getgenv().SuiteFree), tostring(S.Noclip), hum and hum.WalkSpeed or 0, Vector3.new(v.X, 0, v.Z).Magnitude))
	end
end)

--========================= CLEANUP =========================
-- ห้ามใส่ "SuiteDrawFlush" ตรงนี้: ตัวนั้นถูกผูกไว้แล้วในบล็อกหัวไฟล์ (นอก task.spawn) ซึ่งรันไปก่อนบรรทัดนี้ ใส่แล้วจะปลดทิ้งเอง = Drawing หยุดอัปเดตทั้งหมด
for _, n in ipairs({ "SuiteLoop", "PointEsp", "SuiteJitterRS", "SuiteItemLoop" }) do pcall(function() RS:UnbindFromRenderStep(n) end) end
for _, k in ipairs({ "SuiteProp", "SuiteGuiAdd", "SuiteRem", "SuiteStam",
	"PEAdd", "PERem", "PEAnn", "NWConn", "SpeedConn", "SpeedHumConn", "EvConn", "AfkConn", "StamRespawn", "NoclipConn", "InstPromptConn", "SuiteCrouchConn", "SuiteStatsConn", "AimStatsConn", "SuiteJitterConn", "SuiteDodgeConn", "SuiteGfxConn", "SuitePromptConn" }) do
	local v = getgenv()[k]
	if typeof(v) == "RBXScriptConnection" then pcall(function() v:Disconnect() end) end
	if type(v) == "table" then for _, c in pairs(v) do pcall(function() c:Disconnect() end) end end
	getgenv()[k] = nil
end
for _, k in ipairs({ "SuiteEsp", "PEDraw" }) do
	if getgenv()[k] then
		for _, e in pairs(getgenv()[k]) do for _, d in pairs(e) do pcall(function() d:Remove() end) end end
	end
	getgenv()[k] = {}
end
if getgenv().SuiteFov then pcall(function() getgenv().SuiteFov:Remove() end) end
if getgenv().SuiteMarker then pcall(function() getgenv().SuiteMarker:Remove() end) end
getgenv().SuiteTrashRunning = nil   -- กัน trashLoop ซ้อนจากรอบรันก่อน
getgenv().SuiteMulNow, getgenv().SuiteCd, getgenv().SuiteAutoOff = nil, nil, nil   -- ค่าค้างจากรอบก่อนทับ FireMul/สไลเดอร์ความรัว (เจอจริง: FireRate ค้าง 0.03 ทั้งที่ตั้ง 0.2)

-- โยกตัวลวงคนยิง: Heartbeat (หลังฟิสิกส์ ก่อนส่งเน็ต) ขยับ HumanoidRootPart ±JitterAmp ตามแกนขวา, RenderStepped (First) ดึงกลับก่อนกล้อง/อินพุต/ฟิสิกส์
-- = เราไม่เห็น/ควบคุมตามปกติ แต่ตำแหน่งที่ส่งออกกระตุก | ทดสอบ 31/10: โยก 6 วิ ±1 ไม่โดนเตะ, ตำแหน่งที่เห็นเองเลื่อน 0.00 (ฝั่งคนอื่นเห็นจริงหรือไม่ยังไม่ยืนยัน)
-- ทำเป็นช่วง JIT_ON วิ / พัก JIT_OFF วิ ไม่ค้างตลอด (Anti System 25 เช็กความเร็วย้ายตำแหน่ง) | ปิดตอนถอดจิต/ตาย/นั่ง
do
	local JIT_T0 = os.clock()
	local JIT_ON, JIT_OFF = 4, 0   -- JIT_OFF = 0: โยกต่อเนื่องไม่พัก (ตามที่สั่ง) | ใส่ > 0 ถ้าอยากกลับมาเป็นช่วง ๆ
	local applied, hrpRef, sign = Vector3.zero, nil, 1
	pcall(function() RS:UnbindFromRenderStep("SuiteJitterRS") end)
	RS:BindToRenderStep("SuiteJitterRS", Enum.RenderPriority.First.Value, function()
		if applied ~= Vector3.zero then
			if hrpRef and hrpRef.Parent then hrpRef.CFrame = hrpRef.CFrame - applied end
			applied = Vector3.zero
		end
	end)
	-- หลบกระสุนที่เล็งมาหาเรา: ฟัง VisualizeBullet (ส่งมาเฉพาะนัดของคนอื่น) คำนวณวิถี (ความเร็ว+แรงตก) หาจุดที่ใกล้ตัวเรามากสุด
	-- ถ้าห่าง < DodgeRadius และกระสุนยังบินอีก ≥ 0.08 วิ → ขยับตำแหน่งที่ส่งออกไปด้านข้าง (ตั้งฉากวิถี ฝั่งที่ห่างจากวิถี) DodgeAmp ตลอดเวลาบิน + 0.15 วิ
	-- ยังไม่ยืนยันว่าเซิร์ฟตัดสินโดนจากตำแหน่งที่รับ ณ เวลากระสุนถึง | นับ "กระสุนที่เล็งมา" กับ "เลือดเราลด" ลง log.txt เทียบเปิด/ปิดได้
	local dodges, stat, lastLog, lastHp = {}, { aimed = 0, hit = 0, hitDodging = 0 }, 0, nil
	getgenv().SuiteDodgeStat = stat
	-- หน่วงตัวละคร (fake lag): ตำแหน่งที่ส่ง = ตำแหน่งจริงเมื่อ LagTime วิที่แล้ว (เส้นทางเดิมแค่ช้ากว่า ความเร็วย้ายตำแหน่งยังปกติ ไม่กระโดด)
	-- เก็บประวัติตำแหน่งจริง (หลังฟิสิกส์ ก่อนบวกออฟเซ็ต) 1 วิ | ออฟเซ็ตจำกัด 12 studs
	-- act: 1 = โยก/หลบ/หน่วงเต็ม, 0 = ปิดชั่วคราว: คลิกใช้ของในมือ (ต่อย/ยิง) → ลดเป็น 0 ใน 0.2 วิ ค้าง 0.7 วิหลังคลิกล่าสุด แล้วค่อยกลับ 0.5 วิ
	-- เหตุ: เซิร์ฟตัดสินการต่อยจากตำแหน่งที่รับ ซึ่งตอนนี้ถูกโยก/หน่วงอยู่ → ตัวเราไม่อยู่ใกล้เป้าจริง เลือดเป้าไม่ลดบางครั้ง
	local act, lastT, lastHop, lastStep, hopPend = 1, nil, 0, Vector3.zero, Vector3.zero
	local shownPrompts = {}
	do
		local PPS = game:GetService("ProximityPromptService")
		getgenv().SuitePromptConn = {
			PPS.PromptShown:Connect(function(p) shownPrompts[p] = true end),
			PPS.PromptHidden:Connect(function(p) shownPrompts[p] = nil end),
		}
	end
	local outs, byMode, resolved = {}, {}, 0
	local hpEvs, evLines = {}, {}   -- hpEvs = เหตุการณ์เลือดเราลด (จับคู่กับกระสุนทีละนัด ไม่นับซ้ำ) | evLines = บรรทัดต่อกระสุนสะสมข้ามรอบ (dodge_events.txt)
	local EVF = "SailueatSuite/dodge_events.txt"
	pcall(function()
		if isfile and isfile(EVF) then for ln in string.gmatch(readfile(EVF), "[^\n]+") do evLines[#evLines + 1] = ln end end
	end)
	getgenv().SuiteDodgeModes = byMode
	-- สถิติหลบสะสมข้ามรอบรัน: SailueatSuite/dodge_stats.json (ให้ผมอ่าน + ค่าสคริปต์ปัจจุบัน) และ dodge_stats.txt (อ่านง่าย)
	-- แยกตาม "ลายเซ็นค่าตั้ง" (โยก/หลบ/หน่วง + ค่า) เปลี่ยนค่าแล้วไม่ปนกัน | n = กระสุนที่เล็งมาใกล้เรา, h = เลือดเราลด (โดน), หลบได้ = n − h
	local STATF, STATT = "SailueatSuite/dodge_stats.json", "SailueatSuite/dodge_stats.txt"
	local totals, lastStatSave = {}, 0
	pcall(function()
		if isfile and isfile(STATF) then
			local d = HS:JSONDecode(readfile(STATF))
			if type(d) == "table" and type(d.totals) == "table" then totals = d.totals end
		end
	end)
	local function sigNow()
		return string.format("โยก=%s/%.1f/เดิน%.1f หลบ=%s/%.1f/รัศมี%.1f หน่วง=%s/%.2f ตอนตี=%.2fวิ/%.1f แลคสไตล์=%s/%.1f",
			S.Jitter and "เปิด" or "ปิด", S.JitterAmp or 0, S.JitterWalk or 0,
			S.Dodge and "เปิด" or "ปิด", S.DodgeAmp or 0, S.DodgeRadius or 0,
			S.Lag and "เปิด" or "ปิด", S.LagTime or 0, S.AtkWin or 0, S.AtkJitter or 0,
			S.LagStyle and "เปิด" or "ปิด", S.LagStyleAmp or 0)
	end
	local function saveStats(force)
		local now = os.clock()
		if not force and now - lastStatSave < 2 then return end
		lastStatSave = now
		local cur = {}
		for _, k in ipairs({ "Jitter", "JitterAmp", "JitterWalk", "Dodge", "DodgeAmp", "DodgeRadius", "Lag", "LagTime", "AtkSuspend", "AtkWin", "AtkJitter",
			"AimOn", "FireMul", "BulletMul", "LatComp", "FovPx", "StickFovPx", "AutoRate", "FpsUnlock", "LowGfx" }) do cur[k] = S[k] end
		local L = { "อัปเดต " .. os.date("%Y-%m-%d %H:%M:%S"), "รอบนี้ aimed=" .. stat.aimed .. " (เลือดเราลดรวม " .. stat.hit .. ")", "" }
		local keys = {}
		for k in pairs(totals) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = totals[k]
			L[#L + 1] = string.format("%s\n   เล็งมา %d | โดน %d | หลบได้ %d (%.0f%%) | บินเฉลี่ย %.2f วิ", k, v.n, v.h, v.n - v.h, v.n > 0 and (v.n - v.h) / v.n * 100 or 0, v.n > 0 and (v.tt or 0) / v.n or 0)
			L[#L + 1] = string.format("   (ผ่านใกล้ตัวจริง ≤3 studs: เล็งมา %d | โดน %d)", v.n3 or 0, v.h3 or 0)
		end
		if makefolder and isfolder and not isfolder("SailueatSuite") then pcall(makefolder, "SailueatSuite") end
		pcall(writefile, STATF, HS:JSONEncode({ updated = os.date("%Y-%m-%d %H:%M:%S"), current = cur, signature = sigNow(), totals = totals }))
		pcall(writefile, STATT, table.concat(L, "\n"))
		pcall(writefile, EVF, table.concat(evLines, "\n"))
	end
	getgenv().SuiteDodgeSave = function() saveStats(true) end
	saveStats(true)   -- เขียนค่าสคริปต์ปัจจุบันทันทีตอนรัน
	-- เปิดให้สคริปต์ทดสอบภายนอก (Claude ผ่าน Potassium) ปรับค่าตั้งและอ่านสถิติสดได้ | ใช้อ่าน/ตั้งค่าเท่านั้น
	getgenv().SuiteS, getgenv().SuiteDodgeTotals = S, totals
	local hist, lagVec = {}, Vector3.zero   -- lagVec = ออฟเซ็ตหน่วงปัจจุบัน: เซิร์ฟเห็นเราที่ (ตำแหน่งจริง + lagVec) ตัวหลบกระสุนต้องคิดจากตำแหน่งนี้
	local evB = game.ReplicatedStorage:FindFirstChild("VisualizeBullet", true)
	if evB then
		getgenv().SuiteDodgeConn = evB.OnClientEvent:Connect(function(...)
			if not live() then return end   -- เก็บสถิติทุกโหมด (รวมตอนปิดหลบ ไว้เทียบ) หลบจริงเฉพาะตอน S.Dodge เปิด
			local a = { ... }
			pcall(function()
				local dir = type(a[6]) == "table" and a[6][1] or a[6]
				local mz, cfg = a[7], a[12]
				local org = typeof(mz) == "Instance" and mz:IsA("Attachment") and mz.WorldPosition or (typeof(mz) == "Vector3" and mz or nil)
				local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
				if typeof(dir) ~= "Vector3" or not org or type(cfg) ~= "table" or not hrp then return end
				if (org - workspace.CurrentCamera.CFrame.Position).Magnitude < 12 then return end   -- นัดของเราเอง/ใกล้ตัว
				local sp = tonumber(cfg[1])
				local ac = typeof(cfg[2]) == "Vector3" and cfg[2] or Vector3.zero
				if not sp or sp <= 0 then return end
				dir = dir.Unit
				local me = hrp.Position + lagVec
				local bestT, bestD, bestP
				for t = 0.02, 1.2, 0.01 do
					local p = org + dir * sp * t + ac * 0.5 * t * t
					local d = (p - me).Magnitude
					if not bestD or d < bestD then bestT, bestD, bestP = t, d, p end
				end
				-- นับเฉพาะกระสุนที่ "เล็งมาที่ตัวเราจริง" = วิถีผ่านห่าง ≤ 3 studs (กระสุนที่ยิงคนอื่นแถวนั้นไม่นับ) รวมนัดที่บินเร็วเกินจะหลบทัน
				local now0 = os.clock()
				local hum0 = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
				-- รัศมีนับ = AimedR (20) คงที่ทุกค่าตั้ง: ตอนโยก คนยิงเล็งที่ตำแหน่งที่เห็น (ห่างตัวจริงได้ถึงแรงโยก) กระสุนจึงผ่านห่างตัวจริงเกิน 3 studs แต่ถือว่าเล็งมา → รัศมี 3 ตัดนัดที่โยกสำเร็จทิ้ง ทำให้ข้อมูลเอนเอียง
				if bestD <= (S.AimedR or 20) and hum0 then
					stat.aimed += 1
					local shM = typeof(a[2]) == "Instance" and a[2]:FindFirstAncestorOfClass("Model") or nil
					outs[#outs + 1] = { tImp = now0 + bestT, t1 = now0 + bestT + 0.5, tt = bestT, sig = sigNow(), closest = bestD, dist = (org - me).Magnitude,
						shooter = shM and shM.Name or "?", dodgeOn = S.Dodge and bestT >= 0.08, jit = S.Jitter and (S.JitterAmp or 0) or 0,
						key = (S.Jitter and "J" or "-") .. (S.Dodge and "D" or "-") .. (S.Lag and "L" or "-") }
				end
				if not S.Dodge or bestD > (S.DodgeRadius or 4) or bestT < 0.08 then return end
				local perp = dir:Cross(Vector3.yAxis)
				if perp.Magnitude < 0.1 then return end
				perp = perp.Unit
				local s = (me - bestP):Dot(perp)
				s = (s == 0) and (math.random() < 0.5 and 1 or -1) or (s > 0 and 1 or -1)
				local now = os.clock()
				dodges[#dodges + 1] = { t0 = now, t1 = now + bestT + 0.25, dir = perp * s }
				if now - lastLog > 0.5 then
					lastLog = now
					log(string.format("dodge aimed d=%.1f t=%.2f | รวม aimed=%d hit=%d (ตอนหลบ %d)", bestD, bestT, stat.aimed, stat.hit, stat.hitDodging))
				end
			end)
		end)
	end
	getgenv().SuiteJitterConn = RS.Heartbeat:Connect(function()
		if not live() then
			pcall(function() getgenv().SuiteJitterConn:Disconnect() end)
			pcall(function() RS:UnbindFromRenderStep("SuiteJitterRS") end)
			return
		end
		-- ดึงออฟเซ็ตเฟรมก่อนที่ยังค้างอยู่ออกก่อน (ถ้า Heartbeat รัน 2 ครั้งระหว่างเรนเดอร์ ออฟเซ็ตแรกจะถูกเขียนทับแล้วไม่เคยถูกลบ → ตำแหน่งจริงเดินสุ่มสะสม = ยืนเฉยๆ ตัวไหลไปมา/โดนดึงกลับ)
		if applied ~= Vector3.zero then
			pcall(function() if hrpRef and hrpRef.Parent then hrpRef.CFrame = hrpRef.CFrame - applied end end)
			applied = Vector3.zero
		end
		local ch = lp.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum and hum.Health > 0 and not hum.Sit) then lastHp = nil return end
		local now = os.clock()
		for i = #dodges, 1, -1 do if now > dodges[i].t1 then table.remove(dodges, i) end end
		for i = #outs, 1, -1 do
			local o = outs[i]
			if now >= o.t1 then
				local m = byMode[o.key] or { n = 0, h = 0 }
				byMode[o.key] = m
				m.n += 1
				-- จับคู่กับเหตุการณ์เลือดลดที่ใกล้เวลากระสุนถึง (−0.2 ถึง +0.45 วิ) ใช้แล้วไม่ใช้ซ้ำ → นัดรัวไม่นับโดนซ้อน, เลือดลดจากอย่างอื่นไม่ปน
				local took, dmg = false, 0
				for _, e in ipairs(hpEvs) do
					if not e.used and e.t >= o.tImp - 0.2 and e.t <= o.tImp + 0.45 then e.used, took, dmg = true, true, e.amt break end
				end
				if took then m.h += 1 end
				evLines[#evLines + 1] = string.format("%s %s %dm ผ่านห่าง%.1f บิน%.2fs | โยก%.0f หลบ%s → %s", os.date("%H:%M:%S"), o.shooter, math.floor(o.dist), o.closest, o.tt,
					o.jit, o.dodgeOn and "ทำงาน" or (S.Dodge and "ไม่ทัน" or "ปิด"), took and ("โดน -" .. math.floor(dmg)) or "หลบได้")
				while #evLines > 400 do table.remove(evLines, 1) end
				local tv = totals[o.sig] or { n = 0, h = 0, tt = 0 }
				totals[o.sig] = tv
				tv.n += 1
				tv.tt = (tv.tt or 0) + o.tt
				if took then tv.h += 1 end
				if o.closest <= 3 then tv.n3 = (tv.n3 or 0) + 1 if took then tv.h3 = (tv.h3 or 0) + 1 end end   -- แยกนับนัดผ่านใกล้ตัวจริง ≤ 3 studs
				saveStats(false)
				table.remove(outs, i)
				resolved += 1
				if resolved % 5 == 0 then
					local L = {}
					for k, v in pairs(byMode) do L[#L + 1] = string.format("%s %d/%d (%.0f%%)", k, v.h, v.n, v.h / v.n * 100) end
					log("dodge-outcome โดน/เล็งมา ตามโหมด J=โยก D=หลบ L=หน่วง: " .. table.concat(L, " | "))
				end
			end
		end
		for i = #hpEvs, 1, -1 do if now - hpEvs[i].t > 4 then table.remove(hpEvs, i) end end
		if lastHp and hum.Health < lastHp - 1 then
			hpEvs[#hpEvs + 1] = { t = now, amt = lastHp - hum.Health }   -- เลือดเราลด = โดนยิง (เทียบกับจำนวนกระสุนที่เล็งมา)
			stat.hit += 1
			if #dodges > 0 then stat.hitDodging += 1 end
		end
		lastHp = hum.Health
		local truePos = hrp.Position
		hist[#hist + 1] = { now, truePos }
		while #hist > 2 and now - hist[1][1] > 2 do table.remove(hist, 1) end
		lagVec = Vector3.zero
		local dt = math.min(now - (lastT or now), 0.1)
		lastT = now
		-- หลังคลิก AtkWin วิ: โยกไม่ปิด แต่ลดแรงเหลือ AtkJitter studs (ยังใกล้พอให้ตีโดน) | หลบ/หน่วง (ออฟเซ็ตใหญ่) ปิดชั่วคราว
		local atk = S.AtkSuspend ~= false and now - lastClick < (S.AtkWin or 0.35)
		-- มี ProximityPrompt โผล่ (ถึงร้าน/จุดซื้อ/เก็บของแล้ว) → เซิร์ฟเช็กระยะจากตำแหน่งที่รับ ซึ่งถูกโยก/หน่วงอยู่ จึงต้องรอ | ปิดออฟเซ็ตค่อย ๆ (0.25 วิ กันความเร็วย้ายตำแหน่งพุ่ง)
		local prm = S.PromptSuspend ~= false and next(shownPrompts) ~= nil
		local want = (atk or prm) and 0 or 1
		if want < act then act = math.max(want, act - dt / (prm and 0.25 or 0.1)) else act = math.min(want, act + dt / 0.3) end
		-- ช่วงโหลดสคริปต์ใหม่/เข้าแมพ (8 วิแรก) หรือเฟรมสะดุด (>45ms: โหลดหนัก LowGfx/getgc) ไม่บวกออฟเซ็ต: Heartbeat รัวซ้อนระหว่างเรนเดอร์ทำให้ตัวไหล/วาร์ป
		if now - JIT_T0 < 8 or dt > 0.045 then return end
		if getgenv().SuiteFree or not (S.Jitter or S.Dodge or S.Lag or S.LagStyle or S.DownedDodge ~= false) then return end
		local lagOff = Vector3.zero
		if S.Lag then
			local want = now - math.clamp(S.LagTime or 0.15, 0, 1.2)
			local pick
			for i = #hist, 1, -1 do if hist[i][1] <= want then pick = hist[i] break end end
			if pick then
				lagOff = pick[2] - truePos
				if lagOff.Magnitude > 30 then lagOff = lagOff.Unit * 30 end
			end
		end
		local phase = now % (JIT_ON + JIT_OFF)
		local jOn = S.Jitter and phase < JIT_ON
		local dodgeOff = Vector3.zero
		if S.Dodge and #dodges > 0 then
			local d = dodges[#dodges]   -- ใช้กระสุนล่าสุดนัดเดียว ไม่บวกซ้อนกันจนไกลเกิน
			local k = math.min((now - d.t0) / 0.03, (d.t1 - now) / 0.1, 1)   -- ค่อย ๆ เข้า 0.05 วิ ค่อย ๆ ออก 0.1 วิ
			-- ตอนเดิน (แนวราบ > 3) จำกัดระยะหลบที่ DodgeWalk กันตำแหน่งที่ส่งกระโดดเกินความเร็วเดิน แล้วเซิร์ฟดึงกลับ (rubberband)
			local da = math.clamp(S.DodgeAmp or 8, 0, 20)
			local vv = hrp.AssemblyLinearVelocity
			if Vector3.new(vv.X, 0, vv.Z).Magnitude > 3 then da = math.min(da, S.DodgeWalk or 4) end
			if k > 0 then dodgeOff = d.dir * (da * k) end
		end
		-- เดินอยู่ (ความเร็วแนวราบ > 3): ลดแรงโยกเหลือ JitterWalk กันเซิร์ฟดึงกลับ (rubberband) | ค่อย ๆ เพิ่ม/ลดที่ต้นท้ายช่วง 0.4 วิ ไม่กระชาก
		local v = hrp.AssemblyLinearVelocity
		local amp = math.clamp(S.JitterAmp or 2, 0, 15)
		if Vector3.new(v.X, 0, v.Z).Magnitude > 3 then amp = math.min(amp, S.JitterWalk or 0.7) end
		if atk or prm then amp = math.min(amp, prm and 0.3 or (S.AtkJitter or 1.2)) end
		amp = jOn and amp * (JIT_OFF > 0 and math.min(phase, JIT_ON - phase, 0.4) / 0.4 or 1) or 0
		-- สุ่มความแรง + มีแกนหน้า-หลังครึ่งหนึ่ง: ทิศไม่สม่ำเสมอ ทำนายยากกว่าซ้าย-ขวาตรง ๆ
		sign = -sign
		applied = hrp.CFrame.RightVector * (amp * sign * (0.6 + 0.4 * math.random())) + hrp.CFrame.LookVector * (amp * 0.5 * (math.random() * 2 - 1))
			+ Vector3.yAxis * (amp * 0.25 * math.random())   -- แกนตั้งขึ้นอย่างเดียว (0..amp*0.25) ไม่ลงต่ำกว่าพื้น กันตำแหน่งที่ส่งจมพื้นแล้วโดนดึงกลับ
		-- ล้มลงรอตาย (วัดจริง: ตอนล้ม WalkSpeed = 3, เลือด < 20 ฟื้นทีละ 1, DownedEvent "PlayDownedAnim") → ตำแหน่งที่ส่งกระโดดสุ่มทุกเฟรมแรง ๆ
		-- คนที่เข้ามากด F จบ/E ชุบ ต้องอยู่ใกล้ตัวเรา ตำแหน่งที่เซิร์ฟเห็นกระโดดไปมา ระยะไม่ตรง (ยังไม่ยืนยันว่าเซิร์ฟเช็กระยะจากตำแหน่งนี้) | ไม่สนใจโยกปกติ/หลบ/หน่วง
		-- ปรับตามสั่ง: ไม่โยกแรงแล้ว → ขยับตัวจริง (เทเลพอร์ตสั้น ๆ) DownedAmp studs (ค่าเริ่ม 2) ทุก 0.3 วิ ทิศสุ่ม ตัวละครยังคลานตามที่ผู้เล่นกดตามปกติ
		-- สไตล์ "คนแลคโทรศัพท์กาก": นิ่งค้างสักพัก (0.3–1.2 วิ ไม่สม่ำเสมอ) แล้ววาร์ปกระตุกไปที่ใหม่ + บางครั้ง (25%) ดีดกลับที่เดิมเหมือนโดนดึงกลับ
		-- ใช้ตอนล้ม (DownedAmp) และตอนปกติด้วยถ้าเปิด LagStyle (LagStyleAmp) | ตอนปกติปิดชั่วคราวระหว่างต่อย/ยิง/มีปุ่มซื้อ (act ต่ำ) กันตีพลาด/ซื้อช้า
		local downed = S.DownedDodge ~= false and hum.WalkSpeed <= 6 and hum.Health < 40
		local hopAmp = nil
		if downed then hopAmp = S.DownedAmp or 1.2
		elseif S.LagStyle and act > 0.5 and not prm then hopAmp = S.LagStyleAmp or 1.5 end
		if hopAmp then
			if now >= lastHop then
				lastHop = now + 0.3 + math.random() * 0.9
				if lastStep ~= Vector3.zero and math.random() < 0.25 then
					hopPend -= lastStep
					lastStep = Vector3.zero
				else
					local ang = math.random() * math.pi * 2
					lastStep = Vector3.new(math.cos(ang), 0, math.sin(ang)) * hopAmp * (0.6 + math.random() * 0.9)
					hopPend += lastStep
				end
			end
		end
		-- เลื่อนเป็นช่วง ~0.12 วิ (เนียน ไม่วาร์ปทันที) ไม่ใช่กระโดดทีเดียว
		if hopPend.Magnitude > 0.02 then
			local mv = hopPend * math.min(1, dt / 0.12)
			hrp.CFrame = hrp.CFrame + mv
			hopPend -= mv
		end
		if downed then applied, dodgeOff, lagOff = Vector3.zero, Vector3.zero, Vector3.zero end
		lagOff = lagOff * act
		lagVec = lagOff
		applied = applied + dodgeOff * act + lagOff
		if applied == Vector3.zero then return end
		hrpRef = hrp
		hrp.CFrame = hrp.CFrame + applied
	end)
end

local fov = Drawing.new("Circle")
fov.Thickness, fov.Filled, fov.Color, fov.Transparency = 1, false, Color3.fromRGB(0,255,140), 0.5
getgenv().SuiteFov = fov
-- จุดแดง = ที่กระสุนจะไปจริง (silent aim ย้าย Crosshair ที่ซ่อนอยู่ตอนเล็งคลิกขวา ผู้เล่นเลยไม่เห็นว่าล็อกอยู่)
do
	local m = Drawing.new("Circle")
	m.Thickness, m.Filled, m.Color, m.Radius, m.NumSides, m.Transparency = 2, false, Color3.fromRGB(255,60,60), 5, 24, 1
	m.Visible = false
	getgenv().SuiteMarker = m
end

--========================= ปืน =========================
local orig = setmetatable({}, { __mode = "k" })
local ball = { speed = math.huge, accel = Vector3.zero }
local timeKeys = { "ReloadTime", "TacticalReloadTime", "PreShotgunReloadSpeed" }
local animKeys = { "ReloadAnimationSpeed", "VMReloadAnimationSpeed",
	"TacticalReloadAnimationSpeed", "VMTacticalReloadAnimationSpeed",
	"PreShotgunReloadAnimationSpeed", "VMPreShotgunReloadAnimationSpeed" }

-- เกมอัปเดตให้ Setting ของปืนเป็นตาราง frozen (อ่านอย่างเดียว) → ต้องปลดทั้งตารางหลักและตารางซ้อนก่อนแก้
local function unfreeze(t, d)
	if type(t) ~= "table" or d > 3 then return end
	if table.isfrozen(t) then setreadonly(t, false) end
	for _, v in pairs(t) do if type(v) == "table" then unfreeze(v, d + 1) end end
end
local function tweakGun(cfg, name)
	if type(cfg) ~= "table" then return end
	unfreeze(cfg, 0)
	local o = orig[cfg]
	if not o then
		o = { FireRate = cfg.FireRate, BurstRate = cfg.BurstRate,
			FireRates = type(cfg.FireRates) == "table" and table.clone(cfg.FireRates) or nil,
			BurstRates = type(cfg.BurstRates) == "table" and table.clone(cfg.BurstRates) or nil,
			HeatMin = cfg.HeatPerFireMin, HeatMax = cfg.HeatPerFireMax,
			Recoil = cfg.Recoil, CamRecoil = cfg.CameraRecoilingEnabled,
			EquipTime = cfg.EquipTime, EquipAnim = cfg.EquippedAnimationSpeed,
			VMEquipAnim = cfg.VMEquippedAnimationSpeed,
			Spread = cfg.Spread, Bloom = cfg.BulletBloom, Auto = cfg.Auto,
			BSpeed = cfg.BulletSpeed, BAccel = cfg.BulletAcceleration }
		for _, k in ipairs(timeKeys) do o[k] = cfg[k] end
		for _, k in ipairs(animKeys) do o[k] = cfg[k] end
		orig[cfg] = o
	end

	if S.NoSpread then
		cfg.Spread, cfg.SpreadRedutionS, cfg.SpreadRedutionIS, cfg.BulletBloom = 0, 0, 0, 0
		if not cfg.__sk then
			for _, k in ipairs({ "SpreadPattern", "ShotgunPattern" }) do
				if type(cfg[k]) == "table" then
					for i, e in ipairs(cfg[k]) do if type(e) == "table" then cfg[k][i] = { 0, 0 } end end
				end
			end
			if type(cfg.ChargeAlterTable) == "table" and cfg.ChargeAlterTable.Spread ~= nil then
				cfg.ChargeAlterTable.Spread = { Level1 = 0, Level2 = 0, Level3 = 0 }
			end
			cfg.__sk = true
		end
	else
		cfg.Spread, cfg.BulletBloom = o.Spread, o.Bloom
	end
	-- ความเร็วกระสุน ×BulletMul (ลดเวลาบิน = ลดความคลาดเป้าวิ่ง) + ปิดแรงตกเมื่อ >1 | ยังไม่ยืนยันว่าเซิร์ฟนับโดนตามความเร็วนี้ → ทดสอบกับเป้านิ่งก่อน
	if type(o.BSpeed) == "number" then
		local k = math.clamp(S.BulletMul or 1, 1, 10)
		cfg.BulletSpeed = o.BSpeed * k
		if k > 1 and typeof(o.BAccel) == "Vector3" then cfg.BulletAcceleration = Vector3.zero
		elseif o.BAccel ~= nil then cfg.BulletAcceleration = o.BAccel end
	end

	-- คูณแล้วไม่ต่ำกว่า FireFloor: ปืนที่เดิมรัวอยู่แล้ว (FireRate เล็ก) คูณ 0.45 ซ้ำจะเร็วเกินที่เซิร์ฟรับ → โดนเตะ
	local function rate(v)
		local r = math.max(v * (getgenv().SuiteMulNow or S.FireMul), math.min(v, S.FireFloor))
		if getgenv().SuiteCd then r = math.max(r, v, 1.0) end   -- ติดคูลดาวน์: ห่างอย่างน้อย 1 วิ ต่อนัด (ช่วงคูลดาวน์รวม CD_TIME)
		return r
	end
	if o.FireRate then cfg.FireRate = rate(o.FireRate) end
	if o.BurstRate then cfg.BurstRate = rate(o.BurstRate) end
	for _, k in ipairs({ "FireRates", "BurstRates" }) do
		if o[k] then for i, v in pairs(o[k]) do
			if type(v) == "number" then cfg[k][i] = rate(v) end
		end end
	end

	for _, k in ipairs(timeKeys) do
		if type(o[k]) == "number" then cfg[k] = o[k] * S.ReloadMul end
	end
	local inv = S.ReloadMul > 0 and 1 / S.ReloadMul or 1
	for _, k in ipairs(animKeys) do
		if type(o[k]) == "number" then cfg[k] = o[k] * inv end
	end
	if type(o.EquipTime) == "number" then cfg.EquipTime = o.EquipTime * S.EquipMul end
	local einv = S.EquipMul > 0 and 1 / S.EquipMul or 1
	if type(o.EquipAnim) == "number" then cfg.EquippedAnimationSpeed = o.EquipAnim * einv end
	if type(o.VMEquipAnim) == "number" then cfg.VMEquippedAnimationSpeed = o.VMEquipAnim * einv end

	cfg.HeatPerFireMin = S.NoHeat and 0 or o.HeatMin
	cfg.HeatPerFireMax = S.NoHeat and 0 or o.HeatMax
	cfg.Recoil = S.NoRecoil and 0 or o.Recoil
	cfg.CameraRecoilingEnabled = S.NoRecoil and false or o.CamRecoil
	-- กดเมาส์ค้างยิงรัว: ใช้โหมดออโต้ของตัวปืนเอง (Auto) ไม่ต้องสั่งคลิกเอง เกมจับการกด/ปล่อยจริงเอง ไม่มีทางค้าง
	if o.Auto ~= nil then cfg.Auto = (S.HoldSpray and not getgenv().SuiteAutoOff) or o.Auto end   -- SuiteAutoOff = กดค้างเกิน HoldMax วิ ตัดกลับเป็นกึ่งอัตโนมัติจนกว่าจะปล่อย/กดใหม่

end

-- ตัดเสียงรีโหลด/ใส่แม็ก/โยกลูกซอง: ปิดแค่ Volume ฝั่งเครื่องเรา เซิร์ฟเวอร์ไม่รู้ (จำค่าเดิมไว้คืนตอนปิดสวิตช์)
local reloadSnd = { ReloadSound = true, TacticalReloadSound = true, PreReloadSound = true, ShotgunClipin = true, PumpSound = true }
local snd0 = setmetatable({}, { __mode = "k" })
local function muteReload(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") and reloadSnd[d.Name] then
			if snd0[d] == nil then snd0[d] = d.Volume end
			d.Volume = S.MuteReload and 0 or snd0[d]
		end
	end
end
-- มีด (FE Melee Kit): ดีเลย์ระหว่างฟันอยู่ในโมดูลย่อย 1,2,3.. ของ MainModule (AttackDelay) ลดแล้วฟันต่อเร็วขึ้น
-- ทดสอบจริง 31/10 (ง้าว 0.95): ดีเลย์ 70%/59%/50% ของเดิม โดนเท่ากันหมด (5/10) | 35% ตก (1/4) → เพดาน MeleePct = 50 (ไม่ต่ำกว่า 50% ของดีเลย์เดิม) ใช้สัดส่วนกับอาวุธทุกอัน
-- เกมรีเซ็ตดีเลย์กลับเองภายใน ~1.5 วิ → ต้องเขียนซ้ำ (sweep ทำอยู่แล้ว)
local meleeOrig = setmetatable({}, { __mode = "k" })
local gunLogged = {}
local function tweakMelee(tool)
	local mm = tool:FindFirstChild("MainModule")
	if not mm then return end
	for _, m in ipairs(mm:GetChildren()) do
		if m:IsA("ModuleScript") and tonumber(m.Name) then
			local ok, cfg = pcall(require, m)
			if ok and type(cfg) == "table" and type(cfg.AttackDelay) == "number" then
				unfreeze(cfg, 0)
				meleeOrig[cfg] = meleeOrig[cfg] or cfg.AttackDelay
				local o = meleeOrig[cfg]
				cfg.AttackDelay = S.MeleeFast and o * (1 - math.clamp(S.MeleePct or 0, 0, 50) / 100) or o
			end
		end
	end
end
local function sweep()
	for _, root in ipairs({ lp.Character, lp.Backpack }) do
		if root then for _, d in ipairs(root:GetChildren()) do
			if d:IsA("Tool") and d:FindFirstChild("MainModule") then pcall(tweakMelee, d) end
		end end
	end
	muteReload(cam)   -- viewmodel ที่เกมสร้างใต้กล้องตอนถือปืน
	for _, root in ipairs({ lp.Character, lp.Backpack }) do
		if root then for _, d in ipairs(root:GetChildren()) do
			if d:IsA("Tool") and d:FindFirstChild("Setting") then
				muteReload(d)
				local ok, cfg = pcall(require, d.Setting)
				if ok then
					local okT, errT = pcall(tweakGun, cfg, d.Name)
					if not okT and getgenv().SuiteTweakErr ~= errT then
						getgenv().SuiteTweakErr = errT
						print("[GUN] ปรับปืน " .. d.Name .. " พลาด:", errT)
					end
				end
			end
		end end
	end
	local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
	local st = tool and tool:FindFirstChild("Setting")
	ball.speed, ball.accel, ball.range, ball.name = math.huge, Vector3.zero, nil, tool and tool.Name
	if st then
		local ok, cfg = pcall(require, st)
		if ok and type(cfg) == "table" then
			local sp = tonumber(cfg.BulletSpeed)
			ball.speed = (sp and sp > 0) and sp or math.huge
			ball.accel = typeof(cfg.BulletAcceleration) == "Vector3" and cfg.BulletAcceleration or Vector3.zero
			-- โปรไฟล์ปืนที่ถืออยู่: ระยะที่เชื่อถือได้ = ค่าที่ผู้ใช้ตั้งไว้ของปืนนี้ ไม่งั้นอ่านจาก Setting (ชื่อ field ต่างกันตามปืน)
			local ov = S.GunRange and S.GunRange[tool.Name]
			local rng = tonumber(cfg.Range) or tonumber(cfg.MaxRange) or tonumber(cfg.MaxDistance) or tonumber(cfg.ZeroDamageDistance)
			ball.range = (ov and ov > 0) and ov or rng
			-- บันทึกโปรไฟล์ปืนครั้งเดียวต่อกระบอก (ไว้ดูว่า field ไหนมีจริง จะได้ปรับสูตรต่อ)
			if not gunLogged[tool.Name] then
				gunLogged[tool.Name] = true
				local o = orig[cfg]
				local f = {}
				for k, v in pairs(cfg) do
					local s = tostring(k):lower()
					if type(v) == "number" and (s:find("range") or s:find("dist") or s:find("damage") or s:find("fall") or s:find("drop") or s:find("speed")) and #f < 14 then
						f[#f + 1] = k .. "=" .. tostring(v):sub(1, 8)
					end
				end
				log(string.format("GUNPROFILE %s rate0=%s speed=%s range=%s | %s", tool.Name, tostring(o and o.FireRate), tostring(sp), tostring(ball.range), table.concat(f, " ")))
			end
		end
	end
end

--========================= AIM =========================
-- probe ไล่จากใต้หัวขึ้นบน: ผม/หมวกอยู่ด้านบนเสมอ
-- กลางหัวก่อน (log เดิมเล็งต่ำกว่ากลางหัว ~0.5 stud เพราะลองจากใต้หัวก่อน) | hitsHead รับ part ไหนของเป้าก็ได้แล้ว หมวก/ผมไม่บังจนต้องเริ่มจากล่าง
local probes = { Vector2.new(0,0), Vector2.new(0,-0.15), Vector2.new(0,-0.3),
	Vector2.new(-0.25,-0.3), Vector2.new(0.25,-0.3), Vector2.new(-0.3,-0.1),
	Vector2.new(0.3,-0.1), Vector2.new(-0.3,0.1), Vector2.new(0.3,0.1), Vector2.new(0,0.2) }
local lockChar, writing, cal = nil, false, nil
-- ความเร็ว/ความเร่งของเป้าที่ "วัดเอง" จากตำแหน่งจริงต่อเฟรม (กรองด้วย lerp) แม่นกว่า AssemblyLinearVelocity ที่ค้าง/สะดุดกับคนที่เดินวิ่งเลี้ยว
-- ความเร่งจำกัด 35 studs/s² กันค่าสั่น | เป้าวาร์ปไกลผิดปกติ รีเซ็ต
local trk = setmetatable({}, { __mode = "k" })
local function trackMotion(ch, root)
	local now, p = os.clock(), root.Position
	local t = trk[ch]
	if not t then
		t = { p = p, ts = now, v = root.AssemblyLinearVelocity, a = Vector3.zero, c = p, cv = Vector3.zero, rev = {}, h = {} }
		trk[ch] = t
		return t.v, t.a, t
	end
	local dt = now - t.ts
	if dt < 0.016 then return t.v, t.a, t end   -- คำนวณครั้งเดียวต่อเฟรม
	local vm = (p - t.p) / dt
	if vm.Magnitude > 70 then t.p, t.ts, t.v, t.a, t.c, t.cv, t.rev = p, now, Vector3.zero, Vector3.zero, p, Vector3.zero, {} t.h = {} return t.v, t.a, t end
	local nv = t.v:Lerp(vm, 0.4)
	-- ตำแหน่งผู้เล่นอื่นอัปเดตเป็นก้าว ๆ (~20Hz) ความเร็วต่อเฟรมเลยสั่น: คนเดินคงที่ ~16 ได้ค่า 7.8–16.4 (log รอบ 00:24) → ใช้ความเร็วเฉลี่ยในหน้าต่าง 0.12–0.3 วิ แทน
	local hb = t.h
	hb[#hb + 1] = { now, p }
	while #hb > 2 and now - hb[1][1] > 0.3 do table.remove(hb, 1) end
	-- ปิดไว้: ทดสอบ 00:30 ได้ 19% (63 นัด) แย่กว่ารอบ lerp เดิม 27% และ |err side| เฉลี่ยสูงขึ้น (หน้าต่างหน่วงเกินกับเป้าที่กลับทิศถี่)
	-- if #hb >= 3 and now - hb[1][1] >= 0.12 then nv = (p - hb[1][2]) / (now - hb[1][1]) end
	local na = t.a:Lerp((nv - t.v) / dt, 0.15)
	if na.Magnitude > 35 then na = na.Unit * 35 end
	-- โยกซ้ายขวา: นับครั้งที่ความเร็วแนวราบกลับทิศ (ภายใน 0.9 วิ) | c = ศูนย์กลางการโยก (ตำแหน่งกรองช้า ~0.4 วิ) cv = ความเร็วเลื่อนของศูนย์กลาง
	local hv, hp = Vector3.new(nv.X, 0, nv.Z), Vector3.new(t.v.X, 0, t.v.Z)
	if hv.Magnitude > 4 and hp.Magnitude > 4 and hv:Dot(hp) < 0 then t.rev[#t.rev+1] = now end
	while t.rev[1] and now - t.rev[1] > 0.9 do table.remove(t.rev, 1) end
	local nc = t.c:Lerp(p, 1 - math.exp(-dt / 0.4))
	t.cv = t.cv:Lerp((nc - t.c) / dt, 0.2)
	t.c = nc
	t.p, t.ts, t.v, t.a = p, now, nv, na
	return nv, na, t
end

local function aliveC(c)
	if not c or not c.Parent then return false end
	local h = c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function foe(pl)
	if not S.TeamCheck then return true end
	return not (pl.Team and lp.Team and pl.Team == lp.Team)
end
-- มองเห็นเป้ามั้ย: ray จากกล้องถึงจุดเล็ง ต้องไปถึง "ตัวเป้า" (part ไหนก็ได้ของมัน เช่น หมวก/ผม/ตัว)
-- ไม่ใช่ต้องโดน part ชื่อ Head เป๊ะ (NPC/ผู้เล่นใส่หมวก ray โดนหมวกก่อน = เดิมเด้งทิ้งทั้งที่ยิงโดน)
local function hitsHead(head, pos)
	local ch = head.Parent
	local o = cam.CFrame.Position
	local hit = workspace:FindPartOnRayWithIgnoreList(
		Ray.new(o, (pos - o).Unit * S.MaxDist), { cam, lp.Character })
	return hit ~= nil and ch ~= nil and hit:IsDescendantOf(ch)
end
-- กระสุนจริงของเกม (FE Gun Kit): ทิศ = จาก GunFirePoint → จุดแรกที่เรย์กล้องผ่าน crosshair ชน (CastRay 5000)
-- ไม่ใช่เรย์กล้องตรง ๆ จึงต้องคำนวณจากปากกระบอก และเลือกจุดบนจอที่ทำให้ทิศนั้นตรงกับที่ชดเชยตก/นำเป้าไว้
local function firePoint()
	local a
	if (cam.Focus.Position - cam.CFrame.Position).Magnitude <= 1 then a = cam:FindFirstChild("GunFirePoint", true) end
	if not a then
		local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
		a = tool and tool:FindFirstChild("GunFirePoint", true)
	end
	return a and a.WorldPosition
end
local function fixScreen(P)
	local F = firePoint()
	if not F or (P - F).Magnitude < 1 then return nil end
	local C = cam.CFrame.Position
	local d = (P - F).Unit
	local k0 = (P - F).Magnitude
	local ign = { cam, lp.Character }
	local best, bestErr
	for _, m in ipairs({ 1, 1.2, 1.5, 2, 3, 5, 8, 15, 30 }) do
		local X = F + d * (k0 * m)
		local dir = (X - C).Unit
		local part, hp = workspace:FindPartOnRayWithIgnoreList(Ray.new(C, dir * 5000), ign)
		local H = part and hp or (C + dir * 5000)
		local err = (H - F).Unit:Dot(d)   -- 1 = ทิศกระสุนตรงเป๊ะ
		if not bestErr or err > bestErr then
			local sp, vis = cam:WorldToScreenPoint(X)
			if vis then best, bestErr = sp, err end
		end
	end
	return best
end
local function aimAt(ch)
	local head = ch:FindFirstChild("Head")
	if not head then return nil end
	local o = cam.CFrame.Position
	local fp = firePoint() or o   -- เวลาบิน/แรงตกนับจากปากกระบอก ไม่ใช่กล้อง
	local right, up = cam.CFrame.RightVector, cam.CFrame.UpVector
	local r = math.max(head.Size.X, head.Size.Y)
	local root = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
	local vel, acc, tk = Vector3.zero, Vector3.zero, nil
	if root then vel, acc, tk = trackMotion(ch, root) end
	local strafe = tk ~= nil and #tk.rev >= 2   -- โยกซ้ายขวาไว ๆ (กลับทิศ ≥2 ครั้งใน 0.9 วิ)
	for _, p in ipairs(probes) do
		local raw = head.Position + right * (p.X * r) + up * (p.Y * r)
		if hitsHead(head, raw) then
			-- LatComp: ชดเชยดีเลย์ตำแหน่งผู้เล่นอื่นที่เห็น (ping + การหน่วงแสดงผล) นำเพิ่มตามความเร็ว × LatComp วิ | 0 = ปิด (ยังไม่ยืนยันค่าที่เหมาะ)
			raw = raw + vel * (S.LatComp or 0)
			if ball.speed == math.huge then return raw end        -- หิตสแกน ไม่ต้องนำ
			-- นำเป้า + ชดเชยกระสุนตก (accel) เต็ม ๆ วนหาเวลาเดินทางถึงจุดที่นำไว้ให้ลู่เข้า
			-- สำคัญ: ห้ามเช็ก hitsHead ซ้ำกับจุดที่ชดเชยแล้ว เพราะจุดนั้นเล็งเหนือ/นำหน้าหัว = หลุดหัวเสมอ
			if strafe then
				-- นำด้วยความเร็วตอนเป้ากำลังกลับทิศ = พุ่งไปผิดข้างทุกครั้ง → เล็งที่ "ศูนย์กลางการโยก" + เลื่อนตามการลอยของศูนย์กลาง + ชดเชยตก
				local off = tk.c - root.Position
				if off.Magnitude > 6 then off = off.Unit * 6 end
				local base = raw + off
				local ts = (base - fp).Magnitude / ball.speed
				for _ = 1, 3 do
					ts = (base + tk.cv * ts - ball.accel * 0.5 * ts * ts - fp).Magnitude / ball.speed
				end
				return base + tk.cv * ts - ball.accel * 0.5 * ts * ts
			end
			local t = (raw - fp).Magnitude / ball.speed
			if t <= 0 and vel.Magnitude < 0.5 then return raw end
			for _ = 1, 3 do
				local aim = raw + vel * t + (acc - ball.accel) * 0.5 * t * t
				t = (aim - fp).Magnitude / ball.speed
			end
			return raw + vel * t + (acc - ball.accel) * 0.5 * t * t
		end
	end
end
local function scrPos(pos)
	local sp, vis = cam:WorldToScreenPoint(pos)
	if not vis then return nil end
	-- จุดศูนย์กลางวง FOV: ตามเมาส์ (S.FovFollow) หรือกลางจอ | GetMouseLocation เป็นพิกัด viewport ต้องลบ GuiInset ให้เข้ากับ WorldToScreenPoint
	local c = S.FovFollow and (UIS:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()) or cam.ViewportSize * 0.5
	return (Vector2.new(sp.X, sp.Y) - Vector2.new(c.X, c.Y)).Magnitude, sp
end

-- ตอนเล็ง (คลิกขวา) เกมซูม FOV 70→50 เป้าอยู่ห่างกลางจอเป็นพิกเซลมากขึ้น ~1.5 เท่า วง FOV แบบพิกเซลเลยแคบลงเอง
-- ตัวคูณนี้ทำให้วง/ระยะล็อกเป็น "มุมเดิม" ไม่ว่าจะซูมหรือไม่ (อิง 70° = ค่าตอนไม่เล็ง)
local function fovK() return math.tan(math.rad(35)) / math.tan(math.rad(cam.FieldOfView / 2)) end

-- แคช NPC (เป้าส่วนใหญ่ในเกมเป็น NPC ไม่ใช่ผู้เล่น) รีเฟรชทุก 1 วิ — ponytail: O(n) ที่ 1Hz พอ
local npcs = {}
local function isPlayerChar(m) return Players:GetPlayerFromCharacter(m) ~= nil end
local function refreshNPC()
	table.clear(npcs)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Humanoid") and d.Health > 0 then
			local m = d.Parent
			if m and m ~= lp.Character and m:FindFirstChild("Head") and not isPlayerChar(m) then
				npcs[#npcs+1] = m
			end
		end
	end
end
task.spawn(function() while live() do if S.AimNPC then refreshNPC() else table.clear(npcs) end task.wait(1) end end)

local cand = {}
-- มุมที่กระสุนจะ "หักเลี้ยว" จากทิศที่เมาส์/กล้องชี้จริง (องศา) | จำกัดไว้ที่ S.AimAngle (ค่าเริ่มต้น 4°) ให้ดูเป็นความคลาดของมือคน
-- ที่ผ่านมาโดนเตะตอนยิงด้วยล็อก (silent aim) หลายรอบ แต่ยิงเปล่าๆ รัวผ่านเกือบหมด → น่าจะมีตัวตรวจ "กระสุนไม่ตรงทิศที่มองอยู่"
local function aimAng(p)
	local d = p - cam.CFrame.Position
	local look = cam.CFrame.LookVector
	if S.FovFollow then local m = UIS:GetMouseLocation() look = cam:ViewportPointToRay(m.X, m.Y).Direction end
	return math.deg(math.acos(math.clamp(look:Dot(d.Unit), -1, 1)))
end
-- ไม่แว็บไปมา: (1) เป้าที่ล็อกอยู่หายชั่วขณะ (ติดของบัง/นอกวง) ยังถือช่องล็อกไว้ LOCK_GRACE วิ ไม่สลับไปคนอื่นทันที
-- (2) เสียเป้าจริงแล้วพัก LOCK_HOLD วิก่อนหาคนใหม่ (3) เป้าใหม่ต้องเห็นหัวต่อเนื่อง VIS_NEED วิก่อนล็อก (กรองคนที่โผล่แวบเดียว)
local LOCK_GRACE, LOCK_HOLD, VIS_NEED = 0.35, 0.5, 0.2
local lostAt, holdUntil, visSince = nil, 0, setmetatable({}, { __mode = "k" })
local function target()
	local o = cam.CFrame.Position
	local now = os.clock()
	local MD = math.min(S.MaxDist, ball.range or math.huge)   -- ระยะล็อก = ไม่เกินระยะที่เชื่อถือได้ของปืนที่ถืออยู่
	if lockChar and aliveC(lockChar) then
		local pos = aimAt(lockChar)
		if pos then
			local d, sp = scrPos(pos)
			if d and d <= S.StickFovPx * fovK() and (pos - o).Magnitude <= MD and aimAng(pos) <= S.AimAngle * 1.6 then lostAt = nil return lockChar, sp, pos end
		end
		lostAt = lostAt or now
		if now - lostAt <= LOCK_GRACE then return nil end   -- ถือช่องไว้ ไม่ยิง ไม่สลับ
		lockChar, lostAt, holdUntil = nil, nil, now + LOCK_HOLD
	elseif lockChar then
		lockChar, lostAt = nil, nil   -- ตายแล้ว ไปคนต่อไปได้เลย
	end
	if now < holdUntil then return nil end
	table.clear(cand)
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		if pl ~= lp and aliveC(ch) and foe(pl) then
			local head = ch:FindFirstChild("Head")
			if head then
				local dist = (head.Position - o).Magnitude
				if dist <= MD then
					local scr = scrPos(head.Position)
					if scr and scr <= S.FovPx * fovK() and aimAng(head.Position) <= S.AimAngle then cand[#cand+1] = { ch, dist, scr } end
				end
			end
		end
	end
	if S.AimNPC then
		for _, ch in ipairs(npcs) do
			if aliveC(ch) then
				local head = ch:FindFirstChild("Head")
				if head then
					local dist = (head.Position - o).Magnitude
					if dist <= MD then
						local scr = scrPos(head.Position)
						if scr and scr <= S.FovPx * fovK() and aimAng(head.Position) <= S.AimAngle then cand[#cand+1] = { ch, dist, scr } end
					end
				end
			end
		end
	end
	-- เลือกเป้าที่มีโอกาสโดนสูงสุด (คะแนนต่ำ = ดี):
	--   ระยะเลื่อนด้านข้างที่ต้องนำ (ความเร็วขวางแนวเล็ง x เวลากระสุนบิน) เป็นตัวหลัก เป้าวิ่งตัดหน้าไกล ๆ พลาดบ่อยสุด
	--   + ระยะ + ห่างกลางจอ (ตัดสินตอนคะแนนเสมอ)
	local function score(c)
		local ch = c[1]
		local root = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
		local d = (ch.Head.Position - o).Unit
		local vel = root and root.AssemblyLinearVelocity or Vector3.zero
		local lat = (vel - d * vel:Dot(d)).Magnitude
		local t = ball.speed == math.huge and 0 or c[2] / ball.speed
		return lat * t + c[2] * 0.002 + c[3] * 0.01
	end
	for _, c in ipairs(cand) do c.s = score(c) end
	table.sort(cand, function(a, b) return a.s < b.s end)
	for _, c in ipairs(cand) do
		local pos = aimAt(c[1])
		if pos then
			visSince[c[1]] = visSince[c[1]] or now
			local _, sp = scrPos(pos)
			if sp and now - visSince[c[1]] >= VIS_NEED then lockChar = c[1] return c[1], sp, pos end
		else
			visSince[c[1]] = nil
		end
	end
	lockChar = nil
end

-- ปืนยิง raycast จาก GunGUI.Crosshair.AbsolutePosition -> ตรึง crosshair = silent aim
local function pin(ch)
	if not S.AimOn or writing then return end
	ch = ch or (function()
		local g = lp.PlayerGui:FindFirstChild("GunGUI")
		return g and g:FindFirstChild("Crosshair") or nil
	end)()
	if not ch then getgenv().SuiteLock = nil getgenv().SuiteLockChar = nil return end
	local pos, ap = ch.Position, ch.AbsolutePosition
	cal = Vector2.new(pos.X.Offset + pos.X.Scale * cam.ViewportSize.X,
		pos.Y.Offset + pos.Y.Scale * cam.ViewportSize.Y) - ap
	local tc, sp, wp = target()
	if not tc then getgenv().SuiteLock = nil getgenv().SuiteLockChar = nil return end
	local fx = wp and fixScreen(wp)
	if fx then sp = fx end
	writing = true
	ch.Position = UDim2.fromOffset(sp.X + cal.X, sp.Y + cal.Y)
	writing = false
	getgenv().SuiteLock = tc.Name
	getgenv().SuiteLockChar = tc
	getgenv().SuiteLockPos = wp
end
local function hookGui(g)
	if not g or g.Name ~= "GunGUI" then return end
	local ch = g:WaitForChild("Crosshair", 5)
	if not ch then return end
	cal = nil
	if getgenv().SuiteProp then pcall(function() getgenv().SuiteProp:Disconnect() end) end
	getgenv().SuiteProp = ch:GetPropertyChangedSignal("Position"):Connect(function()
		if live() then pin(ch) end
	end)
end
hookGui(lp.PlayerGui:FindFirstChild("GunGUI"))
getgenv().SuiteGuiAdd = lp.PlayerGui.ChildAdded:Connect(hookGui)

--========================= ESP ผู้เล่น =========================
local store = getgenv().SuiteEsp
-- สีระดับหมายจับ 1-3 ตรงกับ PoliceConfig.WANTED_COLORS ของเกม
local WANTED_COL = { Color3.new(1, 0.784, 0.235), Color3.new(1, 0.51, 0.157), Color3.new(1, 0.196, 0.235) }
local function mkE(pl)
	-- ดีไซน์: มุมกรอบ 4 มุม (เส้นตัว L) + เงาเข้มใต้เส้น + พื้นเทาจาง + แถบเลือดไล่สีด้านซ้าย + ชื่อ/ระยะ
	local e = {}
	e.tint = Drawing.new("Square"); e.tint.Filled, e.tint.Color, e.tint.Transparency = true, Color3.new(), 0.12
	for i = 1, 8 do
		local s = Drawing.new("Line"); s.Thickness, s.Color, s.Transparency = 3.5, Color3.new(), 0.6
		e["s" .. i] = s
	end
	for i = 1, 8 do
		local m = Drawing.new("Line"); m.Thickness, m.Transparency = UIS.TouchEnabled and 2.5 or 1.6, 1
		e["m" .. i] = m
	end
	e.hpBg = Drawing.new("Square"); e.hpBg.Filled, e.hpBg.Color, e.hpBg.Transparency = true, Color3.new(), 0.65
	e.hp = Drawing.new("Square"); e.hp.Filled, e.hp.Transparency = true, 1
	e.name = Drawing.new("Text"); e.name.Center, e.name.Outline = true, true
	e.info = Drawing.new("Text"); e.info.Center, e.info.Outline, e.info.Color = true, true, Color3.fromRGB(215,215,215)
	store[pl] = e
	return e
end
local function hideE(e) for _, d in pairs(e) do d.Visible = false end end

local function drawEsp()
	local o = cam.CFrame.Position
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= lp then
			local e = store[pl] or mkE(pl)
			local ch = pl.Character
			local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
			local head = ch and ch:FindFirstChild("Head")
			local friendly = not foe(pl)
			if not (S.EspOn and aliveC(ch) and root and head) or (friendly and not S.EspTeam) then
				hideE(e)
			else
				local dist = (root.Position - o).Magnitude
				if dist > S.EspDist then hideE(e)
				else
					local top, v1 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y, 0))
					local bot, v2 = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
					if not (v1 or v2) then hideE(e)
					else
						-- จอสัมผัส: คนไกลหดเหลือกรอบ ~10px ตัวหนังสือ 8px = บนจอมือถือแทบมองไม่เห็น (ดูเหมือน "ต้องเข้าใกล้ถึงจะขึ้น") → ตั้งขนาดต่ำสุดให้เห็นได้
						local h = math.max(math.abs(bot.Y - top.Y), UIS.TouchEnabled and 30 or 0)
						local w = h * 0.52
						local x, y = top.X - w * 0.5, top.Y
						local col = pl.Team and pl.Team.TeamColor.Color or Color3.new(1,1,1)
						-- ตำรวจ: ผู้ต้องหา (WantedLevel 1-3) ชื่อมี ★ และกรอบเป็นสีระดับหมายจับตามสีของเกม
						local wl = tonumber(pl:GetAttribute("WantedLevel")) or 0
						if wl > 0 and S.WantedEsp then col = WANTED_COL[math.min(wl, 3)] end
						local hum = ch:FindFirstChildOfClass("Humanoid")
						local alpha = friendly and 0.55 or 1
						local L = math.max(6, math.min(w, h) * 0.3)
						local X2, Y2 = x + w, y + h
						local segs = {
							{ x, y, x + L, y }, { x, y, x, y + L },
							{ X2, y, X2 - L, y }, { X2, y, X2, y + L },
							{ x, Y2, x + L, Y2 }, { x, Y2, x, Y2 - L },
							{ X2, Y2, X2 - L, Y2 }, { X2, Y2, X2, Y2 - L } }
						for i = 1, 8 do
							local s, m, g = e["s" .. i], e["m" .. i], segs[i]
							s.From, s.To, s.Visible = Vector2.new(g[1], g[2]), Vector2.new(g[3], g[4]), S.EspBox
							m.From, m.To, m.Visible = s.From, s.To, S.EspBox
							m.Color, m.Transparency = col, alpha
						end
						e.tint.Visible = S.EspBox
						if S.EspBox then
							e.tint.Position, e.tint.Size = Vector2.new(x, y), Vector2.new(w, h)
							local f = math.clamp((hum and hum.Health or 0) / math.max(hum and hum.MaxHealth or 100, 1), 0, 1)
							e.hpBg.Position, e.hpBg.Size = Vector2.new(x - 7, y - 1), Vector2.new(4, h + 2)
							e.hp.Position, e.hp.Size = Vector2.new(x - 6, y + h * (1 - f)), Vector2.new(2, h * f)
							e.hp.Color = Color3.fromHSV(f * 0.33, 0.85, 1)
						end
						e.hpBg.Visible, e.hp.Visible = S.EspBox, S.EspBox
						-- ตัวหนังสือเล็กลงตามระยะ กันซ้อนทับตอนคนเยอะ
						local ts = math.clamp(S.EspTextSize - dist / 140, UIS.TouchEnabled and 15 or 10, math.max(S.EspTextSize, UIS.TouchEnabled and 16 or 0))
						e.name.Size, e.info.Size = ts, ts - 2
						e.name.Text, e.name.Color = ((wl > 0 and S.WantedEsp) and ("★" .. wl .. " ") or "") .. (pl.DisplayName:find("[\128-\255]") and pl.Name or pl.DisplayName), col  -- ลีดเดอร์บอร์ดโชว์ DisplayName | Drawing วาดตัวอักษรไทยไม่ได้ (ขึ้น ???) เลยถอยไปใช้ชื่อบัญชีถ้ามีตัวไทย
						e.name.Position = Vector2.new(top.X, y - (ts + 5))
						-- ไม่โชว์ชื่อทีม: Drawing วาดตัวไทยไม่ได้ (ขึ้น ???) สีกรอบบอกทีมอยู่แล้ว
						e.info.Text = string.format("%dm · %dhp", math.floor(dist), math.floor(hum and hum.Health or 0))
						e.info.Position = Vector2.new(top.X, y + h + 3)
						e.name.Transparency, e.info.Transparency = alpha, alpha * 0.9
						e.name.Visible, e.info.Visible = true, true
					end
				end
			end
		end
	end
end
getgenv().SuiteRem = Players.PlayerRemoving:Connect(function(pl)
	local e = store[pl]
	if e then for _, d in pairs(e) do pcall(function() d:Remove() end) end store[pl] = nil end
end)

--========================= ESP จุดสำคัญ =========================
-- ยืนยันกับเกมจริงแล้ว (26/10): ที่มีจริงคือ ขายยา x3 / DrugSellerNPC / SecretShopNPC_N
-- 'พเนจร' กับ 'Wander' ไม่มีอยู่ในเกม ตัดออก ไม่งั้นแค่ scan เปล่า
getgenv().PERules = {
	-- Drawing API วาดไทย/emoji ไม่ได้ ออกมาเป็น ? หมด label ต้องเป็น ASCII เท่านั้น
	-- kind: drug = จุดขายยา, shop = ร้านค้ามืด (เปิด/ปิดแยกกันได้ในแท็บจุดสำคัญ)
	{ match = "ขายยา",      label = "SELL DRUG",    kind = "drug", color = Color3.fromRGB(120,255,140) },
	{ match = "DrugSeller", label = "DEALER",       kind = "drug", color = Color3.fromRGB(120,255,140) },
	{ match = "SecretShop", label = "BLACK MARKET", kind = "shop", color = Color3.fromRGB(255,190,60) },
}
local points, pdraw = {}, getgenv().PEDraw
local function pivotOf(d)
	if d:IsA("Model") then
		local ok, cf = pcall(function() return d:GetPivot() end)
		if ok then return cf.Position end
	elseif d:IsA("BasePart") then return d.Position end
end
local function ruleFor(n)
	for _, r in ipairs(getgenv().PERules) do
		if n:find(r.match, 1, true) then return r end
	end
end
local function addPoint(d)
	if not (d:IsA("Model") or d:IsA("BasePart")) then return end
	local r = ruleFor(d.Name)
	if r and pivotOf(d) and not points[d] then points[d] = r end
end
local function scanPoints()
	table.clear(points)
	for _, d in ipairs(workspace:GetDescendants()) do addPoint(d) end
	local n = 0
	for _ in pairs(points) do n = n + 1 end
	return n
end
getgenv().PEScan = scanPoints

local function mkP(i)
	local t = Drawing.new("Text"); t.Center, t.Outline = true, true
	local dot = Drawing.new("Circle"); dot.Thickness, dot.Radius, dot.Filled, dot.Transparency = 2, 5, false, 1
	pdraw[i] = { text = t, dot = dot }
	return pdraw[i]
end
local function drawPoints()
	local o, vp = cam.CFrame.Position, cam.ViewportSize
	for inst, r in pairs(points) do
		local e = pdraw[inst] or mkP(inst)
		local want = (r.kind == "drug" and S.PointDrug) or (r.kind == "shop" and S.PointShop)   -- ไม่ใช้ PointOn แล้ว (ค่าเก่าในเซฟค้างเป็นปิดและไม่มีปุ่มเปิด)
		-- โมเดลว่างไม่มีชิ้นส่วนเลย = ตัวหลอก/ที่จองไว้ (SecretShopNPC_1 มีอยู่ตลอดทั้งที่ร้านยังไม่เปิด) ไม่โชว์
		local real = inst.Parent and (not inst:IsA("Model") or inst:FindFirstChildWhichIsA("BasePart", true) ~= nil)
		local pos = want and real and pivotOf(inst)
		if not pos then hideE(e)
		else
			local dist = (pos - o).Magnitude
			local sp, on = cam:WorldToViewportPoint(pos)
			local x, y, off = sp.X, sp.Y, not on
			if off then
				-- นอกจอ/ข้างหลัง: ดันไปขอบจอพร้อมลูกศรชี้ทิศ
				local dir = Vector2.new(sp.X - vp.X / 2, sp.Y - vp.Y / 2)
				if sp.Z < 0 then dir = -dir end
				if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
				dir = dir.Unit
				local c = Vector2.new(vp.X / 2, vp.Y / 2)
				local m = math.min((c.X - S.EdgePad) / math.max(math.abs(dir.X), 1e-3),
					(c.Y - S.EdgePad) / math.max(math.abs(dir.Y), 1e-3))
				x, y = c.X + dir.X * m, c.Y + dir.Y * m
			end
			e.text.Size, e.text.Color = S.PointTextSize, r.color
			e.text.Text = string.format("%s %s %dm", r.label, off and "<" or "", math.floor(dist))
			e.text.Position = Vector2.new(x, y - S.PointTextSize - 6)
			e.dot.Color, e.dot.Position = r.color, Vector2.new(x, y)
			e.text.Visible, e.dot.Visible = true, true
		end
	end
end
getgenv().PEAdd = workspace.DescendantAdded:Connect(function(d)
	if live() then task.wait(0.1) addPoint(d) end
end)
getgenv().PERem = workspace.DescendantRemoving:Connect(function(d)
	if points[d] then
		points[d] = nil
		local e = pdraw[d]
		if e then for _, x in pairs(e) do pcall(function() x:Remove() end) end pdraw[d] = nil end
	end
end)
do
	local blk = game.ReplicatedStorage:FindFirstChild("Shop")
	blk = blk and blk:FindFirstChild("Black")
	local ann = blk and blk:FindFirstChild("SecretShopAnnounce")
	if ann then
		getgenv().PEAnn = ann.OnClientEvent:Connect(function()
			if not live() then return end
			task.wait(1)
			print("[PE] ร้านลับเกิดใหม่ — จุดทั้งหมด:", scanPoints())
		end)
	end
end
scanPoints()

--========================= STAMINA =========================
task.spawn(function()
	local sg = lp.PlayerGui:WaitForChild("StaminaGui", 30)
	if not sg then return end
	local bar = sg:WaitForChild("StaminaContainer"):WaitForChild("BarBg"):WaitForChild("StaminaBar")
	local cache = {}
	getgenv().SuiteStam = RS.Heartbeat:Connect(function()
		if not (live() and S.StaminaOn) then return end
		for _, e in ipairs(cache) do pcall(debug.setupvalue, e[1], e[2], e[3]) end  -- e[3] = ค่าที่ต้องยัด (100 หรือ 1 ตามสเกล)
	end)
	-- ใช้ getupvalue แบบ index (บาง executor ไม่มี getupvalues พหูพจน์ = เดิมพังเงียบ ๆ)
	-- เผื่อสเกล 0-1 กับ 0-100 + ชื่อสคริปต์หลายแบบ เกมเปลี่ยนชื่อก็ยังเจอ
	local names = { "RunSystem", "Stamina", "Sprint", "Movement", "Run" }
	getgenv().StamRespawn = lp.CharacterAdded:Connect(function() table.clear(cache) end)
	local stale = 0
	while live() do
		-- แคชไม่ว่างแต่แถบยังลด = ล็อกผิดตัว (closure เก่าหลังเกิดใหม่) → ทิ้งแล้วสแกนใหม่
		if #cache > 0 and S.StaminaOn and bar.Parent and bar.Size.X.Scale < 0.97 then stale = stale + 1 else stale = 0 end
		if stale >= 3 then table.clear(cache) stale = 0 print("[STAM] แคชเก่า สแกนใหม่") end
		if S.StaminaOn and #cache == 0 then
			local scale = bar.Size.X.Scale        -- 0..1
			local want100 = scale * 100
			if scale < 0.995 then                 -- ต้องเหนื่อยนิดตอนสแกน ค่าถึงไม่ชนกับ 100 เต็ม
				for _, f in ipairs(getgc()) do
					if type(f) == "function" and islclosure(f) then
						local src = tostring(debug.getinfo(f).short_src)
						local hit = false
						for _, nm in ipairs(names) do if src:find(nm) then hit = true break end end
						if hit then
							local i = 1
							while true do
								local ok, v = pcall(debug.getupvalue, f, i)
								if not ok then break end
								if type(v) == "number" then
									if math.abs(v - want100) < 1 then cache[#cache+1] = { f, i, 100 }
									elseif math.abs(v - scale) < 0.01 then cache[#cache+1] = { f, i, 1 } end
								end
								i = i + 1
							end
						end
					end
				end
				if #cache > 0 then print("[STAM] เจอค่า stamina "..#cache.." จุด ล็อกเต็มแล้ว")
				else print("[STAM] ยังหาไม่เจอ — วิ่งให้เหนื่อยนิดรอสแกนรอบหน้า (ถ้ายังไม่ได้ = เซิร์ฟคุมเอง แก้ฝั่ง client ไม่ได้)") end
			end
		end
		task.wait(1)
	end
end)

--========================= SPEED =========================
local function hookSpeed(char)
	local h = char:WaitForChild("Humanoid")
	if getgenv().SpeedHumConn then pcall(function() getgenv().SpeedHumConn:Disconnect() end) end
	local base = (getgenv().SpeedHum == h and getgenv().SpeedBase) or h.WalkSpeed
	getgenv().SpeedHum = h
	local mine = false
	local function set()
		mine = true
		-- ตอนเปิด Noclip ใช้ความเร็วปกติของเกม (ไม่บวกเพิ่ม) | วิ่งเกม = 18 ถ้าไม่ cap 18+16=34 เกิน 30 ที่โดนเตะ (Anti System 25)
		h.WalkSpeed = S.Noclip and base or math.min(base + S.SpeedBonus, SpeedCap)
		mine = false
	end
	getgenv().SpeedHumConn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if mine or not live() then return end
		base = h.WalkSpeed
		getgenv().SpeedBase = base
		set()
	end)
	getgenv().SpeedBase = base
	getgenv().SuiteSetSpeed = set
	set()
end
if lp.Character then task.spawn(hookSpeed, lp.Character) end
getgenv().SpeedConn = lp.CharacterAdded:Connect(hookSpeed)

--========================= เปิดเมนูไว (ไม่ต้องกด E ค้าง) =========================
-- กด E ค้างคือ ProximityPrompt.HoldDuration ตั้งเป็น 0 ตอนที่เกมโชว์ปุ่ม (PromptShown) ครอบคลุมทุกเมนู/ทุกร้านที่ใช้ระบบนี้
-- จำค่าเดิมไว้คืนตอนปิดสวิตช์
-- ตั้งกับ "ทุกปุ่มที่มีอยู่แล้ว" ตั้งแต่ตอนรัน (PromptShown อย่างเดียวไม่พอ ปุ่มที่โชว์อยู่ก่อนรันจะไม่ถูกแตะ)
-- อยู่ใน do-block เพื่อไม่กินจำนวน local ของฟังก์ชันหลัก (Lua จำกัด 200)
do
	local hold0 = setmetatable({}, { __mode = "k" })
	local function fastPrompt(p)
		if hold0[p] == nil then hold0[p] = p.HoldDuration end
		p.HoldDuration = S.InstantPrompt and 0 or hold0[p]
	end
	local function fastAll()
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") then fastPrompt(d) end
		end
	end
	getgenv().SuiteFastAll = fastAll
	fastAll()
	getgenv().InstPromptConn = {
		game:GetService("ProximityPromptService").PromptShown:Connect(function(p) if live() then fastPrompt(p) end end),
		workspace.DescendantAdded:Connect(function(d) if live() and d:IsA("ProximityPrompt") then fastPrompt(d) end end),
	}
end

--========================= NOCLIP =========================
-- ทะลุกำแพง: ปิด CanCollide ทุกชิ้นของตัวละครทุกเฟรม ส่วน Humanoid ยังยืนบนพื้นด้วย raycast ของมันเอง จึงเดินลื่นและไม่ร่วงทะลุพื้น
-- กันตกแมพ: จำจุดที่เหยียบพื้นล่าสุด ถ้าดิ่งลงเกิน 60 studs ดีดกลับจุดนั้น
S.Noclip = false   -- ไม่จำข้ามรอบรัน เริ่มปิดเสมอ
local lastSafe
local wasSolid = setmetatable({}, { __mode = "k" })
-- ⚠ เคยโดนเตะ "Anti System CODE 436" ตอนใช้ฟีเจอร์นี้ (ระบบกันโกงฝั่งเซิร์ฟเวอร์ ไม่รู้เงื่อนไขแน่ชัด) เปิดเฉพาะตอนจำเป็นและปิดทันที
local function setNoclip(v)
	if v then print("[NOCLIP] ⚠ เสี่ยงโดนเตะ (Anti System 436) — เปิดสั้น ๆ เฉพาะที่จำเป็น แล้วปิดทันที") end
	S.Noclip = v
	log("noclip " .. tostring(v))
	if getgenv().SuiteSetSpeed then pcall(getgenv().SuiteSetSpeed) end   -- สลับความเร็วทันที (เปิด = ปกติ / ปิด = บวกเพิ่มกลับ)
	if not v then
		for p in pairs(wasSolid) do if p.Parent then p.CanCollide = true end end
		table.clear(wasSolid)
	end
end
getgenv().NoclipConn = RS.Stepped:Connect(function()
	if not live() then return end
	local ch = lp.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end
	if hum.FloorMaterial ~= Enum.Material.Air then lastSafe = hrp.CFrame end
	if not S.Noclip then return end
	for _, p in ipairs(ch:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then wasSolid[p] = true p.CanCollide = false end
	end
	if lastSafe and hrp.Position.Y < lastSafe.Position.Y - 60 then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = lastSafe
	end
end)

--========================= AUTO TRASH =========================
getgenv().AutoTrash = false
local skip = {}

local function isTargets(t)
	if type(t) ~= "table" then return false end
	local e = rawget(t, 1)
	return type(e) == "table" and rawget(e, "progress") ~= nil and rawget(e, "inst") ~= nil
end
local function scanUps(f)
	local out, i = {}, 1
	while i <= 48 do
		local ok, v = pcall(debug.getupvalue, f, i)
		if not ok then break end
		out[i] = v
		i = i + 1
	end
	return out, i - 1
end
-- เลือก closure ที่ upvalue เยอะสุด + ยังมีเป้าค้าง = Heartbeat ของกองปัจจุบัน
local function findLive()
	local best, bestN, data
	for _, f in ipairs(getgc()) do
		if type(f) == "function" and islclosure(f)
			and tostring(debug.getinfo(f).short_src):find("Minigameclient") then
			local ups, n = scanUps(f)
			local tbl
			for i = 1, n do
				if isTargets(ups[i]) then
					for _, e in ipairs(ups[i]) do
						if not e.found then tbl = ups[i] break end
					end
				end
			end
			if tbl and n > (bestN or 0) then
				local bools, slots = {}, {}
				for i = 1, n do
					local v = ups[i]
					if type(v) == "boolean" then bools[#bools+1] = i
					elseif v == nil or typeof(v) == "Vector2" then slots[#slots+1] = i end
				end
				best, bestN, data = f, n, { tbl = tbl, bools = bools, slots = slots }
			end
		end
	end
	return best, data
end
local function nextT(tbl) for _, e in ipairs(tbl) do if not e.found then return e end end end
local function centerOf(e) return e.inst.AbsolutePosition + e.inst.AbsoluteSize * 0.5 end
local function openFrame()
	local UI = lp.PlayerGui:FindFirstChild("MiniGameUI")
	local TF = UI and UI:FindFirstChild("TrashFrame")
	if UI and TF and UI.Enabled and TF.Visible then return TF end
end
-- เรียนเองว่า upvalue ตัวไหนคือ "กำลังถือไฟ" โดยดูว่า progress ขึ้นจริงมั้ย
local function learnHold(f, d)
	local e = nextT(d.tbl)
	if not e then return end
	local c = centerOf(e)
	for _, bi in ipairs(d.bools) do
		local ok, before = pcall(debug.getupvalue, f, bi)
		if ok and before == false then
			for _, si in ipairs(d.slots) do pcall(debug.setupvalue, f, si, c) end
			pcall(debug.setupvalue, f, bi, true)
			local p0 = e.progress
			task.wait(0.4)
			if e.progress > p0 then return bi end
			pcall(debug.setupvalue, f, bi, before)
		end
	end
end
local function playMinigame()
	local t0 = os.clock()
	local f, d
	repeat
		f, d = findLive()
		if not f then task.wait(0.2) end
	until f or not openFrame() or os.clock() - t0 > 5
	if not f then return false end
	local hi = learnHold(f, d)
	if not hi then return false end
	while live() and getgenv().AutoTrash and openFrame() do
		local e = nextT(d.tbl)
		if not e then break end
		local c = centerOf(e)
		pcall(debug.setupvalue, f, hi, true)
		for _, si in ipairs(d.slots) do pcall(debug.setupvalue, f, si, c) end
		-- เร่งแค่เป้าที่ขุดอยู่ หยุด 7.9 ให้เกมเติมช่วงสุดท้าย+ยิง remote เอง
		if S.DigMult > 1 and e.progress > 0 and e.progress < 7.9 then
			e.progress = math.min(e.progress + (1 / 60) * (S.DigMult - 1), 7.9)
		end
		RS.Heartbeat:Wait()
		if os.clock() - t0 > 85 then break end
	end
	pcall(debug.setupvalue, f, hi, false)
	local done = nextT(d.tbl) == nil
	print(string.format("[AT] จบกอง: %s (%.1f วิ)", done and "ครบ" or "ไม่ครบ", os.clock() - t0))
	local t2 = os.clock()
	repeat task.wait(0.2) until not openFrame() or os.clock() - t2 > 6
	return done
end
local function partOf(p)
	return p.Parent:IsA("BasePart") and p.Parent or p.Parent:FindFirstChildWhichIsA("BasePart", true)
end
local function nearestPrompt()
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local job = workspace:FindFirstChild("Job")
	local pile = job and job:FindFirstChild("ขยะ")
	if not (hrp and pile) then return end
	local best, bd
	for _, p in ipairs(pile:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Dirty" and (skip[p] or 0) < os.clock() then
			local part = partOf(p)
			if part then
				local dd = (part.Position - hrp.Position).Magnitude
				if dd <= S.TrashSearch and (not bd or dd < bd) then best, bd = p, dd end
			end
		end
	end
	return best
end
-- หลบรถเมล์ (Workspace.BusWaypoints.<Model>) | เรียกในลูปเดินของฟาร์ม: คืน true = กำลังถอยหนี ให้รอ
-- ระยะอันตราย = 40 + ความเร็วรถ*1.5 studs (วัดความเร็วจากตำแหน่งที่ต่างระหว่างการเรียก) แล้วถอยทิศตรงข้ามรถ 30 studs
getgenv().SuiteBusDodge = (function()
	local last, since, freeUntil = {}, nil, 0
	return function()
		if os.clock() < freeUntil then return false end   -- หลบนานเกิน 8 วิ (รถจอด/ติดหน้ากำแพง) -> ปล่อยเดินต่อ 12 วิ
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		local bw = workspace:FindFirstChild("BusWaypoints")
		if not (hrp and hum and bw) then return false end
		local now, danger, dv, dp = os.clock(), nil, nil, nil
		for _, m in ipairs(bw:GetChildren()) do
			if m:IsA("Model") then
				local p, l = m:GetPivot().Position, last[m]
				local vel = l and l.v or Vector3.zero
				if l and now - l.t > 0.05 and now - l.t < 1 then
					local nv = Vector3.new(p.X - l.p.X, 0, p.Z - l.p.Z) / (now - l.t)
					vel = nv.Magnitude > 2 and nv or Vector3.zero
				end
				last[m] = { p = p, t = now, v = vel }
				local flat = Vector3.new(p.X - hrp.Position.X, 0, p.Z - hrp.Position.Z)
				local sp = vel.Magnitude
				if flat.Magnitude < (sp < 2 and 18 or 40 + sp * 1.5) then danger, dv, dp = flat, vel, p break end   -- จอดอยู่ = ระยะสั้น
			end
		end
		if not danger then since = nil return false end
		since = since or now
		if now - since > 8 then since, freeUntil = nil, now + 12 return false end
		-- รถวิ่งอยู่: หลบ "ออกข้าง" ตั้งฉากกับทิศรถ ไปฝั่งที่เราอยู่ (ออกจากเลน) ไม่ถอยหลังหนี | รถจอด: ห่างรถ
		-- ทิศที่เลือกต้องไม่มีกำแพงใน 12 studs | ไม่มีทิศโล่ง = ยืนนิ่ง
		local want
		if dv.Magnitude >= 2 then
			local vh = dv.Unit
			local rel = Vector3.new(hrp.Position.X - dp.X, 0, hrp.Position.Z - dp.Z)
			local lat = rel - vh * rel:Dot(vh)
			want = lat.Magnitude > 0.5 and lat.Unit or Vector3.new(-vh.Z, 0, vh.X)
		else
			want = danger.Magnitude > 0.1 and -danger.Unit or Vector3.xAxis
		end
		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = { lp.Character, bw }
		local best, bs = nil, -1
		for k = 0, 7 do
			local a = k * math.pi / 4
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			if not workspace:Raycast(hrp.Position, dir * 12, rp) then
				local s = dir:Dot(want)
				if s > bs then best, bs = dir, s end
			end
		end
		hum:MoveTo(best and bs > -0.2 and hrp.Position + best * 25 or hrp.Position)
		return true
	end
end)()
local function walkTo(p, tmo)
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local part = partOf(p)
	if not (hum and hrp and part) then return false end
	local t0 = os.clock()
	while live() and getgenv().AutoTrash and p.Enabled do
		if (part.Position - hrp.Position).Magnitude <= p.MaxActivationDistance - 1 then
			hum:MoveTo(hrp.Position)
			return true
		end
		if getgenv().SuiteBusDodge() then t0 = t0 + 0.2 task.wait(0.2) continue end
		if os.clock() - t0 > (tmo or 8) then skip[p] = os.clock() + 30 return false end
		hum:MoveTo(part.Position)
		task.wait(0.2)
	end
	return false
end
--========================= ขายให้ NPC อัตโนมัติ =========================
-- ยืนยันกับเกมจริงแล้ว: คลิก ClickCatcher ของทุกชิ้นที่ stock > 0 เพื่อลงรายการ
-- แล้วกด "ขายทั้งหมด" -> SellResult(true, 2804) เงินเข้าจริง เซิร์ฟไม่ตีตก
-- มี NPC ขายหลายตัวในแมพ เอาตัวใกล้สุดเสมอ ไม่งั้นมันเดินข้ามแมพ
local function sellPrompt()
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "selling" then
			local part = d.Parent:IsA("BasePart") and d.Parent
				or d.Parent:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local dd = (part.Position - hrp.Position).Magnitude
				if not bd or dd < bd then best, bd = d, dd end
			end
		end
	end
	if best then print(string.format("[SELL] NPC ใกล้สุด ห่าง %d m", math.floor(bd))) end
	return best
end
local function shopFrame()
	local g = lp.PlayerGui:FindFirstChild("Shopsell")
	if g and g.Enabled and g:FindFirstChild("Frame") then return g.Frame end
end
local function click(btn)
	if not (btn and getconnections) then return end
	for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
end

local function sellAll()
	local p = sellPrompt()
	if not p then print("[SELL] ไม่เจอ NPC ขาย") return false end
	skip[p] = nil
	if not walkTo(p, 150) then print("[SELL] เดินไปหา NPC ไม่ถึง") return false end
	fireproximityprompt(p)

	local t0 = os.clock()
	local F
	repeat task.wait(0.2) F = shopFrame() until F or os.clock() - t0 > 8
	if not F then print("[SELL] UI ไม่เปิด") return false end

	-- เลือกขายเฉพาะที่ติก (SellPick ว่าง = ขายหมด)
	local function shouldSell(name)
		local p = S.SellPick
		if not p or next(p) == nil then return true end   -- ไม่ติกอะไรเลย = ขายหมด (ดีฟอลต์เดิม)
		return p[name] == true
	end
	-- ลงรายการทุกชิ้นที่มีของ (ที่เลือกขาย)
	local inv = F:FindFirstChild("invantory")
	inv = inv and inv:FindFirstChild("Items")
	local skipped = 0
	if inv then
		for _, it in ipairs(inv:GetChildren()) do
			local st = it:FindFirstChild("stock")
			local n = st and tonumber((st.Text:gsub("x", "")))
			if n and n > 0 then
				if shouldSell(it.Name) then
					click(it:FindFirstChild("ClickCatcher")) task.wait(0.12)
				else
					skipped = skipped + 1
				end
			end
		end
	end
	if skipped > 0 then print(string.format("[SELL] เก็บไว้ไม่ขาย %d ชนิด (ตามที่ติก)", skipped)) end
	task.wait(0.4)

	local sf = F:FindFirstChild("Sell")
	local total = sf and sf:FindFirstChild("number")

	-- คลิกลงรายการได้แค่ชิ้นละ 1 ต้องกด + จนเท่าจำนวนที่มี ถึงขายหมดจริง
	local rows = sf and sf:FindFirstChild("Items")
	if rows then
		for _, r in ipairs(rows:GetChildren()) do
			local have = r:FindFirstChild("quantity")
			local set  = r:FindFirstChild("number")
			local plus = r:FindFirstChild("+")
			if have and set and plus then
				local want = tonumber(have.Text) or 0
				for _ = 1, 200 do
					if (tonumber(set.Text) or 0) >= want then break end
					local before = tonumber(set.Text) or 0
					click(plus)
					task.wait(0.03)
					if (tonumber(set.Text) or 0) <= before then break end  -- กดแล้วไม่ขึ้น = เต็มแล้ว
				end
				print(string.format("[SELL]   %s -> ตั้งขาย %s/%s",
					(r:FindFirstChild("Name") and r.Name.Text) or r.Name, set.Text, have.Text))
			end
		end
		task.wait(0.3)
	end

	local amt = total and tonumber(total.Text:match("(%d+)")) or 0
	if amt > 0 then
		click(sf:FindFirstChild("TextButton"))
		local t1 = os.clock()
		repeat task.wait(0.3)
			amt = tonumber(total.Text:match("(%d+)")) or 0
		until amt == 0 or os.clock() - t1 > 6
	end
	print(string.format("[SELL] ขายเสร็จ (เหลือค้าง %d บาท)", amt))
	click(F:FindFirstChild("Close"))
	task.wait(0.5)
	return true
end
getgenv().SuiteSellNow = sellAll

local function trashLoop()
	if getgenv().SuiteTrashRunning then return end   -- มีตัววิ่งอยู่แล้ว ไม่สแปวน์ซ้ำ
	getgenv().SuiteTrashRunning = true
	local piles = 0
	while live() and getgenv().AutoTrash do
		if openFrame() then
			if playMinigame() then piles = piles + 1 end
			if S.AutoSell and piles >= S.SellEvery then
				piles = 0
				pcall(sellAll)
			end
		else
			local p = nearestPrompt()
			if p and walkTo(p) then
				fireproximityprompt(p)
				local t0 = os.clock()
				repeat task.wait(0.1) until openFrame() or os.clock() - t0 > p.HoldDuration + 6
			else task.wait(0.5) end
		end
		task.wait(0.3)
	end
	getgenv().SuiteTrashRunning = false   -- ออกลูปแล้วปลดล็อก
end

--========================= ฟาร์มแคนดี้ (เคาะประตูบ้าน Halloween) =========================
-- ถือ Black Pot Candy -> เดิน pathfinding ไปเคาะบ้านใกล้สุด (E) -> ถังเต็ม (Cap) เดินไปเทหม้อ (F) -> วนซ้ำ
-- หมดบ้านที่เคาะได้: ไปยืนรอที่หม้อ | ค่ารีเซ็ตบ้านยังไม่ยืนยัน ใช้ cooldown ฝั่งสคริปต์ (CANDY_CD)
getgenv().AutoCandy = false
getgenv().SuiteCandy = {}   -- ห่อใน do-block กัน local ทะลุลิมิต 200 ของ Luau | ภายนอกใช้ผ่านตารางนี้
do
local PFS = game:GetService("PathfindingService")
local CANDY_CD = 90
local candyCd, candyBad = {}, {}   -- Cd = บ้านที่เคาะแล้วรอรีเซ็ต | Bad = เดินไม่ถึง ข้ามไว้ก่อน
-- log วัดผลจริง -> SailueatSuite/candy_stats.txt (150 บรรทัดล่าสุด): ต่อบ้านได้กี่ชิ้น / ห่างจากเคาะครั้งก่อนกี่วิ / เทหม้อกี่ชิ้นใช้เวลาเท่าไร
local candyLast, logBuf, potAt = {}, {}, os.clock()
local function candyLog(s)
	logBuf[#logBuf + 1] = os.date("%H:%M:%S ") .. s
	if #logBuf > 150 then table.remove(logBuf, 1) end
	pcall(writefile, "SailueatSuite/candy_stats.txt", table.concat(logBuf, "\n"))
end
local candyStatus = function() end
local function posOf(p)
	local a = p.Parent
	if a:IsA("Attachment") then return a.WorldPosition end
	local part = a:IsA("BasePart") and a or a:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position
end
local function candyHeld() return lp:GetAttribute("CandyHeld") or 0 end
local function candyTool()
	local ch = lp.Character
	return ch and (ch:FindFirstChild("Black Pot Candy") or lp.Backpack:FindFirstChild("Black Pot Candy"))
end
local function candyOn() return live() and getgenv().AutoCandy end
-- โซนเซฟ (Workspace.Safe.*) | ตอนติดคอมแบตเดินเข้าโซนแล้วโดนผลักออก -> ห้ามเหยียบ/ห้ามให้ทางผ่าน
local safeParts, safeAt = {}, 0
local function inSafe(pos, pad)
	if os.clock() - safeAt > 30 then
		safeAt, safeParts = os.clock(), {}
		local f = workspace:FindFirstChild("Safe")
		if f then for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then safeParts[#safeParts + 1] = d end end end
	end
	for _, s in ipairs(safeParts) do
		local l = s.CFrame:PointToObjectSpace(pos)
		local h = s.Size / 2 + Vector3.new(pad, pad, pad)
		if math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z then return true end
	end
	return false
end
local function inCombat() local e = getgenv().CombatEnd return e ~= nil and e > os.clock() end
local function xz(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
local function charNow()
	local ch = lp.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 then return hum, hrp end
end
-- เดินไปจนอยู่ในระยะ stop (studs) | คืน true, หรือ false + เหตุผล: "dead" ตาย | "combat" ทางผ่านโซนเซฟตอนคอมแบต | "stuck" เดินไม่ถึง
-- ไม่เจอทาง/ติดเกิน 3 ครั้ง = ยอมแพ้ ไม่ดันหน้ากำแพง | ดึงตัวละครสดทุกรอบ (ตายแล้วเกิดใหม่ไม่ค้าง ref เก่า)
local function pathTo(pos, stop, tmo)
	local t0, stucks = os.clock(), 0
	while candyOn() and os.clock() - t0 < tmo do
		local hum, hrp = charNow()
		if not hum then return false, "dead" end
		if xz(hrp.Position, pos) <= stop then return true end
		local path = PFS:CreatePath({ AgentRadius = 3, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
		if not (ok and path.Status == Enum.PathStatus.Success) then return false, "stuck" end
		local wps = path:GetWaypoints()
		if inCombat() then
			for _, w in ipairs(wps) do if inSafe(w.Position, 3) then return false, "combat" end end
		end
		local replan, lastW = false, nil
		for i = 2, #wps do
			local w = wps[i]
			lastW = w
			if w.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			hum:MoveTo(w.Position)
			local last, lt, dodged = hrp.Position, os.clock(), false
			while candyOn() and xz(hrp.Position, w.Position) > 3.5 do
				task.wait(0.15)
				hum, hrp = charNow()
				if not hum then return false, "dead" end
				if xz(hrp.Position, pos) <= stop then return true end
				if inCombat() and inSafe(w.Position, 3) then hum:MoveTo(hrp.Position) return false, "combat" end
				if getgenv().SuiteBusDodge() then dodged, lt, t0 = true, os.clock(), t0 + 0.15 continue
				elseif dodged then dodged = false hum:MoveTo(w.Position) end
				if (hrp.Position - last).Magnitude > 0.8 then last, lt = hrp.Position, os.clock() end
				if os.clock() - lt > 1.5 then   -- ไม่ขยับ = ติด: กระโดดครั้งหนึ่ง แล้วคำนวณใหม่ (นับ 3 ครั้งแล้วเลิก)
					hum.Jump = true
					stucks += 1
					replan = true
					break
				end
				if os.clock() - t0 > tmo then break end
			end
			if replan then break end
		end
		if replan then
			if stucks >= 3 then
				local h2 = charNow()
				if h2 then h2:MoveTo(select(2, charNow()).Position) end
				return false, "stuck"
			end
			-- ติดเสา/ขอบ: ก้าวข้างฉากกับทิศที่จะไปครั้งละ 8 studs (สลับซ้าย-ขวา เลือกฝั่งที่ไม่มีของขวาง) แล้วกระโดด ค่อยคำนวณทางใหม่
			local h2, r2 = charNow()
			if h2 and lastW then
				local fwd = Vector3.new(lastW.Position.X - r2.Position.X, 0, lastW.Position.Z - r2.Position.Z)
				local side = fwd.Magnitude > 0.1 and Vector3.new(-fwd.Z, 0, fwd.X).Unit or Vector3.xAxis
				if stucks % 2 == 0 then side = -side end
				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = { lp.Character }
				if workspace:Raycast(r2.Position, side * 8, rp) then side = -side end
				h2:MoveTo(r2.Position + side * 8)
				h2.Jump = true
				task.wait(0.8)
			end
		end
	end
	local hum, hrp = charNow()
	if not hum then return false, "dead" end
	return xz(hrp.Position, pos) <= stop, "stuck"
end
local function candyPot()
	local hel = workspace:FindFirstChild("Helloween")
	if not hel then return end
	for _, p in ipairs(hel:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.ActionText == "เทแคนดี้ลงหม้อ" then return p end
	end
end
-- เลือกบ้านถัดไปตามเวลาจริง: ต้นทุน = max(เวลาเดินไป, เวลาที่บ้านนั้นรอรีเซ็ต) + 0.5 * เวลาเดินจากบ้านนั้นไปบ้านใกล้สุดถัดไป
-- => ฟาร์มบ้านกระจุกเดียวกันให้หมดก่อน ยอมรอบ้านที่ใกล้รีเซ็ตแทนการเดินไปไกล | คืน (บ้าน, วินาทีที่ต้องรอ)
-- เวลาที่บ้านพร้อมให้เคาะ: attr ReadyAt (unix) ของ KnockPrompt เทียบกับ workspace:GetServerTimeNow() (ยืนยันจาก log จริงว่าสเกลตรงกัน)
local function readyIn(p)
	local r = p:GetAttribute("ReadyAt")
	local w = r and r - workspace:GetServerTimeNow() or 0
	return math.max(w, (candyCd[p] or 0) - os.clock(), 0)
end
-- เลือกบ้านถัดไปตามเวลาจริง: ต้นทุน = max(เวลาเดินไป, เวลารอ ReadyAt) + 0.5 * เวลาเดินจากบ้านนั้นไปบ้านใกล้สุดถัดไป (บ้าน Golden ลด 20 วิ ให้ไปก่อน)
-- Enabled=false แต่ ReadyAt ยังไม่ถึง = กำลังคูลดาวน์ ยังเลือกได้ (ไปรอ) | Enabled=false และถึงเวลาแล้ว = ปิดอยู่ ไม่เลือก
-- คืน (บ้าน, วินาทีที่ต้องรอหลังเดินถึง)
local function candyNextHouse()
	local hel = workspace:FindFirstChild("Helloween")
	local hum, hrp = charNow()
	if not (hel and hum) then return end
	local now, sp, list = os.clock(), math.max(hum.WalkSpeed, 8), {}
	for _, p in ipairs(hel:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Name == "KnockPrompt" and (p.Enabled or readyIn(p) > 0) and (candyBad[p] or 0) < now then
			local pos = posOf(p)
			if pos and not (inCombat() and inSafe(pos, 3)) then list[#list + 1] = { p = p, pos = pos } end
		end
	end
	local best, bc, bw
	for _, a in ipairs(list) do
		local travel = (a.pos - hrp.Position).Magnitude / sp
		local cdw = readyIn(a.p)
		local nn
		for _, b in ipairs(list) do
			if b ~= a then
				local d = (b.pos - a.pos).Magnitude
				if not nn or d < nn then nn = d end
			end
		end
		local cost = math.max(travel, cdw) + (nn or 0) / sp * 0.5 - (a.p:GetAttribute("Golden") and 20 or 0)
		if not bc or cost < bc then best, bc, bw = a.p, cost, math.max(cdw - travel, 0) end
	end
	return best, bw
end
local function candyLoop()
	if getgenv().SuiteCandyRunning then return end
	getgenv().SuiteCandyRunning = true
	local rounds = 0
	while candyOn() do
			local ok, err = pcall(function()
				local hum = charNow()
				if not hum then candyStatus("ตายอยู่ รอเกิดใหม่") task.wait(1) return end
				local tool = candyTool()
				if not tool then candyStatus("ไม่มีถัง Black Pot Candy ในตัว") task.wait(2) return end
				if tool.Parent ~= lp.Character then hum:EquipTool(tool) task.wait(0.3) end
				local cap = tool:GetAttribute("Cap") or 300
				local held = candyHeld()
				local house, cdw
				if held < cap then house, cdw = candyNextHouse() end
				if house and cdw > 45 then house = nil end   -- ทุกบ้านต้องรอนาน -> ไปเทหม้อ/ยืนรอที่หม้อแทน
				if house then
					candyStatus(("ไปเคาะบ้าน | ถัง %d/%d | รอบ %d"):format(held, cap, rounds))
					-- เคาะจากไกลขึ้น: ระยะแนวราบ MaxActivationDistance-1.5 (สูงสุด 8.5) แทน 7 ถ้าเคาะไม่ติดจะถูกนับเป็นไม่ได้ gain ใน log
					local good, why = pathTo(posOf(house), math.min(house.MaxActivationDistance - 1.5, 8.5), 60)
					if good then
						-- รอเวลาพร้อมจริง (ReadyAt) และให้อนิเมชันของบ้านเดิมจบ (Busy) ก่อน ไม่ใช่เดาเวลาเอง
						local gate = os.clock()
						-- ถึงบ้านแล้วต้องรอเกิน 45 วิ (ReadyAt ถูกขยับหลังเลือก เช่น มีคนอื่นเคาะ) = ไม่ยืนรอ กลับไปเลือกบ้านใหม่ที่คุ้มกว่า
						if readyIn(house) > 45 then
							candyLog(("SKIP %s ต้องรอ %ds เกินเพดาน ไปเลือกบ้านอื่น"):format(
								house:GetFullName():gsub("^Workspace%.Helloween%.", ""), readyIn(house)))
							candyBad[house] = os.clock() + 20
							return
						end
						while candyOn() and (readyIn(house) > 0 or house:GetAttribute("Busy")) and readyIn(house) <= 45 and os.clock() - gate < 50 do
							candyStatus(("รอบ้านพร้อม %ds | ถัง %d/%d"):format(math.ceil(readyIn(house)), held, cap))
							task.wait(0.3)
						end
						if readyIn(house) > 45 then
							candyBad[house] = os.clock() + 20   -- ReadyAt ถูกขยับระหว่างรอ -> ไปบ้านอื่น
						elseif not house.Enabled then
							candyBad[house] = os.clock() + 120   -- ถึงเวลาแล้วแต่ปุ่มยังปิด (เช่น บ้าน Golden หมดช่วง) ข้ามไปก่อน
						else
							-- เคาะสูงสุด 3 ครั้ง: ถือว่าติดเมื่อ ReadyAt เปลี่ยน / Busy เป็นจริง / ถังเพิ่ม | ไม่ติด = ขยับเข้าใกล้ประตูแล้วลองใหม่
							local r0, hit, tries = house:GetAttribute("ReadyAt"), false, 0
							local function knocked() return candyHeld() ~= held or house:GetAttribute("ReadyAt") ~= r0 or house:GetAttribute("Busy") == true end
							for attempt = 1, 3 do
								tries = attempt
								fireproximityprompt(house)
								local t0 = os.clock()
								repeat task.wait(0.15) until knocked() or os.clock() - t0 > 2
								if knocked() then hit = true break end
								if not candyOn() then break end
								pathTo(posOf(house), 3.5, 8)
							end
							if hit then
								-- ยืนรอแค่จนถังเพิ่ม (ได้ของแล้วไปต่อทันที ไม่รออนิเมชันประตูปิด) | ไม่เพิ่มภายใน 6 วิ = ไปต่อ
								local t1 = os.clock()
								repeat task.wait(0.1) until candyHeld() ~= held or os.clock() - t1 > 6
							end
							local gain, prev = candyHeld() - held, candyLast[house]
							candyLog(("KNOCK %s ครั้งที่=%d ติด=%s gain=%d Golden=%s คูลดาวน์ต่อไป=%ds ห่างจากครั้งก่อน=%s ถัง=%d"):format(
								house:GetFullName():gsub("^Workspace%.Helloween%.", ""), tries, tostring(hit), gain,
								tostring(house:GetAttribute("Golden") == true), readyIn(house), prev and ("%ds"):format(os.clock() - prev) or "ครั้งแรก", candyHeld()))
							if hit then candyLast[house] = os.clock() end
							-- เคาะแล้วอย่ากลับมาบ้านเดิมทันที: ReadyAt ใหม่จากเซิร์ฟเวอร์มาช้ากว่า (ตอนผมเช็ก ยังโชว์ว่าพร้อมอยู่ ทำให้เลือกบ้านเดิมซ้ำแล้วยืนรอ)
							candyCd[house] = os.clock() + (hit and 40 or 30)
							task.wait(0.3)
						end
					elseif why == "combat" then
						candyStatus("ติดคอมแบต ทางผ่านโซนเซฟ รอหมดก่อน") task.wait(1)
					elseif why ~= "dead" then
						candyBad[house] = os.clock() + 60   -- เดินไม่ถึง/ติด ข้ามไปก่อน
					end
				else
					local pot = candyPot()
					local pos = pot and posOf(pot)
					if not pos then task.wait(2) return end
					if held > 0 then
						candyStatus(("ไปเทหม้อ | ถัง %d/%d"):format(held, cap))
						local good, why = pathTo(pos, math.min(pot.MaxActivationDistance - 2, 7), 90)
						if good then
							fireproximityprompt(pot)
							local t0 = os.clock()
							repeat task.wait(0.3) until candyHeld() == 0 or os.clock() - t0 > 6
							if candyHeld() == 0 then
								rounds += 1
								candyLog(("POT เทแล้ว %d ชิ้น รอบที่ %d ใช้เวลาตั้งแต่เทครั้งก่อน %ds"):format(held, rounds, os.clock() - potAt))
								potAt = os.clock()
							end
						elseif why == "combat" then
							candyStatus("ติดคอมแบต หม้ออยู่ในโซนเซฟ รอหมดก่อน") task.wait(1)
						else task.wait(1) end
					else
						candyStatus("ยืนรอบ้านรีเซ็ตที่หม้อ | รอบ " .. rounds)
						if not inCombat() then pathTo(pos, 8, 90) end
						task.wait(3)
					end
				end
			end)
		if not ok then warn("[CANDY]", err) task.wait(1) end
		task.wait(0.2)
	end
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if hum and hrp then hum:MoveTo(hrp.Position) end
	candyStatus("หยุดอยู่")
	getgenv().SuiteCandyRunning = false
end
getgenv().SuiteCandy.loop = candyLoop
getgenv().SuiteCandy.setStatus = function(f) candyStatus = f end
end

--========================= ย้ายเซิร์ฟ (คนน้อยสุด / คนเยอะสุด) =========================
-- ดึงลิสต์เซิร์ฟสาธารณะจาก games.roblox.com (เรียงตามจำนวนคน) ตัดเซิร์ฟปัจจุบันกับเซิร์ฟเต็มออก เสมอกันเอา ping ต่ำสุด
-- ย้ายแล้วสคริปต์หายตามปกติ: ถ้ามี suite_latest.lua จะสั่ง queue_on_teleport ให้โหลดซ้ำอัตโนมัติ (ค่าติกที่จำไว้ เช่น ฟาร์มแคนดี้ จะเปิดต่อเอง)
getgenv().SuiteHop = function(mode, say)
	say = say or print
	task.spawn(function()
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true")
			:format(game.PlaceId, mode == "max" and "Desc" or "Asc")
		local ok, r = pcall(request, { Url = url, Method = "GET" })
		if not (ok and r and r.StatusCode == 200) then
			say("ดึงลิสต์เซิร์ฟไม่ได้ (" .. tostring(ok and r and r.StatusCode or r) .. ") ลองใหม่อีกสักครู่")
			return
		end
		local best
		for _, s in ipairs(game:GetService("HttpService"):JSONDecode(r.Body).data or {}) do
			local roomOk = mode == "max" and s.playing <= s.maxPlayers - 3 or (mode ~= "max" and s.playing > 0)   -- ไม่เอาเซิร์ฟที่เกือบเต็ม (join ไม่ติด) / เซิร์ฟว่าง
			if s.id ~= game.JobId and roomOk then
				local better = not best
					or (mode == "max" and s.playing > best.playing) or (mode ~= "max" and s.playing < best.playing)
					or (s.playing == best.playing and (s.ping or 999) < (best.ping or 999))
				if better then best = s end
			end
		end
		if not best then say("ไม่เจอเซิร์ฟที่ย้ายไปได้") return end
		say(("ไปเซิร์ฟ %d/%d คน (ping %s) ..."):format(best.playing, best.maxPlayers, tostring(best.ping)))
		if isfile and isfile("suite_latest.lua") and (queue_on_teleport or queueonteleport) then
			pcall(queue_on_teleport or queueonteleport, 'task.wait(3) loadstring(readfile("suite_latest.lua"))()')
		end
		local okT, err = pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, best.id, lp) end)
		if not okT then say("ย้ายไม่สำเร็จ: " .. tostring(err)) end
	end)
end

-- อ่าน notification ของเกม รู้ผลทุกกอง
getgenv().NWConn = {}
for _, n in ipairs({ "Notifications", "CleanNotif" }) do
	local g = lp.PlayerGui:FindFirstChild(n)
	if g then
		table.insert(getgenv().NWConn, g.DescendantAdded:Connect(function(dd)
			if not live() or not dd:IsA("TextLabel") then return end
			task.wait(0.15)
			local t = dd.Text or ""
			if t:find("คุ้ย") then print(string.format("[NOTIFY] %s (DigMult=%.2f)", t, S.DigMult)) end
		end))
	end
end

--========================= นับถอยหลังอีเวนต์ =========================
-- เกมคำนวณเวลาให้อยู่แล้ว ไม่ต้องเดาเอง แค่ไปอ่านของเกม
--   EventHUD.Pill  -> "อีเวนต์ถัดไป: <ชื่อ>" + "เริ่มในอีก MM:SS"   (ยืนยันกับเกมจริง 26/10)
--   LotteryRemotes.TimerSync -> วินาทีที่เหลือถึงงวดหวย ยิงทุก 1 วิ
--   Shop.Black.SecretShopTimer -> วินาทีที่เหลือของร้านพเนจร (ยิงตอนร้านเปิดเท่านั้น)
local EV = { lotto = nil, lottoAt = 0, shop = nil, shopAt = 0, restart = nil, restartAt = 0 }
getgenv().EvConn = {}

local function evHook(inst, fn)
	if inst then table.insert(getgenv().EvConn, inst.OnClientEvent:Connect(function(...)
		if live() then fn(...) end
	end)) end
end
do
	local lr = game.ReplicatedStorage:FindFirstChild("LotteryRemotes")
	evHook(lr and lr:FindFirstChild("TimerSync"), function(sec)
		if type(sec) == "number" then EV.lotto, EV.lottoAt = sec, os.clock() end
	end)
	local blk = game.ReplicatedStorage:FindFirstChild("Shop")
	blk = blk and blk:FindFirstChild("Black")
	evHook(blk and blk:FindFirstChild("SecretShopTimer"), function(sec)
		if type(sec) == "number" then EV.shop, EV.shopAt = sec, os.clock() end
	end)
	evHook(blk and blk:FindFirstChild("CloseSecretShop"), function() EV.shop = nil end)
	-- เซิร์ฟรีสตาร์ท: ยิงวินาทีที่เหลือตอนใกล้รีเซ็ต
	local re = game.ReplicatedStorage:FindFirstChild("RemoteEvents")
	evHook(re and re:FindFirstChild("RestartCountdown"), function(sec)
		local n = tonumber(sec)
		if n then EV.restart, EV.restartAt = n, os.clock() end
	end)
	-- กระเป๋า: ฟัง SyncBag เก็บสถานะล่าสุด (อ่านอย่างเดียว ไม่ยิงอะไรเข้าเซิร์ฟ)
	local bs = game.ReplicatedStorage:FindFirstChild("BagSystem")
	if bs and bs:FindFirstChild("SyncBag") then
		table.insert(getgenv().EvConn, bs.SyncBag.OnClientEvent:Connect(function(data)
			if live() and type(data) == "table" then getgenv().BagData = data end
		end))
	end
	-- สถานะคอมแบต: CombatTagged(วินาที) นับถอยหลัง ติดใหม่รีเซ็ต, Untagged = หมด (ยืนยัน 30 วิ 27/10)
	local szf = game.ReplicatedStorage:FindFirstChild("SafeZone")
	if szf then
		local function ev(nm, fn)
			local r = szf:FindFirstChild(nm)
			if r then table.insert(getgenv().EvConn, r.OnClientEvent:Connect(function(...) if live() then fn(...) end end)) end
		end
		ev("CombatTagged", function(sec) local n = tonumber(sec) if n then getgenv().CombatEnd = os.clock() + n end end)
		ev("CombatUntagged", function() getgenv().CombatEnd = nil end)
	end
	-- แคตตาล็อกอีเวนต์ทั้งหมด (หมุนเวียนทุก 2 ชม. ทีละอัน) อ่านจาก EventConfig ของเกมตรง ๆ
	getgenv().EventCatalog = {}
	local hw = game.ReplicatedStorage:FindFirstChild("Halloween")
	local ecm = hw and hw:FindFirstChild("EventConfig")
	if ecm then
		local ok, cfg = pcall(require, ecm)
		if ok and type(cfg) == "table" and type(cfg.Events) == "table" then
			for _, e in ipairs(cfg.Events) do
				if type(e) == "table" and e.name then
					getgenv().EventCatalog[#getgenv().EventCatalog+1] = { name = e.name, kind = e.kind or "" }
				end
			end
		end
	end
end
-- เปิดกระเป๋าเกม = เรียก OpenBag:InvokeServer() (ตัวเปิดจริงของเกม เรียกแล้วไม่เด้ง)
-- + ToggleBagUI (bindable ฝั่ง client) เผื่อบางเวอร์ชันใช้ตัวนี้ toggle
local function openBag()
	local bs = game.ReplicatedStorage:FindFirstChild("BagSystem")
	if not bs then return end
	local t = bs:FindFirstChild("ToggleBagUI")
	if t then pcall(function() t:Fire() end) end
	local of = bs:FindFirstChild("OpenBag")
	if of then task.spawn(function() pcall(function() of:InvokeServer() end) end) end  -- RF ค้างได้ แยก thread
	-- ข้ามอนิเมชันเปิด: ดันหน้าต่างกระเป๋าให้โชว์เต็มทันที (UI ล้วน ไม่ยิงเซิร์ฟ)
	task.spawn(function()
		local bag = lp.PlayerGui:FindFirstChild("BagUIV2")
		local win = bag and bag:FindFirstChild("Window")
		if not win then return end
		local sc = win:FindFirstChildOfClass("UIScale")
		local target = 1.15  -- ponytail: ค่า scale เปิดเต็มที่อ่านจากเกม (26/10). เกมแก้ UI แล้วเพี้ยน -> อ่าน win UIScale ตอนเปิดมาเอง
		local t0 = os.clock()
		while os.clock() - t0 < 0.45 do          -- stomp ทุกเฟรม ทับ tween เปิดของเกม
			win.Visible = true
			if sc then sc.Scale = target end
			local body = win:FindFirstChild("Body") if body then body.Visible = true end
			RS.Heartbeat:Wait()
		end
	end)
end
getgenv().SuiteOpenBag = openBag

local function mmss(sec)
	if not sec or sec < 0 then return nil end
	return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end
-- นาฬิกาที่เดินต่อเองระหว่างที่ remote ยังไม่ยิงรอบถัดไป
local function tick(v, at)
	if not v then return nil end
	local left = v - (os.clock() - at)
	return left > 0 and left or nil
end

-- ป้าย Pill มี TextLabel ชื่อซ้ำกัน 2 ตัว แยกด้วยรูปแบบ MM:SS ไม่ใช่ลำดับ
local function pillRead()
	local eh = lp.PlayerGui:FindFirstChild("EventHUD")
	local pill = eh and eh:FindFirstChild("Pill")
	if not (pill and pill.Visible) then return nil end
	local name, clock
	for _, d in ipairs(pill:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text ~= "" then
			local m, ss = d.Text:match("(%d+):(%d+)")
			if m then clock = m .. ":" .. ss
			else name = (d.Text:gsub("^.-:%s*", "")) end
		end
	end
	if not (name or clock) then return nil end
	return (name or "?") .. " — อีก " .. (clock or "?")
end

-- ร้านพเนจรเกิดอยู่จริงมั้ย เช็กจาก instance ตรง ๆ ไม่ใช่จาก popup ที่ปิดไปแล้ว
local function shopLive()
	for inst in pairs(points) do
		if inst.Parent and inst.Name:find("SecretShop", 1, true) then return inst end
	end
end

local function eventLines()
	local out = {}
	out[#out+1] = "อีเวนต์ถัดไป: " .. (pillRead() or "ยังไม่ประกาศ")

	local inst = shopLive()
	local left = tick(EV.shop, EV.shopAt)
	if inst then
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local ip = pivotOf(inst)
		local d = (hrp and ip) and math.floor((ip - hrp.Position).Magnitude) or 0
		out[#out+1] = "ร้านพเนจร: เปิดอยู่ " .. (left and ("เหลือ " .. mmss(left)) or "")
			.. " | ห่าง " .. d .. "m"
	else
		out[#out+1] = "ร้านพเนจร: ยังไม่เกิด"
	end

	local lt = tick(EV.lotto, EV.lottoAt)
	out[#out+1] = "งวดหวย: " .. (lt and ("อีก " .. mmss(lt)) or "-")

	local rs = tick(EV.restart, EV.restartAt)
	if rs then out[#out+1] = "เซิร์ฟรีสตาร์ท: อีก " .. mmss(rs) end
	return out
end
getgenv().SuiteEvents = eventLines

--========================= กันเตะ AFK =========================
-- error 278 = Roblox เตะเองเมื่อไม่มี input จริง 20 นาที
-- AutoTrash เดินเองไม่นับเป็น input ของ เลยโดนอยู่ดี ๆ ต้องยิง input ปลอมเอง
getgenv().AfkConn = lp.Idled:Connect(function()
	if not live() then return end
	local ok = pcall(function()
		local vu = game:GetService("VirtualUser")
		vu:CaptureController()
		vu:ClickButton2(Vector2.new())
	end)
	print("[AFK] กันเตะ idle " .. (ok and "สำเร็จ" or "พลาด - executor ไม่ให้ VirtualUser"))
end)

--========================= MAIN LOOP =========================
local acc = 0
RS:BindToRenderStep("SuiteLoop", Enum.RenderPriority.Last.Value, function(dt)
	if not live() then RS:UnbindFromRenderStep("SuiteLoop") return end
	local c = cam.ViewportSize * 0.5
	fov.Position, fov.Radius = S.FovFollow and UIS:GetMouseLocation() or Vector2.new(c.X, c.Y), S.FovPx * fovK()
	fov.Visible = S.AimOn and S.ShowFov
	do
		local m = getgenv().SuiteMarker
		local g = lp.PlayerGui:FindFirstChild("GunGUI")
		local ch = g and g:FindFirstChild("Crosshair")
		if m and ch and S.AimOn and getgenv().SuiteLock then
			-- ใช้เรย์เดียวกับที่เกมยิง (ScreenPointToRay จาก Crosshair.AbsolutePosition) แล้วแปลงจุดบนเรย์กลับเป็นพิกัดจอ
			-- ไม่เดา GuiInset เอง (GetGuiInset ตอบ 58 แต่ของจริงเห็น ~36) จึงตรงเสมอ
			local ray = cam:ScreenPointToRay(ch.AbsolutePosition.X, ch.AbsolutePosition.Y)
			local v, on = cam:WorldToViewportPoint(ray.Origin + ray.Direction * 60)
			m.Position = Vector2.new(v.X, v.Y)
			m.Visible = on
		elseif m then
			m.Visible = false
		end
	end
	pin()
	acc = acc + dt
	if acc >= 1 / S.EspHz then
		acc = 0
		drawEsp()
		drawPoints()
	end
end)
getgenv().SuiteSweep = sweep
task.spawn(function() while live() do sweep() task.wait(0.25) end end)  -- สลับปืนแล้ว speed/แรงตกอัปเดตไว
task.spawn(function() while live() do task.wait(3) saveCfg() end end)  -- จำค่าอัตโนมัติทุก 3 วิ

UIS.InputBegan:Connect(function(i, gp)
	if gp or not live() then return end
	if i.KeyCode == Enum.KeyCode.K then S.AimOn = not S.AimOn lockChar = nil
	elseif i.KeyCode == Enum.KeyCode.L then S.EspOn = not S.EspOn
	elseif i.KeyCode == Enum.KeyCode.B then openBag() end
end)

--========================= CUSTOM UI (แนวเกมมิ่ง sidebar น้ำเงิน-ฟ้านีออน) =========================
local C = {
	bg     = Color3.fromRGB(9,14,28),     -- พื้นเข้มสุด
	panel  = Color3.fromRGB(14,22,44),    -- แผงหัว
	side   = Color3.fromRGB(11,18,36),    -- แถบเมนูซ้าย
	card   = Color3.fromRGB(18,28,54),    -- การ์ดคอนโทรล
	card2  = Color3.fromRGB(24,36,66),    -- การ์ดอ่อน
	cyan   = Color3.fromRGB(56,189,248),  -- ฟ้านีออน
	cyanD  = Color3.fromRGB(14,116,190),
	blue   = Color3.fromRGB(30,110,224),  -- น้ำเงินไฮไลต์
	txt    = Color3.fromRGB(230,238,250),
	sub    = Color3.fromRGB(126,140,168),
	off    = Color3.fromRGB(38,50,80),    -- สวิตช์ปิด
	line   = Color3.fromRGB(30,44,78),
}
local function round(p,r) local u=Instance.new("UICorner",p); u.CornerRadius=UDim.new(0,r or 8); return u end
local function stroke(p,col,th) local u=Instance.new("UIStroke",p); u.Color=col or C.line; u.Thickness=th or 1; u.Transparency=0; return u end
local function grad(p,a,b,rot) local g=Instance.new("UIGradient",p); g.Color=ColorSequence.new(a,b); g.Rotation=rot or 0; return g end

local sgui = Instance.new("ScreenGui")
sgui.Name="SailueatUI"; sgui.ResetOnSpawn=false; sgui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sgui.IgnoreGuiInset=true
sgui.DisplayOrder=50   -- เหนือชั้น ESP (SuiteDraw = 5) และ UI ของเกม
-- มือถือ/iOS (ไม่มีคีย์บอร์ด): CoreGui มักไม่แสดง → ใช้ PlayerGui | คอมใช้ CoreGui เหมือนเดิม
-- ตัวรันมือถือส่วนใหญ่มี gethui() (โฟลเดอร์ที่ GUI แสดงจริง) ใช้ก่อน | ไม่มีค่อยใช้ CoreGui (คอม) / PlayerGui (มือถือ)
pcall(function() local h = gethui and gethui() if h then sgui.Parent = h end end)   -- ห้ามประกาศ local ที่ระดับนี้: ฟังก์ชันหลักใกล้เพดาน 200 locals แล้ว
if not sgui.Parent and not (UIS.TouchEnabled and not UIS.KeyboardEnabled) then pcall(function() sgui.Parent=CoreGui end) end
if not sgui.Parent then sgui.Parent=lp:WaitForChild("PlayerGui") end
getgenv().SailueatUI = sgui

-- หน้าต่างหลัก
local win = Instance.new("Frame", sgui)
win.Size=UDim2.fromOffset(760,482); win.Position=UDim2.fromOffset(40,56)
win.BackgroundColor3=C.bg; win.BorderSizePixel=0; win.Active=true; round(win,14)
grad(win, Color3.fromRGB(11,20,44), Color3.fromRGB(5,9,22), 90)
-- ย่อหน้าต่างให้พอดีจอ: หน้าต่างกว้าง 760 จอมือถือไม่ถึง เลยโผล่แค่ครึ่งเดียวหรือหลุดขอบ (ปุ่มเปิด/ปิดอยู่ที่ FAB ☰ ท้ายไฟล์)
do
	local vp = cam.ViewportSize
	local k = math.min(1, (vp.X - 20) / 780, (vp.Y - 20) / 500)
	if k < 1 then
		Instance.new("UIScale", win).Scale = k
		win.Position = UDim2.fromOffset(10, 10)
	end
end
local winGlow=stroke(win,C.cyan,2); winGlow.Transparency=0.4   -- ขอบเรืองฟ้า
local winEdge=Instance.new("UIStroke",win); winEdge.Color=C.cyanD; winEdge.Thickness=1

-- แถบหัว
local header=Instance.new("Frame",win); header.Size=UDim2.new(1,0,0,58); header.BackgroundColor3=C.panel; header.BorderSizePixel=0; header.Active=true
round(header,12); grad(header, Color3.fromRGB(18,28,56), Color3.fromRGB(12,20,40), 0)
local hFix=Instance.new("Frame",header); hFix.Size=UDim2.new(1,0,0,14); hFix.Position=UDim2.new(0,0,1,-14); hFix.BackgroundColor3=C.panel; hFix.BorderSizePixel=0
local logo=Instance.new("TextLabel",header); logo.BackgroundColor3=C.cyan; logo.Size=UDim2.fromOffset(38,38); logo.Position=UDim2.fromOffset(16,10)
logo.Font=Enum.Font.GothamBlack; logo.TextSize=22; logo.TextColor3=C.bg; logo.Text="S"; round(logo,9); grad(logo,C.cyan,C.blue,90)
local logoStroke=stroke(logo,C.cyan,1)
local ttl=Instance.new("TextLabel",header); ttl.BackgroundTransparency=1; ttl.Position=UDim2.fromOffset(64,8); ttl.Size=UDim2.fromOffset(320,26)
ttl.Font=Enum.Font.GothamBlack; ttl.TextSize=20; ttl.TextColor3=C.txt; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text="Sailueat Suite"
local tag=Instance.new("TextLabel",header); tag.BackgroundTransparency=1; tag.Position=UDim2.fromOffset(64,34); tag.Size=UDim2.fromOffset(320,14)
tag.Font=Enum.Font.GothamBold; tag.TextSize=10; tag.TextColor3=C.cyan; tag.TextXAlignment=Enum.TextXAlignment.Left; tag.Text="ALL-IN-ONE  •  BOOST YOUR GAME"
local function hBtn(txt,xoff)
	local b=Instance.new("TextButton",header); b.Size=UDim2.fromOffset(34,30); b.Position=UDim2.new(1,xoff,0,14)
	b.BackgroundColor3=C.card2; b.BorderSizePixel=0; b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=16; b.TextColor3=C.txt; b.AutoButtonColor=true
	round(b,8); stroke(b,C.line,1); return b
end
local closeB=hBtn("✕",-44); local minB=hBtn("—",-84)
-- แบดจ์ Premium ทอง
local prem=Instance.new("Frame",header); prem.Size=UDim2.fromOffset(104,28); prem.Position=UDim2.new(1,-212,0,15)
prem.BackgroundColor3=Color3.fromRGB(58,44,10); prem.BorderSizePixel=0; round(prem,8); stroke(prem,Color3.fromRGB(214,170,60),1)
local crown=Instance.new("TextLabel",prem); crown.BackgroundTransparency=1; crown.Position=UDim2.fromOffset(8,0); crown.Size=UDim2.fromOffset(20,28); crown.Font=Enum.Font.GothamBold; crown.TextSize=14; crown.TextColor3=Color3.fromRGB(240,195,70); crown.Text="👑"
local premT=Instance.new("TextLabel",prem); premT.BackgroundTransparency=1; premT.Position=UDim2.fromOffset(30,0); premT.Size=UDim2.fromOffset(68,28); premT.Font=Enum.Font.GothamBold; premT.TextSize=13; premT.TextColor3=Color3.fromRGB(245,205,90); premT.TextXAlignment=Enum.TextXAlignment.Left; premT.Text="Premium"

-- แถบเมนูซ้าย
local side=Instance.new("ScrollingFrame",win); side.Position=UDim2.fromOffset(0,58); side.Size=UDim2.new(0,196,1,-58)
side.BackgroundColor3=C.side; side.BorderSizePixel=0; side.ScrollBarThickness=0; side.CanvasSize=UDim2.new(); side.AutomaticCanvasSize=Enum.AutomaticSize.Y
local sPad=Instance.new("UIPadding",side); sPad.PaddingTop=UDim.new(0,10); sPad.PaddingLeft=UDim.new(0,10); sPad.PaddingRight=UDim.new(0,10); sPad.PaddingBottom=UDim.new(0,10)
local sList=Instance.new("UIListLayout",side); sList.Padding=UDim.new(0,6); sList.SortOrder=Enum.SortOrder.LayoutOrder
local sideLine=Instance.new("Frame",win); sideLine.Position=UDim2.fromOffset(196,58); sideLine.Size=UDim2.new(0,1,1,-58); sideLine.BackgroundColor3=C.line; sideLine.BorderSizePixel=0
local sFoot=Instance.new("TextLabel",win); sFoot.BackgroundTransparency=1; sFoot.Position=UDim2.new(0,16,1,-24); sFoot.Size=UDim2.fromOffset(170,16)
sFoot.Font=Enum.Font.GothamBold; sFoot.TextSize=10; sFoot.TextColor3=C.sub; sFoot.TextXAlignment=Enum.TextXAlignment.Left; sFoot.Text="〓 MAKE IT EASIER"

-- ส่วนเนื้อหา (ขวา) — แบนเนอร์หัวข้อ + หน้า
local content=Instance.new("Frame",win); content.Position=UDim2.fromOffset(197,58); content.Size=UDim2.new(1,-197,1,-58); content.BackgroundTransparency=1
local banner=Instance.new("Frame",content); banner.Position=UDim2.fromOffset(16,14); banner.Size=UDim2.new(1,-32,0,76); banner.BackgroundColor3=C.card; banner.BorderSizePixel=0; round(banner,12); stroke(banner,C.cyanD,1)
grad(banner, Color3.fromRGB(22,50,104), Color3.fromRGB(13,24,54), 15)
local cTitleIcon=Instance.new("TextLabel",banner); cTitleIcon.BackgroundTransparency=1; cTitleIcon.Position=UDim2.fromOffset(16,14); cTitleIcon.Size=UDim2.fromOffset(46,46)
cTitleIcon.Font=Enum.Font.GothamBold; cTitleIcon.TextSize=30; cTitleIcon.TextColor3=C.cyan; cTitleIcon.Text=""
local cTitle=Instance.new("TextLabel",banner); cTitle.BackgroundTransparency=1; cTitle.Position=UDim2.fromOffset(72,14); cTitle.Size=UDim2.new(1,-240,0,28)
cTitle.Font=Enum.Font.GothamBlack; cTitle.TextSize=22; cTitle.TextColor3=C.txt; cTitle.TextXAlignment=Enum.TextXAlignment.Left; cTitle.Text=""
local cDesc=Instance.new("TextLabel",banner); cDesc.BackgroundTransparency=1; cDesc.Position=UDim2.fromOffset(72,44); cDesc.Size=UDim2.new(1,-240,0,20)
cDesc.Font=Enum.Font.GothamMedium; cDesc.TextSize=12; cDesc.TextColor3=C.sub; cDesc.TextXAlignment=Enum.TextXAlignment.Left; cDesc.Text=""
local cBrand=Instance.new("TextLabel",banner); cBrand.BackgroundTransparency=1; cBrand.Position=UDim2.new(1,-156,0,16); cBrand.Size=UDim2.fromOffset(142,16)
cBrand.Font=Enum.Font.GothamBold; cBrand.TextSize=12; cBrand.TextColor3=C.txt; cBrand.TextXAlignment=Enum.TextXAlignment.Right; cBrand.Text="Sailueat Suite"
local cBrand2=Instance.new("TextLabel",banner); cBrand2.BackgroundTransparency=1; cBrand2.Position=UDim2.new(1,-156,0,36); cBrand2.Size=UDim2.fromOffset(142,14)
cBrand2.Font=Enum.Font.GothamMedium; cBrand2.TextSize=10; cBrand2.TextColor3=C.cyan; cBrand2.TextXAlignment=Enum.TextXAlignment.Right; cBrand2.Text="Aim • Lock • Win"
local pageHost=Instance.new("Frame",content); pageHost.Position=UDim2.fromOffset(0,102); pageHost.Size=UDim2.new(1,0,1,-126); pageHost.BackgroundTransparency=1
local cFoot=Instance.new("TextLabel",content); cFoot.BackgroundTransparency=1; cFoot.Position=UDim2.new(1,-240,1,-20); cFoot.Size=UDim2.fromOffset(224,16)
cFoot.Font=Enum.Font.GothamBold; cFoot.TextSize=10; cFoot.TextColor3=C.cyan; cFoot.TextXAlignment=Enum.TextXAlignment.Right; cFoot.Text="PLAY SMART • STAY AHEAD"

-- ลากหน้าต่าง
do
	local dragging,startPos,startMouse
	header.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true; startPos=win.Position; startMouse=i.Position
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=i.Position-startMouse
			win.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X, startPos.Y.Scale,startPos.Y.Offset+d.Y)
		end
	end)
end
local collapsed=false
minB.MouseButton1Click:Connect(function()
	collapsed=not collapsed; side.Visible=not collapsed; content.Visible=not collapsed; sideLine.Visible=not collapsed
	win:TweenSize(UDim2.fromOffset(collapsed and 440 or 760, collapsed and 58 or 482), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
end)
closeB.MouseButton1Click:Connect(function() win.Visible=false end)

-- คำอธิบายใต้หัวข้อในแบนเนอร์ (คีย์ตามชื่อหัวข้อ)
local DESC = {
	["Aimbot"]="เล็งเป้าหมายอัตโนมัติ แม่นยำ รวดเร็ว",
	["ESP ผู้เล่น"]="มองทะลุเห็นผู้เล่นทั้งแมพ",
	["จุดสำคัญ"]="ชี้จุดขายยา / ร้านพเนจร",
	["ปืน"]="ปรับปืน ไม่สเปรด ไม่รีคอยล์",
	["ตัวละคร"]="สตามินา / ความเร็ว",
	["ออโต้ฟราม"]="ฟาร์มขยะ + ฟาร์มแคนดี้ + เลือก/ขายอัตโนมัติ",
	["กระเป๋า"]="หยิบปืนไว ของในกระเป๋ารอดตอนตาย",
	["อีเวนต์"]="นับถอยหลังอีเวนต์ในเกม",
	["FPS"]="โหมดกราฟิกต่ำ เพิ่มเฟรม",
}
local pages, items, selected = {}, {}, nil
local function selectPage(idx)
	selected=idx
	for i,pg in ipairs(pages) do pg.frame.Visible=(i==idx) end
	for i,it in ipairs(items) do it.setSel(i==idx) end
	cTitleIcon.Text=pages[idx].icon; cTitle.Text=pages[idx].name; cDesc.Text=DESC[pages[idx].name] or ""
end

local order=0
local function Section(label)
	order=order+1
	local icon, nm = label:match("^(%S+)%s+(.+)$")
	icon=icon or "●"; nm=nm or label
	local idx=order

	-- ปุ่มเมนูซ้าย
	local item=Instance.new("TextButton",side); item.Size=UDim2.new(1,0,0,42); item.BackgroundColor3=C.card; item.BackgroundTransparency=1
	item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.LayoutOrder=idx; round(item,9)
	local ig=grad(item,C.blue,C.cyan,0); ig.Enabled=false
	local accent=Instance.new("Frame",item); accent.Size=UDim2.fromOffset(3,22); accent.Position=UDim2.new(0,0,0.5,-11); accent.BackgroundColor3=C.cyan; accent.BorderSizePixel=0; accent.Visible=false; round(accent,2)
	local iic=Instance.new("TextLabel",item); iic.BackgroundTransparency=1; iic.Position=UDim2.fromOffset(12,0); iic.Size=UDim2.fromOffset(26,42); iic.Font=Enum.Font.GothamBold; iic.TextSize=16; iic.TextColor3=C.sub; iic.Text=icon
	local ilb=Instance.new("TextLabel",item); ilb.BackgroundTransparency=1; ilb.Position=UDim2.fromOffset(42,0); ilb.Size=UDim2.new(1,-62,1,0); ilb.Font=Enum.Font.GothamBold; ilb.TextSize=13; ilb.TextColor3=C.sub; ilb.TextXAlignment=Enum.TextXAlignment.Left; ilb.Text=nm
	local chev=Instance.new("TextLabel",item); chev.BackgroundTransparency=1; chev.Position=UDim2.new(1,-22,0,0); chev.Size=UDim2.fromOffset(16,42); chev.Font=Enum.Font.GothamBold; chev.TextSize=14; chev.TextColor3=C.txt; chev.Text="›"; chev.Visible=false
	local function setSel(on)
		item.BackgroundTransparency = on and 0 or 1; ig.Enabled=on; accent.Visible=on; chev.Visible=on
		iic.TextColor3 = on and C.txt or C.sub; ilb.TextColor3 = on and C.txt or C.sub; ilb.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
	end
	setSel(false)
	item.MouseEnter:Connect(function() if selected~=idx then item.BackgroundTransparency=0.85 item.BackgroundColor3=C.card2 end end)
	item.MouseLeave:Connect(function() if selected~=idx then item.BackgroundTransparency=1 end end)
	item.MouseButton1Click:Connect(function() selectPage(idx) end)
	items[idx]={ setSel=setSel }

	-- หน้าเนื้อหา
	local page=Instance.new("ScrollingFrame",pageHost); page.Size=UDim2.fromScale(1,1); page.BackgroundTransparency=1; page.BorderSizePixel=0
	page.ScrollBarThickness=4; page.ScrollBarImageColor3=C.cyanD; page.CanvasSize=UDim2.new(); page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.Visible=false
	local pPad=Instance.new("UIPadding",page); pPad.PaddingLeft=UDim.new(0,20); pPad.PaddingRight=UDim.new(0,20); pPad.PaddingTop=UDim.new(0,4); pPad.PaddingBottom=UDim.new(0,16)
	local pList=Instance.new("UIListLayout",page); pList.Padding=UDim.new(0,10); pList.SortOrder=Enum.SortOrder.LayoutOrder
	pages[idx]={ frame=page, icon=icon, name=nm }

	local api={}; local co=0
	local function card(h)
		co=co+1
		local c=Instance.new("Frame",page); c.BackgroundColor3=C.card; c.BorderSizePixel=0; c.Size=UDim2.new(1,0,0,h or 44); c.LayoutOrder=co; round(c,10); stroke(c,C.line,1); return c
	end
	function api.toggle(label,init,cb)
		local c=card(48)
		local t=Instance.new("TextLabel",c); t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(16,0); t.Size=UDim2.new(1,-80,1,0)
		t.Font=Enum.Font.GothamBold; t.TextSize=14; t.TextColor3=C.txt; t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.TextTruncate=Enum.TextTruncate.AtEnd
		local sw=Instance.new("TextButton",c); sw.Size=UDim2.fromOffset(46,24); sw.Position=UDim2.new(1,-62,0.5,-12); sw.BorderSizePixel=0; sw.Text=""; sw.AutoButtonColor=false; round(sw,12)
		local knob=Instance.new("Frame",sw); knob.Size=UDim2.fromOffset(18,18); knob.BorderSizePixel=0; round(knob,9); knob.BackgroundColor3=Color3.fromRGB(255,255,255)
		local swg=grad(sw,C.blue,C.cyan,0)
		local state=init and true or false
		local function paint()
			swg.Enabled=state; sw.BackgroundColor3=state and C.cyan or C.off
			knob.Position=state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
		end
		paint(); sw.MouseButton1Click:Connect(function() state=not state paint() cb(state) pcall(saveCfg) end)   -- บันทึกค่าทันทีที่กด (เดิมรอลูป 3 วิ ปิดเกมเร็วค่าหาย)
		return { set=function(v) state=v paint() end }
	end
	function api.slider(label,mn,mx,inc,init,cb)
		local c=card(60)
		local t=Instance.new("TextLabel",c); t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(16,8); t.Size=UDim2.new(1,-120,0,18)
		t.Font=Enum.Font.GothamBold; t.TextSize=14; t.TextColor3=C.txt; t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label
		local vb=Instance.new("Frame",c); vb.Size=UDim2.fromOffset(60,24); vb.Position=UDim2.new(1,-76,0,8); vb.BackgroundColor3=C.card2; vb.BorderSizePixel=0; round(vb,6); stroke(vb,C.line,1)
		local val=Instance.new("TextLabel",vb); val.BackgroundTransparency=1; val.Size=UDim2.fromScale(1,1); val.Font=Enum.Font.GothamBold; val.TextSize=13; val.TextColor3=C.cyan; val.Text=tostring(init)
		local track=Instance.new("Frame",c); track.Position=UDim2.fromOffset(16,40); track.Size=UDim2.new(1,-32,0,6); track.BackgroundColor3=C.off; track.BorderSizePixel=0; round(track,3)
		local fill=Instance.new("Frame",track); fill.BackgroundColor3=C.cyan; fill.BorderSizePixel=0; round(fill,3); grad(fill,C.blue,C.cyan,0)
		local knob=Instance.new("Frame",track); knob.Size=UDim2.fromOffset(14,14); knob.Position=UDim2.new(0,-7,0.5,-7); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.BorderSizePixel=0; round(knob,7); knob.ZIndex=3
		local cur=init
		local function paint() local a=math.clamp((cur-mn)/(mx-mn),0,1); fill.Size=UDim2.new(a,0,1,0); knob.Position=UDim2.new(a,-7,0.5,-7); val.Text=tostring(cur) end
		paint()
		local drag=false
		local function setFromX(px)
			local rel=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
			cur=math.floor((mn+rel*(mx-mn))/inc+0.5)*inc
			if inc<1 then cur=math.floor(cur*100+0.5)/100 end
			cur=math.clamp(cur,mn,mx); paint() cb(cur)
		end
		track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true setFromX(i.Position.X) end end)
		UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setFromX(i.Position.X) end end)
		UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if drag then drag=false pcall(saveCfg) end end end)
		return { set=function(v) cur=v paint() end }
	end
	function api.button(label,cb)
		local c=card(42); c.BackgroundTransparency=1
		local b=Instance.new("TextButton",c); b.Size=UDim2.fromScale(1,1); b.BackgroundColor3=C.cyan; b.BorderSizePixel=0; b.Text=label
		b.Font=Enum.Font.GothamBold; b.TextSize=14; b.TextColor3=C.bg; b.AutoButtonColor=true; round(b,10); grad(b,C.blue,C.cyan,0)
		b.MouseButton1Click:Connect(function() pcall(cb) end)
	end
	function api.label(txt)
		local c=card(24); c.BackgroundTransparency=1
		local t=Instance.new("TextLabel",c); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Position=UDim2.fromOffset(4,0)
		t.Font=Enum.Font.Gotham; t.TextSize=12; t.TextColor3=C.sub; t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=txt; t.TextWrapped=true
		return { set=function(v) t.Text=v end }
	end
	-- ดรอปดาวน์ (คลิกวนตัวเลือก)
	function api.dropdown(label,options,default,cb)
		local c=card(48)
		local t=Instance.new("TextLabel",c); t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(16,0); t.Size=UDim2.new(0,160,1,0)
		t.Font=Enum.Font.GothamBold; t.TextSize=14; t.TextColor3=C.txt; t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label
		local box=Instance.new("TextButton",c); box.Position=UDim2.new(0,180,0.5,-16); box.Size=UDim2.new(1,-196,0,32); box.BackgroundColor3=C.card2; box.BorderSizePixel=0; box.Text=""; box.AutoButtonColor=false; round(box,8); stroke(box,C.line,1)
		local vl=Instance.new("TextLabel",box); vl.BackgroundTransparency=1; vl.Position=UDim2.fromOffset(12,0); vl.Size=UDim2.new(1,-40,1,0); vl.Font=Enum.Font.GothamMedium; vl.TextSize=13; vl.TextColor3=C.txt; vl.TextXAlignment=Enum.TextXAlignment.Left; vl.Text=tostring(default)
		local arr=Instance.new("TextLabel",box); arr.BackgroundTransparency=1; arr.Position=UDim2.new(1,-26,0,0); arr.Size=UDim2.fromOffset(20,32); arr.Font=Enum.Font.GothamBold; arr.TextSize=14; arr.TextColor3=C.cyan; arr.Text="▾"
		local idx=1
		for i,o in ipairs(options) do if o==default then idx=i end end
		box.MouseButton1Click:Connect(function()
			idx=idx%(#options)+1; vl.Text=tostring(options[idx]); if cb then pcall(cb,options[idx]) end
		end)
		return { set=function(v) vl.Text=tostring(v) end }
	end
	function api.checklist(items2,isOn,onToggle)
		local paints={}
		for _,it in ipairs(items2) do
			local c=card(38)
			local box=Instance.new("TextButton",c); box.Size=UDim2.fromOffset(22,22); box.Position=UDim2.new(0,14,0.5,-11); box.BackgroundColor3=C.off; box.BorderSizePixel=0; box.Text=""; box.AutoButtonColor=false; round(box,6)
			local chk=Instance.new("TextLabel",box); chk.BackgroundTransparency=1; chk.Size=UDim2.fromScale(1,1); chk.Font=Enum.Font.GothamBold; chk.TextSize=15; chk.TextColor3=C.bg; chk.Text=""
			local nm2=Instance.new("TextButton",c); nm2.BackgroundTransparency=1; nm2.Position=UDim2.fromOffset(46,0); nm2.Size=UDim2.new(1,-130,1,0); nm2.Font=Enum.Font.GothamMedium; nm2.TextSize=13; nm2.TextColor3=C.txt; nm2.TextXAlignment=Enum.TextXAlignment.Left; nm2.Text=it.name; nm2.AutoButtonColor=false; nm2.TextTruncate=Enum.TextTruncate.AtEnd
			local pr=Instance.new("TextLabel",c); pr.BackgroundTransparency=1; pr.Position=UDim2.new(1,-84,0,0); pr.Size=UDim2.fromOffset(72,38); pr.Font=Enum.Font.GothamBold; pr.TextSize=12; pr.TextColor3=C.cyan; pr.TextXAlignment=Enum.TextXAlignment.Right; pr.Text="~"..it.price
			local function paint() local on=isOn(it.name); box.BackgroundColor3=on and C.cyan or C.off; chk.Text=on and "✓" or "" end
			local function tog() onToggle(it.name) paint() end
			paints[#paints+1]=paint
			paint(); box.MouseButton1Click:Connect(tog); nm2.MouseButton1Click:Connect(tog)
		end
		return function() for _,p in ipairs(paints) do p() end end
	end
	if idx==1 then selectPage(1) end
	return api
end


local sAim = Section("🎯 Aimbot", true)
sAim.toggle("SilentAim (หัวเท่านั้น)", S.AimOn, function(v) S.AimOn=v lockChar=nil end)
sAim.toggle("แสดงวง FOV", S.ShowFov, function(v) S.ShowFov=v end)
sAim.toggle("วง FOV ตามเมาส์ (ปิด = กลางจอ)", S.FovFollow, function(v) S.FovFollow=v lockChar=nil end)
sAim.toggle("ไม่ยิงเพื่อนทีม", S.TeamCheck, function(v) S.TeamCheck=v lockChar=nil end)
-- ซ่อนจากเมนู (ตามสั่ง): เล็ง NPC / Triggerbot รัวเป็นชุด / ปิดคลิกเอง — ตัวทำงานยังอยู่ครบ ค่าถูกตรึงไว้ที่หัวไฟล์ (บล็อก "ตรึงค่าที่ซ่อน")
sAim.toggle("Triggerbot (ยิงเองเมื่อล็อกเป้า)", S.Trigger, function(v) S.Trigger=v end)
sAim.toggle("กดเมาส์ซ้ายค้าง = ยิงรัวต่อเนื่อง", S.HoldSpray, function(v) S.HoldSpray=v end)
sAim.slider("กดค้างยิงรัวได้นานสุด (วินาที/ครั้ง)", 0.5, 5, 0.25, S.HoldMax, function(v) S.HoldMax=v end)
sAim.toggle("หมอบ (C) แล้วยังถือปืนได้", S.CrouchKeep, function(v) S.CrouchKeep=v end)
sAim.slider("คลิกสูงสุดต่อวินาที (กันโดนเตะ)", 3, 10, 1, S.MaxCPS, function(v) S.MaxCPS=v end)
sAim.slider("มุมเบี่ยงกระสุนสูงสุด (องศา) ยิ่งน้อยยิ่งเนียน", 1, 12, 1, S.AimAngle, function(v) S.AimAngle=v lockChar=nil end)
sAim.slider("ขนาดวง FOV", 40, 600, 10, S.FovPx, function(v) S.FovPx=v end)
-- ซ่อนจากเมนู: สไลเดอร์ "ล็อกค้างถึง" (ตรึง 200) และ dropdown "เป้าหมาย" (เล็งศีรษะอย่างเดียวอยู่แล้ว)
sAim.slider("ระยะล็อก", 50, 1500, 25, S.MaxDist, function(v) S.MaxDist=v end)

local sEsp = Section("👤 ESP ผู้เล่น")
sEsp.toggle("เปิด ESP", S.EspOn, function(v) S.EspOn=v end)
sEsp.toggle("รูปอาวุธใต้ตัวแต่ละคน", S.ItemPanel, function(v) S.ItemPanel=v end)
sEsp.toggle("ซ่อนไอเท็มของเพื่อนร่วมทีม", S.ItemHideTeam, function(v) S.ItemHideTeam=v end)
sEsp.slider("ระยะที่เห็นรูปอาวุธ", 50, 1000, 25, S.ItemDist, function(v) S.ItemDist=v end)
sEsp.toggle("แสดงกล่อง", S.EspBox, function(v) S.EspBox=v end)
sEsp.toggle("แสดงเพื่อนทีม (สีจาง)", S.EspTeam, function(v) S.EspTeam=v end)
-- ซ่อนจากเมนู: สวิตช์ "ตำรวจ ★ ผู้ต้องหา" (ตัวทำงานยังอยู่ ค่าตรึงที่หัวไฟล์)
sEsp.slider("ขนาดตัวอักษร", 11, 34, 1, S.EspTextSize, function(v) S.EspTextSize=v end)
sEsp.slider("ระยะ ESP", 100, 3000, 50, S.EspDist, function(v) S.EspDist=v end)
sEsp.slider("อัตราวาด (ต่ำ = fps สูง)", 10, 60, 5, S.EspHz, function(v) S.EspHz=v end)
-- จุดสำคัญ (ย้ายมารวมในแท็บ ESP ผู้เล่น: ใช้ sEsp เดียวกัน ไม่มีแท็บ "จุดสำคัญ" แยกแล้ว)
sEsp.toggle("ESP จุดขายยา (SELL DRUG / DEALER)", S.PointDrug, function(v) S.PointDrug=v end)
sEsp.toggle("ESP ร้านค้ามืด (BLACK MARKET)", S.PointShop, function(v) S.PointShop=v end)
sEsp.slider("ขนาดตัวอักษรจุดสำคัญ", 12, 36, 1, S.PointTextSize, function(v) S.PointTextSize=v end)
local pLabel = sEsp.label("จุดที่เจอ: ...")
sEsp.button("สแกนใหม่", function() pLabel.set("จุดที่เจอ: "..scanPoints()) end)
sEsp.label("อยู่นอกจอจะมีลูกศร < ที่ขอบจอ")

local sGun = Section("🔫 ปืน")
-- ซ่อนจากเมนู 4 อัน: กระสุนเกาะกลุ่ม / ไม่ร้อน / ไม่มีรีคอยล์ / ตัดเสียงรีโหลด (ตัวทำงานยังอยู่ ค่าตรึงที่หัวไฟล์)
-- โปรไฟล์ปืนที่ถืออยู่ (อัปเดตอัตโนมัติทุก 1 วิ) + ตั้งระยะยิงที่เชื่อถือได้เฉพาะปืนกระบอกนี้
local gunInfo = sGun.label("ปืนที่ถืออยู่: ...")
task.spawn(function()
	while live() do
		local n = ball.name or "-"
		local ov = S.GunRange and S.GunRange[n]
		pcall(function() gunInfo.set(string.format("ปืน: %s | กระสุน %s/วิ | ระยะ %s%s", n,
			ball.speed == math.huge and "ทันที" or tostring(math.floor(ball.speed)),
			ball.range and tostring(math.floor(ball.range)) or "ไม่ทราบ", (ov and ov > 0) and " (ตั้งเอง)" or "")) end)
		task.wait(1)
	end
end)
-- ซ่อนจากเมนู (ตัวทำงานยังอยู่ ค่าตรึงที่หัวไฟล์): ระยะเชื่อถือได้ของปืน (อัตโนมัติ) / ฟันมีดเร็วขึ้น + สไลเดอร์ % / ปรับความรัวอัตโนมัติ
-- ย้ายไปแท็บ 🏃 ตัวละคร: โยกตัวลวง / หลบกระสุน / ขยับตอนล้ม / หน่วงตัวละคร / ลดโยกตอนต่อย-ยิง (ดูท้าย sChar)
sGun.slider("ชดเชยดีเลย์เป้า (วิ) 0 = ปิด", 0, 0.2, 0.02, S.LatComp or 0, function(v) S.LatComp = v end)
sGun.slider("ความเร็วกระสุน × (1 = ปกติ, ทดสอบเป้านิ่งก่อน)", 1, 10, 1, math.clamp(S.BulletMul or 1, 1, 10), function(v)
	S.BulletMul = v
	if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end
end)
sGun.slider("เวลาโหลด", 0.2, 1, 0.05, math.max(S.ReloadMul, 0.2), function(v) S.ReloadMul=math.max(v, 0.2) end)
sGun.slider("เวลาชักปืน", 0.1, 1, 0.05, math.max(S.EquipMul, 0.1), function(v) S.EquipMul=math.max(v, 0.1) end)
-- ความรัวปืน: ระดับ 1-10 → FireMul 1.0..0.1 (ระดับ 1 = ปืนจริง, 10 = เร็วกว่าเดิม 10 เท่า ติดขีด FireFloor 0.03 วิ/นัด)
sGun.slider("ความรัวปืน (1 = ปกติ ... 10 = รัวสุดๆ)", 1, 10, 1, math.floor((1 - S.FireMul) / 0.1 + 0.5) + 1, function(v)
	S.FireMul = math.max(1 - (v - 1) * 0.1, 0.1)
	getgenv().SuiteMulNow = S.FireMul
	if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end   -- ใช้ค่าใหม่ทันที
end)
sGun.label("ระดับ 1-4 = เร็วกว่าปกติ ~1-1.4 เท่า ปลอดภัย ยิงนานแค่ไหนก็ได้")
sGun.label("ระดับ 5-7 = ~1.7-2.5 เท่า ทดสอบผ่าน 40-60 นัดหลายแม็กรีโหลดปกติ (แนะนำใช้ประจำ)")
sGun.label("ระดับ 8-10 = ~3-10 เท่า รัวได้ 1 แม็กผ่าน แต่ยิงติดกัน 3-4 แม็กตอนระดับ 10 โดนเตะ (Anti 46) ยิงแม็กเดียวแล้วพัก ~30 วิ")
sGun.label("เวลาชักปืน 0.1 ทดสอบผ่าน (ชัก-เก็บ 8 รอบ ไม่โดนเตะ) | เวลาโหลด ค่าพื้นฐาน 0.4: 0.2-0.8 ผ่านตอนยิงนัดเดียวแล้วโหลด แต่ยิงเต็มแม็กแล้วโหลดเร็วติดกันเคยโดนเตะ (Anti 49) ถ้าโดนเตะให้ปรับสไลเดอร์กลับไปที่ 1.0")

--========================= Triggerbot =========================
-- สองโหมดตามโอกาสโดน:
--   โอกาสสูง (เป้านิ่ง/วิ่งตรงสม่ำเสมอ เห็นหัวชัด ระยะที่ต้องนำเป้าคลาดไม่เกินครึ่งหัว) → ยิงรัวเป็นชุด สูงสุด BURST_SHOTS นัด หรือจนเป้าตาย แล้วพัก ~1 วิ
--   โอกาสต่ำ (ล็อกอยู่แต่เป้ากำลังขยับ) → ยิงทีละนัดช้า ๆ ไม่เกิน 5 นัด/3 วิ
-- ไม่ยิงตอนเรา/เป้าอยู่เซฟโซน หรือไกลเกิน TriggerDist | ชุดรัวใช้อัตรายิงปัจจุบันของปืน (ตัวคุมจังหวะด้านบนถอยเป็น x1.0 เองถ้ากดค้าง)
-- BURST_SHOTS 5 (เดิม 8): ชุดสั้นลงเพราะรอบทดสอบกดรัว 14 คลิก/วิ นาน 20 วิ โดนเตะ (น่าจะตรวจ "จำนวนคลิกต่อวินาที") | Triggerbot คลิกเท่าที่ยิง ~3-7 คลิก/วิ
local TRIG_MAX_ERR, BURST_SHOTS = 0.55, 15   -- ชุดละ 15 = 1 แม็ก Beretta (ทดสอบ 1 แม็กรัว ~9 นัด/วิ ผ่าน)
local lastVel, shots = {}, {}
local function trigFr(tool)
	local ok, cfg = pcall(require, tool.Setting)
	return (ok and type(cfg) == "table" and tonumber(cfg.FireRate)) or 0.25
end
-- โอกาสสูงไหม ณ ตอนนี้
local function trigHigh(ch, wp)
	if not wp then return false end
	local root = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
	local o = cam.CFrame.Position
	local vel = root and root.AssemblyLinearVelocity or Vector3.zero
	local prev = lastVel[ch] or vel
	lastVel[ch] = vel
	local dist = (wp - o).Magnitude
	local flight = ball.speed == math.huge and 0 or dist / ball.speed
	local d = (wp - o).Unit
	local lat = (vel - d * vel:Dot(d)).Magnitude
	return lat * flight <= TRIG_MAX_ERR and (vel - prev).Magnitude < 4 and hitsHead(ch.Head, ch.Head.Position)
end
-- กันกระสุน "หักเลี้ยวไปหาเป้า" มากเกิน (silent aim ที่ล็อกหลายคนสลับไปมาตอนกล้องไม่ขยับ = จับง่าย):
-- ยิงเฉพาะเป้าที่อยู่ในมุม TriggerAngle องศาจากทิศที่กล้องมองจริง และไม่สลับเป้ากะทันหัน (ต้องเว้น 1.2 วิ)
local lastT, lastTs = nil, 0
local function trigAimOk(ch)
	local d = ch.Head.Position - cam.CFrame.Position
	local look = cam.CFrame.LookVector
	if S.FovFollow then local m = UIS:GetMouseLocation() look = cam:ViewportPointToRay(m.X, m.Y).Direction end   -- ทิศที่เมาส์ชี้จริง
	local ang = math.deg(math.acos(math.clamp(look:Dot(d.Unit), -1, 1)))
	if ang > S.TriggerAngle then return false end
	local now = os.clock()
	if ch ~= lastT then
		if now - lastTs < 1.2 then return false end
		lastT = ch
	end
	lastTs = now
	return true
end
task.spawn(function()
	while live() do
		local ch = getgenv().SuiteLockChar
		local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
		if S.Trigger and ch and aliveC(ch) and tool and tool:FindFirstChild("GunScript_Local") and trigAimOk(ch)
			and not UIS:GetFocusedTextBox() and not ch:FindFirstChild("SafeZoneFF") and not lp.Character:FindFirstChild("SafeZoneFF")
			and (ch.Head.Position - cam.CFrame.Position).Magnitude <= math.min(S.TriggerDist, (ball.range or math.huge) * 0.95) then   -- ไม่ยิงเกินระยะของปืนที่ถืออยู่
			if S.TrigSpray or trigHigh(ch, getgenv().SuiteLockPos) then   -- TrigSpray: รัวเป็นชุดเสมอ ไม่รอเป้านิ่ง
				-- โอกาสสูง: ยิงรัวเป็นชุดจนตายหรือครบ
				for i = 1, BURST_SHOTS do
					if not (aliveC(ch) and getgenv().SuiteLockChar == ch and lp.Character:FindFirstChildOfClass("Tool") == tool) then break end
					getgenv().SuiteTrigClickAt = os.clock() pcall(mouse1click)
					log(string.format("TRIG burst %d/%d tool=%s target=%s dist=%d", i, BURST_SHOTS, tool.Name, ch.Name,
						math.floor((ch.Head.Position - cam.CFrame.Position).Magnitude)))
					task.wait(math.max(trigFr(tool), S.FireFloor) + math.random() * 0.03)
					if i < BURST_SHOTS and not S.TrigSpray and not trigHigh(ch, getgenv().SuiteLockPos) then break end   -- โอกาสตกกลางชุด หยุด
				end
				task.wait(0.45 + math.random() * 0.25)
			else
				-- โอกาสต่ำ: ทีละนัด ช้า ๆ
				local now = os.clock()
				for i = #shots, 1, -1 do if now - shots[i] > 3 then table.remove(shots, i) end end
				if #shots >= 7 then
					task.wait(0.3)
				else
					shots[#shots + 1] = now
					getgenv().SuiteTrigClickAt = os.clock() pcall(mouse1click)
					log(string.format("TRIG single tool=%s target=%s dist=%d", tool.Name, ch.Name,
						math.floor((ch.Head.Position - cam.CFrame.Position).Magnitude)))
					-- trigFr = อัตรายิง "ที่เร่งแล้ว" ต้องหารกลับเป็นของเดิมก่อน ไม่งั้นยิงเร็วกว่าปืนจริง (.38 เดิม 0.5 วิ เคยยิง 0.42)
					local orig = trigFr(tool) / math.max(getgenv().SuiteMulNow or S.FireMul, 0.01)
					task.wait(math.max(orig * 1.1, S.FireFloor) + math.random() * 0.06)
				end
			end
		else
			task.wait(0.03)
		end
	end
end)

--========================= กดเมาส์ซ้ายค้าง = ยิงรัว =========================
-- ไม่มีลูปคลิกเองแล้ว: HoldSpray สลับ cfg.Auto ของปืนใน tweakGun ให้ตัวปืนยิงออโต้เองตอนกดเมาส์จริงค้าง ปล่อยเมาส์ = หยุดทันที
-- จำกัดการกดค้างครั้งละไม่เกิน S.HoldMax วิ (ค่าเริ่มต้น 1.5): พ้นเวลาแล้วปิด Auto ของปืน ลูปยิงของเกมจบเองหลังนัดนั้น ต้องปล่อยแล้วกดใหม่ถึงรัวต่อ
-- ไม่มีการสั่งคลิกเอง ถ้าพลาด event ปล่อยก็แค่ Auto ปิดค้างจนกดครั้งต่อไป (ไม่มีทางยิงเองไม่หยุด)
do
	local deadline = nil
	UIS.InputBegan:Connect(function(i, gp)
		if live() and not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			deadline = os.clock() + S.HoldMax
			if getgenv().SuiteAutoOff then getgenv().SuiteAutoOff = false if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if live() and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			deadline = nil
			if getgenv().SuiteAutoOff then getgenv().SuiteAutoOff = false if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end end
		end
	end)
	task.spawn(function()
		while live() do
			if deadline and os.clock() >= deadline then
				deadline = nil
				getgenv().SuiteAutoOff = true
				if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end   -- ใช้ทันที ไม่รอรอบ 0.25 วิ
			end
			task.wait(0.03)
		end
	end)
end

--========================= ตัดยิงเมื่อเป้าตาย =========================
-- กดค้างรัวแล้วเป้าที่ล็อกตาย → ปิด Auto จนกว่าจะปล่อยเมาส์/กดใหม่ ไม่ยิงทิ้งใส่ศพ (รอบวัด 189 นัด: 39 นัดยิงทิ้ง) | ตัวปิด/เปิด Auto อยู่ที่ SuiteAutoOff (ดู tweakGun)
do
	local down, track = false, nil
	UIS.InputBegan:Connect(function(i, gp) if live() and not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then down, track = true, nil end end)
	UIS.InputEnded:Connect(function(i) if live() and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then down, track = false, nil end end)
	local function dead(ch) local h = ch and ch:FindFirstChildOfClass("Humanoid") return not h or h.Health <= 0 end
	task.spawn(function()
		while live() do
			local lc = getgenv().SuiteLockChar
			if lc then track = lc end
			if down and track and dead(track) then
				track = nil
				getgenv().SuiteAutoOff = true
				if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end
			end
			task.wait(0.03)
		end
	end)
end

--========================= สถิติความแม่น (เทียบรอบได้) =========================
-- นับจากกระสุนในแม็กที่ลดจริง (รวมนัดจากกดค้างรัว) ทุกนัดที่มีเป้าล็อก: จดระยะ/เป้าวิ่ง/ระยะที่จุดเล็งห่างหัว (up = ชดเชยกระสุนตก, side = นำเป้า)
-- เข้า = เลือดเป้าลดเกิน 2 ภายใน 1.2 วิ (เลือดลด 1 ครั้ง = เข้า 1 นัด) | พลาด = ไม่ลด | ยิงใส่เป้าที่ตายแล้ว = wasted (ไม่นับพลาด)
-- เขียนลง SailueatSuite/aim_stats.txt ทุกรอบรัน รอบก่อนหน้าถูกเก็บเป็น aim_stats_prev.txt
do
	local FILE = "SailueatSuite/aim_stats.txt"
	pcall(function() if isfile and isfile(FILE) then writefile("SailueatSuite/aim_stats_prev.txt", readfile(FILE)) end end)
	local st = { round = os.date("%H:%M:%S"), shots = 0, locked = 0, hits = 0, wasted = 0, bins = {}, rows = {} }
	local function bin(d) return d < 50 and "0-50" or d < 100 and "50-100" or d < 200 and "100-200" or "200+" end
	local function B(k)
		local b = st.bins[k]
		if not b then b = { sh = 0, hit = 0, mov = 0, movHit = 0, up = 0, side = 0 } st.bins[k] = b end
		return b
	end
	local function save()
		local judged = st.locked - st.wasted
		local L = { string.format("ROUND %s | shots=%d locked=%d hits=%d wasted=%d hitRate=%.0f%%", st.round, st.shots, st.locked, st.hits, st.wasted, judged > 0 and st.hits / judged * 100 or 0) }
		for _, k in ipairs({ "0-50", "50-100", "100-200", "200+" }) do
			local b = st.bins[k]
			if b then L[#L + 1] = string.format("  %-8s locked=%d hit=%d (%.0f%%) | moving %d/%d | avg aim offset up=%.1f side=%.1f studs", k, b.sh, b.hit, b.sh > 0 and b.hit / b.sh * 100 or 0, b.movHit, b.mov, b.up / math.max(b.sh, 1), b.side / math.max(b.sh, 1)) end
		end
		L[#L + 1] = "--- last shots"
		for i = math.max(1, #st.rows - 80), #st.rows do L[#L + 1] = st.rows[i] end
		if makefolder and isfolder and not isfolder("SailueatSuite") then pcall(makefolder, "SailueatSuite") end
		pcall(writefile, FILE, table.concat(L, "\n"))
	end
	-- ตัวคุมความรัวอัตโนมัติ (AIMD แบบ TCP): ข้อมูลจริง FireMul 0.30 → โดน 2–3 นัดแรกแล้วพลาดหมดทั้งที่เล็งตรง (err<1 stud) = เซิร์ฟทิ้งนัดที่ถี่เกิน | 0.8–1.0 โดนต่อเนื่อง
-- นัดที่ "เล็งตรงแต่พลาด" (ระยะ ≤180m ที่โมเดลเล็งผ่านการตรวจแล้ว) = สัญญาณถูกทิ้ง → ถอยช้าลง +0.15 ทันที (สูงสุด 1.0) | โดนติด 3 นัดที่เล็งตรง → เร่งขึ้น −0.05 ไม่เกินค่าที่ตั้งไว้ (S.FireMul)
-- เริ่มที่ 0.8 (ค่าที่ทดสอบแล้วนับครบ) | พลาดเพราะเป้าโยก/ไกล (เล็งไม่ตรง) ไม่นับ จะได้ไม่ถอยโดยไม่จำเป็น
local gov = { mul = nil, streak = 0 }
local function govUpdate(p, hit)
	if not S.AutoRate then return end
	if not hit and (p.d > 180 or not p.clean) then return end   -- โดน = เซิร์ฟรับที่ความรัวนี้ (นับเสมอ) | พลาดนับเป็นสัญญาณถูกทิ้งเฉพาะเล็งตรงจริง ๆ
	local cap = S.FireMul
	gov.mul = math.max(cap, gov.mul or math.max(cap, 0.8))
	if hit then
		gov.streak += 1
		if gov.streak >= 3 then gov.streak, gov.mul = 0, math.max(cap, gov.mul - 0.05) end
	else
		gov.streak, gov.mul = 0, math.min(1, gov.mul + 0.15)
	end
	if getgenv().SuiteMulNow ~= gov.mul then
		getgenv().SuiteMulNow = gov.mul
		log(string.format("autorate mul=%.2f (%s)", gov.mul, hit and "hit" or "clean-miss"))
		if getgenv().SuiteSweep then pcall(getgenv().SuiteSweep) end
	end
end
local lastMag, pend, dirty, lastSave = nil, {}, true, 0
	getgenv().SuiteStatsConn = RS.Heartbeat:Connect(function()
		if not live() then pcall(function() getgenv().SuiteStatsConn:Disconnect() end) return end
		local gui = lp.PlayerGui:FindFirstChild("GunGUI")
		local fr = gui and gui:FindFirstChild("Frame")
		local mg = fr and fr:FindFirstChild("Mag")
		local m = mg and tonumber(mg.Current.Text)
		if not m then lastMag = nil
		else
			if lastMag and m < lastMag then
				local ch = getgenv().SuiteLockChar
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
				local head = ch and ch:FindFirstChild("Head")
				local wp = getgenv().SuiteLockPos
				for _ = 1, lastMag - m do
					st.shots += 1
					if hum and root and head and hum.Health > 0 then
						local d = (root.Position - cam.CFrame.Position).Magnitude
						local mv = root.AssemblyLinearVelocity.Magnitude > 3
						local off = wp and (wp - head.Position) or Vector3.zero
						local up, side = off.Y, Vector3.new(off.X, 0, off.Z).Magnitude
						local tk = trk[ch]
						pend[#pend + 1] = { t = os.clock(), hum = hum, hp = hum.Health, d = d, mv = mv, name = ch.Name, up = up, side = side,
							head = head, H0 = head.Position, wp = wp, org = cam.CFrame.Position, ac = ball.accel,
							tt = ball.speed ~= math.huge and (head.Position - cam.CFrame.Position).Magnitude / ball.speed or 0,
							v = tk and Vector3.new(tk.v.X, 0, tk.v.Z).Magnitude or 0, sf = tk ~= nil and #tk.rev >= 2 }
						st.locked += 1
						local b = B(bin(d))
						b.sh += 1 b.up += up b.side += side
						if mv then b.mov += 1 end
					end
				end
				dirty = true
			end
			lastMag = m
		end
		for _, p in ipairs(pend) do
			if not p.done then
				local h = p.hum
				if not p.H1 and os.clock() - p.t >= p.tt and p.head.Parent then p.H1 = p.head.Position end   -- ตำแหน่งหัว ณ เวลากระสุนถึง
				local tag = string.format("%.0fm %s off up=%.1f side=%.1f", p.d, p.mv and "moving" or "still", p.up, p.side)
				-- err = จุดเล็งตอนยิง − หัวจริงตอนกระสุนถึง (side + = ขวาของแนวเล็ง) | moved = เป้าขยับระหว่างบิน | v = ความเร็วแนวราบที่วัด
				do
					local H1 = p.H1 or (p.head.Parent and p.head.Position)
					if H1 and p.wp then
						local fwd = H1 - p.org
						fwd = fwd.Magnitude > 0 and fwd.Unit or Vector3.zAxis
						local rt = fwd:Cross(Vector3.yAxis)
						rt = rt.Magnitude > 0 and rt.Unit or Vector3.xAxis
						local e = p.wp + p.ac * 0.5 * p.tt * p.tt - H1   -- บวกแรงตก: กระสุนจะตกจากจุดเล็งตามนี้ (เล็งสูงชดเชยอยู่แล้ว ไม่ใช่ความคลาด)
						p.clean = math.abs(e:Dot(rt)) < 0.5 and math.abs(e.Y) < 0.5 and p.v < 6   -- เล็งกลางหัว ณ เวลากระสุนถึง (แรงตกหักแล้ว) + เป้าไม่วิ่งเร็ว | รอบ 00:17: err 0.5–0.8 ที่พลาดคือขอบหัว ไม่ใช่โดนทิ้ง
						tag = tag .. string.format(" | v=%.1f%s tt=%.2fs moved=%.1f err side=%+.1f up=%+.1f", p.v, p.sf and " STRAFE" or "", p.tt, (H1 - p.H0).Magnitude, e:Dot(rt), e.Y)
					end
				end
				if h.Health < p.hp - 2 then
					p.done = true
					st.hits += 1 govUpdate(p, true)
					local b = B(bin(p.d))
					b.hit += 1
					if p.mv then b.movHit += 1 end
					st.rows[#st.rows + 1] = string.format("%s HIT  %s %s hp %d->%d", os.date("%H:%M:%S"), p.name, tag, p.hp, h.Health)
					for _, q in ipairs(pend) do if not q.done and q.hum == h then q.hp = h.Health end end   -- นัดอื่นของเป้านี้ใช้เลือดใหม่เป็นฐาน
					dirty = true
				elseif h.Health <= 0 then
					p.done = true
					st.wasted += 1
					dirty = true
				elseif os.clock() - p.t > 1.2 then
					p.done = true
					govUpdate(p, false)
					st.rows[#st.rows + 1] = string.format("%s miss %s %s", os.date("%H:%M:%S"), p.name, tag)
					dirty = true
				end
			end
		end
		for i = #pend, 1, -1 do if pend[i].done then table.remove(pend, i) end end
		if dirty and os.clock() - lastSave > 0.5 then dirty, lastSave = false, os.clock() save() end
	end)
end

--========================= หมอบ (C) ถือปืนได้ =========================
-- สคริปต์ Crouching ของเกม (ฝั่งเรา) ตอนหมอบตั้งตัวแปร u12 = true แล้วถอดของทุกชิ้น + ถอดซ้ำทุกครั้งที่มีของเข้ามือ (ChildAdded → รอ 0.1 วิ → UnequipTools)
-- แก้: บังคับ upvalue u12 = false ในตัวจับ ChildAdded ของมัน (ทั้ง Backpack และ Character) + กด C แล้วถือของชิ้นเดิมกลับให้หลัง 0.4 วิ (หลังถอดรอบ 0.1 วิ ของเกมผ่านไปแล้ว)
-- ฝั่งเซิร์ฟเวอร์จะอนุญาตให้ยิงตอนหมอบไหมยังไม่ยืนยัน (ทดสอบแค่ว่าถือได้) | ตัวสคริปต์เกมสร้างใหม่ทุกครั้งที่เกิดใหม่ จึงหาใหม่ทุกรอบ 0.1 วิ
do
	local SG = game:GetService("StarterGui")
	local function freeU12(char)
		local sc = char and char:FindFirstChild("Crouching")
		if not (sc and getconnections and debug.setupvalue) then return end
		for _, sig in ipairs({ lp.Backpack.ChildAdded, char.ChildAdded }) do
			for _, c in ipairs(getconnections(sig)) do
				local f = c.Function
				local ok, env = pcall(getfenv, f)
				if ok and env.script == sc then pcall(debug.setupvalue, f, 1, false) end   -- upvalue 1 = u12
			end
		end
	end
	task.spawn(function()
		while live() do
			if S.CrouchKeep then freeU12(lp.Character) end
			task.wait(0.1)
		end
	end)
	local conn = UIS.InputBegan:Connect(function(i, gp)
		if not live() or gp or i.KeyCode ~= Enum.KeyCode.C or not S.CrouchKeep or UIS:GetFocusedTextBox() then return end
		local ch = lp.Character
		local tool = ch and ch:FindFirstChildOfClass("Tool")
		if not tool then return end
		task.wait(0.4)
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and tool.Parent == lp.Backpack and not ch:FindFirstChildOfClass("Tool") then
			freeU12(ch)
			pcall(function() SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
			hum:EquipTool(tool)
		end
	end)
	getgenv().SuiteCrouchConn = conn
end

--========================= กล่องอาวุธใต้ตัวแต่ละคน =========================
-- ช่องสี่เหลี่ยมเล็ก ๆ ใต้ ESP ของแต่ละคน โชว์ "รูปอาวุธ" (ปืน/มีด) ที่ถือและพก ของอื่น (กระสุน/ขยะ/ผลไม้) ไม่โชว์
-- เห็นเฉพาะคนในระยะ ItemDist | ช่องสีเหลือง = กำลังถืออยู่ | อาวุธไม่มีรูปในเกมจะโชว์เป็นชื่อแทน
local ItemDist = 350
pcall(function() if getgenv().SuiteItemConn then getgenv().SuiteItemConn:Disconnect() end end)
local oldItems = CoreGui:FindFirstChild("SuiteItems") or (lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("SuiteItems"))
if oldItems then pcall(function() oldItems:Destroy() end) end
local itemGui = Instance.new("ScreenGui")
itemGui.Name, itemGui.ResetOnSpawn, itemGui.DisplayOrder, itemGui.IgnoreGuiInset = "SuiteItems", false, 50, true
pcall(function() local h = gethui and gethui() if h then itemGui.Parent = h end end)
if not itemGui.Parent and not (UIS.TouchEnabled and not UIS.KeyboardEnabled) then pcall(function() itemGui.Parent = CoreGui end) end
if not itemGui.Parent then itemGui.Parent = lp.PlayerGui end

local function isWeapon(t)
	return t:IsA("Tool") and (t:FindFirstChild("GunScript_Local") or t:FindFirstChild("Setting")
		or t:FindFirstChild("FEMeleeKitEvents") or t:FindFirstChild("MainModule")) ~= nil
end
local boxes = {}
local function mkBox(pl)
	local f = Instance.new("Frame", itemGui)
	f.AutomaticSize, f.Size, f.AnchorPoint = Enum.AutomaticSize.XY, UDim2.fromOffset(0, 0), Vector2.new(0.5, 0)
	f.BackgroundTransparency, f.Visible = 1, false
	local lay = Instance.new("UIListLayout", f)
	lay.FillDirection, lay.Padding, lay.HorizontalAlignment = Enum.FillDirection.Horizontal, UDim.new(0, 4), Enum.HorizontalAlignment.Center
	boxes[pl] = { f = f, sig = "", t = 0 }
	return boxes[pl]
end
local function mkTile(parent, tool, held)
	local tile = Instance.new("Frame", parent)
	-- พื้นสว่าง (เทาอ่อน) ให้ไอคอนปืนสีเข้มเด่น พื้นเข้มเดิมกลืนกับสีปืนจนมองไม่ออก
	tile.Size, tile.BackgroundColor3, tile.BackgroundTransparency, tile.BorderSizePixel = UDim2.fromOffset(46, 46), Color3.fromRGB(226, 231, 242), 0.04, 0
	Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 6)
	local st = Instance.new("UIStroke", tile)
	st.Thickness, st.Color, st.Transparency = held and 3 or 1.5, held and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(70, 80, 105), held and 0 or 0.2
	if tool.TextureId ~= "" then
		local im = Instance.new("ImageLabel", tile)
		im.BackgroundTransparency, im.Size, im.Position = 1, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4)
		im.ScaleType, im.Image = Enum.ScaleType.Fit, tool.TextureId
	else
		local tx = Instance.new("TextLabel", tile)
		tx.BackgroundTransparency, tx.Size, tx.Position = 1, UDim2.new(1, -4, 1, -4), UDim2.fromOffset(2, 2)
		tx.Font, tx.TextSize, tx.TextWrapped, tx.TextColor3, tx.Text = Enum.Font.SourceSansBold, 12, true, Color3.fromRGB(20, 26, 42), tool.Name
	end
end
local function refresh(pl, b)
	local list, held = {}, pl.Character and pl.Character:FindFirstChildOfClass("Tool")
	if held and isWeapon(held) then list[1] = held end
	local bp = pl:FindFirstChild("Backpack")
	if bp then for _, t in ipairs(bp:GetChildren()) do if isWeapon(t) and #list < 5 then list[#list + 1] = t end end end
	local sig = {}
	for i, t in ipairs(list) do sig[i] = t.Name .. t.TextureId end
	sig = table.concat(sig, "|")
	if sig == b.sig then return end   -- ไม่เปลี่ยน ไม่สร้างช่องใหม่
	b.sig = sig
	for _, c in ipairs(b.f:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for _, t in ipairs(list) do mkTile(b.f, t, t == held) end
	b.n = #list
end
-- Last (หลังกล้องอัปเดต) ไม่ใช่ RenderStepped (ก่อนกล้อง): RenderStepped ใช้พิกัดกล้องของเฟรมที่แล้ว แผงของเลยว่ายตามหลังตัวคนตอนหันจอ
pcall(function() RS:UnbindFromRenderStep("SuiteItemLoop") end)
RS:BindToRenderStep("SuiteItemLoop", Enum.RenderPriority.Last.Value, function()
	if not live() then
		pcall(function() RS:UnbindFromRenderStep("SuiteItemLoop") end)
		itemGui:Destroy()
		return
	end
	local o, now = cam.CFrame.Position, os.clock()
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= lp then
			local ch = pl.Character
			local head = ch and ch:FindFirstChild("Head")
			local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
			local b = boxes[pl]
			local show = false
			local mate = pl.Team ~= nil and pl.Team == lp.Team
			if S.ItemPanel and not (S.ItemHideTeam and mate) and head and root and aliveC(ch) and (root.Position - o).Magnitude <= S.ItemDist then
				local bot, vis = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
				if vis then
					b = b or mkBox(pl)
					if now - b.t > 0.25 then b.t = now pcall(refresh, pl, b) end
					b.f.Position = UDim2.fromOffset(bot.X, bot.Y + 24)   -- ใต้ข้อความระยะ/เลือดของ ESP
					show = (b.n or 0) > 0
				end
			end
			if b then b.f.Visible = show end
		end
	end
end)
Players.PlayerRemoving:Connect(function(pl)
	local b = boxes[pl]
	if b then b.f:Destroy() boxes[pl] = nil end
end)

--========================= เปลี่ยนชื่อ (เห็นแค่จอเรา) =========================
-- แก้ข้อความบนเครื่องเราเท่านั้น (ป้ายชื่อเหนือหัว + ลีดเดอร์บอร์ด) คนอื่นเห็นชื่อจริงเหมือนเดิม เกมเขียนทับก็แก้ซ้ำทุก 0.5 วิ
local FAKE_NAME = "DEKTHAI"
task.spawn(function()
	while live() do
		pcall(function()
			local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			if h then h.DisplayName = FAKE_NAME end
			for _, r in ipairs({ lp.Character and lp.Character:FindFirstChild("Head"), lp.PlayerGui:FindFirstChild("LeaderboardUI") }) do
				for _, d in ipairs(r:GetDescendants()) do
					if d:IsA("TextLabel") and d.Text:find(lp.Name, 1, true) then d.Text = d.Text:gsub(lp.Name, FAKE_NAME) end
				end
			end
		end)
		task.wait(0.5)
	end
end)

--========================= ถอดจิต (ฟรีแคม) =========================
-- กล้องหลุดออกจากตัว บินไปมองที่ไหนก็ได้ ตัวจริงยืนอยู่ที่เดิม กระสุนยังออกจากปืนของตัวจริง
-- ไปยังจุดที่ crosshair ของ "กล้อง" ชี้ (เกมคำนวณทิศจากเรย์กล้อง) กำแพงที่ขวางระหว่างปืนกับจุดนั้นยังบังอยู่
-- ฝั่งเดียวกับกล้องคือ client ล้วน เซิร์ฟเวอร์ไม่เห็น | SilentAim ทำงานต่อตอนถอดจิต (คำนวณจากตำแหน่งกล้อง)
local K = Enum.KeyCode
local CAS = game:GetService("ContextActionService")
local function setFree(on)
	if on == (getgenv().SuiteFree == true) then return end
	getgenv().SuiteFree = on
	log("freecam " .. tostring(on))
	if on then
		local pitch, yaw = cam.CFrame:ToOrientation()
		cam.CameraType = Enum.CameraType.Scriptable
		-- กินปุ่มเดิน/กระโดดไว้ ตัวจริงจะได้ยืนนิ่ง (UIS:IsKeyDown ยังอ่านปุ่มได้ ใช้บินกล้อง)
		CAS:BindActionAtPriority("SuiteFreeSink", function() return Enum.ContextActionResult.Sink end, false, 9000,
			K.W, K.A, K.S, K.D, K.Space, K.Up, K.Down, K.Left, K.Right)
		RS:BindToRenderStep("SuiteFreecam", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if UIS:GetFocusedTextBox() then return end
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
			local d = UIS:GetMouseDelta()
			pitch = math.clamp(pitch - d.Y * 0.003, -1.5, 1.5)
			yaw = yaw - d.X * 0.003
			local rot = CFrame.fromOrientation(pitch, yaw, 0)
			local mv = Vector3.new((UIS:IsKeyDown(K.D) and 1 or 0) - (UIS:IsKeyDown(K.A) and 1 or 0),
				(UIS:IsKeyDown(K.E) and 1 or 0) - (UIS:IsKeyDown(K.Q) and 1 or 0),
				(UIS:IsKeyDown(K.S) and 1 or 0) - (UIS:IsKeyDown(K.W) and 1 or 0))
			local spd = UIS:IsKeyDown(K.LeftShift) and 90 or 35
			cam.CFrame = CFrame.new(cam.CFrame.Position + rot:VectorToWorldSpace(mv) * spd * dt) * rot
		end)
	else
		pcall(function() RS:UnbindFromRenderStep("SuiteFreecam") end)
		pcall(function() CAS:UnbindAction("SuiteFreeSink") end)
		cam.CameraType = Enum.CameraType.Custom
		local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if h then cam.CameraSubject = h end
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end
-- กระสุนเกิดที่ GunFirePoint ของปืนตัวจริง เกมคำนวณแค่ "จุดที่เล็ง" จากกล้อง
-- ระหว่างถอดจิตเลยย้าย GunFirePoint (ฝั่งเครื่องเราเท่านั้น) ไปไว้ที่กล้อง กระสุนจึงออกจากจุดที่ถอดไป แล้วคืนที่เดิมตอนกลับ
getgenv().SuiteFPOrig = getgenv().SuiteFPOrig or setmetatable({}, { __mode = "k" })
pcall(function() RS:UnbindFromRenderStep("SuiteFreeFire") end)
RS:BindToRenderStep("SuiteFreeFire", Enum.RenderPriority.Last.Value, function()
	local fpOrig = getgenv().SuiteFPOrig
	local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
	local a = tool and tool:FindFirstChild("GunFirePoint", true)
	if not a then return end
	if getgenv().SuiteFree then
		fpOrig[a] = fpOrig[a] or a.CFrame
		a.WorldCFrame = cam.CFrame
	elseif fpOrig[a] then
		a.CFrame = fpOrig[a] fpOrig[a] = nil
	end
end)
getgenv().SuiteFree = nil
pcall(function() RS:UnbindFromRenderStep("SuiteFreecam") end)

local sChar = Section("🏃 ตัวละคร")
local freeTog = sChar.toggle("👻 ถอดจิต (ฟรีแคม) WASD+QE บิน | Shift เร็ว | ปุ่ม G", false, setFree)
sChar.toggle("Stamina ไม่จำกัด", S.StaminaOn, function(v) S.StaminaOn=v end)
sChar.toggle("เปิดเมนูไว (ไม่ต้องกด E ค้าง)", S.InstantPrompt, function(v) S.InstantPrompt=v getgenv().SuiteFastAll() end)
sChar.toggle("⚠ Noclip (เสี่ยงโดนเตะ เปิดเฉพาะจำเป็น)", S.Noclip, setNoclip)
-- ความเร็วปกติของเกม = 8 | SpeedBonus=7 (=15) ตอนโดนเตะ Anti System 25 (ยังไม่ยืนยัน 100%) จึงจำกัดสไลเดอร์ไว้ที่ SpeedMax
sChar.slider("ความเร็วบวกเพิ่ม (รวมไม่เกิน " .. SpeedCap .. " | เดิน 8, วิ่ง 18)", 0, SpeedMax, 1, math.min(S.SpeedBonus, SpeedMax), function(v)
	S.SpeedBonus=v if getgenv().SuiteSetSpeed then getgenv().SuiteSetSpeed() end
end)
-- ย้ายมาจากแท็บปืน: ฟังก์ชันที่ขยับ/หน่วงตำแหน่งตัวละครที่ส่งออก
sChar.toggle("โยกตัวลวงคนยิง (เปิดตลอด ไม่พัก) ⚠ เสี่ยงโดนเตะ", S.Jitter, function(v) S.Jitter = v log("jitter " .. tostring(v) .. " amp=" .. tostring(S.JitterAmp)) end)
sChar.slider("แรงโยกตอนยืน (studs) 3 = ค่าเริ่ม, 15 = สุด", 0.5, 15, 0.5, S.JitterAmp or 2, function(v) S.JitterAmp = v end)
sChar.slider("แรงโยกตอนเดิน (studs) ลดถ้าโดนดึงกลับ", 0, 3, 0.25, S.JitterWalk or 0.7, function(v) S.JitterWalk = v end)
sChar.toggle("หลบกระสุนที่เล็งมา (เปิดพร้อมโยกได้) ⚠ เสี่ยงโดนเตะ", S.Dodge, function(v) S.Dodge = v log("dodge " .. tostring(v) .. " amp=" .. tostring(S.DodgeAmp)) end)
sChar.slider("ระยะหลบ (studs) 8 = ค่าเริ่ม, 20 = สุด", 1, 20, 1, S.DodgeAmp or 8, function(v) S.DodgeAmp = v end)
sChar.toggle("ขยับหลบตอนล้มรอตาย (แบบแลคกระตุก วาร์ปสั้น ๆ) ⚠ เสี่ยงโดนเตะ", S.DownedDodge ~= false, function(v) S.DownedDodge = v end)
-- ลบออก: ท่าแลคกระตุกตอนปกติ (สวิตช์ + สไลเดอร์ระยะ) — ตรึง LagStyle = ปิดที่หัวไฟล์
sChar.slider("ระยะขยับตอนล้ม (studs) 1.2 = ค่าเริ่ม", 0.5, 6, 0.25, S.DownedAmp or 1.2, function(v) S.DownedAmp = v end)
sChar.slider("ระยะหลบตอนเดิน (studs) ลดถ้าโดนดึงกลับ", 0, 20, 1, S.DodgeWalk or 4, function(v) S.DodgeWalk = v end)
sChar.slider("หลบเมื่อกระสุนผ่านใกล้กว่า (studs)", 1, 15, 0.5, S.DodgeRadius or 6, function(v) S.DodgeRadius = v end)
sChar.toggle("หน่วงตัวละคร (คนอื่นเห็นเราช้ากว่าจริง) ⚠ เสี่ยงโดนเตะ", S.Lag, function(v) S.Lag = v log("lag " .. tostring(v) .. " t=" .. tostring(S.LagTime)) end)
sChar.slider("หน่วงกี่วิ (0.15 = ค่าเริ่ม, สูงสุด 1.2)", 0.05, 1.2, 0.05, S.LagTime or 0.15, function(v) S.LagTime = v end)
sChar.toggle("ลดโยก + ปิดหลบ/หน่วง ชั่วคราวตอนต่อย-ยิง (ให้ตีโดน)", S.AtkSuspend ~= false, function(v) S.AtkSuspend = v end)
sChar.slider("ช่วงลดโยกหลังคลิก (วิ)", 0.1, 1, 0.05, S.AtkWin or 0.35, function(v) S.AtkWin = v end)
sChar.slider("แรงโยกตอนตี/ยิง (studs) 0 = นิ่งเลย", 0, 3, 0.25, S.AtkJitter or 1.2, function(v) S.AtkJitter = v end)

-- แท็บ 🎒 กระเป๋า ถูกลบตามสั่ง (คีย์ B และปุ่ม 🎒 บนมือถือยังเปิดกระเป๋าได้ตามปกติ)

local sAuto = Section("🌾 ออโต้ฟราม")
local function setAutoTrash(v)
	if v and getgenv().AutoCandy then   -- ฟาร์มสองอย่างพร้อมกันไม่ได้ ปิดอีกอันให้
		S.AutoCandy, getgenv().AutoCandy = false, false
		if getgenv().SuiteCandyTog then getgenv().SuiteCandyTog.set(false) end
	end
	S.AutoTrash=v getgenv().AutoTrash=v if v then task.spawn(trashLoop) end
end
local autoTrashTog = sAuto.toggle("คุ้ยขยะอัตโนมัติ", S.AutoTrash, setAutoTrash)
local function setAutoCandy(v)
	if v and getgenv().AutoTrash then
		S.AutoTrash, getgenv().AutoTrash = false, false
		autoTrashTog.set(false)
	end
	S.AutoCandy=v getgenv().AutoCandy=v
	if v then task.spawn(function() while getgenv().SuiteCandyRunning do task.wait(0.2) end getgenv().SuiteCandy.loop() end) end
end
getgenv().SuiteCandyTog = sAuto.toggle("ฟาร์มแคนดี้บ้านอัตโนมัติ (เคาะประตู → เทหม้อ)", S.AutoCandy, setAutoCandy)
do
	local lbl = sAuto.label("แคนดี้: ปิดอยู่")
	getgenv().SuiteCandy.setStatus(function(t) pcall(lbl.set, "แคนดี้: " .. t) end)
end
do
	local hopLbl = sAuto.label("ย้ายเซิร์ฟ: -")
	local function say(t) pcall(hopLbl.set, "ย้ายเซิร์ฟ: " .. t) end
	sAuto.button("🌐 ย้ายไปเซิร์ฟคนน้อยสุด", function() say("กำลังหา...") getgenv().SuiteHop("min", say) end)
	sAuto.button("🌐 ย้ายไปเซิร์ฟคนเยอะสุด", function() say("กำลังหา...") getgenv().SuiteHop("max", say) end)
end
if S.AutoTrash then setAutoTrash(true) elseif S.AutoCandy then setAutoCandy(true) end   -- เปิดต่อจากรอบที่แล้ว
sAuto.slider("ความเร็วขุด", 1, 2, 0.05, S.DigMult, function(v) S.DigMult=v end)
sAuto.toggle("ขายให้ NPC อัตโนมัติ", S.AutoSell, function(v) S.AutoSell=v end)
sAuto.slider("ฟาร์มกี่กองแล้วไปขาย", 1, 12, 1, S.SellEvery, function(v) S.SellEvery=v end)
sAuto.button("ไปขายเดี๋ยวนี้", function() task.spawn(sellAll) end)
sAuto.label("1.3 = 25 วิ/กอง ผ่าน | เกิน 1.4 เซิร์ฟตีตก")

-- รวมแท็บ "เลือกขายไอเท็ม" เข้ามาในแท็บเดียวกับ Auto คุ้ยขยะ
sAuto.label("━━ เลือกขายไอเท็ม (ติก=ขาย / ไม่ติก=เก็บ) ━━")
do
	local ok, cfg = pcall(require, game.ReplicatedStorage.Job["ขยะ"]:FindFirstChild("SellConfig"))
	local items = {}
	if ok and type(cfg)=="table" then
		for name,info in pairs(cfg) do
			items[#items+1] = { name=name, price=(type(info)=="table" and (info.base or info.max or 0)) or 0 }
		end
		table.sort(items, function(a,b) return a.price > b.price end)
		-- ติกทั้งหมดเป็นดีฟอลต์เฉพาะตอนที่ยังไม่มีค่าที่จำไว้ (ไม่งั้นทับค่าที่โหลดมา)
		if next(S.SellPick) == nil then
			for _,it in ipairs(items) do S.SellPick[it.name]=true end
		end
	end
	local refreshSell = sAuto.checklist(items,
		function(name) return S.SellPick[name]==true end,
		function(name) if S.SellPick[name] then S.SellPick[name]=nil else S.SellPick[name]=true end end)
	sAuto.button("ติกทั้งหมด (ขายหมด)", function()
		for _,it in ipairs(items) do S.SellPick[it.name]=true end
		refreshSell()
	end)
	sAuto.button("เอาออกทั้งหมด (เก็บหมด)", function()
		for k in pairs(S.SellPick) do S.SellPick[k]=nil end
		refreshSell()
	end)
end

local sFps = Section("⚡ FPS")
local function setLowGfx(v)
	S.LowGfx = v
	local L = game:GetService("Lighting")
	if v then
		-- Level04 ไม่ใช่ Level01: ระดับต่ำสุดลดระยะเรนเดอร์/ตัดโมเดลไกลทิ้ง (โมเดลหาย) | ที่เหลือลดแต่ "หน้าตา" ไม่แตะ Transparency/ไม่ลบอะไร
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level04 end)
		L.GlobalShadows = false
		for _, d in ipairs(L:GetDescendants()) do if d:IsA("PostEffect") then d.Enabled=false end end
		local function lowObj(d)
			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") then d.Enabled=false
			elseif d:IsA("BasePart") then d.Material=Enum.Material.SmoothPlastic d.Reflectance=0 d.CastShadow=false end
		end
		-- ทำเป็นก้อนละ 1500 ชิ้น พักเฟรมระหว่างก้อน กันค้างตอนรันครั้งแรก | ของที่เกิดใหม่ทีหลังจัดให้ด้วย
		task.spawn(function()
			local n = 0
			for _, d in ipairs(workspace:GetDescendants()) do
				pcall(lowObj, d)
				n += 1
				if n % 1500 == 0 then task.wait() end
			end
		end)
		pcall(function() if getgenv().SuiteGfxConn then getgenv().SuiteGfxConn:Disconnect() end end)
		getgenv().SuiteGfxConn = workspace.DescendantAdded:Connect(function(d) if S.LowGfx and live() then pcall(lowObj, d) end end)
		pcall(function() workspace.Terrain.WaterWaveSize=0 workspace.Terrain.WaterReflectance=0 workspace.Terrain.Decoration=false end)
	else
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		L.GlobalShadows = true
	end
end
-- ปลดล็อก FPS: setfpscap(0) = ไม่จำกัด (ถ้าตัวรันไม่มีฟังก์ชันนี้ ข้ามเงียบ ๆ) | เปิดตั้งแต่เริ่มรัน
local function setFpsUnlock(v)
	S.FpsUnlock = v
	pcall(function() if setfpscap then setfpscap(v and 0 or 60) end end)
end
sFps.toggle("ปลดล็อก FPS (ไม่จำกัด)", S.FpsUnlock, setFpsUnlock)
if S.FpsUnlock then setFpsUnlock(true) end
sFps.toggle("โหมดกราฟิกต่ำ (ภาพกาก ไม่ลบโมเดล)", S.LowGfx, setLowGfx)
if S.LowGfx then setLowGfx(true) end
local fpsLabel = sFps.label("FPS: ...")
task.spawn(function()
	while live() do
		local f = math.floor(1 / RS.RenderStepped:Wait())
		pcall(function() fpsLabel.set(string.format("FPS: %d | lock: %s", f, getgenv().SuiteLock or "-")) end)
		task.wait(1)
	end
end)

-- ⏱️ อีเวนต์: รวมเข้าแท็บ FPS (ไม่มีแท็บอีเวนต์แยกแล้ว)
local evL = { sFps.label("..."), sFps.label("..."), sFps.label("..."), sFps.label("...") }
sFps.label("━━ อีเวนต์ทั้งหมด (หมุนเวียนทุก 2 ชม. ทีละอัน) ━━")
-- ลิสต์อีเวนต์ครบทุกอันจาก EventConfig + ไฮไลต์ตัวที่กำลังเกิด
local catL = {}
do
	local cat = getgenv().EventCatalog or {}
	for i = 1, math.max(#cat, 8) do catL[i] = sFps.label("") end
end
sFps.label("อัปเดตทุก 1 วิ — อ่านจาก HUD/เซิร์ฟตรง ๆ")
task.spawn(function()
	while live() do
		local lines = eventLines()
		for i,l in ipairs(evL) do pcall(function() l.set(lines[i] or "") end) end
		-- หาตัวที่ active จากชื่อใน Pill (pillRead อยู่ในบรรทัดแรกของ lines)
		local activeTxt = (lines[1] or "")
		local cat = getgenv().EventCatalog or {}
		for i, lbl in ipairs(catL) do
			local e = cat[i]
			if e then
				local on = activeTxt:find(e.name, 1, true) ~= nil
				pcall(function() lbl.set((on and "▶ " or "• ") .. e.name .. (on and "  ← กำลังเกิด" or "")) end)
			else pcall(function() lbl.set("") end) end
		end
		task.wait(1)
	end
end)


UIS.InputBegan:Connect(function(i,gp)
	if gp or not live() then return end
	if i.KeyCode==Enum.KeyCode.RightControl then win.Visible=not win.Visible end
	if i.KeyCode==Enum.KeyCode.G then local v = not getgenv().SuiteFree setFree(v) freeTog.set(v) end
end)

-- แจ้งเตือนคอมแบตขวาล่าง: นับถอยหลังจนหมดสถานะ (เปิดกระเป๋า/เก็บปืนไม่ได้ตอนติด)
do
	local ct = Instance.new("Frame", sgui)
	ct.AnchorPoint = Vector2.new(1,1); ct.Position = UDim2.new(1,-16,1,-16); ct.Size = UDim2.fromOffset(176,46)
	ct.BackgroundColor3 = Color3.fromRGB(30,10,12); ct.BorderSizePixel = 0; ct.Visible = false; round(ct,10); stroke(ct, Color3.fromRGB(240,70,70), 1)
	local dot = Instance.new("Frame", ct); dot.Size = UDim2.fromOffset(10,10); dot.Position = UDim2.new(0,14,0.5,-5); dot.BackgroundColor3 = Color3.fromRGB(255,70,70); dot.BorderSizePixel = 0; round(dot,5)
	local lb = Instance.new("TextLabel", ct); lb.BackgroundTransparency = 1; lb.Position = UDim2.fromOffset(32,0); lb.Size = UDim2.new(1,-40,1,0)
	lb.Font = Enum.Font.GothamBold; lb.TextSize = 15; lb.TextColor3 = Color3.fromRGB(255,215,215); lb.TextXAlignment = Enum.TextXAlignment.Left; lb.Text = "IN COMBAT"
	task.spawn(function()
		while live() do
			local e = getgenv().CombatEnd
			local left = e and (e - os.clock()) or nil
			if left and left > 0 then
				ct.Visible = true
				lb.Text = string.format("⚔ คอมแบต %d:%02d", math.floor(left/60), math.floor(left%60))
				dot.BackgroundTransparency = (math.floor(os.clock()*2)%2==0) and 0 or 0.65  -- กระพริบ
			else
				if e then getgenv().CombatEnd = nil end
				ct.Visible = false
			end
			task.wait(0.2)
		end
	end)
end

-- ปุ่มมือถือ: เปิดเมนู + เปิดกระเป๋าหยิบปืน (โชว์เฉพาะจอสัมผัส)
if UIS.TouchEnabled then
	local function fab(txt, yoff, cb)
		local b = Instance.new("TextButton", sgui)
		b.Size = UDim2.fromOffset(52,52); b.Position = UDim2.new(1,-66,0.5,yoff)
		b.BackgroundColor3 = C.card; b.BorderSizePixel = 0; b.Text = txt
		b.Font = Enum.Font.GothamBold; b.TextSize = 24; b.TextColor3 = C.txt; b.AutoButtonColor = true
		round(b,14); stroke(b,C.cyan,1)
		b.MouseButton1Click:Connect(cb); return b
	end
	fab("☰", -60, function() win.Visible = not win.Visible end)    -- ซ่อนแค่หน้าต่าง ไม่ใช่ sgui.Enabled ไม่งั้นปุ่มนี้หายไปด้วยแล้วเปิดคืนไม่ได้ (มือถือไม่มี RightCtrl)
	fab("🎒", 0, function() openBag() end)                          -- เปิดกระเป๋าหยิบปืน
end

pLabel.set("จุดที่เจอ: "..scanPoints())
print("[Suite] UI ใหม่โหลดเสร็จ — K=aim L=esp B=กระเป๋า RightCtrl=เมนู | มือถือมีปุ่ม ☰ 🎒")

end)
