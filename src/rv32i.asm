.data
    var0:      100
    res_auipc: 0x00020008
    res_lui:   0x00020000
    res_li:    0x00000194
    res_add:   350
    res_slt:   1
    res_xor:   158
    res_sll:   800
    res_srl:   12
    res_or:    254
    res_and:   96
    res_jal:   0x000000CA

# assembly code to validate entire rv32i
.text
    j     start
error:
    j     error

start:
    # add upper immediate to PC
    auipc t0, 0x20
    lw    t1, res_auipc
    bne   t0, t1, error

    # load upper immediate
    lui   t0, 0x20
    lw    t1, res_lui
    bne   t0, t1, error
    # TODO: asserts to ensure that the first instructions work

    # load and store words
    la    a0, var0
    lw    t0, 0(a0)
    sw    t0, 0(a0)
    lw    t1, 0(a0)
    bne   t0, t1, error
    # TODO: load and store half-words and bytes

    # add immediate
    addi  t0, x0, 0xCA
    addi  t0, t0, 0xCA
    lw    t1, res_li
    bne   t0, t1, error

    # initalize variables for next operations
    li    a0, 100
    li    a1, 250
    li    a2, 3

    # add
    add   t0, a0, a1
    lw    t1, res_add
    bne   t0, t1, error

    # set on less than
    slt   t0, a0, a1
    lw    t1, res_slt
    bne   t0, t1, error
    # TODO: sltu

    # exclusive-or
    xor   t0, a0, a1
    lw    t1, res_xor
    bne   t0, t1, error

    # shift left logical
    sll   t0, a0, a2
    lw    t1, res_sll
    bne   t0, t1, error

    # shift right logical
    srl   t0, a0, a2
    lw    t1, res_srl
    bne   t0, t1, error

    # shift right arithmetic
    sra   t0, a0, a2
    lw    t1, res_srl
    bne   t0, t1, error

    # or
    or    t0, a0, a1
    lw    t1, res_or
    bne   t0, t1, error

    # and
    and   t0, a0, a1
    lw    t1, res_and
    bne   t0, t1, error

    # jump and link
    jal   ra, jal_test
    lw    t1, res_jal
    bne   t0, t1, error
    j     jal_continue
jal_test:
    addi  t0, x0, 0xCA
    jalr  x0, ra, 0

jal_continue:

    # branch on equal
    # test: take branch
    li    t0, 0x100
    li    t1, 0x100
    beq   t0, t1, equal0
    j     error
equal0:
    # test: dont take branch
    li    t0, 0x100
    li    t1, 0x101
    beq   t0, t1, equal1
    j     beq_continue
equal1:
    j     error
beq_continue:

    # branch on not equal
    # test: take branch
    li    t0, 0x100
    li    t1, 0x101
    bne   t0, t1, not_equal0
    j     error
not_equal0:
    # test: dont take branch
    li    t0, 0x100
    li    t1, 0x100
    bne   t0, t1, not_equal1
    j     bne_continue
not_equal1:
    j     error
bne_continue:

    # branch on less than
    # test: take branch
    li    t0, -0x10
    li    t1,  0x10
    blt   t0, t1, less0
    j     error
less0:
    # test: dont take branch
    li    t0, 0x10
    li    t1, 0x10
    blt   t0, t1, less1
    j     blt_continue
less1:
    j     error
blt_continue:

    # branch on greater or equal
    # test: take branch
    li    t0, 0x10
    li    t1, 0x10
    bge   t0, t1, greater0
    j     error
greater0:
    # test: dont take branch
    li    t0, -0x10
    li    t1,  0x10
    bge   t0, t1, greater1
    j     bge_continue
greater1:
    j     error
bge_continue:

    # TODO: bltu, bgeu

success:
    j success
