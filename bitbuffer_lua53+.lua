return
    function(a, b)
        return a & b
    end,
    function(a, b)
        return a | b
    end,
    function(a, b)
        return a << b
    end,
    function(a, b)
        return a >> b
    end,
    function(a)
        return ~a
    end
