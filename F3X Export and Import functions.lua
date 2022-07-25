-- Exporting and importing to f3x servers

local HttpService=game:GetService"HttpService"
do -- compressor
	local char = string.char
	local type = type
	local select = select
	local sub = string.sub
	local tconcat = table.concat

	local basedictcompress = {}
	local basedictdecompress = {}
	for i = 0, 255 do
		local ic, iic = char(i), char(i, 0)
		basedictcompress[ic] = iic
		basedictdecompress[iic] = ic
	end

	local function dictAddA(str, dict, a, b)
		if a >= 256 then
			a, b = 0, b+1
			if b >= 256 then
				dict = {}
				b = 1
			end
		end
		dict[str] = char(a,b)
		a = a+1
		return dict, a, b
	end

	local function compress(input)
		if type(input) ~= "string" then
			return nil, "string expected, got "..type(input)
		end
		local len = #input
		if len <= 1 then
			return "u"..input
		end

		local dict = {}
		local a, b = 0, 1

		local result = {"c"}
		local resultlen = 1
		local n = 2
		local word = ""
		for i = 1, len do
			local c = sub(input, i, i)
			local wc = word..c
			if not (basedictcompress[wc] or dict[wc]) then
				local write = basedictcompress[word] or dict[word]
				if not write then
					return nil, "algorithm error, could not fetch word"
				end
				result[n] = write
				resultlen = resultlen + #write
				n = n+1
				if  len <= resultlen then
					return "u"..input
				end
				dict, a, b = dictAddA(wc, dict, a, b)
				word = c
			else
				word = wc
			end
		end
		result[n] = basedictcompress[word] or dict[word]
		resultlen = resultlen+#result[n]
		n = n+1
		if  len <= resultlen then
			return "u"..input
		end
		return tconcat(result)
	end

	local function dictAddB(str, dict, a, b)
		if a >= 256 then
			a, b = 0, b+1
			if b >= 256 then
				dict = {}
				b = 1
			end
		end
		dict[char(a,b)] = str
		a = a+1
		return dict, a, b
	end

	local function decompress(input)
		if type(input) ~= "string" then
			return nil, "string expected, got "..type(input)
		end

		if #input < 1 then
			return nil, "invalid input - not a compressed string"
		end

		local control = sub(input, 1, 1)
		if control == "u" then
			return sub(input, 2)
		elseif control ~= "c" then
			return nil, "invalid input - not a compressed string"
		end
		input = sub(input, 2)
		local len = #input

		if len < 2 then
			return nil, "invalid input - not a compressed string"
		end

		local dict = {}
		local a, b = 0, 1

		local result = {}
		local n = 1
		local last = sub(input, 1, 2)
		result[n] = basedictdecompress[last] or dict[last]
		n = n+1
		for i = 3, len, 2 do
			local code = sub(input, i, i+1)
			local lastStr = basedictdecompress[last] or dict[last]
			if not lastStr then
				return nil, "could not find last from dict. Invalid input?"
			end
			local toAdd = basedictdecompress[code] or dict[code]
			if toAdd then
				result[n] = toAdd
				n = n+1
				dict, a, b = dictAddB(lastStr..sub(toAdd, 1, 1), dict, a, b)
			else
				local tmp = lastStr..sub(lastStr, 1, 1)
				result[n] = tmp
				n = n+1
				dict, a, b = dictAddB(tmp, dict, a, b)
			end
			last = code
		end
		return tconcat(result)
	end

	Compressor = 
		{
			compress = compress,
			decompress = decompress,
		}
end
---
local RBLXSerialize = {
	_IDENTITY = "RBLXSerialize",
	_AUTHOR = "Whim#2127",
	_VERSION = "v0.7",
	_DESCRIPTION = "A All-In-One Roblox instance and datatype serializer.",
	_LICENSE = [[
    MIT LICENSE
    Copyright (c) 2022 Theron Akubuiro
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]],
	Convertors = function()
		-- This is were the magic happens!
		function splitbyte(input)
			local byte,p,flags = string.byte(input),128,{false,false,false,false,false,false,false,false}
			for i=1,8 do
				if byte>=p then flags[i],byte = true,byte-p end
				p=p/2
			end
			return flags
		end
		function formbyte(...)
			local byte = 0
			for p=1,8 do
				local bit=select(p,...)
				if bit then byte=byte+2^(8-p) end
			end
			return string.char(byte)
		end
		local valueType = "f"
		function deflate(forceType,...) 
			return string.pack(string.rep(forceType or valueType,#{...}),...)
		end 
		function flate(forceType,raw,n)
			return string.unpack(string.rep(forceType or valueType,n),raw)
		end 

		function getNativeSize(forceType) 
			return #string.pack(forceType or valueType ,1) 
		end
		--- Nice Binary Functions^^^^^^^^^^ Lazy formatting/macros


		--  Kept this cacheing for backwards compatability.
		local EnumStorage = {} 
		local cache = function(storage,enum) 
			local Table  = {}
			for _,v in ipairs(enum:GetEnumItems()) do
				Table[v.Value] = v 
			end
			storage[enum] = Table
		end 

		for i,enum in ipairs(Enum:GetEnums()) do 
			cache(EnumStorage,enum)
		end


		return {
			-- Comment for other developers who want to make their own serizliers!
			-- This is stupid complicated, alot of contextual information is used to make this work 
			-- Instance -> Propertyname -> Class -> Class.Name | SubEnum -> EnumValue 
			-- or  Instance|[PropertyName->ClassName(APIInstance[PropertyName].Class)][Value] (as little as 5bytes!)
			-- Irregular Conversion ! < More Context > , certain value are contextual such as SubEnum[PropertyName/Class]
			--ENCODE: Store EnumValue, SubEnum is contextual. 
			--DECODE: Index = Enum[SubEnum] | EnumStorage [ Index ] [ EnumValue ] - > Enum[SubEnum][EnumValue]	
			["EnumItem"] = function(isClass,API,SubEnum,EnumValue) 
				if isClass then 
					return string.pack("I2",EnumValue.Value)
				else 	
					return EnumStorage[Enum[SubEnum]][string.unpack("I2",EnumValue)]	
				end
			end,
			-- Normal Conversion 
			["ColorSequence"] = function(isClass,ColorSequenceValue) 
				if isClass then 
					local encodeStr = ""
					local blockSize =  string.packsize("f I1 I1 I1")
					for i,v in ipairs(ColorSequenceValue.Keypoints) do 
						local ColorKeypoint = v 
						local C3 = ColorKeypoint.Value
						local r, g, b = math.floor(C3.R*255), math.floor(C3.G*255), math.floor(C3.B*255)
						local block =  string.pack("f I1 I1 I1",ColorKeypoint.Time,r,g,b) --  further optimizations are possible to store
						encodeStr=encodeStr..block 
					end
					return encodeStr 
				else 
					local array  = {} 
					local blockSize =  string.packsize("f I1 I1 I1")
					for i=1,#ColorSequenceValue,blockSize do 
						local block = ColorSequenceValue:sub(i,i+blockSize) 
						local Time , r,g,b  = string.unpack("f I1 I1 I1",block) 
						table.insert(array,ColorSequenceKeypoint.new(Time,Color3.new(r/255,g/255,b/255)))
					end
					return ColorSequence.new(array)
				end
			end,
			["ColorSequenceKeypoint"] = function(isClass,ColorKeypoint) 
				if isClass then 
					local C3 = ColorKeypoint.Value
					local r, g, b = math.floor(C3.R*255), math.floor(C3.G*255), math.floor(C3.B*255)
					print(r,g,b)
					return string.pack("f I1 I1 I1",ColorKeypoint.Time,r,g,b) --  further optimizations are possible to store
				else
					local Time , r,g,b  = string.unpack("f I1 I1 I1",ColorKeypoint)
					return ColorSequenceKeypoint.new(Time,Color3.new(r/255,g/255,b/255))
				end
			end,
			["NumberSequence"] = function(isClass,NumberSequenceValue) 
				if isClass then 
					-- Basic binary array 
					local encodeStr = ""
					local nativeFloatSize = getNativeSize(nil) 
					local blockSize = nativeFloatSize*3 
					for i,v in ipairs(NumberSequenceValue.Keypoints) do 
						local block = deflate(nil,v.Time,v.Value,v.Envelope)
						encodeStr = encodeStr..block 
					end 

					return encodeStr
				else
					local array = {} 
					local nativeFloatSize = getNativeSize(nil) 
					local blockSize = nativeFloatSize*3 
					for i=1,#NumberSequenceValue,blockSize do 
						local block = NumberSequenceValue:sub(i,i+blockSize) 
						local a,b,c = flate(nil,block,3) 
						table.insert(array,NumberSequenceKeypoint.new(a,b,c))
					end
					warn(array)
					return NumberSequence.new(array)
				end
			end,
			["NumberSequenceKeypoint"] = function(isClass,NumberKeypoint)
				if isClass then 
					return deflate(nil,NumberKeypoint.Time,NumberKeypoint.Value,NumberKeypoint.Envelope)
				else 
					local a,b,c = flate(nil,NumberKeypoint,3) 
					return NumberSequenceKeypoint.new(a,b,c)
				end
			end,
			["Rect"] = function(isClass,RectValue)
				if isClass then 
					return deflate(nil,RectValue.Min.X,RectValue.Min.Y,RectValue.Max.X,RectValue.Max.Y)
				else 
					local a,b,c,d = flate(nil,RectValue,4)
					return Rect.new(a,b,c,d)
				end
			end,
			["Ray"] = function(isClass,RayValue) 
				if isClass then 
					return deflate(nil,RayValue.Orgin.X,RayValue.Orgin.Y,RayValue.Orgin.Z,RayValue.Direction.X,RayValue.Direction.Y,RayValue.Direction.Z)
				else 
					local x,y,z,x1,y1,z1 = flate(nil,RayValue,6)
					return Ray.new(Vector3.new(x,y,z,x1,y1,z1))
				end
			end,
			["PhysicalProperties"] = function(isClass,PhysicalPropertiesValue) 
				if isClass then 
					return deflate(nil,PhysicalPropertiesValue.Density,PhysicalPropertiesValue.Friction,PhysicalPropertiesValue.Elasticity,
						PhysicalPropertiesValue.FrictionWeight,PhysicalPropertiesValue.ElasticityWeight)
				else 
					local a,b,c,d,e = flate(nil,PhysicalPropertiesValue,5)
					return PhysicalProperties.new(a,b,c,d,e)
				end
			end,
			["NumberRange"] = function(isClass,NumberRangeValue) 
				if isClass then 
					return deflate(nil,NumberRangeValue.Min,NumberRangeValue.Max)
				else 
					local a,b = flate(nil,NumberRangeValue,2)
					return NumberRange.new(a,b)
				end
			end,
			["UDim"] = function(isClass,value)
				if isClass then 
					return deflate(nil,value.Scale,value.Offset) 
				else 
					local a,b = flate(nil,value,2)
					return UDim2.new(a,b)
				end
			end,
			["Color3"] = function(isClass,C3) 
				if isClass then 
					local r, g, b = math.round(C3.R*255), math.round(C3.G*255), math.round(C3.B*255)
					return deflate("I1",r,g,b)	
				else 
					local r1,g2,b2 = flate("I1",C3,3) 
					local r,g,b = r1/255,g2/255,b2/255
					return Color3.new(r,g,b)
				end
			end,
			["UDim2"] = function(isClass,value)
				if isClass then
					return  deflate(nil,value.X.Scale,value.X.Offset,value.Y.Scale,value.Y.Offset)
				else 
					local a,b,c,d = flate(nil,value,4)
					return UDim2.new(a,b,c,d)
				end
			end,
			["Vector3"] = function(isClass,vector) 
				if isClass then 
					if vector then 
						return deflate(nil,vector.X,vector.Y,vector.Z)
					end
				else 
					local X,Y,Z = flate(nil,vector,3)
					return Vector3.new(X,Y,Z)
				end
			end,
			["Vector3int16"] = function(isClass,vector) 
				if isClass then 
					if vector then 
						return deflate("i2",vector.X,vector.Y,vector.Z)
					end
				else 
					local X,Y,Z = flate("i2",vector,3)
					return Vector3.new(X,Y,Z)
				end
			end,
			["Vector2"] = function(isClass,vector) 
				if isClass then 
					if vector then 
						return deflate(nil,vector.X,vector.Y)
					end
				else 
					local X,Y = flate(nil,vector,2)
					return Vector2.new(X,Y)
				end
			end,
			["Vector2int16"] = function(isClass,vector) 
				if isClass then 
					if vector then 
						return deflate("i2",vector.X,vector.Y)
					end
				else 
					local X,Y = flate("i2",vector,2)
					return Vector2.new(X,Y)
				end
			end,
			["Content"]= function(isClass,str) 
				return str
			end,
			["ProtectedString"] = function(isClass,str) 
				return str
			end,
			["string"] = function(isClass,str) 
				return str 
			end,
			["bool"] = function(isClass,bool) 
				if isClass then 
					return ({[true]="#",[false]="$"})[bool]
				else 
					return ({["#"]=true,["$"]=false})[bool]
				end
			end,
			["float"] = function(isCLass,float) 
				if isCLass then 
					return deflate("f",float)
				else 
					local a = flate("f",float,1)
					return a 
				end
			end,
			["double"] = function(isCLass,float) 
				if isCLass then 
					return deflate("d",float)
				else 
					local a = flate("d",float,1)
					return a 
				end
			end,
			["int"] = function(isCLass,float) 
				if isCLass then 
					return deflate("i",math.floor(float))
				else 
					local a = flate("i",float,1)
					return a 
				end
			end,
			["int64"] = function(isCLass,float) 
				if isCLass then 
					return deflate("i8",math.floor(float))
				else 
					local a = flate("i8",float,1)
					return a 
				end
			end,
			["SurfaceType"] = function(isClass,surfaceType) 
				if isClass then 
					return deflate(nil,surfaceType.Value)
				else 
					local id = flate(nil,surfaceType,1)
					return EnumStorage[Enum.SurfaceType][id]
				end
			end,
			["BrickColor"] = function(isClass,brickColor)  
				if isClass then 
					return deflate(nil,math.floor(brickColor.Number))
				else 
					local id = flate(nil,brickColor,1)
					return BrickColor.new(id)
				end
			end,
			["Material"] = function(isClass,material)
				if isClass then
					return deflate(nil,material.Value)
				else  
					local id = flate(nil,material,1)
					return EnumStorage[Enum.Material][id]
				end
			end,
			["Faces"] = function(isClass,faces) 
				if isClass then 
					local byte = splitbyte(string.char(0))
					for i,v in ipairs(table.pack(faces.Top,faces.Bottom,faces.Left,faces.Right,faces.Back,faces.Front)) do 
						byte[i] = v 
					end
					-- table.unpack removes the tuple for some reason ?  
					return formbyte(faces)
				else 
					local face = {}
					local newValues = splitbyte(faces)
					for i,v in ipairs(newValues) do 
						if i <= 5 then 
							face[i] = v
						end
					end
					return Faces.new(table.unpack(face))
				end
			end,
			["CFrame"] = function(isClass,Cframe) 
				if isClass then 
					return deflate(nil,Cframe:components())
				else 
					-- yeah just thank string.unpack!
					local a,b,c,d,e,f,g,h,i,j,k,l = flate(nil,Cframe,12)
					return CFrame.new(a,b,c,d,e,f,g,h,i,j,k,l)
				end
			end,
			["CoordinateFrame"] = function(isClass,Cframe) 
				if isClass then 
					return deflate(nil,Cframe:components())
				else 
					local a,b,c,d,e,f,g,h,i,j,k,l = flate(nil,Cframe,12)
					return CFrame.new(a,b,c,d,e,f,g,h,i,j,k,l)
				end
			end
		}
	end,
	SaveCFrames = true, 
	UseBase92 = true, 
	AutoRename = false, 
	Encode = function(classOrDataType, shouldCompress : bool)end,
	Decode = function(encodedString : string, isCompressed :bool)end
} 
RBLXSerialize.Convertors=RBLXSerialize.Convertors()
local throw = function(...)
	local stuff = {...}
	local newstuff=""
	for _,v in pairs(stuff)do
		newstuff..=tostring(v)
	end
	(SendMsg or warn)(newstuff)
end
do -- base92
	local MAKE_JSON_SAFE = false -- If this is true, " will be replaced by ' in the encoding

	local CHAR_SET = [[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,./:;<=>?@[]^_`{|}~"]]

	local encode_CharSet = {}
	local decode_CharSet = {}
	for i = 1, 91 do
		encode_CharSet[i-1] = string.sub(CHAR_SET, i, i)
		decode_CharSet[string.sub(CHAR_SET, i, i)] = i-1
	end

	if MAKE_JSON_SAFE then
		encode_CharSet[90] = "'"
		decode_CharSet['"'] = nil
		decode_CharSet["'"] = 90
	end

	local function encodeBase91(input)
		local output = {}
		local c = 1

		local counter = 0
		local numBits = 0

		for i = 1, #input do
			counter = bit32.bor(counter, bit32.lshift(string.byte(input, i), numBits))
			numBits = numBits+8
			if numBits > 13 then
				local entry = bit32.band(counter, 8191) -- 2^13-1 = 8191
				if entry > 88 then -- Voodoo magic (https://www.reddit.com/r/learnprogramming/comments/8sbb3v/understanding_base91_encoding/e0y85ot/)
					counter = bit32.rshift(counter, 13)
					numBits = numBits-13
				else
					entry = bit32.band(counter, 16383) -- 2^14-1 = 16383
					counter = bit32.rshift(counter, 14)
					numBits = numBits-14
				end
				output[c] = encode_CharSet[entry%91]..encode_CharSet[math.floor(entry/91)]
				c = c+1
			end
		end

		if numBits > 0 then
			output[c] = encode_CharSet[counter%91]
			if numBits > 7 or counter > 90 then
				output[c+1] = encode_CharSet[math.floor(counter/91)]
			end
		end

		return table.concat(output)
	end

	local function decodeBase91(input)
		local output = {}
		local c = 1

		local counter = 0
		local numBits = 0
		local entry = -1

		for i = 1, #input do
			if decode_CharSet[string.sub(input, i, i)] then
				if entry == -1 then
					entry = decode_CharSet[string.sub(input, i, i)]
				else
					entry = entry+decode_CharSet[string.sub(input, i, i)]*91
					counter = bit32.bor(counter, bit32.lshift(entry, numBits))
					if bit32.band(entry, 8191) > 88 then
						numBits = numBits+13
					else
						numBits = numBits+14
					end

					while numBits > 7 do
						output[c] = string.char(counter%256)
						c = c+1
						counter = bit32.rshift(counter, 8)
						numBits = numBits-8
					end
					entry = -1
				end
			end
		end

		if entry ~= -1 then
			output[c] = string.char(bit32.bor(counter, bit32.lshift(entry, numBits))%256)
		end

		return table.concat(output)
	end

	if MAKE_JSON_SAFE then
		encode_CharSet[90] = '"'
		decode_CharSet["'"] = nil
		decode_CharSet['"'] = 90
	end

	base92={
		encode = encodeBase91,
		decode = decodeBase91,
	}
end
do -- Binary

	local DataIndex = {
		StoreType = {
			["Invalid"]=0,
			["Instance"]=1,
			["Root"]=2,
			["Value"]=3,
			-- FINISHED! 
		}, 
		InstanceName = {
			["Invalid"] = 0,
			["Accessory"] = 1,
			["Accoutrement"] = 2,
			["AlignOrientation"] = 3,
			["AlignPosition"] = 4,
			["AngularVelocity"] = 5,
			["Animation"] = 6,
			["AnimationController"] = 7,
			["ArcHandles"] = 8,
			["Atmosphere"] = 9,
			["Backpack"] = 10,
			["BallSocketConstraint"] = 11,
			["Beam"] = 12,
			["BillboardGui"] = 13,
			["BinaryStringValue"] = 14,
			["BindableEvent"] = 15,
			["BindableFunction"] = 16,
			["BlockMesh"] = 17,
			["BloomEffect"] = 18,
			["BlurEffect"] = 19,
			["BodyAngularVelocity"] = 20,
			["BodyColors"] = 21,
			["BodyForce"] = 22,
			["BodyGyro"] = 23,
			["BodyPosition"] = 24,
			["BodyThrust"] = 25,
			["BodyVelocity"] = 26,
			["BoolValue"] = 27,
			["BoxHandleAdornment"] = 28,
			["BrickColorValue"] = 29,
			["Camera"] = 30,
			["CFrameValue"] = 31,
			["CharacterMesh"] = 32,
			["ChorusSoundEffect"] = 33,
			["ClickDetector"] = 34,
			["Color3Value"] = 35,
			["ColorCorrectionEffect"] = 36,
			["CompressorSoundEffect"] = 37,
			["ConeHandleAdornment"] = 38,
			["Configuration"] = 39,
			["CornerWedgePart"] = 40,
			["CylinderHandleAdornment"] = 41,
			["CylindricalConstraint"] = 42,
			["Decal"] = 43,
			["DepthOfFieldEffect"] = 44,
			["Dialog"] = 45,
			["DialogChoice"] = 46,
			["DistortionSoundEffect"] = 47,
			["EchoSoundEffect"] = 48,
			["EqualizerSoundEffect"] = 49,
			["Explosion"] = 50,
			["FileMesh"] = 51,
			["Fire"] = 52,
			["FlangeSoundEffect"] = 53,
			["Folder"] = 54,
			["ForceField"] = 55,
			["Frame"] = 56,
			["Handles"] = 57,
			["HingeConstraint"] = 58,
			["Humanoid"] = 59,
			["HumanoidController"] = 60,
			["HumanoidDescription"] = 61,
			["ImageButton"] = 62,
			["ImageHandleAdornment"] = 63,
			["ImageLabel"] = 64,
			["IntValue"] = 65,
			["Keyframe"] = 66,
			["KeyframeMarker"] = 67,
			["KeyframeSequence"] = 68,
			["LineForce"] = 69,
			["LineHandleAdornment"] = 70,
			["LocalizationTable"] = 71,
			["LocalScript"] = 72,
			["ManualGlue"] = 73,
			["ManualWeld"] = 74,
			["MeshPart"] = 75,
			["Model"] = 76,
			["ModuleScript"] = 77,
			["Motor"] = 78,
			["Motor6D"] = 79,
			["NegateOperation"] = 80,
			["NoCollisionConstraint"] = 81,
			["NumberValue"] = 82,
			["ObjectValue"] = 83,
			["Pants"] = 84,
			["Part"] = 85,
			["ParticleEmitter"] = 86,
			["PartOperation"] = 87,
			["PartOperationAsset"] = 88,
			["PitchShiftSoundEffect"] = 89,
			["PointLight"] = 90,
			["Pose"] = 91,
			["PrismaticConstraint"] = 92,
			["ProximityPrompt"] = 93,
			["RayValue"] = 94,
			["ReflectionMetadata"] = 95,
			["ReflectionMetadataCallbacks"] = 96,
			["ReflectionMetadataClass"] = 97,
			["ReflectionMetadataClasses"] = 98,
			["ReflectionMetadataEnum"] = 99,
			["ReflectionMetadataEnumItem"] = 100,
			["ReflectionMetadataEnums"] = 101,
			["ReflectionMetadataEvents"] = 102,
			["ReflectionMetadataFunctions"] = 103,
			["ReflectionMetadataMember"] = 104,
			["ReflectionMetadataProperties"] = 105,
			["ReflectionMetadataYieldFunctions"] = 106,
			["RemoteEvent"] = 107,
			["RemoteFunction"] = 108,
			["RenderingTest"] = 109,
			["ReverbSoundEffect"] = 110,
			["RocketPropulsion"] = 111,
			["RodConstraint"] = 112,
			["RopeConstraint"] = 113,
			["Rotate"] = 114,
			["RotateP"] = 115,
			["RotateV"] = 116,
			["ScreenGui"] = 117,
			["Script"] = 118,
			["ScrollingFrame"] = 119,
			["Seat"] = 120,
			["SelectionBox"] = 121,
			["SelectionSphere"] = 122,
			["Shirt"] = 123,
			["ShirtGraphic"] = 124,
			["SkateboardController"] = 125,
			["Sky"] = 126,
			["Smoke"] = 127,
			["Snap"] = 128,
			["Sound"] = 129,
			["SoundGroup"] = 130,
			["Sparkles"] = 131,
			["SpawnLocation"] = 132,
			["SpecialMesh"] = 133,
			["SphereHandleAdornment"] = 134,
			["SpotLight"] = 135,
			["SpringConstraint"] = 136,
			["StandalonePluginScripts"] = 137,
			["StarterGear"] = 138,
			["StringValue"] = 139,
			["SunRaysEffect"] = 140,
			["SurfaceAppearance"] = 141,
			["SurfaceGui"] = 142,
			["SurfaceLight"] = 143,
			["SurfaceSelection"] = 144,
			["Team"] = 145,
			["TerrainRegion"] = 146,
			["TextBox"] = 147,
			["TextButton"] = 148,
			["TextLabel"] = 149,
			["Texture"] = 150,
			["Tool"] = 151,
			["Torque"] = 152,
			["Trail"] = 153,
			["TremoloSoundEffect"] = 154,
			["TrussPart"] = 155,
			["Tween"] = 156,
			["UIAspectRatioConstraint"] = 157,
			["UICorner"] = 158,
			["UIGradient"] = 159,
			["UIGridLayout"] = 160,
			["UIListLayout"] = 161,
			["UIPadding"] = 162,
			["UIPageLayout"] = 163,
			["UIScale"] = 164,
			["UISizeConstraint"] = 165,
			["UITableLayout"] = 166,
			["UITextSizeConstraint"] = 167,
			["UnionOperation"] = 168,
			["Vector3Value"] = 169,
			["VectorForce"] = 170,
			["VehicleController"] = 171,
			["VehicleSeat"] = 172,
			["VelocityMotor"] = 173,
			["VideoFrame"] = 174,
			["ViewportFrame"] = 175,
			["WedgePart"] = 176,
			["Weld"] = 177,
			["WeldConstraint"] = 179,
			-- Additions
			["Attachment"] = 180, 
			-- EXTRAS 
			["BasePart"] = 250,
			-- FINSHED! Can add more latert! [255-251] SpecaialValues
			["RefreshValues"] = 254,
			["StopInstanceReading"] = 255
		},
		DataType = {
			["Invalid"] = 0,
			-- Roblox DataTypes
			["Axes"]=1,
			["BrickColor"]=2,
			["CatalogSearchParams"]=3,
			["CFrame"]=4,
			["Color3"]=5,
			["ColorSequence"]=6,
			["ColorSequenceKeypoint"]=7,
			["DateTime"]=8,
			["DockWidgetPluginGuiInfo"]=9,
			["Enum"]=10,
			["EnumItem"]=11,
			["Enums"]=12,
			["Faces"]=13,
			["FloatCurveKey"]=14,
			["Instance"]=15,
			["NumberRange"]=16,
			["NumberSequence"]=17,
			["NumberSequenceKeypoint"]=18,
			["OverlapParams"]=19,
			["PathWaypoint"]=20,
			["PhysicalProperties"]=21,
			["Random"]=22,
			["Ray"]=23,
			["RaycastParams"]=24,
			["RaycastResult"]=25,
			["RBXScriptConnection"]=26,
			["RBXScriptSignal"]=27,
			["Rect"]=28,
			["Region3"]=29,
			["Region3int16"]=30,
			["TweenInfo"]=31,
			["UDim"]=32,
			["UDim2"]=33,
			["Vector2"]=34,
			["Vector2int16"]=35,
			["Vector3"]=36,
			["Vector3int16"]=37,
			-- NormalValues 
			["string"]=38,
			["bool"]=39,
			["int"]=40,
			["float"]=41,
			["double"]=42
			-- FINISHED CAN  ADD MORE LATER! 
		},
		ValueType = {
			["Archivable"]=3,
			["Name"]=4,
			["className"]=5,
			["Parent"]=6,
			["Graphic"]=7,
			["archivable"]=8,
			["ClassName"]=9,
			["Root"]=10,
			["SourceLocaleId"]=11,
			["DevelopmentLanguage"]=12,
			["PrintStreamInstanceQuota"]=13,
			["PrintEvents"]=14,
			["RenderStreamedRegions"]=15,
			["PrintSplitMessage"]=16,
			["TouchSendRate"]=17,
			["PrintFilters"]=18,
			["NetworkOwnerRate"]=19,
			["ArePhysicsRejectionsReported"]=20,
			["PrintInstances"]=21,
			["DataSendRate"]=22,
			["UsePhysicsPacketCache"]=23,
			["PreferredClientPort"]=24,
			["UseInstancePacketCache"]=25,
			["PhysicsSendPriority"]=26,
			["ReceiveRate"]=27,
			["ShowActiveAnimationAsset"]=28,
			["PhysicsSendRate"]=29,
			["PrintPhysicsErrors"]=30,
			["ClientPhysicsSendRate"]=31,
			["TrackPhysicsDetails"]=32,
			["DataGCRate"]=33,
			["TrackDataTypes"]=34,
			["PrintProperties"]=35,
			["PrintBits"]=36,
			["PhysicsMtuAdjust"]=37,
			["DataMtuAdjust"]=38,
			["IncommingReplicationLag"]=39,
			["PrintTouches"]=40,
			["DataSendPriority"]=41,
			["IsQueueErrorComputed"]=42,
			["ResetPlayerGuiOnSpawn"]=43,
			["ShowDevelopmentGui"]=44,
			["ScreenOrientation"]=45,
			["AttachmentPos"]=46,
			["AttachmentPoint"]=47,
			["AttachmentForward"]=48,
			["AttachmentRight"]=49,
			["AttachmentUp"]=50,
			["DebuggingEnabled"]=51,
			["AbsoluteRotation"]=52,
			["IgnoreGuiInset"]=53,
			["DisplayOrder"]=54,
			["RootLocalizationTable"]=55,
			["Enabled"]=56,
			["AbsoluteSize"]=57,
			["AutoLocalize"]=58,
			["AbsolutePosition"]=59,
			["Localize"]=60,
			["ZIndexBehavior"]=61,
			["ResetOnSpawn"]=62,
			["Visible"]=63,
			["RelativeTo"]=64,
			["ApplyAtCenterOfMass"]=65,
			["Color"]=66,
			["Attachment0"]=67,
			["Force"]=68,
			["Attachment1"]=69,
			["Humanoid"]=70,
			["Transparency"]=71,
			["Color3"]=72,
			["Adornee"]=73,
			["Style"]=74,
			["Faces"]=75,
			["FaceId"]=76,
			["InOut"]=77,
			["LeftRight"]=78,
			["TopBottom"]=79,
			["Opacity"]=80,
			["RiseVelocity"]=81,
			["Size"]=82,
			["Scale"]=83,
			["Value"]=84,
			["UserInputType"]=85,
			["KeyCode"]=86,
			["Delta"]=87,
			["Position"]=88,
			["UserInputState"]=89,
			["ImageColor3"]=90,
			["Active"]=91,
			["SizeConstraint"]=92,
			["ZIndex"]=93,
			["BorderSizePixel"]=94,
			["SliceCenter"]=95,
			["Draggable"]=96,
			["ScaleType"]=97,
			["NextSelectionDown"]=98,
			["IsLoaded"]=99,
			["BackgroundColor3"]=100,
			["ImageTransparency"]=101,
			["Selectable"]=102,
			["AnchorPoint"]=103,
			["Image"]=104,
			["TileSize"]=105,
			["BorderColor"]=106,
			["NextSelectionRight"]=107,
			["LayoutOrder"]=108,
			["BackgroundColor"]=109,
			["NextSelectionUp"]=110,
			["BorderColor3"]=111,
			["NextSelectionLeft"]=112,
			["ClipsDescendants"]=113,
			["Rotation"]=114,
			["ImageRectOffset"]=115,
			["BackgroundTransparency"]=116,
			["SelectionImageObject"]=117,
			["SliceScale"]=118,
			["ImageRectSize"]=119,
			["FillDirection"]=120,
			["HorizontalAlignment"]=121,
			["AbsoluteContentSize"]=122,
			["VerticalAlignment"]=123,
			["SortOrder"]=124,
			["Padding"]=125,
			["Torque"]=126,
			["CFrame"]=127,
			["SizeRelativeOffset"]=128,
			["AlwaysOnTop"]=129,
			["Shadows"]=130,
			["Range"]=131,
			["Brightness"]=132,
			["PlaybackState"]=133,
			["ConstrainedValue"]=134,
			["MinValue"]=135,
			["MaxValue"]=136,
			["CartoonFactor"]=137,
			["MaxTorque"]=138,
			["ThrustD"]=139,
			["TurnD"]=140,
			["Target"]=141,
			["MaxThrust"]=142,
			["MaxSpeed"]=143,
			["TurnP"]=144,
			["ThrustP"]=145,
			["TargetRadius"]=146,
			["TargetOffset"]=147,
			["Version"]=148,
			["Face"]=149,
			["Angle"]=150,
			["RightParamB"]=151,
			["TopSurfaceInput"]=152,
			["Velocity"]=153,
			["FrontSurfaceInput"]=154,
			["BottomSurface"]=155,
			["LeftParamB"]=156,
			["BottomParamB"]=157,
			["Friction"]=158,
			["FrontParamB"]=159,
			["BottomSurfaceInput"]=160,
			["CanCollide"]=161,
			["BackSurfaceInput"]=162,
			["BackSurface"]=163,
			["LeftSurface"]=164,
			["Elasticity"]=165,
			["FrontParamA"]=166,
			["brickColor"]=167,
			["Orientation"]=168,
			["TopParamB"]=169,
			["BackParamB"]=170,
			["TopSurface"]=171,
			["LeftSurfaceInput"]=172,
			["ResizeableFaces"]=173,
			["Reflectance"]=174,
			["UsePartColor"]=175,
			["CollisionGroupId"]=176,
			["Anchored"]=177,
			["TriangleCount"]=178,
			["RightParamA"]=179,
			["RotVelocity"]=180,
			["RightSurface"]=181,
			["BottomParamA"]=182,
			["Material"]=183,
			["LocalTransparencyModifier"]=184,
			["FrontSurface"]=185,
			["RightSurfaceInput"]=186,
			["BackParamA"]=187,
			["Locked"]=188,
			["CenterOfMass"]=189,
			["CustomPhysicalProperties"]=190,
			["SpecificGravity"]=191,
			["ReceiveAge"]=192,
			["BrickColor"]=193,
			["ResizeIncrement"]=194,
			["TopParamA"]=195,
			["LeftParamA"]=196,
			["Mix"]=197,
			["Rate"]=198,
			["Priority"]=199,
			["Depth"]=200,
			["ManualActivationOnly"]=201,
			["RequiresHandle"]=202,
			["Grip"]=203,
			["GripUp"]=204,
			["CanBeDropped"]=205,
			["ToolTip"]=206,
			["TextureId"]=207,
			["GripPos"]=208,
			["GripForward"]=209,
			["GripRight"]=210,
			["Shiny"]=211,
			["StudsPerTileU"]=212,
			["StudsPerTileV"]=213,
			["Specular"]=214,
			["Texture"]=215,
			["AreRegionsShown"]=216,
			["UseCSGv2"]=217,
			["AreAnchorsShown"]=218,
			["AreWorldCoordsShown"]=219,
			["IsTreeShown"]=220,
			["IsReceiveAgeShown"]=221,
			["AreJointCoordinatesShown"]=222,
			["AreMechanismsShown"]=223,
			["ArePartCoordsShown"]=224,
			["AreOwnersShown"]=225,
			["DisableCSGv2"]=226,
			["AreContactPointsShown"]=227,
			["AreModelCoordsShown"]=228,
			["ShowDecompositionGeometry"]=229,
			["AreBodyTypesShown"]=230,
			["AreAssembliesShown"]=231,
			["AreUnalignedPartsShown"]=232,
			["PhysicsEnvironmentalThrottle"]=233,
			["AllowSleep"]=234,
			["AreContactIslandsShown"]=235,
			["AreAwakePartsHighlighted"]=236,
			["ThrottleAdjustTime"]=237,
			["LinkedSource"]=238,
			["Disabled"]=239,
			["WaterWaveSize"]=240,
			["MaxExtents"]=241,
			["WaterColor"]=242,
			["WaterWaveSpeed"]=243,
			["WaterReflectance"]=244,
			["WaterTransparency"]=245,
			["IsSmooth"]=246,
			["Length"]=247,
			["Thickness"]=248,
			["ComparisonDiffThreshold"]=249,
			["FieldOfView"]=250,
			["Description"]=251,
			["QualityLevel"]=252,
			["Ticket"]=253,
			["ComparisonMethod"]=254,
			["ComparisonPsnrThreshold"]=255,
			["ShouldSkip"]=256,
			["TextWrapped"]=257,
			["LineHeight"]=258,
			["TextStrokeTransparency"]=259,
			["TextTruncate"]=260,
			["TextYAlignment"]=261,
			["TextScaled"]=262,
			["TextWrap"]=263,
			["TextBounds"]=264,
			["TextTransparency"]=265,
			["PlaceholderText"]=266,
			["TextSize"]=267,
			["ShowNativeInput"]=268,
			["MultiLine"]=269,
			["TextFits"]=270,
			["TextColor3"]=271,
			["Text"]=272,
			["FontSize"]=273,
			["TextStrokeColor3"]=274,
			["Font"]=275,
			["TextXAlignment"]=276,
			["PlaceholderColor3"]=277,
			["ClearTextOnFocus"]=278,
			["TextColor"]=279,
			["Loop"]=280,
			["ExtentsOffset"]=281,
			["PlayerToHideFrom"]=282,
			["LightInfluence"]=283,
			["SizeOffset"]=284,
			["StudsOffsetWorldSpace"]=285,
			["ExtentsOffsetWorldSpace"]=286,
			["MaxDistance"]=287,
			["StudsOffset"]=288,
			["Score"]=289,
			["AutoColorCharacters"]=290,
			["AutoAssignable"]=291,
			["TeamColor"]=292,
			["AutoButtonColor"]=293,
			["Selected"]=294,
			["Modal"]=295,
			["MaxTextSize"]=296,
			["MinTextSize"]=297,
			["P"]=298,
			["maxTorque"]=299,
			["D"]=300,
			["cframe"]=301,
			["Status"]=302,
			["Offset"]=303,
			["MeshId"]=304,
			["VertexColor"]=305,
			["MeshType"]=306,
			["ShirtTemplate"]=307,
			["LimitsEnabled"]=308,
			["CurrentPosition"]=309,
			["TargetPosition"]=310,
			["Speed"]=311,
			["MotorMaxAcceleration"]=312,
			["LowerLimit"]=313,
			["UpperLimit"]=314,
			["Restitution"]=315,
			["ServoMaxForce"]=316,
			["ActuatorType"]=317,
			["MotorMaxForce"]=318,
			["Throttle"]=319,
			["Steer"]=320,
			["Controller"]=321,
			["ControllingHumanoid"]=322,
			["formFactor"]=323,
			["Shape"]=324,
			["StickyWheels"]=325,
			["FormFactor"]=326,
			["Expression"]=327,
			["LocalizedText"]=328,
			["Origin"]=329,
			["ViewSizeX"]=330,
			["ViewSizeY"]=331,
			["Icon"]=332,
			["UnitRay"]=333,
			["Hit"]=334,
			["Y"]=335,
			["TargetFilter"]=336,
			["hit"]=337,
			["TargetSurface"]=338,
			["X"]=339,
			["target"]=340,
			["ClockTime"]=341,
			["ColorShift_Bottom"]=342,
			["FogColor"]=343,
			["FogEnd"]=344,
			["Outlines"]=345,
			["ColorShift_Top"]=346,
			["GlobalShadows"]=347,
			["ExposureCompensation"]=348,
			["GeographicLatitude"]=349,
			["Ambient"]=350,
			["OutdoorAmbient"]=351,
			["ShadowColor"]=352,
			["FogStart"]=353,
			["TimeOfDay"]=354,
			["ExportMergeByMaterial"]=355,
			["FrameRateManager"]=356,
			["ShowBoundingBoxes"]=357,
			["ReloadAssets"]=358,
			["AutoFRMLevel"]=359,
			["EnableFRM"]=360,
			["GraphicsMode"]=361,
			["EditQualityLevel"]=362,
			["RenderCSGTrianglesDebug"]=363,
			["EagerBulkExecution"]=364,
			["MeshCacheSize"]=365,
			["OverlayTextureId"]=366,
			["BaseTextureId"]=367,
			["BodyPart"]=368,
			["HardwareMouse"]=369,
			["ChatScrollLength"]=370,
			["OverrideStarterScript"]=371,
			["MaxCollisionSounds"]=372,
			["BubbleChatMaxBubbles"]=373,
			["ChatHistory"]=374,
			["VideoCaptureEnabled"]=375,
			["CollisionSoundEnabled"]=376,
			["CollisionSoundVolume"]=377,
			["SoftwareSound"]=378,
			["AdditionalCoreIncludeDirs"]=379,
			["VideoQuality"]=380,
			["BubbleChatLifetime"]=381,
			["ReportAbuseChatHistory"]=382,
			["Browsable"]=383,
			["EditingDisabled"]=384,
			["UIMinimum"]=385,
			["Deprecated"]=386,
			["ScriptContext"]=387,
			["ClassCategory"]=388,
			["summary"]=389,
			["UINumTicks"]=390,
			["IsBackend"]=391,
			["Constraint"]=392,
			["UIMaximum"]=393,
			["RightLegColor"]=394,
			["RightArmColor3"]=395,
			["HeadColor3"]=396,
			["LeftLegColor3"]=397,
			["LeftArmColor"]=398,
			["RightArmColor"]=399,
			["LeftArmColor3"]=400,
			["HeadColor"]=401,
			["TorsoColor"]=402,
			["RightLegColor3"]=403,
			["TorsoColor3"]=404,
			["LeftLegColor"]=405,
			["Contrast"]=406,
			["Saturation"]=407,
			["TintColor"]=408,
			["CurrentDistance"]=409,
			["LineThickness"]=410,
			["SurfaceTransparency"]=411,
			["SurfaceColor3"]=412,
			["SurfaceColor"]=413,
			["TurnSpeed"]=414,
			["Occupant"]=415,
			["ThrottleFloat"]=416,
			["AreHingesDetected"]=417,
			["SteerFloat"]=418,
			["HeadsUpDisplay"]=419,
			["VideoMemory"]=420,
			["IsScriptStackTracingEnabled"]=421,
			["PlayerCount"]=422,
			["LuaRamLimit"]=423,
			["RobloxVersion"]=424,
			["DataModel"]=425,
			["OsVer"]=426,
			["OsIs64Bit"]=427,
			["ErrorReporting"]=428,
			["RobloxProductName"]=429,
			["OsPlatformId"]=430,
			["InstanceCount"]=431,
			["IsFmodProfilingEnabled"]=432,
			["ReportSoundWarnings"]=433,
			["SIMD"]=434,
			["TickCountPreciseOverride"]=435,
			["GfxCard"]=436,
			["JobCount"]=437,
			["SystemProductName"]=438,
			["OsPlatform"]=439,
			["TextureSize"]=440,
			["StudsBetweenTextures"]=441,
			["To"]=442,
			["CycleOffset"]=443,
			["From"]=444,
			["WireRadius"]=445,
			["part1"]=446,
			["MaxVelocity"]=447,
			["DesiredAngle"]=448,
			["CurrentAngle"]=449,
			["Part1"]=450,
			["Part0"]=451,
			["C0"]=452,
			["C1"]=453,
			["F0"]=454,
			["F2"]=455,
			["F3"]=456,
			["F1"]=457,
			["StartCorner"]=458,
			["FillDirectionMaxCells"]=459,
			["CellSize"]=460,
			["CellPadding"]=461,
			["Volume"]=462,
			["Condition"]=463,
			["Line"]=464,
			["IsEnabled"]=465,
			["Intensity"]=466,
			["Spread"]=467,
			["PrimaryPart"]=468,
			["MaskWeight"]=469,
			["EasingStyle"]=470,
			["Weight"]=471,
			["EasingDirection"]=472,
			["WeightTarget"]=473,
			["Animation"]=474,
			["Looped"]=475,
			["TimePosition"]=476,
			["WeightCurrent"]=477,
			["IsPlaying"]=478,
			["RigidityEnabled"]=479,
			["MaxForce"]=480,
			["Responsiveness"]=481,
			["ReactionForceEnabled"]=482,
			["AllowInsertFreeModels"]=483,
			["LowerAngle"]=484,
			["AngularVelocity"]=485,
			["TargetAngle"]=486,
			["AngularSpeed"]=487,
			["MotorMaxTorque"]=488,
			["Radius"]=489,
			["ServoMaxTorque"]=490,
			["UpperAngle"]=491,
			["DevComputerMovementMode"]=492,
			["DataComplexity"]=493,
			["CameraMinZoomDistance"]=494,
			["userId"]=495,
			["DevEnableMouseLock"]=496,
			["HealthDisplayDistance"]=497,
			["CharacterAppearance"]=498,
			["MembershipType"]=499,
			["DevTouchMovementMode"]=500,
			["AccountAge"]=501,
			["ReplicationFocus"]=502,
			["CameraMode"]=503,
			["CameraMaxZoomDistance"]=504,
			["UserId"]=505,
			["Character"]=506,
			["Team"]=507,
			["DevTouchCameraMode"]=508,
			["LocaleId"]=509,
			["DataReady"]=510,
			["NameDisplayDistance"]=511,
			["DevComputerCameraMode"]=512,
			["AutoJumpEnabled"]=513,
			["Neutral"]=514,
			["FollowUserId"]=515,
			["CanLoadCharacterAppearance"]=516,
			["RespawnLocation"]=517,
			["CharacterAppearanceId"]=518,
			["DevCameraOcclusionMode"]=519,
			["RequestQueueSize"]=520,
			["BaseUrl"]=521,
			["AbsoluteWindowSize"]=522,
			["ScrollingDirection"]=523,
			["CanvasSize"]=524,
			["MidImage"]=525,
			["CanvasPosition"]=526,
			["ElasticBehavior"]=527,
			["TopImage"]=528,
			["HorizontalScrollBarInset"]=529,
			["VerticalScrollBarPosition"]=530,
			["ScrollBarImageColor3"]=531,
			["ScrollBarImageTransparency"]=532,
			["ScrollBarThickness"]=533,
			["ScrollingEnabled"]=534,
			["BottomImage"]=535,
			["VerticalScrollBarInset"]=536,
			["AutoRotate"]=537,
			["Torso"]=538,
			["RootPart"]=539,
			["HealthDisplayType"]=540,
			["WalkSpeed"]=541,
			["MaxSlopeAngle"]=542,
			["Jump"]=543,
			["NameOcclusion"]=544,
			["HipHeight"]=545,
			["AutomaticScalingEnabled"]=546,
			["Health"]=547,
			["RightLeg"]=548,
			["FloorMaterial"]=549,
			["MaxHealth"]=550,
			["LeftLeg"]=551,
			["DisplayDistanceType"]=552,
			["MoveDirection"]=553,
			["CameraOffset"]=554,
			["RigType"]=555,
			["TargetPoint"]=556,
			["WalkToPart"]=557,
			["JumpPower"]=558,
			["SeatPart"]=559,
			["Sit"]=560,
			["PlatformStand"]=561,
			["maxHealth"]=562,
			["WalkToPoint"]=563,
			["TextureID"]=564,
			["Height"]=565,
			["Threshold"]=566,
			["WorldPosition"]=567,
			["WorldOrientation"]=568,
			["Axis"]=569,
			["SecondaryAxis"]=570,
			["WorldCFrame"]=571,
			["WorldRotation"]=572,
			["WorldAxis"]=573,
			["WorldSecondaryAxis"]=574,
			["HoverImage"]=575,
			["PressedImage"]=576,
			["GoodbyeChoiceActive"]=577,
			["UserDialog"]=578,
			["ResponseDialog"]=579,
			["GoodbyeDialog"]=580,
			["MotorMaxAngularAcceleration"]=581,
			["AngularLimitsEnabled"]=582,
			["InclinationAngle"]=583,
			["AngularActuatorType"]=584,
			["AngularRestitution"]=585,
			["RotationAxisVisible"]=586,
			["WorldRotationAxis"]=587,
			["Point"]=588,
			["SkinColor"]=589,
			["BinType"]=590,
			["LowGain"]=591,
			["HighGain"]=592,
			["MidGain"]=593,
			["VREnabled"]=594,
			["GuiInputUserCFrame"]=595,
			["angularvelocity"]=596,
			["Hole"]=597,
			["UserHeadCFrame"]=598,
			["MouseBehavior"]=599,
			["MouseIconEnabled"]=600,
			["MouseDeltaSensitivity"]=601,
			["KeyboardEnabled"]=602,
			["MouseEnabled"]=603,
			["GyroscopeEnabled"]=604,
			["GamepadEnabled"]=605,
			["ModalEnabled"]=606,
			["OnScreenKeyboardPosition"]=607,
			["OnScreenKeyboardVisible"]=608,
			["AccelerometerEnabled"]=609,
			["OnScreenKeyboardSize"]=610,
			["TouchEnabled"]=611,
			["TouchMovementMode"]=612,
			["RotationType"]=613,
			["TouchCameraMovementMode"]=614,
			["SavedQualityLevel"]=615,
			["MouseSensitivity"]=616,
			["ControlMode"]=617,
			["GamepadCameraSensitivity"]=618,
			["ComputerCameraMovementMode"]=619,
			["MasterVolume"]=620,
			["ComputerMovementMode"]=621,
			["IsFinished"]=622,
			["Duty"]=623,
			["Frequency"]=624,
			["MajorAxis"]=625,
			["FillEmptySpaceRows"]=626,
			["FillEmptySpaceColumns"]=627,
			["BaseAngle"]=628,
			["MinSize"]=629,
			["MaxSize"]=630,
			["Axes"]=631,
			["localPlayer"]=632,
			["BubbleChat"]=633,
			["numPlayers"]=634,
			["ClassicChat"]=635,
			["CharacterAutoLoads"]=636,
			["NumPlayers"]=637,
			["PreferredPlayers"]=638,
			["LocalPlayer"]=639,
			["MaxPlayers"]=640,
			["DominantAxis"]=641,
			["AspectRatio"]=642,
			["AspectType"]=643,
			["CoordinateFrame"]=644,
			["focus"]=645,
			["ViewportSize"]=646,
			["HeadLocked"]=647,
			["NearPlaneZ"]=648,
			["CameraSubject"]=649,
			["HeadScale"]=650,
			["CameraType"]=651,
			["Focus"]=652,
			["Location"]=653,
			["location"]=654,
			["force"]=655,
			["Circular"]=656,
			["GamepadInputEnabled"]=657,
			["ScrollWheelInputEnabled"]=658,
			["TouchInputEnabled"]=659,
			["Animated"]=660,
			["CurrentPage"]=661,
			["TweenTime"]=662,
			["EmptyCutoff"]=663,
			["Transform"]=664,
			["PaddingTop"]=665,
			["PaddingBottom"]=666,
			["PaddingLeft"]=667,
			["PaddingRight"]=668,
			["BlastPressure"]=669,
			["BlastRadius"]=670,
			["DestroyJointRadiusPercent"]=671,
			["ExplosionType"]=672,
			["SimulateSecondsLag"]=673,
			["ErrorCount"]=674,
			["IsPhysicsEnvironmentalThrottled"]=675,
			["NumberOfPlayers"]=676,
			["Timeout"]=677,
			["Is30FpsThrottleEnabled"]=678,
			["AutoRuns"]=679,
			["ExecuteWithStudioRun"]=680,
			["WarnCount"]=681,
			["IsSleepAllowed"]=682,
			["TestCount"]=683,
			["SizeInCells"]=684,
			["CustomizedTeleportUI"]=685,
			["Pitch"]=686,
			["SoundGroup"]=687,
			["EmitterSize"]=688,
			["RollOffMode"]=689,
			["PlaybackSpeed"]=690,
			["Playing"]=691,
			["TimeLength"]=692,
			["MinDistance"]=693,
			["PlaybackLoudness"]=694,
			["isPlaying"]=695,
			["SoundId"]=696,
			["IsPaused"]=697,
			["PlayOnRemove"]=698,
			["ThreadPoolSize"]=699,
			["SchedulerRate"]=700,
			["SchedulerDutyCycle"]=701,
			["ThreadPoolConfig"]=702,
			["PrimitivesCount"]=703,
			["ContactsCount"]=704,
			["PhysicsStepTimeMs"]=705,
			["DataReceiveKbps"]=706,
			["PhysicsReceiveKbps"]=707,
			["DataSendKbps"]=708,
			["HeartbeatTimeMs"]=709,
			["MovingPrimitivesCount"]=710,
			["PhysicsSendKbps"]=711,
			["AllowTeamChangeOnTouch"]=712,
			["Duration"]=713,
			["position"]=714,
			["maxForce"]=715,
			["EnableMouseLockOption"]=716,
			["AllowCustomAnimations"]=717,
			["DevComputerCameraMovementMode"]=718,
			["LoadCharacterAppearance"]=719,
			["DevTouchCameraMovementMode"]=720,
			["SparkleColor"]=721,
			["DistanceFactor"]=722,
			["RolloffScale"]=723,
			["DopplerScale"]=724,
			["RespectFilteringEnabled"]=725,
			["AmbientReverb"]=726,
			["InitialPrompt"]=727,
			["Tone"]=728,
			["InUse"]=729,
			["ConversationDistance"]=730,
			["Purpose"]=731,
			["BehaviorType"]=732,
			["TriggerOffset"]=733,
			["TriggerDistance"]=734,
			["WetLevel"]=735,
			["Diffusion"]=736,
			["DecayTime"]=737,
			["Density"]=738,
			["DryLevel"]=739,
			["Octave"]=740,
			["Feedback"]=741,
			["Delay"]=742,
			["Level"]=743,
			["AnimationId"]=744,
			["AutoSelectGuiEnabled"]=745,
			["IsModalDialog"]=746,
			["CoreGuiNavigationEnabled"]=747,
			["IsWindows"]=748,
			["GuiNavigationEnabled"]=749,
			["MenuIsOpen"]=750,
			["SelectedObject"]=751,
			["PrivateServerId"]=752,
			["lighting"]=753,
			["PlaceId"]=754,
			["Genre"]=755,
			["Workspace"]=756,
			["PrivateServerOwnerId"]=757,
			["CreatorId"]=758,
			["VIPServerOwnerId"]=759,
			["PlaceVersion"]=760,
			["VIPServerId"]=761,
			["GameId"]=762,
			["JobId"]=763,
			["GearGenreSetting"]=764,
			["workspace"]=765,
			["CreatorType"]=766,
			["ZOffset"]=767,
			["ToolPunchThroughDistance"]=768,
			["Script"]=769,
			["CurrentLine"]=770,
			["IsDebugging"]=771,
			["CurrentScreenOrientation"]=772,
			["Insertable"]=773,
			["PreferredParents"]=774,
			["ExplorerOrder"]=775,
			["ExplorerImageIndex"]=776,
			["PreferredParent"]=777,
			["MaxItems"]=778,
			["Drag"]=779,
			["Lifetime"]=780,
			["Acceleration"]=781,
			["RotSpeed"]=782,
			["EmissionDirection"]=783,
			["LockedToPart"]=784,
			["SpreadAngle"]=785,
			["LightEmission"]=786,
			["VelocityInheritance"]=787,
			["VelocitySpread"]=788,
			["PrimaryAxisOnly"]=789,
			["ReactionTorqueEnabled"]=790,
			["MaxAngularVelocity"]=791,
			["ClickableWhenViewportHidden"]=792,
			["ActionId"]=793,
			["StatusTip"]=794,
			["Port"]=795,
			["CollisionEnabled"]=796,
			["GridSize"]=797,
			["Source"]=798,
			["FaceCamera"]=799,
			["WidthScale"]=800,
			["TextureMode"]=801,
			["TextureLength"]=802,
			["MaxLength"]=803,
			["MinLength"]=804,
			["StarCount"]=805,
			["MoonTextureId"]=806,
			["CelestialBodiesShown"]=807,
			["SunTextureId"]=808,
			["SkyboxUp"]=809,
			["SkyboxFt"]=810,
			["SkyboxLf"]=811,
			["SkyboxBk"]=812,
			["SunAngularSize"]=813,
			["SkyboxDn"]=814,
			["SkyboxRt"]=815,
			["MoonAngularSize"]=816,
			["HostWidgetWasRestored"]=817,
			["Title"]=818,
			["TwistUpperAngle"]=819,
			["TwistLimitsEnabled"]=820,
			["TwistLowerAngle"]=821,
			["PackageId"]=822,
			["VersionNumber"]=823,
			["LoadDefaultChat"]=824,
			["DistributedGameTime"]=825,
			["FilteringEnabled"]=826,
			["AllowThirdPartySales"]=827,
			["FallenPartsDestroyHeight"]=828,
			["CurrentCamera"]=829,
			["StreamingEnabled"]=830,
			["Terrain"]=831,
			["TemporaryLegacyPhysicsSolverOverride"]=832,
			["Gravity"]=833,
			["InverseSquareLaw"]=834,
			["Magnitude"]=835,
			["PantsTemplate"]=836,
			["GainMakeup"]=837,
			["Release"]=838,
			["Ratio"]=839,
			["SideChain"]=840,
			["Attack"]=841,
			["Part"]=842,
			["Damping"]=843,
			["Coils"]=844,
			["Stiffness"]=845,
			["FreeLength"]=846,
			["CurrentLength"]=847,
			["Heat"]=848,
			["SecondaryColor"]=849,
			["size"]=850,
			["Instance"]=851,
			["TweenInfo"]=852,
			["GcStepMul"]=853,
			["AreScriptStartsReported"]=854,
			["DefaultWaitTime"]=855,
			["WaitingThreadsBudget"]=856,
			["GcLimit"]=857,
			["GcFrequency"]=858,
			["GcPause"]=859,
			["RobloxLocaleId"]=860,
			["SystemLocaleId"]=861,
			["Segments"]=862,
			["Width1"]=863,
			["TextureSpeed"]=864,
			["CurveSize1"]=865,
			["CurveSize0"]=866,
			["Width0"]=867,
			["CursorIcon"]=868,
			["MaxActivationDistance"]=869,
			["velocity"]=870,
			["Time"]=871,
		}
	}

	-- Autogenerate translate object 
	local TranslateIndex = {} 
	for name,Indexes in pairs(DataIndex) do 
		TranslateIndex[name] = {}
		for i,v in pairs(Indexes) do 
			TranslateIndex[name][v] = i
		end 
	end 

	local readByte = function(data,pos) 
		return string.byte(data:sub(pos,pos))
	end 
	local translate = function(Index,value) 
		local  Data = TranslateIndex[Index] 
		return Data[value] or "Invalid"
	end 
	local describe = function(Index,Type) 
		local Data = DataIndex[Index]
		if Data and Data[Type] then 
			if Index == "ValueType" then 
				return string.pack("H",Data[Type])
			else 
				return string.char(Data[Type]) or 0
			end
		else
			if Index == "Value" then 
				local Type = tostring(Type)
				local dataSize = #Type 
				if dataSize > 255 then 
					warn("[RBXLSerialize][Binary]:Cannot Encode DataValues more than 255 Bytes.")
					return 
				end 
				return (string.char(dataSize)..Type) or 0
			end 
			warn("[RBXLSerialize][Binary]:Could not describe",Index,Type)
			return 0 
		end 
	end 

	function DecodeData(data)
		local parsedTable = {}  
		local StoreType  = translate("StoreType",readByte(data,1))
		if StoreType ~= "Invalid" then 
			parsedTable.TypeOf = StoreType
			local i = 1; 
			local readMode = ""
			local instanceName , dataType
			if StoreType == "Instance" then 
				readMode = "Ins:Prop"
				instanceName = translate("InstanceName",readByte(data,2))
				-- shift over one byte.
				parsedTable.ClassName = instanceName
				i = i + 1
			end
			if StoreType  == "Value" then 
				readMode = "Val:Prop" 
				dataType = translate("DataType",readByte(data,2))

				parsedTable.ClassName = dataType
				-- 
				local valueSize = readByte(data,3)
				local RawData  = data:sub(4,4+valueSize) 
				parsedTable[dataType] = RawData

				-- shift over  all remaining bytes nothing else to be rea 
				i = i + 5 
			end 
			if StoreType == "Root" then 
				parsedTable.ClassName = "Root"
				parsedTable.Root = {} 
				--
				readMode = "Root:NewRoot"
				i = i -1 
			end 
			while i < #data do i = i + 1 
				local decimalByte = readByte(data,i)
				if readMode == "Root:NewRoot" and i+3 < #data then 
					-- Raw data reading :> 
					local valueSize_RootDir = readByte(data,i+1)
					local RootDir_RawData = data:sub(i+2,i+1+valueSize_RootDir) 
					local valueSize_RootData = readByte(data,i+2+valueSize_RootDir)
					local RootData_RawData = data:sub(i+3+valueSize_RootDir,i+3+valueSize_RootDir+valueSize_RootData)


					local Decoded = DecodeData(RootData_RawData)
					table.insert(parsedTable.Root,{RootDir_RawData,Decoded})
					-- byte shifting 
					i = i + (valueSize_RootDir+valueSize_RootData +1)
				end 
				if readMode == "Ins:Prop" and i+2 < #data then 
					local Chunk = data:sub(i,i+1)
					local Property = translate("ValueType",string.unpack("H",Chunk))
					i = i + 1 
					local valueSize = readByte(data,i+1)
					local RawData  = data:sub(i+2,i+1+valueSize) 
					if Property ~= "Invalid" then 
						parsedTable[Property] = RawData
					end 
					i = i + valueSize+1
				end 
			end 
		else 
			warn("[RBXLSerialize][Binary]:StoreType defined as Invalid? Binary Data may be corrupted?")
		end
		return parsedTable 
	end

	Binary = {
		DecodeData = DecodeData,
		describe = describe,
	} 
end
do -- API
	API = {}

	local API_URL = "https://anaminus.github.io/rbx/json/api/latest.json"


	function FetchAPI()
		local successGetAsync, data = pcall(function()
			return "[{\"Superclass\":null,\"type\":\"Class\",\"Name\":\"Instance\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Archivable\",\"tags\":[],\"Class\":\"Instance\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ClassName\",\"tags\":[\"readonly\"],\"Class\":\"Instance\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DataCost\",\"tags\":[\"LocalUserSecurity\",\"readonly\"],\"Class\":\"Instance\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Name\",\"tags\":[],\"Class\":\"Instance\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Parent\",\"tags\":[],\"Class\":\"Instance\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RobloxLocked\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Instance\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"archivable\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"Instance\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"className\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Instance\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearAllChildren\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"Clone\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Destroy\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"FindFirstAncestor\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"FindFirstAncestorOfClass\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"FindFirstAncestorWhichIsA\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"recursive\",\"Default\":\"false\"}],\"Name\":\"FindFirstChild\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"FindFirstChildOfClass\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"recursive\",\"Default\":\"false\"}],\"Name\":\"FindFirstChildWhichIsA\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetChildren\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"scopeLength\",\"Default\":\"4\"}],\"Name\":\"GetDebugId\",\"tags\":[\"PluginSecurity\",\"notbrowsable\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetDescendants\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetFullName\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"EventInstance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"property\",\"Default\":null}],\"Name\":\"GetPropertyChangedSignal\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"IsA\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"descendant\",\"Default\":null}],\"Name\":\"IsAncestorOf\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"ancestor\",\"Default\":null}],\"Name\":\"IsDescendantOf\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Remove\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"childName\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"timeOut\",\"Default\":null}],\"Name\":\"WaitForChild\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"children\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"clone\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"destroy\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"recursive\",\"Default\":\"false\"}],\"Name\":\"findFirstChild\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"getChildren\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"isA\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"ancestor\",\"Default\":null}],\"Name\":\"isDescendantOf\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"remove\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"child\",\"Type\":\"Instance\"},{\"Name\":\"parent\",\"Type\":\"Instance\"}],\"Name\":\"AncestryChanged\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"property\",\"Type\":\"Property\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"child\",\"Type\":\"Instance\"}],\"Name\":\"ChildAdded\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"child\",\"Type\":\"Instance\"}],\"Name\":\"ChildRemoved\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"descendant\",\"Type\":\"Instance\"}],\"Name\":\"DescendantAdded\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"descendant\",\"Type\":\"Instance\"}],\"Name\":\"DescendantRemoving\",\"tags\":[],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"child\",\"Type\":\"Instance\"}],\"Name\":\"childAdded\",\"tags\":[\"deprecated\"],\"Class\":\"Instance\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Accoutrement\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"AttachmentForward\",\"tags\":[],\"Class\":\"Accoutrement\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"AttachmentPoint\",\"tags\":[],\"Class\":\"Accoutrement\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"AttachmentPos\",\"tags\":[],\"Class\":\"Accoutrement\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"AttachmentRight\",\"tags\":[],\"Class\":\"Accoutrement\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"AttachmentUp\",\"tags\":[],\"Class\":\"Accoutrement\"},{\"Superclass\":\"Accoutrement\",\"type\":\"Class\",\"Name\":\"Accessory\",\"tags\":[]},{\"Superclass\":\"Accoutrement\",\"type\":\"Class\",\"Name\":\"Hat\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AdService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ShowVideoAd\",\"tags\":[\"deprecated\"],\"Class\":\"AdService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"adShown\",\"Type\":\"bool\"}],\"Name\":\"VideoAdClosed\",\"tags\":[\"deprecated\"],\"Class\":\"AdService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AdvancedDragger\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AnalyticsService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"target\",\"Default\":null}],\"Name\":\"ReleaseRBXEventStream\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"counterName\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"amount\",\"Default\":\"1\"}],\"Name\":\"ReportCounter\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"seriesName\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"points\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"throttlingPercentage\",\"Default\":null}],\"Name\":\"ReportInfluxSeries\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"category\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"ReportStats\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventContext\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventName\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"additionalArgs\",\"Default\":null}],\"Name\":\"SendEventDeferred\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventContext\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventName\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"additionalArgs\",\"Default\":null}],\"Name\":\"SendEventImmediately\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventContext\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventName\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"additionalArgs\",\"Default\":null}],\"Name\":\"SetRBXEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventContext\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"eventName\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"additionalArgs\",\"Default\":null}],\"Name\":\"SetRBXEventStream\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"category\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"action\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"label\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"value\",\"Default\":\"0\"}],\"Name\":\"TrackEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Dictionary\",\"Name\":\"args\",\"Default\":null}],\"Name\":\"UpdateHeartbeatObject\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AnalyticsService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Animation\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"AnimationId\",\"tags\":[],\"Class\":\"Animation\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AnimationController\",\"tags\":[]},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetPlayingAnimationTracks\",\"tags\":[],\"Class\":\"AnimationController\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"animation\",\"Default\":null}],\"Name\":\"LoadAnimation\",\"tags\":[],\"Class\":\"AnimationController\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"animationTrack\",\"Type\":\"Instance\"}],\"Name\":\"AnimationPlayed\",\"tags\":[],\"Class\":\"AnimationController\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AnimationTrack\",\"tags\":[]},{\"ValueType\":\"Class:Animation\",\"type\":\"Property\",\"Name\":\"Animation\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsPlaying\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Length\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Looped\",\"tags\":[],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"AnimationPriority\",\"type\":\"Property\",\"Name\":\"Priority\",\"tags\":[],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Speed\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TimePosition\",\"tags\":[],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WeightCurrent\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WeightTarget\",\"tags\":[\"readonly\"],\"Class\":\"AnimationTrack\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"speed\",\"Default\":\"1\"}],\"Name\":\"AdjustSpeed\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"weight\",\"Default\":\"1\"},{\"Type\":\"float\",\"Name\":\"fadeTime\",\"Default\":\"0.100000001\"}],\"Name\":\"AdjustWeight\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"keyframeName\",\"Default\":null}],\"Name\":\"GetTimeOfKeyframe\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"fadeTime\",\"Default\":\"0.100000001\"},{\"Type\":\"float\",\"Name\":\"weight\",\"Default\":\"1\"},{\"Type\":\"float\",\"Name\":\"speed\",\"Default\":\"1\"}],\"Name\":\"Play\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"fadeTime\",\"Default\":\"0.100000001\"}],\"Name\":\"Stop\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"DidLoop\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"keyframeName\",\"Type\":\"string\"}],\"Name\":\"KeyframeReached\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Stopped\",\"tags\":[],\"Class\":\"AnimationTrack\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Animator\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"animation\",\"Default\":null}],\"Name\":\"LoadAnimation\",\"tags\":[],\"Class\":\"Animator\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"deltaTime\",\"Default\":null}],\"Name\":\"StepAnimations\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Animator\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"AssetService\",\"tags\":[]},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"placeName\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"templatePlaceID\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":\"\"}],\"Name\":\"CreatePlaceAsync\",\"tags\":[],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"placeName\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"templatePlaceID\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":\"\"}],\"Name\":\"CreatePlaceInPlayerInventoryAsync\",\"tags\":[],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"packageAssetId\",\"Default\":null}],\"Name\":\"GetAssetIdsForPackage\",\"tags\":[],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"Vector2\",\"Name\":\"thumbnailSize\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"assetType\",\"Default\":\"0\"}],\"Name\":\"GetAssetThumbnailAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"creationID\",\"Default\":null}],\"Name\":\"GetCreatorAssetID\",\"tags\":[\"deprecated\"],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetGamePlacesAsync\",\"tags\":[],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SavePlaceAsync\",\"tags\":[],\"Class\":\"AssetService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Attachment\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Axis\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Orientation\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Rotation\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"SecondaryAxis\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldAxis\",\"tags\":[\"readonly\"],\"Class\":\"Attachment\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"WorldCFrame\",\"tags\":[\"readonly\"],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldOrientation\",\"tags\":[\"readonly\"],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldPosition\",\"tags\":[\"readonly\"],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldRotation\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Attachment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldSecondaryAxis\",\"tags\":[\"readonly\"],\"Class\":\"Attachment\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetAxis\",\"tags\":[],\"Class\":\"Attachment\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetSecondaryAxis\",\"tags\":[],\"Class\":\"Attachment\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"axis\",\"Default\":null}],\"Name\":\"SetAxis\",\"tags\":[],\"Class\":\"Attachment\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"axis\",\"Default\":null}],\"Name\":\"SetSecondaryAxis\",\"tags\":[],\"Class\":\"Attachment\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"BadgeService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"AwardBadge\",\"tags\":[],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"GetBadgeInfoAsync\",\"tags\":[],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"IsDisabled\",\"tags\":[],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"IsLegal\",\"tags\":[],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"UserHasBadge\",\"tags\":[\"deprecated\"],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"badgeId\",\"Default\":null}],\"Name\":\"UserHasBadgeAsync\",\"tags\":[],\"Class\":\"BadgeService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"userId\",\"Type\":\"int64\"},{\"Name\":\"badgeId\",\"Type\":\"int64\"}],\"Name\":\"BadgeAwarded\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"BadgeService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"BasePlayerGui\",\"tags\":[]},{\"Superclass\":\"BasePlayerGui\",\"type\":\"Class\",\"Name\":\"CoreGui\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"SelectionImageObject\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"CoreGui\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Version\",\"tags\":[\"readonly\"],\"Class\":\"CoreGui\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"guiAdornee\",\"Default\":null},{\"Type\":\"NormalId\",\"Name\":\"faceId\",\"Default\":null}],\"Name\":\"SetUserGuiRendering\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"CoreGui\",\"type\":\"Function\"},{\"Superclass\":\"BasePlayerGui\",\"type\":\"Class\",\"Name\":\"PlayerGui\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"ScreenOrientation\",\"type\":\"Property\",\"Name\":\"CurrentScreenOrientation\",\"tags\":[\"readonly\"],\"Class\":\"PlayerGui\"},{\"ValueType\":\"ScreenOrientation\",\"type\":\"Property\",\"Name\":\"ScreenOrientation\",\"tags\":[],\"Class\":\"PlayerGui\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"SelectionImageObject\",\"tags\":[],\"Class\":\"PlayerGui\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetTopbarTransparency\",\"tags\":[],\"Class\":\"PlayerGui\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"transparency\",\"Default\":null}],\"Name\":\"SetTopbarTransparency\",\"tags\":[],\"Class\":\"PlayerGui\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"transparency\",\"Type\":\"float\"}],\"Name\":\"TopbarTransparencyChangedSignal\",\"tags\":[],\"Class\":\"PlayerGui\",\"type\":\"Event\"},{\"Superclass\":\"BasePlayerGui\",\"type\":\"Class\",\"Name\":\"StarterGui\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ProcessUserInput\",\"tags\":[\"PluginSecurity\",\"hidden\"],\"Class\":\"StarterGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ResetPlayerGuiOnSpawn\",\"tags\":[\"deprecated\"],\"Class\":\"StarterGui\"},{\"ValueType\":\"ScreenOrientation\",\"type\":\"Property\",\"Name\":\"ScreenOrientation\",\"tags\":[],\"Class\":\"StarterGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShowDevelopmentGui\",\"tags\":[],\"Class\":\"StarterGui\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"CoreGuiType\",\"Name\":\"coreGuiType\",\"Default\":null}],\"Name\":\"GetCoreGuiEnabled\",\"tags\":[],\"Class\":\"StarterGui\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"parameterName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"getFunction\",\"Default\":null}],\"Name\":\"RegisterGetCore\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"StarterGui\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"parameterName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"setFunction\",\"Default\":null}],\"Name\":\"RegisterSetCore\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"StarterGui\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"parameterName\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetCore\",\"tags\":[],\"Class\":\"StarterGui\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CoreGuiType\",\"Name\":\"coreGuiType\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetCoreGuiEnabled\",\"tags\":[],\"Class\":\"StarterGui\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"parameterName\",\"Default\":null}],\"Name\":\"GetCore\",\"tags\":[],\"Class\":\"StarterGui\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"coreGuiType\",\"Type\":\"CoreGuiType\"},{\"Name\":\"enabled\",\"Type\":\"bool\"}],\"Name\":\"CoreGuiChangedSignal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"StarterGui\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Beam\",\"tags\":[]},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment0\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment1\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"ColorSequence\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurveSize0\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurveSize1\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"FaceCamera\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightEmission\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightInfluence\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Segments\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Texture\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextureLength\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"TextureMode\",\"type\":\"Property\",\"Name\":\"TextureMode\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextureSpeed\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"NumberSequence\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Width0\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Width1\",\"tags\":[],\"Class\":\"Beam\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ZOffset\",\"tags\":[],\"Class\":\"Beam\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"offset\",\"Default\":\"0\"}],\"Name\":\"SetTextureOffset\",\"tags\":[],\"Class\":\"Beam\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"BindableEvent\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"Fire\",\"tags\":[],\"Class\":\"BindableEvent\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"Event\",\"tags\":[],\"Class\":\"BindableEvent\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"BindableFunction\",\"tags\":[]},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"Invoke\",\"tags\":[],\"Class\":\"BindableFunction\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"OnInvoke\",\"tags\":[],\"Class\":\"BindableFunction\",\"type\":\"Callback\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"BodyMover\",\"tags\":[]},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyAngularVelocity\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"AngularVelocity\",\"tags\":[],\"Class\":\"BodyAngularVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MaxTorque\",\"tags\":[],\"Class\":\"BodyAngularVelocity\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"P\",\"tags\":[],\"Class\":\"BodyAngularVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"angularvelocity\",\"tags\":[\"deprecated\"],\"Class\":\"BodyAngularVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"maxTorque\",\"tags\":[\"deprecated\"],\"Class\":\"BodyAngularVelocity\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyForce\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Force\",\"tags\":[],\"Class\":\"BodyForce\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"force\",\"tags\":[\"deprecated\"],\"Class\":\"BodyForce\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyGyro\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"BodyGyro\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"D\",\"tags\":[],\"Class\":\"BodyGyro\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MaxTorque\",\"tags\":[],\"Class\":\"BodyGyro\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"P\",\"tags\":[],\"Class\":\"BodyGyro\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"cframe\",\"tags\":[\"deprecated\"],\"Class\":\"BodyGyro\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"maxTorque\",\"tags\":[\"deprecated\"],\"Class\":\"BodyGyro\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyPosition\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"D\",\"tags\":[],\"Class\":\"BodyPosition\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MaxForce\",\"tags\":[],\"Class\":\"BodyPosition\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"P\",\"tags\":[],\"Class\":\"BodyPosition\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"BodyPosition\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"maxForce\",\"tags\":[\"deprecated\"],\"Class\":\"BodyPosition\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"position\",\"tags\":[\"deprecated\"],\"Class\":\"BodyPosition\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetLastForce\",\"tags\":[],\"Class\":\"BodyPosition\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"lastForce\",\"tags\":[\"deprecated\"],\"Class\":\"BodyPosition\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"ReachedTarget\",\"tags\":[],\"Class\":\"BodyPosition\",\"type\":\"Event\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyThrust\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Force\",\"tags\":[],\"Class\":\"BodyThrust\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Location\",\"tags\":[],\"Class\":\"BodyThrust\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"force\",\"tags\":[\"deprecated\"],\"Class\":\"BodyThrust\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"location\",\"tags\":[\"deprecated\"],\"Class\":\"BodyThrust\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"BodyVelocity\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MaxForce\",\"tags\":[],\"Class\":\"BodyVelocity\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"P\",\"tags\":[],\"Class\":\"BodyVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Velocity\",\"tags\":[],\"Class\":\"BodyVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"maxForce\",\"tags\":[\"deprecated\"],\"Class\":\"BodyVelocity\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"velocity\",\"tags\":[\"deprecated\"],\"Class\":\"BodyVelocity\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetLastForce\",\"tags\":[],\"Class\":\"BodyVelocity\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"lastForce\",\"tags\":[],\"Class\":\"BodyVelocity\",\"type\":\"Function\"},{\"Superclass\":\"BodyMover\",\"type\":\"Class\",\"Name\":\"RocketPropulsion\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CartoonFactor\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxSpeed\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxThrust\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MaxTorque\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Target\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"TargetOffset\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TargetRadius\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ThrustD\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ThrustP\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TurnD\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TurnP\",\"tags\":[],\"Class\":\"RocketPropulsion\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Abort\",\"tags\":[],\"Class\":\"RocketPropulsion\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Fire\",\"tags\":[],\"Class\":\"RocketPropulsion\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"fire\",\"tags\":[\"deprecated\"],\"Class\":\"RocketPropulsion\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"ReachedTarget\",\"tags\":[],\"Class\":\"RocketPropulsion\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Button\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClickableWhenViewportHidden\",\"tags\":[],\"Class\":\"Button\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Button\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Icon\",\"tags\":[],\"Class\":\"Button\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"active\",\"Default\":null}],\"Name\":\"SetActive\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Button\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"Click\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Button\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CacheableContentProvider\",\"tags\":[]},{\"Superclass\":\"CacheableContentProvider\",\"type\":\"Class\",\"Name\":\"MeshContentProvider\",\"tags\":[]},{\"Superclass\":\"CacheableContentProvider\",\"type\":\"Class\",\"Name\":\"SolidModelContentProvider\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Camera\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"CameraSubject\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"CameraType\",\"type\":\"Property\",\"Name\":\"CameraType\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CoordinateFrame\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"Camera\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FieldOfView\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Focus\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HeadLocked\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HeadScale\",\"tags\":[],\"Class\":\"Camera\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"NearPlaneZ\",\"tags\":[\"readonly\"],\"Class\":\"Camera\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"ViewportSize\",\"tags\":[\"readonly\"],\"Class\":\"Camera\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"focus\",\"tags\":[\"deprecated\"],\"Class\":\"Camera\"},{\"ReturnType\":\"float\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"ignoreList\",\"Default\":null}],\"Name\":\"GetLargestCutoffDistance\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetPanSpeed\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Array\",\"Name\":\"castPoints\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"ignoreList\",\"Default\":null}],\"Name\":\"GetPartsObscuringTarget\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[],\"Name\":\"GetRenderCFrame\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetRoll\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetTiltSpeed\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CoordinateFrame\",\"Name\":\"endPos\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"endFocus\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"duration\",\"Default\":null}],\"Name\":\"Interpolate\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"units\",\"Default\":null}],\"Name\":\"PanUnits\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"Ray\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"depth\",\"Default\":\"0\"}],\"Name\":\"ScreenPointToRay\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CameraPanMode\",\"Name\":\"mode\",\"Default\":\"Classic\"}],\"Name\":\"SetCameraPanMode\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"rollAngle\",\"Default\":null}],\"Name\":\"SetRoll\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"units\",\"Default\":null}],\"Name\":\"TiltUnits\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"Ray\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"depth\",\"Default\":\"0\"}],\"Name\":\"ViewportPointToRay\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"worldPoint\",\"Default\":null}],\"Name\":\"WorldToScreenPoint\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"worldPoint\",\"Default\":null}],\"Name\":\"WorldToViewportPoint\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"distance\",\"Default\":null}],\"Name\":\"Zoom\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Camera\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"entering\",\"Type\":\"bool\"}],\"Name\":\"FirstPersonTransition\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Camera\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"InterpolationFinished\",\"tags\":[],\"Class\":\"Camera\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ChangeHistoryService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"GetCanRedo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"GetCanUndo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Redo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ResetWaypoints\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"state\",\"Default\":null}],\"Name\":\"SetEnabled\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"SetWaypoint\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Undo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"waypoint\",\"Type\":\"string\"}],\"Name\":\"OnRedo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"waypoint\",\"Type\":\"string\"}],\"Name\":\"OnUndo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ChangeHistoryService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CharacterAppearance\",\"tags\":[]},{\"Superclass\":\"CharacterAppearance\",\"type\":\"Class\",\"Name\":\"BodyColors\",\"tags\":[]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"HeadColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"HeadColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"LeftArmColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"LeftArmColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"LeftLegColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"LeftLegColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"RightArmColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"RightArmColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"RightLegColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"RightLegColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TorsoColor\",\"tags\":[],\"Class\":\"BodyColors\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TorsoColor3\",\"tags\":[],\"Class\":\"BodyColors\"},{\"Superclass\":\"CharacterAppearance\",\"type\":\"Class\",\"Name\":\"CharacterMesh\",\"tags\":[]},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"BaseTextureId\",\"tags\":[],\"Class\":\"CharacterMesh\"},{\"ValueType\":\"BodyPart\",\"type\":\"Property\",\"Name\":\"BodyPart\",\"tags\":[],\"Class\":\"CharacterMesh\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"MeshId\",\"tags\":[],\"Class\":\"CharacterMesh\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"OverlayTextureId\",\"tags\":[],\"Class\":\"CharacterMesh\"},{\"Superclass\":\"CharacterAppearance\",\"type\":\"Class\",\"Name\":\"Clothing\",\"tags\":[]},{\"Superclass\":\"Clothing\",\"type\":\"Class\",\"Name\":\"Pants\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"PantsTemplate\",\"tags\":[],\"Class\":\"Pants\"},{\"Superclass\":\"Clothing\",\"type\":\"Class\",\"Name\":\"Shirt\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"ShirtTemplate\",\"tags\":[],\"Class\":\"Shirt\"},{\"Superclass\":\"CharacterAppearance\",\"type\":\"Class\",\"Name\":\"ShirtGraphic\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Graphic\",\"tags\":[],\"Class\":\"ShirtGraphic\"},{\"Superclass\":\"CharacterAppearance\",\"type\":\"Class\",\"Name\":\"Skin\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"SkinColor\",\"tags\":[],\"Class\":\"Skin\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Chat\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LoadDefaultChat\",\"tags\":[\"ScriptWriteRestricted: [NotAccessibleSecurity]\"],\"Class\":\"Chat\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"partOrCharacter\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"message\",\"Default\":null},{\"Type\":\"ChatColor\",\"Name\":\"color\",\"Default\":\"Blue\"}],\"Name\":\"Chat\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"partOrCharacter\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"message\",\"Default\":null},{\"Type\":\"ChatColor\",\"Name\":\"color\",\"Default\":\"Blue\"}],\"Name\":\"ChatLocal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Chat\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetShouldUseLuaChat\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Chat\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"ChatCallbackType\",\"Name\":\"callbackType\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"callbackArguments\",\"Default\":null}],\"Name\":\"InvokeChatCallback\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"ChatCallbackType\",\"Name\":\"callbackType\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"callbackFunction\",\"Default\":null}],\"Name\":\"RegisterChatCallback\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"CanUserChatAsync\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userIdFrom\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"userIdTo\",\"Default\":null}],\"Name\":\"CanUsersChatAsync\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"stringToFilter\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"playerFrom\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"playerTo\",\"Default\":null}],\"Name\":\"FilterStringAsync\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"stringToFilter\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"playerFrom\",\"Default\":null}],\"Name\":\"FilterStringForBroadcast\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"stringToFilter\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"playerToFilterFor\",\"Default\":null}],\"Name\":\"FilterStringForPlayerAsync\",\"tags\":[\"deprecated\"],\"Class\":\"Chat\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"part\",\"Type\":\"Instance\"},{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"color\",\"Type\":\"ChatColor\"}],\"Name\":\"Chatted\",\"tags\":[],\"Class\":\"Chat\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ClickDetector\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"CursorIcon\",\"tags\":[],\"Class\":\"ClickDetector\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxActivationDistance\",\"tags\":[],\"Class\":\"ClickDetector\"},{\"Arguments\":[{\"Name\":\"playerWhoClicked\",\"Type\":\"Instance\"}],\"Name\":\"MouseClick\",\"tags\":[],\"Class\":\"ClickDetector\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"playerWhoHovered\",\"Type\":\"Instance\"}],\"Name\":\"MouseHoverEnter\",\"tags\":[],\"Class\":\"ClickDetector\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"playerWhoHovered\",\"Type\":\"Instance\"}],\"Name\":\"MouseHoverLeave\",\"tags\":[],\"Class\":\"ClickDetector\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"playerWhoClicked\",\"Type\":\"Instance\"}],\"Name\":\"RightMouseClick\",\"tags\":[],\"Class\":\"ClickDetector\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"playerWhoClicked\",\"Type\":\"Instance\"}],\"Name\":\"mouseClick\",\"tags\":[\"deprecated\"],\"Class\":\"ClickDetector\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ClusterPacketCache\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CollectionService\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"AddTag\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"class\",\"Default\":null}],\"Name\":\"GetCollection\",\"tags\":[\"deprecated\"],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"EventInstance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"GetInstanceAddedSignal\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"EventInstance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"GetInstanceRemovedSignal\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"GetTagged\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null}],\"Name\":\"GetTags\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"HasTag\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"RemoveTag\",\"tags\":[],\"Class\":\"CollectionService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"instance\",\"Type\":\"Instance\"}],\"Name\":\"ItemAdded\",\"tags\":[\"deprecated\"],\"Class\":\"CollectionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"instance\",\"Type\":\"Instance\"}],\"Name\":\"ItemRemoved\",\"tags\":[\"deprecated\"],\"Class\":\"CollectionService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Configuration\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Constraint\",\"tags\":[]},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment0\",\"tags\":[],\"Class\":\"Constraint\"},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment1\",\"tags\":[],\"Class\":\"Constraint\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Constraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Constraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"Constraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"AlignOrientation\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxAngularVelocity\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxTorque\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrimaryAxisOnly\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ReactionTorqueEnabled\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Responsiveness\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RigidityEnabled\",\"tags\":[],\"Class\":\"AlignOrientation\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"AlignPosition\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ApplyAtCenterOfMass\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxForce\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxVelocity\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ReactionForceEnabled\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Responsiveness\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RigidityEnabled\",\"tags\":[],\"Class\":\"AlignPosition\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"BallSocketConstraint\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LimitsEnabled\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Restitution\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TwistLimitsEnabled\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TwistLowerAngle\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TwistUpperAngle\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"UpperAngle\",\"tags\":[],\"Class\":\"BallSocketConstraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"HingeConstraint\",\"tags\":[]},{\"ValueType\":\"ActuatorType\",\"type\":\"Property\",\"Name\":\"ActuatorType\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AngularSpeed\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AngularVelocity\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentAngle\",\"tags\":[\"readonly\"],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LimitsEnabled\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LowerAngle\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxAcceleration\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxTorque\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Restitution\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ServoMaxTorque\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TargetAngle\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"UpperAngle\",\"tags\":[],\"Class\":\"HingeConstraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"LineForce\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ApplyAtCenterOfMass\",\"tags\":[],\"Class\":\"LineForce\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"InverseSquareLaw\",\"tags\":[],\"Class\":\"LineForce\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Magnitude\",\"tags\":[],\"Class\":\"LineForce\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxForce\",\"tags\":[],\"Class\":\"LineForce\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ReactionForceEnabled\",\"tags\":[],\"Class\":\"LineForce\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"RodConstraint\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentDistance\",\"tags\":[\"readonly\"],\"Class\":\"RodConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Length\",\"tags\":[],\"Class\":\"RodConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Thickness\",\"tags\":[],\"Class\":\"RodConstraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"RopeConstraint\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentDistance\",\"tags\":[\"readonly\"],\"Class\":\"RopeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Length\",\"tags\":[],\"Class\":\"RopeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Restitution\",\"tags\":[],\"Class\":\"RopeConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Thickness\",\"tags\":[],\"Class\":\"RopeConstraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"SlidingBallConstraint\",\"tags\":[]},{\"ValueType\":\"ActuatorType\",\"type\":\"Property\",\"Name\":\"ActuatorType\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentPosition\",\"tags\":[\"readonly\"],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LimitsEnabled\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LowerLimit\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxAcceleration\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxForce\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Restitution\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ServoMaxForce\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Speed\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TargetPosition\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"UpperLimit\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Velocity\",\"tags\":[],\"Class\":\"SlidingBallConstraint\"},{\"Superclass\":\"SlidingBallConstraint\",\"type\":\"Class\",\"Name\":\"CylindricalConstraint\",\"tags\":[]},{\"ValueType\":\"ActuatorType\",\"type\":\"Property\",\"Name\":\"AngularActuatorType\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AngularLimitsEnabled\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AngularRestitution\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AngularSpeed\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AngularVelocity\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentAngle\",\"tags\":[\"readonly\"],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"InclinationAngle\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LowerAngle\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxAngularAcceleration\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MotorMaxTorque\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RotationAxisVisible\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ServoMaxTorque\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TargetAngle\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"UpperAngle\",\"tags\":[],\"Class\":\"CylindricalConstraint\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WorldRotationAxis\",\"tags\":[\"readonly\"],\"Class\":\"CylindricalConstraint\"},{\"Superclass\":\"SlidingBallConstraint\",\"type\":\"Class\",\"Name\":\"PrismaticConstraint\",\"tags\":[]},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"SpringConstraint\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Coils\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentLength\",\"tags\":[\"readonly\"],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Damping\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FreeLength\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LimitsEnabled\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxForce\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxLength\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MinLength\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Stiffness\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Thickness\",\"tags\":[],\"Class\":\"SpringConstraint\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"Torque\",\"tags\":[]},{\"ValueType\":\"ActuatorRelativeTo\",\"type\":\"Property\",\"Name\":\"RelativeTo\",\"tags\":[],\"Class\":\"Torque\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Torque\",\"tags\":[],\"Class\":\"Torque\"},{\"Superclass\":\"Constraint\",\"type\":\"Class\",\"Name\":\"VectorForce\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ApplyAtCenterOfMass\",\"tags\":[],\"Class\":\"VectorForce\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Force\",\"tags\":[],\"Class\":\"VectorForce\"},{\"ValueType\":\"ActuatorRelativeTo\",\"type\":\"Property\",\"Name\":\"RelativeTo\",\"tags\":[],\"Class\":\"VectorForce\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ContentProvider\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"BaseUrl\",\"tags\":[\"readonly\"],\"Class\":\"ContentProvider\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"RequestQueueSize\",\"tags\":[\"readonly\"],\"Class\":\"ContentProvider\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Content\",\"Name\":\"contentId\",\"Default\":null}],\"Name\":\"Preload\",\"tags\":[\"deprecated\"],\"Class\":\"ContentProvider\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null}],\"Name\":\"SetBaseUrl\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"ContentProvider\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Array\",\"Name\":\"contentIdList\",\"Default\":null}],\"Name\":\"PreloadAsync\",\"tags\":[],\"Class\":\"ContentProvider\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ContextActionService\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"functionToBind\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"createTouchButton\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"inputTypes\",\"Default\":null}],\"Name\":\"BindAction\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"functionToBind\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"createTouchButton\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"priorityLevel\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"inputTypes\",\"Default\":null}],\"Name\":\"BindActionAtPriority\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"functionToBind\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"createTouchButton\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"inputTypes\",\"Default\":null}],\"Name\":\"BindActionToInputTypes\",\"tags\":[\"deprecated\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"userInputTypeForActivation\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"keyCodeForActivation\",\"Default\":\"Unknown\"}],\"Name\":\"BindActivate\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"functionToBind\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"createTouchButton\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"inputTypes\",\"Default\":null}],\"Name\":\"BindCoreAction\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"functionToBind\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"createTouchButton\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"priorityLevel\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"inputTypes\",\"Default\":null}],\"Name\":\"BindCoreActionAtPriority\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"UserInputState\",\"Name\":\"state\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"inputObject\",\"Default\":null}],\"Name\":\"CallFunction\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"actionButton\",\"Default\":null}],\"Name\":\"FireActionButtonFoundSignal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetAllBoundActionInfo\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetAllBoundCoreActionInfo\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null}],\"Name\":\"GetBoundActionInfo\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null}],\"Name\":\"GetBoundCoreActionInfo\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetCurrentLocalToolIcon\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null}],\"Name\":\"SetDescription\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"image\",\"Default\":null}],\"Name\":\"SetImage\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"UDim2\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"SetPosition\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"title\",\"Default\":null}],\"Name\":\"SetTitle\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null}],\"Name\":\"UnbindAction\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"userInputTypeForActivation\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"keyCodeForActivation\",\"Default\":\"Unknown\"}],\"Name\":\"UnbindActivate\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"UnbindAllActions\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null}],\"Name\":\"UnbindCoreAction\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionName\",\"Default\":null}],\"Name\":\"GetButton\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"actionAdded\",\"Type\":\"string\"},{\"Name\":\"createTouchButton\",\"Type\":\"bool\"},{\"Name\":\"functionInfoTable\",\"Type\":\"Dictionary\"},{\"Name\":\"isCore\",\"Type\":\"bool\"}],\"Name\":\"BoundActionAdded\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"actionChanged\",\"Type\":\"string\"},{\"Name\":\"changeName\",\"Type\":\"string\"},{\"Name\":\"changeTable\",\"Type\":\"Dictionary\"}],\"Name\":\"BoundActionChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"actionRemoved\",\"Type\":\"string\"},{\"Name\":\"functionInfoTable\",\"Type\":\"Dictionary\"},{\"Name\":\"isCore\",\"Type\":\"bool\"}],\"Name\":\"BoundActionRemoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"actionName\",\"Type\":\"string\"}],\"Name\":\"GetActionButtonEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"toolEquipped\",\"Type\":\"Instance\"}],\"Name\":\"LocalToolEquipped\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"toolUnequipped\",\"Type\":\"Instance\"}],\"Name\":\"LocalToolUnequipped\",\"tags\":[],\"Class\":\"ContextActionService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Controller\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Button\",\"Name\":\"button\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"caption\",\"Default\":null}],\"Name\":\"BindButton\",\"tags\":[],\"Class\":\"Controller\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Button\",\"Name\":\"button\",\"Default\":null}],\"Name\":\"GetButton\",\"tags\":[],\"Class\":\"Controller\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Button\",\"Name\":\"button\",\"Default\":null}],\"Name\":\"UnbindButton\",\"tags\":[],\"Class\":\"Controller\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Button\",\"Name\":\"button\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"caption\",\"Default\":null}],\"Name\":\"bindButton\",\"tags\":[\"deprecated\"],\"Class\":\"Controller\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Button\",\"Name\":\"button\",\"Default\":null}],\"Name\":\"getButton\",\"tags\":[\"deprecated\"],\"Class\":\"Controller\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"button\",\"Type\":\"Button\"}],\"Name\":\"ButtonChanged\",\"tags\":[],\"Class\":\"Controller\",\"type\":\"Event\"},{\"Superclass\":\"Controller\",\"type\":\"Class\",\"Name\":\"HumanoidController\",\"tags\":[]},{\"Superclass\":\"Controller\",\"type\":\"Class\",\"Name\":\"SkateboardController\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Steer\",\"tags\":[\"readonly\"],\"Class\":\"SkateboardController\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Throttle\",\"tags\":[\"readonly\"],\"Class\":\"SkateboardController\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"string\"}],\"Name\":\"AxisChanged\",\"tags\":[],\"Class\":\"SkateboardController\",\"type\":\"Event\"},{\"Superclass\":\"Controller\",\"type\":\"Class\",\"Name\":\"VehicleController\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ControllerService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CookiesService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CorePackages\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CustomEvent\",\"tags\":[\"deprecated\"]},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetAttachedReceivers\",\"tags\":[],\"Class\":\"CustomEvent\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"newValue\",\"Default\":null}],\"Name\":\"SetValue\",\"tags\":[],\"Class\":\"CustomEvent\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"receiver\",\"Type\":\"Instance\"}],\"Name\":\"ReceiverConnected\",\"tags\":[],\"Class\":\"CustomEvent\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"receiver\",\"Type\":\"Instance\"}],\"Name\":\"ReceiverDisconnected\",\"tags\":[],\"Class\":\"CustomEvent\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"CustomEventReceiver\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Source\",\"tags\":[],\"Class\":\"CustomEventReceiver\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetCurrentValue\",\"tags\":[],\"Class\":\"CustomEventReceiver\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"event\",\"Type\":\"Instance\"}],\"Name\":\"EventConnected\",\"tags\":[],\"Class\":\"CustomEventReceiver\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"event\",\"Type\":\"Instance\"}],\"Name\":\"EventDisconnected\",\"tags\":[],\"Class\":\"CustomEventReceiver\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"newValue\",\"Type\":\"float\"}],\"Name\":\"SourceValueChanged\",\"tags\":[],\"Class\":\"CustomEventReceiver\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DataModelMesh\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Offset\",\"tags\":[],\"Class\":\"DataModelMesh\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Scale\",\"tags\":[],\"Class\":\"DataModelMesh\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"VertexColor\",\"tags\":[],\"Class\":\"DataModelMesh\"},{\"Superclass\":\"DataModelMesh\",\"type\":\"Class\",\"Name\":\"BevelMesh\",\"tags\":[\"deprecated\",\"notbrowsable\"]},{\"Superclass\":\"BevelMesh\",\"type\":\"Class\",\"Name\":\"BlockMesh\",\"tags\":[]},{\"Superclass\":\"BevelMesh\",\"type\":\"Class\",\"Name\":\"CylinderMesh\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"DataModelMesh\",\"type\":\"Class\",\"Name\":\"FileMesh\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"MeshId\",\"tags\":[],\"Class\":\"FileMesh\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"TextureId\",\"tags\":[],\"Class\":\"FileMesh\"},{\"Superclass\":\"FileMesh\",\"type\":\"Class\",\"Name\":\"SpecialMesh\",\"tags\":[]},{\"ValueType\":\"MeshType\",\"type\":\"Property\",\"Name\":\"MeshType\",\"tags\":[],\"Class\":\"SpecialMesh\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DataStoreService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutomaticRetry\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"DataStoreService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LegacyNamingScheme\",\"tags\":[\"LocalUserSecurity\",\"deprecated\"],\"Class\":\"DataStoreService\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"scope\",\"Default\":\"global\"}],\"Name\":\"GetDataStore\",\"tags\":[],\"Class\":\"DataStoreService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetGlobalDataStore\",\"tags\":[],\"Class\":\"DataStoreService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"scope\",\"Default\":\"global\"}],\"Name\":\"GetOrderedDataStore\",\"tags\":[],\"Class\":\"DataStoreService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"DataStoreRequestType\",\"Name\":\"requestType\",\"Default\":null}],\"Name\":\"GetRequestBudgetForRequestType\",\"tags\":[],\"Class\":\"DataStoreService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Debris\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MaxItems\",\"tags\":[\"deprecated\"],\"Class\":\"Debris\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"item\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"lifetime\",\"Default\":\"10\"}],\"Name\":\"AddItem\",\"tags\":[],\"Class\":\"Debris\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetLegacyMaxItems\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Debris\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"item\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"lifetime\",\"Default\":\"10\"}],\"Name\":\"addItem\",\"tags\":[\"deprecated\"],\"Class\":\"Debris\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DebugSettings\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DataModel\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"ErrorReporting\",\"type\":\"Property\",\"Name\":\"ErrorReporting\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"GfxCard\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"InstanceCount\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsFmodProfilingEnabled\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsScriptStackTracingEnabled\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"JobCount\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"LuaRamLimit\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"OsIs64Bit\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"OsPlatform\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"OsPlatformId\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"OsVer\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PlayerCount\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ReportSoundWarnings\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"RobloxProductName\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"RobloxVersion\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"SIMD\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"SystemProductName\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"ValueType\":\"TickCountSampleMethod\",\"type\":\"Property\",\"Name\":\"TickCountPreciseOverride\",\"tags\":[],\"Class\":\"DebugSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"VideoMemory\",\"tags\":[\"readonly\"],\"Class\":\"DebugSettings\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DebuggerBreakpoint\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Condition\",\"tags\":[],\"Class\":\"DebuggerBreakpoint\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsEnabled\",\"tags\":[],\"Class\":\"DebuggerBreakpoint\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Line\",\"tags\":[\"readonly\"],\"Class\":\"DebuggerBreakpoint\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DebuggerManager\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"DebuggingEnabled\",\"tags\":[\"readonly\"],\"Class\":\"DebuggerManager\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"script\",\"Default\":null}],\"Name\":\"AddDebugger\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"EnableDebugging\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetDebuggers\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Resume\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepIn\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepOut\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepOver\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"debugger\",\"Type\":\"Instance\"}],\"Name\":\"DebuggerAdded\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"debugger\",\"Type\":\"Instance\"}],\"Name\":\"DebuggerRemoved\",\"tags\":[],\"Class\":\"DebuggerManager\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DebuggerWatch\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Expression\",\"tags\":[],\"Class\":\"DebuggerWatch\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"CheckSyntax\",\"tags\":[],\"Class\":\"DebuggerWatch\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Dialog\",\"tags\":[]},{\"ValueType\":\"DialogBehaviorType\",\"type\":\"Property\",\"Name\":\"BehaviorType\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ConversationDistance\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GoodbyeChoiceActive\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"GoodbyeDialog\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"InUse\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"InitialPrompt\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"DialogPurpose\",\"type\":\"Property\",\"Name\":\"Purpose\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"DialogTone\",\"type\":\"Property\",\"Name\":\"Tone\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TriggerDistance\",\"tags\":[],\"Class\":\"Dialog\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"TriggerOffset\",\"tags\":[],\"Class\":\"Dialog\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetCurrentPlayers\",\"tags\":[],\"Class\":\"Dialog\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"isUsing\",\"Default\":null}],\"Name\":\"SetPlayerIsUsing\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Dialog\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"dialogChoice\",\"Default\":null}],\"Name\":\"SignalDialogChoiceSelected\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Dialog\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"dialogChoice\",\"Type\":\"Instance\"}],\"Name\":\"DialogChoiceSelected\",\"tags\":[],\"Class\":\"Dialog\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"DialogChoice\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GoodbyeChoiceActive\",\"tags\":[],\"Class\":\"DialogChoice\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"GoodbyeDialog\",\"tags\":[],\"Class\":\"DialogChoice\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ResponseDialog\",\"tags\":[],\"Class\":\"DialogChoice\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"UserDialog\",\"tags\":[],\"Class\":\"DialogChoice\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Dragger\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Axis\",\"Name\":\"axis\",\"Default\":\"X\"}],\"Name\":\"AxisRotate\",\"tags\":[],\"Class\":\"Dragger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"mousePart\",\"Default\":null},{\"Type\":\"Vector3\",\"Name\":\"pointOnMousePart\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"parts\",\"Default\":null}],\"Name\":\"MouseDown\",\"tags\":[],\"Class\":\"Dragger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Ray\",\"Name\":\"mouseRay\",\"Default\":null}],\"Name\":\"MouseMove\",\"tags\":[],\"Class\":\"Dragger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"MouseUp\",\"tags\":[],\"Class\":\"Dragger\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Explosion\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BlastPressure\",\"tags\":[],\"Class\":\"Explosion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BlastRadius\",\"tags\":[],\"Class\":\"Explosion\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DestroyJointRadiusPercent\",\"tags\":[],\"Class\":\"Explosion\"},{\"ValueType\":\"ExplosionType\",\"type\":\"Property\",\"Name\":\"ExplosionType\",\"tags\":[],\"Class\":\"Explosion\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"Explosion\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"Explosion\"},{\"Arguments\":[{\"Name\":\"part\",\"Type\":\"Instance\"},{\"Name\":\"distance\",\"Type\":\"float\"}],\"Name\":\"Hit\",\"tags\":[],\"Class\":\"Explosion\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"FaceInstance\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"Face\",\"tags\":[],\"Class\":\"FaceInstance\"},{\"Superclass\":\"FaceInstance\",\"type\":\"Class\",\"Name\":\"Decal\",\"tags\":[]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color3\",\"tags\":[],\"Class\":\"Decal\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LocalTransparencyModifier\",\"tags\":[\"hidden\"],\"Class\":\"Decal\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Shiny\",\"tags\":[\"deprecated\"],\"Class\":\"Decal\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Specular\",\"tags\":[\"deprecated\"],\"Class\":\"Decal\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Texture\",\"tags\":[],\"Class\":\"Decal\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"Decal\"},{\"Superclass\":\"Decal\",\"type\":\"Class\",\"Name\":\"Texture\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"StudsPerTileU\",\"tags\":[],\"Class\":\"Texture\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"StudsPerTileV\",\"tags\":[],\"Class\":\"Texture\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Feature\",\"tags\":[]},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"FaceId\",\"tags\":[],\"Class\":\"Feature\"},{\"ValueType\":\"InOut\",\"type\":\"Property\",\"Name\":\"InOut\",\"tags\":[],\"Class\":\"Feature\"},{\"ValueType\":\"LeftRight\",\"type\":\"Property\",\"Name\":\"LeftRight\",\"tags\":[],\"Class\":\"Feature\"},{\"ValueType\":\"TopBottom\",\"type\":\"Property\",\"Name\":\"TopBottom\",\"tags\":[],\"Class\":\"Feature\"},{\"Superclass\":\"Feature\",\"type\":\"Class\",\"Name\":\"Hole\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"Feature\",\"type\":\"Class\",\"Name\":\"MotorFeature\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Fire\",\"tags\":[]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Fire\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Fire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Heat\",\"tags\":[],\"Class\":\"Fire\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"SecondaryColor\",\"tags\":[],\"Class\":\"Fire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"Fire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"size\",\"tags\":[\"deprecated\"],\"Class\":\"Fire\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"FlagStandService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"FlyweightService\",\"tags\":[]},{\"Superclass\":\"FlyweightService\",\"type\":\"Class\",\"Name\":\"CSGDictionaryService\",\"tags\":[]},{\"Superclass\":\"FlyweightService\",\"type\":\"Class\",\"Name\":\"NonReplicatedCSGDictionaryService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Folder\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ForceField\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"ForceField\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"FriendService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetPlatformFriends\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"FriendService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"friendData\",\"Type\":\"Array\"}],\"Name\":\"FriendsUpdated\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"FriendService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"FunctionalTest\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Description\",\"tags\":[],\"Class\":\"FunctionalTest\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Error\",\"tags\":[],\"Class\":\"FunctionalTest\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Failed\",\"tags\":[],\"Class\":\"FunctionalTest\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Pass\",\"tags\":[],\"Class\":\"FunctionalTest\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Passed\",\"tags\":[],\"Class\":\"FunctionalTest\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Warn\",\"tags\":[],\"Class\":\"FunctionalTest\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GamePassService\",\"tags\":[]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"gamePassId\",\"Default\":null}],\"Name\":\"PlayerHasPass\",\"tags\":[],\"Class\":\"GamePassService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GameSettings\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"AdditionalCoreIncludeDirs\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BubbleChatLifetime\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"BubbleChatMaxBubbles\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ChatHistory\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ChatScrollLength\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CollisionSoundEnabled\",\"tags\":[\"deprecated\"],\"Class\":\"GameSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CollisionSoundVolume\",\"tags\":[\"deprecated\"],\"Class\":\"GameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HardwareMouse\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MaxCollisionSounds\",\"tags\":[\"deprecated\"],\"Class\":\"GameSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"OverrideStarterScript\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ReportAbuseChatHistory\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"SoftwareSound\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"VideoCaptureEnabled\",\"tags\":[],\"Class\":\"GameSettings\"},{\"ValueType\":\"VideoQualitySettings\",\"type\":\"Property\",\"Name\":\"VideoQuality\",\"tags\":[],\"Class\":\"GameSettings\"},{\"Arguments\":[{\"Name\":\"recording\",\"Type\":\"bool\"}],\"Name\":\"VideoRecordingChangeRequest\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GameSettings\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GamepadService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Geometry\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GlobalDataStore\",\"tags\":[]},{\"ReturnType\":\"Connection\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"callback\",\"Default\":null}],\"Name\":\"OnUpdate\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"GetAsync\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"delta\",\"Default\":\"1\"}],\"Name\":\"IncrementAsync\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"RemoveAsync\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetAsync\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"transformFunction\",\"Default\":null}],\"Name\":\"UpdateAsync\",\"tags\":[],\"Class\":\"GlobalDataStore\",\"type\":\"YieldFunction\"},{\"Superclass\":\"GlobalDataStore\",\"type\":\"Class\",\"Name\":\"OrderedDataStore\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"ascending\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"pagesize\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"minValue\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"maxValue\",\"Default\":null}],\"Name\":\"GetSortedAsync\",\"tags\":[],\"Class\":\"OrderedDataStore\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GoogleAnalyticsConfiguration\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GroupService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"GetAlliesAsync\",\"tags\":[],\"Class\":\"GroupService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"GetEnemiesAsync\",\"tags\":[],\"Class\":\"GroupService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"GetGroupInfoAsync\",\"tags\":[],\"Class\":\"GroupService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetGroupsAsync\",\"tags\":[],\"Class\":\"GroupService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GuiBase\",\"tags\":[]},{\"Superclass\":\"GuiBase\",\"type\":\"Class\",\"Name\":\"GuiBase2d\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"AbsolutePosition\",\"tags\":[\"readonly\"],\"Class\":\"GuiBase2d\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AbsoluteRotation\",\"tags\":[\"readonly\"],\"Class\":\"GuiBase2d\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"AbsoluteSize\",\"tags\":[\"readonly\"],\"Class\":\"GuiBase2d\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoLocalize\",\"tags\":[],\"Class\":\"GuiBase2d\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Localize\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"GuiBase2d\"},{\"ValueType\":\"Class:LocalizationTable\",\"type\":\"Property\",\"Name\":\"RootLocalizationTable\",\"tags\":[],\"Class\":\"GuiBase2d\"},{\"Superclass\":\"GuiBase2d\",\"type\":\"Class\",\"Name\":\"GuiObject\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Active\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"AnchorPoint\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"BackgroundColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"GuiObject\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"BackgroundColor3\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BackgroundTransparency\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"BorderColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"GuiObject\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"BorderColor3\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"BorderSizePixel\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClipsDescendants\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Draggable\",\"tags\":[\"deprecated\"],\"Class\":\"GuiObject\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"LayoutOrder\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"NextSelectionDown\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"NextSelectionLeft\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"NextSelectionRight\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"NextSelectionUp\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Rotation\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Selectable\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"SelectionImageObject\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"SizeConstraint\",\"type\":\"Property\",\"Name\":\"SizeConstraint\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[\"hidden\"],\"Class\":\"GuiObject\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ZIndex\",\"tags\":[],\"Class\":\"GuiObject\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UDim2\",\"Name\":\"endPosition\",\"Default\":null},{\"Type\":\"EasingDirection\",\"Name\":\"easingDirection\",\"Default\":\"Out\"},{\"Type\":\"EasingStyle\",\"Name\":\"easingStyle\",\"Default\":\"Quad\"},{\"Type\":\"float\",\"Name\":\"time\",\"Default\":\"1\"},{\"Type\":\"bool\",\"Name\":\"override\",\"Default\":\"false\"},{\"Type\":\"Function\",\"Name\":\"callback\",\"Default\":\"nil\"}],\"Name\":\"TweenPosition\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UDim2\",\"Name\":\"endSize\",\"Default\":null},{\"Type\":\"EasingDirection\",\"Name\":\"easingDirection\",\"Default\":\"Out\"},{\"Type\":\"EasingStyle\",\"Name\":\"easingStyle\",\"Default\":\"Quad\"},{\"Type\":\"float\",\"Name\":\"time\",\"Default\":\"1\"},{\"Type\":\"bool\",\"Name\":\"override\",\"Default\":\"false\"},{\"Type\":\"Function\",\"Name\":\"callback\",\"Default\":\"nil\"}],\"Name\":\"TweenSize\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UDim2\",\"Name\":\"endSize\",\"Default\":null},{\"Type\":\"UDim2\",\"Name\":\"endPosition\",\"Default\":null},{\"Type\":\"EasingDirection\",\"Name\":\"easingDirection\",\"Default\":\"Out\"},{\"Type\":\"EasingStyle\",\"Name\":\"easingStyle\",\"Default\":\"Quad\"},{\"Type\":\"float\",\"Name\":\"time\",\"Default\":\"1\"},{\"Type\":\"bool\",\"Name\":\"override\",\"Default\":\"false\"},{\"Type\":\"Function\",\"Name\":\"callback\",\"Default\":\"nil\"}],\"Name\":\"TweenSizeAndPosition\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"initialPosition\",\"Type\":\"UDim2\"}],\"Name\":\"DragBegin\",\"tags\":[\"deprecated\"],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"DragStopped\",\"tags\":[\"deprecated\"],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"}],\"Name\":\"InputBegan\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"}],\"Name\":\"InputChanged\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"}],\"Name\":\"InputEnded\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseEnter\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseLeave\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseMoved\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseWheelBackward\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseWheelForward\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"SelectionGained\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"SelectionLost\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"}],\"Name\":\"TouchLongPress\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"totalTranslation\",\"Type\":\"Vector2\"},{\"Name\":\"velocity\",\"Type\":\"Vector2\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"}],\"Name\":\"TouchPan\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"scale\",\"Type\":\"float\"},{\"Name\":\"velocity\",\"Type\":\"float\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"}],\"Name\":\"TouchPinch\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"rotation\",\"Type\":\"float\"},{\"Name\":\"velocity\",\"Type\":\"float\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"}],\"Name\":\"TouchRotate\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"swipeDirection\",\"Type\":\"SwipeDirection\"},{\"Name\":\"numberOfTouches\",\"Type\":\"int\"}],\"Name\":\"TouchSwipe\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"}],\"Name\":\"TouchTap\",\"tags\":[],\"Class\":\"GuiObject\",\"type\":\"Event\"},{\"Superclass\":\"GuiObject\",\"type\":\"Class\",\"Name\":\"Frame\",\"tags\":[]},{\"ValueType\":\"FrameStyle\",\"type\":\"Property\",\"Name\":\"Style\",\"tags\":[],\"Class\":\"Frame\"},{\"Superclass\":\"GuiObject\",\"type\":\"Class\",\"Name\":\"GuiButton\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoButtonColor\",\"tags\":[],\"Class\":\"GuiButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Modal\",\"tags\":[],\"Class\":\"GuiButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Selected\",\"tags\":[],\"Class\":\"GuiButton\"},{\"ValueType\":\"ButtonStyle\",\"type\":\"Property\",\"Name\":\"Style\",\"tags\":[],\"Class\":\"GuiButton\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"verb\",\"Default\":null}],\"Name\":\"SetVerb\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiButton\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"inputObject\",\"Type\":\"Instance\"}],\"Name\":\"Activated\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MouseButton1Click\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseButton1Down\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseButton1Up\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MouseButton2Click\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseButton2Down\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"x\",\"Type\":\"int\"},{\"Name\":\"y\",\"Type\":\"int\"}],\"Name\":\"MouseButton2Up\",\"tags\":[],\"Class\":\"GuiButton\",\"type\":\"Event\"},{\"Superclass\":\"GuiButton\",\"type\":\"Class\",\"Name\":\"ImageButton\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"HoverImage\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Image\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ImageColor3\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"ImageRectOffset\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"ImageRectSize\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ImageTransparency\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLoaded\",\"tags\":[\"readonly\"],\"Class\":\"ImageButton\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"PressedImage\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"ScaleType\",\"type\":\"Property\",\"Name\":\"ScaleType\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"Rect2D\",\"type\":\"Property\",\"Name\":\"SliceCenter\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SliceScale\",\"tags\":[],\"Class\":\"ImageButton\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"TileSize\",\"tags\":[],\"Class\":\"ImageButton\"},{\"Superclass\":\"GuiButton\",\"type\":\"Class\",\"Name\":\"TextButton\",\"tags\":[]},{\"ValueType\":\"Font\",\"type\":\"Property\",\"Name\":\"Font\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"FontSize\",\"type\":\"Property\",\"Name\":\"FontSize\",\"tags\":[\"deprecated\"],\"Class\":\"TextButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LineHeight\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"LocalizedText\",\"tags\":[\"hidden\",\"readonly\"],\"Class\":\"TextButton\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Text\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"TextBounds\",\"tags\":[\"readonly\"],\"Class\":\"TextButton\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TextColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"TextButton\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextColor3\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextFits\",\"tags\":[\"readonly\"],\"Class\":\"TextButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextScaled\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextSize\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextStrokeColor3\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextStrokeTransparency\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextTransparency\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"TextTruncate\",\"type\":\"Property\",\"Name\":\"TextTruncate\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrap\",\"tags\":[\"deprecated\"],\"Class\":\"TextButton\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrapped\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"TextXAlignment\",\"type\":\"Property\",\"Name\":\"TextXAlignment\",\"tags\":[],\"Class\":\"TextButton\"},{\"ValueType\":\"TextYAlignment\",\"type\":\"Property\",\"Name\":\"TextYAlignment\",\"tags\":[],\"Class\":\"TextButton\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"SetTextFromInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextButton\",\"type\":\"Function\"},{\"Superclass\":\"GuiObject\",\"type\":\"Class\",\"Name\":\"GuiLabel\",\"tags\":[]},{\"Superclass\":\"GuiLabel\",\"type\":\"Class\",\"Name\":\"ImageLabel\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Image\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ImageColor3\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"ImageRectOffset\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"ImageRectSize\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ImageTransparency\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLoaded\",\"tags\":[\"readonly\"],\"Class\":\"ImageLabel\"},{\"ValueType\":\"ScaleType\",\"type\":\"Property\",\"Name\":\"ScaleType\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"Rect2D\",\"type\":\"Property\",\"Name\":\"SliceCenter\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SliceScale\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"TileSize\",\"tags\":[],\"Class\":\"ImageLabel\"},{\"Superclass\":\"GuiLabel\",\"type\":\"Class\",\"Name\":\"TextLabel\",\"tags\":[]},{\"ValueType\":\"Font\",\"type\":\"Property\",\"Name\":\"Font\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"FontSize\",\"type\":\"Property\",\"Name\":\"FontSize\",\"tags\":[\"deprecated\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LineHeight\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"LocalizedText\",\"tags\":[\"hidden\",\"readonly\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Text\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"TextBounds\",\"tags\":[\"readonly\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TextColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextColor3\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextFits\",\"tags\":[\"readonly\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextScaled\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextSize\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextStrokeColor3\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextStrokeTransparency\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextTransparency\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"TextTruncate\",\"type\":\"Property\",\"Name\":\"TextTruncate\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrap\",\"tags\":[\"deprecated\"],\"Class\":\"TextLabel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrapped\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"TextXAlignment\",\"type\":\"Property\",\"Name\":\"TextXAlignment\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ValueType\":\"TextYAlignment\",\"type\":\"Property\",\"Name\":\"TextYAlignment\",\"tags\":[],\"Class\":\"TextLabel\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"SetTextFromInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextLabel\",\"type\":\"Function\"},{\"Superclass\":\"GuiObject\",\"type\":\"Class\",\"Name\":\"ScrollingFrame\",\"tags\":[]},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"AbsoluteWindowSize\",\"tags\":[\"readonly\"],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"BottomImage\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"CanvasPosition\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"CanvasSize\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"ElasticBehavior\",\"type\":\"Property\",\"Name\":\"ElasticBehavior\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"ScrollBarInset\",\"type\":\"Property\",\"Name\":\"HorizontalScrollBarInset\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"MidImage\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ScrollBarImageColor3\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ScrollBarImageTransparency\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ScrollBarThickness\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"ScrollingDirection\",\"type\":\"Property\",\"Name\":\"ScrollingDirection\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ScrollingEnabled\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"TopImage\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"ScrollBarInset\",\"type\":\"Property\",\"Name\":\"VerticalScrollBarInset\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ValueType\":\"VerticalScrollBarPosition\",\"type\":\"Property\",\"Name\":\"VerticalScrollBarPosition\",\"tags\":[],\"Class\":\"ScrollingFrame\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ScrollToTop\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ScrollingFrame\",\"type\":\"Function\"},{\"Superclass\":\"GuiObject\",\"type\":\"Class\",\"Name\":\"TextBox\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClearTextOnFocus\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"Font\",\"type\":\"Property\",\"Name\":\"Font\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"FontSize\",\"type\":\"Property\",\"Name\":\"FontSize\",\"tags\":[\"deprecated\"],\"Class\":\"TextBox\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LineHeight\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ManualFocusRelease\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"MultiLine\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"OverlayNativeInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextBox\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"PlaceholderColor3\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"PlaceholderText\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShowNativeInput\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Text\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"TextBounds\",\"tags\":[\"readonly\"],\"Class\":\"TextBox\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TextColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"TextBox\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextColor3\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextFits\",\"tags\":[\"readonly\"],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextScaled\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextSize\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TextStrokeColor3\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextStrokeTransparency\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextTransparency\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"TextTruncate\",\"type\":\"Property\",\"Name\":\"TextTruncate\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrap\",\"tags\":[\"deprecated\"],\"Class\":\"TextBox\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TextWrapped\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"TextXAlignment\",\"type\":\"Property\",\"Name\":\"TextXAlignment\",\"tags\":[],\"Class\":\"TextBox\"},{\"ValueType\":\"TextYAlignment\",\"type\":\"Property\",\"Name\":\"TextYAlignment\",\"tags\":[],\"Class\":\"TextBox\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"CaptureFocus\",\"tags\":[],\"Class\":\"TextBox\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsFocused\",\"tags\":[],\"Class\":\"TextBox\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"submitted\",\"Default\":\"false\"}],\"Name\":\"ReleaseFocus\",\"tags\":[],\"Class\":\"TextBox\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ResetKeyboardMode\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextBox\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"SetTextFromInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TextBox\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"enterPressed\",\"Type\":\"bool\"},{\"Name\":\"inputThatCausedFocusLoss\",\"Type\":\"Instance\"}],\"Name\":\"FocusLost\",\"tags\":[],\"Class\":\"TextBox\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Focused\",\"tags\":[],\"Class\":\"TextBox\",\"type\":\"Event\"},{\"Superclass\":\"GuiBase2d\",\"type\":\"Class\",\"Name\":\"LayerCollector\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"LayerCollector\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ResetOnSpawn\",\"tags\":[],\"Class\":\"LayerCollector\"},{\"ValueType\":\"ZIndexBehavior\",\"type\":\"Property\",\"Name\":\"ZIndexBehavior\",\"tags\":[],\"Class\":\"LayerCollector\"},{\"Superclass\":\"LayerCollector\",\"type\":\"Class\",\"Name\":\"BillboardGui\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Active\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Adornee\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AlwaysOnTop\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClipsDescendants\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"ExtentsOffset\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"ExtentsOffsetWorldSpace\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightInfluence\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxDistance\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"PlayerToHideFrom\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"SizeOffset\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"StudsOffset\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"StudsOffsetWorldSpace\",\"tags\":[],\"Class\":\"BillboardGui\"},{\"Superclass\":\"LayerCollector\",\"type\":\"Class\",\"Name\":\"PluginGui\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Title\",\"tags\":[],\"Class\":\"PluginGui\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Function\",\"Name\":\"function\",\"Default\":\"nil\"}],\"Name\":\"BindToClose\",\"tags\":[],\"Class\":\"PluginGui\",\"type\":\"Function\"},{\"ReturnType\":\"Vector2\",\"Arguments\":[],\"Name\":\"GetRelativeMousePosition\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"pluginDragEvent\",\"Type\":\"Instance\"}],\"Name\":\"PluginDragDropped\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"pluginDragEvent\",\"Type\":\"Instance\"}],\"Name\":\"PluginDragEntered\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"pluginDragEvent\",\"Type\":\"Instance\"}],\"Name\":\"PluginDragLeft\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"pluginDragEvent\",\"Type\":\"Instance\"}],\"Name\":\"PluginDragMoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WindowFocusReleased\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WindowFocused\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginGui\",\"type\":\"Event\"},{\"Superclass\":\"PluginGui\",\"type\":\"Class\",\"Name\":\"DockWidgetPluginGui\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HostWidgetWasRestored\",\"tags\":[\"readonly\"],\"Class\":\"DockWidgetPluginGui\"},{\"Superclass\":\"PluginGui\",\"type\":\"Class\",\"Name\":\"QWidgetPluginGui\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"LayerCollector\",\"type\":\"Class\",\"Name\":\"ScreenGui\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DisplayOrder\",\"tags\":[],\"Class\":\"ScreenGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IgnoreGuiInset\",\"tags\":[],\"Class\":\"ScreenGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"OnTopOfCoreBlur\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"ScreenGui\"},{\"Superclass\":\"ScreenGui\",\"type\":\"Class\",\"Name\":\"GuiMain\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"LayerCollector\",\"type\":\"Class\",\"Name\":\"SurfaceGui\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Active\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Adornee\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AlwaysOnTop\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"CanvasSize\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClipsDescendants\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"Face\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightInfluence\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ToolPunchThroughDistance\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ZOffset\",\"tags\":[],\"Class\":\"SurfaceGui\"},{\"Superclass\":\"GuiBase\",\"type\":\"Class\",\"Name\":\"GuiBase3d\",\"tags\":[]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"GuiBase3d\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color3\",\"tags\":[],\"Class\":\"GuiBase3d\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"GuiBase3d\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Visible\",\"tags\":[],\"Class\":\"GuiBase3d\"},{\"Superclass\":\"GuiBase3d\",\"type\":\"Class\",\"Name\":\"FloorWire\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CycleOffset\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"From\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"StudsBetweenTextures\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Texture\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"TextureSize\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"To\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Velocity\",\"tags\":[],\"Class\":\"FloorWire\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WireRadius\",\"tags\":[],\"Class\":\"FloorWire\"},{\"Superclass\":\"GuiBase3d\",\"type\":\"Class\",\"Name\":\"PVAdornment\",\"tags\":[]},{\"ValueType\":\"Class:PVInstance\",\"type\":\"Property\",\"Name\":\"Adornee\",\"tags\":[],\"Class\":\"PVAdornment\"},{\"Superclass\":\"PVAdornment\",\"type\":\"Class\",\"Name\":\"HandleAdornment\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AlwaysOnTop\",\"tags\":[],\"Class\":\"HandleAdornment\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"HandleAdornment\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"SizeRelativeOffset\",\"tags\":[],\"Class\":\"HandleAdornment\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ZIndex\",\"tags\":[],\"Class\":\"HandleAdornment\"},{\"Arguments\":[],\"Name\":\"MouseButton1Down\",\"tags\":[],\"Class\":\"HandleAdornment\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MouseButton1Up\",\"tags\":[],\"Class\":\"HandleAdornment\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MouseEnter\",\"tags\":[],\"Class\":\"HandleAdornment\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MouseLeave\",\"tags\":[],\"Class\":\"HandleAdornment\",\"type\":\"Event\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"BoxHandleAdornment\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"BoxHandleAdornment\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"ConeHandleAdornment\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Height\",\"tags\":[],\"Class\":\"ConeHandleAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"ConeHandleAdornment\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"CylinderHandleAdornment\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Height\",\"tags\":[],\"Class\":\"CylinderHandleAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"CylinderHandleAdornment\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"ImageHandleAdornment\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Image\",\"tags\":[],\"Class\":\"ImageHandleAdornment\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"ImageHandleAdornment\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"LineHandleAdornment\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Length\",\"tags\":[],\"Class\":\"LineHandleAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Thickness\",\"tags\":[],\"Class\":\"LineHandleAdornment\"},{\"Superclass\":\"HandleAdornment\",\"type\":\"Class\",\"Name\":\"SphereHandleAdornment\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Radius\",\"tags\":[],\"Class\":\"SphereHandleAdornment\"},{\"Superclass\":\"PVAdornment\",\"type\":\"Class\",\"Name\":\"ParabolaAdornment\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"A\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"B\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"C\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Range\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Thickness\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"ignoreDescendentsTable\",\"Default\":null}],\"Name\":\"FindPartOnParabola\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ParabolaAdornment\",\"type\":\"Function\"},{\"Superclass\":\"PVAdornment\",\"type\":\"Class\",\"Name\":\"SelectionBox\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LineThickness\",\"tags\":[],\"Class\":\"SelectionBox\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"SurfaceColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"SelectionBox\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"SurfaceColor3\",\"tags\":[],\"Class\":\"SelectionBox\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SurfaceTransparency\",\"tags\":[],\"Class\":\"SelectionBox\"},{\"Superclass\":\"PVAdornment\",\"type\":\"Class\",\"Name\":\"SelectionSphere\",\"tags\":[]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"SurfaceColor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"SelectionSphere\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"SurfaceColor3\",\"tags\":[],\"Class\":\"SelectionSphere\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SurfaceTransparency\",\"tags\":[],\"Class\":\"SelectionSphere\"},{\"Superclass\":\"GuiBase3d\",\"type\":\"Class\",\"Name\":\"PartAdornment\",\"tags\":[]},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Adornee\",\"tags\":[],\"Class\":\"PartAdornment\"},{\"Superclass\":\"PartAdornment\",\"type\":\"Class\",\"Name\":\"HandlesBase\",\"tags\":[]},{\"Superclass\":\"HandlesBase\",\"type\":\"Class\",\"Name\":\"ArcHandles\",\"tags\":[]},{\"ValueType\":\"Axes\",\"type\":\"Property\",\"Name\":\"Axes\",\"tags\":[],\"Class\":\"ArcHandles\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"Axis\"}],\"Name\":\"MouseButton1Down\",\"tags\":[],\"Class\":\"ArcHandles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"Axis\"}],\"Name\":\"MouseButton1Up\",\"tags\":[],\"Class\":\"ArcHandles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"Axis\"},{\"Name\":\"relativeAngle\",\"Type\":\"float\"},{\"Name\":\"deltaRadius\",\"Type\":\"float\"}],\"Name\":\"MouseDrag\",\"tags\":[],\"Class\":\"ArcHandles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"Axis\"}],\"Name\":\"MouseEnter\",\"tags\":[],\"Class\":\"ArcHandles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"axis\",\"Type\":\"Axis\"}],\"Name\":\"MouseLeave\",\"tags\":[],\"Class\":\"ArcHandles\",\"type\":\"Event\"},{\"Superclass\":\"HandlesBase\",\"type\":\"Class\",\"Name\":\"Handles\",\"tags\":[]},{\"ValueType\":\"Faces\",\"type\":\"Property\",\"Name\":\"Faces\",\"tags\":[],\"Class\":\"Handles\"},{\"ValueType\":\"HandlesStyle\",\"type\":\"Property\",\"Name\":\"Style\",\"tags\":[],\"Class\":\"Handles\"},{\"Arguments\":[{\"Name\":\"face\",\"Type\":\"NormalId\"}],\"Name\":\"MouseButton1Down\",\"tags\":[],\"Class\":\"Handles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"face\",\"Type\":\"NormalId\"}],\"Name\":\"MouseButton1Up\",\"tags\":[],\"Class\":\"Handles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"face\",\"Type\":\"NormalId\"},{\"Name\":\"distance\",\"Type\":\"float\"}],\"Name\":\"MouseDrag\",\"tags\":[],\"Class\":\"Handles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"face\",\"Type\":\"NormalId\"}],\"Name\":\"MouseEnter\",\"tags\":[],\"Class\":\"Handles\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"face\",\"Type\":\"NormalId\"}],\"Name\":\"MouseLeave\",\"tags\":[],\"Class\":\"Handles\",\"type\":\"Event\"},{\"Superclass\":\"PartAdornment\",\"type\":\"Class\",\"Name\":\"SurfaceSelection\",\"tags\":[]},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"TargetSurface\",\"tags\":[],\"Class\":\"SurfaceSelection\"},{\"Superclass\":\"GuiBase3d\",\"type\":\"Class\",\"Name\":\"SelectionLasso\",\"tags\":[]},{\"ValueType\":\"Class:Humanoid\",\"type\":\"Property\",\"Name\":\"Humanoid\",\"tags\":[],\"Class\":\"SelectionLasso\"},{\"Superclass\":\"SelectionLasso\",\"type\":\"Class\",\"Name\":\"SelectionPartLasso\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Part\",\"tags\":[],\"Class\":\"SelectionPartLasso\"},{\"Superclass\":\"SelectionLasso\",\"type\":\"Class\",\"Name\":\"SelectionPointLasso\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Point\",\"tags\":[],\"Class\":\"SelectionPointLasso\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GuiItem\",\"tags\":[]},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"Backpack\",\"tags\":[]},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"BackpackItem\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"TextureId\",\"tags\":[],\"Class\":\"BackpackItem\"},{\"Superclass\":\"BackpackItem\",\"type\":\"Class\",\"Name\":\"HopperBin\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Active\",\"tags\":[],\"Class\":\"HopperBin\"},{\"ValueType\":\"BinType\",\"type\":\"Property\",\"Name\":\"BinType\",\"tags\":[],\"Class\":\"HopperBin\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Disable\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HopperBin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ToggleSelect\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HopperBin\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"Deselected\",\"tags\":[],\"Class\":\"HopperBin\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"mouse\",\"Type\":\"Instance\"}],\"Name\":\"Selected\",\"tags\":[],\"Class\":\"HopperBin\",\"type\":\"Event\"},{\"Superclass\":\"BackpackItem\",\"type\":\"Class\",\"Name\":\"Tool\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CanBeDropped\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Grip\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"GripForward\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"GripPos\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"GripRight\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"GripUp\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ManualActivationOnly\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RequiresHandle\",\"tags\":[],\"Class\":\"Tool\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ToolTip\",\"tags\":[],\"Class\":\"Tool\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Activate\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Deactivate\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"Activated\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Deactivated\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"mouse\",\"Type\":\"Instance\"}],\"Name\":\"Equipped\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Unequipped\",\"tags\":[],\"Class\":\"Tool\",\"type\":\"Event\"},{\"Superclass\":\"Tool\",\"type\":\"Class\",\"Name\":\"Flag\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TeamColor\",\"tags\":[],\"Class\":\"Flag\"},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"ButtonBindingWidget\",\"tags\":[]},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"GuiRoot\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"Hopper\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"GuiItem\",\"type\":\"Class\",\"Name\":\"StarterPack\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GuiService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoSelectGuiEnabled\",\"tags\":[],\"Class\":\"GuiService\"},{\"ValueType\":\"Class:Folder\",\"type\":\"Property\",\"Name\":\"CoreEffectFolder\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"GuiService\"},{\"ValueType\":\"Class:Folder\",\"type\":\"Property\",\"Name\":\"CoreGuiFolder\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"GuiService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CoreGuiNavigationEnabled\",\"tags\":[],\"Class\":\"GuiService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GuiNavigationEnabled\",\"tags\":[],\"Class\":\"GuiService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsModalDialog\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"GuiService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsWindows\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"GuiService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"MenuIsOpen\",\"tags\":[\"readonly\"],\"Class\":\"GuiService\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"SelectedCoreObject\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"SelectedObject\",\"tags\":[],\"Class\":\"GuiService\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"dialog\",\"Default\":null},{\"Type\":\"CenterDialogType\",\"Name\":\"centerDialogType\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"showFunction\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"hideFunction\",\"Default\":null}],\"Name\":\"AddCenterDialog\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"AddKey\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"selectionName\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"selectionParent\",\"Default\":null}],\"Name\":\"AddSelectionParent\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"selectionName\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"selections\",\"Default\":null}],\"Name\":\"AddSelectionTuple\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"SpecialKey\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"AddSpecialKey\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"data\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"notificationType\",\"Default\":null}],\"Name\":\"BroadcastNotification\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearError\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"input\",\"Default\":null}],\"Name\":\"CloseStatsBasedOnInputString\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetBrickCount\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"GetClosestDialogToPosition\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"ConnectionError\",\"Arguments\":[],\"Name\":\"GetErrorCode\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetErrorMessage\",\"tags\":[\"RobloxScriptSecurity\",\"deprecated\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"ConnectionError\",\"Arguments\":[],\"Name\":\"GetErrorType\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"GetGuiInset\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetNotificationTypeList\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetResolutionScale\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetSafeZoneOffsets\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetUiMessage\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsMemoryTrackerEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsTenFootInterface\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null}],\"Name\":\"OpenBrowserWindow\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"title\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null}],\"Name\":\"OpenNativeOverlay\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"dialog\",\"Default\":null}],\"Name\":\"RemoveCenterDialog\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"RemoveKey\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"selectionName\",\"Default\":null}],\"Name\":\"RemoveSelectionGroup\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"SpecialKey\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"RemoveSpecialKey\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x1\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y1\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"x2\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y2\",\"Default\":null}],\"Name\":\"SetGlobalGuiInset\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"open\",\"Default\":null}],\"Name\":\"SetMenuIsOpen\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"top\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"bottom\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"left\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"right\",\"Default\":null}],\"Name\":\"SetSafeZoneOffsets\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"UiMessageType\",\"Name\":\"msgType\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"uiMessage\",\"Default\":\"errorCode\"}],\"Name\":\"SetUiMessage\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"input\",\"Default\":null}],\"Name\":\"ShowStatsBasedOnInputString\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ToggleFullscreen\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Function\"},{\"ReturnType\":\"Vector2\",\"Arguments\":[],\"Name\":\"GetScreenResolution\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"YieldFunction\"},{\"Arguments\":[],\"Name\":\"BrowserWindowClosed\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"newErrorMessage\",\"Type\":\"string\"}],\"Name\":\"ErrorMessageChanged\",\"tags\":[\"RobloxScriptSecurity\",\"deprecated\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"key\",\"Type\":\"string\"},{\"Name\":\"modifiers\",\"Type\":\"string\"}],\"Name\":\"KeyPressed\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MenuClosed\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"MenuOpened\",\"tags\":[],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"SafeZoneOffsetsChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"ShowLeaveConfirmation\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"key\",\"Type\":\"SpecialKey\"},{\"Name\":\"modifiers\",\"Type\":\"string\"}],\"Name\":\"SpecialKeyPressed\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"msgType\",\"Type\":\"UiMessageType\"},{\"Name\":\"newUiMessage\",\"Type\":\"string\"}],\"Name\":\"UiMessageChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Event\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Name\":\"title\",\"Type\":\"string\"},{\"Name\":\"text\",\"Type\":\"string\"}],\"Name\":\"SendCoreUiNotification\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"GuiService\",\"type\":\"Callback\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"GuidRegistryService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"HapticService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"inputType\",\"Default\":null},{\"Type\":\"VibrationMotor\",\"Name\":\"vibrationMotor\",\"Default\":null}],\"Name\":\"GetMotor\",\"tags\":[],\"Class\":\"HapticService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"inputType\",\"Default\":null},{\"Type\":\"VibrationMotor\",\"Name\":\"vibrationMotor\",\"Default\":null}],\"Name\":\"IsMotorSupported\",\"tags\":[],\"Class\":\"HapticService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"inputType\",\"Default\":null}],\"Name\":\"IsVibrationSupported\",\"tags\":[],\"Class\":\"HapticService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"inputType\",\"Default\":null},{\"Type\":\"VibrationMotor\",\"Name\":\"vibrationMotor\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"vibrationValues\",\"Default\":null}],\"Name\":\"SetMotor\",\"tags\":[],\"Class\":\"HapticService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"HttpRbxApiService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"apiUrlPath\",\"Default\":null},{\"Type\":\"ThrottlingPriority\",\"Name\":\"priority\",\"Default\":\"Default\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"GetAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRbxApiService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"apiUrl\",\"Default\":null},{\"Type\":\"ThrottlingPriority\",\"Name\":\"priority\",\"Default\":\"Default\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"GetAsyncFullUrl\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRbxApiService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"apiUrlPath\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"data\",\"Default\":null},{\"Type\":\"ThrottlingPriority\",\"Name\":\"priority\",\"Default\":\"Default\"},{\"Type\":\"HttpContentType\",\"Name\":\"content_type\",\"Default\":\"ApplicationJson\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"PostAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRbxApiService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"apiUrl\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"data\",\"Default\":null},{\"Type\":\"ThrottlingPriority\",\"Name\":\"priority\",\"Default\":\"Default\"},{\"Type\":\"HttpContentType\",\"Name\":\"content_type\",\"Default\":\"ApplicationJson\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"PostAsyncFullUrl\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRbxApiService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"Dictionary\",\"Name\":\"requestOptions\",\"Default\":null},{\"Type\":\"ThrottlingPriority\",\"Name\":\"priority\",\"Default\":\"Default\"},{\"Type\":\"HttpContentType\",\"Name\":\"content_type\",\"Default\":\"ApplicationJson\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"RequestAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRbxApiService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"HttpRequest\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Cancel\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRequest\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Function\",\"Name\":\"callback\",\"Default\":null}],\"Name\":\"Start\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpRequest\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"HttpService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HttpEnabled\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"HttpService\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"wrapInCurlyBraces\",\"Default\":\"true\"}],\"Name\":\"GenerateGUID\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetHttpEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"input\",\"Default\":null}],\"Name\":\"JSONDecode\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"Variant\",\"Name\":\"input\",\"Default\":null}],\"Name\":\"JSONEncode\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Dictionary\",\"Name\":\"options\",\"Default\":null}],\"Name\":\"RequestInternal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetHttpEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"input\",\"Default\":null}],\"Name\":\"UrlEncode\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"nocache\",\"Default\":\"false\"},{\"Type\":\"Variant\",\"Name\":\"headers\",\"Default\":null}],\"Name\":\"GetAsync\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"data\",\"Default\":null},{\"Type\":\"HttpContentType\",\"Name\":\"content_type\",\"Default\":\"ApplicationJson\"},{\"Type\":\"bool\",\"Name\":\"compress\",\"Default\":\"false\"},{\"Type\":\"Variant\",\"Name\":\"headers\",\"Default\":null}],\"Name\":\"PostAsync\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"Dictionary\",\"Name\":\"requestOptions\",\"Default\":null}],\"Name\":\"RequestAsync\",\"tags\":[],\"Class\":\"HttpService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Humanoid\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoJumpEnabled\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoRotate\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutomaticScalingEnabled\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"CameraOffset\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"HumanoidDisplayDistanceType\",\"type\":\"Property\",\"Name\":\"DisplayDistanceType\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Material\",\"type\":\"Property\",\"Name\":\"FloorMaterial\",\"tags\":[\"readonly\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Health\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HealthDisplayDistance\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"HumanoidHealthDisplayType\",\"type\":\"Property\",\"Name\":\"HealthDisplayType\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HipHeight\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Jump\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"JumpPower\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"LeftLeg\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxHealth\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxSlopeAngle\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"MoveDirection\",\"tags\":[\"readonly\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"NameDisplayDistance\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"NameOcclusion\",\"type\":\"Property\",\"Name\":\"NameOcclusion\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PlatformStand\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"HumanoidRigType\",\"type\":\"Property\",\"Name\":\"RigType\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"RightLeg\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"RootPart\",\"tags\":[\"readonly\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"SeatPart\",\"tags\":[\"readonly\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Sit\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"TargetPoint\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Torso\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WalkSpeed\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"WalkToPart\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"WalkToPoint\",\"tags\":[],\"Class\":\"Humanoid\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"maxHealth\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"accessory\",\"Default\":null}],\"Name\":\"AddAccessory\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"status\",\"Default\":null}],\"Name\":\"AddCustomStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Status\",\"Name\":\"status\",\"Default\":\"Poison\"}],\"Name\":\"AddStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"BuildRigFromAttachments\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"HumanoidStateType\",\"Name\":\"state\",\"Default\":\"None\"}],\"Name\":\"ChangeState\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"tool\",\"Default\":null}],\"Name\":\"EquipTool\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetAccessories\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"BodyPartR15\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null}],\"Name\":\"GetBodyPartR15\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Limb\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null}],\"Name\":\"GetLimb\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetPlayingAnimationTracks\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"HumanoidStateType\",\"Arguments\":[],\"Name\":\"GetState\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"HumanoidStateType\",\"Name\":\"state\",\"Default\":null}],\"Name\":\"GetStateEnabled\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetStatuses\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"status\",\"Default\":null}],\"Name\":\"HasCustomStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Status\",\"Name\":\"status\",\"Default\":\"Poison\"}],\"Name\":\"HasStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"animation\",\"Default\":null}],\"Name\":\"LoadAnimation\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"moveDirection\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"relativeToCamera\",\"Default\":\"false\"}],\"Name\":\"Move\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"location\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":\"nil\"}],\"Name\":\"MoveTo\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RemoveAccessories\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"status\",\"Default\":null}],\"Name\":\"RemoveCustomStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Status\",\"Name\":\"status\",\"Default\":\"Poison\"}],\"Name\":\"RemoveStatus\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"BodyPartR15\",\"Name\":\"bodyPart\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null}],\"Name\":\"ReplaceBodyPartR15\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetClickToWalkEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"HumanoidStateType\",\"Name\":\"state\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetStateEnabled\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"amount\",\"Default\":null}],\"Name\":\"TakeDamage\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"UnequipTools\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"animation\",\"Default\":null}],\"Name\":\"loadAnimation\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"amount\",\"Default\":null}],\"Name\":\"takeDamage\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"animationTrack\",\"Type\":\"Instance\"}],\"Name\":\"AnimationPlayed\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"speed\",\"Type\":\"float\"}],\"Name\":\"Climbing\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"status\",\"Type\":\"string\"}],\"Name\":\"CustomStatusAdded\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"status\",\"Type\":\"string\"}],\"Name\":\"CustomStatusRemoved\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Died\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"FallingDown\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"FreeFalling\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"GettingUp\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"health\",\"Type\":\"float\"}],\"Name\":\"HealthChanged\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"Jumping\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"reached\",\"Type\":\"bool\"}],\"Name\":\"MoveToFinished\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"PlatformStanding\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"Ragdoll\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"speed\",\"Type\":\"float\"}],\"Name\":\"Running\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"},{\"Name\":\"currentSeatPart\",\"Type\":\"Instance\"}],\"Name\":\"Seated\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"old\",\"Type\":\"HumanoidStateType\"},{\"Name\":\"new\",\"Type\":\"HumanoidStateType\"}],\"Name\":\"StateChanged\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"state\",\"Type\":\"HumanoidStateType\"},{\"Name\":\"isEnabled\",\"Type\":\"bool\"}],\"Name\":\"StateEnabledChanged\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"status\",\"Type\":\"Status\"}],\"Name\":\"StatusAdded\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"status\",\"Type\":\"Status\"}],\"Name\":\"StatusRemoved\",\"tags\":[\"deprecated\"],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"active\",\"Type\":\"bool\"}],\"Name\":\"Strafing\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"speed\",\"Type\":\"float\"}],\"Name\":\"Swimming\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchingPart\",\"Type\":\"Instance\"},{\"Name\":\"humanoidPart\",\"Type\":\"Instance\"}],\"Name\":\"Touched\",\"tags\":[],\"Class\":\"Humanoid\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"InputObject\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Delta\",\"tags\":[],\"Class\":\"InputObject\"},{\"ValueType\":\"KeyCode\",\"type\":\"Property\",\"Name\":\"KeyCode\",\"tags\":[],\"Class\":\"InputObject\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"InputObject\"},{\"ValueType\":\"UserInputState\",\"type\":\"Property\",\"Name\":\"UserInputState\",\"tags\":[],\"Class\":\"InputObject\"},{\"ValueType\":\"UserInputType\",\"type\":\"Property\",\"Name\":\"UserInputType\",\"tags\":[],\"Class\":\"InputObject\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"InsertService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllowInsertFreeModels\",\"tags\":[\"deprecated\",\"notbrowsable\"],\"Class\":\"InsertService\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"ApproveAssetId\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetVersionId\",\"Default\":null}],\"Name\":\"ApproveAssetVersionId\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null}],\"Name\":\"Insert\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"assetPath\",\"Default\":null}],\"Name\":\"LoadLocalAsset\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"InsertService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetBaseCategories\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetBaseSets\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"categoryId\",\"Default\":null}],\"Name\":\"GetCollection\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"searchText\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"pageNum\",\"Default\":null}],\"Name\":\"GetFreeDecals\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"searchText\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"pageNum\",\"Default\":null}],\"Name\":\"GetFreeModels\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"GetLatestAssetVersionAsync\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetUserCategories\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetUserSets\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"LoadAsset\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetVersionId\",\"Default\":null}],\"Name\":\"LoadAssetVersion\",\"tags\":[],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"loadAsset\",\"tags\":[\"deprecated\"],\"Class\":\"InsertService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"InstancePacketCache\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"JointInstance\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"C0\",\"tags\":[],\"Class\":\"JointInstance\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"C1\",\"tags\":[],\"Class\":\"JointInstance\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Part0\",\"tags\":[],\"Class\":\"JointInstance\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Part1\",\"tags\":[],\"Class\":\"JointInstance\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"part1\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"JointInstance\"},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"DynamicRotate\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BaseAngle\",\"tags\":[],\"Class\":\"DynamicRotate\"},{\"Superclass\":\"DynamicRotate\",\"type\":\"Class\",\"Name\":\"RotateP\",\"tags\":[]},{\"Superclass\":\"DynamicRotate\",\"type\":\"Class\",\"Name\":\"RotateV\",\"tags\":[]},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"Glue\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"F0\",\"tags\":[],\"Class\":\"Glue\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"F1\",\"tags\":[],\"Class\":\"Glue\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"F2\",\"tags\":[],\"Class\":\"Glue\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"F3\",\"tags\":[],\"Class\":\"Glue\"},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"ManualSurfaceJointInstance\",\"tags\":[]},{\"Superclass\":\"ManualSurfaceJointInstance\",\"type\":\"Class\",\"Name\":\"ManualGlue\",\"tags\":[]},{\"Superclass\":\"ManualSurfaceJointInstance\",\"type\":\"Class\",\"Name\":\"ManualWeld\",\"tags\":[]},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"Motor\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentAngle\",\"tags\":[],\"Class\":\"Motor\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DesiredAngle\",\"tags\":[],\"Class\":\"Motor\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxVelocity\",\"tags\":[],\"Class\":\"Motor\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetDesiredAngle\",\"tags\":[],\"Class\":\"Motor\",\"type\":\"Function\"},{\"Superclass\":\"Motor\",\"type\":\"Class\",\"Name\":\"Motor6D\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Transform\",\"tags\":[\"hidden\"],\"Class\":\"Motor6D\"},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"Rotate\",\"tags\":[]},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"Snap\",\"tags\":[]},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"VelocityMotor\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CurrentAngle\",\"tags\":[],\"Class\":\"VelocityMotor\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DesiredAngle\",\"tags\":[],\"Class\":\"VelocityMotor\"},{\"ValueType\":\"Class:Hole\",\"type\":\"Property\",\"Name\":\"Hole\",\"tags\":[],\"Class\":\"VelocityMotor\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxVelocity\",\"tags\":[],\"Class\":\"VelocityMotor\"},{\"Superclass\":\"JointInstance\",\"type\":\"Class\",\"Name\":\"Weld\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"JointsService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearJoinAfterMoveJoints\",\"tags\":[],\"Class\":\"JointsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"CreateJoinAfterMoveJoints\",\"tags\":[],\"Class\":\"JointsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"joinInstance\",\"Default\":null}],\"Name\":\"SetJoinAfterMoveInstance\",\"tags\":[],\"Class\":\"JointsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"joinTarget\",\"Default\":null}],\"Name\":\"SetJoinAfterMoveTarget\",\"tags\":[],\"Class\":\"JointsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ShowPermissibleJoints\",\"tags\":[],\"Class\":\"JointsService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"KeyboardService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Keyframe\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Time\",\"tags\":[],\"Class\":\"Keyframe\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"pose\",\"Default\":null}],\"Name\":\"AddPose\",\"tags\":[],\"Class\":\"Keyframe\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetPoses\",\"tags\":[],\"Class\":\"Keyframe\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"pose\",\"Default\":null}],\"Name\":\"RemovePose\",\"tags\":[],\"Class\":\"Keyframe\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"KeyframeSequence\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Loop\",\"tags\":[],\"Class\":\"KeyframeSequence\"},{\"ValueType\":\"AnimationPriority\",\"type\":\"Property\",\"Name\":\"Priority\",\"tags\":[],\"Class\":\"KeyframeSequence\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"keyframe\",\"Default\":null}],\"Name\":\"AddKeyframe\",\"tags\":[],\"Class\":\"KeyframeSequence\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetKeyframes\",\"tags\":[],\"Class\":\"KeyframeSequence\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"keyframe\",\"Default\":null}],\"Name\":\"RemoveKeyframe\",\"tags\":[],\"Class\":\"KeyframeSequence\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"KeyframeSequenceProvider\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Content\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"GetKeyframeSequence\",\"tags\":[\"PluginSecurity\",\"deprecated\"],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"useCache\",\"Default\":null}],\"Name\":\"GetKeyframeSequenceById\",\"tags\":[\"PluginSecurity\",\"deprecated\"],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Content\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"keyframeSequence\",\"Default\":null}],\"Name\":\"RegisterActiveKeyframeSequence\",\"tags\":[],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Content\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"keyframeSequence\",\"Default\":null}],\"Name\":\"RegisterKeyframeSequence\",\"tags\":[],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetAnimations\",\"tags\":[],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Content\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"GetKeyframeSequenceAsync\",\"tags\":[],\"Class\":\"KeyframeSequenceProvider\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Light\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Brightness\",\"tags\":[],\"Class\":\"Light\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Light\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Light\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Shadows\",\"tags\":[],\"Class\":\"Light\"},{\"Superclass\":\"Light\",\"type\":\"Class\",\"Name\":\"PointLight\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Range\",\"tags\":[],\"Class\":\"PointLight\"},{\"Superclass\":\"Light\",\"type\":\"Class\",\"Name\":\"SpotLight\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Angle\",\"tags\":[],\"Class\":\"SpotLight\"},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"Face\",\"tags\":[],\"Class\":\"SpotLight\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Range\",\"tags\":[],\"Class\":\"SpotLight\"},{\"Superclass\":\"Light\",\"type\":\"Class\",\"Name\":\"SurfaceLight\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Angle\",\"tags\":[],\"Class\":\"SurfaceLight\"},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"Face\",\"tags\":[],\"Class\":\"SurfaceLight\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Range\",\"tags\":[],\"Class\":\"SurfaceLight\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Lighting\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Ambient\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Brightness\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ClockTime\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ColorShift_Bottom\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ColorShift_Top\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ExposureCompensation\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"FogColor\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FogEnd\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FogStart\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"GeographicLatitude\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GlobalShadows\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"OutdoorAmbient\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Outlines\",\"tags\":[],\"Class\":\"Lighting\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"ShadowColor\",\"tags\":[\"deprecated\"],\"Class\":\"Lighting\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"TimeOfDay\",\"tags\":[],\"Class\":\"Lighting\"},{\"ReturnType\":\"double\",\"Arguments\":[],\"Name\":\"GetMinutesAfterMidnight\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetMoonDirection\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetMoonPhase\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetSunDirection\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"double\",\"Name\":\"minutes\",\"Default\":null}],\"Name\":\"SetMinutesAfterMidnight\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[],\"Name\":\"getMinutesAfterMidnight\",\"tags\":[\"deprecated\"],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"double\",\"Name\":\"minutes\",\"Default\":null}],\"Name\":\"setMinutesAfterMidnight\",\"tags\":[\"deprecated\"],\"Class\":\"Lighting\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"skyboxChanged\",\"Type\":\"bool\"}],\"Name\":\"LightingChanged\",\"tags\":[],\"Class\":\"Lighting\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LocalizationService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ForcePlayModeGameLocaleId\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ForcePlayModeRobloxLocaleId\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsTextScraperRunning\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"RobloxForcePlayModeGameLocaleId\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"RobloxForcePlayModeRobloxLocaleId\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"RobloxLocaleId\",\"tags\":[\"readonly\"],\"Class\":\"LocalizationService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"SystemLocaleId\",\"tags\":[\"readonly\"],\"Class\":\"LocalizationService\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetCorescriptLocalizations\",\"tags\":[],\"Class\":\"LocalizationService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"GetTranslatorForPlayer\",\"tags\":[],\"Class\":\"LocalizationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StartTextScraper\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StopTextScraper\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"PromptExportToCSVs\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"PromptImportFromCSVs\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\",\"type\":\"YieldFunction\"},{\"Arguments\":[],\"Name\":\"AutoTranslateWillRun\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LocalizationTable\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"DevelopmentLanguage\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"LocalizationTable\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Root\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"LocalizationTable\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"SourceLocaleId\",\"tags\":[],\"Class\":\"LocalizationTable\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetContents\",\"tags\":[\"deprecated\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetEntries\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"targetLocaleId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"GetString\",\"tags\":[\"deprecated\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"localeId\",\"Default\":null}],\"Name\":\"GetTranslator\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null}],\"Name\":\"RemoveEntry\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"localeId\",\"Default\":null}],\"Name\":\"RemoveEntryValue\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"RemoveKey\",\"tags\":[\"deprecated\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"localeId\",\"Default\":null}],\"Name\":\"RemoveTargetLocale\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"contents\",\"Default\":null}],\"Name\":\"SetContents\",\"tags\":[\"deprecated\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Variant\",\"Name\":\"entries\",\"Default\":null}],\"Name\":\"SetEntries\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"targetLocaleId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"SetEntry\",\"tags\":[\"deprecated\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"newContext\",\"Default\":null}],\"Name\":\"SetEntryContext\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"example\",\"Default\":null}],\"Name\":\"SetEntryExample\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"newKey\",\"Default\":null}],\"Name\":\"SetEntryKey\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"newSource\",\"Default\":null}],\"Name\":\"SetEntrySource\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"localeId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"SetEntryValue\",\"tags\":[],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetIsExemptFromUGCAnalytics\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LocalizationTable\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LogService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"source\",\"Default\":null}],\"Name\":\"ExecuteScript\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetHttpResultHistory\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetLogHistory\",\"tags\":[],\"Class\":\"LogService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RequestHttpResultApproved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RequestServerHttpResult\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RequestServerOutput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"httpResult\",\"Type\":\"Dictionary\"}],\"Name\":\"HttpResultOut\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"messageType\",\"Type\":\"MessageType\"}],\"Name\":\"MessageOut\",\"tags\":[],\"Class\":\"LogService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"isApproved\",\"Type\":\"bool\"}],\"Name\":\"OnHttpResultApproved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"httpResult\",\"Type\":\"Dictionary\"}],\"Name\":\"ServerHttpResultOut\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"messageType\",\"Type\":\"MessageType\"},{\"Name\":\"timestamp\",\"Type\":\"int\"}],\"Name\":\"ServerMessageOut\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"LogService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LoginService\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Logout\",\"tags\":[\"RobloxSecurity\"],\"Class\":\"LoginService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"PromptLogin\",\"tags\":[\"RobloxSecurity\"],\"Class\":\"LoginService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"loginError\",\"Type\":\"string\"}],\"Name\":\"LoginFailed\",\"tags\":[\"RobloxSecurity\"],\"Class\":\"LoginService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"username\",\"Type\":\"string\"}],\"Name\":\"LoginSucceeded\",\"tags\":[\"RobloxSecurity\"],\"Class\":\"LoginService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LuaSettings\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreScriptStartsReported\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"DefaultWaitTime\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"GcFrequency\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"GcLimit\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"GcPause\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"GcStepMul\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WaitingThreadsBudget\",\"tags\":[],\"Class\":\"LuaSettings\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LuaSourceContainer\",\"tags\":[\"notbrowsable\"]},{\"Superclass\":\"LuaSourceContainer\",\"type\":\"Class\",\"Name\":\"BaseScript\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Disabled\",\"tags\":[],\"Class\":\"BaseScript\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"LinkedSource\",\"tags\":[],\"Class\":\"BaseScript\"},{\"Superclass\":\"BaseScript\",\"type\":\"Class\",\"Name\":\"CoreScript\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"BaseScript\",\"type\":\"Class\",\"Name\":\"Script\",\"tags\":[]},{\"ValueType\":\"ProtectedString\",\"type\":\"Property\",\"Name\":\"Source\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Script\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetHash\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Script\",\"type\":\"Function\"},{\"Superclass\":\"Script\",\"type\":\"Class\",\"Name\":\"LocalScript\",\"tags\":[]},{\"Superclass\":\"LuaSourceContainer\",\"type\":\"Class\",\"Name\":\"ModuleScript\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"LinkedSource\",\"tags\":[],\"Class\":\"ModuleScript\"},{\"ValueType\":\"ProtectedString\",\"type\":\"Property\",\"Name\":\"Source\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ModuleScript\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"LuaWebService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"MarketplaceService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"PlayerCanMakePurchases\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"gamePassId\",\"Default\":null}],\"Name\":\"PromptGamePassPurchase\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"productId\",\"Default\":null}],\"Name\":\"PromptNativePurchase\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"productId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"equipIfPurchased\",\"Default\":\"true\"},{\"Type\":\"CurrencyType\",\"Name\":\"currencyType\",\"Default\":\"Default\"}],\"Name\":\"PromptProductPurchase\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"equipIfPurchased\",\"Default\":\"true\"},{\"Type\":\"CurrencyType\",\"Name\":\"currencyType\",\"Default\":\"Default\"}],\"Name\":\"PromptPurchase\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"productId\",\"Default\":null}],\"Name\":\"PromptThirdPartyPurchase\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"robuxAmount\",\"Default\":null}],\"Name\":\"ReportAssetSale\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ReportRobuxUpsellStarted\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"ticket\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"playerId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"productId\",\"Default\":null}],\"Name\":\"SignalClientPurchaseSuccess\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"gamePassId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"success\",\"Default\":null}],\"Name\":\"SignalPromptGamePassPurchaseFinished\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"productId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"success\",\"Default\":null}],\"Name\":\"SignalPromptProductPurchaseFinished\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"success\",\"Default\":null}],\"Name\":\"SignalPromptPurchaseFinished\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SignalServerLuaDialogClosed\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetDeveloperProductsAsync\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null},{\"Type\":\"InfoType\",\"Name\":\"infoType\",\"Default\":\"Asset\"}],\"Name\":\"GetProductInfo\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetRobuxBalance\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"InfoType\",\"Name\":\"infoType\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"productId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"expectedPrice\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"requestId\",\"Default\":null}],\"Name\":\"PerformPurchase\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"assetId\",\"Default\":null}],\"Name\":\"PlayerOwnsAsset\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"gamePassId\",\"Default\":null}],\"Name\":\"UserOwnsGamePassAsync\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"ClientLuaDialogRequested\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"ticket\",\"Type\":\"string\"},{\"Name\":\"playerId\",\"Type\":\"int64\"},{\"Name\":\"productId\",\"Type\":\"int64\"}],\"Name\":\"ClientPurchaseSuccess\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"productId\",\"Type\":\"string\"},{\"Name\":\"wasPurchased\",\"Type\":\"bool\"}],\"Name\":\"NativePurchaseFinished\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"gamePassId\",\"Type\":\"int64\"},{\"Name\":\"wasPurchased\",\"Type\":\"bool\"}],\"Name\":\"PromptGamePassPurchaseFinished\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"gamePassId\",\"Type\":\"int64\"}],\"Name\":\"PromptGamePassPurchaseRequested\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"userId\",\"Type\":\"int64\"},{\"Name\":\"productId\",\"Type\":\"int64\"},{\"Name\":\"isPurchased\",\"Type\":\"bool\"}],\"Name\":\"PromptProductPurchaseFinished\",\"tags\":[\"deprecated\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"productId\",\"Type\":\"int64\"},{\"Name\":\"equipIfPurchased\",\"Type\":\"bool\"},{\"Name\":\"currencyType\",\"Type\":\"CurrencyType\"}],\"Name\":\"PromptProductPurchaseRequested\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"assetId\",\"Type\":\"int64\"},{\"Name\":\"isPurchased\",\"Type\":\"bool\"}],\"Name\":\"PromptPurchaseFinished\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"assetId\",\"Type\":\"int64\"},{\"Name\":\"equipIfPurchased\",\"Type\":\"bool\"},{\"Name\":\"currencyType\",\"Type\":\"CurrencyType\"}],\"Name\":\"PromptPurchaseRequested\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"serverResponseTable\",\"Type\":\"Dictionary\"}],\"Name\":\"ServerPurchaseVerification\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"productId\",\"Type\":\"string\"},{\"Name\":\"receipt\",\"Type\":\"string\"},{\"Name\":\"wasPurchased\",\"Type\":\"bool\"}],\"Name\":\"ThirdPartyPurchaseFinished\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"MarketplaceService\",\"type\":\"Event\"},{\"ReturnType\":\"ProductPurchaseDecision\",\"Arguments\":[{\"Name\":\"receiptInfo\",\"Type\":\"Dictionary\"}],\"Name\":\"ProcessReceipt\",\"tags\":[],\"Class\":\"MarketplaceService\",\"type\":\"Callback\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Message\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Text\",\"tags\":[],\"Class\":\"Message\"},{\"Superclass\":\"Message\",\"type\":\"Class\",\"Name\":\"Hint\",\"tags\":[\"deprecated\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Mouse\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Hit\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Icon\",\"tags\":[],\"Class\":\"Mouse\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Origin\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Target\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"TargetFilter\",\"tags\":[],\"Class\":\"Mouse\"},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"TargetSurface\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"Ray\",\"type\":\"Property\",\"Name\":\"UnitRay\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ViewSizeX\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ViewSizeY\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"X\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Y\",\"tags\":[\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"hit\",\"tags\":[\"deprecated\",\"hidden\",\"readonly\"],\"Class\":\"Mouse\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"target\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Mouse\"},{\"Arguments\":[],\"Name\":\"Button1Down\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Button1Up\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Button2Down\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Button2Up\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Idle\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"key\",\"Type\":\"string\"}],\"Name\":\"KeyDown\",\"tags\":[\"deprecated\"],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"key\",\"Type\":\"string\"}],\"Name\":\"KeyUp\",\"tags\":[\"deprecated\"],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Move\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WheelBackward\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WheelForward\",\"tags\":[],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"key\",\"Type\":\"string\"}],\"Name\":\"keyDown\",\"tags\":[\"deprecated\"],\"Class\":\"Mouse\",\"type\":\"Event\"},{\"Superclass\":\"Mouse\",\"type\":\"Class\",\"Name\":\"PlayerMouse\",\"tags\":[]},{\"Superclass\":\"Mouse\",\"type\":\"Class\",\"Name\":\"PluginMouse\",\"tags\":[]},{\"Arguments\":[{\"Name\":\"instances\",\"Type\":\"Objects\"}],\"Name\":\"DragEnter\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginMouse\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"MouseService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"NetworkMarker\",\"tags\":[\"notbrowsable\"]},{\"Arguments\":[],\"Name\":\"Received\",\"tags\":[],\"Class\":\"NetworkMarker\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"NetworkPeer\",\"tags\":[\"notbrowsable\"]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"limit\",\"Default\":null}],\"Name\":\"SetOutgoingKBPSLimit\",\"tags\":[\"PluginSecurity\"],\"Class\":\"NetworkPeer\",\"type\":\"Function\"},{\"Superclass\":\"NetworkPeer\",\"type\":\"Class\",\"Name\":\"NetworkClient\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Ticket\",\"tags\":[],\"Class\":\"NetworkClient\"},{\"Arguments\":[{\"Name\":\"peer\",\"Type\":\"string\"},{\"Name\":\"replicator\",\"Type\":\"Instance\"}],\"Name\":\"ConnectionAccepted\",\"tags\":[],\"Class\":\"NetworkClient\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"peer\",\"Type\":\"string\"},{\"Name\":\"code\",\"Type\":\"int\"},{\"Name\":\"reason\",\"Type\":\"string\"}],\"Name\":\"ConnectionFailed\",\"tags\":[],\"Class\":\"NetworkClient\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"peer\",\"Type\":\"string\"}],\"Name\":\"ConnectionRejected\",\"tags\":[],\"Class\":\"NetworkClient\",\"type\":\"Event\"},{\"Superclass\":\"NetworkPeer\",\"type\":\"Class\",\"Name\":\"NetworkServer\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Port\",\"tags\":[\"readonly\"],\"Class\":\"NetworkServer\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetClientCount\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NetworkServer\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"NetworkReplicator\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"CloseConnection\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NetworkReplicator\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetPlayer\",\"tags\":[],\"Class\":\"NetworkReplicator\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"verbosityLevel\",\"Default\":\"0\"}],\"Name\":\"GetRakStatsString\",\"tags\":[\"PluginSecurity\"],\"Class\":\"NetworkReplicator\",\"type\":\"Function\"},{\"Superclass\":\"NetworkReplicator\",\"type\":\"Class\",\"Name\":\"ClientReplicator\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"request\",\"Default\":null}],\"Name\":\"RequestServerStats\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ClientReplicator\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"stats\",\"Type\":\"Dictionary\"}],\"Name\":\"StatsReceived\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ClientReplicator\",\"type\":\"Event\"},{\"Superclass\":\"NetworkReplicator\",\"type\":\"Class\",\"Name\":\"ServerReplicator\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"NetworkSettings\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ArePhysicsRejectionsReported\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ClientPhysicsSendRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DataGCRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DataMtuAdjust\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"PacketPriority\",\"type\":\"Property\",\"Name\":\"DataSendPriority\",\"tags\":[\"hidden\"],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DataSendRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ExtraMemoryUsed\",\"tags\":[\"PluginSecurity\",\"hidden\"],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FreeMemoryMBytes\",\"tags\":[\"PluginSecurity\",\"hidden\",\"readonly\"],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"IncommingReplicationLag\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsQueueErrorComputed\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"NetworkOwnerRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PhysicsMtuAdjust\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"PacketPriority\",\"type\":\"Property\",\"Name\":\"PhysicsSendPriority\",\"tags\":[\"hidden\"],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"PhysicsSendRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PreferredClientPort\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintBits\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintEvents\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintFilters\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintInstances\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintPhysicsErrors\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintProperties\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintSplitMessage\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintStreamInstanceQuota\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PrintTouches\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"ReceiveRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RenderStreamedRegions\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShowActiveAnimationAsset\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TouchSendRate\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TrackDataTypes\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TrackPhysicsDetails\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UseInstancePacketCache\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsePhysicsPacketCache\",\"tags\":[],\"Class\":\"NetworkSettings\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"NotificationService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLuaChatEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"NotificationService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLuaGamesPageEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"NotificationService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLuaHomePageEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"NotificationService\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"AppShellActionType\",\"Name\":\"actionType\",\"Default\":null}],\"Name\":\"ActionEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"AppShellActionType\",\"Name\":\"actionType\",\"Default\":null}],\"Name\":\"ActionTaken\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"CancelAllNotification\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"alertId\",\"Default\":null}],\"Name\":\"CancelNotification\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"alertId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"alertMsg\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"minutesToFire\",\"Default\":null}],\"Name\":\"ScheduleNotification\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetScheduledNotifications\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"NotificationService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"connectionName\",\"Type\":\"string\"},{\"Name\":\"connectionState\",\"Type\":\"ConnectionState\"},{\"Name\":\"sequenceNumber\",\"Type\":\"string\"}],\"Name\":\"RobloxConnectionChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"eventData\",\"Type\":\"Map\"}],\"Name\":\"RobloxEventReceived\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"NotificationService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PVInstance\",\"tags\":[\"notbrowsable\"]},{\"Superclass\":\"PVInstance\",\"type\":\"Class\",\"Name\":\"BasePart\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Anchored\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BackParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BackParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"BackSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"BackSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BottomParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"BottomParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"BottomSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"BottomSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"BrickColor\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CanCollide\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"CenterOfMass\",\"tags\":[\"readonly\"],\"Class\":\"BasePart\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"CollisionGroupId\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"PhysicalProperties\",\"type\":\"Property\",\"Name\":\"CustomPhysicalProperties\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Elasticity\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Friction\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FrontParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FrontParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"FrontSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"FrontSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LeftParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LeftParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"LeftSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"LeftSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LocalTransparencyModifier\",\"tags\":[\"hidden\"],\"Class\":\"BasePart\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Locked\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Material\",\"type\":\"Property\",\"Name\":\"Material\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Orientation\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ReceiveAge\",\"tags\":[\"hidden\",\"readonly\"],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Reflectance\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ResizeIncrement\",\"tags\":[\"readonly\"],\"Class\":\"BasePart\"},{\"ValueType\":\"Faces\",\"type\":\"Property\",\"Name\":\"ResizeableFaces\",\"tags\":[\"readonly\"],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"RightParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"RightParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"RightSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"RightSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"RotVelocity\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Rotation\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SpecificGravity\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TopParamA\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TopParamB\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"SurfaceType\",\"type\":\"Property\",\"Name\":\"TopSurface\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"InputType\",\"type\":\"Property\",\"Name\":\"TopSurfaceInput\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Velocity\",\"tags\":[],\"Class\":\"BasePart\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"brickColor\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"BreakJoints\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null}],\"Name\":\"CanCollideWith\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"CanSetNetworkOwnership\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"recursive\",\"Default\":\"false\"}],\"Name\":\"GetConnectedParts\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetJoints\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetMass\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetNetworkOwner\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetNetworkOwnershipAuto\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[],\"Name\":\"GetRenderCFrame\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetRootPart\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetTouchingParts\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsGrounded\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"MakeJoints\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"NormalId\",\"Name\":\"normalId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"deltaAmount\",\"Default\":null}],\"Name\":\"Resize\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"playerInstance\",\"Default\":\"nil\"}],\"Name\":\"SetNetworkOwner\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SetNetworkOwnershipAuto\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"breakJoints\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"getMass\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"makeJoints\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"NormalId\",\"Name\":\"normalId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"deltaAmount\",\"Default\":null}],\"Name\":\"resize\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"parts\",\"Default\":null},{\"Type\":\"CollisionFidelity\",\"Name\":\"collisionfidelity\",\"Default\":\"Default\"}],\"Name\":\"SubtractAsync\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"parts\",\"Default\":null},{\"Type\":\"CollisionFidelity\",\"Name\":\"collisionfidelity\",\"Default\":\"Default\"}],\"Name\":\"UnionAsync\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"part\",\"Type\":\"Instance\"}],\"Name\":\"LocalSimulationTouched\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"OutfitChanged\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"otherPart\",\"Type\":\"Instance\"}],\"Name\":\"StoppedTouching\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"otherPart\",\"Type\":\"Instance\"}],\"Name\":\"TouchEnded\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"otherPart\",\"Type\":\"Instance\"}],\"Name\":\"Touched\",\"tags\":[],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"otherPart\",\"Type\":\"Instance\"}],\"Name\":\"touched\",\"tags\":[\"deprecated\"],\"Class\":\"BasePart\",\"type\":\"Event\"},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"CornerWedgePart\",\"tags\":[]},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"FormFactorPart\",\"tags\":[]},{\"ValueType\":\"FormFactor\",\"type\":\"Property\",\"Name\":\"FormFactor\",\"tags\":[\"deprecated\"],\"Class\":\"FormFactorPart\"},{\"ValueType\":\"FormFactor\",\"type\":\"Property\",\"Name\":\"formFactor\",\"tags\":[\"deprecated\",\"hidden\"],\"Class\":\"FormFactorPart\"},{\"Superclass\":\"FormFactorPart\",\"type\":\"Class\",\"Name\":\"Part\",\"tags\":[]},{\"ValueType\":\"PartType\",\"type\":\"Property\",\"Name\":\"Shape\",\"tags\":[],\"Class\":\"Part\"},{\"Superclass\":\"Part\",\"type\":\"Class\",\"Name\":\"FlagStand\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TeamColor\",\"tags\":[],\"Class\":\"FlagStand\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"FlagCaptured\",\"tags\":[],\"Class\":\"FlagStand\",\"type\":\"Event\"},{\"Superclass\":\"Part\",\"type\":\"Class\",\"Name\":\"Platform\",\"tags\":[]},{\"Superclass\":\"Part\",\"type\":\"Class\",\"Name\":\"Seat\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Disabled\",\"tags\":[],\"Class\":\"Seat\"},{\"ValueType\":\"Class:Humanoid\",\"type\":\"Property\",\"Name\":\"Occupant\",\"tags\":[\"readonly\"],\"Class\":\"Seat\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"humanoid\",\"Default\":null}],\"Name\":\"Sit\",\"tags\":[],\"Class\":\"Seat\",\"type\":\"Function\"},{\"Superclass\":\"Part\",\"type\":\"Class\",\"Name\":\"SkateboardPlatform\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"Class:SkateboardController\",\"type\":\"Property\",\"Name\":\"Controller\",\"tags\":[\"readonly\"],\"Class\":\"SkateboardPlatform\"},{\"ValueType\":\"Class:Humanoid\",\"type\":\"Property\",\"Name\":\"ControllingHumanoid\",\"tags\":[\"readonly\"],\"Class\":\"SkateboardPlatform\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Steer\",\"tags\":[],\"Class\":\"SkateboardPlatform\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"StickyWheels\",\"tags\":[],\"Class\":\"SkateboardPlatform\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Throttle\",\"tags\":[],\"Class\":\"SkateboardPlatform\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"impulseWorld\",\"Default\":null}],\"Name\":\"ApplySpecificImpulse\",\"tags\":[],\"Class\":\"SkateboardPlatform\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"humanoid\",\"Type\":\"Instance\"},{\"Name\":\"skateboardController\",\"Type\":\"Instance\"}],\"Name\":\"Equipped\",\"tags\":[],\"Class\":\"SkateboardPlatform\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"newState\",\"Type\":\"MoveState\"},{\"Name\":\"oldState\",\"Type\":\"MoveState\"}],\"Name\":\"MoveStateChanged\",\"tags\":[],\"Class\":\"SkateboardPlatform\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"humanoid\",\"Type\":\"Instance\"}],\"Name\":\"Unequipped\",\"tags\":[],\"Class\":\"SkateboardPlatform\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"humanoid\",\"Type\":\"Instance\"},{\"Name\":\"skateboardController\",\"Type\":\"Instance\"}],\"Name\":\"equipped\",\"tags\":[\"deprecated\"],\"Class\":\"SkateboardPlatform\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"humanoid\",\"Type\":\"Instance\"}],\"Name\":\"unequipped\",\"tags\":[\"deprecated\"],\"Class\":\"SkateboardPlatform\",\"type\":\"Event\"},{\"Superclass\":\"Part\",\"type\":\"Class\",\"Name\":\"SpawnLocation\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllowTeamChangeOnTouch\",\"tags\":[],\"Class\":\"SpawnLocation\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Duration\",\"tags\":[],\"Class\":\"SpawnLocation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"SpawnLocation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Neutral\",\"tags\":[],\"Class\":\"SpawnLocation\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TeamColor\",\"tags\":[],\"Class\":\"SpawnLocation\"},{\"Superclass\":\"FormFactorPart\",\"type\":\"Class\",\"Name\":\"WedgePart\",\"tags\":[]},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"MeshPart\",\"tags\":[]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"MeshId\",\"tags\":[\"ScriptWriteRestricted: [NotAccessibleSecurity]\"],\"Class\":\"MeshPart\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"TextureID\",\"tags\":[],\"Class\":\"MeshPart\"},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"PartOperation\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"TriangleCount\",\"tags\":[\"readonly\"],\"Class\":\"PartOperation\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsePartColor\",\"tags\":[],\"Class\":\"PartOperation\"},{\"Superclass\":\"PartOperation\",\"type\":\"Class\",\"Name\":\"NegateOperation\",\"tags\":[]},{\"Superclass\":\"PartOperation\",\"type\":\"Class\",\"Name\":\"UnionOperation\",\"tags\":[]},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"Terrain\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsSmooth\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Terrain\"},{\"ValueType\":\"Region3int16\",\"type\":\"Property\",\"Name\":\"MaxExtents\",\"tags\":[\"readonly\"],\"Class\":\"Terrain\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"WaterColor\",\"tags\":[],\"Class\":\"Terrain\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WaterReflectance\",\"tags\":[],\"Class\":\"Terrain\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WaterTransparency\",\"tags\":[],\"Class\":\"Terrain\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WaterWaveSize\",\"tags\":[],\"Class\":\"Terrain\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WaterWaveSpeed\",\"tags\":[],\"Class\":\"Terrain\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"AutowedgeCell\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Region3int16\",\"Name\":\"region\",\"Default\":null}],\"Name\":\"AutowedgeCells\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"CellCenterToWorld\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"CellCornerToWorld\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Clear\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ConvertToSmooth\",\"tags\":[\"PluginSecurity\",\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Region3int16\",\"Name\":\"region\",\"Default\":null}],\"Name\":\"CopyRegion\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"CountCells\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"center\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"radius\",\"Default\":null},{\"Type\":\"Material\",\"Name\":\"material\",\"Default\":null}],\"Name\":\"FillBall\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CoordinateFrame\",\"Name\":\"cframe\",\"Default\":null},{\"Type\":\"Vector3\",\"Name\":\"size\",\"Default\":null},{\"Type\":\"Material\",\"Name\":\"material\",\"Default\":null}],\"Name\":\"FillBlock\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"resolution\",\"Default\":null},{\"Type\":\"Material\",\"Name\":\"material\",\"Default\":null}],\"Name\":\"FillRegion\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"GetCell\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Color3\",\"Arguments\":[{\"Type\":\"Material\",\"Name\":\"material\",\"Default\":null}],\"Name\":\"GetMaterialColor\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"GetWaterCell\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Vector3int16\",\"Name\":\"corner\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"pasteEmptyCells\",\"Default\":null}],\"Name\":\"PasteRegion\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"resolution\",\"Default\":null}],\"Name\":\"ReadVoxels\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null},{\"Type\":\"CellMaterial\",\"Name\":\"material\",\"Default\":null},{\"Type\":\"CellBlock\",\"Name\":\"block\",\"Default\":null},{\"Type\":\"CellOrientation\",\"Name\":\"orientation\",\"Default\":null}],\"Name\":\"SetCell\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Region3int16\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"CellMaterial\",\"Name\":\"material\",\"Default\":null},{\"Type\":\"CellBlock\",\"Name\":\"block\",\"Default\":null},{\"Type\":\"CellOrientation\",\"Name\":\"orientation\",\"Default\":null}],\"Name\":\"SetCells\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Material\",\"Name\":\"material\",\"Default\":null},{\"Type\":\"Color3\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetMaterialColor\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"z\",\"Default\":null},{\"Type\":\"WaterForce\",\"Name\":\"force\",\"Default\":null},{\"Type\":\"WaterDirection\",\"Name\":\"direction\",\"Default\":null}],\"Name\":\"SetWaterCell\",\"tags\":[\"deprecated\"],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"WorldToCell\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"WorldToCellPreferEmpty\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"WorldToCellPreferSolid\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"resolution\",\"Default\":null},{\"Type\":\"Array\",\"Name\":\"materials\",\"Default\":null},{\"Type\":\"Array\",\"Name\":\"occupancy\",\"Default\":null}],\"Name\":\"WriteVoxels\",\"tags\":[],\"Class\":\"Terrain\",\"type\":\"Function\"},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"TrussPart\",\"tags\":[]},{\"ValueType\":\"Style\",\"type\":\"Property\",\"Name\":\"Style\",\"tags\":[],\"Class\":\"TrussPart\"},{\"Superclass\":\"BasePart\",\"type\":\"Class\",\"Name\":\"VehicleSeat\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"AreHingesDetected\",\"tags\":[\"readonly\"],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Disabled\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HeadsUpDisplay\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxSpeed\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"Class:Humanoid\",\"type\":\"Property\",\"Name\":\"Occupant\",\"tags\":[\"readonly\"],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Steer\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SteerFloat\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Throttle\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ThrottleFloat\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Torque\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TurnSpeed\",\"tags\":[],\"Class\":\"VehicleSeat\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"humanoid\",\"Default\":null}],\"Name\":\"Sit\",\"tags\":[],\"Class\":\"VehicleSeat\",\"type\":\"Function\"},{\"Superclass\":\"PVInstance\",\"type\":\"Class\",\"Name\":\"Model\",\"tags\":[]},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"PrimaryPart\",\"tags\":[],\"Class\":\"Model\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"BreakJoints\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetExtentsSize\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[],\"Name\":\"GetModelCFrame\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"Vector3\",\"Arguments\":[],\"Name\":\"GetModelSize\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[],\"Name\":\"GetPrimaryPartCFrame\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"MakeJoints\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"MoveTo\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ResetOrientationToIdentity\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SetIdentityOrientation\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CoordinateFrame\",\"Name\":\"cframe\",\"Default\":null}],\"Name\":\"SetPrimaryPartCFrame\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"delta\",\"Default\":null}],\"Name\":\"TranslateBy\",\"tags\":[],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"breakJoints\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"makeJoints\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"location\",\"Default\":null}],\"Name\":\"move\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"location\",\"Default\":null}],\"Name\":\"moveTo\",\"tags\":[\"deprecated\"],\"Class\":\"Model\",\"type\":\"Function\"},{\"Superclass\":\"Model\",\"type\":\"Class\",\"Name\":\"Status\",\"tags\":[\"deprecated\",\"notCreatable\"]},{\"Superclass\":\"Model\",\"type\":\"Class\",\"Name\":\"Workspace\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllowThirdPartySales\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"Class:Camera\",\"type\":\"Property\",\"Name\":\"CurrentCamera\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"DistributedGameTime\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FallenPartsDestroyHeight\",\"tags\":[\"ScriptWriteRestricted: [PluginSecurity]\"],\"Class\":\"Workspace\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"FilteringEnabled\",\"tags\":[\"ScriptWriteRestricted: [PluginSecurity]\"],\"Class\":\"Workspace\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Gravity\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"StreamingEnabled\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TemporaryLegacyPhysicsSolverOverride\",\"tags\":[],\"Class\":\"Workspace\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Terrain\",\"tags\":[\"readonly\"],\"Class\":\"Workspace\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"BreakJoints\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"ExperimentalSolverIsEnabled\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Ray\",\"Name\":\"ray\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"ignoreDescendantsInstance\",\"Default\":\"nil\"},{\"Type\":\"bool\",\"Name\":\"terrainCellsAreCubes\",\"Default\":\"false\"},{\"Type\":\"bool\",\"Name\":\"ignoreWater\",\"Default\":\"false\"}],\"Name\":\"FindPartOnRay\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Ray\",\"Name\":\"ray\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"ignoreDescendantsTable\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"terrainCellsAreCubes\",\"Default\":\"false\"},{\"Type\":\"bool\",\"Name\":\"ignoreWater\",\"Default\":\"false\"}],\"Name\":\"FindPartOnRayWithIgnoreList\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Ray\",\"Name\":\"ray\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"whitelistDescendantsTable\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"ignoreWater\",\"Default\":\"false\"}],\"Name\":\"FindPartOnRayWithWhitelist\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"ignoreDescendantsInstance\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"maxParts\",\"Default\":\"20\"}],\"Name\":\"FindPartsInRegion3\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"ignoreDescendantsTable\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"maxParts\",\"Default\":\"20\"}],\"Name\":\"FindPartsInRegion3WithIgnoreList\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"whitelistDescendantsTable\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"maxParts\",\"Default\":\"20\"}],\"Name\":\"FindPartsInRegion3WithWhiteList\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetNumAwakeParts\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetPhysicsAnalyzerBreakOnIssue\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"index\",\"Default\":null}],\"Name\":\"GetPhysicsAnalyzerIssue\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetPhysicsThrottling\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[],\"Name\":\"GetRealPhysicsFPS\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"ignoreDescendentsInstance\",\"Default\":\"nil\"}],\"Name\":\"IsRegion3Empty\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"ignoreDescendentsTable\",\"Default\":null}],\"Name\":\"IsRegion3EmptyWithIgnoreList\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null},{\"Type\":\"JointCreationMode\",\"Name\":\"jointType\",\"Default\":null}],\"Name\":\"JoinToOutsiders\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"MakeJoints\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"PGSIsEnabled\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enable\",\"Default\":null}],\"Name\":\"SetPhysicsAnalyzerBreakOnIssue\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetPhysicsThrottleEnabled\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"UnjoinFromOutsiders\",\"tags\":[],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ZoomToExtents\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Ray\",\"Name\":\"ray\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"ignoreDescendantsInstance\",\"Default\":\"nil\"},{\"Type\":\"bool\",\"Name\":\"terrainCellsAreCubes\",\"Default\":\"false\"},{\"Type\":\"bool\",\"Name\":\"ignoreWater\",\"Default\":\"false\"}],\"Name\":\"findPartOnRay\",\"tags\":[\"deprecated\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Region3\",\"Name\":\"region\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"ignoreDescendantsInstance\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"maxParts\",\"Default\":\"20\"}],\"Name\":\"findPartsInRegion3\",\"tags\":[\"deprecated\"],\"Class\":\"Workspace\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"count\",\"Type\":\"int\"}],\"Name\":\"PhysicsAnalyzerIssuesFound\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Workspace\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PackageLink\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"PackageId\",\"tags\":[\"readonly\"],\"Class\":\"PackageLink\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"VersionNumber\",\"tags\":[\"readonly\"],\"Class\":\"PackageLink\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Pages\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsFinished\",\"tags\":[\"readonly\"],\"Class\":\"Pages\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetCurrentPage\",\"tags\":[],\"Class\":\"Pages\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"AdvanceToNextPageAsync\",\"tags\":[],\"Class\":\"Pages\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Pages\",\"type\":\"Class\",\"Name\":\"DataStorePages\",\"tags\":[]},{\"Superclass\":\"Pages\",\"type\":\"Class\",\"Name\":\"FriendPages\",\"tags\":[]},{\"Superclass\":\"Pages\",\"type\":\"Class\",\"Name\":\"InventoryPages\",\"tags\":[]},{\"Superclass\":\"Pages\",\"type\":\"Class\",\"Name\":\"StandardPages\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PartOperationAsset\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ParticleEmitter\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Acceleration\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"ColorSequence\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Drag\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NormalId\",\"type\":\"Property\",\"Name\":\"EmissionDirection\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberRange\",\"type\":\"Property\",\"Name\":\"Lifetime\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightEmission\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightInfluence\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LockedToPart\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Rate\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberRange\",\"type\":\"Property\",\"Name\":\"RotSpeed\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberRange\",\"type\":\"Property\",\"Name\":\"Rotation\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberSequence\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberRange\",\"type\":\"Property\",\"Name\":\"Speed\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"SpreadAngle\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Texture\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"NumberSequence\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"VelocityInheritance\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"VelocitySpread\",\"tags\":[\"deprecated\"],\"Class\":\"ParticleEmitter\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ZOffset\",\"tags\":[],\"Class\":\"ParticleEmitter\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Clear\",\"tags\":[],\"Class\":\"ParticleEmitter\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"particleCount\",\"Default\":\"16\"}],\"Name\":\"Emit\",\"tags\":[],\"Class\":\"ParticleEmitter\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Path\",\"tags\":[]},{\"ValueType\":\"PathStatus\",\"type\":\"Property\",\"Name\":\"Status\",\"tags\":[\"readonly\"],\"Class\":\"Path\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetPointCoordinates\",\"tags\":[\"deprecated\"],\"Class\":\"Path\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetWaypoints\",\"tags\":[],\"Class\":\"Path\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"start\",\"Default\":null}],\"Name\":\"CheckOcclusionAsync\",\"tags\":[],\"Class\":\"Path\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PathfindingService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"EmptyCutoff\",\"tags\":[\"deprecated\"],\"Class\":\"PathfindingService\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"start\",\"Default\":null},{\"Type\":\"Vector3\",\"Name\":\"finish\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"maxDistance\",\"Default\":null}],\"Name\":\"ComputeRawPathAsync\",\"tags\":[\"deprecated\"],\"Class\":\"PathfindingService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"start\",\"Default\":null},{\"Type\":\"Vector3\",\"Name\":\"finish\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"maxDistance\",\"Default\":null}],\"Name\":\"ComputeSmoothPathAsync\",\"tags\":[\"deprecated\"],\"Class\":\"PathfindingService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"start\",\"Default\":null},{\"Type\":\"Vector3\",\"Name\":\"finish\",\"Default\":null}],\"Name\":\"FindPathAsync\",\"tags\":[],\"Class\":\"PathfindingService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PhysicsPacketCache\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PhysicsService\",\"tags\":[]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null}],\"Name\":\"CollisionGroupContainsPart\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name1\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"name2\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"collidable\",\"Default\":null}],\"Name\":\"CollisionGroupSetCollidable\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name1\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"name2\",\"Default\":null}],\"Name\":\"CollisionGroupsAreCollidable\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"CreateCollisionGroup\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"GetCollisionGroupId\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"GetCollisionGroupName\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetCollisionGroups\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetMaxCollisionGroups\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"translateStiffness\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"rotateStiffness\",\"Default\":null}],\"Name\":\"IkSolve\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"target\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"translateStiffness\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"rotateStiffness\",\"Default\":null}],\"Name\":\"LocalIkSolve\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"RemoveCollisionGroup\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"from\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"to\",\"Default\":null}],\"Name\":\"RenameCollisionGroup\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"part\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"SetPartCollisionGroup\",\"tags\":[],\"Class\":\"PhysicsService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PhysicsSettings\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllowSleep\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreAnchorsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreAssembliesShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreAwakePartsHighlighted\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreBodyTypesShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreContactIslandsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreContactPointsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreJointCoordinatesShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreMechanismsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreModelCoordsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreOwnersShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ArePartCoordsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreRegionsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreUnalignedPartsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AreWorldCoordsShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"DisableCSGv2\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsReceiveAgeShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsTreeShown\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PhysicsAnalyzerEnabled\",\"tags\":[\"PluginSecurity\",\"readonly\"],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"EnviromentalPhysicsThrottle\",\"type\":\"Property\",\"Name\":\"PhysicsEnvironmentalThrottle\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShowDecompositionGeometry\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"ThrottleAdjustTime\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UseCSGv2\",\"tags\":[],\"Class\":\"PhysicsSettings\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Player\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"AccountAge\",\"tags\":[\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AppearanceDidLoad\",\"tags\":[\"RobloxScriptSecurity\",\"deprecated\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoJumpEnabled\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CameraMaxZoomDistance\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CameraMinZoomDistance\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"CameraMode\",\"type\":\"Property\",\"Name\":\"CameraMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CanLoadCharacterAppearance\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"Class:Model\",\"type\":\"Property\",\"Name\":\"Character\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"CharacterAppearance\",\"tags\":[\"deprecated\",\"notbrowsable\"],\"Class\":\"Player\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"CharacterAppearanceId\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"ChatMode\",\"type\":\"Property\",\"Name\":\"ChatMode\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DataComplexity\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"DataComplexityLimit\",\"tags\":[\"LocalUserSecurity\",\"deprecated\"],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"DataReady\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"DevCameraOcclusionMode\",\"type\":\"Property\",\"Name\":\"DevCameraOcclusionMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"DevComputerCameraMovementMode\",\"type\":\"Property\",\"Name\":\"DevComputerCameraMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"DevComputerMovementMode\",\"type\":\"Property\",\"Name\":\"DevComputerMovementMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"DevEnableMouseLock\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"DevTouchCameraMovementMode\",\"type\":\"Property\",\"Name\":\"DevTouchCameraMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"DevTouchMovementMode\",\"type\":\"Property\",\"Name\":\"DevTouchMovementMode\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"DisplayName\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"FollowUserId\",\"tags\":[\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Guest\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HealthDisplayDistance\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"LocaleId\",\"tags\":[\"hidden\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaximumSimulationRadius\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"MembershipType\",\"type\":\"Property\",\"Name\":\"MembershipType\",\"tags\":[\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"NameDisplayDistance\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Neutral\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"OsPlatform\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"ReplicationFocus\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"Class:SpawnLocation\",\"type\":\"Property\",\"Name\":\"RespawnLocation\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SimulationRadius\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"Class:Team\",\"type\":\"Property\",\"Name\":\"Team\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TeamColor\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Teleported\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\",\"readonly\"],\"Class\":\"Player\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TeleportedIn\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"UserId\",\"tags\":[],\"Class\":\"Player\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"VRDevice\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"userId\",\"tags\":[\"deprecated\"],\"Class\":\"Player\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Array\",\"Name\":\"userIds\",\"Default\":null}],\"Name\":\"AddToBlockList\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearCharacterAppearance\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"point\",\"Default\":null}],\"Name\":\"DistanceFromCharacter\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"FriendStatus\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"GetFriendStatus\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetGameSessionID\",\"tags\":[\"RobloxSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetJoinData\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetMouse\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetUnder13\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"HasAppearanceLoaded\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsUserAvailableForExperiment\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":\"\"}],\"Name\":\"Kick\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"LoadBoolean\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"assetInstance\",\"Default\":null}],\"Name\":\"LoadCharacterAppearance\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"LoadData\",\"tags\":[\"LocalUserSecurity\",\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"LoadInstance\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"LoadNumber\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"LoadString\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector3\",\"Name\":\"walkDirection\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"relativeToCamera\",\"Default\":\"false\"}],\"Name\":\"Move\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RemoveCharacter\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"RequestFriendship\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"RevokeFriendship\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SaveBoolean\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SaveData\",\"tags\":[\"LocalUserSecurity\",\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SaveInstance\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SaveNumber\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SaveString\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"accountAge\",\"Default\":null}],\"Name\":\"SetAccountAge\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"MembershipType\",\"Name\":\"membershipType\",\"Default\":null}],\"Name\":\"SetMembershipType\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetSuperSafeChat\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetUnder13\",\"tags\":[\"RobloxSecurity\",\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"blocked\",\"Default\":null}],\"Name\":\"UpdatePlayerBlocked\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"loadBoolean\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"loadInstance\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"loadNumber\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"loadString\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"saveBoolean\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"saveInstance\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"saveNumber\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"saveString\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"maxFriends\",\"Default\":\"200\"}],\"Name\":\"GetFriendsOnline\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"GetRankInGroup\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"GetRoleInGroup\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"IsBestFriendsWith\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"IsFriendsWith\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"groupId\",\"Default\":null}],\"Name\":\"IsInGroup\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"LoadCharacter\",\"tags\":[],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"LoadCharacterBlocking\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"WaitForDataReady\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"isFriendsWith\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"waitForDataReady\",\"tags\":[\"deprecated\"],\"Class\":\"Player\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"character\",\"Type\":\"Instance\"}],\"Name\":\"CharacterAdded\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"character\",\"Type\":\"Instance\"}],\"Name\":\"CharacterAppearanceLoaded\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"character\",\"Type\":\"Instance\"}],\"Name\":\"CharacterRemoving\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"recipient\",\"Type\":\"Instance\"}],\"Name\":\"Chatted\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"friendStatus\",\"Type\":\"FriendStatus\"}],\"Name\":\"FriendStatusChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"time\",\"Type\":\"double\"}],\"Name\":\"Idled\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"teleportState\",\"Type\":\"TeleportState\"},{\"Name\":\"placeId\",\"Type\":\"int64\"},{\"Name\":\"spawnName\",\"Type\":\"string\"}],\"Name\":\"OnTeleport\",\"tags\":[],\"Class\":\"Player\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"radius\",\"Type\":\"float\"}],\"Name\":\"SimulationRadiusChanged\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Player\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PlayerScripts\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearComputerCameraMovementModes\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearComputerMovementModes\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearTouchCameraMovementModes\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ClearTouchMovementModes\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetRegisteredComputerCameraMovementModes\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetRegisteredComputerMovementModes\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetRegisteredTouchCameraMovementModes\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetRegisteredTouchMovementModes\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"ComputerCameraMovementMode\",\"Name\":\"cameraMovementMode\",\"Default\":null}],\"Name\":\"RegisterComputerCameraMovementMode\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"ComputerMovementMode\",\"Name\":\"movementMode\",\"Default\":null}],\"Name\":\"RegisterComputerMovementMode\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"TouchCameraMovementMode\",\"Name\":\"cameraMovementMode\",\"Default\":null}],\"Name\":\"RegisterTouchCameraMovementMode\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"TouchMovementMode\",\"Name\":\"movementMode\",\"Default\":null}],\"Name\":\"RegisterTouchMovementMode\",\"tags\":[],\"Class\":\"PlayerScripts\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"ComputerCameraMovementModeRegistered\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"ComputerMovementModeRegistered\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"TouchCameraMovementModeRegistered\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"TouchMovementModeRegistered\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"PlayerScripts\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Players\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"BubbleChat\",\"tags\":[\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CharacterAutoLoads\",\"tags\":[],\"Class\":\"Players\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ClassicChat\",\"tags\":[\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"LocalPlayer\",\"tags\":[\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MaxPlayers\",\"tags\":[\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MaxPlayersInternal\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"NumPlayers\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PreferredPlayers\",\"tags\":[\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PreferredPlayersInternal\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"localPlayer\",\"tags\":[\"deprecated\",\"hidden\",\"readonly\"],\"Class\":\"Players\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"numPlayers\",\"tags\":[\"deprecated\",\"hidden\",\"readonly\"],\"Class\":\"Players\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":null}],\"Name\":\"Chat\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"CreateLocalPlayer\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetPlayerByUserId\",\"tags\":[],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"character\",\"Default\":null}],\"Name\":\"GetPlayerFromCharacter\",\"tags\":[],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetPlayers\",\"tags\":[],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"reason\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"optionalMessage\",\"Default\":null}],\"Name\":\"ReportAbuse\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"ChatStyle\",\"Name\":\"style\",\"Default\":\"Classic\"}],\"Name\":\"SetChatStyle\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":null}],\"Name\":\"TeamChat\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"message\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null}],\"Name\":\"WhisperChat\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"character\",\"Default\":null}],\"Name\":\"getPlayerFromCharacter\",\"tags\":[\"deprecated\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"getPlayers\",\"tags\":[\"deprecated\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"character\",\"Default\":null}],\"Name\":\"playerFromCharacter\",\"tags\":[\"deprecated\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"players\",\"tags\":[\"deprecated\"],\"Class\":\"Players\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetCharacterAppearanceAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetCharacterAppearanceInfoAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetFriendsAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetNameFromUserIdAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"userName\",\"Default\":null}],\"Name\":\"GetUserIdFromNameAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"ThumbnailType\",\"Name\":\"thumbnailType\",\"Default\":null},{\"Type\":\"ThumbnailSize\",\"Name\":\"thumbnailSize\",\"Default\":null}],\"Name\":\"GetUserThumbnailAsync\",\"tags\":[],\"Class\":\"Players\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"friendRequestEvent\",\"Type\":\"FriendRequestEvent\"}],\"Name\":\"FriendRequestEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"}],\"Name\":\"GameAnnounce\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerAdded\",\"tags\":[],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"chatType\",\"Type\":\"PlayerChatType\"},{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"targetPlayer\",\"Type\":\"Instance\"}],\"Name\":\"PlayerChatted\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerConnecting\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerDisconnecting\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerRejoining\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"Players\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerRemoving\",\"tags\":[],\"Class\":\"Players\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Plugin\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CollisionEnabled\",\"tags\":[\"readonly\"],\"Class\":\"Plugin\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"GridSize\",\"tags\":[\"readonly\"],\"Class\":\"Plugin\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsesAssetInsertionDrag\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"exclusiveMouse\",\"Default\":null}],\"Name\":\"Activate\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"actionId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"statusTip\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"iconName\",\"Default\":\"\"}],\"Name\":\"CreatePluginAction\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"CreateToolbar\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Deactivate\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"JointCreationMode\",\"Arguments\":[],\"Name\":\"GetJoinMode\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetMouse\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"RibbonTool\",\"Arguments\":[],\"Name\":\"GetSelectedRibbonTool\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"GetSetting\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"int64\",\"Arguments\":[],\"Name\":\"GetStudioUserId\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"rigModel\",\"Default\":null}],\"Name\":\"ImportFbxAnimation\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsActivated\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsActivatedWithExclusiveMouse\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"Negate\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"script\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"lineNumber\",\"Default\":\"1\"}],\"Name\":\"OpenScript\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null}],\"Name\":\"OpenWikiPage\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"soundChannel\",\"Default\":null}],\"Name\":\"PauseSound\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"soundChannel\",\"Default\":null}],\"Name\":\"PlaySound\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"soundChannel\",\"Default\":null}],\"Name\":\"ResumeSound\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SaveSelectedToRoblox\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"RibbonTool\",\"Name\":\"tool\",\"Default\":null},{\"Type\":\"UDim2\",\"Name\":\"position\",\"Default\":null}],\"Name\":\"SelectRibbonTool\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"Separate\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetSetting\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"decal\",\"Default\":null}],\"Name\":\"StartDecalDrag\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"PluginDrag\",\"Name\":\"drag\",\"Default\":null}],\"Name\":\"StartDrag\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StopAllSounds\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"objects\",\"Default\":null}],\"Name\":\"Union\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"pluginGuiId\",\"Default\":null},{\"Type\":\"DockWidgetPluginGuiInfo\",\"Name\":\"dockWidgetPluginGuiInfo\",\"Default\":null}],\"Name\":\"CreateDockWidgetPluginGui\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"pluginGuiId\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"pluginGuiOptions\",\"Default\":null}],\"Name\":\"CreateQWidgetPluginGui\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Plugin\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"ImportFbxRig\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int64\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"assetType\",\"Default\":null}],\"Name\":\"PromptForExistingAssetId\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"suggestedFileName\",\"Default\":\"\"}],\"Name\":\"PromptSaveSelection\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"YieldFunction\"},{\"Arguments\":[],\"Name\":\"Deactivation\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Plugin\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PluginAction\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ActionId\",\"tags\":[\"readonly\"],\"Class\":\"PluginAction\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"StatusTip\",\"tags\":[\"readonly\"],\"Class\":\"PluginAction\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Text\",\"tags\":[\"readonly\"],\"Class\":\"PluginAction\"},{\"Arguments\":[],\"Name\":\"Triggered\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginAction\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PluginGuiService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PluginManager\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"CreatePlugin\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"filePath\",\"Default\":\"\"}],\"Name\":\"ExportPlace\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"filePath\",\"Default\":\"\"}],\"Name\":\"ExportSelection\",\"tags\":[\"PluginSecurity\"],\"Class\":\"PluginManager\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PointsService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetAwardablePoints\",\"tags\":[\"deprecated\"],\"Class\":\"PointsService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"amount\",\"Default\":null}],\"Name\":\"AwardPoints\",\"tags\":[],\"Class\":\"PointsService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetGamePointBalance\",\"tags\":[],\"Class\":\"PointsService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetPointBalance\",\"tags\":[\"deprecated\"],\"Class\":\"PointsService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"userId\",\"Type\":\"int64\"},{\"Name\":\"pointsAwarded\",\"Type\":\"int\"},{\"Name\":\"userBalanceInGame\",\"Type\":\"int\"},{\"Name\":\"userTotalBalance\",\"Type\":\"int\"}],\"Name\":\"PointsAwarded\",\"tags\":[],\"Class\":\"PointsService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Pose\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"Pose\"},{\"ValueType\":\"PoseEasingDirection\",\"type\":\"Property\",\"Name\":\"EasingDirection\",\"tags\":[],\"Class\":\"Pose\"},{\"ValueType\":\"PoseEasingStyle\",\"type\":\"Property\",\"Name\":\"EasingStyle\",\"tags\":[],\"Class\":\"Pose\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaskWeight\",\"tags\":[\"deprecated\"],\"Class\":\"Pose\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Weight\",\"tags\":[],\"Class\":\"Pose\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"pose\",\"Default\":null}],\"Name\":\"AddSubPose\",\"tags\":[],\"Class\":\"Pose\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetSubPoses\",\"tags\":[],\"Class\":\"Pose\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"pose\",\"Default\":null}],\"Name\":\"RemoveSubPose\",\"tags\":[],\"Class\":\"Pose\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"PostEffect\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"PostEffect\"},{\"Superclass\":\"PostEffect\",\"type\":\"Class\",\"Name\":\"BloomEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Intensity\",\"tags\":[],\"Class\":\"BloomEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"BloomEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Threshold\",\"tags\":[],\"Class\":\"BloomEffect\"},{\"Superclass\":\"PostEffect\",\"type\":\"Class\",\"Name\":\"BlurEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"BlurEffect\"},{\"Superclass\":\"PostEffect\",\"type\":\"Class\",\"Name\":\"ColorCorrectionEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Brightness\",\"tags\":[],\"Class\":\"ColorCorrectionEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Contrast\",\"tags\":[],\"Class\":\"ColorCorrectionEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Saturation\",\"tags\":[],\"Class\":\"ColorCorrectionEffect\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"TintColor\",\"tags\":[],\"Class\":\"ColorCorrectionEffect\"},{\"Superclass\":\"PostEffect\",\"type\":\"Class\",\"Name\":\"SunRaysEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Intensity\",\"tags\":[],\"Class\":\"SunRaysEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Spread\",\"tags\":[],\"Class\":\"SunRaysEffect\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadata\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataCallbacks\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataClasses\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataEnums\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataEvents\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataFunctions\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataItem\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Browsable\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ClassCategory\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Constraint\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Deprecated\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"EditingDisabled\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsBackend\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"ScriptContext\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"UIMaximum\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"UIMinimum\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"UINumTicks\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"summary\",\"tags\":[],\"Class\":\"ReflectionMetadataItem\"},{\"Superclass\":\"ReflectionMetadataItem\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataClass\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ExplorerImageIndex\",\"tags\":[],\"Class\":\"ReflectionMetadataClass\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ExplorerOrder\",\"tags\":[],\"Class\":\"ReflectionMetadataClass\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Insertable\",\"tags\":[],\"Class\":\"ReflectionMetadataClass\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"PreferredParent\",\"tags\":[],\"Class\":\"ReflectionMetadataClass\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"PreferredParents\",\"tags\":[],\"Class\":\"ReflectionMetadataClass\"},{\"Superclass\":\"ReflectionMetadataItem\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataEnum\",\"tags\":[]},{\"Superclass\":\"ReflectionMetadataItem\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataEnumItem\",\"tags\":[]},{\"Superclass\":\"ReflectionMetadataItem\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataMember\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataProperties\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReflectionMetadataYieldFunctions\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RemoteEvent\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"FireAllClients\",\"tags\":[],\"Class\":\"RemoteEvent\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"FireClient\",\"tags\":[],\"Class\":\"RemoteEvent\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"FireServer\",\"tags\":[],\"Class\":\"RemoteEvent\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"OnClientEvent\",\"tags\":[],\"Class\":\"RemoteEvent\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"OnServerEvent\",\"tags\":[],\"Class\":\"RemoteEvent\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RemoteFunction\",\"tags\":[]},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"InvokeClient\",\"tags\":[],\"Class\":\"RemoteFunction\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"Tuple\",\"Name\":\"arguments\",\"Default\":null}],\"Name\":\"InvokeServer\",\"tags\":[],\"Class\":\"RemoteFunction\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"OnClientInvoke\",\"tags\":[],\"Class\":\"RemoteFunction\",\"type\":\"Callback\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"arguments\",\"Type\":\"Tuple\"}],\"Name\":\"OnServerInvoke\",\"tags\":[],\"Class\":\"RemoteFunction\",\"type\":\"Callback\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RenderSettings\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"AutoFRMLevel\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"EagerBulkExecution\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"QualityLevel\",\"type\":\"Property\",\"Name\":\"EditQualityLevel\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"EnableFRM\",\"tags\":[\"hidden\"],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ExportMergeByMaterial\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"FramerateManagerMode\",\"type\":\"Property\",\"Name\":\"FrameRateManager\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"GraphicsMode\",\"type\":\"Property\",\"Name\":\"GraphicsMode\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MeshCacheSize\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"QualityLevel\",\"type\":\"Property\",\"Name\":\"QualityLevel\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ReloadAssets\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RenderCSGTrianglesDebug\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShowBoundingBoxes\",\"tags\":[],\"Class\":\"RenderSettings\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetMaxQualityLevel\",\"tags\":[],\"Class\":\"RenderSettings\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RenderingTest\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"CFrame\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ComparisonDiffThreshold\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"RenderingTestComparisonMethod\",\"type\":\"Property\",\"Name\":\"ComparisonMethod\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"ComparisonPsnrThreshold\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Description\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"FieldOfView\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Orientation\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Position\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"QualityLevel\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ShouldSkip\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Ticket\",\"tags\":[],\"Class\":\"RenderingTest\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReplicatedFirst\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsDefaultLoadingGuiRemoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsFinishedReplicating\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RemoveDefaultLoadingScreen\",\"tags\":[],\"Class\":\"ReplicatedFirst\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SetDefaultLoadingGuiRemoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"DefaultLoadingGuiRemoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"FinishedReplicating\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"RemoveDefaultLoadingGuiSignal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ReplicatedFirst\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ReplicatedStorage\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RobloxReplicatedStorage\",\"tags\":[\"notCreatable\",\"notbrowsable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RunService\",\"tags\":[]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"priority\",\"Default\":null},{\"Type\":\"Function\",\"Name\":\"function\",\"Default\":null}],\"Name\":\"BindToRenderStep\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetRobloxVersion\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsClient\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsEdit\",\"tags\":[\"PluginSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsRunMode\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsRunning\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsServer\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsStudio\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Pause\",\"tags\":[\"PluginSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Reset\",\"tags\":[\"PluginSecurity\",\"deprecated\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Run\",\"tags\":[\"PluginSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enable\",\"Default\":null}],\"Name\":\"Set3dRenderingEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"focus\",\"Default\":null}],\"Name\":\"SetRobloxGuiFocused\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Stop\",\"tags\":[\"PluginSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"UnbindFromRenderStep\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"enable\",\"Default\":null}],\"Name\":\"setThrottleFramerateEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"RunService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"step\",\"Type\":\"double\"}],\"Name\":\"Heartbeat\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"step\",\"Type\":\"double\"}],\"Name\":\"RenderStepped\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"time\",\"Type\":\"double\"},{\"Name\":\"step\",\"Type\":\"double\"}],\"Name\":\"Stepped\",\"tags\":[],\"Class\":\"RunService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"RuntimeScriptService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ScriptContext\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ScriptsDisabled\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"ScriptContext\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"parent\",\"Default\":null}],\"Name\":\"AddCoreScriptLocal\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ScriptContext\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"double\",\"Name\":\"seconds\",\"Default\":null}],\"Name\":\"SetTimeout\",\"tags\":[\"PluginSecurity\"],\"Class\":\"ScriptContext\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"message\",\"Type\":\"string\"},{\"Name\":\"stackTrace\",\"Type\":\"string\"},{\"Name\":\"script\",\"Type\":\"Instance\"}],\"Name\":\"Error\",\"tags\":[],\"Class\":\"ScriptContext\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ScriptDebugger\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"CurrentLine\",\"tags\":[\"readonly\"],\"Class\":\"ScriptDebugger\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsDebugging\",\"tags\":[\"readonly\"],\"Class\":\"ScriptDebugger\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsPaused\",\"tags\":[\"readonly\"],\"Class\":\"ScriptDebugger\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Script\",\"tags\":[\"readonly\"],\"Class\":\"ScriptDebugger\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"expression\",\"Default\":null}],\"Name\":\"AddWatch\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetBreakpoints\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Map\",\"Arguments\":[],\"Name\":\"GetGlobals\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Map\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"stackFrame\",\"Default\":\"0\"}],\"Name\":\"GetLocals\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetStack\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Map\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"stackFrame\",\"Default\":\"0\"}],\"Name\":\"GetUpvalues\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"watch\",\"Default\":null}],\"Name\":\"GetWatchValue\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetWatches\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Resume\",\"tags\":[\"deprecated\"],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"line\",\"Default\":null}],\"Name\":\"SetBreakpoint\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetGlobal\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"stackFrame\",\"Default\":\"0\"}],\"Name\":\"SetLocal\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"stackFrame\",\"Default\":\"0\"}],\"Name\":\"SetUpvalue\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepIn\",\"tags\":[\"deprecated\"],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepOut\",\"tags\":[\"deprecated\"],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StepOver\",\"tags\":[\"deprecated\"],\"Class\":\"ScriptDebugger\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"breakpoint\",\"Type\":\"Instance\"}],\"Name\":\"BreakpointAdded\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"breakpoint\",\"Type\":\"Instance\"}],\"Name\":\"BreakpointRemoved\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"line\",\"Type\":\"int\"}],\"Name\":\"EncounteredBreak\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Resuming\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"watch\",\"Type\":\"Instance\"}],\"Name\":\"WatchAdded\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"watch\",\"Type\":\"Instance\"}],\"Name\":\"WatchRemoved\",\"tags\":[],\"Class\":\"ScriptDebugger\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ScriptService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Selection\",\"tags\":[]},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"Get\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Selection\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Objects\",\"Name\":\"selection\",\"Default\":null}],\"Name\":\"Set\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Selection\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"SelectionChanged\",\"tags\":[],\"Class\":\"Selection\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ServerScriptService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ServerStorage\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ServiceProvider\",\"tags\":[\"notbrowsable\"]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"FindService\",\"tags\":[],\"Class\":\"ServiceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"GetService\",\"tags\":[],\"Class\":\"ServiceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"getService\",\"tags\":[\"deprecated\"],\"Class\":\"ServiceProvider\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"className\",\"Default\":null}],\"Name\":\"service\",\"tags\":[\"deprecated\"],\"Class\":\"ServiceProvider\",\"type\":\"Function\"},{\"Arguments\":[],\"Name\":\"Close\",\"tags\":[],\"Class\":\"ServiceProvider\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"CloseLate\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"ServiceProvider\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"service\",\"Type\":\"Instance\"}],\"Name\":\"ServiceAdded\",\"tags\":[],\"Class\":\"ServiceProvider\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"service\",\"Type\":\"Instance\"}],\"Name\":\"ServiceRemoving\",\"tags\":[],\"Class\":\"ServiceProvider\",\"type\":\"Event\"},{\"Superclass\":\"ServiceProvider\",\"type\":\"Class\",\"Name\":\"DataModel\",\"tags\":[]},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"CreatorId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"CreatorType\",\"type\":\"Property\",\"Name\":\"CreatorType\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"GameId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"GearGenreSetting\",\"type\":\"Property\",\"Name\":\"GearGenreSetting\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"Genre\",\"type\":\"Property\",\"Name\":\"Genre\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsSFFlagsLoaded\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"JobId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"PlaceId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PlaceVersion\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"PrivateServerId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"PrivateServerOwnerId\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"VIPServerId\",\"tags\":[\"deprecated\",\"hidden\",\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"VIPServerOwnerId\",\"tags\":[\"deprecated\",\"hidden\",\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"Class:Workspace\",\"type\":\"Property\",\"Name\":\"Workspace\",\"tags\":[\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"lighting\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"DataModel\"},{\"ValueType\":\"Class:Workspace\",\"type\":\"Property\",\"Name\":\"workspace\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"DataModel\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Function\",\"Name\":\"function\",\"Default\":null}],\"Name\":\"BindToClose\",\"tags\":[],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"jobname\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"greaterThan\",\"Default\":null}],\"Name\":\"GetJobIntervalPeakFraction\",\"tags\":[\"PluginSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"double\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"jobname\",\"Default\":null},{\"Type\":\"double\",\"Name\":\"greaterThan\",\"Default\":null}],\"Name\":\"GetJobTimePeakFraction\",\"tags\":[\"PluginSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetJobsExtendedStats\",\"tags\":[\"PluginSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetJobsInfo\",\"tags\":[\"PluginSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetMessage\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"GetRemoteBuildMode\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"GearType\",\"Name\":\"gearType\",\"Default\":null}],\"Name\":\"IsGearTypeAllowed\",\"tags\":[],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"IsLoaded\",\"tags\":[],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Content\",\"Name\":\"url\",\"Default\":null}],\"Name\":\"Load\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"OpenScreenshotsFolder\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"OpenVideosFolder\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"category\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"action\",\"Default\":\"custom\"},{\"Type\":\"string\",\"Name\":\"label\",\"Default\":\"none\"},{\"Type\":\"int\",\"Name\":\"value\",\"Default\":\"0\"}],\"Name\":\"ReportInGoogleAnalytics\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Shutdown\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"DataModel\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"HttpGetAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"url\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"data\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"contentType\",\"Default\":\"*/*\"},{\"Type\":\"HttpRequestType\",\"Name\":\"httpRequestType\",\"Default\":\"Default\"},{\"Type\":\"bool\",\"Name\":\"doNotAllowDiabolicalMode\",\"Default\":\"false\"}],\"Name\":\"HttpPostAsync\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"SaveFilter\",\"Name\":\"saveFilter\",\"Default\":\"SaveAll\"}],\"Name\":\"SavePlace\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"YieldFunction\"},{\"Arguments\":[],\"Name\":\"AllowedGearTypeChanged\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"betterQuality\",\"Type\":\"bool\"}],\"Name\":\"GraphicsQualityChangeRequest\",\"tags\":[],\"Class\":\"DataModel\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"object\",\"Type\":\"Instance\"},{\"Name\":\"descriptor\",\"Type\":\"Property\"}],\"Name\":\"ItemChanged\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"Loaded\",\"tags\":[],\"Class\":\"DataModel\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"path\",\"Type\":\"string\"}],\"Name\":\"ScreenshotReady\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"DataModel\",\"type\":\"Event\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"OnClose\",\"tags\":[\"deprecated\"],\"Class\":\"DataModel\",\"type\":\"Callback\"},{\"Superclass\":\"ServiceProvider\",\"type\":\"Class\",\"Name\":\"GenericSettings\",\"tags\":[]},{\"Superclass\":\"GenericSettings\",\"type\":\"Class\",\"Name\":\"AnalysticsSettings\",\"tags\":[]},{\"Superclass\":\"GenericSettings\",\"type\":\"Class\",\"Name\":\"GlobalSettings\",\"tags\":[\"notbrowsable\"]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"GetFFlag\",\"tags\":[],\"Class\":\"GlobalSettings\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"GetFVariable\",\"tags\":[],\"Class\":\"GlobalSettings\",\"type\":\"Function\"},{\"Superclass\":\"GenericSettings\",\"type\":\"Class\",\"Name\":\"UserSettings\",\"tags\":[]},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"name\",\"Default\":null}],\"Name\":\"IsUserFeatureEnabled\",\"tags\":[],\"Class\":\"UserSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Reset\",\"tags\":[],\"Class\":\"UserSettings\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Sky\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CelestialBodiesShown\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MoonAngularSize\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"MoonTextureId\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxBk\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxDn\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxFt\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxLf\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxRt\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SkyboxUp\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"StarCount\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"SunAngularSize\",\"tags\":[],\"Class\":\"Sky\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SunTextureId\",\"tags\":[],\"Class\":\"Sky\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Smoke\",\"tags\":[]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Smoke\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Smoke\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Opacity\",\"tags\":[],\"Class\":\"Smoke\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"RiseVelocity\",\"tags\":[],\"Class\":\"Smoke\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Size\",\"tags\":[],\"Class\":\"Smoke\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Sound\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"EmitterSize\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsLoaded\",\"tags\":[\"readonly\"],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsPaused\",\"tags\":[\"readonly\"],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsPlaying\",\"tags\":[\"readonly\"],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Looped\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxDistance\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MinDistance\",\"tags\":[\"deprecated\"],\"Class\":\"Sound\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Pitch\",\"tags\":[\"deprecated\"],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PlayOnRemove\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"PlaybackLoudness\",\"tags\":[\"readonly\"],\"Class\":\"Sound\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"PlaybackSpeed\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Playing\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"RollOffMode\",\"type\":\"Property\",\"Name\":\"RollOffMode\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"Class:SoundGroup\",\"type\":\"Property\",\"Name\":\"SoundGroup\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"SoundId\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"TimeLength\",\"tags\":[\"readonly\"],\"Class\":\"Sound\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"TimePosition\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Volume\",\"tags\":[],\"Class\":\"Sound\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"isPlaying\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"Sound\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Pause\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Play\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Resume\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Stop\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"pause\",\"tags\":[\"deprecated\"],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"play\",\"tags\":[\"deprecated\"],\"Class\":\"Sound\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"stop\",\"tags\":[\"deprecated\"],\"Class\":\"Sound\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"},{\"Name\":\"numOfTimesLooped\",\"Type\":\"int\"}],\"Name\":\"DidLoop\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Ended\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Loaded\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Paused\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Played\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Resumed\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"soundId\",\"Type\":\"string\"}],\"Name\":\"Stopped\",\"tags\":[],\"Class\":\"Sound\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"SoundEffect\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"SoundEffect\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Priority\",\"tags\":[],\"Class\":\"SoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"ChorusSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Depth\",\"tags\":[],\"Class\":\"ChorusSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Mix\",\"tags\":[],\"Class\":\"ChorusSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Rate\",\"tags\":[],\"Class\":\"ChorusSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"CompressorSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Attack\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"GainMakeup\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Ratio\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Release\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"SideChain\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Threshold\",\"tags\":[],\"Class\":\"CompressorSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"DistortionSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Level\",\"tags\":[],\"Class\":\"DistortionSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"EchoSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Delay\",\"tags\":[],\"Class\":\"EchoSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DryLevel\",\"tags\":[],\"Class\":\"EchoSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Feedback\",\"tags\":[],\"Class\":\"EchoSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WetLevel\",\"tags\":[],\"Class\":\"EchoSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"EqualizerSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HighGain\",\"tags\":[],\"Class\":\"EqualizerSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LowGain\",\"tags\":[],\"Class\":\"EqualizerSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MidGain\",\"tags\":[],\"Class\":\"EqualizerSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"FlangeSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Depth\",\"tags\":[],\"Class\":\"FlangeSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Mix\",\"tags\":[],\"Class\":\"FlangeSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Rate\",\"tags\":[],\"Class\":\"FlangeSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"PitchShiftSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Octave\",\"tags\":[],\"Class\":\"PitchShiftSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"ReverbSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DecayTime\",\"tags\":[],\"Class\":\"ReverbSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Density\",\"tags\":[],\"Class\":\"ReverbSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Diffusion\",\"tags\":[],\"Class\":\"ReverbSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DryLevel\",\"tags\":[],\"Class\":\"ReverbSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"WetLevel\",\"tags\":[],\"Class\":\"ReverbSoundEffect\"},{\"Superclass\":\"SoundEffect\",\"type\":\"Class\",\"Name\":\"TremoloSoundEffect\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Depth\",\"tags\":[],\"Class\":\"TremoloSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Duty\",\"tags\":[],\"Class\":\"TremoloSoundEffect\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Frequency\",\"tags\":[],\"Class\":\"TremoloSoundEffect\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"SoundGroup\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Volume\",\"tags\":[],\"Class\":\"SoundGroup\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"SoundService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"ReverbType\",\"type\":\"Property\",\"Name\":\"AmbientReverb\",\"tags\":[],\"Class\":\"SoundService\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DistanceFactor\",\"tags\":[],\"Class\":\"SoundService\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DopplerScale\",\"tags\":[],\"Class\":\"SoundService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"RespectFilteringEnabled\",\"tags\":[],\"Class\":\"SoundService\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"RolloffScale\",\"tags\":[],\"Class\":\"SoundService\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"BeginRecording\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"GetListener\",\"tags\":[],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"sound\",\"Default\":null}],\"Name\":\"PlayLocalSound\",\"tags\":[],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"SoundType\",\"Name\":\"sound\",\"Default\":null}],\"Name\":\"PlayStockSound\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"ListenerType\",\"Name\":\"listenerType\",\"Default\":null},{\"Type\":\"Tuple\",\"Name\":\"listener\",\"Default\":null}],\"Name\":\"SetListener\",\"tags\":[],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"deviceIndex\",\"Default\":null}],\"Name\":\"SetRecordingDevice\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"SoundService\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"EndRecording\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"SoundService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[],\"Name\":\"GetRecordingDevices\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"SoundService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Sparkles\",\"tags\":[]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[\"hidden\"],\"Class\":\"Sparkles\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Sparkles\"},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"SparkleColor\",\"tags\":[],\"Class\":\"Sparkles\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"SpawnerService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"StarterGear\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"StarterPlayer\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllowCustomAnimations\",\"tags\":[\"ScriptWriteRestricted: [NotAccessibleSecurity]\",\"hidden\"],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoJumpEnabled\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CameraMaxZoomDistance\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"CameraMinZoomDistance\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"CameraMode\",\"type\":\"Property\",\"Name\":\"CameraMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"DevCameraOcclusionMode\",\"type\":\"Property\",\"Name\":\"DevCameraOcclusionMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"DevComputerCameraMovementMode\",\"type\":\"Property\",\"Name\":\"DevComputerCameraMovementMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"DevComputerMovementMode\",\"type\":\"Property\",\"Name\":\"DevComputerMovementMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"DevTouchCameraMovementMode\",\"type\":\"Property\",\"Name\":\"DevTouchCameraMovementMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"DevTouchMovementMode\",\"type\":\"Property\",\"Name\":\"DevTouchMovementMode\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"EnableMouseLockOption\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HealthDisplayDistance\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LoadCharacterAppearance\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"NameDisplayDistance\",\"tags\":[],\"Class\":\"StarterPlayer\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"StarterPlayerScripts\",\"tags\":[]},{\"Superclass\":\"StarterPlayerScripts\",\"type\":\"Class\",\"Name\":\"StarterCharacterScripts\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Stats\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ContactsCount\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DataReceiveKbps\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"DataSendKbps\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"HeartbeatTimeMs\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"InstanceCount\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MovingPrimitivesCount\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"PhysicsReceiveKbps\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"PhysicsSendKbps\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"PhysicsStepTimeMs\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"PrimitivesCount\",\"tags\":[\"readonly\"],\"Class\":\"Stats\"},{\"ReturnType\":\"float\",\"Arguments\":[{\"Type\":\"DeveloperMemoryTag\",\"Name\":\"tag\",\"Default\":null}],\"Name\":\"GetMemoryUsageMbForTag\",\"tags\":[],\"Class\":\"Stats\",\"type\":\"Function\"},{\"ReturnType\":\"float\",\"Arguments\":[],\"Name\":\"GetTotalMemoryUsageMb\",\"tags\":[],\"Class\":\"Stats\",\"type\":\"Function\"},{\"ReturnType\":\"Dictionary\",\"Arguments\":[{\"Type\":\"TextureQueryType\",\"Name\":\"queryType\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"pageIndex\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"pageSize\",\"Default\":null}],\"Name\":\"GetPaginatedMemoryByTexture\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Stats\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"StatsItem\",\"tags\":[]},{\"ReturnType\":\"double\",\"Arguments\":[],\"Name\":\"GetValue\",\"tags\":[\"PluginSecurity\"],\"Class\":\"StatsItem\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetValueString\",\"tags\":[\"PluginSecurity\"],\"Class\":\"StatsItem\",\"type\":\"Function\"},{\"Superclass\":\"StatsItem\",\"type\":\"Class\",\"Name\":\"RunningAverageItemDouble\",\"tags\":[]},{\"Superclass\":\"StatsItem\",\"type\":\"Class\",\"Name\":\"RunningAverageItemInt\",\"tags\":[]},{\"Superclass\":\"StatsItem\",\"type\":\"Class\",\"Name\":\"RunningAverageTimeIntervalItem\",\"tags\":[]},{\"Superclass\":\"StatsItem\",\"type\":\"Class\",\"Name\":\"TotalCountTimeIntervalItem\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TaskScheduler\",\"tags\":[]},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"SchedulerDutyCycle\",\"tags\":[\"readonly\"],\"Class\":\"TaskScheduler\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"SchedulerRate\",\"tags\":[\"readonly\"],\"Class\":\"TaskScheduler\"},{\"ValueType\":\"ThreadPoolConfig\",\"type\":\"Property\",\"Name\":\"ThreadPoolConfig\",\"tags\":[],\"Class\":\"TaskScheduler\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ThreadPoolSize\",\"tags\":[\"readonly\"],\"Class\":\"TaskScheduler\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Team\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoAssignable\",\"tags\":[],\"Class\":\"Team\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoColorCharacters\",\"tags\":[\"deprecated\"],\"Class\":\"Team\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"Score\",\"tags\":[\"deprecated\"],\"Class\":\"Team\"},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"TeamColor\",\"tags\":[],\"Class\":\"Team\"},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetPlayers\",\"tags\":[],\"Class\":\"Team\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerAdded\",\"tags\":[],\"Class\":\"Team\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"}],\"Name\":\"PlayerRemoved\",\"tags\":[],\"Class\":\"Team\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Teams\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"Objects\",\"Arguments\":[],\"Name\":\"GetTeams\",\"tags\":[],\"Class\":\"Teams\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RebalanceTeams\",\"tags\":[\"deprecated\"],\"Class\":\"Teams\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TeleportService\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CustomizedTeleportUI\",\"tags\":[\"deprecated\"],\"Class\":\"TeleportService\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetArrivingTeleportGui\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[],\"Name\":\"GetLocalPlayerTeleportData\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"Variant\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"setting\",\"Default\":null}],\"Name\":\"GetTeleportSetting\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"gui\",\"Default\":null}],\"Name\":\"SetTeleportGui\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"setting\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetTeleportSetting\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":\"nil\"},{\"Type\":\"Variant\",\"Name\":\"teleportData\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"customLoadingScreen\",\"Default\":\"nil\"}],\"Name\":\"Teleport\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"TeleportCancel\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"instanceId\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":\"nil\"},{\"Type\":\"string\",\"Name\":\"spawnName\",\"Default\":\"\"},{\"Type\":\"Variant\",\"Name\":\"teleportData\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"customLoadingScreen\",\"Default\":\"nil\"}],\"Name\":\"TeleportToPlaceInstance\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"reservedServerAccessCode\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"players\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"spawnName\",\"Default\":\"\"},{\"Type\":\"Variant\",\"Name\":\"teleportData\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"customLoadingScreen\",\"Default\":\"nil\"}],\"Name\":\"TeleportToPrivateServer\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"spawnName\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"player\",\"Default\":\"nil\"},{\"Type\":\"Variant\",\"Name\":\"teleportData\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"customLoadingScreen\",\"Default\":\"nil\"}],\"Name\":\"TeleportToSpawnByName\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"userId\",\"Default\":null}],\"Name\":\"GetPlayerPlaceInstanceAsync\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null}],\"Name\":\"ReserveServer\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"placeId\",\"Default\":null},{\"Type\":\"Objects\",\"Name\":\"players\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"teleportData\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"customLoadingScreen\",\"Default\":\"nil\"}],\"Name\":\"TeleportPartyAsync\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"loadingGui\",\"Type\":\"Instance\"},{\"Name\":\"dataTable\",\"Type\":\"Variant\"}],\"Name\":\"LocalPlayerArrivedFromTeleport\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"player\",\"Type\":\"Instance\"},{\"Name\":\"teleportResult\",\"Type\":\"TeleportResult\"},{\"Name\":\"errorMessage\",\"Type\":\"string\"}],\"Name\":\"TeleportInitFailed\",\"tags\":[],\"Class\":\"TeleportService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TerrainRegion\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsSmooth\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"TerrainRegion\"},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"SizeInCells\",\"tags\":[\"readonly\"],\"Class\":\"TerrainRegion\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ConvertToSmooth\",\"tags\":[\"PluginSecurity\",\"deprecated\"],\"Class\":\"TerrainRegion\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TestService\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AutoRuns\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Description\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"ErrorCount\",\"tags\":[\"readonly\"],\"Class\":\"TestService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ExecuteWithStudioRun\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Is30FpsThrottleEnabled\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsPhysicsEnvironmentalThrottled\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsSleepAllowed\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"NumberOfPlayers\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"SimulateSecondsLag\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"TestCount\",\"tags\":[\"readonly\"],\"Class\":\"TestService\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"Timeout\",\"tags\":[],\"Class\":\"TestService\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"WarnCount\",\"tags\":[\"readonly\"],\"Class\":\"TestService\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"condition\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Check\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Checkpoint\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Done\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Error\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Fail\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Message\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"condition\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Require\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"condition\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"description\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"source\",\"Default\":\"nil\"},{\"Type\":\"int\",\"Name\":\"line\",\"Default\":\"0\"}],\"Name\":\"Warn\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Run\",\"tags\":[\"PluginSecurity\"],\"Class\":\"TestService\",\"type\":\"YieldFunction\"},{\"Arguments\":[{\"Name\":\"condition\",\"Type\":\"bool\"},{\"Name\":\"text\",\"Type\":\"string\"},{\"Name\":\"script\",\"Type\":\"Instance\"},{\"Name\":\"line\",\"Type\":\"int\"}],\"Name\":\"ServerCollectConditionalResult\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"text\",\"Type\":\"string\"},{\"Name\":\"script\",\"Type\":\"Instance\"},{\"Name\":\"line\",\"Type\":\"int\"}],\"Name\":\"ServerCollectResult\",\"tags\":[],\"Class\":\"TestService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TextFilterResult\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"toUserId\",\"Default\":null}],\"Name\":\"GetChatForUserAsync\",\"tags\":[],\"Class\":\"TextFilterResult\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetNonChatStringForBroadcastAsync\",\"tags\":[],\"Class\":\"TextFilterResult\",\"type\":\"YieldFunction\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"toUserId\",\"Default\":null}],\"Name\":\"GetNonChatStringForUserAsync\",\"tags\":[],\"Class\":\"TextFilterResult\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TextService\",\"tags\":[]},{\"ReturnType\":\"Vector2\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"string\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"fontSize\",\"Default\":null},{\"Type\":\"Font\",\"Name\":\"font\",\"Default\":null},{\"Type\":\"Vector2\",\"Name\":\"frameSize\",\"Default\":null}],\"Name\":\"GetTextSize\",\"tags\":[],\"Class\":\"TextService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"stringToFilter\",\"Default\":null},{\"Type\":\"int64\",\"Name\":\"fromUserId\",\"Default\":null},{\"Type\":\"TextFilterContext\",\"Name\":\"textContext\",\"Default\":\"PrivateChat\"}],\"Name\":\"FilterStringAsync\",\"tags\":[],\"Class\":\"TextService\",\"type\":\"YieldFunction\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ThirdPartyUserService\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetUserDisplayName\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"GetUserPlatformId\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"HaveActiveUser\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ReturnToEngagement\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ShowAccountPicker\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Function\"},{\"ReturnType\":\"int\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadId\",\"Default\":null}],\"Name\":\"RegisterActiveUser\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"YieldFunction\"},{\"Arguments\":[],\"Name\":\"ActiveGamepadAdded\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"ActiveGamepadRemoved\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"signOutStatus\",\"Type\":\"int\"}],\"Name\":\"ActiveUserSignedOut\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"ThirdPartyUserService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TimerService\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Toolbar\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"tooltip\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"iconname\",\"Default\":null}],\"Name\":\"CreateButton\",\"tags\":[\"PluginSecurity\"],\"Class\":\"Toolbar\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TouchInputService\",\"tags\":[]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TouchTransmitter\",\"tags\":[\"notCreatable\",\"notbrowsable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Trail\",\"tags\":[]},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment0\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"Class:Attachment\",\"type\":\"Property\",\"Name\":\"Attachment1\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"ColorSequence\",\"type\":\"Property\",\"Name\":\"Color\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"FaceCamera\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Lifetime\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightEmission\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"LightInfluence\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MaxLength\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MinLength\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"Content\",\"type\":\"Property\",\"Name\":\"Texture\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TextureLength\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"TextureMode\",\"type\":\"Property\",\"Name\":\"TextureMode\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"NumberSequence\",\"type\":\"Property\",\"Name\":\"Transparency\",\"tags\":[],\"Class\":\"Trail\"},{\"ValueType\":\"NumberSequence\",\"type\":\"Property\",\"Name\":\"WidthScale\",\"tags\":[],\"Class\":\"Trail\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Clear\",\"tags\":[],\"Class\":\"Trail\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Translator\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"LocaleId\",\"tags\":[\"readonly\"],\"Class\":\"Translator\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null},{\"Type\":\"Variant\",\"Name\":\"args\",\"Default\":null}],\"Name\":\"FormatByKey\",\"tags\":[],\"Class\":\"Translator\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"RobloxOnlyTranslate\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"Translator\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"context\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"text\",\"Default\":null}],\"Name\":\"Translate\",\"tags\":[],\"Class\":\"Translator\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TweenBase\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"PlaybackState\",\"type\":\"Property\",\"Name\":\"PlaybackState\",\"tags\":[\"readonly\"],\"Class\":\"TweenBase\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Cancel\",\"tags\":[],\"Class\":\"TweenBase\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Pause\",\"tags\":[],\"Class\":\"TweenBase\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Play\",\"tags\":[],\"Class\":\"TweenBase\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"playbackState\",\"Type\":\"PlaybackState\"}],\"Name\":\"Completed\",\"tags\":[],\"Class\":\"TweenBase\",\"type\":\"Event\"},{\"Superclass\":\"TweenBase\",\"type\":\"Class\",\"Name\":\"Tween\",\"tags\":[]},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Instance\",\"tags\":[\"readonly\"],\"Class\":\"Tween\"},{\"ValueType\":\"TweenInfo\",\"type\":\"Property\",\"Name\":\"TweenInfo\",\"tags\":[\"readonly\"],\"Class\":\"Tween\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"TweenService\",\"tags\":[]},{\"ReturnType\":\"Instance\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"instance\",\"Default\":null},{\"Type\":\"TweenInfo\",\"Name\":\"tweenInfo\",\"Default\":null},{\"Type\":\"Dictionary\",\"Name\":\"propertyTable\",\"Default\":null}],\"Name\":\"Create\",\"tags\":[],\"Class\":\"TweenService\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"UIBase\",\"tags\":[]},{\"Superclass\":\"UIBase\",\"type\":\"Class\",\"Name\":\"UIComponent\",\"tags\":[]},{\"Superclass\":\"UIComponent\",\"type\":\"Class\",\"Name\":\"UIConstraint\",\"tags\":[]},{\"Superclass\":\"UIConstraint\",\"type\":\"Class\",\"Name\":\"UIAspectRatioConstraint\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"AspectRatio\",\"tags\":[],\"Class\":\"UIAspectRatioConstraint\"},{\"ValueType\":\"AspectType\",\"type\":\"Property\",\"Name\":\"AspectType\",\"tags\":[],\"Class\":\"UIAspectRatioConstraint\"},{\"ValueType\":\"DominantAxis\",\"type\":\"Property\",\"Name\":\"DominantAxis\",\"tags\":[],\"Class\":\"UIAspectRatioConstraint\"},{\"Superclass\":\"UIConstraint\",\"type\":\"Class\",\"Name\":\"UISizeConstraint\",\"tags\":[]},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"MaxSize\",\"tags\":[],\"Class\":\"UISizeConstraint\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"MinSize\",\"tags\":[],\"Class\":\"UISizeConstraint\"},{\"Superclass\":\"UIConstraint\",\"type\":\"Class\",\"Name\":\"UITextSizeConstraint\",\"tags\":[]},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MaxTextSize\",\"tags\":[],\"Class\":\"UITextSizeConstraint\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MinTextSize\",\"tags\":[],\"Class\":\"UITextSizeConstraint\"},{\"Superclass\":\"UIComponent\",\"type\":\"Class\",\"Name\":\"UILayout\",\"tags\":[]},{\"Superclass\":\"UILayout\",\"type\":\"Class\",\"Name\":\"UIGridStyleLayout\",\"tags\":[\"notbrowsable\"]},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"AbsoluteContentSize\",\"tags\":[\"readonly\"],\"Class\":\"UIGridStyleLayout\"},{\"ValueType\":\"FillDirection\",\"type\":\"Property\",\"Name\":\"FillDirection\",\"tags\":[],\"Class\":\"UIGridStyleLayout\"},{\"ValueType\":\"HorizontalAlignment\",\"type\":\"Property\",\"Name\":\"HorizontalAlignment\",\"tags\":[],\"Class\":\"UIGridStyleLayout\"},{\"ValueType\":\"SortOrder\",\"type\":\"Property\",\"Name\":\"SortOrder\",\"tags\":[],\"Class\":\"UIGridStyleLayout\"},{\"ValueType\":\"VerticalAlignment\",\"type\":\"Property\",\"Name\":\"VerticalAlignment\",\"tags\":[],\"Class\":\"UIGridStyleLayout\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"ApplyLayout\",\"tags\":[],\"Class\":\"UIGridStyleLayout\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Function\",\"Name\":\"function\",\"Default\":\"nil\"}],\"Name\":\"SetCustomSortFunction\",\"tags\":[\"deprecated\"],\"Class\":\"UIGridStyleLayout\",\"type\":\"Function\"},{\"Superclass\":\"UIGridStyleLayout\",\"type\":\"Class\",\"Name\":\"UIGridLayout\",\"tags\":[]},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"CellPadding\",\"tags\":[],\"Class\":\"UIGridLayout\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"CellSize\",\"tags\":[],\"Class\":\"UIGridLayout\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"FillDirectionMaxCells\",\"tags\":[],\"Class\":\"UIGridLayout\"},{\"ValueType\":\"StartCorner\",\"type\":\"Property\",\"Name\":\"StartCorner\",\"tags\":[],\"Class\":\"UIGridLayout\"},{\"Superclass\":\"UIGridStyleLayout\",\"type\":\"Class\",\"Name\":\"UIListLayout\",\"tags\":[]},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"Padding\",\"tags\":[],\"Class\":\"UIListLayout\"},{\"Superclass\":\"UIGridStyleLayout\",\"type\":\"Class\",\"Name\":\"UIPageLayout\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Animated\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Circular\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"Class:GuiObject\",\"type\":\"Property\",\"Name\":\"CurrentPage\",\"tags\":[\"readonly\"],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"EasingDirection\",\"type\":\"Property\",\"Name\":\"EasingDirection\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"EasingStyle\",\"type\":\"Property\",\"Name\":\"EasingStyle\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GamepadInputEnabled\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"Padding\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ScrollWheelInputEnabled\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TouchInputEnabled\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"TweenTime\",\"tags\":[],\"Class\":\"UIPageLayout\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Instance\",\"Name\":\"page\",\"Default\":null}],\"Name\":\"JumpTo\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"index\",\"Default\":null}],\"Name\":\"JumpToIndex\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Next\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Previous\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"page\",\"Type\":\"Instance\"}],\"Name\":\"PageEnter\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"page\",\"Type\":\"Instance\"}],\"Name\":\"PageLeave\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"currentPage\",\"Type\":\"Instance\"}],\"Name\":\"Stopped\",\"tags\":[],\"Class\":\"UIPageLayout\",\"type\":\"Event\"},{\"Superclass\":\"UIGridStyleLayout\",\"type\":\"Class\",\"Name\":\"UITableLayout\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"FillEmptySpaceColumns\",\"tags\":[],\"Class\":\"UITableLayout\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"FillEmptySpaceRows\",\"tags\":[],\"Class\":\"UITableLayout\"},{\"ValueType\":\"TableMajorAxis\",\"type\":\"Property\",\"Name\":\"MajorAxis\",\"tags\":[],\"Class\":\"UITableLayout\"},{\"ValueType\":\"UDim2\",\"type\":\"Property\",\"Name\":\"Padding\",\"tags\":[],\"Class\":\"UITableLayout\"},{\"Superclass\":\"UIComponent\",\"type\":\"Class\",\"Name\":\"UIPadding\",\"tags\":[]},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"PaddingBottom\",\"tags\":[],\"Class\":\"UIPadding\"},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"PaddingLeft\",\"tags\":[],\"Class\":\"UIPadding\"},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"PaddingRight\",\"tags\":[],\"Class\":\"UIPadding\"},{\"ValueType\":\"UDim\",\"type\":\"Property\",\"Name\":\"PaddingTop\",\"tags\":[],\"Class\":\"UIPadding\"},{\"Superclass\":\"UIComponent\",\"type\":\"Class\",\"Name\":\"UIScale\",\"tags\":[]},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"Scale\",\"tags\":[],\"Class\":\"UIScale\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"UserGameSettings\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AllTutorialsDisabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"CustomCameraMode\",\"type\":\"Property\",\"Name\":\"CameraMode\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"CameraYInverted\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ChatVisible\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"ComputerCameraMovementMode\",\"type\":\"Property\",\"Name\":\"ComputerCameraMovementMode\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"ComputerMovementMode\",\"type\":\"Property\",\"Name\":\"ComputerMovementMode\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"ControlMode\",\"type\":\"Property\",\"Name\":\"ControlMode\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Fullscreen\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"GamepadCameraSensitivity\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"HasEverUsedVR\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsUsingCameraYInverted\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\",\"readonly\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"IsUsingGamepadCameraSensitivity\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\",\"readonly\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MasterVolume\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"MicroProfilerWebServerEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"MicroProfilerWebServerIP\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\",\"readonly\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"MicroProfilerWebServerPort\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\",\"readonly\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MouseSensitivity\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"MouseSensitivityFirstPerson\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"MouseSensitivityThirdPerson\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"OnScreenProfilerEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"OnboardingsCompleted\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"PerformanceStatsVisible\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"RotationType\",\"type\":\"Property\",\"Name\":\"RotationType\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"SavedQualitySetting\",\"type\":\"Property\",\"Name\":\"SavedQualityLevel\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"TouchCameraMovementMode\",\"type\":\"Property\",\"Name\":\"TouchCameraMovementMode\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"TouchMovementMode\",\"type\":\"Property\",\"Name\":\"TouchMovementMode\",\"tags\":[],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsedCoreGuiIsVisibleToggle\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsedCustomGuiIsVisibleToggle\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"UsedHideHudShortcut\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"VREnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ValueType\":\"int\",\"type\":\"Property\",\"Name\":\"VRRotationIntensity\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\"},{\"ReturnType\":\"int\",\"Arguments\":[],\"Name\":\"GetCameraYInvertValue\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"onboardingId\",\"Default\":null}],\"Name\":\"GetOnboardingCompleted\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"tutorialId\",\"Default\":null}],\"Name\":\"GetTutorialState\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"InFullScreen\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[],\"Name\":\"InStudioMode\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"onboardingId\",\"Default\":null}],\"Name\":\"ResetOnboardingCompleted\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SetCameraYInvertVisible\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"SetGamepadCameraSensitivityVisible\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"onboardingId\",\"Default\":null}],\"Name\":\"SetOnboardingCompleted\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"tutorialId\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"value\",\"Default\":null}],\"Name\":\"SetTutorialState\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"isFullscreen\",\"Type\":\"bool\"}],\"Name\":\"FullscreenChanged\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"isPerformanceStatsVisible\",\"Type\":\"bool\"}],\"Name\":\"PerformanceStatsVisibleChanged\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserGameSettings\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"isStudioMode\",\"Type\":\"bool\"}],\"Name\":\"StudioModeChanged\",\"tags\":[],\"Class\":\"UserGameSettings\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"UserInputService\",\"tags\":[\"notCreatable\"]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"AccelerometerEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"BottomBarSize\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GamepadEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GazeSelectionEnabled\",\"tags\":[\"RobloxScriptSecurity\",\"hidden\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"GyroscopeEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"KeyboardEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"LegacyInputEventsEnabled\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"ModalEnabled\",\"tags\":[],\"Class\":\"UserInputService\"},{\"ValueType\":\"MouseBehavior\",\"type\":\"Property\",\"Name\":\"MouseBehavior\",\"tags\":[],\"Class\":\"UserInputService\"},{\"ValueType\":\"float\",\"type\":\"Property\",\"Name\":\"MouseDeltaSensitivity\",\"tags\":[],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"MouseEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"MouseIconEnabled\",\"tags\":[],\"Class\":\"UserInputService\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"NavBarSize\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"OnScreenKeyboardAnimationDuration\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"OnScreenKeyboardPosition\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"OnScreenKeyboardSize\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"OnScreenKeyboardVisible\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"OverrideMouseIconBehavior\",\"type\":\"Property\",\"Name\":\"OverrideMouseIconBehavior\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"Vector2\",\"type\":\"Property\",\"Name\":\"StatusBarSize\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"TouchEnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"UserHeadCFrame\",\"tags\":[\"deprecated\",\"readonly\"],\"Class\":\"UserInputService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"VREnabled\",\"tags\":[\"readonly\"],\"Class\":\"UserInputService\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadNum\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"gamepadKeyCode\",\"Default\":null}],\"Name\":\"GamepadSupports\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetConnectedGamepads\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetDeviceAcceleration\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetDeviceGravity\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Tuple\",\"Arguments\":[],\"Name\":\"GetDeviceRotation\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Instance\",\"Arguments\":[],\"Name\":\"GetFocusedTextBox\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadNum\",\"Default\":null}],\"Name\":\"GetGamepadConnected\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadNum\",\"Default\":null}],\"Name\":\"GetGamepadState\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetKeysPressed\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"UserInputType\",\"Arguments\":[],\"Name\":\"GetLastInputType\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetMouseButtonsPressed\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Vector2\",\"Arguments\":[],\"Name\":\"GetMouseDelta\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Vector2\",\"Arguments\":[],\"Name\":\"GetMouseLocation\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[],\"Name\":\"GetNavigationGamepads\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Platform\",\"Arguments\":[],\"Name\":\"GetPlatform\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"Array\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadNum\",\"Default\":null}],\"Name\":\"GetSupportedGamepadKeyCodes\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[{\"Type\":\"UserCFrame\",\"Name\":\"type\",\"Default\":null}],\"Name\":\"GetUserCFrame\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadNum\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"gamepadKeyCode\",\"Default\":null}],\"Name\":\"IsGamepadButtonDown\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"KeyCode\",\"Name\":\"keyCode\",\"Default\":null}],\"Name\":\"IsKeyDown\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"mouseButton\",\"Default\":null}],\"Name\":\"IsMouseButtonPressed\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadEnum\",\"Default\":null}],\"Name\":\"IsNavigationGamepad\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RecenterUserHeadCFrame\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"statusBarSize\",\"Default\":null},{\"Type\":\"Vector2\",\"Name\":\"navBarSize\",\"Default\":null},{\"Type\":\"Vector2\",\"Name\":\"bottomBarSize\",\"Default\":null}],\"Name\":\"SendAppUISizes\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"UserInputType\",\"Name\":\"gamepadEnum\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"enabled\",\"Default\":null}],\"Name\":\"SetNavigationGamepad\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"acceleration\",\"Type\":\"Instance\"}],\"Name\":\"DeviceAccelerationChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"gravity\",\"Type\":\"Instance\"}],\"Name\":\"DeviceGravityChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"rotation\",\"Type\":\"Instance\"},{\"Name\":\"cframe\",\"Type\":\"CoordinateFrame\"}],\"Name\":\"DeviceRotationChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"gamepadNum\",\"Type\":\"UserInputType\"}],\"Name\":\"GamepadConnected\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"gamepadNum\",\"Type\":\"UserInputType\"}],\"Name\":\"GamepadDisconnected\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"InputBegan\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"InputChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"input\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"InputEnded\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"JumpRequest\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"lastInputType\",\"Type\":\"UserInputType\"}],\"Name\":\"LastInputTypeChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"position\",\"Type\":\"Vector2\"}],\"Name\":\"StatusBarTapped\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"textboxReleased\",\"Type\":\"Instance\"}],\"Name\":\"TextBoxFocusReleased\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"textboxFocused\",\"Type\":\"Instance\"}],\"Name\":\"TextBoxFocused\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touch\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchEnded\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchLongPress\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touch\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchMoved\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"totalTranslation\",\"Type\":\"Vector2\"},{\"Name\":\"velocity\",\"Type\":\"Vector2\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchPan\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"scale\",\"Type\":\"float\"},{\"Name\":\"velocity\",\"Type\":\"float\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchPinch\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"rotation\",\"Type\":\"float\"},{\"Name\":\"velocity\",\"Type\":\"float\"},{\"Name\":\"state\",\"Type\":\"UserInputState\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchRotate\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touch\",\"Type\":\"Instance\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchStarted\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"swipeDirection\",\"Type\":\"SwipeDirection\"},{\"Name\":\"numberOfTouches\",\"Type\":\"int\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchSwipe\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"touchPositions\",\"Type\":\"Array\"},{\"Name\":\"gameProcessedEvent\",\"Type\":\"bool\"}],\"Name\":\"TouchTap\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"position\",\"Type\":\"Vector2\"},{\"Name\":\"processedByUI\",\"Type\":\"bool\"}],\"Name\":\"TouchTapInWorld\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"type\",\"Type\":\"UserCFrame\"},{\"Name\":\"value\",\"Type\":\"CoordinateFrame\"}],\"Name\":\"UserCFrameChanged\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WindowFocusReleased\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Arguments\":[],\"Name\":\"WindowFocused\",\"tags\":[],\"Class\":\"UserInputService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"VRService\",\"tags\":[]},{\"ValueType\":\"UserCFrame\",\"type\":\"Property\",\"Name\":\"GuiInputUserCFrame\",\"tags\":[],\"Class\":\"VRService\"},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"VRDeviceName\",\"tags\":[\"RobloxScriptSecurity\",\"readonly\"],\"Class\":\"VRService\"},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"VREnabled\",\"tags\":[\"readonly\"],\"Class\":\"VRService\"},{\"ReturnType\":\"VRTouchpadMode\",\"Arguments\":[{\"Type\":\"VRTouchpad\",\"Name\":\"pad\",\"Default\":null}],\"Name\":\"GetTouchpadMode\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"ReturnType\":\"CoordinateFrame\",\"Arguments\":[{\"Type\":\"UserCFrame\",\"Name\":\"type\",\"Default\":null}],\"Name\":\"GetUserCFrame\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"ReturnType\":\"bool\",\"Arguments\":[{\"Type\":\"UserCFrame\",\"Name\":\"type\",\"Default\":null}],\"Name\":\"GetUserCFrameEnabled\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"RecenterUserHeadCFrame\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"CoordinateFrame\",\"Name\":\"cframe\",\"Default\":null},{\"Type\":\"UserCFrame\",\"Name\":\"inputUserCFrame\",\"Default\":null}],\"Name\":\"RequestNavigation\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"VRTouchpad\",\"Name\":\"pad\",\"Default\":null},{\"Type\":\"VRTouchpadMode\",\"Name\":\"mode\",\"Default\":null}],\"Name\":\"SetTouchpadMode\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"cframe\",\"Type\":\"CoordinateFrame\"},{\"Name\":\"inputUserCFrame\",\"Type\":\"UserCFrame\"}],\"Name\":\"NavigationRequested\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"pad\",\"Type\":\"VRTouchpad\"},{\"Name\":\"mode\",\"Type\":\"VRTouchpadMode\"}],\"Name\":\"TouchpadModeChanged\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"type\",\"Type\":\"UserCFrame\"},{\"Name\":\"value\",\"Type\":\"CoordinateFrame\"}],\"Name\":\"UserCFrameChanged\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"type\",\"Type\":\"UserCFrame\"},{\"Name\":\"enabled\",\"Type\":\"bool\"}],\"Name\":\"UserCFrameEnabled\",\"tags\":[],\"Class\":\"VRService\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"ValueBase\",\"tags\":[]},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"BinaryStringValue\",\"tags\":[]},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"BinaryString\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"BinaryStringValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"BoolValue\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"BoolValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"bool\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"BoolValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"bool\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"BoolValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"BrickColorValue\",\"tags\":[]},{\"ValueType\":\"BrickColor\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"BrickColorValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"BrickColor\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"BrickColorValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"BrickColor\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"BrickColorValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"CFrameValue\",\"tags\":[]},{\"ValueType\":\"CoordinateFrame\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"CFrameValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"CoordinateFrame\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"CFrameValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"CoordinateFrame\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"CFrameValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"Color3Value\",\"tags\":[]},{\"ValueType\":\"Color3\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"Color3Value\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Color3\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"Color3Value\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Color3\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"Color3Value\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"DoubleConstrainedValue\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"ConstrainedValue\",\"tags\":[\"hidden\"],\"Class\":\"DoubleConstrainedValue\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"MaxValue\",\"tags\":[],\"Class\":\"DoubleConstrainedValue\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"MinValue\",\"tags\":[],\"Class\":\"DoubleConstrainedValue\"},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"DoubleConstrainedValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"double\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"DoubleConstrainedValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"double\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"DoubleConstrainedValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"IntConstrainedValue\",\"tags\":[\"deprecated\"]},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"ConstrainedValue\",\"tags\":[\"hidden\"],\"Class\":\"IntConstrainedValue\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"MaxValue\",\"tags\":[],\"Class\":\"IntConstrainedValue\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"MinValue\",\"tags\":[],\"Class\":\"IntConstrainedValue\"},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"IntConstrainedValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"int64\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"IntConstrainedValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"int64\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"IntConstrainedValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"IntValue\",\"tags\":[]},{\"ValueType\":\"int64\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"IntValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"int64\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"IntValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"int64\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"IntValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"NumberValue\",\"tags\":[]},{\"ValueType\":\"double\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"NumberValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"double\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"NumberValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"double\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"NumberValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"ObjectValue\",\"tags\":[]},{\"ValueType\":\"Class:Instance\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"ObjectValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Instance\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"ObjectValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Instance\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"ObjectValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"RayValue\",\"tags\":[]},{\"ValueType\":\"Ray\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"RayValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Ray\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"RayValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Ray\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"RayValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"StringValue\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"StringValue\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"string\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"StringValue\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"string\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"StringValue\",\"type\":\"Event\"},{\"Superclass\":\"ValueBase\",\"type\":\"Class\",\"Name\":\"Vector3Value\",\"tags\":[]},{\"ValueType\":\"Vector3\",\"type\":\"Property\",\"Name\":\"Value\",\"tags\":[],\"Class\":\"Vector3Value\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Vector3\"}],\"Name\":\"Changed\",\"tags\":[],\"Class\":\"Vector3Value\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"value\",\"Type\":\"Vector3\"}],\"Name\":\"changed\",\"tags\":[\"deprecated\"],\"Class\":\"Vector3Value\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"VirtualInputManager\",\"tags\":[]},{\"ValueType\":\"string\",\"type\":\"Property\",\"Name\":\"AdditionalLuaState\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"Dump\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"objectId\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"keyCode\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"HandleGamepadAxisInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"deviceId\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"keyCode\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"buttonState\",\"Default\":null}],\"Name\":\"HandleGamepadButtonInput\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"deviceId\",\"Default\":null}],\"Name\":\"HandleGamepadConnect\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"deviceId\",\"Default\":null}],\"Name\":\"HandleGamepadDisconnect\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"SendAccelerometerEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"z\",\"Default\":null}],\"Name\":\"SendGravityEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"quatX\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"quatY\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"quatZ\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"quatW\",\"Default\":null}],\"Name\":\"SendGyroscopeEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"bool\",\"Name\":\"isPressed\",\"Default\":null},{\"Type\":\"KeyCode\",\"Name\":\"keyCode\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"isRepeatedKey\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"pluginGui\",\"Default\":null}],\"Name\":\"SendKeyEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"mouseButton\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"isDown\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"pluginGui\",\"Default\":null}],\"Name\":\"SendMouseButtonEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"pluginGui\",\"Default\":null}],\"Name\":\"SendMouseMoveEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null},{\"Type\":\"bool\",\"Name\":\"isForwardScroll\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"pluginGui\",\"Default\":null}],\"Name\":\"SendMouseWheelEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"str\",\"Default\":null},{\"Type\":\"Instance\",\"Name\":\"pluginGui\",\"Default\":null}],\"Name\":\"SendTextInputCharacterEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"int64\",\"Name\":\"touchId\",\"Default\":null},{\"Type\":\"int\",\"Name\":\"state\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"x\",\"Default\":null},{\"Type\":\"float\",\"Name\":\"y\",\"Default\":null}],\"Name\":\"SendTouchEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"fileName\",\"Default\":null}],\"Name\":\"StartPlaying\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StartRecording\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StopRecording\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"namespace\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"detail\",\"Default\":null},{\"Type\":\"string\",\"Name\":\"detailType\",\"Default\":null}],\"Name\":\"sendRobloxEvent\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Function\"},{\"Arguments\":[{\"Name\":\"additionalLuaState\",\"Type\":\"string\"}],\"Name\":\"PlaybackCompleted\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Event\"},{\"Arguments\":[{\"Name\":\"result\",\"Type\":\"string\"}],\"Name\":\"RecordingCompleted\",\"tags\":[\"RobloxScriptSecurity\"],\"Class\":\"VirtualInputManager\",\"type\":\"Event\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"VirtualUser\",\"tags\":[\"notCreatable\"]},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"Button1Down\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"Button1Up\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"Button2Down\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"Button2Up\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"CaptureController\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"ClickButton1\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"ClickButton2\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"Vector2\",\"Name\":\"position\",\"Default\":null},{\"Type\":\"CoordinateFrame\",\"Name\":\"camera\",\"Default\":\"Identity\"}],\"Name\":\"MoveMouse\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"SetKeyDown\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"SetKeyUp\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[],\"Name\":\"StartRecording\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"string\",\"Arguments\":[],\"Name\":\"StopRecording\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"ReturnType\":\"void\",\"Arguments\":[{\"Type\":\"string\",\"Name\":\"key\",\"Default\":null}],\"Name\":\"TypeKey\",\"tags\":[\"LocalUserSecurity\"],\"Class\":\"VirtualUser\",\"type\":\"Function\"},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"Visit\",\"tags\":[\"notCreatable\"]},{\"Superclass\":\"Instance\",\"type\":\"Class\",\"Name\":\"WeldConstraint\",\"tags\":[]},{\"ValueType\":\"bool\",\"type\":\"Property\",\"Name\":\"Enabled\",\"tags\":[],\"Class\":\"WeldConstraint\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Part0\",\"tags\":[],\"Class\":\"WeldConstraint\"},{\"ValueType\":\"Class:BasePart\",\"type\":\"Property\",\"Name\":\"Part1\",\"tags\":[],\"Class\":\"WeldConstraint\"},{\"type\":\"Enum\",\"Name\":\"ActionType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Nothing\",\"tags\":[],\"Value\":0,\"Enum\":\"ActionType\"},{\"type\":\"EnumItem\",\"Name\":\"Pause\",\"tags\":[],\"Value\":1,\"Enum\":\"ActionType\"},{\"type\":\"EnumItem\",\"Name\":\"Lose\",\"tags\":[],\"Value\":2,\"Enum\":\"ActionType\"},{\"type\":\"EnumItem\",\"Name\":\"Draw\",\"tags\":[],\"Value\":3,\"Enum\":\"ActionType\"},{\"type\":\"EnumItem\",\"Name\":\"Win\",\"tags\":[],\"Value\":4,\"Enum\":\"ActionType\"},{\"type\":\"Enum\",\"Name\":\"ActuatorRelativeTo\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Attachment0\",\"tags\":[],\"Value\":0,\"Enum\":\"ActuatorRelativeTo\"},{\"type\":\"EnumItem\",\"Name\":\"Attachment1\",\"tags\":[],\"Value\":1,\"Enum\":\"ActuatorRelativeTo\"},{\"type\":\"EnumItem\",\"Name\":\"World\",\"tags\":[],\"Value\":2,\"Enum\":\"ActuatorRelativeTo\"},{\"type\":\"Enum\",\"Name\":\"ActuatorType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"ActuatorType\"},{\"type\":\"EnumItem\",\"Name\":\"Motor\",\"tags\":[],\"Value\":1,\"Enum\":\"ActuatorType\"},{\"type\":\"EnumItem\",\"Name\":\"Servo\",\"tags\":[],\"Value\":2,\"Enum\":\"ActuatorType\"},{\"type\":\"Enum\",\"Name\":\"AnimationPriority\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Idle\",\"tags\":[],\"Value\":0,\"Enum\":\"AnimationPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Movement\",\"tags\":[],\"Value\":1,\"Enum\":\"AnimationPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Action\",\"tags\":[],\"Value\":2,\"Enum\":\"AnimationPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Core\",\"tags\":[],\"Value\":1000,\"Enum\":\"AnimationPriority\"},{\"type\":\"Enum\",\"Name\":\"AppShellActionType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"OpenApp\",\"tags\":[],\"Value\":1,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"TapChatTab\",\"tags\":[],\"Value\":2,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"TapConversationEntry\",\"tags\":[],\"Value\":3,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"TapAvatarTab\",\"tags\":[],\"Value\":4,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"ReadConversation\",\"tags\":[],\"Value\":5,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"TapGamePageTab\",\"tags\":[],\"Value\":6,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"TapHomePageTab\",\"tags\":[],\"Value\":7,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"GamePageLoaded\",\"tags\":[],\"Value\":8,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"HomePageLoaded\",\"tags\":[],\"Value\":9,\"Enum\":\"AppShellActionType\"},{\"type\":\"EnumItem\",\"Name\":\"AvatarEditorPageLoaded\",\"tags\":[],\"Value\":10,\"Enum\":\"AppShellActionType\"},{\"type\":\"Enum\",\"Name\":\"AspectType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"FitWithinMaxSize\",\"tags\":[],\"Value\":0,\"Enum\":\"AspectType\"},{\"type\":\"EnumItem\",\"Name\":\"ScaleWithParentSize\",\"tags\":[],\"Value\":1,\"Enum\":\"AspectType\"},{\"type\":\"Enum\",\"Name\":\"AssetType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Image\",\"tags\":[],\"Value\":1,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"TeeShirt\",\"tags\":[],\"Value\":2,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Audio\",\"tags\":[],\"Value\":3,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Mesh\",\"tags\":[],\"Value\":4,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Lua\",\"tags\":[],\"Value\":5,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Hat\",\"tags\":[],\"Value\":8,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Place\",\"tags\":[],\"Value\":9,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Model\",\"tags\":[],\"Value\":10,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Shirt\",\"tags\":[],\"Value\":11,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Pants\",\"tags\":[],\"Value\":12,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Decal\",\"tags\":[],\"Value\":13,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":17,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Face\",\"tags\":[],\"Value\":18,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Gear\",\"tags\":[],\"Value\":19,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Badge\",\"tags\":[],\"Value\":21,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Animation\",\"tags\":[],\"Value\":24,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Torso\",\"tags\":[],\"Value\":27,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"RightArm\",\"tags\":[],\"Value\":28,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"LeftArm\",\"tags\":[],\"Value\":29,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"LeftLeg\",\"tags\":[],\"Value\":30,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"RightLeg\",\"tags\":[],\"Value\":31,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Package\",\"tags\":[],\"Value\":32,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"GamePass\",\"tags\":[],\"Value\":34,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"Plugin\",\"tags\":[],\"Value\":38,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"MeshPart\",\"tags\":[],\"Value\":40,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"HairAccessory\",\"tags\":[],\"Value\":41,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"FaceAccessory\",\"tags\":[],\"Value\":42,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"NeckAccessory\",\"tags\":[],\"Value\":43,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"ShoulderAccessory\",\"tags\":[],\"Value\":44,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"FrontAccessory\",\"tags\":[],\"Value\":45,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"BackAccessory\",\"tags\":[],\"Value\":46,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"WaistAccessory\",\"tags\":[],\"Value\":47,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"ClimbAnimation\",\"tags\":[],\"Value\":48,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"DeathAnimation\",\"tags\":[],\"Value\":49,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"FallAnimation\",\"tags\":[],\"Value\":50,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"IdleAnimation\",\"tags\":[],\"Value\":51,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"JumpAnimation\",\"tags\":[],\"Value\":52,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"RunAnimation\",\"tags\":[],\"Value\":53,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"SwimAnimation\",\"tags\":[],\"Value\":54,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"WalkAnimation\",\"tags\":[],\"Value\":55,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"PoseAnimation\",\"tags\":[],\"Value\":56,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"EarAccessory\",\"tags\":[],\"Value\":57,\"Enum\":\"AssetType\"},{\"type\":\"EnumItem\",\"Name\":\"EyeAccessory\",\"tags\":[],\"Value\":58,\"Enum\":\"AssetType\"},{\"type\":\"Enum\",\"Name\":\"AutoJointsMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"AutoJointsMode\"},{\"type\":\"EnumItem\",\"Name\":\"Explicit\",\"tags\":[],\"Value\":1,\"Enum\":\"AutoJointsMode\"},{\"type\":\"EnumItem\",\"Name\":\"LegacyImplicit\",\"tags\":[],\"Value\":2,\"Enum\":\"AutoJointsMode\"},{\"type\":\"Enum\",\"Name\":\"AvatarContextMenuOption\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Friend\",\"tags\":[],\"Value\":0,\"Enum\":\"AvatarContextMenuOption\"},{\"type\":\"EnumItem\",\"Name\":\"Chat\",\"tags\":[],\"Value\":1,\"Enum\":\"AvatarContextMenuOption\"},{\"type\":\"EnumItem\",\"Name\":\"Emote\",\"tags\":[],\"Value\":2,\"Enum\":\"AvatarContextMenuOption\"},{\"type\":\"Enum\",\"Name\":\"AvatarJointPositionType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Fixed\",\"tags\":[],\"Value\":0,\"Enum\":\"AvatarJointPositionType\"},{\"type\":\"EnumItem\",\"Name\":\"ArtistIntent\",\"tags\":[],\"Value\":1,\"Enum\":\"AvatarJointPositionType\"},{\"type\":\"Enum\",\"Name\":\"Axis\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"X\",\"tags\":[],\"Value\":0,\"Enum\":\"Axis\"},{\"type\":\"EnumItem\",\"Name\":\"Y\",\"tags\":[],\"Value\":1,\"Enum\":\"Axis\"},{\"type\":\"EnumItem\",\"Name\":\"Z\",\"tags\":[],\"Value\":2,\"Enum\":\"Axis\"},{\"type\":\"Enum\",\"Name\":\"BinType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Script\",\"tags\":[],\"Value\":0,\"Enum\":\"BinType\"},{\"type\":\"EnumItem\",\"Name\":\"GameTool\",\"tags\":[],\"Value\":1,\"Enum\":\"BinType\"},{\"type\":\"EnumItem\",\"Name\":\"Grab\",\"tags\":[],\"Value\":2,\"Enum\":\"BinType\"},{\"type\":\"EnumItem\",\"Name\":\"Clone\",\"tags\":[],\"Value\":3,\"Enum\":\"BinType\"},{\"type\":\"EnumItem\",\"Name\":\"Hammer\",\"tags\":[],\"Value\":4,\"Enum\":\"BinType\"},{\"type\":\"Enum\",\"Name\":\"BodyPart\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":0,\"Enum\":\"BodyPart\"},{\"type\":\"EnumItem\",\"Name\":\"Torso\",\"tags\":[],\"Value\":1,\"Enum\":\"BodyPart\"},{\"type\":\"EnumItem\",\"Name\":\"LeftArm\",\"tags\":[],\"Value\":2,\"Enum\":\"BodyPart\"},{\"type\":\"EnumItem\",\"Name\":\"RightArm\",\"tags\":[],\"Value\":3,\"Enum\":\"BodyPart\"},{\"type\":\"EnumItem\",\"Name\":\"LeftLeg\",\"tags\":[],\"Value\":4,\"Enum\":\"BodyPart\"},{\"type\":\"EnumItem\",\"Name\":\"RightLeg\",\"tags\":[],\"Value\":5,\"Enum\":\"BodyPart\"},{\"type\":\"Enum\",\"Name\":\"BodyPartR15\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":0,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"UpperTorso\",\"tags\":[],\"Value\":1,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LowerTorso\",\"tags\":[],\"Value\":2,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftFoot\",\"tags\":[],\"Value\":3,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftLowerLeg\",\"tags\":[],\"Value\":4,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftUpperLeg\",\"tags\":[],\"Value\":5,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightFoot\",\"tags\":[],\"Value\":6,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightLowerLeg\",\"tags\":[],\"Value\":7,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightUpperLeg\",\"tags\":[],\"Value\":8,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftHand\",\"tags\":[],\"Value\":9,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftLowerArm\",\"tags\":[],\"Value\":10,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"LeftUpperArm\",\"tags\":[],\"Value\":11,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightHand\",\"tags\":[],\"Value\":12,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightLowerArm\",\"tags\":[],\"Value\":13,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RightUpperArm\",\"tags\":[],\"Value\":14,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"RootPart\",\"tags\":[],\"Value\":15,\"Enum\":\"BodyPartR15\"},{\"type\":\"EnumItem\",\"Name\":\"Unknown\",\"tags\":[],\"Value\":17,\"Enum\":\"BodyPartR15\"},{\"type\":\"Enum\",\"Name\":\"Button\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Jump\",\"tags\":[],\"Value\":32,\"Enum\":\"Button\"},{\"type\":\"EnumItem\",\"Name\":\"Dismount\",\"tags\":[],\"Value\":8,\"Enum\":\"Button\"},{\"type\":\"Enum\",\"Name\":\"ButtonStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Custom\",\"tags\":[],\"Value\":0,\"Enum\":\"ButtonStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxButtonDefault\",\"tags\":[],\"Value\":1,\"Enum\":\"ButtonStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxButton\",\"tags\":[],\"Value\":2,\"Enum\":\"ButtonStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxRoundButton\",\"tags\":[],\"Value\":3,\"Enum\":\"ButtonStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxRoundDefaultButton\",\"tags\":[],\"Value\":4,\"Enum\":\"ButtonStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxRoundDropdownButton\",\"tags\":[],\"Value\":5,\"Enum\":\"ButtonStyle\"},{\"type\":\"Enum\",\"Name\":\"CameraMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":0,\"Enum\":\"CameraMode\"},{\"type\":\"EnumItem\",\"Name\":\"LockFirstPerson\",\"tags\":[],\"Value\":1,\"Enum\":\"CameraMode\"},{\"type\":\"Enum\",\"Name\":\"CameraPanMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":0,\"Enum\":\"CameraPanMode\"},{\"type\":\"EnumItem\",\"Name\":\"EdgeBump\",\"tags\":[],\"Value\":1,\"Enum\":\"CameraPanMode\"},{\"type\":\"Enum\",\"Name\":\"CameraType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Fixed\",\"tags\":[],\"Value\":0,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Watch\",\"tags\":[],\"Value\":2,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Attach\",\"tags\":[],\"Value\":1,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Track\",\"tags\":[],\"Value\":3,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":4,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Custom\",\"tags\":[],\"Value\":5,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Scriptable\",\"tags\":[],\"Value\":6,\"Enum\":\"CameraType\"},{\"type\":\"EnumItem\",\"Name\":\"Orbital\",\"tags\":[],\"Value\":7,\"Enum\":\"CameraType\"},{\"type\":\"Enum\",\"Name\":\"CellBlock\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Solid\",\"tags\":[],\"Value\":0,\"Enum\":\"CellBlock\"},{\"type\":\"EnumItem\",\"Name\":\"VerticalWedge\",\"tags\":[],\"Value\":1,\"Enum\":\"CellBlock\"},{\"type\":\"EnumItem\",\"Name\":\"CornerWedge\",\"tags\":[],\"Value\":2,\"Enum\":\"CellBlock\"},{\"type\":\"EnumItem\",\"Name\":\"InverseCornerWedge\",\"tags\":[],\"Value\":3,\"Enum\":\"CellBlock\"},{\"type\":\"EnumItem\",\"Name\":\"HorizontalWedge\",\"tags\":[],\"Value\":4,\"Enum\":\"CellBlock\"},{\"type\":\"Enum\",\"Name\":\"CellMaterial\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Empty\",\"tags\":[],\"Value\":0,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Grass\",\"tags\":[],\"Value\":1,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Sand\",\"tags\":[],\"Value\":2,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Brick\",\"tags\":[],\"Value\":3,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Granite\",\"tags\":[],\"Value\":4,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Asphalt\",\"tags\":[],\"Value\":5,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Iron\",\"tags\":[],\"Value\":6,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Aluminum\",\"tags\":[],\"Value\":7,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Gold\",\"tags\":[],\"Value\":8,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"WoodPlank\",\"tags\":[],\"Value\":9,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"WoodLog\",\"tags\":[],\"Value\":10,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Gravel\",\"tags\":[],\"Value\":11,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"CinderBlock\",\"tags\":[],\"Value\":12,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"MossyStone\",\"tags\":[],\"Value\":13,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Cement\",\"tags\":[],\"Value\":14,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"RedPlastic\",\"tags\":[],\"Value\":15,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"BluePlastic\",\"tags\":[],\"Value\":16,\"Enum\":\"CellMaterial\"},{\"type\":\"EnumItem\",\"Name\":\"Water\",\"tags\":[],\"Value\":17,\"Enum\":\"CellMaterial\"},{\"type\":\"Enum\",\"Name\":\"CellOrientation\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NegZ\",\"tags\":[],\"Value\":0,\"Enum\":\"CellOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"X\",\"tags\":[],\"Value\":1,\"Enum\":\"CellOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"Z\",\"tags\":[],\"Value\":2,\"Enum\":\"CellOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"NegX\",\"tags\":[],\"Value\":3,\"Enum\":\"CellOrientation\"},{\"type\":\"Enum\",\"Name\":\"CenterDialogType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UnsolicitedDialog\",\"tags\":[],\"Value\":1,\"Enum\":\"CenterDialogType\"},{\"type\":\"EnumItem\",\"Name\":\"PlayerInitiatedDialog\",\"tags\":[],\"Value\":2,\"Enum\":\"CenterDialogType\"},{\"type\":\"EnumItem\",\"Name\":\"ModalDialog\",\"tags\":[],\"Value\":3,\"Enum\":\"CenterDialogType\"},{\"type\":\"EnumItem\",\"Name\":\"QuitDialog\",\"tags\":[],\"Value\":4,\"Enum\":\"CenterDialogType\"},{\"type\":\"Enum\",\"Name\":\"ChatCallbackType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"OnCreatingChatWindow\",\"tags\":[],\"Value\":1,\"Enum\":\"ChatCallbackType\"},{\"type\":\"EnumItem\",\"Name\":\"OnClientSendingMessage\",\"tags\":[],\"Value\":2,\"Enum\":\"ChatCallbackType\"},{\"type\":\"EnumItem\",\"Name\":\"OnClientFormattingMessage\",\"tags\":[],\"Value\":3,\"Enum\":\"ChatCallbackType\"},{\"type\":\"EnumItem\",\"Name\":\"OnServerReceivingMessage\",\"tags\":[],\"Value\":17,\"Enum\":\"ChatCallbackType\"},{\"type\":\"Enum\",\"Name\":\"ChatColor\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Blue\",\"tags\":[],\"Value\":0,\"Enum\":\"ChatColor\"},{\"type\":\"EnumItem\",\"Name\":\"Green\",\"tags\":[],\"Value\":1,\"Enum\":\"ChatColor\"},{\"type\":\"EnumItem\",\"Name\":\"Red\",\"tags\":[],\"Value\":2,\"Enum\":\"ChatColor\"},{\"type\":\"EnumItem\",\"Name\":\"White\",\"tags\":[],\"Value\":3,\"Enum\":\"ChatColor\"},{\"type\":\"Enum\",\"Name\":\"ChatMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Menu\",\"tags\":[],\"Value\":0,\"Enum\":\"ChatMode\"},{\"type\":\"EnumItem\",\"Name\":\"TextAndMenu\",\"tags\":[],\"Value\":1,\"Enum\":\"ChatMode\"},{\"type\":\"Enum\",\"Name\":\"ChatPrivacyMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"AllUsers\",\"tags\":[],\"Value\":0,\"Enum\":\"ChatPrivacyMode\"},{\"type\":\"EnumItem\",\"Name\":\"NoOne\",\"tags\":[],\"Value\":1,\"Enum\":\"ChatPrivacyMode\"},{\"type\":\"EnumItem\",\"Name\":\"Friends\",\"tags\":[],\"Value\":2,\"Enum\":\"ChatPrivacyMode\"},{\"type\":\"Enum\",\"Name\":\"ChatStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":0,\"Enum\":\"ChatStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Bubble\",\"tags\":[],\"Value\":1,\"Enum\":\"ChatStyle\"},{\"type\":\"EnumItem\",\"Name\":\"ClassicAndBubble\",\"tags\":[],\"Value\":2,\"Enum\":\"ChatStyle\"},{\"type\":\"Enum\",\"Name\":\"CollisionFidelity\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"CollisionFidelity\"},{\"type\":\"EnumItem\",\"Name\":\"Hull\",\"tags\":[],\"Value\":1,\"Enum\":\"CollisionFidelity\"},{\"type\":\"EnumItem\",\"Name\":\"Box\",\"tags\":[],\"Value\":2,\"Enum\":\"CollisionFidelity\"},{\"type\":\"Enum\",\"Name\":\"ComputerCameraMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"ComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":2,\"Enum\":\"ComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":1,\"Enum\":\"ComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Orbital\",\"tags\":[],\"Value\":3,\"Enum\":\"ComputerCameraMovementMode\"},{\"type\":\"Enum\",\"Name\":\"ComputerMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"ComputerMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"KeyboardMouse\",\"tags\":[],\"Value\":1,\"Enum\":\"ComputerMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"ClickToMove\",\"tags\":[],\"Value\":2,\"Enum\":\"ComputerMovementMode\"},{\"type\":\"Enum\",\"Name\":\"ConnectionError\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"OK\",\"tags\":[],\"Value\":0,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectErrors\",\"tags\":[],\"Value\":256,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectBadhash\",\"tags\":[],\"Value\":257,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectSecurityKeyMismatch\",\"tags\":[],\"Value\":258,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectNewSecurityKeyMismatch\",\"tags\":[],\"Value\":272,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectProtocolMismatch\",\"tags\":[],\"Value\":259,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectReceivePacketError\",\"tags\":[],\"Value\":260,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectReceivePacketStreamError\",\"tags\":[],\"Value\":261,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectSendPacketError\",\"tags\":[],\"Value\":262,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectIllegalTeleport\",\"tags\":[],\"Value\":263,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectDuplicatePlayer\",\"tags\":[],\"Value\":264,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectDuplicateTicket\",\"tags\":[],\"Value\":265,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectTimeout\",\"tags\":[],\"Value\":266,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectLuaKick\",\"tags\":[],\"Value\":267,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectOnRemoteSysStats\",\"tags\":[],\"Value\":268,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectHashTimeout\",\"tags\":[],\"Value\":269,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectCloudEditKick\",\"tags\":[],\"Value\":270,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectPlayerless\",\"tags\":[],\"Value\":271,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectEvicted\",\"tags\":[],\"Value\":273,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectDevMaintenance\",\"tags\":[],\"Value\":274,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectRobloxMaintenance\",\"tags\":[],\"Value\":275,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectRejoin\",\"tags\":[],\"Value\":276,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"DisconnectConnectionLost\",\"tags\":[],\"Value\":277,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchErrors\",\"tags\":[],\"Value\":512,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchDisabled\",\"tags\":[],\"Value\":515,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelauchError\",\"tags\":[],\"Value\":516,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchGameEnded\",\"tags\":[],\"Value\":517,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchGameFull\",\"tags\":[],\"Value\":518,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchUserLeft\",\"tags\":[],\"Value\":522,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchRestricted\",\"tags\":[],\"Value\":523,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchUnauthorized\",\"tags\":[],\"Value\":524,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchFlooded\",\"tags\":[],\"Value\":525,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchHashExpired\",\"tags\":[],\"Value\":526,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchHashException\",\"tags\":[],\"Value\":527,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchPartyCannotFit\",\"tags\":[],\"Value\":528,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchHttpError\",\"tags\":[],\"Value\":529,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchCustomMessage\",\"tags\":[],\"Value\":610,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"PlacelaunchOtherError\",\"tags\":[],\"Value\":611,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportErrors\",\"tags\":[],\"Value\":768,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportFailure\",\"tags\":[],\"Value\":769,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportGameNotFound\",\"tags\":[],\"Value\":770,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportGameEnded\",\"tags\":[],\"Value\":771,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportGameFull\",\"tags\":[],\"Value\":772,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportUnauthorized\",\"tags\":[],\"Value\":773,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportFlooded\",\"tags\":[],\"Value\":774,\"Enum\":\"ConnectionError\"},{\"type\":\"EnumItem\",\"Name\":\"TeleportIsTeleporting\",\"tags\":[],\"Value\":775,\"Enum\":\"ConnectionError\"},{\"type\":\"Enum\",\"Name\":\"ConnectionState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Connected\",\"tags\":[],\"Value\":0,\"Enum\":\"ConnectionState\"},{\"type\":\"EnumItem\",\"Name\":\"Disconnected\",\"tags\":[],\"Value\":1,\"Enum\":\"ConnectionState\"},{\"type\":\"Enum\",\"Name\":\"ContextActionPriority\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Low\",\"tags\":[],\"Value\":1000,\"Enum\":\"ContextActionPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Medium\",\"tags\":[],\"Value\":2000,\"Enum\":\"ContextActionPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":2000,\"Enum\":\"ContextActionPriority\"},{\"type\":\"EnumItem\",\"Name\":\"High\",\"tags\":[],\"Value\":3000,\"Enum\":\"ContextActionPriority\"},{\"type\":\"Enum\",\"Name\":\"ContextActionResult\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Pass\",\"tags\":[],\"Value\":1,\"Enum\":\"ContextActionResult\"},{\"type\":\"EnumItem\",\"Name\":\"Sink\",\"tags\":[],\"Value\":0,\"Enum\":\"ContextActionResult\"},{\"type\":\"Enum\",\"Name\":\"ControlMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"MouseLockSwitch\",\"tags\":[],\"Value\":1,\"Enum\":\"ControlMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":0,\"Enum\":\"ControlMode\"},{\"type\":\"Enum\",\"Name\":\"CoreGuiType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"PlayerList\",\"tags\":[],\"Value\":0,\"Enum\":\"CoreGuiType\"},{\"type\":\"EnumItem\",\"Name\":\"Health\",\"tags\":[],\"Value\":1,\"Enum\":\"CoreGuiType\"},{\"type\":\"EnumItem\",\"Name\":\"Backpack\",\"tags\":[],\"Value\":2,\"Enum\":\"CoreGuiType\"},{\"type\":\"EnumItem\",\"Name\":\"Chat\",\"tags\":[],\"Value\":3,\"Enum\":\"CoreGuiType\"},{\"type\":\"EnumItem\",\"Name\":\"All\",\"tags\":[],\"Value\":4,\"Enum\":\"CoreGuiType\"},{\"type\":\"Enum\",\"Name\":\"CreatorType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"User\",\"tags\":[],\"Value\":0,\"Enum\":\"CreatorType\"},{\"type\":\"EnumItem\",\"Name\":\"Group\",\"tags\":[],\"Value\":1,\"Enum\":\"CreatorType\"},{\"type\":\"Enum\",\"Name\":\"CurrencyType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"CurrencyType\"},{\"type\":\"EnumItem\",\"Name\":\"Robux\",\"tags\":[],\"Value\":1,\"Enum\":\"CurrencyType\"},{\"type\":\"EnumItem\",\"Name\":\"Tix\",\"tags\":[],\"Value\":2,\"Enum\":\"CurrencyType\"},{\"type\":\"Enum\",\"Name\":\"CustomCameraMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"CustomCameraMode\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":2,\"Enum\":\"CustomCameraMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":1,\"Enum\":\"CustomCameraMode\"},{\"type\":\"Enum\",\"Name\":\"DataStoreRequestType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"GetAsync\",\"tags\":[],\"Value\":0,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"SetIncrementAsync\",\"tags\":[],\"Value\":1,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"UpdateAsync\",\"tags\":[],\"Value\":2,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"GetSortedAsync\",\"tags\":[],\"Value\":3,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"SetIncrementSortedAsync\",\"tags\":[],\"Value\":4,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"OnUpdate\",\"tags\":[],\"Value\":5,\"Enum\":\"DataStoreRequestType\"},{\"type\":\"Enum\",\"Name\":\"DevCameraOcclusionMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Zoom\",\"tags\":[],\"Value\":0,\"Enum\":\"DevCameraOcclusionMode\"},{\"type\":\"EnumItem\",\"Name\":\"Invisicam\",\"tags\":[],\"Value\":1,\"Enum\":\"DevCameraOcclusionMode\"},{\"type\":\"Enum\",\"Name\":\"DevComputerCameraMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UserChoice\",\"tags\":[],\"Value\":0,\"Enum\":\"DevComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":1,\"Enum\":\"DevComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":2,\"Enum\":\"DevComputerCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Orbital\",\"tags\":[],\"Value\":3,\"Enum\":\"DevComputerCameraMovementMode\"},{\"type\":\"Enum\",\"Name\":\"DevComputerMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UserChoice\",\"tags\":[],\"Value\":0,\"Enum\":\"DevComputerMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"KeyboardMouse\",\"tags\":[],\"Value\":1,\"Enum\":\"DevComputerMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"ClickToMove\",\"tags\":[],\"Value\":2,\"Enum\":\"DevComputerMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Scriptable\",\"tags\":[],\"Value\":3,\"Enum\":\"DevComputerMovementMode\"},{\"type\":\"Enum\",\"Name\":\"DevTouchCameraMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UserChoice\",\"tags\":[],\"Value\":0,\"Enum\":\"DevTouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":1,\"Enum\":\"DevTouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":2,\"Enum\":\"DevTouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Orbital\",\"tags\":[],\"Value\":3,\"Enum\":\"DevTouchCameraMovementMode\"},{\"type\":\"Enum\",\"Name\":\"DevTouchMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UserChoice\",\"tags\":[],\"Value\":0,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbstick\",\"tags\":[],\"Value\":1,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"DPad\",\"tags\":[],\"Value\":2,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbpad\",\"tags\":[],\"Value\":3,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"ClickToMove\",\"tags\":[],\"Value\":4,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Scriptable\",\"tags\":[],\"Value\":5,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"DynamicThumbstick\",\"tags\":[],\"Value\":6,\"Enum\":\"DevTouchMovementMode\"},{\"type\":\"Enum\",\"Name\":\"DeveloperMemoryTag\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Internal\",\"tags\":[],\"Value\":0,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"HttpCache\",\"tags\":[],\"Value\":1,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Instances\",\"tags\":[],\"Value\":2,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Signals\",\"tags\":[],\"Value\":3,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"LuaHeap\",\"tags\":[],\"Value\":4,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Script\",\"tags\":[],\"Value\":5,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"PhysicsCollision\",\"tags\":[],\"Value\":6,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"PhysicsParts\",\"tags\":[],\"Value\":7,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsSolidModels\",\"tags\":[],\"Value\":8,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsMeshParts\",\"tags\":[],\"Value\":9,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsParticles\",\"tags\":[],\"Value\":10,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsParts\",\"tags\":[],\"Value\":11,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsSpatialHash\",\"tags\":[],\"Value\":12,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsTerrain\",\"tags\":[],\"Value\":13,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsTexture\",\"tags\":[],\"Value\":14,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"GraphicsTextureCharacter\",\"tags\":[],\"Value\":15,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Sounds\",\"tags\":[],\"Value\":16,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"StreamingSounds\",\"tags\":[],\"Value\":17,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"TerrainVoxels\",\"tags\":[],\"Value\":18,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Gui\",\"tags\":[],\"Value\":20,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Animation\",\"tags\":[],\"Value\":21,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"EnumItem\",\"Name\":\"Navigation\",\"tags\":[],\"Value\":22,\"Enum\":\"DeveloperMemoryTag\"},{\"type\":\"Enum\",\"Name\":\"DialogBehaviorType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"SinglePlayer\",\"tags\":[],\"Value\":0,\"Enum\":\"DialogBehaviorType\"},{\"type\":\"EnumItem\",\"Name\":\"MultiplePlayers\",\"tags\":[],\"Value\":1,\"Enum\":\"DialogBehaviorType\"},{\"type\":\"Enum\",\"Name\":\"DialogPurpose\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Quest\",\"tags\":[],\"Value\":0,\"Enum\":\"DialogPurpose\"},{\"type\":\"EnumItem\",\"Name\":\"Help\",\"tags\":[],\"Value\":1,\"Enum\":\"DialogPurpose\"},{\"type\":\"EnumItem\",\"Name\":\"Shop\",\"tags\":[],\"Value\":2,\"Enum\":\"DialogPurpose\"},{\"type\":\"Enum\",\"Name\":\"DialogTone\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Neutral\",\"tags\":[],\"Value\":0,\"Enum\":\"DialogTone\"},{\"type\":\"EnumItem\",\"Name\":\"Friendly\",\"tags\":[],\"Value\":1,\"Enum\":\"DialogTone\"},{\"type\":\"EnumItem\",\"Name\":\"Enemy\",\"tags\":[],\"Value\":2,\"Enum\":\"DialogTone\"},{\"type\":\"Enum\",\"Name\":\"DominantAxis\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Width\",\"tags\":[],\"Value\":0,\"Enum\":\"DominantAxis\"},{\"type\":\"EnumItem\",\"Name\":\"Height\",\"tags\":[],\"Value\":1,\"Enum\":\"DominantAxis\"},{\"type\":\"Enum\",\"Name\":\"EasingDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"In\",\"tags\":[],\"Value\":0,\"Enum\":\"EasingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Out\",\"tags\":[],\"Value\":1,\"Enum\":\"EasingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"InOut\",\"tags\":[],\"Value\":2,\"Enum\":\"EasingDirection\"},{\"type\":\"Enum\",\"Name\":\"EasingStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Linear\",\"tags\":[],\"Value\":0,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Sine\",\"tags\":[],\"Value\":1,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Back\",\"tags\":[],\"Value\":2,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Quad\",\"tags\":[],\"Value\":3,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Quart\",\"tags\":[],\"Value\":4,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Quint\",\"tags\":[],\"Value\":5,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Bounce\",\"tags\":[],\"Value\":6,\"Enum\":\"EasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Elastic\",\"tags\":[],\"Value\":7,\"Enum\":\"EasingStyle\"},{\"type\":\"Enum\",\"Name\":\"ElasticBehavior\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"WhenScrollable\",\"tags\":[],\"Value\":0,\"Enum\":\"ElasticBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"Always\",\"tags\":[],\"Value\":1,\"Enum\":\"ElasticBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"Never\",\"tags\":[],\"Value\":2,\"Enum\":\"ElasticBehavior\"},{\"type\":\"Enum\",\"Name\":\"EnviromentalPhysicsThrottle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"DefaultAuto\",\"tags\":[],\"Value\":0,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Disabled\",\"tags\":[],\"Value\":1,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Always\",\"tags\":[],\"Value\":2,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Skip2\",\"tags\":[],\"Value\":3,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Skip4\",\"tags\":[],\"Value\":4,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Skip8\",\"tags\":[],\"Value\":5,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"EnumItem\",\"Name\":\"Skip16\",\"tags\":[],\"Value\":6,\"Enum\":\"EnviromentalPhysicsThrottle\"},{\"type\":\"Enum\",\"Name\":\"ErrorReporting\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"DontReport\",\"tags\":[],\"Value\":0,\"Enum\":\"ErrorReporting\"},{\"type\":\"EnumItem\",\"Name\":\"Prompt\",\"tags\":[],\"Value\":1,\"Enum\":\"ErrorReporting\"},{\"type\":\"EnumItem\",\"Name\":\"Report\",\"tags\":[],\"Value\":2,\"Enum\":\"ErrorReporting\"},{\"type\":\"Enum\",\"Name\":\"ExplosionType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NoCraters\",\"tags\":[],\"Value\":0,\"Enum\":\"ExplosionType\"},{\"type\":\"EnumItem\",\"Name\":\"Craters\",\"tags\":[],\"Value\":1,\"Enum\":\"ExplosionType\"},{\"type\":\"EnumItem\",\"Name\":\"CratersAndDebris\",\"tags\":[],\"Value\":2,\"Enum\":\"ExplosionType\"},{\"type\":\"Enum\",\"Name\":\"FillDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Horizontal\",\"tags\":[],\"Value\":0,\"Enum\":\"FillDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Vertical\",\"tags\":[],\"Value\":1,\"Enum\":\"FillDirection\"},{\"type\":\"Enum\",\"Name\":\"FilterResult\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Rejected\",\"tags\":[],\"Value\":1,\"Enum\":\"FilterResult\"},{\"type\":\"EnumItem\",\"Name\":\"Accepted\",\"tags\":[],\"Value\":0,\"Enum\":\"FilterResult\"},{\"type\":\"Enum\",\"Name\":\"Font\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Legacy\",\"tags\":[],\"Value\":0,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Arial\",\"tags\":[],\"Value\":1,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"ArialBold\",\"tags\":[],\"Value\":2,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SourceSans\",\"tags\":[],\"Value\":3,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SourceSansBold\",\"tags\":[],\"Value\":4,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SourceSansSemibold\",\"tags\":[],\"Value\":16,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SourceSansLight\",\"tags\":[],\"Value\":5,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SourceSansItalic\",\"tags\":[],\"Value\":6,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Bodoni\",\"tags\":[],\"Value\":7,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Garamond\",\"tags\":[],\"Value\":8,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Cartoon\",\"tags\":[],\"Value\":9,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Code\",\"tags\":[],\"Value\":10,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Highway\",\"tags\":[],\"Value\":11,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"SciFi\",\"tags\":[],\"Value\":12,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Arcade\",\"tags\":[],\"Value\":13,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Fantasy\",\"tags\":[],\"Value\":14,\"Enum\":\"Font\"},{\"type\":\"EnumItem\",\"Name\":\"Antique\",\"tags\":[],\"Value\":15,\"Enum\":\"Font\"},{\"type\":\"Enum\",\"Name\":\"FontSize\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Size8\",\"tags\":[],\"Value\":0,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size9\",\"tags\":[],\"Value\":1,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size10\",\"tags\":[],\"Value\":2,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size11\",\"tags\":[],\"Value\":3,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size12\",\"tags\":[],\"Value\":4,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size14\",\"tags\":[],\"Value\":5,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size18\",\"tags\":[],\"Value\":6,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size24\",\"tags\":[],\"Value\":7,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size36\",\"tags\":[],\"Value\":8,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size48\",\"tags\":[],\"Value\":9,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size28\",\"tags\":[],\"Value\":10,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size32\",\"tags\":[],\"Value\":11,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size42\",\"tags\":[],\"Value\":12,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size60\",\"tags\":[],\"Value\":13,\"Enum\":\"FontSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size96\",\"tags\":[],\"Value\":14,\"Enum\":\"FontSize\"},{\"type\":\"Enum\",\"Name\":\"FormFactor\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Symmetric\",\"tags\":[],\"Value\":0,\"Enum\":\"FormFactor\"},{\"type\":\"EnumItem\",\"Name\":\"Brick\",\"tags\":[],\"Value\":1,\"Enum\":\"FormFactor\"},{\"type\":\"EnumItem\",\"Name\":\"Plate\",\"tags\":[],\"Value\":2,\"Enum\":\"FormFactor\"},{\"type\":\"EnumItem\",\"Name\":\"Custom\",\"tags\":[],\"Value\":3,\"Enum\":\"FormFactor\"},{\"type\":\"Enum\",\"Name\":\"FrameStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Custom\",\"tags\":[],\"Value\":0,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"ChatBlue\",\"tags\":[],\"Value\":1,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxSquare\",\"tags\":[],\"Value\":2,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"RobloxRound\",\"tags\":[],\"Value\":3,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"ChatGreen\",\"tags\":[],\"Value\":4,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"ChatRed\",\"tags\":[],\"Value\":5,\"Enum\":\"FrameStyle\"},{\"type\":\"EnumItem\",\"Name\":\"DropShadow\",\"tags\":[],\"Value\":6,\"Enum\":\"FrameStyle\"},{\"type\":\"Enum\",\"Name\":\"FramerateManagerMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Automatic\",\"tags\":[],\"Value\":0,\"Enum\":\"FramerateManagerMode\"},{\"type\":\"EnumItem\",\"Name\":\"On\",\"tags\":[],\"Value\":1,\"Enum\":\"FramerateManagerMode\"},{\"type\":\"EnumItem\",\"Name\":\"Off\",\"tags\":[],\"Value\":2,\"Enum\":\"FramerateManagerMode\"},{\"type\":\"Enum\",\"Name\":\"FriendRequestEvent\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Issue\",\"tags\":[],\"Value\":0,\"Enum\":\"FriendRequestEvent\"},{\"type\":\"EnumItem\",\"Name\":\"Revoke\",\"tags\":[],\"Value\":1,\"Enum\":\"FriendRequestEvent\"},{\"type\":\"EnumItem\",\"Name\":\"Accept\",\"tags\":[],\"Value\":2,\"Enum\":\"FriendRequestEvent\"},{\"type\":\"EnumItem\",\"Name\":\"Deny\",\"tags\":[],\"Value\":3,\"Enum\":\"FriendRequestEvent\"},{\"type\":\"Enum\",\"Name\":\"FriendStatus\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Unknown\",\"tags\":[],\"Value\":0,\"Enum\":\"FriendStatus\"},{\"type\":\"EnumItem\",\"Name\":\"NotFriend\",\"tags\":[],\"Value\":1,\"Enum\":\"FriendStatus\"},{\"type\":\"EnumItem\",\"Name\":\"Friend\",\"tags\":[],\"Value\":2,\"Enum\":\"FriendStatus\"},{\"type\":\"EnumItem\",\"Name\":\"FriendRequestSent\",\"tags\":[],\"Value\":3,\"Enum\":\"FriendStatus\"},{\"type\":\"EnumItem\",\"Name\":\"FriendRequestReceived\",\"tags\":[],\"Value\":4,\"Enum\":\"FriendStatus\"},{\"type\":\"Enum\",\"Name\":\"FunctionalTestResult\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Passed\",\"tags\":[],\"Value\":0,\"Enum\":\"FunctionalTestResult\"},{\"type\":\"EnumItem\",\"Name\":\"Warning\",\"tags\":[],\"Value\":1,\"Enum\":\"FunctionalTestResult\"},{\"type\":\"EnumItem\",\"Name\":\"Error\",\"tags\":[],\"Value\":2,\"Enum\":\"FunctionalTestResult\"},{\"type\":\"Enum\",\"Name\":\"GameAvatarType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"R6\",\"tags\":[],\"Value\":0,\"Enum\":\"GameAvatarType\"},{\"type\":\"EnumItem\",\"Name\":\"R15\",\"tags\":[],\"Value\":1,\"Enum\":\"GameAvatarType\"},{\"type\":\"EnumItem\",\"Name\":\"PlayerChoice\",\"tags\":[],\"Value\":2,\"Enum\":\"GameAvatarType\"},{\"type\":\"Enum\",\"Name\":\"GearGenreSetting\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"AllGenres\",\"tags\":[],\"Value\":0,\"Enum\":\"GearGenreSetting\"},{\"type\":\"EnumItem\",\"Name\":\"MatchingGenreOnly\",\"tags\":[],\"Value\":1,\"Enum\":\"GearGenreSetting\"},{\"type\":\"Enum\",\"Name\":\"GearType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"MeleeWeapons\",\"tags\":[],\"Value\":0,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"RangedWeapons\",\"tags\":[],\"Value\":1,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"Explosives\",\"tags\":[],\"Value\":2,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"PowerUps\",\"tags\":[],\"Value\":3,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"NavigationEnhancers\",\"tags\":[],\"Value\":4,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"MusicalInstruments\",\"tags\":[],\"Value\":5,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"SocialItems\",\"tags\":[],\"Value\":6,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"BuildingTools\",\"tags\":[],\"Value\":7,\"Enum\":\"GearType\"},{\"type\":\"EnumItem\",\"Name\":\"Transport\",\"tags\":[],\"Value\":8,\"Enum\":\"GearType\"},{\"type\":\"Enum\",\"Name\":\"Genre\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"All\",\"tags\":[],\"Value\":0,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"TownAndCity\",\"tags\":[],\"Value\":1,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Fantasy\",\"tags\":[],\"Value\":2,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"SciFi\",\"tags\":[],\"Value\":3,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Ninja\",\"tags\":[],\"Value\":4,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Scary\",\"tags\":[],\"Value\":5,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Pirate\",\"tags\":[],\"Value\":6,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Adventure\",\"tags\":[],\"Value\":7,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Sports\",\"tags\":[],\"Value\":8,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Funny\",\"tags\":[],\"Value\":9,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"WildWest\",\"tags\":[],\"Value\":10,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"War\",\"tags\":[],\"Value\":11,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"SkatePark\",\"tags\":[],\"Value\":12,\"Enum\":\"Genre\"},{\"type\":\"EnumItem\",\"Name\":\"Tutorial\",\"tags\":[],\"Value\":13,\"Enum\":\"Genre\"},{\"type\":\"Enum\",\"Name\":\"GraphicsMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Automatic\",\"tags\":[],\"Value\":1,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"Direct3D9\",\"tags\":[],\"Value\":3,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"Direct3D11\",\"tags\":[],\"Value\":2,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"OpenGL\",\"tags\":[],\"Value\":4,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"Metal\",\"tags\":[],\"Value\":5,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"Vulkan\",\"tags\":[],\"Value\":6,\"Enum\":\"GraphicsMode\"},{\"type\":\"EnumItem\",\"Name\":\"NoGraphics\",\"tags\":[],\"Value\":7,\"Enum\":\"GraphicsMode\"},{\"type\":\"Enum\",\"Name\":\"HandlesStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Resize\",\"tags\":[],\"Value\":0,\"Enum\":\"HandlesStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Movement\",\"tags\":[],\"Value\":1,\"Enum\":\"HandlesStyle\"},{\"type\":\"Enum\",\"Name\":\"HorizontalAlignment\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":0,\"Enum\":\"HorizontalAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":1,\"Enum\":\"HorizontalAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":2,\"Enum\":\"HorizontalAlignment\"},{\"type\":\"Enum\",\"Name\":\"HttpCachePolicy\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"HttpCachePolicy\"},{\"type\":\"EnumItem\",\"Name\":\"Full\",\"tags\":[],\"Value\":1,\"Enum\":\"HttpCachePolicy\"},{\"type\":\"EnumItem\",\"Name\":\"DataOnly\",\"tags\":[],\"Value\":2,\"Enum\":\"HttpCachePolicy\"},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":3,\"Enum\":\"HttpCachePolicy\"},{\"type\":\"EnumItem\",\"Name\":\"InternalRedirectRefresh\",\"tags\":[],\"Value\":4,\"Enum\":\"HttpCachePolicy\"},{\"type\":\"Enum\",\"Name\":\"HttpContentType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"ApplicationJson\",\"tags\":[],\"Value\":0,\"Enum\":\"HttpContentType\"},{\"type\":\"EnumItem\",\"Name\":\"ApplicationXml\",\"tags\":[],\"Value\":1,\"Enum\":\"HttpContentType\"},{\"type\":\"EnumItem\",\"Name\":\"ApplicationUrlEncoded\",\"tags\":[],\"Value\":2,\"Enum\":\"HttpContentType\"},{\"type\":\"EnumItem\",\"Name\":\"TextPlain\",\"tags\":[],\"Value\":3,\"Enum\":\"HttpContentType\"},{\"type\":\"EnumItem\",\"Name\":\"TextXml\",\"tags\":[],\"Value\":4,\"Enum\":\"HttpContentType\"},{\"type\":\"Enum\",\"Name\":\"HttpError\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"OK\",\"tags\":[],\"Value\":0,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"InvalidUrl\",\"tags\":[],\"Value\":1,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"DnsResolve\",\"tags\":[],\"Value\":2,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"ConnectFail\",\"tags\":[],\"Value\":3,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"OutOfMemory\",\"tags\":[],\"Value\":4,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"TimedOut\",\"tags\":[],\"Value\":5,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"TooManyRedirects\",\"tags\":[],\"Value\":6,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"InvalidRedirect\",\"tags\":[],\"Value\":7,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"NetFail\",\"tags\":[],\"Value\":8,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"Aborted\",\"tags\":[],\"Value\":9,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"SslConnectFail\",\"tags\":[],\"Value\":10,\"Enum\":\"HttpError\"},{\"type\":\"EnumItem\",\"Name\":\"Unknown\",\"tags\":[],\"Value\":11,\"Enum\":\"HttpError\"},{\"type\":\"Enum\",\"Name\":\"HttpRequestType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"HttpRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"MarketplaceService\",\"tags\":[],\"Value\":2,\"Enum\":\"HttpRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"Players\",\"tags\":[],\"Value\":7,\"Enum\":\"HttpRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"Chat\",\"tags\":[],\"Value\":15,\"Enum\":\"HttpRequestType\"},{\"type\":\"EnumItem\",\"Name\":\"Avatar\",\"tags\":[],\"Value\":16,\"Enum\":\"HttpRequestType\"},{\"type\":\"Enum\",\"Name\":\"HumanoidDisplayDistanceType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Viewer\",\"tags\":[],\"Value\":0,\"Enum\":\"HumanoidDisplayDistanceType\"},{\"type\":\"EnumItem\",\"Name\":\"Subject\",\"tags\":[],\"Value\":1,\"Enum\":\"HumanoidDisplayDistanceType\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":2,\"Enum\":\"HumanoidDisplayDistanceType\"},{\"type\":\"Enum\",\"Name\":\"HumanoidHealthDisplayType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"DisplayWhenDamaged\",\"tags\":[],\"Value\":0,\"Enum\":\"HumanoidHealthDisplayType\"},{\"type\":\"EnumItem\",\"Name\":\"AlwaysOn\",\"tags\":[],\"Value\":1,\"Enum\":\"HumanoidHealthDisplayType\"},{\"type\":\"EnumItem\",\"Name\":\"AlwaysOff\",\"tags\":[],\"Value\":2,\"Enum\":\"HumanoidHealthDisplayType\"},{\"type\":\"Enum\",\"Name\":\"HumanoidRigType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"R6\",\"tags\":[],\"Value\":0,\"Enum\":\"HumanoidRigType\"},{\"type\":\"EnumItem\",\"Name\":\"R15\",\"tags\":[],\"Value\":1,\"Enum\":\"HumanoidRigType\"},{\"type\":\"Enum\",\"Name\":\"HumanoidStateType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"FallingDown\",\"tags\":[],\"Value\":0,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Running\",\"tags\":[],\"Value\":8,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"RunningNoPhysics\",\"tags\":[],\"Value\":10,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Climbing\",\"tags\":[],\"Value\":12,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"StrafingNoPhysics\",\"tags\":[],\"Value\":11,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Ragdoll\",\"tags\":[],\"Value\":1,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"GettingUp\",\"tags\":[],\"Value\":2,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Jumping\",\"tags\":[],\"Value\":3,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Landed\",\"tags\":[],\"Value\":7,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Flying\",\"tags\":[],\"Value\":6,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Freefall\",\"tags\":[],\"Value\":5,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Seated\",\"tags\":[],\"Value\":13,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"PlatformStanding\",\"tags\":[],\"Value\":14,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Dead\",\"tags\":[],\"Value\":15,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Swimming\",\"tags\":[],\"Value\":4,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"Physics\",\"tags\":[],\"Value\":16,\"Enum\":\"HumanoidStateType\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":18,\"Enum\":\"HumanoidStateType\"},{\"type\":\"Enum\",\"Name\":\"InOut\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Edge\",\"tags\":[],\"Value\":0,\"Enum\":\"InOut\"},{\"type\":\"EnumItem\",\"Name\":\"Inset\",\"tags\":[],\"Value\":1,\"Enum\":\"InOut\"},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":2,\"Enum\":\"InOut\"},{\"type\":\"Enum\",\"Name\":\"InfoType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Asset\",\"tags\":[],\"Value\":0,\"Enum\":\"InfoType\"},{\"type\":\"EnumItem\",\"Name\":\"Product\",\"tags\":[],\"Value\":1,\"Enum\":\"InfoType\"},{\"type\":\"EnumItem\",\"Name\":\"GamePass\",\"tags\":[],\"Value\":2,\"Enum\":\"InfoType\"},{\"type\":\"Enum\",\"Name\":\"InitialDockState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Top\",\"tags\":[],\"Value\":0,\"Enum\":\"InitialDockState\"},{\"type\":\"EnumItem\",\"Name\":\"Bottom\",\"tags\":[],\"Value\":1,\"Enum\":\"InitialDockState\"},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":2,\"Enum\":\"InitialDockState\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":3,\"Enum\":\"InitialDockState\"},{\"type\":\"EnumItem\",\"Name\":\"Float\",\"tags\":[],\"Value\":4,\"Enum\":\"InitialDockState\"},{\"type\":\"Enum\",\"Name\":\"InputType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NoInput\",\"tags\":[],\"Value\":0,\"Enum\":\"InputType\"},{\"type\":\"EnumItem\",\"Name\":\"Constant\",\"tags\":[],\"Value\":12,\"Enum\":\"InputType\"},{\"type\":\"EnumItem\",\"Name\":\"Sin\",\"tags\":[],\"Value\":13,\"Enum\":\"InputType\"},{\"type\":\"Enum\",\"Name\":\"JointCreationMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"All\",\"tags\":[],\"Value\":0,\"Enum\":\"JointCreationMode\"},{\"type\":\"EnumItem\",\"Name\":\"Surface\",\"tags\":[],\"Value\":1,\"Enum\":\"JointCreationMode\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":2,\"Enum\":\"JointCreationMode\"},{\"type\":\"Enum\",\"Name\":\"JointType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":28,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"Rotate\",\"tags\":[],\"Value\":7,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"RotateP\",\"tags\":[],\"Value\":8,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"RotateV\",\"tags\":[],\"Value\":9,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"Glue\",\"tags\":[],\"Value\":10,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"Weld\",\"tags\":[],\"Value\":1,\"Enum\":\"JointType\"},{\"type\":\"EnumItem\",\"Name\":\"Snap\",\"tags\":[],\"Value\":3,\"Enum\":\"JointType\"},{\"type\":\"Enum\",\"Name\":\"KeyCode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Unknown\",\"tags\":[],\"Value\":0,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Backspace\",\"tags\":[],\"Value\":8,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Tab\",\"tags\":[],\"Value\":9,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Clear\",\"tags\":[],\"Value\":12,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Return\",\"tags\":[],\"Value\":13,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Pause\",\"tags\":[],\"Value\":19,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Escape\",\"tags\":[],\"Value\":27,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Space\",\"tags\":[],\"Value\":32,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"QuotedDouble\",\"tags\":[],\"Value\":34,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Hash\",\"tags\":[],\"Value\":35,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Dollar\",\"tags\":[],\"Value\":36,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Percent\",\"tags\":[],\"Value\":37,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Ampersand\",\"tags\":[],\"Value\":38,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Quote\",\"tags\":[],\"Value\":39,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftParenthesis\",\"tags\":[],\"Value\":40,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightParenthesis\",\"tags\":[],\"Value\":41,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Asterisk\",\"tags\":[],\"Value\":42,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Plus\",\"tags\":[],\"Value\":43,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Comma\",\"tags\":[],\"Value\":44,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Minus\",\"tags\":[],\"Value\":45,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Period\",\"tags\":[],\"Value\":46,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Slash\",\"tags\":[],\"Value\":47,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Zero\",\"tags\":[],\"Value\":48,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"One\",\"tags\":[],\"Value\":49,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Two\",\"tags\":[],\"Value\":50,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Three\",\"tags\":[],\"Value\":51,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Four\",\"tags\":[],\"Value\":52,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Five\",\"tags\":[],\"Value\":53,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Six\",\"tags\":[],\"Value\":54,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Seven\",\"tags\":[],\"Value\":55,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Eight\",\"tags\":[],\"Value\":56,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Nine\",\"tags\":[],\"Value\":57,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Colon\",\"tags\":[],\"Value\":58,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Semicolon\",\"tags\":[],\"Value\":59,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LessThan\",\"tags\":[],\"Value\":60,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Equals\",\"tags\":[],\"Value\":61,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"GreaterThan\",\"tags\":[],\"Value\":62,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Question\",\"tags\":[],\"Value\":63,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"At\",\"tags\":[],\"Value\":64,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftBracket\",\"tags\":[],\"Value\":91,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"BackSlash\",\"tags\":[],\"Value\":92,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightBracket\",\"tags\":[],\"Value\":93,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Caret\",\"tags\":[],\"Value\":94,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Underscore\",\"tags\":[],\"Value\":95,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Backquote\",\"tags\":[],\"Value\":96,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"A\",\"tags\":[],\"Value\":97,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"B\",\"tags\":[],\"Value\":98,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"C\",\"tags\":[],\"Value\":99,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"D\",\"tags\":[],\"Value\":100,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"E\",\"tags\":[],\"Value\":101,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F\",\"tags\":[],\"Value\":102,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"G\",\"tags\":[],\"Value\":103,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"H\",\"tags\":[],\"Value\":104,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"I\",\"tags\":[],\"Value\":105,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"J\",\"tags\":[],\"Value\":106,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"K\",\"tags\":[],\"Value\":107,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"L\",\"tags\":[],\"Value\":108,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"M\",\"tags\":[],\"Value\":109,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"N\",\"tags\":[],\"Value\":110,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"O\",\"tags\":[],\"Value\":111,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"P\",\"tags\":[],\"Value\":112,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Q\",\"tags\":[],\"Value\":113,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"R\",\"tags\":[],\"Value\":114,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"S\",\"tags\":[],\"Value\":115,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"T\",\"tags\":[],\"Value\":116,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"U\",\"tags\":[],\"Value\":117,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"V\",\"tags\":[],\"Value\":118,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"W\",\"tags\":[],\"Value\":119,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"X\",\"tags\":[],\"Value\":120,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Y\",\"tags\":[],\"Value\":121,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Z\",\"tags\":[],\"Value\":122,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftCurly\",\"tags\":[],\"Value\":123,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Pipe\",\"tags\":[],\"Value\":124,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightCurly\",\"tags\":[],\"Value\":125,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Tilde\",\"tags\":[],\"Value\":126,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Delete\",\"tags\":[],\"Value\":127,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadZero\",\"tags\":[],\"Value\":256,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadOne\",\"tags\":[],\"Value\":257,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadTwo\",\"tags\":[],\"Value\":258,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadThree\",\"tags\":[],\"Value\":259,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadFour\",\"tags\":[],\"Value\":260,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadFive\",\"tags\":[],\"Value\":261,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadSix\",\"tags\":[],\"Value\":262,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadSeven\",\"tags\":[],\"Value\":263,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadEight\",\"tags\":[],\"Value\":264,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadNine\",\"tags\":[],\"Value\":265,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadPeriod\",\"tags\":[],\"Value\":266,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadDivide\",\"tags\":[],\"Value\":267,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadMultiply\",\"tags\":[],\"Value\":268,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadMinus\",\"tags\":[],\"Value\":269,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadPlus\",\"tags\":[],\"Value\":270,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadEnter\",\"tags\":[],\"Value\":271,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"KeypadEquals\",\"tags\":[],\"Value\":272,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Up\",\"tags\":[],\"Value\":273,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Down\",\"tags\":[],\"Value\":274,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":275,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":276,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Insert\",\"tags\":[],\"Value\":277,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Home\",\"tags\":[],\"Value\":278,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"End\",\"tags\":[],\"Value\":279,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"PageUp\",\"tags\":[],\"Value\":280,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"PageDown\",\"tags\":[],\"Value\":281,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftShift\",\"tags\":[],\"Value\":304,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightShift\",\"tags\":[],\"Value\":303,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftMeta\",\"tags\":[],\"Value\":310,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightMeta\",\"tags\":[],\"Value\":309,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftAlt\",\"tags\":[],\"Value\":308,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightAlt\",\"tags\":[],\"Value\":307,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftControl\",\"tags\":[],\"Value\":306,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightControl\",\"tags\":[],\"Value\":305,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"CapsLock\",\"tags\":[],\"Value\":301,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"NumLock\",\"tags\":[],\"Value\":300,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ScrollLock\",\"tags\":[],\"Value\":302,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"LeftSuper\",\"tags\":[],\"Value\":311,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"RightSuper\",\"tags\":[],\"Value\":312,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Mode\",\"tags\":[],\"Value\":313,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Compose\",\"tags\":[],\"Value\":314,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Help\",\"tags\":[],\"Value\":315,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Print\",\"tags\":[],\"Value\":316,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"SysReq\",\"tags\":[],\"Value\":317,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Break\",\"tags\":[],\"Value\":318,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Menu\",\"tags\":[],\"Value\":319,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Power\",\"tags\":[],\"Value\":320,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Euro\",\"tags\":[],\"Value\":321,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Undo\",\"tags\":[],\"Value\":322,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F1\",\"tags\":[],\"Value\":282,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F2\",\"tags\":[],\"Value\":283,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F3\",\"tags\":[],\"Value\":284,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F4\",\"tags\":[],\"Value\":285,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F5\",\"tags\":[],\"Value\":286,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F6\",\"tags\":[],\"Value\":287,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F7\",\"tags\":[],\"Value\":288,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F8\",\"tags\":[],\"Value\":289,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F9\",\"tags\":[],\"Value\":290,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F10\",\"tags\":[],\"Value\":291,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F11\",\"tags\":[],\"Value\":292,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F12\",\"tags\":[],\"Value\":293,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F13\",\"tags\":[],\"Value\":294,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F14\",\"tags\":[],\"Value\":295,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"F15\",\"tags\":[],\"Value\":296,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World0\",\"tags\":[],\"Value\":160,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World1\",\"tags\":[],\"Value\":161,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World2\",\"tags\":[],\"Value\":162,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World3\",\"tags\":[],\"Value\":163,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World4\",\"tags\":[],\"Value\":164,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World5\",\"tags\":[],\"Value\":165,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World6\",\"tags\":[],\"Value\":166,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World7\",\"tags\":[],\"Value\":167,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World8\",\"tags\":[],\"Value\":168,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World9\",\"tags\":[],\"Value\":169,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World10\",\"tags\":[],\"Value\":170,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World11\",\"tags\":[],\"Value\":171,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World12\",\"tags\":[],\"Value\":172,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World13\",\"tags\":[],\"Value\":173,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World14\",\"tags\":[],\"Value\":174,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World15\",\"tags\":[],\"Value\":175,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World16\",\"tags\":[],\"Value\":176,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World17\",\"tags\":[],\"Value\":177,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World18\",\"tags\":[],\"Value\":178,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World19\",\"tags\":[],\"Value\":179,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World20\",\"tags\":[],\"Value\":180,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World21\",\"tags\":[],\"Value\":181,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World22\",\"tags\":[],\"Value\":182,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World23\",\"tags\":[],\"Value\":183,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World24\",\"tags\":[],\"Value\":184,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World25\",\"tags\":[],\"Value\":185,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World26\",\"tags\":[],\"Value\":186,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World27\",\"tags\":[],\"Value\":187,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World28\",\"tags\":[],\"Value\":188,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World29\",\"tags\":[],\"Value\":189,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World30\",\"tags\":[],\"Value\":190,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World31\",\"tags\":[],\"Value\":191,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World32\",\"tags\":[],\"Value\":192,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World33\",\"tags\":[],\"Value\":193,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World34\",\"tags\":[],\"Value\":194,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World35\",\"tags\":[],\"Value\":195,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World36\",\"tags\":[],\"Value\":196,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World37\",\"tags\":[],\"Value\":197,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World38\",\"tags\":[],\"Value\":198,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World39\",\"tags\":[],\"Value\":199,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World40\",\"tags\":[],\"Value\":200,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World41\",\"tags\":[],\"Value\":201,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World42\",\"tags\":[],\"Value\":202,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World43\",\"tags\":[],\"Value\":203,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World44\",\"tags\":[],\"Value\":204,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World45\",\"tags\":[],\"Value\":205,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World46\",\"tags\":[],\"Value\":206,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World47\",\"tags\":[],\"Value\":207,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World48\",\"tags\":[],\"Value\":208,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World49\",\"tags\":[],\"Value\":209,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World50\",\"tags\":[],\"Value\":210,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World51\",\"tags\":[],\"Value\":211,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World52\",\"tags\":[],\"Value\":212,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World53\",\"tags\":[],\"Value\":213,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World54\",\"tags\":[],\"Value\":214,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World55\",\"tags\":[],\"Value\":215,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World56\",\"tags\":[],\"Value\":216,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World57\",\"tags\":[],\"Value\":217,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World58\",\"tags\":[],\"Value\":218,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World59\",\"tags\":[],\"Value\":219,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World60\",\"tags\":[],\"Value\":220,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World61\",\"tags\":[],\"Value\":221,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World62\",\"tags\":[],\"Value\":222,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World63\",\"tags\":[],\"Value\":223,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World64\",\"tags\":[],\"Value\":224,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World65\",\"tags\":[],\"Value\":225,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World66\",\"tags\":[],\"Value\":226,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World67\",\"tags\":[],\"Value\":227,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World68\",\"tags\":[],\"Value\":228,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World69\",\"tags\":[],\"Value\":229,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World70\",\"tags\":[],\"Value\":230,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World71\",\"tags\":[],\"Value\":231,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World72\",\"tags\":[],\"Value\":232,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World73\",\"tags\":[],\"Value\":233,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World74\",\"tags\":[],\"Value\":234,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World75\",\"tags\":[],\"Value\":235,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World76\",\"tags\":[],\"Value\":236,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World77\",\"tags\":[],\"Value\":237,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World78\",\"tags\":[],\"Value\":238,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World79\",\"tags\":[],\"Value\":239,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World80\",\"tags\":[],\"Value\":240,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World81\",\"tags\":[],\"Value\":241,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World82\",\"tags\":[],\"Value\":242,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World83\",\"tags\":[],\"Value\":243,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World84\",\"tags\":[],\"Value\":244,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World85\",\"tags\":[],\"Value\":245,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World86\",\"tags\":[],\"Value\":246,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World87\",\"tags\":[],\"Value\":247,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World88\",\"tags\":[],\"Value\":248,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World89\",\"tags\":[],\"Value\":249,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World90\",\"tags\":[],\"Value\":250,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World91\",\"tags\":[],\"Value\":251,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World92\",\"tags\":[],\"Value\":252,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World93\",\"tags\":[],\"Value\":253,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World94\",\"tags\":[],\"Value\":254,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"World95\",\"tags\":[],\"Value\":255,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonX\",\"tags\":[],\"Value\":1000,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonY\",\"tags\":[],\"Value\":1001,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonA\",\"tags\":[],\"Value\":1002,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonB\",\"tags\":[],\"Value\":1003,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonR1\",\"tags\":[],\"Value\":1004,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonL1\",\"tags\":[],\"Value\":1005,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonR2\",\"tags\":[],\"Value\":1006,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonL2\",\"tags\":[],\"Value\":1007,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonR3\",\"tags\":[],\"Value\":1008,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonL3\",\"tags\":[],\"Value\":1009,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonStart\",\"tags\":[],\"Value\":1010,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"ButtonSelect\",\"tags\":[],\"Value\":1011,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"DPadLeft\",\"tags\":[],\"Value\":1012,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"DPadRight\",\"tags\":[],\"Value\":1013,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"DPadUp\",\"tags\":[],\"Value\":1014,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"DPadDown\",\"tags\":[],\"Value\":1015,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbstick1\",\"tags\":[],\"Value\":1016,\"Enum\":\"KeyCode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbstick2\",\"tags\":[],\"Value\":1017,\"Enum\":\"KeyCode\"},{\"type\":\"Enum\",\"Name\":\"KeywordFilterType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Include\",\"tags\":[],\"Value\":0,\"Enum\":\"KeywordFilterType\"},{\"type\":\"EnumItem\",\"Name\":\"Exclude\",\"tags\":[],\"Value\":1,\"Enum\":\"KeywordFilterType\"},{\"type\":\"Enum\",\"Name\":\"Language\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"Language\"},{\"type\":\"Enum\",\"Name\":\"LeftRight\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":0,\"Enum\":\"LeftRight\"},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":1,\"Enum\":\"LeftRight\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":2,\"Enum\":\"LeftRight\"},{\"type\":\"Enum\",\"Name\":\"LevelOfDetailSetting\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"High\",\"tags\":[],\"Value\":2,\"Enum\":\"LevelOfDetailSetting\"},{\"type\":\"EnumItem\",\"Name\":\"Medium\",\"tags\":[],\"Value\":1,\"Enum\":\"LevelOfDetailSetting\"},{\"type\":\"EnumItem\",\"Name\":\"Low\",\"tags\":[],\"Value\":0,\"Enum\":\"LevelOfDetailSetting\"},{\"type\":\"Enum\",\"Name\":\"Limb\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":0,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"Torso\",\"tags\":[],\"Value\":1,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"LeftArm\",\"tags\":[],\"Value\":2,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"RightArm\",\"tags\":[],\"Value\":3,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"LeftLeg\",\"tags\":[],\"Value\":4,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"RightLeg\",\"tags\":[],\"Value\":5,\"Enum\":\"Limb\"},{\"type\":\"EnumItem\",\"Name\":\"Unknown\",\"tags\":[],\"Value\":6,\"Enum\":\"Limb\"},{\"type\":\"Enum\",\"Name\":\"ListenerType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Camera\",\"tags\":[],\"Value\":0,\"Enum\":\"ListenerType\"},{\"type\":\"EnumItem\",\"Name\":\"CFrame\",\"tags\":[],\"Value\":1,\"Enum\":\"ListenerType\"},{\"type\":\"EnumItem\",\"Name\":\"ObjectPosition\",\"tags\":[],\"Value\":2,\"Enum\":\"ListenerType\"},{\"type\":\"EnumItem\",\"Name\":\"ObjectCFrame\",\"tags\":[],\"Value\":3,\"Enum\":\"ListenerType\"},{\"type\":\"Enum\",\"Name\":\"Material\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Plastic\",\"tags\":[],\"Value\":256,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Wood\",\"tags\":[],\"Value\":512,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Slate\",\"tags\":[],\"Value\":800,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Concrete\",\"tags\":[],\"Value\":816,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"CorrodedMetal\",\"tags\":[],\"Value\":1040,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"DiamondPlate\",\"tags\":[],\"Value\":1056,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Foil\",\"tags\":[],\"Value\":1072,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Grass\",\"tags\":[],\"Value\":1280,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Ice\",\"tags\":[],\"Value\":1536,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Marble\",\"tags\":[],\"Value\":784,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Granite\",\"tags\":[],\"Value\":832,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Brick\",\"tags\":[],\"Value\":848,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Pebble\",\"tags\":[],\"Value\":864,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Sand\",\"tags\":[],\"Value\":1296,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Fabric\",\"tags\":[],\"Value\":1312,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"SmoothPlastic\",\"tags\":[],\"Value\":272,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Metal\",\"tags\":[],\"Value\":1088,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"WoodPlanks\",\"tags\":[],\"Value\":528,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Cobblestone\",\"tags\":[],\"Value\":880,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Air\",\"tags\":[\"notbrowsable\"],\"Value\":1792,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Water\",\"tags\":[\"notbrowsable\"],\"Value\":2048,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Rock\",\"tags\":[\"notbrowsable\"],\"Value\":896,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Glacier\",\"tags\":[\"notbrowsable\"],\"Value\":1552,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Snow\",\"tags\":[\"notbrowsable\"],\"Value\":1328,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Sandstone\",\"tags\":[\"notbrowsable\"],\"Value\":912,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Mud\",\"tags\":[\"notbrowsable\"],\"Value\":1344,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Basalt\",\"tags\":[\"notbrowsable\"],\"Value\":788,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Ground\",\"tags\":[\"notbrowsable\"],\"Value\":1360,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"CrackedLava\",\"tags\":[\"notbrowsable\"],\"Value\":804,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Neon\",\"tags\":[],\"Value\":288,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Glass\",\"tags\":[],\"Value\":1568,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Asphalt\",\"tags\":[\"notbrowsable\"],\"Value\":1376,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"LeafyGrass\",\"tags\":[\"notbrowsable\"],\"Value\":1284,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Salt\",\"tags\":[\"notbrowsable\"],\"Value\":1392,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Limestone\",\"tags\":[\"notbrowsable\"],\"Value\":820,\"Enum\":\"Material\"},{\"type\":\"EnumItem\",\"Name\":\"Pavement\",\"tags\":[\"notbrowsable\"],\"Value\":836,\"Enum\":\"Material\"},{\"type\":\"Enum\",\"Name\":\"MembershipType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"MembershipType\"},{\"type\":\"EnumItem\",\"Name\":\"BuildersClub\",\"tags\":[],\"Value\":1,\"Enum\":\"MembershipType\"},{\"type\":\"EnumItem\",\"Name\":\"TurboBuildersClub\",\"tags\":[],\"Value\":2,\"Enum\":\"MembershipType\"},{\"type\":\"EnumItem\",\"Name\":\"OutrageousBuildersClub\",\"tags\":[],\"Value\":3,\"Enum\":\"MembershipType\"},{\"type\":\"Enum\",\"Name\":\"MeshType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":0,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Torso\",\"tags\":[],\"Value\":1,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Wedge\",\"tags\":[],\"Value\":2,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Prism\",\"tags\":[\"deprecated\"],\"Value\":7,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Pyramid\",\"tags\":[\"deprecated\"],\"Value\":8,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"ParallelRamp\",\"tags\":[\"deprecated\"],\"Value\":9,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"RightAngleRamp\",\"tags\":[\"deprecated\"],\"Value\":10,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"CornerWedge\",\"tags\":[\"deprecated\"],\"Value\":11,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Brick\",\"tags\":[],\"Value\":6,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Sphere\",\"tags\":[],\"Value\":3,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"Cylinder\",\"tags\":[],\"Value\":4,\"Enum\":\"MeshType\"},{\"type\":\"EnumItem\",\"Name\":\"FileMesh\",\"tags\":[],\"Value\":5,\"Enum\":\"MeshType\"},{\"type\":\"Enum\",\"Name\":\"MessageType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"MessageOutput\",\"tags\":[],\"Value\":0,\"Enum\":\"MessageType\"},{\"type\":\"EnumItem\",\"Name\":\"MessageInfo\",\"tags\":[],\"Value\":1,\"Enum\":\"MessageType\"},{\"type\":\"EnumItem\",\"Name\":\"MessageWarning\",\"tags\":[],\"Value\":2,\"Enum\":\"MessageType\"},{\"type\":\"EnumItem\",\"Name\":\"MessageError\",\"tags\":[],\"Value\":3,\"Enum\":\"MessageType\"},{\"type\":\"Enum\",\"Name\":\"MouseBehavior\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"MouseBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"LockCenter\",\"tags\":[],\"Value\":1,\"Enum\":\"MouseBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"LockCurrentPosition\",\"tags\":[],\"Value\":2,\"Enum\":\"MouseBehavior\"},{\"type\":\"Enum\",\"Name\":\"MoveState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Stopped\",\"tags\":[],\"Value\":0,\"Enum\":\"MoveState\"},{\"type\":\"EnumItem\",\"Name\":\"Coasting\",\"tags\":[],\"Value\":1,\"Enum\":\"MoveState\"},{\"type\":\"EnumItem\",\"Name\":\"Pushing\",\"tags\":[],\"Value\":2,\"Enum\":\"MoveState\"},{\"type\":\"EnumItem\",\"Name\":\"Stopping\",\"tags\":[],\"Value\":3,\"Enum\":\"MoveState\"},{\"type\":\"EnumItem\",\"Name\":\"AirFree\",\"tags\":[],\"Value\":4,\"Enum\":\"MoveState\"},{\"type\":\"Enum\",\"Name\":\"NameOcclusion\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"OccludeAll\",\"tags\":[],\"Value\":2,\"Enum\":\"NameOcclusion\"},{\"type\":\"EnumItem\",\"Name\":\"EnemyOcclusion\",\"tags\":[],\"Value\":1,\"Enum\":\"NameOcclusion\"},{\"type\":\"EnumItem\",\"Name\":\"NoOcclusion\",\"tags\":[],\"Value\":0,\"Enum\":\"NameOcclusion\"},{\"type\":\"Enum\",\"Name\":\"NetworkOwnership\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Automatic\",\"tags\":[],\"Value\":0,\"Enum\":\"NetworkOwnership\"},{\"type\":\"EnumItem\",\"Name\":\"Manual\",\"tags\":[],\"Value\":1,\"Enum\":\"NetworkOwnership\"},{\"type\":\"EnumItem\",\"Name\":\"OnContact\",\"tags\":[],\"Value\":2,\"Enum\":\"NetworkOwnership\"},{\"type\":\"Enum\",\"Name\":\"NormalId\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Top\",\"tags\":[],\"Value\":1,\"Enum\":\"NormalId\"},{\"type\":\"EnumItem\",\"Name\":\"Bottom\",\"tags\":[],\"Value\":4,\"Enum\":\"NormalId\"},{\"type\":\"EnumItem\",\"Name\":\"Back\",\"tags\":[],\"Value\":2,\"Enum\":\"NormalId\"},{\"type\":\"EnumItem\",\"Name\":\"Front\",\"tags\":[],\"Value\":5,\"Enum\":\"NormalId\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":0,\"Enum\":\"NormalId\"},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":3,\"Enum\":\"NormalId\"},{\"type\":\"Enum\",\"Name\":\"OverrideMouseIconBehavior\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"OverrideMouseIconBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"ForceShow\",\"tags\":[],\"Value\":1,\"Enum\":\"OverrideMouseIconBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"ForceHide\",\"tags\":[],\"Value\":2,\"Enum\":\"OverrideMouseIconBehavior\"},{\"type\":\"Enum\",\"Name\":\"PacketPriority\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"IMMEDIATE_PRIORITY\",\"tags\":[],\"Value\":0,\"Enum\":\"PacketPriority\"},{\"type\":\"EnumItem\",\"Name\":\"HIGH_PRIORITY\",\"tags\":[],\"Value\":1,\"Enum\":\"PacketPriority\"},{\"type\":\"EnumItem\",\"Name\":\"MEDIUM_PRIORITY\",\"tags\":[],\"Value\":2,\"Enum\":\"PacketPriority\"},{\"type\":\"EnumItem\",\"Name\":\"LOW_PRIORITY\",\"tags\":[],\"Value\":3,\"Enum\":\"PacketPriority\"},{\"type\":\"Enum\",\"Name\":\"PartType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Ball\",\"tags\":[],\"Value\":0,\"Enum\":\"PartType\"},{\"type\":\"EnumItem\",\"Name\":\"Block\",\"tags\":[],\"Value\":1,\"Enum\":\"PartType\"},{\"type\":\"EnumItem\",\"Name\":\"Cylinder\",\"tags\":[],\"Value\":2,\"Enum\":\"PartType\"},{\"type\":\"Enum\",\"Name\":\"PathStatus\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Success\",\"tags\":[],\"Value\":0,\"Enum\":\"PathStatus\"},{\"type\":\"EnumItem\",\"Name\":\"ClosestNoPath\",\"tags\":[\"deprecated\"],\"Value\":1,\"Enum\":\"PathStatus\"},{\"type\":\"EnumItem\",\"Name\":\"ClosestOutOfRange\",\"tags\":[\"deprecated\"],\"Value\":2,\"Enum\":\"PathStatus\"},{\"type\":\"EnumItem\",\"Name\":\"FailStartNotEmpty\",\"tags\":[\"deprecated\"],\"Value\":3,\"Enum\":\"PathStatus\"},{\"type\":\"EnumItem\",\"Name\":\"FailFinishNotEmpty\",\"tags\":[\"deprecated\"],\"Value\":4,\"Enum\":\"PathStatus\"},{\"type\":\"EnumItem\",\"Name\":\"NoPath\",\"tags\":[],\"Value\":5,\"Enum\":\"PathStatus\"},{\"type\":\"Enum\",\"Name\":\"PathWaypointAction\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Walk\",\"tags\":[],\"Value\":0,\"Enum\":\"PathWaypointAction\"},{\"type\":\"EnumItem\",\"Name\":\"Jump\",\"tags\":[],\"Value\":1,\"Enum\":\"PathWaypointAction\"},{\"type\":\"Enum\",\"Name\":\"Platform\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Windows\",\"tags\":[],\"Value\":0,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"OSX\",\"tags\":[],\"Value\":1,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"IOS\",\"tags\":[],\"Value\":2,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"Android\",\"tags\":[],\"Value\":3,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"XBoxOne\",\"tags\":[],\"Value\":4,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"PS4\",\"tags\":[],\"Value\":5,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"PS3\",\"tags\":[],\"Value\":6,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"XBox360\",\"tags\":[],\"Value\":7,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"WiiU\",\"tags\":[],\"Value\":8,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"NX\",\"tags\":[],\"Value\":9,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"Ouya\",\"tags\":[],\"Value\":10,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"AndroidTV\",\"tags\":[],\"Value\":11,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"Chromecast\",\"tags\":[],\"Value\":12,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"Linux\",\"tags\":[],\"Value\":13,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"SteamOS\",\"tags\":[],\"Value\":14,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"WebOS\",\"tags\":[],\"Value\":15,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"DOS\",\"tags\":[],\"Value\":16,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"BeOS\",\"tags\":[],\"Value\":17,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"UWP\",\"tags\":[],\"Value\":18,\"Enum\":\"Platform\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":19,\"Enum\":\"Platform\"},{\"type\":\"Enum\",\"Name\":\"PlaybackState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Begin\",\"tags\":[],\"Value\":0,\"Enum\":\"PlaybackState\"},{\"type\":\"EnumItem\",\"Name\":\"Delayed\",\"tags\":[],\"Value\":1,\"Enum\":\"PlaybackState\"},{\"type\":\"EnumItem\",\"Name\":\"Playing\",\"tags\":[],\"Value\":2,\"Enum\":\"PlaybackState\"},{\"type\":\"EnumItem\",\"Name\":\"Paused\",\"tags\":[],\"Value\":3,\"Enum\":\"PlaybackState\"},{\"type\":\"EnumItem\",\"Name\":\"Completed\",\"tags\":[],\"Value\":4,\"Enum\":\"PlaybackState\"},{\"type\":\"EnumItem\",\"Name\":\"Cancelled\",\"tags\":[],\"Value\":5,\"Enum\":\"PlaybackState\"},{\"type\":\"Enum\",\"Name\":\"PlayerActions\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"CharacterForward\",\"tags\":[],\"Value\":0,\"Enum\":\"PlayerActions\"},{\"type\":\"EnumItem\",\"Name\":\"CharacterBackward\",\"tags\":[],\"Value\":1,\"Enum\":\"PlayerActions\"},{\"type\":\"EnumItem\",\"Name\":\"CharacterLeft\",\"tags\":[],\"Value\":2,\"Enum\":\"PlayerActions\"},{\"type\":\"EnumItem\",\"Name\":\"CharacterRight\",\"tags\":[],\"Value\":3,\"Enum\":\"PlayerActions\"},{\"type\":\"EnumItem\",\"Name\":\"CharacterJump\",\"tags\":[],\"Value\":4,\"Enum\":\"PlayerActions\"},{\"type\":\"Enum\",\"Name\":\"PlayerChatType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"All\",\"tags\":[],\"Value\":0,\"Enum\":\"PlayerChatType\"},{\"type\":\"EnumItem\",\"Name\":\"Team\",\"tags\":[],\"Value\":1,\"Enum\":\"PlayerChatType\"},{\"type\":\"EnumItem\",\"Name\":\"Whisper\",\"tags\":[],\"Value\":2,\"Enum\":\"PlayerChatType\"},{\"type\":\"Enum\",\"Name\":\"PoseEasingDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Out\",\"tags\":[],\"Value\":1,\"Enum\":\"PoseEasingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"InOut\",\"tags\":[],\"Value\":2,\"Enum\":\"PoseEasingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"In\",\"tags\":[],\"Value\":0,\"Enum\":\"PoseEasingDirection\"},{\"type\":\"Enum\",\"Name\":\"PoseEasingStyle\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Linear\",\"tags\":[],\"Value\":0,\"Enum\":\"PoseEasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Constant\",\"tags\":[],\"Value\":1,\"Enum\":\"PoseEasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Elastic\",\"tags\":[],\"Value\":2,\"Enum\":\"PoseEasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Cubic\",\"tags\":[],\"Value\":3,\"Enum\":\"PoseEasingStyle\"},{\"type\":\"EnumItem\",\"Name\":\"Bounce\",\"tags\":[],\"Value\":4,\"Enum\":\"PoseEasingStyle\"},{\"type\":\"Enum\",\"Name\":\"PrivilegeType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Owner\",\"tags\":[],\"Value\":255,\"Enum\":\"PrivilegeType\"},{\"type\":\"EnumItem\",\"Name\":\"Admin\",\"tags\":[],\"Value\":240,\"Enum\":\"PrivilegeType\"},{\"type\":\"EnumItem\",\"Name\":\"Member\",\"tags\":[],\"Value\":128,\"Enum\":\"PrivilegeType\"},{\"type\":\"EnumItem\",\"Name\":\"Visitor\",\"tags\":[],\"Value\":10,\"Enum\":\"PrivilegeType\"},{\"type\":\"EnumItem\",\"Name\":\"Banned\",\"tags\":[],\"Value\":0,\"Enum\":\"PrivilegeType\"},{\"type\":\"Enum\",\"Name\":\"ProductPurchaseDecision\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NotProcessedYet\",\"tags\":[],\"Value\":0,\"Enum\":\"ProductPurchaseDecision\"},{\"type\":\"EnumItem\",\"Name\":\"PurchaseGranted\",\"tags\":[],\"Value\":1,\"Enum\":\"ProductPurchaseDecision\"},{\"type\":\"Enum\",\"Name\":\"QualityLevel\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Automatic\",\"tags\":[],\"Value\":0,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level01\",\"tags\":[],\"Value\":1,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level02\",\"tags\":[],\"Value\":2,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level03\",\"tags\":[],\"Value\":3,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level04\",\"tags\":[],\"Value\":4,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level05\",\"tags\":[],\"Value\":5,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level06\",\"tags\":[],\"Value\":6,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level07\",\"tags\":[],\"Value\":7,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level08\",\"tags\":[],\"Value\":8,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level09\",\"tags\":[],\"Value\":9,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level10\",\"tags\":[],\"Value\":10,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level11\",\"tags\":[],\"Value\":11,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level12\",\"tags\":[],\"Value\":12,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level13\",\"tags\":[],\"Value\":13,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level14\",\"tags\":[],\"Value\":14,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level15\",\"tags\":[],\"Value\":15,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level16\",\"tags\":[],\"Value\":16,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level17\",\"tags\":[],\"Value\":17,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level18\",\"tags\":[],\"Value\":18,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level19\",\"tags\":[],\"Value\":19,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level20\",\"tags\":[],\"Value\":20,\"Enum\":\"QualityLevel\"},{\"type\":\"EnumItem\",\"Name\":\"Level21\",\"tags\":[],\"Value\":21,\"Enum\":\"QualityLevel\"},{\"type\":\"Enum\",\"Name\":\"R15CollisionType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"OuterBox\",\"tags\":[],\"Value\":0,\"Enum\":\"R15CollisionType\"},{\"type\":\"EnumItem\",\"Name\":\"InnerBox\",\"tags\":[],\"Value\":1,\"Enum\":\"R15CollisionType\"},{\"type\":\"Enum\",\"Name\":\"RenderPriority\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"First\",\"tags\":[],\"Value\":0,\"Enum\":\"RenderPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Input\",\"tags\":[],\"Value\":100,\"Enum\":\"RenderPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Camera\",\"tags\":[],\"Value\":200,\"Enum\":\"RenderPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Character\",\"tags\":[],\"Value\":300,\"Enum\":\"RenderPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Last\",\"tags\":[],\"Value\":2000,\"Enum\":\"RenderPriority\"},{\"type\":\"Enum\",\"Name\":\"RenderingTestComparisonMethod\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"psnr\",\"tags\":[],\"Value\":0,\"Enum\":\"RenderingTestComparisonMethod\"},{\"type\":\"EnumItem\",\"Name\":\"diff\",\"tags\":[],\"Value\":1,\"Enum\":\"RenderingTestComparisonMethod\"},{\"type\":\"Enum\",\"Name\":\"ReverbType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NoReverb\",\"tags\":[],\"Value\":0,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"GenericReverb\",\"tags\":[],\"Value\":1,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"PaddedCell\",\"tags\":[],\"Value\":2,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Room\",\"tags\":[],\"Value\":3,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Bathroom\",\"tags\":[],\"Value\":4,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"LivingRoom\",\"tags\":[],\"Value\":5,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"StoneRoom\",\"tags\":[],\"Value\":6,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Auditorium\",\"tags\":[],\"Value\":7,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"ConcertHall\",\"tags\":[],\"Value\":8,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Cave\",\"tags\":[],\"Value\":9,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Arena\",\"tags\":[],\"Value\":10,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Hangar\",\"tags\":[],\"Value\":11,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"CarpettedHallway\",\"tags\":[],\"Value\":12,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Hallway\",\"tags\":[],\"Value\":13,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"StoneCorridor\",\"tags\":[],\"Value\":14,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Alley\",\"tags\":[],\"Value\":15,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Forest\",\"tags\":[],\"Value\":16,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"City\",\"tags\":[],\"Value\":17,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Mountains\",\"tags\":[],\"Value\":18,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Quarry\",\"tags\":[],\"Value\":19,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"Plain\",\"tags\":[],\"Value\":20,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"ParkingLot\",\"tags\":[],\"Value\":21,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"SewerPipe\",\"tags\":[],\"Value\":22,\"Enum\":\"ReverbType\"},{\"type\":\"EnumItem\",\"Name\":\"UnderWater\",\"tags\":[],\"Value\":23,\"Enum\":\"ReverbType\"},{\"type\":\"Enum\",\"Name\":\"RibbonTool\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Select\",\"tags\":[],\"Value\":0,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Scale\",\"tags\":[],\"Value\":1,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Rotate\",\"tags\":[],\"Value\":2,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Move\",\"tags\":[],\"Value\":3,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Transform\",\"tags\":[],\"Value\":4,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"ColorPicker\",\"tags\":[],\"Value\":5,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"MaterialPicker\",\"tags\":[],\"Value\":6,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Group\",\"tags\":[],\"Value\":7,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"Ungroup\",\"tags\":[],\"Value\":8,\"Enum\":\"RibbonTool\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":9,\"Enum\":\"RibbonTool\"},{\"type\":\"Enum\",\"Name\":\"RollOffMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Inverse\",\"tags\":[],\"Value\":0,\"Enum\":\"RollOffMode\"},{\"type\":\"EnumItem\",\"Name\":\"Linear\",\"tags\":[],\"Value\":1,\"Enum\":\"RollOffMode\"},{\"type\":\"EnumItem\",\"Name\":\"InverseTapered\",\"tags\":[],\"Value\":3,\"Enum\":\"RollOffMode\"},{\"type\":\"EnumItem\",\"Name\":\"LinearSquare\",\"tags\":[],\"Value\":2,\"Enum\":\"RollOffMode\"},{\"type\":\"Enum\",\"Name\":\"RotationType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"MovementRelative\",\"tags\":[],\"Value\":0,\"Enum\":\"RotationType\"},{\"type\":\"EnumItem\",\"Name\":\"CameraRelative\",\"tags\":[],\"Value\":1,\"Enum\":\"RotationType\"},{\"type\":\"Enum\",\"Name\":\"RuntimeUndoBehavior\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Aggregate\",\"tags\":[],\"Value\":0,\"Enum\":\"RuntimeUndoBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"Snapshot\",\"tags\":[],\"Value\":1,\"Enum\":\"RuntimeUndoBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"Hybrid\",\"tags\":[],\"Value\":2,\"Enum\":\"RuntimeUndoBehavior\"},{\"type\":\"Enum\",\"Name\":\"SaveFilter\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"SaveAll\",\"tags\":[],\"Value\":2,\"Enum\":\"SaveFilter\"},{\"type\":\"EnumItem\",\"Name\":\"SaveWorld\",\"tags\":[],\"Value\":0,\"Enum\":\"SaveFilter\"},{\"type\":\"EnumItem\",\"Name\":\"SaveGame\",\"tags\":[],\"Value\":1,\"Enum\":\"SaveFilter\"},{\"type\":\"Enum\",\"Name\":\"SavedQualitySetting\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Automatic\",\"tags\":[],\"Value\":0,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel1\",\"tags\":[],\"Value\":1,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel2\",\"tags\":[],\"Value\":2,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel3\",\"tags\":[],\"Value\":3,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel4\",\"tags\":[],\"Value\":4,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel5\",\"tags\":[],\"Value\":5,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel6\",\"tags\":[],\"Value\":6,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel7\",\"tags\":[],\"Value\":7,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel8\",\"tags\":[],\"Value\":8,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel9\",\"tags\":[],\"Value\":9,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"EnumItem\",\"Name\":\"QualityLevel10\",\"tags\":[],\"Value\":10,\"Enum\":\"SavedQualitySetting\"},{\"type\":\"Enum\",\"Name\":\"ScaleType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Stretch\",\"tags\":[],\"Value\":0,\"Enum\":\"ScaleType\"},{\"type\":\"EnumItem\",\"Name\":\"Slice\",\"tags\":[],\"Value\":1,\"Enum\":\"ScaleType\"},{\"type\":\"EnumItem\",\"Name\":\"Tile\",\"tags\":[],\"Value\":2,\"Enum\":\"ScaleType\"},{\"type\":\"EnumItem\",\"Name\":\"Fit\",\"tags\":[],\"Value\":3,\"Enum\":\"ScaleType\"},{\"type\":\"EnumItem\",\"Name\":\"Crop\",\"tags\":[],\"Value\":4,\"Enum\":\"ScaleType\"},{\"type\":\"Enum\",\"Name\":\"ScreenOrientation\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"LandscapeLeft\",\"tags\":[],\"Value\":0,\"Enum\":\"ScreenOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"LandscapeRight\",\"tags\":[],\"Value\":1,\"Enum\":\"ScreenOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"LandscapeSensor\",\"tags\":[],\"Value\":2,\"Enum\":\"ScreenOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"Portrait\",\"tags\":[],\"Value\":3,\"Enum\":\"ScreenOrientation\"},{\"type\":\"EnumItem\",\"Name\":\"Sensor\",\"tags\":[],\"Value\":4,\"Enum\":\"ScreenOrientation\"},{\"type\":\"Enum\",\"Name\":\"ScrollBarInset\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"ScrollBarInset\"},{\"type\":\"EnumItem\",\"Name\":\"ScrollBar\",\"tags\":[],\"Value\":1,\"Enum\":\"ScrollBarInset\"},{\"type\":\"EnumItem\",\"Name\":\"Always\",\"tags\":[],\"Value\":2,\"Enum\":\"ScrollBarInset\"},{\"type\":\"Enum\",\"Name\":\"ScrollingDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"X\",\"tags\":[],\"Value\":1,\"Enum\":\"ScrollingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Y\",\"tags\":[],\"Value\":2,\"Enum\":\"ScrollingDirection\"},{\"type\":\"EnumItem\",\"Name\":\"XY\",\"tags\":[],\"Value\":4,\"Enum\":\"ScrollingDirection\"},{\"type\":\"Enum\",\"Name\":\"SizeConstraint\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"RelativeXY\",\"tags\":[],\"Value\":0,\"Enum\":\"SizeConstraint\"},{\"type\":\"EnumItem\",\"Name\":\"RelativeXX\",\"tags\":[],\"Value\":1,\"Enum\":\"SizeConstraint\"},{\"type\":\"EnumItem\",\"Name\":\"RelativeYY\",\"tags\":[],\"Value\":2,\"Enum\":\"SizeConstraint\"},{\"type\":\"Enum\",\"Name\":\"SortOrder\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"LayoutOrder\",\"tags\":[],\"Value\":2,\"Enum\":\"SortOrder\"},{\"type\":\"EnumItem\",\"Name\":\"Name\",\"tags\":[],\"Value\":0,\"Enum\":\"SortOrder\"},{\"type\":\"EnumItem\",\"Name\":\"Custom\",\"tags\":[\"deprecated\"],\"Value\":1,\"Enum\":\"SortOrder\"},{\"type\":\"Enum\",\"Name\":\"SoundType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NoSound\",\"tags\":[],\"Value\":0,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Boing\",\"tags\":[],\"Value\":1,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Bomb\",\"tags\":[],\"Value\":2,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Break\",\"tags\":[],\"Value\":3,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Click\",\"tags\":[],\"Value\":4,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Clock\",\"tags\":[],\"Value\":5,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Slingshot\",\"tags\":[],\"Value\":6,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Page\",\"tags\":[],\"Value\":7,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Ping\",\"tags\":[],\"Value\":8,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Snap\",\"tags\":[],\"Value\":9,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Splat\",\"tags\":[],\"Value\":10,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Step\",\"tags\":[],\"Value\":11,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"StepOn\",\"tags\":[],\"Value\":12,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Swoosh\",\"tags\":[],\"Value\":13,\"Enum\":\"SoundType\"},{\"type\":\"EnumItem\",\"Name\":\"Victory\",\"tags\":[],\"Value\":14,\"Enum\":\"SoundType\"},{\"type\":\"Enum\",\"Name\":\"SpecialKey\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Insert\",\"tags\":[],\"Value\":0,\"Enum\":\"SpecialKey\"},{\"type\":\"EnumItem\",\"Name\":\"Home\",\"tags\":[],\"Value\":1,\"Enum\":\"SpecialKey\"},{\"type\":\"EnumItem\",\"Name\":\"End\",\"tags\":[],\"Value\":2,\"Enum\":\"SpecialKey\"},{\"type\":\"EnumItem\",\"Name\":\"PageUp\",\"tags\":[],\"Value\":3,\"Enum\":\"SpecialKey\"},{\"type\":\"EnumItem\",\"Name\":\"PageDown\",\"tags\":[],\"Value\":4,\"Enum\":\"SpecialKey\"},{\"type\":\"EnumItem\",\"Name\":\"ChatHotkey\",\"tags\":[],\"Value\":5,\"Enum\":\"SpecialKey\"},{\"type\":\"Enum\",\"Name\":\"StartCorner\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"TopLeft\",\"tags\":[],\"Value\":0,\"Enum\":\"StartCorner\"},{\"type\":\"EnumItem\",\"Name\":\"TopRight\",\"tags\":[],\"Value\":1,\"Enum\":\"StartCorner\"},{\"type\":\"EnumItem\",\"Name\":\"BottomLeft\",\"tags\":[],\"Value\":2,\"Enum\":\"StartCorner\"},{\"type\":\"EnumItem\",\"Name\":\"BottomRight\",\"tags\":[],\"Value\":3,\"Enum\":\"StartCorner\"},{\"type\":\"Enum\",\"Name\":\"Status\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Poison\",\"tags\":[\"deprecated\"],\"Value\":0,\"Enum\":\"Status\"},{\"type\":\"EnumItem\",\"Name\":\"Confusion\",\"tags\":[\"deprecated\"],\"Value\":1,\"Enum\":\"Status\"},{\"type\":\"Enum\",\"Name\":\"Style\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"AlternatingSupports\",\"tags\":[],\"Value\":0,\"Enum\":\"Style\"},{\"type\":\"EnumItem\",\"Name\":\"BridgeStyleSupports\",\"tags\":[],\"Value\":1,\"Enum\":\"Style\"},{\"type\":\"EnumItem\",\"Name\":\"NoSupports\",\"tags\":[],\"Value\":2,\"Enum\":\"Style\"},{\"type\":\"Enum\",\"Name\":\"SurfaceConstraint\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"SurfaceConstraint\"},{\"type\":\"EnumItem\",\"Name\":\"Hinge\",\"tags\":[],\"Value\":1,\"Enum\":\"SurfaceConstraint\"},{\"type\":\"EnumItem\",\"Name\":\"SteppingMotor\",\"tags\":[],\"Value\":2,\"Enum\":\"SurfaceConstraint\"},{\"type\":\"EnumItem\",\"Name\":\"Motor\",\"tags\":[],\"Value\":3,\"Enum\":\"SurfaceConstraint\"},{\"type\":\"Enum\",\"Name\":\"SurfaceType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Smooth\",\"tags\":[],\"Value\":0,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Glue\",\"tags\":[],\"Value\":1,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Weld\",\"tags\":[],\"Value\":2,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Studs\",\"tags\":[],\"Value\":3,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Inlet\",\"tags\":[],\"Value\":4,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Universal\",\"tags\":[],\"Value\":5,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Hinge\",\"tags\":[],\"Value\":6,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"Motor\",\"tags\":[],\"Value\":7,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"SteppingMotor\",\"tags\":[],\"Value\":8,\"Enum\":\"SurfaceType\"},{\"type\":\"EnumItem\",\"Name\":\"SmoothNoOutlines\",\"tags\":[],\"Value\":10,\"Enum\":\"SurfaceType\"},{\"type\":\"Enum\",\"Name\":\"SwipeDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":0,\"Enum\":\"SwipeDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":1,\"Enum\":\"SwipeDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Up\",\"tags\":[],\"Value\":2,\"Enum\":\"SwipeDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Down\",\"tags\":[],\"Value\":3,\"Enum\":\"SwipeDirection\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":4,\"Enum\":\"SwipeDirection\"},{\"type\":\"Enum\",\"Name\":\"TableMajorAxis\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"RowMajor\",\"tags\":[],\"Value\":0,\"Enum\":\"TableMajorAxis\"},{\"type\":\"EnumItem\",\"Name\":\"ColumnMajor\",\"tags\":[],\"Value\":1,\"Enum\":\"TableMajorAxis\"},{\"type\":\"Enum\",\"Name\":\"Technology\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Legacy\",\"tags\":[],\"Value\":0,\"Enum\":\"Technology\"},{\"type\":\"EnumItem\",\"Name\":\"Voxel\",\"tags\":[],\"Value\":1,\"Enum\":\"Technology\"},{\"type\":\"Enum\",\"Name\":\"TeleportResult\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Success\",\"tags\":[],\"Value\":0,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"Failure\",\"tags\":[],\"Value\":1,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"GameNotFound\",\"tags\":[],\"Value\":2,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"GameEnded\",\"tags\":[],\"Value\":3,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"GameFull\",\"tags\":[],\"Value\":4,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"Unauthorized\",\"tags\":[],\"Value\":5,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"Flooded\",\"tags\":[],\"Value\":6,\"Enum\":\"TeleportResult\"},{\"type\":\"EnumItem\",\"Name\":\"IsTeleporting\",\"tags\":[],\"Value\":7,\"Enum\":\"TeleportResult\"},{\"type\":\"Enum\",\"Name\":\"TeleportState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"RequestedFromServer\",\"tags\":[],\"Value\":0,\"Enum\":\"TeleportState\"},{\"type\":\"EnumItem\",\"Name\":\"Started\",\"tags\":[],\"Value\":1,\"Enum\":\"TeleportState\"},{\"type\":\"EnumItem\",\"Name\":\"WaitingForServer\",\"tags\":[],\"Value\":2,\"Enum\":\"TeleportState\"},{\"type\":\"EnumItem\",\"Name\":\"Failed\",\"tags\":[],\"Value\":3,\"Enum\":\"TeleportState\"},{\"type\":\"EnumItem\",\"Name\":\"InProgress\",\"tags\":[],\"Value\":4,\"Enum\":\"TeleportState\"},{\"type\":\"Enum\",\"Name\":\"TeleportType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"ToPlace\",\"tags\":[],\"Value\":0,\"Enum\":\"TeleportType\"},{\"type\":\"EnumItem\",\"Name\":\"ToInstance\",\"tags\":[],\"Value\":1,\"Enum\":\"TeleportType\"},{\"type\":\"EnumItem\",\"Name\":\"ToReservedServer\",\"tags\":[],\"Value\":2,\"Enum\":\"TeleportType\"},{\"type\":\"Enum\",\"Name\":\"TextFilterContext\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"PublicChat\",\"tags\":[],\"Value\":1,\"Enum\":\"TextFilterContext\"},{\"type\":\"EnumItem\",\"Name\":\"PrivateChat\",\"tags\":[],\"Value\":2,\"Enum\":\"TextFilterContext\"},{\"type\":\"Enum\",\"Name\":\"TextTruncate\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"TextTruncate\"},{\"type\":\"EnumItem\",\"Name\":\"AtEnd\",\"tags\":[],\"Value\":1,\"Enum\":\"TextTruncate\"},{\"type\":\"Enum\",\"Name\":\"TextXAlignment\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":0,\"Enum\":\"TextXAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":2,\"Enum\":\"TextXAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":1,\"Enum\":\"TextXAlignment\"},{\"type\":\"Enum\",\"Name\":\"TextYAlignment\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Top\",\"tags\":[],\"Value\":0,\"Enum\":\"TextYAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":1,\"Enum\":\"TextYAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Bottom\",\"tags\":[],\"Value\":2,\"Enum\":\"TextYAlignment\"},{\"type\":\"Enum\",\"Name\":\"TextureMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Stretch\",\"tags\":[],\"Value\":0,\"Enum\":\"TextureMode\"},{\"type\":\"EnumItem\",\"Name\":\"Wrap\",\"tags\":[],\"Value\":1,\"Enum\":\"TextureMode\"},{\"type\":\"EnumItem\",\"Name\":\"Static\",\"tags\":[],\"Value\":2,\"Enum\":\"TextureMode\"},{\"type\":\"Enum\",\"Name\":\"TextureQueryType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NonHumanoid\",\"tags\":[],\"Value\":0,\"Enum\":\"TextureQueryType\"},{\"type\":\"EnumItem\",\"Name\":\"NonHumanoidOrphaned\",\"tags\":[],\"Value\":1,\"Enum\":\"TextureQueryType\"},{\"type\":\"EnumItem\",\"Name\":\"Humanoid\",\"tags\":[],\"Value\":2,\"Enum\":\"TextureQueryType\"},{\"type\":\"EnumItem\",\"Name\":\"HumanoidOrphaned\",\"tags\":[],\"Value\":3,\"Enum\":\"TextureQueryType\"},{\"type\":\"Enum\",\"Name\":\"ThreadPoolConfig\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Auto\",\"tags\":[],\"Value\":0,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"PerCore1\",\"tags\":[],\"Value\":101,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"PerCore2\",\"tags\":[],\"Value\":102,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"PerCore3\",\"tags\":[],\"Value\":103,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"PerCore4\",\"tags\":[],\"Value\":104,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads1\",\"tags\":[],\"Value\":1,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads2\",\"tags\":[],\"Value\":2,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads3\",\"tags\":[],\"Value\":3,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads4\",\"tags\":[],\"Value\":4,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads8\",\"tags\":[],\"Value\":8,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"EnumItem\",\"Name\":\"Threads16\",\"tags\":[],\"Value\":16,\"Enum\":\"ThreadPoolConfig\"},{\"type\":\"Enum\",\"Name\":\"ThrottlingPriority\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Extreme\",\"tags\":[],\"Value\":2,\"Enum\":\"ThrottlingPriority\"},{\"type\":\"EnumItem\",\"Name\":\"ElevatedOnServer\",\"tags\":[],\"Value\":1,\"Enum\":\"ThrottlingPriority\"},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"ThrottlingPriority\"},{\"type\":\"Enum\",\"Name\":\"ThumbnailSize\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Size48x48\",\"tags\":[],\"Value\":0,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size180x180\",\"tags\":[],\"Value\":1,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size420x420\",\"tags\":[],\"Value\":2,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size60x60\",\"tags\":[],\"Value\":3,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size100x100\",\"tags\":[],\"Value\":4,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size150x150\",\"tags\":[],\"Value\":5,\"Enum\":\"ThumbnailSize\"},{\"type\":\"EnumItem\",\"Name\":\"Size352x352\",\"tags\":[],\"Value\":6,\"Enum\":\"ThumbnailSize\"},{\"type\":\"Enum\",\"Name\":\"ThumbnailType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"HeadShot\",\"tags\":[],\"Value\":0,\"Enum\":\"ThumbnailType\"},{\"type\":\"EnumItem\",\"Name\":\"AvatarBust\",\"tags\":[],\"Value\":1,\"Enum\":\"ThumbnailType\"},{\"type\":\"EnumItem\",\"Name\":\"AvatarThumbnail\",\"tags\":[],\"Value\":2,\"Enum\":\"ThumbnailType\"},{\"type\":\"Enum\",\"Name\":\"TickCountSampleMethod\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Fast\",\"tags\":[],\"Value\":0,\"Enum\":\"TickCountSampleMethod\"},{\"type\":\"EnumItem\",\"Name\":\"Benchmark\",\"tags\":[],\"Value\":1,\"Enum\":\"TickCountSampleMethod\"},{\"type\":\"EnumItem\",\"Name\":\"Precise\",\"tags\":[],\"Value\":2,\"Enum\":\"TickCountSampleMethod\"},{\"type\":\"Enum\",\"Name\":\"TopBottom\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Top\",\"tags\":[],\"Value\":0,\"Enum\":\"TopBottom\"},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":1,\"Enum\":\"TopBottom\"},{\"type\":\"EnumItem\",\"Name\":\"Bottom\",\"tags\":[],\"Value\":2,\"Enum\":\"TopBottom\"},{\"type\":\"Enum\",\"Name\":\"TouchCameraMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"TouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Follow\",\"tags\":[],\"Value\":2,\"Enum\":\"TouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Classic\",\"tags\":[],\"Value\":1,\"Enum\":\"TouchCameraMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Orbital\",\"tags\":[],\"Value\":3,\"Enum\":\"TouchCameraMovementMode\"},{\"type\":\"Enum\",\"Name\":\"TouchMovementMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Default\",\"tags\":[],\"Value\":0,\"Enum\":\"TouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbstick\",\"tags\":[],\"Value\":1,\"Enum\":\"TouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"DPad\",\"tags\":[],\"Value\":2,\"Enum\":\"TouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"Thumbpad\",\"tags\":[],\"Value\":3,\"Enum\":\"TouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"ClickToMove\",\"tags\":[],\"Value\":4,\"Enum\":\"TouchMovementMode\"},{\"type\":\"EnumItem\",\"Name\":\"DynamicThumbstick\",\"tags\":[],\"Value\":5,\"Enum\":\"TouchMovementMode\"},{\"type\":\"Enum\",\"Name\":\"TweenStatus\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Canceled\",\"tags\":[],\"Value\":0,\"Enum\":\"TweenStatus\"},{\"type\":\"EnumItem\",\"Name\":\"Completed\",\"tags\":[],\"Value\":1,\"Enum\":\"TweenStatus\"},{\"type\":\"Enum\",\"Name\":\"UiMessageType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"UiMessageError\",\"tags\":[],\"Value\":0,\"Enum\":\"UiMessageType\"},{\"type\":\"EnumItem\",\"Name\":\"UiMessageInfo\",\"tags\":[],\"Value\":1,\"Enum\":\"UiMessageType\"},{\"type\":\"Enum\",\"Name\":\"UploadSetting\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Never\",\"tags\":[],\"Value\":0,\"Enum\":\"UploadSetting\"},{\"type\":\"EnumItem\",\"Name\":\"Ask\",\"tags\":[],\"Value\":1,\"Enum\":\"UploadSetting\"},{\"type\":\"EnumItem\",\"Name\":\"Always\",\"tags\":[],\"Value\":2,\"Enum\":\"UploadSetting\"},{\"type\":\"Enum\",\"Name\":\"UserCFrame\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Head\",\"tags\":[],\"Value\":0,\"Enum\":\"UserCFrame\"},{\"type\":\"EnumItem\",\"Name\":\"LeftHand\",\"tags\":[],\"Value\":1,\"Enum\":\"UserCFrame\"},{\"type\":\"EnumItem\",\"Name\":\"RightHand\",\"tags\":[],\"Value\":2,\"Enum\":\"UserCFrame\"},{\"type\":\"Enum\",\"Name\":\"UserInputState\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Begin\",\"tags\":[],\"Value\":0,\"Enum\":\"UserInputState\"},{\"type\":\"EnumItem\",\"Name\":\"Change\",\"tags\":[],\"Value\":1,\"Enum\":\"UserInputState\"},{\"type\":\"EnumItem\",\"Name\":\"End\",\"tags\":[],\"Value\":2,\"Enum\":\"UserInputState\"},{\"type\":\"EnumItem\",\"Name\":\"Cancel\",\"tags\":[],\"Value\":3,\"Enum\":\"UserInputState\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":4,\"Enum\":\"UserInputState\"},{\"type\":\"Enum\",\"Name\":\"UserInputType\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"MouseButton1\",\"tags\":[],\"Value\":0,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"MouseButton2\",\"tags\":[],\"Value\":1,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"MouseButton3\",\"tags\":[],\"Value\":2,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"MouseWheel\",\"tags\":[],\"Value\":3,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"MouseMovement\",\"tags\":[],\"Value\":4,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Touch\",\"tags\":[],\"Value\":7,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Keyboard\",\"tags\":[],\"Value\":8,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Focus\",\"tags\":[],\"Value\":9,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Accelerometer\",\"tags\":[],\"Value\":10,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gyro\",\"tags\":[],\"Value\":11,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad1\",\"tags\":[],\"Value\":12,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad2\",\"tags\":[],\"Value\":13,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad3\",\"tags\":[],\"Value\":14,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad4\",\"tags\":[],\"Value\":15,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad5\",\"tags\":[],\"Value\":16,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad6\",\"tags\":[],\"Value\":17,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad7\",\"tags\":[],\"Value\":18,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"Gamepad8\",\"tags\":[],\"Value\":19,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"TextInput\",\"tags\":[],\"Value\":20,\"Enum\":\"UserInputType\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":21,\"Enum\":\"UserInputType\"},{\"type\":\"Enum\",\"Name\":\"VRTouchpad\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":0,\"Enum\":\"VRTouchpad\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":1,\"Enum\":\"VRTouchpad\"},{\"type\":\"Enum\",\"Name\":\"VRTouchpadMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Touch\",\"tags\":[],\"Value\":0,\"Enum\":\"VRTouchpadMode\"},{\"type\":\"EnumItem\",\"Name\":\"VirtualThumbstick\",\"tags\":[],\"Value\":1,\"Enum\":\"VRTouchpadMode\"},{\"type\":\"EnumItem\",\"Name\":\"ABXY\",\"tags\":[],\"Value\":2,\"Enum\":\"VRTouchpadMode\"},{\"type\":\"Enum\",\"Name\":\"VerticalAlignment\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Center\",\"tags\":[],\"Value\":0,\"Enum\":\"VerticalAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Top\",\"tags\":[],\"Value\":1,\"Enum\":\"VerticalAlignment\"},{\"type\":\"EnumItem\",\"Name\":\"Bottom\",\"tags\":[],\"Value\":2,\"Enum\":\"VerticalAlignment\"},{\"type\":\"Enum\",\"Name\":\"VerticalScrollBarPosition\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Left\",\"tags\":[],\"Value\":1,\"Enum\":\"VerticalScrollBarPosition\"},{\"type\":\"EnumItem\",\"Name\":\"Right\",\"tags\":[],\"Value\":0,\"Enum\":\"VerticalScrollBarPosition\"},{\"type\":\"Enum\",\"Name\":\"VibrationMotor\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Large\",\"tags\":[],\"Value\":0,\"Enum\":\"VibrationMotor\"},{\"type\":\"EnumItem\",\"Name\":\"Small\",\"tags\":[],\"Value\":1,\"Enum\":\"VibrationMotor\"},{\"type\":\"EnumItem\",\"Name\":\"LeftTrigger\",\"tags\":[],\"Value\":2,\"Enum\":\"VibrationMotor\"},{\"type\":\"EnumItem\",\"Name\":\"RightTrigger\",\"tags\":[],\"Value\":3,\"Enum\":\"VibrationMotor\"},{\"type\":\"EnumItem\",\"Name\":\"LeftHand\",\"tags\":[],\"Value\":4,\"Enum\":\"VibrationMotor\"},{\"type\":\"EnumItem\",\"Name\":\"RightHand\",\"tags\":[],\"Value\":5,\"Enum\":\"VibrationMotor\"},{\"type\":\"Enum\",\"Name\":\"VideoQualitySettings\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"LowResolution\",\"tags\":[],\"Value\":0,\"Enum\":\"VideoQualitySettings\"},{\"type\":\"EnumItem\",\"Name\":\"MediumResolution\",\"tags\":[],\"Value\":1,\"Enum\":\"VideoQualitySettings\"},{\"type\":\"EnumItem\",\"Name\":\"HighResolution\",\"tags\":[],\"Value\":2,\"Enum\":\"VideoQualitySettings\"},{\"type\":\"Enum\",\"Name\":\"VirtualInputMode\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Recording\",\"tags\":[],\"Value\":1,\"Enum\":\"VirtualInputMode\"},{\"type\":\"EnumItem\",\"Name\":\"Playing\",\"tags\":[],\"Value\":2,\"Enum\":\"VirtualInputMode\"},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"VirtualInputMode\"},{\"type\":\"Enum\",\"Name\":\"WaterDirection\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"NegX\",\"tags\":[],\"Value\":0,\"Enum\":\"WaterDirection\"},{\"type\":\"EnumItem\",\"Name\":\"X\",\"tags\":[],\"Value\":1,\"Enum\":\"WaterDirection\"},{\"type\":\"EnumItem\",\"Name\":\"NegY\",\"tags\":[],\"Value\":2,\"Enum\":\"WaterDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Y\",\"tags\":[],\"Value\":3,\"Enum\":\"WaterDirection\"},{\"type\":\"EnumItem\",\"Name\":\"NegZ\",\"tags\":[],\"Value\":4,\"Enum\":\"WaterDirection\"},{\"type\":\"EnumItem\",\"Name\":\"Z\",\"tags\":[],\"Value\":5,\"Enum\":\"WaterDirection\"},{\"type\":\"Enum\",\"Name\":\"WaterForce\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"None\",\"tags\":[],\"Value\":0,\"Enum\":\"WaterForce\"},{\"type\":\"EnumItem\",\"Name\":\"Small\",\"tags\":[],\"Value\":1,\"Enum\":\"WaterForce\"},{\"type\":\"EnumItem\",\"Name\":\"Medium\",\"tags\":[],\"Value\":2,\"Enum\":\"WaterForce\"},{\"type\":\"EnumItem\",\"Name\":\"Strong\",\"tags\":[],\"Value\":3,\"Enum\":\"WaterForce\"},{\"type\":\"EnumItem\",\"Name\":\"Max\",\"tags\":[],\"Value\":4,\"Enum\":\"WaterForce\"},{\"type\":\"Enum\",\"Name\":\"ZIndexBehavior\",\"tags\":[]},{\"type\":\"EnumItem\",\"Name\":\"Global\",\"tags\":[],\"Value\":0,\"Enum\":\"ZIndexBehavior\"},{\"type\":\"EnumItem\",\"Name\":\"Sibling\",\"tags\":[],\"Value\":1,\"Enum\":\"ZIndexBehavior\"}]"
		end)
		if (not successGetAsync) then
			warn("Failed to fetch Roblox API: " .. tostring(data))
			return
		end
		local successParse, dataArray = pcall(function()
			return game:GetService("HttpService"):JSONDecode(data)
		end)
		if (not successParse) then
			warn("Failed to parse Roblox API: " .. tostring(dataArray))
			return
		end
		return dataArray
	end


	function BuildClasses(api)

		local ValueNameMatch = {} 
		local classes, classesByName = {}, {}

		local function ApplyTags(item)
			if (item.tags) then
				for i = 1,#item.tags do
					local tag = item.tags[i]
					if (tag:match("Security$")) then
						item.Security = tag
					elseif (tag == "readonly") then
						item.ReadOnly = true
					elseif (tag == "hidden") then
						item.Hidden = true
					elseif (tag == "notCreatable") then
						item.NotCreatable = true
					elseif (tag == "notbrowsable") then
						item.NotBrowsable = true
					end
				end
			end
		end

		-- Collect all classes:
		for i = 1,#api do
			local item = api[i]
			if (item.type == "Class") then
				classes[#classes + 1] = item
				classesByName[item.Name] = item
				item.Subclasses = {}
				item.Properties = {}
				item.Methods = {}
				item.Events = {}
				ApplyTags(item)
				for _,key in pairs{"Properties", "Methods", "Events"} do
					setmetatable(item[key], {
						__index = function(self, index)
							return item.Superclass and item.Superclass[key][index]
						end;
					})
				end
				function item:GetAllProperties(discludeSecure)
					local properties = {}
					local class = item
					while (class) do
						for propName,propInfo in pairs(class.Properties) do
							if ((not propInfo.Security) or (not discludeSecure)) then
								properties[propName] = propInfo
							end
						end
						class = class.Superclass
					end
					return properties
				end
			end
		end

		-- Reference superclasses:
		for i = 1,#classes do
			local class = classes[i]
			if (class.Superclass) then
				class.Superclass = classesByName[class.Superclass]
				table.insert(class.Superclass.Subclasses, class)
			end
		end

		-- Collect properties, methods, and events:
		for i = 1,#api do
			local item = api[i]
			if item.Name and item.ValueType then 
				local class = classesByName[item.Class]
				ValueNameMatch[item.Name..":"..class.Name] = item.ValueType
			end 
			if (item.type == "Property") then
				local class = classesByName[item.Class]
				ApplyTags(item) 
				class.Properties[item.Name] = item
			elseif (item.type == "Function") then
				local class = classesByName[item.Class]
				ApplyTags(item)
				class.Methods[item.Name] = item
			elseif (item.type == "Event") then
				local class = classesByName[item.Class]
				ApplyTags(item)
				class.Events[item.Name] = item
			end
		end

		return classes, classesByName , ValueNameMatch

	end


	function BuildEnums(api)

		local enums, enumsByName = {}, {}

		-- Collect enums:
		for i = 1,#api do
			local item = api[i]
			if (item.type == "Enum") then
				enums[#enums + 1] = item
				enumsByName[item.Name] = item
				item.EnumItems = {}
				item.ItemID = #enums 
			end
		end

		-- Collect enum items:
		for i = 1,#api do
			local item = api[i]
			if (item.type == "EnumItem") then
				local enum = enumsByName[item.Enum]
				table.insert(enum.EnumItems, item)
			end
		end

		return enums, enumsByName

	end


	function API:Fetch()

		if (self._fetched) then
			warn("API already fetched")
			return
		end

		if (self._fetching) then
			warn("API is already in the process of being fetched")
			return
		end

		self._fetching = true
		local api = FetchAPI()
		self._fetching = nil
		if (not api) then return end

		API.Classes, API.ClassesByName , API.ValueTypeMatch = BuildClasses(api)
		API.Enums, API.EnumsByName = BuildEnums(api)

		self._fetched = true

		return true

	end

end
local apiFetched =false 
local FetchApi = function() 
	API.throw = throw
	API.SaveCFrames = true
	API.SaveSource = RBLXSerialize.SaveSource
	API.AutoRename = RBLXSerialize.AutoRename
	if (not apiFetched) then
		apiFetched = true
		local success, returnVal = pcall(function()
			return API:Fetch()
		end)
		if ((not success) or (not returnVal)) then
			apiFetched = false
			return
		end
	end
end

local convertors = RBLXSerialize.Convertors
local allowed = {
	["PartGG"] = {
		Size = true,
		Position = true,
		Name = true,
		Trasparency = true,
		Color = true, 
		BrickColor = true, 
		Material = true,
		Reflectance = true,
		CanCollide = true, 
		CanTouch = true,
		CollisionGroupId = true, 
		Anchored = true,
		Massless = true, 
		RootPriority = true,
		Shape = true, 

	}
}
local defaultCheck = function()
	local defaults = {} 
	local valid = {} 

	return{
		isCreatable = function(className) 
			local validD = valid[className] 
			if not validD then 
				valid[className] = pcall(function() 
					Instance.new(className)
				end)
				validD = valid[className]
			end
			return validD
		end,
		getDefaults = function(className,property) 
			local instanceDefault = defaults[className]
			if not instanceDefault then 
				defaults[className] = Instance.new(className) 
				instanceDefault = defaults[className]
			end
			return instanceDefault[property]
		end
	}
end
defaultCheck=defaultCheck()

local instanceEncode = function()
	local searchForParent= function(parent,child) 
		local parentFound = false 
		local parentList = {child.Parent} 
		if child.Parent == parent then 
			return parentList 
		end
		repeat 
			local cParent = parentList[#parentList].Parent
			table.insert(parentList,cParent)
			if cParent == parent then 
				return parentList
			end
		until parentList[#parentList].Parent == nil
		return parentList 
	end
	local generateRoot = function(parentList) 
		local root = "" 
		for i=#parentList,1,-1 do 
			if i~= #parentList then 
				root = root .. parentList[i].Name
				root = root .. string.char(28)
			end 
		end
		return root 
	end
	--^^CylicSearching!

	return function(API,instance,instances) 
		local canCreate = defaultCheck.isCreatable(instance.ClassName)
		if not canCreate then 
			API.throw("Uncreatable isntance detetected  : ",instance.ClassName)
			return nil 
		end
		local allowedTable = allowed[instance.ClassName]
		local InstanceString = Binary.describe("StoreType","Instance")..Binary.describe("InstanceName",instance.ClassName)
		local obj = instance 
		local class = API.ClassesByName[obj.ClassName]
		if not class then 
			API.throw("Class defintion of ",instance.ClassName," not found!")
			return  
		end
		for propName,propInfo in pairs(class:GetAllProperties(true)) do
			if ((not propInfo.ReadOnly) and (not propInfo.Hidden) and propName ~= "Parent") then
				if propInfo.ValueType and propInfo.Name then  
					if allowedTable then  
						local whitelist = allowedTable[propInfo.Name]
						if not whitelist then 
							continue
						end
					end
					local deafult = defaultCheck.getDefaults(instance.ClassName,propInfo.Name)
					if deafult == instance[propInfo.Name] then else
						if not API.SaveCFrames then 
							if propInfo.ValueType == "CFrame" or propInfo.ValueType == "CoordinateFrame" then 
								continue
							end
						end

						--EnumCheck! 
						local EnumData = API.EnumsByName[propInfo.ValueType]
						if EnumData then
							local EnumItemConvertor = convertors["EnumItem"] 
							if EnumItemConvertor then  
								local Encoded = EnumItemConvertor(true,API,EnumData.Name,instance[propInfo.Name])
								if Encoded then 
									InstanceString =InstanceString.. Binary.describe("ValueType",propInfo.Name)..Binary.describe("Value",Encoded)

									continue
								end
							end
						end

						if instances then 
							local SuperClassName = nil 

							if propInfo.ValueType and propInfo.ValueType:find(":") then 
								local superClass = propInfo.ValueType:match(":(.*)")
								if superClass then 
									local Class =  API.ClassesByName[superClass]
									if Class and Class.Superclass then 
										SuperClassName = Class.Superclass.Name
									end
								end
							end	

							if propInfo.ValueType == "Class:PVInstance" or SuperClassName == "Instance" or SuperClassName == "PVInstance" then  
								local referenceInstance = instance[propInfo.Name]
								if typeof(referenceInstance) == "Instance" then
									if referenceInstance:IsDescendantOf(instances) then 
										local ParentSearch = searchForParent(instances,referenceInstance) 
										local CylicRoot = generateRoot(ParentSearch)..referenceInstance.Name


										InstanceString =InstanceString.. Binary.describe("ValueType",propName)..Binary.describe("Value",CylicRoot)	
										continue
									end
								end 
							end				 
						end

						local convertor = convertors[propInfo.ValueType] 
						if convertor then 
							local encodedValue = convertor(true,instance[propInfo.Name])
							if encodedValue then 
								pcall(function()
									InstanceString =InstanceString.. Binary.describe("ValueType",propInfo.Name)..Binary.describe("Value",encodedValue)	
								end)
							end
						end
					end
				end

			end 
		end
		return InstanceString
	end
end
local instancesEncode = function()
	return function(API,instance) 

		if API.AutoRename then 
			local ParentNameIndex = {}
			for i,v in ipairs(instance:GetDescendants()) do 
				ParentNameIndex[v.Name] = ParentNameIndex[v.Name] or {} 
				ParentNameIndex[v.Name][v.Parent] = ParentNameIndex[v.Name][v.Parent] or -1
				ParentNameIndex[v.Name][v.Parent] = ParentNameIndex[v.Name][v.Parent]+1
				local ParentNameOccurance = ParentNameIndex[v.Name][v.Parent]
				if ParentNameOccurance > 0 then 
					v.Name = v.Name..ParentNameOccurance
				end 
			end
		end

		local instances = instance 
		local allowedTable = allowed[instance.ClassName]
		local RootString = Binary.describe("StoreType","Root")
		local addToRoot = function(root,instance)
			local parsed = instanceEncode()(API,instance,instances)
			if parsed then 
				RootString = RootString .. Binary.describe("Value",root) ..  Binary.describe("Value",parsed)
			end
		end  

		addToRoot("",instance)

		local searchForParent= function(parent,child) 
			local parentFound = false 

			local parentList = {child.Parent} 
			if child.Parent == parent then 
				return parentList 
			end
			repeat 
				local cParent = parentList[#parentList].Parent
				table.insert(parentList,cParent)
				if cParent == parent then 
					return parentList
				end
			until parentList[#parentList].Parent == nil 

			return parentList 
		end
		local generateRoot = function(parentList) 
			local root = "" 
			for i=#parentList,1,-1 do 
				if i~= #parentList then 
					root = root .. parentList[i].Name
					root = root .. string.char(28)
				end 
			end
			return root 
		end
		for i,v in ipairs(instance:GetDescendants()) do 
			local parent = searchForParent(instance,v) 
			local root = generateRoot(parent)


			addToRoot(root,v)
		end


		return RootString
	end
end
local valueEncode = function(API,value) 
	local ValueString = Binary.describe("StoreType","Value")
	local ValueType = typeof(value)

	local convertor = convertors[ ValueType ]
	if convertor  then
		local converted = convertor(true,value)
		if converted then 
			return ValueString .. Binary.describe("DataType",ValueType)..Binary.describe("Value",converted)
		else 
			return nil 
		end
	else 
		return nil 
	end
end
local encodeMethods = {
	["Instance"] = instanceEncode(),
	["Instances"] = instancesEncode(),
	["Value"] = valueEncode
}


RBLXSerialize.Encode = function(class,compressed : bool)
	local compressed =compressed or true
	FetchApi() 

	-- Gathering!
	local typeOfClass = typeof(class)
	if  typeOfClass == "Instance" then 
		-- Turns method form Instance to Intance(s)
		if #(class:GetDescendants()) == 0  then else
			typeOfClass ..= "s"
		end
	end 
	-- find the method!
	local enocdeMethod = encodeMethods[typeOfClass]
	if not enocdeMethod then
		enocdeMethod =  encodeMethods["Value"]
	end 

	-- actuall Encode!
	local result = enocdeMethod(API,class)
	if not result then 
		throw("Failure to encode "..typeOfClass)
		return true 
	end

	-- do stuffs if compressed but only if their is somethig! ( avoid compressing nothing)
	if compressed and result  then 
		result =  Compressor.compress(result)
	end 

	--- Return actual result oof biinary based on format
	if RBLXSerialize.UseBase92 then 
		-- 
		return  base92.encode(result)
	end 
	return result 

end

instanceDecode = function()
	local getRootParent = function(root,instance)
		local split = string.split(root,string.char(28))
		local index = instance 

		for i,v in ipairs(split) do 
			if v ~= "" then 
				local canIndex = index:FindFirstChild(v) 
				if canIndex then 
					index = canIndex 
				end
			end
		end

		return index 
	end	
	local IS_CYLIC_SEARCH = 0x01
	--^^CylicSearching
	return function(API,Parsed,Parent,CylicTable,FLAG) 
		local instance = Instance.new(Parsed.ClassName)
		if FLAG == IS_CYLIC_SEARCH then 
			Parent = instance
		end
		for valueType,rawPropertyData in pairs(Parsed) do 
			local class 
			local classReferfence = API.ClassesByName[Parsed.ClassName]
			local propObject = classReferfence.Properties[valueType] 
			if propObject  then
				class = classReferfence.Properties[valueType].ValueType	
			end	
			if Parent then 
				if propObject then 
					local SuperClassName = nil 

					if propObject.ValueType and propObject.ValueType:find(":") then 
						local superClass = propObject.ValueType:match(":(.*)")
						if superClass then 
							local Class =  API.ClassesByName[superClass]
							if Class and Class.Superclass then 
								SuperClassName = Class.Superclass.Name
							end
						end
					end

					if propObject.ValueType == "Class:PVInstance" or SuperClassName == "Instance" or SuperClassName == "PVInstance" then 

						local CylicSearchFunction = function() 
							local InstanceReferenceSearch = getRootParent(rawPropertyData,Parent)
							if InstanceReferenceSearch then
								pcall(function()
									instance[valueType] = InstanceReferenceSearch
								end)
							end
						end

						table.insert(CylicTable,CylicSearchFunction)
						continue
					end
				end
			end

			if propObject then
				local EnumItemConvertor = convertors["EnumItem"] 
				local EnumData = API.EnumsByName[propObject.ValueType]
				if EnumData and EnumItemConvertor then 
					local converted = EnumItemConvertor(false,API,EnumData.Name,rawPropertyData)
					if converted then 
						local Success,Result= pcall(function()
							instance[valueType] = converted
						end) 
						if not Success then 
							API.throw(Result)
						end
					end
				end
				if EnumData then 
					continue -- Cannot contuine! This is what limits backwards-compatability! Will cause unpack errors. if removed!
				end
			end 

			if class and valueType ~= "ClassName" and valueType ~= "Archivable" then 
				local convertor = convertors[class]  
				if convertor then 
					local converted = convertor(false,rawPropertyData)	
					if converted then 
						local Success,Result= pcall(function()
							instance[valueType] = converted
						end) 
						if not Success then 
							API.throw(Result)
						end
					end
				end
			end
		end
		return instance
	end
end
local rootDecode = function()

	local instanceCreator = instanceDecode()

	return function(API,Parsed)
		-- First but data 2
		local CylicSearches = {}													--[CylicFlag]
		local startInstance = instanceCreator(API,Parsed.Root[1][2],nil,CylicSearches,0x01) 
		local getRootParent = function(root,instance)
			local split = string.split(root,string.char(28))
			local index = instance 

			for i,v in ipairs(split) do 
				if v ~= "" then 
					local canIndex = index:FindFirstChild(v) 
					if canIndex then 
						index = canIndex 
					end
				end
			end

			return index 
		end		
		for i,rootData in ipairs(Parsed.Root) do 
			if i ~= 1 then 
				local instance =  instanceCreator(API,rootData[2],startInstance,CylicSearches)
				local Parent = getRootParent(rootData[1],startInstance)

				if Parent then 
					pcall(function()
						instance.Parent = Parent 
					end)
				else 
					API.throw("no parent found for ",instance)
				end
			end
		end
		-- do all of the CylicSearches!
		for _,AppendedCylicSearch in ipairs(CylicSearches)  do
			if AppendedCylicSearch then 
				AppendedCylicSearch() 
			end
		end
		return startInstance
	end
end
local valueDecode = function(API,Parsed) 
	local ValueType = Parsed.ClassName 
	local ValueUnParsed = Parsed[ValueType] 

	if ValueUnParsed then 
		local convertor = convertors[ ValueType ]
		if convertor  then
			return convertor(false,ValueUnParsed)
		else 
			return nil 
		end
	else 
		return nil 
	end

end
local decodeMethods = {
	["Instance"] = instanceDecode(),
	["Root"] = rootDecode(),
	["Value"] = valueDecode
}

RBLXSerialize.Decode = function(encoded,compressed : bool ) 
	local compressed =compressed or true  
	FetchApi()

	-- Yeah, i know...
	if RBLXSerialize.UseBase92 then 
		encoded = base92.decode(encoded)
	end
	if compressed then  
		encoded =  Compressor.decompress(encoded) 
	end

	-- Parse the string!
	local parsed = Binary.DecodeData(encoded)
	if not parsed then 
		throw("Instnace/Datatype failed to decode correctly!")
		return 
	end

	-- Gather information for decoder!
	local typeOfClass = parsed.TypeOf
	local decodeMethod = decodeMethods[typeOfClass]
	if not decodeMethod then 
		decodeMethod =  decodeMethods["Value"]
	end 

	-- Only thing left to do is give it to the decoder!
	local result = decodeMethod(API,parsed)
	return result
end

function F3XExport(TableOfParts)
	local Container = Instance.new"Model"
	Container.Name = "BTExport"..math.random(1,999999999)
	-- F3X has strong security so the only way I managed to sneak in
	-- data that wasn't serialized by their crappy serializer was through a string property on a serialized part
	-- So you can basically store anything on their server with this method as long as it's a string
	for _,v in pairs(TableOfParts)do
	    pcall(function()
			if not v.Archivable then v.Archivable=true end
			v:Clone().Parent=Container
	    end)
	end
	local SerializedBuildData = {Items = {{0,0,RBLXSerialize.Encode(Container),0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}, Version = 3}
    Container:Destroy()
    
    SerializedBuildData=HttpService:JSONEncode(SerializedBuildData)

	local Response = HttpService:JSONDecode(
		(Request or syn.request){
			Url = 'http://f3xteam.com/bt/export',
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode {data = SerializedBuildData, version = 3, userId = math.random(1,1000000) }
		}.Body
	);
	if Response then
		print(Response.id)
		return Response.id
	end
end

-- Import

do
	ExportBaseUrl = "http://www.f3xteam.com/bt/export/%s"
	SupportLibrary = function()SupportLibrary = {};

		function SupportLibrary.FindTableOccurrences(Haystack, Needle)
			-- Returns the positions of instances of `needle` in table `haystack`

			local Positions = {};

			-- Add any indexes from `Haystack` that are `Needle`
			for Index, Value in pairs(Haystack) do
				if Value == Needle then
					table.insert(Positions, Index);
				end;
			end;

			return Positions;
		end;

		function SupportLibrary.FindTableOccurrence(Haystack, Needle)
			-- Returns one occurrence of `Needle` in `Haystack`

			-- Search for the first instance of `Needle` found and return it
			for Index, Value in pairs(Haystack) do
				if Value == Needle then
					return Index;
				end;
			end;

			-- If no occurrences exist, return `nil`
			return nil;

		end;

		function SupportLibrary.IsInTable(Haystack, Needle)
			-- Returns whether the given `Needle` can be found within table `Haystack`

			-- Go through every value in `Haystack` and return whether `Needle` is found
			for _, Value in pairs(Haystack) do
				if Value == Needle then
					return true;
				end;
			end;

			-- If no instances were found, return false
			return false;
		end;

		function SupportLibrary.DoTablesMatch(A, B)
			-- Returns whether the values of tables A and B are the same

			-- Check B table differences
			for Index in pairs(A) do
				if A[Index] ~= B[Index] then
					return false;
				end;
			end;

			-- Check A table differences
			for Index in pairs(B) do
				if B[Index] ~= A[Index] then
					return false;
				end;
			end;

			-- Return true if no differences
			return true;
		end;

		function SupportLibrary.Round(Number, Places)
			-- Returns `Number` rounded to the given number of decimal places (from lua-users)

			-- Ensure that `Number` is a number
			if type(Number) ~= 'number' then
				return;
			end;

			-- Round the number
			local Multiplier = 10 ^ (Places or 0);
			local RoundedNumber = math.floor(Number * Multiplier + 0.5) / Multiplier;

			-- Return the rounded number
			return RoundedNumber;
		end;

		function SupportLibrary.CloneTable(Table)
			-- Returns a copy of `Table`

			local ClonedTable = {};

			-- Copy all values into `ClonedTable`
			for Key, Value in pairs(Table) do
				ClonedTable[Key] = Value;
			end;

			-- Return the clone
			return ClonedTable;
		end;

		function SupportLibrary.GetAllDescendants(Parent)
			-- Recursively gets all the descendants of `Parent` and returns them

			local Descendants = {};

			for _, Child in pairs(Parent:GetChildren()) do

				-- Add the direct descendants of `Parent`
				table.insert(Descendants, Child);

				-- Add the descendants of each child
				for _, Subchild in pairs(SupportLibrary.GetAllDescendants(Child)) do
					table.insert(Descendants, Subchild);
				end;

			end;

			return Descendants;
		end;

		function SupportLibrary.GetDescendantCount(Parent)
			-- Recursively gets a count of all the descendants of `Parent` and returns them

			local Count = 0;

			for _, Child in pairs(Parent:GetChildren()) do

				-- Count the direct descendants of `Parent`
				Count = Count + 1;

				-- Count and add the descendants of each child
				Count = Count + SupportLibrary.GetDescendantCount(Child);

			end;

			return Count;
		end;

		function SupportLibrary.CloneParts(Parts)
			-- Returns a table of cloned `Parts`

			local Clones = {};

			-- Copy the parts into `Clones`
			for Index, Part in pairs(Parts) do
				Clones[Index] = Part:Clone();
			end;

			return Clones;
		end;

		function SupportLibrary.SplitString(String, Delimiter)
			-- Returns a table of string `String` split by pattern `Delimiter`

			local StringParts = {};
			local Pattern = ('([^%s]+)'):format(Delimiter);

			-- Capture each separated part
			String:gsub(Pattern, function (Part)
				table.insert(StringParts, Part);
			end);

			return StringParts;
		end;

		function SupportLibrary.GetChildOfClass(Parent, ClassName, Inherit)
			-- Returns the first child of `Parent` that is of class `ClassName`
			-- or nil if it couldn't find any

			-- Look for a child of `Parent` of class `ClassName` and return it
			if not Inherit then
				for _, Child in pairs(Parent:GetChildren()) do
					if Child.ClassName == ClassName then
						return Child;
					end;
				end;
			else
				for _, Child in pairs(Parent:GetChildren()) do
					if Child:IsA(ClassName) then
						return Child;
					end;
				end;
			end;

			return nil;
		end;

		function SupportLibrary.GetChildrenOfClass(Parent, ClassName, Inherit)
			-- Returns a table containing the children of `Parent` that are
			-- of class `ClassName`

			local Matches = {};

			if not Inherit then
				for _, Child in pairs(Parent:GetChildren()) do
					if Child.ClassName == ClassName then
						table.insert(Matches, Child);
					end;
				end;
			else
				for _, Child in pairs(Parent:GetChildren()) do
					if Child:IsA(ClassName) then
						table.insert(Matches, Child);
					end;
				end;
			end;

			return Matches;
		end;

		function SupportLibrary.HSVToRGB(Hue, Saturation, Value)
			-- Returns the RGB equivalent of the given HSV-defined color
			-- (adapted from some code found around the web)

			-- If it's achromatic, just return the value
			if Saturation == 0 then
				return Value;
			end;

			-- Get the hue sector
			local HueSector = math.floor(Hue / 60);
			local HueSectorOffset = (Hue / 60) - HueSector;

			local P = Value * (1 - Saturation);
			local Q = Value * (1 - Saturation * HueSectorOffset);
			local T = Value * (1 - Saturation * (1 - HueSectorOffset));

			if HueSector == 0 then
				return Value, T, P;
			elseif HueSector == 1 then
				return Q, Value, P;
			elseif HueSector == 2 then
				return P, Value, T;
			elseif HueSector == 3 then
				return P, Q, Value;
			elseif HueSector == 4 then
				return T, P, Value;
			elseif HueSector == 5 then
				return Value, P, Q;
			end;
		end;

		function SupportLibrary.RGBToHSV(Red, Green, Blue)
			-- Returns the HSV equivalent of the given RGB-defined color
			-- (adapted from some code found around the web)

			local Hue, Saturation, Value;

			local MinValue = math.min(Red, Green, Blue);
			local MaxValue = math.max(Red, Green, Blue);

			Value = MaxValue;

			local ValueDelta = MaxValue - MinValue;

			-- If the color is not black
			if MaxValue ~= 0 then
				Saturation = ValueDelta / MaxValue;

				-- If the color is purely black
			else
				Saturation = 0;
				Hue = -1;
				return Hue, Saturation, Value;
			end;

			if Red == MaxValue then
				Hue = (Green - Blue) / ValueDelta;
			elseif Green == MaxValue then
				Hue = 2 + (Blue - Red) / ValueDelta;
			else
				Hue = 4 + (Red - Green) / ValueDelta;
			end;

			Hue = Hue * 60;
			if Hue < 0 then
				Hue = Hue + 360;
			end;

			return Hue, Saturation, Value;
		end;

		function SupportLibrary.IdentifyCommonItem(Items)
			-- Returns the common item in table `Items`, or `nil` if
			-- they vary

			local CommonItem = nil;

			for ItemIndex, Item in pairs(Items) do

				-- Set the initial item to compare against
				if ItemIndex == 1 then
					CommonItem = Item;

					-- Check if this item is the same as the rest
				else
					-- If it isn't the same, there is no common item, so just stop right here
					if Item ~= CommonItem then
						return nil;
					end;
				end;

			end;

			-- Return the common item
			return CommonItem;
		end;

		function SupportLibrary.IdentifyCommonProperty(Items, Property)
			-- Returns the common `Property` value in the instances given in `Items`

			local PropertyVariations = {};

			-- Capture all the variations of the property value
			for _, Item in pairs(Items) do
				table.insert(PropertyVariations, Item[Property]);
			end;

			-- Return the common property value
			return SupportLibrary.IdentifyCommonItem(PropertyVariations);

		end;

		function SupportLibrary.CreateSignal()
			-- Returns a ROBLOX-like signal for connections (RbxUtility's is buggy)

			local Signal = {
				Connections	= {};

				-- Provide a function to connect an event handler
				Connect = function (Signal, Handler)

					-- Register the handler
					table.insert(Signal.Connections, Handler);

					-- Return a controller for this connection
					local ConnectionController = {

						-- Include a reference to the connection's handler
						Handler = Handler;

						-- Provide a way to disconnect this connection
						Disconnect = function (Connection)
							local ConnectionSearch = SupportLibrary.FindTableOccurrences(Signal.Connections, Connection.Handler);
							if #ConnectionSearch > 0 then
								local ConnectionIndex = ConnectionSearch[1];
								table.remove(Signal.Connections, ConnectionIndex);
							end;
						end;

					};

					-- Add compatibility aliases
					ConnectionController.disconnect = ConnectionController.Disconnect;

					-- Return the connection's controller
					return ConnectionController;

				end;

				-- Provide a function to trigger any connections' handlers
				Fire = function (Signal, ...)
					for _, Connection in pairs(Signal.Connections) do
						Connection(...);
					end;
				end;
			};

			-- Add compatibility aliases
			Signal.connect	= Signal.Connect;
			Signal.fire		= Signal.Fire;

			return Signal;
		end;

		function SupportLibrary.GetPartCorners(Part)
			-- Returns a table of the given part's corners' CFrames

			-- Make references to functions called a lot for efficiency
			local Insert = table.insert;
			local ToWorldSpace = CFrame.new().toWorldSpace;
			local NewCFrame = CFrame.new;

			-- Get info about the part
			local PartCFrame = Part.CFrame;
			local SizeX, SizeY, SizeZ = Part.Size.x / 2, Part.Size.y / 2, Part.Size.z / 2;

			-- Get each corner
			local Corners = {};
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, -SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, -SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, -SizeZ)));
			Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, -SizeZ)));

			return Corners;
		end;

		function SupportLibrary.CreatePart(PartType)
			-- Creates and returns new part based on `PartType` with sensible defaults

			local NewPart;

			if PartType == 'Normal' then
				NewPart = Instance.new('Part');
				NewPart.Size = Vector3.new(4, 1, 2);

			elseif PartType == 'Truss' then
				NewPart = Instance.new('TrussPart');

			elseif PartType == 'Wedge' then
				NewPart = Instance.new('WedgePart');
				NewPart.Size = Vector3.new(4, 1, 2);

			elseif PartType == 'Corner' then
				NewPart = Instance.new('CornerWedgePart');

			elseif PartType == 'Cylinder' then
				NewPart = Instance.new('Part');
				NewPart.Shape = 'Cylinder';
				NewPart.TopSurface = Enum.SurfaceType.Smooth;
				NewPart.BottomSurface = Enum.SurfaceType.Smooth;
				NewPart.Size = Vector3.new(2, 2, 2);

			elseif PartType == 'Ball' then
				NewPart = Instance.new('Part');
				NewPart.Shape = 'Ball';
				NewPart.TopSurface = Enum.SurfaceType.Smooth;
				NewPart.BottomSurface = Enum.SurfaceType.Smooth;

			elseif PartType == 'Seat' then
				NewPart = Instance.new('Seat');
				NewPart.Size = Vector3.new(4, 1, 2);

			elseif PartType == 'Vehicle Seat' then
				NewPart = Instance.new('VehicleSeat');
				NewPart.Size = Vector3.new(4, 1, 2);

			elseif PartType == 'Spawn' then
				NewPart = Instance.new('SpawnLocation');
				NewPart.Size = Vector3.new(4, 1, 2);
			end;

			-- Make sure the part is anchored
			NewPart.Anchored = true;

			return NewPart;
		end;

		function SupportLibrary.ImportServices()
			-- Adds references to common services into the calling environment

			-- Get the calling environment
			local CallingEnvironment = getfenv(2);

			-- Add the services
			CallingEnvironment.Workspace = Game:GetService 'Workspace';
			CallingEnvironment.Players = Game:GetService 'Players';
			CallingEnvironment.MarketplaceService = Game:GetService 'MarketplaceService';
			CallingEnvironment.ContentProvider = Game:GetService 'ContentProvider';
			CallingEnvironment.SoundService = Game:GetService 'SoundService';
			CallingEnvironment.UserInputService = Game:GetService 'UserInputService';
			CallingEnvironment.SelectionService = Game:GetService 'Selection';
			CallingEnvironment.CoreGui = Game:GetService 'CoreGui';
			CallingEnvironment.HttpService = Game:GetService 'HttpService';
			CallingEnvironment.ChangeHistoryService = Game:GetService 'ChangeHistoryService';
			CallingEnvironment.ReplicatedStorage = Game:GetService 'ReplicatedStorage';
			CallingEnvironment.GroupService = Game:GetService 'GroupService';
			CallingEnvironment.ServerScriptService = Game:GetService 'ServerScriptService';
			CallingEnvironment.ServerStorage = Game:GetService 'ServerStorage';
			CallingEnvironment.StarterGui = Game:GetService 'StarterGui';
			CallingEnvironment.RunService = Game:GetService 'RunService';
		end;

		function SupportLibrary.GetListMembers(List, MemberName)
			-- Gets the given member for each object in the given list table

			local Members = {};

			-- Collect the member values for each item in the list
			for _, Item in pairs(List) do
				table.insert(Members, Item[MemberName]);
			end;

			-- Return the members
			return Members;

		end;

		function SupportLibrary.AddUserInputListener(InputState, InputType, CatchAll, Callback)
			-- Connects to the given user input event and takes care of standard boilerplate code

			-- Turn the given `InputType` string into a proper enum
			local InputType = Enum.UserInputType[InputType];

			-- Create a UserInputService listener based on the given `InputState`
			return Game:GetService('UserInputService')['Input' .. InputState]:connect(function (Input, GameProcessedEvent)

				-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
				if GameProcessedEvent and not CatchAll then
					return;
				end;

				-- Make sure this is the right input type
				if Input.UserInputType ~= InputType then
					return;
				end;

				-- Make sure any key input did not occur while typing into a UI
				if InputType == Enum.UserInputType.Keyboard and Game:GetService('UserInputService'):GetFocusedTextBox() then
					return;
				end;

				-- Call back upon passing all conditions
				Callback(Input);

			end);

		end;

		function SupportLibrary.AddGuiInputListener(Gui, InputState, InputType, CatchAll, Callback)
			-- Connects to the given GUI user input event and takes care of standard boilerplate code

			-- Turn the given `InputType` string into a proper enum
			local InputType = Enum.UserInputType[InputType];

			-- Create a UserInputService listener based on the given `InputState`
			return Gui['Input' .. InputState]:connect(function (Input, GameProcessedEvent)

				-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
				if GameProcessedEvent and not CatchAll then
					return;
				end;

				-- Make sure this is the right input type
				if Input.UserInputType ~= InputType then
					return;
				end;

				-- Call back upon passing all conditions
				Callback(Input);

			end);

		end;

		function SupportLibrary.AreKeysPressed(...)
			-- Returns whether the given keys are pressed

			local RequestedKeysPressed = 0;

			-- Get currently pressed keys
			local PressedKeys = SupportLibrary.GetListMembers(Game:GetService('UserInputService'):GetKeysPressed(), 'KeyCode');

			-- Go through each requested key
			for _, Key in pairs({ ... }) do

				-- Count requested keys that are pressed
				if SupportLibrary.IsInTable(PressedKeys, Key) then
					RequestedKeysPressed = RequestedKeysPressed + 1;
				end;

			end;

			-- Return whether all the requested keys are pressed or not
			return RequestedKeysPressed == #{...};

		end;

		function SupportLibrary.ConcatTable(DestinationTable, SourceTable)
			-- Inserts all values of SourceTable into DestinationTable

			-- Add each value from `SourceTable` into `DestinationTable`
			for _, Value in ipairs(SourceTable) do
				table.insert(DestinationTable, Value);
			end;

			-- Return the destination table
			return DestinationTable;
		end;

		function SupportLibrary.ClearTable(Table)
			-- Clears out every value in `Table`

			-- Clear each index
			for Index in pairs(Table) do
				Table[Index] = nil;
			end;

			-- Return the given table
			return Table;
		end;

		function SupportLibrary.Values(Table)
			-- Returns all the values in the given table

			local Values = {};

			-- Go through each key and get each value
			for _, Value in pairs(Table) do
				table.insert(Values, Value);
			end;

			-- Return the values
			return Values;
		end;

		function SupportLibrary.Keys(Table)
			-- Returns all the keys in the given table

			local Keys = {};

			-- Go through each key and get each value
			for Key in pairs(Table) do
				table.insert(Keys, Key);
			end;

			-- Return the values
			return Keys;
		end;

		function SupportLibrary.Call(Function, ...)
			-- Returns a callback to `Function` with the given arguments
			local Args = { ... };
			return function (...)
				return Function(unpack(
					SupportLibrary.ConcatTable(SupportLibrary.CloneTable(Args), { ... })
					));
			end;
		end;

		function SupportLibrary.Trim(String)
			-- Returns a trimmed version of `String` (adapted from code from lua-users)
			return (String:gsub("^%s*(.-)%s*$", "%1"));
		end

		function SupportLibrary.ChainCall(...)
			-- Returns function that passes arguments through given functions and returns the final result

			-- Get the given chain of functions
			local Chain = { ... };

			-- Return the chaining function
			return function (...)

				-- Get arguments
				local Arguments = { ... };

				-- Go through each function and store the returned data to reuse in the next function's arguments 
				for _, Function in ipairs(Chain) do
					Arguments = { Function(unpack(Arguments)) };
				end;

				-- Return the final returned data
				return unpack(Arguments);

			end;

		end;

		function SupportLibrary.CountKeys(Table)
			-- Returns the number of keys in `Table`

			local Count = 0;

			-- Count each key
			for _ in pairs(Table) do
				Count = Count + 1;
			end;

			-- Return the count
			return Count;

		end;

		function SupportLibrary.Slice(Table, Start, End)
			-- Returns values from `Start` to `End` in `Table`

			local Slice = {};

			-- Go through the given indices
			for Index = Start, End do
				table.insert(Slice, Table[Index]);
			end;

			-- Return the slice
			return Slice;

		end;

		function SupportLibrary.FlipTable(Table)
			-- Returns a table with keys and values in `Table` swapped

			local FlippedTable = {};

			-- Flip each key and value
			for Key, Value in pairs(Table) do
				FlippedTable[Value] = Key;
			end;

			-- Return the flipped table
			return FlippedTable;

		end;

		function SupportLibrary.ScheduleRecurringTask(TaskFunction, Interval)
			-- Repeats `Task` every `Interval` seconds until stopped

			-- Create a task object
			local Task = {

				-- A switch determining if it's running or not
				Running = true;

				-- A function to stop this task
				Stop = function (Task)
					Task.Running = false;
				end;

				-- References to the task function and set interval
				TaskFunction = TaskFunction;
				Interval = Interval;

			};

			coroutine.wrap(function (Task)

				-- Repeat the task
				while wait(Task.Interval) and Task.Running do
					Task.TaskFunction();
				end;

			end)(Task);

			-- Return the task object
			return Task;

		end;

		function SupportLibrary.Clamp(Number, Minimum, Maximum)
			-- Returns the given number, clamped according to the provided min/max

			-- Clamp the number
			if Minimum and Number < Minimum then
				Number = Minimum;
			elseif Maximum and Number > Maximum then
				Number = Maximum;
			end;

			-- Return the clamped number
			return Number;

		end;

		function SupportLibrary.ReverseTable(Table)
			-- Returns a new table with values in the opposite order

			local ReversedTable = {};

			-- Copy each value at the opposite key
			for Index, Value in ipairs(Table) do
				ReversedTable[#Table - Index + 1] = Value;
			end;

			-- Return the reversed table
			return ReversedTable;

		end;

		return SupportLibrary;
	end
	SupportLibrary=SupportLibrary()
	SerializationV1 = function (creation_data, Container)
		local objects = {};

		for part_id, part_data in pairs( creation_data.parts ) do
			local Part;

			local part_type = part_data[1];
			if part_type == 1 then
				Part = Instance.new( "Part" );
			elseif part_type == 2 then
				Part = Instance.new( "TrussPart" );
			elseif part_type == 3 then
				Part = Instance.new( "WedgePart" );
			elseif part_type == 4 then
				Part = Instance.new( "CornerWedgePart" );
			elseif part_type == 5 then
				Part = Instance.new( "Part" );
				Part.Shape = "Cylinder";
			elseif part_type == 6 then
				Part = Instance.new( "Part" );
				Part.Shape = "Ball";
			elseif part_type == 7 then
				Part = Instance.new( "Seat" );
			elseif part_type == 8 then
				Part = Instance.new( "VehicleSeat" );
			elseif part_type == 9 then
				Part = Instance.new( "SpawnLocation" );
			end;
			objects[part_id] = Part;

			Part.Size = Vector3.new( unpack( part_data[2] ) );
			Part.CFrame = CFrame.new( unpack( part_data[3] ) );
			Part.BrickColor = BrickColor.new( part_data[4] );
			Part.Material = part_data[5];
			Part.Anchored = part_data[6];
			Part.CanCollide = part_data[7];
			Part.Reflectance = part_data[8];
			Part.Transparency = part_data[9];
			Part.TopSurface = part_data[10];
			Part.BottomSurface = part_data[11];
			Part.LeftSurface = part_data[12];
			Part.RightSurface = part_data[13];
			Part.FrontSurface = part_data[14];
			Part.BackSurface = part_data[15];

			Part.Parent = Container;

			-- Add the part ID if it's referenced somewhere else
			if creation_data.welds then
				for _, Weld in pairs( creation_data.welds ) do
					if Weld[1] == part_id or Weld[2] == part_id then
						local Tag = Instance.new('StringValue')
						Tag.Name = 'BTID'
						Tag.Value = part_id
						Tag.Parent = Part
						break
					end;
				end;
			end;

		end;

		if creation_data.welds then
			local weld_count = 0;
			for _, __ in pairs( creation_data.welds ) do
				weld_count = weld_count + 1;
			end;
			if weld_count > 0 then
				local WeldScript = Instance.new( 'Script' );
				WeldScript.Name = 'BTWelder';
				WeldScript.Source = [[-- This script creates the welds between parts imported by the Building Tools by F3X plugin.
		
		local BeforeAnchored = {};
		for _, Part in pairs(script.Parent:GetChildren()) do
		if Part:IsA 'BasePart' then
		BeforeAnchored[Part] = Part.Anchored;
		Part.Anchored = true;
		end;
		end;
		
		function _getAllDescendants( Parent )
		-- Recursively gets all the descendants of  `Parent` and returns them
		
		local descendants = {};
		
		for _, Child in pairs( Parent:GetChildren() ) do
		
		-- Add the direct descendants of `Parent`
		table.insert( descendants, Child );
		
		-- Add the descendants of each child
		for _, Subchild in pairs( _getAllDescendants( Child ) ) do
			table.insert( descendants, Subchild );
		end;
		
		end;
		
		return descendants;
		
		end;
		function findExportedPart( part_id )
		for _, Object in pairs( _getAllDescendants( script.Parent ) ) do
		if Object:IsA( 'StringValue' ) then
			if Object.Name == 'BTID' and Object.Value == part_id then
				return Object.Parent;
			end;
		end;
		end;
		end;
		
		]];

				for weld_id, weld_data in pairs( creation_data.welds ) do
					WeldScript.Source = WeldScript.Source .. [[
		
		( function ()
		local Part0 = findExportedPart( ']] .. weld_data[1] .. [[' );
		local Part1 = findExportedPart( ']] .. weld_data[2] .. [[' );
		if not Part0 or not Part1 then
		return;
		end;
		local Weld = Instance.new('Weld')
		Weld.Name = 'BTWeld';
		Weld.Parent = Game.JointsService;
		Weld.Archivable = false;
		Weld.Part0 = Part0;
		Weld.Part1 = Part1;
		Weld.C1 = CFrame.new( ]] .. table.concat( weld_data[3], ', ' ) .. [[ );
		end )();
		]];
				end;

				WeldScript.Source = WeldScript.Source .. [[
		
		for Part, Anchored in pairs(BeforeAnchored) do
		Part.Anchored = Anchored;
		end;]];
				WeldScript.Parent = Container;
			end;
		end;

		if creation_data.meshes then
			for mesh_id, mesh_data in pairs( creation_data.meshes ) do

				-- Create, place, and register the mesh
				local Mesh = Instance.new( "SpecialMesh", objects[mesh_data[1]] );
				objects[mesh_id] = Mesh;

				-- Set the mesh's properties
				Mesh.MeshType = mesh_data[2];
				Mesh.Scale = Vector3.new( unpack( mesh_data[3] ) );
				Mesh.MeshId = mesh_data[4];
				Mesh.TextureId = mesh_data[5];
				Mesh.VertexColor = Vector3.new( unpack( mesh_data[6] ) );

			end;
		end;

		if creation_data.textures then
			for texture_id, texture_data in pairs( creation_data.textures ) do

				-- Create, place, and register the texture
				local texture_class;
				if texture_data[2] == 1 then
					texture_class = 'Decal';
				elseif texture_data[2] == 2 then
					texture_class = 'Texture';
				end;
				local Texture = Instance.new( texture_class, objects[texture_data[1]] );
				objects[texture_id] = Texture;

				-- Set the texture's properties
				Texture.Face = texture_data[3];
				Texture.Texture = texture_data[4];
				Texture.Transparency = texture_data[5];
				if Texture:IsA( "Texture" ) then
					Texture.StudsPerTileU = texture_data[6];
					Texture.StudsPerTileV = texture_data[7];
				end;

			end;
		end;

		if creation_data.lights then
			for light_id, light_data in pairs( creation_data.lights ) do

				-- Create, place, and register the light
				local light_class;
				if light_data[2] == 1 then
					light_class = 'PointLight';
				elseif light_data[2] == 2 then
					light_class = 'SpotLight';
				end;
				local Light = Instance.new( light_class, objects[light_data[1]] )
				objects[light_id] = Light;

				-- Set the light's properties
				Light.Color = Color3.new( unpack( light_data[3] ) );
				Light.Brightness = light_data[4];
				Light.Range = light_data[5];
				Light.Shadows = light_data[6];
				if Light:IsA( 'SpotLight' ) then
					Light.Angle = light_data[7];
					Light.Face = light_data[8];
				end;

			end;
		end;

		if creation_data.decorations then
			for decoration_id, decoration_data in pairs( creation_data.decorations ) do

				-- Create and register the decoration
				if decoration_data[2] == 1 then
					local Smoke = Instance.new('Smoke')
					Smoke.Color = Color3.new( unpack( decoration_data[3] ) )
					Smoke.Opacity = decoration_data[4];
					Smoke.RiseVelocity = decoration_data[5];
					Smoke.Size = decoration_data[6]
					Smoke.Parent = objects[decoration_data[1]]
					objects[decoration_id] = Smoke

				elseif decoration_data[2] == 2 then
					local Fire = Instance.new('Fire')
					Fire.Color = Color3.new( unpack( decoration_data[3] ) );
					Fire.SecondaryColor = Color3.new( unpack( decoration_data[4] ) );
					Fire.Heat = decoration_data[5];
					Fire.Size = decoration_data[6];
					Fire.Parent = objects[decoration_data[1]];
					objects[decoration_id] = Fire;

				elseif decoration_data[2] == 3 then
					local Sparkles = Instance.new('Sparkles')
					Sparkles.SparkleColor = Color3.new( unpack( decoration_data[3] ) );
					Sparkles.Parent = objects[decoration_data[1]];
					objects[decoration_id] = Sparkles;
				end;

			end;
		end;
	end

	SerializationV2 = function()Serialization = {};

		-- Import services
		Support = SupportLibrary;
		Support.ImportServices();

		local Types = {
			Part = 0,
			WedgePart = 1,
			CornerWedgePart = 2,
			VehicleSeat = 3,
			Seat = 4,
			TrussPart = 5,
			SpecialMesh = 6,
			Texture = 7,
			Decal = 8,
			PointLight = 9,
			SpotLight = 10,
			SurfaceLight = 11,
			Smoke = 12,
			Fire = 13,
			Sparkles = 14,
			Model = 15
		};

		local DefaultNames = {
			Part = 'Part',
			WedgePart = 'Wedge',
			CornerWedgePart = 'CornerWedge',
			VehicleSeat = 'VehicleSeat',
			Seat = 'Seat',
			TrussPart = 'Truss',
			SpecialMesh = 'Mesh',
			Texture = 'Texture',
			Decal = 'Decal',
			PointLight = 'PointLight',
			SpotLight = 'SpotLight',
			SurfaceLight = 'SurfaceLight',
			Smoke = 'Smoke',
			Fire = 'Fire',
			Sparkles = 'Sparkles',
			Model = 'Model'
		};

		function Serialization.SerializeModel(Items)
			-- Returns a serialized version of the given model

			-- Filter out non-serializable items in `Items`
			local SerializableItems = {};
			for Index, Item in ipairs(Items) do
				table.insert(SerializableItems, Types[Item.ClassName] and Item or nil);
			end;
			Items = SerializableItems;

			-- Get a snapshot of the content
			local Keys = Support.FlipTable(Items);

			local Data = {};
			Data.Version = 2;
			Data.Items = {};

			-- Serialize each item in the model
			for Index, Item in pairs(Items) do

				if Item:IsA 'BasePart' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Size.X;
					Datum[5] = Item.Size.Y;
					Datum[6] = Item.Size.Z;
					Support.ConcatTable(Datum, { Item.CFrame:components() });
					Datum[19] = Item.BrickColor.Number;
					Datum[20] = Item.Material.Value;
					Datum[21] = Item.Anchored and 1 or 0;
					Datum[22] = Item.CanCollide and 1 or 0;
					Datum[23] = Item.Reflectance;
					Datum[24] = Item.Transparency;
					Datum[25] = Item.TopSurface.Value;
					Datum[26] = Item.BottomSurface.Value;
					Datum[27] = Item.FrontSurface.Value;
					Datum[28] = Item.BackSurface.Value;
					Datum[29] = Item.LeftSurface.Value;
					Datum[30] = Item.RightSurface.Value;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Part' then
					local Datum = Data.Items[Index];
					Datum[31] = Item.Shape.Value;
				end;

				if Item.ClassName == 'VehicleSeat' then
					local Datum = Data.Items[Index];
					Datum[31] = Item.MaxSpeed;
					Datum[32] = Item.Torque;
					Datum[33] = Item.TurnSpeed;
				end;

				if Item.ClassName == 'TrussPart' then
					local Datum = Data.Items[Index];
					Datum[31] = Item.Style.Value;
				end;

				if Item.ClassName == 'SpecialMesh' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.MeshType.Value;
					Datum[5] = Item.MeshId;
					Datum[6] = Item.TextureId;
					Datum[7] = Item.Offset.X;
					Datum[8] = Item.Offset.Y;
					Datum[9] = Item.Offset.Z;
					Datum[10] = Item.Scale.X;
					Datum[11] = Item.Scale.Y;
					Datum[12] = Item.Scale.Z;
					Datum[13] = Item.VertexColor.X;
					Datum[14] = Item.VertexColor.Y;
					Datum[15] = Item.VertexColor.Z;
					Data.Items[Index] = Datum;
				end;

				if Item:IsA 'Decal' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Texture;
					Datum[5] = Item.Transparency;
					Datum[6] = Item.Face.Value;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Texture' then
					local Datum = Data.Items[Index];
					Datum[7] = Item.StudsPerTileU;
					Datum[8] = Item.StudsPerTileV;
				end;

				if Item:IsA 'Light' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Brightness;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.Enabled and 1 or 0;
					Datum[9] = Item.Shadows and 1 or 0;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'PointLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
				end;

				if Item.ClassName == 'SpotLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
					Datum[11] = Item.Angle;
					Datum[12] = Item.Face.Value;
				end;

				if Item.ClassName == 'SurfaceLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
					Datum[11] = Item.Angle;
					Datum[12] = Item.Face.Value;
				end;

				if Item.ClassName == 'Smoke' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.Size;
					Datum[9] = Item.RiseVelocity;
					Datum[10] = Item.Opacity;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Fire' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.SecondaryColor.r;
					Datum[9] = Item.SecondaryColor.g;
					Datum[10] = Item.SecondaryColor.b;
					Datum[11] = Item.Heat;
					Datum[12] = Item.Size;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Sparkles' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.SparkleColor.r;
					Datum[6] = Item.SparkleColor.g;
					Datum[7] = Item.SparkleColor.b;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Model' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.PrimaryPart and Keys[Item.PrimaryPart] or 0;
					Data.Items[Index] = Datum;
				end;

				-- Spread the workload over time to avoid locking up the CPU
				if Index % 100 == 0 then
					wait(0.01);
				end;

			end;

			-- Return the serialized data
			return HttpService:JSONEncode(Data);

		end;

		function Serialization.InflateBuildData(Data)
			-- Returns an inflated version of the given build data

			local Build = {};
			local Instances = {};

			-- Create each instance
			for Index, Datum in ipairs(Data.Items) do

				-- Inflate BaseParts
				if Datum[1] == Types.Part
					or Datum[1] == Types.WedgePart
					or Datum[1] == Types.CornerWedgePart
					or Datum[1] == Types.VehicleSeat
					or Datum[1] == Types.Seat
					or Datum[1] == Types.TrussPart
				then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Size = Vector3.new(unpack(Support.Slice(Datum, 4, 6)));
					Item.CFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
					Item.BrickColor = BrickColor.new(Datum[19]);
					Item.Material = Datum[20];
					Item.Anchored = Datum[21] == 1;
					Item.CanCollide = Datum[22] == 1;
					Item.Reflectance = Datum[23];
					Item.Transparency = Datum[24];
					Item.TopSurface = Datum[25];
					Item.BottomSurface = Datum[26];
					Item.FrontSurface = Datum[27];
					Item.BackSurface = Datum[28];
					Item.LeftSurface = Datum[29];
					Item.RightSurface = Datum[30];

					-- Register the part
					Instances[Index] = Item;
				end;

				-- Inflate specific Part properties
				if Datum[1] == Types.Part then
					local Item = Instances[Index];
					Item.Shape = Datum[31];
				end;

				-- Inflate specific VehicleSeat properties
				if Datum[1] == Types.VehicleSeat then
					local Item = Instances[Index];
					Item.MaxSpeed = Datum[31];
					Item.Torque = Datum[32];
					Item.TurnSpeed = Datum[33];
				end;

				-- Inflate specific TrussPart properties
				if Datum[1] == Types.TrussPart then
					local Item = Instances[Index];
					Item.Style = Datum[31];
				end;

				-- Inflate SpecialMesh instances
				if Datum[1] == Types.SpecialMesh then
					local Item = Instance.new('SpecialMesh');
					Item.MeshType = Datum[4];
					Item.MeshId = Datum[5];
					Item.TextureId = Datum[6];
					Item.Offset = Vector3.new(unpack(Support.Slice(Datum, 7, 9)));
					Item.Scale = Vector3.new(unpack(Support.Slice(Datum, 10, 12)));
					Item.VertexColor = Vector3.new(unpack(Support.Slice(Datum, 13, 15)));

					-- Register the mesh
					Instances[Index] = Item;
				end;

				-- Inflate Decal instances
				if Datum[1] == Types.Decal or Datum[1] == Types.Texture then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Texture = Datum[4];
					Item.Transparency = Datum[5];
					Item.Face = Datum[6];

					-- Register the Decal
					Instances[Index] = Item;
				end;

				-- Inflate specific Texture properties
				if Datum[1] == Types.Texture then
					local Item = Instances[Index];
					Item.StudsPerTileU = Datum[7];
					Item.StudsPerTileV = Datum[8];
				end;

				-- Inflate Light instances
				if Datum[1] == Types.PointLight
					or Datum[1] == Types.SpotLight
					or Datum[1] == Types.SurfaceLight
				then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Brightness = Datum[4];
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.Enabled = Datum[8] == 1;
					Item.Shadows = Datum[9] == 1;

					-- Register the light
					Instances[Index] = Item;
				end;

				-- Inflate specific PointLight properties
				if Datum[1] == Types.PointLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
				end;

				-- Inflate specific SpotLight properties
				if Datum[1] == Types.SpotLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
					Item.Angle = Datum[11];
					Item.Face = Datum[12];
				end;

				-- Inflate specific SurfaceLight properties
				if Datum[1] == Types.SurfaceLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
					Item.Angle = Datum[11];
					Item.Face = Datum[12];
				end;

				-- Inflate Smoke instances
				if Datum[1] == Types.Smoke then
					local Item = Instance.new('Smoke');
					Item.Enabled = Datum[4] == 1;
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.Size = Datum[8];
					Item.RiseVelocity = Datum[9];
					Item.Opacity = Datum[10];

					-- Register the smoke
					Instances[Index] = Item;
				end;

				-- Inflate Fire instances
				if Datum[1] == Types.Fire then
					local Item = Instance.new('Fire');
					Item.Enabled = Datum[4] == 1;
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.SecondaryColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
					Item.Heat = Datum[11];
					Item.Size = Datum[12];

					-- Register the fire
					Instances[Index] = Item;
				end;

				-- Inflate Sparkles instances
				if Datum[1] == Types.Sparkles then
					local Item = Instance.new('Sparkles');
					Item.Enabled = Datum[4] == 1;
					Item.SparkleColor = Color3.new(unpack(Support.Slice(Datum, 5, 7)));

					-- Register the instance
					Instances[Index] = Item;
				end;

				-- Inflate Model instances
				if Datum[1] == Types.Model then
					local Item = Instance.new('Model');

					-- Register the model
					Instances[Index] = Item;
				end;

			end;

			-- Set object values on each instance
			for Index, Datum in pairs(Data.Items) do

				-- Get the item's instance
				local Item = Instances[Index];

				-- Set each item's parent and name
				if Item and Datum[1] <= 15 then
					Item.Name = (Datum[3] == '') and DefaultNames[Item.ClassName] or Datum[3];
					if Datum[2] == 0 then
						table.insert(Build, Item);
					else
						Item.Parent = Instances[Datum[2]];
					end;
				end;

				-- Set model primary parts
				if Item and Datum[1] == 15 then
					Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
				end;

			end;

			-- Return the model
			return Build;

		end;

		-- Return the API
		return Serialization;
	end
	SerializationV2=SerializationV2()

	SerializationV3 = function()Serialization = {};

		-- Import services
		Support = SupportLibrary;
		Support.ImportServices();

		local Types = {
			Part = 0,
			WedgePart = 1,
			CornerWedgePart = 2,
			VehicleSeat = 3,
			Seat = 4,
			TrussPart = 5,
			SpecialMesh = 6,
			Texture = 7,
			Decal = 8,
			PointLight = 9,
			SpotLight = 10,
			SurfaceLight = 11,
			Smoke = 12,
			Fire = 13,
			Sparkles = 14,
			Model = 15
		};

		local DefaultNames = {
			Part = 'Part',
			WedgePart = 'Wedge',
			CornerWedgePart = 'CornerWedge',
			VehicleSeat = 'VehicleSeat',
			Seat = 'Seat',
			TrussPart = 'Truss',
			SpecialMesh = 'Mesh',
			Texture = 'Texture',
			Decal = 'Decal',
			PointLight = 'PointLight',
			SpotLight = 'SpotLight',
			SurfaceLight = 'SurfaceLight',
			Smoke = 'Smoke',
			Fire = 'Fire',
			Sparkles = 'Sparkles',
			Model = 'Model'
		};

		function Serialization.SerializeModel(Items)
			-- Returns a serialized version of the given model

			-- Filter out non-serializable items in `Items`
			local SerializableItems = {};
			for Index, Item in ipairs(Items) do
				table.insert(SerializableItems, Types[Item.ClassName] and Item or nil);
			end;
			Items = SerializableItems;

			-- Get a snapshot of the content
			local Keys = Support.FlipTable(Items);

			local Data = {};
			Data.Version = 3;
			Data.Items = {};

			-- Serialize each item in the model
			for Index, Item in pairs(Items) do

				if Item:IsA 'BasePart' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Size.X;
					Datum[5] = Item.Size.Y;
					Datum[6] = Item.Size.Z;
					Support.ConcatTable(Datum, { Item.CFrame:components() });
					Datum[19] = Item.Color.r;
					Datum[20] = Item.Color.g;
					Datum[21] = Item.Color.b;
					Datum[22] = Item.Material.Value;
					Datum[23] = Item.Anchored and 1 or 0;
					Datum[24] = Item.CanCollide and 1 or 0;
					Datum[25] = Item.Reflectance;
					Datum[26] = Item.Transparency;
					Datum[27] = Item.TopSurface.Value;
					Datum[28] = Item.BottomSurface.Value;
					Datum[29] = Item.FrontSurface.Value;
					Datum[30] = Item.BackSurface.Value;
					Datum[31] = Item.LeftSurface.Value;
					Datum[32] = Item.RightSurface.Value;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Part' then
					local Datum = Data.Items[Index];
					Datum[33] = Item.Shape.Value;
				end;

				if Item.ClassName == 'VehicleSeat' then
					local Datum = Data.Items[Index];
					Datum[33] = Item.MaxSpeed;
					Datum[34] = Item.Torque;
					Datum[35] = Item.TurnSpeed;
				end;

				if Item.ClassName == 'TrussPart' then
					local Datum = Data.Items[Index];
					Datum[33] = Item.Style.Value;
				end;

				if Item.ClassName == 'SpecialMesh' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.MeshType.Value;
					Datum[5] = Item.MeshId;
					Datum[6] = Item.TextureId;
					Datum[7] = Item.Offset.X;
					Datum[8] = Item.Offset.Y;
					Datum[9] = Item.Offset.Z;
					Datum[10] = Item.Scale.X;
					Datum[11] = Item.Scale.Y;
					Datum[12] = Item.Scale.Z;
					Datum[13] = Item.VertexColor.X;
					Datum[14] = Item.VertexColor.Y;
					Datum[15] = Item.VertexColor.Z;
					Data.Items[Index] = Datum;
				end;

				if Item:IsA 'Decal' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Texture;
					Datum[5] = Item.Transparency;
					Datum[6] = Item.Face.Value;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Texture' then
					local Datum = Data.Items[Index];
					Datum[7] = Item.StudsPerTileU;
					Datum[8] = Item.StudsPerTileV;
				end;

				if Item:IsA 'Light' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Brightness;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.Enabled and 1 or 0;
					Datum[9] = Item.Shadows and 1 or 0;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'PointLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
				end;

				if Item.ClassName == 'SpotLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
					Datum[11] = Item.Angle;
					Datum[12] = Item.Face.Value;
				end;

				if Item.ClassName == 'SurfaceLight' then
					local Datum = Data.Items[Index];
					Datum[10] = Item.Range;
					Datum[11] = Item.Angle;
					Datum[12] = Item.Face.Value;
				end;

				if Item.ClassName == 'Smoke' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.Size;
					Datum[9] = Item.RiseVelocity;
					Datum[10] = Item.Opacity;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Fire' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.Color.r;
					Datum[6] = Item.Color.g;
					Datum[7] = Item.Color.b;
					Datum[8] = Item.SecondaryColor.r;
					Datum[9] = Item.SecondaryColor.g;
					Datum[10] = Item.SecondaryColor.b;
					Datum[11] = Item.Heat;
					Datum[12] = Item.Size;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Sparkles' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.Enabled and 1 or 0;
					Datum[5] = Item.SparkleColor.r;
					Datum[6] = Item.SparkleColor.g;
					Datum[7] = Item.SparkleColor.b;
					Data.Items[Index] = Datum;
				end;

				if Item.ClassName == 'Model' then
					local Datum = {};
					Datum[1] = Types[Item.ClassName];
					Datum[2] = Keys[Item.Parent] or 0;
					Datum[3] = Item.Name == DefaultNames[Item.ClassName] and '' or Item.Name;
					Datum[4] = Item.PrimaryPart and Keys[Item.PrimaryPart] or 0;
					Data.Items[Index] = Datum;
				end;

				-- Spread the workload over time to avoid locking up the CPU
				if Index % 100 == 0 then
					wait(0.01);
				end;

			end;

			-- Return the serialized data
			return HttpService:JSONEncode(Data);

		end;

		function Serialization.InflateBuildData(Data)
			-- Returns an inflated version of the given build data

			local Build = {};
			local Instances = {};

			-- Create each instance
			for Index, Datum in ipairs(Data.Items) do

				-- Inflate BaseParts
				if Datum[1] == Types.Part
					or Datum[1] == Types.WedgePart
					or Datum[1] == Types.CornerWedgePart
					or Datum[1] == Types.VehicleSeat
					or Datum[1] == Types.Seat
					or Datum[1] == Types.TrussPart
				then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Size = Vector3.new(unpack(Support.Slice(Datum, 4, 6)));
					Item.CFrame = CFrame.new(unpack(Support.Slice(Datum, 7, 18)));
					Item.Color = Color3.new(Datum[19], Datum[20], Datum[21]);
					Item.Material = Datum[22]~=0 and Datum[22] or Item.Material;
					Item.Anchored = Datum[23] == 1;
					Item.CanCollide = Datum[24] == 1;
					Item.Reflectance = Datum[25];
					Item.Transparency = Datum[26];
					Item.TopSurface = Datum[27];
					Item.BottomSurface = Datum[28];
					Item.FrontSurface = Datum[29];
					Item.BackSurface = Datum[30];
					Item.LeftSurface = Datum[31];
					Item.RightSurface = Datum[32];

					-- Register the part
					Instances[Index] = Item;
				end;

				-- Inflate specific Part properties
				if Datum[1] == Types.Part then
					local Item = Instances[Index];
					Item.Shape = Datum[33];
				end;

				-- Inflate specific VehicleSeat properties
				if Datum[1] == Types.VehicleSeat then
					local Item = Instances[Index];
					Item.MaxSpeed = Datum[33];
					Item.Torque = Datum[34];
					Item.TurnSpeed = Datum[35];
				end;

				-- Inflate specific TrussPart properties
				if Datum[1] == Types.TrussPart then
					local Item = Instances[Index];
					Item.Style = Datum[33];
				end;

				-- Inflate SpecialMesh instances
				if Datum[1] == Types.SpecialMesh then
					local Item = Instance.new('SpecialMesh');
					Item.MeshType = Datum[4];
					Item.MeshId = Datum[5];
					Item.TextureId = Datum[6];
					Item.Offset = Vector3.new(unpack(Support.Slice(Datum, 7, 9)));
					Item.Scale = Vector3.new(unpack(Support.Slice(Datum, 10, 12)));
					Item.VertexColor = Vector3.new(unpack(Support.Slice(Datum, 13, 15)));

					-- Register the mesh
					Instances[Index] = Item;
				end;

				-- Inflate Decal instances
				if Datum[1] == Types.Decal or Datum[1] == Types.Texture then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Texture = Datum[4];
					Item.Transparency = Datum[5];
					Item.Face = Datum[6];

					-- Register the Decal
					Instances[Index] = Item;
				end;

				-- Inflate specific Texture properties
				if Datum[1] == Types.Texture then
					local Item = Instances[Index];
					Item.StudsPerTileU = Datum[7];
					Item.StudsPerTileV = Datum[8];
				end;

				-- Inflate Light instances
				if Datum[1] == Types.PointLight
					or Datum[1] == Types.SpotLight
					or Datum[1] == Types.SurfaceLight
				then
					local Item = Instance.new(Support.FindTableOccurrence(Types, Datum[1]));
					Item.Brightness = Datum[4];
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.Enabled = Datum[8] == 1;
					Item.Shadows = Datum[9] == 1;

					-- Register the light
					Instances[Index] = Item;
				end;

				-- Inflate specific PointLight properties
				if Datum[1] == Types.PointLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
				end;

				-- Inflate specific SpotLight properties
				if Datum[1] == Types.SpotLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
					Item.Angle = Datum[11];
					Item.Face = Datum[12];
				end;

				-- Inflate specific SurfaceLight properties
				if Datum[1] == Types.SurfaceLight then
					local Item = Instances[Index];
					Item.Range = Datum[10];
					Item.Angle = Datum[11];
					Item.Face = Datum[12];
				end;

				-- Inflate Smoke instances
				if Datum[1] == Types.Smoke then
					local Item = Instance.new('Smoke');
					Item.Enabled = Datum[4] == 1;
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.Size = Datum[8];
					Item.RiseVelocity = Datum[9];
					Item.Opacity = Datum[10];

					-- Register the smoke
					Instances[Index] = Item;
				end;

				-- Inflate Fire instances
				if Datum[1] == Types.Fire then
					local Item = Instance.new('Fire');
					Item.Enabled = Datum[4] == 1;
					Item.Color = Color3.new(unpack(Support.Slice(Datum, 5, 7)));
					Item.SecondaryColor = Color3.new(unpack(Support.Slice(Datum, 8, 10)));
					Item.Heat = Datum[11];
					Item.Size = Datum[12];

					-- Register the fire
					Instances[Index] = Item;
				end;

				-- Inflate Sparkles instances
				if Datum[1] == Types.Sparkles then
					local Item = Instance.new('Sparkles');
					Item.Enabled = Datum[4] == 1;
					Item.SparkleColor = Color3.new(unpack(Support.Slice(Datum, 5, 7)));

					-- Register the instance
					Instances[Index] = Item;
				end;

				-- Inflate Model instances
				if Datum[1] == Types.Model then
					local Item = Instance.new('Model');

					-- Register the model
					Instances[Index] = Item;
				end;

			end;

			-- Set object values on each instance
			for Index, Datum in pairs(Data.Items) do

				-- Get the item's instance
				local Item = Instances[Index];

				-- Set each item's parent and name
				if Item and Datum[1] <= 15 then
					Item.Name = (Datum[3] == '') and DefaultNames[Item.ClassName] or Datum[3];
					if Datum[2] == 0 then
						table.insert(Build, Item);
					else
						Item.Parent = Instances[Datum[2]];
					end;
				end;

				-- Set model primary parts
				if Item and Datum[1] == 15 then
					Item.PrimaryPart = (Datum[4] ~= 0) and Instances[Datum[4]] or nil;
				end;

			end;

			-- Return the model
			return Build;

		end;

		-- Return the API
		return Serialization;
	end
	SerializationV3=SerializationV3()

	SendMsg=SendMsg or function(x,z)print(x,z)end

	function F3XImport(creation_id)
		local creation_data;
		local download_attempt, download_error = ypcall( function ()
			if not pcall(function()
					creation_data = HttpService:GetAsync( ExportBaseUrl:format( creation_id ) );end) then
				creation_data=(Request or syn.request){
					Url=ExportBaseUrl:format( creation_id ),
					Method="GET"
				}.Body
			end
		end );

		-- Fail graciously
		if not download_attempt and download_error == 'Http requests are not enabled' then
			print 'Import from Building Tools by F3X: Please enable HTTP requests (see http://wiki.roblox.com/index.php?title=Sending_HTTP_requests#Http_requests_are_not_enabled)';
			SendMsg( 'Please enable HTTP requests (see Output)', 'Got it' );
			return false;
		end;
		if not download_attempt then
			print( 'Import from Building Tools by F3X (download request error): ' .. tostring( download_error ) );
			SendMsg( "We couldn't get your creation", 'Oh' );
			return false;
		end;
		if not ( creation_data and type( creation_data ) == 'string' and creation_data:len() > 0 ) then
			SendMsg( "We couldn't get your creation", ':(' );
			return false;
		end;
		if not pcall( function () creation_data = HttpService:JSONDecode( creation_data ); end ) then
			SendMsg( "We couldn't get your creation", ":'(" );
			return false;
		end;
		local s, newData = pcall(function()
    		return RBLXSerialize.Decode(creation_data.Items[1][3])
		end)
	    if s and typeof(newData)=="Instance" then
	        return newData
		else print(newData, creation_data.Items[1][3])
	    end
	    -- Well, I guess we didn't create this export. Back to using F3X's crappy serialization system.
	    
	    -- Create a container to hold the creation
		local Container = Instance.new'Model';
		Container.Name = 'BTExport';
		Container.Parent = workspace

		-- Inflate legacy v1 export data
		if creation_data.version == 1 then
			SerializationV1(creation_data, Container)
			Container:MakeJoints()
			return Container

			-- Parse builds with serialization format version 2
		elseif creation_data.Version == 2 then

			-- Inflate the build data
			local Parts = SerializationV2.InflateBuildData(creation_data);

			-- Parent the build into the export container
			for _, Part in pairs(Parts) do
				Part.Parent = Container;
			end;

			-- Finalize the import
			Container:MakeJoints();
			return Container
			-- Parse builds with serialization format version 3
		elseif creation_data.Version == 3 then

			-- Inflate the build data
			local Parts = SerializationV3.InflateBuildData(creation_data);

			-- Parent the build into the export container
			for _, Part in pairs(Parts) do
				Part.Parent = Container;
			end;

			-- Finalize the import
			Container:MakeJoints();
			return Container
		end;
	end
end


return {Export = F3XExport, Import = F3XImport}
