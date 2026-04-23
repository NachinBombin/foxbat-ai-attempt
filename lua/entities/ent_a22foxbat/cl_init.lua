include( "shared.lua" )

-- rotor bone, always max RPM, blur disc bodygroup
local PROP_BONE = 9
local PROP_RPM  = 700

local _rotorAcc = 0

function ENT:OnFrame()
	local ft = RealFrameTime()

	-- rotor
	_rotorAcc = _rotorAcc + PROP_RPM * ft
	local rot = Angle( 0, 0, _rotorAcc )
	rot:Normalize()
	self:ManipulateBoneAngles( PROP_BONE, rot )

	-- control surfaces
	local s   = self:GetSteer()
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

	-- landing gear
	self._smGear = self._smGear and self._smGear + (30 * (1 - self:GetLandingGear()) - self._smGear) * ft * 8 or 0
	self:ManipulateBoneAngles( 1, Angle( 0, 30 - self._smGear, 0 ) )
	self:ManipulateBoneAngles( 2, Angle( 0, 30 - self._smGear, 0 ) )
end
