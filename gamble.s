# gamble.s - 35% win rate + DOUBLE offer + red/black gamble + confetti
# after a win you do NOT enter gamble automatically (like Shining Crown with the GAMBLE button):
# offer (1): SPIN at 412,520 + DOUBLE at 632,520; SPACE=spin onward, G/Enter=gamble
# gamble (2): RED on the left + BLACK on the right + TAKE WIN; left arrow=red, right arrow=black
# the real card is random (rand2), you double or lose everything; on a loss you return straight to the main screen
# C/SPACE/Enter = collect. on a win a livelier confetti animation appears.

.bss
.global gamble_active, gamble_amount, gamble_result, gamble_show_until
.global confetti_until, spins_count, wins_count, last_win, nocash_until
gamble_active:     .space 8   # 0 = idle, 1 = offer (SPIN+DOUBLE), 2 = in gamble (RED/BLACK)
gamble_amount:     .space 8   # amount at stake (current win)
gamble_result:     .space 8   # 0 = black, 1 = red, 2 = nothing to show
gamble_show_until: .space 8   # until when we show the border on the real card
confetti_until:    .space 8   # until when we draw confetti (tick ms)
spins_count:       .space 8   # total spins (for the rate statistics)
wins_count:        .space 8   # winning spins
last_win:          .space 8   # last win (persists after losing spins, starts at 0)
nocash_until:      .space 8   # until when we show NOT ENOUGH CREDITS at the top (tick ms)
numbuf:           .space 20  # digits of the live number (units first, max 20 digits)

.data
fmt_gamble_offer:   .asciz "\n*** CASTIG %ld! (bet %ld, sansa %ld%%) Apasa DOUBLE (G/Enter/click) ca sa intri in dublaj sau SPACE/click SPIN ca sa joci mai departe ***\n"
fmt_gamble_enter:   .asciz "Ai intrat in DUBLAJ cu %ld! Sageata stanga=ROSU, dreapta=NEGRU (sau R/N), SPACE/C=colecteaza.\n"
fmt_gamble_win:     .asciz "DUBLAJ: cartea e %s! Bine: %ld -> %ld (sageti/R/N=continui, SPACE/C=colectezi)\n"
fmt_gamble_lose:    .asciz "DUBLAJ: cartea e %s! Ai pierdut %ld. Iesi pe principal, bafta mai departe.\n"
fmt_gamble_collect: .asciz "Ai colectat %ld. Credit: %ld\n"
fmt_gamble_block:   .asciz "Esti in dublaj! Sageata stanga=ROSU dreapta=NEGRU, SPACE/C=colecteaza.\n"
fmt_offer_block:    .asciz "Ai castig! G/DOUBLE=dublaj, SPACE/SPIN=joci mai departe.\n"
fmt_rate:           .asciz "Statistica: %ld spinuri, %ld castiguri (rata %ld%%, tinta 30-60%% dupa miza)\n"

.text
# resolve_spin: called when the reels have stopped; applies the rate for the bet, evaluates,
# starts the offer + confetti on a win (instead of calling eval_win directly)
# the rate comes from bet_rates[bet_idx]: 10->30% ... 250->60% (higher bet = more frequent + bigger wins)
.global resolve_spin
resolve_spin:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    call rand100              # %rax = 0-99
    movq $bet_rates, %rdx
    movq bet_idx, %rcx
    movq (%rdx, %rcx, 8), %rdx  # rate of the current level (30-60)
    cmpq %rdx, %rax
    jl rs_force_win           # below the rate -> guarantee a win
    # --- otherwise -> guarantee a loss (reshuffle until there is no line) ---
    movq $40, %rbx            # attempts
rs_lotry:
    call has_win
    cmpq $0, %rax
    je rs_eval                # already no win, fine
    # replace a random cell (idx 0-14) with a random symbol
    call rand
    movl %eax, %ecx
    xorl %edx, %edx
    movl $15, %esi
    movl %ecx, %eax
    divl %esi                 # %edx = idx 0-14
    movq %rdx, %r12           # saved idx (r12 survives rand7)
    call rand7                # %rax = symbol 0-6
    movq $grid, %rdx
    movb %al, (%rdx, %r12, 1)
    decq %rbx
    cmpq $0, %rbx
    jg rs_lotry
    jmp rs_eval
