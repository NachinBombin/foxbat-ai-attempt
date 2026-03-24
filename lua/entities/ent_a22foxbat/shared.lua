-- A22 Foxbat — entity identity
-- Inherits LVS fighter plane aerodynamics through nfp_base_fighterplane.
-- nfp_base_fighterplane inherits lvs_base_fighterplane -> lvs_base.
-- PhysicsSimulate drives all flight. This entity only sets _nfpAITargetAng.

ENT.Type           = "anim"
ENT.Base           = "nfp_base_fighterplane"   -- ← THE CRITICAL CHANGE

ENT.PrintName      = "A22 Foxbat"
ENT.Author         = "NachinBombin"
ENT.Information    = "Autonomous loiter munition. Cruises, dives on player contact."
ENT.Category       = "A22 Foxbat"

ENT.Spawnable      = false
ENT.AdminSpawnable = false

ENT.RenderGroup    = RENDERGROUP_OPAQUE

-- ============================================================
-- LVS flight tuning (read by nfp_base_fighterplane/init.lua CalcAero)
-- ============================================================
ENT.MaxThrust                  = 22       -- thrust units (LVS standard ~18-28)
ENT.TurnRatePitch              = 1.0
ENT.TurnRateYaw                = 0.4
ENT.TurnRateRoll               = 1.0
ENT.GravityTurnRatePitch       = 1.0
ENT.GravityTurnRateYaw         = 0.5
ENT.StallVelocity              = -200
ENT.StallForceMultiplier       = 1.0
ENT.StallForceMax              = 3.0
ENT.MaxPerfVelocity            = 1200
ENT.MaxVelocity                = 2200
ENT.MaxSlipAnglePitch          = 25
ENT.MaxSlipAngleYaw            = 15
ENT.WheelSteerAngle            = 25
ENT.ForceLinearMultiplier      = 1.0
ENT.ForceAngleMultiplier       = 1.0
ENT.ForceAngleDampingMultiplier = 1.0
