--[[
Rewrite Structure Heavily Inspired by Squishy's API
]]


--[[ Credits
    CommanderShiji (@the_command) - Influence Math
]]--


---@diagnostic disable: duplicate-set-field
---@diagnostic disable: redefined-local
---@diagnostic disable: undefined-field
---@diagnostic disable: undefined-doc-name
---@diagnostic disable: undefined-global

--This Alias grabs from ease's aliases. If ease is installed and you have VSCode + GS' VSCodeDocs it should show up on your main script
---@alias jl.validInterps: string
---| linear
---| sine
---| quad
---| cubic
---| quart
---| quint
---| expo
---| circ
---| back
---| logarithmic

--#region 'just_lean Initialization'
---@class just_lean
local just_lean = {}
just_lean.__index = just_lean
just_lean.allowAutoUpdates = true
just_lean.enabled = true
just_lean.debug = false
just_lean.useEase = true
just_lean.baseRot = vanilla_model.HEAD:getOriginRot()
--#endregion

--#region 'Math Setup'
local sin, cos, abs, asin, atan, atan2, min, max, map, lerp = math.sin, math.cos, math.abs, math.asin, math.atan, math.atan2, math.min, math.max, math.map, math.lerp
local function tweenFn(a,b,t,s)
    return (just_lean.useEase and easings) and easings:ease(a,b,t,s) or lerp(a,b,t)
end
--#endregion

--#region 'Prerequesites'

local function prequire(m)  --protected require shared by moteus
  local ok, err = pcall(require, m) 
  if not ok then return nil, err end
  return err
end

---@param message string
---@param level number ?
---@param prefix string ?
---@param toLog boolean ?
---@param both boolean ?
local function warn(message, level, prefix, toLog, both) --by Auria, Modified by Xander
    local _, traceback = pcall(function() error(message, (level or 1) + 3) end)
    if both or not toLog then
        printJson(toJson {
            { text = "Soul Fighter Gwen ",              color = "#AC92FA" },
            { text = "loaded by ",              color = "white" },
            { text = avatar:getEntityName(), color = "white" },
        })
    end
    if toLog or both then
        host:warnToLog("[" .. (prefix or "warn") .. "] " .. traceback)
    end
end

local Squishy
for _, key in ipairs(listFiles(nil, true)) do
    if key:find("SquAPI$") then
        Squishy = require(key)
        if host:isHost() then
            warn(
                --"Squishy's API Detected. This script will not work properly with the Smooth Head/Torso/etc.",
                2)
        end
        break
    end
end

function events.entity_init()
    if Squishy ~= nil then
        Squishy = Squishy
    end
end

local assumed = "scripts.ease"
local exists = prequire(assumed)
local easings
    if not exists then
        for _, key in ipairs(listFiles(nil, true)) do
            if key:find("ease$") then
                easings = require(key)
            end
        end
    else
        easings = exists
    end

    function events.tick()
    
    just_lean.useEase = easings ~= nil
    if easings then
        easings.exposeEase = true
    end
end

--#endregion

--#region 'Math Extras'

---@private
---@overload fun(v: number, a: number, b: number): number
local function clamp(v, a, b)
    return min(max(v, a), b)
end

--#endregion

