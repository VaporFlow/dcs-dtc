dofile(lfs.writedir() .. 'Scripts/DCSDTC/commonFunctions.lua')

-- Ka-50 III PVI-800 (device 20). Command ids match the cockpit clickable actions:
-- 3001-3010 digits 0-9, 3011 waypoints, 3018 enter, 3019 cancel, 3026 mode selector.
-- Mode 0.2 is data entry and 0.3 is operate.
local KA50_PVI = 20
local KA50_PVI_IND = 5
local KA50_CMD_0 = 3001
local KA50_CMD_WPT = 3011
local KA50_CMD_ENTER = 3018
local KA50_CMD_CANCEL = 3019
local KA50_CMD_MODE = 3026
local KA50_MODE_ENTER = 0.2
local KA50_MODE_OPER = 0.3
local KA50_ACCEL_RESET_ARG = 572

local function DTC_KA50_Press(cmd)
    DTC_ExecCommand(KA50_PVI, cmd, 250, 0.3, 80)
end

local function DTC_KA50_SetMode(value)
    DTC_ExecCommand(KA50_PVI, KA50_CMD_MODE, -1, value, 0)
    DTC_Wait(400)
end

local function DTC_KA50_ReadPvi()
    local ok, ind = pcall(DTC_ParseDisplay, KA50_PVI_IND)
    if not ok or type(ind) ~= "table" then
        return {}
    end
    return ind
end

local function DTC_KA50_Field(ind, name)
    return DTC_trim(ind[name] or "")
end

local function DTC_KA50_IsNegative(sign)
    return sign == "-" or sign == "−" or sign == "–" or sign == "—"
end

local function DTC_KA50_LineIsNegative(ind, signName, textName)
    if DTC_KA50_IsNegative(DTC_KA50_Field(ind, signName)) then
        return true
    end
    local text = DTC_KA50_Field(ind, textName)
    local first = string.sub(text, 1, 1)
    return DTC_KA50_IsNegative(first)
end

local function DTC_KA50_TypeDigits(digits)
    for i = 1, #digits do
        local n = tonumber(string.sub(digits, i, i))
        if n ~= nil then
            DTC_KA50_Press(KA50_CMD_0 + n)
        end
    end
end

-- South/west: a leading 0 on an empty PVI line sets the minus sign.
-- North/east coordinates are typed as-is, including a leading zero.
-- If that 0 is stored as a digit instead of a sign, clear it so the value is not shifted.
local function DTC_KA50_PrepareSign(wantNegative, signName, textName)
    if tonumber(wantNegative) ~= 1 then
        return
    end

    DTC_KA50_Press(KA50_CMD_0)
    local ind = DTC_KA50_ReadPvi()
    if DTC_KA50_LineIsNegative(ind, signName, textName) then
        return
    end

    if DTC_KA50_Field(ind, textName) ~= "" then
        DTC_KA50_Press(KA50_CMD_CANCEL)
    end
end

function DTC_KA50_ExecCmd_BeginWaypointUpload()
    DTC_Log("KA50 PVI waypoint upload start")
    DTC_KA50_SetMode(KA50_MODE_ENTER)
    DTC_KA50_Press(KA50_CMD_CANCEL)
end

function DTC_KA50_ExecCmd_EnterWaypoint(seq, latDigits, latNeg, lonDigits, lonNeg)
    DTC_Log("KA50 PVI enter " .. tostring(seq) .. " lat=" .. tostring(latDigits) .. " lon=" .. tostring(lonDigits))
    DTC_KA50_Press(KA50_CMD_CANCEL)
    DTC_KA50_Press(KA50_CMD_WPT)
    DTC_KA50_TypeDigits(tostring(seq))
    DTC_KA50_Press(KA50_CMD_ENTER)
    DTC_Wait(150)

    DTC_KA50_PrepareSign(latNeg, "txt_VIT_sign", "txt_VIT")
    DTC_KA50_TypeDigits(tostring(latDigits))
    DTC_KA50_Press(KA50_CMD_ENTER)
    DTC_Wait(150)

    DTC_KA50_PrepareSign(lonNeg, "txt_NIT_sign", "txt_NIT")
    DTC_KA50_TypeDigits(tostring(lonDigits))
    DTC_KA50_Press(KA50_CMD_ENTER)
    DTC_Wait(250)
end

function DTC_KA50_ExecCmd_EndWaypointUpload()
    DTC_KA50_SetMode(KA50_MODE_OPER)
    DTC_Log("KA50 PVI waypoint upload done")
end

function DTC_KA50_AfterNextFrame(params)
    local mainPanel = GetDevice(0)
    local accelReset = mainPanel:get_argument_value(KA50_ACCEL_RESET_ARG)
    if accelReset == 1 then
        params["uploadCommand"] = "1"
    end
end
