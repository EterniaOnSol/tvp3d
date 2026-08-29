-- Diagnostico de casilla para QA: dice que ve el servidor en una posicion.
--
--   /tileinfo            la casilla donde esta parado el god
--   /tileinfo x,y,z      una casilla cualquiera
--
-- Sirve para responder preguntas que desde el cliente son solo suposiciones:
-- si el servidor reconoce un mailbox o un depot en esa casilla, y que texto
-- llevan los items escribibles que hay encima.

local talkaction = TalkAction("/tileinfo")

function talkaction.onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	local pos = player:getPosition()
	local partes = param:split(",")
	if #partes >= 3 then
		pos = {
			x = tonumber(partes[1]),
			y = tonumber(partes[2]),
			z = tonumber(partes[3]),
		}
	end

	local tile = Tile(pos)
	if not tile then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
			string.format("tileinfo %d,%d,%d: no hay casilla", pos.x, pos.y, pos.z))
		return false
	end

	local mailbox = tile:getItemByType(ITEM_TYPE_MAILBOX)
	local depot = tile:getItemByType(ITEM_TYPE_DEPOT)
	local house = tile:getHouse()
	-- La bandera es lo que dispara la entrega en `Tile::postAddNotification`;
	-- que el item este no alcanza si el tile no quedo marcado.
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
		"tileinfo %d,%d,%d: house=%s mailbox=%s depot=%s items=%d flagMailbox=%s flagPZ=%s",
		pos.x, pos.y, pos.z,
		house and house:getId() or "no",
		mailbox and mailbox:getId() or "no",
		depot and depot:getId() or "no",
		tile:getItemCount(),
		tostring(tile:hasFlag(TILESTATE_MAILBOX)),
		tostring(tile:hasFlag(TILESTATE_PROTECTIONZONE))))

	for _, item in ipairs(tile:getItems() or {}) do
		local texto = item:getAttribute(ITEM_ATTRIBUTE_TEXT)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
			"  item %d (%s)%s", item:getId(), item:getName(),
			(texto ~= nil and texto ~= "") and (" texto='" .. texto:gsub("\n", " / ") .. "'") or ""))
		-- Adentro de una parcel va la etiqueta: es lo que lee
		-- `Mailbox::getReceiver` para saber a quien mandarla.
		if item:isContainer() then
			for i = 0, item:getSize() - 1 do
				local dentro = item:getItem(i)
				if dentro then
					local t = dentro:getAttribute(ITEM_ATTRIBUTE_TEXT)
					player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format(
						"    dentro: %d (%s) texto='%s'", dentro:getId(),
						dentro:getName(), tostring(t)))
				end
			end
		end
	end

	return false
end

talkaction:access(true)
talkaction:separator(" ")
talkaction:register()
