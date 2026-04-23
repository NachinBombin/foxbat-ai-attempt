include( "shared.lua" )

local PROP_BONE = 9
local PROP_RPM  = 700

function ENT:OnFrame()
	self._rotorAcc = ( self._rotorAcc or 0 ) + PROP_RPM * RealFrameTime()
	local rot = Angle( 0, 0, self._rotorAcc )
	rot:Normalize()
	self:ManipulateBoneAngles( PROP_BONE, rot )
end
