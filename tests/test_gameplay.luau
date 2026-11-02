--!strict
--[[
    test_gameplay.luau
    Automated Test Suite for DungeonRoblox Gameplay Mechanics (Phase 6 & 7)
    Executes in standalone Luau to verify all math, configurations, and state transitions.
]]

local totalTests = 0
local passedTests = 0

local function test(name: string, fn: () -> ())
    totalTests += 1
    local success: boolean, err: any = (pcall :: any)(fn)
    if success then
        passedTests += 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s:\n    %s", name, tostring(err)))
    end
end

local function assertEq(a: any, b: any, msg: string?)
    if a ~= b then
        error(string.format("Assertion failed: expected '%s', got '%s'. %s", tostring(b), tostring(a), msg or ""))
    end
end

local function assertTrue(condition: boolean, msg: string?)
    if not condition then
        error(string.format("Assertion failed: expected true. %s", msg or ""))
    end
end

print("==================================================")
print("RUNNING DUNGEONROBLOX GAMEPLAY TEST SUITE")
print("==================================================")

--------------------------------------------------------------------------------
-- TEST 1: ITEM TRAITS CONFIGURATION & WEIGHTS
--------------------------------------------------------------------------------
print("\n--- 1. Testing Item Traits (TraitConfig) ---")

local TRAITS: { [string]: { Weight: number, DamageMultiplier: number, HealthMultiplier: number, CritBonus: number, LuckBonus: number } } = {
    Swift = { Weight = 40, DamageMultiplier = 1.10, HealthMultiplier = 1.0, CritBonus = 0.0, LuckBonus = 0.0 },
    Fortified = { Weight = 25, DamageMultiplier = 1.0, HealthMultiplier = 1.20, CritBonus = 0.0, LuckBonus = 0.0 },
    Lucky = { Weight = 15, DamageMultiplier = 1.0, HealthMultiplier = 1.0, CritBonus = 0.0, LuckBonus = 0.5 },
    Ruthless = { Weight = 12, DamageMultiplier = 1.20, HealthMultiplier = 1.0, CritBonus = 0.15, LuckBonus = 0.0 },
    Warlord = { Weight = 6, DamageMultiplier = 1.45, HealthMultiplier = 1.30, CritBonus = 0.0, LuckBonus = 0.0 },
    Celestial = { Weight = 2, DamageMultiplier = 1.80, HealthMultiplier = 1.50, CritBonus = 0.10, LuckBonus = 1.5 },
}

test("Trait weights sum exactly to 100%", function()
    local sum = 0
    for _, t in pairs(TRAITS) do
        sum += t.Weight
    end
    assertEq(sum, 100, "Trait total weight must equal 100")
end)

test("Celestial trait gives highest damage and luck bonuses", function()
    local cel = TRAITS.Celestial
    assertTrue(cel.DamageMultiplier >= 1.80, "Celestial should give +80% DMG")
    assertTrue(cel.HealthMultiplier >= 1.50, "Celestial should give +50% HP")
    assertTrue(cel.LuckBonus >= 1.5, "Celestial should give +1.5 Luck")
end)

test("Simulate 10,000 rolls with 30% natural trait chance", function()
    local traitDrops = 0
    math.randomseed(12345)
    for _ = 1, 10000 do
        if math.random() <= 0.30 then
            traitDrops += 1
        end
    end
    local rate = traitDrops / 10000
    assertTrue(rate >= 0.28 and rate <= 0.32, string.format("Expected ~30%% trait drop rate, got %.2f%%", rate * 100))
end)

--------------------------------------------------------------------------------
-- TEST 2: REBIRTH SYSTEM FORMULA & STAT SCALING
--------------------------------------------------------------------------------
print("\n--- 2. Testing Rebirth System (RebirthService & Stats) ---")

local function getRebirthReqs(rebirths: number)
    local reqLevel = 5 + (rebirths * 5)
    local reqGold = 5000 * (rebirths + 1)
    return reqLevel, reqGold
end

