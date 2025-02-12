--
-- Attack Player Behaviour
--

function petz.bh_attack_player(self, pos, prty, player)
	if (self.attack_pack) and not(self.warn_asensorsttack) then
		if petz.bh_check_pack(self) then
			self.warn_attack = true
		end
	end
	local werewolf = false
	if petz.settings["lycanthropy"] then
		if petz.is_werewolf(player) then
			werewolf = true
		end
	end
	if (not(self.tamed) and not(werewolf)) or (self.tamed and self.status == "guard" and player:get_player_name() ~= self.owner) then
		local player_pos = player:get_pos()
		if vector.distance(pos, player_pos) <= self.view_range then	-- if player close
			if (self.attack_player and not(self.avoid_player)) or (self.warn_attack) then --attack player
				if self.can_swin then
					kitz.hq_aqua_attack(self, prty, player, 6)
				elseif self.can_fly then
					petz.hq_flyhunt(self, prty, player)
				else
					petz.hq_hunt(self, prty, player) -- try to repel them
				end
				return true
			else
				if not(self.can_swin) and not(self.can_fly) then
					if self.avoid_player then
						kitz.hq_runfrom(self, prty, player)  -- run away from player
						return true
					else
						return false
					end
				else
					return false
				end
			end
		else
			return false
		end
	else
		return false
	end
end

function petz.hq_hunt(self,prty,tgtobj)
	local func = function()
		if not kitz.is_alive(tgtobj) then return true end
		if kitz.is_queue_empty_low(self) and self.isonground then
			local pos = kitz.get_stand_pos(self)
			local opos = tgtobj:get_pos()
			local dist = vector.distance(pos,opos)
			if dist > self.view_range then
				return true
			elseif dist > 3 then
				kitz.goto_next_waypoint(self,opos)
			else
				petz.hq_attack(self,prty+1,tgtobj)
			end
		end
	end
	kitz.queue_high(self,func,prty)
end

function petz.is_pos_in_box(self, pos,bpos,box)
	if not self.collisionbox_offset then
		self.collisionbox_offset = {x=0, y=0, z= 0}
	end
	return pos.x > bpos.x+box[1]+(self.collisionbox_offset.x or 0) and pos.x < bpos.x+box[4]+(self.collisionbox_offset.x or 0) and
			pos.y > bpos.y+box[2]+(self.collisionbox_offset.y or 0) and pos.y < bpos.y+box[5]+(self.collisionbox_offset.y or 0) and
			pos.z > bpos.z+box[3]+(self.collisionbox_offset.z or 0) and pos.z < bpos.z+box[6]+(self.collisionbox_offset.z or 0)
end

function petz.hq_attack(self,prty,tgtobj)
	local func = function()
		if not kitz.is_alive(tgtobj) then return true end
		if kitz.is_queue_empty_low(self) then
			local pos = kitz.get_stand_pos(self)
--			local tpos = tgtobj:get_pos()
			local tpos = kitz.get_stand_pos(tgtobj)
			local dist = vector.distance(pos,tpos)
			if dist > 3 then
				return true
			else
				kitz.lq_turn2pos(self,tpos)
				local height = tgtobj:is_player() and 0.35 or tgtobj:get_luaentity().height*0.6
				if tpos.y+height>pos.y then
					petz.lq_jumpattack(self,tpos.y+height-pos.y,tgtobj)
				else
					kitz.lq_dumbwalk(self,kitz.pos_shift(tpos,{x=math.random()-0.5,z=math.random()-0.5}))
				end
			end
		end
	end
	kitz.queue_high(self,func,prty)
end

function petz.lq_jumpattack(self,height,target)
	local phase=1
	local func=function()
		if not kitz.is_alive(target) then return true end
		if self.isonground then
			if phase==1 then	-- collision bug workaround
				local vel = self.object:get_velocity()
				vel.y = -kitz.gravity*math.sqrt(height*2/-kitz.gravity)
				self.object:set_velocity(vel)
				kitz.make_sound(self,'charge')
				phase=2
			else
				kitz.lq_idle(self,0.3)
				return true
			end
		elseif phase==2 then
			local dir = minetest.yaw_to_dir(self.object:get_yaw())
			local vy = self.object:get_velocity().y
			dir=vector.multiply(dir,6)
			dir.y=vy
			self.object:set_velocity(dir)
			phase=3
		elseif phase==3 then	-- in air
			local tgtpos = target:get_pos()
			local pos = self.object:get_pos()
			-- calculate attack spot
			local yaw = self.object:get_yaw()
			local dir = minetest.yaw_to_dir(yaw)
			local distance = vector.distance(pos, tgtpos)
			--minetest.chat_send_all(tostring(distance))
			if distance < 2.0 then
				--if petz.is_pos_in_box(self,apos,tgtpos,tgtbox) then	--bite
				target:punch(self.object,1,self.attack)
				-- bounce off
				local vy = self.object:get_velocity().y
				self.object:set_velocity({x=dir.x*-3,y=vy,z=dir.z*-3})
					-- play attack sound if defined
				kitz.make_sound(self,'attack')
				phase=4
			end
		end
	end
	kitz.queue_low(self,func)
end

---
---Fly Attack Behaviour
---

function petz.hq_flyhunt(self, prty, tgtobj)
	local func = function()
		if not kitz.is_alive(tgtobj) then return true end
		if kitz.is_queue_empty_low(self) then
			local pos = kitz.get_stand_pos(self)
			local opos = tgtobj:get_pos()
			local dist = vector.distance(pos, opos)
			if dist > self.view_range then
				return true
			elseif dist > 3 then
				petz.flyto(self, tgtobj)
			else
				--minetest.chat_send_player("singleplayer", "hq fly attack")
				petz.hq_flyattack(self, prty+1, tgtobj)
			end
		end
	end
	kitz.queue_high(self,func,prty)
end

function petz.hq_flyattack(self, prty, tgtobj)
	local func = function()
		if not kitz.is_alive(tgtobj) then
			return true
		end
		if kitz.is_queue_empty_low(self) then
			local pos = self.object:get_pos()
			local tpos = kitz.get_stand_pos(tgtobj)
			local dist = vector.distance(pos,tpos)
			if dist > 3 then
				return true
			else
				petz.lq_flyattack(self, tgtobj)
			end
		end
	end
	kitz.queue_high(self,func,prty)
end

function petz.lq_flyattack(self, target)
	local func = function()
		if not kitz.is_alive(target) then
			return true
		end
		local tgtpos = target:get_pos()
		local pos = self.object:get_pos()
		-- calculate attack spot
		local dist = vector.distance(pos, tgtpos)
		if dist <= 1.5 then	--bite
			target:punch(self.object, 1, self.attack)
			local vy = self.object:get_velocity().y -- bounce off
			local yaw = self.object:get_yaw()
			local dir = minetest.yaw_to_dir(yaw)
			self.object:set_velocity({x= dir.x*-3, y=vy, z=dir.z * -3})
			kitz.make_sound(self, 'attack') -- play attack sound if defined
			if self.attack_kamikaze then
				self.hp = 0 --bees must to die!!!
			end
		else
			petz.flyto(self, target)
		end
		kitz.lq_idle(self, 0.3)
		return true
	end
	kitz.queue_low(self,func)
end