rs_force_win:
    # --- guarantee a win: if there is no line, put 3 identical symbols on the middle line ---
    call has_win
    cmpq $1, %rax
    je rs_eval                # already a natural win, keep it
    call rand7                # %rax = symbol
    movq %rax, %rbx
    movq $grid, %rax
    movb %bl, 5(%rax)         # row 1 (l1): reels 0,1,2
    movb %bl, 6(%rax)
    movb %bl, 7(%rax)
rs_eval:
    call eval_win             # %rax = total win (adds to win+credit)
    movq %rax, %r12           # saved total
    movq spins_count, %rax
    incq %rax
    movq %rax, spins_count
    cmpq $0, %r12
    je rs_end                 # no win, done
    movq wins_count, %rax
    incq %rax
    movq %rax, wins_count
    # gamble offer (only on a win!): SPIN stays, DOUBLE appears on its right
    movq %r12, gamble_amount
    movq %r12, last_win       # last win = current win (persists after dry spins)
    movq $1, %rax
    movq %rax, gamble_active
    movq $2, %rax
    movq %rax, gamble_result  # nothing to show yet
    movq $bet_rates, %rax
    movq bet_idx, %rcx
    movq (%rax, %rcx, 8), %rcx  # rate of the current level for the message
    movq $fmt_gamble_offer, %rdi
    movq %r12, %rsi           # the win
    movq bet, %rdx            # bet
    movq $0, %rax
    call printf
    movq $3500, %rdi          # confetti for 3.5 seconds on a win (livelier, like Shining)
    call start_confetti
rs_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# gamble_enter: enter from the offer (1) into gamble (2) with the DOUBLE button (G/Enter/click)
# -> %rax = 1 if entered, 0 if there was no offer
.global gamble_enter
gamble_enter:
    pushq %rbp
    movq %rsp, %rbp
    movq gamble_active, %rax
    cmpq $1, %rax
    jne ge_no                 # only enter from the offer
    movq $2, %rax
    movq %rax, gamble_active
    movq $fmt_gamble_enter, %rdi
    movq gamble_amount, %rsi
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp ge_end
ge_no:
    movq $0, %rax
ge_end:
    popq %rbp
    ret

# gamble_play: %rdi = choice (0 = black, 1 = red)
# works ONLY in gamble (2); the real card is generated randomly with rand2; double or nothing
# on a loss you return straight to the main screen (gamble_active=0), on a win you stay in gamble (2)
# -> %rax = 1 if played, 0 if gamble was not active
.global gamble_play
gamble_play:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    # 5 pushes = aligned, no sub
    movq %rdi, %rbx           # player's choice
    movq gamble_active, %rax
    cmpq $2, %rax
    jne gp_no                 # play only in gamble (2), nothing in the offer (1)
    movq gamble_amount, %r14  # old amount
    call rand2                # %rax = real card: 0 black / 1 red
    movq %rax, %r13           # saved result
    movq %rax, gamble_result
    call SDL_GetTicks
    addq $1500, %rax          # show the card for 1.5 seconds
    movq %rax, gamble_show_until
    cmpq %rbx, %r13
    je gp_win                 # choice == real => double
    # --- you lost everything: return straight to the main screen, play with the remaining balance ---
    movq credit, %rax
    subq %r14, %rax
    movq %rax, credit
    movq $0, %rax
    movq %rax, win
    movq %rax, gamble_active
    movq %rax, confetti_until # stop confetti on a loss (0 = expired)
    # real card name: 1 => id 7 red, 0 => id 8 black
    cmpq $1, %r13
    je gp_lose_rosu
    movq $8, %rdi
    jmp gp_lose_nm
gp_lose_rosu:
    movq $7, %rdi
gp_lose_nm:
    call sym_name
    movq %rax, %rsi
    movq $fmt_gamble_lose, %rdi
    movq %r14, %rdx
    movq $0, %rax
    call printf
    call print_stat
    movq $1, %rax             # played
    jmp gp_end
