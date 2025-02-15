/*
	Click code cleanup
	~Sayu
*/

//BYOND has a quirk (maybe bug?) where, if you initiate a clickdrag with one mouse button, any clicks with another button during the drag hit the object being dragged.
//This allowed you to, for example, start a middle-click drag on someone and then have an aimbot that allows you to effortlessly hit them in melee or ranged combat as long as you held MMB.
//This code discards clicks performed during a drag to prevent this.

//As of 2024 this code has been commented out because the bug/exploit is no longer active.
// /client/Click(object, location, control, params)
// 	var/list/p = params2list(params)
// 	if(p["drag"])
// 		return
// 	..()

/*
	Before anything else, defer these calls to a per-mobtype handler.  This allows us to
	remove istype() spaghetti code, but requires the addition of other handler procs to simplify it.

	Alternately, you could hardcode every mob's variation in a flat ClickOn() proc; however,
	that's a lot of code duplication and is hard to maintain.

	Note that this proc can be overridden, and is in the case of screen objects.
*/
/atom/Click(location,control,params)
	usr.ClickOn(src, params)

/atom/DblClick(location,control,params)
	usr.DblClickOn(src,params)

//MouseDrop
/mob/living/carbon/MouseDrop(var/mob/living/carbon/first, var/second_turf, over_location, src_control, over_control, params)
	var/mob/living/carbon/second = locate() in second_turf
	if (!istype(first) || !second || (first == usr && second == usr) || (first == second)) //if user is dragging only on himself or user drags and drops on the same target
		return ..()
	var/obj/item/to_be_handcuffs = usr.get_active_hand()
	if (first.Adjacent(usr) && second.Adjacent(usr) && istype(to_be_handcuffs, /obj/item/weapon/handcuffs))
		var/obj/item/weapon/handcuffs/handcuffs = to_be_handcuffs
		handcuffs.apply_mutual_cuffs(first, second, usr)
		return
	..()

/*
	Standard mob ClickOn()
	Handles exceptions: Buildmode, middle click, modified clicks, mech actions

	After that, mostly just check your state, check whether you're holding an item,
	check whether you're adjacent to the target, then pass off the click to whoever
	is receiving it.
	The most common are:
	* mob/UnarmedAttack(atom,adjacent,params) - used here only when adjacent, with no item in hand; in the case of humans, checks gloves
	* atom/attackby(item,user,params) - used only when adjacent
	* item/afterattack(atom,user,adjacent,params) - used both ranged and adjacent
	* mob/RangedAttack(atom,params) - used only ranged, only used for tk and laser eyes but could be changed
*/

#define MAX_ITEM_DEPTH	3 //how far we can recurse before we can't get an item

/mob/proc/ClickOn( var/atom/A, var/params )
	if(!click_delayer)
		click_delayer = new
	if(timestopped)
		return 0 //under effects of time magick

	if(click_delayer.blocked())
		return
	click_delayer.setDelay(1)

	if(client && client.buildmode)
		build_click(src, client.buildmode, params, A)
		return

	var/obj/item/held_item = get_active_hand()

	var/list/modifiers = params2list(params)
	INVOKE_EVENT(src, /event/clickon, "user" = src,	"modifiers" = modifiers, "target" = A)
	if(modifiers["middle"])
		if(modifiers["shift"])
			MiddleShiftClickOn(A)
		else if (modifiers["alt"])
			MiddleAltClickOn(A)
		else
			MiddleClickOn(A)
		return
	if(modifiers["shift"])
		ShiftClickOn(A)
		return
	if(modifiers["alt"]) // alt and alt-gr (rightalt)
		if (held_item && held_item.AltFrom(A,src,A.Adjacent(src, MAX_ITEM_DEPTH),params))
			return
		AltClickOn(A)
		return
	if(modifiers["ctrl"])
		CtrlClickOn(A)
		return
	if(modifiers["right"])
		RightClickOn(A)
		return

	if(attempt_crawling(A))
		return

	if(isStunned())
		return

	face_atom(A) // change direction to face what you clicked on

	if(attack_delayer.blocked()) // This was next_move.  next_attack makes more sense.
		return