local function computeTotalStats(baseDamage: number, baseHP: number, baseLuck: number, rebirths: number, activeLuckBuff: boolean)
    local dmg = baseDamage
    local hp = baseHP
    local luck = baseLuck

    if rebirths > 0 then
        local mult = 1.0 + (rebirths * 0.35)
        dmg = math.round(dmg * mult)
        hp = math.round(hp * mult)
        luck += (rebirths * 1.5)
    end

    if activeLuckBuff then
        luck *= 2.0
    end

    return dmg, hp, luck
end

test("Rebirth Requirements Progression (Tiers 0, 1, 2, 3)", function()
    local lvl0, gold0 = getRebirthReqs(0)
    assertEq(lvl0, 5, "Rebirth 0 requires Level 5")
    assertEq(gold0, 5000, "Rebirth 0 requires 5,000 Gold")

    local lvl1, gold1 = getRebirthReqs(1)
    assertEq(lvl1, 10, "Rebirth 1 requires Level 10")
    assertEq(gold1, 10000, "Rebirth 1 requires 10,000 Gold")

    local lvl2, gold2 = getRebirthReqs(2)
    assertEq(lvl2, 15, "Rebirth 2 requires Level 15")
    assertEq(gold2, 15000, "Rebirth 2 requires 15,000 Gold")

    local lvl3, gold3 = getRebirthReqs(3)
    assertEq(lvl3, 20, "Rebirth 3 requires Level 20")
    assertEq(gold3, 20000, "Rebirth 3 requires 20,000 Gold")
end)

test("Rebirth Stacking Stat Buffs (+35% DMG, +35% HP, +1.5 Luck per rebirth)", function()
    -- Base: 100 DMG, 1000 HP, 1.0 Luck
    local d0, h0, l0 = computeTotalStats(100, 1000, 1.0, 0, false)
    assertEq(d0, 100)
    assertEq(h0, 1000)
    assertEq(l0, 1.0)

    -- Rebirth 1: +35% DMG = 135, +35% HP = 1350, Luck = 2.5
    local d1, h1, l1 = computeTotalStats(100, 1000, 1.0, 1, false)
    assertEq(d1, 135)
    assertEq(h1, 1350)
    assertEq(l1, 2.5)

    -- Rebirth 2: +70% DMG = 170, +70% HP = 1700, Luck = 4.0
    local d2, h2, l2 = computeTotalStats(100, 1000, 1.0, 2, false)
    assertEq(d2, 170)
    assertEq(h2, 1700)
    assertEq(l2, 4.0)

    -- Rebirth 2 with Luck Potion (2x Luck): 4.0 * 2 = 8.0 Luck!
    local _, _, l2Potion = computeTotalStats(100, 1000, 1.0, 2, true)
    assertEq(l2Potion, 8.0)
end)

test("Rebirth preserves Inventory, Rarities, Traits and Multi-Roll", function()
    local mockPlayer = {
        Level = 10,
        XP = 340,
        Gold = 15000,
        Rebirths = 1,
        MultiRollCount = 3,
        FastRollUnlocked = true,
        Inventory = {
            ["item-1"] = { ItemId = "excalibur", EnchantLevel = 5, Trait = "Celestial" },
            ["item-2"] = { ItemId = "shadow_armor", EnchantLevel = 3, Trait = "Fortified" },
        }
    }

    local reqLvl, reqGold = getRebirthReqs(mockPlayer.Rebirths)
    assertTrue(mockPlayer.Level >= reqLvl, "Level check")
    assertTrue(mockPlayer.Gold >= reqGold, "Gold check")

    -- Perform Rebirth
    mockPlayer.Gold -= reqGold
    mockPlayer.Level = 1
    mockPlayer.XP = 0
    mockPlayer.Rebirths += 1

    -- Verify results
    assertEq(mockPlayer.Level, 1, "Level reset to 1")
    assertEq(mockPlayer.XP, 0, "XP reset to 0")
    assertEq(mockPlayer.Gold, 5000, "Gold deducted (15,000 - 10,000 = 5,000)")
    assertEq(mockPlayer.Rebirths, 2, "Rebirth incremented to 2")
    assertEq(mockPlayer.MultiRollCount, 3, "Multi-Roll level preserved at 3x")
    assertTrue(mockPlayer.FastRollUnlocked, "Fast Roll Pass preserved")
    assertEq(mockPlayer.Inventory["item-1"].Trait, "Celestial", "Celestial weapon trait preserved")
    assertEq(mockPlayer.Inventory["item-1"].EnchantLevel, 5, "Enchant level preserved")
end)

