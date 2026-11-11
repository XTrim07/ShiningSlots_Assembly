# input.s - read keys/clicks with SDL_PollEvent (like input.s in Tetris with scanf)
# normal game (0): SPACE/click SPIN = spin, 1-7/click bet = bet, +/- = level up/down
# offer after a win (1): SPIN stays + DOUBLE on its right
#   G/Enter/click DOUBLE = enter gamble, SPACE/click SPIN = money to balance + new spin
# gamble (2): RED on the left + BLACK on the right + TAKE WIN
#   left arrow=red, right arrow=black (alias R/N), SPACE/C/Enter/click TAKE WIN=collect
#   any other key/click = nothing (ignored)
# Q or X window = quit (always works)
# -> %rax = 2 quit, 1 action, 0 nothing

.data
fmt_bet: .asciz "Bet nou: %ld (credit %ld)\n"
fmt_nocash: .asciz "Nu ai credit! Apasa Q.\n"

.text
.global poll_input
poll_input:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    movq $0, %r12                # default result 0
pi_loop:
    # SDL_PollEvent(&evbuf) -> %eax 1 if there is an event
    movq $evbuf, %rdi
    call SDL_PollEvent
    cmpq $0, %rax
    je pi_end                     # empty queue, exit
    movq $evbuf, %rax
    movl (%rax), %ebx             # type
    cmpl $256, %ebx               # SDL_QUIT = 0x100
    je pi_quit
    cmpl $768, %ebx               # SDL_KEYDOWN = 0x300
    je pi_key
    cmpl $1025, %ebx              # SDL_MOUSEBUTTONDOWN = 0x401
    je pi_click
    jmp pi_loop                   # other event, move on
pi_quit:
    movq $2, %r12
    jmp pi_end
pi_key:
    movq $evbuf, %rax
    movl 20(%rax), %ebx           # keysym.sym
    cmpl $113, %ebx               # 'q' = quit (works in offer/gamble too)
    je pi_quit
    cmpl $81, %ebx                # uppercase 'Q' = quit
    je pi_quit
    cmpl $27, %ebx                # ESC = quit
    je pi_quit
    # offer (1) and gamble (2) have their own keys, the normal game has others
    movq gamble_active, %rax
    cmpq $2, %rax
    je pi_gamble_key              # in gamble: only arrows/R/N/C/SPACE/Enter
    cmpq $1, %rax
    je pi_offer_key               # in offer: only G/Enter/SPACE
    cmpl $32, %ebx                # SPACE = spin
    je pi_spin
    cmpl $49, %ebx                # '1'-'7' = direct bet level
    jl pi_bet_plus
    cmpl $55, %ebx
    jle pi_bet_digit
pi_bet_plus:
    cmpl $43, %ebx                # '+' = next level
    je pi_bet_up
    cmpl $61, %ebx                # '=' (+ key without shift) = next level
    je pi_bet_up
    cmpl $45, %ebx                # '-' = previous level
    je pi_bet_down
    jmp pi_loop
pi_bet_digit:
    # key 1-7: idx = sym - 49 (only when idle, like +/-)
    movq spinning, %rax
    cmpq $1, %rax
    je pi_loop                    # do not change the bet while spinning
    movq gamble_active, %rax
    cmpq $0, %rax
    jne pi_loop                   # neither in offer (1) nor in gamble (2)
    movl %ebx, %eax
    subl $49, %eax                # idx 0-6
    movq %rax, %rdi
    call bet_set_idx
    movq $1, %r12
    jmp pi_loop
pi_click:
    # normal (0): check the bet bar first, otherwise spin as before
    # offer (1): click DOUBLE = gamble, click SPIN = collect+spin; gamble (2): card rects
    # SDL_MouseButtonEvent: x at +20, y at +24 (as above)
    movq gamble_active, %rax
    cmpq $2, %rax
    je pi_gamble_click
    cmpq $1, %rax
    je pi_offer_click
    jmp pi_bet_click              # idle: bet or spin
