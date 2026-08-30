-- Diagnostico de QA: fuerza la calavera propia sin necesidad de un PK real.
--
--   /setskull none|yellow|green|white|red
--   /setskull 0..4
--
-- Creature:setSkull ya llama a Game::updateCreatureSkull, que manda el 0x90
-- a los espectadores; esto no inventa ningun paquete nuevo, solo evita tener
-- que provocar un homicidio de verdad para ver el marcador en el cliente.

local NOMBRES = {
	["none"] = SKULL_NONE,
	["yellow"] = SKULL_YELLOW,
	["green"] = SKULL_GREEN,
	["white"] = SKULL_WHITE,
	["red"] = SKULL_RED,
}

local talkaction = TalkAction("/setskull")

function talkaction.onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	local valor = NOMBRES[param:lower()]
	if not valor then
		valor = tonumber(param)
	end
	if not valor or valor < SKULL_NONE or valor > SKULL_RED then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			"setskull: none|yellow|green|white|red o 0-4")
		return false
	end

	player:setSkull(valor)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		string.format("setskull: calavera propia en %d", valor))
	return false
end

talkaction:access(true)
talkaction:separator(" ")
talkaction:register()
