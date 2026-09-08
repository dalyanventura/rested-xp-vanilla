-- MyRXP - Coeur de l'addon (compatible WoW 1.12.1)

MyRXP = MyRXP or {}
MyRXP.guides = MyRXP.guides or {}

local function trim(text)
    if not text then return "" end
    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

function MyRXP:InitDB()
    if not MyRXP_Settings then
        MyRXP_Settings = {}
    end

    if not MyRXP_Settings.activeGuide then
        MyRXP_Settings.activeGuide = "Horde_1_12_Tauren"
    end

    if not MyRXP_Settings.currentStep then
        MyRXP_Settings.currentStep = 1
    end

    if not MyRXP_Settings.locked then
        MyRXP_Settings.locked = false
    end

    if not MyRXP_Settings.progress then
        MyRXP_Settings.progress = {}
    end
end

function MyRXP:RegisterGuide(guide)
    if not guide or not guide.id then return end
    self.guides[guide.id] = guide
end

function MyRXP:GetActiveGuide()
    return self.guides[MyRXP_Settings.activeGuide]
end

function MyRXP:GetCurrentStep()
    local guide = self:GetActiveGuide()
    if not guide or not guide.steps then return nil end

    local stepIndex = MyRXP_Settings.currentStep or 1
    if stepIndex < 1 then stepIndex = 1 end
    if stepIndex > table.getn(guide.steps) then
        stepIndex = table.getn(guide.steps)
    end

    MyRXP_Settings.currentStep = stepIndex
    return guide.steps[stepIndex], stepIndex
end

function MyRXP:IsObjectiveDone(guideId, stepIndex, objectiveIndex)
    local g = MyRXP_Settings.progress[guideId]
    if not g then return false end
    local s = g[stepIndex]
    if not s then return false end
    return s[objectiveIndex] and true or false
end

function MyRXP:SetObjectiveDone(guideId, stepIndex, objectiveIndex, done)
    if not MyRXP_Settings.progress[guideId] then
        MyRXP_Settings.progress[guideId] = {}
    end
    if not MyRXP_Settings.progress[guideId][stepIndex] then
        MyRXP_Settings.progress[guideId][stepIndex] = {}
    end

    MyRXP_Settings.progress[guideId][stepIndex][objectiveIndex] = done and true or nil
end

function MyRXP:QuestInLogByIdOrName(questId, questName)
    local count = GetNumQuestLogEntries()
    local wantedName = trim(questName)

    for i = 1, count do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and title then
            if wantedName ~= "" and trim(title) == wantedName then
                return true, i
            end
            if questId and self.questNameById and self.questNameById[questId] and trim(title) == trim(self.questNameById[questId]) then
                return true, i
            end
        end
    end

    return false, nil
end

function MyRXP:IsQuestCompleteByIndex(index)
    if not index then return false end
    local _, _, _, _, _, isComplete = GetQuestLogTitle(index)
    return isComplete and true or false
end

function MyRXP:IsQuestCompleteByIdOrName(questId, questName)
    local exists, index = self:QuestInLogByIdOrName(questId, questName)
    if not exists then return false end
    return self:IsQuestCompleteByIndex(index)
end

function MyRXP:TryAutoCompleteCurrentStep()
    local guide = self:GetActiveGuide()
    local step, stepIndex = self:GetCurrentStep()
    if not guide or not step or not step.objectives then return end

    local somethingChanged = false

    for i = 1, table.getn(step.objectives) do
        local objective = step.objectives[i]
        if not self:IsObjectiveDone(guide.id, stepIndex, i) then
            local action = objective.action
            if action == "ACCEPT" then
                if self:QuestInLogByIdOrName(objective.questId, objective.questName) then
                    self:SetObjectiveDone(guide.id, stepIndex, i, true)
                    somethingChanged = true
                end
            elseif action == "COMPLETE" then
                if self:IsQuestCompleteByIdOrName(objective.questId, objective.questName) then
                    self:SetObjectiveDone(guide.id, stepIndex, i, true)
                    somethingChanged = true
                end
            elseif action == "TURNIN" then
                if objective._seenInLog then
                    local exists = self:QuestInLogByIdOrName(objective.questId, objective.questName)
                    if not exists then
                        self:SetObjectiveDone(guide.id, stepIndex, i, true)
                        somethingChanged = true
                    end
                else
                    local exists = self:QuestInLogByIdOrName(objective.questId, objective.questName)
                    if exists then
                        objective._seenInLog = true
                    end
                end
            end
        end
    end

    if somethingChanged then
        self:UpdateUI()
        if self:AreAllObjectivesDone(guide.id, stepIndex, step) then
            self:NextStep()
        end
    end
end