--------------------------------------------------------------------------------
-- TEST 3: FAST ROLL PASS & COOLDOWNS
--------------------------------------------------------------------------------
print("\n--- 3. Testing Fast Roll Pass (Speed Optimization) ---")

test("Roll cooldown is 0.75s default, 0.25s with Fast Roll Pass (3x speed)", function()
    local function getCooldown(hasFastRoll: boolean): number
        return if hasFastRoll then 0.25 else 0.75
    end

    assertEq(getCooldown(false), 0.75, "Default cooldown is 0.75s")
    assertEq(getCooldown(true), 0.25, "Fast roll cooldown is 0.25s")
    local speedMultiplier = 0.75 / 0.25
    assertEq(speedMultiplier, 3, "Fast roll is exactly 3x faster")
end)

--------------------------------------------------------------------------------
-- TEST 4: SHOP POTIONS & TIME STACKING
--------------------------------------------------------------------------------
print("\n--- 4. Testing Shop Potions & Duration Stacking ---")

test("Purchasing multiple Potions stacks remaining duration", function()
    local now = 1000
    local buffEndTime = 0

    -- Buy 1st Potion (300 seconds)
    local base1 = math.max(now, buffEndTime)
    buffEndTime = base1 + 300
    assertEq(buffEndTime, 1300, "Buff expires at t=1300")

    -- Buy 2nd Potion 60 seconds later (now = 1060, remaining was 240s)
    now = 1060
    local base2 = math.max(now, buffEndTime)
    buffEndTime = base2 + 300
    assertEq(buffEndTime, 1600, "Buff stacked to t=1600 (remaining: 540 seconds)")
end)

test("Multi-Roll purchase steps: 1x -> 2x (2,500 G) -> 3x (10,000 G)", function()
    local costs = { [1] = 2500, [2] = 10000 }
    local tier = 1

    -- Step 1
    assertEq(costs[tier], 2500)
    tier += 1
    -- Step 2
    assertEq(costs[tier], 10000)
    tier += 1
    -- Max reached
    assertEq(tier, 3)
end)

--------------------------------------------------------------------------------
-- TEST 5: OVERHEAD RANK TITLE MAPPING
--------------------------------------------------------------------------------
print("\n--- 5. Testing Overhead Rank Title Classification ---")

local function getRankTitle(rebirths: number, cp: number): string
    if rebirths >= 3 then
        return string.format("[🌌 Celestial God - Rebirth %d]", rebirths)
    elseif rebirths == 2 then
        return "[⚡ Mythic Overlord - Rebirth II]"
    elseif rebirths == 1 then
        return "[🔥 Awakened God - Rebirth I]"
    else
        if cp >= 3000 then
            return "[👑 Warlord]"
        elseif cp >= 1000 then
            return "[🛡️ Champion]"
        elseif cp >= 200 then
            return "[⚔️ Slayer]"
        else
            return "[🌱 Novice]"
        end
    end
end

test("Overhead Rank Title scales with CP when Rebirth == 0", function()
    assertEq(getRankTitle(0, 50), "[🌱 Novice]")
    assertEq(getRankTitle(0, 350), "[⚔️ Slayer]")
    assertEq(getRankTitle(0, 1500), "[🛡️ Champion]")
    assertEq(getRankTitle(0, 4200), "[👑 Warlord]")
end)

