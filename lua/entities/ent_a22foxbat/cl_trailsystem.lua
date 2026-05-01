-- ============================================================
-- TRAIL SYSTEM  --  ent_a22foxbat (MiG-25 Foxbat)
-- Always active from spawn. All emission points run at all times.
-- Tier drives color + size: white vapor -> dense black smoke.
-- Unique hook/function names - no collision with other addons.
-- ============================================================

local TRAIL_MATERIAL = Material( "trails/smoke" )

local SAMPLE_RATE = 0.025  -- seconds between samples (40fps)

-- ============================================================
-- EMISSION POINTS  (model-local offsets for MiG-25 Foxbat)
-- Burst FX wingtips confirmed at X=±90, fuselage Y=±90.
-- Twin engines sit side-by-side at the rear.
-- ============================================================
local TRAIL_POSITIONS = {
    Vector(  18, -85,  -6 ),   -- right engine exhaust nozzle
    Vector( -18, -85,  -6 ),   -- left engine exhaust nozzle
    Vector(  90,  10,  -3 ),   -- right wingtip
    Vector( -90,  10,  -3 ),   -- left wingtip
}

-- ============================================================
-- TIER CONFIG  (all emission points share the same tier)
-- Tier 0 = 100% HP  ->  white vapor, always visible.
-- Tier 3 = dead     ->  dense black smoke from all points.
-- ============================================================
local TIER_CONFIG = {
    [0] = { r = 255, g = 255, b = 255, a = 108, startSize = 20, endSize =  3, lifetime = 4 },
    [1] = { r = 160, g = 160, b = 160, a = 148, startSize = 32, endSize =  7, lifetime = 5 },
    [2] = { r =  50, g =  50, b =  50, a = 192, startSize = 48, endSize = 13, lifetime = 6 },
    [3] = { r =  10, g =  10, b =  10, a = 222, startSize = 66, endSize = 20, lifetime = 8 },
}

local FoxbatTrails = {}

-- ============================================================
-- PUBLIC: called from net.Receive in cl_init.lua
-- ============================================================
function FoxbatTrailSystem_SetTier( entIndex, tier )
    local state = FoxbatTrails[entIndex]
    if not state then return end
    state.tier = tier
end

-- ============================================================
-- INTERNALS
-- ============================================================
local function EnsureRegistered( entIndex )
    if FoxbatTrails[entIndex] then return end
    local trails = {}
    for i = 1, #TRAIL_POSITIONS do
        trails[i] = { positions = {} }
    end
    FoxbatTrails[entIndex] = {
        tier       = 0,
        nextSample = 0,
        trails     = trails,
    }
end

local function DrawBeam( positions, cfg )
    local n = #positions
    if n < 2 then return end

    local Time = CurTime()
    local lt   = cfg.lifetime

    for i = n, 1, -1 do
        if Time - positions[i].time > lt then
            table.remove( positions, i )
        end
    end

    n = #positions
    if n < 2 then return end

    render.SetMaterial( TRAIL_MATERIAL )
    render.StartBeam( n )
    for _, pd in ipairs( positions ) do
        local Scale = math.Clamp( (pd.time + lt - Time) / lt, 0, 1 )
        local size  = cfg.startSize * Scale + cfg.endSize * (1 - Scale)
        render.AddBeam( pd.pos, size, pd.time * 50,
            Color( cfg.r, cfg.g, cfg.b, cfg.a * Scale * Scale ) )
    end
    render.EndBeam()
end

-- ============================================================
-- THINK: sample world positions for every emission point
-- ============================================================
hook.Add( "Think", "bombin_foxbat_trails_update", function()
    local Time = CurTime()

    for _, ent in ipairs( ents.FindByClass( "ent_a22foxbat" ) ) do
        EnsureRegistered( ent:EntIndex() )
    end

    for entIndex, state in pairs( FoxbatTrails ) do
        local ent = Entity( entIndex )
        if not IsValid( ent ) then
            FoxbatTrails[entIndex] = nil
            continue
        end

        if Time < state.nextSample then continue end
        state.nextSample = Time + SAMPLE_RATE

        local pos = ent:GetPos()
        local ang = ent:GetAngles()

        for i, trail in ipairs( state.trails ) do
            local wpos = LocalToWorld( TRAIL_POSITIONS[i], Angle(0,0,0), pos, ang )
            table.insert( trail.positions, { time = Time, pos = wpos } )
            table.sort( trail.positions, function( a, b ) return a.time > b.time end )
        end
    end
end )

-- ============================================================
-- DRAW: render beams using current tier config
-- ============================================================
hook.Add( "PostDrawTranslucentRenderables", "bombin_foxbat_trails_draw", function( bDepth, bSkybox )
    if bSkybox then return end

    for _, state in pairs( FoxbatTrails ) do
        local cfg = TIER_CONFIG[ state.tier ] or TIER_CONFIG[0]
        for _, trail in ipairs( state.trails ) do
            DrawBeam( trail.positions, cfg )
        end
    end
end )
