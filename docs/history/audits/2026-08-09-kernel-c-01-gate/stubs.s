* Externs the gate subjects call.  RTS stubs: the gate measures the SUBJECTS,
* so these must contribute ~nothing and must not be mistaken for the callees'
* real cost.  Each is 1 byte; the report subtracts them.
balloc          RTL
bread           RTL
brelse          RTL
bwrite          RTL
bdwrite         RTL
u               DS 2
rablock         DS 4
vfreeh          DS 4
vfreet          DS 4
