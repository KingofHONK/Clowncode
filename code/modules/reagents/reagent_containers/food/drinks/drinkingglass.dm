/obj/item/weapon/reagent_containers/food/drinks/drinkingglass
	name = "drinking glass"
	desc = "Your standard drinking glass."
	icon_state = "glass_empty"
	item_state = "glass_empty"
	isGlass = 1
	amount_per_transfer_from_this = 10
	volume = 50
	starting_materials = list(MAT_GLASS = 500)
	force = 5
	smashtext = ""  //due to inconsistencies in the names of the drinks just don't say anything
	smashname = "broken glass"
	melt_temperature = MELTPOINT_GLASS
	w_type=RECYK_GLASS
	var/list/datum/reagent/drink/available_drinks = list() //for changeling stab
	var/switching = FALSE
	var/current_path = null
	var/counter = 1

	can_flip = TRUE

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/on_reagent_change()
	..()
	flammable = 0
	if(!molotov)
		lit = 0
		light_color = null
		set_light(0)
	origin_tech = ""
	available_drinks.Cut()
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/update_icon()
	..()
	overlays.len = 0
	can_flip = FALSE

	if (reagents.reagent_list.len > 0)
		if(reagents.has_reagent(BLACKCOLOR))
			icon_state ="blackglass"
			name = "international drink of mystery"
			desc = "The identity of this drink has been concealed for its protection."
		else
			var/datum/reagent/R = reagents.get_master_reagent()
			R.when_drinkingglass_master_reagent(src)

			if(R.light_color)
				light_color = R.light_color

			name = R.glass_name ? R.glass_name : "glass of " + R.name //uses glass of [reagent name] if a glass name isn't defined
			desc = R.glass_desc ? R.glass_desc : R.description //uses the description if a glass description isn't defined
			isGlass = R.glass_isGlass

			if(istype(R,/datum/reagent/ethanol/drink/changelingsting/stab))
				available_drinks = subtypesof(/datum/reagent/drink) + subtypesof(/datum/reagent/ethanol/drink)
				available_drinks = shuffle(available_drinks)
				randomize()
			else if(R.glass_icon_state)
				icon_state = R.glass_icon_state
				item_state = R.glass_icon_state
			else
				icon_state ="glass_colour"
				item_state ="glass_colour"
				var/image/filling = image('icons/obj/reagentfillings.dmi', src, "glass")
				filling.icon += mix_color_from_reagents(reagents.reagent_list)
				filling.alpha = mix_alpha_from_reagents(reagents.reagent_list)
				overlays += filling

			if(R.flammable)
				if(lit)
					var/image/I = image(icon, src, "[icon_state]-flamin")
					I.blend_mode = BLEND_ADD
					if (isturf(loc))
						I.plane = ABOVE_LIGHTING_PLANE
					else
						I.plane = ABOVE_HUD_PLANE // inventory
					overlays += I
					name = "flaming [name]"
					desc += " Damn that looks hot!"
				else
					flammable = 1
	else
		icon_state = "glass_empty"
		item_state = "glass_empty"
		name = "drinking glass"
		desc = "Your standard drinking glass."
		can_flip = TRUE

	if(iscarbon(loc))
		var/mob/living/carbon/M = loc
		M.update_inv_hands()

	update_temperature_overlays()
	update_blood_overlay()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/attack_self(mob/user)
	if(switching)
		getnofruit(user)
	else
		..()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/attackby(obj/item/weapon/W, mob/user)
	if(switching)
		getnofruit(user,W)
	else
		..()


/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/proc/randomize()
	if(!available_drinks.len || switching)
		return
	switching = TRUE
	mouse_opacity = 2
	spawn()
		while(switching)
			overlays.Cut()
			current_path = available_drinks[counter]
			var/datum/reagent/drink/D = new current_path
			if(D.glass_icon_state)
				icon_state = initial(D.glass_icon_state)
				item_state = initial(D.glass_icon_state)
			else
				icon_state ="glass_colour"
				item_state ="glass_colour"
				var/image/filling = image('icons/obj/reagentfillings.dmi', src, "glass")
				filling.icon += mix_color_from_reagents(reagents.reagent_list)
				filling.alpha = mix_alpha_from_reagents(reagents.reagent_list)
				overlays += filling
			qdel(D)
			sleep(4)
			if(counter == available_drinks.len)
				counter = 0
				available_drinks = shuffle(available_drinks)
			counter++

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/proc/getnofruit(mob/user, obj/item/weapon/W = null)
	if(!switching || !current_path)
		return
	switching = FALSE
	if(get_turf(user))
		playsound(user, "swing_hit", 50, 1)
	if(W)
		user.visible_message("[user] smacks \the [src] with \the [W].","You smack \the [src] with \the [W].")
	else
		user.visible_message("[user] smacks \the [src].","You smack \the [src].")
	reagents.clear_reagents()
	var/datum/reagent/drink/D = new current_path
	reagents.add_reagent(D.id, 50)
	qdel(D)
	on_reagent_change()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/examine(mob/user)
	..()
	if(reagents.get_master_reagent_id() == METABUDDY && istype(user) && user.client)
		to_chat(user,"<span class='warning'>This one is made out to 'My very best friend, [user.client.ckey]'</span>")

// for /obj/machinery/vending/sovietsoda
/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/soda/New()
	..()
	reagents.add_reagent(SODAWATER, 50)
	on_reagent_change()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/cola/New()
	..()
	reagents.add_reagent(COLA, 50)
	on_reagent_change()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/toxinsspecial/New()
	..()
	reagents.add_reagent(TOXINSSPECIAL, 30)
	on_reagent_change()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/irishcoffee
	name = "irish coffee"

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/irishcoffee/New()
	..()
	reagents.add_reagent(IRISHCOFFEE, 50)
	on_reagent_change()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/irishcoffee/on_vending_machine_spawn()
	reagents.chem_temp = COOKTEMP_READY

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/sake
	name = "glass of sake"

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/sake/New()
	..()
	reagents.add_reagent(SAKE, 50)
	on_reagent_change()

// Cafe Stuff. Mugs act the same as drinking glasses, but they don't break when thrown.

/obj/item/weapon/reagent_containers/food/drinks/mug
	name = "mug"
	desc = "A simple mug."
	icon = 'icons/obj/cafe.dmi'
	icon_state = "mug_empty"
	item_state = "mug_empty"
	isGlass = 0
	amount_per_transfer_from_this = 10
	volume = 30
	starting_materials = list(MAT_IRON = 500)

/obj/item/weapon/reagent_containers/food/drinks/mug/on_reagent_change()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/mug/update_icon()
	..()
	if (reagents.reagent_list.len > 0)
		//item_state = "mug_empty"

		var/datum/reagent/R = reagents.get_master_reagent()

		name = R.mug_name ? R.mug_name : "mug of " + R.name
		desc = R.mug_desc ? R.mug_desc : R.description

		if(R.mug_icon_state)
			icon_state = R.mug_icon_state
			//item_state = R.mug_icon_state
			//looks like there is none made yet so at least let's not hold an invisible mug
		else
			mug_reagent_overlay()
	else
		icon_state = "mug_empty"
		name = "mug"
		desc = "A simple mug."

/obj/item/weapon/reagent_containers/food/drinks/proc/mug_reagent_overlay()
	icon_state = base_icon_state
	var/image/filling = image('icons/obj/reagentfillings.dmi', src, "mug")
	filling.icon += mix_color_from_reagents(reagents.reagent_list)
	filling.alpha = mix_alpha_from_reagents(reagents.reagent_list)
	overlays += filling
