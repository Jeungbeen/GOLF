--[[
 _______  _______  ___      _______ 
|       ||       ||   |    |       |
|    ___||   _   ||   |    |    ___|
|   | __ |  | |  ||   |    |   |___ 
|   ||  ||  |_|  ||   |___ |    ___|
|   |_| ||       ||       ||   |    
|_______||_______||_______||___|   by Jeungbeen
  
]]--


--#region "Config"
local ballParticle = "end_rod"                 --Particle used to render the "ball"
local trajectoryParticle = "electric_spark"    --Particle used to render the guideline
local hitSound = "entity.player.attack.sweep"  --Sound playing when hitting the ball
local ballLandSound = "block.stone.fall"        --Sound playing when ball lands

local golfGUITitle = "GOLF by Jeungbeen"       --Header of the GUI, can be customized
local golfGUIColor = "#8CDB90"               --Color of the GUI

--#endregion


--#region "Implementation"

---@class Vector3
---@field x number
---@field y number
---@field z number

--GOLF System variables
---@class Golf
---@field sequence number           0 -> Not golfing  ~  4 -> In the hole
---@field mode number               0 -> No golf club, 1 -> Driver, 2 -> Putter
---@field firstShot boolean         First shot determines if the ball will be rendered in the world
---@field toggleTrajectory boolean 
---@field shotCount number
---@field inTheHole boolean
---@field GUIHeader string          Header of the GOLF GUI
---@type Golf
local golf = {}
golf.sequence = 0
golf.mode = 1
golf.firstShot = true
golf.toggleTrajectory = false
golf.shotCount = 0
golf.inTheHole = false
golf.GUIHeader = golfGUITitle



---@class BallOrigin
---@field pos Vector3
---@field direction Vector3
---@field angle Vector3

---@class LaunchSpeed       
---@field value number      
---@field climb boolean     True for increasing and false for decreasing the launch speed
---@field clamp number[]    Min/max launch speed

--Ball properties
---@class Ball
---@field origin BallOrigin
---@field launchSpeed LaunchSpeed
---@field currentPos Vector3
---@field currentGround number
---@field launched boolean
---@type Ball
local ball = {}
ball.origin = {}
ball.origin.pos = vec(0, 0, 0)
ball.origin.direction = vec(0, 0, 0)
ball.origin.angle = vec(0, 0, 0)
ball.launchSpeed = {}
ball.launchSpeed.value = 0
ball.launchSpeed.climb = true
ball.launchSpeed.clamp = {1, 30}
ball.currentPos = vec(0, 0, 0)
ball.currentGround = 0
ball.launched = false



--How far away the precalculated landing spot is through f(x) function's zero points 
local landDistance = 0
local landPos = vec(0, 0, 0)

--Variables to be used in the f(x) function
local m, c = 0, 0


--Step of the particle render, also determines the visual speed of the "ball"
local step = 0
--Interval between updating the guideline
local showBallTrajectoryInterval = 0


---@class Place
---@field potentialFlagPos Vector3  Formatting in player:getPos()
---@field potentialFlagRot Vector3  Formatting in player:getRot()
---@field sequence number           0 -> Not placing flags, 1 -> Searching for position, 2 -> Position set and setting name

--Flag System properties
---@class Flag
---@field globalFlags table         All flags in the world
---@field globalFlagCount number    Count of all flags in the world
---@field personalFlags table       All of your flags, this will be added to globalFlags
---@field activeFlags table         All active flag objects in the world
---@field place Place               
---@type Flag
local flags = {}
flags.globalFlags = {}
flags.globalFlagCount = 0
flags.personalFlags = {}
flags.activeFlags = {}
flags.place = {}
flags.place.potentialFlagPos = vec(0, 0, 0)
flags.place.potentialFlagRot = vec(0, 0, 0)
flags.place.sequence = 0


--Yet be implemented
local wind = {}
wind.direction, wind.intensity = vec(0, 0, 0), 0

local ballCamera = {}
ballCamera.enabled = false
ballCamera.offset = vec(0, 0, 0)
--ballCamera.camera = FOXCamera ~= nil and FOXCamera:getCamera() or nil


