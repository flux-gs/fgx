; M4: composite — JSR + JSL + JMP + RTL/RTS mix.
                MX      %00
                JSR     local
                JSL     $0B1234
                JMP     end
                CLC
local           RTS
end             RTL