--#region 'Just-Lean'
---@class lean
lean = {}
lean.__index = lean
setmetatable(lean, just_lean)
lean.activeLeaning = {}
---@overload fun(self?: self, modelpart: ModelPart, minLean: Vector2, maxLean: Vector2, speed: number, interp: jl.validInterps|string, breathing: boolean, enabled: boolean): self
---@overload fun(self?: self, modelpart: ModelPart, minLean: table, maxLean: table, speed: number, interp: jl.validInterps|string, breathing: boolean, enabled: boolean): self
---@overload fun(self?: self, modelpart: ModelPart, minLean: Vector2, maxLean: table, speed: number, interp: jl.validInterps|string, breathing: boolean, enabled: boolean): self
---@overload fun(self?: self, modelpart: ModelPart, minLean: table, maxLean: Vector2, speed: number, interp: jl.validInterps|string, breathing: boolean, enabled: boolean): self
function lean.new(self, modelpart, minLean, maxLean, speed, interp, breathing, enabled)
    local self = setmetatable({}, lean) --[[@as table]]
    self.modelpart = modelpart
    if type(minLean) == "table" then
        self.minLean = vec(minLean.x or minLean[1], minLean.y or minLean[2]) or vectors.vec2()
    else
        self.minLean = minLean or vectors.vec2()
    end
    if type(maxLean) == "table" then
        self.maxLean = vec(maxLean.x or maxLean[1], maxLean.y or maxLean[2]) or vectors.vec2()
    else
        self.maxLean = maxLean or vectors.vec2()
    end
    self.speed = speed
    self.enabled = enabled
    self.rot = vectors.vec3()
    self._rot = vectors.vec3()
    self.breathing = breathing
    self.interp = interp
    self.offset = vectors.vec3()

    function self:reset()
        self.offset:reset()
        self.rot:reset()
        return self
    end

    function self:disable(x)
        if not x then
            self.rot = vec(0, 0, 0)
            self.modelpart:setOffsetRot()
        end
        self.enabled = false
        return self
    end

    function self:enable()
        self.enabled = true
        return self
    end

    function self:toggle()
        self.enabled = not self.enabled
    end

    self.tick = function(self)
        self._rot:set(self.rot)
        local rot = just_lean.baseRot:toRad()
        local t = sin(((client.getSystemTime() / 1000) * 20) / 16.0)
        local breathe = vec(
            t * 2.0,
            abs(t) / 2.0,
            (abs(cos(t)) / 16.0)
        )
        local targetVel = (math.log((player:getVelocity().x_z:length()*20) + 1 - 0.21585) * 0.06486 * 19 + 1)
        local lean_x = clamp(sin(rot.x / targetVel) * 45.5, self.minLean.x, self.maxLean.x) --[[@as number]]
        local lean_y = clamp(sin(rot.y) * 45.5, self.minLean.y, self.maxLean.y) --[[@as number]]
        local targetrot = not player:isCrouching() and
        vec(lean_x, lean_y, lean_y * 0.35):add((vanilla_model.HEAD:getOffsetRot() or vec(0,0,0))) or vec(lean_x*0.2, lean_y*0.5, lean_y * 0.25):add((vanilla_model.HEAD:getOffsetRot() or vec(0,0,0))) 
        if self.breathing then
            self.rot:set(tweenFn(self.rot, targetrot + breathe, self.speed or 0.3, self.interp or "linear"))
        else
            self.rot:set(tweenFn(self.rot, targetrot, self.speed or 0.3, self.interp or "linear"))
        end
    end

    self.render = function(self, delta)
        local fRot = lerp(self._rot, self.rot, delta)
        self.modelpart:setOffsetRot(fRot)
    end

    table.insert(lean.activeLeaning, self)
    return self
end