local indicatorText = ""
local indicatorTextOutline, indicatorTextOutlineColor = false, ""

local indicatorElement = models:newPart("Indicator", "HUD")

local indicatorText = indicatorElement:newText("Indicator")
        :setText(toJson({text = indicatorText, color = "white"}))
        :setShadow(true)
        :setAlignment("CENTER")
        :setPos(-client:getWindowSize().x / 6, -client:getWindowSize().y / 30, 0)
        :setLight(15, 15)

        

--Calculates the distance between two points with a straight line   
---@param a Vector3
---@param b Vector3
---@return number
local function distanceCalculation(a, b)
    local dist = (b - a):length()
    return dist
end

--Calculates the distance between two points via a parabola
---@param m number Slope of the parabola
---@param a number Launch speed, determines the size of the parabola
---@return number  Distance between two points on the parabola
local function ballFlightPathCalculation(m, a) 
    if m <= 0 then return nil end

    return 2 * (a / math.sqrt(m))
end

--Calculates the y of a parabola with the given x
---@param m number Slope of the parabola
---@param a number Launch speed, determines the size of the parabola
---@param c number Shift in y direction of the parabola
---@return number  y of the parabola on position x
local function ballFlightPositionCalculation(x, m, a, c)
    if m <= 0 then return nil end
    
    return (-m/a) * ((x-(a/(math.sqrt(m))))^2) + a + c
end



--Shows the trajectory of the ball with particles
---@param origin Vector3 The origin of the ball to start the calculation at
local function showBallTrajectory(origin)
    if host:isHost() then
        --Needs its own trajectory properties as to not interfere with the main ball properties
        local currentOriginPos = origin
        local currentOriginDirection = (player:getLookDir().x_z):normalize()

        if golf.mode == 1 then
            if ballFlightPathCalculation(math.tan(math.rad((math.clamp(player:getLookDir().y * 90, 1, 89)))), ball.launchSpeed.value, origin.y)  == nil then return end
            
            local currentLandDistance = ballFlightPathCalculation(math.tan(math.rad((math.clamp(player:getLookDir().y * 90, 1, 89)))), ball.launchSpeed.value, origin.y)            

            for i = 0, currentLandDistance, currentLandDistance / (ball.launchSpeed.value * 3) do
                if ballFlightPositionCalculation(i, math.tan(math.rad((math.clamp(player:getLookDir().y * 90, 1, 89)))), ball.launchSpeed.value, origin.y) == nil then return end
                
                local trajectoryPos = vec(currentOriginPos.x + currentOriginDirection.x * i, ballFlightPositionCalculation(i, math.tan(math.rad((math.clamp(player:getLookDir().y * 90, 1, 89)))), ball.launchSpeed.value, origin.y), currentOriginPos.z + currentOriginDirection.z * i)

                particles:newParticle(trajectoryParticle, trajectoryPos)
            end

        elseif golf.mode == 2 then
            local currentLandDistance = distanceCalculation(currentOriginPos, currentOriginPos + currentOriginDirection * (ball.launchSpeed.value / 2))            
            
            for i = 0, currentLandDistance, currentLandDistance / ((ball.launchSpeed.value / 2) * 3) do
                local trajectoryPos = vec(currentOriginPos.x + currentOriginDirection.x * i, currentOriginPos.y, currentOriginPos.z + currentOriginDirection.z * i)

                trajectoryPos = golf.firstShot and trajectoryPos + vec(0, 0.25, 0) or trajectoryPos

                particles:newParticle(trajectoryParticle, trajectoryPos)
            end
        end
    end
end



--Checks if the ball is on the ground
---@param currentPos Vector3
---@return boolean
local function checkBallGrounded(currentPos)
    local block, hitPos, side = raycast:block(currentPos, vec(currentPos.x, -53, currentPos.z))
    ball.currentGround = block:getPos().y

    return block:getPos().y > currentPos.y - 1.2
end

