# anim.s - spin animation like the original + screen drawing
# reels spin fast (vertical scroll), then stop sequentially
# left->right with deceleration, then highlight the winning lines

.bss
.global reel_live
reel_live: .space 5    # 1 = reel i is spinning, 0 = stopped
titlebuf:  .space 128  # window title with credit/bet/win

.data
fmt_title: .asciz "SHINING SLOTS | Credit: %ld | Bet: %ld | Win: %ld | SPACE=spin"
fmt_otitle: .asciz "WIN %ld! | SPIN=continui G/DOUBLE=dublaj | Credit %ld"
fmt_gtitle: .asciz "DUBLAJ win %ld! | Sageata stanga=ROSU dreapta=NEGRU SPACE=colecteaza | Credit %ld"
GX0: .quad 184
GY0: .quad 90
STEP: .quad 132
BTN_X: .quad 412
BTN_Y: .quad 520
BTN_W: .quad 200
BTN_H: .quad 60
DBL_X: .quad 632
DBL_Y: .quad 520
DBL_W: .quad 200
DBL_H: .quad 60
COL_X: .quad 362
COL_Y: .quad 650
COL_W: .quad 300
COL_H: .quad 40

.text
# update_anim: advance the frame, stop reels on time, evaluate at the end
.global update_anim
update_anim:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp
    movq spinning, %rax
    cmpq $1, %rax
    jne ua_end               # not spinning, done
    movq frame, %rax
    incq %rax
    movq %rax, frame
    call SDL_GetTicks        # %eax = current ms
    movq %rax, %rbx          # ticks
    movq spin_start, %rcx
    subq %rcx, %rbx          # %rbx = elapsed
    movq $0, %r12            # reel i
    movq $0, %r13            # how many reels are still spinning
ua_loop:
    cmpq $5, %r12
    jge ua_check
    movq $reel_stop, %rax
    movq (%rax, %r12, 8), %rax   # stop time for reel i
    cmpq %rax, %rbx
    jl ua_still                  # elapsed < stop => still spinning
    # reel stopped
    movq $reel_live, %rax
    movb $0, (%rax, %r12, 1)
    jmp ua_next
ua_still:
    movq $reel_live, %rax
    movb $1, (%rax, %r12, 1)
    incq %r13
ua_next:
    incq %r12
    jmp ua_loop
ua_check:
    cmpq $0, %r13
    jne ua_end                   # reels still spinning, wait
    # all stopped: spin finished
    movq $0, %rax
    movq %rax, spinning
    call resolve_spin            # 35% rate + eval + gamble/confetti on a win
    call print_stat
ua_end:
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# arm_reels: called on start_spin, sets all reels to "live"
.global arm_reels
arm_reels:
    movq $reel_live, %rax
    movb $1, 0(%rax)
    movb $1, 1(%rax)
    movb $1, 2(%rax)
    movb $1, 3(%rax)
    movb $1, 4(%rax)
    ret

# draw_screen: draw everything (grid + button + title), 60fps
.global draw_screen
draw_screen:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
    # dark purple background
    movq $30, %rdi
    movq $8, %rsi
    movq $50, %rdx
    call set_color
    movq renderer, %rdi
    call SDL_RenderClear
    # tick for the scroll offset
    call SDL_GetTicks
    movq %rax, %r15              # ticks (for animation)
    movq $0, %r12                # r = 0
ds_row:
    cmpq $3, %r12
    jge ds_button
    movq $0, %r13                # c = 0
ds_col:
    cmpq $5, %r13
    jge ds_next_row
    # x = 184 + c*132, y = 90 + r*132
    movq %r13, %rax
    imulq $132, %rax
    addq $184, %rax
    movq %rax, %r14              # x in r14
    movq %r12, %rax
    imulq $132, %rax
    addq $90, %rax
    movq %rax, %rbx              # y in rbx (callee saved, survives the call)
    # is the reel spinning?
    movq spinning, %rax
    cmpq $1, %rax
    jne ds_fixed
    movq $reel_live, %rax
    movb (%rax, %r13, 1), %al
    cmpb $1, %al
    jne ds_fixed
    # --- live reel: fast vertical scroll ---
    # off = (ticks/6 + c*37) % 132
    movq %r15, %rax
    movq $0, %rdx
    movq $6, %rcx
    divq %rcx                    # rax = ticks/6
    movq %r13, %rcx
    imulq $37, %rcx
    addq %rcx, %rax
    movq $0, %rdx
    movq $132, %rcx
    divq %rcx                    # rdx = off
    # pseudo symbols for blur: (frame + r*2 + c*3) % 7
    movq frame, %rax
    movq %r12, %rcx
    imulq $2, %rcx
    addq %rcx, %rax
    movq %r13, %rcx
    imulq $3, %rcx
    addq %rcx, %rax
    movq $0, %rcx
    # rax may be large, take mod 7
    pushq %rdx                   # save off
    movq $0, %rdx
    movq $7, %rcx
    divq %rcx                    # rdx = sim1
    movq %rdx, %r10              # sim1
    popq %rcx                    # off in rcx
    # y1 = y + off - 132 (the cell entering from the top)
    movq %rbx, %rax
    addq %rcx, %rax
    subq $132, %rax              # y1
    movq %r14, %rsi              # x
    movq %rax, %rdx              # y1
    movq %r10, %rdi              # sim1
    pushq %rcx
    pushq %r10
    call draw_tex
    popq %r10
    popq %rcx
    # second: y2 = y + off, sim2 = (sim1+3)%7
    movq %r10, %rax
    addq $3, %rax
    movq $0, %rdx
    pushq %rcx
    movq $7, %rcx
    divq %rcx
    movq %rdx, %r10              # sim2
    popq %rcx
    movq %rbx, %rax
    addq %rcx, %rax              # y2 = y + off
    movq %r14, %rsi
    movq %rax, %rdx
    movq %r10, %rdi
    call draw_tex
    jmp ds_next_col