---@class head
head = {}
head.__index = head
setmetatable(head, just_lean)
head.activeHead = {}
---@param self head
---@param modelpart ModelPart
---@param speed number
---@param tilt number
---@param interp jl.validInterps
---@param strength table|Vector2|number?
---@param vanillaHead boolean
---@param metatable table
---@param enabled boolean
---@return head
function head.new(self, modelpart, speed, tilt, interp, strength, vanillaHead, metatable, enabled)
    local self = setmetatable({}, head) --[[@as table]]
    self.modelpart = modelpart
    self.enabled = enabled or true
    self.speed = speed or 0.3625
    self.vanillaHead = vanillaHead or false
    self.rot = vectors.vec3()
    self._rot = vectors.vec3()
    self.frot = vectors.vec3()
    self.__metatable = metatable or false
    self.id = #head.activeHead+1
    if type(strength) == "table" then
        self.strength = vec(strength.x or strength[1], strength.y or strength[2], 1)
    elseif type(strength) == "number" then
        self.strength = vec(strength, strength, 1)
    else
        self.strength = strength
    end
    self.tilt = (1 / (tilt or 4)) * (self.strength.y or self.strength[2] or 1)
    self.interp = interp or "linear"
    if not self.vanillaHead then
        vanilla_model.HEAD:setRot(0,0,0)
    end
    function self:disable(x)
        if not x then
            self.rot = vec(0, 0, 0)
            self.modelpart:setOffsetRot()
            vanilla_model.HEAD:setRot()
        end
        self.enabled = false
        return self
    end

    self.tick = function(self)
        if not self.enabled then return end
        local this = self.__metatable
        local headRot = just_lean.baseRot
        local final = headRot - vec(this._rot.x, this._rot.y, -this._rot.y / (self.tilt or 4))
        local targetRot = (final+(vanilla_model.HEAD:getOffsetRot() or vec(0,0,0))) * self.strength
        self._rot:set(self.rot)
        self.rot:set(
            tweenFn(self.rot,
            targetRot, self.speed or 0.5,
            self.interp or "linear")
        )
    end

    self.render = function(self, delta)
        self.frot = lerp(self._rot, self.rot, delta)
        self.modelpart:setRot(self.frot)
    end
    table.insert(head.activeHead, self)
    return self
end

---If this comment is still here that means you havent pushed an update.

---@alias influence.modes
---| "LEG_LEFT"
---| "LEG_LEFT_LOWER"
---| "LEG_RIGHT"
---| "LEG_RIGHT_LOWER"
---| "ARM_LEFT"
---| "ARM_RIGHT"

