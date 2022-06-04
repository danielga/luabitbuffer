--[[
    Lua bit buffer
    Reads from and writes bits to a buffer (made up of a table of 32 bit numbers)
]]

local band, bor, blshift, brshift, bnot
local min, max = math.min, math.max
local type = type
local sbyte, schar = string.byte, string.char
local tconcat = table.concat
local create_mask

local is_cpu_little_endian = string.byte(string.dump(function() end), 7) ~= 0

local bb = {}

-- Reads up to 32 bits from the buffer
--[[
Example with starting offset of 16 bits:
|-------------32-bits---------------|-------------32-bits---------------|
|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|
Bits to read:
|--------|++++++++|++++++++|++++++++|
Bits to ignore from first uint32 of buffer:
|++++++++|++++++++|--------|--------|
Bits to ignore from second uint32 of buffer:
                                    |--------|++++++++|++++++++|++++++++|
]]
function bb:ReadBits(quantity)
    if quantity <= 0 or quantity > 32 or self.offset + quantity > self.size then
        return nil
    end

    -- Divide by 8 to get byte offset, divide by 4 to get uint32 offset
    -- Bit right shift by 3 is equivalent to dividing by 8, by 2 is equivalent to dividing by 4
    -- Add 1 because Lua indexing starts at 1
    local offset_bytes = brshift(self.offset, 5) + 1
    local start_bit = band(self.offset, 0x1F)

    self.offset = self.offset + quantity

    local bits_to_read1 = min(quantity, 32 - start_bit)
    local mask1 = create_mask(bits_to_read1, 32 - start_bit - bits_to_read1)
    local data1 = band(self.data[offset_bytes] or 0, mask1)

    if quantity <= bits_to_read1 then
        return brshift(data1, 32 - start_bit - bits_to_read1)
    end

    local bits_to_read2 = quantity - bits_to_read1
    local mask2 = create_mask(32, 32 - bits_to_read2)
    local data2 = band(self.data[offset_bytes + 1] or 0, mask2)

    return bor(blshift(data1, bits_to_read2), brshift(data2, 32 - bits_to_read2))
end

-- Writes up to 32 bits to the buffer
--[[
Example with starting offset of 16 bits:
|-------------32-bits---------------|-------------32-bits---------------|
|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|-8-bits-|
Bits to write:
|--------|++++++++|++++++++|++++++++|
Bits to save from first uint32 of buffer:
|++++++++|++++++++|--------|--------|
Bits to save from second uint32 of buffer:
                                    |--------|++++++++|++++++++|++++++++|
]]
function bb:WriteBits(number, quantity)
    if quantity <= 0 or quantity > 32 then
        return false
    end

    -- Divide by 8 to get byte offset, divide by 4 to get uint32 offset
    -- Bit right shift by 3 is equivalent to dividing by 8, by 2 is equivalent to dividing by 4
    -- Add 1 because Lua indexing starts at 1
    local offset_bytes = brshift(self.offset, 5) + 1
    local start_bit = band(self.offset, 0x1F)

    self.offset = self.offset + quantity
    self.size = max(self.size, self.offset)

    local bits_to_write1 = min(quantity, 32 - start_bit)
    local bits_to_write2 = quantity - bits_to_write1
    local mask_lshift1 = 32 - start_bit - bits_to_write1
    local new_mask1 = create_mask(bits_to_write1, mask_lshift1)
    local new_data1
    if bits_to_write2 == 0 then
        new_data1 = band(blshift(number, mask_lshift1), new_mask1)
    else
        new_data1 = band(brshift(number, bits_to_write2), new_mask1)
    end

    local original_mask1 = bnot(new_mask1)
    local original_data1 = band(self.data[offset_bytes] or 0, original_mask1)
    self.data[offset_bytes] = bor(original_data1, new_data1)

    if bits_to_write2 == 0 then
        return true
    end

    local new_data2 = blshift(number, 32 - bits_to_write2)
    local original_mask2 = create_mask(bits_to_write2, 0)
    local original_data2 = band(self.data[offset_bytes + 1] or 0, original_mask2)
    self.data[offset_bytes + 1] = bor(original_data2, new_data2)

    return true
end

-- Seeks to a certain bit in the buffer
function bb:Seek(offset)
    assert(offset >= 0, "invalid bit offset")
    self.offset = offset
end

-- Seeks to a certain bit in the buffer relative to the current offset
function bb:SeekRelative(offset)
    self.offset = self.offset + offset
end

-- Returns the current size of the buffer
function bb:Size()
    return self.size
end

-- Returns the current offset of the buffer
function bb:Tell()
    return self.offset
end