ds_fixed:
    # --- stopped reel: real symbol from the grid ---
    movq %r12, %rax
    imulq $5, %rax
    addq %r13, %rax              # idx = r*5+c
    movq $grid, %rdx
    movzbq (%rdx, %rax, 1), %rdi # sim
    pushq %rax                   # save idx (1 push -> +sub 8 to stay aligned)
    subq $8, %rsp
    movq %r14, %rsi              # x
    movq %rbx, %rdx              # y
    call draw_tex
    addq $8, %rsp
    popq %rax                    # idx
    # golden border if it is a winning cell
    movq $winmask, %rdx
    movzbq (%rdx, %rax, 1), %rdx
    cmpq $1, %rdx
    jne ds_next_col
    # border: 2 golden rectangles over the cell
    movq $255, %rdi
    movq $215, %rsi
    movq $0, %rdx
    call set_color
    movq $rectbuf, %rax
    movl %r14d, (%rax)
    movl %ebx, 4(%rax)
    movl $128, 8(%rax)
    movl $128, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
    movq $rectbuf, %rax
    movl %r14d, %ecx
    addl $3, %ecx
    movl %ecx, (%rax)
    movl %ebx, %ecx
    addl $3, %ecx
    movl %ecx, 4(%rax)
    movl $122, 8(%rax)
    movl $122, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
ds_next_col:
    incq %r13
    jmp ds_col
ds_next_row:
    incq %r12
    jmp ds_row
ds_button:
    # offer (1): SPIN stays + DOUBLE on its right; gamble (2): cards + TAKE WIN
    # the bet bar is visible in 0+1, hidden in gamble (2); the CREDIT/BET panel is always shown
    movq gamble_active, %rax
    cmpq $2, %rax
    je ds_gamble
    cmpq $1, %rax
    je ds_offer
    # idle (0): only the SPIN button with text (id 9 at 412,520,200x60)
    # green when idle, red when spinning (a tint over the BMP, like a filter)
    movq spinning, %rax
    cmpq $1, %rax
    je ds_btn_red
    movq $9, %rdi                # SPIN id
    movq $412, %rsi
    movq $520, %rdx
    movq $200, %rcx
    movq $60, %r8
    call draw_btn
    call draw_bet_bar            # 7 bet levels under SPIN (194+i*92,592,84x32)
    call draw_credit_panel       # CREDIT/BET labels to the left of SPIN
    jmp ds_title
ds_btn_red:
    # spinning: draw SPIN but with a red border (the button is a BMP, not a simple rect)
    movq $9, %rdi
    movq $412, %rsi
    movq $520, %rdx
    movq $200, %rcx
    movq $60, %r8
    call draw_btn
    # red border over the button while spinning
    movq $180, %rdi
    movq $40, %rsi
    movq $40, %rdx
    call set_color
    movq $rectbuf, %rax
    movl $412, (%rax)
    movl $520, 4(%rax)
    movl $200, 8(%rax)
    movl $60, 12(%rax)
    movq renderer, %rdi
    movq $rectbuf, %rsi
    call SDL_RenderDrawRect
    call draw_bet_bar
    call draw_credit_panel
    jmp ds_title
ds_offer:
    call draw_offer_buttons     # SPIN at 412,520 + DOUBLE at 632,520 (both with text)
    call draw_bet_bar
    call draw_credit_panel
    jmp ds_title
ds_gamble:
    call draw_gamble              # 2 cards: RED on the left + BLACK on the right + TAKE WIN
    call draw_credit_panel       # the panel stays, the bet bar is hidden during gamble
ds_title:
    # window title with the score (like fmt_stats in display.s)
    # 0 = credit/bet/win, 1 = WIN offer, 2 = gamble stake
    movq gamble_active, %rax
    cmpq $2, %rax
    je ds_gtitle
    cmpq $1, %rax
    je ds_otitle
    movq $titlebuf, %rdi
    movq $fmt_title, %rsi
    movq credit, %rdx
    movq bet, %rcx
    movq win, %r8
    movq $0, %rax
    call sprintf
    jmp ds_present
ds_otitle:
    movq $titlebuf, %rdi
    movq $fmt_otitle, %rsi
    movq win, %rdx
    movq credit, %rcx
    movq $0, %rax
    call sprintf
    jmp ds_present
ds_gtitle:
    movq $titlebuf, %rdi
    movq $fmt_gtitle, %rsi
    movq win, %rdx
    movq credit, %rcx
    movq $0, %rax
    call sprintf
ds_present:
    movq window, %rdi
    movq $titlebuf, %rsi
    call SDL_SetWindowTitle
    call draw_confetti           # confetti rain everywhere (only on a winning spin)
    call draw_nocash             # NOT ENOUGH CREDITS at the top (only while lit, everywhere)
    # present everything (double-buffer)
    movq renderer, %rdi
    call SDL_RenderPresent
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
