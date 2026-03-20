--[[

   ___|   |     _ _|  __ \   ____| 
 \___ \   |       |   |   |  __|   
       |  |       |   |   |  |     
 _____/  _____| ___| ____/  _____| 
                                   
    ver. 2.0.1                            
    Made by @jeungbeen

]]--


--#region "Config"
local slideParticle = ""
local slideSound = "minecraft:block.powder_snow.step"

--How fast the maximum velocity is
local slideAmount = 2.4
--How much is subtracted from slideAmount each tick (you could probably lerp this!)
local slideDuration = 0.3

local slideAnimation = animations.model.slide

--Which priority the slide animation gets (to cancel the walk animation)
local slideAnimationPriority = 5

--#endregion


--#region "Implementation"
local slideInit = true
local slideQueued = false
local sliding = false

local forwardVel = 0
local slideAmountSaved = slideAmount

local slideKey = keybinds:newKeybind(
  "Slide Keybind",
  "key.keyboard.c",
  false
)

slideKey:setOnPress(function()
    slideQueued = not slideQueued 

end)

slideAnimation:setPriority(slideAnimationPriority)

function slideInteraction(state)
    sliding = state
    slideAnimation:setPlaying(state)

    slideAmount = state and slideAmount - slideDuration or slideAmountSaved

    if state then return end

    slideQueued, slideInit = false, true
end

function events.tick()
    if player:isLoaded() and host:isHost() then
        forwardVel = player:getVelocity():dot((player:getLookDir().x_z):normalize())
        
        if slideQueued then
            if player:isOnGround() and forwardVel > 0.1  then
                if slideInit then
                    slideInit = false
                    pings.syncSlide(true)
                end
                slideInteraction(true)
                cpieSlide()
            
            elseif player:isOnGround() or slideAmount <= 0.2 or (not slideQueued and not slideInit or host:isJumping() and sliding) then
                slideInteraction(false)
                pings.syncSlide(false)
            end
        else
            if not sliding then return end
            pings.syncSlide(false)
        end
    end 

    if sliding and player:isLoaded() and slideParticle ~= "" then
        for _ = 1, 3 do
            local pos = player:getPos() + vec(1.2 * (math.random() - 0.5), 0.2 * (math.random() - 0.5), math.random() - 0.5)
            particles:newParticle(slideParticle, pos + (player:getLookDir().x_z):normalize())
        end
    end
end

function pings.syncSlide(state)
    slideInteraction(state)
    slideAnimation:setPlaying(state)
    if state and player:isLoaded() then
        sounds[slideSound]:setSubtitle(player:getName() .. " slides"):setPos(player:getPos()):play():setVolume(0.5):setPitch(0.5)
    end
end

function cpieSlide()
    if player:isLoaded() then
        if silly then
            silly:setVelocity(player:getLookDir() * vec(forwardVel * slideAmount, 0, forwardVel * slideAmount))
        end
    end
end


--#endregion