--Checks if the ball hits an obstacle
---@param currentPos Vector3
---@return boolean
local function checkBallObstacle(currentPos, direction)
    local block, hitPos, side = raycast:block(currentPos + vec(0, 0.25, 0), currentPos + vec(0, 0.25, 0) + direction * 5)

    if block == nil then return false end

    return distanceCalculation(currentPos, block:getPos()) < 1.4
end

--Checks if the ball hits a wall and grounds it
---@param currentPos Vector3
---@param direction Vector3
local function checkBallHitWall(currentPos, direction)
    if checkBallObstacle(currentPos, direction) then
        local block, hitPos, side = raycast:block(currentPos, vec(currentPos.x, -53, currentPos.z))
        if block == nil then return end

        ball.currentGround = block:getPos().y
    end
end

--Checks if the ball hits a flag
---@param currentPos Vector3
local function checkBallFlag(currentPos)
    local nearestflagPos = vec(0, 0, 0)
    
    if flags.globalFlagCount == 0 or currentPos == vec(0, 0, 0) then return end

    for _, i in ipairs(flags.globalFlags) do
        if distanceCalculation(currentPos, i[2]) < distanceCalculation(currentPos, nearestflagPos) or nearestflagPos == nil then
            nearestflagPos = i[2]
        end
    end

    if distanceCalculation(currentPos, nearestflagPos) < 1 then
        if golf.mode == 1 then
            ball.currentPos.y = ball.currentPos.y + 1.25
        end

        landPos = vec(ball.currentPos.x, math.floor(ball.currentPos.y + 1) - 0.5, ball.currentPos.z)
        
        pings.syncLandPos(landPos)
        pings.syncBallPos(landPos)

        pings.syncSequence(4)
    end
end



--Shows all flags in the world
---@param removeFlags boolean Set true to remove all active flags
local function showFlags(removeFlags) 
    for _, i in ipairs(flags.activeFlags) do i:remove() end
    
    if removeFlags then return end

    for _, i in ipairs(flags.globalFlags) do 
        local flag = models:newPart("Flag", "World")
                :setPos((i[2] + vec(0, 0.1, 0)) * 16)

        local flagDisplay = flag:newBlock("FlagDisplay")
                :setBlock("red_banner")
                :setRot(vec(0, -i[3].y, 0))
                :setLight(15, 15)

        local flagName = flag:newText("FlagName")
                :setText(i[1])
                :setShadow(true)
                :setAlignment("CENTER")
                :setRot(vec(0, -i[3].y - 180, 0))
                :setPos(vec(vectors.angleToDir(-i[3] - 180).x * -9 + vectors.angleToDir(-i[3] - 180).z * 7, 35, vectors.angleToDir(-i[3] - 180).z * 9 + vectors.angleToDir(-i[3] - 180).x * 7))  
                :setScale(0.4, 0.4, 0.4)
                :setLight(10, 10)

        table.insert(flags.activeFlags, flag)
        table.insert(flags.activeFlags, flagDisplay)
        table.insert(flags.activeFlags, flagName)
    end
end



--Resets the entire golf sequence
---@param hardReset boolean Set true to reset every state to the beginning
function pings.resetSequence(hardReset) 
    step = 0
    ball.launched = false
    golf.sequence = hardReset and 0 or 1

    indicatorText:setText("")
    pings.syncBallPos(landPos)
    if not hardReset then return end
    ball.currentPos = ball.origin.pos
    

    golf.firstShot = true
    golf.shotCount = 0
    golf.inTheHole = false
end

--Pings to add a flag to table
---@param str string Name of this flag
---@param pos Vector3 Position of this flag
---@param rot Vector3 Rotation of this flag, formatted like player:getRot()
function pings.addToPersonalFlags(str, pos, rot)
    table.insert(flags.personalFlags, {str, pos, rot})

    if not player:isLoaded() then return end

    sounds["block.iron_trapdoor.close"]:setSubtitle(player:getName() .. " sets a flag"):setPos(pos):setVolume(0.7):setPitch(1.2):play()
end

--Pings current ball position
---@param currentPos Vector3
function pings.syncBallPos(currentPos)
    ball.currentPos = currentPos
end

