include( "shared.lua" )

-- ============================================================
-- PROPELLER CONFIG
-- ============================================================

local NFP_PROP_BONE        = 9
local NFP_PROP_RPM_CRUISE  = 700
local NFP_PROP_RPM_DIVE    = 200
local NFP_PROP_BLUR_THRESH = 470
local NFP_PROP_BODYGROUP   = 1

-- ============================================================
-- PAINT — solid black via color modulation
-- ============================================================

local NFP_COLOR_R = 0.07
local NFP_COLOR_G = 0.07
local NFP_COLOR_B = 0.07

-- ============================================================
-- INITIALIZE
-- ============================================================

function ENT:Initialize()
    self._nfpCurRPM   = 0
    self._nfpRotorAcc = 0

    -- Smoothed control surface values (driven from server angle delta)
    self._nfpSmPitch = 0
    self._nfpSmYaw   = 0
    self._nfpSmRoll  = 0

    -- Landing gear always retracted on this entity (no gear logic serverside)
    self._nfpSmGear  = 30
end

-- ============================================================
-- DRAW — called every render frame, replaces OnFrame
-- ============================================================

function ENT:Draw()
    local nfpFT = RealFrameTime()

    self:NFP_AnimRotor( nfpFT )
    self:NFP_AnimControlSurfacesFromAngle( nfpFT )

    -- Apply black color modulation before drawing
    render.SetColorModulation( NFP_COLOR_R, NFP_COLOR_G, NFP_COLOR_B )
    self:DrawModel()
    render.SetColorModulation( 1, 1, 1 )
end

-- ============================================================
-- ROTOR — fully self-contained, no LVS dependency
-- ============================================================

function ENT:NFP_AnimRotor( nfpFT )
    local nfpTargetRPM = self:GetNWBool( "NFP_Diving", false )
        and NFP_PROP_RPM_DIVE
        or  NFP_PROP_RPM_CRUISE

    -- Lerp RPM toward target
    self._nfpCurRPM = self._nfpCurRPM + ( nfpTargetRPM - self._nfpCurRPM ) * math.min( nfpFT * 2, 1 )

    local nfpPhysRot = self._nfpCurRPM < NFP_PROP_BLUR_THRESH

    -- Accumulate rotation angle
    self._nfpRotorAcc = ( self._nfpRotorAcc + self._nfpCurRPM * nfpFT * ( nfpPhysRot and 4 or 1 ) ) % 360

    self:ManipulateBoneAngles( NFP_PROP_BONE, Angle( 0, 0, self._nfpRotorAcc ) )
    self:SetBodygroup( NFP_PROP_BODYGROUP, nfpPhysRot and 0 or 1 )
end

-- ============================================================
-- CONTROL SURFACES — derived from entity's own angle velocity
-- No LVS GetSteer() needed.
-- ============================================================

function ENT:NFP_AnimControlSurfacesFromAngle( nfpFT )
    local nfpAngVel = self:GetPhysicsObject():IsValid()
        and self:GetPhysicsObject():GetAngleVelocity()
        or  Vector(0,0,0)

    -- Map angular velocity to surface deflections (degrees)
    local nfpTargetPitch = math.Clamp( -nfpAngVel.y * 0.08, -25, 25 )
    local nfpTargetYaw   = math.Clamp( -nfpAngVel.z * 0.06, -18, 18 )
    local nfpTargetRoll  = math.Clamp(  nfpAngVel.x * 0.10, -25, 25 )

    local nfpRate = math.min( nfpFT * 8, 1 )

    self._nfpSmPitch = self._nfpSmPitch + ( nfpTargetPitch - self._nfpSmPitch ) * nfpRate
    self._nfpSmYaw   = self._nfpSmYaw   + ( nfpTargetYaw   - self._nfpSmYaw   ) * nfpRate
    self._nfpSmRoll  = self._nfpSmRoll  + ( nfpTargetRoll  - self._nfpSmRoll  ) * nfpRate

    -- Ailerons (bones 3, 4)
    self:ManipulateBoneAngles( 3, Angle( 0,  self._nfpSmRoll,  0 ) )
    self:ManipulateBoneAngles( 4, Angle( 0, -self._nfpSmRoll,  0 ) )
    -- Elevator (bone 6)
    self:ManipulateBoneAngles( 6, Angle( 0, -self._nfpSmPitch, 0 ) )
    -- Rudder (bone 5)
    self:ManipulateBoneAngles( 5, Angle( self._nfpSmYaw, 0, 0 ) )
end
