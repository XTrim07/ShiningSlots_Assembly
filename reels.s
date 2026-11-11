# reels.s - game state for 5 reels x 3 rows (like board.s in Tetris)
# the board is a 15-byte array: row*5+col, value 0-6 = symbol
# simplified Shining Crown rules: 10 fixed lines, payout from left to right
# bet levels: 10/20/40/80/100/150/250 with win chances 30/35/40/45/50/55/60

.bss
.global grid, winmask, credit, bet, win, spinning, spin_start, reel_stop, frame
.global bet_idx
grid:      .space 15    # current 5x3 symbols
winmask:   .space 15    # 1 = winning cell (golden border)
credit:    .space 8
bet:       .space 8     # effective bet (from the table by bet_idx)
win:       .space 8
spinning:  .space 8     # 0 = stopped, 1 = spinning
spin_start:.space 8     # SDL_GetTicks tick when SPIN is pressed
reel_stop: .space 40    # 5 x quad: after how many ms reel i stops
frame:     .space 8     # frame number for scrolling
bet_idx:   .space 8     # bet level 0-6 (0=10 ... 6=250)

.data
fmt_stat: .asciz "Credit: %ld | Bet: %ld | Win: %ld | SPACE=spin 1-7/+/-=bet Q=iesire\n"
# bet levels + win chances (like lines/pays in paylines.s, index = bet_idx)
bet_levels: .quad 10, 20, 40, 80, 100, 150, 250
bet_rates:  .quad 30, 35, 40, 45, 50, 55, 60

.text
# rand7: -> %rax number 0-6 (like rand7 in board.s, using rand from C)
.global rand7
rand7:
    pushq %rbp
    movq %rsp, %rbp
    call rand                # result in %eax
    movl %eax, %ecx
    xorl %edx, %edx
    movl $7, %esi
    movl %ecx, %eax
    divl %esi                # remainder in %edx
    movq %rdx, %rax
    popq %rbp
    ret

# rand100: -> %rax number 0-99 (for the 35% win rate)
.global rand100
rand100:
    pushq %rbp
    movq %rsp, %rbp
    call rand
    movl %eax, %ecx
    xorl %edx, %edx
    movl $100, %esi
    movl %ecx, %eax
    divl %esi
    movq %rdx, %rax
    popq %rbp
    ret

# rand2: -> %rax 0 or 1 (for red/black gamble, generated randomly)
.global rand2
rand2:
    pushq %rbp
    movq %rsp, %rbp
    call rand
    movl %eax, %ecx
    xorl %edx, %edx
    movl $2, %esi
    movl %ecx, %eax
    divl %esi
    movq %rdx, %rax
    popq %rbp
    ret

# init_reels: credit 1000, bet 10 (level 0), random grid, reel stop times
.global init_reels
init_reels:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq $1000, %rax
    movq %rax, credit
    movq $0, %rax
    movq %rax, bet_idx        # level 0 = bet 10
    movq $10, %rax
    movq %rax, bet
    movq $0, %rax
    movq %rax, win
    movq %rax, spinning
    movq %rax, frame
    movq %rax, last_win       # initially the last win is 0
    # sequential stop times like the original: 1000,1500,2000,2500,3000 ms
    movq $1000, %rax
    movq %rax, reel_stop
    movq $1500, %rax
    movq %rax, reel_stop+8
    movq $2000, %rax
    movq %rax, reel_stop+16
    movq $2500, %rax
    movq %rax, reel_stop+24
    movq $3000, %rax
    movq %rax, reel_stop+32
    # fill the grid randomly
    movq $0, %rbx            # i = 0
ir_loop:
    cmpq $15, %rbx
    jge ir_done
    call rand7               # %rax = 0-6
    movq $grid, %rdx
    movb %al, (%rdx, %rbx, 1)
    incq %rbx
    jmp ir_loop
ir_done:
    # clear winmask
    movq $0, %rbx
