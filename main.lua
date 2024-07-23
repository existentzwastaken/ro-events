--[[

*== RoEvents ==*

->@author existentza
->@creation_date 21/07/24 12:45 PM
->@version v0.1
->@update_date 24/07/24 00:09 AM

require asset id 18626279464 for the updated version!
]]-- 

-- [[ TYPES ]] -- 
export type SettingsType = {
	ObservForTime: number;
	SuspiciousCallRate: number?; -- Seconds
	
	BotLinked: boolean?;
	WebhookLinked: string?;
}

export type SentInfoType = {
	EventName : string;
	SentParams : {}?;
	FiredFrom : string;
	FiredBy : Player | nil;
}

-- [[ SETTINGS ]]--
local Settings: SettingsType = {
	ObservForTime = 60; -- Every how many (s) will the fires in the time fraction reset
	SuspiciousCallRate = 60; -- How many calls in the time ObservForTime are suspcious

	WebhookLinked = "YOUR-WEBHOOK";
}

local DEBUG = true -- Prints

-- [[ MODULE STARTS FROM HERE ]] --
-- SERVICES
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- PRIVATE FUNCTIONS
local function debugMessage(Message: string, Level)
	if not DEBUG then return end
	
	if Level == 0 then
		print(Message)
	elseif Level == 1 then
		warn(Message)
	else
		error(Message)
	end
end

local function StringTbl(Table: {})
	local stringTable = ""
	for Index, Value in Table do
		local value = Value
		if type(value) == "table" then
			value = "{"..StringTbl(Value).."}"
		else
			value = tostring(value)
		end
		stringTable ..= "\n["..tostring(Index).."] = "..value..";"
	end
	return stringTable
end

local function SendInfos(Info: SentInfoType, InfoType: boolean, EventInfo)
	local payload = {
		embeds = {
			{
				title = `· Event Call Log | {Info.EventName} {InfoType and "Suspicious Call" or ""}`,
				description = `**Event Name: {Info.EventName}\nFired From: {Info.FiredFrom}\n\nFired by:\n Username: {Info.FiredBy.Name}\n User Id: {Info.FiredBy.UserId}\n Profile Link: https://www.roblox.com/users/{Info.FiredBy.UserId}/profile \n\nServer ID: {game.JobId}\n\nFired {EventInfo.timefractionCalls} in {math.floor(tick() - EventInfo.timeFraction)} seconds.\n Fired {EventInfo.totalCalls} since server startup.\n\n**`..`Params Sent: {StringTbl(Info.SentParams)}`;
				color = InfoType and 16711680 or 65280;
				footer = {
					text = os.date();
				}
			}
		}
	}

	local headers = {
		["Content-Type"] = "application/json";
	}

	local options = {
		Url = Settings.WebhookLinked;
		Method = "POST";
		Headers = headers;
		Body = HttpService:JSONEncode(payload)
	}

	local sendSuccess, response = pcall(HttpService.RequestAsync, HttpService, options)
	if not sendSuccess then
		debugMessage(response, 1)
	end
end

local Events = {}
local RoEvents = {}

-- PUBLIC FUNCTIONS
function RoEvents.IsEventBeingListened(ReqEvent: RemoteEvent)
	for _, Event in Events do
		if Event == ReqEvent then return true end
	end

	return false
end

local UpdatedEvents = {}
function RoEvents.UpdateAsync(Event, Params, EventInfo)
	local SentInfos: SentInfoType = {
		EventName = Event.Name;
		SentParams = Params.Params;
		FiredFrom = RunService:IsServer() and "Client" or "Server";
		FiredBy = Params.Player or nil;
	}
	SendInfos(SentInfos, Params.Frequence, EventInfo)
end

function RoEvents:IsCallFrequenceSuspicious(EventInfos)
	return (EventInfos.timefractionCalls > Settings.SuspiciousCallRate)
end

function RoEvents.ListenToEvent(Event: RemoteEvent)
	-- Search if event exist
	if RoEvents.IsEventBeingListened(Event) then 
		debugMessage(`[S] Listen Request for event: {Event.Name} rejected | Reason: Event is already being listened to`)
		return
	end
	
	local EventInfos = {
		totalCalls = 0;
		timefractionCalls = 0;
		timeFraction = tick()
	}
	
	if RunService:IsServer() then
		Event.OnServerEvent:Connect(function(PlayerWhoFired, ...)
			local Params = {Player = PlayerWhoFired, Params = {...}, Frequence = RoEvents:IsCallFrequenceSuspicious(EventInfos)}
			EventInfos.timefractionCalls += 1
			EventInfos.totalCalls += 1
			RoEvents.UpdateAsync(Event, Params, EventInfos)
		end)
	end
	
	task.spawn(function()
		while task.wait(Settings.ObservForTime) do
			EventInfos.timefractionCalls = 0
			EventInfos.timeFraction = tick()
		end
	end)

	table.insert(Events, Event)
end 

function RoEvents:ListenInit()
	local loadingTime = tick()
	
	for _, Event in game:GetDescendants() do
		if not Event:IsA("RemoteEvent") then continue end
		
		RoEvents.ListenToEvent(Event)
	end
	
	debugMessage(`[S] Server Listening to {#Events}. Started In {tick() - loadingTime} seconds`, 1)	
end

return RoEvents
