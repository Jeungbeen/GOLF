--[[

   ___|   |   |   _ \   ____|   _ \ __ __|  ____|  |      ____|   _ \    _ \    _ \ __ __| 
 \___ \   |   |  |   |  __|    |   |   |    __|    |      __|    |   |  |   |  |   |   |   
       |  |   |  ___/   |      __ <    |    |      |      |      ___/   |   |  __ <    |   
 _____/  \___/  _|     _____| _| \_\  _|   _____| _____| _____| _|     \___/  _| \_\  _|   
                                                                                           
    ver. 0.2.1                             
    Made by @jeungbeen

]]--


--#region "Config"
local warpSound = "item.firecharge.use"
local warpParticle = "poof"

--#endregion


--#region "Implementation"
function pings.superTeleport(destination)
    if not player:isLoaded() then return end
    local interval = 0

    teleportSequence = function()
        if interval <= 2 then
            if interval == 0 and player:isLoaded() then
                for _ = 1, 7 do
                    local dir = math.random() * math.pi * 2
                    particles[warpParticle]
                        :pos(player:getPos() + vec(0, math.random() * 1.3,0))
                        :velocity(vec(math.cos(dir), math.random(10,150)/100, math.sin(dir)) * 0.05)
                        :spawn()
                end
                
                sounds[warpSound]:setSubtitle(player:getName() .. " teleports"):setPos(player:getPos()):play():setVolume(0.3):setPitch(1.5)

                if silly then
                    silly:setVel(vec(0, 0, 0))
                    silly:setPos(vec(player:getPos().x, 384, player:getPos().z))
                    silly:setVel(vec(0, 0, 0))
                end
            end

            if interval == 1 and player:isLoaded() then
                if silly then
                    silly:setVel(vec(0, 0, 0))
                    silly:setPos(vec(destination.x, 384, destination.z))
                    silly:setVel(vec(0, 0, 0))
                end
            end

            if interval == 2 and player:isLoaded() then
                if silly then
                    silly:setVel(vec(0, 0, 0))
                    silly:setPos(vec(player:getPos().x, destination.y, player:getPos().z))
                    silly:setVel(vec(0, 0, 0))
                end

                sounds[warpSound]:setSubtitle(player:getName() .. " teleports"):setPos(destination):play():setVolume(0.3):setPitch(1.5)

                for _ = 1, 7 do
                    local dir = math.random() * math.pi * 2
                    particles[warpParticle]
                        :pos(destination + vec(0, math.random() * 1.3,0))
                        :velocity(vec(math.cos(dir), math.random(10,150)/100, math.sin(dir)) * 0.05)
                        :spawn()
                end
            end

            interval = interval + 1
        else
            events.TICK:remove("TeleportSequence")
        end
    end

    events.TICK:register(teleportSequence, "TeleportSequence")

end

--#endregion
