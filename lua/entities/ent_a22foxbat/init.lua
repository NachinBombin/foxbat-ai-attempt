AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
include("sv_foxbat_ai.lua")

local FOXBAT_PASS_SOUNDS = {
    "lvs_darklord/rotors/rotor_loop_close.wav",
    "lvs_darklord/rotors/rotor_loop_dist.wav",
}

local FOXBAT_ENGINE_START_SOUND = "lvs_darklord/mi_engine/mi24_engine_start_exterior.wav"
local FOXBAT_ENGINE_LOOP_SOUND  = "^lvs_darklord/rotors/rotor_loop_close.wav"
local FOXBAT_ENGINE_DIST_SOUND  = "^lvs_darklord/rotors/rotor_loop_dist.wav"

ENT.DIVE_Speed         = 1800
ENT.DIVE_TrackInterval = 0.1

local BELLY_BOMB_OFFSET = Vector(15, 0, -35)

function ENT:SpawnBellyBomb()
    local worldPos = self:LocalToWorld(BELLY_BOMB_OFFSET)
    local bomb = ents.Create("gb_bomb_sc250")
    if not IsValid(bomb) then
        self:FoxbatDebug("WARNING: could not create gb_bomb_sc250")
        return
    end

    bomb.IsOnPlane = true
    bomb:SetPos(worldPos)
    bomb:SetAngles(self:GetAngles())
    bomb:Spawn()
    bomb:Activate()
    bomb:Arm()
    bomb:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

    bomb.FoxbatAttached = true
    bomb.OnTakeDamage = function(bomb_self, dmginfo)
        if bomb_self.FoxbatAttached then return end
        return bomb_self.BaseClass.OnTakeDamage(bomb_self, dmginfo)
    end

    local weld = constraint.Weld(self, bomb, 0, 0, 0, true, true)

    self.FoxbatBellyBomb     = bomb
    self.FoxbatBellyBombWeld = weld
    self.FoxbatBombDetached  = false

    self:FoxbatDebug("Belly bomb attached, armed, and protected")
end

function ENT:DetachAndFireBellyBomb(pos)
    if self.FoxbatBombDetached then return end
    self.FoxbatBombDetached = true

    local bomb = self.FoxbatBellyBomb
    if not IsValid(bomb) then return end

    if IsValid(self.FoxbatBellyBombWeld) then
        self.FoxbatBellyBombWeld:Remove()
        self.FoxbatBellyBombWeld = nil
    end

    bomb.FoxbatAttached = nil
    bomb:SetCollisionGroup(COLLISION_GROUP_NONE)
    bomb:SetPos(pos)

    timer.Simple(0, function()
        if not IsValid(bomb) then return end
        bomb:ExplodeCorrectly()
    end)

    self:FoxbatDebug("Belly bomb detached and detonated at " .. tostring(pos))
end

