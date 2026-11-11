# symbols.s - 5x3 Shining Crown style slot symbols + gamble cards + buttons + text
# 33 textures, ids 0-32, like PIECES in Tetris (board.py -> pieces.s)
# each id has a BMP in assets/ + a name + a payout
# 0=coroana 1=pepene 2=pruna 3=portocala 4=banana 5=cirese 6=stea
# 7=red (red heart, gamble) 8=black (black heart, gamble)
# 9=spin (SPIN button 200x60) 10=double (DOUBLE button 200x60) 11=collect (TAKE WIN 300x40)
# 12-18=bets (84x32 buttons: 10,20,40,80,100,150,250)
# 19=credit (CREDITS text) 20=bet_lbl (BET text) 21-30=digits 0-9 31=win_lbl (WIN text) 32=nocash (NOT ENOUGH CREDITS text)

.data
# BMP file paths (external, generated with gen_simboluri.py)
p_coroana:   .asciz "assets/coroana.bmp"
p_pepene:    .asciz "assets/pepene.bmp"
p_pruna:     .asciz "assets/pruna.bmp"
p_portocala: .asciz "assets/portocala.bmp"
p_banana:    .asciz "assets/banana.bmp"
p_cirese:    .asciz "assets/cirese.bmp"
p_stea:      .asciz "assets/stea.bmp"
p_rosu:      .asciz "assets/rosu.bmp"
p_negru:     .asciz "assets/negru.bmp"
p_spin:      .asciz "assets/spin.bmp"
p_double:    .asciz "assets/double.bmp"
p_collect:   .asciz "assets/collect.bmp"
p_bet10:     .asciz "assets/bet10.bmp"
p_bet20:     .asciz "assets/bet20.bmp"
p_bet40:     .asciz "assets/bet40.bmp"
p_bet80:     .asciz "assets/bet80.bmp"
p_bet100:    .asciz "assets/bet100.bmp"
p_bet150:    .asciz "assets/bet150.bmp"
p_bet250:    .asciz "assets/bet250.bmp"
p_credit:    .asciz "assets/credit.bmp"
p_betlbl:    .asciz "assets/bet_lbl.bmp"
p_d0:        .asciz "assets/digit0.bmp"
p_d1:        .asciz "assets/digit1.bmp"
p_d2:        .asciz "assets/digit2.bmp"
p_d3:        .asciz "assets/digit3.bmp"
p_d4:        .asciz "assets/digit4.bmp"
p_d5:        .asciz "assets/digit5.bmp"
p_d6:        .asciz "assets/digit6.bmp"
p_d7:        .asciz "assets/digit7.bmp"
p_d8:        .asciz "assets/digit8.bmp"
p_d9:        .asciz "assets/digit9.bmp"
p_winlbl:    .asciz "assets/win_lbl.bmp"
p_nocash:    .asciz "assets/nocash.bmp"

# array of path pointers, index = symbol id
# used like piece_names in display.s
paths: .quad p_coroana, p_pepene, p_pruna, p_portocala, p_banana, p_cirese, p_stea, p_rosu, p_negru, p_spin, p_double, p_collect, p_bet10, p_bet20, p_bet40, p_bet80, p_bet100, p_bet150, p_bet250, p_credit, p_betlbl, p_d0, p_d1, p_d2, p_d3, p_d4, p_d5, p_d6, p_d7, p_d8, p_d9, p_winlbl, p_nocash

# short names for display in the title / console
n_coroana:   .asciz "COROANA"
n_pepene:    .asciz "PEPENE"
n_pruna:     .asciz "PRUNA"
n_portocala: .asciz "PORTOCALA"
n_banana:    .asciz "BANANA"
n_cirese:    .asciz "CIRESE"
n_stea:      .asciz "STEA"
n_rosu:      .asciz "ROSU"
n_negru:     .asciz "NEGRU"
n_spin:      .asciz "SPIN"
n_double:    .asciz "DOUBLE"
n_collect:   .asciz "TAKE WIN"
n_bet10:     .asciz "BET10"
n_bet20:     .asciz "BET20"
n_bet40:     .asciz "BET40"
n_bet80:     .asciz "BET80"
n_bet100:    .asciz "BET100"
n_bet150:    .asciz "BET150"
n_bet250:    .asciz "BET250"
n_credit:    .asciz "CREDITS"
n_betlbl:    .asciz "BET"
n_d0:        .asciz "0"
n_d1:        .asciz "1"
n_d2:        .asciz "2"
n_d3:        .asciz "3"
n_d4:        .asciz "4"
n_d5:        .asciz "5"
n_d6:        .asciz "6"
n_d7:        .asciz "7"
n_d8:        .asciz "8"
n_d9:        .asciz "9"
n_winlbl:    .asciz "WIN"
n_nocash:    .asciz "NOT ENOUGH CREDITS"
names: .quad n_coroana, n_pepene, n_pruna, n_portocala, n_banana, n_cirese, n_stea, n_rosu, n_negru, n_spin, n_double, n_collect, n_bet10, n_bet20, n_bet40, n_bet80, n_bet100, n_bet150, n_bet250, n_credit, n_betlbl, n_d0, n_d1, n_d2, n_d3, n_d4, n_d5, n_d6, n_d7, n_d8, n_d9, n_winlbl, n_nocash

.text
# sym_path: %rdi = id 0-32 -> %rax = pointer to the BMP path
.global sym_path
sym_path:
    movq $paths, %rax
    movq (%rax, %rdi, 8), %rax
    ret

# sym_name: %rdi = id 0-32 -> %rax = pointer to the name
.global sym_name
sym_name:
    movq $names, %rax
    movq (%rax, %rdi, 8), %rax
    ret
