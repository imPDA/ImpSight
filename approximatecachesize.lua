-- Approximate constants for PUC-Rio Lua 5.3/5.4 on 64-bit.
local TABLE_BASE_BYTES = 56     -- empty table overhead
local TVALUE_BYTES     = 16     -- one array slot (8-byte value + 8-byte tag)
local HASH_NODE_BYTES  = 32     -- one hash entry (key TValue + value TValue + next pointer)

-- String constants for KEYS only (values are assumed to already exist elsewhere)
local STRING_OVERHEAD   = 24    -- TString header, approx.
local STRING_TERMINATOR = 1     -- trailing '\0'

-- Helper: Lua array sizes are usually rounded up to the next power of two.
local function nextPowerOfTwo(n)
    if n <= 0 then return 0 end
    local p = 1
    while p < n do
        p = p * 2
    end
    return p
end

-- Helper: Memory for an array table of 'n' elements (like arrays of strings or ints)
local function calcArrayTableBytes(n)
    local bytes = TABLE_BASE_BYTES
    if n > 0 then
        bytes = bytes + nextPowerOfTwo(n) * TVALUE_BYTES
    end
    return bytes
end

-- Main function: Approximates memory of the specific 'cache' structure
function ApproxCacheMemory(cache)
    local totalBytes = 0
    local entryCount = 0
    local visitedTables = {}

    for key, v in pairs(cache) do
        entryCount = entryCount + 1

        -- 1. Count the string key (length + overhead + terminator)
        if type(key) == "string" then
            totalBytes = totalBytes + STRING_OVERHEAD + #key + STRING_TERMINATOR
        end

        if type(v) == "table" and not visitedTables[v] then
            visitedTables[v] = true

            -- 2. Level 1 Table (exactly 2 indices: 1 and 2)
            -- It has a contiguous array part of size 2.
            totalBytes = totalBytes + calcArrayTableBytes(2)

            -- 3. Level 1, Index 1: Array of existing strings
            if type(v[1]) == "table" then
                -- Strings are pointers in the array slots, so we only count the array table itself
                totalBytes = totalBytes + calcArrayTableBytes(#v[1])
            end

            -- 4. Level 1, Index 2: Metadata table
            local meta = v[2]
            if type(meta) == "table" and not visitedTables[meta] then
                visitedTables[meta] = true

                -- Has 3 indices (1, 2, 3), so array part is rounded up to 4 slots (next power of 2)
                totalBytes = totalBytes + calcArrayTableBytes(3)

                -- 5. Meta, Index 2: Array of ints (of varying length)
                if type(meta[2]) == "table" then
                    totalBytes = totalBytes + calcArrayTableBytes(#meta[2])
                end
                -- Note: meta[1] (int) and meta[3] (float) are primitive values. 
                -- Their memory is already fully accounted for by the array slots in 'meta'.
            end
        end
    end

    -- 6. The root 'cache' table itself (hash part)
    -- We add the table header + the rounded-up hash nodes for the keys
    totalBytes = totalBytes + TABLE_BASE_BYTES
    if entryCount > 0 then
        totalBytes = totalBytes + nextPowerOfTwo(entryCount) * HASH_NODE_BYTES
    end

    return totalBytes
end

-- TODO: Recheck/adjust