gp_win:
    # --- double: win += old amount, credit += old amount (no confetti, only on a spin) ---
    movq win, %rax
    addq %r14, %rax
    movq %rax, win
    movq %rax, gamble_amount  # new amount to double further
    movq %rax, last_win      # last win grows with the doubling
    movq credit, %rax
    addq %r14, %rax
    movq %rax, credit
    # real card name for the message
    cmpq $1, %r13
    je gp_win_rosu
    movq $8, %rdi
    jmp gp_win_nm
gp_win_rosu:
    movq $7, %rdi
gp_win_nm:
    call sym_name
    movq %rax, %rsi
    movq $fmt_gamble_win, %rdi
    movq %r14, %rdx
    movq gamble_amount, %rcx
    movq $0, %rax
    call printf
    call print_stat
    movq $1, %rax
    jmp gp_end
gp_no:
    movq $0, %rax
gp_end:
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# gamble_collect: cash in the win, exit the offer (1) or gamble (2) to the main screen
# the money is already in credit from eval_win, here we just close the state + message
.global gamble_collect
gamble_collect:
    pushq %rbp
    movq %rsp, %rbp
    movq gamble_active, %rax
    cmpq $0, %rax
    je gc_end                 # already idle, nothing to collect
    movq $0, %rax
    movq %rax, gamble_active
    movq $fmt_gamble_collect, %rdi
    movq win, %rsi
    movq credit, %rdx
    movq $0, %rax
    call printf
gc_end:
    popq %rbp
    ret

# start_confetti: %rdi = duration in ms (starts the confetti rain)
.global start_confetti
start_confetti:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    movq %rdi, %rbx           # duration
    call SDL_GetTicks
    addq %rbx, %rax
    movq %rax, confetti_until
    popq %r12
    popq %rbx
    popq %rbp
    ret

# show_nocash: light up the NOT ENOUGH CREDITS message at the top for 2 seconds (when you cannot afford a spin)
.global show_nocash
show_nocash:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    call SDL_GetTicks
    addq $2000, %rax          # 2 seconds
    movq %rax, nocash_until
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_nocash: red NOT ENOUGH CREDITS text at the top center (only while lit)
# id 32 at (282,12,460x36), over the reels but under nothing (reels start at y=90)
.global draw_nocash
draw_nocash:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    call SDL_GetTicks
    movq nocash_until, %rdx
    cmpq %rdx, %rax
    jge dnc_end               # time expired, do not draw
    movq $32, %rdi
    movq $282, %rsi
    movq $12, %rdx
    movq $460, %rcx
    movq $36, %r8
    call draw_btn
dnc_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_confetti: 150 colored squares falling + swaying + blinking (like Shining)
# many golden ones, different sizes, horizontal sway, blink 1/9 (only on a win/double)
# movement is based on ticks/16 (ct), not frames: it flows smoothly even when the reels are stopped
.global draw_confetti
draw_confetti:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp             # 6 pushes = even, need a sub 8
    call SDL_GetTicks
    movq confetti_until, %rdx
    cmpq %rdx, %rax
    jge dc_end                # time expired, do not draw
    # ct = ticks / 16 (~60fps) for smooth movement even when the reels are stopped (frame freezes)
    movq $0, %rdx
    movq $16, %rcx
    divq %rcx                 # rax = ct
    movq %rax, %r15          # ct for movement (always advances, not only on a spin)
    movq $0, %r12             # i = 0