ir_mloop:
    cmpq $15, %rbx
    jge ir_end
    movq $winmask, %rdx
    movb $0, (%rdx, %rbx, 1)
    incq %rbx
    jmp ir_mloop
ir_end:
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# bet_set_idx: %rdi = level 0-6 -> set bet from the table + message
# -> %rax = 1 if changed, 0 if idx invalid (like start_spin: 1 ok / 0 no)
.global bet_set_idx
bet_set_idx:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    movq %rdi, %rbx            # requested idx
    cmpq $0, %rbx
    jl bs_no                  # below 0, reject
    cmpq $6, %rbx
    jg bs_no                  # above 6, reject
    movq %rbx, bet_idx
    movq $bet_levels, %rax
    movq (%rax, %rbx, 8), %rax  # bet from the table
    movq %rax, bet
    movq %rax, %r12             # save bet for printf (rsi gets lost? no, but cleaner style)
    movq $fmt_bet, %rdi
    movq %r12, %rsi
    movq credit, %rdx
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp bs_end
bs_no:
    movq $0, %rax
bs_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# bet_next: next level with wrap 6->0 (for the + key)
.global bet_next
bet_next:
    pushq %rbp
    movq %rsp, %rbp
    movq bet_idx, %rax
    incq %rax
    cmpq $7, %rax
    jl bn_go                  # 0-6, fine
    movq $0, %rax             # wrap to level 0 (bet 10)
bn_go:
    movq %rax, %rdi
    call bet_set_idx
    popq %rbp
    ret

# bet_prev: previous level with wrap 0->6 (for the - key)
.global bet_prev
bet_prev:
    pushq %rbp
    movq %rsp, %rbp
    movq bet_idx, %rax
    cmpq $0, %rax
    jne bp_dec                # >0, decrement normally
    movq $6, %rax             # wrap to level 6 (bet 250)
    jmp bp_go
bp_dec:
    decq %rax
bp_go:
    movq %rax, %rdi
    call bet_set_idx
    popq %rbp
    ret

# start_spin: subtract bet from credit, pick final random symbols, start the animation
# -> %rax = 1 if started, 0 if not enough credit / already spinning
.global start_spin
start_spin:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq spinning, %rax
    cmpq $1, %rax
    je ss_no                 # already spinning, ignore
    movq gamble_active, %rax
    cmpq $0, %rax
    jne ss_no                # offer (1) or gamble (2): first G/DOUBLE or arrows/C, you cannot spin directly
    movq credit, %rax
    movq bet, %rdx
    cmpq %rdx, %rax
    jl ss_no                 # no credit
    subq %rdx, %rax
    movq %rax, credit
    movq $0, %rax
    movq %rax, win
    movq %rax, confetti_until # stop old confetti on a new roll (0 = expired)
    # clear winmask
    movq $0, %rbx
ss_mloop:
    cmpq $15, %rbx
    jge ss_grid
    movq $winmask, %rdx
    movb $0, (%rdx, %rbx, 1)
    incq %rbx
    jmp ss_mloop
ss_grid:
    # draw the final symbols (visible after stopping)
    movq $0, %rbx
ss_gloop:
    cmpq $15, %rbx
    jge ss_time
    call rand7
    movq $grid, %rdx
    movb %al, (%rdx, %rbx, 1)
    incq %rbx
    jmp ss_gloop
ss_time:
    call SDL_GetTicks        # %eax = ms
    movq %rax, spin_start
    movq $0, %rax
    movq %rax, frame
    movq $1, %rax
    movq %rax, spinning
    movq $1, %rax            # 1 = started
    jmp ss_end
ss_no:
    movq $0, %rax
ss_end:
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# print_stat: print credit/bet/win to the console (like fmt_stats in display.s)
.global print_stat
print_stat:
    pushq %rbp
    movq %rsp, %rbp
    movq $fmt_stat, %rdi
    movq credit, %rsi
    movq bet, %rdx
    movq win, %rcx
    movq $0, %rax
    call printf
    popq %rbp
    ret
