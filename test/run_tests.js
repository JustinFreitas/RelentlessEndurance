const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { LuaFactory } = require('wasmoon');

async function runTests() {
    console.log("Setting up Lua VM via wasmoon...");
    const luaFactory = new LuaFactory();
    const lua = await luaFactory.createEngine();

    // 1. Mock FGU environment globals
    console.log("Mocking FGU environment globals...");
    
    await lua.doString(`
        Interface = {}
        OptionsManager = {}
        Comm = {}
        DB = {}
        ActorManager = {}
        CombatManager = {}
        EffectManager = {}
        StringManager = {}
        User = {}
        Session = { VersionMajor = 4 }
        ActionDamage = {}
        
        -- Mock User
        function User.isHost() return true end

        -- Mock StringManager
        StringManager.trim = function(s)
            if not s then return "" end
            return s:match("^%s*(.-)%s*$")
        end
        StringManager.isBlank = function(s)
            if type(s) ~= "string" then return true end
            return s:gsub("%s+", "") == ""
        end

        -- Mock OptionsManager
        local options = {}
        function OptionsManager.registerOption2() end
        function OptionsManager.isOption(key, val)
            return options[key] == val
        end
        function OptionsManager.setOption(key, val)
            options[key] = val
        end

        -- Mock Comm
        local chatMessages = {}
        function Comm.registerSlashHandler() end
        function Comm.addChatMessage(msg)
            table.insert(chatMessages, msg.text)
        end
        function Comm.deliverChatMessage(msg)
            table.insert(chatMessages, msg.text)
        end
        function Comm.getChatMessages()
            return chatMessages
        end
        function Comm.clearChatMessages()
            chatMessages = {}
        end

        -- Mock CombatManager
        CombatManager.CT_LIST = "combattracker"
        function CombatManager.requestActivation() end

        -- Mock Database structure
        dbData = {}
        dbChildren = {}
        
        function DB.setNodeValue(path, val)
            dbData[path] = val
        end
        
        function DB.setValue(node, field, typeStr, val)
            local nodePath = ""
            if type(node) == "table" and node.path then
                nodePath = node.path
            elseif type(node) == "string" then
                nodePath = node
            end
            dbData[nodePath .. "." .. field] = val
        end
        
        function DB.getValue(node, field, default)
            if type(node) == "table" and node.label and field == "label" then
                return node.label
            end
            local nodePath = ""
            if type(node) == "table" and node.path then
                nodePath = node.path
            elseif type(node) == "string" then
                nodePath = node
            end
            local fullPath = nodePath .. "." .. field
            if dbData[fullPath] ~= nil then
                return dbData[fullPath]
            end
            return default
        end

        function DB.getText(node, field, default)
            return DB.getValue(node, field, default)
        end

        function DB.setChildren(nodePath, children)
            dbChildren[nodePath] = {}
            for k, v in pairs(children) do
                dbChildren[nodePath][k] = true
            end
        end

        function DB.getChildren(node, field)
            local nodePath = ""
            if type(node) == "table" and node.path then
                nodePath = node.path
            elseif type(node) == "string" then
                nodePath = node
            end
            
            local fullPath = nodePath
            if field then
                fullPath = nodePath .. "." .. field
            end
            
            local children = dbChildren[fullPath] or {}
            local list = {}
            for k, v in pairs(children) do
                list[k] = { path = fullPath .. "." .. k }
            end
            return list
        end

        -- Enable createChild mocking
        local mockNodeIndex = 1
        function createMockNode(nodePath)
            local node = { path = nodePath }
            function node.createChild(name)
                mockNodeIndex = mockNodeIndex + 1
                local childName = name or ("child" .. mockNodeIndex)
                local childPath = nodePath .. "." .. childName
                
                -- Register child in dbChildren
                if not dbChildren[nodePath] then
                    dbChildren[nodePath] = {}
                end
                dbChildren[nodePath][childName] = true
                
                return createMockNode(childPath)
            end
            return node
        end

        function DB.findNode(nodePath)
            return createMockNode(nodePath)
        end

        -- Mock ActorManager
        local actorMap = {}
        local actorPC = {}
        function ActorManager.getActor(nodeCT)
            return actorMap[nodeCT.path]
        end
        function ActorManager.setActor(nodeCTPath, actor)
            actorMap[nodeCTPath] = actor
        end
        function ActorManager.isPC(v)
            if type(v) == "table" and v.path then
                if actorPC[v.path] == true or v.path:find("charsheet") then
                    return true
                end
            end
            return false
        end
        function ActorManager.setPC(nodeCTPath, val)
            actorPC[nodeCTPath] = val
        end
        function ActorManager.getCreatureNode(v)
            if type(v) == "table" and v.sCreatureNode then
                return DB.findNode(v.sCreatureNode)
            end
            local rActor = actorMap[v.path]
            if rActor and rActor.sCreatureNode then
                return DB.findNode(rActor.sCreatureNode)
            end
            return DB.findNode("charsheet.id-00001")
        end
        function ActorManager.getCTNode(v)
            if type(v) == "table" and v.path then
                return DB.findNode(v.path)
            end
            return nil
        end
        function ActorManager.getDisplayName(node)
            return "Mock Hero"
        end

        -- Mock EffectManager
        local activeEffects = {}
        function EffectManager.hasEffect(rActor, sEffect)
            return activeEffects[sEffect] == true
        end
        function EffectManager.setEffect(sEffect, val)
            activeEffects[sEffect] = val
        end
        function EffectManager.removeEffect(nodeCT, sEffect)
            activeEffects[sEffect] = false
        end

        -- Mock ActionDamage
        appliedDamageTotal = nil
        function ActionDamage.applyDamage(rSource, rTarget, rRoll)
            appliedDamageTotal = rRoll.nTotal
        end
    `);

    // 2. Load the actual relentlessendurance script
    console.log("Loading scripts/relentlessendurance.lua into VM...");
    const luaCodePath = path.join(__dirname, '../scripts/relentlessendurance.lua');
    const luaCode = fs.readFileSync(luaCodePath, 'utf8');
    
    await lua.doString(luaCode);
    console.log("RelentlessEndurance loaded successfully inside VM.\n");

    // 3. Define and run test assertions
    console.log("Running Unit Tests...");
    let testsPassed = 0;
    let testsFailed = 0;

    async function runAssert(fnName, expected, luaCodeToRun) {
        try {
            const result = await lua.doString(luaCodeToRun);
            assert.strictEqual(result, expected);
            console.log(`  ✓ PASS: ${fnName} -> got ${result}`);
            testsPassed++;
        } catch (err) {
            console.error(`  ✗ FAIL: ${fnName} -> expected ${expected}, got error or mismatch: ${err.message}`);
            testsFailed++;
        }
    }

    // --- TEST 1: getTargetHealthData (FGU version returns FGU health paths) ---
    await lua.doString(`
        Session.VersionMajor = 4
        nodeChar = { path = "charsheet.id-00001" }
        DB.setNodeValue("charsheet.id-00001.hp.total", 25)
        DB.setNodeValue("charsheet.id-00001.hp.wounds", 5)
        hDataFGU = getTargetHealthData("pc", nodeChar, nil)
    `);
    await runAssert("getTargetHealthData FGU total HP", 25, "return hDataFGU.nTotalHP");
    await runAssert("getTargetHealthData FGU wounds", 5, "return hDataFGU.nWounds");

    // --- TEST 2: getTargetHealthData (FGC version returns FGC health paths) ---
    await lua.doString(`
        Session.VersionMajor = 3
        nodeCharLegacy = { path = "charsheet.id-00002" }
        DB.setNodeValue("charsheet.id-00002.hp.total", 15)
        DB.setNodeValue("charsheet.id-00002.hp.wounds", 2)
        hDataFGC = getTargetHealthData("pc", nodeCharLegacy, nil)
    `);
    await runAssert("getTargetHealthData FGC total HP", 15, "return hDataFGC.nTotalHP");
    await runAssert("getTargetHealthData FGC wounds", 2, "return hDataFGC.nWounds");
    
    // Restore Session to FGU
    await lua.doString("Session.VersionMajor = 4");

    // --- TEST 3: hasAvailableRelentlessEndurance ---
    await runAssert("hasAvailableRelentlessEndurance() simple check", true, "return hasAvailableRelentlessEndurance({nPrepared=1, nCast=0})");
    await runAssert("hasAvailableRelentlessEndurance() already cast", false, "return hasAvailableRelentlessEndurance({nPrepared=1, nCast=1})");

    // --- TEST 4: getDecomposedTraitName suffix extraction ---
    await lua.doString(`
        local trait = { path = "charsheet.id-00001.traitlist.trait1" }
        DB.setNodeValue("charsheet.id-00001.traitlist.trait1.name", "Relentless Endurance (Half-Orc)")
        decomp = getDecomposedTraitName(trait)
    `);
    await runAssert("getDecomposedTraitName start pos", 1, "return decomp.nRelentlessEnduranceStart");
    await runAssert("getDecomposedTraitName suffix", " (Half-Orc)", "return decomp.sRelentlessEnduranceTraitSuffix");

    // --- TEST 5: hasRelentlessEnduranceTrait with PC sheet ---
    await lua.doString(`
        nodeChar = { path = "charsheet.id-00001" }
        DB.setChildren("charsheet.id-00001.traitlist", {
            ["trait1"] = true
        })
        DB.setNodeValue("charsheet.id-00001.traitlist.trait1.name", "Relentless Endurance")
        
        -- Setup HP: 20 total, 0 temp, 15 wounds (5 current HP)
        DB.setNodeValue("charsheet.id-00001.hp.total", 20)
        DB.setNodeValue("charsheet.id-00001.hp.temporary", 0)
        DB.setNodeValue("charsheet.id-00001.hp.wounds", 15)
        
        -- Override ActorManager return values
        local actorPC = { sCreatureNode = "charsheet.id-00001", sName = "Gromph", sType = "charsheet" }
        ActorManager.setActor("combattracker.entry1", actorPC)
        ActorManager.setPC("combattracker.entry1", true)
        nodeCT = { path = "combattracker.entry1" }
        
        -- Setup ActionDamage callback binding
        onInit()
    `);
    await runAssert("hasRelentlessEnduranceTrait nTotalHP", 20, "return hasRelentlessEnduranceTrait(nodeCT).nTotalHP");
    await runAssert("hasRelentlessEnduranceTrait nPrepared", 1, "return hasRelentlessEnduranceTrait(nodeCT).nPrepared");

    // --- TEST 6: applyDamage_v2 -> normal damage (HP remains > 0) ---
    await lua.doString(`
        appliedDamageTotal = nil
        local roll = { sDesc = "[DAMAGE]", nTotal = 3, bSecret = false }
        applyDamage_v2(nil, nodeCT, roll)
    `);
    await runAssert("Normal damage applied", 3, "return appliedDamageTotal");
    await runAssert("Power not created on charsheet", false, "return DB.getValue('charsheet.id-00001.powers.child3', 'name', '') == 'Relentless Endurance'");

    // --- TEST 7: applyDamage_v2 -> triggers Relentless Endurance (HP drops to 0, saved to 1) ---
    await lua.doString(`
        appliedDamageTotal = nil
        local roll = { sDesc = "[DAMAGE] sword", nTotal = 6, bSecret = false }
        applyDamage_v2(nil, nodeCT, roll)
    `);
    // Gromph has 5 HP. 6 damage would drop him to -1 HP.
    // It should set appliedDamageTotal to 4, leaving him at 1 HP.
    await runAssert("Relentless Endurance damage capped", 4, "return appliedDamageTotal");
    await runAssert("Relentless Endurance power cast incremented", 1, "return DB.getValue('charsheet.id-00001.powers.child3', 'cast', 0)");

    // --- TEST 8: applyDamage_v2 -> instant death (damage exceeds max HP) ---
    await lua.doString(`
        -- Reset power cast and wounds back to 15 (5 HP)
        DB.setValue({path='charsheet.id-00001.powers.child3'}, 'cast', 'number', 0)
        DB.setNodeValue("charsheet.id-00001.hp.wounds", 15)
        appliedDamageTotal = nil
        
        -- 25 damage (5 - 25 = -20, which is exactly negative max HP)
        local roll = { sDesc = "[DAMAGE]", nTotal = 25, bSecret = false }
        applyDamage_v2(nil, nodeCT, roll)
    `);
    await runAssert("Instant death damage not capped", 25, "return appliedDamageTotal");

    // --- TEST 9: applyRelentlessEndurance manual recovery (removes unconscious/prone, sets wounds) ---
    await lua.doString(`
        DB.setNodeValue("charsheet.id-00001.hp.wounds", 20) -- dead/unconscious
        EffectManager.setEffect("Unconscious", true)
        EffectManager.setEffect("Prone", true)
        
        applyRelentlessEndurance(nodeCT)
    `);
    await runAssert("Manual RE wounds set to Max - 1", 19, "return DB.getValue('charsheet.id-00001', 'hp.wounds', 0)");
    await runAssert("Unconscious effect removed", false, "return EffectManager.hasEffect(nodeCT, 'Unconscious')");
    await runAssert("Prone effect removed", false, "return EffectManager.hasEffect(nodeCT, 'Prone')");

    // 4. Print Summary
    console.log(`\nTest Summary: ${testsPassed} passed, ${testsFailed} failed.`);
    
    if (testsFailed > 0) {
        process.exit(1);
    }
}

runTests().catch(err => {
    console.error("Test execution failed: ", err);
    process.exit(1);
});