//	to_chat(world, "next_attack is [next_attack] and world.time is [world.time]")
	if(istype(loc,/obj/mecha))
		if(!locate(/turf) in list(A,A.loc)) // Prevents inventory from being drilled
			return
		var/obj/mecha/M = loc
		return M.click_action(A,src)

	if(restrained())
		RestrainedClickOn(A)
		return

	if(in_throw_mode)
		if(!get_active_hand() && (a_intent == I_DISARM))
			doTackle(A)
		else
			throw_item(A)
		return

	var/item_attack_delay = 0

	if(held_item == A)
		held_item.attack_self(src, params)
		update_inv_hand(active_hand)

		return

	if(!isturf(loc) && !is_holder_of(src, A))
		if(loc == A) //Can attack_hand our holder (a locked closet, for example) from inside, but can't hit it with a tool
			if(held_item)
				return
		else
			return

	//Clicked on an adjacent atom
	// - Allows you to click on a box's contents, if that box is on the ground, but no deeper than that
	if(A.Adjacent(src, MAX_ITEM_DEPTH)) // see adjacent.dm
		if(held_item)
			item_attack_delay = held_item.attack_delay
			var/resolved = held_item.preattack(A, src, 1, params)
			if(!resolved)
				resolved = A.attackby(held_item, src, params)
				if(ismob(A) && a_intent == I_HELP && can_operate(A, src, held_item) && !A.gcDestroyed)
					delayNextAttack(SURGERY_DELAY_TIME) //Surgery steps use the click delay (0.1 second)
				else if((ismob(A) || istype(A, /obj/mecha) || istype(held_item, /obj/item/weapon/grab)) && !A.gcDestroyed)
					delayNextAttack(item_attack_delay)
				if(!resolved && A && !A.gcDestroyed && held_item && !held_item.gcDestroyed)
					held_item.afterattack(A,src,1,params) // 1 indicates adjacency
		else
			if(ismob(A) || istype(held_item, /obj/item/weapon/grab))
				delayNextAttack(10)
			if(INVOKE_EVENT(src, /event/uattack, "atom" = A)) //This returns 1 when doing an action intercept
				return
			UnarmedAttack(A, 1, params)

	//Clicked on a non-adjacent atom
	else
		//If the player's view is not centered on the mob, check how far the clicked object is from the mob
		//This is to prevent abuse with remote view / camera consoles
		if(client && client.eye && client.eye != client.mob)
			var/view_range = get_view_range() + 2 //Extend clickable zone by 2 tiles to allow clicking on the edge of the screen while the camera is moving
			var/atom_distance = get_dist(A, src)  //Distance from the player's mob to the clicked atom

			if(atom_distance <= view_range)
				//Clicked on a non-adjacent atom in view
				RangedClickOn(A, params, held_item)
			else
				//Clicked on a non-adjacent atom that is not in view
				RemoteClickOn(A, params, held_item, client.eye)
		else if(mind && mind.assigned_role == "AI") // clown AI stuff
			if(spell_channeling)
				spell_channeling.channeled_spell(A, bypassrange = TRUE)
			else if(istype(A,/obj/machinery/door/airlock))
				var/obj/machinery/door/airlock/D = A
				if(D.density)
					D.Topic("aiEnable=7", list("aiEnable"="7"), 1)
				else
					D.Topic("aiDisable=7", list("aiDisable"="7"), 1)
			else
				RangedClickOn(A, params, held_item)
		else
			RangedClickOn(A, params, held_item)

/mob/proc/RangedClickOn(atom/A, params, obj/item/held_item)
	if(held_item)
		if(ismob(A))
			delayNextAttack(held_item.attack_delay)

		if(!held_item.preattack(A, src, 0,  params))
			held_item.afterattack(A,src,0,params) // 0: not Adjacent
	else
		if(ismob(A))
			delayNextAttack(10)
		if(INVOKE_EVENT(src, /event/uattack, "atom" = A)) //This returns 1 when doing an action intercept
			return
		RangedAttack(A, params)

