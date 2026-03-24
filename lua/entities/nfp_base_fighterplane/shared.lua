-- NFP Base Fighter Plane
-- Sits between ent_a22foxbat and lvs_base_fighterplane.
-- Provides CalcAero, ApproachTargetAngle, PhysicsSimulate with NFP naming.
-- ent_a22foxbat inherits this; this inherits lvs_base_fighterplane.

ENT.Type  = "anim"
ENT.Base  = "lvs_base_fighterplane"   -- chains into full LVS physics stack

ENT.PrintName      = "NFP Base Fighter Plane"
ENT.Author         = "NachinBombin"
ENT.Spawnable      = false
ENT.AdminSpawnable = false