--Pings current ball position
---@param currentPos Vector3
---@param _m number
---@param _c number
function pings.syncBallOriginPos(currentPos, _m, _c, clamp, speed)
    ball.origin.pos = currentPos
    m = _m
    c = _c
    ball.launchSpeed.clamp = clamp
    ball.launchSpeed.value = speed

    sounds[hitSound]:setSubtitle(player:getName() .. " takes a shot"):setPos(player:getPos()):setVolume(0.5):setPitch(math.clamp(0.1 * (ball.launchSpeed.clamp[2] - ball.launchSpeed.value), 0.5, 1.7)):play()
end

--Pings current land position
---@param currentPos Vector3
function pings.syncLandPos(currentPos)
    landPos = currentPos
end

--Pings current land distance
---@param distance number Current golf.sequence
function pings.syncLandDistance(distance)
    landDistance = distance
end

--Pings personal flags
---@param personalFlags table
function pings.syncFlags(personalFlags)
    flags.personalFlags = personalFlags
end

--Pings current golf sequence
---@param sequence number Current golf.sequence
function pings.syncSequence(sequence)
    golf.sequence = sequence

    if sequence == 3 then
        sounds[ballLandSound]:setSubtitle(player:getName() .. "'s golfball lands"):setPos(landPos):setVolume(1):setPitch(0.7):play()
    end
end

--Pings current flag placement sequence
---@param sequence number Current flags.place.sequence
function pings.syncFlagSequence(sequence)
    flags.place.sequence = sequence
end

--Pings the removal of all flags
function pings.syncFlagRemoval()
    for k, v in pairs(flags.personalFlags) do flags.personalFlags[k] = nil end
    for _, i in ipairs(flags.activeFlags) do i:remove() end
    
end



---@param btn number 0 -> Left click, 1 -> Right click
---@param ctx number 0 -> Release, 1 -> Press once, 2 -> Hold
---@param mod number 4 -> ALT modifier
function events.mouse_press(btn, ctx, mod)
    if mod ~= 4 then return end
    if ctx ~= 1 then return end

    --Limit sequence change when not holding a golf club or when ball is in the air, only allow it when not placing flags
    if not (golf.mode == 0 or golf.sequence == 3) and flags.place.sequence == 0 then
        if btn == 0 then 
            if player:isLoaded() and not (math.tan(math.rad((math.clamp(player:getLookDir().y * 90, 1, 89)))) <= 0 and golf.sequence == 1 and golf.mode == 1) and golf.sequence ~= 2 then
                golf.sequence = golf.sequence + 1 
                pings.syncSequence(golf.sequence)

                if golf.sequence == 1 and host:isHost() then
                    sounds["block.note_block.harp"]:setSubtitle(toJson({{text = "GOLF initialized", bold = true, color = golfGUIColor}})):setPos(player:getPos()):setVolume(0.7):setPitch(1.2):play() 
                end
            end
        elseif btn == 1 and golf.sequence ~= 0 then    --Only allow toggling guidelines when golfing
            golf.toggleTrajectory = not golf.toggleTrajectory 

            if host:isHost() and player:isLoaded() then
                sounds["block.stone_button.click_on"]:setSubtitle(toJson({{text = "Guidelines ", bold = true, color = golfGUIColor}, {text = golf.toggleTrajectory and "enabled" or "disabled"}})):setPos(player:getPos()):setVolume(0.5):setPitch(1):play() 
            end
        end
    end

    --Only allow flag sequence change when holding a flag and not golfing
    if (flags.place.sequence == 1 or flags.place.sequence == 2) and golf.sequence == 0 and btn == 0 then
        --Cycle through 1 and 2
        flags.place.sequence = flags.place.sequence < 2 and flags.place.sequence + 1 or 1

        pings.syncFlagSequence(flags.place.sequence)

        if flags.place.sequence == 2 then
            if host:isHost() then
                sounds["block.note_block.harp"]:setSubtitle(toJson({{text = "Position set!", bold = true, color = golfGUIColor}})):setPos(player:getPos()):setVolume(0.7):setPitch(1.8):play() 
            end
        end
    end

    return true
