local bitbuffer = loadfile("bitbuffer.lua")()

local function ReadFile(path)
    local f = assert(io.open(path, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local function TestCorrectness(buffer_factory, value, read_function, write_function, write_count, test_file)
    local test_data = ReadFile(test_file)

    local BB = buffer_factory(test_data)

    test_data = nil

    collectgarbage("collect")
    collectgarbage("collect")

    local cur_index = 1
    while BB:Tell() < BB:Size() do
        local read = read_function(BB)
        if read ~= 4 then
            error("oops at index " .. cur_index .. " with value " .. tostring(read))
        end

        cur_index = cur_index + 1
    end

    BB = buffer_factory()

    collectgarbage("collect")
    collectgarbage("collect")

    for i = 1, write_count do
        write_function(BB, value)
    end

    BB:Seek(0)

    cur_index = 1
    while BB:Tell() < BB:Size() do
        local read = read_function(BB)
        if read ~= bit.tobit(value) then
            error("oops at index " .. cur_index .. " with value " .. tostring(read))
        end

        cur_index = cur_index + 1
    end

    BB = nil

    collectgarbage("collect")
    collectgarbage("collect")
end

print("Verifying correctness with uint8...")
TestCorrectness(
    bitbuffer,
    0x59,
    function(BB)
        return BB:ReadBits(8)
    end,
    function(BB, value)
        return BB:WriteBits(value, 8)
    end,
    1000 * 1000 * 250,
    "test_data_uint8.bin"
)
print("Finished verifying correctness with uint8!")

print("Verifying correctness with uint16...")
TestCorrectness(
    bitbuffer,
    0x4243,
    function(BB)
        return BB:ReadBits(16)
    end,
    function(BB, value)
        return BB:WriteBits(value, 16)
    end,
    1000 * 1000 * 250 / 2,
    "test_data_uint16.bin"
)
print("Finished verifying correctness with uint16!")

print("Verifying correctness with uint32...")
TestCorrectness(
    bitbuffer,
    0x84428421,
    function(BB)
        return BB:ReadBits(32)
    end,
    function(BB, value)
        return BB:WriteBits(value, 32)
    end,
    1000 * 1000 * 250 / 4,
    "test_data_uint32.bin"
)
print("Finished verifying correctness with uint32!")

print("Verifying correctness of incrementing sequential writing and reading...")
do
    local BB = bitbuffer()

    for i = 1, 32 do
        BB:WriteBits(1, i)
    end

    BB:Seek(0)

    for i = 1, 32 do
        if BB:ReadBits(i) ~= 1 then
            error("oops reading " .. i .. " bits")
        end
    end
end
print("Finished verifying correctness of incrementing sequential writing and reading!")

print("Finished all correctness tests!")
