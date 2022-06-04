local bitbuffer = loadfile("bitbuffer.lua")()
local ByteBuffer = loadfile("unnamed_competitor.lua")
ByteBuffer = ByteBuffer and ByteBuffer() or nil

local function ReadFile(path)
    local f = assert(io.open(path, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local function TestAll(buffer_factory, read_function, write_function, write_count, test_file)
    collectgarbage("collect")
    collectgarbage("collect")

    local test_data = ReadFile(test_file)

    print("Parsing all test data...")
    local start = os.clock()

    local BB = buffer_factory(test_data)

    print("Took " .. os.clock() - start .. "s\n")

    test_data = nil

    collectgarbage("collect")
    collectgarbage("collect")

    print("Reading everything in buffer...")
    start = os.clock()

    while BB:Tell() < BB:Size() do
        read_function(BB)
    end

    print("Took " .. os.clock() - start .. "s\n")

    BB = buffer_factory()

    collectgarbage("collect")
    collectgarbage("collect")

    print("Writing data into buffer...")
    start = os.clock()

    for i = 1, write_count do
        write_function(BB, 4)
    end

    print("Took " .. os.clock() - start .. "s\n")

    print("Outputting data into string...")
    start = os.clock()

    tostring(BB)

    print("Took " .. os.clock() - start .. "s\n")
    print("Finished!\n\n\n")
end

print("Testing bitbuffer with uint8...\n")
TestAll(
    bitbuffer,
    function(BB)
        return BB:ReadBits(8)
    end,
    function(BB, value)
        return BB:WriteBits(value, 8)
    end,
    1000 * 1000 * 250,
    "test_data_uint8.bin"
)

print("Testing bitbuffer with uint16...\n")
TestAll(
    bitbuffer,
    function(BB)
        return BB:ReadBits(16)
    end,
    function(BB, value)
        return BB:WriteBits(value, 16)
    end,
    1000 * 1000 * 250 / 2,
    "test_data_uint16.bin"
)

print("Testing bitbuffer with uint32...\n")
TestAll(
    bitbuffer,
    function(BB)
        return BB:ReadBits(32)
    end,
    function(BB, value)
        return BB:WriteBits(value, 32)
    end,
    1000 * 1000 * 250 / 4,
    "test_data_uint32.bin"
)

if ByteBuffer ~= nil then
    print("Testing ByteBuffer with uint8...\n")
    TestAll(
        ByteBuffer,
        function(BB)
            return BB:ReadByte()
        end,
        function(BB, value)
            return BB:WriteByte(value)
        end,
        1000 * 1000 * 250,
        "test_data_uint8.bin"
    )

    print("Testing ByteBuffer with uint16...\n")
    TestAll(
        ByteBuffer,
        function(BB)
            return BB:ReadUShort()
        end,
        function(BB, value)
            return BB:WriteUShort(value)
        end,
        1000 * 1000 * 250 / 2,
        "test_data_uint16.bin"
    )

    print("Testing ByteBuffer with uint32...\n")
    TestAll(
        ByteBuffer,
        function(BB)
            return BB:ReadULong()
        end,
        function(BB, value)
            return BB:WriteULong(value)
        end,
        1000 * 1000 * 250 / 4,
        "test_data_uint32.bin"
    )
end

print("Finished all bechmark tests!")
