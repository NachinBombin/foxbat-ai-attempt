-- ============================================================
-- sv_foxbat_ai.lua   —   Foxbat standalone AI
-- 1:1 port of lvs_base_fighterplane/sv_ai.lua
-- No altitude forcing. No orbit. No spring. Pure LVS.
-- ============================================================

function ENT:FoxbatGetFilter()
    if istable(self._FoxbatFilter) then return self._FoxbatFilter end
    local filter = {}
    for _, ent in pairs(constraint.GetAllConstrainedEntities(self)) do
        if IsValid(ent) then table.insert(filter, ent) end
    end
    table.insert(filter, self)
    if IsValid(self.FoxbatBellyBomb) then
        table.insert(filter, self.FoxbatBellyBomb)
    end
    self._FoxbatFilter = filter
    return filter
end

function ENT:FoxbatInvalidateFilter()
    self._FoxbatFilter = nil
end

function ENT:FoxbatCanSee(otherEnt)
    if not IsValid(otherEnt) then return false end
    local origin  = self:LocalToWorld(self:OBBCenter())
    local filter  = self:FoxbatGetFilter()
    local PhysObj = otherEnt:GetPhysicsObject()
    local endpos  = IsValid(PhysObj)
        and otherEnt:LocalToWorld(PhysObj:GetMassCenter())
        or  otherEnt:LocalToWorld(otherEnt:OBBCenter())
    return util.TraceLine({ start = origin, endpos = endpos, filter = filter }).Entity == otherEnt
end

function ENT:FoxbatInFront(otherEnt, range)
    if not IsValid(otherEnt) then return false end
    range = range or 45
    if range >= 180 then return true end
    local dir = (otherEnt:GetPos() - self:GetPos()):GetNormalized()
    return math.deg(math.acos(math.Clamp(self:GetForward():Dot(dir), -1, 1))) < range
end

function ENT:FoxbatGetTarget()
    if (self._FoxbatNextCheck or 0) > CurTime() then
        return self._FoxbatLastTarget
    end
    self._FoxbatNextCheck = CurTime() + 2

    local myPos       = self:GetPos()
    local closest     = NULL
    local closestDist = 60000

    for _, ply in pairs(player.GetAll()) do
        if not ply:Alive() then continue end
        if ply:IsFlagSet(FL_NOTARGET) then continue end
        local dist = (ply:GetPos() - myPos):Length()
        if dist > closestDist then continue end
        local vehPod = ply:GetVehicle()
        local veh    = IsValid(vehPod) and vehPod.LVS and vehPod or NULL
        if IsValid(veh) and veh ~= self then
            if self:FoxbatCanSee(veh) then
                closest     = veh
                closestDist = dist
            end
        else
            if ply:IsLineOfSightClear(self) then
                closest     = ply
                closestDist = dist
            end
        end
    end

    for _, npc in pairs(ents.FindByClass("npc_*")) do
        if not IsValid(npc) or not npc:IsNPC() then continue end
        local dist = (npc:GetPos() - myPos):Length()
        if dist > closestDist then continue end
        if self:FoxbatCanSee(npc) then
            closest     = npc
            closestDist = dist
        end
    end

    self._FoxbatLastTarget = closest
    return closest
end

-- Stability: 1 for first 3 seconds after spawn (grace period),
-- then forward speed squared normalized.
-- This prevents the "just spawned = zero velocity = unstable" false positive.
function ENT:FoxbatGetStability()
    if (self._FoxbatStabilityFrozen or 0) > CurTime() then return 1 end
    local maxPerf = self.FoxbatSpeed * 1.2
    local fwdVel  = self:WorldToLocal(self:GetPos() + self:GetVelocity()).x
    -- Clamp minimum to 0.5 so a freshly spawned plane at rest
    -- is never treated as stalled by the AI priority stack.
    return math.max(math.Clamp(fwdVel / maxPerf, 0, 1) ^ 2, 0.5)
end

function ENT:FoxbatHitGround(alt)
    return alt < 80
end

function ENT:FoxbatSetHardLock(target)
    self._FoxbatHardLock     = target
    self._FoxbatHardLockTime = CurTime() + 4
end