pi_offer_key:
    # offer: G=103/lowercase g, uppercase G=71, Enter=13 -> DOUBLE; SPACE=32 -> SPIN onward
    cmpl $103, %ebx               # lowercase 'g' = DOUBLE
    je pi_offer_double
    cmpl $71, %ebx                # uppercase 'G' = DOUBLE
    je pi_offer_double
    cmpl $13, %ebx                # Enter = DOUBLE
    je pi_offer_double
    cmpl $32, %ebx                # SPACE = add the money to the balance + new spin
    je pi_offer_spin
    jmp pi_loop                   # anything else = nothing
pi_offer_double:
    call gamble_enter
    movq $1, %r12
    jmp pi_loop
pi_offer_spin:
    call gamble_collect           # close the offer (the money is already in credit)
    jmp pi_spin_go                # then spin again (like normal SPACE)
pi_gamble_key:
    # gamble: left arrow=RED, right arrow=BLACK, alias R/N, collect SPACE/C/Enter
    cmpl $1073741904, %ebx        # SDLK_LEFT = RED (left)
    je pi_gamble_rosu
    cmpl $1073741903, %ebx        # SDLK_RIGHT = BLACK (right)
    je pi_gamble_negru
    cmpl $114, %ebx               # lowercase 'r' = red (alias)
    je pi_gamble_rosu
    cmpl $82, %ebx                # uppercase 'R' = red
    je pi_gamble_rosu
    cmpl $110, %ebx               # lowercase 'n' = black (alias)
    je pi_gamble_negru
    cmpl $78, %ebx                # uppercase 'N' = black
    je pi_gamble_negru
    cmpl $32, %ebx                # SPACE = collect (tired of gambling)
    je pi_gamble_collect
    cmpl $99, %ebx                # lowercase 'c' = collect
    je pi_gamble_collect
    cmpl $67, %ebx                # uppercase 'C' = collect
    je pi_gamble_collect
    cmpl $13, %ebx                # Enter = collect
    je pi_gamble_collect
    jmp pi_loop                   # anything else does nothing
pi_gamble_rosu:
    movq $1, %rdi                 # 1 = red
    call gamble_play
    movq $1, %r12
    jmp pi_loop
pi_gamble_negru:
    movq $0, %rdi                 # 0 = black
    call gamble_play
    movq $1, %r12
    jmp pi_loop
pi_gamble_collect:
    call gamble_collect
    movq $1, %r12
    jmp pi_loop
pi_offer_click:
    # click in offer: DOUBLE (632,520,200x60) = gamble, SPIN (412,520,200x60) = new spin
    movq $evbuf, %rax
    movl 20(%rax), %ebx           # click x
    movl 24(%rax), %ecx           # click y
    # in DOUBLE? x 632-832, y 520-580
    cmpl $632, %ebx
    jl poc_spin                    # x < 632 -> maybe SPIN
    cmpl $832, %ebx
    jg pi_loop                      # x > 832 -> nothing
    cmpl $520, %ecx
    jl pi_loop
    cmpl $580, %ecx
    jg pi_loop
    jmp pi_offer_double             # it is in DOUBLE
poc_spin:
    # in SPIN? x 412-612, y 520-580
    cmpl $412, %ebx
    jl pi_loop
    cmpl $612, %ebx
    jg pi_loop
    cmpl $520, %ecx
    jl pi_loop
    cmpl $580, %ecx
    jg pi_loop
    jmp pi_offer_spin               # it is in SPIN: collect + new spin
pi_gamble_click:
    # click in gamble on exact rects (otherwise nothing, like the keys)
    movq $evbuf, %rax
    movl 20(%rax), %ebx           # click x
    movl 24(%rax), %ecx           # click y
    # in RED? x 296-424, y 520-648 (left)
    cmpl $296, %ebx
    jl pgc_negru
    cmpl $424, %ebx
    jg pgc_negru
    cmpl $520, %ecx
    jl pgc_negru
    cmpl $648, %ecx
    jg pgc_negru
    jmp pi_gamble_rosu
pgc_negru:
    # in BLACK? x 600-728, y 520-648 (right)
    cmpl $600, %ebx
    jl pgc_collect
    cmpl $728, %ebx
    jg pgc_collect
    cmpl $520, %ecx
    jl pgc_collect
    cmpl $648, %ecx
    jg pgc_collect
    jmp pi_gamble_negru
