include( "shared.lua" )

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

local FOXBAT_COLOR = Color( 18, 18, 18, 255 )  -- deep black

-- ============================================================
-- SPAWN
-- ============================================================

function ENT:OnSpawn()
	self:RegisterTrail( Vector(-25,-219,84), 0, 20, 2, 1000, 600 )
	self:RegisterTrail( Vector(-25, 219,84), 0, 20, 2, 1000, 600 )

	self:SetRenderMode( RENDERMODE_TRANSCOLOR )
	self:SetColor( FOXBAT_COLOR )

	self._foxbatCurRPM = 0
	self._foxbatRPM    = 0
end

-- ============================================================
-- DRAW
-- ============================================================

function ENT:Draw()
	self:DrawModel()
end

-- ============================================================
-- PER-FRAME
-- ============================================================

function ENT:OnFrame()
	local nfpFT = RealFrameTime()
	self:NFP_AnimControlSurfaces( nfpFT )
	self:NFP_AnimLandingGear( nfpFT )
	self:FoxbatAnimRotor( nfpFT )
end

-- ============================================================
-- ROTOR  (self-contained, cruise/dive RPM via NWBool)
-- ============================================================

function ENT:FoxbatAnimRotor( frametime )
	if not self._foxbatCurRPM then
		self._foxbatCurRPM = 0
		self._foxbatRPM    = 0
	end

	local targetRPM = self:GetNWBool( "FoxbatDiving", false )
		and PROP_RPM_DIVE
		or  PROP_RPM_CRUISE

	self._foxbatCurRPM = self._foxbatCurRPM
		+ ( targetRPM - self._foxbatCurRPM ) * frametime * 2

	local physRot = self._foxbatCurRPM < PROP_BLUR_THRESH

	self._foxbatRPM = self._foxbatRPM
		+ self._foxbatCurRPM * frametime * ( physRot and 4 or 1 )

	local rot = Angle( 0, 0, self._foxbatRPM )
	rot:Normalize()
	self:ManipulateBoneAngles( PROP_BONE, rot )
	self:SetBodygroup( PROP_BODYGROUP, physRot and 0 or 1 )
end

-- ============================================================
-- CONTROL SURFACES
-- ============================================================

function ENT:NFP_AnimControlSurfaces( nfpFrametime )
	local nfpFT    = nfpFrametime * 10
	local nfpSteer = self:GetSteer()

	local nfpPitch = -nfpSteer.y * 30
	local nfpYaw   = -nfpSteer.z * 20
	local nfpRoll  = math.Clamp( -nfpSteer.x * 60, -30, 30 )

	self._nfpSmPitch = self._nfpSmPitch and self._nfpSmPitch + (nfpPitch - self._nfpSmPitch) * nfpFT or 0
	self._nfpSmYaw   = self._nfpSmYaw   and self._nfpSmYaw   + (nfpYaw   - self._nfpSmYaw)   * nfpFT or 0
	self._nfpSmRoll  = self._nfpSmRoll  and self._nfpSmRoll  + (nfpRoll  - self._nfpSmRoll)  * nfpFT or 0

	self:ManipulateBoneAngles( 3, Angle( 0,  self._nfpSmRoll,  0 ) )
	self:ManipulateBoneAngles( 4, Angle( 0, -self._nfpSmRoll,  0 ) )
	self:ManipulateBoneAngles( 6, Angle( 0, -self._nfpSmPitch, 0 ) )
	self:ManipulateBoneAngles( 5, Angle( self._nfpSmYaw, 0, 0 ) )
end

-- ============================================================
-- LANDING GEAR
-- ============================================================

function ENT:NFP_AnimLandingGear( nfpFrametime )
	self._nfpSmGear = self._nfpSmGear and self._nfpSmGear + (30 * (1 - self:GetLandingGear()) - self._nfpSmGear) * nfpFrametime * 8 or 0
	self:ManipulateBoneAngles( 1, Angle( 0, 30 - self._nfpSmGear, 0 ) )
	self:ManipulateBoneAngles( 2, Angle( 0, 30 - self._nfpSmGear, 0 ) )
end
