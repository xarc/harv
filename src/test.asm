.data
    var0: 100
    var1: 200
    var3:
.text
    lw t0, var0
    lw t1, var1

    sub t2, t1, t0

    add t3, t1, t2
    add t3, t3, t3
    
    la t4, var3
    sw t3, 0(t4)
    lw t4, 0(t4)

end_loop:
    j end_loop
    