function MyRXP:MarkByQuestNameFromMessage(message, action)
    local guide = self:GetActiveGuide()
    local step, stepIndex = self:GetCurrentStep()
    if not guide or not step or not step.objectives then return end

    for i = 1, table.getn(step.objectives) do
        local objective = step.objectives[i]
        if objective.action == action and objective.questName and objective.questName ~= "" then
            if string.find(message, objective.questName, 1, true) then
                self:SetObjectiveDone(guide.id, stepIndex, i, true)
                self:UpdateUI()
                if self:AreAllObjectivesDone(guide.id, stepIndex, step) then
                    self:NextStep()
                end
                return
            end
        end
    end
end

function MyRXP:AreAllObjectivesDone(guideId, stepIndex, step)
    if not step or not step.objectives then return false end
    for i = 1, table.getn(step.objectives) do
        if not self:IsObjectiveDone(guideId, stepIndex, i) then
            return false
        end
    end
    return true
end

function MyRXP:PrevStep()
    if (MyRXP_Settings.currentStep or 1) > 1 then
        MyRXP_Settings.currentStep = MyRXP_Settings.currentStep - 1
        self:UpdateUI()
    end
end

function MyRXP:NextStep()
    local guide = self:GetActiveGuide()
    if not guide or not guide.steps then return end

    if (MyRXP_Settings.currentStep or 1) < table.getn(guide.steps) then
        MyRXP_Settings.currentStep = MyRXP_Settings.currentStep + 1
        self:UpdateUI()
    end
end

function MyRXP:ToggleLock(value)
    if value ~= nil then
        MyRXP_Settings.locked = value and true or false
    else
        MyRXP_Settings.locked = not MyRXP_Settings.locked
    end

    if self.mainFrame then
        if MyRXP_Settings.locked then
            self.mainFrame.resizeHandle:Hide()
        else
            self.mainFrame.resizeHandle:Show()
        end
    end
end

function MyRXP:CreateUI()
    local frame = CreateFrame("Frame", "MyRXP_MainFrame", UIParent)
    frame:SetWidth(330)
    frame:SetHeight(220)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not MyRXP_Settings.locked then
            this:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)

    if frame.SetResizable then
        frame:SetResizable(true)
    end
    if frame.SetMinResize then
        frame:SetMinResize(280, 180)
    end
    if frame.SetMaxResize then
        frame:SetMaxResize(500, 420)
    end

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    header:SetJustifyH("LEFT")
    frame.headerText = header

    local lockCheck = CreateFrame("CheckButton", "MyRXP_LockCheck", frame, "UICheckButtonTemplate")
    lockCheck:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
    lockCheck:SetScript("OnClick", function()
        MyRXP:ToggleLock(this:GetChecked() and true or false)
    end)

    local lockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockLabel:SetPoint("RIGHT", lockCheck, "LEFT", 0, 1)
    lockLabel:SetText("Verrouiller")
    frame.lockCheck = lockCheck

    local stepTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stepTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
    stepTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -35)
    stepTitle:SetJustifyH("LEFT")
    frame.stepTitleText = stepTitle

    local lineContainer = CreateFrame("Frame", "MyRXP_LineContainer", frame)
    lineContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -55)
    lineContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 35)

    frame.lines = {}
    for i = 1, 5 do
        local check = CreateFrame("CheckButton", "MyRXP_Objective" .. i, lineContainer, "UICheckButtonTemplate")
        check:SetWidth(18)
        check:SetHeight(18)
        check:SetPoint("TOPLEFT", lineContainer, "TOPLEFT", 0, -(i - 1) * 28)

        local text = lineContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", check, "RIGHT", 4, 1)
        text:SetPoint("RIGHT", lineContainer, "RIGHT", 0, 1)
        text:SetJustifyH("LEFT")

        check.text = text
        check.index = i
        check:SetScript("OnClick", function()
            MyRXP:ToggleCurrentObjectiveFromClick(this.index)
        end)

        frame.lines[i] = check
    end

    local scroll = CreateFrame("ScrollFrame", "MyRXP_ScrollFrame", frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -57)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 38)
    scroll:SetWidth(20)
    scroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(24, function()
            MyRXP:UpdateUI()
        end)
    end)
    frame.scrollFrame = scroll

    local prev = CreateFrame("Button", "MyRXP_PrevButton", frame, "UIPanelButtonTemplate")
    prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    prev:SetWidth(100)
    prev:SetHeight(22)
    prev:SetText("Precedent")
    prev:SetScript("OnClick", function()
        MyRXP:PrevStep()
    end)

    local nextBtn = CreateFrame("Button", "MyRXP_NextButton", frame, "UIPanelButtonTemplate")
    nextBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    nextBtn:SetWidth(100)
    nextBtn:SetHeight(22)
    nextBtn:SetText("Suivant")
    nextBtn:SetScript("OnClick", function()
        MyRXP:NextStep()
    end)

    local resizeHandle = CreateFrame("Button", "MyRXP_ResizeHandle", frame)
    resizeHandle:SetWidth(16)
    resizeHandle:SetHeight(16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function()
        if not MyRXP_Settings.locked then
            this:GetParent():StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        this:GetParent():StopMovingOrSizing()
    end)
    frame.resizeHandle = resizeHandle

    self.mainFrame = frame