---@class influence
influence = {}
influence.__index = influence
setmetatable(influence, just_lean)
influence.activeInfluences = {}
---@param self influence
---@param modelpart ModelPart --Required.
---@param speed number
---@param interp jl.validInterps|string
---@param mode influence.modes|string
---@param strength table --Can also take a Vector3
---@param metatable table|nil
---@param enabled boolean
---@param constraints table|nil --Two Vector3s must be inside: {vec(x,y,z), vec(x,y,z)}, for now Exclusively used for the _LOWER modes
---@return influence
function influence.new(self, modelpart, speed, interp, mode, strength, metatable, enabled, constraints)
    local self = setmetatable({}, influence) --[[@as table]]
    self.modelpart = modelpart
    self.speed = speed
    self.interp = interp
    self.enabled = enabled
    self.__metatable = metatable or false
    self.rot = vectors.vec3()
    self._rot = self.rot
    self.pos = vectors.vec3()
    self._pos = self.pos
    self.frot = vectors.vec3()
    self.fpos = vectors.vec3()
    self.mode = mode or "LEGS"
    self.strength = vec(strength[1] or strength.x, strength[2] or strength.y, strength[3] or strength.z)
    self.constraints = constraints or {vec(-360,-360,-360), vec(360,360,360)}

    self.tick = function(self)
        self._rot = self.rot
        self._pos = self.pos
        local pose = player:getPose()
        local rot
        if self.__metatable and self.__metatable.modelpart then
        local animRot = self.__metatable.modelpart:getAnimRot() or vec(0,0,0)
            rot = self.__metatable.rot - animRot
        else
            rot = just_lean.baseRot
        end
        local targetRot, targetPos = vectors.vec3(), vectors.vec3()
        local isHoldingItem = player:getActiveItem().id ~= "minecraft:air"
        local _strength = vec(strength[1] or strength.x, strength[2] or strength.y, strength[3] or strength.z)
        if self.mode == "ARM_LEFT" or self.mode == "ARM_RIGHT" then
            if isHoldingItem then
                self.strength = vec(_strength.x > 0 and -_strength.x or -1, _strength.y > 0 and -_strength.y or -1, _strength.z > 0 and -_strength.z or -1)
            else
                self.strength = _strength
            end
        end
        if self.mode == "LEG_LEFT" then
            targetRot = vec((((-rot.x*0.5)+(rot.y))/14) * self.strength.x, ((rot.y/2)*self.strength.y), (pose ~= "STANDING" and -(rot.y * self.strength.z) or 0))
            targetPos = vec((pose ~= "STANDING" and ((rot.y * self.strength.z) / 4) or 0), 0, (pose ~= "STANDING" and ((-rot.x + rot.y) / 60) or ((-(rot.x*1) + (rot.y*2)) / 40)))
        elseif self.mode == "LEG_RIGHT" then
            targetRot = vec(-(((rot.x*0.5)+(rot.y))/14) * self.strength.x, -((rot.y/2)*self.strength.y), (pose ~= "STANDING" and -(rot.y * self.strength.z) or 0))
            targetPos = vec((pose ~= "STANDING" and ((rot.y * self.strength.z) / 4) or 0), 0, (pose ~= "STANDING" and -((rot.x + rot.y) / 60) or -(((rot.x*1) + (rot.y*2)) / 40)))
        elseif self.mode == "ARM_LEFT" then
            targetRot = rot * self.strength
        elseif self.mode == "ARM_RIGHT" then
            targetRot = rot * self.strength
        elseif self.mode == "LEG_LEFT_LOWER" then
            assert(#self.constraints > 1, "Expected 2 Values/Table Length of 2, got "..#self.constraints)
            --targetPos
            local sel_limit
            targetRot = vec(
                clamp((rot.y/40 + rot.x) * self.strength.x, self.constraints[1] and self.constraints[1].x, self.constraints[2] and self.constraints[2].x),
                0,
                0
            )
        elseif self.mode == "LEG_RIGHT_LOWER" then
            assert(#self.constraints > 1, "Expected 2 Values/Table Length of 2, got "..#self.constraints)
            targetRot = vec(
                clamp((-rot.y/40 + rot.x) * self.strength.x, self.constraints[1] and self.constraints[1].x, self.constraints[2] and self.constraints[2].x),
                0,
                0
            )
        end
        self.rot = tweenFn(self.rot, targetRot, self.speed or 0.5, self.interp or "linear")
        self.pos = tweenFn(self.pos, targetPos, self.speed or 0.5, self.interp or "linear")
    end

    self.render = function(self, delta)
        self.frot = lerp(self._rot, self.rot, delta)
        self.fpos = lerp(self._pos, self.pos, delta)
        self.modelpart:setOffsetRot(self.frot)
        self.modelpart:setPos(self.fpos)
    end
    table.insert(influence.activeInfluences, self)
    return self
end
--#endregion

--#region 'Update'
local hed = head.activeHead
local le = lean.activeLeaning
local influ = influence.activeInfluences
function just_lean:tick()
    if not self.enabled then return self end
    self.baseRot = (((vanilla_model.HEAD:getOriginRot()+180)%360)-180)
    if #le < 1 then
        if self.debug then
            warn("No Parts Specified", 4)
        end
        return false
    end
    for id_h, v in pairs(hed) do
        if v.enabled then
            v:tick()
        end
    end
    
    for _, k in pairs(le) do
        if k.enabled then
            k:tick()
        end
        
    end
    for _, l in pairs(influ) do
        if l.enabled then
            l:tick()
        end
    end
end

just_lean.lean = lean
setmetatable(just_lean.lean, just_lean)
just_lean.head = head
setmetatable(just_lean.head, just_lean)
just_lean.influence = influence
setmetatable(just_lean.influence, just_lean)

function just_lean:render(delta)
    if not self.enabled then return self end
    if delta == 1 then return end
    
    for _, v in pairs(hed) do
        if v.enabled then
            v:render(delta)
        end
    end

    for _, k in pairs(le) do
        if k.enabled then
            k:render(delta)
        end
    end

    for _, l in pairs(influ) do
        if l.enabled then
            l:render(delta)
        end
    end
end

if just_lean.allowAutoUpdates then
    function events.tick()
        just_lean:tick()
    end

    function events.render(d)
        just_lean:render(d)
    end
end
--#endregion

return just_lean