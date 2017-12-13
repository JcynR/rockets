local missiles = {};

function Missile(x, y, z, force, target, lifespan, owner)
	local self = {};
	table.insert(missiles, self);
	self.pos = Vector3(x, y, z);
	self.vel = force or Vector3();
	self.target = target;
	self.index = nil;
	--self.fx = Effect("extinguisher", x, y, z, 0, 0, 0, 8191);
	local life = getTickCount();
	self.lifespan = lifespan or 3000;
	self.owner = owner;

	self.lastSync = getTickCount();
	self.syncRate = 100;
	--[[function self.syncUpdater()
		if (localPlayer == self.owner and getTickCount() > self.lastSync + self.syncRate) then
			self.lastSync = getTickCount();
			self.owner:setData("rocket" .. self.index, {
				pos = {self.pos.x, self.pos.y, self.pos.z},
				vel = {self.vel.x, self.vel.y, self.vel.z}
			});
		end
	end

	function self.sync()
		if (localPlayer ~= self.owner and getTickCount() > self.lastSync + self.syncRate) then
			self.lastSync = getTickCount();
			local data = self.owner:getData("rocket" .. self.index);
			if (data) then
				self.pos = Vector3(data.pos.x, data.pos.y, data.pos.z);
				self.vel = Vector3(data.vel.x, data.vel.y, data.vel.z);
			end
		end
	end]]

	function self.expired(ls)
		return getTickCount() > life + (ls or self.lifespan);
	end

	function self.update()
		if (isElement(self.target)) then
			self.vel = self.vel * 0.99
		end
		--self.vel.z = self.vel.z - 0.005;
		-- local sparks = self.expired(self.lifespan*0.3) and 0 or 10;
		Effect.addBulletImpact(self.pos, (-self.vel):getNormalized()*5, 6, 0, .5);
		Effect.addSparks(self.pos, (-self.vel):getNormalized(), 30, 10, 0,0,0, true, .05, .2);
		-- Effect.addGunshot(self.pos, (-self.vel):getNormalized(), true);
		self.pos = self.pos + self.vel;
		--self.fx.position = self.pos;
		dxDrawLine3D(self.pos,self.pos+self.vel, tocolor(255,0,0), 10);
	end

	function self.destroy()
	--	self.fx:destroy();
		table.remove(missiles, self.index);
	end

	function self.explode()
		self.destroy();
		createExplosion(self.pos, 12);
	end

	local deflected = getTickCount();
	local timesDeflected = 0;
	self.maxDeflections = 4;
	self.deflectMinDelay = 200;

	function self.deflect()
		local col = self.colliding();
		if (col) then
			if (getTickCount() < deflected + self.deflectMinDelay) then
				timesDeflected = timesDeflected + 1;
				if (timesDeflected == self.maxDeflections) then
					self.destroy();
				end
			else
				timesDeflected = 0;
			end
			deflected = getTickCount();
			self.vel:deflect(col.normal);
			self.vel = self.vel * 0.94;
		end
	end

	function self.colliding(target)
		local hit, x, y, z, elem, mx, my, mz = processLineOfSight(self.pos, self.pos + self.vel * 2);
		if (target) then
			return elem == self.target;
		end
		if (hit) then
			return {
				pos = Vector3(x, y, z),
				elem = elem,
				normal = Vector3(mx, my, mz)
			}
		end
		return false;
	end

	self.targetMinHitDistance = 0.8;

	function self.follow()
		local target = isElement(self.target) and self.target.position or false;
		if (target) then
			local force = target - self.pos;
			force:div(force.length);
			self.vel = self.vel + force * 0.02;
			local d = (self.pos-target).length;
			if (self.colliding(target)) then
				self.explode();
			end
		end
	end

	local trail = {};
	local trailUpdated = getTickCount();
	self.trailColor = {math.random(255), math.random(255), math.random(255)};
	self.trailUpdateRate = 100;
	self.trailLength = 10;

	function self.leaveTrail()
		if (getTickCount() > self.trailUpdateRate + trailUpdated) then
			trailUpdated = getTickCount();
			table.insert(trail, Vector3(self.pos.x, self.pos.y, self.pos.z));
		end

		if (#trail == self.trailLength) then
			table.remove(trail, 1);
		end

		for i=#trail, 1, -1  do
			local color = tocolor(self.trailColor[1], self.trailColor[2], self.trailColor[3], i*8);
			if (trail[i+1]) then
				dxDrawLine3D(trail[i], trail[i+1], color, 8);
			end
		end
	end

	return self;
end

function Vector3:div(n)
	self.x = self.x/n;
	self.y = self.y/n;
	self.z = self.z/n;
end

function Vector3:deflect(normal)
	local dir = normal * self:dot(normal) * 2;
	self.x = self.x - dir.x;
	self.y = self.y - dir.y;
	self.z = self.z - dir.z;
end

local cam = false;

addEventHandler("onClientRender", root, function()
	for i=#missiles, 1, -1 do
		local m = missiles[i];
		m.index = i;

		--m.syncUpdater();
		--m.sync();

		m.follow();
		m.deflect();
		m.leaveTrail();
		m.update();
		if (m.expired()) then
			--m.destroy();
			--m.explode();
		end
		if (m.colliding()) then
			--m.explode()
		end
	end

	if (cam) then
		local m = missiles[#missiles];
		if (m) then
			Camera.setMatrix(m.pos, m.pos+m.vel);
		end
	end

	localPlayer:setData("target", false);
	if (getControlState("aim_weapon")) then
		local plrs = getElementsByType("player", root, true);
		for i=1, #plrs do
			if (plrs[i].onScreen and plrs[i] ~= localPlayer) then
				local aimStart = Vector2(getScreenFromWorldPosition(plrs[i].position));
				local aimEnd = Vector2(getScreenFromWorldPosition(getPedTargetEnd(localPlayer)));
				local d = (aimStart-aimEnd).length;
				if (d < 200) then
					localPlayer:setData("target", plrs[i]);
					dxDrawLine(aimStart,aimEnd);
					break;
				end
			end
		end
	end
end);

addCommandHandler("cam", function()
	cam = not cam;
	if (not cam) then
		setCameraTarget(localPlayer);
	end
end)

addEventHandler("onClientPlayerWeaponFire", root, function(wepId)
	if (wepId == 29) then
		local start = Vector3(getPedWeaponMuzzlePosition(source));
		local finish = Vector3(getPedTargetEnd(source));
		local vel = (finish - start) * 0.02;

		Missile(start.x, start.y, start.z, vel, getElementData(source,"target"), 10000, source);
		cancelEvent();
	end
end);
