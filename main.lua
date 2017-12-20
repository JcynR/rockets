local sfw = getScreenFromWorldPosition;

local rockets = {};

function Rocket(x, y, z, force, target, lifespan, creator)
	local self = {};
	table.insert(rockets, self);
	self.index = nil;
	self.pos = Vector3(x, y, z);
	self.vel = force or Vector3();
	self.target = target;
	self.creator = creator;
	--self.marker = Marker(self.pos, "corona", 0.25, 255,0,0);
	self.light = Light(0, self.pos);
	self.isDead = false;
	local life = getTickCount();
	self.lifespan = lifespan or 15000;
	self.groundCheckDist = 0.05;

	function self.update(dt)
		self.vel = self.vel + Vector3(0,0,-0.005) * dt/17;

		if (type(self.target) == "userdata") then
			self.vel = self.vel * 0.99;
		end

		local gp = getGroundPosition(self.pos.x, self.pos.y, self.pos.z+0.5) + self.groundCheckDist;
		if (self.pos.z < gp) then
			self.pos.z = gp;
		end

		self.pos = self.pos + self.vel * dt/17;
	end

	function self.show()
		local vel = (-self.vel):getNormalized();
		Effect.addBulletImpact(self.pos, vel*5, 6, 0, .5);
		Effect.addSparks(self.pos, vel, 30, 10, 0,0,0, true, .05, .2);

		--self.marker.position = self.pos;
		self.light.position = self.pos;

		local x,y = sfw(self.pos);
		if (x) then
			local t = self.target and self.target.name or "";
			dxDrawText(t .. "dc: "..self.deflectCount, x, y);
		end

		dxDrawLine3D(self.pos, self.pos+self.vel, tocolor(255,0,0), 4);
	end

	function self.expired(ls)
		return getTickCount() > life + (ls or self.lifespan);
	end

	function self.destroy()
		--self.marker:destroy();
		self.light:destroy();
		if (type(self.target) == "userdata") then
			self.target:setData("rocket"..self.index, nil);
		end
		table.remove(rockets, self.index);
	end

	function self.explode()
		createExplosion(self.pos, 12);
		self.destroy();
	end

	local deflected = getTickCount();
	self.deflectCount = 0;
	self.maxDeflections = 1000;
	self.deflectMinDelay = 125;

	function self.deflect()
		local col = self.colliding();
		if (col) then
			if (getTickCount() < deflected + self.deflectMinDelay) then
				self.deflectCount = self.deflectCount + 1;
				if (self.deflectCount == self.maxDeflections) then
					self.isDead = true;
				end
			else
				self.deflectCount = 0;
			end
			deflected = getTickCount();

			self.vel:deflect(col.normal);
			self.vel.x = self.vel.x * 0.95;
			self.vel.y = self.vel.y * 0.95;
			self.vel.z = self.vel.z * 0.62;
		end
	end

	function self.colliding(target)
		local targetPos = self.pos + self.vel:getNormalized()*(self.vel.length+self.groundCheckDist);
		local hit, x, y, z, elem, mx, my, mz = processLineOfSight(self.pos, targetPos);
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
		local target = isElement(self.target) and self.target.position or self.target;
		if (target) then
			local force = target - self.pos;
			force:div(force.length);
			self.vel = self.vel + force * 0.02;
			local d = (self.pos-target).length;
			if (self.colliding(target)) then
				self.isDead = true;
			end
		end
	end

	local trail = {};
	local trailUpdated = getTickCount();
	self.trailColor = {math.random(255), math.random(255), math.random(255)};
	self.trailUpdateRate = 40;
	self.trailLength = 15;
	self.trailThickness = 5;

	function self.trail()
		if (#trail == self.trailLength) then
			table.remove(trail, 1);
		end

		if (getTickCount() > self.trailUpdateRate + trailUpdated) then
			trailUpdated = getTickCount();
			table.insert(trail, Vector3(self.pos.x, self.pos.y, self.pos.z));
		end

		for i=#trail, 1, -1  do
			local color = tocolor(self.trailColor[1], self.trailColor[2], self.trailColor[3], i*9);
			if (trail[i+1]) then
				dxDrawLine3D(trail[i], trail[i+1], color, self.trailThickness);
			end
		end
	end

	return self;
end

local camEnabled = false;

addEventHandler("onClientPreRender", root, function(dt)
	for i=#rockets, 1, -1 do
		local m = rockets[i];
		m.index = i;
		if (type(m.target) == "userdata") then
			m.follow();
		end
		m.deflect();
		m.trail();
		m.show();
		m.update(dt);
		if (m.expired() or m.isDead) then
			if (i == #rockets and camEnabled) then
				resetCamera();
			end
			--m.destroy();
			m.explode();
		end
	end

	if (camEnabled) then
		local m = rockets[#rockets];
		if (m) then
			Camera.setMatrix(m.pos, m.pos+m.vel, 0, 120);
		end
	end

	local targetType = "vehicle";
	localPlayer:setData("rocket_target", false);
	if (getControlState("aim_weapon")) then
		local plrs = getElementsByType(targetType, root, true);
		for i=1, #plrs do
			if (plrs[i].onScreen and plrs[i] ~= localPlayer) then
				local aimStart = Vector2(sfw(plrs[i].position));
				local aimEnd = Vector2(sfw(getPedTargetEnd(localPlayer)));
				local d = (aimStart-aimEnd).length;
				if (d < 250) then
					localPlayer:setData("rocket_target", plrs[i]);
					dxDrawLine(aimStart,aimEnd);
					break;
				end
			end
		end
	end
end);

addEventHandler("onClientPlayerWeaponFire", root, function(wepId)
	if (wepId == 29) then
		local start = Vector3(getPedWeaponMuzzlePosition(source));
		local finish = Vector3(getPedTargetEnd(source));
		local vel = (finish - start) * 0.005;
		local target = getElementData(source,"rocket_target");
		Rocket(start.x, start.y, start.z, vel, target, _, source);
	end
end);

addCommandHandler("cam", function()
	camEnabled = not camEnabled;
	if (not camEnabled) then
		resetCamera()
	else
		localPlayer.frozen = true;
	end
end)

function resetCamera()
	localPlayer.frozen = false;
	setCameraTarget(localPlayer);
end

function Vector3:div(n)
	self.x = self.x/n;
	self.y = self.y/n;
	self.z = self.z/n;
	return self;
end

function Vector3:deflect(normal)
	local dir = normal * self:dot(normal) * 2;
	self.x = self.x - dir.x;
	self.y = self.y - dir.y;
	self.z = self.z - dir.z;
	return self;
end