dc_loop:
    cmpq $150, %r12
    jge dc_end
    # blinking: skip 1 out of 9 (sparkle like Shining)
    # t = (ct + i*7) % 9, if 0 -> skip the piece
    movq %r15, %rax
    movq %r12, %rdx
    imulq $7, %rdx
    addq %rdx, %rax
    movq $0, %rdx
    movq $9, %rcx
    divq %rcx                 # rdx = remainder 0-8
    cmpq $0, %rdx
    je dc_next                # blinking, do not draw this piece now
    # q1 = 5 + (i % 3) (horizontal speed)
    movq %r12, %rax
    movq $0, %rdx
    movq $3, %rcx
    divq %rcx
    movq %rdx, %rcx
    addq $5, %rcx             # q1 in rcx
    # base x = (i*173 + ct*q1) % 1024
    movq %r12, %rax
    imulq $173, %rax
    movq %rax, %r10           # part 1 (r10 is caller saved, no call here)
    movq %r15, %rax
    imulq %rcx, %rax
    addq %r10, %rax
    movq $0, %rdx
    movq $1024, %rcx
    divq %rcx
    movq %rdx, %r13           # base x in r13
    # sway = ((ct*3 + i*11) % 40) - 20 (left-right sway like paper)
    movq %r15, %rax
    imulq $3, %rax
    movq %r12, %rdx
    imulq $11, %rdx
    addq %rdx, %rax
    movq $0, %rdx
    movq $40, %rcx
    divq %rcx                 # rdx = 0-39
    subq $20, %rdx            # rdx = -20..+19
    addq %rdx, %r13           # x = base + sway
    # keep x on screen 0-1023 (manual wrap)
    cmpq $0, %r13
    jge dc_x_hi
    addq $1024, %r13
    jmp dc_y
dc_x_hi:
    cmpq $1024, %r13
    jl dc_y
    subq $1024, %r13
dc_y:
    # q2 = 7 + (i % 4) (fall speed)
    movq %r12, %rax
    movq $0, %rdx
    movq $4, %rcx
    divq %rcx
    movq %rdx, %rcx
    addq $7, %rcx             # q2
    # y = (i*97 + ct*q2) % 700
    movq %r12, %rax
    imulq $97, %rax
    movq %rax, %r10
    movq %r15, %rax
    imulq %rcx, %rax
    addq %r10, %rax
    movq $0, %rdx
    movq $700, %rcx
    divq %rcx
    movq %rdx, %r14           # saved y
    # color = i % 7 (Shining palette: 2 golds + red + bright white)
    movq %r12, %rax
    movq $0, %rdx
    movq $7, %rcx
    divq %rcx                 # rdx = 0-6
    cmpq $0, %rdx
    je dc_gold
    cmpq $1, %rdx
    je dc_gold2
    cmpq $2, %rdx
    je dc_red
    cmpq $3, %rdx
    je dc_white
    cmpq $4, %rdx
    je dc_green
    cmpq $5, %rdx
    je dc_blue
    # pink
    movq $255, %rdi
    movq $80, %rsi
    movq $200, %rdx
    jmp dc_fill
dc_gold:                      # Shining gold
    movq $255, %rdi
    movq $215, %rsi
    movq $0, %rdx
    jmp dc_fill
dc_gold2:                     # light yellow (sparkle)
    movq $255, %rdi
    movq $235, %rsi
    movq $130, %rdx
    jmp dc_fill
dc_red:
    movq $255, %rdi
    movq $50, %rsi
    movq $50, %rdx
    jmp dc_fill
dc_white:                     # white for sparks
    movq $255, %rdi
    movq $255, %rsi
    movq $255, %rdx
    jmp dc_fill
dc_green:
    movq $50, %rdi
    movq $255, %rsi
    movq $100, %rdx
    jmp dc_fill
dc_blue:
    movq $80, %rdi
    movq $160, %rsi
    movq $255, %rdx
dc_fill:
    call set_color
    # variable size: w = 4 + (i%3)*2, h = 8 + (i%4)*3 (large/small pieces)
    movq %r12, %rax
    movq $0, %rdx
    movq $3, %rcx
    divq %rcx                 # rdx = i%3
    imulq $2, %rdx
    addq $4, %rdx             # w = 4/6/8
    movq %rdx, %r10           # w in r10 temporarily
    movq %r12, %rax
    movq $0, %rdx
    movq $4, %rcx
    divq %rcx                 # rdx = i%4
    imulq $3, %rdx
    addq $8, %rdx             # h = 8/11/14/17
    movq $rectbuf, %rax
    movl %r13d, (%rax)
    movl %r14d, 4(%rax)
    movl %r10d, 8(%rax)
    movl %edx, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderFillRect
