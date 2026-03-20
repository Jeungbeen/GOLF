--[[
 _______  _______  ___      _______ 
|       ||       ||   |    |       |
|    ___||   _   ||   |    |    ___|
|   | __ |  | |  ||   |    |   |___ 
|   ||  ||  |_|  ||   |___ |    ___|
|   |_| ||       ||       ||   |    
|_______||_______||_______||___|   by Jeungbeen


    GSAnimBlend by GrandpaScout at https://github.com/GrandpaScout/GSAnimBlend
    JustLean2 by XanderCreates at https://github.com/xandercreates/JustLean2
    
--]]


--#region "Sanitization"
for _, m in pairs(figuraMetatables) do
    m.__metatable = false
end

--#endregion


--#region "Requires"
require("libraries/GSAnimBlend")

--#endregion


--#region "Avatar Configs"
avatar:store("color","#8CDB90")

vanilla_model.PLAYER:setVisible(false)
function events.render(_,context)
    models.model.root.Torso.Head:setVisible(not (renderer:isFirstPerson() and (context == "OTHER" or context=="RENDER")))
end

--#endregion

--#region "Implementation"
animations.model.slide:setBlendTime(2, 4)

--#endegion