function ENT:FoxbatGetHardLock()
    if (self._FoxbatHardLockTime or 0) < CurTime() then return NULL end
    return self._FoxbatHardLock
end

function ENT:FoxbatAIOnDamage(dmginfo)
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) then return end
    if not self:FoxbatInFront(attacker, IsValid(self:FoxbatGetTarget()) and 120 or 45) then
        self:FoxbatSetHardLock(attacker)
    end
end

function ENT:FoxbatDrivePhysics(phys, smTargetPos, throttle)
    local pos    = self:GetPos()
    local myDir  = self:GetForward():GetNormalized()
    local want   = (smTargetPos - pos):GetNormalized()
    local rate   = math.Clamp(1.5 * FrameTime(), 0, 1)
    local newDir = LerpVector(rate, myDir, want):GetNormalized()

    phys:SetVelocity(newDir * (self.FoxbatSpeed * math.Clamp(throttle, 0, 1)))

    local cross    = myDir:Cross(newDir)
    local rollSign = (cross.z > 0) and 1 or -1
    local bank     = math.Clamp(
        math.deg(math.asin(math.Clamp(cross:Length(), 0, 1))),
        0, 30
    )

    self.FoxbatVisualRoll  = Lerp(0.08, self.FoxbatVisualRoll or 0, bank * rollSign)
    self.FoxbatVisualPitch = Lerp(0.05, self.FoxbatVisualPitch or 0, newDir:Angle().p)

    self:SetAngles(Angle(self.FoxbatVisualPitch, newDir:Angle().y, self.FoxbatVisualRoll))
    self.FoxbatAng = self:GetAngles()
end

