# paylines.s - 10 fixed lines + paytable (like add_score in board.s)
# lines: 3 horizontal + 2 diagonal + 5 zigzag (5x3 layout like the original)
# payout for 3/4/5 identical from the left, multiplied by bet/10

.data
# each line = 5 bytes (the row on each reel 0-4)
l0: .byte 0,0,0,0,0
l1: .byte 1,1,1,1,1
l2: .byte 2,2,2,2,2
l3: .byte 0,1,2,1,0
l4: .byte 2,1,0,1,2
l5: .byte 0,0,1,0,0
l6: .byte 2,2,1,2,2
l7: .byte 1,0,0,0,1
l8: .byte 1,2,2,2,1
l9: .byte 1,0,1,2,1
lines: .quad l0,l1,l2,l3,l4,l5,l6,l7,l8,l9

# paytable[symbol][3/4/5] - base values (x bet/10)
#        3    4    5
pay0: .quad 100, 500, 2000   # crown
pay1: .quad 30, 100, 500     # melon
pay2: .quad 20, 80, 300      # plum
pay3: .quad 10, 40, 150      # orange
pay4: .quad 10, 40, 150      # banana
pay5: .quad 5, 20, 100       # cherries
pay6: .quad 50, 200, 1000    # star (small scatter)
pays: .quad pay0,pay1,pay2,pay3,pay4,pay5,pay6

fmt_win: .asciz "LINIE %ld: %s x%ld -> +%ld\n"

.text
# has_win: pure check whether any line has 3+ identical symbols (no side effects)
# -> %rax = 1 if it would win, 0 if not (for the 35% win rate)
.global has_win
has_win:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    # 5 pushes = aligned, no calls inside
    movq $0, %r12            # line 0-9
hw_line:
    cmpq $10, %r12
    jge hw_no
    movq $lines, %rax
    movq (%rax, %r12, 8), %rbx
    movzbq (%rbx), %rax
    imulq $5, %rax
    movq $grid, %rdx
    movzbq (%rdx, %rax, 1), %r13  # target symbol
    movq $1, %r14                   # count
hw_count:
    cmpq $5, %r14
    jge hw_pay
    movzbq (%rbx, %r14, 1), %rax
    imulq $5, %rax
    addq %r14, %rax
    movq $grid, %rdx
    movzbq (%rdx, %rax, 1), %rcx
    cmpq %r13, %rcx
    jne hw_pay
    incq %r14
    jmp hw_count
hw_pay:
    cmpq $3, %r14
    jge hw_yes
    incq %r12
    jmp hw_line
hw_yes:
    movq $1, %rax
    jmp hw_end
hw_no:
    movq $0, %rax
hw_end:
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# eval_win: compute the win over 10 lines, fill winmask, add to win+credit
# -> %rax = total win
.global eval_win
eval_win:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
    movq $0, %r12            # current line 0-9
    movq $0, %r15            # total win
ew_line:
    cmpq $10, %r12
    jge ew_done
    # line pointer
    movq $lines, %rax
    movq (%rax, %r12, 8), %rbx   # %rbx = address of the 5 bytes
    # symbol on reel 0
    movzbq (%rbx), %rax          # row for reel 0
    imulq $5, %rax               # rand*5 + 0
    movq $grid, %rdx
    movzbq (%rdx, %rax, 1), %r13 # %r13 = target symbol
    # count how many consecutive reels have the same symbol
    movq $1, %r14                # count = 1
ew_count:
    cmpq $5, %r14
    jge ew_pay
    movzbq (%rbx, %r14, 1), %rax # row for reel r14
    imulq $5, %rax
    addq %r14, %rax              # rand*5 + col
    movq $grid, %rdx
    movzbq (%rdx, %rax, 1), %rcx
    cmpq %r13, %rcx
    jne ew_pay
    incq %r14
    jmp ew_count
ew_pay:
    cmpq $3, %r14
    jl ew_next                   # below 3 = nothing
    # payout = pays[symbol][count-3] * bet / 10
    movq $pays, %rax
    movq (%rax, %r13, 8), %rax   # symbol pay pointer
    movq %r14, %rcx
    subq $3, %rcx
    movq (%rax, %rcx, 8), %rax   # base value
    movq bet, %rcx
    imulq %rcx, %rax
    movq $0, %rdx
    movq $10, %rcx
    divq %rcx                    # %rax = line payout
    addq %rax, %r15              # total += payout
    # mark the winning cells in winmask
    movq %rax, %r10              # save the payout (caller saved, but printf clobbers it -> the stack would be safer)
    pushq %r10
    pushq %r13
    pushq %r14
    movq %r14, %r13              # how many cells to mark
    movq $0, %rax                # i = 0
ew_mark:
    cmpq %r13, %rax
    jge ew_show
    movzbq (%rbx, %rax, 1), %rcx # row
    imulq $5, %rcx
    addq %rax, %rcx              # rand*5+col
    movq $winmask, %rdx
    movb $1, (%rdx, %rcx, 1)
    incq %rax
    jmp ew_mark
ew_show:
    popq %r14
    popq %r13
    popq %r10
    # print the line (like print_rle_loop in bitmap/main.s)
    pushq %r12
    pushq %r15
    pushq %rbx
    subq $8, %rsp                # 3 pushes = odd, realign for the call
    movq %r13, %rdi
    call sym_name
    movq %rax, %rdx              # symbol name
    movq $fmt_win, %rdi
    movq %r12, %rsi
    movq %r14, %rcx
    movq %r10, %r8
    movq $0, %rax
    call printf
    addq $8, %rsp
    popq %rbx
    popq %r15
    popq %r12
ew_next:
    incq %r12
    jmp ew_line
ew_done:
    # win += total, credit += total
    movq win, %rax
    addq %r15, %rax
    movq %rax, win
    movq credit, %rax
    addq %r15, %rax
    movq %rax, credit
    movq %r15, %rax
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
