SWEP.Author = "Anarchy&Nautical"
SWEP.Contact = "dont@dontemailme.dont"
SWEP.Purpose = "Kidnap faggots."
SWEP.Instructions = "Left click to knock-out | Right click to drag"

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

local kidnappedPly = {}
local hasBeenKidnapped = {}

local reviveTime = 60
local waitTime = 20

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
			if (ent == nil || !ent:IsValid() || ply:Health() <= 0 || !ply:GetActiveWeapon():IsValid() || ply:GetActiveWeapon():GetClass() != "weapon_kidnap" ) then

				ply:SetWalkSpeed(250)
				ply:SetRunSpeed(300)
				hook.Remove("Think",ply.pickupObjectTable[2])
				
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
	
	--------
	
	local eyetrace = self.Owner:GetEyeTrace();
	
	if !eyetrace.Entity:IsPlayer() then end
		
	if eyetrace.Entity:IsPlayer() then
		if self.Owner:EyePos():Distance(eyetrace.Entity:GetPos()) < 80 then
			self:EmitSound( HitSound )
		end
	end

	if (!SERVER) then return end
	
	if eyetrace.Entity:IsPlayer() then
		if self.Owner:EyePos():Distance(eyetrace.Entity:GetPos()) < 80 then
			self:kidnapPlayer(eyetrace.Entity)
		else
			return
		end
	end

end

function SWEP:kidnaprevive(ent)

	if (!ent:IsValid()) then print("INVALID ENT") return end
	
	local phy = ent:GetPhysicsObject()
	phy:EnableMotion( false )
	
	local associatedPlayer = nil
	
	for k,v in pairs(kidnappedPly) do
		
		if (v[2] == ent) then
		
			associatedPlayer = v[1]
			break
		end
	end
	
	if (associatedPlayer == nil) then print("ASSOCIATED PLAYER NOT FOUND!") return end
	
	ent:SetSolid(SOLID_NONE)
	associatedPlayer:DrawViewModel(true)
	associatedPlayer:DrawWorldModel(true)
	associatedPlayer:Spawn()
	associatedPlayer:SetPos(ent:GetPos())
	associatedPlayer:SetVelocity(ent:GetPhysicsObject():GetVelocity())

	ent:Remove()
end

function SWEP:kidnapPlayer(ply)

	for k,v in pairs(hasBeenKidnapped) do
		if v == ply then
			self.Owner:PrintMessage(HUD_PRINTCENTER, "This player's been kidnapped recently!")
			return
		end
	end

	local rag = ents.Create( "prop_ragdoll" )
    if not rag:IsValid() then return end

	rag:SetModel( ply:GetModel() )
    rag:SetKeyValue("origin", ply:GetPos().x .. " " .. ply:GetPos().y .. " " .. ply:GetPos().z)
	rag:SetAngles(ply:GetAngles())
	
	table.insert(kidnappedPly, { ply,rag })
	table.insert(hasBeenKidnapped, ply)
		
	ply:StripWeapons()
	ply:DrawViewModel(false)
	ply:DrawWorldModel(false)
	ply:Spectate(OBS_MODE_CHASE)
	ply:SpectateEntity(rag)
	
    rag:Spawn()
    rag:Activate()

	rag:GetPhysicsObject():SetVelocity(4*ply:GetVelocity())
	
	rag:GetPhysicsObject():SetMass(1)
	
    timer.Create("revivedelay" .. randString(10), reviveTime, 1, function() 
	
		self:kidnaprevive(rag) 
		
		for k,v in pairs(kidnappedPly) do // loop through table where k = player #,v = steamID
			if v[1] == ply then // v == ply:SteamID() ( implies that their steamID is already in there )
				table.remove(kidnappedPly, k) // remove it
			end
		end
	end)
	
	timer.Create("waittime" .. randString(10), waitTime, 1, function()
	
		for k,v in pairs(hasBeenKidnapped) do
			if v == ply then
				table.remove(hasBeenKidnapped, k)
			end
		end
	end)
	
end

hook.Add("CanPlayerSuicide", "KidnapSWEP-CanPlayerSuicide", function(ply)
	for k,v in pairs(kidnappedPly) do
		if v[1] == ply then
			return false
		end
	end
end)