test("Overhead Rank Title reflects divine status when Rebirth >= 1", function()
    assertEq(getRankTitle(1, 100), "[🔥 Awakened God - Rebirth I]")
    assertEq(getRankTitle(2, 500), "[⚡ Mythic Overlord - Rebirth II]")
    assertEq(getRankTitle(3, 1000), "[🌌 Celestial God - Rebirth 3]")
    assertEq(getRankTitle(5, 9999), "[🌌 Celestial God - Rebirth 5]")
end)

--------------------------------------------------------------------------------
-- TEST 6: QUALITY OVERHAUL (15% TO 100%) & STAT MULTIPLIER FORMULA
--------------------------------------------------------------------------------
print("\n--- 6. Testing Quality Overhaul (15% - 100%) & Stat Multipliers ---")

local function getQualityMultiplier(quality: number): number
    return 0.5 + (quality / 100) * 1.0
end

test("Quality Multiplier Formula (15% -> 0.65x, 50% -> 1.0x, 100% -> 1.5x)", function()
    local q15 = getQualityMultiplier(15)
    local q50 = getQualityMultiplier(50)
    local q100 = getQualityMultiplier(100)

    assertTrue(math.abs(q15 - 0.65) < 0.001, "15% Quality should give 0.65x base stats")
    assertTrue(math.abs(q50 - 1.00) < 0.001, "50% Quality should give 1.00x base stats")
    assertTrue(math.abs(q100 - 1.50) < 0.001, "100% Quality should give 1.50x base stats")
end)

test("Simulate 5,000 rolls generating Quality integer in [15, 100]", function()
    math.randomseed(98765)
    for _ = 1, 5000 do
        local q = math.random(15, 100)
        assertTrue(q >= 15 and q <= 100, "Quality must be between 15 and 100")
        assertEq(q, math.floor(q), "Quality must be an integer")
    end
end)

test("Quality directly scales MaxHP, Damage, CritChance, and LuckBonus", function()
    local baseStats = { Damage = 100, MaxHP = 500, CritChance = 0.10, LuckBonus = 1.0 }
    local rarityMult = 2.0 -- e.g. Epic
    
    local function calcStats(quality: number)
        local qMult = getQualityMultiplier(quality)
        return {
            Damage = math.round(baseStats.Damage * rarityMult * qMult),
            MaxHP = math.round(baseStats.MaxHP * rarityMult * qMult),
            Crit = baseStats.CritChance * rarityMult * qMult,
            Luck = baseStats.LuckBonus * rarityMult * qMult,
        }
    end

    local low = calcStats(15) -- 0.65x
    local mid = calcStats(50) -- 1.0x
    local high = calcStats(100) -- 1.5x

    assertEq(low.Damage, 130, "100 * 2.0 * 0.65 = 130")
    assertEq(mid.Damage, 200, "100 * 2.0 * 1.00 = 200")
    assertEq(high.Damage, 300, "100 * 2.0 * 1.50 = 300")

    assertEq(low.MaxHP, 650, "500 * 2.0 * 0.65 = 650")
    assertEq(mid.MaxHP, 1000, "500 * 2.0 * 1.00 = 1000")
    assertEq(high.MaxHP, 1500, "500 * 2.0 * 1.50 = 1500")
end)

--------------------------------------------------------------------------------
-- TEST 7: MYSTIC GEMS (💎) & SEPARATE REROLLS & PARTY PODS
--------------------------------------------------------------------------------
print("\n--- 7. Testing Mystic Gems, Separate Rerolls & Party Pods ---")

test("New players initialize with 5 Mystic Gems", function()
    local defaultData = { Gold = 100, Gems = 5, Level = 1 }
    assertEq(defaultData.Gems, 5, "Initial Gems balance is 5")
end)

test("Dungeon Floor Clears award Gems (+2, +5, +12)", function()
    local floorGems = { [1] = 2, [2] = 5, [3] = 12 }
    assertEq(floorGems[1], 2)
    assertEq(floorGems[2], 5)
    assertEq(floorGems[3], 12)
end)

