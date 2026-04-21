-- ============================================================
--  A22 Foxbat Control Panel  |  cl_a22foxbat_menu.lua
--  CLIENT autorun. Registers under "Bombin Support" tab.
-- ============================================================

if not CLIENT then return end

-- ----------------------------------------
--  Color Palette
-- ----------------------------------------
local col_bg_panel      = Color(0, 0, 0, 255)
local col_section_title = Color(210, 210, 210, 255)
local col_accent        = Color(0, 180, 255, 255)

-- ----------------------------------------
--  Helper: Colored Section Banner
-- ----------------------------------------
local SECTION_COLORS = {
    ["NPC Call Settings"]  = Color(60,  120, 200, 120),
    ["Munition Behaviour"] = Color(80,  180, 120, 120),
    ["Dive Attack"]        = Color(200, 60,  40,  120),
    ["Debug"]              = Color(100, 100, 110, 120),
    ["Manual Spawn"]       = Color(140, 80,  200, 120),
}

local function AddColoredCategory(panel, text)
    local bgColor = SECTION_COLORS[text]
    if not bgColor then
        panel:Help(text)
        return
    end

    local cat = vgui.Create("DPanel", panel)
    cat:SetTall(24)
    cat:Dock(TOP)
    cat:DockMargin(0, 8, 0, 4)
    cat.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, bgColor)
        surface.SetDrawColor(0, 0, 0, 35)
        surface.DrawOutlinedRect(0, 0, w, h)
        local textColor = (bgColor.r + bgColor.g + bgColor.b < 200)
            and Color(255, 255, 255, 255)
            or  Color(0,   0,   0,   255)
        draw.SimpleText(
            text, "DermaDefaultBold",
            8, h / 2,
            textColor,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end
    panel:AddItem(cat)
end

-- ----------------------------------------
--  Console Command — manual test spawn
-- ----------------------------------------
concommand.Add("foxbat_spawn", function()
    if not IsValid(LocalPlayer()) then return end
    net.Start("A22Foxbat_ManualSpawn")
    net.SendToServer()
end)

-- ----------------------------------------
--  Tab & Category Registration
-- ----------------------------------------
hook.Add("AddToolMenuTabs", "A22Foxbat_Tab", function()
    spawnmenu.AddToolTab("Bombin Support", "Bombin Support", "icon16/bomb.png")
end)

hook.Add("AddToolMenuCategories", "A22Foxbat_Categories", function()
    spawnmenu.AddToolCategory("Bombin Support", "A22 Foxbat", "A22 Foxbat")
end)

-- ----------------------------------------
--  Tool Menu Population
-- ----------------------------------------
hook.Add("PopulateToolMenu", "A22Foxbat_ToolMenu", function()
    spawnmenu.AddToolMenuOption(
        "Bombin Support",
        "A22 Foxbat",
        "a22foxbat_settings",
        "A22 Foxbat Settings",
        "", "",
        function(panel)
            panel:ClearControls()

            -- Header banner
            local header = vgui.Create("DPanel", panel)
            header:SetTall(32)
            header:Dock(TOP)
            header:DockMargin(0, 0, 0, 8)
            header.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, col_bg_panel)
                surface.SetDrawColor(col_accent)
                surface.DrawRect(0, h - 2, w, 2)
                draw.SimpleText(
                    "A22 Foxbat Controller",
                    "DermaLarge",
                    8, h / 2,
                    col_section_title,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
                )
            end
            panel:AddItem(header)

            -- ─── NPC Call Settings ─────────────────────────────────
            AddColoredCategory(panel, "NPC Call Settings")
            panel:CheckBox("Enable NPC calls",             "npc_a22foxbat_enabled")
            panel:NumSlider("Call chance (per check)",     "npc_a22foxbat_chance",    0,   1,    2)
            panel:NumSlider("Check interval (seconds)",    "npc_a22foxbat_interval",  1,   60,   0)
            panel:NumSlider("NPC cooldown (seconds)",      "npc_a22foxbat_cooldown",  10,  300,  0)
            panel:NumSlider("Min call distance (HU)",      "npc_a22foxbat_min_dist",  100, 1000, 0)
            panel:NumSlider("Max call distance (HU)",      "npc_a22foxbat_max_dist",  500, 8000, 0)
            panel:NumSlider("Flare → arrival delay (s)",  "npc_a22foxbat_delay",     1,   30,   0)

            -- ─── Munition Behaviour ────────────────────────────────
            AddColoredCategory(panel, "Munition Behaviour")
            panel:NumSlider("Lifetime (seconds)",               "npc_a22foxbat_lifetime", 10,  120,  0)
            panel:NumSlider("Flight speed (HU/s)",              "npc_a22foxbat_speed",    50,  800,  0)
            panel:NumSlider("Containment radius (HU)",          "npc_a22foxbat_radius",   500, 6000, 0)
            panel:NumSlider("Spawn altitude above ground (HU)", "npc_a22foxbat_height",   500, 8000, 0)

            -- ─── Dive Attack ───────────────────────────────────────
            AddColoredCategory(panel, "Dive Attack")
            panel:NumSlider("Explosion damage",      "npc_a22foxbat_dive_damage", 50,  1000, 0)
            panel:NumSlider("Explosion radius (HU)", "npc_a22foxbat_dive_radius", 100, 2000, 0)

            -- ─── Debug ─────────────────────────────────────────────
            AddColoredCategory(panel, "Debug")
            panel:CheckBox("Enable debug prints", "npc_a22foxbat_announce")

            -- ─── Manual Spawn ──────────────────────────────────────
            AddColoredCategory(panel, "Manual Spawn")
            panel:Button("Spawn A22 Foxbat now", "foxbat_spawn")
        end
    )
end)