//By default, do nothing if clicked on something that is not in view
/mob/proc/RemoteClickOn(atom/A, params, obj/item/held_item, atom/movable/eye)
	if(held_item)
		held_item.remote_attack(A, src, eye)

// Default behavior: ignore double clicks, consider them normal clicks instead
/mob/proc/DblClickOn(var/atom/A, var/params)
	return

/*
	Translates into attack_hand, etc.

	Note: proximity_flag here is used to distinguish between normal usage (flag=1),
	and usage when clicking on things telekinetically (flag=0).  This proc will
	not be called at ranged except with telekinesis.

	proximity_flag is not currently passed to attack_hand, and is instead used
	in human click code to allow glove touches only at melee range.
*/
/mob/proc/UnarmedAttack(var/atom/A, var/proximity_flag, var/params)
	if(ismob(A))
		delayNextAttack(10)
	return

/*
	Ranged unarmed attack:

	This currently is just a default for all mobs, involving
	laser eyes and telekinesis.  You could easily add exceptions
	for things like ranged glove touches, spitting alien acid/neurotoxin,
	animals lunging, etc.
*/
/mob/proc/RangedAttack(var/atom/A, var/params)
	if(!mutations || !mutations.len)
		return
	if((M_LASER in mutations) && a_intent == I_HURT)
		LaserEyes(A) // moved into a proc below
	else if(M_TK in mutations)
		/*switch(get_dist(src,A))
			if(0)
				;
			if(1 to 5) // not adjacent may mean blocked by window
				next_move += 2
			if(5 to 7)
				next_move += 5
			if(8 to tk_maxrange)
				next_move += 10
			else
				return
		*/
		A.attack_tk(src)
/*
	Restrained ClickOn

	Used when you are handcuffed and click things.
	Not currently used by anything but could easily be.
*/
/mob/proc/RestrainedClickOn(var/atom/A)
	INVOKE_EVENT(src, /event/ruattack, "atom" = A)

/*
	Middle click
	Only used for swapping hands
*/
/mob/proc/MiddleClickOn(var/atom/A)
	return
/mob/living/carbon/MiddleClickOn(var/atom/A)
	swap_hand()

// In case of use break glass
/*
/atom/proc/MiddleClick(var/mob/M as mob)
	return
*/

/mob/proc/MiddleShiftClickOn(var/atom/A)
	A.MiddleShiftClick(src)

/atom/proc/MiddleShiftClick(var/mob/user)
	user.pointed(src)


/*
	Shift click
	For most mobs, examine.
	This is overridden in ai.dm
*/
/mob/proc/ShiftClickOn(var/atom/A)
	A.ShiftClick(src)
	return
/atom/proc/ShiftClick(var/mob/user)
	if(user.client && user.client.eye == user)
		user.examination(src)
	return

/*
	Ctrl click
	For most objects, pull
*/
/mob/proc/CtrlClickOn(var/atom/A)
	A.CtrlClick(src)
	return
/atom/proc/CtrlClick(var/mob/user)
	user.stop_pulling()
	return

/atom/movable/CtrlClick(var/mob/user)
	if(Adjacent(user))
		user.start_pulling(src)

/*
	Right Click
*/

/mob/proc/RightClickOn(var/atom/A)
	A.RightClick()

/atom/proc/RightClick(var/mob/user)
	return


/*
	Alt click
*/

/mob/proc/MiddleAltClickOn(var/atom/A)
	A.MiddleAltClick(src)
	return

/atom/proc/MiddleAltClick(var/mob/user)
	return

/mob/proc/AltClickOn(var/atom/A)
	A.AltClick(src)
	return