dc_next:
    incq %r12
    jmp dc_loop
dc_end:
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_offer_buttons: SPIN stays + DOUBLE appears on its right (only during the offer)
# SPIN id 9 at (412,520,200x60), DOUBLE id 10 at (632,520,200x60)
.global draw_offer_buttons
draw_offer_buttons:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    # SPIN button (green with text)
    movq $9, %rdi
    movq $412, %rsi
    movq $520, %rdx
    movq $200, %rcx
    movq $60, %r8
    call draw_btn
    # DOUBLE button (purple with text, to the right of SPIN)
    movq $10, %rdi
    movq $632, %rsi
    movq $520, %rdx
    movq $200, %rcx
    movq $60, %r8
    call draw_btn
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_bet_bar: 7 bet buttons under SPIN, horizontal one by one (like Shining)
# bet[i] id 12+i at (194+i*92, 592, 84x32); the selected level has a thick golden border
.global draw_bet_bar
draw_bet_bar:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    movq $0, %rbx              # i = 0
db_loop:
    cmpq $7, %rbx
    jge db_end
    # id = 12 + i
    movq $12, %rdi
    addq %rbx, %rdi
    # x = 194 + i*92
    movq %rbx, %rax
    imulq $92, %rax
    addq $194, %rax
    movq %rax, %r12           # saved x (r12 survives the call)
    movq %rax, %rsi
    movq $592, %rdx
    movq $84, %rcx
    movq $32, %r8
    call draw_btn
    # thick golden border on the selected level (bet_idx == i)
    movq bet_idx, %rax
    cmpq %rbx, %rax
    jne db_next
    movq $255, %rdi
    movq $215, %rsi
    movq $0, %rdx
    call set_color
    movq $rectbuf, %rax
    movl %r12d, (%rax)
    movl $592, 4(%rax)
    movl $84, 8(%rax)
    movl $32, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
    movq $rectbuf, %rax
    movl %r12d, %ecx
    addl $3, %ecx
    movl %ecx, (%rax)
    movl $595, 4(%rax)
    movl $78, 8(%rax)
    movl $26, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
db_next:
    incq %rbx
    jmp db_loop
db_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_number: %rdi = value, %rsi = x, %rdx = y
# draw a decimal number with small BMP digits (id 21+digit, 16x22, step 18)
# for the live credits/bet/win below the CREDITS/BET/WIN texts (text only on the background, not buttons)
.global draw_number
draw_number:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp             # 6 pushes = even, need a sub 8
    movq %rdi, %rax            # the value
    movq %rsi, %r12            # x
    movq %rdx, %r13            # y
    movq $0, %r14              # number of digits
    cmpq $0, %rax
    jne dn_div
    movq $numbuf, %rbx
    movb $0, (%rbx)            # value 0 -> a single 0 digit
    movq $1, %r14
    jmp dn_draw
dn_div:
    cmpq $0, %rax
    je dn_draw                 # digits done
    cmpq $20, %r14
    jge dn_draw                # buffer safety (max 20 digits)
    movq $0, %rdx
    movq $10, %rcx
    divq %rcx                  # rax = quotient, rdx = digit
    movq $numbuf, %rbx
    movb %dl, (%rbx, %r14, 1)  # saved digit (units first)
    incq %r14
    jmp dn_div
dn_draw:
    movq %r14, %r15            # j = count (start from the most significant)
    movq $0, %rbx              # pos = x offset
dn_cell:
    cmpq $0, %r15
    je dn_end                  # all digits done
    decq %r15                  # j--
    movq $numbuf, %rax
    movzbq (%rax, %r15, 1), %rdi  # digit
    addq $21, %rdi             # digit texture id (21+digit)
    movq %r12, %rsi
    addq %rbx, %rsi            # x + pos
    movq %r13, %rdx            # y
    movq $16, %rcx
    movq $22, %r8
    call draw_btn              # rbx/r12-r15 are callee saved, they survive
    addq $18, %rbx             # digit step
    jmp dn_cell
