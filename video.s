# video.s - separate SDL2 window (instead of graphics.h)
# Borland graphics.h does not exist on Ubuntu, so we use native SDL2:
# SDL_Init, SDL_CreateWindow, SDL_CreateRenderer, SDL_LoadBMP
# C calls from asm, just like printf/rand in your projects

.bss
.global window, renderer, textures, evbuf, rectbuf
window:   .space 8     # SDL_Window*
renderer: .space 8     # SDL_Renderer*
textures: .space 264   # 33 x SDL_Texture* (0-8 symbols/cards, 9-11 buttons, 12-18 bets, 19-32 text+digits)
evbuf:    .space 56    # SDL_Event (56 bytes)
rectbuf:  .space 16    # SDL_Rect {x,y,w,h}

.data
titlu:     .asciz "SHINING SLOTS - assembly + SDL2 (SPACE=spin Q=iesire)"
rb_mode:   .asciz "rb"
err_init:  .asciz "Eroare SDL_Init\n"
err_win:   .asciz "Eroare CreateWindow (porneste WSLg?)\n"
err_ren:   .asciz "Eroare CreateRenderer\n"
err_bmp:   .asciz "Eroare LoadBMP: %s\n"

.text
# init_video: opens a 1024x700 window + loads 33 BMPs
# -> %rax = 0 ok, 1 failure (like place_piece: 1 ok / 0 fail, here inverted for error)
.global init_video
init_video:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    # 3 pushes = stack aligned to 16 (no sub, since N is odd)

    # SDL_Init(VIDEO=0x20)
    movq $0x20, %rdi
    call SDL_Init
    cmpq $0, %rax
    je iv_win
    movq $err_init, %rdi
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp iv_end

iv_win:
    # SDL_CreateWindow(title, 100,100, 1024,700, SHOWN=4)
    movq $titlu, %rdi
    movq $100, %rsi
    movq $100, %rdx
    movq $1024, %rcx
    movq $700, %r8
    movq $4, %r9
    call SDL_CreateWindow
    cmpq $0, %rax
    jne iv_save_win
    movq $err_win, %rdi
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp iv_end

iv_save_win:
    movq %rax, window

    # SDL_CreateRenderer(window, -1, 0)
    movq window, %rdi
    movq $-1, %rsi
    movq $0, %rdx
    call SDL_CreateRenderer
    cmpq $0, %rax
    jne iv_save_ren
    movq $err_ren, %rdi
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp iv_end

iv_save_ren:
    movq %rax, renderer

    # load 33 textures from assets/ (9 symbols + 3 buttons + 7 bets + 4 texts + 10 digits)
    movq $0, %rbx              # id = 0
iv_loop:
    cmpq $33, %rbx
    jge iv_ok
    movq %rbx, %rdi
    call sym_path              # %rax = BMP path
    movq %rax, %r12            # keep the path (saved register)
    # SDL_LoadBMP is a macro in C; from asm we call RWFromFile + LoadBMP_RW
    movq %rax, %rdi
    movq $rb_mode, %rsi
    call SDL_RWFromFile        # %rax = RW*
    cmpq $0, %rax
    je iv_bmp_fail
    movq %rax, %rdi
    movq $1, %rsi              # freesrc=1, closes RW automatically
    call SDL_LoadBMP_RW        # %rax = surface*
    cmpq $0, %rax
    jne iv_got_surf
iv_bmp_fail:
    # BMP error: print the missing file name
    movq $err_bmp, %rdi
    movq %r12, %rsi
    movq $0, %rax
    call printf
    movq $1, %rax
    jmp iv_end

iv_got_surf:
    # SDL_CreateTextureFromSurface(renderer, surface)
    movq renderer, %rdi
    movq %rax, %rsi            # surface
    movq %rax, %r12            # save surface for Free afterwards
    call SDL_CreateTextureFromSurface
    # %rax = texture*
    movq $textures, %rdx
    movq %rax, (%rdx, %rbx, 8)
    # SDL_FreeSurface(surface)
    movq %r12, %rdi
    call SDL_FreeSurface
    incq %rbx
    jmp iv_loop

iv_ok:
    movq $0, %rax
iv_end:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_tex: %rdi = symbol id 0-8, %rsi = x, %rdx = y
# draw a 128x128 square at the given position
.global draw_tex
draw_tex:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    # 5 pushes = aligned, no sub
    movq %rdi, %r12            # id
    movq %rsi, %r13            # x
    movq %rdx, %r14            # y
    # texture = textures[id]
    movq $textures, %rax
    movq (%rax, %r12, 8), %rbx # %rbx = texture*
    # rectbuf = {x, y, 128, 128}
    movq $rectbuf, %rax
    movl %r13d, (%rax)
    movl %r14d, 4(%rax)
    movl $128, 8(%rax)
    movl $128, 12(%rax)
    # SDL_RenderCopy(renderer, tex, 0, &rect)
    movq renderer, %rdi
    movq %rbx, %rsi
    movq $0, %rdx
    movq $rectbuf, %rcx
    call SDL_RenderCopy
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# draw_btn: %rdi = button/text id 9-32, %rsi = x, %rdx = y, %rcx = w, %r8 = h
# draw a rectangular button with text (SPIN/DOUBLE/TAKE WIN)
# like draw_tex, but variable size (buttons are not 128x128 squares)
.global draw_btn
draw_btn:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp             # 6 pushes = even, need a sub 8 (like draw_confetti)
    movq %rdi, %r12            # id
    movq %rsi, %r13            # x
    movq %rdx, %r14            # y
    movq %rcx, %r15            # w
    movq %r8, %rbx             # h (rbx is callee saved, survives the call)
    # texture = textures[id]
    movq $textures, %rax
    movq (%rax, %r12, 8), %rax
    movq %rax, %r12            # texture* in r12
    # rectbuf = {x, y, w, h}
    movq $rectbuf, %rax
    movl %r13d, (%rax)
    movl %r14d, 4(%rax)
    movl %r15d, 8(%rax)
    movl %ebx, 12(%rax)
    # SDL_RenderCopy(renderer, tex, 0, &rect)
    movq renderer, %rdi
    movq %r12, %rsi
    movq $0, %rdx
    movq $rectbuf, %rcx
    call SDL_RenderCopy
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# set_color: %rdi=r, %rsi=g, %rdx=b -> SetRenderDrawColor(renderer,r,g,b,255)
.global set_color
set_color:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp              # 4 pushes = even, need a sub 8
    movq %rdi, %rbx            # r (saved, because rdi gets overwritten)
    movq %rsi, %r12            # g
    movq %rdx, %r13            # b
    movq renderer, %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    movq %r13, %rcx
    movq $255, %r8
    call SDL_SetRenderDrawColor
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# cleanup: destroy textures + window + SDL_Quit
.global cleanup
cleanup:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq $0, %rbx
cl_loop:
    cmpq $33, %rbx
    jge cl_rest
    movq $textures, %rax
    movq (%rax, %rbx, 8), %rdi
    cmpq $0, %rdi
    je cl_next
    call SDL_DestroyTexture
cl_next:
    incq %rbx
    jmp cl_loop
cl_rest:
    movq renderer, %rdi
    cmpq $0, %rdi
    je cl_win
    call SDL_DestroyRenderer
cl_win:
    movq window, %rdi
    cmpq $0, %rdi
    je cl_quit
    call SDL_DestroyWindow
cl_quit:
    call SDL_Quit
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
