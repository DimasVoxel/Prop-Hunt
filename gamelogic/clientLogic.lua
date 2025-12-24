function client.friendlyFireWarning(amount)
	hudShowBanner("You killed " .. amount .. " players! If you kill more you will get kicked.", {amount/3,0,0})

	if amount == 4 then
		Menu()
	end
end