-- Returns the buffer as a string with binary data
function bb:Data()
    if self.size <= 0 then
        return nil
    end

    local new_data = {}

    local byte_count = brshift(self.size - 1, 3) + 1
    local uint32_count = brshift(byte_count, 2)
    for i = 1, uint32_count do
        local n = self.data[i]
        local b1, b2, b3, b4 = band(n, 0xFF), band(brshift(n, 8), 0xFF), band(brshift(n, 16), 0xFF), band(brshift(n, 24), 0xFF)
        new_data[i] = schar(b1, b2, b3, b4)
    end

    local uint32_byte_count = uint32_count * 4
    if uint32_byte_count < byte_count then
        local last_uint32 = uint32_count + 1
        local n = self.data[last_uint32]
        local remaining_bytes = byte_count - uint32_byte_count
        local b1, b2, b3

        if remaining_bytes >= 3 then
            b3 = band(brshift(n, 16), 0xFF)
        end

        if remaining_bytes >= 2 then
            b2 = band(brshift(n, 8), 0xFF)
        end

        if remaining_bytes >= 1 then
            b1 = band(n, 0xFF)
        end

        new_data[last_uint32] = schar(b1, b2, b3)
    end

    return tconcat(new_data)
end

-- Sets the bitbuffer to read and write in little endian
function bb:SetLittleEndian()
    self.is_little_endian = true
end

-- Sets the bitbuffer to read and write in big endian
function bb:SetBigEndian()
    self.is_little_endian = false
end

-- Returns true if the bitbuffer is reading and writing in little endian
function bb:IsLittleEndian()
    return self.is_little_endian
end

-- Returns true if the bitbuffer is reading and writing in big endian
function bb:IsBigEndian()
    return not self.is_little_endian
end

local bbmeta = {__index = bb}

function bbmeta:__tostring()
    return self:Data() or ""
end

local function bitbuffer(data, size)
    local new_data = {}
    if type(data) == "string" then
        local data_bit_count = #data * 8
        size = size or data_bit_count

        if size > data_bit_count then
            return nil, "invalid bitbuffer size (larger than input data size)"
        end

        local byte_count = brshift(size - 1, 3) + 1
        local uint32_count = brshift(byte_count, 2)
        for i = 1, uint32_count do
            local start_byte = (i - 1) * 4 + 1
            local b1, b2, b3, b4 = sbyte(data, start_byte, start_byte + 4)
            new_data[i] = blshift(b4, 24) + blshift(b3, 16) + blshift(b2, 8) + b1
        end

        local uint32_byte_count = uint32_count * 4
        if uint32_byte_count < byte_count then
            local remaining_bytes = byte_count - uint32_byte_count
            local result = 0

            if remaining_bytes >= 3 then
                result = sbyte(data, uint32_byte_count + 3)
            end

            if remaining_bytes >= 2 then
                result = blshift(result, 8) + sbyte(data, uint32_byte_count + 2)
            end

            if remaining_bytes >= 1 then
                result = blshift(result, 8) + sbyte(data, uint32_byte_count + 1)
            end

            new_data[uint32_count + 1] = result
        end
    elseif type(data) == "table" then
        local data_count = #data
        size = size or data_count * 8 * 4
        if brshift(size, 3 + 2) > data_count then
            return nil, "invalid bitbuffer size (larger than input data size)"
        end

        for i = 1, data_count do
            local value = data[i]
            if value ~= nil and type(value) ~= "number" then
                return nil
            end

            new_data[i] = value or 0
        end
    elseif data ~= nil then
        return nil
    end

    return setmetatable({
        data = new_data,
        size = size or 0,
        offset = 0,
        is_little_endian = is_cpu_little_endian
    }, bbmeta)
end

if bit ~= nil then
    band = bit.band
    bor = bit.bor
    blshift = bit.lshift
    brshift = bit.rshift
    bnot = bit.bnot

    create_mask = function(length, offset)
        return blshift(length < 32 and blshift(1, length) - 1 or 0xFFFFFFFF, offset)
    end
elseif bit32 ~= nil then
    band = bit32.band
    bor = bit32.bor
    blshift = bit32.lshift
    brshift = bit32.rshift
    bnot = bit32.bnot

    create_mask = function(length, offset)
        return blshift(blshift(1, length) - 1, offset)
    end
else
    local version = {}
    for ver in string.gmatch(string.sub(_VERSION, 5), "([^%.]+)") do
        version[#version + 1] = tonumber(ver)
    end

    if version[1] < 5 or (version[1] == 5 and version[2] < 2) then
        error("No supported bit library found")
    end

    band, bor, blshift, brshift, bnot = loadfile("bitbuffer_lua53+.lua")()
end

return bitbuffer