pgc_collect:
    # in TAKE WIN? x 362-662, y 650-690
    cmpl $362, %ebx
    jl pi_loop                    # outside -> nothing
    cmpl $662, %ebx
    jg pi_loop
    cmpl $650, %ecx
    jl pi_loop
    cmpl $690, %ecx
    jg pi_loop
    jmp pi_gamble_collect
pi_bet_up:
    movq spinning, %rax
    cmpq $1, %rax
    je pi_loop                    # do not change the bet while spinning
    movq gamble_active, %rax
    cmpq $0, %rax
    jne pi_loop                   # neither in offer (1) nor in gamble (2)
    call bet_next                 # next level with wrap 6->0 + message
    movq $1, %r12
    jmp pi_loop
pi_bet_down:
    movq spinning, %rax
    cmpq $1, %rax
    je pi_loop
    movq gamble_active, %rax
    cmpq $0, %rax
    jne pi_loop                   # neither in offer (1) nor in gamble (2)
    call bet_prev                 # previous level with wrap 0->6 + message
    movq $1, %r12
    jmp pi_loop
pi_bet_click:
    # strict click: bet bar (194+i*92,592,84x32) = set level, SPIN (412,520,200x60) = spin
    # anywhere else = nothing (only SPACE or SPIN spins, not the edges/screen border)
    movq $evbuf, %rax
    movl 20(%rax), %ebx           # click x
    movl 24(%rax), %ecx           # click y
    cmpl $592, %ecx
    jl pbc_spin                   # above the bar -> maybe SPIN
    cmpl $624, %ecx
    jge pi_loop                   # below the bar -> nothing
    movl %ebx, %eax
    subl $194, %eax               # x - 194
    cmpl $636, %eax               # total width 194-830 (unsigned, also catches x<194)
    jae pi_loop                   # outside the bar -> nothing
    xorl %edx, %edx
    movl $92, %esi
    divl %esi                     # eax = i 0-6, edx = offset within the 92 cell
    cmpl $84, %edx
    jae pi_loop                   # in the gap between buttons -> nothing
    movq spinning, %rax
    cmpq $1, %rax
    je pi_loop                    # spinning, ignore (not an error)
    movq gamble_active, %rax
    cmpq $0, %rax
    jne pi_loop                   # offer/gamble, ignore
    movl %ebx, %eax               # x is intact in ebx, compute i again
    subl $194, %eax
    xorl %edx, %edx
    movl $92, %esi
    divl %esi                     # eax = i 0-6
    movq %rax, %rdi
    call bet_set_idx
    movq $1, %r12
    jmp pi_loop
pbc_spin:
    # in the SPIN button? x 412-612, y 520-580 (only inside spins, not the edge)
    cmpl $412, %ebx
    jl pi_loop                    # outside -> nothing
    cmpl $612, %ebx
    jg pi_loop
    cmpl $520, %ecx
    jl pi_loop
    cmpl $580, %ecx
    jg pi_loop
    jmp pi_spin                   # it is in SPIN: checks + spin
pi_spin:
    # in gamble (2) you cannot spin: first arrows/R/N/C; in offer (1) collect+spin
    movq gamble_active, %rax
    cmpq $2, %rax
    je pi_spin_block
    cmpq $1, %rax
    je pi_offer_spin             # SPACE during offer = money to balance + new spin
    jmp pi_spin_go
pi_spin_block:
    movq $fmt_gamble_block, %rdi
    movq $0, %rax
    call printf
    jmp pi_loop
pi_spin_go:
    call start_spin               # subtract bet, draw final grid
    cmpq $1, %rax
    jne pi_nocash
    call arm_reels                # all 5 reels live
    movq $1, %r12
    jmp pi_loop
pi_nocash:
    movq spinning, %rax
    cmpq $1, %rax
    je pi_loop                    # already spinning, not an error
    movq $fmt_nocash, %rdi
    movq $0, %rax
    call printf
    call show_nocash              # light up NOT ENOUGH CREDITS at the top for 2 seconds
    jmp pi_loop
pi_end:
    movq %r12, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret
