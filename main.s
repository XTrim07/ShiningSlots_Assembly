# main.s - 5x3 slot machine game, Shining Crown style, in assembly (x86-64, GAS)
# style like wow/main.s (Tetris): includes files, srand(time(0)), game loop
# Build (inside the Slots folder):
#   gcc -no-pie -o slots main.s -lSDL2
# Run (requires WSLg for the window):
#   ./slots
#
# Controls: SPACE/click SPIN = spin, 1-7/click bet/+/- = bet (10/20/40/80/100/150/250), Q/ESC/X = quit
# Offer after a win (SPIN stays + DOUBLE on its right): G/Enter/click DOUBLE = gamble, SPACE/click SPIN = keep playing
# Gamble (RED on the left + BLACK on the right + TAKE WIN): left arrow=red, right arrow=black (alias R/N), SPACE/C/Enter=collect
# Registers: %rbx, %r12-%r15 are preserved by functions (callee saved),
# the rest may be lost on call (caller saved). Stack aligned to 16B.

.global main

.include "symbols.s"
.include "video.s"
.include "reels.s"
.include "paylines.s"
.include "gamble.s"
.include "anim.s"
.include "input.s"

.data
fmt_hello: .asciz "\n=== SHINING SLOTS (assembly + SDL2) ===\nCredit initial 1000. Trepte bet 10/20/40/80/100/150/250 (sansa 30-60%%).\nSPACE/click SPIN=spin, 1-7/click bet/+/-=miza, Q=iesire\nDupa castig: SPIN ramane + DOUBLE in dreapta (G/Enter/click DOUBLE=dublaj, SPACE/SPIN=joci mai departe)\nDUBLAJ: sageata stanga=ROSU dreapta=NEGRU (sau R/N), SPACE/C/Enter/TAKE WIN=colecteaza\n"

.text
main:
    # prologue (as in wow/main.s)
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp             # align stack to 16 bytes

    # startup message in the console
    movq $fmt_hello, %rdi
    movq $0, %rax
    call printf

    # seed for rand(): srand(time(0))
    movq $0, %rdi
    movq $0, %rax
    call time
    movq %rax, %rdi
    movq $0, %rax
    call srand

    # init game: reels + video (separate window)
    call init_reels
    call init_video
    cmpq $0, %rax
    je game_loop              # 0 = ok
    # video error, exit with code 1
    movq $1, %rax
    jmp game_exit

game_loop:
    call poll_input           # key/click in %rax: 2=quit
    cmpq $2, %rax
    je game_over
    call update_anim          # stop reels + evaluate win
    call draw_screen          # draw grid + button + title
    # 16ms pause = ~60fps (smooth animation like the original)
    movq $16, %rdi
    call SDL_Delay
    jmp game_loop

game_over:
    call print_stat
    call print_rate               # win rate statistics (target 35%)
    call cleanup              # destroy textures + window

game_exit:
    # epilogue
    addq $8, %rsp
    popq %rbx
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