/atom/proc/AltClick(var/mob/user)
	var/turf/T = get_turf(src)
	var/valid = FALSE
	if(isAI(user))
		var/mob/living/silicon/ai/ai = user
		if(T && (T in range(7, ai.eyeobj.loc)))
			valid = TRUE
	else if(T && (T in range(1, user.loc)) && (T in view(1, user.virtualhearer))) //If next to user's location (to allow locker and mech alt-clicks) and if the user can actually view it
		valid = TRUE
	if(valid)
		if(user.listed_turf == T)
			user.listed_turf = null
		else
			user.listed_turf = T
			user.client.statpanel = T.name

/mob/living/carbon/AltClick(var/mob/user)
	if(!(user == src) && user.Adjacent(src))
		if((meat_type || butchering_drops) && (stat == DEAD))	//if the carbon has a meat, and if it is dead.
			var/obj/item/item_in_hand = user.get_active_hand()
			if(item_in_hand && (item_in_hand.sharpness_flags & SHARP_BLADE))
				butcher()
				return 1
		else if(!isrobot(user))
			src.give_item(user)
			return
	..()

/*
	Misc helpers

	Laser Eyes: as the name implies, handles this since nothing else does currently
	face_atom: turns the mob towards what you clicked on
*/
/mob/proc/LaserEyes(atom/A)
	return

/mob/living/LaserEyes(atom/A)
	//next_move = world.time + 6
	delayNextAttack(4)
	var/turf/T = get_turf(src)
	var/turf/U = get_turf(A)

	var/obj/item/projectile/beam/LE = new /obj/item/projectile/beam(loc)
	LE.icon = 'icons/effects/genetics.dmi'
	LE.icon_state = "eyelasers"
	playsound(usr.loc, 'sound/weapons/laser2.ogg', 75, 1)

	LE.firer = src
	LE.def_zone = get_organ_target()
	LE.original = A
	LE.current = T
	LE.yo = U.y - T.y
	LE.xo = U.x - T.x
	LE.starting = T
	LE.original = A
	LE.target = U

	spawn( 1 )
		LE.OnFired()
		LE.process()

/mob/living/carbon/human/LaserEyes()
	if(burn_calories(0.5))
		nutrition = max(0,nutrition-2)
		..()
		handle_regular_hud_updates()
	else
		to_chat(src, "<span class='warning'>You're out of energy!  You need food!</span>")

// Simple helper to face what you clicked on, in case it should be needed in more than one place
/mob/proc/face_atom(var/atom/A)
	if(stat != CONSCIOUS || locked_to || !A || !x || !y || !A.x || !A.y )
		return

	var/dx = A.x - x
	var/dy = A.y - y

	if(!dx && !dy) // Wall items are graphically shifted but on the floor
		if(A.pixel_y > 16)
			change_dir(NORTH)
		else if(A.pixel_y < -16)
			change_dir(SOUTH)
		else if(A.pixel_x > 16)
			change_dir(EAST)
		else if(A.pixel_x < -16)
			change_dir(WEST)

		INVOKE_EVENT(src, /event/before_move)
		INVOKE_EVENT(src, /event/face)
		INVOKE_EVENT(src, /event/after_move)
		return

	if(abs(dx) < abs(dy))
		if(dy > 0)
			change_dir(NORTH)
		else
			change_dir(SOUTH)
	else
		if(dx > 0)
			change_dir(EAST)
		else
			change_dir(WEST)

	INVOKE_EVENT(src, /event/before_move)
	INVOKE_EVENT(src, /event/face)
	INVOKE_EVENT(src, /event/after_move)


// File renamed to mouse.dm?
/atom/MouseWheel(delta_x,delta_y,location,control,params)
	usr.MouseWheelOn(src, delta_x, delta_y, params)


/mob/proc/MouseWheelOn(var/atom/object, var/delta_x, var/delta_y, var/params)
	if (timestopped || isStunned())
		return FALSE

	var/obj/item/W = get_active_hand()
	if (W)
		W.MouseWheeled(src, delta_x, delta_y, params)

//Currently used to allow a little bit of freedom in click-dragging for melee combat in _onclick/drag_drop.dm
/mob/living/MouseDown(location, control, params, var/past_time)
	usr.client.click_held_down_time = world.timeofday