function ENT:Initialize()
    self.FoxbatCenterPos    = self:GetVar("CenterPos",    self:GetPos())
    self.FoxbatCallDir      = self:GetVar("CallDir",      Vector(1,0,0))
    self.FoxbatLifetime     = self:GetVar("Lifetime",     40)
    self.FoxbatSpeed        = self:GetVar("Speed",        250)
    self.FoxbatOrbitRadius  = self:GetVar("OrbitRadius",  2500)
    self.FoxbatSkyHeightAdd = self:GetVar("SkyHeightAdd", 2500)

    self.DIVE_ExplosionDamage = self:GetVar("DIVE_ExplosionDamage", 350)
    self.DIVE_ExplosionRadius = self:GetVar("DIVE_ExplosionRadius", 600)

    if self.FoxbatCallDir:LengthSqr() <= 1 then self.FoxbatCallDir = Vector(1,0,0) end
    self.FoxbatCallDir.z = 0
    self.FoxbatCallDir:Normalize()

    local ground = self:FindGround(self.FoxbatCenterPos)
    if ground == -1 then
        -- FindGround failed: fall back to player Z + SkyHeightAdd
        -- so the plane still spawns somewhere sensible on open/void maps.
        local fallbackZ = self.FoxbatCenterPos.z
        for _, ply in pairs(player.GetAll()) do
            if ply:Alive() then
                fallbackZ = math.max(fallbackZ, ply:GetPos().z)
                break
            end
        end
        ground = fallbackZ
        self:FoxbatDebug("FindGround failed — using fallback Z " .. ground)
    end

    -- Safety: never spawn below the caller's Z.
    -- This catches maps where the ground trace hits void geometry deep underground.
    ground = math.max(ground, self.FoxbatCenterPos.z - 256)

    self.FoxbatSkyAlt  = ground + self.FoxbatSkyHeightAdd
    self.FoxbatDieTime = CurTime() + self.FoxbatLifetime

    local spawnPos = self.FoxbatCenterPos - self.FoxbatCallDir * 2000
    spawnPos = Vector(spawnPos.x, spawnPos.y, self.FoxbatSkyAlt)
    if not util.IsInWorld(spawnPos) then
        spawnPos = Vector(self.FoxbatCenterPos.x, self.FoxbatCenterPos.y, self.FoxbatSkyAlt)
    end
    if not util.IsInWorld(spawnPos) then
        -- Last resort: spawn directly above the caller
        spawnPos = self.FoxbatCenterPos + Vector(0, 0, self.FoxbatSkyHeightAdd)
        self:FoxbatDebug("Spawn fallback to caller + height: " .. tostring(spawnPos))
    end

    self:SetModel("models/blu/cessna.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
    self:SetPos(spawnPos)

    self:SetBodygroup(4, 1)
    self:SetBodygroup(3, 1)
    self:SetBodygroup(5, 2)

    self:SetNWInt("FoxbatHP",    200)
    self:SetNWInt("FoxbatMaxHP", 200)

    local ang = self.FoxbatCallDir:Angle()
    self:SetAngles(Angle(0, ang.y + 70, 0))
    self.FoxbatAng = self:GetAngles()

    self.FoxbatVisualRoll  = 0
    self.FoxbatVisualPitch = -4

    self.FoxbatPhysObj = self:GetPhysicsObject()
    if IsValid(self.FoxbatPhysObj) then
        self.FoxbatPhysObj:Wake()
        self.FoxbatPhysObj:EnableGravity(false)
    end

    sound.Play(FOXBAT_ENGINE_START_SOUND, spawnPos, 90, 100, 1.0)

    self.FoxbatRotorClose = CreateSound(self, FOXBAT_ENGINE_LOOP_SOUND)
    if self.FoxbatRotorClose then
        self.FoxbatRotorClose:SetSoundLevel(125)
        self.FoxbatRotorClose:ChangePitch(100, 0)
        self.FoxbatRotorClose:ChangeVolume(1.0, 0.5)
        self.FoxbatRotorClose:Play()
    end

    self.FoxbatRotorDist = CreateSound(self, FOXBAT_ENGINE_DIST_SOUND)
    if self.FoxbatRotorDist then
        self.FoxbatRotorDist:SetSoundLevel(125)
        self.FoxbatRotorDist:ChangePitch(100, 0)
        self.FoxbatRotorDist:ChangeVolume(1.0, 0.5)
        self.FoxbatRotorDist:Play()
    end

    self.FoxbatNextPassSound = CurTime() + math.Rand(5, 10)

    self.FoxbatDiving             = false
    self.FoxbatDiveTarget         = nil
    self.FoxbatDiveTargetPos      = nil
    self.FoxbatDiveNextTrack      = 0
    self.FoxbatDiveExploded       = false
    self.FoxbatDiveAimOffset      = Vector(0, 0, 0)
    self.FoxbatDiveCommitTime     = nil
    self.FoxbatDivePitchTelegraph = 0

    self.FoxbatDiveWobblePhase  = 0
    self.FoxbatDiveWobbleAmp    = 180
    self.FoxbatDiveWobbleSpeed  = 4.5

    self.FoxbatDiveWobblePhaseV  = math.Rand(0, math.pi * 2)
    self.FoxbatDiveWobbleAmpV    = 130
    self.FoxbatDiveWobbleSpeedV  = 3.1

    self.FoxbatDiveSpeedMin     = self.DIVE_Speed * 0.55
    self.FoxbatDiveSpeedCurrent = self.DIVE_Speed * 0.55
    self.FoxbatDiveSpeedLerp    = 0.018

    self:SetNWBool("FoxbatDiving", false)

    self.FoxbatBellyBomb     = nil
    self.FoxbatBellyBombWeld = nil
    self.FoxbatBombDetached  = false

    timer.Simple(0, function()
        if IsValid(self) then self:SpawnBellyBomb() end
    end)

    self:FoxbatDebug("Spawned at " .. tostring(spawnPos))
end

function ENT:OnTakeDamage(dmginfo)
    if self.FoxbatDiveExploded then return end
    if dmginfo:IsDamageType(DMG_CRUSH) then return end

    local hp = self:GetNWInt("FoxbatHP", 200) - dmginfo:GetDamage()
    self:SetNWInt("FoxbatHP", hp)
    if hp <= 0 then
        self:FoxbatDiveExplode(self:GetPos())
        return
    end

    self:FoxbatAIOnDamage(dmginfo)
end

function ENT:FoxbatDebug(msg)
    print("[A22 Foxbat] " .. tostring(msg))
end

function ENT:Think()
    local ct = CurTime()

    if ct >= self.FoxbatDieTime then self:Remove() return end

    if not self:IsInWorld() then
        self:FoxbatDebug("Out of world — removing")
        self:Remove()
        return
    end

    if not IsValid(self.FoxbatPhysObj) then
        self.FoxbatPhysObj = self:GetPhysicsObject()
    end
    if IsValid(self.FoxbatPhysObj) and self.FoxbatPhysObj:IsAsleep() then
        self.FoxbatPhysObj:Wake()
    end

    if ct >= self.FoxbatNextPassSound then
        sound.Play(
            table.Random(FOXBAT_PASS_SOUNDS),
            self:GetPos(), 100, math.random(96, 104), 1.0
        )
        self.FoxbatNextPassSound = ct + math.Rand(6, 12)
    end

    if self.FoxbatDiving then
        self:FoxbatUpdateDive(ct)
    else
        if self:FoxbatRunAI() then
            self:FoxbatCommitDive(ct)
        end
    end

    self:NextThink(ct)
    return true
end

function ENT:FoxbatCommitDive(ct)
    local target = self:FoxbatGetTarget()
    if not IsValid(target) then
        self:FoxbatDebug("DIVE: no valid target at commit — aborting")
        return
    end

    self.FoxbatDiving         = true
    self:SetNWBool("FoxbatDiving", true)
    self.FoxbatDiveTarget     = target
    self.FoxbatDiveTargetPos  = target:GetPos()
    self.FoxbatDiveNextTrack  = ct
    self.FoxbatDiveExploded   = false

    self.FoxbatDiveWobblePhase  = 0
    self.FoxbatDiveWobblePhaseV = math.Rand(0, math.pi * 2)
    self.FoxbatDiveSpeedCurrent = self.FoxbatDiveSpeedMin

    self.FoxbatDiveAimOffset = Vector(
        math.Rand(-400, 400),
        math.Rand(-400, 400),
        0
    )

    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    if IsValid(self.FoxbatBellyBomb) then
        self.FoxbatBellyBomb:SetCollisionGroup(COLLISION_GROUP_NONE)
    end

    if IsValid(self.FoxbatPhysObj) then
        self.FoxbatPhysObj:EnableGravity(false)
        self.FoxbatPhysObj:SetVelocity(Vector(0, 0, 0))
    end

    self:FoxbatDebug("DIVE: committed — aim offset " .. tostring(self.FoxbatDiveAimOffset))
end

function ENT:FoxbatUpdateDive(ct)
    if self.FoxbatDiveExploded then return end

    if ct >= self.FoxbatDiveNextTrack then
        if IsValid(self.FoxbatDiveTarget) and self.FoxbatDiveTarget:Alive() then
            local trackJitter = Vector(
                math.Rand(-120, 120),
                math.Rand(-120, 120),
                0
            )
            self.FoxbatDiveTargetPos = self.FoxbatDiveTarget:GetPos() + trackJitter
        end
        self.FoxbatDiveNextTrack = ct + self.DIVE_TrackInterval
    end

    if not self.FoxbatDiveTargetPos then self:Remove() return end

    local aimPos = self.FoxbatDiveTargetPos + self.FoxbatDiveAimOffset
    local myPos  = self:GetPos()
    local dir    = aimPos - myPos
    local dist   = dir:Length()

    if dist < 120 then
        self:FoxbatDiveExplode(myPos)
        return
    end

    dir:Normalize()

    self.FoxbatDiveSpeedCurrent = Lerp(
        self.FoxbatDiveSpeedLerp,
        self.FoxbatDiveSpeedCurrent,
        self.DIVE_Speed
    )

    local dt = FrameTime()

    self.FoxbatDiveWobblePhase  = self.FoxbatDiveWobblePhase  + self.FoxbatDiveWobbleSpeed  * dt
    self.FoxbatDiveWobblePhaseV = self.FoxbatDiveWobblePhaseV + self.FoxbatDiveWobbleSpeedV * dt

    local flatRight = Vector(-dir.y, dir.x, 0)
    if flatRight:LengthSqr() < 0.01 then flatRight = Vector(1, 0, 0) end
    flatRight:Normalize()

    local worldUp = Vector(0, 0, 1)
    local upPerp  = worldUp - dir * dir:Dot(worldUp)
    if upPerp:LengthSqr() < 0.01 then upPerp = Vector(0, 1, 0) end
    upPerp:Normalize()

    local wobbleScale  = math.Clamp(dist / 400, 0, 1)
    local wobbleOffset =
        flatRight * math.sin(self.FoxbatDiveWobblePhase)  * self.FoxbatDiveWobbleAmp  * wobbleScale +
        upPerp    * math.sin(self.FoxbatDiveWobblePhaseV) * self.FoxbatDiveWobbleAmpV * wobbleScale

    local newPos    = myPos + dir * self.FoxbatDiveSpeedCurrent * dt + wobbleOffset * dt
    local travelDir = newPos - myPos

    if travelDir:LengthSqr() > 0.01 then
        local faceAng = travelDir:GetNormalized():Angle()
        faceAng.r = 0
        self:SetAngles(faceAng)
        self.FoxbatAng = faceAng
    end

    local tr = util.TraceLine({
        start  = myPos,
        endpos = newPos,
        filter = self,
        mask   = MASK_SOLID,
    })

    if tr.Hit then
        self:FoxbatDiveExplode(tr.HitPos)
        return
    end

    self:SetPos(newPos)
    if IsValid(self.FoxbatPhysObj) then
        self.FoxbatPhysObj:SetPos(newPos)
        self.FoxbatPhysObj:SetVelocity(Vector(0, 0, 0))
    end
end

function ENT:FoxbatDiveExplode(pos)
    if self.FoxbatDiveExploded then return end
    self.FoxbatDiveExploded = true

    self:FoxbatDebug("DIVE: exploding at " .. tostring(pos))

    local ed1 = EffectData()
    ed1:SetOrigin(pos) ed1:SetScale(5) ed1:SetMagnitude(5) ed1:SetRadius(500)
    util.Effect("HelicopterMegaBomb", ed1, true, true)

    local ed2 = EffectData()
    ed2:SetOrigin(pos) ed2:SetScale(4) ed2:SetMagnitude(4) ed2:SetRadius(400)
    util.Effect("500lb_air", ed2, true, true)

    local ed3 = EffectData()
    ed3:SetOrigin(pos + Vector(0, 0, 60)) ed3:SetScale(3) ed3:SetMagnitude(3) ed3:SetRadius(300)
    util.Effect("500lb_air", ed3, true, true)

    sound.Play("weapon_AWP.Single",               pos, 145, 60, 1.0)
    sound.Play("ambient/explosions/explode_8.wav", pos, 140, 90, 1.0)

    util.BlastDamage(self, self, pos, self.DIVE_ExplosionRadius, self.DIVE_ExplosionDamage)

    self:DetachAndFireBellyBomb(pos)
    self:Remove()
end

-- FindGround: traces downward but rejects results that are
-- deeper than 8192 units below the call center, which catches
-- void geometry and map underside brushes.
function ENT:FindGround(centerPos)
    local startPos   = Vector(centerPos.x, centerPos.y, centerPos.z + 64)
    local endPos     = Vector(centerPos.x, centerPos.y, centerPos.z - 8192)
    local filterList = { self }
    local maxIter    = 0

    while maxIter < 100 do
        local tr = util.TraceLine({ start = startPos, endpos = endPos, filter = filterList })
        if tr.HitWorld then
            -- Sanity: hit must be below start but not absurdly deep
            if tr.HitPos.z < startPos.z and tr.HitPos.z > (centerPos.z - 8192) then
                return tr.HitPos.z
            else
                -- Hit something suspicious (void brush, skybox floor) — give up
                break
            end
        end
        if IsValid(tr.Entity) then
            table.insert(filterList, tr.Entity)
        else
            break
        end
        maxIter = maxIter + 1
    end

    return -1
end

function ENT:OnRemove()
    if self.FoxbatRotorClose then self.FoxbatRotorClose:Stop() end
    if self.FoxbatRotorDist  then self.FoxbatRotorDist:Stop()  end

    if not self.FoxbatBombDetached and IsValid(self.FoxbatBellyBomb) then
        self.FoxbatBellyBomb:Remove()
    end
end
