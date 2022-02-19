; Archivo:	mainL4.s
; Dispositivo:	PIC16F887
; Autor:	Jeferson Noj
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Contador en PORTA (On Change) y contador en PORTC con TMR0
; Hardware:	LEDs en PORTA y pushbuttons en PORTB
;
; Creado: 15 feb, 2022
; Última modificación:  18 feb, 2022

PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

reset_tmr0 MACRO
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   178		    ; 20ms = 4(1/4Mhz)(256-N)(256)
			    ; N = 256 - (20ms*4Mhz)/(4*256) = 157
    MOVWF   TMR0	    ; Configurar tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM

PSECT udata_bank0	    ; Memoria común
  CONT:		DS 1	    ; Contador
  CONT2:	DS 1
  CONT3:	DS 1

PSECT udata_shr		    ; Memoria compartida
  W_TEMP:	DS 1		
  STATUS_TEMP:	DS 1

PSECT resVect, class=CODE, abs, delta=2
;-------- VECTOR RESET ----------
ORG 00h			    ; Posición 0000h para el reset
resetVec:
    PAGESEL main
    GOTO main

PSECT intVect, class=CODE, abs, delta=2
;-------- INTERRUPT VECTOR ----------
ORG 04h			    ; Posición 0004h para interrupciones
push:
    MOVWF   W_TEMP
    SWAPF   STATUS, 0
    MOVWF   STATUS_TEMP
isr: 
    BTFSC   T0IF	    ; Interrupción del TMR0? No=0 SI=1
    CALL    int_tmr0	    ; Si -> Subrutina con código a ejecutar 
    BTFSC   RBIF	    ; Interrupción del PORTB? No=0 Si=1
    CALL    int_IocB	    ; Si -> Subrutina con codigo a ejecutar
pop:			   
    SWAPF   STATUS_TEMP,0
    MOVWF   STATUS
    SWAPF   W_TEMP, 1
    SWAPF   W_TEMP, 0
    RETFIE
;------ Subrutinas de interrupición -----
int_IocB:
    BTFSS   PORTB, 3	    ; Evaluar estado de boton en RB3
    INCF    PORTA	    ; Incrementar contador en PORTA
    BTFSS   PORTB, 7	    ; Evaluar estado de boton en RB7
    DECF    PORTA	    ; Decrementar contador en PORTA
    BCF	    RBIF	    ; Limpiar bandera de interrupción 
    RETURN

int_tmr0:
    reset_tmr0		    ; Reiniciar TMR0
    INCF    CONT	    ; Aumentar variable CONT
    MOVF    CONT, 0	    ; Mover valor de CONT a W
    SUBLW   50		    ; Restar 50 al valor de W
    BTFSC   STATUS, 2	    ; Evaluar bandera ZERO
    CALL    display1	    ; Ir a subrutina indicada si ZERO = 1
    RETURN

display1:
    CLRF    CONT	    ; Limpiar variable CONT
    INCF    CONT2	    ; Aumentar variable CONT2
    MOVF    CONT2, 0	    ; Mover valor de CONT2 a W
    CALL    tabla	    ; Buscar valor de W equivalente, en la tabla
    MOVWF   PORTD	    ; Mover valor equivalente (7 seg) a PORTD
    MOVF    CONT2, 0	    ; Mover valor de CONT2 a W
    SUBLW   10		    ; Restar 10 al valor de W
    BTFSC   STATUS, 2	    ; Evaluar bandera ZERO
    CALL    display2	    ; Ir a subrutina indicada si ZERO = 1
    RETURN

display2:
    CLRF    CONT2	    ; Limpiar variable CONT2
    INCF    CONT3	    ; Aumentar variables CONT3
    MOVF    CONT3, 0	    ; Mover valor de CONT3 a W
    CALL    tabla	    ; Buscar valor de W equivalente, en la tabla
    MOVWF   PORTC	    ; Mover valor equivalente (7 seg) a PORTD 
    MOVF    CONT3, 0	    ; Mover valor de CONT3 a W
    SUBLW   6		    ; Restar 6 al valor de W
    BTFSS   STATUS, 2	    ; Evaluar bandera ZERO
    GOTO    $+4		    ; Saltar a quinta instrucción siguiente si ZERO = 0
    CLRF    CONT3	    ; Limpiar variable CONT3
    MOVLW   00111111B	    ; Mover literal indicada a W
    MOVWF   PORTC	    ; Mover valor de W a PORTC
    RETURN

PSECT code, delta=2, abs
ORG 100h		    ; Posición 0100h para el código

