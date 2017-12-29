loadstring(exports.utils:load('require'))();
require 'general';

local rockets = {};
local camEnabled = false;
local targetable = "player";
local targetSeekDist = 250;

function Rocket(x, y, z, force, target, lifespan, creator)
	local self = {};
	self.index = nil;
	self.pos = Vector3(x, y, z);
	self.vel = force or Vector3();
	self.target = target;
	self.creator = creator;
	self.isDead = false;
	local life = getTickCount();
	self.fuel = lifespan or 10000;
	self.groundCheckDist = 0.06;
	local targetHit = false;
	self.fall = true;
	self.gravity = 0.008;

	local deflected = getTickCount();
	self.deflectCount = 0;
	self.maxDeflections = 4;
	self.deflectMinDelay = 200;

	local trail = {};
	local trailUpdated = getTickCount();
	self.trailColor = {math.random(255), math.random(255), math.random(255)};
	self.trailUpdateRate = 50;
	self.trailLength = 120;
	self.trailThickness = 5;

	self.marker = Marker(self.pos, "corona", 0.5, self.trailColor[1], 100, 255);
	self.light = Light(0, self.pos, 5, self.trailColor[1], 100, 255, _,_,_, true);

	--self.obj = Object(3003, self.pos);
	--self.obj.mass = 10;
	--self.obj:setCollisionsEnabled(false);

	function self.update(dt)
		if (type(self.target) == "userdata") then
			self.vel = self.vel * 0.99;
		end

		self.pos = self.pos + self.vel * (dt/25);

		local gp = getGroundPosition(self.pos.x, self.pos.y, self.pos.z) + self.groundCheckDist;
		if (self.pos.z <= gp) then
			self.vel.x = self.vel.x * 0.98;
			self.vel.y = self.vel.y * 0.98;
			self.vel.z = 0;
			self.pos.z = gp;
		else
			if (not self.target) then
				if (self.fall) then
					self.addVel(0, 0, -self.gravity);
				end
			end
		end
	end

	function self.addVel(x, y, z)
		self.vel = self.vel + Vector3(x, y, z);
	end

	function self.show()
		local vel = (-self.vel);
		dxDrawLine3D(self.pos, self.pos+self.vel, tocolor(255,0,0), 5);
		Effect.addBulletImpact(self.pos, vel*5, 6, 0, .5);
		Effect.addSparks(self.pos, vel, 30, 10, 0,0,0, true, .05, .2);

		self.marker.position = self.pos;
		self.light.position = self.pos;
		--self.obj.position = self.pos;
		--self.obj.velocity = self.vel;

		local x,y = sfw(self.pos);
		if (x) then
			local t = isElement(self.target) and self.target.name;
			if (t) then
				local d = getDistanceBetweenPoints3D(self.pos, Camera.matrix.position);
				dxDrawText(t, x, y, x, y, tocolor(255,255,255), 35/d);
			end
		end
	end

	function self.expired(ls)
		return getTickCount() > life + (ls or self.fuel);
	end

	function self.destroy()
		--self.obj:destroy();
		self.light:destroy();
		self.marker:destroy();
		table.remove(rockets, self.index);
	end

	function self.explode()
		createExplosion(self.pos, 12);
		self.destroy();
	end

	function self.deflect()
		local col = self.colliding();
		if (col) then
			if (getTickCount() < deflected + self.deflectMinDelay) then
				self.deflectCount = self.deflectCount + 1;
				if (self.deflectCount == self.maxDeflections) then
					self.isDead = true;
				end
			else
				if (self.deflectCount > 0) then
					self.deflectCount = self.deflectCount - 1;
				end
			end
			deflected = getTickCount();

			self.vel.x = self.vel.x * 0.65;
			self.vel.y = self.vel.y * 0.65;


			if (self.deflectCount > 0) then
				self.vel.z = self.vel.z * 0.3;
			else
				self.vel.z = self.vel.z * 0.62;
			end

			self.vel = self.vel - (col.normal * self.vel:dot(col.normal) * 2);
		end
	end

	function self.colliding(target)
		local targetPos = self.pos + self.vel * 1.5;
		local hit = process(self.pos, targetPos, {
			vehicles = true,
			ignoredElement = self.obj,
			includeWorldModelInfo= true
		});

		if (hit and hit.element) then
			if (hit.element == self.target) then
				targetHit = true;
			end
			self.onhit(hit.element, hit.piece);
		end

		return hit;
	end

	function self.onhit(elem, piece)
		if (elem.type == "player") then
			fxAddBlood(self.pos, self.vel, 3, 1 );
			playSFX3D("genrl", 20, 9, self.pos, false);
			playSFX3D("pain_a", 0, math.random(25,33), elem.position, false);
			elem.health = elem.health - 4;
			setPedLookAt(elem, self.pos);
			if (math.random(4) == 1) then
				local p = elem.position;
				p.z = p.z + 0.015;
				elem.position = p;
				elem.velocity = elem.velocity + self.vel * 1.5;
			end
			--[[if (math.random(4) == 1) then
   			setPedAnimation(elem, "ped", "floor_hit", 1000, false, true, false);
			end]]
			if (piece == 9) then
				setPedHeadless(elem, true);
				setTimer(function(elem) setPedHeadless(elem, false); end, 9000, 1, elem);
			end
		end
	end

	function self.follow()
		self.target = isElement(self.target) and self.target or nil;
		local target = isElement(self.target) and self.target.position or nil;
		if (type(target) == "userdata") then
			local force = (target - self.pos):getNormalized();
			self.vel = self.vel + force * 0.02;
			local d = (self.pos-target).length;
			if (targetHit) then
				self.isDead = true;
			end
		end
	end

	function self.trail()
		if (#trail == self.trailLength) then
			table.remove(trail, 1);
		end

		if (getTickCount() > self.trailUpdateRate + trailUpdated) then
			trailUpdated = getTickCount();
			table.insert(trail, Vector3(self.pos.x, self.pos.y, self.pos.z));
		end

		for i=#trail, 1, -1  do
			local alpha = (255 / #trail) * i;
			local color = tocolor(self.trailColor[1], self.trailColor[2], self.trailColor[3], alpha);
			if (trail[i+1]) then
				dxDrawLine3D(trail[i], trail[i+1], color, self.trailThickness);
			end
		end
	end

	table.insert(rockets, self);
	return self;
end

addEventHandler("onClientPreRender", root, function(dt)
	for i=#rockets, 1, -1 do
		local r = rockets[i];
		r.index = i;
		r.follow();
		r.deflect();
		r.update(dt);
		r.show();
		r.trail();

		if (r.expired() or r.isDead) then
			if (i == #rockets and camEnabled) then
				if (#rockets == 1) then
					resetCamera();
				end
			end
			r.destroy();
		end
	end

	if (camEnabled) then
		local r = rockets[#rockets];
		if (r and r.creator == localPlayer) then
			Camera.setMatrix(r.pos, r.pos+r.vel, 0, 100);
		end
	end

	localPlayer:setData("rocket_target", false);
	if (getControlState("aim_weapon")) then
		getTargetOnScreen(targetable);
	end

	dxDrawText("Rockets: "..#rockets,0,0);
end);

function getTargetOnScreen(targetType)
	local plrs = getElementsByType(targetType, root, true);
	for i=1, #plrs do
		if (plrs[i].onScreen and plrs[i] ~= localPlayer) then
			local aimStart = Vector2(sfw(plrs[i].position));
			local aimEnd = Vector2(sfw(getPedTargetEnd(localPlayer)));
			local d = (aimStart-aimEnd).length;
			if (d < targetSeekDist) then
				localPlayer:setData("rocket_target", plrs[i]);
				dxDrawLine(aimStart,aimEnd);
				break;
			end
		end
	end
end

addCommandHandler("cam", function()
	camEnabled = not camEnabled;
	if (not camEnabled) then
		resetCamera();
	else
		localPlayer.frozen = true;
	end
end)

function resetCamera()
	localPlayer.frozen = false;
	setCameraTarget(localPlayer);
end
