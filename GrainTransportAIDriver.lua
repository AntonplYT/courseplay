--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

GrainTransportAIDriver = CpObject(AIDriver)

function GrainTransportAIDriver:init(vehicle)
	AIDriver.init(self, vehicle)
	self.mode = courseplay.MODE_GRAIN_TRANSPORT
end

function GrainTransportAIDriver:isAlignmentCourseNeeded(ix)
	-- never use alignment course for grain transport mode
	return false
end

function GrainTransportAIDriver:drive(dt)
	-- update current waypoint/goal point
	self.ppc:update()
	local lx, lz = self:getDirectionToNextWaypoint()
	-- should we keep driving?
	local allowedToDrive = self:checkLastWaypoint()

	-- RESET TRIGGER RAYCASTS from drive.lua. 
	-- TODO: Not sure how raycast can be called twice if everything is coded cleanly
	self.vehicle.cp.hasRunRaycastThisLoop['tipTrigger'] = false;
	self.vehicle.cp.hasRunRaycastThisLoop['specialTrigger'] = false;

	courseplay:updateFillLevelsAndCapacities(self.vehicle)

	local giveUpControl = false

	if self.vehicle.cp.totalFillLevel ~= nil
		and self.vehicle.cp.tipRefOffset ~= nil
		and self.vehicle.cp.workToolAttached then
		
		self:searchForTipTrigger()
	
		allowedToDrive, giveUpControl = courseplay:handle_mode1(self.vehicle, allowedToDrive, dt)

	end

	if giveUpControl then
		-- handle_mode1 does the driving
		return
	else
		-- we drive
		local moveForwards
		lx, lz, moveForwards = self:checkReverse(lx, lz)
		self:driveVehicle(dt, allowedToDrive, moveForwards, lx, lz, self:getSpeed())
	end
end

function GrainTransportAIDriver:onWaypointChange(newIx)
	AIDriver.onWaypointChange(self, newIx)
	if self.ppc:atLastWaypoint() then
		courseplay:changeRunCounter(self.vehicle, false)
	end
end

function GrainTransportAIDriver:isNearTipTrigger()
	-- TODO: come up with something better?
	return self.vehicle.cp.currentTipTrigger ~= nil
end

function GrainTransportAIDriver:getSpeed()
	if self:isNearTipTrigger() then
		return 10		
	else
		return AIDriver.getSpeed(self)
	end
end

function GrainTransportAIDriver:searchForTipTrigger()
	if not self.vehicle.cp.hasAugerWagon
		and self.vehicle.cp.currentTipTrigger == nil
		and self.vehicle.cp.totalFillLevel > 0
		and self.ppc:getCurrentWaypointIx() > 2
		and not self.ppc:atLastWaypoint()
		and not self.ppc:isReversing() then
		local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, lx, 0, lz)
		-- raycast start point in front of vehicle
		local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
		courseplay:doTriggerRaycasts(self.vehicle, 'tipTrigger', 'fwd', true, x, y, z, nx, ny, nz)
	end
end