end

function MyRXP:ToggleCurrentObjectiveFromClick(visibleLineIndex)
    local guide = self:GetActiveGuide()
    local step, stepIndex = self:GetCurrentStep()
    if not guide or not step or not step.objectives then return end

    local offset = FauxScrollFrame_GetOffset(self.mainFrame.scrollFrame)
    local objectiveIndex = offset + visibleLineIndex
    if objectiveIndex < 1 or objectiveIndex > table.getn(step.objectives) then return end

    local current = self:IsObjectiveDone(guide.id, stepIndex, objectiveIndex)
    self:SetObjectiveDone(guide.id, stepIndex, objectiveIndex, not current)

    self:UpdateUI()
    if self:AreAllObjectivesDone(guide.id, stepIndex, step) then
        self:NextStep()
    end
end

function MyRXP:FormatObjectiveText(objective)
    if objective.text and objective.text ~= "" then
        return objective.text
    end

    if objective.raw and objective.raw ~= "" then
        return objective.raw
    end

    return "Objectif"
end

function MyRXP:UpdateUI()
    if not self.mainFrame then return end

    local guide = self:GetActiveGuide()
    local step, stepIndex = self:GetCurrentStep()

    if not guide or not step then
        self.mainFrame.headerText:SetText("MyRXP")
        self.mainFrame.stepTitleText:SetText("Aucun guide charge")
        return
    end

    self.mainFrame.headerText:SetText(guide.title or guide.id)
    self.mainFrame.stepTitleText:SetText("Etape " .. stepIndex .. " : " .. (step.title or ""))
    self.mainFrame.lockCheck:SetChecked(MyRXP_Settings.locked and true or false)

    local objectiveCount = table.getn(step.objectives or {})
    FauxScrollFrame_Update(self.mainFrame.scrollFrame, objectiveCount, 5, 24)
    local offset = FauxScrollFrame_GetOffset(self.mainFrame.scrollFrame)

    for lineIndex = 1, 5 do
        local objectiveIndex = offset + lineIndex
        local line = self.mainFrame.lines[lineIndex]
        if objectiveIndex <= objectiveCount then
            local objective = step.objectives[objectiveIndex]
            line:Show()
            line:SetChecked(self:IsObjectiveDone(guide.id, stepIndex, objectiveIndex) and true or false)
            line.text:SetText(self:FormatObjectiveText(objective))
        else
            line:Hide()
        end
    end

    if MyRXP_Settings.locked then
        self.mainFrame.resizeHandle:Hide()
    else
        self.mainFrame.resizeHandle:Show()
    end
end

SLASH_MYRXP1 = "/myrxp"
SlashCmdList["MYRXP"] = function(msg)
    msg = string.lower(trim(msg or ""))

    if msg == "lock" then
        MyRXP:ToggleLock(true)
    elseif msg == "unlock" then
        MyRXP:ToggleLock(false)
    elseif msg == "next" then
        MyRXP:NextStep()
    elseif msg == "prev" then
        MyRXP:PrevStep()
    end

    if msg == "" and MyRXP.mainFrame then
        if MyRXP.mainFrame:IsShown() then
            MyRXP.mainFrame:Hide()
        else
            MyRXP.mainFrame:Show()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("UI_INFO_MESSAGE")

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        MyRXP:InitDB()
        MyRXP:CreateUI()
        MyRXP:UpdateUI()
        return
    end

    if event == "QUEST_LOG_UPDATE" then
        MyRXP:TryAutoCompleteCurrentStep()
        return
    end

    local message = arg1
    if type(message) ~= "string" then return end

    if event == "CHAT_MSG_SYSTEM" then
        if string.find(message, "Quest accepted", 1, true) or string.find(message, "Quete acceptee", 1, true) then
            MyRXP:MarkByQuestNameFromMessage(message, "ACCEPT")
        elseif string.find(message, "is complete", 1, true) or string.find(message, "est terminee", 1, true) then
            MyRXP:MarkByQuestNameFromMessage(message, "COMPLETE")
        end
    elseif event == "UI_INFO_MESSAGE" then
        if string.find(message, "Quest Complete", 1, true) or string.find(message, "Quete terminee", 1, true) then
            MyRXP:TryAutoCompleteCurrentStep()
        end
    end
end)
