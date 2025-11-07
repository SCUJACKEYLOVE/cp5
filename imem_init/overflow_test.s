nop

addi $1, $0, 65535         # r1 = 0x0000_FFFF
sll  $2, $1, 15            # r2 = 0x7FFF_8000
addi $1, $2, 32767         # r1 = 0x7FFF_FFFF

addi $4, $0, 1             # r4 = 1
sll  $7, $4, 31            # r7 = 0x8000_0000

add  $10, $1, $4           # Expect r10 remains 0, r30 = 1
addi $11, $1, 1            # Expect r11 remains 0, r30 = 2
sub  $12, $7, $4           # Expect r12 remains 0, r30 = 3
add  $13, $4, $4           # r13 = 2, r30 clear to 0
