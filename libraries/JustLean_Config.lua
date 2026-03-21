vanilla_model.PLAYER:setVisible(false)

local jl = require("libraries/JustLean")
local torso = jl.lean:new(
    models.model.root.Torso,      --ModelPart, change this accordingly
    { x = -20, y = -20 },         -- minimum Lean, can be either a table or Vector2. Change to suit your needs
    { x = 15, y = 20 },           -- maximum Lean, can be either a table or Vector2. Change to suit your needs.
    0.3,                          --speed,
    "inOutSine",               --interpolation method. Takes string, Valid vals: "linear", "inOutSine", "inOutCubic"
    true,                         --optional breathing idle
    true                          --enabled or not
)
local head = jl.head:new(       --optional
    models.model.root.Torso.Head, --ModelPart, change this accordingly
    0.6,                          --speed
    0.5,                            --Tilt. the lower the less
    "inOutSine",                 --interpolation method. Takes string, Valid vals: "linear", "inOutSine", "inOutCubic"
    {1,1},
    false,                         --Rotate Vanilla Head Instead (Will rotate modelpart if it follows vanilla head)
    torso,                          ---a result of moving the updating code. now it'll grab the __metatable
    true                          --enabled or not
)
local left_leg = jl.influence:new(
    models.model.root.LeftLeg, --modelpart
    0.5, --speed
    "linear", --interpolation
    "LEG_LEFT", --type (VALID: LEG_LEFT, LEG_RIGHT, ARM_LEFT, ARM_RIGHT)
    {1,0.5,0.1}, --strength
    torso, --used to grab active head or active lean modelpart rotations for use in its own rotation
    true --enabled
)

--you know the drill
local right_leg = jl.influence:new(
    models.model.root.RightLeg, 
    0.5, 
    "linear",
    "LEG_RIGHT",
    {1,0.5,0.1},
    torso,
    true
)

local left_arm = jl.influence:new(
    models.model.root.Torso.LeftArm,
    0.5,
    "linear",
    "ARM_LEFT",
    {0.7,0,0},
    torso,
    true
)

local right_arm = jl.influence:new(
    models.model.root.Torso.RightArm,
    0.5,
    "linear",
    "ARM_RIGHT",
    {0.7,0,0},
    torso,
    true
)