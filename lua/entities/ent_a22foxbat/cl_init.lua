include("shared.lua")

-- ============================================================
-- PROPELLER CONFIG
-- ============================================================

local PROP_BONE        = 9
local PROP_RPM_CRUISE  = 700
local PROP_RPM_DIVE    = 200
local PROP_BLUR_THRESH = 470
local PROP_BODYGROUP   = 1

-- ============================================================
-- TINT CONFIG
-- ============================================================

local FOXBAT_COLOR = Color(18, 18, 18, 255)   -- deep black tint

-- ============================================================
-- INITIALIZE
-- ============================================================

function ENT:Initialize()
    self._foxbatRPM    = 0
    self._foxbatCurRPM = 0

    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetColor(FOXBAT_COLOR)
end

-- ============================================================
-- DRAW
-- ============================================================

function ENT:Draw()
    self:DrawModel()
    self:FoxbatAnimRotor(RealFrameTime())
end

-- ============================================================
-- ROTOR ANIMATION
-- ============================================================

function ENT:FoxbatAnimRotor(frametime)
    local targetRPM = self:GetNWBool("FoxbatDiving", false)
        and PROP_RPM_DIVE
        or  PROP_RPM_CRUISE

    self._foxbatCurRPM = self._foxbatCurRPM
        + (targetRPM - self._foxbatCurRPM) * frametime * 2

    local physRot = self._foxbatCurRPM < PROP_BLUR_THRESH

    self._foxbatRPM = self._foxbatRPM
        + self._foxbatCurRPM * frametime * (physRot and 4 or 1)

    local rot = Angle(0, 0, self._foxbatRPM)
    rot:Normalize()
    self:ManipulateBoneAngles(PROP_BONE, rot)

    self:SetBodygroup(PROP_BODYGROUP, physRot and 0 or 1)
end