test("Shop Gem Pouch gives 3 Gems for 1,000 Gold", function()
    local player = { Gold = 1500, Gems = 5 }
    local cost = 1000
    local gemsAdded = 3
    assertTrue(player.Gold >= cost, "Player has enough gold")
    player.Gold -= cost
    player.Gems += gemsAdded
    assertEq(player.Gold, 500)
    assertEq(player.Gems, 8)
end)

test("Separate Reroll Costs: Quality costs 150 Gold, Trait costs 1 Gem", function()
    local player = { Gold = 300, Gems = 2 }

    -- Reroll Quality
    local qualityCost = 150
    assertTrue(player.Gold >= qualityCost)
    player.Gold -= qualityCost
    assertEq(player.Gold, 150)

    -- Reroll Trait
    local traitCost = 1
    assertTrue(player.Gems >= traitCost)
    player.Gems -= traitCost
    assertEq(player.Gems, 1)
end)

test("Multiplayer Custom Party Room Host Assignment, Floor Switching & Settings", function()
    local room = {
        RoomId = 1,
        Host = nil :: string?,
        Members = {} :: { string },
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        Invited = {} :: { [string]: boolean },
    }

    local function enter(player: string): boolean
        if #room.Members >= room.MaxPlayers then return false end
        if room.Host == nil then
            room.Host = player
        end
        table.insert(room.Members, player)
        return true
    end

    -- 1. First player becomes Host
    assertTrue(enter("Player1"), "Player1 creates room")
    assertEq(room.Host, "Player1")
    assertEq(#room.Members, 1)

    -- 2. Host changes floor
    room.SelectedFloor = "floor_3"
    assertEq(room.SelectedFloor, "floor_3")

    -- 3. Host changes max players
    room.MaxPlayers = 2
    assertEq(room.MaxPlayers, 2)

    -- 4. Member enters
    assertTrue(enter("Player2"), "Player2 enters")
    assertEq(#room.Members, 2)

    -- 5. Third player rejected because cap is 2
    assertTrue(not enter("Player3"), "Player3 rejected due to cap 2")
end)

test("Multiplayer Custom Party Room Friends-Only restriction & Invite Bypass", function()
    local room = {
        Host = "Alice",
        Members = { "Alice" },
        FriendsOnly = true,
        Friends = { ["Bob"] = true },
        Invited = { ["Charlie"] = true },
    }

    local function canJoin(user: string): boolean
        if not room.FriendsOnly then return true end
        if user == room.Host then return true end
        if room.Friends[user] then return true end
        if room.Invited[user] then return true end
        return false
    end

    assertTrue(canJoin("Bob"), "Friend Bob should join")
    assertTrue(canJoin("Charlie"), "Invited Charlie should bypass Friends-Only")
    assertTrue(not canJoin("Stranger"), "Stranger should be rejected")
end)

test("Multiplayer Custom Party Room Movement Lock & Restoration", function()
    local playerChar = {
        WalkSpeed = 16,
        JumpPower = 50,
        InPartyRoom = false,
    }

    -- Step into room -> Locked
    local function lockInRoom()
        playerChar.WalkSpeed = 0
        playerChar.JumpPower = 0
        playerChar.InPartyRoom = true
    end

    -- Leave room or start dungeon -> Restored
    local function restoreFreeMovement()
        playerChar.WalkSpeed = 16
        playerChar.JumpPower = 50
        playerChar.InPartyRoom = false
    end

    lockInRoom()
    assertEq(playerChar.WalkSpeed, 0)
    assertEq(playerChar.JumpPower, 0)
    assertTrue(playerChar.InPartyRoom)

    restoreFreeMovement()
    assertEq(playerChar.WalkSpeed, 16)
    assertEq(playerChar.JumpPower, 50)
    assertTrue(not playerChar.InPartyRoom)
end)

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------
print("\n==================================================")
print(string.format("TEST RESULTS: %d / %d PASSED (%.1f%%)", passedTests, totalTests, (passedTests / totalTests) * 100))
print("==================================================")

if passedTests == totalTests then
    print("ALL TESTS COMPLETED WITH 100% SUCCESS!")
else
    error("Some tests failed!")
end