end    



--Sync flags every set interval
local syncInterval = 200
local syncIntervalSaved = syncInterval

function events.tick()
    if syncInterval > 0 then
            syncInterval = syncInterval - 1
        else
            syncInterval = syncIntervalSaved
            pings.syncFlags(flags.personalFlags)
    end
end



--Main logic system
function events.tick()
    indicatorText:setPos(-client:getWindowSize().x / 6, -client:getWindowSize().y / 30, 0)
    if flags.place.sequence == 0 and golf.sequence == 0 then
        indicatorText:setText("")
    end


    if not player:isLoaded() then return end
    
    --Sync and render new flags
    if #flags.globalFlags ~= flags.globalFlagCount then
        flags.globalFlagCount = #flags.globalFlags
        showFlags(false) 
    end


    --Sync your flags to all clients
    avatar:store("GOLF", flags.personalFlags)

    --Get flags of all clients
    for k, v in pairs(flags.globalFlags) do flags.globalFlags[k] = nil end
    for k, v in pairs(world.avatarVars()) do
        if v["GOLF"] then
            for _, _i in ipairs(v["GOLF"]) do
                table.insert(flags.globalFlags, _i)
            end     
        end
    end


    --Checks if you are holding a golf related item
    if flags.place.sequence == 0 or flags.place.sequence == 1 then
        flags.place.sequence = not ((player:getHeldItem(false):getName() == "Driver" or player:getHeldItem(false):getName() == "Hybrid" or player:getHeldItem(false):getName() == "Wedge") or player:getHeldItem(false):getName() == "Putter") and player:getHeldItem(false):getName() == "Flag" and 1 or 0
    end

    if golf.sequence == 0 or golf.sequence == 1 then
        golf.mode = (player:getHeldItem(false):getName() == "Driver" or player:getHeldItem(false):getName() == "Hybrid" or player:getHeldItem(false):getName() == "Wedge") and 1 or player:getHeldItem(false):getName() == "Putter" and 2 or 0
    end
    

    if flags.place.sequence == 1 then
        flags.place.potentialFlagPos = player:getPos()
        flags.place.potentialFlagRot = player:getRot()

        indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = "Place flag at\n", color = "white"}, {text = string.gsub(tostring(vec(math.floor(flags.place.potentialFlagPos.x * 100) / 100, math.floor(flags.place.potentialFlagPos.y * 100) / 100, math.floor(flags.place.potentialFlagPos.z * 100) / 100)), "[{}]", "")}, {text = "\n\n[ALT] + [LClick] to place", color = "white"}}))
    
    elseif flags.place.sequence == 2 then
        indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = "Type /golf 'Your flag name' to add this flag's name\n\n[ALT] + [LClick] to cancel", color = "white"}}))
     
        if host:isHost() then
            particles:newParticle("firework", vec(flags.place.potentialFlagPos.x + (math.random() - 0.5) * 0.5, flags.place.potentialFlagPos.y + 1 + math.random() - 0.5, flags.place.potentialFlagPos.z + (math.random() - 0.5) * 0.5))
        end
    end


    if golf.sequence == 1 then
        ball.launched = false

        ball.launchSpeed.clamp = golf.mode == 1 and {1, 30} or golf.mode == 2 and {1, 10} or {1, 1}

        if ball.launchSpeed.climb and ball.launchSpeed.value < ball.launchSpeed.clamp[2] then
            ball.launchSpeed.value = ball.launchSpeed.value + 1
        elseif ball.launchSpeed.climb then
            ball.launchSpeed.climb = false
        end

        if not ball.launchSpeed.climb and ball.launchSpeed.value > ball.launchSpeed.clamp[1] then
            ball.launchSpeed.value = ball.launchSpeed.value - 1
        elseif not ball.launchSpeed.climb then
            ball.launchSpeed.climb = true
        end

        --Render ball when not first shot
        if not golf.firstShot then
            particles:newParticle(ballParticle, landPos)
        end

        --Render guidelines
        if golf.toggleTrajectory and showBallTrajectoryInterval == 0 and golf.firstShot and player:isLoaded() then
            if golf.mode == 1 then
                showBallTrajectory(player:getPos() + (player:getLookDir()):normalize())
            elseif golf.mode == 2 then
                showBallTrajectory(player:getPos() + (player:getLookDir().x_z):normalize())
            end

        elseif golf.toggleTrajectory and showBallTrajectoryInterval == 0 and player:isLoaded() then
            showBallTrajectory(landPos)
        end

        showBallTrajectoryInterval = showBallTrajectoryInterval < 2 and showBallTrajectoryInterval + 1 or 0


        --String for the power indicator bar
        local powerIndicator = ""

        for i = 1, ball.launchSpeed.clamp[2] do
            powerIndicator = i > ball.launchSpeed.value and powerIndicator .. "□" or powerIndicator .. "■"
        end
        
        --Not display GUI when 
        if golf.mode ~= 0 then
            indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = golf.shotCount == 0 and "" or golf.shotCount == 1 and tostring(golf.shotCount) .. " shot taken\n\n" or tostring(golf.shotCount) .. " shots taken\n\n", bold = true, italic = true, color = golfGUIColor}, {text = "Power\n", color = "white"}, {text = powerIndicator, color = golfGUIColor}, {text = golf.firstShot and "\n\n[ALT] + [LClick] to swing\n[ALT] + [RClick] to toggle Guidelines\n\n/golf help for all commands" or "", color = "white"}}))
        else
            indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = golf.shotCount == 0 and "" or golf.shotCount == 1 and tostring(golf.shotCount) .. " shot taken\n\n" or tostring(golf.shotCount) .. " shots taken\n\n", bold = true, italic = true, color = golfGUIColor}, {text = player:getHeldItem(false):getName() ~= "Flag" and "Golf club not equipped!\n" or "Cannot place flags during a game!\n", color = "white"}}))
        end
    end

    if golf.sequence == 2 then
        if not ball.launched and player:isLoaded() then    --On initialization of sequence 2
            ball.launched = true     
            step = 0
            golf.shotCount = golf.shotCount + 1
            
            if golf.mode == 1 then
                ball.origin.angle = player:getLookDir()
                ball.origin.direction = (ball.origin.angle.x_z):normalize()
                ball.origin.pos = golf.firstShot and player:getPos() + ball.origin.direction + vec(0, 0.25, 0) or landPos
                
                m, c = math.tan(math.rad((ball.origin.angle.y * 90))), ball.origin.pos.y

                if ballFlightPathCalculation(m, ball.launchSpeed.value) == nil then return end
                
                landDistance = ballFlightPathCalculation(m, ball.launchSpeed.value)

            elseif golf.mode == 2 then
                ball.origin.angle = (player:getLookDir().x_z):normalize()
                ball.origin.direction = ball.origin.angle
                ball.origin.pos = golf.firstShot and player:getPos() + ball.origin.direction + vec(0, 0.25, 0) or landPos + ball.origin.direction 

                ball.launchSpeed.value = ball.launchSpeed.value / 2

                landDistance = distanceCalculation(ball.origin.pos, ball.origin.pos + ball.origin.direction * ball.launchSpeed.value)
            end
            
            pings.syncBallPos(ball.origin.pos)
            pings.syncBallOriginPos(ball.origin.pos, m, c, ball.launchSpeed.clamp, ball.launchSpeed.value)
            pings.syncLandDistance(landDistance)

            host:swingArm()

            golf.firstShot = false
        elseif player:isLoaded() then
            checkBallFlag(ball.currentPos)
            checkBallHitWall(ball.currentPos, ball.origin.direction)    --Unreliable! fix asap

            --Check for ball land events
            if (golf.mode == 1 and (checkBallGrounded(ball.currentPos) or checkBallObstacle(ball.currentPos, ball.origin.direction))) or (golf.mode == 2 and step == landDistance or checkBallObstacle(ball.currentPos, ball.origin.direction)) then 
                golf.sequence = 3 
                pings.syncSequence(3)

                ball.currentPos.y = golf.mode == 1 and ball.currentPos.y + 1.25 or ball.currentPos.y

                landPos = vec(ball.currentPos.x, math.floor(ball.currentPos.y + 1) - 0.5, ball.currentPos.z)

                pings.syncLandPos(landPos)
                pings.syncBallPos(landPos)

                if host:isHost() then
                    sounds["block.note_block.harp"]:setSubtitle(toJson({{text = "Your golfball landed!", bold = true, color = golfGUIColor}})):setPos(player:getPos()):setVolume(0.7):setPitch(1.2):play() 
                end
            return end


            indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = golf.shotCount == 0 and "" or golf.shotCount == 1 and tostring(golf.shotCount) .. " shot taken\n\n" or tostring(golf.shotCount) .. " shots taken\n\n", bold = true, italic = true, color = golfGUIColor}, {text = "Power\n", color = "white"}, {text = tostring(ball.launchSpeed.value), color = golfGUIColor}, {text = "\nDistance\n", color = "white"}, {text = tostring(math.floor(distanceCalculation(ball.origin.pos, ball.currentPos) * 100) / 100)}, {text = "m"}}))
            
            if golf.mode == 1 and ballFlightPositionCalculation(step, m, ball.launchSpeed.value, c) == nil then return end

            if golf.mode == 1 then
                ball.currentPos = vec(ball.origin.pos.x + ball.origin.direction.x * step, ballFlightPositionCalculation(step, m, ball.launchSpeed.value, c), ball.origin.pos.z + ball.origin.direction.z * step)
            elseif golf.mode == 2 then
                ball.currentPos = vec(ball.origin.pos.x + ball.origin.direction.x * step, ball.origin.pos.y + ball.origin.direction.y * step, ball.origin.pos.z + ball.origin.direction.z * step)  

                ball.currentPos.y = not checkBallGrounded(ball.currentPos) and ball.currentGround + 1.25 or ball.currentPos.y
            end
            

            step = ((golf.mode == 1 and not checkBallGrounded(ball.currentPos)) or (golf.mode == 2 and step < landDistance)) and step + landDistance / (ball.launchSpeed.value * 4) or landDistance
            
            particles:newParticle(ballParticle, ball.currentPos)
        end      
    end

    if golf.sequence == 3 then
        indicatorText:setText(toJson({{text = golf.GUIHeader .. "\n\n", bold = true, color = golfGUIColor}, {text = golf.shotCount == 0 and "" or golf.shotCount == 1 and tostring(golf.shotCount) .. " shot taken\n\n" or tostring(golf.shotCount) .. " shots taken\n\n", bold = true, italic = true, color = golfGUIColor}, {text = "Go to your golfball to proceed!\n", color = "white"}, {text = string.gsub(tostring(vec(math.floor(landPos.x * 100) / 100, math.floor(landPos.y * 100) / 100, math.floor(landPos.z * 100) / 100)), "[{}]", "")}}))
        particles:newParticle(ballParticle, landPos)
        
        --Wait for player to go near the ball
        if player:isLoaded() and distanceCalculation(player:getPos(), landPos) < 4 then
            pings.syncLandPos(landPos)
            pings.syncBallPos(landPos)
            
            --Soft reset, only puts sequence to 1 and keeps the ball's current position
            pings.resetSequence(false)

            if host:isHost() then
                sounds["block.note_block.harp"]:setSubtitle(toJson({{text = "You arrived at your golfball!", bold = true, color = golfGUIColor}})):setPos(player:getPos()):setVolume(0.7):setPitch(0.8):play()
            end
        end
    end

    if golf.sequence == 4 then
        if not golf.inTheHole and player:isLoaded() then    --On initialization of sequence 4
            golf.inTheHole = true

            for _ = 1, 15 do
                local dir = math.random() * math.pi * 2
                particles["firework"]
                    :pos(landPos + vec(0, math.random() * 1.3,0))
                    :velocity(vec(math.cos(dir), math.random(10,150)/100, math.sin(dir)) * 0.5)
                    :spawn()
            end
            sounds["entity.firework_rocket.blast"]:setSubtitle(player:getName() .. "'s golfball is in the hole"):setPos(landPos):setVolume(0.6):setPitch(0.6):play()

            if host:isHost() then
                sounds["ui.toast.challenge_complete"]:setSubtitle(toJson({{text = "In the Hole!", bold = true, color = golfGUIColor}})):setPos(player:getPos()):setVolume(0.7):setPitch(1):play() 
            end
        end

        indicatorText:setText(toJson({{text = golfGUITitle .. "\n\n", bold = true, color = golfGUIColor}, {text = golf.shotCount == 1 and tostring(golf.shotCount) .. " shot taken in total" or tostring(golf.shotCount) .. " shots taken in total", bold = true, italic = true, color = golfGUIColor}, {text = "\n\nIn the hole!", color = "white"}, {text = "\n\n[ALT] + [LClick] to reset", bold = true, italic = false, color = "white"}}))
    end

    if golf.sequence == 5 then
        --Hard reset, resets everything and puts the game to the initial state
        pings.resetSequence(true)
    end
