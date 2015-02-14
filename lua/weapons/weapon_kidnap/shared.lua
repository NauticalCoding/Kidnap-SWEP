SWEP.Author = "Anarchy"
SWEP.Contact = "dont@dontemailme.dont"
SWEP.Purpose = "Kidnap faggots."
SWEP.Instructions = "Left click to knock out | Right click to drag"

SWEP.UseHands	= true
SWEP.DrawAmmo	= false

SWEP.Spawnable = true
SWEP.AdminSpawnable = true
 
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = ""
 
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.HitDistance = 48

SWEP.Damage = 0
SWEP.Spread = 0
SWEP.NumBul = 1
SWEP.Delay = 0.3
SWEP.Force = 3

local SwingSound = Sound( "weapons/slam/throw.wav" )
local HitSound = Sound( "Flesh.ImpactHard" )

local kidnappedRag = {}
local kidnappedPly = {}
local kidnapUniqueTimer1 = 0
local revivetime = 120

function SWEP:Initialize()

	self:SetHoldType( "fist" )

end

function SWEP:Deploy()

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
	
	return true
end


local function randString(len)
       
	local str = ""
		   
	for i = 1,len do   
		str = str .. string.char(math.random(97,122))
	end
		   
	return str
end
 
local function altPickup(ply,ent)
       
	if (ply.pickupObjectTable[1]) then
		hook.Remove("Think",ply.pickupObjectTable[2]);
	else     
		local hookID = randString(15);
       
		ply.pickupObjectTable[2] = hookID;
       
		hook.Add("Think",hookID,function()
			if not ent:IsValid() then 
				hook.Remove("Think",hookID)
				ply:SetWalkSpeed(250)
				ply:SetRunSpeed(300)
				return 
			end	
			if ply:Health() <= 0 then 
				hook.Remove("Think",hookID)
				ply:SetWalkSpeed(250)
				ply:SetRunSpeed(300)
				return 
			end			
			if not ply:GetActiveWeapon():IsValid() then 
				hook.Remove("Think",hookID)
				ply:SetWalkSpeed(250)
				ply:SetRunSpeed(300)
				return 
			end	
			if ply:GetActiveWeapon():GetClass() != "weapon_kidnap" then 
				hook.Remove("Think",hookID)
				ply:SetWalkSpeed(250)
				ply:SetRunSpeed(300)
				return 
			end
               
			local desiredPos = ply:GetShootPos() + ply:EyeAngles():Forward() * 80
			ent:GetPhysicsObject():SetVelocity((desiredPos - ent:GetPos()) * 40000)
		end)
	end
       
	ply.pickupObjectTable[1] = !ply.pickupObjectTable[1];
end

function SWEP:SecondaryAttack()

	if (self.Owner.pickupObjectTable == nil) then
                      
		self.Owner.pickupObjectTable = {         
			false, // is holding object
			"" // hook identifier
		}
	end
 
	local ent = self.Owner:GetEyeTrace().Entity
 
	if CLIENT then return end
 
	if(self.Owner.pickupObjectTable[1]) then
		altPickup(self.Owner)
		self.Owner:SetWalkSpeed(250)
		self.Owner:SetRunSpeed(300)
	else
		if ent:GetClass() == "prop_ragdoll" then
			if self.Owner:EyePos():Distance(ent:GetPos()) < 80 then 
				altPickup(self.Owner,ent)
				self.Owner:SetWalkSpeed(75)
				self.Owner:SetRunSpeed(125)
			end
		end
	end
		
end

function SWEP:PrimaryAttack()
	
	self.Owner:SetAnimation( PLAYER_ATTACK1 )

	local anim = "fists_left"
	
	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( anim ) )

	self:EmitSound( SwingSound )
 
	self:SetNextPrimaryFire( CurTime() + self.Delay )
	self:SetNextSecondaryFire( CurTime() + self.Delay )
	
	--------
	
	local eyetrace = self.Owner:GetEyeTrace();
	
	if !eyetrace.Entity:IsPlayer() then end
		
	
	//if eyetrace.Entity:IsPlayer() then
	//	if self.Owner:EyePos():Distance(eyetrace.Entity:GetPos()) < 80 then
	//		self:EmitSound( HitSound )
	//	end
	//end

	if (!SERVER) then return end
	
	if eyetrace.Entity:IsPlayer() then
		if self.Owner:EyePos():Distance(eyetrace.Entity:GetPos()) < 80 then
			self:kidnapPlayer(eyetrace.Entity)
			self:EmitSound( HitSound )
		else
			return
		end
	end

end

function SWEP:kidnapPlayer(ply)

	local rag = ents.Create( "prop_ragdoll" )
    if not rag:IsValid() then return end

	rag:SetModel( ply:GetModel() )
    rag:SetKeyValue( "origin", ply:GetPos().x .. " " .. ply:GetPos().y .. " " .. ply:GetPos().z )
	rag:SetAngles(ply:GetAngles())
			
	rag.kidnappedPly = ply
	table.insert(kidnappedRag, rag)
	table.insert(kidnappedPly, ply:SteamID())
	
	timer.Create("removeID"..ply:SteamID(), revivetime, 1, function() self:destroytimer(ply) end)
	
		
	ply:StripWeapons()
	ply:DrawViewModel(false)
	ply:DrawWorldModel(false)
	ply:Spectate(OBS_MODE_CHASE)
	ply:SpectateEntity(rag)
	

    rag:Spawn()
    rag:Activate()
	
	rag:GetPhysicsObject():SetVelocity(4*ply:GetVelocity())
	
	rag:GetPhysicsObject():SetMass(1)
	
    self:setrevivedelay(rag)
	
end

function SWEP:destroytimer(ply)
	if table.HasValue(kidnappedPly, ply:SteamID()) then
		for k,v in pairs(kidnappedPly) do
			if v == ply:SteamID() then
				table.remove(kidnappedPly, k)
			end
		end
	end
end

function SWEP:setrevivedelay(rag)
	
	if kidnapUniqueTimer1 > 30 then
		kidnapUniqueTimer1 = 0
	end
	
	kidnapUniqueTimer1 = kidnapUniqueTimer1 + 1
	
	timer.Create("revivedelay"..kidnapUniqueTimer1, revivetime, 1, function() self:kidnaprevive(rag) end)

end

function SWEP:kidnaprevive(ent)

	if !ent then return end
	
	if ent.kidnappedPly then
		if ( !ent.kidnappedPly:IsValid() ) then return end
	
		local phy = ent:GetPhysicsObject()
		phy:EnableMotion(false)
		ent:SetSolid(SOLID_NONE)
		ent.kidnappedPly:DrawViewModel(true)
		ent.kidnappedPly:DrawWorldModel(true)
		ent.kidnappedPly:Spawn()
		ent.kidnappedPly:SetPos(ent:GetPos())
		ent.kidnappedPly:SetVelocity(ent:GetPhysicsObject():GetVelocity())
	else 
		return
	end
	
	for k, v in pairs(kidnappedRag) do 
		if v == ent then 
			table.remove( kidnappedRag, k )
		end
	end
	ent:Remove()

end

hook.Add("CanPlayerSuicide", "TESTYLITPPER", function(ply)
	for k,v in pairs(kidnappedPly) do
		if v == ply:SteamID() then
			return false
		end
	end
end)