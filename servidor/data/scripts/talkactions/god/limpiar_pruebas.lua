-- Limpia los objetos que dejan las pruebas vivas de QA.
--
--   /limpiarpruebas            saca parcels y etiquetas del inventario
--   /limpiarpruebas 2595,2599  saca esos server ids
--
-- Las pruebas se crean sus propios objetos con `/i` y a veces quedan a medio
-- camino, llenando la mochila del personaje de pruebas. Esto lo ordena sin
-- tocar nada del mundo ni de otros jugadores.

local POR_DEFECTO = {2595, 2596, 2599, 2597, 2598}

local talkaction = TalkAction("/limpiarpruebas")

local function limpiarContenedor(contenedor, ids, sacados)
	for i = contenedor:getSize() - 1, 0, -1 do
		local item = contenedor:getItem(i)
		if item then
			if item:isContainer() then
				limpiarContenedor(item, ids, sacados)
			end
			for _, id in ipairs(ids) do
				if item:getId() == id then
					sacados[1] = sacados[1] + 1
					item:remove()
					break
				end
			end
		end
	end
end

function talkaction.onSay(player, words, param)
	if not player:getGroup():getAccess() then
		return true
	end

	local ids = {}
	if param ~= "" then
		for _, texto in ipairs(param:split(",")) do
			local id = tonumber(texto)
			if id then
				ids[#ids + 1] = id
			end
		end
	end
	if #ids == 0 then
		ids = POR_DEFECTO
	end

	local sacados = {0}
	-- Las diez ranuras del equipo 7.72: cabeza, amuleto, mochila, armadura,
	-- las dos manos, piernas, pies, anillo y municion.
	for slot = 1, 10 do
		local item = player:getSlotItem(slot)
		if item then
			if item:isContainer() then
				limpiarContenedor(item, ids, sacados)
			end
			for _, id in ipairs(ids) do
				if item:getId() == id then
					sacados[1] = sacados[1] + 1
					item:remove()
					break
				end
			end
		end
	end

	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		string.format("limpiarpruebas: se sacaron %d objetos", sacados[1]))
	return false
end

talkaction:access(true)
talkaction:separator(" ")
talkaction:register()