dn_end:
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_credit_panel: CREDITS/BET/WIN text + live numbers below them (text only on the background, not buttons)
# 3 small columns stuck to the left, so they do not touch the RED card (296,520) in gamble:
# CREDITS id 19 at (16,518,90x20) + live credits at (16,542)
# BET id 20 at (108,518,90x20) + live bet at (108,542)
# WIN id 31 at (200,518,90x20) + live last win at (200,542)
# stays during gamble (2) too, does not disappear (values are always visible in real time)
.global draw_credit_panel
draw_credit_panel:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    movq $19, %rdi
    movq $16, %rsi
    movq $518, %rdx
    movq $90, %rcx
    movq $20, %r8
    call draw_btn
    movq $20, %rdi
    movq $108, %rsi
    movq $518, %rdx
    movq $90, %rcx
    movq $20, %r8
    call draw_btn
    movq $31, %rdi
    movq $200, %rsi
    movq $518, %rdx
    movq $90, %rcx
    movq $20, %r8
    call draw_btn
    movq credit, %rdi         # live credits below CREDITS
    movq $16, %rsi
    movq $542, %rdx
    call draw_number
    movq bet, %rdi            # live bet below BET
    movq $108, %rsi
    movq $542, %rdx
    call draw_number
    movq last_win, %rdi       # last win below WIN (persists after dry spins)
    movq $200, %rsi
    movq $542, %rdx
    call draw_number
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_gamble: 2 cards (red left + black right) + TAKE WIN button + border on the real card
.global draw_gamble
draw_gamble:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = aligned, no sub
    # red heart id 7 at (296,520), black heart id 8 at (600,520)
    movq $7, %rdi
    movq $296, %rsi
    movq $520, %rdx
    call draw_tex
    movq $8, %rdi
    movq $600, %rsi
    movq $520, %rdx
    call draw_tex
    # TAKE WIN button id 11 at (362,650,300x40) (collect when you are tired of gambling)
    movq $11, %rdi
    movq $362, %rsi
    movq $650, %rdx
    movq $300, %rcx
    movq $40, %r8
    call draw_btn
    # golden border on the real card (if it was just revealed)
    call SDL_GetTicks
    movq gamble_show_until, %rdx
    cmpq %rdx, %rax
    jge dg_end
    movq gamble_result, %rax
    cmpq $2, %rax
    je dg_end                 # nothing to show
    # x = 296 for red (1), 600 for black (0)
    cmpq $1, %rax
    je dg_x_rosu
    movq $600, %rbx
    jmp dg_border
dg_x_rosu:
    movq $296, %rbx
dg_border:
    movq %rbx, %r12           # saved x
    movq $255, %rdi
    movq $215, %rsi
    movq $0, %rdx
    call set_color
    movq $rectbuf, %rax
    movl %r12d, (%rax)
    movl $520, 4(%rax)
    movl $128, 8(%rax)
    movl $128, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
    # the second border blinks with the frame (sparkle like Shining)
    movq frame, %rax
    andq $1, %rax
    cmpq $1, %rax
    je dg_end                   # odd frame -> only one border (blink)
    movq $rectbuf, %rax
    movl %r12d, %ecx
    addl $3, %ecx
    movl %ecx, (%rax)
    movl $523, 4(%rax)
    movl $122, 8(%rax)
    movl $122, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
dg_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# print_rate: win rate statistics (spins vs wins)
.global print_rate
print_rate:
    pushq %rbp
    movq %rsp, %rbp
    movq spins_count, %rcx
    cmpq $0, %rcx
    je pr_zero
    movq wins_count, %rax
    imulq $100, %rax          # rax = wins * 100
    movq $0, %rdx
    divq %rcx                 # rax = rate %
    jmp pr_show
pr_zero:
    movq $0, %rax             # rate 0
pr_show:
    movq %rax, %r8            # percentage temporarily in r8
    movq $fmt_rate, %rdi
    movq spins_count, %rsi    # 1st %ld
    movq wins_count, %rdx     # 2nd %ld
    movq %r8, %rcx            # 3rd %ld is in rcx (not r8!)
    movq $0, %rax
    call printf
    popq %rbp
    ret