end


---@param msg string
function events.chat_send_message(msg)

    if msg and msg:find("/" .. "golf") then
        
        local command, func = "", ""
        command = string.sub(msg, 7, #msg)

        if string.sub(command, 1, 2) == ("tp") then
            func = string.sub(command, 5, #command)
            if ball.currentPos ~= vec(0, 0, 0) and pings.superTeleport ~= nil then
                pings.superTeleport(ball.currentPos + vec(0, 1, 0))
            end
        return nil end
        
        if string.sub(command, 1, 5) == ("reset") then
            pings.resetSequence(true)
            host:actionbar(toJson({{text = "GOLF reset!", bold = true, color = golfGUIColor}})) 
        return nil end

        if string.sub(command, 1, 6) == ("remove") then
            pings.syncFlagRemoval()
            
            host:actionbar(toJson({{text = "All Flags removed!", bold = true, color = golfGUIColor}})) 

            if host:isHost() then
                sounds["block.iron_trapdoor.open"]:setSubtitle(toJson({{text = "All Flags removed!", bold = true, color = golfGUIColor}})):setPos(player:getPos()):play():setVolume(0.7):setPitch(1.2) 
            end
        return nil end
        
        if string.sub(command, 1, 4) == ("help") then
            if host:isHost() then
                host:setChatMessage(1, toJson({{text = "\n" .. golf.GUIHeader .. "\n\n\n", bold = true, color = golfGUIColor}, {text = "Renamed items needed\n\n", color = "white"}, {text = "  'Driver' / 'Hybrid' / 'Wedge'  ->  Long range shots\n  *Must look above 0 Degrees to use!\n\n  'Putter'  ->  Close range straight shots\n  'Flag'  ->  Use to place down flags/holes\n\n", color = "white", bold = false, italic = true}, {text = "Keybinds\n\n", color = "white"}, {text = "  [ALT] + [LClick]  ->  Swings golf club/places flag\n  [ALT] + [RClick]  ->  Toggles guidelines\n\n", color = "white", bold = false, italic = true}, {text = "Available Commands\n\n", color = "white"}, {text = "  /golf help  ->  Returns all commands\n  /golf reset  ->  Resets the game, does NOT reset your flags\n  /golf remove  ->  Removes ALL of your flags\n  /golf tp  ->  Teleports you to your golfball", color = "white", bold = false, italic = true}}), vec(0, 0, 0))
            end
        return nil end

        if flags.place.sequence == 2 and golf.sequence == 0 then
            func = string.sub(command, 1, #command)
            pings.addToPersonalFlags(func, flags.place.potentialFlagPos, flags.place.potentialFlagRot)

            host:actionbar(toJson({{text = "Flag ", bold = true, color = golfGUIColor}, {text = func, color = "white"}, {text = " set!", color = golfGUIColor}})) 

            flags.place.sequence = 1
            pings.syncFlagSequence(flags.place.sequence)
        return nil end

        host:actionbar(toJson({{text = "Command not recognized!", bold = true, color = golfGUIColor}})) 
    end
    return msg
end

--#endregion