;-------- CONFIGURACION --------
main:
    CALL    config_clk	    ; Configuración del reloj
    CALL    config_io	    ; Configuración de entradas y salidas
    CALL    config_tmr0	    ; Configuración de TMR0
    CALL    config_IocRB    ; Configuración de interruciones ON-CHANGE
    CALL    config_INT	    ; Configuración de interrupciones
    CLRF    CONT	    ; Limpiar variable CONT
    CLRF    CONT2	    ; Limpiar variable CONT2
    CLRF    CONT3	    ; Limpiar variable CONT3
    BANKSEL PORTA

;-------- LOOP RRINCIPAL --------
loop: 
    GOTO    loop

;---------- SUBRUTINAS ----------
config_clk:
    BANKSEL OSCCON
    BSF	    IRCF2	    ; IRCF/110/4MHz (frecuencia de oscilación)
    BSF	    IRCF1
    BCF	    IRCF0
    BSF	    SCS		    ; Reloj interno
    RETURN
   
config_io:
    BANKSEL ANSEL	
    CLRF    ANSEL	    ; I/O digitales
    CLRF    ANSELH
    BANKSEL TRISA
    CLRF    TRISA	    ; PORTA como salida
    CLRF    TRISC	    ; PORTC como salida
    CLRF    TRISD	    ; PORTD como salida
    BSF	    TRISB, 3	    ; RB3 como entrada
    BSF	    TRISB, 7	    ; RB7 como entrada
    BCF	    OPTION_REG, 7   ; Habilitación de Pull-ups en PORTB
    BSF	    WPUB, 3	    ; Habilitar Pull-up para RB3
    BSF	    WPUB, 7	    ; Habilitar Pull-up para RB7
    BANKSEL PORTA
    CLRF    PORTA	    ; Limpiar PORTA
    CLRF    PORTC	    ; Limpiar PORTC
    CLRF    PORTD	    ; Limpiar PORTD
    RETURN

config_IocRB:
    BANKSEL IOCB	    ; Cambiar a banco 01
    BSF	    IOCB, 3	    ; Habilitar interrupción ON-CHANGE para RB3
    BSF	    IOCB, 7	    ; Hablitiar interrupción ON-CHANGE para RB7
    BANKSEL INTCON	    ; Cambiar a banco 00
    MOVF    PORTB, 0	    ; Mover valor de PORTB a W
    BCF	    RBIF	    ; Limpiar bandera de interrupciones ON-CHANGE
    RETURN

config_INT:
    BANKSEL INTCON	    ; Cambiar a banco 00
    BSF	    GIE		    ; Habilitar interrupciones globales
    BSF	    RBIE	    ; Habilitar interrupciones ON-CHANGE del PORTB
    BCF	    RBIF	    ; Limpiar bandera de interrupciones ON-CHANGE
    BSF	    T0IE	    ; Habilitar interrupcion de overflow del TMR0
    BCF	    T0IF	    ; Limpiar bandera de interrución del TMR0
    RETURN

config_tmr0:
    BANKSEL OPTION_REG
    BCF	    T0CS	    ; Selección de reloj interno
    BCF	    PSA		    ; Asignación del Prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0		    ; Prescaler/111/1:256
    reset_tmr0		    
    RETURN 

ORG 200h		    ; Establecer posición para la tabla
tabla:
    CLRF    PCLATH	    ; Limpiar registro PCLATH
    BSF	    PCLATH, 1	    ; Posicionar PC en 0x02xxh
    ANDLW   0x0F	    ; AND entre W y literal 0x0F
    ADDWF   PCL		    ; ADD entre W y PCL 
    RETLW   00111111B	    ; 0	en 7 seg
    RETLW   00000110B	    ; 1 en 7 seg
    RETLW   01011011B	    ; 2 en 7 seg
    RETLW   01001111B	    ; 3 en 7 seg
    RETLW   01100110B	    ; 4 en 7 seg
    RETLW   01101101B	    ; 5 en 7 seg
    RETLW   01111101B	    ; 6 en 7 seg
    RETLW   00000111B	    ; 7 en 7 seg
    RETLW   01111111B	    ; 8 en 7 seg
    RETLW   01101111B	    ; 9 en 7 seg
    RETLW   00111111B	    ; 10 en 7 seg
    RETLW   01111100B	    ; 11 en 7 seg
    RETLW   00111001B	    ; 12 en 7 seg
    RETLW   01011110B	    ; 13 en 7 seg
    RETLW   01111001B	    ; 14 en 7 seg
    RETLW   01110001B	    ; 15 en 7 seg

END