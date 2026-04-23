include( "shared.lua" )

-- ============================================================
-- CONFIG
-- ============================================================

local PROP_BONE  = 9
local PROP_RPM   = 700   -- always max
local PROP_BG    = 1     -- bodygroup: 1 = blur disc

-- ============================================================
-- INITIALIZE (client)
-- ============================================================

function ENT:Initialize()
	self:SetRenderMode( RENDERMODE_TRANSCOLOR )
	self:SetColor( Color( 18, 18, 18, 255 ) )
	self._rotorAcc = 0
end

-- ============================================================
-- DRAW  — reapply tint every frame so it can never get stripped
-- ============================================================

function ENT:Draw()
	self:SetColor( Color( 18, 18, 18, 255 ) )
	self:DrawModel()
end

-- ============================================================
-- PER-FRAME
-- ============================================================

function ENT:OnFrame()
	local ft = RealFrameTime()
	self:NFP_AnimControlSurfaces( ft )
	self:NFP_AnimLandingGear( ft )

	-- rotor always at max RPM, always blur disc bodygroup
	self._rotorAcc = ( self._rotorAcc or 0 ) + PROP_RPM * ft
	local rot = Angle( 0, 0, self._rotorAcc )
	rot:Normalize()
	self:ManipulateBoneAngles( PROP_BONE, rot )
	self:SetBodygroup( PROP_BG, 1 )
end

-- ============================================================
-- CONTROL SURFACES
-- ============================================================

function ENT:NFP_AnimControlSurfaces( ft )
	local s = self:GetSteer()
	local fts = ft * 10

	local tPitch = -s.y * 30
	local tYaw   = -s.z * 20
	local tRoll  = math.Clamp( -s.x * 60, -30, 30 )

	self._smPitch = self._smPitch and self._smPitch + (tPitch - self._smPitch) * fts or 0
	self._smYaw   = self._smYaw   and self._smYaw   + (tYaw   - self._smYaw)   * fts or 0
	self._smRoll  = self._smRoll  and self._smRoll  + (tRoll  - self._smRoll)  * fts or 0

	self:ManipulateBoneAngles( 3, Angle( 0,  self._smRoll,  0 ) )
	self:ManipulateBoneAngles( 4, Angle( 0, -self._smRoll,  0 ) )
	self:ManipulateBoneAngles( 6, Angle( 0, -self._smPitch, 0 ) )
	self:ManipulateBoneAngles( 5, Angle( self._smYaw, 0, 0 ) )
end

-- ============================================================
-- LANDING GEAR
-- ============================================================

function ENT:NFP_AnimLandingGear( ft )
	self._smGear = self._smGear and self._smGear + (30 * (1 - self:GetLandingGear()) - self._smGear) * ft * 8 or 0
	self:ManipulateBoneAngles( 1, Angle( 0, 30 - self._smGear, 0 ) )
	self:ManipulateBoneAngles( 2, Angle( 0, 30 - self._smGear, 0 ) )
end