function ENT:FoxbatRunAI()
    local ct = CurTime()

    local RangerLength = 15000
    local mySpeed      = self:GetVelocity():Length()
    local MinDist      = 600 + mySpeed
    local StartPos     = self:LocalToWorld(self:OBBCenter())
    local TraceFilter  = self:FoxbatGetFilter()
    local myPos        = self:GetPos()
    local myDir        = self:GetForward()

    local FrontLeft   = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle(0,   20, 0)):Forward() * RangerLength })
    local FrontRight  = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle(0,  -20, 0)):Forward() * RangerLength })
    local FrontLeft2  = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle( 25,  65, 0)):Forward() * RangerLength })
    local FrontRight2 = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle( 25, -65, 0)):Forward() * RangerLength })
    local FrontLeft3  = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle(-25,  65, 0)):Forward() * RangerLength })
    local FrontRight3 = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle(-25, -65, 0)):Forward() * RangerLength })
    local FrontUp     = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle(-20,   0, 0)):Forward() * RangerLength })
    local FrontDown   = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles(Angle( 20,   0, 0)):Forward() * RangerLength })
    local TraceForward = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + myDir * RangerLength })
    local TraceDown   = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + Vector(0, 0, -RangerLength) })
    local TraceUp     = util.TraceLine({ start = StartPos, filter = TraceFilter, endpos = StartPos + Vector(0, 0,  RangerLength) })

    local cAvoid   = Vector(0, 0, 0)
    local myRadius = self:BoundingRadius()
    for _, v in pairs(ents.FindByClass("ent_a22foxbat")) do
        if v == self then continue end
        local Sub  = myPos - v:GetPos()
        local Dir  = Sub:GetNormalized()
        local Dist = Sub:Length()
        if Dist < (v:BoundingRadius() + myRadius + 200) then
            if math.deg(math.acos(math.Clamp(myDir:Dot(-Dir), -1, 1))) < 90 then
                cAvoid = cAvoid + Dir * (v:BoundingRadius() + myRadius + 500)
            end
        end
    end

    local TargetPos = (
        FrontLeft.HitPos   + FrontLeft.HitNormal   * MinDist + cAvoid * 8 +
        FrontRight.HitPos  + FrontRight.HitNormal  * MinDist + cAvoid * 8 +
        FrontLeft2.HitPos  + FrontLeft2.HitNormal  * MinDist +
        FrontRight2.HitPos + FrontRight2.HitNormal * MinDist +
        FrontLeft3.HitPos  + FrontLeft3.HitNormal  * MinDist +
        FrontRight3.HitPos + FrontRight3.HitNormal * MinDist +
        FrontUp.HitPos     + FrontUp.HitNormal     * MinDist +
        FrontDown.HitPos   + FrontDown.HitNormal   * MinDist +
        TraceUp.HitPos     + TraceUp.HitNormal     * MinDist +
        TraceDown.HitPos   + TraceDown.HitNormal   * MinDist
    ) / 10

    local alt      = (StartPos - TraceDown.HitPos):Length()
    local ceiling  = (StartPos - TraceUp.HitPos):Length()
    local WallDist = (StartPos - TraceForward.HitPos):Length()
    local Throttle = math.min(WallDist / math.max(mySpeed, 1), 1)

    -- Throttle floor: always maintain at least 60% thrust so the
    -- plane never stalls out on spawn or in open sky with no walls ahead.
    Throttle = math.max(Throttle, 0.6)

    local diveReady = false

    if alt < 600 or ceiling < 600 or
        WallDist < (MinDist * 3 * (math.deg(math.acos(math.Clamp(Vector(0,0,1):Dot(myDir), -1, 1))) / 180) ^ 2)
    then
        if ceiling < 600 then
            Throttle = 0
        else
            Throttle = 1
            if self:FoxbatHitGround(alt) then
                TargetPos.z = StartPos.z + 750
            else
                if self:FoxbatGetStability() < 0.5 then
                    TargetPos.z = StartPos.z + 1500
                end
            end
        end
    else
        if self:FoxbatGetStability() < 0.5 then
            TargetPos.z = StartPos.z + 600
        else
            if IsValid(self:FoxbatGetHardLock()) then
                TargetPos = self:FoxbatGetHardLock():GetPos() + cAvoid * 8
            else
                if alt > mySpeed then
                    local Target = self._FoxbatLastTarget

                    if not IsValid(self._FoxbatLastTarget)
                    or not self:FoxbatInFront(self._FoxbatLastTarget, 135)
                    or not self:FoxbatCanSee(self._FoxbatLastTarget) then
                        Target = self:FoxbatGetTarget()
                    end

                    if IsValid(Target) then
                        if self:FoxbatInFront(Target, 65) then
                            local T = ct + self:EntIndex() * 1337
                            TargetPos = Target:GetPos()
                                + cAvoid * 8
                                + Vector(0, 0, math.sin(T * 5) * 500)
                                + Target:GetVelocity() * math.abs(math.cos(T * 13.37)) * 5

                            Throttle = math.max(math.min(
                                (StartPos - TargetPos):Length() / math.max(mySpeed, 1),
                                1
                            ), 0.6)

                            if self:FoxbatCanSee(Target) then
                                diveReady = true
                            end
                        else
                            if alt > 6000 and self:FoxbatInFront(Target, 90) then
                                TargetPos = Target:GetPos()
                            end
                        end
                    end
                else
                    TargetPos.z = StartPos.z + 2000
                end
            end
        end
    end

    self._FoxbatSmTarget = self._FoxbatSmTarget
        and self._FoxbatSmTarget + (TargetPos - self._FoxbatSmTarget) * FrameTime()
        or  myPos

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        self:FoxbatDrivePhysics(phys, self._FoxbatSmTarget, Throttle)
    end

    if diveReady then
        if not self.FoxbatDiveCommitTime then
            self.FoxbatDiveCommitTime = ct + 1.0
            self:FoxbatDebug("AI: dive window open")
        end

        local frac = math.Clamp((ct - (self.FoxbatDiveCommitTime - 1.0)) / 1.0, 0, 1)
        self.FoxbatDivePitchTelegraph = frac * -60
        self:SetAngles(Angle(
            self.FoxbatDivePitchTelegraph,
            self.FoxbatAng.y,
            self.FoxbatVisualRoll
        ))

        if ct >= self.FoxbatDiveCommitTime then
            self.FoxbatDiveCommitTime     = nil
            self.FoxbatDivePitchTelegraph = 0
            self:FoxbatDebug("AI: dive committed")
            return true
        end
    else
        self.FoxbatDiveCommitTime     = nil
        self.FoxbatDivePitchTelegraph = 0
    end

    return false
end
