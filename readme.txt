-- Hangglider mod for Minetest
-- Original code by Piezo_ (orderofthefourthwall@gmail.com)
-- 2018-11-14

-- Modifications by David G (kestral246@gmail.com)
-- 2018-11-24
-- For Minetest 5.x, glider's set_attach needs to be offset by 1 node
--     Switch to alternate commented line below with correct offset.
-- Additional tuning of parameters.
-- Commented out debug hud display code, prefixed with "--debug:".

-- 2018-11-22
-- Give visual indication that hangglider is equiped.
--     Display simple overlay with blurred struts when equiped.
--     Issue: don't know how to disable overlay in third person view.
-- Also Unequip hangglider when landing on water.
-- Attempt to linearize parabolic flight path.
--     Start gravity stronger, but gradually reduce it as descent velocity increases.
--     Don't use airstopper when equipped from the ground (descent velocity is low).
--     Slightly increase flight speed to 1.25.
-- Unequip/equip cycling mid-flight should not fly farther than continuous flight.
--     When equipping mid-air (descent velocity higher), use airstopper but increase descent slope afterwards.
--     Create airbreak flag so all equips mid-flight use faster descent.
--     Reset airbreak flag only when land (canExist goes false).
--     Issue: it wouldn't reset if land in water, use fly, and launch from air, before I added test for water,
--            not sure if there are other such cases.
-- Temporarily add hud debug display to show descent velocity, gravity override, and airbreak flag.
--     Still in process of tuning all the parameters.


-- Modifications by Piezo_
-- 2018-11-25
-- hud overlay and debug can be enabled/disabled
-- Added blender-rendered overlay for struts using the actual model.
-- Reduced airbreak penalty severity
-- gave glider limited durability.
-- Improved gravity adjustment function.
-- Changed airbreaking process
-- Removed airbreak penalty, as any 'advantage' seems minimal after new adjustments
-- Removed airbreak until minetest devs are smart enough to implement better serverside players.
-- Simplified liquid check.

-- Modifications by gpcf
-- 2018-12-09
-- get shot down while flying over protected areas marked as no-fly-zones (flak, from German Flugabwehrkanone)
--  set these areas with the /area_flak command

-- Modifications by SpaghettiToastBook
-- 2018-12-29
-- Physics overrides use player_monoids mod if available

-- Modifications by SwissalpS
-- 2022-05-16
-- Add Z-index to theoretically be behind hotbar and practically behind other HUDs

-- Modifications by 2BW
-- 2025-02-14
-- 